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
    'body':(None,(0,0,0)), 'head':('body',(0,.275,.005)),
    'arm_l':('body',(-.18,.19,0)), 'arm_r':('body',(.18,.19,0)),
    'forearm_l':('arm_l',(0,-.235,0)), 'forearm_r':('arm_r',(0,-.235,0)),
    'leg_l':('body',(-.025,-.17,.01)), 'leg_r':('body',(.025,-.17,.01)),
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
            'skin':('fbe0d2',.36,.0), 'body_skin':('fbe0d2',.37,.0),
            'skin_shadow':('c9827b',.44,.0), 'lip':('e25b70',.16,.0),
            'eye_white':('fcf8f7',.12,.0), 'iris':('1d9db8',.10,.04),
            'pupil':('0b0d18',.08,.0), 'lash':('26141d',.34,.0),
            'hair':('5a1f36',.29,.04), 'hair_highlight':('9c3d5c',.27,.06),
            'scales':('24b6c8',.20,.20), 'fin_pearl':('7ce0dc',.22,.14),
            'shell_pearl':('fae8e4',.21,.12), 'pearl':('fdf7f2',.14,.12),
            'gold':('d4aa5a',.23,.82), 'gold_light':('eed9a2',.25,.70),
            'glass':('92f0ed',.08,.02), 'specimen_gold':('f2c86b',.22,.18),
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
                # Translucent sea-crystal & gossamer mermaid fin veil (< 0.5 alpha).
                bsdf.inputs['Alpha'].default_value=.42
                bsdf.inputs['IOR'].default_value=1.36
                if 'Specular IOR Level' in bsdf.inputs:
                    bsdf.inputs['Specular IOR Level'].default_value=.58
                if 'Emission Color' in bsdf.inputs:
                    bsdf.inputs['Emission Color'].default_value=rgba('8af2ef')
                    bsdf.inputs['Emission Strength'].default_value=.06
                mat.diffuse_color=rgba(pigment)[:3]+(.42,)
                mat.surface_render_method='BLENDED'
                mat.use_backface_culling=True
            elif key=='specimen_gold':
                if 'Emission Color' in bsdf.inputs:
                    bsdf.inputs['Emission Color'].default_value=rgba('ffd984')
                    bsdf.inputs['Emission Strength'].default_value=.10
            pig_srgb=np.asarray([int(pigment[i:i+2],16)/255 for i in (0,2,4)],dtype=np.float32)
            if key=='scales':
                # 1024x1024 Iridescent Mermaid Tail Scales:
                # v=1 (waist) warm rose-pearl transition -> aquamarine/turquoise -> royal sapphire -> pearl-gold peduncle (v=0)
                size=1024; vv,uu=(np.mgrid[:size,:size].astype(np.float32)+.5)/size
                cols_s,rows_s=34.0,54.0
                gy=vv*rows_s
                row_i=np.floor(gy)
                fy=gy-row_i
                gx=uu*cols_s + (np.mod(row_i,2.0)*.5)
                fx=(gx-np.floor(gx))-.5
                dist_rim=np.sqrt((fx*1.12)**2 + ((fy-.42)*1.05)**2)
                dome=np.clip(1.0 - dist_rim**1.85,0.0,1.0)
                rim_band=np.exp(-((dist_rim-.82)/.085)**2) * (fy>.18).astype(np.float32)
                groove=np.exp(-((dist_rim-.93)/.055)**2)
                striations=np.sin(fx*math.pi*16.0)*0.015*dome
                ventral=np.cos(uu*math.tau)*.5+.5
                lateral=np.sin(uu*math.pi)**2
                waist_blend=np.clip((vv-.85)/.15,0.0,1.0)**1.35
                peduncle_blend=np.clip((.16-vv)/.16,0.0,1.0)**1.4
                c_aqua=np.asarray([.15,.76,.82],dtype=np.float32)
                c_sapphire=np.asarray([.11,.36,.68],dtype=np.float32)
                c_seafoam=np.asarray([.54,.93,.89],dtype=np.float32)
                c_rose=np.asarray([.94,.67,.76],dtype=np.float32)
                c_gold=np.asarray([.96,.84,.58],dtype=np.float32)
                c_skin=np.asarray([.96,.84,.78],dtype=np.float32)
                body_c=(c_sapphire[None,None,:]*(1.0-ventral[:,:,None])*.65
                        + c_aqua[None,None,:]*(.55+.35*lateral[:,:,None])
                        + c_seafoam[None,None,:]*(ventral[:,:,None]*.42))
                body_c=np.clip(body_c,0.0,1.0)
                irid=.5+.5*np.sin(vv*15.0 + uu*math.tau*2.0)
                body_c=body_c*(1.0-.24*irid[:,:,None]*lateral[:,:,None]) + c_rose[None,None,:]*(.24*irid[:,:,None]*lateral[:,:,None])
                col=body_c*(.72 + .34*dome[:,:,None] + striations[:,:,None])
                rim_c=c_gold[None,None,:]*.58 + c_rose[None,None,:]*.42
                col=col*(1.0-.52*rim_band[:,:,None]) + rim_c*(.52*rim_band[:,:,None])
                col*=(1.0 - .32*groove[:,:,None])
                ped_c=c_rose*.45 + c_gold*.30 + c_seafoam*.25
                col=col*(1.0-peduncle_blend[:,:,None]*.55) + ped_c[None,None,:]*(peduncle_blend[:,:,None]*.55)
                col=col*(1.0-waist_blend[:,:,None]*.82) + c_skin[None,None,:]*(waist_blend[:,:,None]*.82)
                px=np.ones((size,size,4),dtype=np.float32); px[:,:,:3]=np.clip(col,0.0,1.0)
                height=(dome*.085 - groove*.045 + striations)*(1.0 - waist_blend*.55)
                dy,dx=np.gradient(height)
                nm=np.ones_like(px); nm[:,:,0]=.5-dx*9.5; nm[:,:,1]=.5-dy*9.5
                self._pack_tex(mat,bsdf,key,px,nm,.58)
            elif key=='fin_pearl':
                size=512; vv,uu=(np.mgrid[:size,:size].astype(np.float32)+.5)/size
                c_root=np.asarray([.42,.88,.86],dtype=np.float32)
                c_mid=np.asarray([.95,.68,.78],dtype=np.float32)
                c_tip=np.asarray([.97,.86,.64],dtype=np.float32)
                w_mid=np.exp(-((vv-.54)/.30)**2)
                w_tip=np.clip((vv-.45)/.55,0.0,1.0)**1.5
                w_root=np.clip(1.0-vv*1.5,0.0,1.0)
                tot=np.maximum(1e-5,w_root+w_mid+w_tip)
                base=(c_root[None,None,:]*w_root[:,:,None]+c_mid[None,None,:]*w_mid[:,:,None]+c_tip[None,None,:]*w_tip[:,:,None])/tot[:,:,None]
                rays=np.sin(uu*math.pi*38.0)*.035*(1.0-.25*vv)
                shimmer=.04*np.cos(uu*math.pi*12.0 - vv*6.0)
                px=np.ones((size,size,4),dtype=np.float32)
                px[:,:,:3]=np.clip(base*(1.0+rays[:,:,None]+shimmer[:,:,None]),0.0,1.0)
                dy,dx=np.gradient(rays)
                nm=np.ones_like(px); nm[:,:,0]=.5-dx*6.0; nm[:,:,1]=.5-dy*6.0
                self._pack_tex(mat,bsdf,key,px,nm,.34)
            elif key=='shell_pearl':
                size=512; vv,uu=(np.mgrid[:size,:size].astype(np.float32)+.5)/size
                flute=np.sin(uu*math.pi*18.0)*.032
                ivory=np.asarray([.98,.92,.90],dtype=np.float32)
                rose=np.asarray([.95,.70,.77],dtype=np.float32)
                aqua=np.asarray([.76,.95,.93],dtype=np.float32)
                blush=np.clip(1.0-vv*1.3,0.0,1.0)*.48
                irid=np.clip(vv-.35,0.0,1.0)*.36*(.5+.5*np.cos(uu*math.tau*2.0))
                col=ivory[None,None,:]*(1.0-blush[:,:,None]-irid[:,:,None])+rose[None,None,:]*blush[:,:,None]+aqua[None,None,:]*irid[:,:,None]
                px=np.ones((size,size,4),dtype=np.float32)
                px[:,:,:3]=np.clip(col*(1.0+flute[:,:,None]),0.0,1.0)
                dy,dx=np.gradient(flute)
                nm=np.ones_like(px); nm[:,:,0]=.5-dx*5.0; nm[:,:,1]=.5-dy*5.0
                self._pack_tex(mat,bsdf,key,px,nm,.30)
            elif key=='skin':
                size=512; vv,uu=(np.mgrid[:size,:size].astype(np.float32)+.5)/size
                cheek=np.exp(-((np.abs(uu-.5)-.090)/.068)**2 - ((vv-.44)/.080)**2)
                nose_tip=np.exp(-((uu-.5)/.030)**2 - ((vv-.38)/.036)**2)
                chin_rosy=np.exp(-((uu-.5)/.050)**2 - ((vv-.14)/.055)**2)
                eyeshadow=np.exp(-((np.abs(uu-.5)-.070)/.050)**2 - ((vv-.545)/.038)**2)
                bridge_hi=np.exp(-((uu-.5)/.015)**2 - ((vv-.46)/.075)**2)
                px=np.ones((size,size,4),dtype=np.float32)
                blush_c=np.asarray([.97,.60,.65],dtype=np.float32)
                shadow_c=np.asarray([.90,.56,.63],dtype=np.float32)
                hi_c=np.asarray([1.0,.96,.93],dtype=np.float32)
                w_b=.30*cheek + .18*nose_tip + .12*chin_rosy
                col=pig_srgb[None,None,:]*(1.0-w_b[:,:,None]) + blush_c[None,None,:]*w_b[:,:,None]
                col=col*(1.0-.22*eyeshadow[:,:,None]) + shadow_c[None,None,:]*(.22*eyeshadow[:,:,None])
                col=col*(1.0-.16*bridge_hi[:,:,None]) + hi_c[None,None,:]*(.16*bridge_hi[:,:,None])
                px[:,:,:3]=np.clip(col,0.0,1.0)
                self._pack_tex(mat,bsdf,key,px,None)
            elif key=='body_skin':
                size=512; vv,uu=(np.mgrid[:size,:size].astype(np.float32)+.5)/size
                shimmer=np.clip((.18-vv)/.18,0.0,1.0)**1.5
                warmth=np.exp(-((vv-.74)/.18)**2)*.12
                rose_c=np.asarray([.97,.68,.70],dtype=np.float32)
                pearl_c=np.asarray([.86,.95,.94],dtype=np.float32)
                col=pig_srgb[None,None,:]*(1.0-warmth[:,:,None]) + rose_c[None,None,:]*warmth[:,:,None]
                col=col*(1.0-.22*shimmer[:,:,None]) + pearl_c[None,None,:]*(.22*shimmer[:,:,None])
                px=np.ones((size,size,4),dtype=np.float32); px[:,:,:3]=np.clip(col,0.0,1.0)
                self._pack_tex(mat,bsdf,key,px,None)
            elif key=='lip':
                size=256; vv,uu=(np.mgrid[:size,:size].astype(np.float32)+.5)/size
                inner=np.clip(1.0-vv*1.15,0.0,1.0)
                center=np.exp(-((uu-.5)/.32)**2)
                gloss_hi=np.exp(-((uu-.48)/.14)**2 - ((vv-.42)/.12)**2)*.24
                deep=np.asarray([.84,.26,.38],dtype=np.float32)
                soft=np.asarray([.96,.58,.65],dtype=np.float32)
                w=np.clip(inner*.74*center+.20,0.0,1.0)
                px=np.ones((size,size,4),dtype=np.float32)
                col=deep[None,None,:]*w[:,:,None] + soft[None,None,:]*(1.0-w[:,:,None])
                px[:,:,:3]=np.clip(col + gloss_hi[:,:,None]*np.asarray([1.0,.92,.94],dtype=np.float32)*.35,0.0,1.0)
                self._pack_tex(mat,bsdf,key,px,None)
            elif key=='iris':
                size=256; yy,xx=(np.mgrid[:size,:size].astype(np.float32)+.5)/size*2.0-1.0
                rr=np.sqrt(xx**2+yy**2); ang=np.arctan2(yy,xx)
                # Note: planar_xy_uv maps ly=+1 (top of iris) to v=1 (yy=+1), ly=-1 (bottom) to v=0 (yy=-1)
                limbal=np.clip((rr-.66)/.30,0.0,1.0)**1.25
                upper_shade=np.clip((yy+.10)/.95,0.0,1.0)**1.35
                lower_glow=np.exp(-((rr-.54)/.18)**2)*np.clip(-yy+.15,0.0,1.0)
                gold_ring=np.exp(-((rr-.35)/.11)**2)
                fibers=.5+.5*np.sin(ang*36.0 + np.sin(rr*8.0)*1.1)
                c_lim=np.asarray([.03,.09,.24],dtype=np.float32)
                c_deep=np.asarray([.06,.20,.46],dtype=np.float32)
                c_turq=np.asarray([.12,.68,.84],dtype=np.float32)
                c_aqua=np.asarray([.48,.98,.95],dtype=np.float32)
                c_gold=np.asarray([.98,.82,.52],dtype=np.float32)
                mid=c_turq[None,None,:]*(1.0-.32*fibers[:,:,None]) + c_aqua[None,None,:]*(.32*fibers[:,:,None])
                col=mid*(1.0-upper_shade[:,:,None]*.78) + c_deep[None,None,:]*(upper_shade[:,:,None]*.78)
                col=col*(1.0-gold_ring[:,:,None]*.48) + c_gold[None,None,:]*(gold_ring[:,:,None]*.48)
                col=col + c_aqua[None,None,:]*(lower_glow[:,:,None]*.52)
                col=col*(1.0-limbal[:,:,None]*.90) + c_lim[None,None,:]*(limbal[:,:,None]*.90)
                px=np.ones((size,size,4),dtype=np.float32); px[:,:,:3]=np.clip(col,0.0,1.0)
                self._pack_tex(mat,bsdf,key,px,None)
            elif key in {'hair','hair_highlight'}:
                size=512; vv,uu=(np.mgrid[:size,:size].astype(np.float32)+.5)/size
                strands=np.sin(uu*math.tau*38.0)*.042 + np.sin(uu*math.tau*14.0)*.028
                angel_halo=np.exp(-((vv-.28)/.085)**2)*(.5+.5*np.cos(uu*math.tau*2.0))*.16
                ombre=np.clip((vv-.25)/.75,0.0,1.0)**1.25
                root_c=np.asarray([.26,.09,.18] if key=='hair' else [.42,.15,.27],dtype=np.float32)
                tip_c=np.asarray([.72,.26,.40] if key=='hair' else [.89,.46,.59],dtype=np.float32)
                halo_c=np.asarray([.96,.68,.76],dtype=np.float32)
                col=root_c[None,None,:]*(1.0-ombre[:,:,None]) + tip_c[None,None,:]*ombre[:,:,None]
                col=col*(1.0+strands[:,:,None]) + halo_c[None,None,:]*angel_halo[:,:,None]
                px=np.ones((size,size,4),dtype=np.float32); px[:,:,:3]=np.clip(col,0.0,1.0)
                dy,dx=np.gradient(strands)
                nm=np.ones_like(px); nm[:,:,0]=.5-dx*5.5; nm[:,:,1]=.5-dy*5.5
                self._pack_tex(mat,bsdf,key,px,nm,.26)
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
    semantics={'skin':'SculptedFaceSkin','body_skin':'PorcelainTorsoSkin',
               'hair':'FlowingMermaidHairBrows','lash':'CurvedLashesAndBrows',
               'glass':'TranslucentSeaGlassVisorVeil','scales':'IridescentMermaidTailScales',
               'fin_pearl':'PearlescentMermaidFin','shell_pearl':'MotherOfPearlScallopShell',
               'pearl':'LustrousSeaPearls','eye_white':'EyeWhite','iris':'Iris','lip':'Lips'}
    suffixes={'hose_bridge':'HoseBridge','hip_sling':'HipSling','boot_cuff':'BootCuff',
              'suit_body':'Continuous','suit_arm':'ContinuousArm','long_hair':'CascadingLocks',
              'torso_skin':'SculptedTorso','mermaid_tail':'SirenTail','caudal_fluke':'RoyalFluke'}
    for (driver,material,deform),objects in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        for obj in objects:obj.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]
        bpy.ops.object.join();obj=bpy.context.object
        label=semantics.get(material,material)
        if driver.startswith('forearm') and material=='skin':label='HandThumbIndexMiddleRingLittleSkin'
        elif driver=='body' and material=='glass':label='CrystalGlassPendantAndHipVeil'
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


def _mermaid_tail_field(point):
    """Unified C1-continuous bone weight field shared by waist, hip fins, tail & dorsal crest."""
    hip=_sstep(-.060,-.215,point.y)
    calf=_sstep(-.340,-.490,point.y)
    fin=_sstep(-.620,-.710,point.y)
    right=_sstep(-.045,.045,point.x)
    wl=hip*(1.0-right); wr=hip*right
    return {
        'body':1.0-hip,
        'leg_l':wl*(1.0-calf), 'calf_l':wl*calf*(1.0-fin), 'fin_l':wl*calf*fin,
        'leg_r':wr*(1.0-calf), 'calf_r':wr*calf*(1.0-fin), 'fin_r':wr*calf*fin,
    }


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
            if deform=='torso_skin':
                if point.y>.10:
                    neck=_sstep(.200,.275,point.y)
                    sh=_sstep(.075,.135,abs(point.x))*_sstep(.13,.225,point.y)*.34*(1-neck)
                    arm_k='arm_r' if point.x>=0 else 'arm_l'
                    weights={'body':1-neck-sh,'head':neck,arm_k:sh}
                elif point.y<-.055:
                    weights=_mermaid_tail_field(point)
                else:
                    weights={'body':1.}
            elif deform=='mermaid_tail':
                weights=_mermaid_tail_field(point)
            elif deform=='caudal_fluke':
                calf_b=_sstep(-.745,-.690,point.y)*.32
                right=_sstep(-.038,.038,point.x)
                fl=(1.0-calf_b)*(1.0-right); fr=(1.0-calf_b)*right
                cl=calf_b*(1.0-right); cr=calf_b*right
                weights={'fin_l':fl,'fin_r':fr,'calf_l':cl,'calf_r':cr}
            elif deform=='long_hair':
                top_edge=.282 if point.z<0.0 else .292
                bot_edge=.195 if point.z<0.0 else .140
                body_w=_sstep(top_edge,bot_edge,point.y)
                sh_w=_sstep(.088,.150,abs(point.x))*_sstep(.12,.23,point.y)*.24*body_w
                arm_k='arm_r' if point.x>=0 else 'arm_l'
                weights={'head':1.0-body_w,'body':body_w-sh_w,arm_k:sh_w}
            elif deform=='suit_arm' or (mat_role=='seam' and driver in {'arm_l','arm_r'}):
                arm_k='arm_l' if driver=='arm_l' else 'arm_r'
                fore_k='forearm_l' if driver=='arm_l' else 'forearm_r'
                sh_b=_sstep(.145,.235,point.y)*.48
                fore_b=_sstep(-.005,-.085,point.y)*(1-sh_b)
                weights={'body':sh_b,arm_k:1-sh_b-fore_b,fore_k:fore_b}
            elif deform=='hip_sling':
                weights=_mermaid_tail_field(point)
            elif deform=='hose_bridge':
                hd=_sstep(.235,.295,point.y)*.55
                weights={'body':1-hd,'head':hd}
            elif deform=='boot_cuff':
                weights=_mermaid_tail_field(point)
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
    # Luminous ocean-gallery studio backdrop so porcelain skin, jewel scales & gossamer veil shine!
    bg.inputs[0].default_value=(.20,.30,.38,1); bg.inputs[1].default_value=.72
    # Note: in Blender coords (x, -z, y), +Y is FRONT (-Z_godot) and -Y is BACK (+Z_godot)!
    for name,at,power,size,col in [
        ('Key front',(-1.3,2.8,2.0),235,2.2,(1.0,.96,.93)),
        ('Warm fill',(1.9,2.3,.9),125,2.0,(.98,.94,.96)),
        ('Aqua rim',(.4,-2.8,1.8),195,2.1,(.78,.97,1.0)),
        ('Side kick',(-2.5,-.5,1.1),105,1.6,(.92,.96,1.0)),
    ]:
        data=bpy.data.lights.new(name,'AREA');data.energy=power;data.size=size;data.color=col
        lamp=bpy.data.objects.new(name,data);scene.collection.objects.link(lamp);lamp.location=at
        lamp.rotation_euler=(Vector((0,0,-.18))-lamp.location).to_track_quat('-Z','Y').to_euler()
    cam=bpy.data.objects.new('Comparison camera',bpy.data.cameras.new('Comparison camera'))
    scene.collection.objects.link(cam);scene.camera=cam;cam.data.type='ORTHO'
    scene.render.engine='CYCLES';scene.cycles.samples=36;scene.cycles.use_denoising=True
    scene.render.resolution_x=1056;scene.render.resolution_y=1536;scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG'
    bpy.context.view_layer.update()
    points=[obj.matrix_world@Vector(corner) for obj in api.objects for corner in obj.bound_box]
    lo=Vector(tuple(min(p[i] for p in points) for i in range(3)))
    hi=Vector(tuple(max(p[i] for p in points) for i in range(3))); center=(lo+hi)/2
    cam.data.ortho_scale=max(hi.z-lo.z,(hi.x-lo.x)*(1536/1056))*1.09
    folder=out_dir/'review-v3';folder.mkdir(parents=True,exist_ok=True)
    for name,eye in [('front',(0,4,0)),('side',(-4,0,0)),('back',(0,-4,0)),('three-quarter',(-2.2,3.8,.25))]:
        cam.location=center+Vector(eye)
        cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
        scene.render.filepath=str(folder/(name+'.png'))
        bpy.ops.render.render(write_still=True)
    # Render sinuous horizontal mermaid swimming hero view!
    arm=getattr(api,'armature',None) or bpy.data.objects.get('ReferenceCharacterRig')
    if arm is not None:
        pb=arm.pose.bones
        for b in pb:b.rotation_mode='XYZ'
        pb['body'].rotation_euler=(math.radians(-72),math.radians(6),math.radians(-14))
        pb['head'].rotation_euler=(math.radians(46),math.radians(-8),math.radians(4))
        pb['arm_r'].rotation_euler=(math.radians(52),math.radians(-8),math.radians(14))
        pb['forearm_r'].rotation_euler=(math.radians(18),0,0)
        pb['arm_l'].rotation_euler=(math.radians(-18),math.radians(6),math.radians(-16))
        pb['forearm_l'].rotation_euler=(math.radians(14),0,0)
        pb['leg_l'].rotation_euler=(math.radians(20),0,0)
        pb['leg_r'].rotation_euler=(math.radians(20),0,0)
        pb['calf_l'].rotation_euler=(math.radians(-28),0,0)
        pb['calf_r'].rotation_euler=(math.radians(-28),0,0)
        pb['fin_l'].rotation_euler=(math.radians(24),0,math.radians(-4))
        pb['fin_r'].rotation_euler=(math.radians(24),0,math.radians(4))
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
