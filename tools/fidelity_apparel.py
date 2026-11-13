"""Royal Siren shell bodice, draped Akoya pearls, translucent gossamer hip/arm fins & grand caudal fluke."""
import math
from mathutils import Vector


TAU = math.tau


def _thick_grid(api, name, grid, thickness, material, driver='body', deform_mode=None, uv_fn=None):
    """Convert a (rows x cols) 3D surface grid into a watertight 3D thin solid."""
    rows = len(grid)
    cols = len(grid[0])
    verts, uv, faces = [], [], []
    for shell in (0, 1):
        sgn = .5 if shell == 0 else -.5
        for r in range(rows):
            for c in range(cols):
                p = Vector(grid[r][c])
                p_u = Vector(grid[r][min(cols - 1, c + 1)]) - Vector(grid[r][max(0, c - 1)])
                p_v = Vector(grid[min(rows - 1, r + 1)][c]) - Vector(grid[max(0, r - 1)][c])
                nrm = p_u.cross(p_v)
                if nrm.length < 1e-8:
                    nrm = Vector((0, 0, 1))
                else:
                    nrm.normalize()
                fade = 1.0 - .58 * (r / max(1, rows - 1))
                pt = p + nrm * (thickness * fade * sgn)
                verts.append((pt.x, pt.y, pt.z))
                if uv_fn:
                    uv.append(uv_fn(r, c, rows, cols))
                else:
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
    return api.surface(name, verts, faces, material, driver=driver, uv=uv, deform_mode=deform_mode)


def _pearl_strand(api, prefix, waypoints, count, min_r=.0026, max_r=.0040, driver='body', deform_mode=None):
    """Drape a smooth cord of gold thread studded with graduated Akoya pearls."""
    pts = [Vector(p) for p in waypoints]
    dense = []
    steps = max(4, count * 2)
    for s in range(steps + 1):
        t = s / steps * (len(pts) - 1)
        i = min(len(pts) - 2, int(t))
        f = t - i
        p0 = pts[max(0, i - 1)]
        p1, p2 = pts[i], pts[i + 1]
        p3 = pts[min(len(pts) - 1, i + 2)]
        pt = .5 * (2 * p1 + (-p0 + p2) * f + (2 * p0 - 5 * p1 + 4 * p2 - p3) * f * f
                   + (-p0 + 3 * p1 - 3 * p2 + p3) * (f ** 3))
        dense.append((pt.x, pt.y, pt.z))
    cord = api.tube(prefix + 'GoldThread', dense, [.0008] * len(dense), 'gold_light', driver=driver, sides=6)
    if deform_mode:
        cord['deform_mode'] = deform_mode
    for k in range(count):
        u = (k + .5) / count
        idx = min(len(dense) - 1, int(round(u * (len(dense) - 1))))
        pr = min_r + (max_r - min_r) * math.sin(u * math.pi)
        pearl = api.ellipsoid(f'{prefix}Pearl{k:02d}', dense[idx], (pr, pr, pr),
                              'pearl', driver=driver, segments=10, rings=7)
        if deform_mode:
            pearl['deform_mode'] = deform_mode


def _fit_back(api, x, y, offset=.0022):
    import bpy
    from mathutils.bvhtree import BVHTree
    torso = next(o for o in api.objects if o['driver'] == 'body' and 'torso' in o.name.lower())
    tree = BVHTree.FromObject(torso, bpy.context.evaluated_depsgraph_get())
    hit, _, _, _ = tree.ray_cast(Vector((x, -1.0, y)), Vector((0, 1.0, 0)))
    return -hit.y + offset if hit is not None else .056


def _shell_bodice_and_pearls(api):
    """Sculpted 3D fluted Mother-of-Pearl Scallop Shell cups, crystal pendant & bare-back pearl drapes."""
    for side, tag in ((-1, 'L'), (1, 'R')):
        hinge_x, hinge_y = side * .018, .098
        rows_s, cols_s = 13, 21
        grid = []
        for r in range(rows_s):
            tr = r / (rows_s - 1)
            row = []
            for c in range(cols_s):
                tc = c / (cols_s - 1)
                ang = -.18 + tc * 1.62
                scallop = 1.0 + .055 * math.cos(tc * math.pi * 8.0) * (tr ** 1.6)
                rad = (.008 + .072 * (tr ** .86)) * scallop
                px = hinge_x + side * rad * math.sin(ang) * 1.05
                py = hinge_y + rad * (.46 + .54 * math.cos(ang - .58))
                flute = .0026 * math.cos(tc * math.pi * 8.0) * math.sin(tr * math.pi * .9)
                cup_dome = .0038 * math.sin(tr * math.pi) * math.sin(tc * math.pi)
                pz = api.fit_front(px, py, .0022 + flute + cup_dome)
                row.append((px, py, pz))
            grid.append(row)
        _thick_grid(api, 'ScallopShellCup' + tag, grid, .0028, 'shell_pearl', driver='body')
        rim_pts = [grid[-1][c] for c in range(cols_s)]
        api.tube('ScallopGoldFiligreeRim' + tag, rim_pts, [.0013] * cols_s, 'gold_light', 'body', sides=7)
        hz = api.fit_front(hinge_x, hinge_y, .0045)
        api.ellipsoid('ScallopHingeGold' + tag, (hinge_x, hinge_y, hz), (.005, .005, .003), 'gold', 'body', 16, 10)

        swag = []
        for i in range(9):
            u = i / 8
            sx = side * (.012 + .084 * u)
            sy = .102 - .022 * math.sin(u * math.pi) + .016 * u
            swag.append((sx, sy, api.fit_front(sx, sy, .0032)))
        _pearl_strand(api, 'UnderbustPearlSwag' + tag, swag, 9, .0024, .0036)

        halter = [
            (side * .058, .164, api.fit_front(side * .058, .164, .003)),
            (side * .066, .206, api.fit_front(side * .066, .206, .003)),
            (side * .068, .222, .008),
            (side * .062, .205, _fit_back(api, side * .062, .205, .003)),
            (0.0, .148, _fit_back(api, 0.0, .148, .004)),
            (-side * .072, .098, _fit_back(api, -side * .072, .098, .003)),
            (-side * .088, .112, .002),
            (-side * .084, .118, api.fit_front(-side * .084, .118, .003)),
        ]
        _pearl_strand(api, 'HalterCrossBackPearls' + tag, halter, 18, .0024, .0035, deform_mode='hose_bridge')

    neck_pts = []
    for i in range(13):
        u = i / 12 * 2.0 - 1.0
        nx = u * .068
        ny = .208 - .026 * (1.0 - u * u)
        neck_pts.append((nx, ny, api.fit_front(nx, ny, .0028)))
    _pearl_strand(api, 'ClaviclePearlChoker', neck_pts, 13, .0022, .0034)

    cz = api.fit_front(0.0, .114, .0065)
    api.ellipsoid('BodiceCenterGoldBezel', (0.0, .114, cz + .0015), (.0095, .0125, .0035), 'gold', 'body', 22, 14)
    api.ellipsoid('BodiceCenterCrystalGlass', (0.0, .114, cz - .0012), (.0072, .0100, .0042), 'glass', 'body', 22, 14)
    api.tube('BodiceDropLink', [(0.0, .102, cz), (0.0, .086, cz + .002)], [.0009, .0009], 'gold_light', 'body', 6)
    api.ellipsoid('BodiceTeardropPearl', (0.0, .080, cz + .002), (.0046, .0062, .0046), 'pearl', 'body', 18, 14)

    bz = _fit_back(api, 0.0, .148, .005)
    api.ellipsoid('BackCrossGoldMedallion', (0.0, .148, bz), (.008, .008, .003), 'gold', 'body', 18, 12)
    api.ellipsoid('BackCrossPearlCenter', (0.0, .148, bz + .002), (.0045, .0045, .0035), 'pearl', 'body', 16, 12)


def _siren_hip_girdle_and_veil_fins(api):
    """V-contoured Gold & Pearl Siren Hip Girdle, Starlight Vial & fluttering Lateral Hip Veil-Fins."""
    girdle_upper, girdle_lower = [], []
    segs = 64
    for j in range(segs + 1):
        phi = j / segs * TAU
        s, c = math.sin(phi), math.cos(phi)
        y_v = -.052 - .040 * (c ** 2)
        rx, front, back, shift = .109, .057, .065, .003
        x = rx * s
        z = shift + (-front * c if c > 0 else -back * c)
        girdle_upper.append((x, y_v + .003, z))
        girdle_lower.append((x * 1.02, y_v - .007, z * 1.02))
    g_up = api.tube('SirenVGirdleGold', girdle_upper, [.0026] * len(girdle_upper), 'gold', 'body', sides=8)
    g_up['deform_mode'] = 'mermaid_tail'
    g_lo = api.tube('SirenVGirdleFiligree', girdle_lower, [.0016] * len(girdle_lower), 'gold_light', 'body', sides=7)
    g_lo['deform_mode'] = 'mermaid_tail'

    for k in range(20):
        idx = int(round(k / 20 * segs))
        px, py, pz = girdle_upper[idx]
        pr = .0034 if k in (0, 10) else .0026
        p_obj = api.ellipsoid(f'GirdleStudPearl{k:02d}', (px * 1.02, py, pz * 1.02),
                              (pr, pr, pr), 'pearl', 'body', 10, 7)
        p_obj['deform_mode'] = 'mermaid_tail'

    fx, fy, fz = 0.0, -.094, -.058
    for arm_i in range(5):
        a = arm_i / 5 * TAU - math.pi * .5
        st = api.tube(f'HipApexStarArm{arm_i}',
                      [(fx, fy, fz), (fx + .016 * math.cos(a), fy + .016 * math.sin(a), fz + .002)],
                      [.0036, .0009], 'gold', 'body', sides=7)
        st['deform_mode'] = 'mermaid_tail'
    gem = api.ellipsoid('HipApexCrystalGlass', (fx, fy, fz - .0025), (.0065, .0082, .0038), 'glass', 'body', 20, 12)
    gem['deform_mode'] = 'mermaid_tail'

    for side, tag in ((-1, 'L'), (1, 'R')):
        for tier, drop in enumerate((.042, .072)):
            chain = []
            for i in range(11):
                u = i / 10
                ang = u * math.pi
                c_a, s_a = math.cos(ang), math.sin(ang)
                sag = drop * math.sin(u * math.pi)
                cy = -.056 - .038 * (c_a ** 2) - sag
                rx_h = .112 + .022 * min(1.0, (-cy - .055) / .09)
                fr_h = .058 + .006 * min(1.0, (-cy - .055) / .09)
                bk_h = .066 + .016 * min(1.0, (-cy - .055) / .09)
                cx = side * rx_h * s_a
                cz = .006 + (-fr_h * c_a if c_a > 0 else -bk_h * c_a)
                chain.append((cx, cy, cz))
            _pearl_strand(api, f'HipDrapedPearlChain{tag}{tier}', chain, 11 + tier * 3,
                          .0023, .0036, deform_mode='mermaid_tail')

        rows_f, cols_f = 16, 19
        core_grid, veil_grid = [], []
        for r in range(rows_f):
            tr = r / (rows_f - 1)
            c_row, v_row = [], []
            for c in range(cols_f):
                tc = c / (cols_f - 1)
                ang = .55 + tc * 1.85
                s_a, c_a = math.sin(ang), math.cos(ang)
                root_y = -.058 - .032 * (c_a ** 2) - .028 * tc
                root_x = side * .108 * s_a
                root_z = .005 + (-.056 * c_a if c_a > 0 else -.068 * c_a)

                # Rounded orchid/butterfly petal envelope (zero square corners, sweeps gracefully aft!)
                petal_arch = math.sin((tc * .86 + .07) * math.pi) ** .68
                petal_flare = math.sin(tr * math.pi * .78) * petal_arch
                scallop = 1.0 + .08 * math.cos(tc * math.pi * 5.0) * (tr ** 1.3)
                pleat = .0085 * math.sin(tc * math.pi * 5.0 + tr * 1.6) * tr * petal_arch
                tr_c = tr * .62
                flare_c = (.048 * math.sin(tr_c * math.pi * .82) * petal_arch) * scallop
                drop_c = (.165 * (tr_c ** 1.04)) * (.55 + .55 * petal_arch)
                c_row.append((root_x + side * flare_c * (.55 + .45 * s_a) - side * .018 * (tr_c ** 1.8),
                              root_y - drop_c,
                              root_z + .042 * tr_c + pleat * .6))
                flare_v = (.072 * petal_flare) * scallop
                drop_v = (.255 * (tr ** 1.04)) * (.52 + .58 * petal_arch)
                v_row.append((root_x + side * flare_v * (.55 + .45 * s_a) - side * .028 * (tr ** 1.8),
                              root_y - drop_v,
                              root_z + .064 * tr + pleat))
            core_grid.append(c_row)
            veil_grid.append(v_row)
        _thick_grid(api, 'HipCorePetalFin' + tag, core_grid, .0024, 'fin_pearl',
                    driver='body', deform_mode='mermaid_tail')
        _thick_grid(api, 'HipTranslucentGlassVeilFin' + tag, veil_grid, .0016, 'glass',
                    driver='body', deform_mode='mermaid_tail')
        base_leg = (-.025 if side < 0 else .025, -.17, .01)
        for ray_i in range(5):
            ci = int(round((ray_i + .5) / 5 * (cols_f - 1)))
            local_pts = [(veil_grid[r][ci][0] - base_leg[0],
                          veil_grid[r][ci][1] - base_leg[1],
                          veil_grid[r][ci][2] - base_leg[2]) for r in range(rows_f)]
            ray = api.tube(f'HipVeilFinRay{tag}{ray_i}', local_pts,
                           [.0018 * (1.0 - .68 * r / (rows_f - 1)) for r in range(rows_f)],
                           'gold_light' if ray_i in (0, 4) else 'fin_pearl',
                           'leg_l' if side < 0 else 'leg_r', sides=6)
            ray['deform_mode'] = 'mermaid_tail'

    vx, vy, vz = -.128, -.126, -.024
    for nm, cy0, rx0, ry0, mat in [
        ('StarlightVialTopGold', vy + .030, .011, .008, 'gold'),
        ('StarlightVialBotGold', vy - .030, .011, .008, 'gold'),
        ('StarlightVialGlass', vy, .013, .028, 'glass'),
        ('StarlightEssenceCore', vy, .0065, .018, 'specimen_gold'),
    ]:
        o = api.ellipsoid(nm, (vx, cy0, vz), (rx0, ry0, rx0), mat, 'body', 16, 10)
        o['deform_mode'] = 'mermaid_tail'


def _arm_jewelry_and_fins(api):
    """Coiled Sea-Gold & Pearl upper armlets, wrist bracelets & translucent forearm fin-frills."""
    for side, tag in ((-1, 'l'), (1, 'r')):
        drv_arm = 'arm_' + tag
        drv_fore = 'forearm_' + tag
        sgn = -1 if side < 0 else 1
        coil = []
        for i in range(37):
            t = i / 36
            a = t * TAU * 1.65
            yy = -.068 - .058 * t
            cx = -sgn * (.033 - .015 * t)
            r = .0325 - .0025 * t
            coil.append((cx + r * math.cos(a), yy, .001 + r * math.sin(a)))
        armlet = api.tube('SpiralGoldArmlet' + tag, coil, [.0020] * len(coil), 'gold', drv_arm, sides=7)
        armlet['deform_mode'] = 'suit_arm'
        for p_k in (0, 18, 36):
            ap = api.ellipsoid(f'ArmletPearl{tag}{p_k}', coil[p_k], (.0032, .0032, .0032),
                               'pearl', drv_arm, 14, 10)
            ap['deform_mode'] = 'suit_arm'

        wrist_ring = [(sgn * .004 + .0185 * math.cos(i / 24 * TAU),
                       -.202,
                       -.004 + .0185 * math.sin(i / 24 * TAU)) for i in range(25)]
        api.tube('WristGoldBracelet' + tag, wrist_ring, [.0016] * 25, 'gold_light', drv_fore, sides=7)
        for pk in range(8):
            idx = pk * 3
            api.ellipsoid(f'WristPearl{tag}{pk}', wrist_ring[idx], (.0026, .0026, .0026),
                          'pearl', drv_fore, 12, 8)

        rows_a, cols_a = 9, 13
        f_grid = []
        for r in range(rows_a):
            tr = r / (rows_a - 1)
            row = []
            for c in range(cols_a):
                tc = c / (cols_a - 1)
                root_y = -.035 - .145 * tc
                root_x = sgn * (.016 + .006 * tc)
                root_z = .016 - .004 * tc
                scallop = 1.0 + .12 * math.cos(tc * math.pi * 4.0) * tr
                span = (.056 * math.sin((tc * .85 + .10) * math.pi) * (tr ** .88)) * scallop
                pleat = .0045 * math.sin(tc * math.pi * 4.0) * tr
                row.append((root_x + sgn * span * .38 + pleat,
                            root_y - span * .32,
                            root_z + span * .92))
            f_grid.append(row)
        _thick_grid(api, 'ForearmGlassFinFrill' + tag, f_grid, .0014, 'glass', driver=drv_fore)
        for ri in (0, 4, 8, 12):
            r_pts = [f_grid[r][ri] for r in range(rows_a)]
            api.tube(f'ForearmFinRay{tag}{ri}', r_pts,
                     [.0013 * (1.0 - .65 * r / (rows_a - 1)) for r in range(rows_a)],
                     'fin_pearl', drv_fore, sides=5)


def _dorsal_crest_and_peduncle_crown(api):
    """Graceful translucent dorsal tail crest & ornate gold-pearl caudal peduncle crown."""
    rows_d, cols_d = 10, 17
    d_grid = []
    for r in range(rows_d):
        tr = r / (rows_d - 1)
        row = []
        for c in range(cols_d):
            tc = c / (cols_d - 1)
            wy = -.310 - .350 * tc
            t_tail = (-wy - .052) / (.736 - .052)
            back_z = .009 + (.062 * (1.0 - t_tail) + .018 * t_tail) * .96
            scallop = 1.0 + .10 * math.cos(tc * math.pi * 5.0) * tr
            height = .068 * math.sin((tc * .88 + .06) * math.pi) * (tr ** .86) * scallop
            wave_x = .0055 * math.sin(tc * math.pi * 5.0) * tr
            row.append((wave_x, wy - height * .38, back_z + height * .94))
        d_grid.append(row)
    calf_l_grid = [[(x + .025, y + .435, z - .01) for (x, y, z) in row] for row in d_grid]
    _thick_grid(api, 'TailDorsalGlassCrest', calf_l_grid, .0016, 'glass',
                driver='calf_l', deform_mode='mermaid_tail')
    for ri in range(5):
        ci = int(round(ri / 4 * (cols_d - 1)))
        drv = 'calf_l' if ri % 2 == 0 else 'calf_r'
        bx = -.025 if drv == 'calf_l' else .025
        pts = [(d_grid[r][ci][0] - bx, d_grid[r][ci][1] + .435, d_grid[r][ci][2] - .01) for r in range(rows_d)]
        ray = api.tube(f'TailDorsalFinRay{ri}', pts,
                       [.0017 * (1.0 - .65 * r / (rows_d - 1)) for r in range(rows_d)],
                       'fin_pearl', drv, sides=6)
        ray['deform_mode'] = 'mermaid_tail'

    crown_pts = []
    for j in range(41):
        phi = j / 40 * TAU
        s, c = math.sin(phi), math.cos(phi)
        wy = -.678 - .018 * (c ** 2)
        wx = .026 * s
        wz = .010 - .020 * c
        crown_pts.append((wx, wy, wz))
    ped = api.tube('PeduncleGoldCrown', crown_pts, [.0026] * len(crown_pts), 'gold', 'body', sides=8)
    ped['deform_mode'] = 'mermaid_tail'
    for pk in range(10):
        px, py, pz = crown_pts[pk * 4]
        po = api.ellipsoid(f'PeduncleCrownPearl{pk}', (px * 1.08, py, pz),
                           (.0028, .0028, .0028), 'pearl', 'body', 10, 7)
        po['deform_mode'] = 'mermaid_tail'
    for fb_sgn, fb_tag in ((-1, 'Front'), (1, 'Back')):
        clasp_z = .010 + fb_sgn * .018
        clasp_b = api.ellipsoid('PeduncleGoldClasp' + fb_tag, (0.0, -.692, clasp_z),
                                (.010, .016, .0045), 'gold', 'body', 16, 10)
        clasp_b['deform_mode'] = 'mermaid_tail'
        clasp_p = api.ellipsoid('PedunclePearlGem' + fb_tag, (0.0, -.692, clasp_z + fb_sgn * .0025),
                                (.0065, .0105, .0040), 'pearl', 'body', 14, 10)
        clasp_p['deform_mode'] = 'mermaid_tail'


def _royal_caudal_fluke(api):
    """Grand sweeping Crescent/Butterfly Swallowtail Mermaid Caudal Fluke (0.58m span x 0.55m sweep!)."""
    for side, tag in ((-1, 'l'), (1, 'r')):
        drv = 'fin_' + tag
        bx, by, bz = (-.025 if side < 0 else .025), -.695, .010

        def to_local(wx, wy, wz):
            return (wx - bx, wy - by, wz - bz)

        rows_c, cols_c = 24, 20
        core_grid, veil_grid = [], []
        leading_arch = []

        for r in range(rows_c):
            tr = r / (rows_c - 1)
            c_row, v_row = [], []
            for c in range(cols_c):
                tc = c / (cols_c - 1)
                outer_x_core = .020 + .235 * (math.sin(tr * math.pi * .72) ** .78) - .025 * (tr ** 2.6)
                inner_x_core = 0.0 if tr <= .20 else .004 + .168 * (((tr - .20) / .80) ** 1.32)
                wx_c = side * (inner_x_core + (outer_x_core - inner_x_core) * (tc ** .86))
                sweep_len_c = .32 + .17 * (tc ** .75)
                wy_c = -.692 - sweep_len_c * (tr ** .95)
                s_camber_c = .034 * math.sin(tr * math.pi * .95) - .024 * (tr ** 2.2)
                flute_c = .0075 * math.sin(tc * math.pi * 5.0) * math.sin(tr * math.pi * .85)
                wz_c = .010 + s_camber_c + flute_c - .010 * (1.0 - tc) * tr
                c_row.append(to_local(wx_c, wy_c, wz_c))

                scallop = 1.0 + .075 * math.cos(tc * math.pi * 6.0) * (tr ** 1.4)
                outer_x_veil = (.022 + .272 * (math.sin(tr * math.pi * .74) ** .76) - .020 * (tr ** 2.6)) * scallop
                inner_x_veil = 0.0 if tr <= .26 else .002 + .142 * (((tr - .26) / .74) ** 1.38)
                wx_v = side * (inner_x_veil + (outer_x_veil - inner_x_veil) * (tc ** .86))
                sweep_len_v = (.38 + .185 * (tc ** .75)) * scallop
                wy_v = -.692 - sweep_len_v * (tr ** .95)
                s_camber_v = .038 * math.sin(tr * math.pi * .95) - .028 * (tr ** 2.2)
                pleat_v = .0125 * math.sin(tc * math.pi * 6.0 - tr * 1.2) * (tr ** .85)
                wz_v = .010 + s_camber_v + pleat_v - .012 * (1.0 - tc) * tr
                v_row.append(to_local(wx_v, wy_v, wz_v))

            core_grid.append(c_row)
            veil_grid.append(v_row)
            leading_arch.append(c_row[-1])

        _thick_grid(api, 'MermaidCaudalCoreLobe' + tag, core_grid, .0058, 'fin_pearl',
                    driver=drv, deform_mode='caudal_fluke',
                    uv_fn=lambda r, c, nr, nc: (c / max(1, nc - 1), r / max(1, nr - 1)))
        _thick_grid(api, 'MermaidCaudalGlassVeil' + tag, veil_grid, .0022, 'glass',
                    driver=drv, deform_mode='caudal_fluke',
                    uv_fn=lambda r, c, nr, nc: (c / max(1, nc - 1), r / max(1, nr - 1)))

        lead = api.tube('CaudalLeadingGoldArch' + tag, leading_arch,
                        [.0036 * (1.0 - .66 * i / (rows_c - 1)) for i in range(rows_c)],
                        'gold', drv, sides=7)
        lead['deform_mode'] = 'caudal_fluke'

        for ray_i in range(7):
            ci = int(round((ray_i + 1) / 8 * (cols_c - 1)))
            r_pts = [veil_grid[r][ci] for r in range(rows_c - 1)]
            mat_r = 'gold_light' if ray_i % 2 == 0 else 'fin_pearl'
            ray = api.tube(f'CaudalRadiatingRay{tag}{ray_i}', r_pts,
                           [.0024 * (1.0 - .74 * r / max(1, len(r_pts) - 1)) for r in range(len(r_pts))],
                           mat_r, drv, sides=6)
            ray['deform_mode'] = 'caudal_fluke'


def build(api):
    """Build Scallop-Shell Bodice, Akoya Pearls, Hip/Arm Gossamer Fins & Grand Caudal Fluke."""
    _shell_bodice_and_pearls(api)
    _siren_hip_girdle_and_veil_fins(api)
    _arm_jewelry_and_fins(api)
    _dorsal_crest_and_peduncle_crown(api)
    _royal_caudal_fluke(api)
