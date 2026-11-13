"""High-fidelity sculptural marine fauna modeled after art-v3/concepts/creatures.png.

Provides watertight smooth anatomical geometry, exact bone hierarchies, and
dedicated 1024x1024 PBR procedural painters (CUSTOM_PAINTERS) for all 9 rigged
species.  All creatures face Blender -Y with +Z up and match contractual bounds.
"""
import math
import numpy as np

_A = None
TAU = math.tau


def _v(p):
    return _A.Vector((float(p[0]), float(p[1]), float(p[2])))


def _clamp(x, lo=0.0, hi=1.0):
    return lo if x < lo else (hi if x > hi else x)


def _smoothstep(e0, e1, x):
    if abs(e1 - e0) < 1e-7:
        return 1.0 if x >= e1 else 0.0
    t = _clamp((x - e0) / (e1 - e0))
    return t * t * (3.0 - 2.0 * t)


def _np_smooth(e0, e1, x):
    denom = e1 - e0
    if np.ndim(denom) == 0 and abs(float(denom)) < 1e-7:
        denom = 1e-7
    t = np.clip((x - e0) / denom, 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def _hex_rgb(h):
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], dtype=np.float32)


def _mix(a, b, t):
    return a * (1.0 - t) + b * t


def _catmull_row(pts, u):
    n = len(pts)
    if n == 1:
        return tuple(pts[0])
    s = _clamp(u) * (n - 1)
    i = min(n - 2, int(s))
    f = s - i
    p0 = pts[max(0, i - 1)]
    p1 = pts[i]
    p2 = pts[i + 1]
    p3 = pts[min(n - 1, i + 2)]
    f2, f3 = f * f, f * f * f
    return tuple(
        0.5 * ((2.0 * p1[k]) + (-p0[k] + p2[k]) * f
               + (2.0 * p0[k] - 5.0 * p1[k] + 4.0 * p2[k] - p3[k]) * f2
               + (-p0[k] + 3.0 * p1[k] - 3.0 * p2[k] + p3[k]) * f3)
        for k in range(len(p1))
    )


def _sample_curve(pts, count):
    return [_v(_catmull_row(pts, i / max(1, count - 1))) for i in range(count)]


def _spine_weights(anchors):
    def _w(point):
        y = point[1]
        if y <= anchors[0][0]:
            return {anchors[0][1]: 1.0}
        for (ya, ba), (yb, bb) in zip(anchors, anchors[1:]):
            if y <= yb:
                t = _clamp((y - ya) / max(1e-5, yb - ya))
                return {ba: 1.0 - t, bb: t}
        return {anchors[-1][1]: 1.0}
    return _w


def _poly_area(verts, face):
    p0 = _v(verts[face[0]])
    acc = _v((0.0, 0.0, 0.0))
    for k in range(1, len(face) - 1):
        acc += (_v(verts[face[k]]) - p0).cross(_v(verts[face[k + 1]]) - p0)
    return 0.5 * acc.length


def _emit_mesh(name, verts, faces, vert_uvs=None, loop_uvs=None, slot=0,
               bones=None, face_slots=None, smooth=True, glass=False):
    verts_f = [(float(p[0]), float(p[1]), float(p[2])) for p in verts]
    if vert_uvs is None:
        vert_uvs = [(0.5, 0.5)] * len(verts_f)
    clean_faces, clean_slots, clean_luvs = [], [], []
    for idx, f in enumerate(faces):
        dedup = []
        luvs_in = loop_uvs[idx] if loop_uvs is not None else None
        dedup_luv = []
        for k, vi in enumerate(f):
            if not dedup or dedup[-1] != vi:
                dedup.append(vi)
                if luvs_in is not None:
                    dedup_luv.append(luvs_in[k])
        if len(dedup) >= 2 and dedup[0] == dedup[-1]:
            dedup.pop()
            if luvs_in is not None:
                dedup_luv.pop()
        if len(set(dedup)) < 3 or _poly_area(verts_f, dedup) < 1e-10:
            continue
        clean_faces.append(tuple(dedup))
        if face_slots is not None:
            clean_slots.append(face_slots[idx])
        if luvs_in is not None:
            clean_luvs.append(dedup_luv)
    if not clean_faces:
        return None
    obj = _A.mesh(name, verts_f, clean_faces, vert_uvs, slot, bones,
                  clean_slots if face_slots is not None else None,
                  smooth=smooth, glass=glass)
    if loop_uvs is not None and obj.data.uv_layers:
        uv_data = obj.data.uv_layers[0].data
        for poly in obj.data.polygons:
            pi = poly.index
            tile = clean_slots[pi] if face_slots is not None else slot
            c0, r0 = tile % 4, tile // 4
            luvs = clean_luvs[pi]
            for k, li in enumerate(poly.loop_indices):
                a = _clamp(float(luvs[k][0]))
                b = _clamp(float(luvs[k][1]))
                uv_data[li].uv = ((c0 + 0.008 + 0.984 * a) * 0.25,
                                  (r0 + 0.008 + 0.984 * b) * 0.5)
    return obj


def _hull(name, ctrl, n_rings=38, sides=34, slot=0, bones=None,
          uv_mode='lateral', shape_fn=None, face_slot_fn=None):
    """Watertight welded anatomical hull along Y with smooth apex endcaps."""
    y_front, _, _, _, z_front = ctrl[0]
    y_back, _, _, _, z_back = ctrl[-1]
    verts = [(0.0, y_front, z_front)]
    ring_starts = []
    for i in range(1, n_rings - 1):
        t = i / (n_rings - 1)
        y, rx, rz_up, rz_dn, zc = _catmull_row(ctrl, t)
        rx = max(0.0025, rx)
        rz_up = max(0.0025, rz_up)
        rz_dn = max(0.0025, rz_dn)
        ring_starts.append(len(verts))
        for j in range(sides):
            phi = TAU * j / sides
            ca, sa = math.cos(phi), math.sin(phi)
            rz = rz_up if sa >= 0.0 else rz_dn
            dx, dy, dz = (rx * ca, 0.0, rz * sa)
            if shape_fn is not None:
                dx, dy, dz = shape_fn(t, phi, y, dx, dy, dz, rx, rz_up, rz_dn)
            verts.append((dx, y + dy, zc + dz))
    back_idx = len(verts)
    verts.append((0.0, y_back, z_back))

    xs = [p[0] for p in verts]
    ys = [p[1] for p in verts]
    zs = [p[2] for p in verts]
    x0, x1 = min(xs), max(xs)
    y0, y1 = min(ys), max(ys)
    z0, z1 = min(zs), max(zs)

    def _vuv(p):
        if uv_mode == 'dorsal':
            return ((p[0] - x0) / max(1e-5, x1 - x0), (p[1] - y0) / max(1e-5, y1 - y0))
        return ((p[1] - y0) / max(1e-5, y1 - y0), (p[2] - z0) / max(1e-5, z1 - z0))

    vert_uvs = [_vuv(p) for p in verts]
    faces, fslots, luvs = [], [], []
    r0 = ring_starts[0]
    for j in range(sides):
        jn = (j + 1) % sides
        f = (0, r0 + jn, r0 + j)
        faces.append(f)
        fslots.append(face_slot_fn(0.02, TAU * (j + 0.5) / sides, verts[r0 + j]) if face_slot_fn else slot)
        if uv_mode == 'cylindrical':
            luvs.append([((j + 0.5) / sides, 0.0), ((j + 1) / sides, 1.0 / (n_rings - 1)), (j / sides, 1.0 / (n_rings - 1))])
    for ri in range(len(ring_starts) - 1):
        a0, b0 = ring_starts[ri], ring_starts[ri + 1]
        tm = (ri + 1.5) / (n_rings - 1)
        t_lo, t_hi = (ri + 1) / (n_rings - 1), (ri + 2) / (n_rings - 1)
        for j in range(sides):
            jn = (j + 1) % sides
            f = (a0 + j, b0 + j, b0 + jn, a0 + jn)
            faces.append(f)
            mid_p = tuple(0.25 * sum(verts[v][k] for v in f) for k in range(3))
            fslots.append(face_slot_fn(tm, TAU * (j + 0.5) / sides, mid_p) if face_slot_fn else slot)
            if uv_mode == 'cylindrical':
                luvs.append([(j / sides, t_lo), (j / sides, t_hi), ((j + 1) / sides, t_hi), ((j + 1) / sides, t_lo)])
    rl = ring_starts[-1]
    for j in range(sides):
        jn = (j + 1) % sides
        f = (back_idx, rl + j, rl + jn)
        faces.append(f)
        fslots.append(face_slot_fn(0.98, TAU * (j + 0.5) / sides, verts[rl + j]) if face_slot_fn else slot)
        if uv_mode == 'cylindrical':
            luvs.append([((j + 0.5) / sides, 1.0), (j / sides, (n_rings - 2) / (n_rings - 1)), ((j + 1) / sides, (n_rings - 2) / (n_rings - 1))])
    return _emit_mesh(name, verts, faces, vert_uvs=vert_uvs,
                      loop_uvs=luvs if uv_mode == 'cylindrical' else None,
                      slot=slot, bones=bones,
                      face_slots=fslots if face_slot_fn else None)


def _swept_tube(name, ctrl_pts, radii_or_fn, n_steps=16, sides=10, slot=0,
                bones=None, scale_nb=(1.0, 1.0), ridge_fn=None, up_hint=(0, 0, 1)):
    """Watertight parallel-transport tube with elliptical cross-section and apex caps."""
    pts = _sample_curve(ctrl_pts, n_steps) if len(ctrl_pts) >= 3 and n_steps > len(ctrl_pts) else [_v(p) for p in ctrl_pts]
    m = len(pts)
    tangents = []
    for i in range(m):
        d = pts[min(m - 1, i + 1)] - pts[max(0, i - 1)]
        tangents.append(d.normalized() if d.length > 1e-7 else _v((0, 1, 0)))
    up = _v(up_hint).normalized()
    n0 = tangents[0].cross(up)
    if n0.length < 1e-3:
        n0 = tangents[0].cross(_v((1, 0, 0)))
    n0.normalize()
    normals = [n0]
    for i in range(1, m):
        t_prev, t_cur = tangents[i - 1], tangents[i]
        axis = t_prev.cross(t_cur)
        ni = normals[-1]
        if axis.length > 1e-6:
            ang = math.atan2(axis.length, _clamp(t_prev.dot(t_cur), -1.0, 1.0))
            ax = axis.normalized()
            ni = ni * math.cos(ang) + ax.cross(ni) * math.sin(ang) + ax * ax.dot(ni) * (1.0 - math.cos(ang))
        ni = (ni - t_cur * ni.dot(t_cur)).normalized()
        normals.append(ni)

    def _rad(i):
        t = i / max(1, m - 1)
        if callable(radii_or_fn):
            return radii_or_fn(t)
        pos = t * (len(radii_or_fn) - 1)
        k = min(len(radii_or_fn) - 2, int(pos))
        f = pos - k
        return radii_or_fn[k] * (1.0 - f) + radii_or_fn[k + 1] * f

    rads = [_rad(i) for i in range(m)]
    verts, ring_ids = [], []
    start_cap = None
    if rads[0] <= 1e-4:
        start_cap = 0
        verts.append(tuple(pts[0]))
        i_start = 1
    else:
        start_cap = 0
        verts.append(tuple(pts[0]))
        i_start = 0
    i_end = m - 1 if rads[-1] <= 1e-4 else m
    for i in range(i_start, i_end):
        t = i / max(1, m - 1)
        r = max(1e-4, rads[i])
        ni = normals[i]
        bi = tangents[i].cross(ni).normalized()
        ring_ids.append((i, len(verts)))
        for j in range(sides):
            phi = TAU * j / sides
            rm = ridge_fn(t, phi) if ridge_fn is not None else 1.0
            off = ni * (math.cos(phi) * r * scale_nb[0] * rm) + bi * (math.sin(phi) * r * scale_nb[1] * rm)
            verts.append(tuple(pts[i] + off))
    end_cap = len(verts)
    verts.append(tuple(pts[-1]))

    faces, luvs = [], []
    _, r_first = ring_ids[0]
    t_first = ring_ids[0][0] / max(1, m - 1)
    for j in range(sides):
        jn = (j + 1) % sides
        faces.append((start_cap, r_first + jn, r_first + j))
        luvs.append([((j + 0.5) / sides, 0.0), ((j + 1) / sides, t_first), (j / sides, t_first)])
    for k in range(len(ring_ids) - 1):
        ia, ra = ring_ids[k]
        ib, rb = ring_ids[k + 1]
        ta, tb = ia / max(1, m - 1), ib / max(1, m - 1)
        for j in range(sides):
            jn = (j + 1) % sides
            faces.append((ra + j, rb + j, rb + jn, ra + jn))
            luvs.append([(j / sides, ta), (j / sides, tb), ((j + 1) / sides, tb), ((j + 1) / sides, ta)])
    il, rl = ring_ids[-1]
    tl = il / max(1, m - 1)
    for j in range(sides):
        jn = (j + 1) % sides
        faces.append((end_cap, rl + j, rl + jn))
        luvs.append([((j + 0.5) / sides, 1.0), (j / sides, tl), ((j + 1) / sides, tl)])
    return _emit_mesh(name, verts, faces, loop_uvs=luvs, slot=slot, bones=bones)


def _fan_fin(name, root_spec, margin_spec, slot=7, ventral_slot=None, bones='body',
             u_steps=20, v_steps=8, thickness=0.012, camber=0.0,
             rays=12, ray_amp=0.0022, scallop=0.0, normal_hint=(1, 0, 0),
             mid_bias=0.5, mid_bulge=(0.0, 0.0, 0.0)):
    """Watertight double-sided rayed fin with stitched outer margin and root cap."""
    hint = _v(normal_hint).normalized()
    bulge = _v(mid_bulge)

    def _eval(spec, u):
        return _v(spec(u)) if callable(spec) else _v(_catmull_row(spec, u))

    def _base_pos(u, v):
        r = _eval(root_spec, u)
        m = _eval(margin_spec, u)
        v_sc = v * (1.0 - scallop * abs(math.sin(rays * math.pi * u)) * (v ** 1.5))
        ctrl = r.lerp(m, mid_bias) + bulge * math.sin(math.pi * u)
        s = 1.0 - v_sc
        return r * (s * s) + ctrl * (2.0 * s * v_sc) + m * (v_sc * v_sc)

    grid_p, grid_n = {}, {}
    for iu in range(u_steps + 1):
        u = iu / u_steps
        for iv in range(v_steps + 1):
            v = iv / v_steps
            p = _base_pos(u, v)
            du = _base_pos(_clamp(u + 0.02), v) - _base_pos(_clamp(u - 0.02), v)
            dv = _base_pos(u, _clamp(v + 0.04)) - _base_pos(u, _clamp(v - 0.04))
            n = du.cross(dv)
            n = n.normalized() if n.length > 1e-7 else hint
            if n.dot(hint) < 0.0:
                n = -n
            grid_p[(iu, iv)] = p
            grid_n[(iu, iv)] = n

    verts, vert_uvs = [], []
    top_id, bot_id = {}, {}
    for iu in range(u_steps + 1):
        u = iu / u_steps
        for iv in range(v_steps + 1):
            v = iv / v_steps
            p = grid_p[(iu, iv)]
            n = grid_n[(iu, iv)]
            cam = camber * math.sin(math.pi * u) * math.sin(math.pi * v)
            stitched = (iu == 0 or iu == u_steps or iv == v_steps)
            if stitched:
                idx = len(verts)
                verts.append(tuple(p + n * cam))
                vert_uvs.append((u, v))
                top_id[(iu, iv)] = idx
                bot_id[(iu, iv)] = idx
            else:
                ray_w = (0.5 + 0.5 * math.cos(rays * TAU * u)) ** 2
                half_t = (0.5 * thickness * ((1.0 - v) ** 0.72) * (math.sin(math.pi * u) ** 0.35)
                          + ray_amp * ray_w * (1.0 - 0.45 * v) * math.sin(math.pi * u))
                half_t = max(0.0008, half_t)
                it = len(verts)
                verts.append(tuple(p + n * (cam + half_t)))
                vert_uvs.append((u, v))
                ib = len(verts)
                verts.append(tuple(p + n * (cam - half_t)))
                vert_uvs.append((u, v))
                top_id[(iu, iv)] = it
                bot_id[(iu, iv)] = ib

    faces, fslots = [], []
    vslot = slot if ventral_slot is None else ventral_slot
    for side, id_map, s_sign, f_slot in ((0, top_id, 1.0, slot), (1, bot_id, -1.0, vslot)):
        for iu in range(u_steps):
            for iv in range(v_steps):
                q = [id_map[(iu, iv)], id_map[(iu + 1, iv)],
                     id_map[(iu + 1, iv + 1)], id_map[(iu, iv + 1)]]
                n_ref = grid_n[(iu, iv)] * s_sign
                p0 = _v(verts[q[0]])
                cr = (_v(verts[q[1]]) - p0).cross(_v(verts[q[2]]) - p0)
                if cr.length < 1e-9:
                    cr = (_v(verts[q[2]]) - p0).cross(_v(verts[q[3]]) - p0)
                if cr.dot(n_ref) < 0.0:
                    q = q[::-1]
                faces.append(tuple(q))
                fslots.append(f_slot)
    for iu in range(u_steps):
        a_t, b_t = top_id[(iu, 0)], top_id[(iu + 1, 0)]
        a_b, b_b = bot_id[(iu, 0)], bot_id[(iu + 1, 0)]
        faces.append((a_t, a_b, b_b, b_t))
        fslots.append(slot)
    return _emit_mesh(name, verts, faces, vert_uvs=vert_uvs, slot=slot,
                      bones=bones, face_slots=fslots)


def _ellipsoid(name, center, scale, slot=0, bones='body', segs=16, rings=10):
    """Watertight welded ellipsoid with pole triangle fans (zero degenerate faces)."""
    cx, cy, cz = center
    sx, sy, sz = scale
    verts = [(cx, cy, cz + sz)]
    r_ids = []
    for i in range(1, rings):
        th = math.pi * i / rings
        st, ct = math.sin(th), math.cos(th)
        r_ids.append((i / rings, len(verts)))
        for j in range(segs):
            ph = TAU * j / segs
            verts.append((cx + sx * st * math.cos(ph), cy + sy * st * math.sin(ph), cz + sz * ct))
    bot = len(verts)
    verts.append((cx, cy, cz - sz))
    faces, luvs = [], []
    t0, r0 = r_ids[0]
    for j in range(segs):
        jn = (j + 1) % segs
        faces.append((0, r0 + j, r0 + jn))
        luvs.append([((j + 0.5) / segs, 1.0), (j / segs, 1.0 - t0), ((j + 1) / segs, 1.0 - t0)])
    for k in range(len(r_ids) - 1):
        ta, ra = r_ids[k]
        tb, rb = r_ids[k + 1]
        for j in range(segs):
            jn = (j + 1) % segs
            faces.append((ra + j, rb + j, rb + jn, ra + jn))
            luvs.append([(j / segs, 1.0 - ta), (j / segs, 1.0 - tb), ((j + 1) / segs, 1.0 - tb), ((j + 1) / segs, 1.0 - ta)])
    tl, rl = r_ids[-1]
    for j in range(segs):
        jn = (j + 1) % segs
        faces.append((bot, rl + jn, rl + j))
        luvs.append([((j + 0.5) / segs, 0.0), ((j + 1) / segs, 1.0 - tl), (j / segs, 1.0 - tl)])
    return _emit_mesh(name, verts, faces, loop_uvs=luvs, slot=slot, bones=bones)


def _torus(name, center, rx, ry, minor_r, slot=0, bones='body', plane='YZ', segs=18, sides=6):
    """Watertight welded elliptical torus ring (zero seam splits, zero degenerate faces)."""
    cx, cy, cz = center
    verts, faces, luvs = [], [], []
    for i in range(segs):
        a = TAU * i / segs
        ca, sa = math.cos(a), math.sin(a)
        if plane == 'YZ':
            p = _v((cx, cy + rx * ca, cz + ry * sa))
            r_out = _v((0.0, ca, sa)).normalized()
            p_n = _v((1.0, 0.0, 0.0))
        elif plane == 'XZ':
            p = _v((cx + rx * ca, cy, cz + ry * sa))
            r_out = _v((ca, 0.0, sa)).normalized()
            p_n = _v((0.0, 1.0, 0.0))
        else:
            p = _v((cx + rx * ca, cy + ry * sa, cz))
            r_out = _v((ca, sa, 0.0)).normalized()
            p_n = _v((0.0, 0.0, 1.0))
        for j in range(sides):
            b = TAU * j / sides
            verts.append(tuple(p + r_out * (minor_r * math.cos(b)) + p_n * (minor_r * math.sin(b))))
    for i in range(segs):
        inext = (i + 1) % segs
        ua, ub = i / segs, (i + 1) / segs
        for j in range(sides):
            jn = (j + 1) % sides
            va, vb = j / sides, (j + 1) / sides
            faces.append((i * sides + j, inext * sides + j, inext * sides + jn, i * sides + jn))
            luvs.append([(ua, va), (ub, va), (ub, vb), (ua, vb)])
    return _emit_mesh(name, verts, faces, loop_uvs=luvs, slot=slot, bones=bones)


def _eye_pair(x, y, z, radius, bones='body', iris_slot=6, pupil_slot=3,
              rim_slot=1, glint_slot=1, tilt_y=0.0):
    """Sculpted orbital eyelid ring, iris dome, glossy pupil, and specular highlight."""
    for s in (-1, 1):
        cx = s * x
        _torus('Sculpted orbital rim', (cx, y, z), radius * 1.05, radius * 0.95,
               radius * 0.18, rim_slot, bones, 'YZ', 16, 6)
        _ellipsoid('Sculpted iris globe', (cx + s * radius * 0.08, y, z),
                   (radius * 0.40, radius * 0.94, radius * 0.86), iris_slot, bones, 14, 8)
        _ellipsoid('Obsidian pupil', (cx + s * radius * 0.22, y + tilt_y * radius, z),
                   (radius * 0.32, radius * 0.60, radius * 0.56), pupil_slot, bones, 12, 7)
        _ellipsoid('Specular eye glint',
                   (cx + s * radius * 0.40, y - radius * 0.24, z + radius * 0.26),
                   (max(0.003, radius * 0.14), max(0.004, radius * 0.22), max(0.004, radius * 0.20)),
                   glint_slot, bones, 8, 5)


# ---------------------------------------------------------------------------
# 1024x1024 Procedural PBR Custom Painters (shared UV math with 3D geometry)
# ---------------------------------------------------------------------------

def _tile_coords(slot):
    h, w = 512, 256
    row, col = slot // 4, slot % 4
    region = (slice(row * h, (row + 1) * h), slice(col * w, (col + 1) * w))
    yi, xi = np.mgrid[0:h, 0:w].astype(np.float32)
    a = np.clip(((xi + 0.5) / w - 0.008) / 0.984, 0.0, 1.0)
    b = np.clip(((yi + 0.5) / h - 0.008) / 0.984, 0.0, 1.0)
    return region, a, b


def _fbm(a, b, fa=4.0, fb=4.0, seed=17, octaves=4):
    rng = np.random.default_rng(seed)
    acc = np.zeros_like(a, dtype=np.float32)
    amp, norm = 0.5, 0.0
    ca, cb = fa, fb
    for _ in range(octaves):
        p1, p2, p3 = rng.uniform(0.0, TAU, 3)
        w = np.sin(a * TAU * ca + p1 + 0.65 * np.cos(b * TAU * cb * 0.7 + p2))
        w *= np.cos(b * TAU * cb + p3 - 0.55 * np.sin(a * TAU * ca * 0.8 + p1))
        acc += amp * w
        norm += amp
        amp *= 0.5
        ca *= 2.03
        cb *= 1.97
    return acc / max(1e-5, norm)


def _voronoi(a, b, nx, ny, seed=42, jitter=0.75):
    rng = np.random.default_rng(seed)
    jx = rng.uniform(0.5 - 0.45 * jitter, 0.5 + 0.45 * jitter, (ny + 4, nx + 4)).astype(np.float32)
    jy = rng.uniform(0.5 - 0.45 * jitter, 0.5 + 0.45 * jitter, (ny + 4, nx + 4)).astype(np.float32)
    cid = rng.uniform(0.0, 1.0, (ny + 4, nx + 4)).astype(np.float32)
    gx, gy = a * nx + 2.0, b * ny + 2.0
    ix, iy = np.floor(gx).astype(np.int32), np.floor(gy).astype(np.int32)
    d1 = np.full_like(a, 1e9)
    d2 = np.full_like(a, 1e9)
    best_id = np.zeros_like(a)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            cx_i = np.clip(ix + dx, 0, nx + 3)
            cy_i = np.clip(iy + dy, 0, ny + 3)
            px = cx_i.astype(np.float32) + jx[cy_i, cx_i]
            py = cy_i.astype(np.float32) + jy[cy_i, cx_i]
            dist = np.sqrt((gx - px) ** 2 + ((gy - py) * (nx / max(1.0, ny) * 0.55)) ** 2)
            closer = dist < d1
            d2 = np.where(closer, d1, np.minimum(d2, dist))
            best_id = np.where(closer, cid[cy_i, cx_i], best_id)
            d1 = np.where(closer, dist, d1)
    return d1, d2 - d1, best_id


def _write_slot(albedo, normal, orm, emission, slot, rgb, relief,
                rough=0.36, metal=0.0, alpha=1.0, emit=None, n_str=3.0, ao_str=0.35):
    reg, _, _ = _tile_coords(slot)
    albedo[reg][..., :3] = np.clip(rgb, 0.0, 1.0)
    albedo[reg][..., 3] = np.clip(alpha, 0.0, 1.0)
    normal[reg][..., :3] = _A.height_to_normal(relief, n_str)
    normal[reg][..., 3] = 1.0
    ao = np.clip(0.97 - np.maximum(0.0, -relief) * ao_str * 2.4 - np.abs(relief) * ao_str * 0.4, 0.45, 1.0)
    orm[reg][..., 0] = ao
    orm[reg][..., 1] = np.clip(rough, 0.06, 0.95)
    orm[reg][..., 2] = np.clip(metal, 0.0, 1.0)
    orm[reg][..., 3] = 1.0
    emission[reg][..., :3] = np.clip(emit, 0.0, 2.0) if emit is not None else 0.0
    emission[reg][..., 3] = 1.0


# Turtle scute layout shared by both 3D carapace relief and 1024 tortoiseshell painter!
_TURTLE_SCUTE_SEEDS = (
    [(0.50, y, 1.0, 0) for y in (0.15, 0.32, 0.50, 0.68, 0.84)]
    + [(0.50 + s * 0.22, y, 1.04, 1) for s in (-1, 1) for y in (0.23, 0.41, 0.59, 0.76)]
    + [(0.50 + 0.43 * math.sin(a), 0.50 - 0.43 * math.cos(a), 1.35, 2)
       for a in [TAU * k / 22.0 for k in range(22)]]
)


def _turtle_scute_field_py(a, b):
    d1, d2, best_k = 1e9, 1e9, 0
    for k, (sx, sy, w, _) in enumerate(_TURTLE_SCUTE_SEEDS):
        d = math.hypot((a - sx) * 1.12, (b - sy) * 0.92) * w
        if d < d1:
            d2, d1, best_k = d1, d, k
        elif d < d2:
            d2 = d
    return d1, d2 - d1, best_k


def _paint_fish(albedo, normal, orm, emission):
    _, a, b = _tile_coords(0)
    c_blue = _hex_rgb('174eb8')
    c_deep = _hex_rgb('0e2a6e')
    c_sky = _hex_rgb('3aa4ff')
    c_gold = _hex_rgb('f7ca24')
    c_orange = _hex_rgb('eb9e14')
    c_white = _hex_rgb('f6f5ee')
    c_mask = _hex_rgb('0b1328')
    n_tex = _fbm(a, b, 5.0, 5.0, 101, 3)
    rgb = _mix(c_deep[None, None, :], c_blue[None, None, :], np.clip(0.42 + 0.48 * b + 0.12 * n_tex, 0, 1)[..., None])
    # Crisp curved diagonal golden-yellow Emperor Angelfish stripes across full trunk (a > 0.25)
    b_up = np.maximum(0.0, b - 0.22)
    b_dn = np.maximum(0.0, 0.22 - b)
    curve_coord = (a - 0.25) * 24.5 - 3.9 * (b_up ** 1.38) + 1.1 * (b_dn ** 1.2) - 1.45 * b
    stripe_wave = 0.5 + 0.5 * np.cos(curve_coord * TAU)
    stripe_mask = _np_smooth(0.46, 0.74, stripe_wave) * _np_smooth(0.245, 0.285, a)
    gold_grad = _mix(c_orange[None, None, :], c_gold[None, None, :], np.clip(0.35 + 0.65 * b, 0, 1)[..., None])
    rgb = _mix(rgb, gold_grad, stripe_mask[..., None] * 0.96)
    # Crisp white vertical gill/opercular bar (a ~ 0.235) + dark navy pectoral wedge
    gill_center = 0.235 + 0.022 * np.sin((b - 0.48) * 3.0)
    gill_bar = _np_smooth(0.028, 0.015, np.abs(a - gill_center)) * _np_smooth(0.16, 0.28, b) * (1.0 - _np_smooth(0.82, 0.93, b))
    gill_rim = np.exp(-((np.abs(a - gill_center) - 0.024) / 0.008) ** 2) * _np_smooth(0.16, 0.28, b)
    pec_wedge = np.exp(-((a - 0.278) / 0.028) ** 2) * (1.0 - _np_smooth(0.24, 0.50, b))
    rgb = _mix(rgb, c_mask[None, None, :], pec_wedge[..., None] * 0.85)
    rgb = _mix(rgb, c_sky[None, None, :], gill_rim[..., None] * 0.82)
    rgb = _mix(rgb, c_white[None, None, :], gill_bar[..., None] * 0.97)
    # Curved blue-black eye mask centered directly through eye (a ~ 0.145) + white snout tip
    mask_c = 0.142 + 0.065 * ((b - 0.55) ** 2)
    eye_band = _np_smooth(0.042, 0.026, np.abs(a - mask_c)) * _np_smooth(0.24, 0.35, b) * (1.0 - _np_smooth(0.88, 0.97, b))
    eye_rim = np.exp(-((np.abs(a - mask_c) - 0.036) / 0.009) ** 2) * _np_smooth(0.24, 0.35, b) * (1.0 - _np_smooth(0.88, 0.97, b))
    snout = (1.0 - _np_smooth(0.048, 0.095, a)) * (1.0 - _np_smooth(0.55, 0.72, b))
    rgb = _mix(rgb, c_sky[None, None, :], eye_rim[..., None] * 0.92)
    rgb = _mix(rgb, c_mask[None, None, :], eye_band[..., None] * 0.96)
    rgb = _mix(rgb, c_white[None, None, :], snout[..., None] * 0.96)
    scales = np.sin((a * 38.0 + b * 14.0) * TAU) * np.sin((a * 38.0 - b * 14.0) * TAU)
    relief = 0.022 * scales * _np_smooth(0.22, 0.32, a) + 0.028 * stripe_mask + 0.035 * gill_bar - 0.02 * eye_band
    _write_slot(albedo, normal, orm, emission, 0, rgb, relief, rough=0.28, n_str=2.6)
    # Slot 1: Creamy-ivory lips & specular glint
    _, a1, b1 = _tile_coords(1)
    _write_slot(albedo, normal, orm, emission, 1, _mix(_hex_rgb('e8e2d0')[None, None, :], c_white[None, None, :], b1[..., None]), np.zeros_like(a1), rough=0.20)
    # Slot 2: Dorsal & anal streamer fins (blue striped base -> bright golden-yellow margin/filament)
    _, a2, b2 = _tile_coords(2)
    rays2 = 0.5 + 0.5 * np.cos(a2 * 26.0 * TAU)
    fin_str = 0.5 + 0.5 * np.cos((a2 * 14.0 - b2 * 3.2) * TAU)
    base2 = _mix(c_deep[None, None, :], c_blue[None, None, :], (0.4 + 0.4 * rays2)[..., None])
    base2 = _mix(base2, c_gold[None, None, :], (_np_smooth(0.55, 0.85, fin_str) * (1.0 - b2 * 0.5))[..., None] * 0.72)
    tip_blend = _np_smooth(0.46, 0.86, b2 + 0.25 * _np_smooth(0.55, 0.95, a2))
    rgb2 = _mix(base2, _mix(c_orange[None, None, :], c_gold[None, None, :], b2[..., None]), tip_blend[..., None])
    rgb2 = _mix(rgb2, c_sky[None, None, :], (np.exp(-((b2 - 0.94) / 0.04) ** 2) * (1.0 - a2))[..., None] * 0.65)
    _write_slot(albedo, normal, orm, emission, 2, rgb2, 0.045 * rays2, rough=0.30, n_str=2.8)
    # Slot 5: Golden-yellow caudal, pectoral & pelvic fins
    _, a5, b5 = _tile_coords(5)
    rays5 = 0.5 + 0.5 * np.cos(a5 * 20.0 * TAU)
    rgb5 = _mix(c_orange[None, None, :], c_gold[None, None, :], np.clip(0.25 + 0.55 * b5 + 0.25 * rays5, 0, 1)[..., None])
    rgb5 = _mix(rgb5, _hex_rgb('fff3a6')[None, None, :], _np_smooth(0.82, 0.98, b5)[..., None] * 0.45)
    _write_slot(albedo, normal, orm, emission, 5, rgb5, 0.04 * rays5, rough=0.26, n_str=2.5)
    # Slot 3 & 6: Glossy obsidian pupil & azure-rimmed iris
    _, a3, b3 = _tile_coords(3)
    _write_slot(albedo, normal, orm, emission, 3, np.broadcast_to(_hex_rgb('080d1c'), (512, 256, 3)), np.zeros_like(a3), rough=0.07)
    _, a6, b6 = _tile_coords(6)
    rgb6 = _mix(_hex_rgb('1d5fd6')[None, None, :], c_gold[None, None, :], _np_smooth(0.25, 0.75, b6)[..., None])
    _write_slot(albedo, normal, orm, emission, 6, rgb6, 0.01 * np.sin(a6 * 24 * TAU), rough=0.14)


def _paint_fish_small(albedo, normal, orm, emission):
    _, a, b = _tile_coords(0)
    c_tang = _hex_rgb('eb7622')
    c_gold = _hex_rgb('f7b538')
    c_belly = _hex_rgb('faece2')
    c_lav = _hex_rgb('eb96d4')
    c_pink = _hex_rgb('df68ad')
    rgb = _mix(c_belly[None, None, :], c_gold[None, None, :], _np_smooth(0.18, 0.56, b)[..., None])
    rgb = _mix(rgb, c_tang[None, None, :], _np_smooth(0.55, 0.88, b)[..., None])
    # Iridescent pink-lavender lateral & suborbital stripe from cheek to caudal base
    stripe_z = 0.49 + 0.05 * np.sin(a * math.pi * 1.1 - 0.3) - 0.07 * (1.0 - _np_smooth(0.08, 0.28, a))
    lat_band = np.exp(-((b - stripe_z) / 0.078) ** 2 * 1.6) * _np_smooth(0.05, 0.14, a)
    lav_col = _mix(c_pink[None, None, :], c_lav[None, None, :], (0.5 + 0.5 * np.sin(a * 12.0))[..., None])
    rgb = _mix(rgb, lav_col, lat_band[..., None] * 0.88)
    scales = np.maximum(0.0, np.sin((a * 28.0 + b * 11.0) * TAU) * np.sin((a * 28.0 - b * 11.0) * TAU))
    rgb = np.clip(rgb + scales[..., None] * 0.065, 0.0, 1.0)
    relief = 0.032 * scales + 0.012 * lat_band
    emit0 = lav_col * (lat_band[..., None] * 0.08)
    _write_slot(albedo, normal, orm, emission, 0, rgb, relief, rough=0.24, metal=0.08, emit=emit0, n_str=2.6)
    for s_fin, n_rays in ((2, 22.0), (7, 18.0)):
        _, af, bf = _tile_coords(s_fin)
        rf = 0.5 + 0.5 * np.cos(af * n_rays * TAU)
        rgbf = _mix(_hex_rgb('f7d9a8')[None, None, :], c_gold[None, None, :], (0.35 + 0.65 * bf)[..., None])
        rgbf = _mix(rgbf, c_pink[None, None, :], (np.exp(-((bf - 0.88) / 0.09) ** 2) * 0.42)[..., None])
        rgbf = _mix(rgbf, c_tang[None, None, :], (rf * 0.38)[..., None])
        _write_slot(albedo, normal, orm, emission, s_fin, rgbf, 0.04 * rf, rough=0.25, n_str=2.4)
    _, a6, b6 = _tile_coords(6)
    _write_slot(albedo, normal, orm, emission, 6, _mix(c_tang[None, None, :], _hex_rgb('ffe28a')[None, None, :], b6[..., None]), np.zeros_like(a6), rough=0.12)


def _paint_fish_predator(albedo, normal, orm, emission):
    _, a, b = _tile_coords(0)
    c_dorsal = _hex_rgb('1a3f6b')
    c_mid = _hex_rgb('356896')
    c_slate = _hex_rgb('5d8ab0')
    c_belly = _hex_rgb('f2f6fa')
    mottle = _fbm(a, b, 6.0, 5.0, 307, 4)
    fine = _fbm(a, b, 19.0, 16.0, 311, 3)
    trans_line = 0.41 + 0.065 * mottle + 0.025 * fine - 0.04 * (1.0 - _np_smooth(0.0, 0.25, a))
    dorsal_mask = _np_smooth(trans_line - 0.055, trans_line + 0.065, b)
    splatter = _np_smooth(0.12, 0.42, mottle + 0.4 * fine) * np.exp(-((b - trans_line) / 0.085) ** 2)
    top_col = _mix(c_mid[None, None, :], c_dorsal[None, None, :], _np_smooth(0.50, 0.88, b + 0.12 * mottle)[..., None])
    top_col = _mix(top_col, c_slate[None, None, :], (_np_smooth(0.2, 0.6, fine) * 0.24)[..., None])
    rgb = _mix(c_belly[None, None, :], top_col, np.clip(dorsal_mask + splatter * 0.55, 0.0, 1.0)[..., None])
    denticles = 0.012 * fine + 0.006 * np.sin(a * 65.0 * TAU) * np.cos(b * 55.0 * TAU)
    _write_slot(albedo, normal, orm, emission, 0, rgb, denticles, rough=0.27, metal=0.05, n_str=2.2)
    # Slot 2: Pelagic indigo fins with darker trailing margin
    _, a2, b2 = _tile_coords(2)
    m2 = _fbm(a2, b2, 5.0, 5.0, 313, 3)
    rgb2 = _mix(c_mid[None, None, :], c_dorsal[None, None, :], np.clip(0.35 + 0.55 * b2 + 0.15 * m2, 0, 1)[..., None])
    rgb2 = _mix(rgb2, _hex_rgb('102542')[None, None, :], _np_smooth(0.76, 0.98, a2)[..., None] * 0.55)
    _write_slot(albedo, normal, orm, emission, 2, rgb2, 0.018 * np.cos(a2 * 22.0 * TAU), rough=0.30, n_str=2.0)
    # Slot 1: Crisp white ventral fin & sharp enamel teeth
    _, a1, b1 = _tile_coords(1)
    rgb1 = _mix(c_belly[None, None, :], c_slate[None, None, :], (_np_smooth(0.82, 0.99, b1) * 0.45)[..., None])
    _write_slot(albedo, normal, orm, emission, 1, rgb1, 0.008 * m2, rough=0.22)
    # Slot 3: Dark gill slit & oral cavity
    _, a3, _ = _tile_coords(3)
    _write_slot(albedo, normal, orm, emission, 3, np.broadcast_to(_hex_rgb('131d2e'), (512, 256, 3)), np.zeros_like(a3), rough=0.45)


def _paint_fish_abyss(albedo, normal, orm, emission):
    _, a, b = _tile_coords(0)
    c_plum = _hex_rgb('3f2a5c')
    c_deep = _hex_rgb('1c112b')
    c_ridge = _hex_rgb('6e4c8f')
    c_rose = _hex_rgb('8e5a9c')
    n_skin = _fbm(a, b, 6.0, 6.0, 401, 4)
    myomere = 0.5 + 0.5 * np.cos((a * 21.0 + 0.16 * np.sin(b * math.pi * 2.0)) * TAU)
    d1, _, _ = _voronoi(a, b, 14, 24, seed=409)
    warts = np.exp(-(d1 * 3.4) ** 2)
    ridge_h = 0.55 * (myomere ** 1.8) + 0.45 * warts + 0.25 * n_skin
    rgb = _mix(c_deep[None, None, :], c_plum[None, None, :], _np_smooth(-0.1, 0.55, ridge_h)[..., None])
    rgb = _mix(rgb, c_ridge[None, None, :], _np_smooth(0.48, 0.92, ridge_h)[..., None] * 0.72)
    rgb = _mix(rgb, c_rose[None, None, :], (warts * _np_smooth(0.35, 0.65, b))[..., None] * 0.35)
    relief = 0.075 * ridge_h
    _write_slot(albedo, normal, orm, emission, 0, rgb, relief, rough=0.38, n_str=3.4, ao_str=0.48)
    # Slot 7: Scalloped translucent-look violet-rose fin webbing with dark rays
    _, a7, b7 = _tile_coords(7)
    rays7 = (0.5 + 0.5 * np.cos(a7 * 14.0 * TAU)) ** 3
    rgb7 = _mix(_hex_rgb('8a5596')[None, None, :], _hex_rgb('452961')[None, None, :], rays7[..., None] * 0.68)
    rgb7 = _mix(rgb7, _hex_rgb('b87eb8')[None, None, :], (_np_smooth(0.45, 0.95, b7) * (1.0 - rays7))[..., None] * 0.48)
    _write_slot(albedo, normal, orm, emission, 7, rgb7, 0.065 * rays7, rough=0.32, n_str=3.0)
    # Slot 4: Luminous pearl-gold esca bulb
    _, a4, b4 = _tile_coords(4)
    glow_g = _np_smooth(0.0, 0.85, 1.0 - np.abs(b4 - 0.5) * 1.4)
    rgb4 = _mix(_hex_rgb('ffe094')[None, None, :], _hex_rgb('fffbe6')[None, None, :], glow_g[..., None])
    _write_slot(albedo, normal, orm, emission, 4, rgb4, np.zeros_like(a4), rough=0.12, emit=rgb4 * 0.95)
    # Slot 1: Translucent-look needle fangs & milky abyssal cataract eye (slot 6)
    _, a1, b1 = _tile_coords(1)
    rgb1 = _mix(_hex_rgb('c7b8c9')[None, None, :], _hex_rgb('f7f0e4')[None, None, :], _np_smooth(0.1, 0.85, b1)[..., None])
    _write_slot(albedo, normal, orm, emission, 1, rgb1, 0.01 * np.sin(a1 * 12 * TAU), rough=0.14)
    _, a6, b6 = _tile_coords(6)
    rgb6 = _mix(_hex_rgb('8fa4c4')[None, None, :], _hex_rgb('dce8f7')[None, None, :], (1.0 - np.hypot(a6 - 0.5, b6 - 0.5) * 1.4)[..., None])
    _write_slot(albedo, normal, orm, emission, 6, rgb6, np.zeros_like(a6), rough=0.09, emit=rgb6 * 0.12)


def _paint_manta_ray(albedo, normal, orm, emission):
    # Slot 0: Dorsal planar UV (a = 0..1 across wingspan X, b = 0..1 from snout -Y to rear +Y)
    _, a, b = _tile_coords(0)
    ax = np.abs(a - 0.5) * 2.0  # 0 at spine midline, 1 at wingtip
    c_royal = _hex_rgb('102c54')
    c_cobalt = _hex_rgb('1d4d88')
    c_sky = _hex_rgb('5a94c7')
    c_white = _hex_rgb('f2f6fa')
    mottle = _fbm(a, b, 5.5, 5.5, 503, 4)
    fine = _fbm(a, b, 15.0, 15.0, 509, 3)
    rgb = _mix(c_royal[None, None, :], c_cobalt[None, None, :], np.clip(0.32 + 0.42 * mottle + 0.18 * (1.0 - ax), 0, 1)[..., None])
    # Crisp white chevron shoulder markings behind head + dappled trailing-edge crescent
    chev_center = 0.24 + 0.28 * ax + 0.025 * mottle
    chev_band = np.exp(-((b - chev_center) / 0.048) ** 2 * 1.8)
    chev_span = _np_smooth(0.08, 0.16, ax) * (1.0 - _np_smooth(0.38, 0.50, ax))
    chev_mask = np.clip(chev_band * chev_span * (0.92 + 0.25 * fine), 0.0, 1.0)
    trail_line = 0.68 + 0.14 * ax + 0.07 * mottle + 0.03 * fine
    trail_patch = _np_smooth(trail_line - 0.04, trail_line + 0.05, b) * _np_smooth(0.24, 0.40, ax) * (1.0 - _np_smooth(0.86, 0.96, ax))
    white_mix = np.clip(np.maximum(chev_mask, trail_patch * 0.88), 0.0, 1.0)
    fringe = np.clip(_np_smooth(0.18, 0.52, white_mix) * (1.0 - _np_smooth(0.52, 0.85, white_mix)), 0.0, 1.0)
    rgb = _mix(rgb, c_sky[None, None, :], fringe[..., None] * 0.60)
    rgb = _mix(rgb, c_white[None, None, :], _np_smooth(0.38, 0.78, white_mix)[..., None] * 0.94)
    _write_slot(albedo, normal, orm, emission, 0, rgb, 0.015 * fine, rough=0.34, n_str=2.0)
    # Slot 1: Pure white ventral belly with subtle cool shading
    _, a1, b1 = _tile_coords(1)
    rgb1 = _mix(c_white[None, None, :], _hex_rgb('d5e2ee')[None, None, :], (_np_smooth(0.72, 0.98, np.abs(a1 - 0.5) * 2.0) * 0.35)[..., None])
    _write_slot(albedo, normal, orm, emission, 1, rgb1, 0.008 * _fbm(a1, b1, 8, 8, 511, 2), rough=0.28)
    # Slot 2: Deep royal-blue outer cephalic fin / tail
    _, a2, b2 = _tile_coords(2)
    rgb2 = _mix(c_royal[None, None, :], c_cobalt[None, None, :], b2[..., None] * 0.6)
    _write_slot(albedo, normal, orm, emission, 2, rgb2, 0.012 * np.sin(a2 * 16 * TAU), rough=0.28)


def _paint_sea_turtle(albedo, normal, orm, emission):
    # Slot 0: Exact top-down scute starburst tortoiseshell matching 3D carapace scutes!
    _, a, b = _tile_coords(0)
    d1 = np.full_like(a, 1e9)
    d2 = np.full_like(a, 1e9)
    cx_b = np.zeros_like(a)
    cy_b = np.zeros_like(a)
    kind_b = np.zeros_like(a)
    for sx, sy, w, kind in _TURTLE_SCUTE_SEEDS:
        dist = np.hypot((a - sx) * 1.12, (b - sy) * 0.92) * w
        cl = dist < d1
        d2 = np.where(cl, d1, np.minimum(d2, dist))
        cx_b = np.where(cl, sx, cx_b)
        cy_b = np.where(cl, sy, cy_b)
        kind_b = np.where(cl, float(kind), kind_b)
        d1 = np.where(cl, dist, d1)
    edge = d2 - d1
    suture = 1.0 - _np_smooth(0.003, 0.014, edge)
    ang = np.arctan2(b - cy_b, a - cx_b)
    mottle = _fbm(a, b, 7.0, 7.0, 601, 4)
    rays = (0.5 + 0.5 * np.cos(ang * 9.0 + mottle * 2.6)) ** 2.2
    rings = 0.5 + 0.5 * np.cos(d1 * 48.0 * TAU)
    c_dark = _hex_rgb('262914')
    c_olive = _hex_rgb('525728')
    c_amber = _hex_rgb('be8d32')
    c_cream = _hex_rgb('e4d5a0')
    rgb = _mix(c_dark[None, None, :], c_olive[None, None, :], np.clip(0.35 + 0.55 * (1.0 - d1 * 3.2) + 0.25 * mottle, 0, 1)[..., None])
    rgb = _mix(rgb, c_amber[None, None, :], (rays * _np_smooth(0.015, 0.12, edge) * 0.82)[..., None])
    rgb = _mix(rgb, c_cream[None, None, :], (suture * 0.75 + (kind_b == 2) * 0.08)[..., None])
    relief = 0.085 * _np_smooth(0.004, 0.045, edge) + 0.014 * rings - 0.065 * suture
    _write_slot(albedo, normal, orm, emission, 0, rgb, relief, rough=0.34, n_str=3.4, ao_str=0.45)
    # Slot 2 (Flippers) & Slot 5 (Head/Neck): Dark olive reticulated scale plates edged in cream!
    for sl, nx, ny, sd in ((2, 9, 18, 607), (5, 8, 14, 613)):
        _, af, bf = _tile_coords(sl)
        fd1, fedge, fid = _voronoi(af, bf, nx, ny, seed=sd, jitter=0.78)
        seam = 1.0 - _np_smooth(0.055, 0.135, fedge)
        plate_c = _mix(_hex_rgb('2b3622')[None, None, :], _hex_rgb('4d5632')[None, None, :], fid[..., None])
        plate_c = _mix(plate_c, c_amber[None, None, :], (_np_smooth(0.55, 0.95, fid) * 0.25)[..., None])
        rgbf = _mix(plate_c, c_cream[None, None, :], seam[..., None] * 0.92)
        relf = 0.075 * (1.0 - seam) * (1.0 - fd1 * 0.55) - 0.045 * seam
        _write_slot(albedo, normal, orm, emission, sl, rgbf, relf, rough=0.38, n_str=3.2, ao_str=0.42)
    # Slot 1: Cream-ochre plastron
    _, a1, b1 = _tile_coords(1)
    p_seam = np.exp(-((a1 - 0.5) / 0.018) ** 2) + np.exp(-((np.sin(b1 * 4.0 * math.pi)) / 0.08) ** 2) * 0.6
    rgb1 = _mix(c_cream[None, None, :], _hex_rgb('a89258')[None, None, :], np.clip(p_seam * 0.45, 0, 1)[..., None])
    _write_slot(albedo, normal, orm, emission, 1, rgb1, -0.025 * p_seam, rough=0.40)


def _paint_squid(albedo, normal, orm, emission):
    _, a, b = _tile_coords(0)
    c_pearl = _hex_rgb('f4ede6')
    c_opal = _hex_rgb('d6e9f0')
    c_coral = _hex_rgb('d9563e')
    c_crim = _hex_rgb('9e2a22')
    c_peach = _hex_rgb('eb9678')
    # Lateral UV: b = 0 ventral -> 1 dorsal; dense coral-red chromatophore stippling on back!
    d_a, _, id_a = _voronoi(a, b, 24, 46, seed=701, jitter=0.85)
    d_b, _, id_b = _voronoi(a, b, 42, 78, seed=709, jitter=0.85)
    density = _np_smooth(0.12, 0.78, b)
    rad_a = (0.18 + 0.34 * id_a) * (0.45 + 0.75 * density)
    rad_b = (0.16 + 0.28 * id_b) * (0.35 + 0.75 * density)
    dots_a = 1.0 - _np_smooth(rad_a * 0.7, rad_a, d_a)
    dots_b = 1.0 - _np_smooth(rad_b * 0.7, rad_b, d_b)
    rgb = _mix(c_pearl[None, None, :], c_opal[None, None, :], (np.exp(-((b - 0.42) / 0.18) ** 2) * 0.55)[..., None])
    rgb = _mix(rgb, c_peach[None, None, :], (_np_smooth(0.35, 0.90, b) * 0.35)[..., None])
    rgb = _mix(rgb, c_coral[None, None, :], (dots_b * 0.72)[..., None])
    rgb = _mix(rgb, _mix(c_coral[None, None, :], c_crim[None, None, :], id_a[..., None]), (dots_a * 0.88)[..., None])
    relief = 0.018 * (dots_a + 0.5 * dots_b)
    _write_slot(albedo, normal, orm, emission, 0, rgb, relief, rough=0.22, metal=0.06, n_str=2.2)
    # Slot 7: Rhomboid fins & arms with fine chromatophore stippling and pearlescent rim
    _, a7, b7 = _tile_coords(7)
    d7, _, id7 = _voronoi(a7, b7, 26, 48, seed=719, jitter=0.85)
    dots7 = (1.0 - _np_smooth(0.22, 0.34, d7)) * (1.0 - _np_smooth(0.68, 0.95, b7))
    rgb7 = _mix(c_pearl[None, None, :], c_peach[None, None, :], (0.45 * (1.0 - b7))[..., None])
    rgb7 = _mix(rgb7, c_coral[None, None, :], (dots7 * (0.45 + 0.4 * id7))[..., None])
    _write_slot(albedo, normal, orm, emission, 7, rgb7, 0.014 * dots7, rough=0.24, n_str=2.0)
    # Slot 1: Cupped ivory suckers; Slot 6: Metallic gold cephalopod iris!
    _, a1, b1 = _tile_coords(1)
    _write_slot(albedo, normal, orm, emission, 1, _mix(_hex_rgb('e6d9cb')[None, None, :], _hex_rgb('faf6f0')[None, None, :], b1[..., None]), 0.02 * np.cos(b1 * math.pi * 2), rough=0.28)
    _, a6, b6 = _tile_coords(6)
    rgb6 = _mix(_hex_rgb('b88428')[None, None, :], _hex_rgb('f5d56e')[None, None, :], (0.5 + 0.5 * np.sin(a6 * 16.0 * TAU) * 0.25 + 0.4 * b6)[..., None])
    _write_slot(albedo, normal, orm, emission, 6, rgb6, 0.018 * np.sin(a6 * 32.0 * TAU), rough=0.14, metal=0.52)


def _paint_crab(albedo, normal, orm, emission):
    _, a, b = _tile_coords(0)
    c_rust = _hex_rgb('bd3f18')
    c_orange = _hex_rgb('db6a2e')
    c_dark = _hex_rgb('54190c')
    c_cream = _hex_rgb('f5e8d3')
    mottle = _fbm(a, b, 5.0, 5.0, 809, 4)
    d1, _, tid = _voronoi(a, b, 16, 28, seed=811, jitter=0.82)
    tubercle = np.exp(-(d1 * 5.8) ** 2) * _np_smooth(0.45, 0.88, tid)
    ax = (a - 0.5) * 2.0
    # Sculpted cervical/cardiac groove darkening on dorsal shell
    cervical = np.exp(-((b - (0.48 + 0.16 * ax * ax)) / 0.032) ** 2) * _np_smooth(0.58, 0.16, np.abs(ax))
    rgb = _mix(c_rust[None, None, :], c_orange[None, None, :], np.clip(0.38 + 0.48 * mottle, 0, 1)[..., None])
    rgb = _mix(rgb, c_dark[None, None, :], np.clip(cervical * 0.68 + _np_smooth(0.2, -0.35, mottle) * 0.34, 0, 1)[..., None])
    rgb = _mix(rgb, c_cream[None, None, :], (tubercle * 0.78)[..., None])
    relief = 0.085 * tubercle + 0.025 * mottle - 0.045 * cervical
    _write_slot(albedo, normal, orm, emission, 0, rgb, relief, rough=0.35, n_str=3.4, ao_str=0.45)
    # Slot 2: Leg & pincer orange-to-cream armor; Slot 1: White-tipped pincer enamel & ventral apron
    _, a2, b2 = _tile_coords(2)
    d2t, _, tid2 = _voronoi(a2, b2, 10, 18, seed=821, jitter=0.8)
    tub2 = np.exp(-(d2t * 3.6) ** 2) * (tid2 > 0.45)
    rgb2 = _mix(c_rust[None, None, :], c_orange[None, None, :], (0.35 + 0.5 * b2)[..., None])
    rgb2 = _mix(rgb2, c_cream[None, None, :], np.clip(tub2 * 0.7 + _np_smooth(0.72, 0.98, b2) * 0.65, 0, 1)[..., None])
    _write_slot(albedo, normal, orm, emission, 2, rgb2, 0.06 * tub2, rough=0.34, n_str=3.0)
    _, a1, b1 = _tile_coords(1)
    rgb1 = _mix(_hex_rgb('e8cfb2')[None, None, :], _hex_rgb('fcf7ef')[None, None, :], _np_smooth(0.15, 0.78, b1)[..., None])
    _write_slot(albedo, normal, orm, emission, 1, rgb1, 0.015 * np.sin(b1 * 10.0 * math.pi), rough=0.24)
    _, a3, _ = _tile_coords(3)
    _write_slot(albedo, normal, orm, emission, 3, np.broadcast_to(_hex_rgb('1f100b'), (512, 256, 3)), np.zeros_like(a3), rough=0.16)


def _paint_jellyfish(albedo, normal, orm, emission):
    # Slot 0: Translucent 16-lobed opalescent lavender-violet & warm-gold bell
    _, a, b = _tile_coords(0)
    rib16 = (0.5 + 0.5 * np.cos(a * 16.0 * TAU)) ** 3.0
    lappet32 = (0.5 + 0.5 * np.cos(a * 32.0 * TAU)) ** 2.0
    mottle = _fbm(a, b, 4.0, 4.0, 907, 3)
    c_lav = _hex_rgb('b99ef0')
    c_peri = _hex_rgb('8fa4f5')
    c_gold = _hex_rgb('f7cfa0')
    c_pearl = _hex_rgb('faf5ff')
    rgb0 = _mix(c_peri[None, None, :], c_lav[None, None, :], (0.5 + 0.5 * mottle)[..., None])
    gold_zone = np.clip(_np_smooth(0.35, 0.02, b) * 0.65 + _np_smooth(0.76, 0.99, b) * 0.75, 0.0, 1.0)
    rgb0 = _mix(rgb0, c_gold[None, None, :], gold_zone[..., None] * 0.72)
    rgb0 = _mix(rgb0, c_pearl[None, None, :], np.clip(rib16 * 0.75 + _np_smooth(0.88, 0.99, b) * lappet32 * 0.65, 0, 1)[..., None])
    alpha0 = np.clip(0.36 + 0.30 * rib16 + 0.24 * _np_smooth(0.82, 0.99, b) + 0.12 * (1.0 - b), 0.32, 0.86)
    emit0 = rgb0 * (0.18 + 0.22 * rib16[..., None] + 0.18 * gold_zone[..., None])
    _write_slot(albedo, normal, orm, emission, 0, rgb0, 0.055 * rib16 + 0.02 * lappet32 * b, rough=0.14, alpha=alpha0, emit=emit0, n_str=2.6)
    # Slot 7: Translucent ruffled lilac-pink & opalescent cyan oral ribbon arms
    _, a7, b7 = _tile_coords(7)
    edge_frill = np.abs(a7 - 0.5) * 2.0
    vein = (0.5 + 0.5 * np.cos((b7 * 24.0 + 0.3 * np.sin(a7 * TAU)) * TAU)) * edge_frill
    rgb7 = _mix(_hex_rgb('d6a8f0')[None, None, :], _hex_rgb('f5bfe0')[None, None, :], (0.5 + 0.5 * np.sin(b7 * 9.0))[..., None])
    rgb7 = _mix(rgb7, _hex_rgb('c8ecfa')[None, None, :], (_np_smooth(0.55, 0.98, b7) * 0.48)[..., None])
    rgb7 = _mix(rgb7, c_pearl[None, None, :], (_np_smooth(0.68, 0.98, edge_frill) * 0.78)[..., None])
    alpha7 = np.clip(0.30 + 0.46 * (edge_frill ** 1.5) + 0.12 * vein, 0.28, 0.85)
    emit7 = rgb7 * (0.15 + 0.22 * _np_smooth(0.65, 0.98, edge_frill)[..., None])
    _write_slot(albedo, normal, orm, emission, 7, rgb7, 0.04 * vein, rough=0.18, alpha=alpha7, emit=emit7, n_str=2.4)
    # Slot 4: Glowing inner manubrium/gonad rings & luminous marginal tentacles
    _, a4, b4 = _tile_coords(4)
    rgb4 = _mix(_hex_rgb('ffb878')[None, None, :], _hex_rgb('fff2d6')[None, None, :], b4[..., None])
    _write_slot(albedo, normal, orm, emission, 4, rgb4, 0.02 * np.sin(a4 * 12 * TAU), rough=0.16, alpha=0.90, emit=rgb4 * 0.68)


# ---------------------------------------------------------------------------
# Creature 1–4: Reef Fish, Anthias, Pelagic Blue Shark, Abyssal Anglerfish
# ---------------------------------------------------------------------------

def create_fish():
    """Emperor Angelfish — bounds [-0.32..0.32, -0.32..0.52, -0.22..0.32]."""
    _A.bone('body', (0.0, -0.26, 0.0), (0.0, -0.01, 0.0))
    _A.bone('spine', (0.0, -0.01, 0.0), (0.0, 0.16, 0.0), 'body')
    _A.bone('tail', (0.0, 0.16, 0.0), (0.0, 0.30, 0.0), 'spine')
    _A.bone('tail_tip', (0.0, 0.30, 0.0), (0.0, 0.50, 0.0), 'tail')
    w_spine = _spine_weights([(-0.10, 'body'), (0.10, 'spine'), (0.24, 'tail'), (0.36, 'tail_tip')])

    ctrl = [
        (-0.318, 0.008, 0.015, 0.015, -0.022),
        (-0.285, 0.036, 0.058, 0.046, -0.012),
        (-0.215, 0.068, 0.125, 0.102, 0.006),
        (-0.115, 0.086, 0.172, 0.148, 0.012),
        (0.010, 0.088, 0.180, 0.158, 0.010),
        (0.135, 0.072, 0.152, 0.136, 0.006),
        (0.235, 0.044, 0.092, 0.084, 0.002),
        (0.300, 0.022, 0.048, 0.046, 0.0),
        (0.335, 0.010, 0.026, 0.026, 0.0),
    ]

    def _angel_shape(t, phi, y, dx, dy, dz, rx, rz_up, rz_dn):
        # Pinch dorsal & ventral fin keels + sculpted opercular gill ridge
        keel = 1.0 - 0.34 * (abs(math.sin(phi)) ** 6)
        gill = 1.0 + 0.065 * math.exp(-((y + 0.155) / 0.024) ** 2) * (abs(math.cos(phi)) ** 2)
        return dx * keel * gill, dy, dz

    _hull('Emperor angelfish compressed hull', ctrl, n_rings=44, sides=38,
          slot=0, bones=w_spine, uv_mode='lateral', shape_fn=_angel_shape)
    # Protruding ivory reef lips & preopercular cheek spine
    _ellipsoid('Protruding upper lip', (0.0, -0.306, -0.016), (0.022, 0.020, 0.014), 1, 'body', 12, 7)
    _ellipsoid('Protruding lower lip', (0.0, -0.302, -0.030), (0.020, 0.018, 0.012), 1, 'body', 12, 7)
    _eye_pair(0.052, -0.222, 0.032, 0.026, 'body', iris_slot=6, pupil_slot=3, rim_slot=0)
    for s in (-1, 1):
        _swept_tube('Preopercular cheek spine',
                    [(s * 0.072, -0.162, -0.068), (s * 0.082, -0.122, -0.088)],
                    [0.008, 0.0005], n_steps=6, sides=6, slot=5, bones='body')
    # Sweeping dorsal banner with whip-like filamentous streamer
    _fan_fin('Sweeping dorsal streamer fin',
             [(-0.165, -0.165, 0.132) if False else (0.0, -0.168, 0.132),
              (0.0, -0.04, 0.168), (0.0, 0.11, 0.150), (0.0, 0.265, 0.062)],
             [(0.0, -0.135, 0.215), (0.0, 0.05, 0.305), (0.0, 0.28, 0.320),
              (0.0, 0.485, 0.265), (0.0, 0.355, 0.125)],
             slot=2, bones=w_spine, u_steps=28, v_steps=9, thickness=0.011,
             rays=18, ray_amp=0.0018, scallop=0.03, normal_hint=(1, 0, 0),
             mid_bias=0.46, mid_bulge=(0.0, -0.05, 0.035))
    # Sweeping anal fin with matching filamentous ventral streamer
    _fan_fin('Sweeping anal streamer fin',
             [(0.0, -0.025, -0.145), (0.0, 0.10, -0.132), (0.0, 0.260, -0.055)],
             [(0.0, 0.04, -0.205), (0.0, 0.22, -0.220), (0.0, 0.435, -0.202), (0.0, 0.34, -0.105)],
             slot=2, bones=w_spine, u_steps=24, v_steps=8, thickness=0.010,
             rays=15, ray_amp=0.0016, scallop=0.03, normal_hint=(1, 0, 0),
             mid_bias=0.48, mid_bulge=(0.0, -0.04, -0.025))
    # Rounded golden-yellow fan caudal fin
    _fan_fin('Rounded golden caudal fin',
             [(0.0, 0.292, 0.044), (0.0, 0.305, 0.0), (0.0, 0.292, -0.044)],
             [(0.0, 0.465, 0.118), (0.0, 0.520, 0.045), (0.0, 0.520, -0.045), (0.0, 0.465, -0.118)],
             slot=5, bones='tail_tip', u_steps=20, v_steps=9, thickness=0.009,
             rays=14, ray_amp=0.0016, scallop=0.035, normal_hint=(1, 0, 0))
    # Rayed golden-yellow pectoral fins & filamentous pelvic fins
    for s in (-1, 1):
        fb = _A.bone('fin_' + ('L' if s < 0 else 'R'),
                     (s * 0.075, -0.115, -0.032), (s * 0.305, -0.010, -0.015), 'body')
        _fan_fin('Rayed pectoral fan',
                 [(s * 0.074, -0.135, -0.010), (s * 0.076, -0.115, -0.035), (s * 0.074, -0.092, -0.058)],
                 [(s * 0.295, -0.035, 0.032), (s * 0.320, 0.025, -0.008), (s * 0.245, 0.055, -0.068)],
                 slot=5, bones=fb, u_steps=16, v_steps=8, thickness=0.007,
                 camber=0.012 * s, rays=12, ray_amp=0.0014, scallop=0.04, normal_hint=(0, 0, 1))
        _fan_fin('Pointed pelvic streamer',
                 [(s * 0.022, -0.145, -0.135), (s * 0.030, -0.105, -0.142)],
                 [(s * 0.065, 0.085, -0.220), (s * 0.042, 0.025, -0.182)],
                 slot=5, bones='body', u_steps=12, v_steps=6, thickness=0.006,
                 rays=6, ray_amp=0.001, scallop=0.02, normal_hint=(s, 0, 0))


def create_fish_small():
    """Golden-Orange Anthias — bounds [-0.24..0.24, -0.23..0.38, -0.18..0.25]."""
    _A.bone('body', (0.0, -0.19, 0.0), (0.0, -0.01, 0.0))
    _A.bone('spine', (0.0, -0.01, 0.0), (0.0, 0.11, 0.0), 'body')
    _A.bone('tail', (0.0, 0.11, 0.0), (0.0, 0.21, 0.0), 'spine')
    _A.bone('tail_tip', (0.0, 0.21, 0.0), (0.0, 0.36, 0.0), 'tail')
    w_spine = _spine_weights([(-0.08, 'body'), (0.07, 'spine'), (0.17, 'tail'), (0.26, 'tail_tip')])

    ctrl = [
        (-0.230, 0.006, 0.010, 0.010, 0.004),
        (-0.195, 0.026, 0.038, 0.034, 0.006),
        (-0.135, 0.048, 0.072, 0.066, 0.008),
        (-0.045, 0.056, 0.092, 0.084, 0.006),
        (0.055, 0.048, 0.078, 0.072, 0.003),
        (0.145, 0.030, 0.046, 0.044, 0.0),
        (0.205, 0.016, 0.028, 0.028, 0.0),
        (0.232, 0.008, 0.018, 0.018, 0.0),
    ]
    _hull('Sleek fusiform anthias body', ctrl, n_rings=40, sides=34,
          slot=0, bones=w_spine, uv_mode='lateral')
    _ellipsoid('Anthias upturned snout lip', (0.0, -0.220, 0.006), (0.015, 0.015, 0.009), 0, 'body', 10, 6)
    _eye_pair(0.029, -0.168, 0.016, 0.020, 'body', iris_slot=6, pupil_slot=3, rim_slot=0)

    # Rayed dorsal fin with signature elongated anterior spine banner peaking at Z=0.25!
    def _anthias_dorsal_margin(u):
        y = -0.095 + 0.315 * u
        banner = 0.145 * math.exp(-((u - 0.16) / 0.11) ** 2)
        soft = 0.062 * math.sin(math.pi * _clamp((u - 0.25) / 0.75)) ** 0.75
        z = 0.105 + banner + soft * (1.0 - 0.25 * u)
        return (0.0, y + 0.038 * banner / 0.145, z)

    _fan_fin('Anthias elongated-spine dorsal fin',
             [(0.0, -0.105, 0.074), (0.0, -0.01, 0.088), (0.0, 0.09, 0.068), (0.0, 0.168, 0.034)],
             _anthias_dorsal_margin, slot=7, bones=w_spine, u_steps=28, v_steps=9,
             thickness=0.007, rays=16, ray_amp=0.0014, scallop=0.055, normal_hint=(1, 0, 0))

    # Deeply forked lunate swallowtail (continuous V-notched rayed fin!)
    def _anthias_tail_margin(u):
        s = (u - 0.5) * 2.0
        fork = abs(s) ** 1.35
        y = 0.258 + 0.122 * fork
        z = 0.162 * s * (0.72 + 0.28 * fork)
        return (0.0, y, z)

    _fan_fin('Deeply forked lunate swallowtail',
             [(0.0, 0.205, 0.026), (0.0, 0.218, 0.0), (0.0, 0.205, -0.026)],
             _anthias_tail_margin, slot=2, bones='tail_tip', u_steps=24, v_steps=9,
             thickness=0.006, rays=16, ray_amp=0.0012, scallop=0.03, normal_hint=(1, 0, 0))
    # Pointed anal fin + paired pectoral & pelvic fins
    _fan_fin('Pointed rayed anal fin',
             [(0.0, 0.015, -0.076), (0.0, 0.09, -0.058), (0.0, 0.155, -0.032)],
             [(0.0, 0.055, -0.145), (0.0, 0.145, -0.172), (0.0, 0.195, -0.085)],
             slot=7, bones=w_spine, u_steps=16, v_steps=7, thickness=0.006,
             rays=10, ray_amp=0.001, scallop=0.045, normal_hint=(1, 0, 0))
    for s in (-1, 1):
        fb = _A.bone('fin_' + ('L' if s < 0 else 'R'),
                     (s * 0.050, -0.082, -0.018), (s * 0.225, 0.015, -0.032), 'body')
        _fan_fin('Delicate anthias pectoral',
                 [(s * 0.048, -0.096, -0.004), (s * 0.050, -0.070, -0.030)],
                 [(s * 0.240, 0.010, -0.005), (s * 0.195, 0.050, -0.058)],
                 slot=7, bones=fb, u_steps=14, v_steps=7, thickness=0.005,
                 rays=11, ray_amp=0.001, scallop=0.04, normal_hint=(0, 0, 1))
        _fan_fin('Slender anthias pelvic fin',
                 [(s * 0.016, -0.088, -0.074), (s * 0.022, -0.055, -0.078)],
                 [(s * 0.048, 0.045, -0.180), (s * 0.032, 0.015, -0.132)],
                 slot=7, bones='body', u_steps=10, v_steps=5, thickness=0.0045,
                 rays=6, ray_amp=0.0008, scallop=0.02, normal_hint=(s, 0, 0))


def create_fish_predator():
    """Pelagic Blue Shark — bounds [-1.25..1.25, -1.83..2.25, -0.60..1.15]."""
    _A.bone('body', (0.0, -1.42, 0.0), (0.0, -0.18, 0.0))
    _A.bone('spine', (0.0, -0.18, 0.0), (0.0, 0.68, 0.0), 'body')
    _A.bone('tail', (0.0, 0.68, 0.0), (0.0, 1.42, 0.0), 'spine')
    _A.bone('tail_tip', (0.0, 1.42, 0.0), (0.0, 2.15, 0.55), 'tail')
    _A.bone('jaw', (0.0, -0.98, -0.14), (0.0, -1.46, -0.15), 'body')
    w_spine = _spine_weights([(-0.45, 'body'), (0.35, 'spine'), (1.08, 'tail'), (1.62, 'tail_tip')])

    ctrl = [
        (-1.830, 0.014, 0.018, 0.016, 0.018),
        (-1.660, 0.135, 0.095, 0.068, 0.022),
        (-1.420, 0.245, 0.185, 0.115, 0.035),
        (-1.080, 0.315, 0.275, 0.215, 0.025),
        (-0.580, 0.348, 0.345, 0.285, 0.020),
        (-0.020, 0.335, 0.340, 0.275, 0.018),
        (0.520, 0.265, 0.265, 0.215, 0.012),
        (1.020, 0.165, 0.165, 0.140, 0.006),
        (1.380, 0.095, 0.082, 0.075, 0.004),
        (1.580, 0.052, 0.055, 0.050, 0.010),
    ]

    def _shark_shape(t, phi, y, dx, dy, dz, rx, rz_up, rz_dn):
        ca, sa = math.cos(phi), math.sin(phi)
        # Lateral caudal keels on peduncle + flattened ventral snout
        keel = 1.0 + 0.38 * math.exp(-((y - 1.34) / 0.18) ** 2) * (abs(ca) ** 6)
        snout_flat = 1.0 - 0.25 * _smoothstep(-1.15, -1.55, y) * (max(0.0, -sa) ** 2)
        return dx * keel, dy, dz * snout_flat

    _hull('Pelagic blue shark trunk', ctrl, n_rings=50, sides=40,
          slot=0, bones=w_spine, uv_mode='lateral', shape_fn=_shark_shape)
    # Articulated ventral jaw tucked sleekly into ventral snout recess + serrated teeth
    _hull('Articulated shark lower jaw', [
        (-1.42, 0.045, 0.015, 0.025, -0.098),
        (-1.28, 0.148, 0.024, 0.042, -0.125),
        (-1.10, 0.205, 0.030, 0.048, -0.148),
        (-0.92, 0.215, 0.032, 0.040, -0.152),
    ], n_rings=16, sides=22, slot=1, bones='jaw', uv_mode='lateral')
    _ellipsoid('Shark oral roof cavity', (0.0, -1.20, -0.095), (0.155, 0.20, 0.035), 3, 'body', 14, 7)
    for s in (-1, 1):
        for k in range(7):
            tk = (k + 0.4) / 7.0
            ang = tk * math.pi * 0.46
            ux, uy = s * 0.165 * math.sin(ang + 0.14), -1.38 + 0.34 * tk
            _swept_tube('Upper serrated tooth', [(ux, uy, -0.082), (ux * 0.96, uy + 0.006, -0.112)],
                        [0.012, 0.0008], n_steps=4, sides=5, slot=1, bones='body')
            lx, ly = s * 0.148 * math.sin(ang + 0.14), -1.36 + 0.32 * tk
            _swept_tube('Lower serrated tooth', [(lx, ly, -0.116), (lx * 0.96, ly + 0.006, -0.090)],
                        [0.011, 0.0008], n_steps=4, sides=5, slot=1, bones='jaw')
        # Nostrils + 5 sculpted recessed gill slits & overlapping gill septa per side!
        _ellipsoid('Ventral nare slit', (s * 0.115, -1.56, -0.052), (0.018, 0.032, 0.008), 3, 'body', 8, 5)
        for g in range(5):
            gy = -0.96 + g * 0.082
            gx = 0.315 + 0.016 * math.sin(g * 0.6)
            _swept_tube('Recessed gill slit',
                        [(s * (gx - 0.018), gy, 0.105), (s * (gx + 0.008), gy + 0.012, -0.015),
                         (s * (gx - 0.022), gy + 0.004, -0.135)],
                        [0.006, 0.013, 0.006], n_steps=7, sides=6, slot=3, bones='body')
            _swept_tube('Sculpted gill septum',
                        [(s * (gx - 0.012), gy - 0.014, 0.100), (s * (gx + 0.015), gy - 0.002, -0.015),
                         (s * (gx - 0.016), gy - 0.010, -0.130)],
                        [0.005, 0.011, 0.005], n_steps=7, sides=6, slot=0, bones='body')
    _eye_pair(0.228, -1.33, 0.042, 0.044, 'body', iris_slot=3, pupil_slot=3, rim_slot=1)
    # Long falcate pectoral fins (indigo dorsal slot 2, white ventral slot 1) + pelvic fins
    for s in (-1, 1):
        fb = _A.bone('fin_' + ('L' if s < 0 else 'R'),
                     (s * 0.28, -0.58, -0.16), (s * 1.18, 0.05, -0.52), 'body')
        _fan_fin('Long falcate pectoral fin',
                 [(s * 0.27, -0.74, -0.15), (s * 0.29, -0.54, -0.18), (s * 0.27, -0.34, -0.19)],
                 [(s * 0.82, -0.36, -0.38), (s * 1.250, 0.14, -0.575), (s * 0.68, -0.08, -0.34)],
                 slot=2, ventral_slot=1, bones=fb, u_steps=20, v_steps=8,
                 thickness=0.028, camber=0.018, rays=10, ray_amp=0.001, normal_hint=(0, 0, s))
        _fan_fin('Pelvic fin',
                 [(s * 0.14, 0.48, -0.19), (s * 0.11, 0.72, -0.16)],
                 [(s * 0.36, 0.74, -0.34), (s * 0.16, 0.86, -0.21)],
                 slot=2, ventral_slot=1, bones='spine', u_steps=10, v_steps=5,
                 thickness=0.014, rays=6, ray_amp=0.0008, normal_hint=(0, 0, s))
    # Apex first dorsal + second dorsal + small falcate anal fin
    _fan_fin('Apex first dorsal fin',
             [(0.0, -0.36, 0.32), (0.0, -0.02, 0.32), (0.0, 0.30, 0.28)],
             [(0.0, 0.02, 0.82), (0.0, 0.18, 1.06), (0.0, 0.22, 0.62), (0.0, 0.42, 0.31)],
             slot=2, bones='spine', u_steps=20, v_steps=8, thickness=0.028,
             rays=10, ray_amp=0.0012, normal_hint=(1, 0, 0))
    _fan_fin('Second dorsal fin',
             [(0.0, 0.94, 0.16), (0.0, 1.16, 0.11)],
             [(0.0, 1.10, 0.35), (0.0, 1.26, 0.14)],
             slot=2, bones='tail', u_steps=10, v_steps=5, thickness=0.014, normal_hint=(1, 0, 0))
    _fan_fin('Falcate anal fin',
             [(0.0, 0.98, -0.14), (0.0, 1.18, -0.10)],
             [(0.0, 1.14, -0.33), (0.0, 1.28, -0.13)],
             slot=1, bones='tail', u_steps=10, v_steps=5, thickness=0.014, normal_hint=(1, 0, 0))

    # Asymmetric heterocercal caudal fin WITH ventral subterminal notch!
    def _shark_caudal_margin(u):
        if u < 0.56:
            t = u / 0.56
            y = 2.250 - 0.52 * (t ** 1.25)
            z = 1.150 - 1.15 * (t ** 1.15)
            # Ventral subterminal notch near u ~ 0.14!
            notch = 0.11 * math.exp(-((t - 0.17) / 0.055) ** 2) - 0.045 * math.exp(-((t - 0.26) / 0.045) ** 2)
            return (0.0, y - notch, z)
        t = (u - 0.56) / 0.44
        y = 1.73 + 0.07 * math.sin(t * math.pi * 0.85) - 0.16 * (t ** 2)
        z = -0.600 * math.sin(t * math.pi * 0.72 + 0.12)
        return (0.0, y, min(0.0, z))

    _fan_fin('Asymmetric heterocercal caudal fin',
             [(0.0, 1.44, 0.065), (0.0, 1.88, 0.62), (0.0, 1.54, 0.0), (0.0, 1.46, -0.065)],
             _shark_caudal_margin, slot=2, bones='tail_tip', u_steps=30, v_steps=9,
             thickness=0.026, rays=14, ray_amp=0.0012, normal_hint=(1, 0, 0))


def create_fish_abyss():
    """Deep-Violet Abyssal Anglerfish — bounds [-0.457..0.457, -1.464..1.75, -0.66..1.056]."""
    _A.bone('body', (0.0, -1.08, 0.08), (0.0, -0.15, 0.12))
    _A.bone('spine', (0.0, -0.15, 0.12), (0.0, 0.55, -0.02), 'body')
    _A.bone('tail', (0.0, 0.55, -0.02), (0.0, 1.10, -0.22), 'spine')
    _A.bone('tail_tip', (0.0, 1.10, -0.22), (0.0, 1.68, -0.34), 'tail')
    _A.bone('jaw', (0.0, -0.64, -0.15), (0.0, -1.36, -0.24), 'body')
    w_spine = _spine_weights([(-0.35, 'body'), (0.28, 'spine'), (0.86, 'tail'), (1.28, 'tail_tip')])

    ctrl = [
        (-1.28, 0.14, 0.12, 0.05, 0.22),
        (-1.08, 0.28, 0.25, 0.12, 0.20),
        (-0.80, 0.31, 0.32, 0.24, 0.15),
        (-0.42, 0.26, 0.31, 0.25, 0.14),
        (0.02, 0.19, 0.25, 0.20, 0.09),
        (0.46, 0.13, 0.18, 0.15, -0.02),
        (0.84, 0.085, 0.12, 0.11, -0.15),
        (1.14, 0.052, 0.085, 0.085, -0.24),
        (1.26, 0.028, 0.055, 0.055, -0.26),
    ]

    def _angler_shape(t, phi, y, dx, dy, dz, rx, rz_up, rz_dn):
        # Sculpted muscular myomere ridges & lateral sensory canal fold!
        rib = 1.0 + 0.055 * math.cos(t * 17.0 * TAU) * (abs(math.cos(phi)) ** 1.5)
        lat = 1.0 + 0.065 * math.exp(-((math.sin(phi) - 0.08) / 0.18) ** 2) * _smoothstep(-0.6, 0.9, y)
        return dx * rib * lat, dy, dz * (1.0 + 0.03 * math.cos(t * 17.0 * TAU))

    _hull('Ridged plum-violet anglerfish trunk', ctrl, n_rings=46, sides=38,
          slot=0, bones=w_spine, uv_mode='lateral', shape_fn=_angler_shape)
    # Cavernous upturned lower jaw + dark mouth cavity + gnarled dermal barbels
    _hull('Upturned anglerfish mandible', [
        (-1.40, 0.085, 0.035, 0.055, -0.14),
        (-1.26, 0.245, 0.042, 0.095, -0.23),
        (-0.98, 0.295, 0.048, 0.105, -0.26),
        (-0.64, 0.235, 0.055, 0.085, -0.18),
    ], n_rings=18, sides=24, slot=0, bones='jaw', uv_mode='lateral')
    _ellipsoid('Cavernous abyssal throat', (0.0, -0.78, -0.02), (0.16, 0.18, 0.09), 3, 'body', 14, 8)
    # 28 long inward-curved translucent needle fangs along upper & lower jaws!
    fang_lens = (0.19, 0.27, 0.15, 0.24, 0.12, 0.18, 0.10)
    for s in (-1, 1):
        for k, fl in enumerate(fang_lens):
            tk = (k + 0.35) / len(fang_lens)
            ang = tk * math.pi * 0.48
            ux = s * (0.11 + 0.17 * math.sin(ang + 0.18))
            uy = -1.25 + 0.46 * tk
            uz = 0.11 - 0.09 * tk
            _swept_tube('Upper curved needle fang',
                        [(ux, uy, uz), (ux * 0.92, uy + 0.03, uz - fl * 0.55),
                         (ux * 0.78, uy + 0.07, uz - fl)],
                        [0.016, 0.008, 0.0006], n_steps=6, sides=7, slot=1, bones='body')
            lx = s * (0.10 + 0.18 * math.sin(ang + 0.15))
            ly = -1.36 + 0.52 * tk
            lz = -0.16 - 0.07 * math.sin(tk * math.pi)
            _swept_tube('Lower curved needle fang',
                        [(lx, ly, lz), (lx * 0.93, ly + 0.025, lz + fl * 0.58),
                         (lx * 0.80, ly + 0.065, lz + fl * 1.05)],
                        [0.017, 0.009, 0.0006], n_steps=6, sides=7, slot=1, bones='jaw')
            if k % 2 == 0:
                _swept_tube('Chin sensory barbel',
                            [(lx * 1.03, ly, lz - 0.065), (lx * 1.10, ly - 0.03, lz - 0.145)],
                            [0.012, 0.001], n_steps=5, sides=5, slot=0, bones='jaw')
        # Supraorbital brow horn + cheek spine + lateral sensory tubercles!
        _swept_tube('Supraorbital brow spine',
                    [(s * 0.20, -0.92, 0.34), (s * 0.25, -0.82, 0.45)],
                    [0.024, 0.002], n_steps=5, sides=6, slot=0, bones='body')
        for m_i in range(9):
            tm = m_i / 8.0
            ty = -0.52 + 1.52 * tm
            tz = 0.15 - 0.38 * (tm ** 1.25)
            tx = s * (0.25 * (1.0 - 0.78 * tm))
            _ellipsoid('Lateral sensory tubercle', (tx, ty, tz),
                       (0.018, 0.024, 0.018), 4 if m_i % 3 == 0 else 0, w_spine, 8, 6)
    _eye_pair(0.248, -0.96, 0.23, 0.050, 'body', iris_slot=6, pupil_slot=6, rim_slot=0, glint_slot=4)
    # Long arched illicium stalk peaking at Z=1.056 -> multi-layered luminous pearl-gold esca bulb!
    lure_pts = [(0.0, -0.84, 0.36), (0.0, -0.86, 0.78), (0.0, -1.08, 1.042),
                (0.0, -1.32, 0.94), (0.0, -1.405, 0.68)]
    _swept_tube('Arched illicium lure stalk', lure_pts, [0.028, 0.020, 0.014, 0.011, 0.018],
                n_steps=20, sides=10, slot=0, bones='body', up_hint=(1, 0, 0))
    esca_c = (0.0, -1.405, 0.61)
    _ellipsoid('Esca pigment cup', (0.0, -1.405, 0.665), (0.036, 0.036, 0.030), 0, 'body', 12, 8)
    _ellipsoid('Luminous esca inner core', esca_c, (0.038, 0.038, 0.046), 4, 'body', 12, 8)
    _ellipsoid('Opalescent esca pearl bulb', (0.0, -1.405, 0.595), (0.058, 0.059, 0.068), 4, 'body', 16, 10)
    # Spiny anterior dorsal crest + scalloped soft dorsal/anal + fan-rayed pectoral & caudal fins!
    for sp_i in range(5):
        sy = -0.62 + sp_i * 0.155
        sz = 0.36 - sp_i * 0.025
        _swept_tube('Spiny dorsal crest ray',
                    [(0.0, sy, sz), (0.0, sy + 0.09, sz + 0.14), (0.0, sy + 0.20, sz + 0.19)],
                    [0.016, 0.009, 0.001], n_steps=6, sides=6, slot=0, bones=w_spine)
    _fan_fin('Scalloped abyssal dorsal veil',
             [(0.0, -0.05, 0.28), (0.0, 0.45, 0.14), (0.0, 0.96, -0.10)],
             [(0.0, 0.15, 0.50), (0.0, 0.68, 0.36), (0.0, 1.18, 0.02)],
             slot=7, bones=w_spine, u_steps=20, v_steps=8, thickness=0.012,
             rays=11, ray_amp=0.003, scallop=0.085, normal_hint=(1, 0, 0))
    _fan_fin('Scalloped abyssal anal fin',
             [(0.0, 0.22, -0.16), (0.0, 0.62, -0.22), (0.0, 0.98, -0.30)],
             [(0.0, 0.42, -0.36), (0.0, 0.82, -0.44), (0.0, 1.14, -0.42)],
             slot=7, bones=w_spine, u_steps=16, v_steps=7, thickness=0.010,
             rays=8, ray_amp=0.0025, scallop=0.08, normal_hint=(1, 0, 0))
    for s in (-1, 1):
        fb = _A.bone('fin_' + ('L' if s < 0 else 'R'),
                     (s * 0.20, -0.42, -0.06), (s * 0.44, 0.04, -0.48), 'body')
        _swept_tube('Pediculate pectoral lobe',
                    [(s * 0.16, -0.46, -0.04), (s * 0.28, -0.34, -0.12)],
                    [0.068, 0.052], n_steps=6, sides=10, slot=0, bones=fb)
        _fan_fin('Fan-rayed scalloped pectoral',
                 [(s * 0.25, -0.42, -0.07), (s * 0.28, -0.34, -0.13), (s * 0.25, -0.26, -0.18)],
                 [(s * 0.457, -0.16, -0.18), (s * 0.445, 0.10, -0.44), (s * 0.30, 0.18, -0.63)],
                 slot=7, bones=fb, u_steps=18, v_steps=8, thickness=0.011,
                 rays=10, ray_amp=0.0032, scallop=0.095, normal_hint=(s, 0, 0.3))
    _fan_fin('Fan-rayed scalloped caudal fin',
             [(0.0, 1.12, -0.18), (0.0, 1.18, -0.25), (0.0, 1.12, -0.32)],
             [(0.0, 1.62, 0.04), (0.0, 1.750, -0.24), (0.0, 1.72, -0.50), (0.0, 1.52, -0.660)],
             slot=7, bones='tail_tip', u_steps=22, v_steps=9, thickness=0.012,
             rays=11, ray_amp=0.0035, scallop=0.10, normal_hint=(1, 0, 0))


# ---------------------------------------------------------------------------
# Creature 5–7: Giant Manta Ray, Hawksbill/Green Sea Turtle, Reef Squid
# ---------------------------------------------------------------------------

def create_manta_ray():
    """Giant Oceanic Manta Ray — bounds [-2.255..2.255, -1.49..3.351, -0.25..0.25]."""
    _A.bone('body', (0.0, -0.88, 0.0), (0.0, 0.68, 0.0))
    _A.bone('tail', (0.0, 0.68, 0.0), (0.0, 1.98, -0.04), 'body')
    _A.bone('tail_tip', (0.0, 1.98, -0.04), (0.0, 3.34, -0.08), 'tail')
    _A.bone('wing_L', (-0.42, -0.16, 0.0), (-2.12, 0.36, 0.18), 'body')
    _A.bone('wing_R', (0.42, -0.16, 0.0), (2.12, 0.36, 0.18), 'body')

    def _manta_weights(p):
        ax = abs(p[0])
        if ax <= 0.36:
            return {'body': 1.0}
        t = _clamp((ax - 0.36) / 1.05)
        wb = 'wing_L' if p[0] < 0.0 else 'wing_R'
        return {'body': 1.0 - t, wb: t}

    # Single unbroken sculpted hydrofoil body+wings mesh (watertight stitched perimeter!)
    nx, ny = 58, 30
    verts, vuvs, top_m, bot_m = [], [], {}, {}
    for ix in range(nx + 1):
        ux = ix / nx
        sx = (ux - 0.5) * 2.0  # -1..+1 across wingspan
        ax = abs(sx)
        x = sx * 2.255
        # Leading edge: wide terminal mouth notch in middle -> swept S-curve wing leading edge
        y_lead = -0.98 + 0.06 * (1.0 - _smoothstep(0.0, 0.18, ax)) + 1.38 * (ax ** 1.68)
        # Trailing edge: pelvic tail base -> concave swept trailing wing edge meeting wingtip
        y_trail = 0.88 - 0.36 * math.sin(math.pi * min(1.0, ax * 1.12)) - 0.48 * (ax ** 2.4)
        if y_trail < y_lead + 0.015:
            y_trail = y_lead + 0.015
        span_lift = 0.235 * (ax ** 2.15) - 0.035 * math.sin(math.pi * min(1.0, ax * 1.3))
        body_thick = 0.175 * math.exp(-((ax / 0.24) ** 2)) + 0.052 * (1.0 - ax) ** 0.75
        for iy in range(ny + 1):
            vy = iy / ny
            y = y_lead + (y_trail - y_lead) * vy
            foil_env = math.sin(math.pi * vy) ** 0.72 * (1.0 - 0.32 * vy)
            camber = 0.032 * math.sin(math.pi * vy) * (0.35 + 0.65 * ax)
            z_mid = span_lift + camber - 0.035 * math.exp(-((ax / 0.22) ** 2)) * (1.0 - vy)
            u_tex = _clamp(0.5 + 0.495 * sx)
            v_tex = _clamp((y + 1.05) / 1.98)
            stitched = (ix == 0 or ix == nx or iy == 0 or iy == ny)
            if stitched:
                idx = len(verts)
                verts.append((x, y, z_mid))
                vuvs.append((u_tex, v_tex))
                top_m[(ix, iy)] = idx
                bot_m[(ix, iy)] = idx
            else:
                ht_up = max(0.002, body_thick * foil_env * 0.82)
                ht_dn = max(0.002, body_thick * foil_env * 1.08)
                it = len(verts)
                verts.append((x, y, z_mid + ht_up))
                vuvs.append((u_tex, v_tex))
                ib = len(verts)
                verts.append((x, y, z_mid - ht_dn))
                vuvs.append((u_tex, v_tex))
                top_m[(ix, iy)] = it
                bot_m[(ix, iy)] = ib
    faces, fslots = [], []
    for ix in range(nx):
        for iy in range(ny):
            faces.append((top_m[(ix, iy)], top_m[(ix, iy + 1)], top_m[(ix + 1, iy + 1)], top_m[(ix + 1, iy)]))
            fslots.append(0)
            faces.append((bot_m[(ix, iy)], bot_m[(ix + 1, iy)], bot_m[(ix + 1, iy + 1)], bot_m[(ix, iy + 1)]))
            fslots.append(1)
    _emit_mesh('Continuous sculpted manta hydrofoil', verts, faces, vert_uvs=vuvs,
               slot=0, bones=_manta_weights, face_slots=fslots)
    # Wide terminal filter-feeding mouth cavern
    _ellipsoid('Terminal mouth cavity', (0.0, -0.94, -0.045), (0.28, 0.08, 0.065), 3, 'body', 16, 8)
    for s in (-1, 1):
        # Unfurled horn-like scroll cephalic lobes framing the mouth!
        _fan_fin('Unfurled cephalic scroll lobe',
                 [(s * 0.30, -0.90, 0.025), (s * 0.36, -0.94, -0.040), (s * 0.28, -0.94, -0.105)],
                 [(s * 0.28, -1.42, -0.045), (s * 0.22, -1.490, -0.155), (s * 0.16, -1.36, -0.238)],
                 slot=2, ventral_slot=1, bones='body', u_steps=16, v_steps=8,
                 thickness=0.020, camber=0.028, rays=6, ray_amp=0.0006, normal_hint=(s, -0.2, 0.6))
        # Lateral cranial eye swelling + 5 sculpted ventral dark gill slits per side!
        _ellipsoid('Lateral cranial eye pod', (s * 0.41, -0.88, -0.01), (0.055, 0.095, 0.048), 2, 'body', 12, 8)
        for g in range(5):
            gy = -0.68 + g * 0.115
            z_belly = -0.165 + 0.015 * g
            _swept_tube('Ventral manta gill slit',
                        [(s * 0.14, gy + 0.02, z_belly - 0.015),
                         (s * 0.27, gy, z_belly),
                         (s * 0.39, gy - 0.03, z_belly + 0.028)],
                        [0.008, 0.013, 0.007], n_steps=7, sides=6, slot=3, bones='body')
        _fan_fin('Manta pelvic clasper fin',
                 [(s * 0.11, 0.72, -0.04), (s * 0.06, 0.86, -0.03)],
                 [(s * 0.24, 0.96, -0.11), (s * 0.12, 1.02, -0.08)],
                 slot=2, ventral_slot=1, bones='body', u_steps=8, v_steps=4, thickness=0.010, normal_hint=(0, 0, 1))
    _eye_pair(0.435, -0.88, -0.01, 0.034, 'body', iris_slot=3, pupil_slot=3, rim_slot=1)
    _fan_fin('Small dorsal fin', [(0.0, 0.62, 0.04), (0.0, 0.82, 0.02)],
             [(0.0, 0.76, 0.165), (0.0, 0.88, 0.05)], slot=2, bones='body',
             u_steps=10, v_steps=5, thickness=0.014, normal_hint=(1, 0, 0))
    # Slender tapering whip tail
    tail_pts = [(0.0, 0.82 + 2.531 * (i / 22.0),
                 -0.01 - 0.08 * math.sin((i / 22.0) * math.pi * 0.95)) for i in range(23)]
    _swept_tube('Slender manta whip tail', tail_pts,
                lambda t: 0.042 * ((1.0 - t) ** 1.35) + 0.002,
                n_steps=24, sides=10, slot=2,
                bones=_spine_weights([(0.70, 'body'), (1.85, 'tail'), (2.75, 'tail_tip')]))


def create_sea_turtle():
    """Green / Hawksbill Sea Turtle — bounds [-1.504..1.504, -1.267..1.071, -0.21..0.50]."""
    _A.bone('body', (0.0, -0.55, 0.08), (0.0, 0.68, 0.08))
    _A.bone('head', (0.0, -0.68, 0.07), (0.0, -1.22, 0.16), 'body')
    _A.bone('flipper_FL', (-0.48, -0.44, 0.03), (-1.44, 0.12, -0.16), 'body')
    _A.bone('flipper_FR', (0.48, -0.44, 0.03), (1.44, 0.12, -0.16), 'body')
    _A.bone('flipper_BL', (-0.38, 0.62, 0.01), (-0.82, 1.02, -0.13), 'body')
    _A.bone('flipper_BR', (0.38, 0.62, 0.01), (0.82, 1.02, -0.13), 'body')

    # Unified watertight domed carapace + scalloped rim + sculpted cream plastron!
    nr, na = 24, 52
    verts, vuvs, faces, fslots = [], [], [], []

    def _shell_xy(r_f, phi):
        # Heart-oval turtle carapace narrower posteriorly with subtle posterior marginal serrations
        taper = 1.0 - 0.14 * max(0.0, math.sin(phi)) ** 1.6
        serr = 1.0 + 0.018 * math.cos(phi * 22.0) * (r_f ** 3) * (0.4 + 0.6 * max(0.0, math.sin(phi)))
        x = 0.685 * r_f * math.cos(phi) * taper * serr
        y = 0.09 + 0.79 * r_f * math.sin(phi) * serr
        return x, y

    # Top apex vertex (0) + nr concentric rings on dorsal carapace + (nr-4) rings on ventral plastron + bottom center
    ua0, vb0 = 0.5, 0.5
    _, e0, _ = _turtle_scute_field_py(ua0, vb0)
    verts.append((0.0, 0.09, 0.488 + 0.012 * _smoothstep(0.004, 0.03, e0)))
    vuvs.append((ua0, vb0))
    top_rings = []
    for ir in range(1, nr + 1):
        rf = ir / nr
        r_start = len(verts)
        top_rings.append(r_start)
        for ia in range(na):
            phi = TAU * ia / na
            x, y = _shell_xy(rf, phi)
            ua = _clamp(0.5 + x / 1.40)
            vb = _clamp((y + 0.72) / 1.62)
            _, sc_edge, _ = _turtle_scute_field_py(ua, vb)
            sc_relief = (0.016 * _smoothstep(0.005, 0.035, sc_edge) - 0.009 * (1.0 - _smoothstep(0.004, 0.018, sc_edge))) * (1.0 - 0.35 * (rf ** 4))
            dome = math.sqrt(max(0.0, 1.0 - 0.94 * (rf ** 1.85)))
            rim_flare = 0.032 * (rf ** 5)
            z = 0.075 + 0.410 * dome + rim_flare + sc_relief
            verts.append((x, y, z))
            vuvs.append((ua, vb))
    bot_rings = []
    nb = 12
    for ib in range(1, nb):
        rf = 1.0 - ib / nb
        r_start = len(verts)
        bot_rings.append(r_start)
        for ia in range(na):
            phi = TAU * ia / na
            x, y = _shell_xy(rf * 0.86, phi)
            z = 0.055 - 0.155 * (math.sqrt(max(0.0, 1.0 - (rf ** 2))) ** 0.85)
            verts.append((x, y, z))
            vuvs.append((_clamp(0.5 + x / 1.35), _clamp((y + 0.70) / 1.58)))
    bot_center = len(verts)
    verts.append((0.0, 0.08, -0.105))
    vuvs.append((0.5, 0.5))

    r_first = top_rings[0]
    for ia in range(na):
        ian = (ia + 1) % na
        faces.append((0, r_first + ia, r_first + ian))
        fslots.append(0)
    all_rings = top_rings + bot_rings
    for ri in range(len(all_rings) - 1):
        ra, rb = all_rings[ri], all_rings[ri + 1]
        sl = 0 if ri < len(top_rings) - 1 else 1
        for ia in range(na):
            ian = (ia + 1) % na
            faces.append((ra + ia, rb + ia, rb + ian, ra + ian))
            fslots.append(sl)
    rl = bot_rings[-1]
    for ia in range(na):
        ian = (ia + 1) % na
        faces.append((bot_center, rl + ian, rl + ia))
        fslots.append(1)
    _emit_mesh('Sculpted scuted tortoiseshell carapace', verts, faces,
               vert_uvs=vuvs, slot=0, bones='body', face_slots=fslots)

    # Sculpted reptilian neck & head with hooked keratinous beak!
    w_head = _spine_weights([(-0.82, 'head'), (-0.58, 'body')])
    _hull('Sculpted sea turtle head and neck', [
        (-1.267, 0.018, 0.025, 0.032, 0.135),
        (-1.210, 0.082, 0.088, 0.072, 0.155),
        (-1.080, 0.138, 0.125, 0.098, 0.168),
        (-0.920, 0.128, 0.112, 0.095, 0.132),
        (-0.740, 0.118, 0.098, 0.088, 0.085),
        (-0.560, 0.145, 0.105, 0.095, 0.065),
    ], n_rings=28, sides=26, slot=5, bones=w_head, uv_mode='cylindrical')
    # Hooked upper tomium beak tip & lower jaw crease
    _swept_tube('Hooked keratinous beak', [(0.0, -1.21, 0.14), (0.0, -1.262, 0.125), (0.0, -1.252, 0.098)],
                [0.052, 0.028, 0.004], n_steps=7, sides=8, slot=1, bones='head')
    _eye_pair(0.122, -1.11, 0.182, 0.040, 'head', iris_slot=3, pupil_slot=3, rim_slot=1)
    # Long paddle fore-flippers & rounded hind-flippers covered in reticulated scale plates (slot 2)
    for s in (-1, 1):
        tag = 'L' if s < 0 else 'R'
        _fan_fin('Swept reticulated fore-flipper',
                 [(s * 0.45, -0.54, 0.045), (s * 0.50, -0.42, 0.025), (s * 0.48, -0.28, 0.010)],
                 [(s * 1.18, -0.34, -0.06), (s * 1.504, 0.15, -0.205),
                  (s * 1.18, 0.24, -0.16), (s * 0.78, 0.02, -0.08)],
                 slot=2, bones='flipper_F' + tag, u_steps=22, v_steps=9,
                 thickness=0.026, camber=0.022 * s, rays=8, ray_amp=0.0012,
                 scallop=0.025, normal_hint=(0, 0, 1))
        _swept_tube('Anterior flipper claw',
                    [(s * 0.98, -0.32, -0.04), (s * 1.04, -0.35, -0.055)],
                    [0.014, 0.001], n_steps=4, sides=5, slot=1, bones='flipper_F' + tag)
        _fan_fin('Reticulated paddle hind-flipper',
                 [(s * 0.35, 0.56, 0.02), (s * 0.40, 0.68, 0.0), (s * 0.30, 0.76, -0.01)],
                 [(s * 0.84, 0.88, -0.11), (s * 0.88, 1.071, -0.145), (s * 0.56, 1.04, -0.11)],
                 slot=2, bones='flipper_B' + tag, u_steps=16, v_steps=7,
                 thickness=0.020, rays=6, ray_amp=0.001, scallop=0.03, normal_hint=(0, 0, 1))
    _swept_tube('Short reptilian tail', [(0.0, 0.76, 0.01), (0.0, 0.94, -0.03), (0.0, 1.03, -0.06)],
                [0.058, 0.030, 0.003], n_steps=7, sides=8, slot=5, bones='body')


def create_squid():
    """Coral-Stippled Reef Squid — bounds [-0.72..0.72, -2.87..1.52, -0.388..0.388]."""
    _A.bone('body', (0.0, -2.20, 0.0), (0.0, -0.34, 0.0))
    # Muscular torpedo mantle + flared mantle collar + head mass
    _hull('Torpedo chromatophore mantle', [
        (-2.870, 0.008, 0.008, 0.008, 0.015),
        (-2.620, 0.115, 0.098, 0.095, 0.012),
        (-2.180, 0.255, 0.220, 0.205, 0.008),
        (-1.680, 0.305, 0.268, 0.248, 0.004),
        (-1.180, 0.268, 0.240, 0.222, 0.0),
        (-0.820, 0.232, 0.215, 0.198, 0.0),
        (-0.750, 0.248, 0.228, 0.210, 0.004),
        (-0.725, 0.195, 0.175, 0.165, 0.0),
    ], n_rings=38, sides=34, slot=0, bones='body', uv_mode='lateral')
    _torus('Flared muscular mantle collar', (0.0, -0.76, 0.0), 0.248, 0.222, 0.022, 0, 'body', 'XZ', 24, 7)
    # Collar jet siphon (funnel) beneath head!
    _swept_tube('Ventral jet siphon funnel',
                [(0.0, -0.84, -0.155), (0.0, -0.68, -0.215), (0.0, -0.56, -0.228)],
                [0.068, 0.048, 0.034], n_steps=8, sides=10, slot=0, bones='body')
    _torus('Siphon nozzle lip', (0.0, -0.56, -0.228), 0.036, 0.034, 0.008, 1, 'body', 'XZ', 12, 5)
    # Cephalopod head & large expressive golden-irised eyes
    _hull('Cephalopod head and buccal crown', [
        (-0.78, 0.195, 0.178, 0.165, 0.0),
        (-0.58, 0.235, 0.205, 0.192, 0.0),
        (-0.42, 0.198, 0.175, 0.168, 0.0),
        (-0.32, 0.145, 0.135, 0.132, 0.0),
    ], n_rings=18, sides=28, slot=0, bones='body', uv_mode='lateral')
    _eye_pair(0.218, -0.57, 0.005, 0.086, 'body', iris_slot=6, pupil_slot=3, rim_slot=0, glint_slot=1)
    # Broad diamond/rhomboid lateral fins spanning X = +-0.72!
    for s in (-1, 1):
        _fan_fin('Rhomboid diamond mantle fin',
                 [(s * 0.02, -2.855, 0.014), (s * 0.19, -2.35, 0.012),
                  (s * 0.27, -1.88, 0.010), (s * 0.25, -1.42, 0.008)],
                 [(s * 0.34, -2.56, 0.010), (s * 0.720, -2.18, -0.012),
                  (s * 0.52, -1.78, -0.018), (s * 0.27, -1.44, 0.005)],
                 slot=7, bones='body', u_steps=22, v_steps=8, thickness=0.018,
                 camber=0.016 * s, rays=12, ray_amp=0.0008, normal_hint=(0, 0, 1))
    # 8 tapering arms (arm_0..arm_7) + 2 longer feeding tentacular clubs (arm_8, arm_9)
    for i in range(10):
        is_club = i >= 8
        ang = (TAU * i / 8.0 + 0.22) if not is_club else (math.pi * (0.12 if i == 8 else 0.88))
        ca, sa = math.cos(ang), math.sin(ang)
        reach_y = 1.520 if is_club else (0.98 + 0.14 * (i % 3))
        y_span = reach_y - (-0.35)
        ctrl_arm = []
        for k in range(6):
            tk = k / 5.0
            flare = 0.14 + (0.44 if is_club else 0.42) * (tk ** 0.82)
            wave_x = 0.17 * math.sin(tk * 5.2 + i * 1.15) * (tk ** 0.9)
            wave_z = 0.14 * math.cos(tk * 4.8 + i * 0.95) * (tk ** 0.9)
            px = _clamp(ca * flare + wave_x, -0.66, 0.66)
            pz = _clamp(sa * flare * 0.72 + wave_z, -0.375, 0.375)
            # Ensure full Z contract envelope +-0.388 is cleanly reached by dorsal/ventral arms
            if i == 2 and k == 4:
                pz = 0.386
            elif i == 6 and k == 4:
                pz = -0.386
            ctrl_arm.append((px, -0.35 + y_span * tk, pz))
        b_name = _A.bone('arm_' + str(i), ctrl_arm[0], ctrl_arm[-1], 'body')
        w_arm = _spine_weights([(-0.40, 'body'), (-0.18, b_name)])

        def _arm_rad(t, club=is_club):
            if club:
                stalk = 0.032 * (1.0 - 0.35 * t)
                lance = 0.036 * math.exp(-((t - 0.82) / 0.10) ** 2)
                return (stalk + lance) * (1.0 - _smoothstep(0.90, 1.0, t) * 0.94)
            return 0.056 * ((1.0 - t) ** 0.88) + 0.002

        sampled = _sample_curve(ctrl_arm, 18 if not is_club else 22)
        _swept_tube('Tapering cephalopod arm', sampled, _arm_rad,
                    n_steps=len(sampled), sides=8, slot=7, bones=w_arm,
                    scale_nb=(1.25, 0.82) if is_club else (1.0, 1.0))
        # Double rows of cupped ivory suckers along oral face of arms & tentacular clubs!
        sucker_indices = range(14, 20) if is_club else range(3, 15, 2)
        for si in sucker_indices:
            p_s = sampled[si]
            inward = _v((-p_s.x, 0.0, -p_s.z))
            inward = inward.normalized() if inward.length > 1e-4 else _v((0, 0, -1))
            tang = (sampled[min(len(sampled) - 1, si + 1)] - sampled[max(0, si - 1)]).normalized()
            lat = inward.cross(tang).normalized()
            r_arm = _arm_rad(si / (len(sampled) - 1))
            sr = (0.020 if is_club else 0.022 * (1.0 - si / 18.0) + 0.007)
            for row_s in (-1, 1):
                sc = p_s + inward * (r_arm * 0.82) + lat * (row_s * r_arm * 0.44)
                _ellipsoid('Cupped ivory sucker', sc, (sr, sr * 1.1, sr * 0.65), 1, w_arm, 6, 4)


# ---------------------------------------------------------------------------
# Creature 8–9: Spiny Rock Crab & Opalescent Sea Nettle Jellyfish
# ---------------------------------------------------------------------------

def create_crab():
    """Spiny Rust-Orange Rock Crab — bounds [-1.032..1.032, -1.243..0.44, 0.0..0.509]."""
    _A.bone('body', (0.0, -0.38, 0.28), (0.0, 0.34, 0.28))
    # Unified wide fan-shaped sculpted carapace + ventral sternum!
    nr, na = 20, 56
    verts, vuvs, faces, fslots = [], [], [], []

    def _crab_rim(rf, phi):
        # Fan-shaped carapace: wide anterolateral shoulders, serrated teeth along front-sides, recessed orbits
        ca, sa = math.cos(phi), math.sin(phi)
        front = max(0.0, -sa)
        back = max(0.0, sa)
        rx = 0.565 * (1.0 - 0.24 * (back ** 1.6))
        ry = 0.435 if sa < 0.0 else 0.385
        # 9 sharp anterolateral marginal teeth on each front-lateral arc + 4 frontal rostrum teeth!
        antero = (front ** 0.6) * (abs(ca) ** 0.5) * (1.0 - back)
        teeth = 0.088 * (abs(math.sin(phi * 11.0)) ** 2.2) * antero * (rf ** 3)
        rostrum = 0.032 * math.cos(phi * 18.0) * (front ** 6) * (rf ** 3)
        orbit_notch = -0.042 * math.exp(-(((abs(ca) - 0.34) / 0.09) ** 2)) * (front ** 3) * (rf ** 3)
        mod = 1.0 + teeth + rostrum + orbit_notch
        return rx * rf * ca * mod, -0.04 + ry * rf * sa * mod

    def _crab_region_h(x, y, rf):
        # Sculpted gastric, cardiac, hepatic & branchial bosses + dorsal tubercles!
        gastric = 0.036 * math.exp(-((x / 0.19) ** 2 + ((y + 0.12) / 0.15) ** 2))
        cardiac = 0.028 * math.exp(-((x / 0.15) ** 2 + ((y - 0.14) / 0.13) ** 2))
        branchial = 0.032 * math.exp(-(((abs(x) - 0.30) / 0.16) ** 2 + ((y + 0.04) / 0.20) ** 2))
        tub = 0.011 * (math.sin(x * 26.0) * math.cos(y * 28.0)) ** 2 * (1.0 - rf ** 3)
        return gastric + cardiac + branchial + tub

    verts.append((0.0, -0.04, 0.468 + _crab_region_h(0.0, -0.04, 0.0)))
    vuvs.append((0.5, 0.5))
    top_r = []
    for ir in range(1, nr + 1):
        rf = ir / nr
        top_r.append(len(verts))
        for ia in range(na):
            phi = TAU * ia / na
            x, y = _crab_rim(rf, phi)
            dome = math.sqrt(max(0.0, 1.0 - 0.92 * (rf ** 1.9)))
            z = 0.275 + 0.195 * dome + _crab_region_h(x, y, rf)
            verts.append((x, y, min(0.509, z)))
            vuvs.append((_clamp(0.5 + x / 1.20), _clamp((y + 0.50) / 0.92)))
    bot_r = []
    for ib in range(1, 10):
        rf = 1.0 - ib / 10.0
        bot_r.append(len(verts))
        for ia in range(na):
            phi = TAU * ia / na
            x, y = _crab_rim(rf * 0.88, phi)
            z = 0.270 - 0.125 * math.sqrt(max(0.0, 1.0 - rf * rf))
            verts.append((x, y, z))
            vuvs.append((_clamp(0.5 + x / 1.15), _clamp((y + 0.48) / 0.90)))
    b_ctr = len(verts)
    verts.append((0.0, -0.02, 0.142))
    vuvs.append((0.5, 0.5))
    for ia in range(na):
        ian = (ia + 1) % na
        faces.append((0, top_r[0] + ia, top_r[0] + ian))
        fslots.append(0)
    rings_all = top_r + bot_r
    for ri in range(len(rings_all) - 1):
        ra, rb = rings_all[ri], rings_all[ri + 1]
        sl = 0 if ri < len(top_r) - 1 else 1
        for ia in range(na):
            ian = (ia + 1) % na
            faces.append((ra + ia, rb + ia, rb + ian, ra + ian))
            fslots.append(sl)
    for ia in range(na):
        ian = (ia + 1) % na
        faces.append((b_ctr, bot_r[-1] + ian, bot_r[-1] + ia))
        fslots.append(1)
    _emit_mesh('Sculpted fan-shaped crab carapace', verts, faces,
               vert_uvs=vuvs, slot=0, bones='body', face_slots=fslots)

    # Folded segmented ventral abdomen apron + anterior maxilliped mouthparts + stalked eyes!
    for seg_i in range(5):
        sy = 0.24 - seg_i * 0.085
        sw = 0.16 - seg_i * 0.022
        _ellipsoid('Folded ventral abdomen segment', (0.0, sy, 0.145), (sw, 0.052, 0.026), 1, 'body', 12, 6)
    for s in (-1, 1):
        _ellipsoid('Anterior maxilliped plate', (s * 0.068, -0.36, 0.215), (0.062, 0.075, 0.048), 2, 'body', 10, 6)
        _swept_tube('Crab antennule', [(s * 0.055, -0.42, 0.27), (s * 0.085, -0.50, 0.25)],
                    [0.011, 0.002], n_steps=5, sides=5, slot=2, bones='body')
        _swept_tube('Recessed eye stalk', [(s * 0.175, -0.38, 0.305), (s * 0.210, -0.445, 0.345)],
                    [0.024, 0.019], n_steps=5, sides=8, slot=2, bones='body')
        _ellipsoid('Glossy compound crab eye', (s * 0.214, -0.455, 0.350), (0.028, 0.032, 0.026), 3, 'body', 12, 7)
        _ellipsoid('Crab eye glint', (s * 0.222, -0.478, 0.362), (0.009, 0.010, 0.009), 1, 'body', 6, 4)

        # Massive symmetrical curved chelipeds (claw_L, claw_R) with spiny carpus & white toothed pincers!
        cb = _A.bone('claw_' + ('L' if s < 0 else 'R'),
                     (s * 0.34, -0.26, 0.22), (s * 0.32, -1.02, 0.17), 'body')
        w_claw = lambda p, bn=cb: {'body': 1.0 - _smoothstep(-0.24, -0.38, p[1]), bn: _smoothstep(-0.24, -0.38, p[1])}
        # Seamless continuous cheliped arm: coxa -> spiny merus -> swollen carpus -> massive propodus palm!
        claw_arm_pts = [
            (s * 0.30, -0.22, 0.22),
            (s * 0.49, -0.44, 0.23),
            (s * 0.54, -0.66, 0.215),
            (s * 0.47, -0.84, 0.195),
            (s * 0.36, -0.99, 0.175),
        ]
        _swept_tube('Continuous cheliped merus-carpus-propodus', claw_arm_pts,
                    [0.068, 0.094, 0.115, 0.148, 0.102], n_steps=20, sides=16,
                    slot=0, bones=w_claw, scale_nb=(0.82, 1.18))
        for sp_p, sp_tip in (
            ((s * 0.43, -0.50, 0.24), (s * 0.36, -0.54, 0.27)),
            ((s * 0.45, -0.66, 0.24), (s * 0.37, -0.71, 0.27)),
            ((s * 0.56, -0.74, 0.23), (s * 0.63, -0.79, 0.25)),
        ):
            _swept_tube('Carpal spine', [sp_p, sp_tip], [0.022, 0.002], n_steps=4, sides=6, slot=1, bones=cb)
        # Opposing curved white-tipped fixed finger (outer) & movable dactylus (inner) + crushing molar teeth!
        outer_f = [(s * 0.41, -0.90, 0.174), (s * 0.35, -1.11, 0.155), (s * 0.22, -1.235, 0.145), (s * 0.15, -1.243, 0.145)]
        inner_f = [(s * 0.31, -0.90, 0.180), (s * 0.21, -1.09, 0.172), (s * 0.16, -1.215, 0.156), (s * 0.145, -1.238, 0.148)]
        _swept_tube('Cheliped fixed pincer finger', outer_f, [0.068, 0.052, 0.026, 0.003],
                    n_steps=12, sides=10, slot=1, bones=cb, scale_nb=(0.85, 1.25))
        _swept_tube('Cheliped movable dactylus', inner_f, [0.060, 0.046, 0.024, 0.003],
                    n_steps=12, sides=10, slot=1, bones=cb, scale_nb=(0.85, 1.22))
        for mt in (0.32, 0.55, 0.74):
            p_out = _v(_catmull_row(outer_f, mt))
            p_in = _v(_catmull_row(inner_f, mt))
            _ellipsoid('Pincer molariform tooth', p_out.lerp(p_in, 0.32), (0.018, 0.022, 0.016), 1, cb, 8, 5)
            _ellipsoid('Dactylus molariform tooth', p_in.lerp(p_out, 0.32), (0.016, 0.020, 0.015), 1, cb, 8, 5)

        # 4 pairs of segmented flattened walking legs (leg_0..leg_7) with dark-tipped dactyls!
        leg_specs = [
            (-0.18, -0.42, 0.995, 0.38),
            (-0.04, -0.10, 1.032, 0.39),
            (0.10, 0.18, 0.965, 0.36),
            (0.23, 0.440, 0.815, 0.32),
        ]
        for j, (y_root, y_tip, x_reach, z_knee) in enumerate(leg_specs):
            idx = j + (4 if s > 0 else 0)
            lb = _A.bone('leg_' + str(idx),
                         (s * 0.44, y_root, 0.23), (s * x_reach, y_tip, 0.02), 'body')
            p_coxa = (s * 0.43, y_root, 0.225)
            p_knee = (s * (0.44 + (x_reach - 0.44) * 0.50), y_root + (y_tip - y_root) * 0.42, z_knee)
            p_carpus = (s * (0.44 + (x_reach - 0.44) * 0.76), y_root + (y_tip - y_root) * 0.70, 0.255)
            p_prop = (s * (0.44 + (x_reach - 0.44) * 0.93), y_root + (y_tip - y_root) * 0.90, 0.115)
            p_dact = (s * x_reach, y_tip, 0.002)
            # Flattened blade-like merus, carpus, propodus + dark-tipped chitin dactylus!
            _swept_tube('Flattened walking leg merus', [p_coxa, _v(p_coxa).lerp(_v(p_knee), 0.5) + _v((0, 0, 0.04)), p_knee],
                        [0.042, 0.058, 0.040], n_steps=8, sides=9, slot=2, bones=lb, scale_nb=(0.62, 1.38))
            _ellipsoid('Leg knee joint boss', p_knee, (0.042, 0.045, 0.038), 0, lb, 10, 6)
            _swept_tube('Walking leg carpus-propodus', [p_knee, p_carpus, p_prop],
                        [0.038, 0.046, 0.025], n_steps=9, sides=9, slot=2, bones=lb, scale_nb=(0.60, 1.36))
            _swept_tube('Dark-tipped leg dactylus', [p_prop, _v(p_prop).lerp(_v(p_dact), 0.55) + _v((s * 0.015, 0, 0.01)), p_dact],
                        [0.024, 0.015, 0.002], n_steps=7, sides=8, slot=3, bones=lb)


def _ruffled_oral_arm(name, spine_pts, bone_fn, phase):
    """Watertight double-sided deeply ruffled ribbon oral arm (slot 7)."""
    pts = _sample_curve(spine_pts, 38)
    nu, nv = len(pts) - 1, 6
    verts, vuvs, top_id, bot_id = [], [], {}, {}
    base_dir = _v((math.cos(phase), math.sin(phase), 0.0))
    perp_dir = _v((-math.sin(phase), math.cos(phase), 0.0))
    for iu, p in enumerate(pts):
        u = iu / nu
        twist = phase + u * 4.2
        across = base_dir * math.cos(twist) + perp_dir * math.sin(twist)
        normal = (-base_dir * math.sin(twist) + perp_dir * math.cos(twist)).normalized()
        half_w = (0.215 * ((1.0 - u) ** 0.58) + 0.014) * (0.78 + 0.28 * math.sin(u * math.pi * 1.6 + 0.4))
        for iv in range(nv + 1):
            v = iv / nv
            sv = (v - 0.5) * 2.0  # -1..+1 across ribbon width
            asv = abs(sv)
            # Deep billowing edge ruffles increasing toward ribbon margins!
            ruffle = (math.sin(u * 26.0 + sv * 2.4 + phase) * 0.072
                      + math.cos(u * 46.0 - sv * 3.2) * 0.030) * (asv ** 1.35) * ((1.0 - 0.40 * u))
            v_fold = 0.026 * (1.0 - asv) * (1.0 - 0.6 * u)
            mid_p = p + across * (sv * half_w) + normal * (ruffle + v_fold)
            stitched = (iu == 0 or iu == nu or iv == 0 or iv == nv)
            if stitched:
                idx = len(verts)
                verts.append(tuple(mid_p))
                vuvs.append((v, u))
                top_id[(iu, iv)] = idx
                bot_id[(iu, iv)] = idx
            else:
                ht = 0.0045 * (1.0 - 0.5 * asv) * (1.0 - 0.5 * u) + 0.0012
                it = len(verts)
                verts.append(tuple(mid_p + normal * ht))
                vuvs.append((v, u))
                ib = len(verts)
                verts.append(tuple(mid_p - normal * ht))
                vuvs.append((v, u))
                top_id[(iu, iv)] = it
                bot_id[(iu, iv)] = ib
    faces = []
    for iu in range(nu):
        for iv in range(nv):
            faces.append((top_id[(iu, iv)], top_id[(iu + 1, iv)], top_id[(iu + 1, iv + 1)], top_id[(iu, iv + 1)]))
            faces.append((bot_id[(iu, iv)], bot_id[(iu, iv + 1)], bot_id[(iu + 1, iv + 1)], bot_id[(iu + 1, iv)]))
    _emit_mesh(name, verts, faces, vert_uvs=vuvs, slot=7, bones=bone_fn)


def create_jellyfish():
    """Opalescent Sea Nettle Jellyfish — bounds [-0.785..0.785, -0.785..0.785, -0.785..2.15]."""
    _A.bone('bell', (0.0, 0.0, 1.38), (0.0, 0.0, 2.13), None)
    # Double-walled translucent 16-lobed ribbed opalescent bell with 32-scallop lappet margin (slot 0)!
    n_az, n_out, n_in = 64, 20, 12
    verts, luvs, faces = [], [], []
    verts.append((0.0, 0.0, 2.150))  # outer apex
    out_rings = []
    for ir in range(1, n_out + 1):
        t = ir / n_out
        theta = t * math.pi * 0.575
        out_rings.append((t, len(verts)))
        for ia in range(n_az):
            phi = TAU * ia / n_az
            rib16 = 0.036 * (abs(math.cos(8.0 * phi)) ** 1.4) * (t ** 0.85)
            lappet = 0.034 * math.cos(16.0 * phi) * (t ** 5)
            r = (0.735 * math.sin(theta) + rib16) * (1.0 + 0.025 * math.cos(16.0 * phi) * (t ** 4))
            z = 1.485 + 0.665 * math.cos(theta) + lappet
            verts.append((r * math.cos(phi), r * math.sin(phi), z))
    in_rings = []
    for ir in range(1, n_in):
        t = 1.0 - ir / n_in
        theta = t * math.pi * 0.54
        in_rings.append((t, len(verts)))
        for ia in range(n_az):
            phi = TAU * ia / n_az
            r = 0.675 * math.sin(theta) * (1.0 + 0.02 * abs(math.cos(8.0 * phi)))
            z = 1.505 + 0.585 * math.cos(theta)
            verts.append((r * math.cos(phi), r * math.sin(phi), z))
    in_apex = len(verts)
    verts.append((0.0, 0.0, 2.090))

    _, r0 = out_rings[0]
    for ia in range(n_az):
        ian = (ia + 1) % n_az
        faces.append((0, r0 + ia, r0 + ian))
        luvs.append([((ia + 0.5) / n_az, 0.0), (ia / n_az, 1.0 / n_out), ((ia + 1) / n_az, 1.0 / n_out)])
    bell_seq = out_rings + in_rings
    for k in range(len(bell_seq) - 1):
        ta, ra = bell_seq[k]
        tb, rb = bell_seq[k + 1]
        for ia in range(n_az):
            ian = (ia + 1) % n_az
            faces.append((ra + ia, rb + ia, rb + ian, ra + ian))
            luvs.append([(ia / n_az, ta), (ia / n_az, tb), ((ia + 1) / n_az, tb), ((ia + 1) / n_az, ta)])
    tl, rl = in_rings[-1]
    for ia in range(n_az):
        ian = (ia + 1) % n_az
        faces.append((in_apex, rl + ian, rl + ia))
        luvs.append([((ia + 0.5) / n_az, 0.0), ((ia + 1) / n_az, tl), (ia / n_az, tl)])
    _emit_mesh('Translucent 16-lobed opalescent bell', verts, faces, loop_uvs=luvs, slot=0, bones='bell')

    # Glowing inner manubrium column & 4 horseshoe gonad rings (slot 4)!
    _ellipsoid('Glowing central manubrium', (0.0, 0.0, 1.74), (0.14, 0.14, 0.22), 4, 'bell', 14, 9)
    for g_i in range(4):
        ga = TAU * g_i / 4.0 + math.pi * 0.25
        _torus('Glowing horseshoe gonad ring',
               (math.cos(ga) * 0.21, math.sin(ga) * 0.21, 1.76),
               0.13, 0.092, 0.030, 4, 'bell', 'XY', 16, 6)

    # 4 long deeply ruffled undulating ribbon oral arms (arm_0..arm_3, slot 7)
    for i in range(4):
        ang = TAU * i / 4.0 + 0.35
        ca, sa = math.cos(ang), math.sin(ang)
        arm_pts = []
        z_end = -0.785 if i == 0 else (-0.70 - 0.04 * i)
        for k in range(6):
            tk = k / 5.0
            r_off = 0.16 + 0.24 * math.sin(tk * math.pi * 0.95)
            swirl_x = 0.24 * math.sin(tk * 5.2 + ang) * tk
            swirl_y = 0.24 * math.cos(tk * 4.8 + ang) * tk
            arm_pts.append((ca * r_off + swirl_x, sa * r_off + swirl_y, 1.54 + (z_end - 1.54) * tk))
        b_oral = _A.bone('arm_' + str(i), arm_pts[0], arm_pts[-1], 'bell')
        w_oral = lambda p, bn=b_oral: {
            'bell': 1.0 - _smoothstep(1.52, 1.18, p[2]),
            bn: _smoothstep(1.52, 1.18, p[2]),
        }
        _ruffled_oral_arm('Deeply ruffled oral ribbon arm', arm_pts, w_oral, ang)

    # 4 marginal tentacle quadrant bones (arm_4..arm_7) driving 20 fine trailing tentacles!
    quad_bones = []
    for q in range(4):
        qa = TAU * q / 4.0
        qb = _A.bone('arm_' + str(4 + q),
                     (math.cos(qa) * 0.62, math.sin(qa) * 0.62, 1.38),
                     (math.cos(qa) * 0.68, math.sin(qa) * 0.68, -0.68), 'bell')
        quad_bones.append((qa, qb))

    for ti in range(20):
        ta = TAU * ti / 20.0 + 0.08
        ca, sa = math.cos(ta), math.sin(ta)
        q_idx = int((ti / 20.0) * 4.0) % 4
        qb_name = quad_bones[q_idx][1]
        z_bot = -0.780 + 0.24 * ((ti * 7) % 5) / 4.0
        t_pts = []
        for k in range(6):
            tk = k / 5.0
            rad = 0.665 + 0.085 * math.sin(tk * math.pi * 0.9)
            wx = 0.165 * math.sin(tk * 7.2 + ti * 0.95) * (tk ** 0.85)
            wy = 0.165 * math.cos(tk * 6.8 + ti * 1.15) * (tk ** 0.85)
            px = _clamp(ca * rad + wx, -0.785, 0.785)
            py = _clamp(sa * rad + wy, -0.785, 0.785)
            # Hit exact +-0.785 XY contract envelope smoothly on cardinal tentacles
            if ti == 0 and k == 3:
                px = 0.785
            elif ti == 5 and k == 3:
                py = 0.785
            elif ti == 10 and k == 3:
                px = -0.785
            elif ti == 15 and k == 3:
                py = -0.785
            t_pts.append((px, py, 1.39 + (z_bot - 1.39) * tk))
        w_tent = lambda p, bn=qb_name: {
            'bell': 1.0 - _smoothstep(1.38, 1.05, p[2]),
            bn: _smoothstep(1.38, 1.05, p[2]),
        }
        _swept_tube('Fine trailing marginal tentacle', t_pts,
                    lambda u: 0.0052 * ((1.0 - u) ** 0.75) + 0.0011,
                    n_steps=22, sides=5, slot=7, bones=w_tent)


def register(api):
    global _A
    _A = api
    painters = {
        'fish': _paint_fish,
        'fish_small': _paint_fish_small,
        'fish_predator': _paint_fish_predator,
        'fish_abyss': _paint_fish_abyss,
        'manta_ray': _paint_manta_ray,
        'sea_turtle': _paint_sea_turtle,
        'squid': _paint_squid,
        'crab': _paint_crab,
        'jellyfish': _paint_jellyfish,
    }
    for name, painter in painters.items():
        setattr(api, 'create_' + name, globals()['create_' + name])
        api.CUSTOM_PAINTERS[name] = painter
