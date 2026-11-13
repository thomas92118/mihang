"""Visible human face and pressure helmet, authored after concepts/diver.png.

All positions are Godot-local (+Y up, -Z forward).  The coordinator owns the
Blender scene, normal recalculation, materials, export and runtime attachments.
This module deliberately exposes the face through a genuinely transparent
visor; an opaque helmet is not used to hide missing anatomy.
"""
import math


TAU = math.tau


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
               driver='head'):
    vertices = [(center[0], center[1] + radius[1], center[2])]
    uv, faces = [(.5, 1)], []
    for i in range(1, rings):
        theta = i / rings * math.pi
        for j in range(segments):
            phi = j / segments * TAU
            vertices.append((center[0] + radius[0] * math.sin(theta) * math.cos(phi),
                             center[1] + radius[1] * math.cos(theta),
                             center[2] + radius[2] * math.sin(theta) * math.sin(phi)))
            uv.append((j / segments, 1 - i / rings))
    bottom = len(vertices)
    vertices.append((center[0], center[1] - radius[1], center[2]))
    uv.append((.5, 0))
    for j in range(segments):
        k = (j + 1) % segments
        faces.append((0, 1 + k, 1 + j))
        for i in range(rings - 2):
            a, b = 1 + i * segments + j, 1 + i * segments + k
            faces.append((a, b, b + segments, a + segments))
        a, b = 1 + (rings - 2) * segments + j, 1 + (rings - 2) * segments + k
        faces.append((a, b, bottom))
    return api.surface(name, vertices, faces, material, driver=driver, uv=uv)


def _tube(api, name, path, radii, material, sides=8, smooth_steps=3,
          driver='head'):
    from mathutils import Vector
    if smooth_steps > 1:
        path = _catmull(path, smooth_steps)
        # Scalar radii interpolate without Catmull overshoot at the fine ends.
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
        for j in range(sides):
            a = j / sides * TAU
            vertices.append(tuple(point + (normal * math.cos(a) + cross * math.sin(a)) * radii[i]))
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
    return api.surface(name, vertices, faces, material, driver=driver, uv=uv)


def _ring(api, name, center, radii, thickness, material, plane='XY',
          segments=80, sides=8, driver='head'):
    path = []
    for i in range(segments + 1):
        a = i / segments * TAU
        x, y = radii[0] * math.cos(a), radii[1] * math.sin(a)
        delta = {'XY': (x, y, 0), 'YZ': (0, x, y), 'XZ': (x, 0, y)}[plane]
        path.append(tuple(center[k] + delta[k] for k in range(3)))
    return _tube(api, name, path, [thickness] * len(path), material,
                 sides=sides, smooth_steps=1, driver=driver)


def _face(api):
    # Refined oval feminine head & face proportions matching concepts/diver.png:
    # (y, half_width, z_front, z_back)
    profile = [
        (-.076, .009, -.044, .010),
        (-.068, .021, -.051, .018),
        (-.052, .035, -.053, .032),
        (-.032, .046, -.054, .045),
        (-.010, .053, -.055, .056),
        (.012, .056, -.056, .063),
        (.036, .056, -.055, .065),
        (.062, .053, -.050, .063),
        (.084, .045, -.038, .054),
        (.102, .029, -.020, .036),
        (.112, .008, -.002, .010),
    ]
    rows = _catmull(profile, 6)
    sides = 80
    vertices, uv, faces = [], [], []

    def gaussian(x, y, cx, cy, sx, sy):
        return math.exp(-((x - cx) / sx) ** 2 - ((y - cy) / sy) ** 2)

    def relief_at(x, y):
        # Straight feminine nose bridge, delicate upturned tip, soft alae,
        # malar cheekbones, brow ridge, orbital hollows, and rounded chin.
        relief = .0065 * gaussian(x, y, 0, .006, .0085, .024)
        relief += .0125 * gaussian(x, y, 0, -.014, .0082, .011)
        relief += .0032 * gaussian(x, y, 0, -.021, .0042, .0055)
        # Chin pad & mouth barrel fullness
        relief += .0042 * gaussian(x, y, 0, -.065, .016, .011)
        relief += .0032 * gaussian(x, y, 0, -.041, .020, .012)
        # Forehead / glabella softness
        relief += .0022 * gaussian(x, y, 0, .042, .034, .022)
        for side in (-1, 1):
            # Soft nostril wing
            relief += .0036 * gaussian(x, y, side * .0095, -.017, .0058, .0058)
            # Feminine malar cheekbone
            relief += .0048 * gaussian(x, y, side * .031, -.006, .020, .019)
            # Brow arch ridge
            relief += .0034 * gaussian(x, y, side * .025, .029, .019, .0085)
            # Natural orbital socket recess so almond eyes sit cleanly inside
            relief -= .0036 * gaussian(x, y, side * .0245, .011, .0145, .0095)
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

    def in_eye_opening(x, y):
        side = -1 if x < 0 else 1
        u = (x - side * .0245) / .0128
        if abs(u) >= 1:
            return False
        slant = side * u * .0011
        center_y = .011 + slant
        arch = math.sin((u + 1) / 2 * math.pi) ** .75
        return center_y - .0038 * arch < y < center_y + .0048 * arch

    for i, (y, width, front, back) in enumerate(rows):
        for j in range(sides):
            angle = j / sides * TAU
            x = math.sin(angle) * width
            z = (front + back) / 2 + (back - front) / 2 * math.cos(angle)
            weight = max(0., -math.cos(angle)) ** 3.2
            vertices.append((x, y, z - relief_at(x, y) * weight))
            # Front-centered UV so u=0.5 is nose bridge and v maps chin -> crown
            u_coord = .5 + math.atan2(x, -z) / TAU
            uv.append((u_coord % 1.0, i / (len(rows) - 1)))
    for i in range(1, len(rows)):
        for j in range(sides):
            a = (i - 1) * sides + j
            b = (i - 1) * sides + (j + 1) % sides
            quad = (a, b, b + sides, a + sides)
            center_x = sum(vertices[k][0] for k in quad) / 4
            center_y = sum(vertices[k][1] for k in quad) / 4
            center_z = sum(vertices[k][2] for k in quad) / 4
            if not (center_z < -.030 and in_eye_opening(center_x, center_y)):
                faces.append(quad)
    for i in (0, len(rows) - 1):
        y, _, front, back = rows[i]
        center = len(vertices)
        vertices.append((0, y, (front + back) / 2))
        uv.append((.5, .5))
        for j in range(sides):
            a, b = i * sides + j, i * sides + (j + 1) % sides
            faces.append((center, b, a) if i == 0 else (center, a, b))
    api.surface('SculptedHumanFace', vertices, faces, 'skin', driver='head', uv=uv)
    # Keep lower neck strictly above LowerPressureCollar (y=-0.092) so pitching head +48 deg while swimming never pokes skin out below collar
    _ellipsoid(api, 'NaturalNeck', (0, -.067, .006), (.026, .021, .024), 'skin', 32, 18)

    for side, label in ((-1, 'Left'), (1, 'Right')):
        eye_x = side * .0245
        eye_y = .011
        eye_z = front_at(eye_x, eye_y) + .0048
        eye_front = eye_z - .0064
        _ellipsoid(api, label + 'RecessedSclera', (eye_x, eye_y, eye_z), (.0138, .0068, .0064), 'eye_white', 28, 16)
        _ellipsoid(api, label + 'HazelIris', (eye_x - side * .0005, eye_y + .0003, eye_front - .00015),
                   (.0046, .0047, .00055), 'iris', 28, 14)
        _ellipsoid(api, label + 'Pupil', (eye_x - side * .0005, eye_y + .0003, eye_front - .00065),
                   (.0021, .0022, .0003), 'pupil', 20, 12)
        _ellipsoid(api, label + 'EyeCatchlight', (eye_x - .0014, eye_y + .0017, eye_front - .00095),
                   (.00078, .00078, .0002), 'eye_white', 12, 8)
        _ellipsoid(api, label + 'EyeCatchlightSub', (eye_x + .0012, eye_y - .0011, eye_front - .0009),
                   (.00038, .00038, .00018), 'eye_white', 10, 6)
        upper, lower = [], []
        for i in range(17):
            t = i / 16
            x = eye_x + side * (.0132 * (2 * t - 1))
            arch = math.sin(t * math.pi) ** .75
            slant = (t - .5) * .0022
            uy, ly = eye_y + arch * .0048 + slant, eye_y - arch * .0038 + slant
            upper.append((x, uy, front_at(x, uy) - .0004))
            lower.append((x, ly, front_at(x, ly) - .0003))
        _tube(api, label + 'UpperEyelid', upper, [.0006 + .0004 * math.sin(i / 16 * math.pi) for i in range(17)], 'skin', 7, 1)
        _tube(api, label + 'LowerEyelid', lower, [.00045 + .00025 * math.sin(i / 16 * math.pi) for i in range(17)], 'skin', 6, 1)
        lashes = [(x + (side * .0014 if i == 16 else 0), y + (.0005 if i == 16 else .00015), z - .0005)
                  for i, (x, y, z) in enumerate(upper)]
        _tube(api, label + 'FineUpperLashes', lashes,
              [.00035 + .00055 * (math.sin(i / 16 * math.pi) ** .7) for i in range(17)], 'hair', 6, 1)
        # Softly arched feminine dark-espresso eyebrows
        brow_pts = [(.009, .0265), (.019, .0310), (.030, .0322), (.040, .0282)]
        brow = [(side * bx, by, front_at(side * bx, by) - .0010) for bx, by in brow_pts]
        _tube(api, label + 'ShapedEyebrow', brow, [.0012, .0018, .0015, .00045], 'hair', 8, 4)
        nostril = []
        for i in range(9):
            t = i / 8
            x = side * (.0036 + .0050 * t)
            y = -.0205 - .0008 * math.sin(t * math.pi)
            nostril.append((x, y, front_at(x, y) - .00025))
        _tube(api, label + 'SubtleNostrilCrease', nostril,
              [.00025 + .00018 * math.sin(i / 8 * math.pi) for i in range(9)], 'skin_shadow', 5, 1)
        _ellipsoid(api, label + 'Ear', (side * .056, .006, .006), (.008, .019, .012), 'skin', 20, 12)

    # Sculpted Cupid's bow upper lip & fuller natural rose-terracotta lower lip
    mouth_y = -.0415
    half_mouth = .0148
    for upper in (True, False):
        corner_y = mouth_y + .0007
        vertices, faces, uv = [(-half_mouth, corner_y, front_at(-half_mouth, corner_y) - .0002)], [], [(0, .5)]
        cols = 28
        for i in range(1, cols):
            t = i / cols
            x = (t - .5) * (2 * half_mouth)
            taper = math.sin(t * math.pi) ** .72
            cupid = math.exp(-((abs(x) - .0042) / .0034) ** 2)
            dip = math.exp(-(x / .0024) ** 2)
            mid_y = mouth_y - .0004 * math.cos(t * TAU)
            thickness = (.0036 + .0018 * cupid - .0007 * dip) if upper else .0054
            for j in range(7):
                v = j / 6
                y = mid_y + (1 if upper else -1) * thickness * taper * v
                pillow = (.0024 if upper else .0031) * math.sin(v * math.pi) * taper
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
        api.surface('CupidBowUpperLip' if upper else 'NaturalLowerLip', vertices, faces, 'lip', driver='head', uv=uv)
    crease = [((i / 20 - .5) * (2 * half_mouth * .94), mouth_y - .0004 * math.cos(i / 20 * TAU),
               front_at((i / 20 - .5) * (2 * half_mouth * .94), mouth_y) - .0009) for i in range(21)]
    _tube(api, 'ClosedMouthCrease', crease, [.00022 + .00016 * math.sin(i / 20 * math.pi) for i in range(21)], 'skin_shadow', 5, 1)


def _hair(api):
    sides, rings = 64, 22
    vertices, faces, uv = [(.008, .116, .008)], [], [(.5, 0)]
    # Lush dark-espresso scalp cap with natural crown wave & open feminine forehead
    for i in range(1, rings + 1):
        v = i / rings
        for j in range(sides):
            a = j / sides * TAU
            front = max(0.0, -math.cos(a))
            limit = 2.16 - 1.12 * (front ** 2.15)
            theta = v * limit
            wave = .0024 * (.5 + .5 * math.sin(a * 7.0 + v * 4.5)) * math.sin(theta)
            x = (.0645 + wave) * math.sin(theta) * math.sin(a)
            y = .016 + (.099 + .0025 * math.sin(a + .35)) * math.cos(theta)
            z = .009 + (.073 + wave) * math.sin(theta) * math.cos(a)
            vertices.append((x, y, z))
            uv.append((j / sides, v))
            if i == 1:
                faces.append((0, 1 + (j + 1) % sides, 1 + j))
            else:
                a0, a1 = 1 + (i - 2) * sides + j, 1 + (i - 2) * sides + (j + 1) % sides
                faces.append((a0, a1, a1 + sides, a0 + sides))
    api.surface('SidePartedDarkHairCap', vertices, faces, 'hair', driver='head', uv=uv)

    # Layered wavy curtain locks framing BOTH sides of forehead, temples & cheekbones
    part_x = .009
    for side, tag in ((-1, 'L'), (1, 'R')):
        for k in range(4):
            yk = k * .0045
            zk = k * .004
            mat = 'hair_highlight' if k == 2 else 'hair'
            path = [
                (part_x + side * .004, .111 - yk * .3, -.031 + zk),
                (side * (.027 + k * .004), .094 - yk * .5, -.055 + zk * .6),
                (side * (.052 + k * .003), .057 - yk * .7, -.051 + zk * .8),
                (side * (.062 + k * .002), .018 - yk * .5, -.024 + zk),
                (side * .056, -.014 - k * .003, .022 + zk),
                (side * .028, -.016, .068),
            ]
            radii = [.0075, .0118, .0122, .0098, .0078, .0050]
            _tube(api, f'WavyCurtainLock{tag}{k}', path, radii, mat, 10, 5)
        # Delicate face-framing temple tendril wave (swim_upper_gear.png!)
        tendril = [
            (side * .044, .068, -.048),
            (side * .056, .038, -.044),
            (side * .053, .010, -.036),
            (side * .058, -.014, -.022),
            (side * .052, -.030, -.010),
        ]
        _tube(api, 'TempleWaveTendril' + tag, tendril, [.0032, .0038, .0028, .0018, .0006], 'hair', 8, 5)

    # Crown-to-nape gathered wavy hair ropes flowing into the rear helmet opening
    for k in range(10):
        ang = -.95 + k / 9 * 1.90
        mat = 'hair_highlight' if k in (2, 7) else 'hair'
        pts = []
        for s_i in range(7):
            t = s_i / 6
            th = .25 + t * 1.45
            az = math.pi + ang * (1.0 - .55 * t) + .08 * math.sin(t * TAU)
            pts.append((.063 * math.sin(th) * math.sin(az),
                        .018 + .098 * math.cos(th) - .012 * t,
                        .010 - .071 * math.sin(th) * math.cos(az) + .022 * t ** 2))
        _tube(api, 'GatheredCrownWave%02d' % k, pts,
              [.0055 + .0045 * math.sin(s_i / 6 * math.pi) for s_i in range(7)], mat, 8, 3)

    # Voluminous multi-strand coiled low bun protruding cleanly behind the helmet!
    # Rear helmet collar sits around z=+0.076; bun extends boldly out to z=+0.142!
    bun_y, bun_z = -.006, .106
    _ellipsoid(api, 'LowRolledChignon', (0, bun_y, bun_z), (.044, .038, .031), 'hair', 28, 18)
    for k in range(6):
        mat = 'hair_highlight' if k % 3 == 1 else 'hair'
        points = []
        for j in range(29):
            t = j / 28
            a = t * TAU * 1.25 + k * (TAU / 6)
            rad_x = .043 - .022 * t
            rad_y = .036 - .018 * t
            wobble = .0035 * math.sin(a * 3.0 + k)
            points.append((math.cos(a) * rad_x,
                           bun_y + math.sin(a) * rad_y,
                           bun_z + .006 + .024 * math.sin(t * math.pi * .85) + wobble))
        _tube(api, 'TwistedChignonLock%02d' % k, points,
              [.0085 * (1.0 - .38 * j / 28) for j in range(29)], mat, 8, 1)

    # Expressive loose wavy wisps fluttering around the coiled bun (side & swim views!)
    wisp_specs = [
        [(0.018, .016, .118), (.034, .028, .134), (.044, .024, .148), (.048, .014, .156)],
        [(-.020, .014, .118), (-.038, .025, .136), (-.048, .018, .150), (-.052, .006, .157)],
        [(.006, .024, .116), (.014, .038, .132), (.008, .046, .145), (-.002, .042, .152)],
        [(-.014, -.022, .116), (-.030, -.032, .132), (-.036, -.026, .144), (-.032, -.018, .150)],
        [(.016, -.020, .116), (.032, -.028, .130), (.038, -.020, .142), (.034, -.012, .148)],
    ]
    for idx, wisp in enumerate(wisp_specs):
        _tube(api, 'WavyBunWisp%02d' % idx, wisp, [.0045, .0036, .0020, .0006], 'hair', 7, 4)


def _helmet(api):
    # Authentic expedition bubble helmet matching concepts/diver.png:
    # 1) Crystal-clear front spherical visor dome (no milky rear bowl over the bun!)
    dome_cy, dome_cz = .012, -.004
    rx, ry, rz = .097, .116, .102
    sides, rings = 64, 24
    vertices, faces, uv = [], [], []
    # Parameterize from front apex (0, dome_cy, dome_cz - rz) back to bezel arch!
    vertices.append((0.0, dome_cy, dome_cz - rz))
    uv.append((.5, 1))
    for i in range(1, rings + 1):
        v = i / rings
        for j in range(sides):
            a = j / sides * TAU
            # Upper crown extends slightly past z=0 (+0.016), chin stops above regulator
            up = math.sin(a)  # +1 top, -1 bottom
            max_theta = 1.68 + .16 * up - .22 * max(0.0, -up) ** 2
            theta = v * max_theta
            x = rx * math.sin(theta) * math.cos(a)
            y = dome_cy + ry * math.sin(theta) * math.sin(a)
            z = dome_cz - rz * math.cos(theta)
            vertices.append((x, y, z))
            uv.append((j / sides, 1 - v))
            if i == 1:
                faces.append((0, 1 + j, 1 + (j + 1) % sides))
            else:
                a0, a1 = 1 + (i - 2) * sides + j, 1 + (i - 2) * sides + (j + 1) % sides
                faces.append((a0, a0 + sides, a1 + sides, a1))
    api.surface('ClearGlassPressureDome', vertices, faces, 'glass', driver='head', uv=uv)

    # 2) Sculpted warm-ivory ceramic rear cranial shell with open rear bun aperture!
    # Covers from bezel arch (theta ~ 1.68) around rear-sides up to bun gasket collar.
    sh_sides, sh_rings = 56, 14
    sh_verts, sh_faces, sh_uv = [], [], []
    for r_i in range(sh_rings + 1):
        t = r_i / sh_rings
        for j in range(sh_sides):
            a = j / sh_sides * TAU
            up = math.sin(a)
            th_start = 1.66 + .16 * up - .20 * max(0.0, -up) ** 2
            # Leave rear aperture open around (0, -0.006, +z) for hair crown & bun!
            th_end = 2.52 - .12 * max(0.0, up)
            theta = th_start + (th_end - th_start) * t
            rad_scale = 1.012 - .015 * t
            x = rx * rad_scale * math.sin(theta) * math.cos(a)
            y = dome_cy + ry * rad_scale * math.sin(theta) * math.sin(a)
            z = dome_cz - rz * rad_scale * math.cos(theta)
            # Clamp above neck collar
            y = max(y, -.088)
            sh_verts.append((x, y, z))
            sh_uv.append((j / sh_sides, t))
            if r_i > 0:
                a0 = (r_i - 1) * sh_sides + j
                a1 = (r_i - 1) * sh_sides + (j + 1) % sh_sides
                sh_faces.append((a0, a0 + sh_sides, a1 + sh_sides, a1))
    # Add inner thickness shell so rear ceramic shell is solid watertight 3D armor
    outer_n = len(sh_verts)
    for x, y, z in list(sh_verts):
        sh_verts.append((x * .955, y * .965, z * .955))
        sh_uv.append((.5, .5))
    for r_i in range(1, sh_rings + 1):
        for j in range(sh_sides):
            a0 = outer_n + (r_i - 1) * sh_sides + j
            a1 = outer_n + (r_i - 1) * sh_sides + (j + 1) % sh_sides
            sh_faces.append((a0, a1, a1 + sh_sides, a0 + sh_sides))
    for rim_row, flip in ((0, False), (sh_rings, True)):
        base_r = rim_row * sh_sides
        for j in range(sh_sides):
            j1 = (j + 1) % sh_sides
            q = (base_r + j, base_r + j1, outer_n + base_r + j1, outer_n + base_r + j)
            sh_faces.append(q if flip else tuple(reversed(q)))
    api.surface('SculptedIvoryCranialShell', sh_verts, sh_faces, 'ivory', driver='head', uv=sh_uv)

    # Bezel arch & rear bun collar trim rings in antique brass & ivory
    bezel_pts = []
    rear_rim_pts = []
    for j in range(65):
        a = j / 64 * TAU
        up = math.sin(a)
        th0 = 1.67 + .16 * up - .21 * max(0.0, -up) ** 2
        th1 = 2.52 - .12 * max(0.0, up)
        bezel_pts.append((rx * 1.015 * math.sin(th0) * math.cos(a),
                          max(-.087, dome_cy + ry * 1.015 * math.sin(th0) * math.sin(a)),
                          dome_cz - rz * 1.015 * math.cos(th0)))
        rear_rim_pts.append((rx * .995 * math.sin(th1) * math.cos(a),
                             max(-.086, dome_cy + ry * .995 * math.sin(th1) * math.sin(a)),
                             dome_cz - rz * .995 * math.cos(th1)))
    _tube(api, 'CeramicBezelArch', bezel_pts, [.0048] * len(bezel_pts), 'ivory', 10, 1)
    _tube(api, 'FineBrassPressureInlay', [(x * 1.01, y * 1.01, z - .003) for x, y, z in bezel_pts],
          [.0022] * len(bezel_pts), 'gold', 8, 1)
    _tube(api, 'RearBunBrassCollar', rear_rim_pts, [.0032] * len(rear_rim_pts), 'gold', 8, 1)
    _tube(api, 'RearBunRubberGasket', [(x * .96, y * .96, z + .002) for x, y, z in rear_rim_pts],
          [.0028] * len(rear_rim_pts), 'rubber', 8, 1)

    # Brass & rubber neck seal collar
    _ring(api, 'LowerPressureCollar', (0, -.092, .006), (.066, .060), .0068, 'gold', plane='XZ', segments=56, sides=10)
    _ring(api, 'CollarRubberSeal', (0, -.085, .006), (.064, .058), .0042, 'rubber', plane='XZ', segments=56, sides=8)

    for side, label in ((-1, 'Left'), (1, 'Right')):
        # Circular antique-brass ear/temple comm pods + mandible chin struts
        ex, ey, ez = side * .097, .005, .009
        _ellipsoid(api, label + 'CeramicEarMount', (ex, ey, ez), (.010, .028, .028), 'ivory', 28, 16)
        _ellipsoid(api, label + 'BrassEarMechanism', (ex + side * .007, ey, ez), (.007, .024, .024), 'gold', 28, 16)
        _ring(api, label + 'EarConcentricInlay', (ex + side * .013, ey, ez), (.018, .018), .0020, 'gold_light', plane='YZ', segments=40)
        _ellipsoid(api, label + 'EarPlate', (ex + side * .0135, ey, ez), (.002, .015, .015), 'gold', 24, 14)
        for j in range(4):
            a = (j + .5) / 4 * TAU
            _ellipsoid(api, label + 'EarFastener%02d' % j,
                       (ex + side * .015, ey + math.cos(a) * .0185, ez + math.sin(a) * .0185),
                       (.0014, .0016, .0016), 'gold_light', 10, 6)
        # Sculpted ivory & brass chin-bar strut sweeping from ear pod down to front rebreather
        chin_strut = [
            (side * .094, -.018, .004),
            (side * .082, -.054, -.024),
            (side * .054, -.074, -.058),
            (side * .020, -.079, -.078),
        ]
        _tube(api, label + 'MandibleChinStrut', chin_strut, [.0065, .0072, .0075, .0068], 'ivory', 10, 4)
        _tube(api, label + 'MandibleBrassTrim', [(x, y - .004, z - .002) for x, y, z in chin_strut],
              [.0024] * 4, 'gold', 8, 4)

    # Prominent front circular slotted antique-brass rebreather mouthpiece valve
    ry_v, rz_v = -.079, -.082
    _ellipsoid(api, 'ChinRegulatorHousing', (0, ry_v, rz_v), (.023, .023, .015), 'gold', 32, 18)
    _ellipsoid(api, 'RegulatorRecess', (0, ry_v, rz_v - .013), (.0165, .0165, .003), 'rubber', 28, 14)
    _ring(api, 'RegulatorBeadedRim', (0, ry_v, rz_v - .0145), (.0185, .0185), .0024, 'gold_light', plane='XY', segments=40)
    for i in range(-2, 3):
        x = i * .0052
        reach = math.sqrt(max(.00001, .0145 ** 2 - x ** 2))
        _tube(api, 'RegulatorVerticalVent%02d' % (i + 2),
              [(x, ry_v - reach, rz_v - .016), (x, ry_v + reach, rz_v - .016)],
              [.0011, .0011], 'gold', 6, 1)


def build(api):
    """Build original 3D anatomy and gear; do not replace them with a plane."""
    _face(api)
    _hair(api)
    _helmet(api)
