"""Ethereal sculpted Siren/Mermaid face, jewel eyes, ear-fins, pearl-crystal tiara & cascading waves.

All positions are Godot-local (+Y up, -Z forward). The head exposes a luminous
porcelain V-line face, large starry aquamarine eyes, glossy coral-rose lips,
pleated translucent siren ear-fins, and long multi-layered flowing hair waves.
"""
import math


TAU = math.tau


def _head_surface(api, name, vertices, faces, material, driver='head', uv=None, deform_mode=None):
    if driver == 'head':
        vertices = [(x, y + .065, z - .005) for x, y, z in vertices]
    return api.surface(name, vertices, faces, material, driver=driver, uv=uv, deform_mode=deform_mode)


def _lerp(a, b, t):
    return tuple(x + (y - x) * t for x, y in zip(a, b))


def _catmull(points, steps=8):
    result = []
    for index in range(len(points) - 1):
        p0 = points[max(0, index - 1)]
        p1, p2 = points[index:index + 2]
        p3 = points[min(len(points) - 1, index + 2)]
        for sample in range(steps):
            t = sample / steps
            result.append(tuple(.5 * (2 * b + (-a + c) * t +
                (2 * a - 5 * b + 4 * c - d) * t * t +
                (-a + 3 * b - 3 * c + d) * t * t * t)
                for a, b, c, d in zip(p0, p1, p2, p3)))
    result.append(tuple(points[-1]))
    return result


def _ellipsoid(api, name, center, radius, material, segments=32, rings=20,
               driver='head', deform_mode=None, planar_xy_uv=False):
    vertices = [(center[0], center[1] + radius[1], center[2])]
    uv = [(.5, 1.0)] if planar_xy_uv else [(.5, 1)]
    faces = []
    for i in range(1, rings):
        theta = i / rings * math.pi
        for j in range(segments):
            phi = j / segments * TAU
            lx = math.sin(theta) * math.cos(phi)
            ly = math.cos(theta)
            lz = math.sin(theta) * math.sin(phi)
            vertices.append((center[0] + radius[0] * lx,
                             center[1] + radius[1] * ly,
                             center[2] + radius[2] * lz))
            if planar_xy_uv:
                uv.append((.5 + .5 * lx, .5 + .5 * ly))
            else:
                uv.append((j / segments, 1 - i / rings))
    bottom = len(vertices)
    vertices.append((center[0], center[1] - radius[1], center[2]))
    uv.append((.5, 0.0) if planar_xy_uv else (.5, 0))
    for j in range(segments):
        k = (j + 1) % segments
        faces.append((0, 1 + k, 1 + j))
        for i in range(rings - 2):
            a, b = 1 + i * segments + j, 1 + i * segments + k
            faces.append((a, b, b + segments, a + segments))
        a, b = 1 + (rings - 2) * segments + j, 1 + (rings - 2) * segments + k
        faces.append((a, b, bottom))
    return _head_surface(api, name, vertices, faces, material, driver=driver, uv=uv, deform_mode=deform_mode)


def _tube(api, name, path, radii, material, sides=8, smooth_steps=3,
          driver='head', flatten=1.0, deform_mode=None):
    from mathutils import Vector
    if smooth_steps > 1:
        path = _catmull(path, smooth_steps)
        old = list(radii)
        radii = []
        for i in range(len(old) - 1):
            radii.extend(old[i] + (old[i + 1] - old[i]) * j / smooth_steps
                         for j in range(smooth_steps))
        radii.append(old[-1])
    path = [Vector(p) for p in path]
    vertices, faces, uv = [], [], []
    for i, point in enumerate(path):
        tangent = (path[min(i + 1, len(path) - 1)] - path[max(0, i - 1)]).normalized()
        normal = tangent.cross(Vector((0, 0, 1)))
        if normal.length < .01:
            normal = tangent.cross(Vector((0, 1, 0)))
        normal.normalize()
        cross = tangent.cross(normal).normalized()
        r = max(.00032, radii[i])
        for j in range(sides):
            a = j / sides * TAU
            vertices.append(tuple(point + (normal * math.cos(a) + cross * (math.sin(a) * flatten)) * r))
            uv.append((j / sides, i / max(1, len(path) - 1)))
            if i:
                a0 = (i - 1) * sides + j
                a1 = (i - 1) * sides + (j + 1) % sides
                faces.append((a0, a1, a1 + sides, a0 + sides))
    for end in (0, len(path) - 1):
        center = len(vertices)
        vertices.append(tuple(path[end]))
        uv.append((.5, .5))
        for j in range(sides):
            a, b = end * sides + j, end * sides + (j + 1) % sides
            faces.append((center, b, a) if end == 0 else (center, a, b))
    return _head_surface(api, name, vertices, faces, material, driver=driver, uv=uv, deform_mode=deform_mode)


def _thick_petal(api, name, grid, thickness, material, driver='head', deform_mode=None, taper_top=False):
    """Build a watertight 3D thin shell from a (rows x cols) 3D coordinate grid."""
    from mathutils import Vector
    rows = len(grid)
    cols = len(grid[0])
    verts, uv, faces = [], [], []
    for shell in (0, 1):
        sgn = .5 if shell == 0 else -.5
        for r in range(rows):
            tr = r / max(1, rows - 1)
            t_fade = 1.0 - .58 * tr
            if taper_top:
                t_fade *= min(1.0, .18 + 3.6 * tr)
            for c in range(cols):
                p = Vector(grid[r][c])
                p_u = Vector(grid[r][min(cols - 1, c + 1)]) - Vector(grid[r][max(0, c - 1)])
                p_v = Vector(grid[min(rows - 1, r + 1)][c]) - Vector(grid[max(0, r - 1)][c])
                nrm = p_u.cross(p_v)
                if nrm.length < 1e-8:
                    nrm = Vector((0, 0, 1))
                else:
                    nrm.normalize()
                pt = p + nrm * (thickness * t_fade * sgn)
                verts.append((pt.x, pt.y, pt.z))
                uv.append((c / max(1, cols - 1), r / max(1, rows - 1)))
    stride = rows * cols
    for sh in (0, 1):
        for r in range(rows - 1):
            for c in range(cols - 1):
                k = sh * stride + r * cols + c
                q = (k, k + 1, k + cols + 1, k + cols)
                faces.append(q if sh == 0 else tuple(reversed(q)))
    for r in range(rows - 1):
        for c, flip in ((0, True), (cols - 1, False)):
            a, b = r * cols + c, (r + 1) * cols + c
            q = (a, b, b + stride, a + stride)
            faces.append(q if flip else tuple(reversed(q)))
    for r, flip in ((0, False), (rows - 1, True)):
        for c in range(cols - 1):
            a = r * cols + c
            q = (a, a + 1, a + 1 + stride, a + stride)
            faces.append(q if flip else tuple(reversed(q)))
    return _head_surface(api, name, verts, faces, material, driver=driver, uv=uv, deform_mode=deform_mode)


def _face(api):
    # Delicate heart/oval V-line siren head proportions:
    # (y, half_width, z_front, z_back)
    profile = [
        (-.058, .008, -.044, .006),
        (-.051, .019, -.051, .015),
        (-.038, .032, -.054, .029),
        (-.020, .045, -.056, .044),
        (-.002, .055, -.057, .056),
        (.016, .058, -.057, .063),
        (.038, .057, -.055, .065),
        (.063, .053, -.049, .063),
        (.085, .045, -.037, .054),
        (.103, .029, -.019, .036),
        (.113, .008, -.002, .010),
    ]
    rows = _catmull(profile, 7)
    sides = 80
    vertices, uv, faces = [], [], []

    def gaussian(x, y, cx, cy, sx, sy):
        return math.exp(-((x - cx) / sx) ** 2 - ((y - cy) / sy) ** 2)

    def relief_at(x, y):
        relief = .0054 * gaussian(x, y, 0, .006, .0068, .019)
        relief += .0116 * gaussian(x, y, 0, -.010, .0065, .0085)
        relief += .0026 * gaussian(x, y, 0, -.015, .0036, .0044)
        relief += .0042 * gaussian(x, y, 0, -.050, .014, .0090)
        relief += .0036 * gaussian(x, y, 0, -.031, .019, .010)
        relief += .0028 * gaussian(x, y, 0, .043, .036, .023)
        for side in (-1, 1):
            relief += .0025 * gaussian(x, y, side * .0074, -.013, .0046, .0045)
            relief += .0066 * gaussian(x, y, side * .028, -.003, .021, .018)
            relief += .0026 * gaussian(x, y, side * .023, .029, .019, .0075)
            relief -= .0046 * gaussian(x, y, side * .0230, .0115, .0162, .0108)
        return relief

    def front_at(x, y):
        section = rows[-1]
        for a, b in zip(rows, rows[1:]):
            if a[0] <= y <= b[0]:
                section = _lerp(a, b, (y - a[0]) / max(1e-8, b[0] - a[0]))
                break
        _, width, front, back = section
        facing = math.sqrt(max(.0001, 1 - (x / max(width, .001)) ** 2))
        base = (front + back) / 2 - (back - front) / 2 * facing
        return base - relief_at(x, y) * (facing ** 3.2)

    for i, (y, width, front, back) in enumerate(rows):
        for j in range(sides):
            angle = j / sides * TAU
            x = math.sin(angle) * width
            z = (front + back) / 2 + (back - front) / 2 * math.cos(angle)
            weight = max(0., -math.cos(angle)) ** 3.2
            vertices.append((x, y, z - relief_at(x, y) * weight))
            u_coord = .5 + math.atan2(x, -z) / TAU
            uv.append((u_coord % 1.0, i / (len(rows) - 1)))
    for i in range(1, len(rows)):
        for j in range(sides):
            a = (i - 1) * sides + j
            b = (i - 1) * sides + (j + 1) % sides
            faces.append((a, b, b + sides, a + sides))
    for i in (0, len(rows) - 1):
        y, _, front, back = rows[i]
        center = len(vertices)
        vertices.append((0, y, (front + back) / 2))
        uv.append((.5, .5))
        for j in range(sides):
            a, b = i * sides + j, i * sides + (j + 1) % sides
            faces.append((center, b, a) if i == 0 else (center, a, b))
    _head_surface(api, 'SculptedHumanFace', vertices, faces, 'skin', driver='head', uv=uv)

    for side, label in ((-1, 'Left'), (1, 'Right')):
        eye_x = side * .0228
        eye_y = .0115
        surf_z = front_at(eye_x, eye_y)
        eye_z = surf_z + .0040
        eye_front = eye_z - .0060
        _ellipsoid(api, label + 'RecessedSclera', (eye_x, eye_y, eye_z),
                   (.0134, .0082, .0060), 'eye_white', 28, 16)
        # Large soulful ocean-gem iris tucked slightly under upper lash so there is zero startled white gap!
        iris_x = eye_x - side * .0007
        iris_y = eye_y + .0009
        _ellipsoid(api, label + 'OceanGemIris', (iris_x, iris_y, eye_front - .00045),
                   (.0081, .0086, .0012), 'iris', 30, 16, planar_xy_uv=True)
        _ellipsoid(api, label + 'Pupil', (iris_x, iris_y - .0002, eye_front - .00140),
                   (.0035, .0038, .0005), 'pupil', 22, 12)
        _ellipsoid(api, label + 'EyeCatchlight', (iris_x - .0025, iris_y + .0026, eye_front - .00185),
                   (.00195, .00195, .00035), 'eye_white', 14, 10)
        _ellipsoid(api, label + 'EyeCatchlightSub', (iris_x + .0024, iris_y - .0022, eye_front - .00180),
                   (.00095, .00095, .00030), 'eye_white', 12, 8)

        upper, lower = [], []
        for i in range(19):
            t = i / 18
            x = eye_x + side * (.0142 * (2 * t - 1))
            arch = math.sin(t * math.pi) ** .74
            slant = (t - .5) * .0028
            uy = eye_y + arch * .0065 + slant
            ly = eye_y - arch * .0055 + slant * .55
            dome_push = .0034 * math.sin(t * math.pi)
            upper.append((x, uy, front_at(x, uy) - .0011 - dome_push))
            lower.append((x, ly, front_at(x, ly) - .0008 - dome_push * .78))
        _tube(api, label + 'UpperEyelid', upper,
              [.0011 + .0007 * math.sin(i / 18 * math.pi) for i in range(19)], 'skin', 8, 1)
        _tube(api, label + 'LowerEyelid', lower,
              [.00085 + .00050 * math.sin(i / 18 * math.pi) for i in range(19)], 'skin', 7, 1)

        lashes = [(x + (side * .0028 if i == 18 else 0),
                   y + (.0010 if i == 18 else .0001),
                   z - .0010) for i, (x, y, z) in enumerate(upper)]
        _tube(api, label + 'ThickUpperLashLine', lashes,
              [.00055 + .00105 * (math.sin(i / 18 * math.pi) ** .62) for i in range(19)], 'lash', 7, 1)
        for w_i, t_pos in enumerate((.58, .72, .85, .96)):
            idx = int(round(t_pos * 18))
            bx, by, bz = upper[idx]
            wing_len = .0034 + .0013 * w_i
            lash_fan = [
                (bx, by, bz - .0006),
                (bx + side * wing_len * .58, by + wing_len * .48, bz - .0016),
                (bx + side * wing_len * 1.18, by + wing_len * .96, bz - .0020),
            ]
            _tube(api, f'{label}WingEyelash{w_i}', lash_fan, [.00072, .00046, .00018], 'lash', 6, 2)

        fold = [(x, y + .0024, z + .0005) for (x, y, z) in upper[2:-2]]
        _tube(api, label + 'DoubleEyelidFold', fold, [.00030] * len(fold), 'skin_shadow', 5, 1)

        # Gentle, serene willow-arch eyebrows (sweet & enchanting, not high/startled)
        brow_pts = [(.0082, .0252), (.0185, .0286), (.0305, .0292), (.0405, .0258)]
        brow = [(side * bx, by, front_at(side * bx, by) - .0012) for bx, by in brow_pts]
        _tube(api, label + 'ShapedEyebrow', brow, [.0010, .00145, .00115, .00038], 'lash', 7, 3)

        nostril = []
        for i in range(9):
            t = i / 8
            x = side * (.0030 + .0038 * t)
            y = -.0152 - .0006 * math.sin(t * math.pi)
            nostril.append((x, y, front_at(x, y) - .00025))
        _tube(api, label + 'SubtleNostrilCrease', nostril,
              [.00022 + .00015 * math.sin(i / 8 * math.pi) for i in range(9)], 'skin_shadow', 5, 1)

    mouth_y = -.0312
    half_mouth = .0130
    for upper in (True, False):
        corner_y = mouth_y + .0020
        vertices, faces, uv = [(-half_mouth, corner_y, front_at(-half_mouth, corner_y) - .0002)], [], [(0, .5)]
        cols = 26
        for i in range(1, cols):
            t = i / cols
            x = (t - .5) * (2 * half_mouth)
            taper = math.sin(t * math.pi) ** .72
            cupid = math.exp(-((abs(x) - .0036) / .0030) ** 2)
            dip = math.exp(-(x / .0020) ** 2)
            smile = .0020 * ((2 * t - 1) ** 2)
            mid_y = mouth_y + smile - .00035 * math.cos(t * TAU)
            thickness = (.0038 + .0018 * cupid - .0008 * dip) if upper else .0056
            for j in range(7):
                v = j / 6
                y = mid_y + (1 if upper else -1) * thickness * taper * v
                pillow = (.0028 if upper else .0037) * math.sin(v * math.pi) * taper
                z = front_at(x, y) - .0003 - pillow
                vertices.append((x, y, z))
                uv.append((t, v))
                if i > 1 and j:
                    a = 1 + (i - 2) * 7 + j - 1
                    faces.append((a, a + 1, a + 8, a + 7))
        for j in range(6):
            faces.append((0, 1 + j, 2 + j))
        end = len(vertices)
        vertices.append((half_mouth, corner_y, front_at(half_mouth, corner_y) - .0002))
        uv.append((1, .5))
        for j in range(6):
            faces.append((end, 1 + (cols - 2) * 7 + j + 1, 1 + (cols - 2) * 7 + j))
        if upper:
            faces = [tuple(reversed(face)) for face in faces]
        _head_surface(api, 'CupidBowUpperLip' if upper else 'NaturalLowerLip', vertices, faces, 'lip', driver='head', uv=uv)
    crease = [((i / 20 - .5) * (2 * half_mouth * .94),
               mouth_y + .0020 * ((2 * (i / 20) - 1) ** 2) - .00035 * math.cos(i / 20 * TAU),
               front_at((i / 20 - .5) * (2 * half_mouth * .94), mouth_y) - .0009)
              for i in range(21)]
    _tube(api, 'SmilingMouthCrease', crease,
          [.00020 + .00015 * math.sin(i / 20 * math.pi) for i in range(21)], 'skin_shadow', 5, 1)


def _ear_fins(api):
    """Pleated translucent pearlescent Siren ear-fins with golden rays & dangling pearls."""
    for side, label in ((-1, 'Left'), (1, 'Right')):
        base_x, base_y, base_z = side * .055, .005, .005
        _ellipsoid(api, label + 'DelicateEarBase', (base_x, base_y, base_z), (.007, .015, .010), 'skin', 18, 12)
        rows_e, cols_e = 11, 17
        veil_grid = []
        for r in range(rows_e):
            tr = r / (rows_e - 1)
            row_pts = []
            for c in range(cols_e):
                tc = c / (cols_e - 1)
                ang = -.32 + tc * 1.18
                scallop = 1.0 + .09 * math.cos(tc * math.pi * 4.0) * (tr ** 1.4)
                reach = (.006 + .052 * (tr ** .88)) * scallop
                pleat = .0032 * math.sin(tc * math.pi * 4.0) * tr
                px = base_x + side * (reach * (.72 + .22 * math.sin(ang)))
                py = base_y + reach * math.sin(ang) * .88
                pz = base_z + reach * (.62 + .25 * math.cos(ang)) + pleat
                row_pts.append((px, py, pz))
            veil_grid.append(row_pts)
        _thick_petal(api, label + 'SirenEarFinGlassVeil', veil_grid, .0016, 'glass')
        for ray_i in range(5):
            c_idx = int(round(ray_i / 4 * (cols_e - 1)))
            ray_pts = [veil_grid[r][c_idx] for r in range(rows_e)]
            _tube(api, f'{label}SirenEarFinRay{ray_i}', ray_pts,
                  [.0016 * (1.0 - .62 * r / (rows_e - 1)) for r in range(rows_e)],
                  'gold_light' if ray_i in (0, 4) else 'fin_pearl', 6, 2)
        _tube(api, label + 'EarringGoldLink',
              [(side * .058, -.009, .004), (side * .061, -.023, .005)], [.0007, .0007], 'gold_light', 6, 1)
        _ellipsoid(api, label + 'EarringPearlDrop', (side * .061, -.028, .005),
                   (.0042, .0054, .0042), 'pearl', 18, 14)


def _crown(api):
    """Ethereal Sea-Gold Filigree Tiara with faceted Aquamarine Teardrop & Akoya Pearls."""
    upper_arc, lower_arc = [], []
    for i in range(41):
        u = i / 40 * 2.0 - 1.0
        ang = u * 1.18
        rx, rz = .065, .071
        x = rx * math.sin(ang)
        z = .008 - rz * math.cos(ang)
        y_up = .062 + .024 * math.exp(-(u / .34) ** 2) - .006 * (u ** 2)
        y_lo = .052 - .008 * math.exp(-(u / .28) ** 2) + .004 * (u ** 2)
        upper_arc.append((x, y_up, z - .003))
        lower_arc.append((x, y_lo, z - .0035))
    _tube(api, 'TiaraUpperGoldFiligree', upper_arc,
          [.0018 + .0010 * math.exp(-((i / 20 - 1) / .35) ** 2) for i in range(41)], 'gold', 8, 1)
    _tube(api, 'TiaraLowerGoldFiligree', lower_arc, [.0014] * 41, 'gold_light', 7, 1)

    cx, cy, cz = 0.0, .064, -.065
    _ellipsoid(api, 'TiaraCenterGoldBezel', (cx, cy, cz + .0015), (.0088, .0128, .0032), 'gold', 24, 14)
    _ellipsoid(api, 'TiaraCenterCrystalGlassVisor', (cx, cy, cz - .0012), (.0068, .0105, .0042), 'glass', 24, 14)
    _ellipsoid(api, 'TiaraForeheadPearlDrop', (0.0, .045, -.064), (.0036, .0044, .0036), 'pearl', 18, 12)

    for side, tag in ((-1, 'L'), (1, 'R')):
        for k, (u_p, pr) in enumerate(((.24, .0036), (.48, .0031), (.72, .0026), (.92, .0022))):
            ang = side * u_p * 1.18
            px = .066 * math.sin(ang)
            pz = .008 - .072 * math.cos(ang) - .003
            py = .062 + .020 * math.exp(-(u_p / .36) ** 2) - .004 * (u_p ** 2) + .004
            _ellipsoid(api, f'TiaraCrownPearl{tag}{k}', (px, py, pz), (pr, pr, pr), 'pearl', 16, 12)
        for sp_u, sp_h in ((.14, .016), (.34, .011)):
            ang = side * sp_u * 1.18
            sx, sz = .065 * math.sin(ang), .008 - .071 * math.cos(ang) - .003
            sy = .062 + .020 * math.exp(-(sp_u / .36) ** 2)
            _tube(api, f'TiaraStarSpire{tag}{sp_u}',
                  [(sx, sy, sz), (sx + side * .002, sy + sp_h, sz + .002)],
                  [.0015, .00035], 'gold_light', 6, 1)


def _hair(api):
    # 1. Seamless sculpted cranium cap tapering smoothly into the nape (zero flat shelf!)
    sides, rings = 60, 22
    vertices, faces, uv = [(.005, .124, .010)], [], [(.5, 0)]
    for i in range(1, rings + 1):
        v = i / rings
        for j in range(sides):
            a = j / sides * TAU
            front = max(0.0, -math.cos(a))
            limit = 2.38 - 1.34 * (front ** 2.10)
            theta = v * limit
            nape_taper = 1.0 - .28 * max(0.0, (theta - 1.75) / .65) ** 1.4
            wave = .0028 * (.5 + .5 * math.sin(a * 8.0 + v * 4.5)) * math.sin(theta)
            x = (.0665 + wave) * nape_taper * math.sin(theta) * math.sin(a)
            y = .020 + (.104 + .0028 * math.sin(a + .35)) * math.cos(theta)
            z = .011 + (.074 + wave) * nape_taper * math.sin(theta) * math.cos(a)
            vertices.append((x, y, z))
            uv.append((j / sides, v))
            if i == 1:
                faces.append((0, 1 + (j + 1) % sides, 1 + j))
            else:
                a0, a1 = 1 + (i - 2) * sides + j, 1 + (i - 2) * sides + (j + 1) % sides
                faces.append((a0, a1, a1 + sides, a0 + sides))
    _head_surface(api, 'SidePartedMermaidHairCap', vertices, faces, 'hair', driver='head', uv=uv)

    # 2. Voluminous continuous sculpted Mermaid Hair Mantle (seamless from crown down to waist, zero gaps!)
    def _hair_canopy_point(u, t_eff):
        # Smoothly follow the spherical cranium cap for t_eff in [0, 0.26], then cascade down the back!
        if t_eff <= .26:
            s = t_eff / .26
            theta = .34 + s * 1.18  # 0.34 rad (crown top inside cap) -> 1.52 rad (equator/occiput)
            az = u * 1.24           # wraps around left/right temples to back
            rx = .065 + .008 * s
            ry = .103
            rz = .072 + .012 * s
            px = rx * math.sin(theta) * math.sin(az)
            py = .020 + ry * math.cos(theta)
            pz = .011 + rz * math.sin(theta) * math.cos(az)
            return px, py, pz
        # Below occiput (t_eff > 0.26): C1-continuous tangent straight down into lush S-waves!
        s = (t_eff - .26) / .74
        az0 = u * 1.24
        x0 = .073 * math.sin(1.52) * math.sin(az0)
        y0 = .020 + .103 * math.cos(1.52)
        z0 = .011 + .084 * math.sin(1.52) * math.cos(az0)
        fan_w = (.073 + .082 * math.sin(s * math.pi * .76)) * (1.0 - .10 * (s ** 2.2))
        px = x0 * (1.0 - s) + (u * fan_w) * s + .012 * math.sin(s * TAU * 1.15 + u * 1.4) * (s ** .8)
        py = y0 - .395 * (s ** 1.02)
        s_wave_z = .016 * math.sin(s * TAU * 1.25 - .35) * (s ** .75)
        pz = z0 + .024 * (s ** .85) + s_wave_z + .014 * (u ** 2) * s
        return px, py, pz

    m_rows, m_cols = 30, 39
    mantle_grid = []
    for r in range(m_rows):
        tr = r / (m_rows - 1)
        row = []
        for c in range(m_cols):
            tc = c / (m_cols - 1)
            u = tc * 2.0 - 1.0  # -1 (left) to +1 (right)
            # Scalloped multi-lock mermaid hemline at bottom
            tip_scallop = 1.0 - .14 * (1.0 - math.cos(tc * math.pi * 7.0)) * .5 * (tr ** 2.2)
            t_eff = tr * tip_scallop
            px, py, pz = _hair_canopy_point(u, t_eff)
            flute_fade = max(0.0, (tr - .18) / .82) * math.sin(tr * math.pi * .92)
            pz += .0065 * math.cos(tc * math.pi * 7.0) * flute_fade
            row.append((px, py, pz))
        mantle_grid.append(row)
    _thick_petal(api, 'FlowingMermaidHairMantle', mantle_grid, .0125, 'hair',
                 driver='head', deform_mode='long_hair', taper_top=True)

    # 3. Harmonized wide silk-ribbon locks over the mantle + face-framing curtain bangs
    for k, u0 in enumerate((-.78, -.46, -.16, .16, .46, .78)):
        rib_rows, rib_cols = 18, 7
        rib_grid = []
        mat = 'hair_highlight' if k in (1, 4) else 'hair'
        for r in range(rib_rows):
            tr = r / (rib_rows - 1)
            t_rib = .06 + .92 * tr
            row = []
            w_lock = .024 * math.sin(min(1.0, .18 + tr * .82) * math.pi * .88) * (1.0 - .65 * (tr ** 2.2))
            cx, cy, cz = _hair_canopy_point(u0, t_rib)
            cx += .008 * math.sin(tr * TAU * 1.2 + k) * (tr ** .7)
            cz += .0055 * math.sin(min(1.0, tr / .22) * math.pi * .5)
            for c in range(rib_cols):
                uc = (c / (rib_cols - 1)) * 2.0 - 1.0
                arch_z = .0035 * (1.0 - uc * uc) * (1.0 - .5 * tr)
                row.append((cx + uc * w_lock, cy, cz + arch_z))
            rib_grid.append(row)
        _thick_petal(api, f'CascadingSilkHairRibbon{k}', rib_grid, .0055, mat,
                     driver='head', deform_mode='long_hair', taper_top=True)

    part_x = .006
    for side, tag in ((-1, 'L'), (1, 'R')):
        # Sweeping wide curtain bangs framing forehead, temples & cheekbones
        for k in range(3):
            yk = k * .0045
            zk = k * .0055
            mat = 'hair_highlight' if k == 1 else 'hair'
            path = [
                (part_x + side * .003, .118 - yk * .20, -.024 + zk),
                (side * (.030 + k * .005), .096 - yk * .35, -.056 + zk * .6),
                (side * (.058 + k * .004), .054 - yk * .50, -.047 + zk * .8),
                (side * (.068 + k * .003), .008 - yk * .45, -.016 + zk),
                (side * (.072 + k * .003), -.042 - k * .008, .018 + zk),
                (side * (.076 + k * .004), -.096 - k * .010, .038 + zk),
            ]
            radii = [.0105, .0165, .0168, .0142, .0105, .0032]
            _tube(api, f'WavyCurtainLock{tag}{k}', path, radii, mat, 10, 4, flatten=.38, deform_mode='long_hair')

        tendril = [
            (side * .044, .072, -.049),
            (side * .058, .038, -.044),
            (side * .055, .004, -.033),
            (side * .061, -.030, -.018),
            (side * .066, -.062, -.004),
        ]
        _tube(api, 'TempleWaveTendril' + tag, tendril,
              [.0042, .0056, .0046, .0030, .0008], 'hair_highlight', 8, 4, flatten=.42, deform_mode='long_hair')

        # Wide silk ribbons draped cleanly over outer clavicles (|x| >= 0.088 so they never swing under chin!)
        for s_k in range(2):
            mat = 'hair_highlight' if s_k == 1 else 'hair'
            front_lock = [
                (side * (.062 + s_k * .008), .032, .016 + s_k * .008),
                (side * (.084 + s_k * .009), -.038, .010 + s_k * .006),
                (side * (.098 + s_k * .010), -.105, -.022 + s_k * .006),
                (side * (.094 + s_k * .010), -.165, -.056 + s_k * .005),
                (side * (.100 + s_k * .008), -.225, -.064 + s_k * .005),
                (side * (.090 + s_k * .006), -.275, -.054 + s_k * .005),
            ]
            _tube(api, f'ShoulderFrontWave{tag}{s_k}', front_lock,
                  [.014, .019, .0195, .0165, .0110, .0022], mat, 10, 4, flatten=.35, deform_mode='long_hair')

    for side, tag in ((-1, 'L'), (1, 'R')):
        sx, sy, sz = side * .068, .042, -.024
        for arm_i in range(5):
            a = arm_i / 5 * TAU - .3 * side
            tip = (sx + side * .003, sy + .013 * math.sin(a), sz + .013 * math.cos(a))
            _tube(api, f'StarfishHairpinArm{tag}{arm_i}', [(sx, sy, sz), tip], [.0032, .0008], 'gold_light', 6, 2)
        _ellipsoid(api, f'StarfishHairpinCenterPearl{tag}', (sx + side * .002, sy, sz),
                   (.0028, .0028, .0028), 'pearl', 10, 8)
        for p_i in range(5):
            tp = .30 + p_i * .14
            u_p = side * (.36 + p_i * .06)
            px, py, pz = _hair_canopy_point(u_p, tp)
            pz += .0085
            _ellipsoid(api, f'WovenHairPearl{tag}{p_i}', (px, py, pz),
                       (.0034, .0034, .0034), 'pearl', 10, 8, deform_mode='long_hair')


def build(api):
    """Build sculpted siren face, jewel eyes, ear-fins, tiara and cascading hair."""
    _face(api)
    _ear_fins(api)
    _hair(api)
    _crown(api)
