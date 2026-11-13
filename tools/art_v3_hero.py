"""Blender-built expedition suit and articulated creature/vehicle mesh library.

The GPT Image concept sheets are required inputs. Geometry is authored in the
existing Godot part-local coordinates, then rotated into Blender's Z-up space.
Controllers continue to animate their original pivots; this module replaces
only their visible surfaces. It deliberately does not touch ocean-kit assets.
"""

from pathlib import Path
import json
import math

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector


TAU = math.tau
OBJECTS = []
MATERIAL = None
FAUNA_MAT = None
FAUNA_GLOW_MAT = None
SUB_MAT = None
SUB_GLASS_MAT = None
COLLECTION = None


class Shape:
    def __init__(self):
        self.vertices = []
        self.faces = []
        self.uv = []

    def vertex(self, point, uv=(0, 0)):
        self.vertices.append(tuple(point))
        self.uv.append(tuple(uv))
        return len(self.vertices) - 1

    def loft(self, profile, segments=20, subdivisions=2):
        """Y-axis anatomical sections: (height, half-width, half-depth, z-shift)."""
        rings = []
        for index in range(len(profile) - 1):
            p0 = np.array(profile[max(0, index - 1)], dtype=float)
            p1 = np.array(profile[index], dtype=float)
            p2 = np.array(profile[index + 1], dtype=float)
            p3 = np.array(profile[min(len(profile) - 1, index + 2)], dtype=float)
            for step in range(subdivisions):
                t = step / subdivisions
                p = .5 * ((2*p1) + (-p0+p2)*t + (2*p0-5*p1+4*p2-p3)*t*t + (-p0+3*p1-3*p2+p3)*t*t*t)
                p[1:3] = np.maximum(p[1:3], .0001)
                rings.append(p)
        rings.append(np.array(profile[-1], dtype=float))
        base = len(self.vertices)
        for ring, (height, width, depth, shift) in enumerate(rings):
            for segment in range(segments):
                a = TAU * segment / segments
                self.vertex((math.cos(a)*width, height, math.sin(a)*depth+shift),
                            (segment/segments, ring/(len(rings)-1)))
                if ring < len(rings)-1:
                    n = base + ring*segments+segment
                    nxt = base + ring*segments+(segment+1) % segments
                    self.faces.append((n, n+segments, nxt+segments, nxt))
        for end in (0, len(rings)-1):
            height, width, depth, shift = rings[end]
            center = self.vertex((0, height, shift), (.5, .5))
            rim = []
            for segment in range(segments):
                a = TAU * segment/segments
                rim.append(self.vertex((math.cos(a)*width, height, math.sin(a)*depth+shift),
                                       (.5+.5*math.cos(a), .5+.5*math.sin(a))))
            for segment in range(segments):
                a, b = rim[segment], rim[(segment+1) % segments]
                self.faces.append((center, a, b) if end == 0 else (center, b, a))
        return self

    def tube(self, points, radii, segments=8):
        points = [Vector(p) for p in points]
        base = len(self.vertices)
        for index, point in enumerate(points):
            direction = (points[min(index+1, len(points)-1)]-points[max(0, index-1)]).normalized()
            tangent = direction.cross(Vector((0, 0, 1)))
            if tangent.length < .01:
                tangent = direction.cross(Vector((0, 1, 0)))
            tangent.normalize()
            bitangent = direction.cross(tangent).normalized()
            for segment in range(segments):
                a = TAU*segment/segments
                self.vertex(point + (math.cos(a)*tangent+math.sin(a)*bitangent)*radii[index],
                            (segment/segments, index/(len(points)-1)))
                if index < len(points)-1:
                    n = base+index*segments+segment
                    nxt = base+index*segments+(segment+1) % segments
                    self.faces.append((n, nxt, nxt+segments, n+segments))
        for end in (0, len(points)-1):
            center = self.vertex(points[end], (.5, .5))
            for segment in range(segments):
                a = base+end*segments+segment
                b = base+end*segments+(segment+1) % segments
                self.faces.append((center, b, a) if end == 0 else (center, a, b))
        return self

    def merge(self, other):
        offset = len(self.vertices)
        self.vertices.extend(other.vertices)
        self.uv.extend(other.uv)
        self.faces.extend(tuple(v+offset for v in face) for face in other.faces)
        return self

    def transform(self, fn):
        self.vertices = [tuple(fn(Vector(v))) for v in self.vertices]
        return self

    def normalize(self):
        points = np.asarray(self.vertices)
        low, high = points.min(axis=0), points.max(axis=0)
        self.vertices = [tuple((np.asarray(v)-(low+high)/2)/np.maximum(high-low, .00001)) for v in self.vertices]
        return self

    def object(self, name):
        # Godot (x,y,z) -> Blender (x,-z,y); a proper rotation, never a reflection.
        data = bpy.data.meshes.new(name)
        data.from_pydata([(x, -z, y) for x, y, z in self.vertices], [], self.faces)
        data.validate(clean_customdata=False)
        data.update()
        data.calc_loop_triangles()
        for triangle in data.loop_triangles:
            a,b,c=(data.vertices[i].co for i in triangle.vertices)
            if (b-a).cross(c-a).length_squared <= 1e-12:
                raise RuntimeError(f'{name}: triangle {triangle.index} is too small for the runtime geometry contract')
        for polygon in data.polygons:
            polygon.use_smooth = True
        uv_layer = data.uv_layers.new(name='ConceptDetailUV')
        for polygon in data.polygons:
            for loop in polygon.loop_indices:
                uv_layer.data[loop].uv = self.uv[data.loops[loop].vertex_index]
        obj = bpy.data.objects.new(name, data)
        COLLECTION.objects.link(obj)
        obj.data.materials.append(MATERIAL)
        obj['art_direction'] = 'GPT Image concept to original Blender surface'
        OBJECTS.append(obj)
        return obj


def _material(output, reference):
    """Neutral woven/brush detail multiplies the controller's authored pigments."""
    size = 512
    image = bpy.data.images.load(str(reference.resolve()), check_existing=True)
    w, h = image.size
    source = np.asarray(image.pixels[:], dtype=np.float32).reshape(h, w, 4)
    y, x = np.mgrid[0:size, 0:size]
    sx = np.minimum((x/max(1, size-1)*(w-1)).astype(int), w-1)
    sy = np.minimum((y/max(1, size-1)*(h-1)).astype(int), h-1)
    lum = source[sy, sx, :3].mean(axis=2)
    # Only use the concept's low-amplitude paint variation: no baked faces,
    # text or lighting projected onto unrelated body parts.
    grain = np.random.default_rng(4203).normal(0, .005, (size, size))
    weave = np.sin(x*math.pi*.55)*np.sin(y*math.pi*.58)*.009
    brush = np.sin(y*.11+np.sin(x*.023)*1.8)*.011
    tone = np.clip(.968 + (lum-lum.mean())*.026 + grain+weave+brush, .88, 1)
    albedo = np.stack((tone, tone, tone, np.ones_like(tone)), axis=-1)
    dx, dy = np.gradient(weave+brush)
    normal = np.stack((.5-dx*.9, .5-dy*.9, np.ones_like(dx), np.ones_like(dx)), axis=-1)
    orm = np.stack((np.ones_like(tone), np.clip(.92+weave*2, .7, 1), np.zeros_like(tone), np.ones_like(tone)), axis=-1)
    images = {}
    for key, pixels in [('albedo', albedo), ('normal', normal), ('orm', orm)]:
        img = bpy.data.images.new('expedition_'+key, size, size, alpha=True)
        if key != 'albedo':
            img.colorspace_settings.name = 'Non-Color'
        img.pixels.foreach_set(pixels.astype(np.float32).ravel())
        img.filepath_raw = str(output / ('expedition_'+key+'.png'))
        img.file_format = 'PNG'
        img.save()
        img.pack()
        images[key] = img
    mat = bpy.data.materials.new('Expedition handworked neutral detail')
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    bsdf = next(n for n in nodes if n.type == 'BSDF_PRINCIPLED')
    bsdf.inputs['Roughness'].default_value = .7
    for key, img in images.items():
        tex = nodes.new('ShaderNodeTexImage')
        tex.image = img
        if key == 'albedo':
            links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
        elif key == 'normal':
            nm = nodes.new('ShaderNodeNormalMap')
            nm.inputs['Strength'].default_value = .35
            links.new(tex.outputs['Color'], nm.inputs['Color'])
            links.new(nm.outputs['Normal'], bsdf.inputs['Normal'])
        else:
            sep = nodes.new('ShaderNodeSeparateColor')
            links.new(tex.outputs['Color'], sep.inputs['Color'])
            links.new(sep.outputs['Green'], bsdf.inputs['Roughness'])
            links.new(sep.outputs['Blue'], bsdf.inputs['Metallic'])
    return mat


def _srgb_to_linear(rgb):
    arr = np.asarray(rgb, dtype=np.float32)
    return np.where(arr <= 0.04045, arr / 12.92, ((arr + 0.055) / 1.055) ** 2.4)


def _hex_lin(h):
    return _srgb_to_linear([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


def _save_packed_image(output, name, pixels, non_color=False):
    h, w, _ = pixels.shape
    img = bpy.data.images.new(name, w, h, alpha=True)
    if non_color:
        img.colorspace_settings.name = 'Non-Color'
    # Flip vertically so row 0 corresponds to UV V=0..0.25 cleanly.
    img.pixels.foreach_set(np.clip(pixels, 0.0, 1.0).astype(np.float32).ravel())
    img.filepath_raw = str(output / (name + '.png'))
    img.file_format = 'PNG'
    img.save()
    img.pack()
    return img


def _build_pbr_material(name, maps, blended=False, alpha_val=1.0, emission_strength=1.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.use_backface_culling = not blended
    if blended:
        if hasattr(mat, 'surface_render_method'):
            mat.surface_render_method = 'BLENDED'
        if hasattr(mat, 'blend_method'):
            mat.blend_method = 'BLEND'
    nodes = mat.node_tree.nodes
    links = mat.node_tree.links
    bsdf = next(n for n in nodes if n.type == 'BSDF_PRINCIPLED')
    bsdf.inputs['Alpha'].default_value = alpha_val
    for key, img in maps.items():
        tex = nodes.new('ShaderNodeTexImage')
        tex.name = key
        tex.image = img
        tex.interpolation = 'Linear'
    if 'albedo' in maps:
        links.new(nodes['albedo'].outputs['Color'], bsdf.inputs['Base Color'])
        if blended:
            links.new(nodes['albedo'].outputs['Alpha'], bsdf.inputs['Alpha'])
    if 'normal' in maps:
        nmap = nodes.new('ShaderNodeNormalMap')
        nmap.inputs['Strength'].default_value = 0.65
        links.new(nodes['normal'].outputs['Color'], nmap.inputs['Color'])
        links.new(nmap.outputs['Normal'], bsdf.inputs['Normal'])
    if 'orm' in maps:
        sep = nodes.new('ShaderNodeSeparateColor')
        links.new(nodes['orm'].outputs['Color'], sep.inputs['Color'])
        links.new(sep.outputs['Green'], bsdf.inputs['Roughness'])
        links.new(sep.outputs['Blue'], bsdf.inputs['Metallic'])
        group = bpy.data.node_groups.get('glTF Material Output')
        if group is None:
            group = bpy.data.node_groups.new('glTF Material Output', 'ShaderNodeTree')
            group.interface.new_socket(name='Occlusion', in_out='INPUT', socket_type='NodeSocketFloat')
        ao = nodes.new('ShaderNodeGroup')
        ao.node_tree = group
        links.new(sep.outputs['Red'], ao.inputs['Occlusion'])
    if 'emission' in maps:
        links.new(nodes['emission'].outputs['Color'], bsdf.inputs['Emission Color'])
        bsdf.inputs['Emission Strength'].default_value = emission_strength
    return mat


def _height_to_normal(height_map, strength=2.4):
    dy, dx = np.gradient(height_map)
    nx = -dx * strength
    ny = -dy * strength
    nz = np.ones_like(height_map)
    inv = 1.0 / np.maximum(np.sqrt(nx * nx + ny * ny + nz * nz), 1e-6)
    return np.stack((0.5 + 0.5 * nx * inv, 0.5 + 0.5 * ny * inv, 0.5 + 0.5 * nz * inv, np.ones_like(nz)), axis=-1)


def _fauna_materials(output):
    size = 1024
    tile = 256
    albedo = np.zeros((size, size, 4), dtype=np.float32)
    albedo[:, :, 3] = 1.0
    height = np.zeros((size, size), dtype=np.float32)
    orm = np.zeros((size, size, 4), dtype=np.float32)
    orm[:, :, 0] = 1.0
    orm[:, :, 1] = 0.45
    orm[:, :, 3] = 1.0
    emission = np.zeros((size, size, 4), dtype=np.float32)
    emission[:, :, 3] = 1.0
    yy, xx = np.mgrid[0:tile, 0:tile].astype(np.float32) / (tile - 1)
    rng = np.random.default_rng(7301)
    speck = rng.normal(0.0, 0.025, (tile, tile)).astype(np.float32)

    def put(idx, col, hgt, rough, metal=0.0, ao=1.0, em=None):
        r, c = divmod(idx, 4)
        y0, y1, x0, x1 = r * tile, (r + 1) * tile, c * tile, (c + 1) * tile
        albedo[y0:y1, x0:x1, :3] = np.clip(col, 0.0, 1.0)
        height[y0:y1, x0:x1] = hgt
        orm[y0:y1, x0:x1, 0] = np.clip(ao, 0.35, 1.0)
        orm[y0:y1, x0:x1, 1] = np.clip(rough, 0.06, 0.95)
        orm[y0:y1, x0:x1, 2] = np.clip(metal, 0.0, 1.0)
        if em is not None:
            emission[y0:y1, x0:x1, :3] = np.clip(em, 0.0, 1.0)

    # 0: spider_carapace - spiny rust-crimson & terracotta chitin with pale mineral speckles
    tub = np.sin(xx * TAU * 7) * np.sin(yy * TAU * 6) * 0.5 + np.sin((xx + yy) * TAU * 13) * 0.25
    c0 = _hex_lin('9d3926') * (1 - 0.35 * np.maximum(0, tub))[..., None] + _hex_lin('d46c49') * np.maximum(0, tub)[..., None]
    dots = (np.sin(xx * 43) * np.cos(yy * 47) > 0.84).astype(np.float32)[..., None]
    put(0, c0 * (1 - 0.35 * dots) + _hex_lin('e6d2b8') * 0.35 * dots + speck[..., None] * 0.4, tub * 0.45, 0.44 - tub * 0.06, 0.06, 0.88 + 0.12 * tub)
    # 1: spider_leg_band - banded rust-crimson & warm cream chitin
    band = 0.5 + 0.5 * np.sin(yy * TAU * 4.5 + np.sin(xx * TAU * 2) * 0.18)
    c1 = _hex_lin('9e3623') * (1 - band[..., None]) + _hex_lin('e6d6be') * band[..., None]
    grooves = np.sin(xx * TAU * 14) * 0.18 + np.cos(yy * TAU * 4.5) * 0.25
    put(1, c1 + speck[..., None] * 0.3, grooves, 0.40, 0.05, 0.90 + 0.08 * band)
    # 2: seal_dapple - sleek wet silver-slate harbor seal fur with fine dappled spots
    blotch = np.sin(xx * 34 + np.cos(yy * 27) * 1.4) * np.cos(yy * 31 - np.sin(xx * 23) * 1.3)
    fine_sp = np.sin(xx * 68 + 0.9) * np.cos(yy * 64 - 0.7)
    w_dark = np.clip((blotch * 0.65 + fine_sp * 0.35 - 0.15) * 2.2, 0.0, 1.0)[..., None]
    w_pale = np.clip((-blotch * 0.60 - fine_sp * 0.40 - 0.22) * 2.0, 0.0, 1.0)[..., None]
    c2 = _hex_lin('5a6d7d') * (1 - w_dark - w_pale * 0.6) + _hex_lin('2c3a48') * w_dark + _hex_lin('c4cfd6') * (w_pale * 0.6)
    fur = np.sin(yy * 110 + xx * 14) * 0.08
    put(2, c2 * (0.94 + 0.10 * yy[..., None]) + speck[..., None] * 0.22, fur + blotch * 0.06, 0.30, 0.04, 0.94)
    # 3: seal_cream_belly - soft cream-silver ventral coat with subtle speckles
    sp3 = (np.sin(xx * 29 + 1.2) * np.cos(yy * 23) > 0.72).astype(np.float32)[..., None]
    c3 = _hex_lin('dfe4e6') * (1 - 0.22 * sp3) + _hex_lin('8796a2') * (0.22 * sp3)
    put(3, c3 + speck[..., None] * 0.18, fur * 0.6, 0.34, 0.03, 0.96)
    # 4: dragon_cobalt_scale - imbricated deep cobalt-sapphire dragon scales
    sx = (xx * 10.0) % 1.0
    sy = (yy * 10.0 + 0.5 * (np.floor(xx * 10.0) % 2.0)) % 1.0
    sc_d = np.sqrt((sx - 0.5) ** 2 + (sy - 0.55) ** 2 * 1.25)
    rim = np.clip(1.0 - sc_d * 1.75, 0.0, 1.0)
    c4 = _hex_lin('122f63') * (1 - rim[..., None]) + _hex_lin('356cb8') * rim[..., None] + _hex_lin('7ba8e3') * (rim ** 3)[..., None] * 0.28
    put(4, c4, rim * 0.55, 0.34 - rim * 0.08, 0.16, 0.76 + 0.24 * rim)
    # 5: dragon_ivory_plate - ribbed pearl-ivory & champagne-gold ventral plates & horns
    rib = np.abs(np.sin(yy * math.pi * 12))
    c5 = _hex_lin('9c8663') * (1 - rib[..., None]) + _hex_lin('e6decb') * rib[..., None]
    put(5, c5 + speck[..., None] * 0.2, rib * 0.42, 0.40, 0.08, 0.80 + 0.20 * rib)
    # 6: dragon_fin_pleat - cobalt root -> pearl sky -> warm golden-ochre pleated fin membrane
    pleat = 0.5 + 0.5 * np.sin(xx * TAU * 16)
    grad = np.clip(yy, 0.0, 1.0)[..., None]
    c6 = _hex_lin('235096') * (1 - grad) + (_hex_lin('9bb8d9') * 0.45 + _hex_lin('dfb774') * 0.55) * grad
    c6 = c6 * (0.86 + 0.22 * pleat[..., None])
    em6 = _hex_lin('3c88e6') * (1 - grad) * (pleat ** 3)[..., None] * 0.18
    put(6, c6, pleat * 0.38, 0.36, 0.10, 0.86 + 0.14 * pleat, em6)
    # 7: flying_cobalt_silver - pelagic metallic cobalt back & mirror-silver flank
    fgrad = np.clip((yy - 0.35) / 0.5, 0.0, 1.0)[..., None]
    fscale = 0.5 + 0.5 * np.sin(xx * TAU * 22) * np.sin(yy * TAU * 18)
    c7 = _hex_lin('d4dfe8') * (1 - fgrad) + _hex_lin('1c5496') * fgrad
    put(7, c7 * (0.93 + 0.10 * fscale[..., None]), fscale * 0.22, 0.24, 0.36 * (1 - 0.4 * fgrad[..., 0]), 0.92)
    # 8: flying_wing_amber - rayed translucent-look sky-blue & golden-amber gliding wing
    rays = np.abs(np.sin(xx * math.pi * 18)) ** 2.2
    c8 = _hex_lin('9ec0de') * (1 - rays[..., None]) + _hex_lin('e3ba7d') * rays[..., None]
    put(8, c8 * (0.90 + 0.12 * yy[..., None]), rays * 0.45, 0.30, 0.14, 0.88 + 0.12 * rays, _hex_lin('5eb5e8') * 0.08)
    # 9: kraken_crimson_mantle - muscular ridged rust-crimson & mahogany dermal papillae
    pap = np.sin(xx * TAU * 9 + np.sin(yy * 9)) * np.cos(yy * TAU * 8) * 0.5 + np.sin(xx * 45) * np.cos(yy * 43) * 0.25
    c9 = _hex_lin('6e231b') * (1 - np.clip(pap + 0.5, 0, 1)[..., None]) + _hex_lin('bc553d') * np.clip(pap + 0.5, 0, 1)[..., None]
    put(9, c9 + speck[..., None] * 0.3, pap * 0.52, 0.33, 0.04, 0.82 + 0.18 * np.clip(pap + 0.5, 0, 1))
    # 10: kraken_sucker_ivory - fleshy peach-ivory suction cup rings
    rr = np.sqrt((xx - 0.5) ** 2 + (yy - 0.5) ** 2)
    cup = np.exp(-((rr - 0.28) / 0.11) ** 2)
    c10 = _hex_lin('a84d3c') * (1 - cup[..., None]) + _hex_lin('ead8c7') * cup[..., None]
    put(10, c10, cup * 0.60 - np.exp(-(rr / 0.16) ** 2) * 0.35, 0.38, 0.02, 0.80 + 0.20 * cup)
    # 11: turtle_scute_mosaic - olive-emerald & golden-ochre sunburst marbled carapace scutes
    tx = (xx * 3.5) % 1.0 - 0.5
    ty = (yy * 3.0 + 0.5 * (np.floor(xx * 3.5) % 2.0)) % 1.0 - 0.5
    ang = np.arctan2(ty, tx)
    rad = (np.abs(tx) * 0.85 + np.abs(ty) * 0.65 + np.maximum(np.abs(tx), np.abs(ty)) * 0.75)
    burst = 0.5 + 0.5 * np.sin(ang * 10.0 + rad * 7.0)
    rings11 = np.sin(rad * TAU * 6.0) * 0.16
    seam = np.clip((0.76 - rad) * 11.0, 0.0, 1.0)
    c11_scute = _hex_lin('3a664d') * (1 - burst[..., None] * 0.78) + _hex_lin('d4a553') * (burst[..., None] * 0.78)
    c11 = _hex_lin('26382c') * (1 - seam[..., None]) + c11_scute * seam[..., None]
    put(11, c11 + speck[..., None] * 0.22, seam * 0.48 + rings11, 0.44, 0.05, 0.72 + 0.28 * seam)
    # 12: turtle_reticulated_skin - dark olive-slate polygonal scales with cream-ochre outlines
    gx = (xx * 7.0) % 1.0 - 0.5
    gy = (yy * 7.0 + 0.5 * (np.floor(xx * 7.0) % 2.0)) % 1.0 - 0.5
    poly = np.maximum(np.abs(gx), np.abs(gy) * 0.86 + np.abs(gx) * 0.35)
    plate = np.clip((0.40 - poly) * 9.0, 0.0, 1.0)
    c12 = _hex_lin('cfc097') * (1 - plate[..., None]) + _hex_lin('345046') * plate[..., None]
    put(12, c12 + speck[..., None] * 0.2, plate * 0.48, 0.48 - plate * 0.08, 0.04, 0.78 + 0.22 * plate)
    # 13: wolf_slate_mottle - lupine sea-wolf mottled slate-blue/charcoal & silver coat
    wm = np.sin(xx * 32 + np.sin(yy * 24)) * np.cos(yy * 29 + np.cos(xx * 21))
    wf = np.sin(xx * 63 - 0.4) * np.cos(yy * 57 + 0.8)
    wd = np.clip((wm * 0.65 + wf * 0.35 - 0.10) * 2.0, 0.0, 1.0)[..., None]
    wp = np.clip((-wm * 0.55 - wf * 0.45 - 0.18) * 1.9, 0.0, 1.0)[..., None]
    c13 = _hex_lin('4b6178') * (1 - wd - wp * 0.55) + _hex_lin('263445') * wd + _hex_lin('9fb0bd') * (wp * 0.55)
    put(13, c13 + speck[..., None] * 0.22, np.sin(xx * 90) * 0.08 + wm * 0.08, 0.38, 0.06, 0.92)
    # 14: school_silver_ochre - pelagic silver flank, slate back & golden-ochre lateral stripe
    stripe = np.exp(-((yy - 0.56) / 0.10) ** 2)[..., None]
    back = np.clip((yy - 0.62) / 0.35, 0.0, 1.0)[..., None]
    c14 = _hex_lin('dae3ea') * (1 - back) + _hex_lin('4c6678') * back
    c14 = c14 * (1 - stripe * 0.85) + _hex_lin('d99d3b') * (stripe * 0.85)
    put(14, c14, np.sin(xx * TAU * 20) * np.sin(yy * TAU * 16) * 0.16, 0.23, 0.40, 0.94)
    # 15: 4 sub-quadrants (BL=152 ivory fang/claw, BR=153 bio glow, TL=150 obsidian eye, TR=151 golden slit eye)
    c15 = np.zeros((tile, tile, 3), dtype=np.float32)
    h15 = np.zeros((tile, tile), dtype=np.float32)
    r15 = np.full((tile, tile), 0.22, dtype=np.float32)
    em15 = np.zeros((tile, tile, 3), dtype=np.float32)
    half = tile // 2
    q_yy, q_xx = np.mgrid[0:half, 0:half].astype(np.float32) / (half - 1)
    # Row 0 (bottom, V=0..0.5): left = ivory fang, right = bioluminescent cyan-gold
    c15[0:half, 0:half] = _hex_lin('f0eadb') * (0.85 + 0.15 * q_yy[..., None])
    r15[0:half, 0:half] = 0.28
    c15[0:half, half:tile] = _hex_lin('86f2ff')
    em15[0:half, half:tile] = _hex_lin('4ad8ff') * 0.65
    # Row 1 (top, V=0.5..1.0): left = glossy obsidian eye + glint, right = golden slit eye
    glint = ((q_xx - 0.34) ** 2 + (q_yy - 0.66) ** 2 < 0.018).astype(np.float32)[..., None]
    c15[half:tile, 0:half] = _hex_lin('0b1118') * (1 - glint) + _hex_lin('f5f8fa') * glint
    r15[half:tile, 0:half] = 0.07
    slit = (np.abs(q_xx - 0.5) < 0.09 * (1.0 - 0.7 * (q_yy - 0.5) ** 2 * 4)).astype(np.float32)[..., None]
    iris = _hex_lin('ebb134') * (1 - 0.35 * np.sqrt((q_xx - 0.5) ** 2 + (q_yy - 0.5) ** 2)[..., None])
    c15[half:tile, half:tile] = iris * (1 - slit) + _hex_lin('090807') * slit
    r15[half:tile, half:tile] = 0.10
    em15[half:tile, half:tile] = iris * (1 - slit) * 0.45
    put(15, c15, h15, r15, 0.05, 0.96, em15)

    normal = _height_to_normal(height, 2.2)
    maps = {
        'albedo': _save_packed_image(output, 'hero_fauna_albedo', albedo, False),
        'normal': _save_packed_image(output, 'hero_fauna_normal', normal, True),
        'orm': _save_packed_image(output, 'hero_fauna_orm', orm, True),
        'emission': _save_packed_image(output, 'hero_fauna_emission', emission, False),
    }
    fauna_mat = _build_pbr_material('HeroFaunaAtlas', maps, blended=False, emission_strength=0.8)
    glow_maps = {'albedo': maps['albedo'], 'normal': maps['normal'], 'orm': maps['orm']}
    glow_mat = _build_pbr_material('HeroFaunaGlow', glow_maps, blended=False, emission_strength=0.45)
    bsdf = next(n for n in glow_mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    bsdf.inputs['Emission Color'].default_value = (0.25, 0.82, 1.0, 1.0)
    return fauna_mat, glow_mat


def _submarine_materials(output):
    size = 1024
    tile = 256
    albedo = np.zeros((size, size, 4), dtype=np.float32)
    albedo[:, :, 3] = 1.0
    height = np.zeros((size, size), dtype=np.float32)
    orm = np.zeros((size, size, 4), dtype=np.float32)
    orm[:, :, 0] = 1.0
    orm[:, :, 1] = 0.42
    orm[:, :, 3] = 1.0
    emission = np.zeros((size, size, 4), dtype=np.float32)
    emission[:, :, 3] = 1.0
    yy, xx = np.mgrid[0:tile, 0:tile].astype(np.float32) / (tile - 1)
    rng = np.random.default_rng(9107)
    wear = rng.normal(0.0, 0.018, (tile, tile)).astype(np.float32)

    def put(idx, col, hgt, rough, metal=0.0, ao=1.0, em=None):
        r, c = divmod(idx, 4)
        y0, y1, x0, x1 = r * tile, (r + 1) * tile, c * tile, (c + 1) * tile
        albedo[y0:y1, x0:x1, :3] = np.clip(col, 0.0, 1.0)
        height[y0:y1, x0:x1] = hgt
        orm[y0:y1, x0:x1, 0] = np.clip(ao, 0.35, 1.0)
        orm[y0:y1, x0:x1, 1] = np.clip(rough, 0.06, 0.95)
        orm[y0:y1, x0:x1, 2] = np.clip(metal, 0.0, 1.0)
        if em is not None:
            emission[y0:y1, x0:x1, :3] = np.clip(em, 0.0, 1.0)

    # 0: ceramic_ivory_panel - warm ivory hull panels with subtle seams & sea-wear flecks
    seam_x = np.minimum((xx * 3) % 1.0, 1.0 - (xx * 3) % 1.0)
    seam_y = np.minimum((yy * 3) % 1.0, 1.0 - (yy * 3) % 1.0)
    groove = np.clip(np.minimum(seam_x, seam_y) * 28.0, 0.0, 1.0)
    fleck = (np.sin(xx * 67 + yy * 23) * np.cos(yy * 59 - xx * 31) > 0.89).astype(np.float32)[..., None]
    c0 = (_hex_lin('eadfcd') * groove[..., None] + _hex_lin('b59d7e') * (1 - groove[..., None]))
    c0 = c0 * (1 - 0.25 * fleck) + _hex_lin('9e724d') * (0.25 * fleck)
    put(0, c0 + wear[..., None], groove * 0.35, 0.36 + (1 - groove) * 0.18, 0.08, 0.82 + 0.18 * groove)
    # 1: navy_indigo_trim - deep nautical navy-indigo lower keel & side trim
    brush = np.sin(xx * 95) * 0.05
    c1 = _hex_lin('1d304b') * (0.90 + 0.15 * groove[..., None]) + wear[..., None] * 0.4
    put(1, c1, groove * 0.25 + brush, 0.40, 0.26, 0.86 + 0.14 * groove)
    # 2: coral_red_stripe - expedition coral-vermilion safety band
    c2 = _hex_lin('d9583f') * (1 - 0.18 * fleck) + _hex_lin('e8c8ad') * (0.18 * fleck) + wear[..., None] * 0.5
    put(2, c2, groove * 0.20, 0.39, 0.10, 0.92)
    # 3: machined_brass - satin antique gold-brass mullions, bezels, propellers
    turn = np.sin(xx * TAU * 18) * 0.08 + np.sin(yy * TAU * 6) * 0.06
    c3 = _hex_lin('c99b4e') * (0.88 + 0.20 * (0.5 + turn)[..., None])
    put(3, c3, turn * 0.35, 0.27, 0.80, 0.90)
    # 4: dark_hydraulic_metal - gunmetal steel pistons, torpedo barrels & landing pads
    put(4, _hex_lin('323a45') + wear[..., None] * 0.3, np.sin(yy * TAU * 12) * 0.18, 0.35, 0.72, 0.88)
    # 5: cream_leather_seat - plush horizontal-quilted cream leather upholstery
    tuft = np.abs(np.sin(yy * math.pi * 7.0)) ** 0.65
    c5 = _hex_lin('9e9380') * (1 - tuft[..., None]) + _hex_lin('e5ded0') * tuft[..., None]
    put(5, c5 + wear[..., None] * 0.25, tuft * 0.55, 0.54, 0.02, 0.76 + 0.24 * tuft)
    # 6: cabin_wood_brass - warm walnut/teak cabinetry, tables & helm console
    grain = np.sin(yy * 42 + np.sin(xx * 9) * 2.2) * 0.5 + 0.5
    c6 = _hex_lin('593a24') * (1 - grain[..., None]) + _hex_lin('875c3b') * grain[..., None]
    put(6, c6, grain * 0.22, 0.44, 0.05, 0.90)
    # 7: red_coral_specimen - vibrant living branching red coral
    p7 = np.sin(xx * 55) * np.cos(yy * 55) * 0.15
    put(7, _hex_lin('e65340') * (0.92 + p7[..., None]), p7, 0.52, 0.0, 0.92, _hex_lin('e65340') * 0.08)
    # 8: cabin_deck_teal - deep sea-teal interior bulkhead & ribbed deck flooring
    rib8 = 0.5 + 0.5 * np.sin(xx * TAU * 12)
    c8 = _hex_lin('213f4a') * (0.85 + 0.22 * rib8[..., None])
    put(8, c8, rib8 * 0.28, 0.48, 0.18, 0.84 + 0.16 * rib8)
    # 9: helm_sonar_glow - glowing cyan radar/sonar screen & amber brass instrument dials
    scr = ((xx > 0.14) & (xx < 0.86) & (yy > 0.18) & (yy < 0.82)).astype(np.float32)
    grid9 = ((np.abs(np.sin(xx * TAU * 8)) > 0.92) | (np.abs(np.sin(yy * TAU * 6)) > 0.92)).astype(np.float32)
    sweep = np.exp(-((np.sqrt((xx - 0.5) ** 2 + (yy - 0.5) ** 2) - 0.24) / 0.04) ** 2)
    c9 = _hex_lin('1b2b34') * (1 - scr[..., None]) + (_hex_lin('124e57') + _hex_lin('4ef2e0') * np.clip(grid9 * 0.5 + sweep, 0, 1)[..., None]) * scr[..., None]
    em9 = (_hex_lin('3be8d5') * np.clip(0.35 + grid9 * 0.45 + sweep * 0.8, 0, 1)[..., None]) * scr[..., None]
    put(9, c9, scr * -0.15, 0.18, 0.20, 0.95, em9)
    # 10: warm_lamp_glow - warm golden incandescent cabin lamp & hull floodlight lens
    glow10 = np.clip(1.15 - np.sqrt((xx - 0.5) ** 2 + (yy - 0.5) ** 2) * 0.9, 0.4, 1.0)[..., None]
    c10 = _hex_lin('ffe29a') * glow10
    put(10, c10, 0.1, 0.16, 0.08, 1.0, _hex_lin('ffc45c') * glow10 * 0.95)
    # 11: bookshelf_specimens - wooden shelf rows with colorful book spines & brass specimen jars
    shelf_y = ((yy * 4.0) % 1.0 < 0.14).astype(np.float32)
    book_id = np.floor(xx * 14.0) % 5.0
    bcol = (
        (book_id == 0)[..., None] * _hex_lin('9c3b32')
        + (book_id == 1)[..., None] * _hex_lin('2d5b6b')
        + (book_id == 2)[..., None] * _hex_lin('b88e44')
        + (book_id == 3)[..., None] * _hex_lin('3f6b4e')
        + (book_id == 4)[..., None] * _hex_lin('78583c')
    )
    c11 = _hex_lin('664329') * shelf_y[..., None] + bcol * (1 - shelf_y[..., None]) * 0.85
    put(11, c11, shelf_y * 0.35 + np.sin(xx * TAU * 14) * 0.12, 0.46, 0.08, 0.84)
    for extra in (12, 13, 14, 15):
        put(extra, _hex_lin('dfd4c0'), 0.0, 0.40, 0.10, 0.95)

    normal = _height_to_normal(height, 2.0)
    maps = {
        'albedo': _save_packed_image(output, 'hero_sub_albedo', albedo, False),
        'normal': _save_packed_image(output, 'hero_sub_normal', normal, True),
        'orm': _save_packed_image(output, 'hero_sub_orm', orm, True),
        'emission': _save_packed_image(output, 'hero_sub_emission', emission, False),
    }
    sub_mat = _build_pbr_material('HeroSubmarineAtlas', maps, blended=False, emission_strength=1.0)

    # Transparent teal pressure glass material (alpha = 0.30)
    glass_mat = bpy.data.materials.new('HeroSubmarineGlass')
    glass_mat.use_nodes = True
    glass_mat.use_backface_culling = True
    if hasattr(glass_mat, 'surface_render_method'):
        glass_mat.surface_render_method = 'BLENDED'
    if hasattr(glass_mat, 'blend_method'):
        glass_mat.blend_method = 'BLEND'
    g_bsdf = next(n for n in glass_mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    g_bsdf.inputs['Base Color'].default_value = (*_hex_lin('6bc2cf'), 1.0)
    g_bsdf.inputs['Alpha'].default_value = 0.30
    g_bsdf.inputs['Roughness'].default_value = 0.09
    g_bsdf.inputs['Metallic'].default_value = 0.08
    g_bsdf.inputs['IOR'].default_value = 1.48
    return sub_mat, glass_mat


def _fin_membrane(trim=False):
    shape = Shape()
    # One narrow foot pocket divides into two fluid, swept leaves. The open
    # swallow-tail is real geometry, readable from either side while swimming.
    for side in (-1, 1):
        points = [
            (side*.013, .001, -.020, .026, .014),
            (side*.022, .000, .065, .029, .012),
            (side*.038, -.002, .180, .033, .009),
            (side*.053, -.006, .310, .032, .006),
            (side*.066, -.012, .430, .022, .0035),
            (side*.080, -.024, .550, .0020, .0014),
        ]
        if trim:
            for edge in (-1, 1):
                coords = [(cx+edge*rx*.94, cy, z) for cx, cy, z, rx, ry in points]
                shape.tube(coords, [.0022, .0021, .0019, .0016, .0013, .0013], 6)
            continue
        lobe = Shape().loft([(z, rx, ry, 0) for cx, cy, z, rx, ry in points], 12, 2)
        # Loft's height maps to the fin length, and its second radial axis to
        # blade thickness. Interpolate the graceful lateral sweep per section.
        z_values = [p[2] for p in points]
        def move(p):
            cx = float(np.interp(p.y, z_values, [v[0] for v in points]))
            cy = float(np.interp(p.y, z_values, [v[1] for v in points]))
            return (p.x+cx, p.z+cy, p.y)
        # Swap y/z is a reflection, so explicitly restore the face winding.
        lobe.transform(move)
        lobe.faces = [tuple(reversed(f)) for f in lobe.faces]
        shape.merge(lobe)
    return shape


def _diver():
    profiles = {
        'torso': [(-.19,.079,.061,.009),(-.145,.110,.070,.007),(-.065,.108,.069,.005),(.020,.113,.076,-.003),(.105,.141,.088,-.006),(.184,.167,.083,0),(.235,.154,.073,.002),(.279,.094,.058,.003),(.307,.066,.048,.004)],
        'chest': [(-.036,.047,.013,-.067),(.030,.074,.018,-.071),(.115,.121,.022,-.079),(.185,.116,.020,-.074),(.232,.078,.012,-.059)],
        'helmet': [(-.100,.050,.054,.005),(-.079,.084,.078,.004),(-.030,.105,.094,.006),(.032,.108,.097,.009),(.084,.093,.084,.014),(.119,.059,.055,.017),(.136,.014,.014,.018)],
        'visor': [(-.053,.052,.014,-.078),(-.029,.090,.022,-.083),(.015,.098,.027,-.086),(.053,.089,.022,-.080),(.076,.050,.012,-.069)],
        'collar': [(-.018,.080,.065,-.002),(-.008,.088,.072,-.003),(.008,.088,.072,-.002),(.017,.080,.064,-.001)],
        'belt': [(-.133,.110,.075,.005),(-.123,.118,.081,.005),(-.108,.117,.080,.004),(-.100,.109,.074,.004)],
        'backpack': [(-.175,.047,.025,.022),(-.140,.084,.042,.025),(-.070,.096,.046,.025),(.090,.100,.049,.022),(.159,.071,.040,.014),(.185,.029,.020,.008)],
        'tank': [(-.162,.010,.012,0),(-.149,.029,.032,0),(-.125,.037,.039,0),(.105,.035,.038,-.002),(.145,.026,.029,-.003),(.165,.007,.009,-.003)],
        'shoulder': [(-.079,.020,.022,-.002),(-.041,.043,.039,-.005),(.005,.047,.044,-.002),(.040,.036,.032,.003),(.055,.015,.014,.005)],
        # The built-in arm mesh already has a 32-degree tilt. Its elbow is at
        # local y=-.15, not at the old mesh's y=-.214 extremity. Shorten and
        # tuck the terminal section into the real elbow sleeve so no capped
        # cylinder hangs past the joint when the forearm swings forwards.
        'upper_arm': [(-.084,.026,.026,-.012),(-.053,.033,.033,-.006),(.002,.041,.037,0),(.059,.046,.041,.002),(.106,.030,.030,0)],
        'forearm': [(-.125,.025,.025,0),(-.087,.031,.031,.001),(-.020,.038,.034,.001),(.049,.041,.036,0),(.109,.030,.030,0)],
        'glove': [(-.043,.021,.021,-.007),(-.023,.032,.031,-.003),(.002,.035,.033,0),(.027,.031,.029,.003),(.043,.019,.021,.005)],
        'thigh': [(-.146,.034,.037,0),(-.086,.042,.046,.001),(-.010,.053,.055,.002),(.066,.062,.061,.002),(.129,.047,.049,0)],
        'knee': [(-.050,.027,.028,0),(-.026,.039,.042,-.006),(.008,.044,.044,-.008),(.035,.037,.036,-.002),(.050,.024,.025,.002)],
        'calf': [(-.142,.025,.028,0),(-.092,.031,.035,.001),(-.029,.045,.048,.003),(.040,.048,.047,.003),(.083,.042,.041,.001),(.123,.033,.033,0)],
    }
    for key, profile in profiles.items():
        Shape().loft(profile, 22 if key in ('torso','helmet','visor') else 16, 2).object('diver_'+key)
    Shape().tube([(0,.034,.024),(0,.018,.015),(0,-.003,0),(0,-.023,-.026),(0,-.038,-.052)],
                 [.029,.033,.035,.033,.029],12).object('diver_elbow_sleeve')
    Shape().loft([(-.038,.013,.008,.024),(-.014,.030,.015,.025),(.016,.028,.014,.020),(.040,.009,.006,.014)],
                 14,2).object('diver_elbow_guard')
    rim = Shape()
    # A complete horseshoe bezel follows the smoky glass rather than making
    # a solid golden mask. The crown stays unobstructed for the headlamp.
    rim_points = []
    for i in range(41):
        a = TAU*i/40
        rim_points.append((math.cos(a)*.099, math.sin(a)*.069+.009, -.079-.018*math.cos(a)**2))
    rim.tube(rim_points, [.0027]*len(rim_points), 6).object('diver_visor_rim')
    harness = Shape()
    for side in (-1, 1):
        harness.tube([(side*.046,.294,-.040),(side*.093,.220,-.075),(side*.101,.133,-.100),
                      (side*.066,.025,-.083),(side*.066,-.106,-.066)], [.0032,.0031,.0027,.0023,.0025], 6)
        harness.tube([(side*.023,-.107,-.078),(side*.057,-.111,-.078),(side*.093,-.111,-.062)], [.003]*3, 6)
    harness.object('diver_harness')
    _fin_membrane().object('diver_fin')
    _fin_membrane(trim=True).object('diver_fin_trim')


def _body(profile, kind='round'):
    # Profiles along length (Godot Z), x half-width and y half-height.
    shape = Shape().loft(profile, 24, 2)
    shape.transform(lambda p: (p.x, p.z, p.y))
    shape.faces = [tuple(reversed(f)) for f in shape.faces]
    return shape.normalize()


def _atlas_uv(tile, u, v):
    u = max(0.0, min(1.0, float(u)))
    v = max(0.0, min(1.0, float(v)))
    if tile >= 150:
        sub = tile - 150  # 0:TL(0,1), 1:TR(1,1), 2:BL(0,0), 3:BR(1,0)
        sc, sr = (sub % 2), (1 if sub < 2 else 0)
        pad = 0.08
        su = (sc + pad + u * (1.0 - 2.0 * pad)) * 0.5
        sv = (sr + pad + v * (1.0 - 2.0 * pad)) * 0.5
        return ((3.0 + su) * 0.25, (3.0 + sv) * 0.25)
    r, c = divmod(int(tile), 4)
    pad = 0.06
    return ((c + pad + u * (1.0 - 2.0 * pad)) * 0.25, (r + pad + v * (1.0 - 2.0 * pad)) * 0.25)


def _rot_vec(p, rx=0.0, ry=0.0, rz=0.0):
    m = Matrix.Rotation(ry, 3, 'Y') @ Matrix.Rotation(rx, 3, 'X') @ Matrix.Rotation(rz, 3, 'Z')
    return m @ Vector(p)


class HeroMesh:
    """Godot-local (x,y,z) multi-tile, multi-slot mesh sculptor."""

    def __init__(self):
        self.vertices = []
        self.faces = []      # list of index tuples
        self.face_uvs = []   # list of uv tuples matching face indices
        self.face_slots = [] # 0 or 1

    def add_vert(self, p):
        self.vertices.append((float(p[0]), float(p[1]), float(p[2])))
        return len(self.vertices) - 1

    def add_face(self, idxs, uvs, slot=0):
        if len(set(idxs)) < 3:
            return
        pts = [Vector(self.vertices[i]) for i in idxs]
        if len(idxs) == 3:
            if (pts[1] - pts[0]).cross(pts[2] - pts[0]).length_squared <= 2e-11:
                return
        else:
            a1 = (pts[1] - pts[0]).cross(pts[2] - pts[0]).length_squared
            a2 = (pts[2] - pts[0]).cross(pts[3] - pts[0]).length_squared
            if a1 <= 2e-11 or a2 <= 2e-11:
                return
        self.faces.append(tuple(idxs))
        self.face_uvs.append(tuple(uvs))
        self.face_slots.append(int(slot))

    def merge(self, other, offset=(0.0, 0.0, 0.0), rot=(0.0, 0.0, 0.0), scale=(1.0, 1.0, 1.0)):
        ox, oy, oz = offset
        sx, sy, sz = scale
        base = len(self.vertices)
        flip = (sx * sy * sz) < 0.0
        for vx, vy, vz in other.vertices:
            v = _rot_vec((vx * sx, vy * sy, vz * sz), rot[0], rot[1], rot[2])
            self.add_vert((v.x + ox, v.y + oy, v.z + oz))
        for f, uv, sl in zip(other.faces, other.face_uvs, other.face_slots):
            nf = tuple(base + i for i in (reversed(f) if flip else f))
            nuv = tuple(reversed(uv)) if flip else uv
            self.faces.append(nf)
            self.face_uvs.append(nuv)
            self.face_slots.append(sl)
        return self

    def mirrored_x(self):
        out = HeroMesh()
        return out.merge(self, scale=(-1.0, 1.0, 1.0))

    def axial_loft(self, sections, sides=20, tile_fn=0, slot_fn=0, ridge_amp=0.0, ridge_freq=0, uv_height=False, uv_planar_xz=False):
        """Sections along Z: (z, rx, ry, cy[, cx]). Automatically orders z ascending."""
        secs = [tuple(s) + ((0.0,) if len(s) == 4 else ()) for s in sections]
        if secs[0][0] > secs[-1][0]:
            secs = list(reversed(secs))
        ring_ids = []
        n_sec = len(secs)
        max_rx = max(max(s[1], 0.01) for s in secs)
        for i, (z, rx, ry, cy, cx) in enumerate(secs):
            t_v = i / max(1, n_sec - 1)
            if max(rx, ry) < 0.0025 and i in (0, n_sec - 1):
                ring_ids.append(self.add_vert((cx, cy, z)))
                continue
            rx, ry = max(rx, 0.0025), max(ry, 0.0025)
            ring = []
            for j in range(sides):
                a = TAU * j / sides
                r_mod = 1.0 + (ridge_amp * max(0.0, math.sin(a)) * math.cos(a * ridge_freq) if ridge_freq else 0.0)
                ring.append(self.add_vert((cx + math.cos(a) * rx * r_mod, cy + math.sin(a) * ry * r_mod, z)))
            ring_ids.append(ring)

        def eval_tile(ti, u_mid, v_mid, a_mid):
            return ti(u_mid, v_mid, a_mid) if callable(ti) else int(ti)

        for i in range(n_sec - 1):
            r0, r1 = ring_ids[i], ring_ids[i + 1]
            v0, v1 = i / max(1, n_sec - 1), (i + 1) / max(1, n_sec - 1)
            vm = 0.5 * (v0 + v1)
            for j in range(sides):
                jn = (j + 1) % sides
                u0, u1 = j / sides, (j + 1) / sides
                am = TAU * (j + 0.5) / sides
                tl = eval_tile(tile_fn, 0.5 * (u0 + u1), vm, am)
                sl = slot_fn(0.5 * (u0 + u1), vm, am) if callable(slot_fn) else int(slot_fn)
                if uv_height:
                    va0 = 0.5 + 0.48 * math.sin(TAU * j / sides)
                    va1 = 0.5 + 0.48 * math.sin(TAU * jn / sides)
                    uv_q = (_atlas_uv(tl, v0, va0), _atlas_uv(tl, v0, va1), _atlas_uv(tl, v1, va1), _atlas_uv(tl, v1, va0))
                elif uv_planar_xz:
                    ux00 = 0.5 + 0.46 * math.cos(TAU * j / sides) * (secs[i][1] / max_rx)
                    ux01 = 0.5 + 0.46 * math.cos(TAU * jn / sides) * (secs[i][1] / max_rx)
                    ux11 = 0.5 + 0.46 * math.cos(TAU * jn / sides) * (secs[i + 1][1] / max_rx)
                    ux10 = 0.5 + 0.46 * math.cos(TAU * j / sides) * (secs[i + 1][1] / max_rx)
                    uv_q = (_atlas_uv(tl, ux00, v0), _atlas_uv(tl, ux01, v0), _atlas_uv(tl, ux11, v1), _atlas_uv(tl, ux10, v1))
                else:
                    uv_q = (_atlas_uv(tl, u0, v0), _atlas_uv(tl, u1, v0), _atlas_uv(tl, u1, v1), _atlas_uv(tl, u0, v1))
                if isinstance(r0, int) and isinstance(r1, list):
                    self.add_face((r0, r1[jn], r1[j]), (_atlas_uv(tl, v0 if uv_height else 0.5, 0.5), uv_q[2], uv_q[3]), sl)
                elif isinstance(r1, int) and isinstance(r0, list):
                    self.add_face((r0[j], r0[jn], r1), (uv_q[0], uv_q[1], _atlas_uv(tl, v1 if uv_height else 0.5, 0.5)), sl)
                elif isinstance(r0, list) and isinstance(r1, list):
                    self.add_face((r0[j], r0[jn], r1[jn], r1[j]), uv_q, sl)
        for end_i, rev in ((0, True), (n_sec - 1, False)):
            r_end = ring_ids[end_i]
            if isinstance(r_end, list):
                z, rx, ry, cy, cx = secs[end_i]
                c_idx = self.add_vert((cx, cy, z))
                tl = eval_tile(tile_fn, 0.5, 0.0 if rev else 1.0, math.pi * 0.5)
                sl = slot_fn(0.5, 0.0 if rev else 1.0, math.pi * 0.5) if callable(slot_fn) else int(slot_fn)
                for j in range(sides):
                    jn = (j + 1) % sides
                    tri = (c_idx, r_end[jn], r_end[j]) if rev else (c_idx, r_end[j], r_end[jn])
                    self.add_face(tri, (_atlas_uv(tl, 0.5, 0.5), _atlas_uv(tl, 0.8, 0.5), _atlas_uv(tl, 0.5, 0.8)), sl)
        return self

    def curved_tube(self, points, radii, sides=8, tile=0, band_every=0, band_tile=None, slot=0, sy_ratio=1.0):
        pts = [Vector(p) for p in points]
        rads = list(radii)
        n_pts = len(pts)
        tangents = []
        for i in range(n_pts):
            d = pts[min(n_pts - 1, i + 1)] - pts[max(0, i - 1)]
            tangents.append(d.normalized() if d.length > 1e-6 else Vector((0, 0, 1)))
        up = Vector((0, 1, 0)) if abs(tangents[0].y) < 0.9 else Vector((1, 0, 0))
        nrm = tangents[0].cross(up).normalized()
        rings = []
        for i, (p, r) in enumerate(enumerate_r := list(zip(pts, rads))):
            t = tangents[i]
            if i > 0:
                proj = nrm - t * nrm.dot(t)
                nrm = proj.normalized() if proj.length > 1e-5 else t.orthogonal().normalized()
            bnrm = t.cross(nrm).normalized()
            if r < 0.0022 and i in (0, n_pts - 1):
                rings.append(self.add_vert(p))
            else:
                rr = max(r, 0.0022)
                rings.append([self.add_vert(p + nrm * (math.cos(TAU * j / sides) * rr) + bnrm * (math.sin(TAU * j / sides) * rr * sy_ratio)) for j in range(sides)])
        for i in range(n_pts - 1):
            r0, r1 = rings[i], rings[i + 1]
            v0, v1 = i / max(1, n_pts - 1), (i + 1) / max(1, n_pts - 1)
            tl = band_tile if (band_every and band_tile is not None and (i // band_every) % 2 == 1) else (tile(i / max(1, n_pts - 1)) if callable(tile) else tile)
            for j in range(sides):
                jn = (j + 1) % sides
                u0, u1 = j / sides, (j + 1) / sides
                if isinstance(r0, int) and isinstance(r1, list):
                    self.add_face((r0, r1[jn], r1[j]), (_atlas_uv(tl, 0.5, v0), _atlas_uv(tl, u1, v1), _atlas_uv(tl, u0, v1)), slot)
                elif isinstance(r1, int) and isinstance(r0, list):
                    self.add_face((r0[j], r0[jn], r1), (_atlas_uv(tl, u0, v0), _atlas_uv(tl, u1, v0), _atlas_uv(tl, 0.5, v1)), slot)
                elif isinstance(r0, list) and isinstance(r1, list):
                    self.add_face((r0[j], r0[jn], r1[jn], r1[j]),
                                  (_atlas_uv(tl, u0, v0), _atlas_uv(tl, u1, v0), _atlas_uv(tl, u1, v1), _atlas_uv(tl, u0, v1)), slot)
        for end_i, rev in ((0, True), (n_pts - 1, False)):
            re = rings[end_i]
            if isinstance(re, list):
                ci = self.add_vert(pts[end_i])
                tl = tile(0.0 if rev else 1.0) if callable(tile) else tile
                for j in range(sides):
                    jn = (j + 1) % sides
                    self.add_face((ci, re[jn], re[j]) if rev else (ci, re[j], re[jn]),
                                  (_atlas_uv(tl, 0.5, 0.5), _atlas_uv(tl, 0.8, 0.5), _atlas_uv(tl, 0.5, 0.8)), slot)
        return self

    def hydrofoil(self, lead_pts, trail_pts, normal=(0, 1, 0), rows=9, cols=4, thickness=0.03, camber=0.025, pleat_amp=0.0, pleats=6, tile=6, slot=0):
        lp = [Vector(p) for p in lead_pts]
        tp = [Vector(p) for p in trail_pts]
        nrm = Vector(normal).normalized()

        def sample(curve, t):
            pos = t * (len(curve) - 1)
            idx = min(len(curve) - 2, max(0, int(pos)))
            return curve[idx].lerp(curve[idx + 1], pos - idx)

        grid = {}
        for side_idx, sign in enumerate((1.0, -1.0)):
            for i in range(rows + 1):
                u = i / rows
                p_front = sample(lp, u)
                p_back = sample(tp, u)
                chord = max((p_front - p_back).length, 0.02)
                t_half = max(0.0025, thickness * 0.5 * (1.0 - 0.72 * u) * min(1.0, chord * 4.0))
                for j in range(cols + 1):
                    v = j / cols
                    arch = math.sin(math.pi * v) * camber * (1.0 - 0.5 * u)
                    pleat = math.sin(u * math.pi * pleats) * pleat_amp * math.sin(math.pi * v)
                    pt = p_front.lerp(p_back, v) + nrm * (sign * t_half + arch + pleat)
                    grid[(side_idx, i, j)] = self.add_vert(pt)
        for side_idx in (0, 1):
            for i in range(rows):
                for j in range(cols):
                    a, b = grid[(side_idx, i, j)], grid[(side_idx, i + 1, j)]
                    c, d = grid[(side_idx, i + 1, j + 1)], grid[(side_idx, i, j + 1)]
                    u0, u1 = i / rows, (i + 1) / rows
                    v0, v1 = j / cols, (j + 1) / cols
                    q = (a, b, c, d) if side_idx == 0 else (a, d, c, b)
                    uv = (_atlas_uv(tile, u0, v0), _atlas_uv(tile, u1, v0), _atlas_uv(tile, u1, v1), _atlas_uv(tile, u0, v1))
                    self.add_face(q, uv if side_idx == 0 else (uv[0], uv[3], uv[2], uv[1]), slot)
        for i in range(rows):
            for j, rev in ((0, True), (cols, False)):
                a, b = grid[(0, i, j)], grid[(0, i + 1, j)]
                c, d = grid[(1, i + 1, j)], grid[(1, i, j)]
                q = (a, d, c, b) if rev else (a, b, c, d)
                self.add_face(q, (_atlas_uv(tile, 0.1, 0.1), _atlas_uv(tile, 0.9, 0.1), _atlas_uv(tile, 0.9, 0.9), _atlas_uv(tile, 0.1, 0.9)), slot)
        for i, rev in ((0, False), (rows, True)):
            for j in range(cols):
                a, b = grid[(0, i, j)], grid[(0, i, j + 1)]
                c, d = grid[(1, i, j + 1)], grid[(1, i, j)]
                q = (a, d, c, b) if rev else (a, b, c, d)
                self.add_face(q, (_atlas_uv(tile, 0.1, 0.1), _atlas_uv(tile, 0.9, 0.1), _atlas_uv(tile, 0.9, 0.9), _atlas_uv(tile, 0.1, 0.9)), slot)
        return self

    def box(self, center, size, tile=0, front_tile=None, top_tile=None, rot=(0, 0, 0), slot=0):
        hx, hy, hz = size[0] * 0.5, size[1] * 0.5, size[2] * 0.5
        sub = HeroMesh()
        corners = [
            (-hx, -hy, -hz), (hx, -hy, -hz), (hx, hy, -hz), (-hx, hy, -hz),
            (-hx, -hy, hz), (hx, -hy, hz), (hx, hy, hz), (-hx, hy, hz),
        ]
        ids = [sub.add_vert(c) for c in corners]
        ft = front_tile if front_tile is not None else tile
        tt = top_tile if top_tile is not None else tile
        quads = [
            ((0, 3, 2, 1), ft),   # -Z front
            ((4, 5, 6, 7), tile), # +Z back
            ((0, 4, 7, 3), tile), # -X left
            ((1, 2, 6, 5), tile), # +X right
            ((3, 7, 6, 2), tt),   # +Y top
            ((0, 1, 5, 4), tile), # -Y bottom
        ]
        for q, tl in quads:
            sub.add_face([ids[k] for k in q], (_atlas_uv(tl, 0, 0), _atlas_uv(tl, 0, 1), _atlas_uv(tl, 1, 1), _atlas_uv(tl, 1, 0)), slot)
        return self.merge(sub, offset=center, rot=rot)

    def lathe_y(self, center, profile_yr, sides=16, tile=0, slot=0, rot=(0, 0, 0)):
        sub = HeroMesh()
        prof = list(profile_yr)
        if prof[0][0] > prof[-1][0]:
            prof = list(reversed(prof))
        secs = [(y, r, r, 0.0, 0.0) for y, r in prof]
        # Build along Z then rotate -90 deg X so Z -> +Y
        sub.axial_loft(secs, sides=sides, tile_fn=tile, slot_fn=slot)
        return self.merge(sub, offset=center, rot=(-math.pi * 0.5 + rot[0], rot[1], rot[2]))

    def ring(self, center, rx, ry, tube_r, plane='XY', arc=(0.0, TAU), sides=24, tube_sides=8, tile=3, slot=0):
        a0, a1 = arc
        closed = abs((a1 - a0) - TAU) < 1e-4
        cnt = sides if closed else sides + 1
        pts = []
        for i in range(cnt + (1 if closed else 0)):
            a = a0 + (a1 - a0) * (i / sides)
            c, s = math.cos(a) * rx, math.sin(a) * ry
            if plane == 'XY':
                pts.append((center[0] + c, center[1] + s, center[2]))
            elif plane == 'XZ':
                pts.append((center[0] + c, center[1], center[2] + s))
            else:
                pts.append((center[0], center[1] + s, center[2] + c))
        return self.curved_tube(pts, [tube_r] * len(pts), sides=tube_sides, tile=tile, slot=slot)

    def to_object(self, name, materials, recalc_normals=True):
        bm = bmesh.new()
        uv_layer = bm.loops.layers.uv.new('ConceptDetailUV')
        bverts = [bm.verts.new((x, -z, y)) for x, y, z in self.vertices]
        bm.verts.ensure_lookup_table()
        for idxs, uvs, sl in zip(self.faces, self.face_uvs, self.face_slots):
            try:
                face = bm.faces.new([bverts[i] for i in idxs])
            except ValueError:
                continue
            face.smooth = True
            face.material_index = min(sl, len(materials) - 1)
            for loop, uv in zip(face.loops, uvs):
                loop[uv_layer].uv = uv
        if recalc_normals:
            bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        # Drop any sliver polygons before finalizing mesh
        tiny = [f for f in bm.faces if f.calc_area() <= 1e-6]
        if tiny:
            bmesh.ops.delete(bm, geom=tiny, context='FACES')
        data = bpy.data.meshes.new(name)
        bm.to_mesh(data)
        bm.free()
        data.validate(clean_customdata=False)
        data.update()
        data.calc_loop_triangles()
        for triangle in data.loop_triangles:
            a, b, c = (data.vertices[i].co for i in triangle.vertices)
            if (b - a).cross(c - a).length_squared <= 1e-12:
                raise RuntimeError(f'{name}: triangle {triangle.index} is too small for the runtime geometry contract')
        obj = bpy.data.objects.new(name, data)
        COLLECTION.objects.link(obj)
        for mat in materials:
            obj.data.materials.append(mat)
        obj['art_direction'] = 'GPT Image concept to authored multi-material PBR Blender surface'
        OBJECTS.append(obj)
        return obj


def _creatures():
    mats = [FAUNA_MAT, FAUNA_GLOW_MAT]

    def dv_tile(dorsal, ventral, split=-0.22):
        return lambda _u, _v, a: ventral if math.sin(a) < split else dorsal

    # 1. SEA SPIDER (spiny hexagonal rust-crimson carapace, chelicerae, eyes, 8 banded legs)
    spider_shell = HeroMesh()
    spider_shell.axial_loft([
        (-0.82, 0.14, 0.10, 0.88), (-0.58, 0.56, 0.24, 0.94), (-0.18, 0.78, 0.33, 0.98),
        (0.24, 0.74, 0.31, 0.96), (0.58, 0.46, 0.22, 0.91), (0.88, 0.16, 0.12, 0.86),
    ], sides=18, tile_fn=dv_tile(0, 1, -0.35), ridge_amp=0.12, ridge_freq=5)
    # Dorsal axial keel & radial marginal spines
    for z_sp in (-0.42, -0.10, 0.22, 0.48):
        spider_shell.curved_tube([(0, 1.18, z_sp), (0, 1.38, z_sp - 0.06)], [0.075, 0.004], sides=6, tile=0)
    for s in (-1.0, 1.0):
        for idx, z_m in enumerate((-0.48, -0.16, 0.16, 0.44)):
            w_m = 0.62 if idx in (1, 2) else 0.48
            spider_shell.curved_tube([(s * w_m, 0.96, z_m), (s * (w_m + 0.24), 1.08, z_m + 0.04)], [0.055, 0.004], sides=6, tile=0)
        # Hooked chelicerae + pedipalps + dark/amber clustered eyes
        spider_shell.curved_tube([(s * 0.13, 0.86, 0.82), (s * 0.18, 0.72, 1.08), (s * 0.11, 0.50, 1.12)], [0.075, 0.055, 0.005], sides=7, tile=1)
        spider_shell.curved_tube([(s * 0.28, 0.84, 0.76), (s * 0.46, 0.68, 1.14), (s * 0.38, 0.36, 1.28)], [0.052, 0.038, 0.005], sides=7, tile=1)
        spider_shell.lathe_y((s * 0.14, 0.98, 0.84), [(-0.06, 0.004), (0.0, 0.068), (0.06, 0.004)], sides=10, tile=151, slot=1)
        spider_shell.lathe_y((s * 0.24, 0.95, 0.78), [(-0.045, 0.004), (0.0, 0.048), (0.045, 0.004)], sides=8, tile=150, slot=0)
    spider_shell.to_object('creature_sea_spider_shell', mats)

    spider_leg_r = HeroMesh()
    leg_pts = [(0.0, 0.0, 0.0), (0.42, 0.24, 0.0), (0.98, 0.36, 0.0), (1.52, -0.08, 0.0), (1.86, -0.62, 0.0), (1.98, -0.96, 0.0)]
    spider_leg_r.curved_tube(leg_pts, [0.095, 0.088, 0.082, 0.064, 0.038, 0.005], sides=8, tile=1, band_every=1, band_tile=0)
    for kx, ky in ((0.42, 0.24), (0.98, 0.36), (1.52, -0.08)):
        spider_leg_r.curved_tube([(kx, ky + 0.04, 0.0), (kx + 0.12, ky + 0.19, 0.0)], [0.042, 0.004], sides=6, tile=152)
    spider_leg_r.to_object('creature_sea_spider_leg_r', mats)
    spider_leg_r.mirrored_x().to_object('creature_sea_spider_leg_l', mats)

    # 2. SEAL (dappled silver-slate & cream harbor seal with whiskers & webbed flippers)
    seal_body = HeroMesh().axial_loft([
        (-1.72, 0.08, 0.07, -0.06), (-1.35, 0.26, 0.22, -0.04), (-0.75, 0.56, 0.48, -0.02),
        (-0.05, 0.76, 0.64, 0.02), (0.68, 0.72, 0.60, 0.06), (1.28, 0.50, 0.46, 0.14), (1.56, 0.32, 0.30, 0.18),
    ], sides=22, tile_fn=dv_tile(2, 3, -0.15))
    seal_body.to_object('creature_seal_body', mats)

    seal_head = HeroMesh().axial_loft([
        (-0.22, 0.36, 0.34, -0.02), (0.15, 0.46, 0.43, 0.03), (0.52, 0.38, 0.34, 0.01),
        (0.84, 0.24, 0.19, -0.05), (1.06, 0.13, 0.11, -0.06), (1.14, 0.005, 0.005, -0.05),
    ], sides=20, tile_fn=dv_tile(2, 3, -0.18))
    seal_head.lathe_y((0.0, -0.01, 1.09), [(-0.05, 0.004), (0.0, 0.085), (0.05, 0.004)], sides=10, tile=150)
    for s in (-1.0, 1.0):
        seal_head.lathe_y((s * 0.31, 0.13, 0.56), [(-0.075, 0.004), (0.0, 0.082), (0.075, 0.004)], sides=12, tile=150)
        seal_head.lathe_y((s * 0.35, 0.16, 0.59), [(-0.024, 0.004), (0.0, 0.026), (0.024, 0.004)], sides=8, tile=153, slot=1)
        for w_i in range(4):
            wy = -0.05 - w_i * 0.032
            wz = 0.88 + (w_i % 2) * 0.06
            seal_head.curved_tube([(s * 0.18, wy, wz), (s * 0.46, wy - 0.04, wz + 0.03), (s * 0.68, wy - 0.14, wz - 0.04)],
                                  [0.010, 0.007, 0.003], sides=5, tile=152)
    seal_head.to_object('creature_seal_head', mats)

    seal_flip_r = HeroMesh().hydrofoil(
        [(0.0, 0.0, 0.18), (0.45, -0.06, 0.08), (0.95, -0.14, -0.18), (1.32, -0.20, -0.48)],
        [(0.0, 0.0, -0.22), (0.42, -0.06, -0.34), (0.88, -0.14, -0.52), (1.32, -0.20, -0.56)],
        normal=(0, 1, 0), rows=8, cols=4, thickness=0.07, camber=0.02, pleat_amp=0.008, pleats=5, tile=2)
    seal_flip_r.to_object('creature_seal_flipper_r', mats)
    seal_flip_r.mirrored_x().to_object('creature_seal_flipper_l', mats)

    seal_hind_r = HeroMesh().hydrofoil(
        [(0.0, 0.05, 0.0), (0.26, 0.14, -0.38), (0.58, 0.22, -0.86)],
        [(0.0, -0.06, 0.0), (0.18, -0.12, -0.42), (0.36, -0.20, -0.92)],
        normal=(1, 0.3, 0), rows=7, cols=4, thickness=0.05, camber=0.015, pleat_amp=0.01, pleats=5, tile=2)
    seal_hind_r.to_object('creature_seal_hind_r', mats)
    seal_hind_r.mirrored_x().to_object('creature_seal_hind_l', mats)

    # 3. WATER DRAGON (cobalt-sapphire scales, ivory ventral scutes, dorsal crest, barbels, pleated wings)
    d_seg = HeroMesh().axial_loft([
        (-0.68, 0.72, 0.56, 0.0), (-0.22, 0.86, 0.66, 0.02), (0.24, 0.86, 0.66, 0.02), (0.68, 0.72, 0.56, 0.0),
    ], sides=18, tile_fn=dv_tile(4, 5, -0.22), ridge_amp=0.06, ridge_freq=3)
    d_seg.hydrofoil(
        [(0.0, 0.56, 0.58), (0.0, 0.58, 0.0), (0.0, 0.54, -0.58)],
        [(0.0, 1.38, 0.25), (0.0, 1.65, -0.28), (0.0, 1.12, -0.86)],
        normal=(1, 0, 0), rows=6, cols=3, thickness=0.045, camber=0.0, pleat_amp=0.015, pleats=4, tile=6)
    d_seg.curved_tube([(0.0, 0.56, 0.42), (0.0, 1.22, 0.05), (0.0, 1.72, -0.45)], [0.055, 0.036, 0.005], sides=6, tile=5)
    for s in (-1.0, 1.0):
        d_seg.lathe_y((s * 0.80, 0.06, 0.05), [(-0.07, 0.004), (0.0, 0.075), (0.07, 0.004)], sides=8, tile=153, slot=1)
    d_seg.to_object('creature_water_dragon_segment', mats)

    d_head = HeroMesh().axial_loft([
        (-0.85, 0.88, 0.72, 0.08), (-0.15, 0.96, 0.74, 0.12), (0.65, 0.72, 0.52, 0.08),
        (1.48, 0.44, 0.30, 0.02), (2.25, 0.26, 0.19, -0.02), (2.52, 0.005, 0.005, -0.02),
    ], sides=18, tile_fn=dv_tile(4, 5, -0.12))
    # Articulated-look lower jaw + horns + cheek frills + fangs + flowing barbels
    d_head.axial_loft([
        (-0.35, 0.66, 0.24, -0.34), (0.65, 0.52, 0.20, -0.32), (1.65, 0.32, 0.14, -0.26), (2.28, 0.005, 0.005, -0.20),
    ], sides=12, tile_fn=5)
    d_head.hydrofoil([(0.0, 0.74, 0.45), (0.0, 0.78, -0.65)], [(0.0, 1.55, 0.05), (0.0, 1.85, -1.25)],
                     normal=(1, 0, 0), rows=6, cols=3, thickness=0.05, pleat_amp=0.015, pleats=4, tile=6)
    for s in (-1.0, 1.0):
        d_head.curved_tube([(s * 0.52, 0.62, -0.05), (s * 0.92, 1.05, -0.85), (s * 1.18, 1.42, -1.85)], [0.16, 0.095, 0.006], sides=8, tile=5)
        d_head.curved_tube([(s * 0.68, 0.18, -0.15), (s * 1.15, 0.28, -0.78), (s * 1.38, 0.42, -1.35)], [0.11, 0.065, 0.005], sides=7, tile=5)
        d_head.lathe_y((s * 0.66, 0.28, 0.62), [(-0.14, 0.005), (0.0, 0.16), (0.14, 0.005)], sides=10, tile=151, slot=1)
        # Upper snout & chin sensory barbels
        d_head.curved_tube([(s * 0.24, -0.02, 2.05), (s * 0.68, -0.38, 2.15), (s * 0.95, -0.95, 1.65), (s * 0.78, -1.48, 0.95)],
                           [0.036, 0.026, 0.016, 0.004], sides=6, tile=5)
        d_head.curved_tube([(s * 0.18, -0.34, 1.65), (s * 0.42, -0.78, 1.45), (s * 0.35, -1.25, 0.92)],
                           [0.028, 0.018, 0.004], sides=6, tile=5)
        for f_i in range(6):
            fz = 0.75 + f_i * 0.26
            fw = 0.44 - f_i * 0.042
            d_head.curved_tube([(s * fw, -0.08, fz), (s * fw, -0.26, fz + 0.02)], [0.036, 0.004], sides=5, tile=152)
    d_head.to_object('creature_water_dragon_head', mats)

    d_pec_r = HeroMesh().hydrofoil(
        [(0.0, 0.0, 0.55), (1.45, -0.42, 0.18), (3.15, -1.05, -0.65), (4.65, -1.75, -1.95)],
        [(0.0, 0.0, -0.85), (1.25, -0.58, -1.65), (2.65, -1.28, -2.65), (4.65, -1.75, -2.18)],
        normal=(0, 1, 0), rows=10, cols=5, thickness=0.08, camber=0.06, pleat_amp=0.03, pleats=7, tile=6)
    d_pec_r.curved_tube([(0.0, 0.03, 0.52), (1.45, -0.39, 0.16), (3.15, -1.02, -0.66), (4.58, -1.72, -1.93)],
                        [0.085, 0.065, 0.042, 0.005], sides=7, tile=5)
    d_pec_r.to_object('creature_water_dragon_pectoral_r', mats)
    d_pec_r.mirrored_x().to_object('creature_water_dragon_pectoral_l', mats)

    d_pel_r = HeroMesh().hydrofoil(
        [(0.0, 0.0, 0.25), (0.85, -0.18, -0.15), (1.95, -0.48, -0.95)],
        [(0.0, 0.0, -0.35), (0.75, -0.22, -0.85), (1.95, -0.48, -1.08)],
        normal=(0, 1, 0), rows=7, cols=4, thickness=0.05, camber=0.03, pleat_amp=0.02, pleats=5, tile=6)
    d_pel_r.to_object('creature_water_dragon_pelvic_r', mats)
    d_pel_r.mirrored_x().to_object('creature_water_dragon_pelvic_l', mats)

    d_caudal = HeroMesh()
    for sign in (1.0, -1.0):
        d_caudal.hydrofoil(
            [(0.0, 0.0, 0.15), (0.0, sign * 0.95, -0.95), (0.0, sign * 2.35, -2.55)],
            [(0.0, 0.0, -0.45), (0.0, sign * 0.52, -1.55), (0.0, sign * 2.20, -2.72)],
            normal=(1, 0, 0), rows=8, cols=4, thickness=0.05, camber=0.0, pleat_amp=0.025, pleats=6, tile=6)
    d_caudal.to_object('creature_water_dragon_caudal', mats)

    # 4. FLYING FISH (metallic cobalt & silver torpedo body, huge rayed amber-blue pectoral & pelvic wings)
    ff_body = HeroMesh().axial_loft([
        (-4.35, 0.14, 0.22, 0.0), (-2.85, 0.48, 0.56, 0.02), (-0.85, 0.92, 0.98, 0.06),
        (1.45, 1.05, 1.06, 0.08), (3.45, 0.84, 0.88, 0.06), (4.65, 0.36, 0.42, 0.02), (5.15, 0.005, 0.005, 0.0),
    ], sides=20, tile_fn=7, uv_height=True)
    ff_body.hydrofoil([(0.0, 0.82, -1.15), (0.0, 0.56, -2.85)], [(0.0, 1.95, -1.85), (0.0, 1.35, -3.45)],
                      normal=(1, 0, 0), rows=6, cols=3, thickness=0.045, pleat_amp=0.015, pleats=5, tile=8)
    ff_body.hydrofoil([(0.0, -0.78, -1.45), (0.0, -0.52, -2.95)], [(0.0, -1.65, -2.05), (0.0, -1.10, -3.45)],
                      normal=(1, 0, 0), rows=5, cols=3, thickness=0.04, pleat_amp=0.012, pleats=4, tile=8)
    for s in (-1.0, 1.0):
        ff_body.lathe_y((s * 0.72, 0.24, 3.85), [(-0.18, 0.005), (0.0, 0.26), (0.18, 0.005)], sides=12, tile=150)
        ff_body.ring((s * 0.76, 0.24, 3.85), 0.24, 0.24, 0.032, plane='YZ', sides=14, tube_sides=6, tile=153, slot=1)
    ff_body.to_object('creature_flying_fish_body', mats)

    ff_wing_r = HeroMesh().hydrofoil(
        [(0.0, 0.0, 0.65), (1.95, 0.88, 0.45), (4.35, 1.95, -0.25), (6.45, 2.85, -1.45)],
        [(0.0, 0.0, -1.35), (1.75, 0.38, -2.25), (3.85, 1.15, -3.05), (6.45, 2.80, -1.72)],
        normal=(0, 1, 0), rows=12, cols=5, thickness=0.065, camber=0.07, pleat_amp=0.035, pleats=9, tile=8)
    ff_wing_r.curved_tube([(0.0, 0.02, 0.62), (1.95, 0.90, 0.43), (4.35, 1.97, -0.26), (6.38, 2.84, -1.44)],
                          [0.09, 0.068, 0.042, 0.005], sides=7, tile=5)
    ff_wing_r.to_object('creature_flying_fish_wing_r', mats)
    ff_wing_r.mirrored_x().to_object('creature_flying_fish_wing_l', mats)

    ff_pel_r = HeroMesh().hydrofoil(
        [(0.0, 0.0, 0.35), (1.25, -0.55, -0.08), (2.75, -1.25, -1.05)],
        [(0.0, 0.0, -0.55), (1.05, -0.72, -1.18), (2.75, -1.25, -1.28)],
        normal=(0, 1, 0), rows=8, cols=4, thickness=0.045, camber=0.03, pleat_amp=0.02, pleats=6, tile=8)
    ff_pel_r.to_object('creature_flying_fish_pelvic_r', mats)
    ff_pel_r.mirrored_x().to_object('creature_flying_fish_pelvic_l', mats)

    ff_caudal = HeroMesh()
    # Hypocercal forked tail: upper lobe shorter, lower lobe sweeping & longer
    ff_caudal.hydrofoil([(0.0, 0.0, 0.12), (0.0, 0.95, -0.85), (0.0, 2.05, -2.05)],
                        [(0.0, 0.0, -0.42), (0.0, 0.55, -1.25), (0.0, 1.95, -2.18)],
                        normal=(1, 0, 0), rows=7, cols=4, thickness=0.045, pleat_amp=0.018, pleats=5, tile=8)
    ff_caudal.hydrofoil([(0.0, 0.0, 0.12), (0.0, -1.25, -1.05), (0.0, -2.85, -2.85)],
                        [(0.0, 0.0, -0.42), (0.0, -0.75, -1.55), (0.0, -2.72, -3.02)],
                        normal=(1, 0, 0), rows=8, cols=4, thickness=0.05, pleat_amp=0.02, pleats=6, tile=8)
    ff_caudal.to_object('creature_flying_fish_caudal', mats)

    # 5. KRAKEN (muscular ridged crimson mantle with tubercles, golden slit eyes, 8 sucker-lined curling arms)
    k_mantle = HeroMesh()
    m_sub = HeroMesh().axial_loft([
        (-4.2, 0.28, 0.26, 0.0), (-3.2, 1.85, 1.68, 0.12), (-1.4, 2.95, 2.65, 0.18),
        (0.6, 2.65, 2.38, 0.08), (2.2, 1.75, 1.58, -0.05), (2.9, 0.85, 0.78, -0.10),
    ], sides=22, tile_fn=9, ridge_amp=0.14, ridge_freq=6)
    for row_a in (-0.85, -0.32, 0.32, 0.85):
        for z_t in (-2.8, -1.7, -0.6, 0.5, 1.4):
            rad_here = 2.55 if abs(z_t) < 1.2 else 1.85
            tx = math.sin(row_a) * rad_here * 0.82
            ty = math.cos(row_a) * rad_here * 0.78 + 0.10
            m_sub.curved_tube([(tx, ty, z_t), (tx * 1.14, ty + 0.42, z_t - 0.12)], [0.22, 0.008], sides=6, tile=9)
    k_mantle.merge(m_sub, offset=(0.0, 3.35, -1.15), rot=(-0.58, 0.0, 0.0))
    k_mantle.to_object('creature_kraken_mantle', mats)

    k_head = HeroMesh().axial_loft([
        (-1.45, 1.65, 1.45, 0.55), (-0.25, 2.25, 1.85, 0.65), (0.95, 2.05, 1.65, 0.58),
        (1.85, 1.35, 1.15, 0.45), (2.25, 0.35, 0.32, 0.38),
    ], sides=20, tile_fn=9, ridge_amp=0.08, ridge_freq=4)
    for s in (-1.0, 1.0):
        # Heavy orbital brow + menacing golden slit eye + lateral siphon
        k_head.curved_tube([(s * 1.35, 1.35, 0.45), (s * 1.88, 1.42, 1.05), (s * 1.55, 1.12, 1.65)], [0.26, 0.30, 0.18], sides=8, tile=9)
        k_head.lathe_y((s * 1.68, 0.92, 1.08), [(-0.34, 0.008), (0.0, 0.42), (0.34, 0.008)], sides=14, tile=151, slot=1)
    k_head.curved_tube([(1.15, 0.35, -0.35), (1.75, -0.15, 0.25), (2.05, -0.42, 0.65)], [0.42, 0.32, 0.24], sides=10, tile=9)
    k_head.to_object('creature_kraken_head', mats)

    k_arm = HeroMesh()
    arm_pts, arm_rads = [], []
    for i in range(17):
        t = i / 16.0
        # Extending radially outward (+Z in local arm frame) and curling down & up at tip
        az = t * 9.6 - max(0.0, t - 0.72) ** 2 * 11.5
        ay = -math.sin(t * math.pi * 0.88) * 3.8 + max(0.0, t - 0.68) * 3.2
        ax = math.sin(t * math.pi * 1.65) * 1.25
        arm_pts.append((ax, ay, az))
        arm_rads.append(max(0.018, 0.62 * ((1.0 - t) ** 1.15)))
    k_arm.curved_tube(arm_pts, arm_rads, sides=10, tile=9)
    # Double staggered row of raised ivory suction cups along underside
    for s_idx in range(1, 14):
        p_cur = Vector(arm_pts[s_idx])
        r_cur = arm_rads[s_idx]
        for side_s in (-1.0, 1.0):
            cup_pos = p_cur + Vector((side_s * r_cur * 0.48, -r_cur * 0.78, side_s * 0.08))
            cr = max(0.045, r_cur * 0.36)
            k_arm.lathe_y(cup_pos, [(-cr * 0.45, cr * 0.65), (0.0, cr), (cr * 0.35, cr * 0.82)], sides=9, tile=10)
    k_arm.to_object('creature_kraken_arm', mats)

    # 6. COLOSSUS TURTLE (olive-emerald & golden-ochre polygonal scute carapace, hooked beak, reticulated flippers)
    t_shell = HeroMesh().axial_loft([
        (-5.45, 0.45, 0.22, 0.35), (-4.45, 2.65, 0.95, 0.65), (-2.35, 4.15, 1.65, 1.05),
        (0.25, 4.38, 1.82, 1.15), (2.65, 3.85, 1.52, 0.98), (4.55, 2.35, 0.82, 0.62), (5.35, 0.55, 0.24, 0.42),
    ], sides=26, tile_fn=dv_tile(11, 5, -0.18), ridge_amp=0.04, ridge_freq=5, uv_planar_xz=True)
    # Scalloped marginal rim & glowing ancient scute nodes
    for s_m in (-1.0, 1.0):
        rim_pts = [(s_m * 4.15 * math.sqrt(max(0.08, 1.0 - (rz / 5.0) ** 2)), 0.88 - 0.06 * abs(rz), rz) for rz in np.linspace(-4.4, 4.4, 9)]
        t_shell.curved_tube(rim_pts, [0.14] * len(rim_pts), sides=7, tile=11)
    for s in (-1.0, 1.0):
        t_shell.lathe_y((s * 2.05, 2.38, 0.25), [(-0.08, 0.006), (0.0, 0.14), (0.08, 0.006)], sides=8, tile=153, slot=1)
    t_shell.to_object('creature_colossus_turtle_shell', mats)

    t_head = HeroMesh().axial_loft([
        (-0.95, 0.82, 0.72, -0.08), (-0.15, 1.08, 0.95, 0.04), (0.75, 1.02, 0.88, 0.06),
        (1.48, 0.68, 0.62, -0.04), (1.92, 0.28, 0.32, -0.16), (2.06, 0.006, 0.006, -0.22),
    ], sides=18, tile_fn=dv_tile(12, 5, -0.30))
    # Hooked ivory-ochre beak & eyes
    t_head.curved_tube([(0.0, -0.02, 1.72), (0.0, -0.16, 2.08), (0.0, -0.38, 2.12)], [0.34, 0.20, 0.008], sides=8, tile=152)
    for s in (-1.0, 1.0):
        t_head.lathe_y((s * 0.82, 0.22, 1.02), [(-0.14, 0.006), (0.0, 0.20), (0.14, 0.006)], sides=12, tile=150)
        t_head.ring((s * 0.86, 0.22, 1.02), 0.18, 0.18, 0.028, plane='YZ', sides=12, tube_sides=6, tile=151, slot=1)
    t_head.to_object('creature_colossus_turtle_head', mats)

    t_ff_r = HeroMesh().hydrofoil(
        [(0.0, 0.0, 0.78), (1.95, -0.48, 0.55), (4.05, -1.15, -0.25), (5.75, -1.78, -1.35)],
        [(0.0, 0.0, -0.82), (1.75, -0.62, -1.18), (3.65, -1.28, -1.68), (5.75, -1.78, -1.58)],
        normal=(0, 1, 0), rows=10, cols=5, thickness=0.22, camber=0.05, tile=12)
    t_ff_r.to_object('creature_colossus_turtle_flipper_f_r', mats)
    t_ff_r.mirrored_x().to_object('creature_colossus_turtle_flipper_f_l', mats)

    t_rf_r = HeroMesh().hydrofoil(
        [(0.0, 0.0, 0.45), (1.25, -0.12, -0.15), (2.85, -0.28, -1.15)],
        [(0.0, 0.0, -0.55), (1.05, -0.16, -1.12), (2.85, -0.28, -1.38)],
        normal=(0, 1, 0), rows=8, cols=4, thickness=0.16, camber=0.03, tile=12)
    t_rf_r.to_object('creature_colossus_turtle_flipper_r_r', mats)
    t_rf_r.mirrored_x().to_object('creature_colossus_turtle_flipper_r_l', mats)

    HeroMesh().curved_tube([(0.0, 0.08, 0.25), (0.0, -0.06, -0.75), (0.0, -0.18, -1.75)], [0.38, 0.22, 0.008], sides=10, tile=12).to_object('creature_colossus_turtle_tail', mats)

    # 7. SEA WOLF (muscular mottled slate-blue predator, elongated fanged wolf jaws, 4 flippers, horizontal fluke)
    sw_body = HeroMesh().axial_loft([
        (-2.42, 0.14, 0.12, -0.04), (-1.65, 0.38, 0.34, -0.02), (-0.65, 0.68, 0.60, 0.02),
        (0.45, 0.84, 0.72, 0.04), (1.35, 0.74, 0.66, 0.10), (2.02, 0.52, 0.48, 0.16),
    ], sides=20, tile_fn=dv_tile(13, 3, -0.18))
    sw_body.to_object('creature_sea_wolf_body', mats)

    sw_head = HeroMesh().axial_loft([
        (-0.25, 0.52, 0.48, 0.0), (0.28, 0.56, 0.50, 0.04), (0.85, 0.36, 0.30, 0.02),
        (1.42, 0.22, 0.18, 0.0), (1.68, 0.005, 0.005, 0.01),
    ], sides=18, tile_fn=dv_tile(13, 3, -0.22))
    # Parted snarling lower jaw + black nose + fangs + swept lupine ears + amber eyes
    sw_head.axial_loft([
        (0.05, 0.38, 0.16, -0.20), (0.78, 0.28, 0.12, -0.24), (1.42, 0.16, 0.08, -0.26), (1.58, 0.005, 0.005, -0.25),
    ], sides=12, tile_fn=3)
    sw_head.lathe_y((0.0, 0.04, 1.62), [(-0.05, 0.004), (0.0, 0.075), (0.05, 0.004)], sides=10, tile=150)
    for s in (-1.0, 1.0):
        sw_head.curved_tube([(s * 0.34, 0.38, 0.08), (s * 0.48, 0.54, -0.38), (s * 0.52, 0.62, -0.68)], [0.10, 0.06, 0.005], sides=6, tile=13)
        sw_head.lathe_y((s * 0.38, 0.16, 0.62), [(-0.07, 0.004), (0.0, 0.088), (0.07, 0.004)], sides=10, tile=151, slot=1)
        for t_i in range(5):
            tz = 0.86 + t_i * 0.15
            tw = 0.21 - t_i * 0.016
            fh = 0.13 if t_i == 3 else 0.075
            sw_head.curved_tube([(s * tw, -0.05, tz), (s * tw, -0.05 - fh, tz + 0.01)], [0.024, 0.0035], sides=5, tile=152)
            sw_head.curved_tube([(s * (tw * 0.88), -0.22, tz - 0.02), (s * (tw * 0.88), -0.22 + fh * 0.8, tz - 0.01)], [0.020, 0.0035], sides=5, tile=152)
    sw_head.to_object('creature_sea_wolf_head', mats)

    sw_pec_r = HeroMesh().hydrofoil(
        [(0.0, 0.0, 0.30), (0.65, -0.28, 0.10), (1.38, -0.64, -0.28), (1.95, -0.98, -0.82)],
        [(0.0, 0.0, -0.32), (0.58, -0.34, -0.54), (1.22, -0.68, -0.78), (1.95, -0.98, -0.94)],
        normal=(0, 1, 0), rows=8, cols=4, thickness=0.075, camber=0.025, pleat_amp=0.01, pleats=5, tile=13)
    sw_pec_r.to_object('creature_sea_wolf_pectoral_r', mats)
    sw_pec_r.mirrored_x().to_object('creature_sea_wolf_pectoral_l', mats)

    sw_pel_r = HeroMesh().hydrofoil(
        [(0.0, 0.0, 0.18), (0.45, -0.08, -0.08), (1.05, -0.18, -0.52)],
        [(0.0, 0.0, -0.20), (0.40, -0.10, -0.42), (1.05, -0.18, -0.60)],
        normal=(0, 1, 0), rows=6, cols=4, thickness=0.05, camber=0.018, tile=13)
    sw_pel_r.to_object('creature_sea_wolf_pelvic_r', mats)
    sw_pel_r.mirrored_x().to_object('creature_sea_wolf_pelvic_l', mats)

    sw_fluke = HeroMesh()
    for s in (1.0, -1.0):
        sw_fluke.hydrofoil(
            [(0.0, 0.0, 0.12), (s * 0.55, -0.04, -0.38), (s * 1.25, -0.10, -1.05)],
            [(0.0, 0.0, -0.32), (s * 0.42, -0.04, -0.72), (s * 1.22, -0.10, -1.16)],
            normal=(0, 1, 0), rows=7, cols=4, thickness=0.055, camber=0.015, pleat_amp=0.01, pleats=4, tile=13)
    sw_fluke.to_object('creature_sea_wolf_fluke', mats)

    # 8. SCHOOL FISH (silver-blue pelagic fish with golden-ochre lateral stripe, dark eye, forked yellow tail)
    sf_body = HeroMesh().axial_loft([
        (-0.54, 0.025, 0.045, 0.0), (-0.28, 0.075, 0.125, 0.0), (0.04, 0.115, 0.175, 0.01),
        (0.32, 0.100, 0.145, 0.01), (0.52, 0.048, 0.072, 0.0), (0.60, 0.005, 0.005, 0.0),
    ], sides=14, tile_fn=14, uv_height=True)
    sf_body.hydrofoil([(0.0, 0.15, 0.12), (0.0, 0.12, -0.16)], [(0.0, 0.30, -0.04), (0.0, 0.22, -0.26)],
                      normal=(1, 0, 0), rows=4, cols=2, thickness=0.012, tile=8)
    sf_body.hydrofoil([(0.0, -0.12, -0.12), (0.0, -0.08, -0.32)], [(0.0, -0.22, -0.20), (0.0, -0.16, -0.38)],
                      normal=(1, 0, 0), rows=4, cols=2, thickness=0.010, tile=8)
    for s in (-1.0, 1.0):
        sf_body.lathe_y((s * 0.082, 0.028, 0.40), [(-0.026, 0.004), (0.0, 0.038), (0.026, 0.004)], sides=8, tile=150)
        sf_body.lathe_y((s * 0.095, 0.032, 0.41), [(-0.012, 0.0035), (0.0, 0.015), (0.012, 0.0035)], sides=6, tile=151, slot=1)
    sf_body.to_object('creature_school_fish_body', mats)

    sf_fin_r = HeroMesh().hydrofoil(
        [(0.0, 0.0, 0.04), (0.18, -0.03, -0.10)], [(0.0, 0.0, -0.04), (0.17, -0.03, -0.14)],
        normal=(0, 1, 0), rows=4, cols=2, thickness=0.010, tile=8)
    sf_fin_r.to_object('creature_school_fish_fin_r', mats)
    sf_fin_r.mirrored_x().to_object('creature_school_fish_fin_l', mats)

    sf_caudal = HeroMesh()
    for s in (1.0, -1.0):
        sf_caudal.hydrofoil(
            [(0.0, 0.0, 0.02), (0.0, s * 0.22, -0.26)], [(0.0, 0.0, -0.06), (0.0, s * 0.20, -0.30)],
            normal=(1, 0, 0), rows=4, cols=2, thickness=0.010, tile=8)
    sf_caudal.to_object('creature_school_fish_caudal', mats)


def _open_shell_and_glass(sections, sides, wall, cutout_fn, outer_tile_fn, mullion_i=(), mullion_j=(), tube_r=0.04, axis='Z'):
    """Build double-walled hull with brass-jamb window openings + matching curved glass."""
    hull = HeroMesh()
    glass = HeroMesh()
    secs = [tuple(s) for s in sections]
    if secs[0][0] > secs[-1][0]:
        secs = list(reversed(secs))
    n_s = len(secs)
    out_r, in_r, gl_r = [], [], []
    for s_coord, r1, r2, c_off in secs:
        ro, ri, rg = [], [], []
        ir1, ir2 = max(0.012, r1 - wall), max(0.012, r2 - wall)
        gr1, gr2 = max(0.012, r1 - wall * 0.28), max(0.012, r2 - wall * 0.28)
        for j in range(sides):
            a = TAU * j / sides
            ca, sa = math.cos(a), math.sin(a)
            if axis == 'Y':
                ro.append(hull.add_vert((ca * r1, s_coord, c_off - sa * r2)))
                ri.append(hull.add_vert((ca * ir1, s_coord, c_off - sa * ir2)))
                rg.append(glass.add_vert((ca * gr1, s_coord, c_off - sa * gr2)))
            else:
                ro.append(hull.add_vert((ca * r1, c_off + sa * r2, s_coord)))
                ri.append(hull.add_vert((ca * ir1, c_off + sa * ir2, s_coord)))
                rg.append(glass.add_vert((ca * gr1, c_off + sa * gr2, s_coord)))
        out_r.append(ro)
        in_r.append(ri)
        gl_r.append(rg)
    open_map = {}
    for i in range(n_s - 1):
        zm = 0.5 * (secs[i][0] + secs[i + 1][0])
        for j in range(sides):
            am = TAU * (j + 0.5) / sides
            open_map[(i, j)] = bool(cutout_fn(i, j, zm, am))
    for i in range(n_s - 1):
        v0, v1 = i / max(1, n_s - 1), (i + 1) / max(1, n_s - 1)
        zm = 0.5 * (secs[i][0] + secs[i + 1][0])
        for j in range(sides):
            jn = (j + 1) % sides
            u0, u1 = j / sides, (j + 1) / sides
            am = TAU * (j + 0.5) / sides
            if open_map[(i, j)]:
                glass.add_face((gl_r[i][j], gl_r[i][jn], gl_r[i + 1][jn], gl_r[i + 1][j]),
                               ((u0, v0), (u1, v0), (u1, v1), (u0, v1)), 1)
                continue
            tl = outer_tile_fn(i, j, zm, am)
            hull.add_face((out_r[i][j], out_r[i][jn], out_r[i + 1][jn], out_r[i + 1][j]),
                          (_atlas_uv(tl, u0, v0), _atlas_uv(tl, u1, v0), _atlas_uv(tl, u1, v1), _atlas_uv(tl, u0, v1)), 0)
            hull.add_face((in_r[i][j], in_r[i + 1][j], in_r[i + 1][jn], in_r[i][jn]),
                          (_atlas_uv(8, u0, v0), _atlas_uv(8, u0, v1), _atlas_uv(8, u1, v1), _atlas_uv(8, u1, v0)), 0)
    # Bridge brass jambs around every cutout boundary + raised brass bezel tubes
    uv_b = (_atlas_uv(3, 0.1, 0.1), _atlas_uv(3, 0.9, 0.1), _atlas_uv(3, 0.9, 0.9), _atlas_uv(3, 0.1, 0.9))
    for i in range(n_s - 1):
        for j in range(sides):
            if open_map[(i, j)]:
                continue
            jn = (j + 1) % sides
            jp = (j - 1) % sides
            if i > 0 and open_map[(i - 1, j)]:
                hull.add_face((out_r[i][jn], out_r[i][j], in_r[i][j], in_r[i][jn]), uv_b, 0)
                hull.curved_tube([hull.vertices[out_r[i][j]], hull.vertices[out_r[i][jn]]], [tube_r, tube_r], sides=6, tile=3)
            if i < n_s - 2 and open_map[(i + 1, j)]:
                hull.add_face((out_r[i + 1][j], out_r[i + 1][jn], in_r[i + 1][jn], in_r[i + 1][j]), uv_b, 0)
                hull.curved_tube([hull.vertices[out_r[i + 1][j]], hull.vertices[out_r[i + 1][jn]]], [tube_r, tube_r], sides=6, tile=3)
            if open_map[(i, jp)]:
                hull.add_face((out_r[i][j], out_r[i + 1][j], in_r[i + 1][j], in_r[i][j]), uv_b, 0)
                hull.curved_tube([hull.vertices[out_r[i][j]], hull.vertices[out_r[i + 1][j]]], [tube_r, tube_r], sides=6, tile=3)
            if open_map[(i, jn)]:
                hull.add_face((out_r[i + 1][jn], out_r[i][jn], in_r[i][jn], in_r[i + 1][jn]), uv_b, 0)
                hull.curved_tube([hull.vertices[out_r[i][jn]], hull.vertices[out_r[i + 1][jn]]], [tube_r, tube_r], sides=6, tile=3)
    # Arched ring mullions & longitudinal mullions across open glass bays
    for mi in mullion_i:
        run = []
        for j in range(sides):
            if open_map.get((max(0, mi - 1), j), False) or open_map.get((min(n_s - 2, mi), j), False):
                run.append(hull.vertices[out_r[mi][j]])
                run.append(hull.vertices[out_r[mi][(j + 1) % sides]])
            else:
                if len(run) >= 2:
                    dedup = [run[0]] + [p for k, p in enumerate(run[1:]) if (Vector(p) - Vector(run[k])).length > 1e-4]
                    if len(dedup) >= 2:
                        hull.curved_tube(dedup, [tube_r * 0.9] * len(dedup), sides=6, tile=3)
                run = []
        if len(run) >= 2:
            dedup = [run[0]] + [p for k, p in enumerate(run[1:]) if (Vector(p) - Vector(run[k])).length > 1e-4]
            if len(dedup) >= 2:
                hull.curved_tube(dedup, [tube_r * 0.9] * len(dedup), sides=6, tile=3)
    for mj in mullion_j:
        pts = [hull.vertices[out_r[i][mj]] for i in range(n_s - 1) if open_map[(i, mj)] or open_map[(i, (mj - 1) % sides)]]
        if len(pts) >= 2:
            hull.curved_tube(pts, [tube_r * 0.85] * len(pts), sides=6, tile=3)
    # End caps (outer & inner)
    uv_c0 = (_atlas_uv(0, 0.2, 0.2), _atlas_uv(0, 0.8, 0.2), _atlas_uv(0, 0.5, 0.8))
    uv_c8 = (_atlas_uv(8, 0.2, 0.2), _atlas_uv(8, 0.8, 0.2), _atlas_uv(8, 0.5, 0.8))
    for end_i, rev in ((0, True), (n_s - 1, False)):
        s_coord, rx_e, _r2, c_off = secs[end_i]
        adj_i = 0 if rev else (n_s - 2)
        bulge = (-0.22 * rx_e) if rev else (0.18 * rx_e)
        if axis == 'Y':
            co = hull.add_vert((0.0, s_coord, c_off))
            ci = hull.add_vert((0.0, s_coord + (wall if rev else -wall), c_off))
            cg = glass.add_vert((0.0, s_coord + bulge, c_off))
        else:
            co = hull.add_vert((0.0, c_off, s_coord))
            ci = hull.add_vert((0.0, c_off, s_coord + (wall if rev else -wall)))
            cg = glass.add_vert((0.0, c_off, s_coord + bulge))
        for j in range(sides):
            jn = (j + 1) % sides
            if open_map[(adj_i, j)]:
                u0, u1 = j / sides, (j + 1) / sides
                gv = 0.0 if rev else 1.0
                glass.add_face((cg, gl_r[end_i][jn], gl_r[end_i][j]) if rev else (cg, gl_r[end_i][j], gl_r[end_i][jn]),
                               ((0.5, gv), (u1, gv), (u0, gv)) if rev else ((0.5, gv), (u0, gv), (u1, gv)), 1)
            else:
                end_tl = outer_tile_fn(adj_i, j, s_coord, TAU * (j + 0.5) / sides)
                uv_ce = (_atlas_uv(end_tl, 0.2, 0.2), _atlas_uv(end_tl, 0.8, 0.2), _atlas_uv(end_tl, 0.5, 0.8))
                hull.add_face((co, out_r[end_i][jn], out_r[end_i][j]) if rev else (co, out_r[end_i][j], out_r[end_i][jn]), uv_ce, 0)
                hull.add_face((ci, in_r[end_i][j], in_r[end_i][jn]) if rev else (ci, in_r[end_i][jn], in_r[end_i][j]), uv_c8, 0)
    return hull, glass


def _sub_chair(scale=1.0):
    m = HeroMesh()
    m.lathe_y((0.0, -0.36, 0.0), [(-0.12, 0.20), (-0.08, 0.06), (0.14, 0.055), (0.18, 0.16)], sides=12, tile=3)
    m.box((0.0, -0.14, -0.02), (0.54, 0.13, 0.52), tile=5)
    m.box((0.0, 0.24, 0.20), (0.50, 0.68, 0.13), tile=5, rot=(0.16, 0.0, 0.0))
    m.box((0.0, 0.64, 0.27), (0.36, 0.18, 0.12), tile=5, rot=(0.10, 0.0, 0.0))
    for s in (-1.0, 1.0):
        m.box((s * 0.29, 0.04, 0.02), (0.08, 0.08, 0.42), tile=3, top_tile=5)
        m.box((s * 0.29, -0.06, -0.14), (0.06, 0.16, 0.06), tile=3)
    out = HeroMesh()
    return out.merge(m, scale=(scale, scale, scale))


def _sub_coral_pot(scale=1.0):
    m = HeroMesh()
    m.lathe_y((0.0, 0.0, 0.0), [(0.0, 0.11), (0.14, 0.15), (0.17, 0.16), (0.18, 0.12)], sides=12, tile=3)
    branches = [
        [(0.0, 0.14, 0.0), (0.0, 0.34, -0.02), (0.06, 0.54, -0.05)],
        [(0.0, 0.22, 0.0), (-0.14, 0.38, 0.04), (-0.22, 0.52, 0.06)],
        [(0.0, 0.26, 0.0), (0.15, 0.40, 0.05), (0.24, 0.50, 0.09)],
        [(-0.08, 0.32, 0.02), (-0.12, 0.48, -0.08)],
        [(0.09, 0.34, 0.02), (0.14, 0.48, -0.09)],
    ]
    for br in branches:
        rads = [0.036 - 0.010 * k for k in range(len(br))]
        m.curved_tube(br, rads, sides=6, tile=7)
    out = HeroMesh()
    return out.merge(m, scale=(scale, scale, scale))


def _sub_lamp(stem_len=0.28, shade_r=0.20):
    m = HeroMesh()
    m.curved_tube([(0.0, 0.0, 0.0), (0.0, -stem_len, 0.0)], [0.022, 0.022], sides=8, tile=3)
    m.lathe_y((0.0, -stem_len, 0.0), [(-0.06, shade_r), (0.02, shade_r * 0.55), (0.06, 0.04)], sides=14, tile=3)
    m.lathe_y((0.0, -stem_len - 0.05, 0.0), [(-0.07, 0.01), (-0.02, shade_r * 0.78), (0.02, shade_r * 0.72)], sides=14, tile=10)
    return m


def _sub_thruster_duct(radius=0.52, length=1.35):
    m = HeroMesh()
    hz = length * 0.5
    outer_pts = [(-hz, radius * 0.92), (-hz * 0.45, radius * 1.03), (hz * 0.35, radius * 1.02), (hz, radius * 0.90)]
    inner_r = radius * 0.78
    sides = 22
    o_rings, i_rings = [], []
    for z, r in outer_pts:
        o_rings.append([m.add_vert((math.cos(TAU * j / sides) * r, math.sin(TAU * j / sides) * r, z)) for j in range(sides)])
        i_rings.append([m.add_vert((math.cos(TAU * j / sides) * inner_r, math.sin(TAU * j / sides) * inner_r, z)) for j in range(sides)])
    for idx in range(len(outer_pts) - 1):
        tl = 2 if idx == 1 else 0
        for j in range(sides):
            jn = (j + 1) % sides
            u0, u1 = j / sides, (j + 1) / sides
            m.add_face((o_rings[idx][j], o_rings[idx][jn], o_rings[idx + 1][jn], o_rings[idx + 1][j]),
                       (_atlas_uv(tl, u0, 0.2), _atlas_uv(tl, u1, 0.2), _atlas_uv(tl, u1, 0.8), _atlas_uv(tl, u0, 0.8)), 0)
            m.add_face((i_rings[idx][j], i_rings[idx + 1][j], i_rings[idx + 1][jn], i_rings[idx][jn]),
                       (_atlas_uv(4, u0, 0.2), _atlas_uv(4, u0, 0.8), _atlas_uv(4, u1, 0.8), _atlas_uv(4, u1, 0.2)), 0)
    uv_br = (_atlas_uv(3, 0.1, 0.1), _atlas_uv(3, 0.9, 0.1), _atlas_uv(3, 0.9, 0.9), _atlas_uv(3, 0.1, 0.9))
    for end_i, rev in ((0, True), (len(outer_pts) - 1, False)):
        for j in range(sides):
            jn = (j + 1) % sides
            q = (o_rings[end_i][jn], o_rings[end_i][j], i_rings[end_i][j], i_rings[end_i][jn]) if rev else (o_rings[end_i][j], o_rings[end_i][jn], i_rings[end_i][jn], i_rings[end_i][j])
            m.add_face(q, uv_br, 0)
    m.ring((0.0, 0.0, -hz), radius * 0.86, radius * 0.86, radius * 0.065, plane='XY', sides=22, tube_sides=8, tile=3)
    m.ring((0.0, 0.0, hz), radius * 0.85, radius * 0.85, radius * 0.065, plane='XY', sides=22, tube_sides=8, tile=3)
    for st in range(4):
        ang = st * TAU / 4.0 + math.pi * 0.25
        m.curved_tube([(0.0, 0.0, 0.0), (math.cos(ang) * inner_r, math.sin(ang) * inner_r, 0.0)], [radius * 0.06, radius * 0.05], sides=6, tile=3)
    return m


def _vehicles():
    sub_mats = [SUB_MAT, SUB_GLASS_MAT]

    # Shared 5-blade machined antique-brass propeller rotor (unit diameter ~1.0m)
    rotor = HeroMesh()
    rotor.axial_loft([(-0.24, 0.01, 0.01, 0.0), (-0.06, 0.14, 0.14, 0.0), (0.14, 0.13, 0.13, 0.0), (0.28, 0.01, 0.01, 0.0)], sides=14, tile_fn=3)
    blade = HeroMesh().hydrofoil(
        [(0.08, 0.0, -0.04), (0.28, 0.05, -0.03), (0.48, 0.09, 0.01)],
        [(0.08, -0.04, 0.04), (0.26, -0.07, 0.05), (0.46, -0.02, 0.06)],
        normal=(0, 0, 1), rows=5, cols=3, thickness=0.024, camber=0.015, tile=3)
    for b_i in range(5):
        rotor.merge(blade, rot=(0.0, 0.0, b_i * TAU / 5.0))
    rotor.to_object('vehicle_propeller_rotor', sub_mats)

    # Shared styled Escape Pod (unit ~1x1x1 scaled by _build_escape_pod)
    pod_b = HeroMesh().axial_loft([
        (-0.50, 0.04, 0.04, 0.0), (-0.36, 0.36, 0.35, 0.01), (-0.08, 0.48, 0.46, 0.01),
        (0.22, 0.45, 0.44, 0.0), (0.42, 0.28, 0.28, -0.01), (0.50, 0.05, 0.05, 0.0),
    ], sides=18, tile_fn=lambda _u, v, a: 2 if 0.42 < v < 0.62 else (1 if math.sin(a) < -0.35 else 0))
    pod_b.ring((0.0, 0.06, -0.32), 0.22, 0.20, 0.032, plane='XY', sides=16, tube_sides=6, tile=3)
    pod_b.to_object('vehicle_escape_pod_body', sub_mats)
    pod_g = HeroMesh().axial_loft([(-0.49, 0.012, 0.012, 0.06), (-0.43, 0.12, 0.11, 0.06), (-0.36, 0.20, 0.18, 0.06), (-0.30, 0.21, 0.19, 0.06)], sides=16, tile_fn=0, slot_fn=1)
    pod_g.to_object('vehicle_escape_pod_glass', sub_mats, recalc_normals=False)

    # 1. MINI SUBMARINE (vertical egg hull, open front panoramic dome, hydraulic skids, twin side thrusters, furnished cabin)
    mini_secs = [
        (-1.46, 0.04, 0.04, 0.04), (-1.36, 0.38, 0.36, 0.04), (-1.14, 0.70, 0.68, 0.05),
        (-0.82, 0.91, 0.90, 0.06), (-0.40, 1.02, 1.02, 0.06), (0.06, 1.04, 1.04, 0.06),
        (0.52, 0.99, 0.99, 0.06), (0.92, 0.85, 0.84, 0.05), (1.22, 0.62, 0.61, 0.04),
        (1.40, 0.34, 0.34, 0.03), (1.48, 0.04, 0.04, 0.02),
    ]
    def mini_cut(i, _j, _ym, am):
        # Constant meridian span on egg radii r(y) naturally forms a smooth continuous oval bezel with zero staircase steps
        return i in (2, 3, 4, 5, 6, 7) and math.sin(am) > 0.48
    def mini_tile(i, _j, _zm, am):
        if i in (0, 1):
            return 1
        if i == 8 and math.sin(am) > -0.25:
            return 2
        return 0
    mini_ext, mini_gl = _open_shell_and_glass(mini_secs, 32, 0.09, mini_cut, mini_tile, tube_r=0.042, axis='Y')
    # Front spherical-dome glass bulge & perimeter brass bezel + top hatch cupola + mast + side portholes
    mini_ext.ring((0.0, 1.48, 0.02), 0.36, 0.36, 0.045, plane='XZ', sides=18, tube_sides=7, tile=3)
    mini_gl.lathe_y((0.0, 1.50, 0.02), [(0.0, 0.34), (0.11, 0.24), (0.16, 0.02)], sides=16, tile=0, slot=1)
    mini_ext.curved_tube([(-0.34, 1.38, 0.12), (-0.34, 1.92, 0.12)], [0.028, 0.014], sides=7, tile=3)
    mini_ext.lathe_y((0.0, -0.96, -0.76), [(-0.06, 0.02), (0.0, 0.16), (0.06, 0.02)], sides=12, tile=10)
    mini_ext.curved_tube([(0.0, -1.08, -0.25), (0.0, -1.08, -1.28)], [0.11, 0.09], sides=10, tile=4)
    for s in (-1.0, 1.0):
        mini_ext.ring((s * 0.94, 0.42, -0.08), 0.22, 0.26, 0.032, plane='YZ', sides=14, tube_sides=6, tile=3)
        mini_ext.merge(_sub_thruster_duct(0.42, 0.88), offset=(s * 1.32, -0.32, 0.18))
        mini_ext.curved_tube([(s * 0.86, -0.28, 0.18), (s * 0.98, -0.32, 0.18)], [0.14, 0.14], sides=8, tile=3)
        # Articulated hydraulic landing skid
        mini_ext.curved_tube([(s * 0.56, -1.12, -0.05), (s * 0.92, -1.42, -0.08)], [0.13, 0.10], sides=8, tile=4)
        mini_ext.box((s * 0.98, -1.58, -0.08), (0.18, 0.42, 0.26), tile=0, front_tile=2, rot=(0.0, 0.0, -s * 0.35))
        mini_ext.lathe_y((s * 0.90, -1.40, -0.08), [(-0.07, 0.11), (0.07, 0.11)], sides=10, tile=3)
        mini_ext.box((s * 1.12, -1.82, -0.08), (0.38, 0.08, 0.56), tile=3, top_tile=4)
    mini_ext.to_object('vehicle_mini_exterior', sub_mats)
    mini_gl.to_object('vehicle_mini_glass', sub_mats, recalc_normals=False)

    mini_int = HeroMesh()
    mini_int.box((0.0, -0.68, 0.05), (1.32, 0.08, 1.28), tile=8)
    mini_int.merge(_sub_chair(0.95), offset=(0.0, -0.26, 0.14), rot=(0.0, math.pi, 0.0))
    mini_int.box((0.0, 0.12, 0.66), (1.10, 0.96, 0.20), tile=6, front_tile=11)
    mini_int.box((-0.46, -0.40, -0.24), (0.34, 0.44, 0.34), tile=6, top_tile=3)
    mini_int.merge(_sub_coral_pot(0.78), offset=(-0.45, -0.18, -0.24))
    mini_int.box((0.36, -0.36, -0.32), (0.32, 0.42, 0.26), tile=6, front_tile=9, rot=(-0.25, 0.3, 0.0))
    mini_int.merge(_sub_lamp(0.24, 0.18), offset=(0.0, 1.22, -0.05))
    mini_int.to_object('vehicle_mini_interior', sub_mats)

    # 2. SCOUT SUBMARINE (sleek 5.9m teardrop hull, forward/side glazed salon, brass mullions, tandem cream chairs, coral, 2 rear thrusters)
    scout_secs = [
        (-3.04, 0.024, 0.022, -0.04), (-2.95, 0.28, 0.25, -0.04), (-2.76, 0.62, 0.54, -0.03),
        (-2.44, 0.95, 0.81, -0.01), (-1.85, 1.26, 1.02, 0.04), (-0.95, 1.38, 1.12, 0.06),
        (0.05, 1.32, 1.06, 0.05), (1.05, 1.08, 0.88, 0.02), (2.05, 0.72, 0.62, 0.0),
        (2.92, 0.05, 0.05, 0.0),
    ]
    def scout_cut(i, _j, _zm, am):
        sa = math.sin(am)
        if i in (0, 1):
            return True
        if i in (2, 3):
            return sa > -0.36
        if i in (4, 5):
            return -0.22 < sa < 0.76 and abs(math.cos(am)) > 0.30
        return False
    def scout_tile(i, _j, _zm, am):
        sa = math.sin(am)
        if sa < -0.76:
            return 1
        if i in (6, 7) and abs(sa) < 0.30:
            return 1
        return 0
    scout_ext, scout_gl = _open_shell_and_glass(scout_secs, 32, 0.09, scout_cut, scout_tile, mullion_i=(4, 5), tube_r=0.044)
    # Dorsal observation cupola + sensor mast + swept tail fin with coral-red tip
    scout_ext.axial_loft([(-0.45, 0.42, 0.22, 1.08), (0.15, 0.48, 0.30, 1.12), (0.85, 0.34, 0.22, 1.04)], sides=16, tile_fn=0)
    scout_ext.ring((0.0, 1.24, 0.05), 0.38, 0.42, 0.04, plane='XZ', sides=18, tube_sides=6, tile=3)
    scout_gl.lathe_y((0.0, 1.26, 0.05), [(0.0, 0.36), (0.16, 0.26), (0.24, 0.02)], sides=16, tile=0, slot=1)
    scout_ext.curved_tube([(0.0, 1.22, 0.68), (0.0, 1.78, 0.68)], [0.032, 0.016], sides=7, tile=3)
    scout_ext.hydrofoil([(0.0, 0.68, 1.35), (0.0, 1.52, 2.25)], [(0.0, 0.52, 2.55), (0.0, 1.42, 2.68)],
                        normal=(1, 0, 0), rows=6, cols=3, thickness=0.09, tile=0)
    scout_ext.box((0.0, 1.46, 2.46), (0.10, 0.14, 0.44), tile=2, rot=(-0.18, 0.0, 0.0))
    for s in (-1.0, 1.0):
        scout_ext.lathe_y((s * 0.56, -0.44, -2.38), [(-0.06, 0.02), (0.0, 0.14), (0.06, 0.02)], sides=12, tile=10)
        scout_ext.curved_tube([(s * 0.82, -0.42, -1.75), (s * 0.82, -0.42, -2.68)], [0.12, 0.11], sides=10, tile=4)
        scout_ext.curved_tube([(s * 0.92, -0.08, 1.45), (s * 1.18, -0.08, 1.55)], [0.16, 0.14], sides=8, tile=3)
        scout_ext.merge(_sub_thruster_duct(0.56, 1.35), offset=(s * 1.58, -0.08, 1.55))
    scout_ext.to_object('vehicle_scout_exterior', sub_mats)
    scout_gl.to_object('vehicle_scout_glass', sub_mats, recalc_normals=False)

    scout_int = HeroMesh()
    scout_int.box((0.0, -0.44, -0.95), (1.82, 0.09, 3.05), tile=8)
    scout_int.box((0.0, 0.08, 0.55), (1.48, 1.02, 0.14), tile=6, front_tile=11)
    # Forward helm console + sonar screens + tandem cream seats + potted red coral + brass globe + ceiling lamps
    scout_int.box((0.0, -0.14, -2.05), (1.35, 0.52, 0.48), tile=6, top_tile=3, front_tile=6)
    scout_int.box((0.0, 0.18, -2.02), (0.78, 0.24, 0.12), tile=3, front_tile=9, rot=(0.35, 0.0, 0.0))
    scout_int.merge(_sub_chair(0.88), offset=(0.0, -0.08, -1.18), rot=(0.0, math.pi, 0.0))
    scout_int.merge(_sub_chair(0.88), offset=(-0.22, -0.02, -0.18), rot=(0.0, math.pi, 0.0))
    scout_int.box((0.56, -0.22, -0.58), (0.44, 0.38, 0.92), tile=6, top_tile=3)
    scout_int.merge(_sub_coral_pot(0.82), offset=(0.56, -0.03, -0.75))
    scout_int.lathe_y((0.54, 0.16, -0.22), [(-0.14, 0.08), (-0.10, 0.03), (0.02, 0.13), (0.14, 0.02)], sides=12, tile=3)
    scout_int.merge(_sub_lamp(0.22, 0.18), offset=(0.0, 0.96, -1.25))
    scout_int.merge(_sub_lamp(0.22, 0.18), offset=(0.0, 0.94, -0.20))
    scout_int.to_object('vehicle_scout_interior', sub_mats)

    # 3. TITAN SUBMARINE (24.6m grand panoramic research cruiser, multi-bay brass gallery, dorsal bridge tower, 4 stern thrusters, 4-room interior)
    titan_secs = [
        (-12.48, 0.05, 0.045, -0.04), (-12.22, 0.82, 0.74, -0.03), (-11.68, 1.72, 1.54, -0.01),
        (-10.85, 2.48, 2.22, 0.02), (-9.55, 3.18, 2.78, 0.05), (-7.25, 3.58, 3.05, 0.08),
        (-4.25, 3.68, 3.12, 0.08), (-1.05, 3.68, 3.12, 0.08), (2.15, 3.55, 3.02, 0.06),
        (4.85, 3.25, 2.75, 0.04), (7.65, 2.55, 2.18, 0.0), (10.25, 1.65, 1.45, -0.02),
        (12.25, 0.14, 0.14, -0.04),
    ]
    def titan_cut(i, _j, _zm, am):
        sa = math.sin(am)
        if i in (0, 1):
            return True
        if i in (2, 3):
            return sa > -0.35
        if i in (4, 5, 6, 7):
            return -0.20 < sa < 0.85 and abs(math.cos(am)) > 0.22
        return False
    def titan_tile(i, _j, _zm, am):
        sa = math.sin(am)
        if sa < -0.76:
            return 1
        if i == 8 and 0.20 < sa < 0.72:
            return 2
        if i in (9, 10) and abs(sa) < 0.28:
            return 1
        return 0
    titan_ext, titan_gl = _open_shell_and_glass(titan_secs, 32, 0.22, titan_cut, titan_tile, mullion_i=(4, 5, 6, 7), mullion_j=(4, 12, 20, 28), tube_r=0.105)
    # Elevated Dorsal Command Bridge Tower (conning sail with cantilevered aft arch, windows & twin masts)
    bridge_secs = [
        (-2.78, 0.04, 0.03, 3.62), (-2.52, 0.68, 0.50, 3.64), (-1.65, 1.45, 0.98, 3.85),
        (0.15, 1.52, 1.05, 3.92), (1.95, 1.18, 0.78, 3.85), (3.45, 0.12, 0.10, 3.75),
    ]
    b_ext, b_gl = _open_shell_and_glass(
        bridge_secs, 20, 0.10,
        lambda i, _j, _z, am: True if i == 0 else (i in (1, 2) and math.sin(am) > -0.15),
        lambda i, _j, _z, am: 2 if i == 4 and math.sin(am) > 0.2 else 0,
        mullion_i=(2,), tube_r=0.055)
    titan_ext.merge(b_ext)
    titan_gl.merge(b_gl)
    # Cantilevered bridge neck & aft support strut + twin tall brass sensor masts
    titan_ext.axial_loft([(-1.25, 1.15, 0.65, 3.05), (0.85, 1.12, 0.65, 3.05)], sides=14, tile_fn=0)
    titan_ext.curved_tube([(0.0, 2.85, 2.35), (0.0, 3.72, 2.55)], [0.22, 0.18], sides=10, tile=3)
    titan_ext.curved_tube([(0.0, 4.88, 1.15), (0.0, 7.65, 1.15)], [0.095, 0.045], sides=8, tile=3)
    titan_ext.curved_tube([(0.48, 4.82, 0.35), (0.48, 7.05, 0.35)], [0.075, 0.038], sides=8, tile=3)
    # Swept dorsal & ventral stern fins + 4 stern shrouded thrusters + bow torpedo ports & hull floodlights
    for s_fin, fy0, fy1 in ((1.0, 1.95, 4.45), (-1.0, -1.85, -3.75)):
        titan_ext.hydrofoil([(0.0, fy0, 7.35), (0.0, fy1, 10.65)], [(0.0, fy0 * 0.72, 10.85), (0.0, fy1 * 0.94, 11.65)],
                            normal=(1, 0, 0), rows=6, cols=3, thickness=0.22, tile=0)
        titan_ext.box((0.0, fy1 * 0.96, 11.15), (0.24, 0.28, 1.05), tile=2)
    for sx in (-1.0, 1.0):
        for sy in (-1.0, 1.0):
            titan_ext.merge(_sub_thruster_duct(1.08, 2.65), offset=(sx * 1.95, sy * 1.35, 10.65))
            titan_ext.curved_tube([(sx * 1.15, sy * 0.95, 10.25), (sx * 1.55, sy * 1.20, 10.55)], [0.24, 0.22], sides=8, tile=3)
            titan_ext.curved_tube([(sx * 1.55, -1.35 + sy * 0.55, -9.85), (sx * 1.55, -1.35 + sy * 0.55, -11.75)], [0.24, 0.22], sides=10, tile=4)
        for lz in (-9.65, -4.85, 1.25):
            titan_ext.lathe_y((sx * 1.85, -2.15, lz), [(-0.12, 0.04), (0.0, 0.34), (0.12, 0.04)], sides=12, tile=10)
    titan_ext.to_object('vehicle_titan_exterior', sub_mats)
    titan_gl.to_object('vehicle_titan_glass', sub_mats, recalc_normals=False)

    titan_int = HeroMesh()
    # Main gallery deck (-11.4 .. +4.2) & aft library bulkhead
    titan_int.box((0.0, -0.95, -3.6), (5.4, 0.22, 15.4), tile=8)
    titan_int.box((0.0, 0.35, 4.15), (4.3, 2.45, 0.28), tile=6, front_tile=11)
    # Room 1: Forward Bridge Helm (-10.8 .. -8.2)
    titan_int.box((0.0, -0.18, -10.55), (3.4, 1.15, 0.95), tile=6, top_tile=3, front_tile=6)
    titan_int.box((0.0, 0.55, -10.45), (2.2, 0.58, 0.22), tile=3, front_tile=9, rot=(0.32, 0.0, 0.0))
    titan_int.ring((0.0, 0.42, -9.95), 0.38, 0.38, 0.045, plane='XY', sides=16, tube_sides=6, tile=3)
    titan_int.merge(_sub_chair(1.65), offset=(0.0, -0.15, -8.85), rot=(0.0, math.pi, 0.0))
    # Room 2: Microscope & Marine Science Desk (-6.8 .. -4.2)
    for sx in (-1.0, 1.0):
        titan_int.box((sx * 1.85, -0.32, -5.65), (1.35, 1.05, 2.35), tile=6, top_tile=3)
    # Sculpted brass microscope + brass desk lamp on starboard/port science benches
    titan_int.box((-1.75, 0.26, -5.85), (0.36, 0.08, 0.42), tile=3)
    titan_int.curved_tube([(-1.75, 0.30, -5.72), (-1.75, 0.68, -5.62), (-1.75, 0.88, -5.78)], [0.065, 0.055, 0.042], sides=8, tile=3)
    titan_int.curved_tube([(-1.75, 0.96, -5.84), (-1.75, 0.62, -5.96)], [0.048, 0.036], sides=8, tile=3)
    titan_int.merge(_sub_lamp(0.55, 0.28), offset=(-1.75, 1.05, -5.15))
    # Room 3: Grand Midship Lounge (-3.2 .. +1.2) - 4 plush cream armchairs + round walnut/brass table + giant red coral
    titan_int.lathe_y((0.0, -0.42, -1.15), [(-0.42, 0.55), (-0.34, 0.18), (0.18, 0.16), (0.26, 1.25), (0.34, 1.28)], sides=20, tile=6)
    titan_int.ring((0.0, -0.10, -1.15), 1.28, 1.28, 0.055, plane='XZ', sides=22, tube_sides=6, tile=3)
    titan_int.merge(_sub_coral_pot(2.15), offset=(0.0, -0.08, -1.15))
    for cx, cz, yaw in ((-1.75, -2.15, 2.25), (1.75, -2.15, -2.25), (-1.75, -0.15, 0.88), (1.75, -0.15, -0.88)):
        titan_int.merge(_sub_chair(1.52), offset=(cx, -0.22, cz), rot=(0.0, yaw, 0.0))
    # Room 4: Aft Library Bookshelves & Brass Globe (+1.4 .. +4.0)
    for sx in (-1.0, 1.0):
        titan_int.box((sx * 2.25, 0.55, 2.65), (0.65, 2.75, 2.45), tile=6, front_tile=11)
    titan_int.lathe_y((1.35, -0.15, 2.55), [(-0.65, 0.32), (-0.52, 0.09), (0.05, 0.44), (0.48, 0.06)], sides=16, tile=3)
    # Upper Dorsal Command Bridge furniture + 5 warm golden gallery pendant lamps
    titan_int.box((0.0, 3.25, -0.35), (2.15, 0.14, 2.85), tile=8)
    titan_int.box((0.0, 3.62, -1.35), (1.25, 0.55, 0.48), tile=6, front_tile=9)
    titan_int.merge(_sub_chair(0.95), offset=(0.0, 3.65, -0.45), rot=(0.0, math.pi, 0.0))
    titan_int.merge(_sub_lamp(0.28, 0.22), offset=(0.0, 4.78, -0.65))
    for lz in (-8.8, -5.6, -2.4, 0.4, 2.8):
        titan_int.merge(_sub_lamp(0.65, 0.36), offset=(0.0, 2.65, lz))
    titan_int.to_object('vehicle_titan_interior', sub_mats)


def _preview_material(name, hex_value, metallic=.0, roughness=.6):
    material = MATERIAL.copy()
    material.name = name
    node = next(n for n in material.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    # Neutral detail is used at runtime. For the source atelier assign pigment
    # through a Multiply node so the saved file also displays the final intent.
    def linear(value):
        return value/12.92 if value <= .04045 else ((value+.055)/1.055)**2.4
    input_color = tuple(linear(int(hex_value[i:i+2],16)/255) for i in (0,2,4)) + (1,)
    link = next(iter(node.inputs['Base Color'].links), None)
    if link:
        mix = material.node_tree.nodes.new('ShaderNodeMixRGB')
        mix.blend_type = 'MULTIPLY'
        mix.inputs[0].default_value = 1
        mix.inputs[2].default_value = input_color
        material.node_tree.links.new(link.from_socket,mix.inputs[1])
        material.node_tree.links.new(mix.outputs[0],node.inputs['Base Color'])
    else:
        node.inputs['Base Color'].default_value = input_color
    for link in list(node.inputs['Roughness'].links):
        material.node_tree.links.remove(link)
    for link in list(node.inputs['Metallic'].links):
        material.node_tree.links.remove(link)
    node.inputs['Metallic'].default_value = metallic
    node.inputs['Roughness'].default_value = roughness
    return material


def _atelier(scene, output):
    from mathutils import Matrix

    library = {obj.name:obj for obj in OBJECTS}
    for obj in OBJECTS:
        obj.hide_render = True
        obj.hide_viewport = True
    colors = {
        'navy': _preview_material('Ink navy expedition textile','17354b',.06,.71),
        'armor': _preview_material('Sea-glass ceramic','789b9d',.10,.53),
        'gold': _preview_material('Satin antique brass','d5b566',.50,.36),
        'glass': _preview_material('Smoked blue glass','2b6e7d',.24,.18),
        'ivory': _preview_material('Pearlescent fin membranes','e1d8b8',.10,.42),
    }
    conversion=Matrix(((1,0,0),(0,0,-1),(0,1,0))).to_4x4()
    displayed=[]

    def local_transform(at=(0,0,0),rotation=(0,0,0)):
        # Godot Node3D's default Euler order is YXZ: yaw * pitch * roll.
        # Conjugating the complete matrix preserves the axis conversion for
        # both positions and rotations, including nested forearm/ankle pivots.
        rx,ry,rz=rotation
        basis=(Matrix.Rotation(ry,4,'Y') @ Matrix.Rotation(rx,4,'X') @ Matrix.Rotation(rz,4,'Z'))
        basis.translation=Vector(at)
        return conversion @ basis @ conversion.inverted()

    def pivot(name,at=(0,0,0),rotation=(0,0,0),parent=None):
        obj=bpy.data.objects.new(name,None)
        COLLECTION.objects.link(obj)
        obj.parent=parent
        obj.matrix_basis=local_transform(at,rotation)
        return obj

    def radians(values):
        return tuple(math.radians(v) for v in values)

    def clone(key,at=(0,0,0),rotation=(0,0,0),color='navy',parent=None):
        src = library['diver_'+key]
        obj = bpy.data.objects.new('Atelier '+key,src.data.copy())
        COLLECTION.objects.link(obj)
        obj.parent=parent
        obj.matrix_basis=local_transform(at,rotation)
        obj.data.materials.clear()
        obj.data.materials.append(colors[color])
        displayed.append(obj)
        return obj

    body=pivot('Atelier BodyPivot')
    clone('torso',parent=body)
    clone('chest',color='armor',parent=body)
    clone('harness',color='gold',parent=body)
    clone('belt',color='gold',parent=body)
    head=pivot('Atelier HeadPivot',(0,.34,0),(.28,0,0),body)
    for key,color in [('helmet','navy'),('visor','glass'),('visor_rim','gold')]:
        clone(key,color=color,parent=head)
    clone('collar',(0,-.092,0),color='gold',parent=head)
    backpack=pivot('Atelier ScubaBackpack',(0,.10,.145),parent=body)
    clone('backpack',parent=backpack)
    for side in (-1,1):
        clone('tank',(side*.052,0,.045),color='armor',parent=backpack)
        # This is the production idle pose at phase zero, rather than an
        # unrelated mannequin. Every part's offset and built-in tilt matches
        # _build_limb_arm/_build_limb_leg in scripts/diver.gd.
        shoulder_rotation=radians((15,8,-11) if side < 0 else (23.412,-12,10))
        shoulder=pivot('Atelier Shoulder '+str(side),(side*.20,.21,-.01),shoulder_rotation,body)
        clone('shoulder',(-side*.010,-.022,-.016),radians((26,0,side*10)),color='armor',parent=shoulder)
        clone('upper_arm',(side*.02,-.10,-.05),radians((32,0,-side*8)),parent=shoulder)
        elbow_rotation=radians((5.741,4,0) if side < 0 else (14,8,0))
        elbow=pivot('Atelier Elbow '+str(side),(side*.02,-.15,-.10),elbow_rotation,shoulder)
        clone('elbow_sleeve',parent=elbow)
        clone('elbow_guard',color='armor',parent=elbow)
        clone('forearm',(0,-.04,-.09),radians((72,-side*10,0)),parent=elbow)
        clone('glove',(-side*.01,-.08,-.21),radians((72,-side*10,0)),parent=elbow)
        hip=pivot('Atelier Hip '+str(side),(side*.09,-.15,.01),(0,0,side*.015),body)
        clone('thigh',(0,-.11,.012),radians((-6,0,0)),parent=hip)
        knee=pivot('Atelier Knee '+str(side),(0,-.235,.025),parent=hip)
        clone('knee',color='armor',parent=knee)
        clone('calf',(0,-.12,.018),radians((-7.5,0,0)),parent=knee)
        ankle=pivot('Atelier Ankle '+str(side),(0,-.245,.034),radians((11.5,0,0)),knee)
        fin_frame=pivot('Atelier Fin Mount '+str(side),(0,-.010,-.006),radians((66,0,0)),ankle)
        clone('fin',color='ivory',parent=fin_frame)
        clone('fin_trim',color='gold',parent=fin_frame)

    bpy.context.view_layer.update()
    points=[obj.matrix_world @ vertex.co for obj in displayed for vertex in obj.data.vertices]
    center=Vector(tuple((min(p[i] for p in points)+max(p[i] for p in points))*.5 for i in range(3)))
    # Matched atelier background, with a calm navy shadow to reveal the edges.
    scene.world=bpy.data.worlds.new('Expedition warm studio')
    scene.world.use_nodes=True
    background=next(n for n in scene.world.node_tree.nodes if n.type=='BACKGROUND')
    background.inputs['Color'].default_value=(.12,.16,.18,1)
    background.inputs['Strength'].default_value=.45
    def area(name,at,power,size):
        data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size
        obj=bpy.data.objects.new(name,data);COLLECTION.objects.link(obj);obj.location=at
        obj.rotation_euler=(center-obj.location).to_track_quat('-Z','Y').to_euler()
    area('Large linen key',(2,3,3),170,3)
    area('Soft sea fill',(-2,0,1),100,2)
    area('Brass rim',(0,-2,2),170,2)
    data=bpy.data.cameras.new('Expedition atelier camera')
    cam=bpy.data.objects.new('Expedition atelier camera',data);COLLECTION.objects.link(cam)
    cam.location=center+Vector((1.05,2.7,.40))
    cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
    data.type='ORTHO';scene.camera=cam
    inverse=cam.rotation_euler.to_matrix().transposed()
    projected=[inverse @ (point-center) for point in points]
    low=Vector(tuple(min(p[i] for p in projected) for i in range(3)))
    high=Vector(tuple(max(p[i] for p in projected) for i in range(3)))
    # Center the actual projected geometry, then fit both dimensions. A full
    # eight-percent border includes the tips of both long trailing fins.
    center += cam.rotation_euler.to_matrix() @ Vector(((low.x+high.x)*.5,(low.y+high.y)*.5,0))
    cam.location=center+Vector((1.05,2.7,.40))
    cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
    data.ortho_scale=max(high.y-low.y,(high.x-low.x)/.75)/.84
    (output/'atelier-framing.json').write_text(json.dumps({'view':'front_three_quarter','border':.08,
        'ortho_scale':data.ortho_scale,'mesh_count':len(displayed),'production_pivots':True},indent=2)+'\n',encoding='utf-8')
    try:
        scene.render.engine='CYCLES'
        scene.cycles.samples=32
        scene.cycles.use_denoising=True
    except (TypeError,AttributeError):
        pass
    scene.render.resolution_x=1050;scene.render.resolution_y=1400;scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG'
    scene.render.filepath=str(output/'expedition-atelier.png')
    scene.render.film_transparent=False


def build(output_dir, reference_paths):
    """Write a standalone GLB library, provenance, editable blend and preview.

    `output_dir` is a durable source directory. `reference_paths` accepts a
    mapping of names to paths or an iterable of paths; diver.png is mandatory.
    Caller copies expedition_library.glb to assets/models after validation.
    """
    global MATERIAL,FAUNA_MAT,FAUNA_GLOW_MAT,SUB_MAT,SUB_GLASS_MAT,COLLECTION
    OBJECTS.clear()
    output=Path(output_dir).resolve();output.mkdir(parents=True,exist_ok=True)
    refs=reference_paths.values() if isinstance(reference_paths,dict) else reference_paths
    paths=[Path(p).resolve() for p in refs]
    reference=next((p for p in paths if 'diver' in p.stem),None)
    if reference is None or not reference.is_file():
        raise RuntimeError('Generate and save the GPT Image diver reference before Blender modeling')
    scene=bpy.data.scenes.new('Expedition concept-to-model atelier')
    if bpy.context.window:
        bpy.context.window.scene=scene
    COLLECTION=bpy.data.collections.new('Blender concept-derived part library')
    scene.collection.children.link(COLLECTION)
    scene.unit_settings.system='METRIC'
    MATERIAL=_material(output,reference)
    FAUNA_MAT,FAUNA_GLOW_MAT=_fauna_materials(output)
    SUB_MAT,SUB_GLASS_MAT=_submarine_materials(output)
    _diver();_creatures();_vehicles()
    bpy.ops.object.select_all(action='DESELECT')
    for obj in OBJECTS:
        obj.select_set(True)
    bpy.context.view_layer.objects.active=OBJECTS[0]
    path=output/'expedition_library.glb'
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,
                              use_active_scene=True,export_yup=True,export_apply=False,
                              export_animations=False,export_cameras=False,export_lights=False)
    entries={}
    for obj in OBJECTS:
        obj.data.calc_loop_triangles()
        entries[obj.name]={'triangles':len(obj.data.loop_triangles),'dimensions_blender_xyz':list(obj.dimensions)}
    record={'version':'gpt-blender-expedition-3','file':str(path),'references':[str(p) for p in paths],
            'modeler':'Original Blender scripted topology guided by GPT Image concepts',
            'rig_strategy':'Original gameplay Node3D pivots; shared immutable local mesh surfaces',
            'hero_triangle_budget':12000,'parts':entries}
    (output/'expedition-library.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
    _atelier(scene,output)
    bpy.ops.file.pack_all()
    bpy.ops.wm.save_as_mainfile(filepath=str(output/'expedition-atelier.blend'))
    # A rendered preview is part of the handoff, not a stand-in for runtime
    # validation. It also catches missing faces and badly oriented subparts.
    bpy.ops.render.render(write_still=True)
    print('EXPEDITION_LIBRARY_READY '+str(path)+' '+str(len(entries))+' parts',flush=True)
    return record
