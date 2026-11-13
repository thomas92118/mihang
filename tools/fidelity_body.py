"""Sculpted feminine Mermaid upper body, slender bare arms/hands & seamless scaled Siren tail.

All coordinates are Godot driver-local (+X across, +Y up, -Z forward).
"""
import math


TAU = math.tau


def _catmull(a, b, c, d, t):
    return tuple(.5 * (2 * b[k] + (-a[k] + c[k]) * t
                        + (2 * a[k] - 5 * b[k] + 4 * c[k] - d[k]) * t * t
                        + (-a[k] + 3 * b[k] - 3 * c[k] + d[k]) * t ** 3)
                 for k in range(len(b)))


def _resample(profile, density=5):
    result = []
    for i in range(len(profile) - 1):
        for j in range(density):
            result.append(_catmull(profile[max(0, i - 1)], profile[i],
                                   profile[i + 1], profile[min(len(profile) - 1, i + 2)],
                                   j / density))
    result.append(tuple(profile[-1]))
    return result


def _loft_curve(api, name, sections, material, driver, sides=40, density=4, deform_mode=None):
    rings = _resample(sorted(sections, key=lambda s: s[0]), density)
    vertices, faces, uv = [], [], []
    for i, (y, cx, cz, rx, front, back) in enumerate(rings):
        rx, front, back = max(rx, .001), max(front, .001), max(back, .001)
        for j in range(sides):
            phi = j / sides * TAU
            s, c = math.sin(phi), math.cos(phi)
            x = cx + rx * s
            z = cz + (-front * c if c > 0 else -back * c)
            vertices.append((x, y, z))
            uv.append((j / sides, i / (len(rings) - 1)))
    for i in range(len(rings) - 1):
        for j in range(sides):
            j1 = (j + 1) % sides
            p, q = i * sides + j, i * sides + j1
            faces.append((p, q, q + sides, p + sides))
    for last in (False, True):
        ring = len(rings) - 1 if last else 0
        y, cx, cz, _, _, _ = rings[ring]
        center = len(vertices)
        vertices.append((cx, y, cz))
        uv.append((.5, .5))
        for j in range(sides):
            p, q = ring * sides + j, ring * sides + (j + 1) % sides
            faces.append((center, p, q) if last else (center, q, p))
    return api.surface(name, vertices, faces, material, driver=driver, uv=uv, deform_mode=deform_mode)


def _subtract(a, b):
    return tuple(x - y for x, y in zip(a, b))


def _cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2],
            a[0] * b[1] - a[1] * b[0])


def _unit(a):
    scale = max(1e-10, math.sqrt(sum(c * c for c in a)))
    return tuple(c / scale for c in a)


def _tube(api, name, points, radii, material, driver, sides=10, density=3,
          flatten=1.0, deform_mode=None):
    samples = _resample([tuple(p) + (r,) for p, r in zip(points, radii)], density)
    vertices, uv, faces = [], [], []
    stride = sides + 1
    for i, sample in enumerate(samples):
        p, radius = sample[:3], max(sample[3], .00035)
        tangent = _unit(_subtract(samples[min(len(samples) - 1, i + 1)][:3],
                                  samples[max(0, i - 1)][:3]))
        cross = _cross(tangent, (0, 0, 1))
        if sum(k * k for k in cross) < .0001:
            cross = _cross(tangent, (0, 1, 0))
        cross = _unit(cross)
        normal = _unit(_cross(tangent, cross))
        for j in range(stride):
            a = j / sides * TAU
            offset = tuple(radius * (math.cos(a) * cross[k]
                                     + math.sin(a) * normal[k] * flatten) for k in range(3))
            vertices.append(tuple(p[k] + offset[k] for k in range(3)))
            uv.append((j / sides, i / (len(samples) - 1)))
    for i in range(len(samples) - 1):
        for j in range(sides):
            a = i * stride + j
            faces.append((a, a + 1, a + stride + 1, a + stride))
    for last in (False, True):
        i = len(samples) - 1 if last else 0
        center = len(vertices)
        vertices.append(samples[i][:3])
        uv.append((.5, .5))
        for j in range(sides):
            a, b = i * stride + j, i * stride + j + 1
            faces.append((center, a, b) if last else (center, b, a))
    return api.surface(name, vertices, faces, material, driver=driver, uv=uv, deform_mode=deform_mode)


def _upper_torso(api):
    """Sculpted feminine porcelain upper body: swan neck, collarbones, bust, hourglass waist."""
    torso_spec = [
        (-.115, .114, .054, .068, .006),
        (-.085, .106, .053, .062, .004),
        (-.045, .088, .050, .054, .000),
        (-.005, .070, .045, .046, -.003),
        (.034, .066, .043, .044, -.004),
        (.080, .084, .055, .050, -.004),
        (.126, .103, .076, .055, -.003),
        (.172, .120, .059, .052, .000),
        (.202, .134, .046, .045, .002),
        (.224, .092, .038, .038, .003),
        (.250, .034, .029, .030, .004),
        (.282, .026, .025, .026, .005),
        (.308, .023, .023, .024, .006),
    ]
    rings = list(reversed(_resample(torso_spec, 4)))
    sides = 64
    vertices, uv, faces = [], [], []

    def sculpt(x, y, z, phi):
        c = math.cos(phi)
        front = max(0.0, c) ** 2.2
        back = max(0.0, -c) ** 2.0
        bust_y = math.exp(-((y - .126) / .044) ** 2)
        cup = math.exp(-((abs(x) - .048) / .037) ** 2)
        sternum = math.exp(-(x / .018) ** 2)
        z -= .0185 * bust_y * cup * front
        z += .0065 * bust_y * sternum * front
        clav_y = .204 + .012 * (abs(x) / .10)
        clav = math.exp(-((y - clav_y) / .010) ** 2) * math.exp(-((abs(x) - .055) / .042) ** 2)
        notch = math.exp(-((y - .202) / .012) ** 2) * math.exp(-(x / .015) ** 2)
        z -= .0034 * clav * front
        z += .0038 * notch * front
        navel = math.exp(-((y + .018) / .0085) ** 2) * math.exp(-(x / .0065) ** 2)
        z += .0042 * navel * front
        spine = math.exp(-((y - .065) / .115) ** 2) * math.exp(-(x / .020) ** 2)
        scap = math.exp(-((y - .155) / .045) ** 2) * math.exp(-((abs(x) - .056) / .032) ** 2)
        z -= .0058 * spine * back
        z += .0032 * scap * back
        return (x, y, z)

    ring_idx = []
    for r_i, (y, w, front, back, shift) in enumerate(rings):
        row = []
        v_coord = 1.0 - r_i / max(1, len(rings) - 1)
        for j in range(sides):
            phi = j / sides * TAU
            s, c = math.sin(phi), math.cos(phi)
            x = w * s
            z = shift + (-front * c if c > 0 else -back * c)
            row.append(len(vertices))
            vertices.append(sculpt(x, y, z, phi))
            uv.append((j / sides, v_coord))
        ring_idx.append(row)

    for last, idx in ((False, 0), (True, len(rings) - 1)):
        y, _, _, _, shift = rings[idx]
        ctr = len(vertices)
        vertices.append((0.0, y, shift))
        uv.append((.5, 0.0 if last else 1.0))
        for j in range(sides):
            a, b = ring_idx[idx][j], ring_idx[idx][(j + 1) % sides]
            faces.append((ctr, a, b) if last else (ctr, b, a))
    for r_i in range(len(ring_idx) - 1):
        r0, r1 = ring_idx[r_i], ring_idx[r_i + 1]
        for j in range(sides):
            j1 = (j + 1) % sides
            faces.append((r0[j], r0[j1], r1[j1], r1[j]))

    api.surface('SculptedPorcelainTorso', vertices, faces, 'body_skin',
                driver='body', uv=uv, deform_mode='torso_skin')


def _mermaid_tail(api):
    """Seamless V-waisted iridescent scaled Mermaid Tail tapering to caudal peduncle."""
    tail_spec = [
        (-.052, .106, .054, .062, .003),
        (-.085, .120, .058, .070, .006),
        (-.132, .132, .062, .082, .009),
        (-.185, .126, .060, .078, .009),
        (-.250, .108, .055, .066, .008),
        (-.325, .087, .048, .054, .008),
        (-.405, .068, .040, .044, .009),
        (-.485, .052, .033, .036, .010),
        (-.565, .039, .027, .029, .010),
        (-.640, .029, .021, .023, .010),
        (-.685, .021, .015, .016, .010),
        (-.712, .006, .005, .006, .010),
    ]
    rings = _resample(tail_spec, 5)
    sides = 64
    vertices, uv, faces = [], [], []
    ring_idx = []

    for r_i, (base_y, rx, front, back, shift) in enumerate(rings):
        t = r_i / max(1, len(rings) - 1)
        v_fade = max(0.0, 1.0 - t / .26) ** 1.5
        row = []
        for j in range(sides):
            phi = j / sides * TAU
            s, c = math.sin(phi), math.cos(phi)
            v_dip = -.040 * (c ** 2) * v_fade
            y = base_y + v_dip
            keel = 1.0 + .12 * max(0.0, (t - .55) / .45) * (s ** 4)
            x = rx * keel * s
            z = shift + (-front * c if c > 0 else -back * c)
            back_w = max(0.0, -c) ** 2.0
            glute_y = math.exp(-((y + .150) / .055) ** 2)
            lobe = math.exp(-((abs(x) - .058) / .048) ** 2)
            cleft = math.exp(-(x / .018) ** 2)
            z += .0095 * glute_y * lobe * back_w
            z -= .0090 * glute_y * cleft * back_w
            row.append(len(vertices))
            vertices.append((x, y, z))
            uv.append((j / sides, 1.0 - t))
        ring_idx.append(row)

    top_y, _, _, _, top_sh = rings[0]
    top_c = len(vertices)
    vertices.append((0.0, top_y - .040, top_sh))
    uv.append((.5, 1.0))
    for j in range(sides):
        faces.append((top_c, ring_idx[0][(j + 1) % sides], ring_idx[0][j]))

    for r_i in range(len(ring_idx) - 1):
        r0, r1 = ring_idx[r_i], ring_idx[r_i + 1]
        for j in range(sides):
            j1 = (j + 1) % sides
            faces.append((r0[j], r0[j1], r1[j1], r1[j]))

    bot_y, _, _, _, bot_sh = rings[-1]
    bot_c = len(vertices)
    vertices.append((0.0, bot_y, bot_sh))
    uv.append((.5, 0.0))
    for j in range(sides):
        faces.append((bot_c, ring_idx[-1][j], ring_idx[-1][(j + 1) % sides]))

    api.surface('SculptedMermaidTailBody', vertices, faces, 'scales',
                driver='body', uv=uv, deform_mode='mermaid_tail')


def _arms(api, side):
    driver = 'arm_l' if side < 0 else 'arm_r'
    fore = 'forearm_l' if side < 0 else 'forearm_r'
    hand_name = 'Left' if side < 0 else 'Right'
    arm_sec = [
        (-.446, side * .004, -.004, .0158, .0155, .0160),
        (-.412, side * .003, -.003, .0178, .0172, .0178),
        (-.355, side * .001, -.001, .0215, .0210, .0220),
        (-.300, -side * .001, .001, .0242, .0235, .0248),
        (-.262, -side * .003, .002, .0242, .0232, .0242),
        (-.235, -side * .004, .002, .0230, .0224, .0232),
        (-.192, -side * .010, .001, .0250, .0248, .0255),
        (-.130, -side * .020, .000, .0275, .0275, .0282),
        (-.068, -side * .032, .001, .0305, .0300, .0310),
        (-.014, -side * .042, .002, .0335, .0320, .0330),
        (.014, -side * .054, .002, .0330, .0305, .0315),
        (.028, -side * .068, .002, .0260, .0245, .0255),
    ]
    _loft_curve(api, 'SlenderBareArm' + hand_name, arm_sec, 'body_skin',
                driver, sides=32, density=4, deform_mode='suit_arm')

    _loft_curve(api, 'GracefulHandPalm' + hand_name, [
        (-.274, side * .004, -.006, .0095, .0215, .0195),
        (-.260, side * .005, -.006, .0115, .0260, .0235),
        (-.240, side * .005, -.005, .0125, .0250, .0225),
        (-.222, side * .004, -.004, .0145, .0195, .0195),
        (-.206, side * .004, -.004, .0168, .0172, .0172),
    ], 'skin', fore, sides=32, density=3)

    finger_specs = [
        (-.020, .054, .0050),
        (-.0065, .062, .0053),
        (.0068, .057, .0049),
        (.019, .046, .0043),
    ]
    finger_names = ('Index', 'Middle', 'Ring', 'Little')
    medial = -side
    for i, (z_off, length, radius) in enumerate(finger_specs):
        z0 = -.006 + z_off
        x0 = side * .005
        start_y = -.267 + abs(z_off) * .18
        points = [
            (x0, start_y, z0),
            (x0 + medial * .002, start_y - length * .32, z0 + z_off * .08),
            (x0 + medial * .0055, start_y - length * .65, z0 + z_off * .11),
            (x0 + medial * .0105, start_y - length * .88, z0 + z_off * .09),
            (x0 + medial * .0145, start_y - length, z0 + z_off * .07),
        ]
        radii = [radius, radius * .90, radius * .78, radius * .64, radius * .35]
        _tube(api, 'HandFinger' + finger_names[i] + hand_name, points, radii,
              'skin', fore, sides=12, density=3, flatten=.88)
        tx, ty, tz = points[-1]
        _tube(api, 'PearlFingernail' + finger_names[i] + hand_name,
              [(tx + side * .0016, ty + .0055, tz), (tx + side * .0008, ty - .0015, tz)],
              [.0024, .0014], 'shell_pearl', fore, sides=8, density=2, flatten=.35)

    thumb_pts = [
        (medial * .004, -.228, -.017),
        (medial * .008, -.242, -.028),
        (medial * .010, -.257, -.035),
        (medial * .012, -.272, -.038),
        (medial * .014, -.283, -.036),
    ]
    _tube(api, 'HandFingerThumb' + hand_name, thumb_pts,
          [.0078, .0070, .0060, .0048, .0030], 'skin', fore, sides=12, density=3, flatten=.86)
    tx, ty, tz = thumb_pts[-1]
    _tube(api, 'PearlFingernailThumb' + hand_name,
          [(tx, ty + .005, tz - .0018), (tx, ty - .0015, tz - .0010)],
          [.0026, .0015], 'shell_pearl', fore, sides=8, density=2, flatten=.35)


def build(api):
    """Build sculpted feminine upper torso, scaled mermaid tail, and slender bare arms/hands."""
    _upper_torso(api)
    _mermaid_tail(api)
    for side in (-1, 1):
        _arms(api, side)
