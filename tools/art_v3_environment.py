"""Sculptural reef and astronomical stonework, after GPT Image environment.png.

The coordinator calls register(create_assets_module). All meshes still use the
shared pigment atlas, exact bounds, deterministic seeds and production budgets.
"""
import math

import numpy as np
from mathutils import Vector

TAU = math.tau


def _install_painters(api):
    h, w = 512, 256
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    u, v = xx / w, yy / h

    def reg(slot):
        r, c = slot // 4, slot % 4
        return slice(r * h, (r + 1) * h), slice(c * w, (c + 1) * w)

    def write_slot(albedo, normal, orm, slot, rgb, relief, rough=0.76, metal=0.0, strength=3.0, ao_k=0.38):
        s = reg(slot)
        albedo[s][:, :, :3] = np.clip(rgb, 0.0, 1.0)
        albedo[s][:, :, 3] = 1.0
        normal[s][:, :, :3] = api.height_to_normal(relief, strength)
        normal[s][:, :, 3] = 1.0
        orm[s][:, :, 0] = np.clip(0.97 - np.maximum(0.0, -relief) * ao_k * 2.4 - np.abs(relief) * ao_k * 0.4, 0.56, 1.0)
        orm[s][:, :, 1] = np.clip(rough, 0.08, 0.98)
        orm[s][:, :, 2] = metal
        orm[s][:, :, 3] = 1.0

    def paint_rock(albedo, normal, orm, _emission):
        pal = [api.color(c)[None, None, :] for c in api.PALETTES['rock']]
        bedding = np.sin(v * TAU * 9.0 + 0.55 * np.sin(u * TAU * 2.0)) * 0.08
        cracks = -np.exp(-((np.sin(u * TAU * 3.0 + v * 5.2)) ** 2) * 90.0) * 0.11
        pits = -np.maximum(0.0, np.sin(u * TAU * 19.0) * np.cos(v * TAU * 23.0)) ** 6 * 0.07
        for slot in range(8):
            base = pal[slot] * (0.90 + 0.14 * v + bedding)[:, :, None]
            if slot in (1, 4):
                crust = np.maximum(0.0, np.sin(u * TAU * 5.0 + 1.4 * np.cos(v * TAU * 4.0))) ** 5
                coralline = np.array([0.74, 0.58, 0.60], dtype=np.float32)[None, None, :]
                base = base * (1.0 - 0.18 * crust[:, :, None]) + coralline * (0.18 * crust[:, :, None])
            write_slot(albedo, normal, orm, slot, base, bedding + cracks + pits, rough=0.86 if slot != 3 else 0.92, strength=3.2)

    def paint_table_coral(albedo, normal, orm, _emission):
        pal = [api.color(c)[None, None, :] for c in api.PALETTES['table_coral']]
        rings = np.sin(v * TAU * 11.0 + 0.25 * np.sin(u * TAU * 7.0)) * 0.055
        rad_ridges = np.cos(u * TAU * 38.0) * (0.028 * (0.3 + 0.7 * v))
        pores = -np.maximum(0.0, np.sin(u * TAU * 34.0) * np.cos(v * TAU * 32.0)) ** 4 * 0.05
        rim_w = np.clip((v - 0.83) / 0.17, 0.0, 1.0) ** 1.5
        for slot in (0, 2, 5, 7):
            inner = pal[5 if slot in (0, 5) else 2] * 0.84
            mid = pal[slot] * (0.94 + 0.10 * np.sin(v * TAU * 5.5))[:, :, None]
            blend_v = np.clip(v * 1.25, 0.0, 1.0)[:, :, None]
            rgb = inner * (1.0 - blend_v) + mid * blend_v
            rgb = rgb * (1.0 - 0.88 * rim_w[:, :, None]) + pal[4] * (0.88 * rim_w[:, :, None])
            write_slot(albedo, normal, orm, slot, rgb, rings + rad_ridges + pores, rough=0.72, strength=3.1)
        costae = np.cos(u * TAU * 32.0) * 0.075 + np.sin(v * TAU * 8.0) * 0.02
        rgb1 = pal[1] * (0.90 + 0.10 * v)[:, :, None] + costae[:, :, None] * 0.35
        write_slot(albedo, normal, orm, 1, rgb1, costae, rough=0.78, strength=3.0)

    def make_branch_coral_painter(asset_name):
        def _paint(albedo, normal, orm, _emission):
            pal = [api.color(c)[None, None, :] for c in api.PALETTES[asset_name]]
            gx = (u * 14.0) % 1.0 - 0.5
            gy = ((v * 26.0 + 0.5 * np.floor(u * 14.0)) % 1.0) - 0.5
            dist = np.sqrt(gx * gx + gy * gy)
            cup_rim = np.exp(-((dist - 0.24) ** 2) * 95.0) * (1.0 - np.clip((v - 0.82) / 0.18, 0.0, 1.0))
            cup_pit = -np.exp(-(dist ** 2) * 70.0) * 0.08
            tip_w = np.clip((v - 0.66) / 0.34, 0.0, 1.0) ** 1.45
            for slot in (0, 2, 5, 7):
                rgb = pal[slot] * (0.90 + 0.12 * v)[:, :, None] + pal[1] * (0.20 * cup_rim[:, :, None])
                rgb = rgb * (1.0 - 0.90 * tip_w[:, :, None]) + pal[4] * (0.90 * tip_w[:, :, None])
                write_slot(albedo, normal, orm, slot, rgb, cup_rim * 0.09 + cup_pit, rough=0.74, strength=3.2)
            tip_relief = -np.maximum(0.0, np.sin(u * TAU * 16.0) * np.cos(v * TAU * 16.0)) ** 4 * 0.04
            write_slot(albedo, normal, orm, 4, pal[4] * (0.96 + 0.05 * v)[:, :, None], tip_relief, rough=0.68, strength=2.4)
        return _paint

    def make_sponge_painter(asset_name, flutes_n=12.0):
        def _paint(albedo, normal, orm, _emission):
            pal = [api.color(c)[None, None, :] for c in api.PALETTES[asset_name]]
            flute = np.cos(u * TAU * flutes_n + 0.45 * np.sin(v * TAU * 4.0))
            web = np.abs(np.sin(u * TAU * 18.0 + 0.8 * np.cos(v * TAU * 7.0)) * np.cos(v * TAU * 20.0))
            ridge_mask = np.clip((flute * 0.55 + (1.0 - web) * 0.65 - 0.35) * 2.2, 0.0, 1.0)
            pit_mask = (web > 0.58).astype(np.float32) * (web - 0.58) / 0.42
            rim_w = np.clip((v - 0.88) / 0.12, 0.0, 1.0) ** 1.7
            for slot in (0, 2, 5, 7):
                rgb = pal[slot] * (0.88 + 0.14 * v)[:, :, None]
                rgb = rgb * (1.0 - 0.52 * pit_mask[:, :, None]) + pal[3] * (0.52 * pit_mask[:, :, None])
                rgb = rgb * (1.0 - 0.46 * ridge_mask[:, :, None]) + pal[1] * (0.46 * ridge_mask[:, :, None])
                rgb = rgb * (1.0 - 0.72 * rim_w[:, :, None]) + pal[4] * (0.72 * rim_w[:, :, None])
                relief = flute * 0.08 + ridge_mask * 0.07 - pit_mask * 0.11
                write_slot(albedo, normal, orm, slot, rgb, relief, rough=0.84, strength=3.5, ao_k=0.48)
            rim_tex = np.cos(u * TAU * 28.0) * 0.03
            write_slot(albedo, normal, orm, 4, pal[4] * (0.94 + 0.07 * v)[:, :, None], rim_tex, rough=0.78, strength=2.4)
        return _paint

    def paint_giant_clam(albedo, normal, orm, _emission):
        pal = [api.color(c)[None, None, :] for c in api.PALETTES['giant_clam']]
        warp = np.sin(u * TAU * 3.0 + 1.8 * np.cos(v * TAU * 2.0)) + 0.6 * np.cos(u * TAU * 7.0 - v * TAU * 4.0)
        vein1 = np.exp(-((np.sin(u * TAU * 4.0 + warp * 1.35)) ** 2) * 26.0)
        vein2 = np.exp(-((np.cos(v * TAU * 5.0 - warp * 1.15)) ** 2) * 32.0) * 0.75
        spots = np.maximum(0.0, np.sin(u * TAU * 15.0 + warp) * np.cos(v * TAU * 13.0 - warp)) ** 8
        edge_stripes = np.maximum(0.0, np.cos(u * TAU * 26.0 + warp * 0.5)) ** 4 * np.clip((v - 0.70) / 0.30, 0.0, 1.0)
        gold_m = np.clip(vein1 * 0.85 + vein2 * 0.65 + spots * 0.9 + edge_stripes * 0.75, 0.0, 1.0)
        deep_blue = np.array([0.08, 0.24, 0.42], dtype=np.float32)[None, None, :]
        teal_glow = np.array([0.16, 0.52, 0.64], dtype=np.float32)[None, None, :]
        gold_col = np.array([0.90, 0.70, 0.31], dtype=np.float32)[None, None, :]
        for slot in (2, 5, 7):
            t_mix = (0.35 + 0.55 * np.sin(u * TAU * 2.0 + v * 3.1) * 0.5 + (0.22 if slot == 5 else 0.0))[:, :, None]
            rgb = deep_blue * (1.0 - t_mix) + teal_glow * t_mix
            rgb = rgb * (1.0 - 0.82 * gold_m[:, :, None]) + gold_col * (0.82 * gold_m[:, :, None])
            relief = gold_m * 0.035 + np.sin(u * TAU * 12.0) * np.cos(v * TAU * 10.0) * 0.02
            write_slot(albedo, normal, orm, slot, rgb, relief, rough=0.32, strength=2.6)
        lamellae = np.sin(v * TAU * 20.0 + 0.25 * np.cos(u * TAU * 6.0)) * 0.065 + np.cos(u * TAU * 18.0) * 0.03
        for slot in (0, 1, 6):
            umbo = np.clip(1.0 - v * 2.4, 0.0, 1.0)[:, :, None]
            rgb = pal[slot] * (0.93 + 0.08 * np.sin(v * TAU * 20.0))[:, :, None]
            rgb = rgb * (1.0 - 0.22 * umbo) + pal[3] * (0.22 * umbo)
            write_slot(albedo, normal, orm, slot, rgb, lamellae, rough=0.68 if slot == 1 else 0.80, strength=3.1)

    def paint_kelp(albedo, normal, orm, _emission):
        pal = [api.color(c)[None, None, :] for c in api.PALETTES['kelp']]
        midrib = np.exp(-(((u - 0.5) / 0.085) ** 2))
        bullae = np.sin(u * TAU * 7.0) * np.sin(v * TAU * 24.0) * (1.0 - midrib) * 0.045
        veins = np.cos((u - 0.5) * TAU * 14.0 - v * 8.0) * 0.015
        for slot in (1, 2, 4, 7):
            rgb = pal[slot] * (0.88 + 0.16 * v)[:, :, None]
            rgb = rgb * (1.0 - 0.42 * midrib[:, :, None]) + pal[4] * (0.42 * midrib[:, :, None])
            edge_gold = np.clip((np.abs(u - 0.5) - 0.30) / 0.20, 0.0, 1.0)[:, :, None]
            rgb = rgb * (1.0 - 0.35 * edge_gold) + pal[1] * (0.35 * edge_gold)
            write_slot(albedo, normal, orm, slot, rgb, midrib * 0.06 + bullae + veins, rough=0.38, strength=2.8)

    def paint_brain_coral(albedo, normal, orm, _emission):
        pal = [api.color(c)[None, None, :] for c in api.PALETTES['brain_coral']]
        # Continuous v=0(valley) -> v=0.5(ribbed septa wall) -> v=1(rounded ridge crest) gradient with zero polygon staircasing
        septa_wave = np.cos(u * TAU * 42.0)
        wall_mask = np.exp(-(((v - 0.50) / 0.24) ** 2))
        septa = septa_wave * 0.065 * (0.30 + 0.70 * wall_mask)
        crest_t = np.clip((v - 0.46) / 0.46, 0.0, 1.0) ** 1.15
        valley_t = np.clip((0.50 - v) / 0.44, 0.0, 1.0) ** 1.20
        for slot, c_valley, c_wall, c_crest in (
            (0, pal[3], pal[7], pal[0]),
            (2, pal[5], pal[2], pal[1]),
            (1, pal[3], pal[2], pal[1]),
            (4, pal[5], pal[4], pal[0]),
            (7, pal[3], pal[7], pal[1]),
        ):
            rgb = c_wall * (1.0 - crest_t - valley_t * (1.0 - crest_t))[:, :, None]
            rgb = c_wall * (1.0 - valley_t)[:, :, None] + c_valley * valley_t[:, :, None]
            rgb = rgb * (1.0 - crest_t)[:, :, None] + c_crest * crest_t[:, :, None]
            rgb = rgb * (0.93 + 0.08 * septa_wave * wall_mask)[:, :, None]
            write_slot(albedo, normal, orm, slot, rgb, septa + (v - 0.5) * 0.08, rough=0.76, strength=3.2)
        for slot in (3, 5):
            write_slot(albedo, normal, orm, slot, pal[slot], septa * 0.35, rough=0.84, strength=2.6)

    def paint_sea_fan(albedo, normal, orm, _emission):
        pal = [api.color(c)[None, None, :] for c in api.PALETTES['sea_fan']]
        bark = np.sin(u * TAU * 16.0 + 0.3 * np.sin(v * TAU * 6.0)) * 0.035
        polyps = np.maximum(0.0, np.sin(u * TAU * 12.0) * np.cos(v * TAU * 28.0)) ** 6
        def sstep(a, b, x):
            t = np.clip((x - a) / (b - a), 0.0, 1.0)
            return t * t * (3.0 - 2.0 * t)
        t1 = sstep(0.00, 0.36, v)[:, :, None]
        t2 = sstep(0.30, 0.70, v)[:, :, None]
        t3 = (sstep(0.64, 1.00, v) ** 1.10)[:, :, None]
        for slot, mid_c in ((0, pal[0]), (7, pal[7]), (2, pal[2])):
            rgb = pal[5] * (1.0 - t1) + mid_c * t1
            rgb = rgb * (1.0 - t2) + pal[2] * t2
            rgb = rgb * (1.0 - 0.84 * t3) + pal[4] * (0.84 * t3)
            rgb = rgb + pal[4] * (0.22 * polyps[:, :, None])
            write_slot(albedo, normal, orm, slot, rgb, bark + polyps * 0.06, rough=0.68, strength=2.8)
        trunk_t = sstep(0.0, 1.0, v)[:, :, None]
        trunk_rgb = (pal[5] * 0.72 + pal[3] * 0.28) * (1.0 - trunk_t) + pal[5] * trunk_t
        write_slot(albedo, normal, orm, 5, trunk_rgb, bark * 1.25, rough=0.74, strength=3.0)
        rock_pits = -np.maximum(0.0, np.sin(u * TAU * 15.0) * np.cos(v * TAU * 19.0)) ** 5 * 0.06
        rock_rgb = pal[6] * (0.84 + 0.18 * v)[:, :, None]
        write_slot(albedo, normal, orm, 6, rock_rgb, rock_pits + np.sin(v * TAU * 6.0) * 0.03, rough=0.88, strength=2.8)

    def paint_crystal(albedo, normal, orm, emission):
        pal = [api.color(c)[None, None, :] for c in api.PALETTES['crystal_spire']]
        striae = np.sin(v * TAU * 42.0) * 0.018 + np.sin(v * TAU * 13.0) * 0.012
        chevron = np.exp(-(((v - 0.68 - 0.12 * (1.0 - np.abs(u - 0.5) * 2.0)) / 0.06) ** 2))
        apex = np.clip((v - 0.55) / 0.45, 0.0, 1.0) ** 1.3
        for slot in (0, 1, 2, 4, 7):
            rgb = pal[slot] * (0.88 + 0.16 * v)[:, :, None]
            rgb = rgb * (1.0 - 0.45 * apex[:, :, None]) + pal[1] * (0.45 * apex[:, :, None])
            rgb = np.clip(rgb + chevron[:, :, None] * 0.14, 0.0, 1.0)
            write_slot(albedo, normal, orm, slot, rgb, striae, rough=0.16 if slot in (1, 4) else 0.21, strength=1.9)
        s4 = reg(4)
        emission[s4][:, :, :3] = pal[4] * (0.22 + 0.30 * apex)[:, :, None]

    def paint_ruins(albedo, normal, orm, emission):
        pal = [api.color(c)[None, None, :] for c in api.PALETTES['ruins']]
        vugs = -np.maximum(0.0, np.sin(u * TAU * 23.0 + 1.5 * np.cos(v * TAU * 9.0)) * np.cos(v * TAU * 29.0)) ** 6 * 0.07
        vein = np.sin(v * TAU * 5.0 + 0.8 * np.sin(u * TAU * 3.0)) * 0.03
        mortar = np.clip(((np.abs((u * 3.0) % 1.0 - 0.5) > 0.465) | (np.abs((v * 5.0) % 1.0 - 0.5) > 0.465)).astype(np.float32), 0.0, 1.0)
        for slot in (0, 1, 6, 7):
            rgb = pal[slot] * (0.92 + 0.09 * v + vein)[:, :, None] * (1.0 - 0.18 * mortar[:, :, None])
            write_slot(albedo, normal, orm, slot, rgb, vein + vugs - mortar * 0.065, rough=0.84, strength=3.1)
        ticks = ((np.abs((u * 24.0) % 1.0 - 0.5) > 0.40) & (np.abs(v - 0.5) > 0.34)).astype(np.float32)
        rings_b = np.sin(v * TAU * 16.0) * 0.018 - ticks * 0.035
        patina = np.maximum(0.0, np.sin(u * TAU * 7.0) * np.cos(v * TAU * 9.0)) ** 6
        for slot, met, rgh in ((2, 0.82, 0.24), (5, 0.74, 0.31)):
            rgb = pal[slot] * (0.94 + 0.12 * np.cos((v - 0.5) * math.pi))[:, :, None]
            rgb = rgb * (1.0 - 0.16 * patina[:, :, None]) + pal[7] * (0.16 * patina[:, :, None])
            write_slot(albedo, normal, orm, slot, rgb, rings_b, rough=rgh, metal=met, strength=2.5)
        dial = -np.exp(-((np.sin(v * TAU * 6.0)) ** 2) * 35.0) * 0.04 + vugs * 0.5
        write_slot(albedo, normal, orm, 3, pal[3] * (0.90 + 0.12 * v)[:, :, None], dial, rough=0.88, strength=2.8)
        s4 = reg(4)
        radial = np.sqrt((u - 0.5) ** 2 + (v - 0.5) ** 2)
        glow = np.clip(1.0 - radial * 1.5, 0.0, 1.0)
        write_slot(albedo, normal, orm, 4, pal[4] * (0.95 + 0.08 * glow)[:, :, None], rings_b * 0.5, rough=0.26, metal=0.65, strength=2.0)
        emission[s4][:, :, :3] = pal[4] * (0.16 + 0.22 * glow)[:, :, None]

    def paint_anemone(albedo, normal, orm, _emission):
        pal = [api.color(c)[None, None, :] for c in api.PALETTES['anemone']]
        furrows = np.cos(u * TAU * 18.0) * 0.05
        warts = np.maximum(0.0, np.sin(u * TAU * 14.0) * np.cos(v * TAU * 18.0)) ** 5 * 0.07
        for slot in (0, 5):
            rgb = pal[slot] * (0.88 + 0.16 * v)[:, :, None] + pal[1] * (0.28 * warts[:, :, None] / 0.07)
            write_slot(albedo, normal, orm, slot, rgb, furrows + warts, rough=0.52, strength=2.9)
        ring_band = np.exp(-(((v - 0.78) / 0.07) ** 2))
        tip_rose = np.clip((v - 0.55) / 0.45, 0.0, 1.0) ** 1.3
        for slot in (1, 2, 7):
            rgb = pal[slot] * (0.92 + 0.10 * v)[:, :, None]
            rgb = rgb * (1.0 - 0.65 * tip_rose[:, :, None]) + pal[0] * (0.65 * tip_rose[:, :, None])
            rgb = rgb * (1.0 - 0.55 * ring_band[:, :, None]) + pal[4] * (0.55 * ring_band[:, :, None])
            write_slot(albedo, normal, orm, slot, rgb, np.sin(v * TAU * 12.0) * 0.015, rough=0.38, strength=2.0)

    def paint_tubeworms(albedo, normal, orm, _emission):
        pal = [api.color(c)[None, None, :] for c in api.PALETTES['tubeworms']]
        collars = np.sin(v * TAU * 22.0 + 0.2 * np.sin(u * TAU * 3.0)) * 0.055
        for slot in (0, 1):
            base_dark = np.clip(1.0 - v * 2.2, 0.0, 1.0)[:, :, None]
            rgb = pal[slot] * (0.93 + 0.08 * np.sin(v * TAU * 22.0))[:, :, None]
            rgb = rgb * (1.0 - 0.35 * base_dark) + pal[3] * (0.35 * base_dark)
            write_slot(albedo, normal, orm, slot, rgb, collars, rough=0.72, strength=2.8)
        herring = np.cos((np.abs(u - 0.5) * 18.0 - v * 26.0) * TAU) * 0.05
        bands = np.exp(-((np.sin(v * TAU * 3.5)) ** 2) * 18.0)
        for slot in (2, 5, 7):
            rgb = pal[slot] * (0.90 + 0.12 * v)[:, :, None]
            rgb = rgb * (1.0 - 0.52 * bands[:, :, None]) + pal[4] * (0.52 * bands[:, :, None])
            write_slot(albedo, normal, orm, slot, rgb, herring, rough=0.58, strength=3.0)

    def paint_starfish_urchin(albedo, normal, orm, _emission):
        pal = [api.color(c)[None, None, :] for c in api.PALETTES['starfish_urchin']]
        retic = np.abs(np.sin(u * TAU * 9.0 + 0.6 * np.cos(v * TAU * 7.0)) * np.cos(v * TAU * 11.0))
        net = (retic < 0.22).astype(np.float32) * (0.22 - retic) / 0.22
        for slot in (0, 2, 7):
            rgb = pal[slot] * (0.90 + 0.12 * v)[:, :, None]
            rgb = rgb * (1.0 - 0.38 * net[:, :, None]) + pal[1] * (0.38 * net[:, :, None])
            write_slot(albedo, normal, orm, slot, rgb, net * 0.06 - retic * 0.03, rough=0.68, strength=2.9)
        pores = np.maximum(0.0, np.cos(u * TAU * 5.0)) ** 8 * (np.cos(v * TAU * 24.0) > 0.3).astype(np.float32)
        rgb5 = pal[5] * (0.76 + 0.20 * v)[:, :, None] + pal[1] * (0.35 * pores[:, :, None])
        write_slot(albedo, normal, orm, 5, rgb5, pores * 0.05 + np.cos(u * TAU * 10.0) * 0.025, rough=0.62, strength=2.6)

    def paint_sea_lily(albedo, normal, orm, _emission):
        pal = [api.color(c)[None, None, :] for c in api.PALETTES['sea_lily']]
        columnals = np.sin(v * TAU * 28.0) * 0.055
        for slot in (0, 1, 5):
            rgb = pal[slot] * (0.91 + 0.10 * np.sin(v * TAU * 28.0))[:, :, None]
            write_slot(albedo, normal, orm, slot, rgb, columnals, rough=0.68, strength=2.8)
        joints = np.sin(v * TAU * 18.0) * 0.035
        stripe = (np.sin(v * TAU * 5.0) > 0.35).astype(np.float32)
        for slot in (2, 7):
            rgb = pal[slot] * (0.92 + 0.10 * v)[:, :, None]
            rgb = rgb * (1.0 - 0.36 * stripe[:, :, None]) + pal[4] * (0.36 * stripe[:, :, None])
            write_slot(albedo, normal, orm, slot, rgb, joints, rough=0.62, strength=2.5)

    api.CUSTOM_PAINTERS.update({
        'rock': paint_rock,
        'table_coral': paint_table_coral,
        'coral': make_branch_coral_painter('coral'),
        'staghorn_coral': make_branch_coral_painter('staghorn_coral'),
        'barrel_sponge': make_sponge_painter('barrel_sponge', 13.0),
        'tube_coral': make_sponge_painter('tube_coral', 10.0),
        'giant_clam': paint_giant_clam,
        'kelp': paint_kelp,
        'brain_coral': paint_brain_coral,
        'sea_fan': paint_sea_fan,
        'crystal_spire': paint_crystal,
        'ruins': paint_ruins,
        'anemone': paint_anemone,
        'tubeworms': paint_tubeworms,
        'starfish_urchin': paint_starfish_urchin,
        'sea_lily': paint_sea_lily,
    })


def register(api):
    _install_painters(api)
    tau = TAU

    def stratified_outcrop(name, center, scale, layers, sides=24, phase=0.0,
                           flat_bottom=False, wall_slots=(0, 2, 5, 7), top_slot=1, crevice_slot=3):
        verts, uv, faces, slots = [], [], [], []
        cx, cy, cz = center
        sx, sy, sz = scale
        base_rings = []
        if flat_bottom:
            verts.append((cx, cy, cz))
            uv.append((0.5, 0.5))
            h0, w0, ox0, oy0, jag0 = layers[0]
            for frac in (0.45, 0.76):
                start = len(verts)
                base_rings.append(start)
                for j in range(sides):
                    a = tau * j / sides
                    r = w0 * frac * (1.0 + jag0 * math.sin(a * 3.0 + phase) + 0.06 * math.cos(a * 5.0 - phase))
                    verts.append((cx + sx * (r * math.cos(a) + ox0 * frac),
                                  cy + sy * (r * math.sin(a) + oy0 * frac), cz + sz * h0))
                    uv.append((0.5 + 0.45 * frac * math.cos(a), 0.5 + 0.45 * frac * math.sin(a)))
        ring_starts = []
        for i, (h, width, ox, oy, jag) in enumerate(layers):
            ring_starts.append(len(verts))
            for j in range(sides):
                a = tau * j / sides
                ledge = 1.0 + jag * math.sin(a * 3.0 + phase + i * 0.55) + 0.08 * math.cos(a * 5.0 - phase * 1.3 + i * 0.9)
                facet = 1.0 + 0.045 * math.cos(a * 7.0 + i * 1.7)
                r = width * ledge * facet
                z_jit = 0.0 if (flat_bottom and i == 0) else 0.022 * math.sin(a * 4.0 + i * 1.2 + phase)
                verts.append((cx + sx * (r * math.cos(a) + ox),
                              cy + sy * (r * math.sin(a) + oy),
                              cz + sz * max(0.0 if flat_bottom else -1.0, h + z_jit)))
                uv.append((j / sides, h))
        top_center_idx = len(verts)
        ht, _, oxt, oyt, _ = layers[-1]
        verts.append((cx + sx * oxt, cy + sy * oyt, cz + sz * (ht + 0.015)))
        uv.append((0.5, 0.95))
        if flat_bottom:
            r0 = base_rings[0]
            for j in range(sides):
                jn = (j + 1) % sides
                faces.append((0, r0 + jn, r0 + j))
                slots.append(crevice_slot)
            all_b = base_rings + [ring_starts[0]]
            for b0, b1 in zip(all_b, all_b[1:]):
                for j in range(sides):
                    jn = (j + 1) % sides
                    faces.append((b0 + j, b0 + jn, b1 + jn, b1 + j))
                    slots.append(crevice_slot)
        else:
            b0 = ring_starts[0]
            faces.append(tuple(b0 + j for j in range(sides - 1, -1, -1)))
            slots.append(crevice_slot)
        for i in range(len(layers) - 1):
            s0, s1 = ring_starts[i], ring_starts[i + 1]
            for j in range(sides):
                jn = (j + 1) % sides
                q = (s0 + j, s0 + jn, s1 + jn, s1 + j)
                p0, p1, p2 = Vector(verts[q[0]]), Vector(verts[q[1]]), Vector(verts[q[3]])
                nrm = (p1 - p0).cross(p2 - p0)
                nz = nrm.normalized().z if nrm.length > 1e-6 else 0.0
                faces.append(q)
                if nz > 0.56:
                    slots.append(top_slot)
                elif nz < -0.22:
                    slots.append(crevice_slot)
                else:
                    slots.append(wall_slots[i % len(wall_slots)])
        st = ring_starts[-1]
        for j in range(sides):
            jn = (j + 1) % sides
            faces.append((st + j, st + jn, top_center_idx))
            slots.append(top_slot)
        return api.mesh(name, verts, faces, uv, face_slots=slots, smooth=False)

    def reef_substrate(rx=0.68, ry=0.60, height=0.22, phase=0.4, rock_slot=6, top_slot=6, crevice_slot=3, sides=18):
        layers = [
            (0.00, 0.92, 0.00, 0.00, 0.11),
            (0.32, 1.00, 0.03, -0.02, 0.13),
            (0.68, 0.84, -0.02, 0.03, 0.10),
            (1.00, 0.56, 0.01, 0.01, 0.08),
        ]
        return stratified_outcrop('Calcified reef substrate', (0, 0, 0), (rx, ry, height), layers,
                                  sides=sides, phase=phase, flat_bottom=True,
                                  wall_slots=(rock_slot, crevice_slot, rock_slot),
                                  top_slot=top_slot, crevice_slot=crevice_slot)

    def bishop_tube(name, points, radii, slot=0, ring_slots=None, sides=8,
                    flatten=1.0, smooth=True, tip_dome=False, tip_slot=4, v_range=(0.0, 1.0)):
        pts = [Vector(p) for p in points]
        rads = list(radii)
        if tip_dome and rads[-1] > 0.002:
            t_end = (pts[-1] - pts[-2]).normalized()
            r_last = rads[-1]
            pts.append(pts[-1] + t_end * (r_last * 0.68))
            rads.append(r_last * 0.58)
            pts.append(pts[-1] + t_end * (r_last * 0.45))
            rads.append(r_last * 0.18)
        tangents = []
        for i in range(len(pts)):
            d = pts[min(i + 1, len(pts) - 1)] - pts[max(0, i - 1)]
            tangents.append(d.normalized() if d.length > 1e-6 else Vector((0, 0, 1)))
        ref = Vector((0, 0, 1)) if abs(tangents[0].z) < 0.92 else Vector((1, 0, 0))
        normal_v = (ref - tangents[0] * ref.dot(tangents[0])).normalized()
        verts, uv, faces, slots = [], [], [], []
        n_pts = len(pts)
        for i, (p, rad, tg) in enumerate(zip(pts, rads, tangents)):
            if i > 0:
                proj = normal_v - tg * normal_v.dot(tg)
                if proj.length > 1e-5:
                    normal_v = proj.normalized()
            binorm = tg.cross(normal_v).normalized()
            v_uv = v_range[0] + (v_range[1] - v_range[0]) * (i / max(1, n_pts - 1))
            for j in range(sides):
                a = tau * j / sides
                verts.append(p + rad * (normal_v * math.cos(a) + binorm * flatten * math.sin(a)))
                uv.append((j / sides, v_uv))
        b_center = len(verts)
        verts.append(pts[0])
        uv.append((0.5, v_range[0]))
        t_center = len(verts)
        verts.append(pts[-1] + tangents[-1] * (rads[-1] * 0.25))
        uv.append((0.5, v_range[1]))
        for j in range(sides):
            jn = (j + 1) % sides
            faces.append((b_center, jn, j))
            slots.append(ring_slots[0] if ring_slots else slot)
        for i in range(n_pts - 1):
            s_here = (tip_slot if (tip_dome and i >= n_pts - 3)
                      else (ring_slots[min(i, len(ring_slots) - 1)] if ring_slots else slot))
            for j in range(sides):
                jn = (j + 1) % sides
                a0, b0 = i * sides + j, i * sides + jn
                faces.append((a0, b0, b0 + sides, a0 + sides))
                slots.append(s_here)
        top_ring = (n_pts - 1) * sides
        end_s = tip_slot if tip_dome else (ring_slots[-1] if ring_slots else slot)
        for j in range(sides):
            jn = (j + 1) % sides
            faces.append((top_ring + j, top_ring + jn, t_center))
            slots.append(end_s)
        return api.mesh(name, verts, faces, uv, face_slots=slots, smooth=smooth)

    def kelp_ribbon(name, origin, dir_vec, length, max_width, slot=7, edge_slot=2, tip_slot=4, steps=15, phase=0.0):
        origin = Vector(origin)
        d = Vector(dir_vec).normalized()
        lat = d.cross(Vector((0, 0, 1)))
        if lat.length < 0.05:
            lat = Vector((1, 0, 0))
        lat.normalize()
        up_n = lat.cross(d).normalized()
        cross_pts = [(-1.0, 0.0), (-0.48, 0.35), (0.0, 1.0), (0.48, 0.35),
                     (1.0, 0.0), (0.48, -0.35), (0.0, -1.0), (-0.48, -0.35)]
        nc = len(cross_pts)
        verts, uv, faces, slots = [], [], [], []
        spine_pts = []
        for i in range(steps):
            t = i / (steps - 1)
            env = math.sin(math.pi * min(0.995, t ** 0.78)) ** 0.72
            w = max(0.008, max_width * env)
            twist = 0.42 * math.sin(t * 3.4 + phase)
            cl = lat * math.cos(twist) + up_n * math.sin(twist)
            cu = -lat * math.sin(twist) + up_n * math.cos(twist)
            center = (origin + d * (length * t)
                      + Vector((0.14 * math.sin(t * 4.2 + phase) * t,
                                0.14 * math.cos(t * 3.6 + phase) * t,
                                length * (0.34 * math.sin(t * math.pi * 0.92) + 0.14 * t))))
            spine_pts.append(center)
            thick = 0.006 + 0.012 * (1.0 - t * 0.7)
            for cx_u, cz_u in cross_pts:
                ruffle = 0.036 * abs(cx_u) ** 1.4 * math.sin(t * 19.0 + cx_u * 2.4 + phase) * env
                pt = center + cl * (cx_u * w) + cu * (cz_u * thick + ruffle)
                verts.append(pt)
                uv.append(((cx_u + 1.0) * 0.5, t))
        b_cap, t_cap = len(verts), len(verts) + 1
        verts.extend([spine_pts[0], spine_pts[-1] + d * 0.02])
        uv.extend([(0.5, 0.0), (0.5, 1.0)])
        for j in range(nc):
            jn = (j + 1) % nc
            faces.append((b_cap, jn, j))
            slots.append(slot)
        for i in range(steps - 1):
            t = i / (steps - 1)
            for j in range(nc):
                jn = (j + 1) % nc
                a0, b0 = i * nc + j, i * nc + jn
                faces.append((a0, b0, b0 + nc, a0 + nc))
                is_edge = j in (0, 3, 4, 7)
                slots.append(tip_slot if t > 0.80 else (edge_slot if is_edge else slot))
        tr = (steps - 1) * nc
        for j in range(nc):
            jn = (j + 1) % nc
            faces.append((tr + j, tr + jn, t_cap))
            slots.append(tip_slot)
        return api.mesh(name, verts, faces, uv, face_slots=slots, smooth=True)

    def acropora_plate(name, center, rx, ry, cup=0.14, thick=0.038, segments=56,
                       phase=0.0, top_slot=0, inner_slot=5, rim_slot=4, under_slot=1):
        cx, cy, cz = center
        radii_f = (0.16, 0.38, 0.62, 0.84, 1.00)
        nr = len(radii_f)
        verts, uv, faces, slots = [], [], [], []
        verts.append((cx, cy, cz - 0.01))
        uv.append((0.5, 0.0))
        for r in radii_f:
            for j in range(segments):
                a = tau * j / segments
                sc = 1.0 + 0.082 * math.sin(a * 7.0 + phase) + 0.044 * math.sin(a * 13.0 - phase * 1.4) + 0.022 * math.cos(a * 21.0 + phase)
                ruffle = 0.042 * (r ** 2.1) * math.sin(a * 9.0 + phase * 1.3) + 0.018 * (r ** 3) * math.cos(a * 17.0 - phase)
                ring_rib = 0.009 * math.sin(r * 22.0) * r
                verts.append((cx + rx * r * sc * math.cos(a),
                              cy + ry * r * sc * math.sin(a),
                              cz + cup * (r ** 1.65) + ruffle + ring_rib))
                uv.append((j / segments, r))
        under_start = len(verts)
        verts.append((cx, cy, cz - thick * 1.65))
        uv.append((0.5, 0.0))
        for r in radii_f:
            for j in range(segments):
                a = tau * j / segments
                sc = 1.0 + 0.082 * math.sin(a * 7.0 + phase) + 0.044 * math.sin(a * 13.0 - phase * 1.4) + 0.022 * math.cos(a * 21.0 + phase)
                ruffle = 0.042 * (r ** 2.1) * math.sin(a * 9.0 + phase * 1.3) + 0.018 * (r ** 3) * math.cos(a * 17.0 - phase)
                costa = 0.012 * math.cos(a * 28.0) * r
                dz_u = thick * (0.55 + 1.15 * (1.0 - r))
                verts.append((cx + rx * r * sc * math.cos(a) * (0.992 if r == 1.0 else 1.0),
                              cy + ry * r * sc * math.sin(a) * (0.992 if r == 1.0 else 1.0),
                              cz + cup * (r ** 1.65) + ruffle - dz_u - costa))
                uv.append((j / segments, r))
        for j in range(segments):
            jn = (j + 1) % segments
            faces.append((0, 1 + j, 1 + jn))
            slots.append(inner_slot)
            faces.append((under_start, under_start + 1 + jn, under_start + 1 + j))
            slots.append(under_slot)
        for ri in range(nr - 1):
            b0, b1 = 1 + ri * segments, 1 + (ri + 1) * segments
            u0, u1 = under_start + 1 + ri * segments, under_start + 1 + (ri + 1) * segments
            s_top = rim_slot if ri == nr - 2 else (inner_slot if ri == 0 else top_slot)
            for j in range(segments):
                jn = (j + 1) % segments
                faces.append((b0 + j, b1 + j, b1 + jn, b0 + jn))
                slots.append(s_top)
                faces.append((u0 + j, u0 + jn, u1 + jn, u1 + j))
                slots.append(under_slot)
        top_outer = 1 + (nr - 1) * segments
        und_outer = under_start + 1 + (nr - 1) * segments
        for j in range(segments):
            jn = (j + 1) % segments
            faces.append((top_outer + j, und_outer + j, und_outer + jn, top_outer + jn))
            slots.append(rim_slot)
        return api.mesh(name, verts, faces, uv, face_slots=slots, smooth=True)

    def create_rock():
        main_layers = [
            (0.00, 0.96, 0.00, 0.00, 0.12),
            (0.16, 1.05, 0.05, -0.03, 0.14),
            (0.30, 0.92, -0.04, 0.02, 0.11),
            (0.44, 1.06, 0.12, -0.06, 0.15),
            (0.58, 0.84, 0.04, 0.03, 0.12),
            (0.73, 0.93, -0.10, 0.06, 0.14),
            (0.87, 0.68, -0.06, 0.04, 0.11),
            (1.00, 0.44, -0.08, 0.02, 0.09),
        ]
        stratified_outcrop('Terraced reef limestone bluff', (-0.12, 0.03, 0.0), (1.16, 0.88, 1.76),
                           main_layers, sides=28, phase=0.35, flat_bottom=True,
                           wall_slots=(0, 2, 5, 7), top_slot=1, crevice_slot=3)
        shelf_a = [
            (0.00, 0.90, 0.00, 0.00, 0.13),
            (0.28, 1.04, 0.10, -0.05, 0.15),
            (0.56, 0.88, 0.04, -0.02, 0.12),
            (0.82, 0.96, 0.14, -0.08, 0.13),
            (1.00, 0.62, 0.08, -0.04, 0.10),
        ]
        stratified_outcrop('Overhanging foreground ledge', (0.64, -0.34, 0.0), (0.76, 0.62, 0.84),
                           shelf_a, sides=22, phase=1.4, flat_bottom=True,
                           wall_slots=(2, 5, 0, 6), top_slot=4, crevice_slot=3)
        shelf_b = [
            (0.00, 0.94, 0.00, 0.00, 0.12),
            (0.35, 1.02, -0.09, -0.06, 0.14),
            (0.72, 0.86, -0.14, -0.04, 0.12),
            (1.00, 0.58, -0.10, -0.02, 0.09),
        ]
        stratified_outcrop('Weathered side terrace', (-0.78, -0.36, 0.0), (0.68, 0.56, 0.58),
                           shelf_b, sides=18, phase=2.5, flat_bottom=True,
                           wall_slots=(5, 7, 0), top_slot=1, crevice_slot=3)
        stratified_outcrop('Sunlit cap boulder', (0.28, 0.42, 0.0), (0.58, 0.50, 0.44),
                           shelf_b, sides=16, phase=3.8, flat_bottom=True,
                           wall_slots=(6, 2, 7), top_slot=4, crevice_slot=3)

    def create_kelp():
        reef_substrate(0.46, 0.42, 0.20, phase=0.7, rock_slot=6, top_slot=3, crevice_slot=3, sides=16)
        for r in range(12):
            a = r * tau / 12 + 0.2 * (r % 2)
            p0 = Vector((0.06 * math.cos(a), 0.06 * math.sin(a), 0.22))
            p1 = Vector((0.24 * math.cos(a + 0.15), 0.24 * math.sin(a + 0.15), 0.12))
            p2 = Vector((0.44 * math.cos(a + 0.32), 0.44 * math.sin(a + 0.32), 0.02))
            bishop_tube('Holdfast haptera', [p0, p1, p2], [0.042, 0.028, 0.010], slot=3, sides=5)
        stipe_specs = [
            (0.15, 4.92, 0.056, 0),
            (1.75, 4.55, 0.050, 5),
            (3.35, 4.15, 0.046, 0),
            (4.85, 3.55, 0.042, 5),
        ]
        for s_idx, (az, h_top, r0, st_slot) in enumerate(stipe_specs):
            pts, rads, r_slots = [], [], []
            n_seg = 16
            for i in range(n_seg):
                t = i / (n_seg - 1)
                sway_x = math.cos(az) * 0.11 + math.sin(t * 3.6 + s_idx * 1.4) * 0.30 * (t ** 0.9)
                sway_y = math.sin(az) * 0.11 + math.cos(t * 3.1 + s_idx * 1.9) * 0.28 * (t ** 0.9)
                pts.append(Vector((sway_x, sway_y, 0.16 + h_top * t)))
                rads.append(r0 * (1.0 - 0.68 * t))
                r_slots.append(3 if t < 0.18 else (st_slot if t < 0.72 else 2))
            bishop_tube('Sinuous kelp stipe', pts, rads, ring_slots=r_slots, sides=7)
            blade_indices = range(2, n_seg - 1, 2) if s_idx < 3 else range(2, n_seg - 1, 3)
            for b_k, idx in enumerate(blade_indices):
                base_pt = pts[idx]
                frac = idx / (n_seg - 1)
                b_az = az + b_k * 2.15 + s_idx * 0.8
                dir_v = Vector((math.cos(b_az) * 0.86, math.sin(b_az) * 0.86, 0.34 + 0.22 * frac))
                pneum = base_pt + dir_v.normalized() * 0.075
                bishop_tube('Pear pneumatocyst',
                            [base_pt, base_pt.lerp(pneum, 0.45), pneum, pneum + dir_v.normalized() * 0.055],
                            [0.016, 0.048, 0.042, 0.014], slot=4 if frac > 0.55 else 1, sides=7)
                b_len = (1.18 - 0.32 * frac) * (1.0 if s_idx < 2 else 0.86)
                b_wid = 0.19 - 0.04 * frac
                b_slot = 1 if frac > 0.68 else (2 if frac > 0.38 else 7)
                kelp_ribbon('Ruffled kelp blade', pneum + dir_v.normalized() * 0.04, dir_v,
                            b_len, b_wid, slot=b_slot, edge_slot=2 if b_slot == 7 else 4,
                            tip_slot=4, steps=14, phase=s_idx * 1.7 + b_k)

    def _build_branching_colony(staghorn=False):
        rx, ry = (0.72, 0.68) if staghorn else (0.64, 0.64)
        reef_substrate(rx, ry, 0.22, phase=1.1 if staghorn else 0.5, rock_slot=6, top_slot=6, crevice_slot=3, sides=18)
        n_primary = 8 if staghorn else 11
        for k in range(n_primary):
            az = k * tau / n_primary + 0.22 * math.sin(k * 2.1)
            spread = (0.98 if staghorn else 0.72) * (0.82 + 0.22 * ((k * 3) % 3) / 2.0)
            height = (1.92 if staghorn else 1.88) * (0.78 + 0.26 * math.cos(k * 1.3 + 0.4))
            r_base = 0.082 if staghorn else 0.074
            base_r = (0.14 + 0.12 * (k % 2)) if staghorn else (0.10 + 0.14 * (k % 3) / 2.0)
            p_start = Vector((base_r * math.cos(az), base_r * math.sin(az), 0.16))
            pts = []
            for s in range(8):
                t = s / 7
                curv = az + 0.22 * math.sin(t * 2.6 + k)
                rr = spread * (t ** 0.86)
                pts.append(p_start + Vector((math.cos(curv) * rr, math.sin(curv) * rr,
                                             height * (t ** 0.92) + 0.08 * math.sin(t * math.pi))))
            rads = [r_base * (1.0 - 0.58 * (s / 7) ** 1.1) for s in range(8)]
            main_slot = (0, 2, 5, 7)[k % 4]
            r_slots = [5 if s == 0 else (main_slot if s < 6 else 1) for s in range(8)]
            bishop_tube('Primary coral stem', pts, rads, ring_slots=r_slots,
                        sides=8, tip_dome=True, tip_slot=4)
            fork_stations = (2, 4, 5) if staghorn else (2, 3, 5, 6)
            for f_i, st_idx in enumerate(fork_stations):
                origin = pts[st_idx]
                sign = -1 if (f_i + k) % 2 == 0 else 1
                f_az = az + sign * (0.58 + 0.18 * f_i)
                f_len = (0.68 if staghorn else 0.54) * (1.0 - 0.11 * st_idx)
                f_pts = []
                for s in range(6):
                    t = s / 5
                    f_pts.append(origin + Vector((
                        math.cos(f_az + 0.18 * t * sign) * f_len * (0.72 if staghorn else 0.56) * t,
                        math.sin(f_az + 0.18 * t * sign) * f_len * (0.72 if staghorn else 0.56) * t,
                        f_len * (0.74 + 0.18 * (not staghorn)) * t + 0.05 * math.sin(t * math.pi),
                    )))
                r_sec = rads[st_idx] * 0.78
                sec_slot = (2, 7, 0, 5)[(k + f_i) % 4]
                bishop_tube('Secondary coral branch', f_pts,
                            [r_sec * (1.0 - 0.55 * (s / 5)) for s in range(6)],
                            ring_slots=[sec_slot, sec_slot, sec_slot, sec_slot, 1],
                            sides=7, tip_dome=True, tip_slot=4, v_range=(0.25, 1.0))
                for t_sign in ((-1, 1) if (not staghorn or f_i < 2) else (sign,)):
                    t_orig = f_pts[2 if t_sign < 0 else 3]
                    t_az = f_az + t_sign * 0.62
                    t_len = (0.34 if staghorn else 0.30) * (1.0 - 0.06 * st_idx)
                    t_pts = [
                        t_orig,
                        t_orig + Vector((math.cos(t_az) * t_len * 0.36, math.sin(t_az) * t_len * 0.36, t_len * 0.46)),
                        t_orig + Vector((math.cos(t_az + 0.12 * t_sign) * t_len * 0.68,
                                         math.sin(t_az + 0.12 * t_sign) * t_len * 0.68, t_len * 0.88)),
                    ]
                    bishop_tube('Tertiary corallite tine', t_pts,
                                [r_sec * 0.58, r_sec * 0.46, r_sec * 0.34],
                                ring_slots=[sec_slot, 1], sides=6, tip_dome=True, tip_slot=4, v_range=(0.45, 1.0))

    def create_coral():
        _build_branching_colony(staghorn=False)

    def create_staghorn_coral():
        _build_branching_colony(staghorn=True)

    def create_table_coral():
        reef_substrate(0.92, 0.86, 0.24, phase=0.8, rock_slot=6, top_slot=6, crevice_slot=3, sides=20)
        bishop_tube('Primary calcified pedestal',
                    [(-0.22, -0.10, 0.14), (-0.28, -0.08, 0.56), (-0.20, -0.04, 1.08)],
                    [0.24, 0.17, 0.11], slot=1, sides=10)
        bishop_tube('Secondary apricot pedestal',
                    [(0.28, 0.14, 0.14), (0.34, 0.16, 0.52), (0.24, 0.10, 0.96)],
                    [0.20, 0.14, 0.09], slot=1, sides=9)
        plates = [
            (-0.26, -0.14, 0.42, 1.08, 0.98, 0.15, 0.042, 60, 0.2, 0, 5),
            (-0.24, -0.10, 0.74, 0.82, 0.76, 0.16, 0.036, 52, 1.3, 0, 5),
            (-0.20, -0.06, 1.04, 0.52, 0.48, 0.15, 0.030, 44, 2.4, 5, 0),
            (-0.18, -0.05, 1.24, 0.25, 0.23, 0.11, 0.024, 32, 3.5, 0, 5),
            (0.34, 0.18, 0.34, 0.98, 0.90, 0.14, 0.040, 56, 0.9, 2, 7),
            (0.30, 0.14, 0.64, 0.74, 0.68, 0.15, 0.034, 48, 2.1, 7, 2),
            (0.24, 0.10, 0.94, 0.46, 0.43, 0.14, 0.028, 40, 3.2, 2, 7),
            (0.06, -0.58, 0.24, 0.54, 0.48, 0.10, 0.030, 38, 4.1, 0, 5),
            (-0.10, 0.56, 0.88, 0.60, 0.54, 0.13, 0.032, 42, 4.9, 2, 7),
        ]
        for x, y, z, rx, ry, cup, th, segs, ph, ts, ins in plates:
            acropora_plate('Acropora rosette plate', (x, y, z), rx, ry, cup=cup, thick=th,
                           segments=segs, phase=ph, top_slot=ts, inner_slot=ins, rim_slot=4, under_slot=1)

    def fluted_sponge_vessel(name, base_xy, base_z, height, radius, lean_xy=(0.0, 0.0),
                             segments=42, outer_rings=16, inner_rings=9, n_flutes=13,
                             bulbous=0.42, wall_thick=0.22, cavity_depth=0.78,
                             wall_slots=(0, 2, 5, 7), rim_slot=4, inner_slot=3, phase=0.0):
        verts, uv, faces, slots = [], [], [], []
        bx, by = base_xy
        lx, ly = lean_xy
        verts.append((bx, by, base_z))
        uv.append((0.5, 0.0))
        out_start = len(verts)
        for i in range(outer_rings + 1):
            t = i / outer_rings
            cx = bx + lx * (t ** 1.15)
            cy = by + ly * (t ** 1.15)
            cz = base_z + height * t
            prof = (0.62 + bulbous * math.sin(t * math.pi * 0.78) - 0.10 * (t ** 3)) * radius
            for j in range(segments):
                a = tau * j / segments
                rib_wave = 0.5 + 0.5 * math.cos(a * n_flutes + 0.32 * math.sin(a * 3.0 + t * 4.5 + phase))
                buttress = (rib_wave ** 1.8) * 0.135 * math.sin(math.pi * min(0.96, 0.12 + 0.82 * t))
                crinkle = 0.028 * math.sin(t * math.pi * 10.0 + a * 2.0 + phase) * (1.0 - 0.5 * (t ** 2))
                sc_rim = 0.038 * math.sin(a * 7.0 + phase) * (t ** 4) + 0.018 * math.cos(a * 13.0 - phase) * (t ** 5)
                rr = prof * (1.0 + buttress + crinkle)
                verts.append((cx + rr * math.cos(a), cy + rr * math.sin(a), cz + height * sc_rim * 0.35))
                uv.append((j / segments, t))
        in_start = len(verts)
        for i in range(inner_rings + 1):
            s = i / inner_rings
            t = 1.0 - cavity_depth * s
            cx = bx + lx * (t ** 1.15)
            cy = by + ly * (t ** 1.15)
            cz = base_z + height * t
            prof = (0.62 + bulbous * math.sin(t * math.pi * 0.78) - 0.10 * (t ** 3)) * radius
            in_scale = (1.0 - wall_thick) * (1.0 - 0.32 * (s ** 1.6))
            for j in range(segments):
                a = tau * j / segments
                sc_rim = (0.038 * math.sin(a * 7.0 + phase) + 0.018 * math.cos(a * 13.0 - phase)) * ((1.0 - s) ** 3)
                in_rib = 1.0 + 0.025 * math.cos(a * n_flutes + phase) + 0.015 * math.sin(s * math.pi * 6.0)
                rr = prof * in_scale * in_rib
                verts.append((cx + rr * math.cos(a), cy + rr * math.sin(a), cz + height * sc_rim * 0.35))
                uv.append((j / segments, max(0.05, 1.0 - s * 0.85)))
        in_floor = len(verts)
        t_fl = 1.0 - cavity_depth
        verts.append((bx + lx * (t_fl ** 1.15), by + ly * (t_fl ** 1.15), base_z + height * max(0.06, t_fl - 0.03)))
        uv.append((0.5, 0.1))
        for j in range(segments):
            jn = (j + 1) % segments
            faces.append((0, out_start + jn, out_start + j))
            slots.append(inner_slot)
        for i in range(outer_rings):
            r0, r1 = out_start + i * segments, out_start + (i + 1) * segments
            for j in range(segments):
                jn = (j + 1) % segments
                a = tau * (j + 0.5) / segments
                crest = math.cos(a * n_flutes) > 0.35
                faces.append((r0 + j, r0 + jn, r1 + jn, r1 + j))
                if i == outer_rings - 1:
                    slots.append(1 if crest else wall_slots[0])
                else:
                    slots.append(wall_slots[1 if crest else ((i + j) % len(wall_slots))])
        top_out = out_start + outer_rings * segments
        for j in range(segments):
            jn = (j + 1) % segments
            faces.append((top_out + j, top_out + jn, in_start + jn, in_start + j))
            slots.append(rim_slot)
        for i in range(inner_rings):
            r0, r1 = in_start + i * segments, in_start + (i + 1) * segments
            s_in = 5 if i < 2 else inner_slot
            for j in range(segments):
                jn = (j + 1) % segments
                faces.append((r0 + j, r0 + jn, r1 + jn, r1 + j))
                slots.append(s_in)
        bot_in = in_start + inner_rings * segments
        for j in range(segments):
            jn = (j + 1) % segments
            faces.append((bot_in + j, bot_in + jn, in_floor))
            slots.append(inner_slot)
        return api.mesh(name, verts, faces, uv, face_slots=slots, smooth=True)

    def create_tube_coral():
        reef_substrate(0.72, 0.58, 0.22, phase=1.2, rock_slot=6, top_slot=6, crevice_slot=3, sides=18)
        tubes = [
            (-0.08, 0.06, 0.14, 2.44, 0.27, (-0.06, 0.08), 32, 14, 8, 10, 0.3) ,
            (0.32, 0.12, 0.14, 1.98, 0.24, (0.18, 0.09), 30, 13, 8, 9, 1.4),
            (-0.34, -0.14, 0.13, 1.72, 0.22, (-0.16, -0.10), 28, 12, 7, 9, 2.3),
            (0.14, -0.26, 0.13, 1.46, 0.21, (0.12, -0.15), 26, 11, 7, 8, 3.2),
            (0.56, -0.06, 0.12, 1.24, 0.19, (0.20, -0.04), 24, 10, 6, 8, 4.1),
            (-0.18, 0.34, 0.12, 1.12, 0.18, (-0.10, 0.14), 24, 10, 6, 8, 5.0),
            (0.42, 0.34, 0.11, 0.88, 0.16, (0.16, 0.14), 22, 9, 6, 7, 5.8),
        ]
        for x, y, bz, h, r, lean, segs, orings, irings, nf, ph in tubes:
            fluted_sponge_vessel('Organ-pipe sponge chimney', (x, y), bz, h, r, lean_xy=lean,
                                 segments=segs, outer_rings=orings, inner_rings=irings, n_flutes=nf,
                                 bulbous=0.22, wall_thick=0.23, cavity_depth=0.80,
                                 wall_slots=(0, 2, 7, 5), rim_slot=4, inner_slot=3, phase=ph)

    def create_barrel_sponge():
        reef_substrate(0.84, 0.82, 0.24, phase=0.4, rock_slot=6, top_slot=6, crevice_slot=3, sides=20)
        fluted_sponge_vessel('Primary Xestospongia barrel', (0.06, 0.08), 0.15, 2.30, 0.68,
                             lean_xy=(0.14, 0.06), segments=52, outer_rings=18, inner_rings=10,
                             n_flutes=15, bulbous=0.46, wall_thick=0.20, cavity_depth=0.78,
                             wall_slots=(0, 2, 7, 5), rim_slot=4, inner_slot=3, phase=0.3)
        fluted_sponge_vessel('Secondary fluted barrel', (-0.52, -0.34), 0.14, 1.38, 0.43,
                             lean_xy=(-0.14, -0.10), segments=38, outer_rings=14, inner_rings=8,
                             n_flutes=12, bulbous=0.44, wall_thick=0.21, cavity_depth=0.76,
                             wall_slots=(5, 0, 2, 7), rim_slot=4, inner_slot=3, phase=1.9)
        fluted_sponge_vessel('Juvenile side barrel', (0.48, -0.44), 0.12, 0.92, 0.30,
                             lean_xy=(0.12, -0.11), segments=30, outer_rings=11, inner_rings=7,
                             n_flutes=10, bulbous=0.42, wall_thick=0.22, cavity_depth=0.74,
                             wall_slots=(7, 2, 0, 5), rim_slot=4, inner_slot=3, phase=3.4)

    def create_anemone():
        reef_substrate(0.92, 0.88, 0.24, phase=1.6, rock_slot=6, top_slot=6, crevice_slot=3, sides=20)
        col_segs, col_rings = 36, 12
        c_verts, c_uv, c_faces, c_slots = [(0.0, 0.0, 0.12)], [(0.5, 0.0)], [], []
        for i in range(col_rings + 1):
            t = i / col_rings
            base_r = 0.56 - 0.12 * math.sin(t * math.pi * 0.7) + 0.26 * (t ** 2.4)
            z = 0.14 + 0.68 * t
            for j in range(col_segs):
                a = tau * j / col_segs
                furrow = 1.0 + 0.045 * math.cos(a * 14.0) + (0.055 * math.sin(a * 9.0 + 0.6) if t > 0.72 else 0.0)
                c_verts.append((base_r * furrow * math.cos(a), base_r * furrow * math.sin(a),
                                z + 0.028 * (t ** 3) * math.sin(a * 9.0)))
                c_uv.append((j / col_segs, t))
        oral_center = len(c_verts)
        c_verts.append((0.0, 0.0, 0.78))
        c_uv.append((0.5, 0.2))
        for j in range(col_segs):
            jn = (j + 1) % col_segs
            c_faces.append((0, 1 + jn, 1 + j))
            c_slots.append(5)
        for i in range(col_rings):
            r0, r1 = 1 + i * col_segs, 1 + (i + 1) * col_segs
            for j in range(col_segs):
                jn = (j + 1) % col_segs
                c_faces.append((r0 + j, r0 + jn, r1 + jn, r1 + j))
                c_slots.append(5 if i < 5 else 0)
        top_r = 1 + col_rings * col_segs
        for j in range(col_segs):
            jn = (j + 1) % col_segs
            c_faces.append((top_r + j, top_r + jn, oral_center))
            c_slots.append(1)
        api.mesh('Verrucose pedal column and oral disc', c_verts, c_faces, c_uv, face_slots=c_slots, smooth=True)
        api.ellipsoid('Pleated actinopharynx mouth', (0.0, 0.0, 0.80), (0.16, 0.10, 0.045), 3, segments=16, rings=6)
        whorls = [
            (22, 0.62, 0.82, 0.42, -0.14, 0.068, 1),
            (18, 0.48, 0.74, 0.68, 0.04, 0.062, 2),
            (14, 0.33, 0.56, 0.88, 0.28, 0.056, 7),
            (10, 0.18, 0.34, 0.96, 0.48, 0.050, 2),
        ]
        for w_idx, (count, r0, reach, lift, drop, thick0, base_s) in enumerate(whorls):
            for k in range(count):
                a = tau * (k + 0.37 * w_idx) / count + 0.05 * math.sin(k * 2.3)
                pts, rads, r_slots = [], [], []
                for s in range(8):
                    t = s / 7
                    curl = a + 0.20 * math.sin(t * 2.4 + k * 0.7 + w_idx)
                    rad_d = r0 + reach * (t ** 0.88) * (0.92 + 0.14 * math.cos(k * 1.9 + w_idx))
                    z = 0.79 + lift * math.sin(t * math.pi * 0.68) + drop * (t ** 1.7)
                    pts.append(Vector((rad_d * math.cos(curl), rad_d * math.sin(curl), z)))
                    bulb = 1.0 + 0.22 * math.exp(-(((t - 0.80) / 0.14) ** 2))
                    rads.append(thick0 * (1.0 - 0.66 * (t ** 1.15)) * bulb)
                    r_slots.append(base_s if s < 4 else (7 if s < 5 else (4 if s == 5 else 0)))
                bishop_tube('Rose-tipped anemone tentacle', pts, rads, ring_slots=r_slots,
                            sides=6, tip_dome=True, tip_slot=0)

    def create_sea_fan():
        reef_substrate(0.42, 0.34, 0.20, phase=0.9, rock_slot=6, top_slot=6, crevice_slot=6, sides=18)

        def fan_point(u_ang, r_norm):
            reach_r = 2.08 * (0.86 + 0.14 * math.cos(u_ang * 1.45) + 0.05 * math.sin(u_ang * 7.0))
            rr = reach_r * r_norm
            x = rr * math.sin(u_ang) * 0.54
            z = 0.44 + rr * math.cos(u_ang * 0.72) * 1.02
            y = 0.26 * math.sin(u_ang * 2.1 + r_norm * 2.4) * (r_norm ** 0.85) + 0.08 * math.cos(r_norm * 4.5)
            return Vector((x, y, z))

        bishop_tube('Gorgonian holdfast trunk',
                    [(0.0, -0.02, 0.10), (-0.01, 0.02, 0.30), (0.0, 0.06, 0.46), (0.0, 0.08, 0.56)],
                    [0.102, 0.082, 0.068, 0.048], slot=5, sides=8, flatten=0.68, v_range=(0.0, 1.0))
        n_veins = 9
        vein_paths = []
        for k in range(n_veins):
            u_base = (k / (n_veins - 1) - 0.5) * 2.16
            pts, rads = [Vector((0.0, 0.065, 0.47))], [0.040]
            for s in range(11):
                rn = 0.04 + 0.96 * (s / 10)
                wobble = 0.045 * math.sin(rn * 5.2 + k * 1.3)
                pts.append(fan_point(u_base + wobble, rn))
                rads.append(0.036 * (1.0 - 0.78 * (s / 10)))
            vein_paths.append((u_base, pts))
            bishop_tube('Primary gorgonian vein', pts, rads, slot=0,
                        sides=5, flatten=0.75, tip_dome=True, tip_slot=4, v_range=(0.0, 1.0))
            for st_i in (3, 5, 7):
                for sign in (-1, 1):
                    if (k == 0 and sign < 0 and st_i > 5) or (k == n_veins - 1 and sign > 0 and st_i > 5):
                        continue
                    rn0 = 0.04 + 0.96 * (st_i / 10)
                    rn1 = min(1.02, rn0 + 0.28)
                    du = sign * (0.14 + 0.04 * (st_i % 2))
                    p0 = pts[st_i + 1]
                    pm = fan_point(u_base + du * 0.55, (rn0 + rn1) * 0.5)
                    p1 = fan_point(u_base + du, rn1)
                    bishop_tube('Secondary fan branch', [p0, pm, p1], [0.018, 0.012, 0.006],
                                slot=7, sides=4, tip_dome=True, tip_slot=4, v_range=(rn0, min(1.0, rn1)))
                    if rn1 > 0.76:
                        for twig_s in (-1, 1):
                            pt_end = fan_point(u_base + du + twig_s * 0.055, min(1.04, rn1 + 0.09))
                            bishop_tube('Peach fan margin tip', [p1, pt_end], [0.006, 0.003],
                                        slot=4, sides=4, v_range=(0.85, 1.0))
        for k in range(n_veins - 1):
            _, pts_a = vein_paths[k]
            _, pts_b = vein_paths[k + 1]
            for step in range(3, 11):
                pa = pts_a[step]
                pb = pts_b[min(11, step + (1 if (k + step) % 2 == 0 else 0))]
                mid = (pa + pb) * 0.5 + Vector((0.0, 0.012 * math.sin(k + step), 0.035))
                rn = (step - 1) / 10
                bishop_tube('Anastomosing lace bridge', [pa, mid, pb], [0.009, 0.007, 0.009],
                            slot=0, sides=4, v_range=(rn, min(1.0, rn + 0.12)))
                if step >= 4:
                    diag = (pts_a[step - 1] + pts_b[step]) * 0.5 + Vector((0.0, -0.008, 0.02))
                    bishop_tube('Reticulate cross meshlet', [mid, diag], [0.0065, 0.005],
                                slot=7, sides=3, v_range=(rn, min(1.0, rn + 0.08)))

    def create_tubeworms():
        reef_substrate(0.58, 0.50, 0.20, phase=1.8, rock_slot=6, top_slot=6, crevice_slot=3, sides=18)
        worm_specs = [
            (0.02, 0.02, 2.02, 0.054, (0.06, 0.04)),
            (0.24, 0.14, 1.84, 0.050, (0.14, 0.08)),
            (-0.22, 0.12, 1.72, 0.048, (-0.15, 0.09)),
            (0.16, -0.22, 1.56, 0.046, (0.12, -0.14)),
            (-0.26, -0.18, 1.44, 0.045, (-0.16, -0.12)),
            (0.40, -0.04, 1.28, 0.042, (0.20, -0.04)),
            (-0.04, 0.30, 1.18, 0.040, (-0.04, 0.18)),
            (-0.42, 0.02, 1.02, 0.038, (-0.20, 0.03)),
            (0.28, 0.28, 0.86, 0.036, (0.16, 0.16)),
        ]
        for idx, (bx, by, h, r0, lean) in enumerate(worm_specs):
            pts, rads, r_slots = [], [], []
            for s in range(10):
                t = s / 9
                pts.append(Vector((bx + lean[0] * (t ** 1.25) + 0.03 * math.sin(t * 3.5 + idx),
                                   by + lean[1] * (t ** 1.25) + 0.03 * math.cos(t * 3.1 + idx),
                                   0.12 + h * t)))
                collar = 1.0 + (0.14 if s in (3, 6, 9) else 0.0)
                rads.append(r0 * (1.0 - 0.16 * t) * collar)
                r_slots.append(3 if s == 0 else (0 if s < 6 else 1))
            bishop_tube('Chitinous parchment tube', pts, rads, ring_slots=r_slots, sides=9)
            crown = pts[-1]
            axis = (pts[-1] - pts[-2]).normalized()
            lat = axis.cross(Vector((0, 0, 1)))
            lat = Vector((1, 0, 0)) if lat.length < 0.05 else lat.normalized()
            up_v = lat.cross(axis).normalized()
            for tier, (n_rad, r_len, spread_a, lift_a, pl_slot) in enumerate((
                (10, 0.25 - 0.01 * idx, 0.82, 0.68, 2 if idx % 2 == 0 else 7),
                (7, 0.17 - 0.007 * idx, 0.48, 0.92, 5),
            )):
                for f in range(n_rad):
                    a = tau * (f + 0.42 * tier) / n_rad + idx * 0.5
                    radial_d = lat * math.cos(a) + up_v * math.sin(a)
                    p0 = crown + radial_d * (r0 * 0.45) + axis * (0.025 * tier)
                    p1 = p0 + (radial_d * (spread_a * 0.48) + axis * lift_a).normalized() * (r_len * 0.52)
                    p2 = p1 + (radial_d * spread_a + axis * (lift_a * 0.42)).normalized() * (r_len * 0.56)
                    kelp_ribbon('Feathery crimson radiole', p0, p2 - p0, r_len, 0.034 - 0.006 * tier,
                                slot=pl_slot, edge_slot=7 if pl_slot == 5 else 2,
                                tip_slot=4, steps=5, phase=f + idx)

    def create_starfish_urchin():
        boulder_layers = [
            (0.00, 0.96, 0.00, 0.00, 0.11),
            (0.32, 1.04, 0.04, -0.02, 0.13),
            (0.64, 0.88, -0.03, 0.03, 0.11),
            (0.88, 0.72, -0.02, 0.01, 0.09),
            (1.00, 0.48, 0.00, 0.00, 0.07),
        ]
        boulder = stratified_outcrop('Tidepool limestone boulder', (0.0, 0.0, 0.0), (0.64, 0.57, 0.25),
                                     boulder_layers, sides=28, phase=0.8, flat_bottom=True,
                                     wall_slots=(6, 1, 6), top_slot=1, crevice_slot=3)
        down_ray = Vector((0.0, 0.0, -1.0))

        def _raw_rock_z(px, py):
            hit, loc, _, _ = boulder.ray_cast(Vector((px, py, 1.0)), down_ray)
            if hit:
                return loc.z
            d = math.hypot(px / 0.64, py / 0.57)
            return max(0.06, 0.25 - 0.18 * min(1.2, max(0.0, d - 0.45) / 0.55))

        def rock_z(px, py):
            z0 = _raw_rock_z(px, py)
            zs = [z0,
                  _raw_rock_z(px + 0.028, py), _raw_rock_z(px - 0.028, py),
                  _raw_rock_z(px, py + 0.028), _raw_rock_z(px, py - 0.028)]
            return max(z0, max(zs) * 0.55 + (sum(zs) / 5.0) * 0.45) + 0.004

        star_specs = [
            (-0.12, -0.11, 0.34, 0.068, 0.18, 0, 7, 3),
            (-0.28, 0.22, 0.24, 0.052, 0.92, 2, 0, 4),
        ]
        for s_idx, (cx, cy, size, thick, rot, body_s, edge_s, horn_s) in enumerate(star_specs):
            n_ang, rads_f = 50, (0.18, 0.40, 0.64, 0.85, 1.00)
            nr = len(rads_f)
            verts, uv, faces, slots = [], [], [], []
            zc = rock_z(cx, cy)
            verts.append((cx, cy, zc + thick))
            uv.append((0.5, 0.5))
            for rf in rads_f:
                for j in range(n_ang):
                    a0 = tau * j / n_ang
                    arm_w = (0.5 + 0.5 * math.cos(5.0 * (a0 - rot))) ** 1.85
                    r_star = size * (0.31 + 0.69 * arm_w) * rf
                    a_curv = a0 + 0.11 * (rf ** 1.8) * math.sin(a0 * 2.0 + s_idx * 1.7)
                    px, py = cx + r_star * math.cos(a_curv), cy + r_star * math.sin(a_curv)
                    pz_base = rock_z(px, py)
                    dome = thick * ((1.0 - rf ** 1.55) * (0.55 + 0.45 * arm_w) + 0.16 * (rf ** 3) * arm_w)
                    verts.append((px, py, pz_base + max(0.012, dome)))
                    uv.append((0.5 + 0.48 * rf * math.cos(a0), 0.5 + 0.48 * rf * math.sin(a0)))
            bot_start = len(verts)
            verts.append((cx, cy, zc - 0.003))
            uv.append((0.5, 0.5))
            for rf in rads_f:
                for j in range(n_ang):
                    a0 = tau * j / n_ang
                    arm_w = (0.5 + 0.5 * math.cos(5.0 * (a0 - rot))) ** 1.85
                    r_star = size * (0.31 + 0.69 * arm_w) * rf * (0.985 if rf == 1.0 else 1.0)
                    a_curv = a0 + 0.11 * (rf ** 1.8) * math.sin(a0 * 2.0 + s_idx * 1.7)
                    px, py = cx + r_star * math.cos(a_curv), cy + r_star * math.sin(a_curv)
                    verts.append((px, py, _raw_rock_z(px, py) - 0.003))
                    uv.append((0.5 + 0.48 * rf * math.cos(a0), 0.5 + 0.48 * rf * math.sin(a0)))
            for j in range(n_ang):
                jn = (j + 1) % n_ang
                faces.append((0, 1 + j, 1 + jn))
                slots.append(body_s)
                faces.append((bot_start, bot_start + 1 + jn, bot_start + 1 + j))
                slots.append(1)
            for ri in range(nr - 1):
                t0, t1 = 1 + ri * n_ang, 1 + (ri + 1) * n_ang
                u0, u1 = bot_start + 1 + ri * n_ang, bot_start + 1 + (ri + 1) * n_ang
                for j in range(n_ang):
                    jn = (j + 1) % n_ang
                    faces.append((t0 + j, t1 + j, t1 + jn, t0 + jn))
                    slots.append(edge_s if ri == nr - 2 else body_s)
                    faces.append((u0 + j, u0 + jn, u1 + jn, u1 + j))
                    slots.append(1)
            to_r, bo_r = 1 + (nr - 1) * n_ang, bot_start + 1 + (nr - 1) * n_ang
            for j in range(n_ang):
                jn = (j + 1) % n_ang
                faces.append((to_r + j, bo_r + j, bo_r + jn, to_r + jn))
                slots.append(edge_s)
            api.mesh('Sculpted 3D sea star', verts, faces, uv, face_slots=slots, smooth=True)
            bishop_tube('Central sea star horn', [(cx, cy, zc + thick * 0.9), (cx, cy, zc + thick * 1.38)],
                        [0.018, 0.005], slot=horn_s, sides=6, tip_dome=True, tip_slot=horn_s)
            for j in range(5):
                aa = rot + j * tau / 5
                for step_r, h_sc in ((0.24, 1.0), (0.48, 0.82), (0.70, 0.62)):
                    ac = aa + 0.11 * (step_r ** 1.8) * math.sin(aa * 2.0 + s_idx * 1.7)
                    hx, hy = cx + size * step_r * math.cos(ac), cy + size * step_r * math.sin(ac)
                    hz = rock_z(hx, hy) + thick * (1.0 - step_r ** 1.55)
                    bishop_tube('Tuberculate carinal horn',
                                [(hx, hy, hz - 0.004), (hx, hy, hz + 0.026 * h_sc)],
                                [0.015 * h_sc, 0.004 * h_sc], slot=horn_s, sides=5, tip_dome=True, tip_slot=horn_s)
        urchins = [
            (Vector((0.28, 0.18, rock_z(0.28, 0.18) + 0.075)), 0.125, 0.095, 52, 0.255),
            (Vector((0.36, -0.18, rock_z(0.36, -0.18) + 0.055)), 0.088, 0.068, 30, 0.185),
        ]
        for center, rx, rz, n_sp, sp_len in urchins:
            api.ellipsoid('Diadema urchin test', center, (rx, rx, rz), 5, segments=18, rings=10, organic=0.04)
            api.ellipsoid('Urchin apical ring', center + Vector((0, 0, rz * 0.92)),
                          (rx * 0.26, rx * 0.26, 0.014), 3, segments=12, rings=5)
            for j in range(n_sp):
                a = j * 2.399963
                zz = 0.05 + 0.92 * ((j + 0.5) / n_sp)
                rr_xy = math.sqrt(max(0.0, 1.0 - zz * zz))
                d_vec = Vector((rr_xy * math.cos(a), rr_xy * math.sin(a), zz)).normalized()
                p0 = center + Vector((d_vec.x * rx * 0.86, d_vec.y * rx * 0.86, d_vec.z * rz * 0.86))
                l_sp = sp_len * (0.78 + 0.28 * math.sin(j * 1.9))
                p1 = p0 + d_vec * l_sp
                bishop_tube('Long Diadema spine', [p0, p0.lerp(p1, 0.14), p1],
                            [0.011, 0.0075, 0.0014], slot=3 if j % 3 else 5, sides=4)

    def create_brain_coral():
        reef_substrate(0.84, 0.80, 0.18, phase=2.2, rock_slot=6, top_slot=6, crevice_slot=3, sides=26)

        def brain_lobe(name, center, scale, segs, rings, freq, seed_p, crest_s, wall_s, valley_s):
            cx, cy, cz = center
            sx, sy, sz = scale
            verts, uv, faces, slots, heights = [], [], [], [], []
            verts.append((cx, cy, cz + sz * 1.03))
            uv.append((0.5, 1.0))
            heights.append(0.5)
            for i in range(1, rings + 1):
                theta = (i / rings) * (math.pi * 0.64)
                st, ct = math.sin(theta), math.cos(theta)
                skirt = math.sin(min(1.0, i / rings) * math.pi * 0.88)
                for j in range(segs):
                    phi = tau * j / segs
                    nx, ny, nz = st * math.cos(phi), st * math.sin(phi), ct
                    px, py, pz = nx * sx, ny * sy, nz * sz
                    w1 = math.sin(freq * (px * 0.82 - py * 0.57) + 1.55 * math.cos(freq * 0.72 * (py * 0.76 + pz * 0.65) + seed_p))
                    w2 = math.cos(freq * 0.94 * (px * 0.45 + py * 0.89 + pz * 0.35) + 1.65 * w1 + seed_p)
                    gyrus = math.tanh(1.75 * math.sin(freq * 1.05 * (pz * 0.75 - px * 0.55) + 1.85 * w2))
                    disp = 0.056 * gyrus * skirt
                    verts.append((cx + px + nx * disp, cy + py + ny * disp, max(0.06, cz + pz + nz * disp)))
                    uv.append((j / segs * 4.0 % 1.0, (0.5 + 0.5 * gyrus)))
                    heights.append(gyrus)
            bot_idx = len(verts)
            verts.append((cx, cy, max(0.04, cz - sz * 0.25)))
            uv.append((0.5, 0.0))
            heights.append(-1.0)
            for j in range(segs):
                jn = (j + 1) % segs
                faces.append((0, 1 + j, 1 + jn))
                slots.append(crest_s)
            for i in range(rings - 1):
                r0, r1 = 1 + i * segs, 1 + (i + 1) * segs
                for j in range(segs):
                    jn = (j + 1) % segs
                    q = (r0 + j, r1 + j, r1 + jn, r0 + jn)
                    faces.append(q)
                    slots.append(crest_s)
            last_r = 1 + (rings - 1) * segs
            for j in range(segs):
                jn = (j + 1) % segs
                faces.append((last_r + j, bot_idx, last_r + jn))
                slots.append(3)
            return api.mesh(name, verts, faces, uv, face_slots=slots, smooth=True)

        brain_lobe('Primary brain coral hemisphere', (0.12, 0.10, 0.42), (0.86, 0.82, 0.96),
                   segs=88, rings=42, freq=8.4, seed_p=0.4, crest_s=4, wall_s=0, valley_s=3)
        brain_lobe('Secondary ochre meandroid lobe', (-0.50, -0.34, 0.28), (0.52, 0.48, 0.62),
                   segs=58, rings=26, freq=9.6, seed_p=2.1, crest_s=1, wall_s=2, valley_s=5)
        brain_lobe('Tertiary sunlit brain lobe', (-0.26, 0.50, 0.24), (0.42, 0.40, 0.48),
                   segs=46, rings=20, freq=10.4, seed_p=3.9, crest_s=7, wall_s=5, valley_s=3)

    def create_giant_clam():
        reef_substrate(0.86, 0.72, 0.22, phase=1.5, rock_slot=6, top_slot=6, crevice_slot=3, sides=20)
        u_steps, v_steps = 56, 15

        def valve_point(sign, u_f, t_f, inner=False):
            a = (u_f - 0.5) * math.pi * 0.94
            fold = math.cos(a * 6.5 + (0.0 if sign > 0 else math.pi))
            deep_rib = (0.095 * fold + 0.022 * math.cos(a * 13.0)) * (t_f ** 1.15)
            scute_wave = 0.016 * max(0.0, math.sin(t_f * math.pi * 9.0)) * (0.4 + 0.6 * max(0.0, fold)) * (0.0 if inner else 1.0)
            thick = (0.085 * (1.0 - 0.58 * t_f) + 0.022) if inner else 0.0
            x = math.sin(a) * (1.10 * (t_f ** 0.70))
            y = sign * (0.075 + 0.74 * math.sin(t_f * math.pi * 0.64) + deep_rib + scute_wave - thick)
            z = 0.16 + 1.12 * (t_f ** 0.86) * (0.62 + 0.38 * math.cos(a * 0.78)) + 0.075 * fold * (t_f ** 1.4)
            return Vector((x, y, z)), fold

        for sign in (-1, 1):
            verts, uv, faces, slots = [], [], [], []
            folds_grid = []
            for inner in (False, True):
                for vi in range(v_steps + 1):
                    tf = 0.04 + 0.96 * (vi / v_steps)
                    for ui in range(u_steps + 1):
                        uf = ui / u_steps
                        pt, fld = valve_point(sign, uf, tf, inner=inner)
                        verts.append(pt)
                        uv.append((uf, tf))
                        folds_grid.append(fld)
            stride = (u_steps + 1) * (v_steps + 1)
            for layer in (0, 1):
                for vi in range(v_steps):
                    for ui in range(u_steps):
                        n = layer * stride + vi * (u_steps + 1) + ui
                        q = (n, n + 1, n + u_steps + 2, n + u_steps + 1)
                        flip = (sign > 0) == (layer == 0)
                        faces.append(tuple(reversed(q)) if flip else q)
                        slots.append(1 if layer == 1 else (0 if folds_grid[n] > -0.25 else 6))
            for ui in range(u_steps):
                t0, b0 = v_steps * (u_steps + 1) + ui, ui
                q_top = (t0, t0 + 1, t0 + stride + 1, t0 + stride)
                q_bot = (b0, b0 + stride, b0 + stride + 1, b0 + 1)
                faces.append(q_top if sign < 0 else tuple(reversed(q_top)))
                slots.append(1)
                faces.append(q_bot if sign < 0 else tuple(reversed(q_bot)))
                slots.append(3)
            for vi in range(v_steps):
                l0, r0 = vi * (u_steps + 1), vi * (u_steps + 1) + u_steps
                q_l = (l0, l0 + u_steps + 1, l0 + stride + u_steps + 1, l0 + stride)
                q_r = (r0, r0 + stride, r0 + stride + u_steps + 1, r0 + u_steps + 1)
                faces.append(q_l if sign < 0 else tuple(reversed(q_l)))
                slots.append(0)
                faces.append(q_r if sign < 0 else tuple(reversed(q_r)))
                slots.append(0)
            api.mesh('Fluted Tridacna calcite valve', verts, faces, uv, face_slots=slots, smooth=True)
            for tier_t in (0.38, 0.56, 0.74, 0.90):
                for flute_k in range(-3, 4):
                    a_c = (flute_k / 6.5) * math.pi - (0.0 if sign > 0 else math.pi / 6.5)
                    uf_c = a_c / (math.pi * 0.94) + 0.5
                    if 0.08 < uf_c < 0.92:
                        sc_pts = []
                        for du in (-0.042, -0.020, 0.0, 0.020, 0.042):
                            base_p, _ = valve_point(sign, uf_c + du, tier_t, inner=False)
                            arch = math.cos(du / 0.042 * math.pi * 0.5)
                            sc_pts.append(base_p + Vector((0.0, sign * 0.048 * arch, 0.022 * arch)))
                        bishop_tube('Projecting concentric scute', sc_pts,
                                    [0.008, 0.019, 0.024, 0.019, 0.008], slot=1, sides=5, flatten=0.45)
        mu_steps, mv_steps = 52, 16
        m_verts, m_uv, m_faces, m_slots = [], [], [], []
        for under in (False, True):
            for ui in range(mu_steps + 1):
                uf = ui / mu_steps
                p_neg, _ = valve_point(-1, uf, 0.96, inner=True)
                p_pos, _ = valve_point(1, uf, 0.96, inner=True)
                a = (uf - 0.5) * math.pi * 0.92
                for vj in range(mv_steps + 1):
                    vf = vj / mv_steps
                    s_lat = vf * 2.0 - 1.0
                    span_p = p_neg.lerp(p_pos, vf)
                    curl = math.exp(-(((abs(s_lat) - 0.90) / 0.14) ** 2))
                    billow = 0.065 * math.sin(uf * tau * 5.5 + s_lat * 2.2) * (abs(s_lat) ** 1.3)
                    trough = -0.14 * (1.0 - s_lat * s_lat)
                    lip_spill = 0.085 * (s_lat ** 3) * curl
                    if under:
                        pt = Vector((span_p.x * 0.95, span_p.y * 0.88, max(0.24, span_p.z - 0.24 - 0.12 * (1.0 - s_lat * s_lat))))
                    else:
                        pt = Vector((span_p.x * (1.0 + 0.02 * curl),
                                     span_p.y + lip_spill,
                                     span_p.z + 0.055 * curl + billow + trough))
                    m_verts.append(pt)
                    m_uv.append((uf, abs(s_lat)))
        m_stride = (mu_steps + 1) * (mv_steps + 1)
        for ui in range(mu_steps):
            for vj in range(mv_steps):
                n = ui * (mv_steps + 1) + vj
                m_faces.append((n, n + mv_steps + 1, n + mv_steps + 2, n + 1))
                s_abs = abs((vj + 0.5) / mv_steps * 2.0 - 1.0)
                m_slots.append(5 if s_abs > 0.72 else (7 if s_abs > 0.36 else 2))
                nb = m_stride + n
                m_faces.append((nb, nb + 1, nb + mv_steps + 2, nb + mv_steps + 1))
                m_slots.append(3)
        for ui in range(mu_steps):
            for edge_j, rev in ((0, False), (mv_steps, True)):
                a0 = ui * (mv_steps + 1) + edge_j
                b0 = a0 + (mv_steps + 1)
                q = (a0, b0, b0 + m_stride, a0 + m_stride)
                m_faces.append(tuple(reversed(q)) if rev else q)
                m_slots.append(5)
        for vj in range(mv_steps):
            for end_u, rev in ((0, True), (mu_steps, False)):
                a0 = end_u * (mv_steps + 1) + vj
                q = (a0, a0 + 1, a0 + m_stride + 1, a0 + m_stride)
                m_faces.append(tuple(reversed(q)) if rev else q)
                m_slots.append(2)
        api.mesh('Billowing iridescent clam mantle', m_verts, m_faces, m_uv, face_slots=m_slots, smooth=True)
        fluted_sponge_vessel('Exhalant muscular siphon', (-0.22, 0.0), 0.78, 0.24, 0.14,
                             segments=22, outer_rings=6, inner_rings=4, n_flutes=8,
                             bulbous=0.18, wall_thick=0.26, cavity_depth=0.72,
                             wall_slots=(5, 2, 7), rim_slot=4, inner_slot=3, phase=0.5)
        api.ring('Inhalant frilled siphon rim', (0.28, 0.0, 0.89), 0.22, 0.085, 0.028, 5, plane='XY', segments=24, sides=6)
        api.ellipsoid('Inhalant siphon aperture', (0.28, 0.0, 0.87), (0.19, 0.062, 0.025), 3, segments=16, rings=6)

    def create_sea_lily():
        reef_substrate(0.50, 0.48, 0.20, phase=2.0, rock_slot=6, top_slot=6, crevice_slot=3, sides=18)
        lilies = [
            (Vector((0.06, 0.04, 0.14)), Vector((-0.04, 0.02, 1.88)), 12, 0.90, 0.044),
            (Vector((-0.26, -0.18, 0.13)), Vector((-0.38, -0.24, 1.18)), 10, 0.62, 0.034),
        ]
        for l_idx, (root, cal_pos, n_arms, arm_len, r_stem) in enumerate(lilies):
            s_pts, s_rads, s_slots = [], [], []
            for i in range(15):
                t = i / 14
                bow = Vector((-0.10 * math.sin(t * math.pi) * (1 - 2 * l_idx), 0.07 * math.sin(t * math.pi * 1.3), 0.0))
                s_pts.append(root.lerp(cal_pos, t) + bow)
                nodal = 1.18 if i in (4, 8, 12) else 1.0
                s_rads.append(r_stem * (1.0 - 0.34 * t) * nodal)
                s_slots.append(0 if i % 2 == 0 else 1)
            bishop_tube('Articulated crinoid stalk', s_pts, s_rads, ring_slots=s_slots, sides=7)
            for c_k in range(8 if l_idx == 0 else 6):
                ca = c_k * tau / (8 if l_idx == 0 else 6) + l_idx
                p0 = s_pts[0] + Vector((0.0, 0.0, 0.05))
                p1 = p0 + Vector((0.16 * math.cos(ca), 0.16 * math.sin(ca), -0.02))
                p2 = p0 + Vector((0.28 * math.cos(ca + 0.2), 0.28 * math.sin(ca + 0.2), -0.11))
                bishop_tube('Basal grasping cirrus', [p0, p1, p2], [0.018, 0.012, 0.004], slot=5, sides=4)
            for node_i in ((4, 8, 12) if l_idx == 0 else (5, 10)):
                np_pt = s_pts[node_i]
                for cw in range(5):
                    ca = cw * tau / 5 + node_i * 0.7
                    c1 = np_pt + Vector((0.11 * math.cos(ca), 0.11 * math.sin(ca), -0.02))
                    c2 = np_pt + Vector((0.18 * math.cos(ca + 0.25), 0.18 * math.sin(ca + 0.25), -0.09))
                    bishop_tube('Nodal segmented cirrus', [np_pt, c1, c2], [0.013, 0.008, 0.003], slot=5, sides=4)
            bishop_tube('Pentagonal crinoid calyx',
                        [cal_pos - Vector((0, 0, 0.04)), cal_pos + Vector((0, 0, 0.05)), cal_pos + Vector((0, 0, 0.10))],
                        [r_stem * 0.85, r_stem * 1.95, r_stem * 1.55], slot=0, sides=10)
            crown_base = cal_pos + Vector((0, 0, 0.09))
            for j in range(n_arms):
                a = tau * j / n_arms + 0.18 * l_idx
                a_pts, a_rads, a_slots = [], [], []
                for s in range(9):
                    t = s / 8
                    az_c = a + 0.14 * math.sin(t * 2.8 + j)
                    reach = arm_len * (0.12 + 0.88 * (t ** 0.86))
                    lift = arm_len * (0.68 * math.sin(t * math.pi * 0.80) - 0.16 * (t ** 2.4))
                    a_pts.append(crown_base + Vector((reach * math.cos(az_c), reach * math.sin(az_c), lift)))
                    a_rads.append((0.024 - 0.004 * l_idx) * (1.0 - 0.78 * t))
                    a_slots.append(2 if s < 3 else (7 if s < 6 else 4))
                bishop_tube('Feathery crinoid arm', a_pts, a_rads, ring_slots=a_slots,
                            sides=4, tip_dome=True, tip_slot=4)
                lat_v = Vector((-math.sin(a), math.cos(a), 0.0))
                for p_i in range(1, 8):
                    tf = p_i / 8
                    p_len = arm_len * (0.19 * math.sin(tf * math.pi * 0.9 + 0.2))
                    for side_s in (-1, 1):
                        orig = a_pts[p_i]
                        tip_p = orig + lat_v * (side_s * p_len) + Vector((math.cos(a) * p_len * 0.35,
                                                                          math.sin(a) * p_len * 0.35, 0.045 * (1.0 - tf * 0.5)))
                        bishop_tube('Crinoid pinnule', [orig, tip_p], [0.0075, 0.002],
                                    slot=4 if p_i > 5 else 7, sides=3)

    def create_crystal_spire():
        matrix_layers = [
            (0.00, 0.96, 0.00, 0.00, 0.13),
            (0.28, 1.05, 0.04, -0.03, 0.15),
            (0.60, 0.88, -0.03, 0.04, 0.13),
            (0.85, 0.70, 0.02, -0.02, 0.10),
            (1.00, 0.46, 0.00, 0.00, 0.08),
        ]
        stratified_outcrop('Dark reef mineral matrix', (0.0, 0.0, 0.0), (1.36, 1.18, 0.72),
                           matrix_layers, sides=26, phase=0.6, flat_bottom=True,
                           wall_slots=(3, 5, 3, 6), top_slot=5, crevice_slot=3)
        stratified_outcrop('Secondary mineral shelf', (-0.64, -0.38, 0.0), (0.78, 0.66, 0.46),
                           matrix_layers, sides=18, phase=2.1, flat_bottom=True,
                           wall_slots=(3, 6, 5), top_slot=6, crevice_slot=3)

        def hex_quartz(x, y, z0, length, r_base, tilt_xy, rot_a, glow_core=False):
            axis = Vector((tilt_xy[0], tilt_xy[1], 1.0)).normalized()
            ref = Vector((0, 0, 1)) if abs(axis.z) < 0.92 else Vector((1, 0, 0))
            u_ax = (ref - axis * ref.dot(axis)).normalized()
            v_ax = axis.cross(u_ax).normalized()
            ca, sa = math.cos(rot_a), math.sin(rot_a)
            u_rot = u_ax * ca + v_ax * sa
            v_rot = -u_ax * sa + v_ax * ca
            origin = Vector((x, y, z0))
            stations = [(0.00, 0.90), (0.18, 1.02), (0.52, 0.98), (0.78, 0.94)]
            verts, uv, faces, slots = [], [], [], []
            for st_t, r_sc in stations:
                for j in range(6):
                    a = tau * j / 6
                    asym = 1.0 + 0.06 * (1 if j % 2 == 0 else -1)
                    rad = r_base * r_sc * asym
                    t_here = st_t + (0.035 if (st_t > 0.70 and j % 2 == 0) else 0.0)
                    pt = origin + axis * (length * t_here) + (u_rot * math.cos(a) + v_rot * math.sin(a)) * rad
                    verts.append(pt)
                    uv.append((j / 6, t_here))
            b_idx, apex_idx = len(verts), len(verts) + 1
            verts.append(origin)
            uv.append((0.5, 0.0))
            verts.append(origin + axis * length)
            uv.append((0.5, 1.0))
            for j in range(6):
                jn = (j + 1) % 6
                faces.append((b_idx, jn, j))
                slots.append(3)
            facet_cycle = (0, 1, 2, 7, 4 if glow_core else 0, 1)
            for si in range(len(stations) - 1):
                r0, r1 = si * 6, (si + 1) * 6
                for j in range(6):
                    jn = (j + 1) % 6
                    faces.append((r0 + j, r0 + jn, r1 + jn, r1 + j))
                    slots.append(5 if si == 0 and j % 2 else facet_cycle[j])
            sh_r = (len(stations) - 1) * 6
            for j in range(6):
                jn = (j + 1) % 6
                faces.append((sh_r + j, sh_r + jn, apex_idx))
                slots.append(4 if (glow_core and j % 2 == 0) else (1 if j % 2 == 0 else 7))
            api.mesh('Hexagonal aquamarine quartz prism', verts, faces, uv, face_slots=slots, smooth=False)

        spires = [
            (0.02, 0.04, 0.34, 5.16, 0.38, (0.02, 0.03), 0.15, True),
            (-0.42, -0.14, 0.32, 3.85, 0.29, (-0.22, -0.10), 0.72, True),
            (0.44, 0.18, 0.32, 4.05, 0.30, (0.21, 0.12), 1.35, True),
            (0.18, -0.44, 0.30, 3.15, 0.25, (0.14, -0.26), 2.05, False),
            (-0.34, 0.42, 0.30, 3.30, 0.26, (-0.20, 0.25), 2.68, True),
            (-0.78, 0.10, 0.26, 2.45, 0.22, (-0.38, 0.06), 0.40, False),
            (0.76, -0.18, 0.26, 2.55, 0.23, (0.38, -0.12), 1.12, False),
            (0.48, 0.56, 0.24, 2.15, 0.20, (0.28, 0.34), 1.88, False),
            (-0.62, -0.52, 0.22, 1.95, 0.19, (-0.34, -0.30), 2.44, False),
            (0.96, 0.28, 0.20, 1.55, 0.17, (0.46, 0.18), 0.95, False),
            (-0.98, -0.22, 0.20, 1.62, 0.18, (-0.48, -0.14), 1.62, False),
            (0.08, 0.78, 0.20, 1.68, 0.17, (0.06, 0.44), 2.25, False),
            (-0.12, -0.76, 0.20, 1.52, 0.16, (-0.08, -0.44), 2.90, False),
            (0.68, -0.62, 0.18, 1.18, 0.14, (0.42, -0.38), 0.55, False),
            (-0.56, 0.72, 0.18, 1.24, 0.15, (-0.34, 0.42), 1.45, False),
        ]
        for spec in spires:
            hex_quartz(*spec)

    def create_ruins():
        def fluted_column(name, cx, cy, z0, z1, r_base, r_top, n_flutes=16, rings=9, slot=0, flute_slot=1):
            segs = n_flutes * 2
            verts, uv, faces, slots = [(cx, cy, z0)], [(0.5, 0.0)], [], []
            for i in range(rings + 1):
                t = i / rings
                entasis = 1.0 + 0.035 * math.sin(t * math.pi * 0.85)
                r_nom = (r_base * (1.0 - t) + r_top * t) * entasis
                for j in range(segs):
                    a = tau * j / segs
                    in_flute = (j % 2 == 1) and (0 < i < rings)
                    rr = r_nom * (0.915 if in_flute else 1.0)
                    verts.append((cx + rr * math.cos(a), cy + rr * math.sin(a), z0 + (z1 - z0) * t))
                    uv.append((j / segs, t))
            top_c = len(verts)
            verts.append((cx, cy, z1))
            uv.append((0.5, 1.0))
            for j in range(segs):
                jn = (j + 1) % segs
                faces.append((0, 1 + jn, 1 + j))
                slots.append(slot)
            for i in range(rings):
                r0, r1 = 1 + i * segs, 1 + (i + 1) * segs
                for j in range(segs):
                    jn = (j + 1) % segs
                    faces.append((r0 + j, r0 + jn, r1 + jn, r1 + j))
                    slots.append(flute_slot if j % 2 == 0 else slot)
            tr = 1 + rings * segs
            for j in range(segs):
                jn = (j + 1) % segs
                faces.append((tr + j, tr + jn, top_c))
                slots.append(flute_slot)
            return api.mesh(name, verts, faces, uv, face_slots=slots, smooth=True)

        def fluted_pilaster(name, cx, y_face, y_dir, z0, z1, width, depth, n_flutes=4):
            nx = n_flutes * 2 + 1
            nz = 6
            verts, uv, faces, slots = [], [], [], []
            y_back = y_face - y_dir * 0.02
            for iz in range(nz + 1):
                tz = iz / nz
                z = z0 + (z1 - z0) * tz
                for ix in range(nx):
                    tx = ix / (nx - 1)
                    x = cx + (tx - 0.5) * width
                    flute = (ix % 2 == 1) and (0 < iz < nz)
                    y_out = y_face + y_dir * (depth * (0.58 if flute else 1.0))
                    verts.append((x, y_out, z))
                    uv.append((tx, tz))
                verts.append((cx + 0.5 * width, y_back, z))
                uv.append((1.0, tz))
                verts.append((cx - 0.5 * width, y_back, z))
                uv.append((0.0, tz))
            ring_n = nx + 2
            b_c, t_c = len(verts), len(verts) + 1
            verts.extend([(cx, y_face, z0), (cx, y_face, z1)])
            uv.extend([(0.5, 0.0), (0.5, 1.0)])
            for j in range(ring_n):
                jn = (j + 1) % ring_n
                faces.append((b_c, jn, j) if y_dir < 0 else (b_c, j, jn))
                slots.append(1)
            for iz in range(nz):
                r0, r1 = iz * ring_n, (iz + 1) * ring_n
                for j in range(ring_n):
                    jn = (j + 1) % ring_n
                    q = (r0 + j, r0 + jn, r1 + jn, r1 + j)
                    faces.append(q if y_dir < 0 else tuple(reversed(q)))
                    slots.append(0 if (j < nx - 1 and j % 2 == 1) else 1)
            tr = nz * ring_n
            for j in range(ring_n):
                jn = (j + 1) % ring_n
                faces.append((tr + j, tr + jn, t_c) if y_dir < 0 else (tr + jn, tr + j, t_c))
                slots.append(1)
            return api.mesh(name, verts, faces, uv, face_slots=slots, smooth=False)

        def chamfered_voussoir(name, r_in, r_out, a0, a1, y_half, z_c, slot_main=0, slot_bevel=1, ch=0.022):
            am = 0.5 * (a0 + a1)
            rm = 0.5 * (r_in + r_out)
            ring_defs = [
                (-y_half, r_in + ch, r_out - ch, a0 + 0.004, a1 - 0.004),
                (-y_half + ch, r_in, r_out, a0, a1),
                (y_half - ch, r_in, r_out, a0, a1),
                (y_half, r_in + ch, r_out - ch, a0 + 0.004, a1 - 0.004),
            ]
            verts, uv, faces, slots = [], [], [], []
            for yy, ri, ro, aa0, aa1 in ring_defs:
                for rr, aa, u_c, v_c in ((ri, aa0, 0, 0), (ro, aa0, 0, 1), (ro, aa1, 1, 1), (ri, aa1, 1, 0)):
                    verts.append((rr * math.cos(aa), yy, z_c + rr * math.sin(aa)))
                    uv.append((u_c, v_c))
            faces.append((0, 3, 2, 1))
            slots.append(slot_main)
            faces.append((12, 13, 14, 15))
            slots.append(slot_main)
            for layer in range(3):
                b0, b1 = layer * 4, (layer + 1) * 4
                for j in range(4):
                    jn = (j + 1) % 4
                    faces.append((b0 + j, b0 + jn, b1 + jn, b1 + j))
                    slots.append(slot_main if layer == 1 else slot_bevel)
            return api.mesh(name, verts, faces, uv, face_slots=slots, smooth=False)

        def compass_star_ray(name, center, dir_xz, length, half_w, half_y, slot=2):
            c = Vector(center)
            d = Vector((dir_xz[0], 0.0, dir_xz[1])).normalized()
            p_lat = Vector((-d.z, 0.0, d.x))
            p_y = Vector((0.0, 1.0, 0.0))
            base = c
            mid = c + d * (length * 0.24)
            tip = c + d * length
            verts = [
                base,
                mid + p_lat * half_w,
                mid + p_y * half_y,
                mid - p_lat * half_w,
                mid - p_y * half_y,
                tip,
            ]
            uv = [(0.5, 0.0), (1.0, 0.3), (0.5, 0.3), (0.0, 0.3), (0.5, 0.3), (0.5, 1.0)]
            faces = [
                (0, 2, 1), (0, 3, 2), (0, 4, 3), (0, 1, 4),
                (1, 2, 5), (2, 3, 5), (3, 4, 5), (4, 1, 5),
            ]
            return api.mesh(name, verts, faces, uv, slot=slot, smooth=False)

        z_spring = 2.52
        oc_z = 5.06
        oc_r_in, oc_r_out = 0.75, 0.94
        encrust_layers = [
            (0.00, 0.98, 0.00, 0.00, 0.14),
            (0.45, 1.04, 0.04, -0.03, 0.15),
            (0.85, 0.78, -0.03, 0.02, 0.11),
            (1.00, 0.52, 0.00, 0.00, 0.08),
        ]
        for sign in (-1, 1):
            px = sign * 2.54
            api.box('Monumental pier base plinth', (px, 0.0, 0.14), (1.28, 1.80, 0.28), 6, bevel=0.035)
            api.box('Pier stepped socle', (px, 0.0, 0.39), (1.14, 1.56, 0.24), 0, bevel=0.030)
            api.box('Pier moulded dado base', (px, 0.0, 0.58), (1.04, 1.38, 0.16), 1, bevel=0.024)
            stratified_outcrop('Reef encrusted plinth ledge', (px - sign * 0.42, -0.44, 0.0),
                               (0.46, 0.42, 0.34), encrust_layers, sides=14, phase=1.2 + sign,
                               flat_bottom=True, wall_slots=(6, 7, 3), top_slot=6, crevice_slot=3)
            for c_idx in range(4):
                cz = 0.89 + c_idx * 0.44
                off_x = 0.014 * math.sin(c_idx * 2.1 + sign)
                api.box('Weathered pier ashlar course', (px + off_x, 0.0, cz),
                        (0.96, 1.24, 0.42), 0 if c_idx % 2 == 0 else 1, bevel=0.026)
            fluted_pilaster('Inner jamb pilaster', px - sign * 0.46, 0.0, -sign, 0.66, 2.48, 0.04, 0.03, n_flutes=3)
            for y_s in (-1, 1):
                yf = y_s * 0.62
                for pil_x in (-0.34, 0.34):
                    fluted_pilaster('Pier facade fluted pilaster', px + pil_x, yf, y_s,
                                    0.68, 2.46, 0.19, 0.048, n_flutes=4)
                    api.box('Pilaster attic base', (px + pil_x, yf + y_s * 0.026, 0.69), (0.23, 0.065, 0.07), 1, bevel=0.01)
                    api.box('Pilaster echinus capital', (px + pil_x, yf + y_s * 0.028, 2.45), (0.24, 0.070, 0.08), 1, bevel=0.01)
                med_z = 1.54
                api.ring('Pier stone oculus moulding', (px, yf + y_s * 0.018, med_z),
                         0.35, 0.35, 0.034, 1, plane='XZ', segments=28, sides=8)
                api.ellipsoid('Pier sunken slate tympanum', (px, yf + y_s * 0.004, med_z),
                              (0.33, 0.016, 0.33), 3, segments=24, rings=8)
                api.ring('Pier outer brass seal ring', (px, yf + y_s * 0.034, med_z),
                         0.30, 0.30, 0.016, 2, plane='XZ', segments=28, sides=6)
                api.ring('Pier inner brass seal ring', (px, yf + y_s * 0.036, med_z),
                         0.17, 0.17, 0.012, 5, plane='XZ', segments=24, sides=6)
                ecc_z = med_z - 0.19 * sign
                api.ring('Pier eccentric orbital ring', (px, yf + y_s * 0.040, ecc_z),
                         0.072, 0.072, 0.009, 2, plane='XZ', segments=18, sides=5)
                compass_star_ray('Pier meridian spear N', (px, yf + y_s * 0.042, med_z),
                                 (0.0, 1.0), 0.64, 0.024, 0.016, slot=2)
                compass_star_ray('Pier meridian spear S', (px, yf + y_s * 0.042, med_z),
                                 (0.0, -1.0), 0.64, 0.024, 0.016, slot=2)
                compass_star_ray('Pier equinox bar E', (px, yf + y_s * 0.042, med_z),
                                 (1.0, 0.0), 0.34, 0.020, 0.014, slot=2)
                compass_star_ray('Pier equinox bar W', (px, yf + y_s * 0.042, med_z),
                                 (-1.0, 0.0), 0.34, 0.020, 0.014, slot=2)
                for d_ang in (0.785, 2.356, 3.927, 5.498):
                    compass_star_ray('Pier diagonal needle', (px, yf + y_s * 0.038, med_z),
                                     (math.cos(d_ang), math.sin(d_ang)), 0.25, 0.014, 0.010, slot=5)
                api.ellipsoid('Pier compass sun boss', (px, yf + y_s * 0.048, med_z),
                              (0.058, 0.028, 0.058), 4, segments=14, rings=6)
            api.box('Impost architrave band', (px, 0.0, 2.56), (1.10, 1.36, 0.11), 1, bevel=0.018)
            for dx_i in range(-3, 4):
                for y_s in (-1, 1):
                    api.box('Impost cornice dentil', (px + dx_i * 0.15, y_s * 0.69, 2.65),
                            (0.08, 0.05, 0.07), 0, bevel=0.008)
            api.box('Projecting impost cornice', (px, 0.0, 2.75), (1.24, 1.50, 0.13), 1, bevel=0.024)
            api.box('Impost brass fillet', (px, 0.0, 2.615), (1.13, 1.39, 0.024), 2)
            pylon_x = px + sign * 0.10
            pylon_courses = [
                (3.04, 0.84, 1.06, 0.44, 0.0, 0),
                (3.48, 0.80, 1.00, 0.44, sign * 0.02, 1),
                (3.92, 0.76, 0.94, 0.44, sign * 0.03, 0),
                (4.36, 0.70, 0.88, 0.42, sign * 0.05, 6),
            ]
            for pz_c, pw, pd, ph, pox, p_sl in pylon_courses:
                api.box('Towering pier buttress pylon', (pylon_x + pox, 0.0, pz_c),
                        (pw, pd, ph), p_sl, bevel=0.025)
            for y_s in (-1, 1):
                api.box('Pylon recessed channel', (pylon_x + sign * 0.02, y_s * 0.49, 3.68),
                        (0.24, 0.04, 1.38), 3, bevel=0.008)
                api.box('Pylon brass vertical strip', (pylon_x + sign * 0.02, y_s * 0.505, 3.68),
                        (0.045, 0.02, 1.28), 5)
            frag_h = 5.26 if sign > 0 else 5.08
            api.box('Fractured pylon summit block A', (pylon_x + sign * 0.14, -0.10, 4.76),
                    (0.46, 0.62, 0.42), 1, bevel=0.022)
            api.box('Fractured pylon summit spire', (pylon_x + sign * 0.20, 0.08, frag_h - 0.18),
                    (0.30, 0.44, 0.38), 0, bevel=0.020)
            wing_cx = sign * 3.56
            api.box('Colonnade wing footing', (wing_cx, 0.0, 0.12), (1.17, 1.18, 0.24), 6, bevel=0.028)
            api.box('Colonnade stylobate step', (wing_cx, 0.0, 0.32), (1.06, 1.02, 0.18), 0, bevel=0.022)
            col_x = sign * 3.68
            api.box('Column Attic plinth', (col_x, 0.0, 0.46), (0.56, 0.56, 0.10), 1, bevel=0.015)
            api.ring('Column lower torus', (col_x, 0.0, 0.54), 0.23, 0.23, 0.038, 1, plane='XY', segments=24, sides=8)
            api.ring('Column upper torus', (col_x, 0.0, 0.60), 0.20, 0.20, 0.028, 0, plane='XY', segments=24, sides=7)
            fluted_column('Classical colonnade shaft', col_x, 0.0, 0.62, 2.20, 0.205, 0.175,
                          n_flutes=16, rings=8, slot=0, flute_slot=1)
            api.ring('Column necking astragal', (col_x, 0.0, 2.21), 0.185, 0.185, 0.024, 2, plane='XY', segments=24, sides=6)
            api.ellipsoid('Column Doric echinus', (col_x, 0.0, 2.27), (0.25, 0.25, 0.065), 1, segments=24, rings=8)
            api.box('Column square abacus', (col_x, 0.0, 2.35), (0.52, 0.52, 0.09), 1, bevel=0.014)
            api.box('Wing stone architrave beam', (sign * 3.50, 0.0, 2.48), (1.08, 0.68, 0.18), 0, bevel=0.020)
            api.box('Wing carved frieze course', (sign * 3.44, 0.0, 2.64), (0.96, 0.64, 0.15), 1, bevel=0.018)
            api.box('Wing frieze brass inlay', (sign * 3.44, 0.0, 2.64), (0.92, 0.67, 0.032), 2)
            api.box('Broken wing cornice inner', (sign * 3.36, 0.0, 2.78), (0.82, 0.78, 0.13), 1, bevel=0.020)
            api.box('Broken wing cornice outer fragment', (sign * 3.88, 0.04 * sign, 2.75),
                    (0.36, 0.66, 0.11), 6, bevel=0.018)
            stratified_outcrop('Fallen colonnade rubble', (sign * 3.92, 0.36, 0.0),
                               (0.22, 0.26, 0.26), encrust_layers, sides=12, phase=2.8 - sign,
                               flat_bottom=True, wall_slots=(0, 6, 7), top_slot=1, crevice_slot=3)

        n_inner = 26
        for i in range(n_inner):
            a0 = i * math.pi / n_inner + 0.005
            a1 = (i + 1) * math.pi / n_inner - 0.005
            am = 0.5 * (a0 + a1)
            in_oculus = abs(am - math.pi * 0.5) < 0.295
            r_outer_v = 2.29 if in_oculus else 2.52
            chamfered_voussoir('Inner archivolt voussoir', 2.06, r_outer_v, a0, a1, 0.52, z_spring,
                               slot_main=0 if i % 2 else 1, slot_bevel=1, ch=0.020)
            if not in_oculus and i % 2 == 0:
                rc = 2.045
                cx_s, cz_s = rc * math.cos(am), z_spring + rc * math.sin(am)
                api.box('Arch soffit coffer rib', (cx_s, 0.0, cz_s), (0.06, 0.88, 0.06), 3, bevel=0.008)

        n_outer = 30
        for i in range(n_outer):
            a0 = i * math.pi / n_outer + 0.004
            a1 = (i + 1) * math.pi / n_outer - 0.004
            am = 0.5 * (a0 + a1)
            if abs(am - math.pi * 0.5) < 0.285:
                chamfered_voussoir('Upper oculus hood voussoir', 3.48, 3.66, a0, a1, 0.48,
                                   z_spring - 0.18, slot_main=1, slot_bevel=0, ch=0.018)
                continue
            chamfered_voussoir('Outer archivolt voussoir', 2.53, 3.06, a0, a1, 0.57, z_spring,
                               slot_main=1 if i % 3 == 0 else 0, slot_bevel=1, ch=0.022)
            chamfered_voussoir('Arch extrados hood moulding', 3.06, 3.20, a0 - 0.002, a1 + 0.002,
                               0.62, z_spring, slot_main=1, slot_bevel=0, ch=0.016)
            if i in (4, 8, 21, 25):
                rm = 2.79
                mx, mz = rm * math.cos(am), z_spring + rm * math.sin(am)
                for y_s in (-1, 1):
                    api.ring('Archivolt celestial relief boss', (mx, y_s * 0.585, mz),
                             0.11, 0.11, 0.014, 2, plane='XZ', segments=18, sides=5)
                    api.ellipsoid('Archivolt relief center', (mx, y_s * 0.588, mz),
                                  (0.045, 0.020, 0.045), 5, segments=10, rings=5)

        for side_arc in ((0.03, math.pi * 0.5 - 0.295), (math.pi * 0.5 + 0.295, math.pi - 0.03)):
            for r_inlay, y_off, rad_t in ((2.22, 0.535, 0.018), (2.53, 0.582, 0.020), (3.04, 0.592, 0.022)):
                for y_s in (-1, 1):
                    pts_arc = [
                        (r_inlay * math.cos( side_arc[0] + (side_arc[1] - side_arc[0]) * (k / 18) ),
                         y_s * y_off,
                         z_spring + r_inlay * math.sin( side_arc[0] + (side_arc[1] - side_arc[0]) * (k / 18) ))
                        for k in range(19)
                    ]
                    bishop_tube('Concentric gilded arch inlay', pts_arc, [rad_t] * 19, slot=2, sides=5)

        n_oc = 28
        for i in range(n_oc):
            a0 = i * tau / n_oc + 0.006
            a1 = (i + 1) * tau / n_oc - 0.006
            chamfered_voussoir('Keystone oculus stone ring', oc_r_in, oc_r_out, a0, a1, 0.56, oc_z,
                               slot_main=1 if i % 2 == 0 else 0, slot_bevel=1, ch=0.018)
        for y_s in (-1, 1):
            api.ring('Oculus gilded outer bezel', (0.0, y_s * 0.565, oc_z),
                     0.91, 0.91, 0.020, 2, plane='XZ', segments=40, sides=6)
            api.ring('Oculus gilded inner bezel', (0.0, y_s * 0.565, oc_z),
                     0.77, 0.77, 0.018, 2, plane='XZ', segments=36, sides=6)
        api.box('Keystone crown clasp', (0.0, 0.0, oc_z + 0.96), (0.34, 1.20, 0.24), 1, bevel=0.022)
        api.box('Keystone lower clasp', (0.0, 0.0, oc_z - 0.92), (0.32, 1.16, 0.20), 1, bevel=0.020)

        api.ring('Compass outer graduated brass wheel', (0.0, 0.0, oc_z),
                 0.72, 0.72, 0.036, 2, plane='XZ', segments=48, sides=8)
        api.ring('Compass middle astrolabe ring', (0.0, 0.0, oc_z),
                 0.50, 0.50, 0.026, 2, plane='XZ', segments=40, sides=8)
        api.ring('Compass inner solar ring', (0.0, 0.0, oc_z),
                 0.24, 0.24, 0.022, 5, plane='XZ', segments=28, sides=7)
        for t_i in range(32):
            ta = t_i * tau / 32
            r_t0 = 0.65 if t_i % 4 == 0 else 0.68
            p_a = Vector((r_t0 * math.cos(ta), 0.0, oc_z + r_t0 * math.sin(ta)))
            p_b = Vector((0.74 * math.cos(ta), 0.0, oc_z + 0.74 * math.sin(ta)))
            bishop_tube('Graduated degree tick', [p_a, p_b], [0.014, 0.012],
                        slot=2 if t_i % 2 == 0 else 5, sides=4, smooth=False)
        for i in range(8):
            a = i * tau / 8
            is_zenith = (i == 2)
            ray_len = 1.151 if is_zenith else (0.90 if i % 2 == 0 else 0.79)
            compass_star_ray('Primary compass star ray', (0.0, 0.0, oc_z),
                             (math.cos(a), math.sin(a)), ray_len,
                             0.068 if i % 2 == 0 else 0.052, 0.056, slot=2)
            a_sec = a + tau / 16
            compass_star_ray('Secondary compass point', (0.0, 0.0, oc_z),
                             (math.cos(a_sec), math.sin(a_sec)), 0.58, 0.034, 0.032, slot=5)
        for f_i in range(16):
            fa = f_i * tau / 16
            compass_star_ray('Solar corona petal', (0.0, 0.0, oc_z),
                             (math.cos(fa), math.sin(fa)), 0.28, 0.026, 0.042,
                             slot=4 if f_i % 2 == 0 else 2)
        api.ellipsoid('Sculpted central sun boss', (0.0, 0.0, oc_z),
                      (0.165, 0.095, 0.165), 2, segments=24, rings=12)
        for y_s in (-1, 1):
            api.ellipsoid('Radiant solar medallion face', (0.0, y_s * 0.078, oc_z),
                          (0.115, 0.032, 0.115), 4, segments=18, rings=8)

    for name in ('rock', 'kelp', 'coral', 'staghorn_coral', 'table_coral',
                 'tube_coral', 'barrel_sponge', 'anemone', 'sea_fan', 'tubeworms',
                 'starfish_urchin', 'brain_coral', 'giant_clam', 'sea_lily',
                 'crystal_spire', 'ruins'):
        setattr(api, 'create_' + name, locals()['create_' + name])
