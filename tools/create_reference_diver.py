"""High detail, reference-led character iteration; fidelity is NOT auto-certified.

Blender --background --factory-startup --python tools/create_reference_diver.py
Geometry uses Godot part-local coordinates, converted once into Blender Z-up.
The untouched original concept is the visual reference, never a texture billboard.
"""
import argparse
import hashlib
import importlib.util
import json
import math
import struct
import sys
from pathlib import Path

import bpy
import bmesh
import numpy as np
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT/'assets/source/reference-fidelity'
REFERENCE = ROOT/'assets/source/art-v3/concepts/diver.png'
DRIVERS = {
    'body':(None,(0,0,0)), 'head':('body',(0,.34,0)),
    'arm_l':('body',(-.18,.19,0)), 'arm_r':('body',(.18,.19,0)),
    'forearm_l':('arm_l',(0,-.235,0)), 'forearm_r':('arm_r',(0,-.235,0)),
    'leg_l':('body',(-.08,-.17,.01)), 'leg_r':('body',(.08,-.17,.01)),
    'calf_l':('leg_l',(0,-.265,0)), 'calf_r':('leg_r',(0,-.265,0)),
    'fin_l':('calf_l',(0,-.26,0)), 'fin_r':('calf_r',(0,-.26,0)),
}


def rgba(hex_value):
    rgb = [int(hex_value[i:i+2],16)/255 for i in (0,2,4)]
    return tuple(x/12.92 if x <= .04045 else ((x+.055)/1.055)**2.4 for x in rgb)+(1.,)


class Atelier:
    def __init__(self, output_dir=None):
        self.output_dir=Path(output_dir) if output_dir else OUTPUT
        self.output_dir.mkdir(parents=True,exist_ok=True)
        self.objects=[]
        self.materials={}
        self.entries={}
        self._materials()

    def _pack_tex(self,mat,bsdf,key,pixels,normal=None,normal_strength=.28):
        size=pixels.shape[0]
        entries=[('albedo',pixels)]+([('normal',normal)] if normal is not None else [])
        for kind,array in entries:
            img=bpy.data.images.new('Reference_'+key+'_'+kind,size,size,alpha=True)
            img.colorspace_settings.name='sRGB' if kind=='albedo' else 'Non-Color'
            img.pixels.foreach_set(np.clip(array,0.0,1.0).astype(np.float32).ravel())
            img.filepath_raw=str(self.output_dir/(key+'_'+kind+'.png'))
            img.file_format='PNG';img.save();img.pack()
            tex=mat.node_tree.nodes.new('ShaderNodeTexImage');tex.image=img
            if kind=='albedo':
                mat.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])
            else:
                n=mat.node_tree.nodes.new('ShaderNodeNormalMap');n.inputs['Strength'].default_value=normal_strength
                mat.node_tree.links.new(tex.outputs['Color'],n.inputs['Color'])
                mat.node_tree.links.new(n.outputs['Normal'],bsdf.inputs['Normal'])

    def _materials(self):
        settings={
            'suit':('223244',.59,.02), 'seam':('d4c295',.40,.22),
            'rubber':('1c242e',.65,.03), 'armor':('abbfb4',.35,.08),
            'armor_shadow':('6e857d',.46,.10), 'gold':('b7924c',.30,.78),
            'gold_light':('dac490',.31,.60), 'leather':('8e724b',.56,.02),
            'leather_dark':('4e4237',.62,.02), 'ivory':('dbd1bd',.39,.05),
            'fin_ivory':('e8d9bb',.32,.04), 'skin':('c99b82',.46,.0),
            'skin_shadow':('986c5a',.54,.0), 'lip':('9e5b52',.38,.0),
            'eye_white':('e2d8cb',.22,.0), 'iris':('483326',.22,.04),
            'pupil':('111115',.15,.0), 'hair':('221b18',.46,.02),
            'hair_highlight':('3a2d27',.43,.03), 'glass':('cfe9ef',.04,.0),
            'specimen_gold':('e2b150',.28,.16), 'gauge':('243c44',.20,.15),
        }
        rng=np.random.default_rng(41)
        for key,(pigment,rough,metallic) in settings.items():
            mat=bpy.data.materials.new('Reference_'+key)
            mat.use_nodes=True
            mat.diffuse_color=rgba(pigment)
            bsdf=next(n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED')
            bsdf.inputs['Base Color'].default_value=rgba(pigment)
            bsdf.inputs['Roughness'].default_value=rough
            bsdf.inputs['Metallic'].default_value=metallic
            if key=='glass':
                # Crystal-clear bubble glass (< 0.5 alpha) with minimal face occlusion.
                bsdf.inputs['Alpha'].default_value=.10
                bsdf.inputs['IOR'].default_value=1.16
                if 'Specular IOR Level' in bsdf.inputs:
                    bsdf.inputs['Specular IOR Level'].default_value=.18
                mat.diffuse_color=rgba(pigment)[:3]+(.10,)
                mat.surface_render_method='BLENDED'
                mat.use_backface_culling=True
            pig_srgb=np.asarray([int(pigment[i:i+2],16)/255 for i in (0,2,4)],dtype=np.float32)
            if key in {'suit','rubber'}:
                size=512; yy,xx=np.mgrid[:size,:size].astype(np.float32)
                weave=np.sin((xx+yy)*math.pi*.35)*np.cos((xx-yy)*math.pi*.35)*.012
                grain=rng.normal(0,.004,(size,size)).astype(np.float32)
                tone=.98+weave+grain
                px=np.ones((size,size,4),dtype=np.float32); px[:,:,:3]=pig_srgb[None,None,:]*tone[:,:,None]
                dy,dx=np.gradient(weave)
                nm=np.ones_like(px); nm[:,:,0]=.5-dx*3.5; nm[:,:,1]=.5-dy*3.5
                self._pack_tex(mat,bsdf,key,px,nm,.32)
            elif key=='armor':
                # Genuine cellular Voronoi crackle plate relief matching diver.png!
                size=512; yy,xx=(np.mgrid[:size,:size].astype(np.float32)+.5)/size
                pts=rng.uniform(.04,.96,(34,2)).astype(np.float32)
                d2=(xx[:,:,None]-pts[None,None,:,0])**2+(yy[:,:,None]-pts[None,None,:,1])**2
                part=np.partition(d2,1,axis=2)
                f1,f2=np.sqrt(part[:,:,0]),np.sqrt(part[:,:,1])
                edge=f2-f1
                groove=np.exp(-(edge/.013)**2)
                highlight=np.exp(-((edge-.016)/.012)**2)*.05
                cell_id=np.argmin(d2,axis=2)
                cell_var=(rng.uniform(-.025,.025,34).astype(np.float32))[cell_id]
                height=.04*(1.0-groove)+.015*(1.0-np.clip(f1/.14,0,1))
                px=np.ones((size,size,4),dtype=np.float32)
                groove_col=np.asarray([.46,.56,.52],dtype=np.float32)
                base_col=pig_srgb[None,None,:]*(1.0+cell_var[:,:,None]+highlight[:,:,None])
                px[:,:,:3]=base_col*(1.0-.68*groove[:,:,None])+groove_col[None,None,:]*(.68*groove[:,:,None])
                dy,dx=np.gradient(height)
                nm=np.ones_like(px); nm[:,:,0]=.5-dx*8.0; nm[:,:,1]=.5-dy*8.0
                self._pack_tex(mat,bsdf,key,px,nm,.55)
            elif key=='fin_ivory':
                # Creamy pearl-ivory membrane blending into warm amber-gold outer rails & tips!
                size=512; vv,uu=(np.mgrid[:size,:size].astype(np.float32)+.5)/size
                amber_w=np.clip((1.0-uu*2.6),0.0,1.0)**1.6 * .65 + (vv**2.2)*.75
                amber_w=np.clip(amber_w,0.0,1.0)
                rays=np.sin(uu*math.pi*26.0 + vv*4.0)*.018*(1.0-amber_w*.4)
                ivory_c=np.asarray([.92,.86,.74],dtype=np.float32)
                amber_c=np.asarray([.85,.58,.23],dtype=np.float32)
                px=np.ones((size,size,4),dtype=np.float32)
                px[:,:,:3]=(ivory_c[None,None,:]*(1.0-amber_w[:,:,None])+amber_c[None,None,:]*amber_w[:,:,None])*(1.0+rays[:,:,None])
                dy,dx=np.gradient(rays)
                nm=np.ones_like(px); nm[:,:,0]=.5-dx*5.0; nm[:,:,1]=.5-dy*5.0
                self._pack_tex(mat,bsdf,key,px,nm,.28)
            elif key=='skin':
                # Subtle natural facial warmth (soft cheek/nose rose & orbital shading)
                size=256; vv,uu=(np.mgrid[:size,:size].astype(np.float32)+.5)/size
                cheek=np.exp(-((np.abs(uu-.5)-.10)/.07)**2 - ((vv-.44)/.09)**2)
                nose_w=np.exp(-((uu-.5)/.04)**2 - ((vv-.36)/.05)**2)
                orbit=np.exp(-((np.abs(uu-.5)-.08)/.05)**2 - ((vv-.54)/.05)**2)
                px=np.ones((size,size,4),dtype=np.float32)
                warm=np.asarray([.78,.50,.44],dtype=np.float32)
                shade=np.asarray([.66,.46,.39],dtype=np.float32)
                col=pig_srgb[None,None,:]*(1.0-.16*cheek[:,:,None]-.12*nose_w[:,:,None])+warm[None,None,:]*(.16*cheek[:,:,None]+.12*nose_w[:,:,None])
                px[:,:,:3]=col*(1.0-.12*orbit[:,:,None])+shade[None,None,:]*(.12*orbit[:,:,None])
                self._pack_tex(mat,bsdf,key,px,None)
            self.materials[key]=mat

    def fit_front(self,x,y,offset=.0015):
        torso=next(o for o in self.objects if o['driver']=='body' and 'torso' in o.name.lower())
        tree=BVHTree.FromObject(torso,bpy.context.evaluated_depsgraph_get())
        hit,normal,_,_=tree.ray_cast(Vector((x,1,y)),Vector((0,-1,0)))
        return -hit.y-offset if hit is not None else -.055

    def fit_radial(self,angle,y,offset=.002):
        torso=next(o for o in self.objects if o['driver']=='body' and 'torso' in o.name.lower())
        tree=BVHTree.FromObject(torso,bpy.context.evaluated_depsgraph_get())
        radial=Vector((math.cos(angle),-math.sin(angle),0))
        hit,normal,_,_=tree.ray_cast(radial+Vector((0,0,y)),-radial)
        if hit is None:return (math.cos(angle)*.11,y,math.sin(angle)*.065)
        hit+=radial*offset
        return (hit.x,hit.z,-hit.y)

    def surface(self,name,vertices,faces,material,driver='body',uv=None,smooth=True,deform_mode=None):
        if driver not in DRIVERS:
            raise ValueError('Unknown driver '+driver)
        label=driver+'__'+name
        if label in self.entries:
            raise ValueError('Duplicate authored part '+label)
        data=bpy.data.meshes.new(label)
        data.from_pydata([(float(x),-float(z),float(y)) for x,y,z in vertices],[],faces)
        data.validate()
        bm=bmesh.new(); bm.from_mesh(data)
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
        bm.to_mesh(data); bm.free()
        data.update()
        for polygon in data.polygons:
            polygon.use_smooth=smooth
        layer=data.uv_layers.new(name='TailoredUV')
        for loop in data.loops:
            if uv is not None:
                layer.data[loop.index].uv=uv[loop.vertex_index]
            else:
                x,y,z=vertices[loop.vertex_index]
                layer.data[loop.index].uv=((math.atan2(z,x)/math.tau)%1, y+.5)
        obj=bpy.data.objects.new(label,data)
        bpy.context.scene.collection.objects.link(obj)
        data.materials.append(self.materials[material])
        obj['driver']=driver; obj['material_role']=material
        if deform_mode:
            obj['deform_mode']=deform_mode
        self.objects.append(obj)
        data.calc_loop_triangles()
        self.entries[label]={'driver':driver,'material':material,'triangles':len(data.loop_triangles)}
        return obj

    def ellipsoid(self,name,center,radii,material,driver='body',segments=32,rings=20):
        verts=[(center[0],center[1]+radii[1],center[2])]; uv=[(.5,1)]; faces=[]
        for i in range(1,rings):
            theta=math.pi*i/rings
            for j in range(segments):
                a=math.tau*j/segments
                verts.append((center[0]+radii[0]*math.sin(theta)*math.cos(a),
                              center[1]+radii[1]*math.cos(theta),center[2]+radii[2]*math.sin(theta)*math.sin(a)))
                uv.append((j/segments,1-i/rings))
        bottom=len(verts); verts.append((center[0],center[1]-radii[1],center[2])); uv.append((.5,0))
        for j in range(segments):
            faces.append((0,1+(j+1)%segments,1+j))
            for i in range(rings-2):
                a=1+i*segments+j; b=1+i*segments+(j+1)%segments
                faces.append((a,b,b+segments,a+segments))
            faces.append((bottom,1+(rings-2)*segments+j,1+(rings-2)*segments+(j+1)%segments))
        return self.surface(name,verts,faces,material,driver,uv)

    def tube(self,name,points,radii,material,driver='body',sides=10):
        points=[Vector(p) for p in points]; verts=[]; faces=[]; uv=[]
        for i,p in enumerate(points):
            direction=(points[min(i+1,len(points)-1)]-points[max(i-1,0)]).normalized()
            cross=direction.cross(Vector((0,0,1)))
            if cross.length<.01: cross=direction.cross(Vector((1,0,0)))
            cross.normalize(); up=direction.cross(cross).normalized()
            for j in range(sides):
                a=j/sides*math.tau
                verts.append(p+radii[i]*(cross*math.cos(a)+up*math.sin(a))); uv.append((j/sides,i/(len(points)-1)))
                if i:
                    n=i*sides+j; q=i*sides+(j+1)%sides
                    faces.append((n-sides,q-sides,q,n))
        faces.extend([tuple(range(sides-1,-1,-1)),tuple((len(points)-1)*sides+j for j in range(sides))])
        return self.surface(name,verts,faces,material,driver,uv)

    def strap(self,name,path,width,material='leather',driver='body',thickness=.002):
        # A real closed strip follows the garment rather than floating tubes.
        verts=[]; faces=[]
        path=[Vector(p) for p in path]
        for i,p in enumerate(path):
            tangent=(path[min(i+1,len(path)-1)]-path[max(0,i-1)]).normalized()
            lateral=tangent.cross(Vector((0,0,1))).normalized()
            for depth in (-thickness/2,thickness/2):
                for side in (-1,1): verts.append(p+lateral*width*side/2+Vector((0,0,depth)))
            if i:
                n=i*4; a=n-4
                for x,y in ((0,1),(1,3),(3,2),(2,0)):
                    faces.append((a+x,a+y,n+y,n+x))
        faces.extend([(0,2,3,1),tuple(range(len(verts)-4,len(verts)))])
        return self.surface(name,verts,faces,material,driver)


def load(name):
    spec=importlib.util.spec_from_file_location(name,ROOT/'tools'/(name+'.py'))
    module=importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
    return module


def driver_world(key):
    parent,position=DRIVERS[key]
    result=Vector(position)
    if parent: result+=driver_world(parent)
    return result


def merge_draw_groups(api):
    """Keep distinct authored material roles without hundreds of tiny draw calls."""
    original=dict(api.entries);groups={};merged=[];entries={}
    for obj in api.objects:
        groups.setdefault((obj['driver'],obj['material_role'],obj.get('deform_mode','')),[]).append(obj)
    semantics={'skin':'SculptedFaceSkin','hair':'SidePartHairBunBrows','glass':'ClearGlassVisor',
               'eye_white':'EyeWhite','iris':'Iris','lip':'Lips','suit':'TailoredSuit'}
    suffixes={'hose_bridge':'HoseBridge','hip_sling':'HipSling','boot_cuff':'BootCuff',
              'suit_body':'Continuous','suit_arm':'Sleeve'}
    for (driver,material,deform),objects in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        for obj in objects:obj.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]
        bpy.ops.object.join();obj=bpy.context.object
        label=semantics.get(material,material)
        if driver.startswith('forearm') and material=='suit':label='GloveThumbIndexMiddleRingLittleSuit'
        elif driver.startswith('forearm') and material=='rubber':label='GloveThumbIndexMiddleRingLittleRubber'
        elif driver=='body' and material=='glass':label='SpecimenGlassVial'
        if deform in suffixes and (driver,material,'') in groups:
            label=label+suffixes[deform]
        obj.name=driver+'__'+label;obj['driver']=driver;obj['material_role']=material
        if deform:obj['deform_mode']=deform
        obj.data.calc_loop_triangles()
        entries[obj.name]={'driver':driver,'material':material,'triangles':len(obj.data.loop_triangles),
                          'authored_parts':[o for o,v in original.items() if v['driver']==driver and v['material']==material]}
        merged.append(obj)
    api.objects=merged;api.entries=entries


def _sstep(e0,e1,x):
    t=max(0.0,min(1.0,(x-e0)/(e1-e0)))
    return t*t*(3.0-2.0*t)


def skin_character(api):
    """Author a real multi-joint deformation rig with normalized blended weights."""
    bones=bpy.data.armatures.new('ReferenceCharacterSkeleton')
    arm=bpy.data.objects.new('ReferenceCharacterRig',bones)
    bpy.context.scene.collection.objects.link(arm)
    bpy.ops.object.select_all(action='DESELECT');arm.select_set(True)
    bpy.context.view_layer.objects.active=arm;bpy.ops.object.mode_set(mode='EDIT')
    for key,(parent,offset) in DRIVERS.items():
        p=driver_world(key)
        tail=p+Vector((0,.09 if key=='head' else -.12,0))
        bone=bones.edit_bones.new(key)
        bone.head=(p.x,-p.z,p.y);bone.tail=(tail.x,-tail.z,tail.y)
        if parent:bone.parent=bones.edit_bones[parent]
    bpy.ops.object.mode_set(mode='OBJECT')
    for obj in api.objects:
        driver=obj['driver'];mat_role=obj['material_role'];deform=obj.get('deform_mode','')
        base=driver_world(driver)
        groups={key:obj.vertex_groups.new(name=key) for key in DRIVERS}
        for v in obj.data.vertices:
            point=Vector((v.co.x,v.co.z,-v.co.y))
            point+=base
            v.co=(point.x,-point.z,point.y)
            weights={driver:1.}
            if deform=='suit_body' or (mat_role=='seam' and driver in {'body','leg_l','leg_r','calf_l','calf_r'}):
                if point.y>.11:
                    neck=_sstep(.235,.285,point.y)*.28
                    sh=_sstep(.085,.122,abs(point.x))*_sstep(.13,.22,point.y)*.24*(1-neck)
                    arm_k='arm_r' if point.x>=0 else 'arm_l'
                    weights={'body':1-neck-sh,'head':neck,arm_k:sh}
                elif point.y<-.085:
                    hip=_sstep(-.085,-.225,point.y)
                    right=_sstep(-.032,.032,point.x)
                    calf=_sstep(-.385,-.485,point.y)
                    fin=_sstep(-.665,-.710,point.y)
                    wl=hip*(1-right); wr=hip*right
                    weights={'body':1-hip,'leg_l':wl*(1-calf),'calf_l':wl*calf*(1-fin),'fin_l':wl*calf*fin,
                             'leg_r':wr*(1-calf),'calf_r':wr*calf*(1-fin),'fin_r':wr*calf*fin}
                else:
                    weights={'body':1.}
            elif deform=='suit_arm' or (mat_role=='seam' and driver in {'arm_l','arm_r'}):
                arm_k='arm_l' if driver=='arm_l' else 'arm_r'
                fore_k='forearm_l' if driver=='arm_l' else 'forearm_r'
                sh_b=_sstep(.145,.235,point.y)*.48
                fore_b=_sstep(-.005,-.085,point.y)*(1-sh_b)
                weights={'body':sh_b,arm_k:1-sh_b-fore_b,fore_k:fore_b}
            elif deform=='hip_sling':
                hip=_sstep(-.085,-.220,point.y)
                right=1. if point.x>=0 else 0.
                weights={'body':1-hip,'leg_l':hip*(1-right),'leg_r':hip*right}
            elif deform=='hose_bridge':
                hd=_sstep(.065,-.005,point.z)
                weights={'body':1-hd,'head':hd}
            elif deform=='boot_cuff':
                calf_k='calf_l' if driver=='fin_l' else 'calf_r'
                cb=_sstep(-.695,-.648,point.y)*.45
                weights={driver:1-cb,calf_k:cb}
            total_w=sum(w for w in weights.values() if w>1e-5)
            for key,weight in weights.items():
                if weight>1e-5:groups[key].add([v.index],weight/total_w,'REPLACE')
        obj.parent=arm
        mod=obj.modifiers.new('Anatomical cloth deformation','ARMATURE');mod.object=arm
    api.armature=arm
    api.skinned=True


def prepare_export_normals(api):
    for obj in api.objects:
        bm=bmesh.new();bm.from_mesh(obj.data)
        bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-8)
        bmesh.ops.triangulate(bm,faces=list(bm.faces))
        tiny=[f for f in bm.faces if f.calc_area()<=1e-11]
        if tiny:bmesh.ops.delete(bm,geom=tiny,context='FACES')
        bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
        bm.to_mesh(obj.data);bm.free();obj.data.update()
        for _ in range(8):
            obj.data.calc_loop_triangles()
            cn=obj.data.corner_normals
            flipped=False
            for tri in obj.data.loop_triangles:
                if not obj.data.polygons[tri.polygon_index].use_smooth:
                    continue
                a,b,c=(obj.data.vertices[i].co for i in tri.vertices)
                face=(b-a).cross(c-a)
                l0,l1,l2=tri.loops
                nsum=cn[l0].vector+cn[l1].vector+cn[l2].vector
                if face.dot(nsum)<=1e-6:
                    obj.data.polygons[tri.polygon_index].use_smooth=False
                    flipped=True
            obj.data.update()
            if not flipped:
                break


def preview(api, out_dir=None):
    out_dir=Path(out_dir) if out_dir else OUTPUT
    scene=bpy.context.scene
    for obj in api.objects:
        if not getattr(api,'skinned',False):
            driver=obj['driver']; p=driver_world(driver)
            obj.location=(p.x,-p.z,p.y)
    scene.world=bpy.data.worlds.new('Reference neutral studio')
    scene.world.use_nodes=True
    bg=next(n for n in scene.world.node_tree.nodes if n.type=='BACKGROUND')
    # Warm sunlit studio fill so materials read clearly like concepts/diver.png
    bg.inputs[0].default_value=(.58,.54,.49,1); bg.inputs[1].default_value=.75
    # Note: in Blender coords (x, -z, y), +Y is FRONT (-Z_godot) and -Y is BACK (+Z_godot)!
    for name,at,power,size in [('Key front',(-1.4,2.8,2.1),210,2.2),('Warm fill',(1.8,2.2,.8),110,1.8),
                               ('Back light',(.3,-2.8,1.9),165,2.0),('Side kick',(-2.6,-.4,1.2),95,1.5)]:
        data=bpy.data.lights.new(name,'AREA');data.energy=power;data.size=size
        lamp=bpy.data.objects.new(name,data);scene.collection.objects.link(lamp);lamp.location=at
        lamp.rotation_euler=(Vector((0,0,-.10))-lamp.location).to_track_quat('-Z','Y').to_euler()
    cam=bpy.data.objects.new('Comparison camera',bpy.data.cameras.new('Comparison camera'))
    scene.collection.objects.link(cam);scene.camera=cam;cam.data.type='ORTHO'
    scene.render.engine='CYCLES';scene.cycles.samples=28;scene.cycles.use_denoising=True
    scene.render.resolution_x=1056;scene.render.resolution_y=1536;scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG'
    bpy.context.view_layer.update()
    points=[obj.matrix_world@Vector(corner) for obj in api.objects for corner in obj.bound_box]
    lo=Vector(tuple(min(p[i] for p in points) for i in range(3)))
    hi=Vector(tuple(max(p[i] for p in points) for i in range(3))); center=(lo+hi)/2
    cam.data.ortho_scale=(hi.z-lo.z)*1.11
    folder=out_dir/'review-v3';folder.mkdir(parents=True,exist_ok=True)
    # Side camera at (-4,0,0) faces left, matching diver.png middle turnaround!
    for name,eye in [('front',(0,4,0)),('side',(-4,0,0)),('back',(0,-4,0)),('three-quarter',(-2.2,3.8,.25))]:
        cam.location=center+Vector(eye)
        cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(folder/(name+'.png'))
        bpy.ops.render.render(write_still=True)
    # Render horizontal swimming hero view matching diver.png bottom illustration!
    arm=getattr(api,'armature',None) or bpy.data.objects.get('ReferenceCharacterRig')
    if arm is not None:
        pb=arm.pose.bones
        for b in pb:b.rotation_mode='XYZ'
        pb['body'].rotation_euler=(math.radians(-78),0,math.radians(-10))
        pb['head'].rotation_euler=(math.radians(48),math.radians(-10),0)
        pb['arm_r'].rotation_euler=(math.radians(38),0,math.radians(16))
        pb['forearm_r'].rotation_euler=(math.radians(14),0,0)
        pb['arm_l'].rotation_euler=(math.radians(-16),0,math.radians(-14))
        pb['leg_l'].rotation_euler=(math.radians(10),0,0)
        pb['leg_r'].rotation_euler=(math.radians(-8),0,0)
        pb['calf_l'].rotation_euler=(math.radians(-10),0,0)
        pb['fin_l'].rotation_euler=(math.radians(8),0,0)
        pb['fin_r'].rotation_euler=(math.radians(-6),0,0)
        bpy.context.view_layer.update()
        scene.render.resolution_x=1536;scene.render.resolution_y=960
        deps=bpy.context.evaluated_depsgraph_get()
        s_pts=[eo.matrix_world@v.co for obj in api.objects for eo in (obj.evaluated_get(deps),) for v in eo.data.vertices]
        s_lo=Vector(tuple(min(p[i] for p in s_pts) for i in range(3)))
        s_hi=Vector(tuple(max(p[i] for p in s_pts) for i in range(3)))
        swim_c=(s_lo+s_hi)*.5
        cam.location=swim_c+Vector((3.6,1.4,.28))
        cam.rotation_euler=(swim_c-cam.location).to_track_quat('-Z','Y').to_euler()
        inv_m=cam.rotation_euler.to_matrix().transposed()
        proj=[inv_m@(p-swim_c) for p in s_pts]
        px_lo,px_hi=min(p.x for p in proj),max(p.x for p in proj)
        py_lo,py_hi=min(p.y for p in proj),max(p.y for p in proj)
        swim_c+=cam.rotation_euler.to_matrix()@Vector((.5*(px_lo+px_hi),.5*(py_lo+py_hi),0))
        cam.location=swim_c+Vector((3.6,1.4,.28))
        cam.rotation_euler=(swim_c-cam.location).to_track_quat('-Z','Y').to_euler()
        cam.data.ortho_scale=max(px_hi-px_lo,(py_hi-py_lo)*(1536/960))*1.10
        scene.render.filepath=str(folder/'swimming.png')
        bpy.ops.render.render(write_still=True)
        for b in pb:b.rotation_euler=(0,0,0)
        bpy.context.view_layer.update()
    bpy.ops.wm.save_as_mainfile(filepath=str(out_dir/'reference-diver.blend'))


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--no-render',action='store_true')
    parser.add_argument('--render-only',action='store_true')
    parser.add_argument('--output-dir',type=Path,default=OUTPUT)
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    if not REFERENCE.is_file():raise RuntimeError('Original reference required')
    out_dir=args.output_dir.resolve()
    out_dir.mkdir(parents=True,exist_ok=True)
    if args.render_only:
        bpy.ops.wm.open_mainfile(filepath=str(out_dir/'reference-diver.blend'))
        api=Atelier.__new__(Atelier)
        api.objects=[o for o in bpy.context.scene.objects if o.type=='MESH' and 'driver' in o]
        api.armature=bpy.data.objects.get('ReferenceCharacterRig')
        api.skinned=True
        preview(api,out_dir)
        return
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    scene=bpy.context.scene;scene.name='Reference-led diver - visual review required'
    scene.unit_settings.system='METRIC'
    api=Atelier(out_dir)
    for module in ('fidelity_body','fidelity_head','fidelity_apparel'):
        load(module).build(api)
    merge_draw_groups(api)
    skin_character(api)
    prepare_export_normals(api)
    for obj in api.objects:
        obj.data.calc_loop_triangles()
        api.entries[obj.name]['triangles']=len(obj.data.loop_triangles)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in api.objects:obj.select_set(True)
    api.armature.select_set(True)
    bpy.context.view_layer.objects.active=api.armature
    bpy.ops.export_scene.gltf(filepath=str(out_dir/'reference_diver.glb'),export_format='GLB',use_selection=True,
                              export_yup=True,export_apply=False,export_skins=True,export_animations=False,export_cameras=False,export_lights=False)
    exported=(out_dir/'reference_diver.glb').read_bytes()
    json_length=struct.unpack_from('<I',exported,12)[0]
    gltf=json.loads(exported[20:20+json_length])
    for node in gltf['nodes']:
        if 'mesh' in node and node.get('name') in api.entries:
            api.entries[node['name']]['triangles']=sum(gltf['accessors'][p['indices']]['count']//3 for p in gltf['meshes'][node['mesh']]['primitives'])
    record={'status':'iteration-needs-visual-review','reference':str(REFERENCE.relative_to(ROOT)).replace('\\','/'),
            'reference_sha256':hashlib.sha256(REFERENCE.read_bytes()).hexdigest(),
            'parts':api.entries,'triangles':sum(v['triangles'] for v in api.entries.values()),
            'drivers':DRIVERS,'skinned':True,'bones':len(DRIVERS),
            'model_sha256':hashlib.sha256(exported).hexdigest(),
            'not_a_100_percent_fidelity_certificate':True}
    (out_dir/'manifest.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(out_dir/'reference-diver.blend'))
    if not args.no_render:preview(api,out_dir)
    else:bpy.ops.wm.save_as_mainfile(filepath=str(out_dir/'reference-diver.blend'))
    print('REFERENCE_DIVER_ITERATION_READY '+str(record['triangles'])+' triangles, visual review remains required',flush=True)


if __name__=='__main__':main()
