"""Anatomically shaped expedition suit, authored from the locked diver concept.

All coordinates are Godot part-local coordinates: X across, Y up, -Z forwards.
The build API intentionally needs only ``surface``; this module never exports,
alters the production library, or replaces a 3D surface with a reference image.
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


def _smoothstep(edge0, edge1, x):
    t = max(0.0, min(1.0, (x - edge0) / (edge1 - edge0)))
    return t * t * (3.0 - 2.0 * t)


def _loft_curve(api, name, sections, material, driver, sides=40, density=4, deform=None):
    """Closed loft along (y, cx, cz, rx, front, back) sections."""
    rings = _resample(sorted(sections, key=lambda s: s[0]), density)
    vertices, faces, uv = [], [], []
    for i, (y, cx, cz, rx, front, back) in enumerate(rings):
        rx, front, back = max(rx, .001), max(front, .001), max(back, .001)
        for j in range(sides):
            phi = j / sides * TAU
            s, c = math.sin(phi), math.cos(phi)
            x = cx + rx * s
            z = cz + (-front * c if c > 0 else -back * c)
            point = (x, y, z)
            if deform:
                point = deform(point, phi)
            vertices.append(point)
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
    return api.surface(name, vertices, faces, material, driver=driver, uv=uv)


def _subtract(a, b):
    return tuple(x - y for x, y in zip(a, b))


def _cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2],
            a[0] * b[1] - a[1] * b[0])


def _unit(a):
    scale = max(1e-10, math.sqrt(sum(c * c for c in a)))
    return tuple(c / scale for c in a)


def _tube(api, name, points, radii, material, driver, sides=10, density=3,
          flatten=1):
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
    return api.surface(name, vertices, faces, material, driver=driver, uv=uv)


def _taubin_smooth(vertices, faces, mask_fn, passes=4, lam=.38, mu=-.40):
    adj = [set() for _ in vertices]
    for face in faces:
        n = len(face)
        for i in range(n):
            a, b = face[i], face[(i + 1) % n]
            adj[a].add(b)
            adj[b].add(a)
    pts = [list(v) for v in vertices]
    active = [i for i, v in enumerate(pts) if mask_fn(v) and adj[i]]
    for _ in range(passes):
        for factor in (lam, mu):
            nxt = [p[:] for p in pts]
            for i in active:
                nbrs = adj[i]
                inv = 1.0 / len(nbrs)
                for k in range(3):
                    avg = sum(pts[j][k] for j in nbrs) * inv
                    nxt[i][k] += factor * (avg - pts[i][k])
            pts = nxt
    return [tuple(p) for p in pts]


def _project_seam_on_mesh(api, name, target_obj, waypoints, driver='body', radius=.00125):
    """Project 3D waypoints onto the sculpted suit surface via BVH closest/ray."""
    import bpy
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    tree = BVHTree.FromObject(target_obj, bpy.context.evaluated_depsgraph_get())
    dense = _resample(waypoints, 5)
    snapped = []
    for x, y, z in dense:
        co_b = Vector((x, -z, y))
        loc, normal, _, _ = tree.find_nearest(co_b)
        if loc is None:
            snapped.append((x, y, z))
        else:
            out = loc + normal * (radius * .52)
            snapped.append((out.x, out.z, -out.y))
    return _tube(api, name, snapped, [radius] * len(snapped), 'seam', driver, sides=8, density=1)


def _torso_pelvis_and_legs(api):
    """Single watertight manifold pair-of-pants suit from collar to ankles."""
    # (y, half_width, front_depth, back_depth, z_shift)
    torso_spec = [
        (-.172, .133, .055, .078, .008),
        (-.145, .134, .058, .082, .009),
        (-.105, .125, .059, .074, .006),
        (-.055, .104, .056, .062, .002),
        (-.005, .083, .051, .051, -.002),
        (.038, .076, .048, .048, -.004),
        (.082, .088, .058, .053, -.004),
        (.126, .105, .074, .057, -.003),
        (.172, .114, .063, .055, .000),
        (.212, .118, .050, .049, .002),
        (.236, .090, .044, .043, .003),
        (.256, .056, .040, .039, .004),
        (.278, .045, .037, .036, .004),
    ]
    torso_rings = _resample(torso_spec, 3)
    M = 28
    sides = 2 * M
    S = 8

    def sculpt_torso(x, y, z, phi):
        c = math.cos(phi)
        front = max(0.0, c) ** 2.2
        back = max(0.0, -c) ** 2.0
        # Natural feminine bust contours & central sternum hollow
        bust_y = math.exp(-((y - .126) / .046) ** 2)
        cup = math.exp(-((abs(x) - .049) / .038) ** 2)
        sternum = math.exp(-(x / .019) ** 2)
        z -= .0155 * bust_y * cup * front
        z += .0055 * bust_y * sternum * front
        # Subtle underbust definition & navel-line softness
        under = math.exp(-((y - .080) / .022) ** 2) * cup
        z += .0028 * under * front
        # Scapula & lumbar/gluteal cleft sculpting on the back
        cleft = math.exp(-(x / .020) ** 2) * _smoothstep(-.05, -.15, -y if False else 0)
        glute_y = math.exp(-((y + .148) / .052) ** 2)
        glute_lobe = math.exp(-((abs(x) - .060) / .048) ** 2)
        glute_cleft = math.exp(-(x / .018) ** 2)
        z += .009 * glute_y * glute_lobe * back
        z -= .011 * glute_y * glute_cleft * back
        # Gentle spinal channel along lumbar back
        spine = math.exp(-((y - .055) / .095) ** 2) * math.exp(-(x / .022) ** 2)
        z -= .0045 * spine * back
        return (x, y, z)

    vertices, uv, faces = [], [], []
    # Build from top collar down to pelvic split so ring indices run top -> bottom
    ordered_torso = list(reversed(torso_rings))
    ring_indices = []
    for r_i, (y, w, front, back, shift) in enumerate(ordered_torso):
        row_idx = []
        for j in range(sides):
            phi = j / sides * TAU
            s, c = math.sin(phi), math.cos(phi)
            x = w * s
            z = shift + (-front * c if c > 0 else -back * c)
            pt = sculpt_torso(x, y, z, phi)
            row_idx.append(len(vertices))
            vertices.append(pt)
            uv.append((j / sides, .55 + .45 * (1.0 - r_i / max(1, len(ordered_torso) - 1))))
        ring_indices.append(row_idx)

    # Cap top collar
    top_y, _, _, _, top_shift = ordered_torso[0]
    top_c = len(vertices)
    vertices.append((0.0, top_y, top_shift))
    uv.append((.5, 1.0))
    for j in range(sides):
        faces.append((top_c, ring_indices[0][(j + 1) % sides], ring_indices[0][j]))

    for r_i in range(len(ring_indices) - 1):
        r0, r1 = ring_indices[r_i], ring_indices[r_i + 1]
        for j in range(sides):
            j1 = (j + 1) % sides
            faces.append((r0[j], r0[j1], r1[j1], r1[j]))

    # Crotch saddle curve along x = 0 connecting front (j=0) to back (j=M)
    split_ring = ring_indices[-1]
    p_front = vertices[split_ring[0]]
    p_back = vertices[split_ring[M]]
    crotch_idx = [split_ring[0]]
    for u in range(1, S):
        t = u / S
        arch = math.sin(t * math.pi)
        cy = p_front[1] * (1.0 - t) + p_back[1] * t - .021 * (arch ** .85)
        cz = p_front[2] * (1.0 - t) + p_back[2] * t
        crotch_idx.append(len(vertices))
        vertices.append((0.0, cy, cz))
        uv.append((.5, .52))
    crotch_idx.append(split_ring[M])

    # Leg cross-sections: (y, cx_mag, cz, rx_outer, rx_inner, front, back)
    # Seamless tangent continuation from hip outer x=0.133 at y=-0.172!
    leg_spec = [
        (-.196, .073, .009, .057, .058, .056, .072),
        (-.225, .077, .010, .051, .050, .055, .065),
        (-.265, .080, .010, .043, .040, .050, .056),
        (-.320, .081, .010, .037, .034, .044, .047),
        (-.380, .082, .010, .031, .029, .036, .038),
        (-.435, .082, .010, .028, .027, .030, .032),
        (-.480, .083, .012, .032, .029, .031, .037),
        (-.528, .083, .014, .036, .032, .032, .043),
        (-.585, .082, .012, .030, .027, .028, .034),
        (-.640, .081, .010, .024, .022, .024, .027),
        (-.698, .080, .010, .021, .020, .022, .024),
    ]
    leg_rings = _resample(leg_spec, 3)
    N_leg = M + S  # 36 vertices per leg ring

    for side in (1, -1):
        if side > 0:
            # Right leg (+X): j=0..M (front -> +X -> back), then crotch S-1..1 (back -> front)
            prev_loop = [split_ring[j] for j in range(M + 1)] + [crotch_idx[u] for u in range(S - 1, 0, -1)]
        else:
            # Left leg (-X): crotch 0..S (front -> back), then j=M+1..2M-1 (back -> -X -> front)
            prev_loop = [crotch_idx[u] for u in range(S + 1)] + [split_ring[j] for j in range(M + 1, sides)]

        for l_i, (y, cx_m, cz, rx_out, rx_in, front, back) in enumerate(leg_rings):
            cx = side * cx_m
            cur_loop = []
            # Match parameter angle of prev_loop seamlessly!
            for k in range(N_leg):
                if side > 0:
                    if k <= M:
                        phi = (k / M) * math.pi  # 0 (front) -> pi/2 (+X) -> pi (back)
                    else:
                        phi = math.pi + ((k - M) / S) * math.pi  # pi (back) -> 2pi (front)
                    s, c = math.sin(phi), math.cos(phi)
                    rx = rx_out if s >= 0 else rx_in
                    x = cx + rx * s
                else:
                    if k <= S:
                        phi = (k / S) * math.pi  # 0 (front) -> pi (back) on medial (+X side of left leg)
                    else:
                        phi = math.pi + ((k - S) / M) * math.pi  # pi (back) -> 3pi/2 (-X) -> 2pi (front)
                    s, c = math.sin(phi), math.cos(phi)
                    rx = rx_in if s >= 0 else rx_out
                    x = cx + rx * s
                # Prevent medial thigh overlap near crotch while keeping smooth arch
                if side > 0 and x < .004:
                    x = .004 + (x - .004) * .15
                elif side < 0 and x > -.004:
                    x = -.004 + (x + .004) * .15
                z = cz + (-front * c if c > 0 else -back * c)
                # Subtle quad & shin contour
                quad = math.exp(-((y + .30) / .085) ** 2) * max(0.0, c) ** 2
                z -= .0025 * quad
                cur_loop.append(len(vertices))
                vertices.append((x, y, z))
                uv.append((k / N_leg, .52 * (1.0 - (l_i + 1) / len(leg_rings))))
            for k in range(N_leg):
                k1 = (k + 1) % N_leg
                faces.append((prev_loop[k], prev_loop[k1], cur_loop[k1], cur_loop[k]))
            prev_loop = cur_loop

        # Cap ankle bottom
        ay, acx_m, acz, _, _, _, _ = leg_rings[-1]
        bot_c = len(vertices)
        vertices.append((side * acx_m, ay, acz))
        uv.append((.5, 0.0))
        for k in range(N_leg):
            faces.append((bot_c, prev_loop[k], prev_loop[(k + 1) % N_leg]))

    vertices = _taubin_smooth(vertices, faces, lambda v: -.255 < v[1] < -.125, passes=4)
    suit_obj = api.surface('TailoredTorsoPelvisAndLegs', vertices, faces, 'suit',
                           driver='body', uv=uv, deform_mode='suit_body')

    # Crisp raised pale-gold anatomical piping seams matching diver.png
    _project_seam_on_mesh(api, 'SternumSuitClosure', suit_obj,
                          [(0.0, .270, -.045), (0.0, .190, -.065), (0.0, .125, -.075),
                           (0.0, .055, -.058), (0.0, -.025, -.058)], 'body', radius=.0012)
    for side in (-1, 1):
        tag = 'Left' if side < 0 else 'Right'
        drv_leg = 'leg_l' if side < 0 else 'leg_r'
        drv_calf = 'calf_l' if side < 0 else 'calf_r'
        # Front princess + underbust + high-waist + iliac flare seam
        _project_seam_on_mesh(api, 'PrincessPanelSeam' + tag, suit_obj, [
            (side * .042, .248, -.045), (side * .068, .192, -.062),
            (side * .086, .132, -.078), (side * .058, .078, -.064),
            (side * .046, .032, -.054), (side * .068, -.045, -.060),
            (side * .096, -.125, -.055), (side * .108, -.185, -.035),
        ], 'body', radius=.0013)
        # Underbust cup contour arc visible in swimming close-up
        _project_seam_on_mesh(api, 'UnderbustCupSeam' + tag, suit_obj, [
            (side * .006, .112, -.072), (side * .028, .086, -.075),
            (side * .058, .082, -.070), (side * .088, .108, -.062),
        ], 'body', radius=.0011)
        # Back scapular -> waist -> heart-shaped upper-glute arch seam
        _project_seam_on_mesh(api, 'BackTailoredPanelSeam' + tag, suit_obj, [
            (side * .040, .250, .042), (side * .072, .185, .056),
            (side * .068, .110, .058), (side * .050, .038, .052),
            (side * .058, -.045, .062), (side * .096, -.115, .072),
            (side * .114, -.175, .052),
        ], 'body', radius=.00125)
        _project_seam_on_mesh(api, 'GluteArchSeam' + tag, suit_obj, [
            (0.0, -.082, .072), (side * .048, -.096, .078),
            (side * .092, -.128, .076),
        ], 'body', radius=.0012)
        # Outer & inner thigh tailoring seams (expressed in world, shifted to leg driver local? Wait: keep on body or shift!)
        # Convert world seam points to leg/calf driver-local so semantic leg/calf seam parts remain!
        leg_origin = (side * .08, -.17, .01)
        calf_origin = (side * .08, -.435, .01)
        for name_s, wpts, drv, orig in [
            ('OuterThighSeam' + tag, [
                (side * .128, -.190, -.010), (side * .120, -.255, -.018),
                (side * .110, -.330, -.024), (side * .102, -.405, -.024),
            ], drv_leg, leg_origin),
            ('InnerThighSeam' + tag, [
                (side * .036, -.215, -.022), (side * .045, -.285, -.028),
                (side * .055, -.355, -.026), (side * .062, -.410, -.022),
            ], drv_leg, leg_origin),
            ('SweepingShinSeam' + tag, [
                (side * .102, -.455, -.018), (side * .108, -.515, -.005),
                (side * .102, -.580, -.014), (side * .092, -.650, -.020),
            ], drv_calf, calf_origin),
            ('BackCalfChevronSeam' + tag, [
                (side * .060, -.520, .052), (side * .083, -.490, .056),
                (side * .108, -.525, .048),
            ], drv_calf, calf_origin),
        ]:
            import bpy
            from mathutils import Vector
            from mathutils.bvhtree import BVHTree
            tree = BVHTree.FromObject(suit_obj, bpy.context.evaluated_depsgraph_get())
            dense = _resample(wpts, 5)
            local_pts = []
            for wx, wy, wz in dense:
                loc, normal, _, _ = tree.find_nearest(Vector((wx, -wz, wy)))
                out = loc + normal * .00065 if loc is not None else Vector((wx, -wz, wy))
                gx, gy, gz = out.x, out.z, -out.y
                local_pts.append((gx - orig[0], gy - orig[1], gz - orig[2]))
            _tube(api, name_s, local_pts, [.0012] * len(local_pts), 'seam', drv,
                  sides=8, density=1)


def _arms(api, side):
    driver = 'arm_l' if side < 0 else 'arm_r'
    fore = 'forearm_l' if side < 0 else 'forearm_r'
    hand_name = 'Left' if side < 0 else 'Right'
    # Continuous sleek feminine sleeve from tucked shoulder cap (world x=+-0.124)
    # through gently angled A-line elbow (world x=+-0.176) to wrist (world x=+-0.184).
    # Expressed in arm_l/arm_r local coords (origin at +-0.18, +0.19, 0):
    sleeve = [
        (-.446, side * .004, -.004, .019, .018, .019),
        (-.415, side * .003, -.003, .021, .020, .021),
        (-.360, side * .001, -.001, .025, .024, .026),
        (-.305, -side * .001, .001, .029, .027, .029),
        (-.265, -side * .003, .002, .029, .027, .028),
        (-.235, -side * .004, .002, .027, .026, .027),
        (-.195, -side * .010, .001, .029, .029, .030),
        (-.135, -side * .020, .000, .032, .032, .033),
        (-.070, -side * .033, .001, .035, .035, .036),
        (-.015, -side * .044, .002, .037, .036, .037),
        (.022, -side * .054, .003, .034, .032, .033),
        (.042, -side * .064, .004, .022, .022, .022),
    ]
    sleeve_obj = _loft_curve(api, 'NaturalUpperSleeve' + hand_name, sleeve, 'suit',
                             driver, sides=36, density=4)
    sleeve_obj['deform_mode'] = 'suit_arm'
    _project_seam_on_mesh(api, 'UpperSleeveSeam' + hand_name, sleeve_obj, [
        (-side * .020, .005, -.032), (-side * .002, -.075, -.033),
        (side * .008, -.155, -.028), (side * .014, -.235, -.024),
        (side * .018, -.335, -.022), (side * .020, -.425, -.016),
    ], driver, radius=.00115)
    api.ObjectsLastSeam = None
    # Subtle suit cuff ring on forearm driver so forearm__Glove...Suit semantic slot stays populated
    _loft_curve(api, 'TailoredForearmCuff' + hand_name, [
        (-.215, side * .004, -.004, .0195, .0185, .0195),
        (-.200, side * .003, -.003, .0202, .0192, .0202),
    ], 'suit', fore, sides=28, density=2)

    # Natural thumb-forward (-Z), palm-medial (-side*X) sleek expedition dive gloves!
    # Hand socket is at (0, -0.255, -0.005) in forearm local space.
    _loft_curve(api, 'FittedGlovePalm' + hand_name, [
        (-.276, side * .004, -.006, .011, .023, .021),
        (-.262, side * .005, -.006, .013, .028, .025),
        (-.242, side * .005, -.005, .014, .027, .024),
        (-.224, side * .004, -.004, .016, .021, .021),
        (-.208, side * .004, -.004, .019, .019, .019),
    ], 'rubber', fore, sides=32, density=3)

    # Four fingers arranged front-to-back along Z (Index at -Z, Little at +Z), curving gently medially!
    finger_specs = [
        (-.021, .054, .0058),  # Index (anterior -Z)
        (-.007, .062, .0062),  # Middle
        (.007, .057, .0058),   # Ring
        (.020, .046, .0050),   # Little (posterior +Z)
    ]
    finger_names = ('Index', 'Middle', 'Ring', 'Little')
    medial = -side  # +1 for Left hand, -1 for Right hand (inward toward thighs)
    for i, (z_off, length, radius) in enumerate(finger_specs):
        z0 = -.006 + z_off
        x0 = side * .005
        start_y = -.268 + abs(z_off) * .18
        points = [
            (x0, start_y, z0),
            (x0 + medial * .002, start_y - length * .32, z0 + z_off * .08),
            (x0 + medial * .006, start_y - length * .65, z0 + z_off * .12),
            (x0 + medial * .012, start_y - length * .88, z0 + z_off * .10),
            (x0 + medial * .016, start_y - length, z0 + z_off * .08),
        ]
        radii = [radius, radius * .92, radius * .82, radius * .68, radius * .38]
        _tube(api, 'GloveFinger' + finger_names[i] + hand_name, points, radii,
              'rubber', fore, sides=12, density=3, flatten=.90)

    # Thumb emerging anteriorly (-Z) and medially in natural relaxed opposition
    _tube(api, 'GloveFingerThumb' + hand_name, [
        (medial * .004, -.228, -.018),
        (medial * .008, -.242, -.029),
        (medial * .010, -.258, -.037),
        (medial * .012, -.274, -.040),
        (medial * .014, -.286, -.038),
    ], [.0088, .0080, .0070, .0058, .0035], 'rubber', fore, sides=12, density=3, flatten=.88)

    # Crisp pale-gold dorsal glove piping lines visible in swim_legs_fins.png
    for z_off in (-.011, .0, .011):
        _tube(api, 'DorsalGloveSeam' + hand_name + str(z_off), [
            (side * .019, -.216, -.004 + z_off * .6),
            (side * .019, -.240, -.005 + z_off),
            (side * .016, -.264, -.006 + z_off * 1.25),
        ], [.00085] * 3, 'seam', fore, sides=6, density=2)


def build(api):
    """Build anatomical suit surfaces and five-finger gloves through surface()."""
    _torso_pelvis_and_legs(api)
    for side in (-1, 1):
        _arms(api, side)

