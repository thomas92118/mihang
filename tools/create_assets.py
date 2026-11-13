"""Original painterly ocean kit; deterministic, offline Blender production.

Build: blender --background --factory-startup --python tools/create_assets.py -- --assets coral kelp
Validate: Godot --headless --path . -s tests/asset_pipeline.gd -- --staging
Promote validated staging: blender --background --python tools/create_assets.py -- --promote
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
STAGING = ROOT / '.tools/art-staging'
SOURCE = STAGING / 'source'
CONTRACT = json.loads((ROOT / 'assets/source/asset-contract.json').read_text(encoding='utf-8'))
GENERATOR_VERSION = 'luminous-ocean-2'
TRIANGLE_BUDGETS = {
    'fish': 18000, 'fish_small': 14000, 'fish_predator': 26000, 'fish_abyss': 28000,
    'manta_ray': 24000, 'sea_turtle': 28000, 'squid': 28000, 'crab': 28000, 'jellyfish': 26000,
    'rock': 6500, 'kelp': 12000, 'crystal_spire': 12000,
    'coral': 14000, 'staghorn_coral': 16000, 'table_coral': 16000, 'tube_coral': 14000,
    'barrel_sponge': 16000, 'anemone': 15000, 'sea_fan': 16000, 'tubeworms': 14000,
    'starfish_urchin': 14000, 'brain_coral': 14000, 'giant_clam': 18000, 'sea_lily': 15000,
    'pod': 48000, 'ruins': 44000, 'shipwreck': 48000,
    'weapon_knife': 18000, 'weapon_axe': 18000, 'weapon_sonic': 22000,
    'resource_titanium': 8500, 'resource_copper': 8500, 'resource_quartz': 8500, 'resource_kelp': 8500,
}
for _key in CONTRACT:
    TRIANGLE_BUDGETS.setdefault(_key, 14000)
LUMINOUS_ASSETS = {'fish_small', 'fish_abyss', 'jellyfish', 'crystal_spire', 'resource_quartz',
                   'pod', 'ruins', 'shipwreck', 'weapon_knife', 'weapon_axe', 'weapon_sonic'}
CUSTOM_PAINTERS = {}
TAU = math.tau
PARTS = []
BONES = {}
ASSETS = []
MANIFEST = {}
CURRENT = ''

# Semantic atlas slots: pigment, belly/limestone, accent, crevice, tip/light,
# secondary pigment, metal, membrane/leaf. Ordinary benthos has zero emission.
PALETTES = {
 'fish_predator': ['285580','edf1f4','4c7da6','152436','c7dae6','6993b5','a9bac6','376891'],
 'fish': ['1a56b8', 'f5f1e4', 'f2c12e', '101d38', 'fff0a8', 'e8ad23', '6aaee0', '2878d6'],
 'fish_small': ['f08a38', 'fae7d2', 'f5be49', '1b2433', 'ffe8ad', 'e69cb8', 'c9d6dc', 'f5a842'],
 'fish_abyss': ['4b3666','dfd8e8','7b4e8a','1d132b','fff0be','63457d','9a90a8','6d4982'],
 'manta_ray': ['1c4c82', 'f1f5f8', '3d7db8', '142742', 'cbe3f0', '29629c', '9cb9cc', '2d6ca8'],
 'sea_turtle': ['6e6c3a','dfd09f','b5984b','363c25','d4c98e','8c8648','afa783','596136'],
 'squid': ['d45a47','f2e9e0','e68c6b','24272b','d6f0f2','b84b47','cbbab2','eb9e82'],
 'crab': ['c9522b','f0e2ce','de7d43','472217','f7ead9','9e3c22','d4bfa6','d86b38'],
 'jellyfish': ['b59ce3','f7d6a8','e3b8eb','4b356b','d2f4f7','f0be86','c8d8e4','cfa8e8'],
 'kelp': ['4d8a3d', 'b2c74c', '88ab41', '254d27', 'd7df73', '6c9c42', '7fa368', '74a844'],
 'resource_kelp': ['4d8a3d', 'b2c74c', '88ab41', '254d27', 'd7df73', '6c9c42', '7fa368', '74a844'],
 'coral': ['e67858', 'f5e4cb', 'f0a66e', '4a3338', 'faf0df', 'db6266', '9cb5ad', 'ee936e'],
 'staghorn_coral': ['e6855c', 'f7ead4', 'f2b57c', '4a3638', 'fbf2e3', 'd97566', '9eb5ac', 'f0a97a'],
 'table_coral': ['d95368', 'f5ddd4', 'ee8d5a', '472836', 'fae6dc', 'c7455e', '9cb0ac', 'e87668'],
 'brain_coral': ['d9b14e', 'ede0b4', 'c4983d', '45594d', 'f5e8a6', '9fb35c', 'a5b89e', 'e3c264'],
 'barrel_sponge': ['8f2d4b','e3aab6','b03e60','2b101b','f2c9d1','6e2039','b8959c','a33858'],
 'tube_coral': ['993858','e8b8c2','ba5270','331624','f5d4db','782945','bfa0a6','ad4766'],
 'anemone': ['cf5c68','f2d8c2','e8857a','4d2b38','fae6d4','a84862','c7aba8','e3767c'],
 'sea_fan': ['d95b8a', 'f5c2b0', 'e6829e', '3d294a', 'fad4be', '85448a', '9cb0b2', 'e06d96'],
 'tubeworms': ['ded2ba','f0e7d3','cf5246','4f4843','f5b59e','a63c38','c7bfb0','d96255'],
 'starfish_urchin': ['d45a3b','ebd4b0','d99b4e','3b2e3d','f2dec0','6e4668','c2b0a4','c46d4e'],
 'giant_clam': ['dfd5be','ede5d2','265878','524b3f','d9a84e','387594','cfc5b0','2e6788'],
 'sea_lily': ['b8a85c','ebe0b5','cfbe6d','4b4f3d','f5ecc4','7d9468','bfbda0','c7bd7b'],
 'rock': ['5c6e74', '9aa8a6', '788a8e', '2b3942', 'b8c4be', '677b80', '899899', '6d8085'],
 'crystal_spire': ['6fd4c2','dffaf3','4bb8ab','235c5e','b8fff2','4ea3a8','b2dbd6','85e3d3'],
 'pod': ['ebe3d0','f5efe2','c99a49','22354d','ffcf75','d95a43','9aa6ab','4b8996'],
 'ruins': ['d8ceb4', 'ece5d3', 'cfa046', '485e63', 'f5e3a4', 'b89244', '9ab3ab', '6ea399'],
 'shipwreck': ['558c84','b8afa0','a85834','1e2d33','96d4cc','8f7248','7d8f91','4d8e99'],
 'resource_titanium': ['738c96','d9ddd0','9eb0ad','344b54','c4d9d6','859c9e','c2cfd1','8ea8ad'],
 'resource_copper': ['5d8c78','d4ccb0','c7743e','384d43','dfcfb0','6fa188','d48a52','7eab93'],
 'resource_quartz': ['72d6c4','e4faf5','54bdb0','265e61','c2fff5','5aa8ad','bde0dc','8ce6d7'],
 'weapon_knife': ['25354a','ebe2ce','cba052','172230','6ce0d6','d95840','cfd6d9','3c6b78'],
 'weapon_axe': ['25354a','ebe2ce','cba052','172230','6ce0d6','d95840','cfd6d9','3c6b78'],
 'weapon_sonic': ['25354a','ebe2ce','cba052','172230','6ce0d6','d95840','cfd6d9','1d5963'],
}


def height_to_normal(relief, strength=2.4):
    dy, dx = np.gradient(relief.astype(np.float32))
    nx, ny = -dx * strength, -dy * strength
    length = np.sqrt(nx * nx + ny * ny + 1.0)
    out = np.empty((relief.shape[0], relief.shape[1], 3), dtype=np.float32)
    out[:, :, 0] = nx / length * 0.5 + 0.5
    out[:, :, 1] = ny / length * 0.5 + 0.5
    out[:, :, 2] = 0.5 + 0.5 / length
    return out


def color(hex_value):
    return np.array([int(hex_value[i:i + 2], 16) / 255 for i in (0, 2, 4)])


def _sample_reference_detail(name, h, w):
    ref_file = SOURCE / 'references' / (name + '.png')
    if not ref_file.is_file():
        return np.ones((h, w, 3), dtype=np.float32), np.zeros((h, w), dtype=np.float32)
    img = bpy.data.images.load(str(ref_file.resolve()))
    iw, ih = img.size
    raw = np.array(img.pixels[:], dtype=np.float32).reshape((ih, iw, 4))[:, :, :3]
    bpy.data.images.remove(img)
    y0, y1 = int(ih * 0.16), int(ih * 0.84)
    x0, x1 = int(iw * 0.16), int(iw * 0.84)
    sub = raw[max(0, y0):min(ih, y1), max(0, x0):min(iw, x1)]
    sy = np.linspace(0, sub.shape[0] - 1, h).astype(np.int32)
    sx = np.linspace(0, sub.shape[1] - 1, w).astype(np.int32)
    patch = sub[np.ix_(sy, sx)]
    wy = 0.5 - 0.5 * np.cos(np.linspace(0, TAU, h, dtype=np.float32))[:, None]
    wx = 0.5 - 0.5 * np.cos(np.linspace(0, TAU, w, dtype=np.float32))[None, :]
    w_mask = np.clip(wy * wx * 1.6, 0.0, 1.0)[:, :, None]
    tiled = patch * w_mask + patch[::-1, ::-1] * (1.0 - w_mask)
    luma = 0.299 * tiled[:, :, 0] + 0.587 * tiled[:, :, 1] + 0.114 * tiled[:, :, 2]
    valid = luma > 0.08
    mean_rgb = np.mean(tiled[valid], axis=0) if np.any(valid) else np.array([0.5, 0.5, 0.5], dtype=np.float32)
    color_mod = np.clip(tiled / np.maximum(mean_rgb[None, None, :], 0.12), 0.62, 1.42)
    blur = 0.25 * (np.roll(luma, 3, axis=0) + np.roll(luma, -3, axis=0) + np.roll(luma, 3, axis=1) + np.roll(luma, -3, axis=1))
    highpass = np.clip((luma - blur) * 2.4, -0.35, 0.35)
    return color_mod.astype(np.float32), highpass.astype(np.float32)


def image_from_array(name, pixels, data=False):
    path = (SOURCE / 'textures' / (name + '.png')).resolve()
    image = bpy.data.images.new(name, width=pixels.shape[1], height=pixels.shape[0], alpha=True)
    image.colorspace_settings.name = 'Non-Color' if data else 'sRGB'
    image.pixels.foreach_set(np.ascontiguousarray(pixels, dtype=np.float32).ravel())
    image.filepath_raw = str(path)
    image.file_format = 'PNG'
    image.save()
    return image


def make_material(name):
    # Pigment values stay independent of depth. Runtime lighting handles absorption.
    size = 1024
    w, h = size // 4, size // 2
    y, x = np.mgrid[0:h, 0:w].astype(np.float32)
    u, v = x / w, y / h
    cloud = np.sin(u * TAU * 1.7 + np.sin(v * TAU)) * np.cos(v * TAU * 1.3) * .5
    brush = np.sin(u * TAU * 18 + np.sin(v * TAU * 4)) * .012
    fine = np.random.default_rng(913 + sum(map(ord, name))).random((h, w), dtype=np.float32) - .5
    creature = name in {'fish', 'fish_small', 'fish_predator', 'fish_abyss', 'manta_ray', 'sea_turtle', 'squid', 'crab', 'jellyfish'}
    artificial = name.startswith('weapon') or name in {'pod', 'shipwreck'}
    mineral = name in {'rock', 'ruins', 'crystal_spire', 'resource_titanium', 'resource_copper', 'resource_quartz'}
    albedo = np.ones((size, size, 4), dtype=np.float32)
    normal = np.ones_like(albedo)
    orm = np.ones_like(albedo)
    emission = np.zeros_like(albedo); emission[:, :, 3] = 1
    for slot, pigment in enumerate(PALETTES[name]):
        row, col = slot // 4, slot % 4
        region = (slice(row*h, (row+1)*h), slice(col*w, (col+1)*w))
        base = color(pigment)[None, None, :]
        ramp = .88 + .14*v + .045*cloud + brush + fine*.012
        rgb = base * ramp[:, :, None]
        relief = cloud * .022 + brush * .25 + fine * .008
        if creature and slot == 0:
            if name == 'fish':
                stripes = np.maximum(0.0, np.sin((v * 7.5 + 0.18 * np.sin(u * TAU)) * TAU)) ** 4
                rgb = rgb * (1 - 0.72 * stripes[:, :, None]) + color(PALETTES[name][2])[None, None, :] * (0.72 * stripes[:, :, None])
                relief += stripes * 0.035
            elif name == 'sea_turtle':
                scute = np.abs(np.sin(u * TAU * 3.0 + 0.35 * np.cos(v * TAU * 2.0)) * np.cos(v * TAU * 3.5))
                border = (scute < 0.14).astype(np.float32)
                burst = np.maximum(0.0, np.cos((u * 6.0 % 1.0 - 0.5) * 9.0)) * scute
                rgb = rgb * (1 - 0.42 * burst[:, :, None]) + color(PALETTES[name][2])[None, None, :] * (0.42 * burst[:, :, None])
                rgb = rgb * (1 - 0.55 * border[:, :, None]) + color(PALETTES[name][1])[None, None, :] * (0.55 * border[:, :, None])
                relief += scute * 0.08 - border * 0.05
            elif name == 'squid':
                dots = ((np.sin(u * TAU * 22.0 + fine * 1.8) * np.cos(v * TAU * 28.0)) > 0.52).astype(np.float32)
                rgb = rgb * (1 - 0.45 * dots[:, :, None]) + color(PALETTES[name][5])[None, None, :] * (0.45 * dots[:, :, None])
                relief += dots * 0.02
            elif name == 'crab':
                bumps = np.maximum(0.0, np.sin(u * TAU * 11.0) * np.cos(v * TAU * 13.0)) ** 3
                rgb = rgb * (1 - 0.32 * bumps[:, :, None]) + color(PALETTES[name][4])[None, None, :] * (0.32 * bumps[:, :, None])
                relief += bumps * 0.09
            else:
                markings = np.maximum(0.0, np.sin(v * TAU * 3.5 + np.sin(u * TAU) * .65)) ** 5
                amount = markings[:, :, None] * (.14 if name == 'fish_predator' else .24)
                rgb = rgb*(1-amount) + color(PALETTES[name][5])[None,None,:]*amount
                scales = np.sin(u * TAU * 28.0) * np.cos(v * TAU * 34.0) * 0.018
                relief += scales
        if name == 'sea_turtle' and slot in (2, 7):
            scales = np.abs(np.sin(u * TAU * 7.0) * np.cos(v * TAU * 9.0))
            edge = (scales < 0.18).astype(np.float32)
            rgb = color(PALETTES[name][3])[None, None, :] * (1 - edge[:, :, None]) + color(PALETTES[name][1])[None, None, :] * edge[:, :, None]
            relief += scales * 0.06 - edge * 0.04
        if name in {'coral','staghorn_coral','table_coral','tube_coral','barrel_sponge','sea_fan'} and slot in (0,2,7):
            tip = (np.clip((v-.52)/.48,0,1)**1.6)[:,:,None] * .56
            rgb = rgb*(1-tip) + color(PALETTES[name][4])[None,None,:]*tip
            polyps = np.maximum(0.0, np.sin(u * TAU * 18.0) * np.cos(v * TAU * 20.0)) ** 4
            relief += polyps * 0.055
        if name == 'giant_clam' and slot in (2, 5, 7):
            marble = 0.5 + 0.5 * np.sin(u * TAU * 5.0 + 2.2 * np.sin(v * TAU * 3.0 + cloud * 3.0))
            gold = (marble > 0.68).astype(np.float32) * (marble - 0.68) / 0.32
            rgb = rgb * (1 - 0.75 * gold[:, :, None]) + color(PALETTES[name][4])[None, None, :] * (0.75 * gold[:, :, None])
            relief += marble * 0.04
        if mineral:
            strata = np.sin(v * TAU * 6 + .4*np.sin(u*TAU*2)) * .055
            rgb *= (1 + strata[:,:,None])
            relief += strata * 0.65
        if name == 'ruins' and slot in (0, 1):
            mortar_u = (np.abs((u * 4.0) % 1.0 - 0.5) > 0.46).astype(np.float32)
            mortar_v = (np.abs((v * 6.0) % 1.0 - 0.5) > 0.46).astype(np.float32)
            mortar = np.clip(mortar_u + mortar_v, 0.0, 1.0)
            rgb *= (1.0 - 0.16 * mortar[:, :, None])
            relief -= mortar * 0.06
        if name == 'shipwreck' and slot in (0, 2, 5):
            rust = np.clip(0.5 + 0.5 * np.sin(u * TAU * 3.1 + 1.9 * np.cos(v * TAU * 2.7)) + fine * 0.25, 0.0, 1.0)
            rust_mask = np.clip((rust - 0.52) * 2.2, 0.0, 1.0)[:, :, None]
            rgb = rgb * (1 - 0.55 * rust_mask) + color(PALETTES[name][2])[None, None, :] * (0.55 * rust_mask)
            relief += (rust - 0.5) * 0.08
        if name in {'pod', 'weapon_knife', 'weapon_axe', 'weapon_sonic'} and slot in (0, 1):
            panel = ((np.abs(u - 0.5) > 0.47) | (np.abs(v - 0.5) > 0.47)).astype(np.float32)
            rgb *= (1.0 - 0.10 * panel[:, :, None])
            relief -= panel * 0.035
        if name == 'weapon_sonic' and slot == 7:
            cx, cy = u - 0.5, v - 0.5
            rad = np.sqrt(cx * cx + cy * cy)
            rings_mask = (np.abs((rad * 10.0) % 1.0 - 0.5) > 0.42).astype(np.float32) * (rad < 0.46).astype(np.float32)
            sweep = np.maximum(0.0, np.cos(np.arctan2(cy, cx) - 1.1)) ** 8 * (rad < 0.46).astype(np.float32)
            grid_glow = np.clip(rings_mask * 0.65 + sweep * 0.85, 0.0, 1.0)[:, :, None]
            rgb = rgb * (1 - grid_glow) + color(PALETTES[name][4])[None, None, :] * grid_glow
            emission[region][:, :, :3] = color(PALETTES[name][4])[None, None, :] * grid_glow * 0.55
        albedo[region][:,:,:3] = np.clip(rgb,0,1)
        if name == 'jellyfish' and slot in (0,7):
            rib = 0.5 + 0.5 * np.cos(u * TAU * 16.0)
            albedo[region][:,:,3] = (.46 + .20 * rib) if slot == 0 else (.58 + .18 * v)
        elif name in {'pod', 'shipwreck', 'weapon_sonic'} and slot == 7:
            if name == 'pod':
                albedo[region][:, :, 3] = 0.28 + 0.08 * (1.0 - v)
            elif name == 'shipwreck':
                crack = (np.abs(np.sin(u * 19.0 + np.cos(v * 17.0) * 2.4)) > 0.965).astype(np.float32)
                albedo[region][:, :, :3] = np.clip(rgb + crack[:, :, None] * 0.32, 0.0, 1.0)
                albedo[region][:, :, 3] = np.clip(0.34 + crack * 0.42, 0.25, 0.82)
                relief -= crack * 0.06
            else:
                albedo[region][:, :, 3] = 0.72
        if name == 'brain_coral':
            relief += np.tanh(np.sin(u*TAU*7+1.8*np.sin(v*TAU*5))*np.cos(v*TAU*6)*2.4)*.14
        if name in {'barrel_sponge','tube_coral'}:
            flutes = np.cos(u * TAU * 14.0) * 0.09
            pores = -np.maximum(0.0, np.sin(u * TAU * 26.0) * np.cos(v * TAU * 28.0)) ** 4 * 0.08
            relief += flutes + pores
        normal[region][:, :, :3] = height_to_normal(relief, 2.8)
        orm[region][:,:,0] = np.clip(.97-np.abs(relief)*.32,.72,1)
        rough = .46 if creature else (.38 if artificial else .78)
        if name == 'jellyfish': rough = .22
        if name in {'crystal_spire','resource_quartz'}: rough = .20
        if name in {'pod', 'shipwreck', 'weapon_sonic'} and slot == 7: rough = .09
        if slot in (2, 6) and (artificial or name == 'ruins'): rough = .28
        orm[region][:,:,1] = np.clip(rough+cloud*.025,.2,.95)
        if name in {'pod', 'shipwreck', 'weapon_sonic'} and slot == 7:
            orm[region][:, :, 1] = 0.08
        metal = 0.0
        if artificial and slot == 6:
            metal = 0.78
        elif (artificial or name == 'ruins') and slot == 2:
            metal = 0.72
        elif name in {'resource_titanium', 'resource_copper'} and slot in (2, 6):
            metal = 0.58
        orm[region][:,:,2] = metal
        if name in LUMINOUS_ASSETS and slot == 4:
            energy = .45 if name in {'fish_abyss', 'jellyfish', 'pod'} else (.25 if creature else .38)
            emission[region][:,:,:3] = base*energy
    if name in CUSTOM_PAINTERS:
        CUSTOM_PAINTERS[name](albedo, normal, orm, emission)
    maps = {key:image_from_array(name+'_'+key, values, key in ('normal','orm'))
        for key,values in [('albedo',albedo),('normal',normal),('orm',orm),('emission',emission)]}

    def _build_gltf_mat(mat_name, blended=False):
        mat = bpy.data.materials.new(mat_name)
        mat.use_nodes = True
        mat.use_backface_culling = False
        nodes, links = mat.node_tree.nodes, mat.node_tree.links
        bsdf = next(n for n in nodes if n.type == 'BSDF_PRINCIPLED')
        for key, img in maps.items():
            tex = nodes.new('ShaderNodeTexImage')
            tex.name = key
            tex.image = img
            tex.interpolation = 'Linear'
        links.new(nodes['albedo'].outputs['Color'], bsdf.inputs['Base Color'])
        if blended:
            links.new(nodes['albedo'].outputs['Alpha'], bsdf.inputs['Alpha'])
            mat.surface_render_method = 'BLENDED'
        nmap = nodes.new('ShaderNodeNormalMap')
        links.new(nodes['normal'].outputs['Color'], nmap.inputs['Color'])
        links.new(nmap.outputs['Normal'], bsdf.inputs['Normal'])
        separate = nodes.new('ShaderNodeSeparateColor')
        links.new(nodes['orm'].outputs['Color'], separate.inputs['Color'])
        links.new(separate.outputs['Green'], bsdf.inputs['Roughness'])
        links.new(separate.outputs['Blue'], bsdf.inputs['Metallic'])
        links.new(nodes['emission'].outputs['Color'], bsdf.inputs['Emission Color'])
        bsdf.inputs['Emission Strength'].default_value = 1.0
        group = bpy.data.node_groups.get('glTF Material Output')
        if group is None:
            group = bpy.data.node_groups.new('glTF Material Output', 'ShaderNodeTree')
            group.interface.new_socket(name='Occlusion', in_out='INPUT', socket_type='NodeSocketFloat')
        ao = nodes.new('ShaderNodeGroup')
        ao.node_tree = group
        links.new(separate.outputs['Red'], ao.inputs['Occlusion'])
        return mat

    mat = _build_gltf_mat(name + '_Pigment', blended=(name == 'jellyfish'))
    return mat, size, _build_gltf_mat


def mesh(name, vertices, faces, uv, slot=0, bone=None, face_slots=None, smooth=True, glass=False):
    data = bpy.data.meshes.new(CURRENT + '_' + name)
    data.from_pydata(vertices, [], faces)
    data.update()
    obj = bpy.data.objects.new(CURRENT + '_' + name, data)
    if glass:
        obj['is_glass'] = True
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


def ellipsoid(name, center, scale, slot=0, bone_name=None, segments=20, rings=12, organic=0, glass=False):
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
    return mesh(name, verts, faces, uv, slot, bone_name, glass=glass)


def tube(name, points, radii, slot=0, bone_name=None, sides=10, glass=False):
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
    return mesh(name, verts, faces, uv, slot, bone_name, glass=glass)


def ring(name, center, rx, ry, thickness, slot=2, bone_name=None, plane='XY', segments=24, sides=8, glass=False):
    pts = []
    for i in range(segments + 1):
        a = i / segments * TAU
        off = {'XY': (rx * math.cos(a), ry * math.sin(a), 0),
               'XZ': (rx * math.cos(a), 0, ry * math.sin(a)),
               'YZ': (0, rx * math.cos(a), ry * math.sin(a))}[plane]
        pts.append(Vector(center) + Vector(off))
    return tube(name, pts, [thickness] * len(pts), slot, bone_name, sides, glass=glass)


def membrane(name, a, b, tip, slot=7, bone_name=None, bulge=.06, rows=9, columns=6, glass=False):
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
    return mesh(name, verts, faces, uv, slot, bone_name, glass=glass)


def plate(name, outline, thickness, slot=6, bone_name=None, glass=False):
    # Extruded YZ outline: preserves the first-person weapon grip convention.
    verts = [(side * thickness / 2, y, z) for side in (-1, 1) for y, z in outline]
    n = len(outline)
    ylo, yhi = min(p[0] for p in outline), max(p[0] for p in outline)
    zlo, zhi = min(p[1] for p in outline), max(p[1] for p in outline)
    uv = [((p[1] - ylo) / max(.001, yhi - ylo), (p[2] - zlo) / max(.001, zhi - zlo)) for p in verts]
    faces = [tuple(range(n - 1, -1, -1)), tuple(range(n, n * 2))]
    faces.extend((i, (i + 1) % n, (i + 1) % n + n, i + n) for i in range(n))
    obj = mesh(name, verts, faces, uv, slot, bone_name, glass=glass)
    for p in obj.data.polygons:
        p.use_smooth = False
    bevel = obj.modifiers.new('Machined edge radius', 'BEVEL')
    bevel.width, bevel.segments = thickness * .12, 2
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    return obj


def box(name, location, scale, slot=0, bone_name=None, bevel=0.0, glass=False):
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
    obj = mesh(name, verts, faces, uv, slot, bone_name, smooth=False, glass=glass)
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


def spindle(name, profile, slot=0, segments=24, bone_name=None, glass=False):
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
    return mesh(name, verts, faces, uv, slot, bone_name, slots, glass=glass)


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
    direction = Vector((math.cos(angle), math.sin(angle), .12))
    cross = Vector((-math.sin(angle), math.cos(angle), 0))
    verts, uv, faces = [], [], []
    # Budget the ribbon itself, rather than decimating dense ruffles into flags.
    # Eleven cross-sections retain a tapered tip and an unbroken curved silhouette.
    for i in range(11):
        t = i / 10
        for j in range(3):
            v = j - 1
            envelope = max(.001, math.sin(math.pi * t)) ** .82
            p = at + direction * t * length + cross * (v * width * .64 * envelope + math.sin(t * math.pi) * length * .10)
            p.z += math.sin(t * math.pi * 1.45) * length * .24 + (1 - abs(v)) * .025 * envelope
            verts.append(p)
            uv.append((j / 2, t))
    for i in range(10):
        for j in range(2):
            n = i * 3 + j
            faces.append((n, n + 1, n + 4, n + 3))
    mesh(name, verts, faces, uv, 7, bone_name)


def create_kelp():
    for r in range(8):
        a = r * TAU / 8
        tube('Holdfast root', [(0, 0, .23), (.2 * math.cos(a), .2 * math.sin(a), .08), (.42 * math.cos(a + .25), .42 * math.sin(a + .25), .015)], [.07, .045, .003], 3, sides=6)
    for stem in range(3):
        angle = stem * 2.3
        height = 4.8 - stem * .54
        points = [(math.sin(i / 12 * 2.9 + angle) * (i / 12) ** 1.15 * .68, math.cos(i / 12 * 2.3 + angle) * (i / 12) ** 1.15 * .56, height * i / 12 + .1) for i in range(13)]
        tube('Flexible stipe', points, [.062 * (1 - i / 18) for i in range(13)], 0, sides=7)
        for i in (2, 4, 6, 8, 10, 11):
            point = Vector(points[i])
            a = angle + i * 1.85
            kelp_blade('Ruffled blade', point, a, 1.52 * (1 - i / 36), .36)
            if i in (4, 8, 11):
                ellipsoid('Amber gas bladder', point + Vector((0, 0, .05)), (.085, .09, .14), 5, segments=8, rings=5)


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
    body_obj = spindle('Scaled fusiform body', profile, segments=16, bone_name=body_weights)
    uv_layer = body_obj.data.uv_layers.active.data
    for poly in body_obj.data.polygons:
        center_z = sum(body_obj.data.vertices[vi].co.z for vi in poly.vertices) / len(poly.vertices)
        center_y = sum(body_obj.data.vertices[vi].co.y for vi in poly.vertices) / len(poly.vertices)
        target_slot = 1 if center_z < -0.06 else (5 if abs(center_z - 0.08) < 0.09 and center_y < 1.1 else None)
        if target_slot is not None:
            u0, v0 = (target_slot % 4) * 0.25 + 0.04, (target_slot // 4) * 0.5 + 0.08
            for li in poly.loop_indices:
                uv_layer[li].uv = (u0 + (uv_layer[li].uv.x % 0.25) * 0.68, v0 + (uv_layer[li].uv.y % 0.5) * 0.68)
    ellipsoid('Armored forehead', (0, -.83, .17), (.25, .35, .3), 0 if small else 2, 'body', 12, 8)
    for s in (-1, 1):
        ellipsoid('Recessed eye', (s * .235, -.91, .13), (.025, .077, .071), 3, 'body', 12, 7)
        ellipsoid('Eye shine', (s * .252, -.93, .155), (.012, .026, .024), 4, 'body', 8, 5)
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
        ellipsoid('Eye shine', (s * .59, -.74, .095), (.018, .025, .018), 4, 'body', 8, 5)
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
        ellipsoid('Eye shine', (s * .185, -1.50, .155), (.010, .020, .014), 4, 'body', 8, 5)
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
        ellipsoid('Eye shine', (s * .30, .23, .085), (.025, .042, .035), 4, 'body', 8, 5)
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
        ellipsoid('Eye shine', (s * .33, -.69, .625), (.024, .026, .022), 4, 'body', 8, 5)
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
    ellipsoid('Calcified holdfast', (0, 0, 0.15), (0.68, 0.58, 0.24), 1, organic=0.28, segments=14, rings=8)
    for r_idx in range(5):
        ra = r_idx * TAU / 5.0 + 0.3
        ellipsoid('Encrusting reef lobe', (math.cos(ra) * 0.48, math.sin(ra) * 0.42, 0.12), (0.24, 0.20, 0.14), 3, organic=0.22, segments=10, rings=6)
    angles = [0.0, 0.85, 1.8, 2.7, 3.7, 4.6, 5.5]
    for index, angle in enumerate(angles):
        height = 1.4 + (index % 3) * 0.38
        base = Vector((0, 0, 0.18))
        mid1 = Vector((0.20 * math.cos(angle - 0.12), 0.20 * math.sin(angle - 0.12), height * 0.28))
        elbow = Vector((0.38 * math.cos(angle), 0.38 * math.sin(angle), height * 0.52))
        mid2 = Vector((0.62 * math.cos(angle + 0.08), 0.62 * math.sin(angle + 0.08), height * 0.78))
        top = Vector((0.82 * math.cos(angle), 0.82 * math.sin(angle), height))
        tube('Coral stem curved', [base, mid1, elbow, mid2, top], [0.145, 0.122, 0.104, 0.082, 0.062], 0, sides=8)
        ellipsoid('Coral bud', top, (0.078, 0.078, 0.096), 4, segments=10, rings=6)
        for sign in [-1, 1]:
            start = elbow.lerp(top, 0.45)
            ctrl = start + Vector((0.24 * math.cos(angle + sign * 0.52), 0.24 * math.sin(angle + sign * 0.52), 0.18))
            end = start + Vector((0.48 * math.cos(angle + sign * 0.72), 0.48 * math.sin(angle + sign * 0.72), 0.38))
            tube('Coral fork', [start, ctrl, end], [0.082, 0.060, 0.042], 2, sides=7)
            ellipsoid('Coral luminous bud', end, (0.058, 0.058, 0.078), 4, segments=8, rings=5)


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
    ellipsoid('Anemone pedal disc', (0, 0, 0.12), (0.8, 0.8, 0.22), 3, organic=0.15, segments=14, rings=7)
    tube('Fleshy column', [(0, 0, 0.18), (0, 0, 0.62), (0, 0, 0.95)], [0.66, 0.54, 0.72], 0, sides=14)
    ellipsoid('Oral disc center', (0, 0, 0.96), (0.68, 0.68, 0.14), 1, segments=14, rings=6)
    ellipsoid('Mouth slit', (0, 0, 1.01), (0.2, 0.08, 0.06), 2, segments=8, rings=5)
    # Inner whorl tentacles
    for i in range(9):
        ang = i * TAU / 9 + 0.15
        p0 = Vector((math.cos(ang) * 0.38, math.sin(ang) * 0.38, 0.95))
        p1 = Vector((math.cos(ang + 0.22) * 0.60, math.sin(ang + 0.22) * 0.60, 1.38 + (i % 3) * 0.14))
        p2 = Vector((math.cos(ang + 0.08) * 0.76, math.sin(ang + 0.08) * 0.76, 1.68 + (i % 2) * 0.17))
        tube('Inner tentacle', [p0, p1, p2], [0.095, 0.068, 0.044], 7, sides=6)
        ellipsoid('Inner tentacle tip', p2, (0.062, 0.062, 0.074), 4, segments=8, rings=5)
    # Outer whorl drooping tentacles
    for i in range(12):
        ang = i * TAU / 12
        p0 = Vector((math.cos(ang) * 0.62, math.sin(ang) * 0.62, 0.90))
        p1 = Vector((math.cos(ang + 0.18) * 1.04, math.sin(ang + 0.18) * 1.04, 1.22))
        p2 = Vector((math.cos(ang + 0.3) * 1.35, math.sin(ang + 0.3) * 1.35, 0.85 - (i % 3) * 0.12))
        tube('Outer tentacle', [p0, p1, p2], [0.102, 0.072, 0.046], 0, sides=6)
        ellipsoid('Outer tentacle tip', p2, (0.062, 0.062, 0.076), 4, segments=8, rings=5)


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


def _labyrinth_dome(name, center, scale, rings=40, segments=64, seed_phase=0.0, slot=0):
    verts, uv, faces = [], [], []
    cx, cy, cz = center
    rx, ry, rz = scale
    for i in range(rings + 1):
        v = i / rings
        theta = 0.001 + (math.pi * 0.56) * v
        for j in range(segments + 1):
            u = j / segments
            phi = TAU * u
            nx = math.sin(theta) * math.cos(phi)
            ny = math.sin(theta) * math.sin(phi)
            nz = math.cos(theta)
            # Match exact labyrinth wave field in make_material('brain_coral') so 3D ridges align with texture ridges!
            lab = math.sin(u * TAU * 7.0 + 1.85 * math.sin(v * TAU * 5.0)) * math.cos(v * TAU * 6.0 - 1.65 * math.cos(u * TAU * 5.0))
            g = math.tanh(lab * 2.6)
            septa_rib = 0.012 * math.sin(u * TAU * 64.0 + lab * 2.5) * max(0.0, g)
            disp = (0.082 * g + septa_rib) if g >= 0.0 else (0.052 * g)
            fade = math.sin(min(math.pi, v * math.pi)) ** 0.55
            r_mod = 1.0 + disp * fade
            px = cx + nx * rx * r_mod
            py = cy + ny * ry * r_mod
            pz = max(0.02, cz + nz * rz * r_mod)
            verts.append((px, py, pz))
            uv.append((u, v))
    for i in range(rings):
        for j in range(segments):
            a = i * (segments + 1) + j
            faces.append((a, a + 1, a + segments + 2, a + segments + 1))
    return mesh(name, verts, faces, uv, slot=slot, smooth=True)


def create_brain_coral():
    ellipsoid('Reef limestone plinth', (0, 0, 0.16), (1.08, 1.04, 0.22), 3, organic=0.14, segments=28, rings=14)
    for k in range(8):
        ang = k * TAU / 8.0 + 0.2
        ellipsoid('Coralline crust nodule', (math.cos(ang) * 0.84, math.sin(ang) * 0.80, 0.15), (0.26, 0.22, 0.14), 5 if k % 2 == 0 else 3, organic=0.14, segments=16, rings=10)
    _labyrinth_dome('Primary brain coral hemisphere', (0.02, 0.02, 0.22), (0.98, 0.94, 0.94), rings=16, segments=24, seed_phase=0.4, slot=0)
    _labyrinth_dome('Anterior satellite brain lobe', (-0.56, -0.42, 0.16), (0.48, 0.44, 0.46), rings=10, segments=16, seed_phase=2.1, slot=2)
    _labyrinth_dome('Posterior satellite brain lobe', (0.54, -0.40, 0.15), (0.42, 0.40, 0.40), rings=10, segments=16, seed_phase=4.2, slot=0)


def create_staghorn_coral():
    ellipsoid('Calcified reef base', (0, 0, 0.15), (0.80, 0.76, 0.20), 3, organic=0.12, segments=24, rings=12)
    ellipsoid('Acropora basal plate', (0, 0, 0.24), (0.56, 0.52, 0.16), 1, organic=0.12, segments=20, rings=10)
    branch_specs = [
        (0.0, 0.22, 1.95, 0.11), (0.52, 0.46, 1.82, 0.10), (1.08, 0.34, 1.88, 0.105),
        (1.62, 0.50, 1.74, 0.095), (2.18, 0.36, 1.92, 0.105), (2.75, 0.48, 1.78, 0.095),
        (3.30, 0.30, 1.90, 0.105), (3.88, 0.52, 1.72, 0.095), (4.42, 0.38, 1.86, 0.10),
        (5.02, 0.48, 1.76, 0.095), (5.60, 0.34, 1.88, 0.10), (0.28, 0.68, 1.38, 0.085),
        (1.35, 0.72, 1.34, 0.085), (2.45, 0.68, 1.40, 0.085), (3.58, 0.70, 1.32, 0.085),
        (4.75, 0.66, 1.36, 0.085),
    ]
    for b_idx, (az, tilt, length, base_r) in enumerate(branch_specs):
        pts = []
        radii = []
        steps = 6
        for s in range(steps):
            t = s / (steps - 1)
            curve_az = az + 0.18 * math.sin(t * math.pi + b_idx)
            r_horiz = math.sin(tilt) * length * (t ** 0.88)
            z_pos = 0.24 + math.cos(tilt) * length * t + 0.12 * math.sin(t * math.pi)
            pts.append(Vector((math.cos(curve_az) * r_horiz, math.sin(curve_az) * r_horiz, z_pos)))
            radii.append(base_r * (1.0 - 0.66 * t))
        tube('Staghorn main antler', pts, radii, 0 if b_idx % 2 == 0 else 2, sides=9)
        ellipsoid('Axial polyp crown', pts[-1], (0.048, 0.048, 0.068), 4, segments=10, rings=6)
        for sign in (-1, 1):
            f_start = pts[2].lerp(pts[3], 0.4) if sign < 0 else pts[3].lerp(pts[4], 0.3)
            f_az = az + sign * (0.48 + 0.08 * (b_idx % 3))
            f_len = length * (0.42 if sign < 0 else 0.34)
            f_mid = f_start + Vector((math.cos(f_az) * f_len * 0.48, math.sin(f_az) * f_len * 0.48, f_len * 0.46))
            f_tip = f_start + Vector((math.cos(f_az) * f_len * 0.88, math.sin(f_az) * f_len * 0.88, f_len * 0.86))
            tube('Staghorn secondary tine', [f_start, f_mid, f_tip], [base_r * 0.58, base_r * 0.40, 0.024], 5 if (b_idx + sign) % 2 == 0 else 0, sides=7)
            ellipsoid('Secondary axial polyp', f_tip, (0.038, 0.038, 0.054), 4, segments=8, rings=5)
        for c_i in range(5):
            t_c = (c_i + 1) / 6.0
            seg_idx = min(steps - 2, int(t_c * (steps - 1)))
            local_t = t_c * (steps - 1) - seg_idx
            c_base = pts[seg_idx].lerp(pts[seg_idx + 1], local_t)
            c_ang = az + c_i * 2.2
            c_tip = c_base + Vector((math.cos(c_ang) * 0.075, math.sin(c_ang) * 0.075, 0.055))
            tube('Radial corallite tube', [c_base, c_tip], [0.026, 0.015], 2, sides=5)
            ellipsoid('Radial polyp tip', c_tip, (0.019, 0.019, 0.022), 4, segments=6, rings=4)


def _table_coral_plate(name, center, rx, ry, thickness, tier_idx):
    cx, cy, cz = center
    rings = 10
    segs = 44
    verts, uv, faces, face_slots = [], [], [], []
    for is_bottom in (False, True):
        for r_i in range(rings + 1):
            u = r_i / rings
            for s_i in range(segs + 1):
                phi = TAU * s_i / segs
                scallop = 1.0 + 0.065 * math.sin(phi * 9.0 + tier_idx * 1.4) + 0.035 * math.cos(phi * 17.0)
                rad_x = rx * u * scallop
                rad_y = ry * u * scallop
                dish = 0.11 * (u ** 1.5) + 0.018 * math.sin(phi * 9.0) * (u ** 2)
                rib = 0.022 * abs(math.cos(phi * 22.0)) * u if is_bottom else 0.014 * math.sin(u * TAU * 6.0)
                z_off = (dish - thickness * (1.0 - 0.78 * u) - rib) if is_bottom else (dish + rib)
                verts.append((cx + rad_x * math.cos(phi), cy + rad_y * math.sin(phi), cz + z_off))
                uv.append((s_i / segs, u))
    stride = (rings + 1) * (segs + 1)
    for half in (0, 1):
        base_v = half * stride
        for r_i in range(rings):
            for s_i in range(segs):
                a = base_v + r_i * (segs + 1) + s_i
                if half == 0:
                    faces.append((a, a + 1, a + segs + 2, a + segs + 1))
                    face_slots.append(0)
                else:
                    faces.append((a, a + segs + 1, a + segs + 2, a + 1))
                    face_slots.append(1)
    top_rim = rings * (segs + 1)
    bot_rim = stride + rings * (segs + 1)
    for s_i in range(segs):
        faces.append((top_rim + s_i, bot_rim + s_i, bot_rim + s_i + 1, top_rim + s_i + 1))
        face_slots.append(4)
    mesh(name, verts, faces, uv, slot=0, face_slots=face_slots, smooth=True)


def create_table_coral():
    ellipsoid('Reef anchor rock', (0, 0, 0.14), (0.92, 0.88, 0.20), 3, organic=0.12, segments=24, rings=12)
    tube('Calcified table pedestal', [(0, 0, 0.14), (0.04, -0.03, 0.55), (0.0, 0.0, 1.18)], [0.36, 0.26, 0.18], 1, sides=14)
    for b in range(6):
        ba = b * TAU / 6.0
        tube('Pedestal root buttress', [(math.cos(ba) * 0.58, math.sin(ba) * 0.58, 0.12), (math.cos(ba) * 0.24, math.sin(ba) * 0.24, 0.52)], [0.09, 0.05], 1, sides=7)
    tiers = [
        ((0.06, -0.05, 0.46), 1.32, 1.24, 0.045, 0),
        ((-0.08, 0.06, 0.78), 1.06, 1.00, 0.040, 1),
        ((0.04, 0.02, 1.08), 0.80, 0.76, 0.036, 2),
        ((0.0, 0.0, 1.36), 0.52, 0.50, 0.032, 3),
    ]
    for center, rx, ry, thick, idx in tiers:
        _table_coral_plate('Acropora table tier ' + str(idx), center, rx, ry, thick, idx)


def _fluted_sponge_barrel(name, base_xy, height, outer_r, inner_r, flutes=16, lean=(0.0, 0.0)):
    bx, by = base_xy
    lx, ly = lean
    rings = 8
    segs = 28
    flutes = max(7, min(flutes, 9))
    verts, uv, faces, face_slots = [], [], [], []
    # Outer wall (0..rings) + Inner cavity wall (0..rings)
    for wall in ('outer', 'inner'):
        for i in range(rings + 1):
            t = i / rings
            profile = math.sin(t * math.pi * 0.78 + 0.22) ** 0.55
            cx = bx + lx * (t ** 1.4) * height
            cy = by + ly * (t ** 1.4) * height
            for j in range(segs + 1):
                phi = TAU * j / segs
                if wall == 'outer':
                    flute_wave = (0.5 + 0.5 * math.cos(phi * flutes + math.sin(t * 6.0) * 0.35)) ** 2.2
                    crag = 0.045 * math.sin(t * TAU * 7.0 + phi * 3.0)
                    r = outer_r * profile * (0.84 + 0.22 * flute_wave + crag)
                    z = 0.14 + t * (height - 0.14) + 0.045 * math.sin(phi * 7.0) * (t ** 2)
                else:
                    r = inner_r * (0.45 + 0.55 * t) * (1.0 + 0.04 * math.cos(phi * flutes))
                    z = (0.32 * height) + (1.0 - t) * (height * 0.68 - 0.14) + 0.045 * math.sin(phi * 7.0) * ((1.0 - t) ** 2)
                verts.append((cx + r * math.cos(phi), cy + r * math.sin(phi), z))
                uv.append((j / segs, t if wall == 'outer' else (1.0 - t * 0.75)))
    stride = (rings + 1) * (segs + 1)
    for i in range(rings):
        for j in range(segs):
            a = i * (segs + 1) + j
            faces.append((a, a + 1, a + segs + 2, a + segs + 1))
            face_slots.append(0)
            b = stride + i * (segs + 1) + j
            faces.append((b, b + segs + 1, b + segs + 2, b + 1))
            face_slots.append(5)
    top_outer = rings * (segs + 1)
    top_inner = stride
    for j in range(segs):
        faces.append((top_outer + j, top_outer + j + 1, top_inner + j + 1, top_inner + j))
        face_slots.append(4)
    return mesh(name, verts, faces, uv, slot=0, face_slots=face_slots, smooth=True)


def create_barrel_sponge():
    ellipsoid('Sponge reef substrate', (0, 0, 0.15), (0.94, 0.90, 0.20), 3, organic=0.12, segments=24, rings=12)
    _fluted_sponge_barrel('Giant barrel sponge', (0.04, -0.02), 2.38, 0.88, 0.52, flutes=18, lean=(0.03, 0.02))
    _fluted_sponge_barrel('Side barrel sponge L', (-0.64, 0.34), 1.32, 0.42, 0.24, flutes=12, lean=(-0.12, 0.08))
    _fluted_sponge_barrel('Side barrel sponge R', (0.62, -0.36), 1.08, 0.36, 0.20, flutes=11, lean=(0.14, -0.08))


def _clam_valve(name, side_sign):
    u_steps = 32
    v_steps = 18
    verts, uv, faces, face_slots = [], [], [], []
    for layer in ('outer', 'inner'):
        for iv in range(v_steps + 1):
            v = iv / v_steps
            for iu in range(u_steps + 1):
                u = iu / u_steps
                theta = (u - 0.5) * math.pi * 0.88
                rib_wave = math.cos(u * math.pi * 7.0)
                flute = (0.095 * rib_wave if layer == 'outer' else 0.038 * rib_wave) * (v ** 1.15)
                thick = 0.0 if layer == 'outer' else -0.065 * (1.0 - 0.35 * v)
                px = math.sin(theta) * (1.08 * (v ** 0.72))
                bowl_out = 0.10 + 0.64 * math.sin(v * math.pi * 0.72) + flute + thick
                py = side_sign * max(0.04, bowl_out)
                pz = 0.18 + 0.92 * (v ** 0.86) * math.cos(theta * 0.55) + 0.075 * rib_wave * (v ** 1.8)
                verts.append((px, py, max(0.05, pz)))
                uv.append((u, v))
    stride = (v_steps + 1) * (u_steps + 1)
    for iv in range(v_steps):
        for iu in range(u_steps):
            a = iv * (u_steps + 1) + iu
            b = stride + iv * (u_steps + 1) + iu
            if side_sign > 0:
                faces.append((a, a + 1, a + u_steps + 2, a + u_steps + 1))
                faces.append((b, b + u_steps + 1, b + u_steps + 2, b + 1))
            else:
                faces.append((a, a + u_steps + 1, a + u_steps + 2, a + 1))
                faces.append((b, b + 1, b + u_steps + 2, b + u_steps + 1))
            face_slots.append(0)
            face_slots.append(6)
    rim_o = v_steps * (u_steps + 1)
    rim_i = stride + v_steps * (u_steps + 1)
    for iu in range(u_steps):
        faces.append((rim_o + iu, rim_i + iu, rim_i + iu + 1, rim_o + iu + 1))
        face_slots.append(1)
    mesh(name, verts, faces, uv, slot=1, face_slots=face_slots, smooth=True)
    # Raised calcified scute scales along the major ribs
    for rib_idx in range(0, 8, 2):
        u = (rib_idx + 0.5) / 7.0
        if u < 0.08 or u > 0.92:
            continue
        theta = (u - 0.5) * math.pi * 0.88
        for v_sc in (0.42, 0.66, 0.86):
            px = math.sin(theta) * (1.08 * (v_sc ** 0.72))
            py = side_sign * (0.16 + 0.68 * math.sin(v_sc * math.pi * 0.72))
            pz = 0.18 + 0.92 * (v_sc ** 0.86) * math.cos(theta * 0.55) + 0.075 * v_sc
            ellipsoid('Shell scute scale', (px, py, pz), (0.10, 0.065, 0.032), 1, segments=10, rings=6)


def create_giant_clam():
    ellipsoid('Reef limestone cradle', (0, 0, 0.14), (1.02, 0.78, 0.18), 3, organic=0.12, segments=24, rings=12)
    _clam_valve('Left Tridacna valve', -1)
    _clam_valve('Right Tridacna valve', 1)
    # Fleshy undulating iridescent mantle lobes
    for side in (-1, 1):
        pts = []
        radii = []
        for k in range(21):
            t = k / 20.0
            theta = (t - 0.5) * math.pi * 0.82
            rib_wave = math.cos(t * math.pi * 7.0)
            x_m = math.sin(theta) * 0.94
            y_m = side * (0.46 + 0.12 * rib_wave)
            z_m = 0.86 * math.cos(theta * 0.52) + 0.065 * rib_wave
            pts.append(Vector((x_m, y_m, z_m)))
            radii.append(0.155 * (0.65 + 0.45 * math.sin(t * math.pi)))
        tube('Iridescent mantle lip', pts, radii, 5, sides=14)
        for k in range(1, 20, 2):
            spot_p = pts[k] + Vector((0, -side * 0.04, 0.11))
            ellipsoid('Mantle glowing ocellus', spot_p, (0.045, 0.038, 0.028), 4, segments=8, rings=5)
    ellipsoid('Inner mantle bed', (0, 0, 0.48), (0.72, 0.38, 0.22), 5, organic=0.10, segments=24, rings=12)
    ellipsoid('Abyssal lustrous pearl', (0, 0, 0.72), (0.24, 0.24, 0.23), 1, segments=28, rings=18)
    ring('Pearl bioluminescent aura', (0, 0, 0.62), 0.28, 0.28, 0.026, 4, plane='XY', segments=28)


def _crinoid_crown(prefix, base_pos, top_pos, arm_count, arm_len):
    p0 = Vector(base_pos)
    p2 = Vector(top_pos)
    p1 = p0.lerp(p2, 0.52) + Vector((0.08, -0.05, 0.0))
    stalk_pts = [p0.lerp(p1, t / 8.0).lerp(p1.lerp(p2, t / 8.0), t / 8.0) for t in range(9)]
    tube(prefix + ' stalk', stalk_pts, [0.052 * (1.0 - 0.28 * (i / 8.0)) for i in range(9)], 1, sides=8)
    for i in range(1, 8, 2):
        ring(prefix + ' ossicle', stalk_pts[i], 0.058, 0.058, 0.012, 2, plane='XY', segments=10)
    for c_i in range(6):
        ca = c_i * TAU / 6.0
        c_end = p0 + Vector((math.cos(ca) * 0.24, math.sin(ca) * 0.24, -0.06))
        tube(prefix + ' cirrus', [p0 + Vector((0, 0, 0.08)), c_end], [0.022, 0.006], 2, sides=5)
    ellipsoid(prefix + ' calyx cup', p2, (0.095, 0.095, 0.075), 4, segments=12, rings=8)
    for a_i in range(arm_count):
        az = a_i * TAU / arm_count
        elev = 0.55 if a_i % 2 == 0 else 0.32
        a_pts = []
        for s in range(11):
            t = s / 10.0
            reach = arm_len * (t ** 0.85)
            arch_z = math.sin(t * math.pi * 0.82) * arm_len * elev - (t ** 2.2) * arm_len * 0.22
            sway = 0.06 * math.sin(t * math.pi + a_i)
            a_pts.append(p2 + Vector((math.cos(az + sway) * reach, math.sin(az + sway) * reach, arch_z)))
        tube(prefix + ' arm', a_pts, [0.026 * (1.0 - 0.68 * (s / 10.0)) for s in range(11)], 4 if a_i % 2 == 0 else 7, sides=6)
        for p_idx in range(2, 10, 2):
            origin = a_pts[p_idx]
            tang = (a_pts[min(10, p_idx + 1)] - a_pts[max(0, p_idx - 1)]).normalized()
            side_vec = Vector((-tang.y, tang.x, 0.0)).normalized()
            pin_len = arm_len * 0.25 * math.sin((p_idx / 10.0) * math.pi * 0.9 + 0.1)
            for sign in (-1, 1):
                mid_p = origin + side_vec * (sign * pin_len * 0.55) + Vector((0, 0, 0.035))
                tip = origin + side_vec * (sign * pin_len) + Vector((0, 0, 0.015))
                tube(prefix + ' pinnule', [origin, mid_p, tip], [0.010, 0.007, 0.002], 4, sides=4)


def create_sea_lily():
    ellipsoid('Abyssal reef rock', (0, 0, 0.16), (0.84, 0.80, 0.20), 3, organic=0.12, segments=24, rings=12)
    _crinoid_crown('Primary sea lily', (-0.08, 0.06, 0.28), (0.04, 0.02, 1.88), arm_count=8, arm_len=0.88)
    _crinoid_crown('Secondary sea lily', (-0.42, -0.28, 0.24), (-0.48, -0.32, 1.18), arm_count=6, arm_len=0.56)


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


def sculpt_and_budget(name, obj):
    organism = name in {'coral','staghorn_coral','table_coral','tube_coral','barrel_sponge','sea_fan','kelp','anemone','sea_lily'}
    if GENERATOR_VERSION != 'luminous-ocean-3':
        for vertex in obj.data.vertices:
            p=vertex.co
            if organism:
                h=max(0,p.z)
                p.x += math.sin(h*1.2)*h*.035
                p.y += math.sin(h*1.7+.4)*h*.045
            elif name=='rock':
                p.z += math.sin(p.x*2.1+p.y)*.07
                p.x += math.sin(p.z*3+p.y)*.08
            elif name=='ruins':
                p.x += math.sin(p.z*1.3)*.025
            elif name in {'fish','fish_small','fish_predator','fish_abyss'}:
                p.x *= 1.0+.09*math.sin(p.y*1.2)
                p.z += math.sin(p.y*.9)*.025
    obj.data.calc_loop_triangles()
    triangle_count=len(obj.data.loop_triangles)
    budget=TRIANGLE_BUDGETS[name]
    if triangle_count>budget:
        mod=obj.modifiers.new('Silhouette budget','DECIMATE')
        mod.ratio=(budget-30)/triangle_count
        mod.use_collapse_triangulate=True
        bpy.context.view_layer.objects.active=obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
    obj.data.calc_loop_triangles()


def finish_asset(name):
    normalize_parts(name)
    material, resolution, glass_builder = make_material(name)
    has_glass = any(bool(p.get('is_glass')) for p in PARTS)
    glass_material = glass_builder(name + '_Glass', blended=True) if has_glass else None
    bpy.ops.object.select_all(action='DESELECT')
    for obj in PARTS:
        obj.data.materials.clear()
        obj.data.materials.append(glass_material if (glass_material and obj.get('is_glass')) else material)
        obj.select_set(True)
    bpy.context.view_layer.objects.active = PARTS[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name
    sculpt_and_budget(name, obj)
    # Decimation changes extremal points slightly; restore the exact original bounds.
    PARTS.clear(); PARTS.append(obj)
    normalize_parts(name)
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
        'source': 'tools/create_assets.py', 'generator_version': GENERATOR_VERSION,
        'seed': 913+sum(map(ord,name)), 'license': 'MIT', 'author': 'Abyssal Echo Contributors',
        'forward': '-Y (Blender) / +Z (Godot)', 'up': '+Z (Blender) / +Y (Godot)',
        'triangle_budget': TRIANGLE_BUDGETS[name], 'external_sources': [],
        'texture_resolution': resolution, 'materials': len(obj.data.materials),
        'textures': {kind: 'embedded://' + name + '_' + kind + '.png'
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
    bg.inputs[0].default_value, bg.inputs[1].default_value = (.055, .18, .28, 1), 1.15
    camera = bpy.data.objects.new('Preview Camera', bpy.data.cameras.new('Preview Camera'))
    scene.collection.objects.link(camera)
    scene.camera = camera
    camera.data.type = 'ORTHO'
    lamps = []
    for i, (energy, rgb) in enumerate([(2200, (1.0, .96, .88)), (1800, (.28, .92, 1.0)), (1500, (1.0, .55, .82))]):
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
            lamp.data.energy = 88 * span * span
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


def render_reference_sheets_and_kit():
    import shutil
    ref_dir = SOURCE / 'references'
    ref_dir.mkdir(parents=True, exist_ok=True)
    for name, _ in ASSETS:
        preview_file = SOURCE / 'previews' / (name + '.png')
        if preview_file.is_file():
            shutil.copy2(preview_file, ref_dir / (name + '.png'))

    def save_composite(names, cols, rows, out_path, cell_w=384, cell_h=288):
        canvas = np.zeros((rows * cell_h, cols * cell_w, 4), dtype=np.float32)
        canvas[:, :, 0] = 0.055
        canvas[:, :, 1] = 0.16
        canvas[:, :, 2] = 0.25
        canvas[:, :, 3] = 1.0
        for idx, asset_name in enumerate(names[:cols * rows]):
            p = SOURCE / 'previews' / (asset_name + '.png')
            if not p.is_file():
                continue
            img = bpy.data.images.load(str(p.resolve()))
            iw, ih = img.size
            raw = np.array(img.pixels[:], dtype=np.float32).reshape((ih, iw, 4))
            bpy.data.images.remove(img)
            sy = np.linspace(0, ih - 1, cell_h).astype(np.int32)
            sx = np.linspace(0, iw - 1, cell_w).astype(np.int32)
            tile = raw[np.ix_(sy, sx)]
            r = rows - 1 - (idx // cols)
            c = idx % cols
            canvas[r * cell_h:(r + 1) * cell_h, c * cell_w:(c + 1) * cell_w, :] = tile
        out = bpy.data.images.new('CompositeSheet', width=cols * cell_w, height=rows * cell_h, alpha=True)
        out.colorspace_settings.name = 'sRGB'
        out.pixels.foreach_set(np.ascontiguousarray(canvas, dtype=np.float32).ravel())
        out.filepath_raw = str(out_path.resolve())
        out.file_format = 'PNG'
        out.save()
        bpy.data.images.remove(out)

    benthic_names = ['brain_coral', 'staghorn_coral', 'table_coral', 'barrel_sponge', 'giant_clam', 'sea_lily']
    coral_names = ['coral', 'tube_coral', 'anemone', 'sea_fan', 'tubeworms', 'starfish_urchin']
    all_names = [name for name, _ in ASSETS]
    if len(ASSETS) >= 6:
        save_composite(benthic_names, 3, 2, ROOT / 'assets/source/benthic_reef_reference_sheet.png', 512, 512)
        save_composite(coral_names, 3, 2, ROOT / 'assets/source/coral_reef_reference_sheet.png', 512, 512)
        save_composite(all_names, 6, 6, ROOT / 'assets/source/asset-kit.png', 320, 240)


def promote():
    import shutil
    staged=json.loads((STAGING/'asset-manifest.json').read_text(encoding='utf-8'))
    # Validation proof is tied to the manifest digest, not just an old marker file.
    import hashlib
    digest=hashlib.sha256((STAGING/'asset-manifest.json').read_bytes()).hexdigest()
    proof=STAGING/'validated.sha256'
    if not proof.is_file() or proof.read_text().strip()!=digest:
        raise RuntimeError('Run tests/asset_pipeline.gd -- --staging before promotion')
    for name,entry in staged.items():
        if name not in CONTRACT or not (STAGING/'models'/(name+'.glb')).is_file():
            raise RuntimeError('Invalid staging asset '+name)
        if entry['triangles']>entry['triangle_budget']:
            raise RuntimeError('Triangle budget exceeded '+name)
    production=ROOT/'assets/models'
    production.mkdir(parents=True,exist_ok=True)
    imported_cache=ROOT/'.godot/imported'
    editor_cache=ROOT/'.godot/editor'
    cleared_editor_cache=False
    for name in staged:
        shutil.copy2(STAGING/'models'/(name+'.glb'), production/(name+'.glb'))
        missing_tex=any(not (production/f'{name}_{name}_{k}.png').is_file() for k in ('albedo','normal','orm','emission'))
        if missing_tex:
            if imported_cache.is_dir():
                for cached_file in imported_cache.glob(name+'.glb-*'):
                    cached_file.unlink()
                for cached_tex in imported_cache.glob(name+'_'+name+'_*.png-*'):
                    cached_tex.unlink()
            if not cleared_editor_cache and editor_cache.is_dir():
                for cache_file in editor_cache.glob('filesystem_cache*'):
                    cache_file.unlink()
                cleared_editor_cache=True
    manifest_file=ROOT/'assets/source/asset-manifest.json'
    previous=json.loads(manifest_file.read_text(encoding='utf-8')) if manifest_file.is_file() else {}
    previous.update(staged)
    manifest_file.write_text(json.dumps(previous,indent=2)+'\n',encoding='utf-8')
    print('PROMOTED '+str(len(staged))+' validated assets',flush=True)


def main():
    global CURRENT,MANIFEST
    parser=argparse.ArgumentParser()
    parser.add_argument('--assets',nargs='+',default=list(CONTRACT))
    parser.add_argument('--promote',action='store_true')
    parser.add_argument('--previews',action='store_true')
    parser.add_argument('--save-blend',action='store_true')
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    if args.promote:
        promote(); return
    unknown=set(args.assets)-set(CONTRACT)
    if unknown: raise RuntimeError('Unknown asset IDs '+str(sorted(unknown)))
    for folder in (SOURCE/'textures',SOURCE/'previews',SOURCE/'references',STAGING/'models'):
        folder.mkdir(parents=True,exist_ok=True)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    bpy.context.scene.name='Luminous ocean production assets'
    bpy.context.scene.render.fps=30
    bpy.context.scene.unit_settings.system='METRIC'
    staged_manifest=STAGING/'asset-manifest.json'
    MANIFEST=json.loads(staged_manifest.read_text(encoding='utf-8')) if staged_manifest.is_file() else {}
    for name in args.assets:
        CURRENT=name
        random.seed(913+sum(map(ord,name)))
        globals()['create_'+name]()
        finish_asset(name)
    staged_manifest.write_text(json.dumps(MANIFEST,indent=2)+'\n',encoding='utf-8')
    if args.previews: render_previews()
    if args.save_blend:
        bpy.ops.file.pack_all()
        bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/'painterly-ocean.blend'))
    print('BUILD_COMPLETE '+str(len(args.assets))+' staged / '+str(len(MANIFEST))+' total',flush=True)


if __name__=='__main__': main()
