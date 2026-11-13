"""Build the image-directed v3 kit with Blender, then validate before promotion.

rtk proxy blender --background --factory-startup --python tools/create_art_v3.py
rtk proxy Godot --headless --path . -s tests/asset_pipeline.gd -- --staging
rtk proxy blender --background --python tools/create_art_v3.py -- --promote

All references and editable sources live under assets/source/art-v3. Individual
family modules own the silhouettes; the existing pipeline owns UVs, PBR, skinning,
animation, dimensions and triangle budgets.
"""
import argparse
import hashlib
import importlib.util
import json
import math
import random
import shutil
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/source/art-v3'
STAGING = ROOT / '.tools/art-staging'
VERSION = 'luminous-ocean-3'


def load_module(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / 'tools' / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def refresh_library_records():
    path = SOURCE/'provenance.json'
    if not path.is_file():
        return
    record = json.loads(path.read_text(encoding='utf-8'))
    record['tools'] = {p.name:digest(p) for p in (ROOT/'tools').glob('art_v3_*.py')}
    record['tools']['create_art_v3.py'] = digest(Path(__file__))
    record['libraries'] = {name:{'file':'assets/source/art-v3/'+name, 'sha256':digest(SOURCE/name)}
                           for name in ('ocean_surface.glb','expedition_library.glb') if (SOURCE/name).is_file()}
    path.write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')


def references():
    result = {}
    for name in ('diver', 'creatures', 'creatures_large', 'environment', 'equipment', 'submarines', 'ocean'):
        path = SOURCE / 'concepts' / (name + '.png')
        if not path.is_file() or path.stat().st_size < 100_000:
            raise RuntimeError('Generate and save GPT Image reference first: ' + str(path))
        result[name] = path
    return result


def recalculate_normals(parts):
    for obj in parts:
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        bm.to_mesh(obj.data)
        bm.free()


def render_models(api):
    """Neutral, honest previews from the actual exported production geometry."""
    preview = SOURCE / 'previews'
    preview.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    try:
        scene.render.engine = 'BLENDER_EEVEE'
    except TypeError:
        scene.render.engine = 'CYCLES'
        scene.cycles.samples = 24
    scene.render.resolution_x, scene.render.resolution_y = 720, 600
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.world = bpy.data.worlds.new('Warm paper studio')
    scene.world.use_nodes = True
    bg = next(n for n in scene.world.node_tree.nodes if n.type == 'BACKGROUND')
    bg.inputs[0].default_value = (.12, .16, .17, 1)
    bg.inputs[1].default_value = .65
    camera = bpy.data.objects.new('Art review camera', bpy.data.cameras.new('Art review camera'))
    scene.collection.objects.link(camera)
    scene.camera = camera
    camera.data.type = 'ORTHO'
    camera.data.clip_start = .001
    lamps = []
    for i, color in enumerate(((1., .91, .76), (.66, .88, 1.), (1., .98, .89))):
        data = bpy.data.lights.new('Art studio ' + str(i), 'AREA')
        data.color, data.shape = color, 'DISK'
        lamp = bpy.data.objects.new(data.name, data)
        scene.collection.objects.link(lamp)
        lamps.append(lamp)
    for _, obj in api.ASSETS:
        obj.hide_render = True
        for child in obj.children_recursive:
            child.hide_render = True
    for name, obj in api.ASSETS:
        obj.hide_render = False
        for child in obj.children_recursive:
            child.hide_render = False
        lo, hi = (Vector(p) for p in api.CONTRACT[name]['bounds_blender'])
        center, span = (lo + hi) / 2, max(hi - lo)
        camera.location = center + Vector((1.15, -1.65, 1.05)) * span
        camera.rotation_euler = (center - camera.location).to_track_quat('-Z', 'Y').to_euler()
        # Fit all eight projected AABB corners, including tall asymmetric coral.
        inverse = camera.rotation_euler.to_matrix().transposed()
        projected = [inverse @ (Vector((x,y,z))-center)
                     for x in (lo.x,hi.x) for y in (lo.y,hi.y) for z in (lo.z,hi.z)]
        width = max(p.x for p in projected)-min(p.x for p in projected)
        height = max(p.y for p in projected)-min(p.y for p in projected)
        camera.data.ortho_scale = max(width,height*720/600)*1.12
        for lamp, direction, energy in zip(lamps, ((1,-1.2,1.7),(-1,.8,1),(-1,-1,.8)), (115,70,90)):
            lamp.location = center + Vector(direction) * span
            lamp.rotation_euler = (center - lamp.location).to_track_quat('-Z', 'Y').to_euler()
            lamp.data.size = span * 1.6
            lamp.data.energy = energy * span * span
        scene.render.filepath = str(preview / (name + '.png'))
        bpy.ops.render.render(write_still=True)
        obj.hide_render = True
        for child in obj.children_recursive:
            child.hide_render = True
        print('PREVIEW_READY ' + name, flush=True)
    for obj in lamps + [camera]:
        bpy.data.objects.remove(obj, do_unlink=True)
    scene.camera = None
    for _, obj in api.ASSETS:
        obj.hide_render = False
        for child in obj.children_recursive:
            child.hide_render = False


def ocean_mesh():
    """Camera-centered concentric ocean grid: dense nearby, sparse at infinity.

    Uniform 19 m cells undersample the 20 m short waves. This authored radial
    topology puts 0.75 m rings near the observer and spends fewer triangles in
    the hazy distance. Height remains animated analytically by both shaders.
    """
    vertices, faces = [(0., 0., 0.)], []
    radii = [.75 * i for i in range(1, 25)]
    radii += [18. * (2200. / 18.) ** (i / 52.) for i in range(1, 53)]
    count = 128
    for radius in radii:
        for j in range(count):
            angle = j / count * math.tau
            vertices.append((math.cos(angle) * radius, math.sin(angle) * radius, 0.))
    for j in range(count):
        faces.append((0, 1+j, 1+(j+1)%count))
    for i in range(len(radii)-1):
        inner, outer = 1+i*count, 1+(i+1)*count
        for j in range(count):
            k = (j+1)%count
            faces.append((inner+j,outer+j,outer+k,inner+k))
    data = bpy.data.meshes.new('Concentric ocean patch')
    data.from_pydata(vertices, [], faces)
    data.update()
    obj = bpy.data.objects.new('OceanSurface', data)
    bpy.context.scene.collection.objects.link(obj)
    uv = data.uv_layers.new(name='UVMap')
    for loop in data.loops:
        p = data.vertices[loop.vertex_index].co
        uv.data[loop.index].uv = (p.x / 4400 + .5, p.y / 4400 + .5)
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    path = SOURCE / 'ocean_surface.glb'
    bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB', use_selection=True,
                              export_yup=True, export_animations=False, export_cameras=False,
                              export_lights=False)
    obj.hide_set(True)
    obj.hide_render = True
    return {'file':'assets/models/ocean_surface.glb', 'triangles':count*(2*len(radii)-1),
            'vertices':len(vertices), 'radius':2200, 'near_ring_spacing':.75,
            'reference':'assets/source/art-v3/concepts/ocean.png'}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--assets', nargs='+')
    parser.add_argument('--promote', action='store_true')
    parser.add_argument('--previews', action='store_true')
    parser.add_argument('--skip-hero', action='store_true')
    parser.add_argument('--hero-only', action='store_true')
    parser.add_argument('--preview-only', action='store_true')
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    api = load_module('create_assets')
    api.GENERATOR_VERSION = VERSION
    if args.promote:
        staged = json.loads((STAGING/'asset-manifest.json').read_text(encoding='utf-8'))
        extras = [SOURCE / name for name in ('ocean_surface.glb', 'expedition_library.glb')]
        for path in extras:
            if not path.is_file():
                raise RuntimeError('Missing authored production library: ' + path.name)
        for name, entry in staged.items():
            if entry.get('model_sha256') != digest(STAGING/'models'/(name+'.glb')):
                raise RuntimeError('Staged mesh changed after the v3 build: ' + name)
        api.promote()
        for path in extras:
            shutil.copy2(path, ROOT / 'assets/models' / path.name)
        return
    refs = references()
    if args.preview_only:
        bpy.ops.wm.open_mainfile(filepath=str(SOURCE/'ocean-kit.blend'))
        for name in api.CONTRACT:
            obj = bpy.data.objects.get(name+'_Rig') or bpy.data.objects.get(name)
            if obj is None:
                raise RuntimeError('Editable kit missing ' + name)
            obj.location = (0,0,0)
            api.ASSETS.append((name,obj))
        render_models(api)
        return
    if args.hero_only:
        load_module('art_v3_hero').build(SOURCE, refs)
        refresh_library_records()
        return
    for module in ('art_v3_environment', 'art_v3_creatures', 'art_v3_equipment'):
        load_module(module).register(api)
    api.SOURCE = STAGING / 'source-v3'
    for path in (api.SOURCE/'textures', STAGING/'models', SOURCE):
        path.mkdir(parents=True,exist_ok=True)
    names = args.assets or list(api.CONTRACT)
    unknown = set(names)-set(api.CONTRACT)
    if unknown:
        raise RuntimeError('Unknown asset IDs: ' + str(unknown))
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    bpy.context.scene.name = 'Abyssal Echo - image directed ocean atelier'
    bpy.context.scene.render.fps = 30
    bpy.context.scene.unit_settings.system = 'METRIC'
    api.MANIFEST = json.loads((STAGING/'asset-manifest.json').read_text()) if args.assets and (STAGING/'asset-manifest.json').exists() else {}
    for name in names:
        api.CURRENT = name
        random.seed(913+sum(map(ord,name)))
        getattr(api,'create_'+name)()
        recalculate_normals(api.PARTS)
        api.finish_asset(name)
        entry = api.MANIFEST[name]
        category = 'creatures' if name in {'fish','fish_small','fish_predator','fish_abyss','manta_ray','sea_turtle','squid','crab','jellyfish'} else ('equipment' if name.startswith(('weapon_','resource_')) or name in {'pod','shipwreck'} else 'environment')
        entry.update(source='tools/create_art_v3.py', reference_image=str(refs[category].relative_to(ROOT)).replace('\\','/'),
                     reference_sha256=digest(refs[category]), model_sha256=digest(STAGING/'models'/(name+'.glb')))
    (STAGING/'asset-manifest.json').write_text(json.dumps(api.MANIFEST,indent=2)+'\n',encoding='utf-8')
    if args.previews:
        render_models(api)
    water = ocean_mesh()
    # Arrange the editable kit after export; GLB coordinates remain contractual.
    for i,(name,obj) in enumerate(api.ASSETS):
        obj.location += Vector(((i%6)*12,(i//6)*12,0))
    bpy.ops.file.pack_all()
    blend_name = 'ocean-kit.blend' if not args.assets else 'ocean-kit-subset.blend'
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/blend_name))
    if not args.skip_hero:
        load_module('art_v3_hero').build(SOURCE, refs)
    provenance = {'version':VERSION,'image_generation':'built-in GPT Image',
                  'workflow':['GPT Image reference','authored Blender mesh','PBR/UV/rigged glTF','Godot contract validation','promotion'],
                  'concepts':{k:{'file':str(p.relative_to(ROOT)).replace('\\','/'),'sha256':digest(p)} for k,p in refs.items()},
                  'ocean':water, 'asset_ids':list(api.MANIFEST),
                  'tools':{p.name:digest(p) for p in (ROOT/'tools').glob('art_v3_*.py')}}
    (SOURCE/'provenance.json').write_text(json.dumps(provenance,indent=2)+'\n',encoding='utf-8')
    refresh_library_records()
    print('BUILD_COMPLETE v3 '+str(len(names))+' assets; Blender sources and references saved',flush=True)


if __name__ == '__main__':
    main()
