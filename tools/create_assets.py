"""Rebuild the alien-ocean kit from the imagegen reference boards in Blender.

rtk proxy /Applications/Blender.app/Contents/MacOS/Blender --background \
    --factory-startup --python tools/create_assets.py -- --assets fish_predator kelp weapon_knife
Outputs are staged in .tools/alien-staging; the source .blend packs its textures.
"""
import argparse
import json
import math
import random
import sys
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/source/alien-ocean-v2'
STAGING = ROOT / '.tools/alien-staging'
CONTRACT = json.loads((SOURCE / 'original-manifest.json').read_text())
TAU = math.tau
PARTS = []
BONES = {}
ASSETS = []
MANIFEST = {}
CURRENT = ''

# Atlas slots: skin/hull, belly/bone, accent, dark, photophores, secondary,
# brushed metal, membrane. Textures contain surface detail, not studio lighting.
PALETTES = {
    'fish_predator': ['173e4b', '78b1aa', 'b77543', '08171e', '46e8ec', '476574', '91aaa9', '27677c'],
    'kelp': ['426d36', 'a9ba64', 'c4a04d', '283d24', '3cd5ba', 'b17d26', '698066', '245f57'],
    'weapon_knife': ['1d3948', 'b5c8cc', 'dc713b', '10252d', '38dce5', '7b6861', '98adb7', '36505c'],
    'fish': ['236976', 'bfc4ac', 'ba673b', '10262d', '48e0d8', '447d77', '9eacaa', '548f94'],
    'fish_small': ['c99528', 'e1d7ab', 'b67c24', '15242a', '57e9e3', 'c49a52', 'adad91', '66b6b1'],
    'fish_abyss': ['262e48', '7b8091', '554068', '0c1121', '57e4f0', '704356', '8c8c96', '44374d'],
    'manta_ray': ['182b4e', 'a5b3b6', 'b27c53', '0a1424', '49d5eb', '526781', 'a5aaad', '29456b'],
    'sea_turtle': ['406449', 'b9b99b', 'bc995e', '152b2c', '4bddc2', '768747', '91a095', '4c907b'],
    'squid': ['682b44', 'c9998a', 'a46a66', '171525', '56e9e3', '744f6e', '948a96', 'a45972'],
    'crab': ['a34335', 'cbb998', 'c57946', '242e38', '4ddcc6', '734447', 'a79883', 'a76852'],
    'jellyfish': ['80b6ba', 'a6c4c5', '8a659f', '253758', '54e3d9', 'cf944b', 'a7b6c2', '8172ab'],
    'coral': ['a65d4d', 'cab69c', 'd18a64', '344645', '56d9be', 'a4846c', '919583', 'b05f70'],
    'tube_coral': ['785287', 'b49bb2', 'ba935f', '37273e', '4dd9d5', '83506e', '9d8f98', '94708e'],
    'anemone': ['437e75', 'b7bba5', 'bd7373', '253d43', '67e9cf', '995c83', '8aaba3', 'a16996'],
    'sea_fan': ['813c51', 'b1997a', 'c48151', '3a2634', '61d5c7', '845479', '9c8797', 'a45a78'],
    'tubeworms': ['b6b4a0', 'd9c9a8', '9c4d52', '36293a', '59d8d1', '774751', '9eaca3', 'ab546d'],
    'starfish_urchin': ['a76844', 'c6b89b', 'b08064', '334344', '62dacc', '6c4d7d', '988a94', '856096'],
    'rock': ['455b5b', 'aba896', '6c827b', '2b393e', '5e8574', '7c8280', '8d9492', '626e6a'],
    'crystal_spire': ['344049', '9cbdbf', '8a73a5', '25323c', '4ab6c7', '79629a', 'a1bac8', '598eab'],
    'pod': ['c6d0c9', 'd8ddd2', 'ce7944', '17363d', '41d1c6', '637779', '9baeb6', '365f68'],
    'ruins': ['8a9c9b', 'b9bbaa', '687d78', '374c4e', '42c4b9', '7d7d69', 'a2aaa5', '5b8c83'],
    'shipwreck': ['2d4e59', '8e9e9d', 'b88343', '132c34', '41c9c3', '78654d', '8b9ca4', '577567'],
    'resource_titanium': ['3e4b55', 'acb9b7', '858e94', '26333a', '637e8b', '6c7377', 'abbec9', '637a87'],
    'resource_copper': ['424744', '99a392', 'c87b44', '263838', '719788', '567d69', 'bc844b', '6d927b'],
    'resource_quartz': ['354953', 'a3c5ca', '739cab', '20343d', '65c9d4', '657f9b', 'b2c6ce', '78adbd'],
    'resource_kelp': ['426d36', 'a9ba64', 'c4a04d', '283d24', '3cd5ba', 'b17d26', '698066', '245f57'],
    'weapon_axe': ['26404e', 'a9bec3', 'ce703b', '142933', '41d9de', '81776b', '9bb1bb', '526a72'],
    'weapon_sonic': ['254957', 'aebdc0', 'ba7a4a', '142b35', '49d9db', '756956', '93acb5', '3c6975'],
}


def color(hex_value):
    return np.array([int(hex_value[i:i + 2], 16) / 255 for i in (0, 2, 4)])


def image_from_array(name, pixels, data=False):
    path = SOURCE / 'textures' / (name + '.png')
    image = bpy.data.images.new(name, width=pixels.shape[1], height=pixels.shape[0], alpha=True)
    image.colorspace_settings.name = 'Non-Color' if data else 'sRGB'
    image.pixels.foreach_set(np.ascontiguousarray(pixels, dtype=np.float32).ravel())
    image.filepath_raw = str(path)
    image.file_format = 'PNG'
    image.save()
    return image


def make_material(name):
    size = 2048 if name in {'fish_predator', 'fish_abyss', 'manta_ray', 'sea_turtle', 'squid', 'crab', 'jellyfish', 'pod', 'ruins', 'shipwreck', 'weapon_knife', 'weapon_axe', 'weapon_sonic'} else 1024
    w, h = size // 4, size // 2
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    u, v = x / w, y / h
    rng = np.random.default_rng(sum(map(ord, name)))
    noise = rng.random((h, w), dtype=np.float32)
    cloud = .5 + .2 * np.sin(u * 29 + np.sin(v * 17)) * np.cos(v * 23 - u * 11)
    cell = (np.cos(u * TAU * 32 + np.sin(v * TAU * 24)) * np.cos(v * TAU * 24)) ** 8
    veins = np.exp(-np.abs(np.sin(u * 36 + np.sin(v * 14))) * 22)
    albedo = np.ones((size, size, 4), dtype=np.float32)
    normal = np.ones_like(albedo)
    orm = np.ones_like(albedo)
    emission = np.zeros_like(albedo)
    emission[:, :, 3] = 1
    artificial = name.startswith('weapon') or name in {'pod', 'shipwreck'}
    mineral = name in {'rock', 'crystal_spire', 'ruins', 'resource_titanium', 'resource_copper', 'resource_quartz'}
    for slot, hex_value in enumerate(PALETTES[name]):
        row, col = slot // 4, slot % 4
        region = (slice(row * h, (row + 1) * h), slice(col * w, (col + 1) * w))
        relief = cloud * .2 + noise * .045 + cell * .06
        if slot == 7:
            relief = .045 * np.sin(v * TAU * 34) + veins * .05 + noise * .015
        if artificial or slot == 6:
            relief = noise * .014 + .01 * np.sin(v * TAU * 120)
        if mineral:
            relief = cloud * .5 + noise * .05 + veins * .03
        wear = np.clip(.75 + cloud * .33 + noise * .09 + cell * .12, .55, 1.3)
        base = color(hex_value)
        albedo[region][:, :, :3] = np.clip(base[None, None, :] * wear[:, :, None], 0, 1)
        if name == 'jellyfish' and slot in (0, 7):
            albedo[region][:, :, 3] = .42 if slot == 0 else .7
        dy, dx = np.gradient(relief)
        nx, ny = -dx * 8, -dy * 8
        length = np.sqrt(nx * nx + ny * ny + 1)
        normal[region][:, :, 0] = nx / length * .5 + .5
        normal[region][:, :, 1] = ny / length * .5 + .5
        normal[region][:, :, 2] = .5 + .5 / length
        orm[region][:, :, 0] = np.clip(.94 - veins * .1, .65, 1)
        rough = .44 if slot in (0, 1, 2) else .3
        if slot == 3:
            rough = .22 if not artificial else .7
        if slot == 7:
            rough = .6
        if mineral:
            rough = .82 if slot in (0, 3) else .34
        orm[region][:, :, 1] = np.clip(rough + (noise - .5) * .11 + cloud * .08, .12, .95)
        orm[region][:, :, 2] = .82 if slot == 6 or (artificial and slot in (0, 1, 2)) else 0
        if slot == 4:
            emission[region][:, :, :3] = base[None, None, :] * (.72 + .28 * cloud[:, :, None])
        if slot == 7 and not artificial:
            emission[region][:, :, :3] = color(PALETTES[name][4])[None, None, :] * veins[:, :, None] * .28
    maps = {key: image_from_array(name + '_' + key, values, key in ('normal', 'orm'))
            for key, values in [('albedo', albedo), ('normal', normal), ('orm', orm), ('emission', emission)]}
    mat = bpy.data.materials.new(name + '_PBR')
    mat.use_nodes = True
    mat.use_backface_culling = False
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes.get('Principled BSDF')
    for key, img in maps.items():
        tex = nodes.new('ShaderNodeTexImage')
        tex.name = key
        tex.image = img
        tex.interpolation = 'Linear'
    links.new(nodes['albedo'].outputs['Color'], bsdf.inputs['Base Color'])
    if name == 'jellyfish':
        links.new(nodes['albedo'].outputs['Alpha'], bsdf.inputs['Alpha'])
        mat.surface_render_method = 'DITHERED'
    nmap = nodes.new('ShaderNodeNormalMap')
    links.new(nodes['normal'].outputs['Color'], nmap.inputs['Color'])
    links.new(nmap.outputs['Normal'], bsdf.inputs['Normal'])
    separate = nodes.new('ShaderNodeSeparateColor')
    links.new(nodes['orm'].outputs['Color'], separate.inputs['Color'])
    links.new(separate.outputs['Green'], bsdf.inputs['Roughness'])
    links.new(separate.outputs['Blue'], bsdf.inputs['Metallic'])
    links.new(nodes['emission'].outputs['Color'], bsdf.inputs['Emission Color'])
    bsdf.inputs['Emission Strength'].default_value = .9
    # The glTF exporter recognizes this group as the baked occlusion channel.
    group = bpy.data.node_groups.get('glTF Material Output')
    if group is None:
        group = bpy.data.node_groups.new('glTF Material Output', 'ShaderNodeTree')
        group.interface.new_socket(name='Occlusion', in_out='INPUT', socket_type='NodeSocketFloat')
    ao = nodes.new('ShaderNodeGroup')
    ao.node_tree = group
    links.new(separate.outputs['Red'], ao.inputs['Occlusion'])
    return mat, size


def mesh(name, vertices, faces, uv, slot=0, bone=None, face_slots=None, smooth=True):
    data = bpy.data.meshes.new(CURRENT + '_' + name)
    data.from_pydata(vertices, [], faces)
    data.update()
    obj = bpy.data.objects.new(CURRENT + '_' + name, data)
    bpy.context.scene.collection.objects.link(obj)
    layer = data.uv_layers.new(name='UVMap')
    for polygon in data.polygons:
        tile = face_slots[polygon.index] if face_slots else slot
        for loop_index in polygon.loop_indices:
            vi = data.loops[loop_index].vertex_index
            a, b = uv[vi]
            layer.data[loop_index].uv = ((tile % 4 + .008 + .984 * a) / 4, (tile // 4 + .008 + .984 * b) / 2)
        polygon.use_smooth = smooth
    if bone:
        if isinstance(bone, str):
            obj.vertex_groups.new(name=bone).add(list(range(len(vertices))), 1, 'REPLACE')
        else:
            groups = {}
            for index, point in enumerate(vertices):
                for key, weight in bone(point).items():
                    if weight > .0001:
                        if key not in groups:
                            groups[key] = obj.vertex_groups.new(name=key)
                        groups[key].add([index], weight, 'REPLACE')
    PARTS.append(obj)
    return obj


def bone(name, start, end, parent='body'):
    BONES[name] = (Vector(start), Vector(end), parent if name != 'body' else None)
    return name


def body_weights(point):
    anchors = [(-.9, 'body'), (.3, 'spine'), (1.05, 'tail'), (1.8, 'tail_tip')]
    y = point[1]
    if y <= anchors[0][0]:
        return {'body': 1.0}
    for (a, an), (b, bn) in zip(anchors, anchors[1:]):
        if y <= b:
            t = max(0, min(1, (y - a) / (b - a)))
            return {an: 1 - t, bn: t}
    return {'tail_tip': 1.0}


def ellipsoid(name, center, scale, slot=0, bone_name=None, segments=20, rings=12, organic=0):
    verts, uv, faces = [], [], []
    for i in range(rings + 1):
        theta = .0001 + (math.pi - .0002) * i / rings
        for j in range(segments + 1):
            phi = TAU * j / segments
            ripple = 1 + organic * math.sin(phi * 5 + theta * 3) * math.sin(theta * 7)
            verts.append((center[0] + math.sin(theta) * math.cos(phi) * scale[0] * ripple,
                          center[1] + math.sin(theta) * math.sin(phi) * scale[1] * ripple,
                          center[2] + math.cos(theta) * scale[2] * ripple))
            uv.append((j / segments, i / rings))
    for i in range(rings):
        for j in range(segments):
            a = i * (segments + 1) + j
            faces.append((a, a + 1, a + segments + 2, a + segments + 1))
    return mesh(name, verts, faces, uv, slot, bone_name)


def tube(name, points, radii, slot=0, bone_name=None, sides=10):
    verts, uv, faces = [], [], []
    points = [Vector(p) for p in points]
    for i, p in enumerate(points):
        direction = (points[min(i + 1, len(points) - 1)] - points[max(0, i - 1)]).normalized()
        cross = direction.cross(Vector((0, 0, 1)))
        if cross.length < .01:
            cross = direction.cross(Vector((0, 1, 0)))
        cross.normalize()
        up = cross.cross(direction).normalized()
        for j in range(sides + 1):
            a = TAU * j / sides
            verts.append(p + radii[i] * (cross * math.cos(a) + up * math.sin(a)))
            uv.append((j / sides, i / (len(points) - 1)))
    for i in range(len(points) - 1):
        for j in range(sides):
            a = i * (sides + 1) + j
            faces.append((a, a + sides + 1, a + sides + 2, a + 1))
    faces.extend([tuple(range(sides - 1, -1, -1)), tuple((len(points) - 1) * (sides + 1) + j for j in range(sides))])
    return mesh(name, verts, faces, uv, slot, bone_name)


def ring(name, center, rx, ry, thickness, slot=2, bone_name=None, plane='XY', segments=24):
    pts = []
    for i in range(segments + 1):
        a = i / segments * TAU
        off = {'XY': (rx * math.cos(a), ry * math.sin(a), 0),
               'XZ': (rx * math.cos(a), 0, ry * math.sin(a)),
               'YZ': (0, rx * math.cos(a), ry * math.sin(a))}[plane]
        pts.append(Vector(center) + Vector(off))
    return tube(name, pts, [thickness] * len(pts), slot, bone_name, 6)


def membrane(name, a, b, tip, slot=7, bone_name=None, bulge=.06, rows=9, columns=6):
    a, b, tip = Vector(a), Vector(b), Vector(tip)
    norm = (b - a).cross(tip - a).normalized()
    verts, uv, faces = [], [], []
    for i in range(rows + 1):
        u = i / rows * .999
        for j in range(columns + 1):
            v = j / columns
            root = a.lerp(b, v)
            control = root.lerp(tip, .65) + (b - a) * (v - .55) * .28
            pos = root * (1 - u) ** 2 + control * 2 * (1 - u) * u + tip * u ** 2
            pos += norm * math.sin(math.pi * u) * math.sin(math.pi * v) * bulge
            pos += norm * math.sin(v * TAU * 3) * u * (1 - u) * bulge * .22
            verts.append(pos)
            uv.append((u, v))
    for i in range(rows):
        for j in range(columns):
            n = i * (columns + 1) + j
            faces.append((n, n + columns + 1, n + columns + 2, n + 1))
    return mesh(name, verts, faces, uv, slot, bone_name)


def plate(name, outline, thickness, slot=6, bone_name=None):
    # Extruded YZ outline: preserves the first-person weapon grip convention.
    verts = [(side * thickness / 2, y, z) for side in (-1, 1) for y, z in outline]
    n = len(outline)
    ylo, yhi = min(p[0] for p in outline), max(p[0] for p in outline)
    zlo, zhi = min(p[1] for p in outline), max(p[1] for p in outline)
    uv = [((p[1] - ylo) / max(.001, yhi - ylo), (p[2] - zlo) / max(.001, zhi - zlo)) for p in verts]
    faces = [tuple(range(n - 1, -1, -1)), tuple(range(n, n * 2))]
    faces.extend((i, (i + 1) % n, (i + 1) % n + n, i + n) for i in range(n))
    obj = mesh(name, verts, faces, uv, slot, bone_name)
    for p in obj.data.polygons:
        p.use_smooth = False
    bevel = obj.modifiers.new('Machined edge radius', 'BEVEL')
    bevel.width, bevel.segments = thickness * .12, 2
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    return obj


def box(name, location, scale, slot=0, bone_name=None, bevel=0.0):
    dx, dy, dz = scale[0] / 2, scale[1] / 2, scale[2] / 2
    cx, cy, cz = location
    verts = [
        (cx - dx, cy - dy, cz - dz), (cx + dx, cy - dy, cz - dz),
        (cx + dx, cy + dy, cz - dz), (cx - dx, cy + dy, cz - dz),
        (cx - dx, cy - dy, cz + dz), (cx + dx, cy - dy, cz + dz),
        (cx + dx, cy + dy, cz + dz), (cx - dx, cy + dy, cz + dz),
    ]
    faces = [
        (0, 1, 2, 3), (4, 7, 6, 5),
        (0, 4, 5, 1), (1, 5, 6, 2),
        (2, 6, 7, 3), (3, 7, 4, 0),
    ]
    uv = [(0, 0), (1, 0), (1, 1), (0, 1), (0, 0), (1, 0), (1, 1), (0, 1)]
    obj = mesh(name, verts, faces, uv, slot, bone_name, smooth=False)
    if bevel > 0:
        mod = obj.modifiers.new('Bevel', 'BEVEL')
        mod.width = bevel
        mod.segments = 2
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj


def fish_spine():
    bone('body', (0, -.9, 0), (0, .1, 0))
    bone('spine', (0, .1, 0), (0, .8, 0))
    bone('tail', (0, .8, 0), (0, 1.45, 0), 'spine')
    bone('tail_tip', (0, 1.45, 0), (0, 2.1, 0), 'tail')


def spindle(name, profile, slot=0, segments=24, bone_name=None):
    verts, uv, faces, slots = [], [], [], []
    for i, (y, rx, rz, z) in enumerate(profile):
        for j in range(segments + 1):
            a = TAU * j / segments
            verts.append((math.cos(a) * rx, y, z + math.sin(a) * rz))
            uv.append((j / segments, i / (len(profile) - 1)))
    for i in range(len(profile) - 1):
        for j in range(segments):
            n = i * (segments + 1) + j
            faces.append((n, n + 1, n + segments + 2, n + segments + 1))
            slots.append(1 if math.sin(TAU * (j + .5) / segments) < -.45 else slot)
    return mesh(name, verts, faces, uv, slot, bone_name, slots)


def create_fish_predator():
    fish_spine()
    profile = []
    for i in range(25):
        t = i / 24
        y = -1.1 + t * 3
        envelope = max(.015, math.sin(math.pi * (t * .84 + .1))) ** .9
        profile.append((y, envelope * .46 * (1 - t * .65), envelope * .53 * (1 - t * .58), 0))
    spindle('Muscular scaled trunk', profile, segments=28, bone_name=body_weights)
    spindle('Wedge cranial armor', [(-1.98, .09, .025, .02), (-1.86, .32, .09, .06),
            (-1.6, .44, .18, .12), (-1.25, .46, .25, .14), (-.9, .38, .27, .07)],
            0, 24, 'body')
    ellipsoid('Upper maxillary rim', (0, -1.53, -.035), (.37, .44, .035), 2, 'body', 22, 6)
    bone('jaw', (0, -.92, -.24), (0, -1.68, -.25))
    spindle('Lower muscular jaw', [(-1.93, .08, .01, -.25), (-1.78, .28, .035, -.32),
            (-1.5, .36, .06, -.36), (-1.15, .32, .07, -.27), (-.94, .22, .04, -.2)], 1, 20, 'jaw')
    ellipsoid('Oral cavity', (0, -1.5, -.17), (.33, .36, .1), 3, 'body', 20, 8)
    for s in (-1, 1):
        for i in range(9):
            y = -1.82 + i * .088
            x = s * (.16 + math.sin(i / 9 * math.pi) * .18)
            for lower in (False, True):
                z = -.245 if lower else -.09
                end = z + (.10 if lower else -.12)
                tube('Teeth', [(x, y, z), (x * .98, y - .015, end)], [.031, .002], 1, 'jaw' if lower else 'body', 5)
        for i in range(3):
            for j in range(2):
                ellipsoid('Sensory pit', (s * .435, -1.27 - i * .12, .20 - j * .13), (.02, .057, .045), 3, 'body', 12, 7)
                ellipsoid('Luminous iris', (s * .45, -1.27 - i * .12, .20 - j * .13), (.008, .019, .019), 4, 'body', 8, 6)
        for i in range(3):
            pts = [(s * (.27 + math.sin(j / 8 * math.pi) * .17), -.71 + i * .14, -.27 + j * .075) for j in range(9)]
            tube('Armored gill collar', pts, [.045] * 9, 2, 'body', 6)
        side = 'L' if s < 0 else 'R'
        bone('fin_' + side, (s * .28, -.38, -.05), (s * 1.15, .38, -.09))
        membrane('Pectoral crescent', (s * .3, -.65, -.06), (s * .32, .18, -.12), (s * 1.25, .88, -.1), 7, 'fin_' + side, .16)
        membrane('Pelvic fin', (s * .22, .65, -.18), (s * .2, 1.02, -.16), (s * .55, 1.3, -.25), 2, 'tail', .035, 6, 4)
        for i in range(18):
            y = -.62 + i * .12
            x = s * (.4 - (y + .62) * .115)
            ellipsoid('Photophore', (x, y, .055), (.016, .025, .013), 4, body_weights, 8, 5)
    membrane('Dorsal sail', (0, -.55, .4), (0, .66, .34), (0, .34, 1.05), 7, 'body', .015)
    for sign in (-1, 1):
        membrane('Lunate tail', (0, 1.63, 0), (0, 2.05, 0), (0, 2.44, sign * .92), 2, 'tail_tip', .01)


def kelp_blade(name, at, angle, length, width, bone_name=None):
    at = Vector(at)
    direction = Vector((math.cos(angle), math.sin(angle), .35))
    cross = Vector((-math.sin(angle), math.cos(angle), 0))
    verts, uv, faces = [], [], []
    for i in range(17):
        t = i / 16
        for j in range(5):
            v = j / 4 * 2 - 1
            envelope = max(.002, math.sin(math.pi * t)) ** .8
            p = at + direction * t * length + cross * v * width * envelope
            p.z += math.sin(t * math.pi * 1.6) * length * .22 + math.sin(t * 19 + v * 2) * abs(v) * .04
            verts.append(p)
            uv.append((j / 4, t))
    for i in range(16):
        for j in range(4):
            n = i * 5 + j
            faces.append((n, n + 1, n + 6, n + 5))
    mesh(name, verts, faces, uv, 7, bone_name)
    pts = [at + direction * i / 12 * length + Vector((0, 0, math.sin(i / 12 * math.pi * 1.6) * length * .22)) for i in range(13)]
    tube('Luminous leaf midrib', pts, [.009] * 13, 4, bone_name, 4)


def create_kelp():
    for r in range(8):
        a = r * TAU / 8
        tube('Holdfast root', [(0, 0, .23), (.2 * math.cos(a), .2 * math.sin(a), .08), (.42 * math.cos(a + .25), .42 * math.sin(a + .25), .015)], [.07, .045, .003], 0, sides=7)
    for stem in range(3):
        angle = stem * 2.3
        height = 4.8 - stem * .54
        points = [(math.sin(i / 12 * 2.7 + angle) * i / 12 * .45, math.cos(i / 12 * 2.2 + angle) * i / 12 * .4, height * i / 12 + .1) for i in range(13)]
        tube('Flexible stipe', points, [.065 * (1 - i / 18) for i in range(13)], 0, sides=9)
        for i in (4, 7, 10):
            point = Vector(points[i])
            a = angle + i * 2.1
            kelp_blade('Ruffled blade', point, a, 1.25 * (1 - i / 40), .24)
            ellipsoid('Amber gas bladder', point + Vector((0, 0, .05)), (.09, .095, .16), 5, segments=10, rings=6)
            for vein in range(3):
                va = vein * TAU / 3
                tube('Bladder vein', [point + Vector((.092 * math.cos(va), .095 * math.sin(va), z)) for z in (-.05, .05, .18)], [.006] * 3, 2, sides=4)


def create_weapon_knife():
    plate('Forged titanium blade', [(-.24, .005), (-.18, .029), (-.02, .035), (0, .021), (-.01, -.024), (-.14, -.014)], .006, 6)
    for s in (-1, 1):
        tube('Recessed energy inlay', [(s * .0034, -.185, .015), (s * .0034, -.04, .019)], [.0018, .0018], 4, sides=6)
        plate('Ceramic blade facing', [(-.18, .024), (-.025, .03), (-.018, .02), (-.13, .017)], .0063, 0)
    plate('Orange thumb guard', [(-.004, -.035), (.009, -.033), (.015, .034), (0, .038)], .042, 2)
    tube('Rubber grip', [(0, .015, 0), (0, .052, 0), (0, .105, 0), (0, .166, 0)], [.019, .023, .021, .018], 3, sides=16)
    for i in range(8):
        ring('Raised grip tread', (0, .03 + i * .016, 0), .022, .024, .002, 0, plane='XZ', segments=16)
    plate('Lanyard butt cap', [(.155, -.024), (.177, -.017), (.177, .017), (.158, .024)], .037, 6)


def reef_fish(small=False):
    fish_spine()
    profile = []
    for i in range(15):
        t = i / 14
        e = max(.01, math.sin(math.pi * t)) ** .8
        profile.append((-1.2 + t * 3, .39 * e * (1 - t * .5), .6 * e * (1 - t * .6), 0))
    spindle('Scaled fusiform body', profile, segments=16, bone_name=body_weights)
    ellipsoid('Armored forehead', (0, -.83, .17), (.25, .35, .3), 0 if small else 2, 'body', 12, 8)
    for s in (-1, 1):
        ellipsoid('Recessed eye', (s * .235, -.91, .13), (.025, .077, .071), 3, 'body', 12, 7)
        side = 'L' if s < 0 else 'R'
        b = bone('fin_' + side, (s * .23, -.3, -.02), (s * .75, .12, -.1))
        membrane('Paired fin', (s * .24, -.45, -.02), (s * .25, -.06, -.05), (s * .77, .36, -.17), 7, b, .08, 6, 4)
        for i in range(6):
            ellipsoid('Flank photophore', (s * (.29 - i * .023), -.3 + i * .21, .04), (.014, .025, .025), 4, body_weights, 7, 4)
    membrane('Dorsal sail', (0, -.6, .34), (0, .75, .2), (0, .05 if small else -.1, .84), 7 if small else 2, 'body', .015, 8, 4)
    for s in (-1, 1):
        membrane('Bifurcated tail', (0, 1.5, -.07), (0, 1.68, .07), (0, 2.22, s * .6), 7 if small else 2, 'tail_tip', .015, 6, 4)
    if small:
        ellipsoid('Ventral lantern', (0, -.54, -.31), (.13, .21, .11), 4, 'body', 10, 6)
        tube('Sensory crest', [(0, -.9, .38), (0, -.94, .57), (0, -.81, .66)], [.016, .012, .004], 2, 'body', 6)


def create_fish():
    reef_fish()


def create_fish_small():
    reef_fish(True)


def create_fish_abyss():
    create_fish_predator()
    for obj in PARTS:
        for v in obj.data.vertices:
            if v.co.y < -.7:
                v.co.x *= 1.3
    for i in range(3):
        s = i - 1
        points = [(s * .16, -.85, .35), (s * .23, -.98, .76), (s * .30, -1.3, .96), (s * .32, -1.65, .86)]
        tube('Angler lure peduncle', points, [.045, .032, .024, .015], 5, 'body', 8)
        ellipsoid('Lure bulb', points[-1], (.085, .1, .09), 4, 'body', 12, 8)


def create_manta_ray():
    bone('body', (0, -.7, 0), (0, .7, 0))
    bone('tail', (0, .7, 0), (0, 1.8, 0))
    bone('tail_tip', (0, 1.8, 0), (0, 3.1, 0), 'tail')
    ellipsoid('Hydrofoil body', (0, 0, 0), (.65, 1.16, .22), 0, 'body', 28, 14)
    ellipsoid('Ventral shield', (0, -.05, -.095), (.6, .95, .13), 1, 'body', 24, 10)
    for s in (-1, 1):
        side = 'L' if s < 0 else 'R'
        b = bone('wing_' + side, (s * .45, 0, 0), (s * 1.95, .2, 0))
        weight = lambda p, side_bone=b: {'body': 1 - min(1, max(0, (abs(p[0]) - .4) / 1.0)), side_bone: min(1, max(0, (abs(p[0]) - .4) / 1.0))}
        membrane('Broad hydrofoil wing', (s * .35, -.95, 0), (s * .5, .9, 0), (s * 2.4, .7, .08), 7, weight, .24, 18, 12)
        for i in range(6):
            start = Vector((s * .42, -.72 + i * .24, .055))
            end = Vector((s * (1.8 + i * .08), .56 + i * .06, .09))
            pts = [start.lerp(end, j / 8) + Vector((0, 0, math.sin(j / 8 * math.pi) * .055)) for j in range(9)]
            tube('Wing vascular rib', pts, [.013] * 9, 2 if i % 2 else 4, weight, 5)
        tube('Cephalic scoop', [(s * .3, -.8, 0), (s * .34, -1.28, -.03), (s * .23, -1.48, -.08)], [.10, .08, .022], 2, 'body', 12)
        ellipsoid('Lateral eye', (s * .56, -.72, .08), (.045, .075, .047), 3, 'body', 12, 7)
    pts = [(0, 1.0 + i * .26, .02 + math.sin(i * .3) * .03) for i in range(10)]
    tube('Whip tail', pts, [.055 * (1 - i / 10) for i in range(10)], 0, lambda p: {'tail' if p[1] < 1.8 else 'tail_tip': 1}, 8)


def scute(name, at, rx, ry, height, slot=0):
    verts = [Vector(at) + Vector((0, 0, height))]
    uv = [(.5, .5)]
    for i in range(7):
        a = i / 6 * TAU
        verts.append(Vector(at) + Vector((rx * math.cos(a), ry * math.sin(a), 0)))
        uv.append((.5 + .49 * math.cos(a), .5 + .49 * math.sin(a)))
    return mesh(name, verts, [(0, i + 1, i + 2) for i in range(6)], uv, slot, 'body' if BONES else None)


def create_sea_turtle():
    bone('body', (0, -.6, 0), (0, .65, 0))
    ellipsoid('Mineralized carapace', (0, 0, .12), (.77, 1.02, .4), 0, 'body', 28, 16, .035)
    ellipsoid('Pale plastron', (0, 0, -.05), (.69, .92, .17), 1, 'body', 24, 10)
    for i in range(3):
        y = -.55 + i * .55
        scute('Central carapace scute', (0, y, .43), .26, .29, .09, 5)
        for s in (-1, 1):
            scute('Lateral carapace scute', (s * .39, y, .35), .22, .27, .08, 0 if i % 2 else 2)
            tube('Luminous shell suture', [(s * .18, y - .19, .47), (s * .36, y -.25, .43), (s * .61, y - .12, .32)], [.013] * 3, 4, 'body', 5)
    tube('Articulated neck', [(0, -.8, 0), (0, -1.16, .04), (0, -1.3, .05)], [.2, .14, .15], 7, 'body', 14)
    ellipsoid('Tapered head', (0, -1.4, .06), (.21, .35, .18), 7, 'body', 20, 10)
    for s in (-1, 1):
        ellipsoid('Dark eye', (s * .17, -1.48, .14), (.022, .055, .035), 3, 'body', 10, 6)
        for fore in (True, False):
            y = -.6 if fore else .63
            b = bone('flipper_' + ('F' if fore else 'B') + str(s), (s * .48, y, 0), (s * 1.55, y + .6, -.05))
            membrane('Paddle flipper', (s * .48, y - .17, 0), (s * .49, y + .2, -.02), (s * (1.7 if fore else 1.2), y + .9, -.09), 7, b, .07, 12, 7)
    tube('Short tail', [(0, .85, -.03), (0, 1.35, -.04)], [.11, .006], 7, 'body', 9)


def chain_arm(name, points, radius, slot=7, sides=8):
    points = [Vector(p) for p in points]
    count = 3
    for j in range(count):
        bone(name + '_' + str(j), points[j * 4], points[(j + 1) * 4], 'body' if j == 0 else name + '_' + str(j - 1))
    anchors = [points[j * 4] for j in range(count)]
    def weights(point):
        distances = sorted(((Vector(point) - p).length, j) for j, p in enumerate(anchors))[:2]
        a, b = distances
        total = max(.00001, a[0] + b[0])
        return {name + '_' + str(a[1]): b[0] / total, name + '_' + str(b[1]): a[0] / total}
    tube('Flexible segmented appendage', points, [radius * (1 - i / 14) for i in range(13)], slot, weights, sides)
    return weights


def create_squid():
    bone('body', (0, -.9, 0), (0, .4, 0))
    profile = [(-1.9, .015, .015, .01), (-1.65, .20, .19, .01), (-1.25, .39, .31, 0),
               (-.65, .42, .33, 0), (0, .30, .25, 0), (.4, .26, .22, 0)]
    spindle('Chromatophore mantle', profile, 0, 28, 'body')
    for s in (-1, 1):
        b = bone('fin_' + str(s), (s * .2, -1.1, 0), (s * .9, -.8, 0))
        membrane('Mantle fin sail', (s * .2, -1.7, 0), (s * .35, -.3, 0), (s * .95, -.4, -.02), 7, b, .13, 12, 8)
        ellipsoid('Cephalopod eye', (s * .25, .26, .05), (.07, .13, .1), 3, 'body', 14, 8)
    for i in range(5):
        ring('Mantle photophore ring', (0, -1.15 + i * .3, 0), .39 - abs(i - 1) * .034, .31 - abs(i - 1) * .018, .013, 4, 'body', 'XZ', 20)
    for i in range(10):
        a = i / 10 * TAU
        length = 2.9 if i in (3, 8) else 1.9
        points = [(math.cos(a) * (.19 + t * .45) + math.sin(t * 5 + a) * t * .18,
                   .4 + t * length, math.sin(a) * (.18 + t * .38) + math.sin(t * 5 + a) * .08)
                  for t in [j / 12 for j in range(13)]]
        weights = chain_arm('arm_' + str(i), points, .085 if i < 8 else .065, 7, 8)
        for j in (3, 5, 7, 9):
            ellipsoid('Pale sucker', Vector(points[j]) + Vector((0, 0, -.025)), (.038, .048, .022), 1, weights, 8, 5)
        if i in (3, 8):
            ellipsoid('Feeding club', points[-2], (.11, .18, .10), 5, 'arm_' + str(i) + '_2', 12, 8)


def create_crab():
    bone('body', (0, -.4, .3), (0, .45, .3))
    ellipsoid('Segmented carapace', (0, 0, .32), (.65, .61, .24), 0, 'body', 28, 14, .06)
    for y in (-.25, .12, .4):
        scute('Dorsal armor plate', (0, y, .53), .3, .2, .055, 2)
    for s in (-1, 1):
        for j in range(4):
            index = j + (4 if s > 0 else 0)
            y = -.39 + j * .26
            pts = [(s * .48, y, .32), (s * .89, y + (j - 1.5) * .13, .48), (s * 1.22, y + (j - 1.5) * .28, .18), (s * 1.31, y + (j - 1.5) * .31, .02)]
            for k in range(3):
                b = bone('leg_' + str(index) + '_' + str(k), pts[k], pts[k + 1], 'body' if k == 0 else 'leg_' + str(index) + '_' + str(k - 1))
                tube('Walking leg segment', pts[k:k + 2], [.07 - k * .018, .05 - k * .018], 0, b, 9)
                ellipsoid('Leg hinge', pts[k], (.083, .083, .066), 2, b, 10, 6)
        b = bone('claw_' + str(s), (s * .43, -.34, .3), (s * .78, -.98, .38))
        tube('Claw forearm', [(s * .43, -.34, .3), (s * .74, -.65, .35), (s * .77, -.99, .4)], [.12, .13, .15], 0, b, 12)
        f = 1.2 if s < 0 else .9
        ellipsoid('Pincer palm', (s * .75, -1.02, .4), (.24 * f, .28 * f, .17 * f), 0, b, 18, 10)
        for tooth in (-1, 1):
            tube('Opposing pincer finger', [(s * .75 + tooth * .13, -1.13, .4), (s * .75 + tooth * .17, -1.4, .41), (s * .75 + tooth * .045, -1.53, .4)], [.10, .065, .006], 1, b, 10)
        tube('Eye stalk', [(s * .25, -.42, .43), (s * .31, -.64, .59)], [.043, .029], 2, 'body', 8)
        ellipsoid('Compound eye', (s * .31, -.65, .6), (.066, .075, .055), 3, 'body', 12, 8)
        tube('Photophore seam', [(s * .44, -.33, .49), (s * .53, 0, .49), (s * .4, .35, .47)], [.012] * 3, 4, 'body', 5)


def create_jellyfish():
    bone('body', (0, 0, 1.6), (0, 0, 2))
    bone('bell', (0, 0, 1.8), (0, 0, 2.7))
    ellipsoid('Hydrated outer bell', (0, 0, 2.1), (.8, .8, .5), 0, 'bell', 32, 18)
    ellipsoid('Amber internal gland', (0, 0, 2.04), (.24, .24, .26), 5, 'bell', 20, 12)
    ring('Violet bell margin', (0, 0, 1.84), .72, .72, .035, 2, 'bell', segments=32)
    for i in range(12):
        a = i / 12 * TAU
        pts = [(math.cos(a) * .8 * math.sin(t), math.sin(a) * .8 * math.sin(t), 2.1 + .5 * math.cos(t)) for t in [j / 9 * math.pi * .63 for j in range(10)]]
        tube('Bell vascular rib', pts, [.014] * 10, 4, 'bell', 5)
        wide = i < 4
        radius = .28 if wide else .67
        points = [(math.cos(a) * (radius + t * .1) + math.sin(t * 8 + a) * t * .13,
                   math.sin(a) * (radius + t * .1) + math.cos(t * 7 + a) * t * .12,
                   1.85 - t * (2.1 if wide else 2.5)) for t in [j / 12 for j in range(13)]]
        chain_arm('arm_' + str(i), points, .075 if wide else .023, 7 if wide else 4, 8 if wide else 6)



def create_coral():
    ellipsoid('Calcified holdfast', (0, 0, 0.15), (0.65, 0.55, 0.22), 1, organic=0.2)
    angles = [0.0, 0.85, 1.8, 2.7, 3.7, 4.6, 5.5]
    for index, angle in enumerate(angles):
        height = 1.4 + (index % 3) * 0.38
        base = Vector((0, 0, 0.18))
        elbow = Vector((0.38 * math.cos(angle), 0.38 * math.sin(angle), height * 0.52))
        top = Vector((0.82 * math.cos(angle), 0.82 * math.sin(angle), height))
        tube('Coral stem lower', [base, elbow], [0.13, 0.098], 0, sides=8)
        tube('Coral stem upper', [elbow, top], [0.098, 0.052], 0, sides=8)
        ellipsoid('Coral bud', top, (0.075, 0.075, 0.095), 4, segments=12, rings=8)
        for sign in [-1, 1]:
            start = elbow.lerp(top, 0.45)
            end = start + Vector((0.48 * math.cos(angle + sign * 0.72), 0.48 * math.sin(angle + sign * 0.72), 0.38))
            tube('Coral fork', [start, end], [0.075, 0.03], 2, sides=6)
            ellipsoid('Coral luminous bud', end, (0.055, 0.055, 0.08), 4, segments=10, rings=6)
            mid_calyx = start.lerp(end, 0.5)
            ellipsoid('Coral calyx', mid_calyx, (0.035, 0.035, 0.035), 5, segments=8, rings=5)
        tube('Vascular ridge', [base, elbow, top], [0.015, 0.012, 0.008], 2, sides=4)


def create_tube_coral():
    ellipsoid('Colony holdfast', (0, 0, 0.1), (0.8, 0.7, 0.25), 1, organic=0.2)
    tubes = [
        (-0.45, 0.12, 1.7, 0.22), (0.12, 0.28, 2.25, 0.25), (0.48, -0.12, 1.45, 0.21),
        (-0.16, -0.42, 1.15, 0.23), (0.52, 0.38, 1.25, 0.18), (-0.35, 0.45, 0.95, 0.16),
        (0.25, -0.35, 1.55, 0.20)
    ]
    for index, (x, y, h, radius) in enumerate(tubes):
        steps = 8
        pts = [Vector((x + 0.18 * (s / (steps - 1)) ** 2, y, 0.05 + s / (steps - 1) * (h - 0.05))) for s in range(steps)]
        radii = [radius * (0.88 + 0.32 * (s / (steps - 1)) ** 2) for s in range(steps)]
        tube('Sponge tube outer', pts, radii, 0 if index % 2 else 5, sides=12)
        tube('Sponge tube cavity', pts[1:], [r * 0.76 for r in radii[1:]], 2, sides=10)
        ring('Turquoise luminous lip', pts[-1], radii[-1] * 1.02, radii[-1] * 1.02, 0.022, 4, plane='XY', segments=20)
        for t_idx in range(6):
            t_ang = t_idx * TAU / 6
            t_tip = pts[-1] + Vector((math.cos(t_ang) * 0.26, math.sin(t_ang) * 0.26, 0.2))
            tube('Polyp tentacle', [pts[-1], t_tip], [0.022, 0.005], 4, sides=4)
            ellipsoid('Polyp bud', t_tip, (0.022, 0.022, 0.025), 4, segments=6, rings=4)


def create_anemone():
    ellipsoid('Anemone pedal disc', (0, 0, 0.12), (0.8, 0.8, 0.22), 0, organic=0.15, segments=24, rings=12)
    tube('Fleshy column', [(0, 0, 0.18), (0, 0, 0.65), (0, 0, 0.95)], [0.65, 0.54, 0.72], 0, sides=20)
    for a in range(12):
        ang = a * TAU / 12
        tube('Column rib', [
            (math.cos(ang) * 0.65, math.sin(ang) * 0.65, 0.18),
            (math.cos(ang) * 0.54, math.sin(ang) * 0.54, 0.65),
            (math.cos(ang) * 0.72, math.sin(ang) * 0.72, 0.95)
        ], [0.03, 0.025, 0.03], 2, sides=5)
    ellipsoid('Oral disc center', (0, 0, 0.96), (0.68, 0.68, 0.14), 1, segments=20, rings=8)
    ellipsoid('Mouth slit', (0, 0, 1.01), (0.2, 0.07, 0.06), 4, segments=12, rings=6)
    # Inner whorl tentacles
    for i in range(10):
        ang = i * TAU / 10 + 0.15
        p0 = Vector((math.cos(ang) * 0.42, math.sin(ang) * 0.42, 0.95))
        p1 = Vector((math.cos(ang + 0.2) * 0.62, math.sin(ang + 0.2) * 0.62, 1.45 + (i % 3) * 0.15))
        p2 = Vector((math.cos(ang + 0.1) * 0.78, math.sin(ang + 0.1) * 0.78, 1.65 + (i % 2) * 0.2))
        tube('Inner tentacle', [p0, p1, p2], [0.075, 0.05, 0.02], 7, sides=8)
        ellipsoid('Inner tentacle tip', p2, (0.045, 0.045, 0.06), 4, segments=8, rings=6)
    # Outer whorl drooping tentacles
    for i in range(16):
        ang = i * TAU / 16
        p0 = Vector((math.cos(ang) * 0.62, math.sin(ang) * 0.62, 0.90))
        p1 = Vector((math.cos(ang + 0.15) * 1.05, math.sin(ang + 0.15) * 1.05, 1.22))
        p2 = Vector((math.cos(ang + 0.3) * 1.35, math.sin(ang + 0.3) * 1.35, 0.85 - (i % 3) * 0.12))
        tube('Outer tentacle', [p0, p1, p2], [0.08, 0.055, 0.022], 7, sides=8)
        ellipsoid('Outer tentacle tip', p2, (0.045, 0.045, 0.065), 4, segments=8, rings=6)


def create_sea_fan():
    ellipsoid('Fan holdfast base', (0, 0, 0.14), (0.45, 0.38, 0.18), 1, organic=0.2, segments=18, rings=10)
    tube('Fan primary trunk', [(0, 0, 0.14), (0, 0, 0.65)], [0.14, 0.09], 0, sides=8)
    angles = [-1.18, -0.80, -0.42, 0.0, 0.42, 0.80, 1.18]
    for idx, ang in enumerate(angles):
        h_reach = 1.35 + math.cos(ang * 0.8) * 0.55
        p0 = Vector((0, 0, 0.65))
        p1 = Vector((math.sin(ang) * 0.65, 0.04 * math.sin(ang * 3.0), 0.65 + math.cos(ang) * 0.55))
        p2 = Vector((math.sin(ang) * 1.15, 0.06 * math.cos(ang * 2.0), 0.65 + math.cos(ang) * h_reach))
        tube('Fan limb lower', [p0, p1], [0.085, 0.055], 0, sides=6)
        tube('Fan limb upper', [p1, p2], [0.055, 0.024], 0, sides=6)
        ellipsoid('Fan apex bud', p2, (0.045, 0.045, 0.055), 4, segments=8, rings=6)
        for branchlet in [-1, 1]:
            b_start = p1.lerp(p2, 0.42)
            b_end = b_start + Vector((branchlet * 0.28, 0.02 * branchlet, 0.22))
            tube('Fan sub-branch', [b_start, b_end], [0.035, 0.014], 2, sides=4)
            ellipsoid('Sub-branch bud', b_end, (0.035, 0.035, 0.04), 4, segments=6, rings=4)
        ellipsoid('Polyp cup', p1.lerp(p2, 0.7), (0.025, 0.025, 0.025), 5, segments=6, rings=4)


def create_tubeworms():
    ellipsoid('Basalt anchor', (0, 0, 0.22), (0.82, 0.72, 0.32), 3, organic=0.3, segments=20, rings=12)
    tubes_data = [
        (0.0, 0.0, 1.85, 0.085, 0.04, 0.02),
        (0.24, 0.18, 1.65, 0.078, 0.12, 0.06),
        (-0.22, 0.20, 1.72, 0.080, -0.10, 0.08),
        (0.35, -0.15, 1.45, 0.072, 0.15, -0.08),
        (-0.32, -0.18, 1.55, 0.075, -0.12, -0.06),
        (0.05, 0.38, 1.35, 0.068, 0.05, 0.16),
        (-0.08, -0.36, 1.40, 0.070, -0.06, -0.15),
        (0.48, 0.12, 1.15, 0.062, 0.22, 0.04),
        (-0.46, 0.08, 1.20, 0.064, -0.20, 0.05),
        (0.18, -0.32, 1.10, 0.058, 0.10, -0.18),
        (-0.25, 0.35, 1.05, 0.055, -0.14, 0.16),
        (0.38, 0.32, 0.95, 0.052, 0.18, 0.14),
        (-0.38, -0.30, 0.98, 0.054, -0.16, -0.14),
        (0.55, -0.10, 0.85, 0.048, 0.24, -0.08),
        (-0.52, -0.12, 0.88, 0.050, -0.22, -0.06),
        (0.0, -0.50, 0.82, 0.046, 0.02, -0.22),
    ]
    for idx, (x, y, h, r, lean_x, lean_y) in enumerate(tubes_data):
        p_base = Vector((x, y, 0.20))
        p_mid = Vector((x + lean_x * 0.4, y + lean_y * 0.4, h * 0.55))
        p_top = Vector((x + lean_x * h, y + lean_y * h, h))
        tube('Tubeworm lower', [p_base, p_mid], [r, r * 0.92], 1, sides=8)
        tube('Tubeworm upper', [p_mid, p_top], [r * 0.92, r * 0.82], 1, sides=8)
        ring('Tubeworm collar', p_mid, r * 1.06, r * 1.06, 0.014, 0, plane='XY', segments=12)
        ring('Luminous base', p_top, r * 0.88, r * 0.88, 0.012, 4, plane='XY', segments=10)
        plume_dir = Vector((lean_x * 0.4, lean_y * 0.4, 0.35)).normalized()
        p_plume_tip = p_top + plume_dir * 0.38
        tube('Tubeworm plume', [p_top, p_plume_tip], [r * 0.88, r * 0.14], 7, sides=8)
        ellipsoid('Plume tip', p_plume_tip, (r * 0.45, r * 0.45, r * 0.6), 7, segments=10, rings=6)


def create_starfish_urchin():
    ellipsoid('Benthic host stone', (0, 0, 0.18), (0.75, 0.65, 0.28), 3, organic=0.25, segments=22, rings=14)
    # Starfish 1 (Vermilion)
    s1_center = Vector((0.26, 0.12, 0.34))
    ellipsoid('Starfish 1 disc', s1_center, (0.095, 0.095, 0.038), 0, segments=16, rings=8)
    for arm_idx in range(5):
        ang = arm_idx * TAU / 5.0 + 0.2
        arm_mid = s1_center + Vector((math.cos(ang) * 0.16, math.sin(ang) * 0.16, -0.01))
        arm_tip = s1_center + Vector((math.cos(ang) * 0.32, math.sin(ang) * 0.32, -0.06))
        tube('Starfish 1 arm lower', [s1_center, arm_mid], [0.055, 0.032], 0, sides=6)
        tube('Starfish 1 arm upper', [arm_mid, arm_tip], [0.032, 0.008], 0, sides=6)
        ellipsoid('Ossicle 1', arm_mid, (0.018, 0.018, 0.018), 1, segments=6, rings=4)
        ellipsoid('Cyan pore 1', arm_mid + Vector((0, 0, 0.02)), (0.008, 0.008, 0.008), 4, segments=6, rings=4)
    # Starfish 2 (Ochre gold)
    s2_center = Vector((-0.30, -0.16, 0.30))
    ellipsoid('Starfish 2 disc', s2_center, (0.078, 0.078, 0.032), 2, segments=14, rings=8)
    for arm_idx in range(5):
        ang = arm_idx * TAU / 5.0 + 0.5
        arm_mid = s2_center + Vector((math.cos(ang) * 0.13, math.sin(ang) * 0.13, -0.02))
        arm_tip = s2_center + Vector((math.cos(ang) * 0.26, math.sin(ang) * 0.26, -0.07))
        tube('Starfish 2 arm lower', [s2_center, arm_mid], [0.045, 0.025], 2, sides=6)
        tube('Starfish 2 arm upper', [arm_mid, arm_tip], [0.025, 0.006], 2, sides=6)
        ellipsoid('Ossicle 2', arm_mid, (0.015, 0.015, 0.015), 1, segments=6, rings=4)
    # Spiky sea urchins
    urchin_locs = [Vector((-0.18, 0.28, 0.32)), Vector((0.28, -0.22, 0.28)), Vector((-0.38, 0.05, 0.24))]
    for u_idx, u_center in enumerate(urchin_locs):
        u_radius = 0.075 if u_idx == 0 else 0.060
        ellipsoid('Urchin body', u_center, (u_radius, u_radius, u_radius * 0.9), 5, segments=14, rings=10)
        for sp_idx in range(16):
            sp_theta = (sp_idx * 2.399) % math.pi
            sp_phi = (sp_idx * 1.618 * TAU) % TAU
            spine_dir = Vector((
                math.sin(sp_theta) * math.cos(sp_phi),
                math.sin(sp_theta) * math.sin(sp_phi),
                abs(math.cos(sp_theta)) * 0.85 + 0.15
            )).normalized()
            p_spine_tip = u_center + spine_dir * (u_radius * 2.6)
            tube('Urchin spine', [u_center, p_spine_tip], [0.012, 0.002], 3, sides=4)
            ellipsoid('Spine tip glow', p_spine_tip, (0.012, 0.012, 0.012), 4, segments=6, rings=4)


def create_rock():
    for location, scale in [((0, 0, 0.55), (1.52, 1.12, 0.92)), ((0.65, 0.25, 0.40), (0.82, 0.82, 0.65)), ((-0.65, -0.4, 0.22), (0.72, 0.60, 0.42))]:
        ellipsoid('Reef rock mass', location, scale, 0, organic=0.32, segments=24, rings=16)
    plate('Strata ledge 1', [(-0.8, -0.5), (0.6, -0.6), (0.8, 0.4), (-0.7, 0.5)], 0.08, 2)
    plate('Strata ledge 2', [(-0.5, -0.3), (0.4, -0.4), (0.5, 0.3), (-0.4, 0.4)], 0.06, 1)


def create_crystal_spire():
    for loc, sc in [((0, 0, 0.35), (1.62, 1.42, 0.72)), ((0.6, -0.4, 0.25), (1.12, 0.92, 0.52)), ((-0.52, 0.5, 0.2), (0.92, 1.02, 0.46))]:
        ellipsoid('Basalt mineral base', loc, sc, 3, organic=0.25, segments=20, rings=12)
    spires = [
        (0.0, 0.0, 0.3, 4.8, 0.36, 0.04, 0.02, 4),
        (0.48, -0.35, 0.2, 3.4, 0.28, 0.14, -0.12, 1),
        (-0.52, -0.30, 0.2, 3.1, 0.26, -0.12, -0.15, 4),
        (-0.35, 0.45, 0.2, 3.6, 0.29, -0.10, 0.16, 1),
        (0.42, 0.40, 0.2, 2.7, 0.24, 0.15, 0.11, 4),
        (0.85, 0.10, 0.15, 1.8, 0.19, 0.25, 0.04, 1),
        (-0.75, 0.05, 0.15, 1.6, 0.18, -0.22, 0.03, 4),
    ]
    for idx, (x, y, z0, h, r, tx, ty, slot) in enumerate(spires):
        p_base = Vector((x, y, z0))
        p_top = p_base + Vector((tx * h, ty * h, h * 0.84))
        p_tip = p_base + Vector((tx * (h + r * 1.6), ty * (h + r * 1.6), h))
        tube('Hex spire shaft', [p_base, p_top], [r, r * 0.92], slot, sides=6)
        tube('Hex spire tip', [p_top, p_tip], [r * 0.92, 0.002], 4, sides=6)
        tube('Hex core vein', [p_base, p_top * 0.8], [r * 0.25, r * 0.15], 4, sides=4)
        ring('Crystal base collar', p_base, r * 1.15, r * 1.15, 0.025, 0, plane='XY', segments=6)


def create_pod():
    ellipsoid('Porcelain pressure hull', (0, 0, 1.72), (2.35, 2.0, 1.45), 0, segments=32, rings=20)
    ring('Flotation collar', (0, 0, 0.94), 2.15, 1.85, 0.24, 2, plane='XY', segments=32)
    ring('Lower dark seam', (0, 0, 0.79), 1.98, 1.72, 0.055, 3, plane='XY', segments=32)
    ellipsoid('Top cap', (0, 0, 2.98), (0.85, 0.8, 0.21), 2, segments=20, rings=10)
    tube('Antenna mast', [(0.35, 0.2, 3.04), (0.35, 0.2, 4.12)], [0.047, 0.035], 6, sides=8)
    ellipsoid('Antenna beacon', (0.35, 0.2, 4.13), (0.095, 0.095, 0.11), 4, segments=12, rings=8)
    tube('Antenna crossbar', [(-0.08, 0.20, 3.78), (0.78, 0.20, 3.78)], [0.027, 0.027], 3, sides=6)
    for side in [-1, 1]:
        for fore in [-1, 1]:
            tube('Landing strut', [(side * 1.4, fore * 1.2, 0.95), (side * 1.9, fore * 1.6, 0.22)], [0.11, 0.15], 3, sides=8)
            box('Landing shoe', (side * 1.9, fore * 1.6, 0.13), (0.65, 0.57, 0.21), 0, bevel=0.03)
    tube('Hatch outer cylinder', [(0, -1.72, 1.49), (0, -2.06, 1.49)], [0.79, 0.79], 3, sides=24)
    ring('Hatch orange rim', (0, -2.085, 1.49), 0.76, 0.76, 0.075, 2, plane='XZ', segments=24)
    tube('Hatch plate', [(0, -2.08, 1.49), (0, -2.13, 1.49)], [0.64, 0.64], 0, sides=24)
    tube('Front observation window', [(0, -2.132, 1.74), (0, -2.16, 1.74)], [0.37, 0.37], 4, sides=24)
    ring('Front window cyan rim', (0, -2.18, 1.74), 0.37, 0.37, 0.021, 4, plane='XZ', segments=24)
    box('Hatch grip', (0.37, -2.18, 1.20), (0.12, 0.09, 0.30), 2, bevel=0.01)
    for side in [-1, 1]:
        ellipsoid('Side observation window', (side * 2.04, -0.13, 2.08), (0.15, 0.68, 0.46), 4, segments=16, rings=10)
        ring('Side illuminated trim', (side * 2.025, -0.13, 2.07), 0.5, 0.35, 0.025, 4, plane='YZ', segments=20)
    for step in range(3):
        box('Boarding step', (0, -2.05 - step * 0.30, 0.75 - step * 0.18), (1.1, 0.40, 0.10), 3, bevel=0.02)
    box('Roof solar panel', (-0.73, 0.20, 3.04), (0.75, 1.02, 0.09), 3, bevel=0.02)
    for y in [-0.10, 0.20, 0.50]:
        box('Solar cell stripe', (-0.73, y, 3.095), (0.65, 0.025, 0.014), 4)


def create_ruins():
    for side in [-1, 1]:
        for row in range(3):
            box('Ancient pillar block', (side * 3.15, 0, 0.48 + row * 0.86), (1.16, 1.38, 0.82), 1 if row % 2 else 0, bevel=0.05)
        box('Ancient pillar plinth', (side * 3.15, 0, 0.16), (1.6, 1.8, 0.32), 0, bevel=0.04)
        for z in [0.9, 1.32, 1.74, 2.16]:
            box('Bioluminescent glyph', (side * 3.15, -0.706, z), (0.12, 0.025, 0.25), 4, bevel=0.005)
    count = 11
    for index in range(count):
        a0 = index * math.pi / count + 0.018
        a1 = (index + 1) * math.pi / count - 0.018
        verts = []
        for y in [-0.64, 0.64]:
            for radius, angle in [(2.61, a0), (3.69, a0), (3.69, a1), (2.61, a1)]:
                verts.append((radius * math.cos(angle), y, 2.55 + radius * math.sin(angle)))
        faces = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
        uv = [(0, 0), (1, 0), (1, 1), (0, 1), (0, 0), (1, 0), (1, 1), (0, 1)]
        mesh('Arch voussoir', verts, faces, uv, slot=1 if index % 3 else 0, smooth=False)
    ellipsoid('Keystone luminous heart', (0, -0.68, 5.7), (0.22, 0.06, 0.34), 4, segments=12, rings=8)
    for side in [-1, 1]:
        box('Fallen foundation', (side * 3.72, -0.28, 0.15), (0.85, 1.2, 0.28), 0, bevel=0.03)


def create_shipwreck():
    hull_len = 7.2
    hull_rad = 1.65
    tube('Wreck forward hull', [(0, -hull_len * 0.5, 1.8), (0, hull_len * 0.4, 1.8)], [hull_rad, hull_rad], 0, sides=24)
    ellipsoid('Wreck bow dome', (0, hull_len * 0.4, 1.8), (hull_rad, hull_rad * 1.2, hull_rad), 0, segments=24, rings=14)
    ellipsoid('Bow observation port', (0, hull_len * 0.4 + 1.1, 1.8), (hull_rad * 0.55, hull_rad * 0.55, hull_rad * 0.55), 4, segments=20, rings=10)
    ring('Bow port ring', (0, hull_len * 0.4 + 1.05, 1.8), hull_rad * 0.56, hull_rad * 0.56, 0.09, 2, plane='XZ', segments=24)
    box('Conning tower sail', (0, 0.2, 3.8), (0.9, 2.6, 1.4), 0, bevel=0.08)
    tube('Sensor mast', [(0, 0.6, 4.5), (0, 0.6, 6.2)], [0.08, 0.05], 3, sides=8)
    ellipsoid('Emergency beacon top', (0, 0.6, 6.25), (0.14, 0.14, 0.18), 4, segments=12, rings=8)
    ring('Bridge hatch rim', (0, -0.4, 4.55), 0.42, 0.42, 0.07, 2, plane='XY', segments=16)
    tube('Bridge hatch cover', [(0, -0.4, 4.5), (0, -0.4, 4.6)], [0.4, 0.4], 3, sides=16)
    for y in [-2.6, -1.3, 0.0, 1.3, 2.4]:
        ring('Exoskeleton rib', (0, y, 1.8), hull_rad + 0.08, hull_rad + 0.08, 0.07, 2, plane='XZ', segments=28)
    for y in [-0.65, 0.85]:
        ring('Orange warning band', (0, y, 1.8), hull_rad + 0.03, hull_rad + 0.03, 0.05, 2, plane='XZ', segments=28)
    for z in [0.8, 1.4, 2.0, 2.6]:
        tube('Exposed bulkhead girder', [(1.4, -2.0, z), (1.4, -0.5, z)], [0.06, 0.06], 3, sides=6)
    box('Ruptured deck plating', (1.65, -1.2, 1.5), (0.2, 1.8, 1.2), 3, bevel=0.04)
    for side in [-1, 1]:
        tx = side * 1.55
        ty = -hull_len * 0.5 - 0.9
        tz = 1.8
        tube('Thruster strut', [(side * 1.2, -hull_len * 0.45, 1.8), (tx, ty, tz)], [0.12, 0.12], 3, sides=8)
        tube('Thruster duct', [(tx, ty - 0.7, tz), (tx, ty + 0.7, tz)], [0.65, 0.65], 0, sides=20)
        ring('Thruster duct rim front', (tx, ty + 0.7, tz), 0.65, 0.65, 0.06, 2, plane='XZ', segments=20)
        ring('Thruster duct rim rear', (tx, ty - 0.7, tz), 0.65, 0.65, 0.06, 3, plane='XZ', segments=20)
        ellipsoid('Propeller hub', (tx, ty, tz), (0.18, 0.25, 0.18), 6, segments=12, rings=8)
        for blade_angle in [0, 2.094, 4.189]:
            bx = tx + math.cos(blade_angle) * 0.38
            bz = tz + math.sin(blade_angle) * 0.38
            box('Propeller blade', (bx, ty, bz), (0.28, 0.04, 0.16), 6, bevel=0.02)
    for side in [-1, 1]:
        tube('Landing keel rail', [(side * 1.2, -3.2, 0.2), (side * 1.2, 2.8, 0.2)], [0.14, 0.14], 6, sides=8)
        for y in [-2.0, 0.2, 2.2]:
            tube('Keel riser', [(side * 1.2, y, 0.2), (side * 1.3, y, 1.0)], [0.11, 0.11], 3, sides=8)


def create_resource_titanium():
    ellipsoid('Ore host stone', (0, 0, 0.16), (0.34, 0.28, 0.23), 3, organic=0.25, segments=16, rings=10)
    for x, y, z, s in [(-0.12, -0.1, 0.27, 0.18), (0.15, -0.03, 0.28, 0.17), (0.02, 0.12, 0.38, 0.16), (-0.06, 0.06, 0.19, 0.2)]:
        ellipsoid('Exposed titanium nodule', (x, y, z), (s, s * 0.82, s * 0.92), 6, organic=0.2, segments=12, rings=8)
        tube('Crystalline facet', [(x - s * 0.4, y - s * 0.3, z + s * 0.4), (x + s * 0.4, y + s * 0.3, z + s * 0.4)], [0.015, 0.015], 1, sides=4)


def create_resource_copper():
    ellipsoid('Ore host stone', (0, 0, 0.16), (0.34, 0.28, 0.23), 3, organic=0.25, segments=16, rings=10)
    for x, y, z, s in [(-0.12, -0.1, 0.27, 0.18), (0.15, -0.03, 0.28, 0.17), (0.02, 0.12, 0.38, 0.16), (-0.06, 0.06, 0.19, 0.2)]:
        ellipsoid('Exposed copper nugget', (x, y, z), (s, s * 0.82, s * 0.92), 2, organic=0.25, segments=12, rings=8)
    tube('Branching copper vein 1', [(-0.15, -0.12, 0.15), (-0.08, -0.05, 0.28), (0.05, 0.1, 0.35)], [0.02, 0.025, 0.015], 2, sides=6)
    tube('Branching copper vein 2', [(0.12, -0.15, 0.12), (0.14, -0.03, 0.28), (0.1, 0.12, 0.32)], [0.018, 0.022, 0.012], 6, sides=6)


def create_resource_quartz():
    ellipsoid('Crystal matrix', (0, 0, 0.07), (0.32, 0.24, 0.12), 3, organic=0.2, segments=16, rings=10)
    for x, y, height, radius in [(0, 0, 0.69, 0.13), (-0.19, 0.04, 0.4, 0.11), (0.18, 0.04, 0.49, 0.1)]:
        tube('Quartz hexagonal body', [(x, y, 0.05), (x, y, height - 0.13)], [radius, radius], 1, sides=6)
        tube('Quartz crystal point', [(x, y, height - 0.13), (x, y, height)], [radius, 0.002], 4, sides=6)
        tube('Quartz core light', [(x, y, 0.08), (x, y, height - 0.1)], [radius * 0.35, radius * 0.2], 4, sides=4)


def create_resource_kelp():
    tube('Sample stalk', [(0, 0, 0.02), (0, 0, 0.26), (0, 0, 0.51)], [0.022, 0.018, 0.013], 0, sides=8)
    kelp_blade('Cutting lower blade', (0, 0, 0.18), 0.5, 0.36, 0.085)
    kelp_blade('Cutting upper blade', (0, 0, 0.29), 3.5, 0.33, 0.075)
    ellipsoid('Seed cluster bladder', (0, 0, 0.54), (0.13, 0.1, 0.18), 5, segments=14, rings=10)
    ring('Bladder calyx', (0, 0, 0.51), 0.05, 0.05, 0.014, 0, plane='XY', segments=12)
    tube('Bladder vein', [(0, 0.1, 0.54), (0, 0.1, 0.62)], [0.008, 0.003], 4, sides=4)


def create_weapon_axe():
    tube('Axe carbon shaft', [(0, -0.28, 0), (0, 0.12, 0)], [0.018, 0.016], 3, sides=12)
    for g in range(5):
        ring('Grip groove', (0, -0.24 + g * 0.045, 0), 0.018, 0.018, 0.003, 0, plane='XZ', segments=16)
    box('Pommel cap', (0, -0.30, 0), (0.034, 0.025, 0.034), 6, bevel=0.004)
    box('Axe head socket', (0, 0.12, 0.02), (0.044, 0.09, 0.058), 2, bevel=0.006)
    box('Energy cell', (0, 0.12, 0.02), (0.048, 0.05, 0.036), 4, bevel=0.004)
    mesh('Axe wide blade', [
        (-0.014, 0.08, 0.03), (0.014, 0.08, 0.03),
        (0.014, 0.16, 0.03), (-0.014, 0.16, 0.03),
        (-0.006, 0.04, 0.18), (0.006, 0.04, 0.18),
        (0.006, 0.22, 0.18), (-0.006, 0.22, 0.18)
    ], [
        (0, 1, 2, 3), (4, 5, 6, 7), (0, 1, 5, 4),
        (2, 3, 7, 6), (1, 2, 6, 5), (0, 3, 7, 4)
    ], [(0, 0)] * 8, slot=6, smooth=False)
    mesh('Axe glowing crescent edge', [
        (0.0, 0.02, 0.21), (0.0, 0.24, 0.21),
        (0.005, 0.04, 0.18), (-0.005, 0.04, 0.18),
        (0.005, 0.22, 0.18), (-0.005, 0.22, 0.18)
    ], [
        (0, 1, 4, 2), (0, 3, 5, 1)
    ], [(0, 0)] * 6, slot=4, smooth=False)
    mesh('Axe rear spike', [
        (-0.012, 0.10, -0.01), (0.012, 0.10, -0.01),
        (0.012, 0.14, -0.01), (-0.012, 0.14, -0.01),
        (0.0, 0.12, -0.09)
    ], [
        (0, 1, 2, 3), (0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4)
    ], [(0, 0)] * 5, slot=6, smooth=False)


def create_weapon_sonic():
    box('Sonic receiver body', (0, -0.08, 0), (0.075, 0.32, 0.095), 0, bevel=0.008)
    box('Sonic rear stock', (0, -0.32, -0.04), (0.055, 0.18, 0.11), 3, bevel=0.012)
    tube('Sonic pistol grip', [(0, -0.12, -0.04), (0, -0.22, -0.16)], [0.024, 0.020], 3, sides=8)
    box('Sonic trigger guard', (0, -0.14, -0.07), (0.015, 0.065, 0.045), 6, bevel=0.003)
    box('Sonic trigger', (0, -0.11, -0.05), (0.008, 0.018, 0.025), 4, bevel=0.002)
    tube('Sonic battery cell', [(0, -0.22, 0.02), (0, -0.34, 0.02)], [0.038, 0.035], 0, sides=12)
    ring('Sonic battery ring', (0, -0.28, 0.02), 0.041, 0.041, 0.005, 4, plane='XZ')
    tube('Sonic chamber casing', [(0, 0.08, 0.02), (0, 0.26, 0.02)], [0.048, 0.048], 6, sides=16)
    tube('Sonic resonance core', [(0, 0.09, 0.02), (0, 0.25, 0.02)], [0.036, 0.036], 4, sides=12)
    for r in range(3):
        y_pos = 0.26 + r * 0.08
        radius = 0.045 + r * 0.018
        ring('Sonic emitter ring', (0, y_pos, 0.02), radius, radius, 0.008, 2, plane='XZ', segments=20)
        ring('Sonic inner glow ring', (0, y_pos, 0.02), radius * 0.88, radius * 0.88, 0.003, 4, plane='XZ', segments=20)
    tube('Sonic muzzle cone', [(0, 0.40, 0.02), (0, 0.46, 0.02)], [0.055, 0.085], 2, sides=16)
    ellipsoid('Sonic focus lens', (0, 0.42, 0.02), (0.035, 0.035, 0.035), 4, segments=12, rings=8)
    box('Sonic sight rail', (0, -0.02, 0.09), (0.032, 0.22, 0.022), 6, bevel=0.004)
    box('Sonic holo housing', (0, 0.02, 0.12), (0.04, 0.04, 0.04), 0, bevel=0.004)
    ring('Sonic reticle ring', (0, 0.02, 0.15), 0.022, 0.022, 0.003, 4, plane='XZ', segments=16)


def normalize_parts(name):
    points = [v.co.copy() for obj in PARTS for v in obj.data.vertices]
    minimum = Vector([min(p[i] for p in points) for i in range(3)])
    maximum = Vector([max(p[i] for p in points) for i in range(3)])
    target_min, target_max = [Vector(p) for p in CONTRACT[name]['bounds_blender']]
    scale = Vector([(target_max[i] - target_min[i]) / max(.0001, maximum[i] - minimum[i]) for i in range(3)])
    def transform(p):
        return Vector([(p[i] - minimum[i]) * scale[i] + target_min[i] for i in range(3)])
    for obj in PARTS:
        for vertex in obj.data.vertices:
            vertex.co = transform(vertex.co)
    for key, (head, tail, parent) in list(BONES.items()):
        BONES[key] = (transform(head), transform(tail), parent)


def build_rig(name, obj):
    data = bpy.data.armatures.new(name + '_Skeleton')
    arm = bpy.data.objects.new(name + '_Rig', data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.ops.object.select_all(action='DESELECT')
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode='EDIT')
    for key, (head, tail, parent) in BONES.items():
        b = data.edit_bones.new(key)
        b.head, b.tail = head, tail
        if (tail - head).length < .001:
            b.tail.z += .01
        b.align_roll(Vector((0, 0, 1)))
        if parent:
            b.parent = data.edit_bones[parent]
    bpy.ops.object.mode_set(mode='OBJECT')
    mod = obj.modifiers.new('Deform skeleton', 'ARMATURE')
    mod.object = arm
    obj.parent = arm
    arm.animation_data_create()
    clips = ['swim', 'bite'] if name in ('fish_predator', 'fish_abyss') else ['swim']
    if name == 'jellyfish':
        clips = ['pulse']
    if name == 'crab':
        clips = ['walk', 'defend']
    for clip in clips:
        duration = 24 if clip == 'bite' else 60
        action = bpy.data.actions.new(name + '_' + clip)
        arm.animation_data.action = action
        for frame in range(1, duration + 2, 3):
            phase = (frame - 1) / duration * TAU
            for key, pb in arm.pose.bones.items():
                pb.rotation_mode = 'XYZ'
                pb.rotation_euler = (0, 0, 0)
                pb.scale = (1, 1, 1)
                if clip == 'bite':
                    if key == 'jaw':
                        pb.rotation_euler.x = -.55 * math.sin(phase / 2) ** 2
                elif clip == 'swim':
                    if key in ('body', 'spine', 'tail', 'tail_tip'):
                        i = ('body', 'spine', 'tail', 'tail_tip').index(key)
                        pb.rotation_euler.z = math.sin(phase - i * .7) * (.018 if i == 0 else .10 + i * .06)
                    if key.startswith(('fin_', 'wing_', 'flipper_')):
                        pb.rotation_euler.x = math.sin(phase) * .16
                    if key.startswith('arm_'):
                        i = int(key.split('_')[-1])
                        pb.rotation_euler.x = math.sin(phase - i * .5) * .13
                elif clip == 'pulse':
                    if key == 'bell':
                        pulse = math.sin(phase) * .09
                        pb.scale = (1 + pulse, 1 - pulse, 1 + pulse)
                    elif key.startswith('arm_'):
                        pb.rotation_euler.x = math.sin(phase - int(key.split('_')[-1]) * .6) * .12
                elif clip in ('walk', 'defend'):
                    if key.startswith('leg_'):
                        index = int(key.split('_')[1])
                        pb.rotation_euler.z = math.sin(phase + index * math.pi) * .22 if clip == 'walk' else .06
                    if key.startswith('claw_'):
                        pb.rotation_euler.x = -.55 + math.sin(phase) * .035 if clip == 'defend' else math.sin(phase) * .06
                pb.keyframe_insert(data_path='rotation_euler', frame=frame)
                if key == 'bell':
                    pb.keyframe_insert(data_path='scale', frame=frame)
        slot = arm.animation_data.action_slot
        track = arm.animation_data.nla_tracks.new()
        track.name = clip
        strip = track.strips.new(clip, 1, action)
        if hasattr(strip, 'action_slot'):
            strip.action_slot = slot
        track.mute = True
        arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.rotation_euler = (0, 0, 0)
        pb.scale = (1, 1, 1)
    return arm, clips


def finish_asset(name):
    normalize_parts(name)
    material, resolution = make_material(name)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in PARTS:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = PARTS[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.clear()
    obj.data.materials.append(material)
    obj.data.calc_loop_triangles()
    rig, clips = (build_rig(name, obj) if BONES else (None, []))
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    if rig:
        rig.select_set(True)
    bpy.context.view_layer.objects.active = rig or obj
    path = STAGING / 'models' / (name + '.glb')
    bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB', use_selection=True,
                              use_active_scene=True, export_yup=True, export_apply=False,
                              export_animations=bool(rig), export_animation_mode='NLA_TRACKS',
                              export_skins=True, export_def_bones=True, export_cameras=False,
                              export_lights=False, export_morph=False)
    MANIFEST[name] = {
        'file': 'assets/models/' + name + '.glb',
        'dimensions_blender_xyz': CONTRACT[name]['dimensions_blender_xyz'],
        'dimensions_godot_xyz': CONTRACT[name]['dimensions_godot_xyz'],
        'triangles': len(obj.data.loop_triangles), 'bones': len(BONES), 'animations': clips,
        'reference': 'assets/source/alien-ocean-v2/references/' + name + '.png',
        'source': 'assets/source/alien-ocean-v2/alien-ocean.blend',
        'texture_resolution': resolution, 'materials': 1,
        'textures': {kind: 'assets/source/alien-ocean-v2/textures/' + name + '_' + kind + '.png'
                     for kind in ('albedo', 'normal', 'orm', 'emission')},
    }
    ASSETS.append((name, rig or obj))
    PARTS.clear()
    BONES.clear()
    print('ASSET_READY ' + name + ' ' + json.dumps(MANIFEST[name]), flush=True)


def render_previews():
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_EEVEE'
    scene.render.resolution_x, scene.render.resolution_y = 960, 720
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.render.film_transparent = False
    scene.world = bpy.data.worlds.new('Neutral reference studio')
    scene.world.use_nodes = True
    bg = scene.world.node_tree.nodes.get('Background')
    bg.inputs[0].default_value, bg.inputs[1].default_value = (.075, .095, .11, 1), .8
    camera = bpy.data.objects.new('Preview Camera', bpy.data.cameras.new('Preview Camera'))
    scene.collection.objects.link(camera)
    scene.camera = camera
    camera.data.type = 'ORTHO'
    lamps = []
    for i, (energy, rgb) in enumerate([(1700, (.82, .93, 1)), (1400, (.4, .8, 1)), (1000, (1, .73, .51))]):
        data = bpy.data.lights.new('Studio_' + str(i), 'AREA')
        data.energy, data.color, data.shape, data.size = energy, rgb, 'DISK', 5
        obj = bpy.data.objects.new(data.name, data)
        scene.collection.objects.link(obj)
        lamps.append(obj)
    for _, root in ASSETS:
        root.hide_render = True
        for child in root.children_recursive:
            child.hide_render = True
    for name, root in ASSETS:
        root.hide_render = False
        for child in root.children_recursive:
            child.hide_render = False
        lo, hi = [Vector(p) for p in CONTRACT[name]['bounds_blender']]
        center = (lo + hi) * .5
        span = max(hi - lo)
        camera.location = center + Vector((1.1, -1.6, .9)) * span
        camera.rotation_euler = (center - camera.location).to_track_quat('-Z', 'Y').to_euler()
        camera.data.ortho_scale = span * 1.5
        camera.data.clip_start = .001
        for lamp, direction in zip(lamps, [(1, -1.2, 1.7), (-1, .8, 1), (-1, -1, .4)]):
            lamp.location = center + Vector(direction) * span
            lamp.rotation_euler = (center - lamp.location).to_track_quat('-Z', 'Y').to_euler()
            lamp.data.size = span * 1.5
            lamp.data.energy = 65 * span * span
        scene.render.filepath = str(SOURCE / 'previews' / (name + '.png'))
        bpy.ops.render.render(write_still=True)
        root.hide_render = True
        for child in root.children_recursive:
            child.hide_render = True
    for _, root in ASSETS:
        root.hide_render = False
        for child in root.children_recursive:
            child.hide_render = False
    for obj in lamps + [camera]:
        bpy.data.objects.remove(obj, do_unlink=True)


def main():
    global CURRENT
    parser = argparse.ArgumentParser()
    parser.add_argument('--assets', nargs='+', default=list(CONTRACT))
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
    for folder in (SOURCE / 'textures', SOURCE / 'previews', STAGING / 'models'):
        folder.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    bpy.context.scene.name = 'Alien ocean production assets'
    bpy.context.scene.render.fps = 30
    bpy.context.scene.unit_settings.system = 'METRIC'
    for name in args.assets:
        assert (SOURCE / 'references' / (name + '.png')).is_file(), 'Generate reference first: ' + name
        CURRENT = name
        random.seed(913 + sum(map(ord, name)))
        globals()['create_' + name]()
        finish_asset(name)
    render_previews()
    # Each asset occupies its own collection; the reference is a viewport-only Empty.
    for index, (name, root) in enumerate(ASSETS):
        collection = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(collection)
        for obj in [root] + list(root.children_recursive):
            for old in list(obj.users_collection):
                old.objects.unlink(obj)
            collection.objects.link(obj)
        image = bpy.data.images.load(str(SOURCE / 'references' / (name + '.png')))
        ref = bpy.data.objects.new(name + '_Reference', None)
        ref.empty_display_type, ref.data = 'IMAGE', image
        ref.empty_display_size = 5
        ref.hide_render = True
        collection.objects.link(ref)
        root.location.x += (index % 7) * 12
        root.location.y += (index // 7) * 14
        ref.location = root.location + Vector((0, 4, 3))
        ref.rotation_euler.x = math.pi / 2
    (STAGING / 'asset-manifest.json').write_text(json.dumps(MANIFEST, indent=2) + '\n')
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE / 'alien-ocean.blend'))
    print('BUILD_COMPLETE ' + str(len(MANIFEST)), flush=True)


if __name__ == '__main__':
    main()
