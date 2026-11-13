"""Image-directed marine instruments, habitats, wrecks, and resources for the v3 ocean kit.

Concept reference: assets/source/art-v3/concepts/equipment.png.
All 9 assets are authored directly in Blender 3D geometry with PBR atlases and
transparent glass portals (glass=True, slot=7) revealing modeled 3D interiors.
"""
import math
import numpy as np
from mathutils import Matrix, Vector

TAU = math.tau


def _frame_basis(axis):
    w = Vector(axis).normalized()
    ref = Vector((0.0, 0.0, 1.0)) if abs(w.z) < 0.92 else Vector((1.0, 0.0, 0.0))
    u = ref.cross(w).normalized()
    v = w.cross(u).normalized()
    return u, v, w


def _sweep(api, name, points, radii, slot=0, sides=12, cap=True, closed=False,
           smooth=True, glass=False, face_slots_fn=None):
    pts = [Vector(p) for p in points]
    count = len(pts)
    tangents = []
    for i in range(count):
        p_prev = pts[(i - 1) % count] if closed else pts[max(0, i - 1)]
        p_next = pts[(i + 1) % count] if closed else pts[min(count - 1, i + 1)]
        d = p_next - p_prev
        tangents.append(d.normalized() if d.length > 1e-6 else Vector((0.0, 0.0, 1.0)))
    n0, b0, _ = _frame_basis(tangents[0])
    frames = [(n0, b0)]
    for i in range(1, count):
        prev_n, _ = frames[-1]
        t = tangents[i]
        n = prev_n - t * prev_n.dot(t)
        if n.length < 1e-5:
            n, _, _ = _frame_basis(t)
        else:
            n.normalize()
        b = t.cross(n).normalized()
        frames.append((n, b))
    verts, uv, faces, fslots = [], [], [], []
    const_pair = isinstance(radii, tuple) and len(radii) == 2 and isinstance(radii[0], (int, float))
    for i, p in enumerate(pts):
        if isinstance(radii, (int, float)):
            rx, ry = radii, radii
        elif const_pair:
            rx, ry = radii
        else:
            r = radii[i]
            rx, ry = (r[0], r[1]) if isinstance(r, (list, tuple)) else (r, r)
        n, b = frames[i]
        v_coord = i / max(1, count - (0 if closed else 1))
        for j in range(sides + 1):
            ang = TAU * j / sides
            verts.append(tuple(p + n * (rx * math.cos(ang)) + b * (ry * math.sin(ang))))
            uv.append((j / sides, v_coord))
    rings = count if closed else count - 1
    for i in range(rings):
        i_next = (i + 1) % count
        for j in range(sides):
            a = i * (sides + 1) + j
            c = i_next * (sides + 1) + j
            faces.append((a, c, c + 1, a + 1))
            fslots.append(face_slots_fn(i, j) if face_slots_fn else slot)
    if cap and not closed:
        c0 = len(verts)
        verts.append(tuple(pts[0]))
        uv.append((0.5, 0.0))
        c1 = len(verts)
        verts.append(tuple(pts[-1]))
        uv.append((0.5, 1.0))
        for j in range(sides):
            faces.append((c0, j + 1, j))
            fslots.append(face_slots_fn(0, j) if face_slots_fn else slot)
            base = (count - 1) * (sides + 1)
            faces.append((c1, base + j, base + j + 1))
            fslots.append(face_slots_fn(count - 2, j) if face_slots_fn else slot)
    return api.mesh(name, verts, faces, uv, slot,
                    face_slots=fslots if face_slots_fn else None,
                    smooth=smooth, glass=glass)


def _revolve(api, name, origin, axis, profile_rh, slot=0, segs=32, smooth=True,
             glass=False, planar_uv=False, face_slots_fn=None):
    origin = Vector(origin)
    u_ax, v_ax, w_ax = _frame_basis(axis)
    verts, uv, faces, fslots = [], [], [], []
    max_r = max(max(r for r, _ in profile_rh), 1e-4)
    n_prof = len(profile_rh)
    for i, (r, h) in enumerate(profile_rh):
        for j in range(segs + 1):
            ang = TAU * j / segs
            ca, sa = math.cos(ang), math.sin(ang)
            pt = origin + w_ax * h + (u_ax * ca + v_ax * sa) * r
            verts.append(tuple(pt))
            if planar_uv:
                uv.append((0.5 + 0.48 * (r / max_r) * ca, 0.5 + 0.48 * (r / max_r) * sa))
            else:
                uv.append((j / segs, i / max(1, n_prof - 1)))
    for i in range(n_prof - 1):
        for j in range(segs):
            a = i * (segs + 1) + j
            faces.append((a, a + 1, a + segs + 2, a + segs + 1))
            fslots.append(face_slots_fn(i, j) if face_slots_fn else slot)
    return api.mesh(name, verts, faces, uv, slot,
                    face_slots=fslots if face_slots_fn else None,
                    smooth=smooth, glass=glass)


def _coral_cluster(api, name, root, scale=1.0, branches=5, slot=5, tip_slot=None):
    root = Vector(root)
    for idx in range(branches):
        ang = idx * TAU / branches + 0.37 * math.sin(idx * 2.1)
        lean = (0.20 + 0.08 * (idx % 3)) * scale
        h = (0.34 + 0.11 * ((idx * 2) % 3)) * scale
        p0 = root
        p1 = root + Vector((math.cos(ang) * lean * 0.45, math.sin(ang) * lean * 0.45, h * 0.42))
        p2 = root + Vector((math.cos(ang + 0.18) * lean, math.sin(ang + 0.18) * lean, h))
        _sweep(api, name, [p0, p1, p2], [0.036 * scale, 0.025 * scale, 0.015 * scale], slot, sides=7)
        api.ellipsoid(name + '_tip', p2, (0.020 * scale, 0.020 * scale, 0.024 * scale),
                      tip_slot if tip_slot is not None else slot, segments=8, rings=5)
        for side in (-1, 1):
            fang = ang + side * 0.68
            f0 = p1.lerp(p2, 0.38)
            f1 = f0 + Vector((math.cos(fang) * 0.13 * scale, math.sin(fang) * 0.13 * scale, 0.11 * scale))
            f2 = f0 + Vector((math.cos(fang + side * 0.2) * 0.21 * scale,
                              math.sin(fang + side * 0.2) * 0.21 * scale, 0.22 * scale))
            _sweep(api, name + '_fork', [f0, f1, f2], [0.021 * scale, 0.015 * scale, 0.010 * scale], slot, sides=6)
            api.ellipsoid(name + '_bud', f2, (0.015 * scale, 0.015 * scale, 0.018 * scale),
                          tip_slot if tip_slot is not None else slot, segments=7, rings=4)


def _barnacle(api, center, normal_dir, radius=0.075, height=0.065):
    prof = [(radius, 0.0), (radius * 0.86, height * 0.55), (radius * 0.52, height),
            (radius * 0.34, height * 0.92), (0.0, height * 0.45)]
    _revolve(api, 'Barnacle cone', center, normal_dir, prof, slot=1, segs=9,
             face_slots_fn=lambda i, _j: 3 if i >= 2 else 1)


def _braided_lanyard(api, anchor, end_pt, sag_vec, radius=0.0042, slot=5):
    anchor, end_pt, sag_vec = Vector(anchor), Vector(end_pt), Vector(sag_vec)
    knot = anchor.lerp(end_pt, 0.72) + sag_vec * 0.82
    for side in (-1, 1):
        pts = []
        for i in range(13):
            t = i / 12.0
            base = anchor.lerp(knot, t) + sag_vec * math.sin(math.pi * t) * 0.55
            braid = Vector((side * math.cos(t * TAU * 2.5) * radius * 0.85,
                            math.sin(t * TAU * 2.5) * radius * 0.45,
                            side * math.sin(t * TAU * 2.5) * radius * 0.65)) * math.sin(math.pi * t)
            pts.append(base + braid)
        _sweep(api, 'Braided lanyard strand', pts, radius, slot, sides=8)
    for k in range(3):
        off = (end_pt - anchor).normalized() * ((k - 1) * radius * 1.45)
        api.ellipsoid('Lanyard turks-head knot', knot + off,
                      (radius * 2.1, radius * 1.65, radius * 2.0), slot, segments=12, rings=7)
    for side in (-1, 1):
        t0 = knot
        t1 = knot.lerp(end_pt, 0.55) + Vector((side * radius * 1.6, 0.0, -radius * 0.8))
        t2 = end_pt + Vector((side * radius * 2.1, 0.0, side * radius * 0.6))
        _sweep(api, 'Lanyard tassel', [t0, t1, t2], [radius * 1.05, radius * 1.25, radius * 0.55], slot, sides=8)


def _install_painters(api):
    def _tile(slot, size=1024):
        w, h = size // 4, size // 2
        r, c = slot // 4, slot % 4
        return (slice(r * h, (r + 1) * h), slice(c * w, (c + 1) * w)), w, h

    def paint_pod(albedo, normal, orm, emission):
        # Slot 1: subtle plush diamond-quilted upholstery relief for cabin chair & cream trim
        reg1, w, h = _tile(1)
        y, x = np.mgrid[0:h, 0:w].astype(np.float32)
        u, v = x / w, y / h
        quilt = np.abs(np.sin((u + v) * TAU * 4.0)) * np.abs(np.sin((u - v) * TAU * 4.0))
        albedo[reg1][:, :, :3] = np.clip(albedo[reg1][:, :, :3] * (0.94 + 0.08 * quilt[:, :, None]), 0.0, 1.0)
        normal[reg1][:, :, :3] = api.height_to_normal(quilt * 0.055, 2.4)
        # Slot 4: warm golden incandescent cabin lamp glow
        reg4, _, _ = _tile(4)
        warm = np.array([1.0, 0.82, 0.46], dtype=np.float32)[None, None, :]
        grad = (0.78 + 0.22 * np.sin(v * math.pi))[:, :, None]
        albedo[reg4][:, :, :3] = np.clip(warm * grad, 0.0, 1.0)
        emission[reg4][:, :, :3] = warm * grad * 0.92
        orm[reg4][:, :, 1] = 0.24
        # Slot 7: crystal-clear marine observation glass so the warm cabin reads vividly
        reg7, _, _ = _tile(7)
        edge = np.maximum(np.abs(u - 0.5), np.abs(v - 0.5)) * 2.0
        albedo[reg7][:, :, :3] = np.array([0.42, 0.72, 0.78], dtype=np.float32)[None, None, :]
        albedo[reg7][:, :, 3] = np.clip(0.18 + 0.14 * (edge ** 2.2), 0.16, 0.34)
        orm[reg7][:, :, 1] = 0.05
        orm[reg7][:, :, 2] = 0.05

    def paint_shipwreck(albedo, normal, orm, emission):
        # Slot 5: vibrant pink-coral polyps with creamy-peach tips (no rust bleed)
        reg5, w, h = _tile(5)
        y, x = np.mgrid[0:h, 0:w].astype(np.float32)
        u, v = x / w, y / h
        base_coral = np.array([0.87, 0.41, 0.38], dtype=np.float32)[None, None, :]
        tip_coral = np.array([0.97, 0.78, 0.68], dtype=np.float32)[None, None, :]
        blend = np.clip((v - 0.35) / 0.65, 0.0, 1.0)[:, :, None] ** 1.35
        polyps = np.maximum(0.0, np.sin(u * TAU * 16.0) * np.cos(v * TAU * 18.0)) ** 3
        albedo[reg5][:, :, :3] = np.clip(base_coral * (1.0 - 0.68 * blend) + tip_coral * (0.68 * blend), 0.0, 1.0)
        normal[reg5][:, :, :3] = api.height_to_normal(polyps * 0.075, 2.6)
        orm[reg5][:, :, 1] = 0.64
        orm[reg5][:, :, 2] = 0.0
        # Slot 7: Voronoi spiderweb-cracked teal dome glass
        reg7, _, _ = _tile(7)
        rng = np.random.default_rng(4077)
        seeds = rng.uniform(0.06, 0.94, size=(26, 2)).astype(np.float32)
        dx = u[:, :, None] - seeds[None, None, :, 0]
        dy = v[:, :, None] - seeds[None, None, :, 1]
        dist = np.sort(np.sqrt(dx * dx + dy * dy), axis=2)
        border = dist[:, :, 1] - dist[:, :, 0]
        radial = np.abs(np.sin(np.arctan2(v - 0.5, u - 0.5) * 7.0 + dist[:, :, 0] * 6.0))
        crack = np.clip(1.0 - border / 0.013, 0.0, 1.0)
        fine_crack = np.clip(1.0 - border / 0.026, 0.0, 1.0) * (radial > 0.93).astype(np.float32)
        c_mask = np.clip(crack + fine_crack * 0.75, 0.0, 1.0)
        glass_rgb = np.array([0.22, 0.52, 0.56], dtype=np.float32)[None, None, :]
        crack_rgb = np.array([0.80, 0.96, 0.94], dtype=np.float32)[None, None, :]
        albedo[reg7][:, :, :3] = glass_rgb * (1.0 - c_mask[:, :, None]) + crack_rgb * c_mask[:, :, None]
        albedo[reg7][:, :, 3] = np.clip(0.28 + c_mask * 0.56, 0.26, 0.86)
        normal[reg7][:, :, :3] = api.height_to_normal(-c_mask * 0.09, 3.0)
        orm[reg7][:, :, 1] = np.clip(0.08 + c_mask * 0.35, 0.07, 0.45)

    def paint_blade_tool(albedo, normal, orm, _emission):
        for s_idx, rough, metal, freq in ((1, 0.16, 0.90, 42.0), (6, 0.24, 0.86, 32.0)):
            reg, w, h = _tile(s_idx)
            y, x = np.mgrid[0:h, 0:w].astype(np.float32)
            u, v = x / w, y / h
            grind = np.sin((u * 0.85 + v * 0.35) * TAU * freq) * 0.022
            albedo[reg][:, :, :3] = np.clip(albedo[reg][:, :, :3] * (1.0 + grind[:, :, None]), 0.0, 1.0)
            normal[reg][:, :, :3] = api.height_to_normal(grind * 0.6, 2.2)
            orm[reg][:, :, 1] = rough
            orm[reg][:, :, 2] = metal

    def paint_sonic(albedo, normal, orm, emission):
        # Slot 4: recessed concave dark-teal sector-scan sonar display with glowing grid
        reg4, w, h = _tile(4)
        y, x = np.mgrid[0:h, 0:w].astype(np.float32)
        u, v = x / w, y / h
        ox, oy = 0.50, 0.20
        dx, dy = u - ox, v - oy
        r = np.sqrt(dx * dx + dy * dy)
        ang = np.arctan2(dx, np.maximum(dy, 1e-4))
        in_dish = ((u - 0.5) ** 2 + (v - 0.5) ** 2) < 0.225
        in_fan = (np.abs(ang) < 0.98) & (dy > 0.0) & (r < 0.72) & in_dish
        arcs = (np.abs((r * 7.5) % 1.0 - 0.5) > 0.445).astype(np.float32) * in_fan.astype(np.float32)
        spokes = (np.abs(((ang + 0.98) / 1.96 * 8.0) % 1.0 - 0.5) > 0.455).astype(np.float32) * in_fan.astype(np.float32)
        border_fan = ((np.abs(np.abs(ang) - 0.98) < 0.018) & (dy > 0.0) & (r < 0.72) & in_dish).astype(np.float32)
        outer_ring = (np.abs(np.sqrt((u - 0.5) ** 2 + (v - 0.5) ** 2) - 0.44) < 0.010).astype(np.float32)
        pip = np.exp(-((dx * dx + dy * dy) / 0.0012))
        sweep_cone = np.exp(-((ang - 0.22) ** 2) / 0.08) * in_fan.astype(np.float32) * 0.42
        grid = np.clip(arcs * 0.80 + spokes * 0.72 + border_fan * 0.90 + outer_ring * 0.75 + pip + sweep_cone, 0.0, 1.0)
        bg = np.array([0.07, 0.24, 0.28], dtype=np.float32)[None, None, :]
        glow = np.array([0.52, 0.96, 0.89], dtype=np.float32)[None, None, :]
        albedo[reg4][:, :, :3] = bg * (1.0 - grid[:, :, None]) + glow * grid[:, :, None]
        emission[reg4][:, :, :3] = glow * (grid[:, :, None] * 0.78 + 0.06 * in_fan[:, :, None])
        normal[reg4][:, :, :3] = api.height_to_normal(grid * 0.02, 1.8)
        orm[reg4][:, :, 1] = 0.16
        # Slot 7: clear slightly domed glass cover lens
        reg7, _, _ = _tile(7)
        rad = np.sqrt((u - 0.5) ** 2 + (v - 0.5) ** 2) * 2.0
        albedo[reg7][:, :, :3] = np.array([0.46, 0.78, 0.82], dtype=np.float32)[None, None, :]
        albedo[reg7][:, :, 3] = np.clip(0.16 + 0.12 * (rad ** 2.0), 0.15, 0.30)
        orm[reg7][:, :, 1] = 0.05
        emission[reg7][:, :, :3] = 0.0

    def paint_copper(albedo, normal, orm, _emission):
        for s_idx in (0, 5, 7):
            reg, w, h = _tile(s_idx)
            y, x = np.mgrid[0:h, 0:w].astype(np.float32)
            u, v = x / w, y / h
            rings = 0.5 + 0.5 * np.sin((np.sqrt((u - 0.4) ** 2 + (v - 0.5) ** 2) * 18.0 + 0.25 * np.sin(u * TAU * 3.0)) * TAU)
            dark_m = np.array([0.13, 0.40, 0.31], dtype=np.float32)[None, None, :]
            lite_m = np.array([0.42, 0.78, 0.62], dtype=np.float32)[None, None, :]
            albedo[reg][:, :, :3] = dark_m * (1.0 - rings[:, :, None] * 0.72) + lite_m * (rings[:, :, None] * 0.72)
            normal[reg][:, :, :3] = api.height_to_normal(rings * 0.06, 2.4)
            orm[reg][:, :, 1] = 0.46
            orm[reg][:, :, 2] = 0.0
        for s_idx, rough in ((2, 0.24), (6, 0.19)):
            reg, w, h = _tile(s_idx)
            y, x = np.mgrid[0:h, 0:w].astype(np.float32)
            hammer = np.sin(x / w * TAU * 9.0) * np.cos(y / h * TAU * 11.0) * 0.035
            normal[reg][:, :, :3] = api.height_to_normal(hammer, 2.2)
            orm[reg][:, :, 1] = rough
            orm[reg][:, :, 2] = 0.88

    def paint_titanium(albedo, normal, orm, _emission):
        for s_idx, rough, metal in ((1, 0.16, 0.90), (2, 0.24, 0.84), (6, 0.20, 0.88)):
            reg, w, h = _tile(s_idx)
            y, x = np.mgrid[0:h, 0:w].astype(np.float32)
            u, v = x / w, y / h
            steps = (np.floor(u * 14.0) / 14.0 - u) * 0.18 + (np.floor(v * 14.0) / 14.0 - v) * 0.12
            albedo[reg][:, :, :3] = np.clip(albedo[reg][:, :, :3] * (1.0 + steps[:, :, None] * 0.35), 0.0, 1.0)
            normal[reg][:, :, :3] = api.height_to_normal(steps * 0.32, 2.6)
            orm[reg][:, :, 1] = rough
            orm[reg][:, :, 2] = metal

    api.CUSTOM_PAINTERS['pod'] = paint_pod
    api.CUSTOM_PAINTERS['shipwreck'] = paint_shipwreck
    api.CUSTOM_PAINTERS['weapon_knife'] = paint_blade_tool
    api.CUSTOM_PAINTERS['weapon_axe'] = paint_blade_tool
    api.CUSTOM_PAINTERS['weapon_sonic'] = paint_sonic
    api.CUSTOM_PAINTERS['resource_copper'] = paint_copper
    api.CUSTOM_PAINTERS['resource_titanium'] = paint_titanium


def _build_pod(api):
    cx, cy, cz = 0.0, -0.34, 2.08
    n_lat, n_lon = 50, 84
    theta_min, theta_max = 0.07, math.pi - 0.33

    def hull_pt(theta, phi, inset=0.0):
        s = (1.0 - math.cos(theta)) * 0.5
        z = 0.64 + 2.94 * s
        r_base = 1.86 * math.sin(theta) * (1.03 - 0.13 * math.cos(theta) - 0.04 * math.cos(2.0 * theta))
        r = max(0.04, r_base - inset)
        return Vector((cx + r * math.cos(phi), cy + r * math.sin(phi), z))

    portholes = [
        (-0.92, -0.38, 0.56, 0.30), (0.92, -0.38, 0.56, 0.30),
        (-0.95, -0.24, -0.36, 0.27), (0.95, -0.24, -0.36, 0.27),
    ]

    def portal_sdf(pt):
        d_best = 9.0
        if pt.y < cy - 0.45:
            zn = (pt.z - 1.90) / 0.86
            w_eff = 0.66 * (1.0 - 0.13 * max(0.0, zn))
            xn = pt.x / max(0.2, w_eff)
            d_door = (math.hypot(xn, zn) - 1.0) * 0.64 if zn > 0.0 else ((abs(xn) ** 3.2 + abs(zn) ** 3.2) ** (1.0 / 3.2) - 1.0) * 0.64
            d_best = min(d_best, d_door)
            zn2 = (pt.z - 3.21) / 0.145
            xn2 = pt.x / (0.41 * (1.0 - 0.18 * zn2))
            d_brow = ((abs(xn2) ** 2.6 + abs(zn2) ** 2.4) ** (1.0 / 2.5) - 1.0) * 0.16
            d_best = min(d_best, d_brow)
        rel = (pt - Vector((cx, cy, cz))).normalized()
        for px, py, pz, prad in portholes:
            pdir = Vector((px, py, pz)).normalized()
            ang_dist = math.acos(max(-1.0, min(1.0, rel.dot(pdir)))) * 1.82
            d_best = min(d_best, ang_dist - prad)
        return d_best

    angles = [[(theta_min + (theta_max - theta_min) * i / n_lat, -math.pi + TAU * j / n_lon)
               for j in range(n_lon)] for i in range(n_lat + 1)]
    keep = [[False] * n_lon for _ in range(n_lat)]
    used_count = [[0] * n_lon for _ in range(n_lat + 1)]
    for i in range(n_lat):
        for j in range(n_lon):
            jn = (j + 1) % n_lon
            pts4 = [hull_pt(*angles[i][j]), hull_pt(*angles[i][jn]),
                    hull_pt(*angles[i + 1][jn]), hull_pt(*angles[i + 1][j])]
            center_p = (pts4[0] + pts4[1] + pts4[2] + pts4[3]) * 0.25
            if portal_sdf(center_p) >= 0.0:
                keep[i][j] = True
                for ii, jj in ((i, j), (i, jn), (i + 1, jn), (i + 1, j)):
                    used_count[ii][jj] += 1

    # Snap hole boundary vertices onto exact smooth portal curves (zero stair-stepping)
    for _step in range(4):
        for i in range(1, n_lat):
            for j in range(n_lon):
                if 0 < used_count[i][j] < 4:
                    th, ph = angles[i][j]
                    p0 = hull_pt(th, ph)
                    d0 = portal_sdf(p0)
                    eps = 0.006
                    gt = (portal_sdf(hull_pt(th + eps, ph)) - d0) / eps
                    gp = (portal_sdf(hull_pt(th, ph + eps)) - d0) / eps
                    denom = gt * gt + gp * gp + 1e-6
                    angles[i][j] = (max(theta_min + 0.02, min(theta_max - 0.02, th - d0 * gt / denom * 0.75)),
                                    ph - d0 * gp / denom * 0.75)

    def panel_role(pt, ph):
        # Concave 4-cusp naval-indigo astroid star panels around equator/meridians
        for c_phi in (-math.pi * 0.5 - 0.66, -math.pi * 0.5 + 0.66, math.pi * 0.5 - 0.68, math.pi * 0.5 + 0.68):
            dphi = abs((ph - c_phi + math.pi) % TAU - math.pi)
            dz = abs(pt.z - 2.08)
            if (dphi / 0.44) ** 0.68 + (dz / 0.56) ** 0.68 < 1.0:
                return 3
        if abs(pt.z - 2.08) < 0.045 and not (pt.y < cy - 0.5 and abs(pt.x) < 0.78):
            return 3
        if pt.y < cy - 0.5 and abs(pt.x) < 0.16 and 2.84 < pt.z < 3.06:
            return 5
        if pt.y < cy - 0.4 and abs(pt.x) < 0.25 and 0.79 < pt.z < 0.94:
            return 5
        if pt.z < 0.88:
            return 3
        return 0

    verts, uv, faces, fslots = [], [], [], []
    outer_idx, inner_idx = {}, {}
    for i in range(n_lat + 1):
        for j in range(n_lon):
            if used_count[i][j] == 0:
                continue
            th, ph = angles[i][j]
            p_raw = hull_pt(th, ph)
            inset_ext = 0.024 if panel_role(p_raw, ph) == 3 and 0 < used_count[i][j] == 4 else 0.0
            outer_idx[(i, j)] = len(verts)
            verts.append(tuple(hull_pt(th, ph, inset_ext)))
            uv.append(((ph + math.pi) / TAU, i / n_lat))
            inner_idx[(i, j)] = len(verts)
            verts.append(tuple(hull_pt(th, ph, 0.13)))
            uv.append(((ph + math.pi) / TAU, i / n_lat))

    edge_uses = {}
    for i in range(n_lat):
        for j in range(n_lon):
            if not keep[i][j]:
                continue
            jn = (j + 1) % n_lon
            q = [(i, j), (i, jn), (i + 1, jn), (i + 1, j)]
            c_pt = sum((hull_pt(*angles[a][b]) for a, b in q), Vector()) * 0.25
            c_ph = math.atan2(c_pt.y - cy, c_pt.x - cx)
            faces.append(tuple(outer_idx[k] for k in q))
            fslots.append(panel_role(c_pt, c_ph))
            faces.append(tuple(inner_idx[k] for k in reversed(q)))
            fslots.append(1 if c_pt.z >= 0.98 else 3)
            for e_idx in range(4):
                ka, kb = q[e_idx], q[(e_idx + 1) % 4]
                und = (ka, kb) if ka < kb else (kb, ka)
                edge_uses.setdefault(und, []).append((ka, kb))

    for und, directed in edge_uses.items():
        if len(directed) == 1:
            ka, kb = directed[0]
            faces.append((outer_idx[ka], inner_idx[ka], inner_idx[kb], outer_idx[kb]))
            fslots.append(2)
    api.mesh('Hollow ceramic habitat shell', verts, faces, uv, 0, face_slots=fslots)

    # Exterior machined brass meridian/astroid seams & coral-red safety capsules
    for sign in (-1, 1):
        for fore in (-1, 1):
            c_phi = (-math.pi * 0.5 if fore < 0 else math.pi * 0.5) + sign * 0.66
            for v_sign in (-1, 1):
                seam_pts = []
                for k in range(13):
                    t = k / 12.0
                    dphi = 0.44 * (t ** 1.47)
                    dz = 0.56 * ((1.0 - t) ** 1.47)
                    z_t = 2.08 + v_sign * dz
                    s_val = max(0.03, min(0.97, (z_t - 0.64) / 2.94))
                    th_t = math.acos(1.0 - 2.0 * s_val)
                    seam_pts.append(hull_pt(th_t, c_phi - sign * dphi, -0.012))
                _sweep(api, 'Astroid brass seam', seam_pts, 0.016, 2, sides=6)
        for ph_cap, z_lo, z_hi in ((-math.pi * 0.5 + sign * 0.52, 1.46, 1.74),
                                   (-0.12 if sign > 0 else math.pi + 0.12, 1.54, 1.84)):
            cap_pts = []
            for k in range(5):
                zt = z_lo + (z_hi - z_lo) * k / 4.0
                th_c = math.acos(1.0 - 2.0 * (zt - 0.64) / 2.94)
                cap_pts.append(hull_pt(th_c, ph_cap, -0.018))
            _sweep(api, 'Coral safety capsule', cap_pts, (0.036, 0.022), 5, sides=8)

    # Front arch door frame, latch handle & curved transparent glass (glass=True, slot=7)
    door_ring = []
    for k in range(48):
        ang = TAU * k / 48.0
        ca, sa = math.cos(ang), math.sin(ang)
        zn = sa if sa > 0.0 else math.copysign(abs(sa) ** 0.64, sa)
        xn = ca if sa > 0.0 else math.copysign(abs(ca) ** 0.64, ca)
        z_d = 1.90 + zn * 0.87
        x_d = xn * 0.67 * (1.0 - 0.13 * max(0.0, zn))
        th_d = math.acos(1.0 - 2.0 * (z_d - 0.64) / 2.94)
        r_xy = hull_pt(th_d, 0.0).x - cx
        y_d = cy - math.sqrt(max(0.08, r_xy * r_xy - x_d * x_d))
        door_ring.append(Vector((x_d, y_d - 0.018, z_d)))
    _sweep(api, 'Front door brass frame', door_ring, (0.048, 0.038), 2, sides=10, closed=True)
    _sweep(api, 'Front door outer ivory bezel',
           [p + Vector((p.x * 0.06, -0.012, (p.z - 1.90) * 0.05)) for p in door_ring],
           (0.030, 0.026), 0, sides=8, closed=True)
    api.box('Door latch housing', (-0.69, cy - 1.74, 1.88), (0.14, 0.14, 0.36), 2, bevel=0.022)
    api.box('Door latch recess', (-0.69, cy - 1.80, 1.88), (0.075, 0.05, 0.24), 3, bevel=0.010)
    _sweep(api, 'Door latch grip', [(-0.69, cy - 1.82, 1.78), (-0.69, cy - 1.85, 1.88), (-0.69, cy - 1.82, 1.98)],
           0.018, 5, sides=8)

    g_verts, g_uv, g_faces = [(0.0, cy - 1.90, 1.90)], [(0.5, 0.5)], []
    for k, p in enumerate(door_ring):
        g_verts.append((p.x * 0.96, p.y - 0.012, 1.90 + (p.z - 1.90) * 0.96))
        g_uv.append((0.5 + p.x * 0.62, 0.5 + (p.z - 1.90) * 0.52))
        g_faces.append((0, 1 + k, 1 + (k + 1) % len(door_ring)))
    api.mesh('Front observation door glass', g_verts, g_faces, g_uv, 7, glass=True)

    # Upper-front arched eyebrow window + glass
    brow_ring = []
    for k in range(28):
        ang = TAU * k / 28.0
        ca, sa = math.cos(ang), math.sin(ang)
        zn = math.copysign(abs(sa) ** 0.78, sa)
        xn = math.copysign(abs(ca) ** 0.76, ca)
        z_b = 3.21 + zn * 0.148
        x_b = xn * 0.41 * (1.0 - 0.18 * zn)
        th_b = math.acos(1.0 - 2.0 * (z_b - 0.64) / 2.94)
        r_xy = hull_pt(th_b, 0.0).x - cx
        y_b = cy - math.sqrt(max(0.05, r_xy * r_xy - x_b * x_b))
        brow_ring.append(Vector((x_b, y_b - 0.015, z_b)))
    _sweep(api, 'Eyebrow window brass bezel', brow_ring, 0.028, 2, sides=8, closed=True)
    b_verts = [(0.0, cy - 1.18, 3.21)] + [tuple(p) for p in brow_ring]
    b_uv = [(0.5, 0.5)] + [(0.5 + p.x, 0.5 + (p.z - 3.21) * 2.5) for p in brow_ring]
    api.mesh('Eyebrow window glass', b_verts,
             [(0, 1 + k, 1 + (k + 1) % len(brow_ring)) for k in range(len(brow_ring))],
             b_uv, 7, glass=True)

    # 4 Brass-framed side portholes + curved glass lenses
    for px, py, pz, prad in portholes:
        n_dir = Vector((px, py, pz)).normalized()
        th_p = math.acos(max(-1.0, min(1.0, n_dir.z)))
        ph_p = math.atan2(n_dir.y, n_dir.x)
        p_surf = hull_pt(th_p, ph_p, 0.015)
        _revolve(api, 'Porthole brass bezel', p_surf, n_dir,
                 [(prad * 0.92, -0.06), (prad * 0.95, 0.045), (prad * 1.16, 0.048), (prad * 1.19, -0.01)],
                 slot=2, segs=28)
        _revolve(api, 'Porthole glass pane', p_surf, n_dir,
                 [(0.0, 0.055), (prad * 0.55, 0.044), (prad * 0.94, 0.018)],
                 slot=7, segs=24, glass=True, planar_uv=True)

    # Top skylight cupola + transparent glass dome + acoustic mast (reaching Z = 4.215)
    _revolve(api, 'Cupola collar', (cx, cy, 3.48), (0, 0, 1),
             [(0.66, -0.03), (0.64, 0.04), (0.58, 0.09), (0.54, 0.15), (0.47, 0.16), (0.46, 0.02)],
             slot=2, segs=32, face_slots_fn=lambda i, _j: 5 if i == 0 else (3 if i == 1 else 2))
    _revolve(api, 'Top skylight glass dome', (cx, cy, 3.61), (0, 0, 1),
             [(0.0, 0.14), (0.26, 0.11), (0.47, 0.0)], slot=7, segs=28, glass=True, planar_uv=True)
    _revolve(api, 'Antenna base boss', (-0.58, cy - 0.12, 3.36), (0, 0, 1),
             [(0.09, -0.02), (0.08, 0.07), (0.045, 0.12), (0.0, 0.12)], slot=2, segs=14)
    _sweep(api, 'Acoustic mast', [(-0.58, cy - 0.12, 3.46), (-0.58, cy - 0.12, 4.14)], [0.028, 0.016], 6, sides=10)
    api.ellipsoid('Acoustic mast beacon', (-0.58, cy - 0.12, 4.165), (0.046, 0.046, 0.050), 4, segments=12, rings=8)

    # 4 Articulated Hydraulic Landing Legs (splayed strictly to bounds_blender [-2.35..2.35, -2.85..2.044, 0..4.215])
    for sx in (-1.0, 1.0):
        for fy, y_hip, y_knee, y_foot in ((-1.0, -1.48, -2.02, -2.47), (1.0, 0.80, 1.28, 1.664)):
            hip = Vector((sx * 1.28, y_hip, 1.18))
            knee = Vector((sx * 1.72, y_knee, 0.94))
            ankle = Vector((sx * 1.97, y_foot, 0.15))
            api.ellipsoid('Hip socket housing', hip, (0.22, 0.22, 0.20), 3, segments=14, rings=8)
            _revolve(api, 'Hip brass collar', hip, (knee - hip).normalized(),
                     [(0.20, -0.04), (0.22, 0.04), (0.16, 0.08)], slot=2, segs=16)
            _sweep(api, 'Upper leg clevis', [hip, knee], [(0.11, 0.09), (0.10, 0.08)], 3, sides=10)
            for p_off in (-0.075, 0.075):
                perp = Vector((-fy * p_off, sx * p_off, 0.06))
                p_mid = hip.lerp(knee, 0.56) + perp
                _sweep(api, 'Hydraulic cylinder barrel', [hip + perp, p_mid], 0.036, 2, sides=8)
                _sweep(api, 'Hydraulic piston rod', [p_mid, knee + perp * 0.7], 0.021, 6, sides=8)
            api.ellipsoid('Articulated knee drum', knee, (0.16, 0.16, 0.15), 6, segments=14, rings=8)
            shin_mid = knee.lerp(ankle, 0.46) + Vector((sx * 0.06, fy * 0.05, 0.05))
            _sweep(api, 'Armored ivory shin strut', [knee, shin_mid, ankle],
                   [(0.15, 0.12), (0.16, 0.12), (0.10, 0.09)], 0, sides=12)
            _sweep(api, 'Shin brass seam', [knee + Vector((0, 0, 0.02)), shin_mid + Vector((sx * 0.03, fy * 0.03, 0.02)), ankle],
                   0.022, 2, sides=6)
            pad_a = shin_mid.lerp(ankle, 0.22) + Vector((sx * 0.055, fy * 0.055, 0.0))
            pad_b = shin_mid.lerp(ankle, 0.78) + Vector((sx * 0.045, fy * 0.045, 0.0))
            _sweep(api, 'Coral shin armor pad', [pad_a, pad_b], [(0.078, 0.042), (0.065, 0.036)], 5, sides=10)
            api.ellipsoid('Ankle ball joint', ankle, (0.11, 0.11, 0.10), 3, segments=12, rings=7)
            _revolve(api, 'Circular brass footpad', (ankle.x, ankle.y, 0.0), (0, 0, 1),
                     [(0.0, 0.0), (0.375, 0.0), (0.380, 0.045), (0.365, 0.105), (0.25, 0.135), (0.11, 0.155), (0.0, 0.155)],
                     slot=2, segs=24, face_slots_fn=lambda i, _j: 3 if i <= 1 else (2 if i <= 3 else 0))

    # === Complete 3D Furnished Warm-Lit Cabin Interior ===
    _revolve(api, 'Cabin wood-brass floor', (cx, cy, 1.00), (0, 0, 1),
             [(0.0, 0.03), (1.36, 0.03), (1.42, 0.0), (0.0, 0.0)], slot=2, segs=32,
             face_slots_fn=lambda i, _j: 2 if i == 0 else 3)
    _revolve(api, 'Cabin cream rug', (cx, cy - 0.08, 1.032), (0, 0, 1),
             [(0.0, 0.012), (0.86, 0.012), (0.88, 0.0)], slot=1, segs=28)
    _revolve(api, 'Warm ceiling light cove', (cx, cy, 3.38), (0, 0, 1),
             [(0.48, 0.0), (0.58, -0.04), (0.62, 0.02)], slot=4, segs=28)
    for r_ang in (0.35, 1.05, 2.09, 2.79, -0.35, -2.79):
        rib_pts = [hull_pt(0.28 + 0.72 * k / 10.0, r_ang, 0.155) for k in range(11)]
        _sweep(api, 'Cabin curved structural rib', rib_pts, (0.032, 0.022), 1, sides=6)

    # Plush cream quilted lounge armchair (foreground right inside glass door)
    ch_c = Vector((0.36, cy - 0.22, 1.03))
    ch_rot = Matrix.Rotation(math.radians(-26.0), 3, 'Z')
    def c_pt(lx, ly, lz):
        return ch_c + ch_rot @ Vector((lx, ly, lz))

    _revolve(api, 'Chair brass swivel base', ch_c, (0, 0, 1),
             [(0.24, 0.0), (0.22, 0.04), (0.06, 0.07), (0.055, 0.24), (0.16, 0.26)], slot=2, segs=18)
    _sweep(api, 'Chair plush seat cushion', [c_pt(-0.24, 0.0, 0.30), c_pt(0.0, 0.02, 0.29), c_pt(0.24, 0.0, 0.30)],
           [(0.24, 0.095), (0.26, 0.10), (0.24, 0.095)], 1, sides=14)
    for q_idx, qz in enumerate((0.46, 0.64, 0.82, 0.98)):
        lean_y = 0.16 + q_idx * 0.055
        rad_z = 0.095 if q_idx < 3 else 0.085
        _sweep(api, 'Chair quilted backrest bolster',
               [c_pt(-0.22, lean_y, qz), c_pt(0.0, lean_y + 0.02, qz), c_pt(0.22, lean_y, qz)],
               [(0.095, rad_z), (0.105, rad_z), (0.095, rad_z)], 1, sides=12)
    for arm_s in (-1.0, 1.0):
        _sweep(api, 'Chair padded armrest',
               [c_pt(arm_s * 0.27, -0.16, 0.32), c_pt(arm_s * 0.28, -0.12, 0.48), c_pt(arm_s * 0.26, 0.18, 0.52)],
               [(0.055, 0.065), (0.062, 0.072), (0.058, 0.065)], 1, sides=10)

    # Right/rear curved wooden-brass desk & glowing warm brass shade table lamp
    desk_pts = [Vector((0.88 * math.cos(a), cy + 0.88 * math.sin(a), 1.66))
                for a in np.linspace(-0.18, 0.72, 9)]
    _sweep(api, 'Curved cabin desk top', desk_pts, (0.22, 0.036), 2, sides=10)
    api.box('Desk cabinet pedestal', (0.72, cy + 0.28, 1.33), (0.34, 0.38, 0.60), 3, bevel=0.02)
    lamp_pos = Vector((0.66, cy + 0.22, 1.69))
    _revolve(api, 'Lamp brass base & stem', lamp_pos, (0, 0, 1),
             [(0.11, 0.0), (0.095, 0.035), (0.022, 0.06), (0.018, 0.34), (0.04, 0.36)], slot=2, segs=18)
    _revolve(api, 'Glowing warm lampshade', lamp_pos + Vector((0, 0, 0.28)), (0, 0, 1),
             [(0.185, 0.0), (0.175, 0.01), (0.095, 0.19), (0.105, 0.19), (0.195, 0.0)], slot=4, segs=22)
    api.ellipsoid('Lamp warm bulb', lamp_pos + Vector((0, 0, 0.34)), (0.055, 0.055, 0.065), 4, segments=10, rings=6)

    # Left curved specimen counter + ceramic pot with branching red coral
    cnt_pts = [Vector((-0.86 * math.cos(a), cy + 0.86 * math.sin(a), 1.62))
               for a in np.linspace(-0.35, 0.42, 8)]
    _sweep(api, 'Specimen counter top', cnt_pts, (0.20, 0.034), 2, sides=10)
    api.box('Specimen counter cabinet', (-0.74, cy - 0.05, 1.30), (0.32, 0.42, 0.56), 3, bevel=0.02)
    pot_pos = Vector((-0.62, cy - 0.14, 1.65))
    _revolve(api, 'Coral ceramic planter pot', pot_pos, (0, 0, 1),
             [(0.0, 0.0), (0.095, 0.0), (0.125, 0.14), (0.135, 0.17), (0.105, 0.17), (0.095, 0.13), (0.0, 0.13)],
             slot=1, segs=18, face_slots_fn=lambda i, _j: 2 if i in (2, 3) else (3 if i >= 5 else 1))
    _coral_cluster(api, 'Potted cabin red coral', pot_pos + Vector((0, 0, 0.13)), scale=0.72, branches=5, slot=5)

    # Curved rear floor-to-ceiling bookshelf with 3D books & specimen jars
    for sh_z in (1.22, 1.68, 2.14, 2.58):
        r_sh = 1.12 if sh_z < 2.3 else 0.96
        sh_pts = [Vector((r_sh * math.cos(a), cy + r_sh * math.sin(a), sh_z))
                  for a in np.linspace(0.88, 2.26, 9)]
        _sweep(api, 'Curved bookshelf plank', sh_pts, (0.15, 0.024), 2, sides=8)
    for up_a in (0.90, 1.35, 1.79, 2.24):
        u_pts = [Vector(((1.12 - 0.18 * k / 4.0) * math.cos(up_a),
                         cy + (1.12 - 0.18 * k / 4.0) * math.sin(up_a), 1.05 + 0.40 * k)) for k in range(5)]
        _sweep(api, 'Bookshelf brass upright', u_pts, 0.022, 2, sides=6)
    book_slots = (5, 3, 2, 1, 0, 5, 3, 2)
    for row_i, sh_z in enumerate((1.25, 1.71, 2.17)):
        for b_i in range(7):
            ang = 0.98 + b_i * 0.17 + 0.03 * row_i
            if (row_i + b_i) % 5 == 0:
                jp = Vector((1.02 * math.cos(ang), cy + 1.02 * math.sin(ang), sh_z))
                _revolve(api, 'Specimen jar', jp, (0, 0, 1),
                         [(0.048, 0.0), (0.052, 0.15), (0.038, 0.18), (0.042, 0.21), (0.0, 0.21)],
                         slot=4, segs=12, face_slots_fn=lambda i, _j: 2 if i >= 2 else 4)
            else:
                bh = 0.22 + 0.04 * ((b_i + row_i) % 3)
                bp = Vector((1.03 * math.cos(ang), cy + 1.03 * math.sin(ang), sh_z + bh * 0.5))
                api.box('Cabin book', bp, (0.048, 0.16, bh), book_slots[(b_i + row_i * 2) % len(book_slots)], bevel=0.005)


def _build_shipwreck(api):
    # Hull cross-section profile from behind bow dome (Y=-3.55) to tailcone (Y=4.22)
    def hull_sec(y):
        t = (y + 3.55) / 7.77
        env = math.sin(math.pi * min(0.985, 0.16 + 0.82 * t)) ** 0.82
        rx = max(0.16, 1.76 * env * (1.0 - 0.18 * t))
        rz = max(0.18, 1.52 * env * (1.0 - 0.14 * t))
        zc = 1.68 - 0.08 * t + 0.05 * math.sin(t * math.pi)
        return rx, rz, zc

    # 1. Forward Geodesic Brass-Mullioned Nose Dome (Y = -5.252 .. -3.55)
    dome_c = Vector((0.0, -3.55, 1.68))
    dome_r = Vector((1.58, 1.702, 1.38))
    rings_cfg = [(0.11, 7, 0.0), (0.42, 7, 0.0), (0.82, 9, 0.22), (1.22, 11, 0.08), (1.56, 14, 0.0)]

    def dome_pt(alpha, beta, inset=0.0):
        sa, ca = math.sin(alpha), math.cos(alpha)
        d = Vector((sa * math.cos(beta) * (dome_r.x - inset),
                    -ca * (dome_r.y - inset),
                    sa * math.sin(beta) * (dome_r.z - inset)))
        return dome_c + d

    # Nose cap brass ring + center cracked glass
    nose_ring = [dome_pt(0.11, TAU * k / 7.0) for k in range(7)]
    _sweep(api, 'Dome nose brass bezel', nose_ring, 0.036, 2, sides=7, closed=True)
    nv = [tuple(dome_pt(0.0, 0.0, 0.01))] + [tuple(dome_pt(0.11, TAU * k / 7.0, 0.01)) for k in range(7)]
    nuv = [(0.5, 0.5)] + [(0.5 + 0.44 * math.cos(TAU * k / 7.0), 0.5 + 0.44 * math.sin(TAU * k / 7.0)) for k in range(7)]
    api.mesh('Dome nose glass', nv, [(0, 1 + k, 1 + (k + 1) % 7) for k in range(7)], nuv, 7, glass=True)

    missing_panes = {(1, 0), (1, 1), (2, 8)}
    for r_idx in range(len(rings_cfg) - 1):
        a0, n0, off0 = rings_cfg[r_idx]
        a1, n1, off1 = rings_cfg[r_idx + 1]
        ring1_pts = [dome_pt(a1, off1 + TAU * k / n1) for k in range(n1)]
        _sweep(api, 'Geodesic dome ring mullion', ring1_pts, 0.038 if r_idx < 3 else 0.052, 2, sides=7, closed=True)
        for k in range(n1):
            b_lo0 = off1 + TAU * k / n1
            b_lo1 = off1 + TAU * (k + 1) / n1
            b_hi0 = off0 + TAU * round((b_lo0 - off0) / TAU * n0) / n0
            b_hi1 = off0 + TAU * round((b_lo1 - off0) / TAU * n0) / n0
            p00, p01 = dome_pt(a0, b_hi0), dome_pt(a0, b_hi1)
            p11, p10 = dome_pt(a1, b_lo1), dome_pt(a1, b_lo0)
            _sweep(api, 'Geodesic radial mullion', [p00, p10], 0.034, 2, sides=6)
            if (p01 - p00).length > 0.04:
                poly_pts = [dome_pt(a0, b_hi0, 0.015), dome_pt(a0, b_hi1, 0.015),
                            dome_pt(a1, b_lo1, 0.015), dome_pt(a1, b_lo0, 0.015)]
                p_uv = [(0.15, 0.15), (0.85, 0.15), (0.88, 0.88), (0.12, 0.88)]
            else:
                poly_pts = [dome_pt(a0, b_hi0, 0.015), dome_pt(a1, b_lo1, 0.015), dome_pt(a1, b_lo0, 0.015)]
                p_uv = [(0.5, 0.12), (0.88, 0.88), (0.12, 0.88)]
            if (r_idx, k) in missing_panes:
                # Jagged broken glass shards clinging to frame of shattered pane
                mid_in = sum(poly_pts, Vector()) / len(poly_pts)
                s_tip = poly_pts[0].lerp(mid_in, 0.42)
                s_edge = poly_pts[0].lerp(poly_pts[1], 0.58)
                api.mesh('Shattered dome shard', [tuple(poly_pts[0]), tuple(s_edge), tuple(s_tip)],
                         [(0, 1, 2)], [(0.1, 0.1), (0.6, 0.15), (0.35, 0.5)], 7, glass=True)
            elif r_idx < 3 or abs(math.sin(0.5 * (b_lo0 + b_lo1))) < 0.82:
                api.mesh('Cracked geodesic dome pane', [tuple(p) for p in poly_pts],
                         [tuple(range(len(poly_pts)))], p_uv, 7, glass=True)

    # Flanking almond side observation galleries (matching equipment.png bow cheeks)
    for sx in (-1.0, 1.0):
        cheek_ring = []
        for k in range(20):
            ang = TAU * k / 20.0
            yc = -3.12 + 0.56 * math.cos(ang)
            zc = 1.82 + 0.30 * math.sin(ang) * (1.0 - 0.28 * math.cos(ang))
            rx_c, _, _ = hull_sec(yc)
            xc = sx * (rx_c * math.sqrt(max(0.12, 1.0 - ((zc - 1.68) / 1.48) ** 2)) + 0.02)
            cheek_ring.append(Vector((xc, yc, zc)))
        _sweep(api, 'Bow cheek gallery frame', cheek_ring, 0.036, 2, sides=7, closed=True)
        for m_y in (-3.32, -2.96):
            rx_m, _, _ = hull_sec(m_y)
            xm = sx * (rx_m * 0.96)
            _sweep(api, 'Cheek gallery mullion', [(xm, m_y, 1.58), (xm * 1.02, m_y, 1.82), (xm * 0.95, m_y, 2.06)], 0.024, 2, sides=6)
        c_center = sum(cheek_ring, Vector()) / len(cheek_ring) + Vector((sx * 0.03, 0.0, 0.0))
        cv = [tuple(c_center)] + [tuple(p) for p in cheek_ring]
        cuv = [(0.5, 0.5)] + [(0.5 + 0.44 * math.cos(TAU * k / 20.0), 0.5 + 0.44 * math.sin(TAU * k / 20.0)) for k in range(20)]
        api.mesh('Bow cheek cracked glass', cv,
                 [(0, 1 + (k + 1) % 20, 1 + k) if sx < 0 else (0, 1 + k, 1 + (k + 1) % 20) for k in range(20)],
                 cuv, 7, glass=True)

    # 2. Interior Pilot Cockpit (visible through geodesic dome & missing panes)
    api.box('Cockpit slatted floor', (0.0, -3.55, 0.84), (1.75, 1.65, 0.07), 3, bevel=0.015)
    api.box('Pilot helm console', (0.0, -4.28, 1.12), (1.08, 0.46, 0.52), 3, bevel=0.03)
    api.box('Consolebrass bezel', (0.0, -4.16, 1.40), (0.96, 0.30, 0.06), 2, bevel=0.012)
    for gx in (-0.28, 0.0, 0.28):
        _revolve(api, 'Pilot glowing gauge', (gx, -4.14, 1.44), (0, 0.45, 0.89),
                 [(0.0, 0.012), (0.085, 0.012), (0.095, 0.0)], slot=4, segs=12,
                 face_slots_fn=lambda i, _j: 4 if i == 0 else 2)
    for lx in (-0.18, 0.18):
        _sweep(api, 'Pilot throttle lever', [(lx, -4.06, 1.38), (lx, -3.96, 1.56)], 0.016, 2, sides=6)
    api.box('Pilot seat pedestal', (0.0, -3.48, 1.02), (0.22, 0.22, 0.32), 2, bevel=0.015)
    api.box('Pilot seat cushion', (0.0, -3.48, 1.22), (0.54, 0.48, 0.12), 1, bevel=0.025)
    api.box('Pilot seat backrest', (0.0, -3.26, 1.56), (0.50, 0.11, 0.62), 1, bevel=0.025)

    # 3. Double-Sided Ruptured Verdigris/Rust Pressure Hull (Y = -3.55 .. 4.22)
    ny, na = 52, 44
    ys = [-3.55 + 7.77 * i / ny for i in range(ny + 1)]

    def hull_breach(y, ang):
        # ang=0 is +X starboard, pi/2 is +Z top, pi/-pi is -X port, -pi/2 is -Z keel
        ca, sa = math.cos(ang), math.sin(ang)
        jag = 0.22 * math.sin(y * 3.7 + ang * 3.0) + 0.14 * math.cos(y * 6.3 - ang * 5.0)
        # Bow cheek gallery openings
        if -3.62 < y < -2.62 and abs(ca) > 0.72 and -0.05 < sa < 0.42:
            return True
        # Wide midship rupture on flanks & dorsal gap matching equipment.png
        if -2.35 + jag * 0.45 < y < 0.68 + jag * 0.45:
            if sa > -0.62 + 0.18 * math.sin(y * 4.2):
                if sa > 0.84 and not (-1.28 < y < -0.42):
                    return False
                return True
        # Aft lower-flank corrosion tear (Y = 2.68 .. 3.68)
        if 2.68 + jag * 0.25 < y < 3.68 - jag * 0.25 and abs(ca) > 0.56 and -0.58 < sa < 0.22:
            return True
        return False

    h_keep = [[not hull_breach(0.5 * (ys[i] + ys[i + 1]), -math.pi + TAU * (j + 0.5) / na)
               for j in range(na)] for i in range(ny)]
    h_verts, h_uv, h_faces, h_slots = [], [], [], []
    o_map, k_map = {}, {}
    for i, y in enumerate(ys):
        rx, rz, zc = hull_sec(y)
        for j in range(na):
            ang = -math.pi + TAU * j / na
            ca, sa = math.cos(ang), math.sin(ang)
            o_map[(i, j)] = len(h_verts)
            h_verts.append((ca * rx, y, zc + sa * rz))
            h_uv.append(((j / na) * 2.0 % 1.0, i / ny))
            k_map[(i, j)] = len(h_verts)
            h_verts.append((ca * max(0.06, rx - 0.09), y, zc + sa * max(0.06, rz - 0.09)))
            h_uv.append(((j / na) * 2.0 % 1.0, i / ny))

    h_edges = {}
    for i in range(ny):
        for j in range(na):
            if not h_keep[i][j]:
                continue
            jn = (j + 1) % na
            q = [(i, j), (i, jn), (i + 1, jn), (i + 1, j)]
            ang_m = -math.pi + TAU * (j + 0.5) / na
            slot_ext = 2 if abs(math.sin(ang_m) + 0.58) < 0.06 else 0
            h_faces.append(tuple(o_map[k] for k in q))
            h_slots.append(slot_ext)
            h_faces.append(tuple(k_map[k] for k in reversed(q)))
            h_slots.append(3)
            for e_i in range(4):
                ka, kb = q[e_i], q[(e_i + 1) % 4]
                und = (ka, kb) if ka < kb else (kb, ka)
                h_edges.setdefault(und, []).append((ka, kb))
    for und, directed in h_edges.items():
        if len(directed) == 1:
            ka, kb = directed[0]
            h_faces.append((o_map[ka], k_map[ka], k_map[kb], o_map[kb]))
            h_slots.append(6)
    api.mesh('Corroded ruptured sub hull', h_verts, h_faces, h_uv, 0, face_slots=h_slots)

    # Sweeping longitudinal bronze hull strakes
    for sx in (-1.0, 1.0):
        strake_fore = [Vector((sx * hull_sec(y)[0] * 0.94, y, 1.32 + 0.12 * (y + 3.5)))
                       for y in np.linspace(-3.52, -1.85, 8)]
        _sweep(api, 'Bow bronze strake', strake_fore, (0.045, 0.028), 2, sides=6)
        strake_aft = [Vector((sx * hull_sec(y)[0] * 0.96, y, 1.44 + 0.05 * (y - 0.6)))
                      for y in np.linspace(0.55, 3.85, 11)]
        _sweep(api, 'Aft bronze strake', strake_aft, (0.042, 0.026), 2, sides=6)

    # 4. Exposed Heavy Curved Bronze/Steel Structural Ribs, Bulkheads, Catwalk & Pipes
    rib_stations = [(-2.52, False), (-2.05, False), (-1.58, False), (-1.12, True),
                    (-0.66, True), (-0.20, False), (0.26, False), (0.68, False),
                    (2.92, False), (3.36, False)]
    for ry, broken_top in rib_stations:
        rx, rz, zc = hull_sec(ry)
        if broken_top:
            for seg_a, seg_b in ((-0.42 * math.pi, 0.36 * math.pi), (0.64 * math.pi, 1.42 * math.pi)):
                r_pts = [Vector((math.cos(a) * (rx - 0.02), ry, zc + math.sin(a) * (rz - 0.02)))
                         for a in np.linspace(seg_a, seg_b, 16)]
                _sweep(api, 'Snapped structural hull rib', r_pts, (0.068, 0.052), 2, sides=8)
        else:
            r_pts = [Vector((math.cos(TAU * k / 28.0) * (rx - 0.02), ry, zc + math.sin(TAU * k / 28.0) * (rz - 0.02)))
                     for k in range(28)]
            _sweep(api, 'Structural bronze hull rib', r_pts, (0.065, 0.050), 2, sides=8, closed=True)

    for by in (-2.64, 0.76):
        rx, rz, zc = hull_sec(by)
        _revolve(api, 'Interior bulkhead & circular hatch', (0.0, by, zc - 0.06), (0, 1, 0),
                 [(0.52, -0.04), (0.54, 0.05), (min(rx, rz) * 0.88, 0.04), (min(rx, rz) * 0.88, -0.04), (0.52, -0.04)],
                 slot=3, segs=24, face_slots_fn=lambda i, _j: 2 if i <= 1 else 3)

    _sweep(api, 'Central keel girder', [(0.0, -3.4, 0.26), (0.0, 0.0, 0.24), (0.0, 3.6, 0.58)], (0.14, 0.11), 6, sides=8)
    for sx in (-1.0, 1.0):
        _sweep(api, 'Bilge stringer', [(sx * 0.86, -2.6, 0.62), (sx * 0.88, 0.7, 0.62)], (0.055, 0.055), 6, sides=6)
        _sweep(api, 'Midship catwalk rail', [(sx * 0.92, -2.55, 0.78), (sx * 0.92, 0.72, 0.78)], (0.048, 0.048), 3, sides=6)
        _sweep(api, 'Ballast copper pipe', [(sx * 1.18, -2.58, 1.18), (sx * 1.12, -0.9, 1.14), (sx * 1.08, 0.72, 1.22)],
               0.042, 2, sides=8)
        _sweep(api, 'Upper conduit pipe', [(sx * 0.78, -2.58, 2.52), (sx * 0.74, 0.72, 2.48)], 0.030, 6, sides=7)
    for gy in np.linspace(-2.45, 0.62, 14):
        api.box('Catwalk floor grating bar', (0.0, float(gy), 0.76), (1.76, 0.11, 0.045), 3, bevel=0.008)

    # 5. Aft Brass Portholes & Shoulder Skylights
    for sx in (-1.0, 1.0):
        for py in (1.18, 1.82, 2.44):
            rx, rz, zc = hull_sec(py)
            pz = zc + 0.14
            px = sx * rx * math.sqrt(max(0.1, 1.0 - ((pz - zc) / rz) ** 2))
            n_out = Vector((sx * 0.94, 0.12, 0.22)).normalized()
            _revolve(api, 'Aft brass porthole bezel', (px, py, pz), n_out,
                     [(0.20, -0.05), (0.21, 0.045), (0.28, 0.048), (0.29, -0.01)], slot=2, segs=20)
            _revolve(api, 'Aft porthole cracked glass', (px, py, pz), n_out,
                     [(0.0, 0.042), (0.205, 0.022)], slot=7, segs=18, glass=True, planar_uv=True)
        for sy in (1.34, 1.96):
            rx, rz, zc = hull_sec(sy)
            api.box('Shoulder skylight frame', (sx * 0.72, sy, zc + rz * 0.84), (0.28, 0.42, 0.07), 2, bevel=0.014)

    # 6. Dorsal Conning Tower, Bridge Windows, Railings & Twin Tilted Masts (Z up to 6.430)
    sail_levels = [(2.78, 0.62, 1.18, 1.18), (3.32, 0.56, 1.02, 1.14),
                   (3.88, 0.46, 0.82, 1.16), (4.18, 0.34, 0.62, 1.22), (4.24, 0.04, 0.08, 1.24)]
    sv, suv, sf, sslots = [], [], [], []
    for i, (sz, srx, sry, scy) in enumerate(sail_levels):
        for j in range(25):
            ang = TAU * j / 24.0
            sv.append((srx * math.cos(ang), scy + sry * math.sin(ang), sz))
            suv.append((j / 24.0, i / 4.0))
    for i in range(4):
        for j in range(24):
            ang_m = TAU * (j + 0.5) / 24.0
            if i == 1 and math.sin(ang_m) < -0.42:
                continue
            a = i * 25 + j
            sf.append((a, a + 1, a + 26, a + 25))
            sslots.append(2 if i == 2 and j % 3 == 0 else 0)
    api.mesh('Oxidized conning tower sail', sv, sf, suv, 0, face_slots=sslots)

    for w_ang0, w_ang1 in ((-2.35, -1.82), (-1.78, -1.36), (-1.32, -0.78)):
        w_pts = [Vector((0.53 * math.cos(w_ang0), 1.15 + 0.98 * math.sin(w_ang0), 3.36)),
                 Vector((0.53 * math.cos(w_ang1), 1.15 + 0.98 * math.sin(w_ang1), 3.36)),
                 Vector((0.45 * math.cos(w_ang1), 1.16 + 0.80 * math.sin(w_ang1), 3.84)),
                 Vector((0.45 * math.cos(w_ang0), 1.16 + 0.80 * math.sin(w_ang0), 3.84))]
        _sweep(api, 'Bridge window brass mullion', w_pts, 0.024, 2, sides=6, closed=True)
        api.mesh('Bridge cracked window', [tuple(p) for p in w_pts], [(0, 1, 2, 3)],
                 [(0.1, 0.1), (0.9, 0.1), (0.85, 0.9), (0.15, 0.9)], 7, glass=True)

    rail_pts = [Vector((0.36 * math.cos(a), 1.20 + 0.68 * math.sin(a), 4.42))
                for a in np.linspace(-2.4, 2.4, 13)]
    _sweep(api, 'Conning bridge deck railing', rail_pts, 0.016, 2, sides=6)
    for rp in rail_pts[::2]:
        _sweep(api, 'Bridge railing stanchion', [rp - Vector((0, 0, 0.24)), rp], 0.013, 2, sides=5)

    for sx in (-1.0, 1.0):
        aft_rail = [Vector((sx * 0.34, y, hull_sec(y)[2] + hull_sec(y)[1] + 0.18))
                    for y in np.linspace(2.22, 3.32, 6)]
        _sweep(api, 'Aft spine handrail', aft_rail, 0.016, 2, sides=6)
        for ap in aft_rail[::2]:
            _sweep(api, 'Aft handrail post', [ap - Vector((0, 0, 0.20)), ap], 0.013, 2, sides=5)

    # Twin tilted masts (tall main mast reaching Z = 6.430, companion mast Z = 5.62)
    _sweep(api, 'Main tilted sensor mast', [(0.04, 1.52, 4.10), (0.16, 1.72, 5.28), (0.28, 1.94, 6.35)],
           [0.058, 0.040, 0.020], 6, sides=8)
    api.ellipsoid('Top mast rescue beacon', (0.28, 1.94, 6.375), (0.048, 0.048, 0.055), 4, segments=10, rings=6)
    _sweep(api, 'Mast crossbar', [(-0.08, 1.70, 5.20), (0.40, 1.74, 5.34)], 0.016, 2, sides=6)
    _sweep(api, 'Secondary tilted periscope mast', [(-0.08, 1.74, 4.06), (0.02, 1.96, 4.92), (0.11, 2.16, 5.62)],
           [0.046, 0.032, 0.016], 2, sides=8)

    # 7. Corroded Skeletal Swept Tailfins (Y to +4.888, X to ±2.260)
    def _skeletal_fin(lead_pts, trail_pts, rib_count=4):
        _sweep(api, 'Tailfin leading spar', lead_pts, [0.062, 0.048, 0.026], 2, sides=8)
        _sweep(api, 'Tailfin trailing spar', trail_pts, [0.038, 0.030, 0.020], 6, sides=7)
        for r_i in range(1, rib_count + 1):
            u = r_i / (rib_count + 1.0)
            idx_f = u * (len(lead_pts) - 1)
            i0 = min(len(lead_pts) - 2, int(idx_f))
            fr = idx_f - i0
            pa = Vector(lead_pts[i0]).lerp(Vector(lead_pts[i0 + 1]), fr)
            pb = Vector(trail_pts[i0]).lerp(Vector(trail_pts[i0 + 1]), fr)
            _sweep(api, 'Tailfin internal rib', [pa, pb], 0.024, 2, sides=6)
            if r_i % 2 == 1:
                pa2 = Vector(lead_pts[min(len(lead_pts) - 1, i0 + 1)])
                pm = pa.lerp(pb, 0.62)
                api.mesh('Torn tailfin skin patch',
                         [tuple(pa), tuple(pm), tuple(pa2)],
                         [(0, 1, 2)], [(0.1, 0.1), (0.8, 0.4), (0.2, 0.9)], 0)
                api.mesh('Torn tailfin skin back',
                         [tuple(pa), tuple(pa2), tuple(pm)],
                         [(0, 1, 2)], [(0.1, 0.1), (0.2, 0.9), (0.8, 0.4)], 0)

    _skeletal_fin([(0.0, 3.38, 2.02), (0.0, 4.18, 3.08), (0.0, 4.888, 3.74)],
                  [(0.0, 4.08, 1.72), (0.0, 4.38, 2.62), (0.0, 4.888, 3.74)], rib_count=4)
    _skeletal_fin([(0.0, 3.45, 1.24), (0.0, 4.12, 0.52), (0.0, 4.68, 0.06)],
                  [(0.0, 4.06, 1.48), (0.0, 4.28, 0.78), (0.0, 4.68, 0.06)], rib_count=3)
    for sx in (-1.0, 1.0):
        _skeletal_fin([(sx * 0.24, 3.42, 1.58), (sx * 1.28, 3.92, 1.56), (sx * 2.260, 4.42, 1.52)],
                      [(sx * 0.18, 4.08, 1.58), (sx * 1.18, 4.26, 1.55), (sx * 2.260, 4.42, 1.52)], rib_count=3)

    # 8. Lush Pink-Coral Colonies, Calcified Barnacles & Seabed Stones (Z touching 0.000)
    for cx_p, cy_p, cz_p, c_sc in [
        (1.05, -2.18, 0.08, 1.35), (-1.02, -1.75, 0.08, 1.20),
        (0.88, -0.58, 0.42, 1.45), (-0.78, 0.12, 0.38, 1.25),
        (0.95, 2.85, 0.08, 1.18), (-0.92, 2.45, 0.08, 1.10),
    ]:
        _coral_cluster(api, 'Reef pink coral colony', (cx_p, cy_p, cz_p), scale=c_sc, branches=5, slot=5)

    for bx, by, bz in [
        (1.25, -3.35, 0.85), (-1.22, -3.20, 0.92), (1.52, -2.55, 1.42), (-1.48, -2.42, 1.55),
        (1.38, 0.88, 1.25), (-1.35, 1.05, 1.32), (1.12, 2.15, 0.98), (0.42, 0.55, 2.95),
    ]:
        for b_sub in range(3):
            off = Vector((0.09 * math.cos(b_sub * 2.1), 0.11 * math.sin(b_sub * 2.1), 0.06 * (b_sub - 1)))
            _barnacle(api, Vector((bx, by, bz)) + off, Vector((bx, 0.0, max(0.2, bz - 1.2))).normalized(),
                      radius=0.075 - 0.014 * b_sub, height=0.065 - 0.010 * b_sub)

    for rx_s, ry_s, sc_s in [(0.85, -2.35, 0.16), (-0.92, -1.65, 0.15), (0.72, -0.45, 0.14),
                             (-0.68, 0.35, 0.15), (0.82, 2.75, 0.14)]:
        api.ellipsoid('Seabed ballast stone', (rx_s, ry_s, sc_s * 0.5), (sc_s * 1.4, sc_s * 1.1, sc_s * 0.5), 1,
                      segments=10, rings=6, organic=0.22)


def _build_weapon_knife(api):
    # Bounds [-0.022..0.022, -0.191..0.230, -0.036..0.036]
    # diver.gd contract: tip at -Y_b (+Z_g), grip center at +0.085 Y_b (-0.085 Z_g), edge at -Z_b (-Y_g), spine at +Z_b (+Y_g)
    n_sec = 28
    ys = [-0.191 + 0.196 * i / (n_sec - 1) for i in range(n_sec)]
    b_verts, b_uv, b_faces, b_slots = [], [], [], []
    for i, y in enumerate(ys):
        t = i / (n_sec - 1.0)
        tip_env = math.sin(0.5 * math.pi * min(1.0, t / 0.42)) ** 0.78 if t < 0.42 else 1.0
        z_spine = -0.004 * (1.0 - t) + 0.021 * (t ** 0.58)
        if 0.68 < t < 0.94 and i % 2 == 1:
            z_spine -= 0.0022  # crisp spine jimping notches
        belly = 0.028 * (math.sin(math.pi * min(0.95, 0.06 + 0.86 * t)) ** 0.85)
        choil = 0.006 * math.exp(-((t - 0.94) / 0.045) ** 2)
        z_edge = -0.004 * (1.0 - t) - belly + choil
        z_grind = z_edge + (z_spine - z_edge) * 0.46
        z_full_lo = z_edge + (z_spine - z_edge) * 0.62
        z_full_hi = z_edge + (z_spine - z_edge) * 0.78
        w_half = 0.0042 * tip_env * (0.35 + 0.65 * t)
        in_fuller = 0.28 < t < 0.86
        w_full = w_half * (0.52 if in_fuller else 0.94)
        ring_pts = [
            (0.0, y, z_edge),
            (w_half, y, z_grind), (w_full, y, z_full_lo), (w_full, y, z_full_hi), (w_half * 0.92, y, z_spine),
            (0.0, y, z_spine + 0.0008 * tip_env),
            (-w_half * 0.92, y, z_spine), (-w_full, y, z_full_hi), (-w_full, y, z_full_lo), (-w_half, y, z_grind),
        ]
        for j, pt in enumerate(ring_pts):
            b_verts.append(pt)
            b_uv.append((t, j / 9.0))
    ring_slots = [1, 6, 7, 6, 6, 6, 6, 7, 6, 1]
    for i in range(n_sec - 1):
        t_m = (i + 0.5) / (n_sec - 1.0)
        for j in range(10):
            jn = (j + 1) % 10
            a, b = i * 10 + j, i * 10 + jn
            c, d = (i + 1) * 10 + jn, (i + 1) * 10 + j
            b_faces.append((a, b, c, d))
            sl = ring_slots[j]
            if sl == 7 and not (0.28 < t_m < 0.86):
                sl = 6
            if j in (4, 5) and t_m > 0.56:
                sl = 2  # antique-brass spine inlay near ricasso
            b_slots.append(sl)
    api.mesh('Forged multi-bevel dive blade', b_verts, b_faces, b_uv, 6, face_slots=b_slots, smooth=False)

    # Sculpted antique-brass & ivory contoured bolster/guard (Y = 0.000 .. 0.048)
    guard_pts = [(0.0, 0.002, 0.018), (0.0, 0.016, -0.034), (0.0, 0.028, -0.022), (0.0, 0.044, 0.012)]
    _sweep(api, 'Sculpted brass lower finger guard', guard_pts,
           [(0.016, 0.012), (0.018, 0.009), (0.019, 0.012), (0.020, 0.014)], 2, sides=14)
    _sweep(api, 'Contoured ivory bolster core', [(0.0, 0.004, 0.014), (0.0, 0.026, 0.015), (0.0, 0.048, 0.014)],
           [(0.017, 0.014), (0.021, 0.017), (0.021, 0.016)], 0, sides=16)
    for sx in (-1.0, 1.0):
        api.ellipsoid('Guard recessed dark cheek inlay', (sx * 0.018, 0.024, 0.012), (0.005, 0.012, 0.009), 3, segments=10, rings=6)

    # Angled coral-red collar band (Y = 0.044 .. 0.064)
    _sweep(api, 'Angled coral-red collar', [(0.0, 0.044, 0.018), (0.0, 0.055, 0.006), (0.0, 0.064, -0.008)],
           [(0.0215, 0.015), (0.022, 0.017), (0.021, 0.014)], 5, sides=16)

    # Ergonomic palm-swell dark-navy grip + ivory/brass spine & diagonal ribs (Y = 0.056 .. 0.186)
    grip_spine = [
        (0.0, 0.056, 0.005), (0.0, 0.085, 0.010), (0.0, 0.118, 0.012),
        (0.0, 0.152, 0.008), (0.0, 0.184, -0.002),
    ]
    grip_rads = [(0.019, 0.018), (0.022, 0.022), (0.0215, 0.021), (0.0195, 0.018), (0.018, 0.017)]
    _sweep(api, 'Palm-swell dark-navy grip', grip_spine, grip_rads, 3, sides=20)
    _sweep(api, 'Handle ivory-brass belly trim',
           [(0.0, 0.064, -0.012), (0.0, 0.108, -0.008), (0.0, 0.155, -0.010), (0.0, 0.192, -0.014)],
           [(0.014, 0.006), (0.015, 0.006), (0.015, 0.007), (0.016, 0.009)], 2, sides=12)
    for r_i in range(5):
        ry = 0.074 + r_i * 0.021
        rib_loop = [Vector((0.0222 * math.cos(a), ry + 0.009 * math.sin(a), 0.009 + 0.0215 * math.sin(a)))
                    for a in range(16)]
        for idx_a in range(16):
            ang = TAU * idx_a / 16.0
            rib_loop[idx_a] = Vector((0.0222 * math.cos(ang), ry + 0.008 * math.sin(ang), 0.009 + 0.0215 * math.sin(ang)))
        _sweep(api, 'Diagonal grip rib groove', rib_loop, 0.0018, 7, sides=6, closed=True)

    # Sculpted brass pommel with lanyard eye & 3D braided coral-red lanyard
    _sweep(api, 'Sculpted brass pommel', [(0.0, 0.176, 0.002), (0.0, 0.196, -0.006), (0.0, 0.205, -0.012)],
           [(0.0185, 0.017), (0.017, 0.016), (0.012, 0.012)], 2, sides=16)
    _revolve(api, 'Pommel lanyard brass eyelet', (0.0, 0.198, -0.008), (1, 0, 0),
             [(0.0065, -0.017), (0.0105, -0.018), (0.0105, 0.018), (0.0065, 0.017)], slot=2, segs=14)
    _braided_lanyard(api, (0.0, 0.202, -0.010), (0.0, 0.228, -0.032), (0.0, 0.012, -0.016), radius=0.0038, slot=5)


def _build_weapon_axe(api):
    # Bounds [-0.023..0.023, -0.312..0.240, -0.090..0.210]
    # diver.gd contract: head at +Y_b (-Z_g), grip center at -0.14 Y_b (+0.14 Z_g), blade at +Z_b (+Y_g), rear pick at -Z_b (-Y_g)
    haft_pts = [
        (0.0, -0.278, -0.030), (0.0, -0.215, -0.008), (0.0, -0.140, 0.006),
        (0.0, -0.055, 0.012), (0.0, 0.025, 0.010), (0.0, 0.115, 0.006), (0.0, 0.175, 0.004),
    ]
    haft_rads = [(0.018, 0.022), (0.019, 0.021), (0.0185, 0.020), (0.0175, 0.019),
                 (0.018, 0.020), (0.019, 0.022), (0.016, 0.018)]
    _sweep(api, 'Curved ergonomic dark-navy haft', haft_pts[:5], haft_rads[:5], 3, sides=18)

    # 7 diagonal grip ribs along dark-navy handle
    for g_i in range(7):
        gy = -0.228 + g_i * 0.028
        gz = -0.008 + 0.018 * math.sin((g_i / 6.0) * math.pi * 0.8)
        loop = [Vector((0.0192 * math.cos(TAU * k / 16.0),
                        gy + 0.007 * math.sin(TAU * k / 16.0),
                        gz + 0.0208 * math.sin(TAU * k / 16.0))) for k in range(16)]
        _sweep(api, 'Haft grip groove', loop, 0.0019, 7, sides=6, closed=True)

    # 3 Wrapped coral-red collar bands (Y = -0.022 .. 0.032)
    for b_i in range(3):
        by = -0.016 + b_i * 0.019
        _sweep(api, 'Coral-red haft collar wrap',
               [(0.0, by - 0.008, 0.011), (0.0, by + 0.008, 0.011)],
               [(0.0198, 0.0218), (0.0198, 0.0218)], 5, sides=18)

    # Flared antique-brass pommel & 3D braided coral-red lanyard (within Y >= -0.312, Z >= -0.090)
    _sweep(api, 'Flared antique-brass pommel',
           [(0.0, -0.238, -0.015), (0.0, -0.268, -0.026), (0.0, -0.288, -0.036)],
           [(0.019, 0.022), (0.021, 0.025), (0.015, 0.019)], 2, sides=16)
    _revolve(api, 'Axe pommel lanyard eyelet', (0.0, -0.280, -0.033), (1, 0, 0),
             [(0.006, -0.020), (0.010, -0.021), (0.010, 0.021), (0.006, 0.020)], slot=2, segs=14)
    _braided_lanyard(api, (0.0, -0.284, -0.036), (0.0, -0.308, -0.084), (0.0, -0.012, -0.024), radius=0.0042, slot=5)

    # Sculpted antique-brass cheek socket & open frame arms (matching equipment.png)
    _sweep(api, 'Brass axe neck socket',
           [(0.0, 0.024, 0.010), (0.0, 0.095, 0.008), (0.0, 0.168, 0.006), (0.0, 0.212, 0.014)],
           [(0.020, 0.022), (0.021, 0.024), (0.020, 0.024), (0.012, 0.014)], 2, sides=16)
    _sweep(api, 'Brass lower beard strut',
           [(0.0, 0.068, 0.015), (0.0, 0.078, 0.058), (0.0, 0.060, 0.105)],
           [(0.017, 0.014), (0.014, 0.012), (0.011, 0.010)], 2, sides=12)
    _sweep(api, 'Brass upper blade cheek strut',
           [(0.0, 0.145, 0.012), (0.0, 0.172, 0.052), (0.0, 0.188, 0.092)],
           [(0.017, 0.014), (0.014, 0.012), (0.011, 0.010)], 2, sides=12)

    # Curved Bearded Brushed-Steel Dive Blade with front crescent cutout (Z up to +0.210, Y up to +0.240)
    n_arc = 26
    av, auv, af, aslots = [], [], [], []
    for i in range(n_arc):
        u = i / (n_arc - 1.0)
        # Outer razor edge sweeps from bearded heel (Y=0.042, Z=0.145) through peak Z=0.210 to toe (Y=0.238, Z=0.055)
        y_edge = 0.042 + 0.196 * (u ** 0.92)
        z_edge = 0.145 + 0.065 * math.sin(math.pi * (u ** 0.78)) - 0.090 * (u ** 2.2)
        # Inner back of blade has arched beard cutout + distal front crescent notch
        crescent = 0.026 * math.exp(-((u - 0.86) / 0.085) ** 2)
        y_back = 0.062 + 0.132 * u - crescent * 0.45
        z_back = 0.102 - 0.032 * math.sin(math.pi * u) - 0.042 * (u ** 1.8) + crescent
        y_bevel = y_back + (y_edge - y_back) * 0.62
        z_bevel = z_back + (z_edge - z_back) * 0.62
        thk = 0.0085 * (1.0 - 0.32 * abs(u - 0.5))
        sec = [
            (0.0, y_edge, z_edge),
            (thk * 0.68, y_bevel, z_bevel), (thk, y_back, z_back),
            (0.0, y_back - 0.003, z_back - 0.004),
            (-thk, y_back, z_back), (-thk * 0.68, y_bevel, z_bevel),
        ]
        for j, pt in enumerate(sec):
            av.append(pt)
            auv.append((u, j / 5.0))
    sec_slots = [1, 6, 2, 2, 6, 1]
    for i in range(n_arc - 1):
        for j in range(6):
            jn = (j + 1) % 6
            av_a, av_b = i * 6 + j, i * 6 + jn
            av_c, av_d = (i + 1) * 6 + jn, (i + 1) * 6 + j
            af.append((av_a, av_b, av_c, av_d))
            aslots.append(sec_slots[j])
    for cap_base, rev in ((0, True), ((n_arc - 1) * 6, False)):
        idxs = [cap_base + k for k in range(6)]
        af.append(tuple(reversed(idxs)) if rev else tuple(idxs))
        aslots.append(6)
    api.mesh('Forged bearded salvage axe blade', av, af, auv, 6, face_slots=aslots, smooth=False)

    # Sharp Curved Rear Pick Spike (extending to Z = -0.090, hooking slightly forward)
    pick_pts = [
        (0.0, 0.148, 0.002), (0.0, 0.162, -0.032), (0.0, 0.182, -0.064), (0.0, 0.208, -0.090),
    ]
    _sweep(api, 'Curved rear pick spike', pick_pts,
           [(0.013, 0.022), (0.009, 0.016), (0.0055, 0.010), (0.0012, 0.002)], 6, sides=8, smooth=False,
           face_slots_fn=lambda i, _j: 2 if i == 0 else (6 if i == 1 else 1))


def _build_weapon_sonic(api):
    # Bounds [-0.089..0.089, -0.410..0.460, -0.173..0.175]
    # diver.gd contract: gun_muzzle at +0.46 Y_b (-0.46 Z_g), pistol grip at Y_b=-0.16, Z_b=-0.10 (+0.16 Z_g, -0.10 Y_g)
    drum_c = Vector((0.0, 0.175, 0.018))

    # 1. Main Circular Ivory-Ceramic Drum Housing (radius 0.146 in YZ, width X in [-0.074..0.074])
    _revolve(api, 'Ivory sonar drum left shell', drum_c, (-1, 0, 0),
             [(0.104, 0.068), (0.132, 0.066), (0.146, 0.046), (0.148, 0.0)], slot=0, segs=36)
    _revolve(api, 'Ivory sonar drum right shell', drum_c, (1, 0, 0),
             [(0.104, 0.068), (0.132, 0.066), (0.146, 0.046), (0.148, 0.0)], slot=0, segs=36)
    _sweep(api, 'Drum equatorial brass seam',
           [drum_c + Vector((0.0, 0.149 * math.cos(TAU * k / 36.0), 0.149 * math.sin(TAU * k / 36.0)))
            for k in range(36)], 0.0035, 2, sides=6, closed=True)

    # 2. Both ±X Sides: Wide Circular Brass Bezel + Recessed Concave Sonar Dish (slot=4) + Clear Domed Glass Lens (glass=True, slot=7)
    for sx in (-1.0, 1.0):
        ax = (sx, 0.0, 0.0)
        _revolve(api, 'Wide circular brass sonar bezel', drum_c, ax,
                 [(0.096, 0.052), (0.102, 0.076), (0.122, 0.075), (0.126, 0.064)], slot=2, segs=36)
        _revolve(api, 'Recessed concave sonar grid dish', drum_c, ax,
                 [(0.0, 0.040), (0.048, 0.044), (0.082, 0.051), (0.098, 0.058)],
                 slot=4, segs=36, planar_uv=True)
        _revolve(api, 'Domed clear sonar glass lens', drum_c, ax,
                 [(0.0, 0.089), (0.052, 0.085), (0.086, 0.079), (0.101, 0.073)],
                 slot=7, segs=32, glass=True, planar_uv=True)
        # Twin side brass push-buttons right behind the sonar bezel (matching equipment.png)
        for by, bz, br in ((0.018, 0.032, 0.017), (0.032, -0.022, 0.014)):
            b_org = Vector((sx * 0.056, by, bz))
            _revolve(api, 'Side brass push-button', b_org, ax,
                     [(0.0, 0.016), (br * 0.72, 0.015), (br * 0.76, 0.006), (br, 0.005), (br * 1.08, 0.0)],
                     slot=2, segs=16, face_slots_fn=lambda i, _j: 2 if i <= 1 else 1)

    # 3. Forward Brass Emitter Nose Cone at +Y_b = +0.460 (aligned with gun_muzzle)
    _revolve(api, 'Forward emitter ceramic cowling', (0.0, 0.305, 0.018), (0, 1, 0),
             [(0.082, 0.0), (0.068, 0.065), (0.052, 0.095)], slot=0, segs=24)
    _revolve(api, 'Forward brass emitter nose cone', (0.0, 0.395, 0.018), (0, 1, 0),
             [(0.054, 0.0), (0.056, 0.022), (0.042, 0.045), (0.026, 0.062), (0.0, 0.065)],
             slot=2, segs=24, face_slots_fn=lambda i, _j: 6 if i == 2 else 2)

    # 4. Top Knurled Brass Dial Knob & Coral-Red Top/Front/Rear Bumper Pads
    dial_dir = Vector((0.0, -0.42, 0.91)).normalized()
    _revolve(api, 'Top brass rotary dial knob', (0.0, 0.105, 0.148), dial_dir,
             [(0.034, 0.0), (0.032, 0.012), (0.026, 0.026), (0.018, 0.029), (0.0, 0.029)],
             slot=2, segs=20, face_slots_fn=lambda i, _j: 3 if i == 0 else 2)
    _sweep(api, 'Coral-red top shoulder bumper',
           [(0.0, 0.052, 0.132), (0.0, 0.005, 0.108), (0.0, -0.042, 0.076)],
           [(0.036, 0.014), (0.040, 0.016), (0.034, 0.013)], 5, sides=14)
    _sweep(api, 'Coral-red lower front bumper',
           [(0.0, 0.295, -0.072), (0.0, 0.258, -0.105), (0.0, 0.215, -0.125)],
           [(0.032, 0.013), (0.036, 0.015), (0.030, 0.012)], 5, sides=12)

    # Ventral brass-rimmed sensor intake pod under the drum
    _revolve(api, 'Ventral brass sensor pod', (0.0, 0.145, -0.118), (0.0, 0.18, -0.98),
             [(0.0, 0.024), (0.036, 0.026), (0.052, 0.032), (0.058, 0.0)],
             slot=2, segs=20, face_slots_fn=lambda i, _j: 3 if i <= 1 else 2)

    # 5. Contoured Ivory Handle Neck + Ribbed Dark-Navy Grip Saddle + Sweeping Ivory/Brass Lower Bow
    neck_pts = [
        (0.0, 0.045, 0.005), (0.0, -0.045, -0.028), (0.0, -0.160, -0.068),
        (0.0, -0.275, -0.098), (0.0, -0.372, -0.118),
    ]
    neck_rads = [(0.058, 0.068), (0.044, 0.048), (0.036, 0.038), (0.035, 0.038), (0.032, 0.040)]
    _sweep(api, 'Flowing ivory handle housing', neck_pts, neck_rads, 0, sides=20)

    saddle_pts = [
        (0.0, -0.068, -0.016), (0.0, -0.160, -0.052), (0.0, -0.255, -0.078), (0.0, -0.335, -0.096),
    ]
    _sweep(api, 'Ergonomic dark-navy pistol grip saddle', saddle_pts,
           [(0.037, 0.024), (0.038, 0.028), (0.037, 0.026), (0.033, 0.022)], 3, sides=16)
    for g_i in range(5):
        t_g = (g_i + 1) / 6.0
        gy = -0.085 - t_g * 0.22
        gz = -0.026 - t_g * 0.065
        loop = [Vector((0.0385 * math.cos(TAU * k / 14.0), gy, gz + 0.028 * math.sin(TAU * k / 14.0)))
                for k in range(14)]
        _sweep(api, 'Sonic grip tactile rib', loop, 0.0020, 6, sides=6, closed=True)

    # Finger trigger rail under grip (right around Y=-0.14, Z=-0.10)
    _sweep(api, 'Acoustic trigger bar',
           [(0.0, -0.095, -0.072), (0.0, -0.155, -0.096), (0.0, -0.215, -0.108)],
           [(0.014, 0.012), (0.015, 0.014), (0.013, 0.011)], 3, sides=10)

    # Sweeping lower ivory & brass trigger-guard bow (reaching Z = -0.173)
    bow_pts = [
        (0.0, 0.115, -0.128), (0.0, 0.015, -0.156), (0.0, -0.115, -0.170),
        (0.0, -0.245, -0.166), (0.0, -0.365, -0.138),
    ]
    _sweep(api, 'Sweeping ivory trigger-guard bow', bow_pts,
           [(0.026, 0.016), (0.022, 0.014), (0.020, 0.012), (0.020, 0.013), (0.024, 0.016)], 0, sides=14)
    _sweep(api, 'Lower bow brass reinforcement trim',
           [Vector(p) + Vector((0.0, 0.0, 0.006)) for p in bow_pts],
           [(0.016, 0.008)] * len(bow_pts), 2, sides=10)

    # Coral-red & brass rear butt endcap at Y = -0.410
    _revolve(api, 'Rear coral-red butt cap', (0.0, -0.370, -0.118), (0.0, -0.97, -0.24),
             [(0.036, 0.0), (0.035, 0.016), (0.028, 0.036), (0.016, 0.041), (0.0, 0.041)],
             slot=5, segs=18, face_slots_fn=lambda i, _j: 2 if i == 0 else 5)


def _galena_crystal(api, origin, axis, yaw, wx, wy, height, bevel=0.22, bevel_slot=1, cap_slots=(1, 6)):
    origin = Vector(origin)
    u_b, v_b, w_b = _frame_basis(axis)
    cy, sy = math.cos(yaw), math.sin(yaw)
    ux, vy = u_b * cy + v_b * sy, -u_b * sy + v_b * cy
    cham = 0.26
    unit_oct = [
        (1.0, 1.0 - cham), (1.0 - cham, 1.0), (-1.0 + cham, 1.0), (-1.0, 1.0 - cham),
        (-1.0, -1.0 + cham), (-1.0 + cham, -1.0), (1.0 - cham, -1.0), (1.0, -1.0 + cham),
    ]
    levels = [(0.0, 1.04), (height * (1.0 - bevel), 0.96), (height, 0.56)]
    verts, uv, faces, fslots = [], [], [], []
    for li, (zh, sc) in enumerate(levels):
        for j, (px, py) in enumerate(unit_oct):
            pt = origin + w_b * zh + ux * (px * wx * sc) + vy * (py * wy * sc)
            verts.append(tuple(pt))
            uv.append((j / 8.0, li / 2.0))
    top_idx = len(verts)
    verts.append(tuple(origin + w_b * (height * 1.03)))
    uv.append((0.5, 1.0))
    bot_idx = len(verts)
    verts.append(tuple(origin))
    uv.append((0.5, 0.0))
    for li in range(2):
        for j in range(8):
            jn = (j + 1) % 8
            a, b = li * 8 + j, li * 8 + jn
            c, d = (li + 1) * 8 + jn, (li + 1) * 8 + j
            faces.append((a, b, c, d))
            fslots.append(bevel_slot if li == 1 else (2 if j % 2 == 1 else 6))
    for j in range(8):
        jn = (j + 1) % 8
        faces.append((16 + j, 16 + jn, top_idx))
        fslots.append(cap_slots[0] if j % 2 == 0 else cap_slots[1])
        faces.append((bot_idx, jn, j))
        fslots.append(3)
    api.mesh('Titanium galena crystal', verts, faces, uv, 6, face_slots=fslots, smooth=False)


def _build_resource_titanium(api):
    # Bounds [[-0.304, -0.238, 0], [0.311, 0.238, 0.593]]
    for bx, by, bz, rx, ry, rz, sl in [
        (0.01, 0.0, 0.075, 0.275, 0.215, 0.075, 3),
        (-0.11, -0.05, 0.105, 0.190, 0.165, 0.082, 0),
        (0.12, 0.04, 0.098, 0.185, 0.160, 0.076, 7),
        (0.02, -0.09, 0.120, 0.155, 0.130, 0.072, 3),
    ]:
        api.ellipsoid('Stratified basalt reef matrix', (bx, by, bz), (rx, ry, rz), sl,
                      segments=14, rings=8, organic=0.22)
    for cx, cy, cz, dir_v, yaw, wx, wy, h in [
        (0.01, 0.01, 0.09, (0.04, -0.03, 1.0), 0.35, 0.088, 0.082, 0.488),
        (-0.08, 0.03, 0.10, (-0.24, 0.10, 0.96), 0.92, 0.074, 0.070, 0.395),
        (0.10, -0.03, 0.09, (0.28, -0.12, 0.95), -0.48, 0.072, 0.068, 0.370),
        (-0.16, -0.06, 0.07, (-0.48, -0.20, 0.85), 0.22, 0.064, 0.060, 0.285),
        (0.17, 0.07, 0.07, (0.46, 0.22, 0.86), 1.10, 0.062, 0.058, 0.275),
        (0.02, 0.11, 0.08, (0.05, 0.44, 0.89), 0.64, 0.060, 0.055, 0.255),
        (-0.02, -0.11, 0.08, (-0.08, -0.45, 0.89), -0.75, 0.062, 0.056, 0.250),
        (-0.21, 0.07, 0.05, (-0.58, 0.24, 0.78), 0.40, 0.052, 0.048, 0.195),
        (0.22, -0.07, 0.05, (0.58, -0.22, 0.78), -0.30, 0.052, 0.048, 0.195),
        (0.07, 0.02, 0.24, (0.34, 0.08, 0.93), 0.82, 0.048, 0.045, 0.210),
        (-0.06, -0.04, 0.22, (-0.32, -0.14, 0.93), -0.52, 0.046, 0.044, 0.195),
    ]:
        _galena_crystal(api, (cx, cy, cz), dir_v, yaw, wx, wy, h)
    for b_pt in [(-0.22, -0.12, 0.09), (0.21, 0.12, 0.08), (0.04, -0.18, 0.08)]:
        _barnacle(api, b_pt, (0, 0, 1), radius=0.036, height=0.032)


def _build_resource_copper(api):
    # Bounds [[-0.304, -0.238, 0], [0.311, 0.238, 0.593]]
    for bx, by, bz, rx, ry, rz, sl in [
        (0.0, 0.0, 0.072, 0.278, 0.215, 0.072, 3),
        (-0.10, 0.04, 0.105, 0.185, 0.155, 0.078, 1),
        (0.11, -0.03, 0.100, 0.180, 0.150, 0.075, 3),
    ]:
        api.ellipsoid('Limestone host matrix', (bx, by, bz), (rx, ry, rz), sl,
                      segments=14, rings=8, organic=0.24)
    # Botryoidal banded malachite-verdigris spherules (slots 0, 5, 7)
    malachite_lobes = [
        (-0.15, -0.06, 0.15, 0.095, 0), (-0.08, -0.11, 0.18, 0.086, 5),
        (0.14, 0.07, 0.16, 0.092, 7), (0.08, 0.12, 0.19, 0.082, 0),
        (-0.19, 0.06, 0.13, 0.084, 5), (0.20, -0.06, 0.13, 0.085, 0),
        (-0.04, 0.08, 0.24, 0.078, 7), (0.05, -0.08, 0.23, 0.076, 5),
        (-0.11, 0.01, 0.27, 0.070, 0), (0.11, 0.01, 0.26, 0.068, 7),
        (0.0, -0.15, 0.13, 0.074, 0), (0.01, 0.15, 0.13, 0.072, 5),
    ]
    for mx, my, mz, mr, msl in malachite_lobes:
        api.ellipsoid('Botryoidal malachite crust', (mx, my, mz), (mr * 1.12, mr * 1.04, mr * 0.88),
                      msl, segments=14, rings=9, organic=0.08)
    # Sculpted dendritic & angular native copper nuggets/spires (slots 2, 6)
    for nx, ny, nz, axis_v, yaw, wx, wy, h in [
        (0.01, 0.0, 0.14, (0.05, -0.04, 1.0), 0.45, 0.072, 0.058, 0.442),
        (-0.07, -0.02, 0.15, (-0.26, -0.08, 0.96), 1.15, 0.062, 0.050, 0.345),
        (0.09, 0.02, 0.15, (0.30, 0.10, 0.95), -0.60, 0.058, 0.048, 0.320),
        (-0.14, 0.05, 0.12, (-0.45, 0.22, 0.86), 0.25, 0.048, 0.042, 0.235),
        (0.15, -0.05, 0.12, (0.46, -0.20, 0.86), 0.90, 0.048, 0.042, 0.225),
    ]:
        _galena_crystal(api, (nx, ny, nz), axis_v, yaw, wx, wy, h, bevel=0.30, bevel_slot=6, cap_slots=(6, 2))
    for v_pts in [
        [(-0.02, -0.03, 0.22), (0.03, -0.05, 0.38), (0.06, -0.02, 0.52)],
        [(0.02, 0.04, 0.20), (-0.04, 0.06, 0.35), (-0.08, 0.03, 0.46)],
    ]:
        _sweep(api, 'Dendritic native copper vein', v_pts, [0.024, 0.018, 0.010], 2, sides=7, smooth=False)


def _hex_crystal(api, origin, axis, yaw, radius, length, tip_frac=0.28):
    origin = Vector(origin)
    u_b, v_b, w_b = _frame_basis(axis)
    cy, sy = math.cos(yaw), math.sin(yaw)
    ux, vy = u_b * cy + v_b * sy, -u_b * sy + v_b * cy
    verts, uv, faces, fslots = [], [], [], []
    shoulder = length * (1.0 - tip_frac)
    rings = [(0.0, radius * 1.05), (shoulder * 0.45, radius * 0.98), (shoulder, radius * 0.90)]
    asym = [1.04, 0.95, 1.03, 0.96, 1.05, 0.94]
    for ri, (zh, rad) in enumerate(rings):
        for j in range(6):
            ang = TAU * j / 6.0
            r_j = rad * asym[j]
            pt = origin + w_b * zh + (ux * math.cos(ang) + vy * math.sin(ang)) * r_j
            verts.append(tuple(pt))
            uv.append((j / 6.0, ri * 0.36))
    apex_idx = len(verts)
    verts.append(tuple(origin + w_b * length + ux * (radius * 0.06)))
    uv.append((0.5, 1.0))
    bot_idx = len(verts)
    verts.append(tuple(origin))
    uv.append((0.5, 0.0))
    for ri in range(2):
        for j in range(6):
            jn = (j + 1) % 6
            a, b = ri * 6 + j, ri * 6 + jn
            c, d = (ri + 1) * 6 + jn, (ri + 1) * 6 + j
            faces.append((a, b, c, d))
            fslots.append((4 if j % 2 == 0 else 0) if ri == 1 else (7 if j % 2 == 0 else 2))
    for j in range(6):
        jn = (j + 1) % 6
        faces.append((12 + j, 12 + jn, apex_idx))
        fslots.append(1 if j % 2 == 0 else 4)
        faces.append((bot_idx, jn, j))
        fslots.append(3)
    api.mesh('Hexagonal aquamarine quartz prism', verts, faces, uv, 0, face_slots=fslots, smooth=False)


def _build_resource_quartz(api):
    # Bounds [[-0.286, -0.204, 0], [0.286, 0.204, 0.74]]
    for bx, by, bz, rx, ry, rz, sl in [
        (0.0, 0.0, 0.055, 0.215, 0.165, 0.055, 3),
        (-0.08, 0.02, 0.075, 0.145, 0.120, 0.058, 5),
        (0.09, -0.02, 0.072, 0.140, 0.115, 0.055, 3),
    ]:
        api.ellipsoid('Geode reef matrix', (bx, by, bz), (rx, ry, rz), sl, segments=14, rings=7, organic=0.22)
    prisms = [
        (0.00, 0.00, 0.05, (0.02, -0.02, 1.00), 0.20, 0.068, 0.690),
        (-0.06, 0.02, 0.06, (-0.18, 0.07, 0.98), 0.75, 0.056, 0.565),
        (0.07, -0.02, 0.06, (0.20, -0.06, 0.98), -0.45, 0.054, 0.535),
        (-0.10, -0.04, 0.05, (-0.36, -0.14, 0.92), 1.15, 0.046, 0.430),
        (0.11, 0.04, 0.05, (0.38, 0.14, 0.91), 0.35, 0.045, 0.415),
        (0.01, 0.06, 0.06, (0.04, 0.32, 0.95), 0.90, 0.044, 0.390),
        (-0.02, -0.06, 0.06, (-0.05, -0.34, 0.94), -0.80, 0.043, 0.375),
        (-0.14, 0.03, 0.04, (-0.54, 0.12, 0.83), 0.50, 0.038, 0.285),
        (0.14, -0.03, 0.04, (0.54, -0.12, 0.83), -0.25, 0.038, 0.285),
        (-0.08, 0.07, 0.04, (-0.34, 0.42, 0.84), 1.40, 0.034, 0.245),
        (0.08, -0.07, 0.04, (0.34, -0.42, 0.84), -1.10, 0.034, 0.245),
        (0.04, 0.03, 0.05, (0.14, 0.18, 0.97), 0.10, 0.036, 0.465),
    ]
    for ox, oy, oz, ax_v, yaw, rad, ln in prisms:
        _hex_crystal(api, (ox, oy, oz), ax_v, yaw, rad, ln)


def _kelp_frond(api, base, tip, side_dir, width=0.085, waves=3.5, slot=0):
    base, tip = Vector(base), Vector(tip)
    axis = (tip - base).normalized()
    lat = Vector(side_dir)
    lat = (lat - axis * lat.dot(axis)).normalized()
    nrm = axis.cross(lat).normalized()
    rows, cols = 16, 8
    verts, uv, faces, fslots = [], [], [], []
    for side_sign in (1.0, -1.0):
        for i in range(rows):
            u = i / (rows - 1.0)
            env = math.sin(math.pi * (u ** 0.72)) ** 0.78
            spine_bow = nrm * (0.032 * math.sin(math.pi * u)) + lat * (0.018 * math.sin(u * TAU * 1.1))
            center = base.lerp(tip, u) + spine_bow
            for j in range(cols):
                s = (j / (cols - 1.0)) * 2.0 - 1.0
                ruffle = math.sin(u * TAU * waves + abs(s) * 1.9) * (abs(s) ** 1.5) * width * 0.26 * env
                rib_thk = (0.0045 * (1.0 - 0.65 * abs(s)) + 0.0018) * (1.0 - 0.55 * u)
                pt = center + lat * (s * width * env) + nrm * (ruffle + side_sign * rib_thk)
                verts.append(tuple(pt))
                uv.append(((s + 1.0) * 0.5, u))
    stride = rows * cols
    for s_idx in range(2):
        base_v = s_idx * stride
        for i in range(rows - 1):
            for j in range(cols - 1):
                a = base_v + i * cols + j
                b = a + 1
                c = a + cols + 1
                d = a + cols
                faces.append((a, d, c, b) if s_idx == 1 else (a, b, c, d))
                is_midrib = (j == 3 and i < rows - 2)
                is_margin = j in (0, cols - 2) or i >= rows - 2
                fslots.append(1 if is_midrib else (2 if is_margin else slot))
    api.mesh('Ruffled kelp frond', verts, faces, uv, slot, face_slots=fslots, smooth=True)


def _build_resource_kelp(api):
    # Bounds [[-0.299, -0.152, 0], [0.31, 0.201, 0.7]]
    stipes = [
        [(-0.035, -0.015, 0.00), (-0.018, -0.006, 0.15), (-0.055, 0.020, 0.40), (-0.095, 0.045, 0.66)],
        [(0.035, 0.012, 0.00), (0.016, 0.008, 0.15), (0.062, -0.018, 0.42), (0.105, -0.035, 0.67)],
        [(0.005, -0.032, 0.00), (0.004, -0.014, 0.15), (0.012, 0.042, 0.44), (0.018, 0.075, 0.69)],
        [(-0.015, 0.028, 0.00), (-0.008, 0.012, 0.15), (-0.025, -0.038, 0.38), (-0.042, -0.065, 0.62)],
    ]
    for s_pts in stipes:
        _sweep(api, 'Harvested kelp stipe', s_pts, [0.016, 0.014, 0.011, 0.007], 5, sides=9)
    # Braided harvest twine wrap around gathered stipes at Z = 0.13..0.17
    for k in range(3):
        zk = 0.132 + k * 0.016
        ring_pts = [Vector((0.042 * math.cos(TAU * j / 16.0), 0.036 * math.sin(TAU * j / 16.0), zk))
                    for j in range(16)]
        _sweep(api, 'Harvest binder cord', ring_pts, 0.0075, 3 if k == 1 else 1, sides=7, closed=True)

    frond_specs = [
        ((-0.02, 0.00, 0.18), (-0.285, 0.035, 0.56), (-0.35, 0.92, 0.15), 0.082, 0),
        ((0.02, 0.00, 0.19), (0.295, -0.025, 0.58), (0.32, 0.93, -0.12), 0.084, 7),
        ((-0.03, 0.02, 0.26), (-0.215, 0.145, 0.65), (-0.65, -0.72, 0.18), 0.078, 2),
        ((0.03, -0.02, 0.27), (0.225, -0.115, 0.66), (0.68, 0.70, 0.15), 0.076, 0),
        ((0.00, 0.03, 0.30), (0.035, 0.188, 0.70), (0.96, -0.22, 0.10), 0.080, 7),
        ((0.00, -0.02, 0.24), (-0.025, -0.140, 0.63), (0.95, 0.25, -0.12), 0.074, 5),
        ((-0.05, 0.01, 0.36), (-0.155, -0.065, 0.69), (0.45, 0.88, 0.14), 0.068, 2),
        ((0.05, 0.01, 0.37), (0.165, 0.115, 0.69), (-0.48, 0.86, 0.12), 0.068, 0),
        ((0.01, 0.01, 0.40), (-0.015, 0.035, 0.70), (0.88, 0.45, 0.08), 0.065, 7),
    ]
    for b_p, t_p, s_d, wd, sl in frond_specs:
        _kelp_frond(api, b_p, t_p, s_d, width=wd, waves=3.6, slot=sl)

    # Glossy golden-amber gas bladders (pneumatocysts)
    bladders = [
        (-0.055, 0.025, 0.24, (-0.65, 0.30, 0.70)), (0.058, -0.020, 0.25, (0.68, -0.25, 0.69)),
        (-0.075, 0.055, 0.38, (-0.58, 0.45, 0.68)), (0.080, -0.045, 0.40, (0.60, -0.40, 0.69)),
        (0.022, 0.065, 0.36, (0.20, 0.72, 0.66)), (-0.030, -0.055, 0.34, (-0.25, -0.70, 0.67)),
        (-0.095, 0.020, 0.51, (-0.62, 0.20, 0.76)), (0.100, 0.025, 0.52, (0.62, 0.22, 0.75)),
    ]
    for px, py, pz, pdir in bladders:
        _revolve(api, 'Golden kelp gas bladder', (px, py, pz), pdir,
                 [(0.005, 0.0), (0.018, 0.016), (0.025, 0.036), (0.019, 0.055), (0.004, 0.068), (0.0, 0.071)],
                 slot=4, segs=12, face_slots_fn=lambda i, _j: 5 if i == 0 else (1 if i == 3 else 4))


def register(api):
    api.PALETTES.update({
        'pod': ['ebe3d0', 'f5efe2', 'c99a49', '22354d', 'ffcf75', 'd95a43', '9aa6ab', '4b8996'],
        'shipwreck': ['548b82', 'b9b0a0', '9e5a36', '1d2b31', '96d4cc', 'd96862', '7c8f92', '488892'],
        'weapon_knife': ['ebe2ce', 'e2e8ec', 'cca050', '223145', '6ce0d6', 'd9563e', 'bcc5ca', '151f2d'],
        'weapon_axe': ['ebe2ce', 'e2e8ec', 'cca050', '223145', '6ce0d6', 'd9563e', 'bcc5ca', '151f2d'],
        'weapon_sonic': ['ebe2ce', 'ded5c1', 'cca050', '223145', '6ce0d6', 'd9563e', '34465c', '4b8996'],
        'resource_titanium': ['6d858f', 'e2e7ea', '9eb0b5', '2d3f47', 'c8dcdf', '7f969c', 'bcc9ce', '526870'],
        'resource_copper': ['4d856d', 'd4ccb0', 'cc763c', '2f4239', 'e2d2b4', '659e82', 'df9256', '78ab90'],
        'resource_quartz': ['6fd4c2', 'ebfffb', '4db5a8', '1f4f52', 'c4fff5', '4ea0a5', 'bce3de', '8ae8d9'],
        'resource_kelp': ['4d8a3d', 'c4d458', '88ab41', '2a4a28', 'e6bd45', '689940', '7fa368', '74a844'],
    })
    _install_painters(api)
    builders = {
        'pod': _build_pod,
        'shipwreck': _build_shipwreck,
        'weapon_knife': _build_weapon_knife,
        'weapon_axe': _build_weapon_axe,
        'weapon_sonic': _build_weapon_sonic,
        'resource_titanium': _build_resource_titanium,
        'resource_copper': _build_resource_copper,
        'resource_quartz': _build_resource_quartz,
        'resource_kelp': _build_resource_kelp,
    }
    for asset_name, fn in builders.items():
        setattr(api, 'create_' + asset_name, lambda f=fn: f(api))
