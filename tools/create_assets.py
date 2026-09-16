"""Original MIHANG underwater kit. Run in Blender or through Blender MCP.

All assets use meters, origin at their base, and export to Godot's Y-up GLB.
No external assets, textures, or Python dependencies are required.
"""
import bpy
import json
import math
import random
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parent.parent
MODELS = ROOT / 'assets/models'
SOURCE = ROOT / 'assets/source'
MODELS.mkdir(parents=True, exist_ok=True)
SOURCE.mkdir(parents=True, exist_ok=True)
(SOURCE / '.gdignore').touch()
random.seed(913)

# A new scene preserves every object in the user's original Blender scene.
scene = bpy.data.scenes.new('MIHANG • Original underwater kit')
bpy.context.window.scene = scene
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1.0
parts = []
assets = []
manifest = {}


def material(name, rgb, roughness=0.65, metallic=0.0, emission=0.0):
    mat = bpy.data.materials.new('MIHANG_' + name)
    mat.diffuse_color = (*rgb, 1)
    mat.use_nodes = True
    mat.use_backface_culling = False
    bsdf = next(node for node in mat.node_tree.nodes if node.type == 'BSDF_PRINCIPLED')
    bsdf.inputs['Base Color'].default_value = (*rgb, 1)
    bsdf.inputs['Roughness'].default_value = roughness
    bsdf.inputs['Metallic'].default_value = metallic
    if emission:
        bsdf.inputs['Emission Color'].default_value = (*rgb, 1)
        bsdf.inputs['Emission Strength'].default_value = emission
    return mat


peach = material('Coral peach', (0.96, 0.34, 0.24))
pink = material('Coral light tips', (1.0, 0.62, 0.48), emission=0.16)
purple = material('Tube violet', (0.40, 0.16, 0.57))
violet = material('Tube lilac', (0.66, 0.31, 0.72))
cyan = material('Bioluminescent cyan', (0.17, 0.94, 0.91), emission=1.2)
dark = material('Deep teal', (0.023, 0.10, 0.14))
green = material('Kelp jade', (0.10, 0.40, 0.22))
lime = material('Kelp young leaves', (0.41, 0.69, 0.20))
glowgreen = material('Kelp sample', (0.63, 1.0, 0.25), emission=1.4)
stone = material('Limestone blue', (0.29, 0.40, 0.43))
stone2 = material('Limestone pale', (0.46, 0.57, 0.55))
sand = material('Sand gold', (0.61, 0.56, 0.38))
teal = material('Fish turquoise', (0.07, 0.60, 0.62), roughness=0.34)
orange = material('Safety orange', (1.0, 0.30, 0.065), roughness=0.4)
white = material('Ceramic ivory', (0.86, 0.92, 0.86), roughness=0.3, metallic=0.15)
silver = material('Titanium', (0.62, 0.73, 0.75), roughness=0.34, metallic=0.75)
copper = material('Copper', (0.79, 0.33, 0.12), roughness=0.4, metallic=0.65)
black = material('Eye obsidian', (0.005, 0.02, 0.025), roughness=0.18)
rust = material('Rust iron', (0.42, 0.20, 0.12), roughness=0.88, metallic=0.3)
sub_gray = material('Submarine hull', (0.18, 0.24, 0.28), roughness=0.55, metallic=0.7)
sub_dark = material('Submarine chassis', (0.08, 0.11, 0.13), roughness=0.7, metallic=0.8)
sub_trim = material('Submarine warning orange', (0.95, 0.38, 0.08), roughness=0.45)
sub_glass = material('Reinforced observation glass', (0.15, 0.55, 0.65), roughness=0.15, emission=0.6)
anemone_flesh = material('Anemone flesh', (0.88, 0.42, 0.38), roughness=0.6)
anemone_glow = material('Anemone bioluminescent tip', (0.22, 0.96, 0.85), roughness=0.3, emission=1.6)
anemone_center = material('Anemone oral disc', (0.65, 0.18, 0.35), roughness=0.7)
crystal_rock = material('Basalt crust', (0.10, 0.12, 0.14), roughness=0.92)
crystal_cyan = material('Abyssal quartz crystal', (0.12, 0.88, 0.95), roughness=0.18, metallic=0.2, emission=1.8)
crystal_violet = material('Abyssal fluorite crystal', (0.55, 0.22, 0.88), roughness=0.2, metallic=0.1, emission=1.5)
jelly_bell = material('Jellyfish translucent bell', (0.28, 0.82, 0.88), roughness=0.25, emission=0.35)
jelly_core = material('Jellyfish luminescent core', (0.20, 0.98, 0.95), roughness=0.15, emission=2.4)
jelly_violet = material('Jellyfish tentacle rim', (0.62, 0.28, 0.85), roughness=0.3, emission=0.9)


def finish(obj, name, mat, smooth=False):
    obj.name = name
    obj.data.materials.append(mat)
    if smooth:
        for polygon in obj.data.polygons:
            polygon.use_smooth = True
    parts.append(obj)
    return obj


def ico(name, location, scale, mat, subdivisions=1, smooth=False):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=1, location=location)
    obj = bpy.context.object
    obj.scale = scale
    return finish(obj, name, mat, smooth)


def sphere(name, location, scale, mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=1, location=location)
    obj = bpy.context.object
    obj.scale = scale
    return finish(obj, name, mat, True)


def box(name, location, scale, mat, bevel=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.object
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = obj.modifiers.new('Soft manufactured edges', 'BEVEL')
        mod.width = bevel
        mod.segments = 2
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(obj, name, mat)


def branch(name, start, end, radius_start, radius_end, mat, vertices=8):
    direction = Vector(end) - Vector(start)
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius_start, radius2=radius_end,
                                    depth=direction.length, location=(Vector(start) + Vector(end)) / 2)
    obj = bpy.context.object
    obj.rotation_euler = direction.to_track_quat('Z', 'Y').to_euler()
    return finish(obj, name, mat, True)


def torus(name, location, major, minor, mat, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_segments=24, minor_segments=6,
                                   major_radius=major, minor_radius=minor, location=location,
                                   rotation=rotation)
    return finish(bpy.context.object, name, mat, True)


def mesh(name, vertices, faces, mat, smooth=False):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    scene.collection.objects.link(obj)
    return finish(obj, name, mat, smooth)


def export_asset(name, center=False):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in parts:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.convert(target='MESH')
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    scene.cursor.location = (0, 0, 0)
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    minimum_z = min((obj.matrix_world @ vertex.co).z for vertex in obj.data.vertices)
    if not center:
        for vertex in obj.data.vertices:
            vertex.co.z -= minimum_z
    bpy.context.view_layer.update()
    obj.data.calc_loop_triangles()
    manifest[name] = {'file': 'assets/models/' + name + '.glb',
                      'dimensions_blender_xyz': [round(x, 3) for x in obj.dimensions],
                      'dimensions_godot_xyz': [round(obj.dimensions.x, 3), round(obj.dimensions.z, 3), round(obj.dimensions.y, 3)],
                      'triangles': len(obj.data.loop_triangles)}
    bpy.ops.export_scene.gltf(filepath=str(MODELS / (name + '.glb')), export_format='GLB',
                              use_selection=True, export_yup=True, export_apply=True,
                              export_animations=False, export_cameras=False, export_lights=False)
    assets.append(obj)
    parts.clear()
    return obj


def create_coral():
    ico('Coral holdfast', (0, 0, 0.12), (0.45, 0.35, 0.20), peach, 2)
    for index, angle in enumerate([0.0, 1.05, 2.3, 3.5, 4.7, 5.6]):
        height = 1.4 + (index % 3) * 0.34
        base = Vector((0, 0, 0.18))
        elbow = Vector((0.35 * math.cos(angle), 0.35 * math.sin(angle), height * 0.55))
        top = Vector((0.76 * math.cos(angle), 0.76 * math.sin(angle), height))
        branch('Coral stem', base, elbow, 0.12, 0.095, peach)
        branch('Coral upward branch', elbow, top, 0.095, 0.05, peach)
        ico('Coral bud', top, (0.066, 0.066, 0.09), pink, 2, True)
        for sign in [-1, 1]:
            start = elbow.lerp(top, 0.45)
            end = start + Vector((0.45 * math.cos(angle + sign * 0.7), 0.45 * math.sin(angle + sign * 0.7), 0.35))
            branch('Coral fork', start, end, 0.07, 0.027, peach)
            ico('Coral luminous bud', end, (0.05, 0.05, 0.075), pink, 2, True)
    export_asset('coral')


def create_tube_coral():
    ico('Violet colony holdfast', (0, 0, 0.08), (0.70, 0.60, 0.20), purple, 2)
    for index, (x, y, h, radius) in enumerate([(-.4, .1, 1.6, .19), (.1, .25, 2.1, .23), (.45, -.1, 1.35, .19), (-.15, -.38, 1.05, .22), (.48, .35, 1.1, .16)]):
        verts, faces = [], []
        rings = [(radius, .03), (radius * .80, h*.42), (radius*.84, h*.8), (radius*1.13, h), (radius*.75, h), (radius*.57, h-.23)]
        for r, z in rings:
            for k in range(12):
                a = k * math.tau/12
                bend = 0.16 * (z/h)**2
                verts.append((x + r*math.cos(a) + bend, y + r*math.sin(a), z))
        for ring in range(5):
            for k in range(12):
                faces.append((ring*12+k, ring*12+(k+1)%12, (ring+1)*12+(k+1)%12, (ring+1)*12+k))
        obj = mesh('Sponge tube', verts, faces, purple if index%2 else violet, True)
        obj.data.materials.append(cyan)
        obj.data.materials.append(dark)
        for polygon in obj.data.polygons:
            if 36 <= polygon.index < 48:
                polygon.material_index = 1
            elif polygon.index >= 48:
                polygon.material_index = 2
    export_asset('tube_coral')


def leaf(start, angle, length, width, mat):
    verts, faces = [], []
    for step in range(9):
        t = step / 8
        reach = length * math.sin(t * 1.28)
        center = Vector(start) + Vector((math.cos(angle)*reach, math.sin(angle)*reach, length*(.5*t - .3*t*t)))
        w = width * math.sin(math.pi*t)**0.75
        side = Vector((-math.sin(angle)*w, math.cos(angle)*w, .045 * math.sin(t*math.tau*2)))
        verts.extend([center-side, center+side])
        if step:
            n = step*2
            faces.append((n-2, n-1, n+1, n))
    return mesh('Undulating kelp blade', verts, faces, mat, True)


def create_kelp():
    ico('Kelp root', (0, 0, .1), (.30, .30, .17), green, 2)
    for stem_id in range(3):
        angle = stem_id * 2.2
        h = 4.5 - stem_id*.55
        last = Vector((0, 0, .1))
        for step in range(1, 10):
            t = step/9
            point = Vector((.4*math.sin(t*3+angle)*t, .45*math.cos(t*2+angle)*t, h*t))
            branch('Flexible kelp stipe', last, point, .037, .03, green, 6)
            if step > 1:
                leaf(point, angle + step*2.3, 1.0*(1-.35*t), .18, lime if step%3==0 else green)
            last = point
        ico('Kelp air bladder', last, (.085, .075, .15), lime, 2, True)
    export_asset('kelp')


def create_rock():
    for location, scale in [((0, 0, .55), (1.5, 1.12, .9)), ((.65, .25, .40), (.80, .80, .65)), ((-.65, -.4, .2), (.70, .58, .4))]:
        obj = ico('Weathered reef limestone', location, scale, stone, 2)
        obj.data.materials.append(stone2)
        obj.data.materials.append(sand)
        for vertex in obj.data.vertices:
            vertex.co *= random.uniform(.91, 1.1)
        for polygon in obj.data.polygons:
            polygon.material_index = random.choices([0,1,2], [8,2,1])[0]
    export_asset('rock')


def create_fish():
    ico('Streamlined fish body', (0, 0, 0), (.12, .29, .17), teal, 3, True)
    ico('Bright fish forehead', (0, -.16, .045), (.10, .13, .12), orange, 2, True)
    mesh('Forked tail', [(-.025,.22,0), (0,.46,.20), (0,.40,0), (0,.46,-.20), (.025,.22,0)], [(0,1,2,4), (0,2,3,4)], orange)
    mesh('Dorsal fin', [(0,-.10,.12), (0,.18,.14), (0,.13,.29)], [(0,1,2)], orange)
    for side in [-1, 1]:
        ico('Eye white', (side*.091, -.19, .075), (.04,.043,.044), white, 2, True)
        ico('Eye pupil', (side*.119, -.199, .078), (.02,.025,.028), black, 2, True)
        mesh('Pectoral fin', [(side*.1,-.015,-.01), (side*.28,.11,-.02), (side*.08,.14,-.07)], [(0,1,2)], orange)
    export_asset('fish', center=True)


def create_fish_small():
    # Compact, plump, adorable small fish (length ~0.42m)
    # Bright shimmering gold and turquoise
    gold = material('Small fish gold', (1.0, 0.78, 0.22), roughness=0.32, metallic=0.1)
    belly = material('Small fish belly', (0.96, 0.98, 0.95), roughness=0.25)
    fin_cyan = material('Small fish fin glow', (0.22, 0.95, 0.92), roughness=0.3, emission=0.8)

    ico('Small fish body', (0, 0, 0), (0.11, 0.21, 0.14), gold, 3, True)
    ico('Small fish belly', (0, -0.02, -0.04), (0.095, 0.17, 0.08), belly, 2, True)

    mesh('Small fish tail', [
        (-0.015, 0.16, 0),
        (0, 0.35, 0.14),
        (0, 0.29, 0),
        (0, 0.35, -0.14),
        (0.015, 0.16, 0)
    ], [(0, 1, 2, 4), (0, 2, 3, 4)], fin_cyan)

    mesh('Small fish dorsal', [(0, -0.06, 0.10), (0, 0.12, 0.11), (0, 0.08, 0.23)], [(0, 1, 2)], fin_cyan)

    for side in [-1, 1]:
        ico('Small fish eye white', (side * 0.082, -0.12, 0.045), (0.038, 0.038, 0.038), white, 2, True)
        ico('Small fish eye pupil', (side * 0.108, -0.128, 0.048), (0.02, 0.024, 0.024), black, 2, True)
        ico('Small fish eye shine', (side * 0.118, -0.138, 0.058), (0.008, 0.008, 0.008), white, 1, True)
        mesh('Small fish pectoral', [(side * 0.08, -0.01, -0.02), (side * 0.22, 0.09, -0.01), (side * 0.07, 0.11, -0.06)], [(0, 1, 2)], fin_cyan)

    export_asset('fish_small', center=True)


def create_fish_predator():
    # Large aggressive predator shark (~2.9m long)
    shark_dark = material('Predator shark dark', (0.09, 0.13, 0.18), roughness=0.42)
    shark_pale = material('Predator shark pale', (0.78, 0.84, 0.88), roughness=0.35)
    shark_eye = material('Predator shark eye', (1.0, 0.85, 0.1), emission=2.2)
    shark_tooth = material('Predator shark tooth', (0.95, 0.95, 0.90), roughness=0.25, metallic=0.1)

    # Torso: Hydrodynamic elongated body
    ico('Predator torso', (0, 0, 0), (0.38, 1.45, 0.48), shark_dark, 3, True)
    ico('Predator belly', (0, -0.05, -0.15), (0.34, 1.25, 0.28), shark_pale, 2, True)
    ico('Predator snout', (0, -1.2, 0.05), (0.28, 0.55, 0.24), shark_dark, 2, True)

    # Gaping lower jaw
    box('Predator jaw', (0, -0.95, -0.22), (0.28, 0.55, 0.12), shark_pale, 0.03)

    # Sharp teeth along jaw
    for i in range(7):
        ang = (i - 3) * 0.22
        tx = math.sin(ang) * 0.16
        ty = -1.15 + abs(math.sin(ang)) * 0.22
        branch(f'Upper tooth {i}', (tx, ty, -0.08), (tx, ty, -0.17), 0.022, 0.002, shark_tooth, 4)
        branch(f'Lower tooth {i}', (tx * 0.88, ty + 0.06, -0.24), (tx * 0.88, ty + 0.06, -0.16), 0.02, 0.002, shark_tooth, 4)

    # Prominent towering dorsal fin
    mesh('Predator dorsal fin', [
        (0, -0.2, 0.35),
        (0, 0.55, 0.32),
        (0, 0.32, 1.05)
    ], [(0, 1, 2)], shark_dark)

    # Second smaller dorsal fin
    mesh('Predator small dorsal', [(0, 0.85, 0.18), (0, 1.25, 0.16), (0, 1.15, 0.42)], [(0, 1, 2)], shark_dark)

    # Large crescent shark tail
    mesh('Predator tail upper lobe', [
        (-0.03, 1.25, 0),
        (0, 2.15, 0.85),
        (0, 1.85, 0.15),
        (0.03, 1.25, 0)
    ], [(0, 1, 2, 3)], shark_dark)
    mesh('Predator tail lower lobe', [
        (-0.03, 1.25, 0),
        (0, 1.85, 0.15),
        (0, 1.95, -0.55),
        (0.03, 1.25, 0)
    ], [(0, 1, 2, 3)], shark_dark)

    # Large pectoral fins & glowing eyes
    for side in [-1, 1]:
        ico('Predator eye', (side * 0.26, -1.05, 0.14), (0.045, 0.055, 0.045), shark_eye, 2, True)
        ico('Predator pupil', (side * 0.29, -1.08, 0.14), (0.022, 0.035, 0.04), black, 1, True)
        mesh('Predator pectoral', [
            (side * 0.32, -0.15, -0.12),
            (side * 1.15, 0.45, -0.32),
            (side * 0.26, 0.55, -0.15)
        ], [(0, 1, 2)], shark_dark)
        mesh('Predator pelvic', [
            (side * 0.18, 0.82, -0.15),
            (side * 0.48, 1.15, -0.28),
            (side * 0.15, 1.15, -0.14)
        ], [(0, 1, 2)], shark_dark)

    export_asset('fish_predator', center=True)


def create_fish_abyss():
    # Abyssal deep-sea fang predator with glowing lure (length ~2.3m)
    abyss_skin = material('Abyss fangfish skin', (0.035, 0.045, 0.065), roughness=0.8)
    abyss_lure_mat = material('Abyss lure glow', (0.2, 0.98, 0.92), roughness=0.2, emission=3.6)
    fang_mat = material('Abyss fangs', (0.85, 0.90, 0.95), roughness=0.15, metallic=0.3)
    ridge_mat = material('Abyss spiny ridge', (0.12, 0.18, 0.22), roughness=0.5)

    ico('Abyss monster head', (0, -0.4, 0.0), (0.46, 0.65, 0.55), abyss_skin, 2, True)
    ico('Abyss monster body', (0, 0.45, -0.05), (0.34, 0.75, 0.38), abyss_skin, 2, True)
    ico('Abyss lower jaw', (0, -0.55, -0.35), (0.42, 0.6, 0.28), abyss_skin, 2, True)

    fangs_data = [
        (-0.32, -0.75, -0.38, -0.34, -0.75, -0.08),
        (0.32, -0.75, -0.38, 0.34, -0.75, -0.08),
        (-0.18, -0.92, -0.38, -0.16, -0.92, -0.12),
        (0.18, -0.92, -0.38, 0.16, -0.92, -0.12),
        (0.0, -0.98, -0.38, 0.0, -0.98, -0.15),
        (-0.25, -0.55, -0.1, -0.26, -0.55, -0.32),
        (0.25, -0.55, -0.1, 0.26, -0.55, -0.32),
    ]
    for idx, (x0, y0, z0, x1, y1, z1) in enumerate(fangs_data):
        branch(f'Abyss fang {idx}', (x0, y0, z0), (x1, y1, z1), 0.026, 0.003, fang_mat, 4)

    # Long arching bioluminescent antenna (illicium) with glowing esca bulb
    p_last = Vector((0, -0.5, 0.52))
    for step in range(1, 7):
        t = step / 6.0
        p_next = Vector((
            0,
            -0.5 - math.sin(t * 2.2) * 0.45 - t * 0.35,
            0.52 + math.sin(t * math.pi) * 0.55 - t * 0.25
        ))
        branch(f'Illicium rod {step}', p_last, p_next, 0.03 * (1.0 - t*0.5), 0.03 * (1.0 - (t+0.16)*0.5), ridge_mat, 6)
        p_last = p_next
    ico('Abyss glowing esca', p_last, (0.095, 0.095, 0.11), abyss_lure_mat, 2, True)
    torus('Esca glow ring', p_last, 0.09, 0.02, cyan)

    for i in range(5):
        y = -0.1 + i * 0.22
        h = 0.35 + math.sin(i * 0.7) * 0.2
        branch(f'Dorsal spine {i}', (0, y, 0.32), (0, y + 0.12, 0.32 + h), 0.035, 0.005, ridge_mat, 4)
        ico(f'Dorsal spine light {i}', (0, y + 0.12, 0.32 + h), (0.025, 0.025, 0.03), cyan, 1, True)

    mesh('Abyss tail', [
        (-0.02, 1.05, -0.05),
        (0, 1.65, 0.42),
        (0, 1.45, -0.05),
        (0, 1.65, -0.45),
        (0.02, 1.05, -0.05)
    ], [(0, 1, 2, 4), (0, 2, 3, 4)], ridge_mat)

    for side in [-1, 1]:
        ico('Abyss eye white', (side * 0.36, -0.65, 0.18), (0.045, 0.045, 0.045), white, 2, True)
        ico('Abyss eye pupil', (side * 0.39, -0.68, 0.18), (0.02, 0.025, 0.025), black, 1, True)
        for p_idx in range(6):
            py = -0.3 + p_idx * 0.22
            ico(f'Photophore {side}_{p_idx}', (side * 0.32, py, 0.02), (0.018, 0.018, 0.02), cyan, 1, True)

    export_asset('fish_abyss', center=True)


def create_weapon_knife():
    # Tactical dive knife (length ~0.35m)
    blade_mat = material('Knife titanium blade', (0.72, 0.82, 0.88), roughness=0.22, metallic=0.9)
    edge_mat = material('Knife polished edge', (0.92, 0.96, 1.0), roughness=0.12, metallic=0.98)
    grip_mat = material('Knife rubber grip', (0.07, 0.09, 0.11), roughness=0.82)
    guard_mat = material('Knife titanium guard', (0.28, 0.34, 0.38), roughness=0.4, metallic=0.85)
    glow_mat = material('Knife cyan power ring', (0.18, 0.95, 0.92), roughness=0.2, emission=1.8)

    box('Knife grip', (0, -0.08, 0), (0.038, 0.13, 0.026), grip_mat, 0.006)
    for i in range(4):
        box(f'Knife grip rib {i}', (0, -0.12 + i * 0.03, 0.013), (0.04, 0.016, 0.006), dark, 0.002)

    box('Knife pommel', (0, -0.16, 0), (0.042, 0.028, 0.03), guard_mat, 0.005)
    torus('Knife lanyard ring', (0, -0.18, 0), 0.014, 0.0035, guard_mat)

    box('Knife guard', (0, 0.0, 0), (0.065, 0.018, 0.032), guard_mat, 0.004)
    torus('Knife power ring', (0, 0.01, 0), 0.022, 0.003, glow_mat)

    box('Knife blade spine', (0, 0.10, 0), (0.032, 0.18, 0.009), blade_mat, 0.002)
    mesh('Knife primary edge', [
        (-0.016, 0.01, -0.004),
        (-0.028, 0.15, -0.001),
        (0.0, 0.21, 0.0),
        (-0.016, 0.01, 0.004),
        (-0.028, 0.15, 0.001)
    ], [(0, 1, 2), (3, 4, 2), (0, 3, 4, 1)], edge_mat)
    for s in range(5):
        box(f'Knife serration {s}', (0.018, 0.03 + s * 0.025, 0), (0.008, 0.014, 0.006), edge_mat)
    mesh('Knife tip', [
        (-0.016, 0.18, -0.004),
        (0.016, 0.18, -0.004),
        (0.0, 0.22, 0.0),
        (-0.016, 0.18, 0.004),
        (0.016, 0.18, 0.004)
    ], [(0, 1, 2), (3, 4, 2), (0, 3, 4, 1)], edge_mat)

    export_asset('weapon_knife', center=True)


def create_weapon_axe():
    # Tactical breaching dive axe (length ~0.55m)
    shaft_mat = material('Axe composite shaft', (0.08, 0.10, 0.12), roughness=0.75)
    head_mat = material('Axe titanium head', (0.24, 0.28, 0.32), roughness=0.35, metallic=0.85)
    edge_mat = material('Axe razor edge', (0.90, 0.95, 1.0), roughness=0.15, metallic=0.95)
    glow_mat = material('Axe thermal glow', (1.0, 0.45, 0.12), roughness=0.2, emission=2.2)

    branch('Axe shaft', (0, -0.22, 0), (0, 0.22, 0), 0.022, 0.025, shaft_mat, 8)
    branch('Axe lower grip', (0, -0.24, 0), (0, -0.02, 0), 0.027, 0.025, dark, 8)
    for g in range(5):
        torus(f'Axe grip rib {g}', (0, -0.22 + g * 0.04, 0), 0.027, 0.003, dark)
    box('Axe pommel', (0, -0.25, 0), (0.045, 0.025, 0.045), head_mat, 0.005)
    torus('Axe lanyard ring', (0, -0.27, 0), 0.016, 0.004, head_mat)

    box('Axe head collar', (0, 0.18, 0), (0.055, 0.09, 0.055), head_mat, 0.006)
    torus('Axe energy ring', (0, 0.18, 0), 0.038, 0.006, glow_mat)

    box('Axe front blade core', (-0.07, 0.18, 0), (0.09, 0.14, 0.024), head_mat, 0.004)
    mesh('Axe curved cutting beard', [
        (-0.08, 0.11, -0.012),
        (-0.16, 0.07, 0.0),
        (-0.17, 0.25, 0.0),
        (-0.08, 0.24, -0.012),
        (-0.08, 0.11, 0.012),
        (-0.08, 0.24, 0.012)
    ], [(0, 1, 2, 3), (4, 1, 2, 5)], edge_mat)

    mesh('Axe rear pick', [
        (0.03, 0.15, -0.016),
        (0.12, 0.18, -0.002),
        (0.03, 0.21, -0.016),
        (0.03, 0.15, 0.016),
        (0.12, 0.18, 0.002),
        (0.03, 0.21, 0.016)
    ], [(0, 1, 2), (3, 4, 5), (0, 3, 4, 1), (1, 4, 5, 2)], head_mat)

    export_asset('weapon_axe', center=True)


def create_weapon_sonic():
    # Advanced sonic pulse rifle (length ~0.72m)
    body_mat = material('Sonic rifle chassis', (0.12, 0.16, 0.20), roughness=0.35, metallic=0.75)
    trim_mat = material('Sonic alloy trim', (0.55, 0.65, 0.70), roughness=0.25, metallic=0.85)
    core_mat = material('Sonic plasma core', (0.16, 0.96, 0.92), roughness=0.1, emission=2.8)
    emitter_mat = material('Sonic acoustic emitter', (0.75, 0.85, 0.90), roughness=0.2, metallic=0.92)

    box('Sonic receiver', (0, -0.05, 0.02), (0.08, 0.32, 0.11), body_mat, 0.01)
    branch('Sonic grip', (0, -0.15, 0.0), (0, -0.22, -0.14), 0.028, 0.024, dark, 8)
    box('Sonic trigger guard', (0, -0.12, -0.06), (0.015, 0.06, 0.05), trim_mat, 0.004)
    box('Sonic trigger', (0, -0.11, -0.05), (0.008, 0.018, 0.025), cyan, 0.002)

    branch('Sonic battery cell', (0, -0.22, 0.02), (0, -0.34, 0.02), 0.038, 0.035, body_mat, 12)
    torus('Sonic battery ring', (0, -0.28, 0.02), 0.041, 0.005, core_mat)

    branch('Sonic chamber casing', (0, 0.08, 0.02), (0, 0.26, 0.02), 0.048, 0.048, trim_mat, 16)
    branch('Sonic resonance core', (0, 0.09, 0.02), (0, 0.25, 0.02), 0.036, 0.036, core_mat, 12)

    for r in range(3):
        y_pos = 0.26 + r * 0.08
        radius = 0.045 + r * 0.018
        torus(f'Sonic emitter ring {r}', (0, y_pos, 0.02), radius, 0.008, emitter_mat, (math.pi/2, 0, 0))
        torus(f'Sonic inner glow ring {r}', (0, y_pos, 0.02), radius * 0.88, 0.003, core_mat, (math.pi/2, 0, 0))

    branch('Sonic muzzle cone', (0, 0.40, 0.02), (0, 0.46, 0.02), 0.055, 0.085, emitter_mat, 16)
    ico('Sonic emitter focus lens', (0, 0.42, 0.02), (0.035, 0.035, 0.035), core_mat, 2, True)

    box('Sonic sight rail', (0, -0.02, 0.09), (0.032, 0.22, 0.022), trim_mat, 0.004)
    box('Sonic holo emitter', (0, 0.02, 0.12), (0.04, 0.04, 0.04), body_mat, 0.004)
    torus('Sonic reticle ring', (0, 0.02, 0.15), 0.022, 0.003, core_mat, (math.pi/2, 0, 0))

    export_asset('weapon_sonic', center=True)


def create_pod():
    sphere('Porcelain pressure hull', (0, 0, 1.72), (2.35, 2.0, 1.43), white)
    torus('Orange flotation collar', (0, 0, .94), 2.12, .23, orange).scale.y = .87
    torus('Lower dark seam', (0, 0, .79), 1.97, .055, dark).scale.y = .87
    sphere('Top orange cap', (0, 0, 2.98), (.83, .78, .21), orange)
    branch('Antenna mast', (.35, .20, 3.04), (.35, .20, 4.12), .047, .035, silver)
    ico('Antenna cyan beacon', (.35,.20,4.13), (.095,.095,.11), cyan, 2, True)
    branch('Antenna crossbar', (-.08,.20,3.78), (.78,.20,3.78), .027, .027, dark)
    for side in [-1, 1]:
        for fore in [-1, 1]:
            branch('Landing strut', (side*1.4,fore*1.2,.95), (side*1.9,fore*1.6,.22), .11, .15, dark)
            box('Landing shoe', (side*1.9,fore*1.6,.13), (.65,.57,.21), white,.07)
    # The round front hatch and glass are opaque: easy to read underwater.
    branch('Hatch outer cylinder', (0,-1.72,1.49), (0,-2.06,1.49), .79, .79, dark, 32)
    torus('Hatch orange rim', (0,-2.085,1.49), .76, .075, orange, (math.pi/2,0,0))
    branch('Hatch ceramic plate', (0,-2.08,1.49), (0,-2.13,1.49), .64, .64, white, 32)
    branch('Front observation window', (0,-2.132,1.74), (0,-2.16,1.74), .37, .37, dark, 32)
    torus('Front window cyan rim', (0,-2.18,1.74), .37, .021, cyan, (math.pi/2,0,0))
    box('Hatch grip', (.37,-2.18,1.20), (.12,.09,.30), orange,.025)
    for side in [-1,1]:
        sphere('Side observation window', (side*2.04,-.13,2.08), (.15,.68,.46), dark)
        sphere('Side illuminated trim', (side*2.025,-.13,2.07), (.145,.72,.49), cyan)
        box('Hull orange vertical trim', (side*1.4,-1.4,2.32), (.21,.16,.67), orange,.04).rotation_euler.y = side * .20
    for step in range(3):
        box('Boarding step', (0,-2.05-step*.30,.75-step*.18), (1.1,.40,.10), dark,.035)
    box('Roof solar panel', (-.73,.20,3.04), (.75,1.02,.09), dark,.06)
    for y in [-.10,.20,.50]:
        box('Solar cell stripe', (-.73,y,3.095), (.65,.025,.014), cyan)
    export_asset('pod')


def create_ruins():
    for side in [-1,1]:
        for row in range(3):
            obj = box('Ancient pillar block', (side*3.15,0,.48+row*.86), (1.16,1.38,.82), stone2,.11)
            obj.rotation_euler.z = random.uniform(-.025,.025)
        box('Ancient pillar plinth', (side*3.15,0,.16), (1.6,1.8,.32), stone,.07)
        for z in [.9,1.32,1.74,2.16]:
            box('Bioluminescent glyph', (side*3.15,-.706,z), (.12,.025,.25), cyan,.02)
        for k in range(3):
            ico('Pillar algae', (side*3.1+random.uniform(-.55,.55),random.uniform(-.6,.6),.28), (.40,.40,.22), green, 1)
    count = 11
    for index in range(count):
        a0 = index*math.pi/count + .018
        a1 = (index+1)*math.pi/count - .018
        vertices = []
        for y in [-.64,.64]:
            for radius, angle in [(2.61,a0),(3.69,a0),(3.69,a1),(2.61,a1)]:
                vertices.append((radius*math.cos(angle), y, 2.55+radius*math.sin(angle)))
        mesh('Arch voussoir', vertices, [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)], stone2 if index%3 else stone)
    ico('Keystone luminous heart', (0,-.68,5.7), (.22,.06,.34), cyan, 1)
    for side in [-1,1]:
        box('Fallen foundation', (side*3.72,-.28,.15), (.85,1.2,.28), stone,.07)
    export_asset('ruins')


def create_shipwreck():
    hull_len = 7.2
    hull_rad = 1.65
    branch('Wreck forward hull', (0, -hull_len*0.5, 1.8), (0, hull_len*0.4, 1.8), hull_rad, hull_rad, sub_gray, 24)
    sphere('Wreck bow dome', (0, hull_len*0.4, 1.8), (hull_rad, hull_rad*1.2, hull_rad), sub_gray)
    sphere('Bow observation port', (0, hull_len*0.4 + 1.1, 1.8), (hull_rad*0.55, hull_rad*0.55, hull_rad*0.55), sub_glass)
    torus('Bow port ring', (0, hull_len*0.4 + 1.05, 1.8), hull_rad*0.56, 0.09, sub_dark, (math.pi/2, 0, 0))
    box('Conning tower sail', (0, 0.2, 3.8), (0.9, 2.6, 1.4), sub_gray, 0.12)
    branch('Sensor mast', (0, 0.6, 4.5), (0, 0.6, 6.2), 0.08, 0.05, sub_dark, 12)
    ico('Emergency beacon top', (0, 0.6, 6.25), (0.14, 0.14, 0.18), cyan, 2, True)
    torus('Bridge hatch rim', (0, -0.4, 4.55), 0.42, 0.07, sub_trim, (0, 0, 0))
    branch('Bridge hatch cover', (0, -0.4, 4.5), (0, -0.4, 4.6), 0.4, 0.4, sub_dark, 16)
    for y in [-2.6, -1.3, 0.0, 1.3, 2.4]:
        torus('Exoskeleton rib', (0, y, 1.8), hull_rad + 0.08, 0.07, sub_dark, (math.pi/2, 0, 0))
    for y in [-0.65, 0.85]:
        torus('Orange warning band', (0, y, 1.8), hull_rad + 0.03, 0.05, sub_trim, (math.pi/2, 0, 0))
    for z in [0.8, 1.4, 2.0, 2.6]:
        branch('Exposed bulkhead girder', (1.4, -2.0, z), (1.4, -0.5, z), 0.06, 0.06, rust, 6)
    box('Ruptured deck plating', (1.65, -1.2, 1.5), (0.2, 1.8, 1.2), rust, 0.04)
    for side in [-1, 1]:
        thruster_x = side * 1.55
        thruster_y = -hull_len * 0.5 - 0.9
        thruster_z = 1.8
        branch('Thruster strut', (side * 1.2, -hull_len * 0.45, 1.8), (thruster_x, thruster_y, thruster_z), 0.12, 0.12, sub_dark, 8)
        branch('Thruster duct', (thruster_x, thruster_y - 0.7, thruster_z), (thruster_x, thruster_y + 0.7, thruster_z), 0.65, 0.65, sub_gray, 20)
        torus('Thruster duct rim front', (thruster_x, thruster_y + 0.7, thruster_z), 0.65, 0.06, sub_trim, (math.pi/2, 0, 0))
        torus('Thruster duct rim rear', (thruster_x, thruster_y - 0.7, thruster_z), 0.65, 0.06, sub_dark, (math.pi/2, 0, 0))
        sphere('Propeller hub', (thruster_x, thruster_y, thruster_z), (0.18, 0.25, 0.18), sub_dark)
        for blade_angle in [0, 2.094, 4.189]:
            bx = thruster_x + math.cos(blade_angle) * 0.38
            bz = thruster_z + math.sin(blade_angle) * 0.38
            box('Propeller blade', (bx, thruster_y, bz), (0.28, 0.04, 0.16), rust, 0.02)
    for side in [-1, 1]:
        branch('Landing keel rail', (side * 1.2, -3.2, 0.2), (side * 1.2, 2.8, 0.2), 0.14, 0.14, rust, 8)
        for y in [-2.0, 0.2, 2.2]:
            branch('Keel riser', (side * 1.2, y, 0.2), (side * 1.3, y, 1.0), 0.11, 0.11, sub_dark, 8)
    export_asset('shipwreck')


def create_anemone():
    ico('Anemone pedal disc', (0, 0, 0.12), (0.75, 0.75, 0.22), anemone_flesh, 2, True)
    branch('Anemone column base', (0, 0, 0.18), (0, 0, 0.65), 0.62, 0.52, anemone_flesh, 16)
    branch('Anemone column upper', (0, 0, 0.65), (0, 0, 0.92), 0.52, 0.68, anemone_flesh, 16)
    ico('Anemone oral disc', (0, 0, 0.94), (0.64, 0.64, 0.14), anemone_center, 2, True)
    ico('Anemone mouth slit', (0, 0, 0.99), (0.18, 0.06, 0.08), anemone_glow, 1, True)
    num_inner = 10
    for i in range(num_inner):
        ang = i * (math.tau / num_inner) + 0.15
        rad_base = 0.42
        rad_tip = 0.78
        h_base = 0.95
        h_mid = 1.45 + (i % 3) * 0.15
        h_tip = 1.65 + (i % 2) * 0.2
        p0 = Vector((math.cos(ang) * rad_base, math.sin(ang) * rad_base, h_base))
        p1 = Vector((math.cos(ang + 0.2) * (rad_base + 0.2), math.sin(ang + 0.2) * (rad_base + 0.2), h_mid))
        p2 = Vector((math.cos(ang + 0.1) * rad_tip, math.sin(ang + 0.1) * rad_tip, h_tip))
        branch('Inner tentacle lower', p0, p1, 0.075, 0.05, anemone_flesh, 8)
        branch('Inner tentacle upper', p1, p2, 0.05, 0.025, anemone_flesh, 8)
        ico('Inner tentacle tip', p2, (0.045, 0.045, 0.06), anemone_glow, 2, True)
    num_outer = 14
    for i in range(num_outer):
        ang = i * (math.tau / num_outer)
        rad_base = 0.62
        rad_mid = 1.05 + (i % 3) * 0.1
        rad_tip = 1.35 + (i % 2) * 0.15
        h_base = 0.90
        h_mid = 1.22
        h_tip = 0.85 - (i % 3) * 0.12
        p0 = Vector((math.cos(ang) * rad_base, math.sin(ang) * rad_base, h_base))
        p1 = Vector((math.cos(ang + 0.15) * rad_mid, math.sin(ang + 0.15) * rad_mid, h_mid))
        p2 = Vector((math.cos(ang + 0.3) * rad_tip, math.sin(ang + 0.3) * rad_tip, h_tip))
        branch('Outer tentacle lower', p0, p1, 0.08, 0.055, anemone_flesh, 8)
        branch('Outer tentacle drooping', p1, p2, 0.055, 0.025, anemone_flesh, 8)
        ico('Outer tentacle tip', p2, (0.045, 0.045, 0.065), anemone_glow, 2, True)
    export_asset('anemone')


def create_crystal_spire():
    for loc, sc in [((0, 0, 0.35), (1.6, 1.4, 0.7)),
                    ((0.6, -0.4, 0.25), (1.1, 0.9, 0.5)),
                    ((-0.5, 0.5, 0.2), (0.9, 1.0, 0.45))]:
        obj = ico('Basalt mineral base', loc, sc, crystal_rock, 2)
        for v in obj.data.vertices:
            v.co *= random.uniform(0.9, 1.12)
    spires = [
        (0.0, 0.0, 0.3, 4.8, 0.36, 0.04, 0.02, crystal_cyan),
        (0.48, -0.35, 0.2, 3.4, 0.28, 0.14, -0.12, crystal_violet),
        (-0.52, -0.30, 0.2, 3.1, 0.26, -0.12, -0.15, crystal_cyan),
        (-0.35, 0.45, 0.2, 3.6, 0.29, -0.10, 0.16, crystal_violet),
        (0.42, 0.40, 0.2, 2.7, 0.24, 0.15, 0.11, crystal_cyan),
        (0.85, 0.10, 0.15, 1.8, 0.19, 0.25, 0.04, crystal_violet),
        (-0.75, 0.05, 0.15, 1.6, 0.18, -0.22, 0.03, crystal_cyan),
    ]
    for idx, (x, y, z0, h, r, tx, ty, mat) in enumerate(spires):
        p_base = Vector((x, y, z0))
        p_top = p_base + Vector((tx * h, ty * h, h * 0.84))
        p_tip = p_base + Vector((tx * (h + r*1.6), ty * (h + r*1.6), h))
        branch(f'Hex spire shaft {idx}', p_base, p_top, r, r*0.92, mat, 6)
        branch(f'Hex spire tip {idx}', p_top, p_tip, r*0.92, 0.0, mat, 6)
    export_asset('crystal_spire')


def create_jellyfish():
    sphere('Jellyfish outer bell', (0, 0, 1.6), (0.75, 0.75, 0.55), jelly_bell)
    ico('Jellyfish bioluminescent core', (0, 0, 1.55), (0.28, 0.28, 0.28), jelly_core, 2, True)
    torus('Jellyfish bell margin', (0, 0, 1.15), 0.72, 0.065, jelly_violet)
    for i in range(4):
        angle = i * (math.pi * 0.5) + 0.4
        p_last = Vector((math.cos(angle) * 0.18, math.sin(angle) * 0.18, 1.3))
        for step in range(1, 8):
            t = step / 7.0
            sway = math.sin(t * math.pi * 2.5 + i * 1.5) * 0.18
            p_next = Vector((
                math.cos(angle) * (0.18 + t * 0.22) + sway * math.cos(angle + math.pi*0.5),
                math.sin(angle) * (0.18 + t * 0.22) + sway * math.sin(angle + math.pi*0.5),
                1.3 - t * 1.7
            ))
            branch(f'Oral arm {i}_{step}', p_last, p_next, 0.05 * (1.0 - t*0.6), 0.05 * (1.0 - (t+0.14)*0.6), jelly_bell, 6)
            if step % 2 == 0:
                ico(f'Oral arm glow node {i}_{step}', p_next, (0.035, 0.035, 0.045), jelly_core, 1, True)
            p_last = p_next
    for i in range(8):
        angle = i * (math.pi * 0.25)
        p_last = Vector((math.cos(angle) * 0.70, math.sin(angle) * 0.70, 1.15))
        for step in range(1, 7):
            t = step / 6.0
            p_next = Vector((
                math.cos(angle) * (0.70 - t * 0.2) + math.sin(t * 3.0 + i) * 0.08,
                math.sin(angle) * (0.70 - t * 0.2) + math.cos(t * 3.0 + i) * 0.08,
                1.15 - t * 1.9
            ))
            branch(f'Outer tentacle {i}_{step}', p_last, p_next, 0.022 * (1.0 - t*0.5), 0.022 * (1.0 - (t+0.16)*0.5), jelly_violet, 4)
            p_last = p_next
        ico(f'Outer tentacle tip {i}', p_last, (0.025, 0.025, 0.035), jelly_core, 1, True)
    export_asset('jellyfish', center=True)


def create_resources():
    for name, ore_mat in [('titanium',silver),('copper',copper)]:
        ico('Ore host stone', (0,0,.16), (.34,.28,.23), stone, 1)
        for x,y,z,s in [(-.12,-.1,.27,.18),(.15,-.03,.28,.17),(.02,.12,.38,.16),(-.06,.06,.19,.2)]:
            obj = ico('Exposed ore nugget', (x,y,z), (s,s*.82,s*.92), ore_mat, 1)
            obj.rotation_euler = (.2,.15,random.random())
        export_asset('resource_' + name)
    ico('Crystal matrix', (0,0,.07), (.32,.24,.12), stone, 1)
    for x,y,height,radius in [(0,0,.69,.13),(-.19,.04,.4,.11),(.18,.04,.49,.1)]:
        branch('Quartz hexagonal body',(x,y,.05),(x,y,height-.13),radius,radius,cyan,6)
        branch('Quartz crystal point',(x,y,height-.13),(x,y,height),radius,0,cyan,6)
    export_asset('resource_quartz')
    branch('Sample stalk', (0,0,.02), (0,0,.51), .022,.013,green,6)
    leaf((0,0,.18), .5, .36, .085, glowgreen)
    leaf((0,0,.29), 3.5, .33, .075, lime)
    ico('Seed cluster', (0,0,.54), (.13,.1,.18), glowgreen,2,True)
    export_asset('resource_kelp')


def presentation():
    positions = [
        (-0.5, 0.5, 0),    # coral
        (-3.5, 0.5, 0),    # tube_coral
        (-6.5, 1.0, 0),    # kelp
        (-6.5, -2.5, 0),   # rock
        (-2.0, -2.5, 1.2), # fish
        (-1.0, 5.0, 0),    # pod
        (-6.0, 5.0, 0),    # ruins
        (5.5, 4.5, 0),     # shipwreck
        (2.5, 0.5, 0),     # anemone
        (6.0, 0.5, 0),     # crystal_spire
        (2.0, -2.5, 1.5),  # jellyfish
        (-3.0, -5.5, 0),   # resource_titanium
        (-1.0, -5.5, 0),   # resource_copper
        (1.0, -5.5, 0),    # resource_quartz
        (3.0, -5.5, 0),    # resource_kelp
        (-4.0, -2.5, 1.0), # fish_small
        (-2.5, 2.8, 2.0),  # fish_predator
        (2.5, 2.8, 2.0),   # fish_abyss
        (-2.0, -4.0, 0.4), # weapon_knife
        (0.0, -4.0, 0.4),  # weapon_axe
        (2.0, -4.0, 0.4),  # weapon_sonic
    ]
    for obj, position in zip(assets, positions):
        obj.location = position
    ground_mat = material('Presentation seabed', (.025,.095,.115), roughness=.88)
    box('Presentation floor', (0,0.5,-.14), (28,26,.22), ground_mat,.08)
    scene.world = bpy.data.worlds.new('MIHANG deep-water studio')
    scene.world.use_nodes = True
    background = next(node for node in scene.world.node_tree.nodes if node.type == 'BACKGROUND')
    background.inputs[0].default_value = (.035,.14,.19,1)
    background.inputs[1].default_value = .6
    for name, location, energy, color, size in [('Key',(0,-5,15),2600,(.65,.9,1),12),('Rim',(8,8,11),3200,(.1,.8,.9),10),('Warm',(-10,-1,9),2000,(1,.65,.4),9)]:
        light = bpy.data.lights.new(name,'AREA')
        light.energy, light.color, light.shape, light.size = energy,color,'DISK',size
        obj = bpy.data.objects.new(name,light)
        scene.collection.objects.link(obj)
        obj.location = location
        obj.rotation_euler = (Vector((0,0.8,1.8))-obj.location).to_track_quat('-Z','Y').to_euler()
    camera_data = bpy.data.cameras.new('MIHANG kit camera')
    camera = bpy.data.objects.new('MIHANG kit camera', camera_data)
    scene.collection.objects.link(camera)
    camera.location = (18,-25,18)
    camera.rotation_euler = (Vector((0,.8,1.7))-camera.location).to_track_quat('-Z','Y').to_euler()
    camera_data.type = 'ORTHO'
    camera_data.ortho_scale = 26
    scene.camera = camera
    scene.render.engine = 'BLENDER_EEVEE'
    scene.render.resolution_x = 1440
    scene.render.resolution_y = 1080
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.render.filepath = str(SOURCE/'asset-kit.png')
    scene.view_settings.view_transform = 'AgX'
    for area in bpy.context.screen.areas:
        if area.type == 'VIEW_3D':
            area.spaces.active.region_3d.view_perspective = 'CAMERA'
            area.spaces.active.shading.type = 'MATERIAL'
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'mihang-underwater-kit.blend'))
    (SOURCE/'asset-manifest.json').write_text(json.dumps(manifest,indent=2))
    assert len(manifest)==21 and all((MODELS/(name+'.glb')).stat().st_size > 1000 for name in manifest)
    print(json.dumps(manifest,indent=2))


if __name__ == '__main__':
    create_coral()
    create_tube_coral()
    create_kelp()
    create_rock()
    create_fish()
    create_pod()
    create_ruins()
    create_shipwreck()
    create_anemone()
    create_crystal_spire()
    create_jellyfish()
    create_resources()
    create_fish_small()
    create_fish_predator()
    create_fish_abyss()
    create_weapon_knife()
    create_weapon_axe()
    create_weapon_sonic()
    presentation()
    bpy.ops.render.render(write_still=True)
