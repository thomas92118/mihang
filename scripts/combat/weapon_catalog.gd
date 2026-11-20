extends RefCounted

const CombatTypes = preload("res://scripts/combat/combat_types.gd")

const MAX_WEAPON_TIER := 5
const TIER_DAMAGE_STEP := 0.14
const TIER_POISE_STEP := 0.10

const WEAPON_ORDER: Array[String] = [
	"knife",
	"axe",
	"harpoon",
	"sonar_cannon",
	"sonic",
	"marker_gun",
]

const WEAPONS := {
	"knife": {
		"id": "knife",
		"name": "高频热能战术刀",
		"short_name": "战术刀",
		"category": "melee_light",
		"desc": "轻近战 4 连段高速压制，重击旋流回旋斩叠加裂伤。",
		"range": 4.8,
		"combo_steps": 4,
		"combo_multipliers": [1.0, 1.12, 1.24, 1.55],
		"base_damage": 22.0,
		"heavy_damage": 42.0,
		"poise_damage": 16.0,
		"heavy_poise_damage": 34.0,
		"attack_interval": 0.26,
		"heavy_charge_time": 0.55,
		"crit_chance": 0.16,
		"crit_mult": 1.65,
		"armor_pierce": 0.15,
		"status_type": CombatTypes.STATUS_RUPTURE,
		"status_amount": 18.0,
		"heavy_status_amount": 46.0,
		"heavy_name": "旋流回旋斩",
		"heavy_desc": "360° 旋流斩击，对周围目标叠加高额裂伤。",
		"weapon_art": {
			"id": "dark_current_dash",
			"name": "暗流瞬步斩",
			"cooldown": 8.0,
			"range": 12.0,
			"dash_distance": 12.0,
			"damage_mult": 2.15,
			"poise_damage": 48.0,
			"status_type": CombatTypes.STATUS_RUPTURE,
			"status_amount": 65.0,
			"armor_pierce": 0.35,
			"desc": "穿刺 12m 瞬间突进斩击并施加高额裂伤。",
		},
		"star_bias": 2,
		"loot_bonus": 0.0,
		"non_lethal_stun": false,
		"uses_heat": false,
		"heat_per_shot": 0.0,
		"weakpoint_zero_heat": false,
		"supports_ads": false,
		"craft_cost": {},
	},
	"axe": {
		"id": "axe",
		"name": "深渊破拆重斧",
		"short_name": "破拆重斧",
		"category": "melee_heavy",
		"desc": "重近战 3 连段超高削韧，素材掉落 +30%。",
		"range": 5.8,
		"combo_steps": 3,
		"combo_multipliers": [1.0, 1.25, 1.68],
		"base_damage": 46.0,
		"heavy_damage": 86.0,
		"poise_damage": 42.0,
		"heavy_poise_damage": 82.0,
		"attack_interval": 0.62,
		"heavy_charge_time": 0.85,
		"crit_chance": 0.12,
		"crit_mult": 1.70,
		"armor_pierce": 0.30,
		"status_type": CombatTypes.STATUS_RUPTURE,
		"status_amount": 24.0,
		"heavy_status_amount": 52.0,
		"heavy_name": "断流裂海劈",
		"heavy_desc": "蓄力纵劈破除重甲并造成巨额削韧。",
		"weapon_art": {
			"id": "vortex_quake_slam",
			"name": "涡压震荡砸",
			"cooldown": 11.0,
			"range": 10.0,
			"aoe_radius": 10.0,
			"damage_mult": 2.25,
			"poise_damage": 95.0,
			"status_type": CombatTypes.STATUS_RUPTURE,
			"status_amount": 55.0,
			"armor_pierce": 0.45,
			"desc": "以 10m 球形水压冲击波震碎护甲与韧性。",
		},
		"star_bias": 1,
		"loot_bonus": 0.30,
		"non_lethal_stun": false,
		"uses_heat": false,
		"heat_per_shot": 0.0,
		"weakpoint_zero_heat": false,
		"supports_ads": false,
		"craft_cost": {"titanium": 2, "copper": 1},
	},
	"harpoon": {
		"id": "harpoon",
		"name": "潮汐电磁鱼叉枪",
		"short_name": "电磁鱼叉",
		"category": "ranged_harpoon",
		"desc": "38m 电磁矛矢叠感电，重击锚定钩锁拉鱼或牵引飞向巨兽。",
		"range": 38.0,
		"combo_steps": 1,
		"combo_multipliers": [1.0],
		"base_damage": 32.0,
		"heavy_damage": 48.0,
		"poise_damage": 24.0,
		"heavy_poise_damage": 44.0,
		"attack_interval": 0.54,
		"heavy_charge_time": 0.75,
		"crit_chance": 0.14,
		"crit_mult": 1.60,
		"armor_pierce": 0.20,
		"status_type": CombatTypes.STATUS_ELECTRO,
		"status_amount": 32.0,
		"heavy_status_amount": 58.0,
		"heavy_name": "锚定钩锁",
		"heavy_desc": "小型目标拉近活捕，巨兽则反向牵引自身飞向弱点。",
		"weapon_art": {
			"id": "volt_net_burst",
			"name": "高压电网爆发",
			"cooldown": 10.0,
			"range": 28.0,
			"aoe_radius": 12.0,
			"chain_targets": 4,
			"damage_mult": 1.85,
			"poise_damage": 52.0,
			"status_type": CombatTypes.STATUS_ELECTRO,
			"status_amount": 85.0,
			"paralyze_duration": 2.5,
			"armor_pierce": 0.25,
			"desc": "链式感电爆发并麻痹范围目标 2.5s。",
		},
		"star_bias": 2,
		"loot_bonus": 0.0,
		"non_lethal_stun": false,
		"uses_heat": false,
		"heat_per_shot": 0.0,
		"weakpoint_zero_heat": false,
		"supports_ads": true,
		"craft_cost": {"titanium": 2, "copper": 2, "creature_tooth": 1},
	},
	"sonar_cannon": {
		"id": "sonar_cannon",
		"name": "声呐共鸣冲击炮",
		"short_name": "声呐冲击炮",
		"category": "ranged_cone",
		"desc": "22m 锥形声波破甲且震晕不伤鱼体，专精三星活捕与破盾。",
		"range": 22.0,
		"cone_angle_deg": 42.0,
		"combo_steps": 1,
		"combo_multipliers": [1.0],
		"base_damage": 26.0,
		"heavy_damage": 40.0,
		"poise_damage": 38.0,
		"heavy_poise_damage": 65.0,
		"attack_interval": 0.68,
		"heavy_charge_time": 0.85,
		"crit_chance": 0.08,
		"crit_mult": 1.45,
		"armor_pierce": 0.65,
		"status_type": CombatTypes.STATUS_RESONANCE,
		"status_amount": 42.0,
		"heavy_status_amount": 78.0,
		"heavy_name": "聚焦声压震晕",
		"heavy_desc": "高密度聚焦声波震晕目标且保留鱼体完整。",
		"weapon_art": {
			"id": "echolocation_pulse",
			"name": "回声定位震爆",
			"cooldown": 12.0,
			"range": 35.0,
			"aoe_radius": 35.0,
			"damage_mult": 1.40,
			"poise_damage": 64.0,
			"status_type": CombatTypes.STATUS_RESONANCE,
			"status_amount": 100.0,
			"expose_weakpoint_duration": 8.0,
			"armor_pierce": 1.0,
			"desc": "35m 全向声呐脉冲，暴露弱点并施加破甲易伤。",
		},
		"star_bias": 3,
		"loot_bonus": 0.0,
		"non_lethal_stun": true,
		"uses_heat": false,
		"heat_per_shot": 0.0,
		"weakpoint_zero_heat": false,
		"supports_ads": false,
		"craft_cost": {"titanium": 2, "quartz": 2, "chitin": 1},
	},
	"sonic": {
		"id": "sonic",
		"name": "蓝光静滞步枪",
		"short_name": "蓝光步枪",
		"category": "ranged_rifle",
		"desc": "支持 T/Y 远距开镜，短按精准脉冲（弱点零增热），长按 1.8s 发射满层静滞球。",
		"range": 65.0,
		"combo_steps": 1,
		"combo_multipliers": [1.0],
		"base_damage": 34.0,
		"heavy_damage": 62.0,
		"poise_damage": 22.0,
		"heavy_poise_damage": 56.0,
		"attack_interval": 0.36,
		"heavy_charge_time": 1.8,
		"crit_chance": 0.18,
		"crit_mult": 1.75,
		"armor_pierce": 0.25,
		"status_type": CombatTypes.STATUS_STASIS,
		"status_amount": 24.0,
		"heavy_status_amount": 100.0,
		"heavy_name": "满层静滞球",
		"heavy_desc": "蓄力 1.8s 发射静滞力场球，直接叠满静滞异常。",
		"weapon_art": {
			"id": "zero_prism_refract",
			"name": "零度晶棱折射",
			"cooldown": 12.0,
			"range": 65.0,
			"damage_mult": 2.30,
			"poise_damage": 68.0,
			"status_type": CombatTypes.STATUS_STASIS,
			"status_amount": 100.0,
			"clear_heat": true,
			"detonate_stasis": true,
			"armor_pierce": 0.55,
			"desc": "立即清零过热并射出穿透冰晶光束，引爆静滞目标。",
		},
		"star_bias": 3,
		"loot_bonus": 0.0,
		"non_lethal_stun": false,
		"uses_heat": true,
		"heat_per_shot": 18.0,
		"weakpoint_zero_heat": true,
		"supports_ads": true,
		"craft_cost": {"titanium": 2, "quartz": 2, "copper": 1},
	},
	"marker_gun": {
		"id": "marker_gun",
		"name": "深渊晶核指挥杖",
		"short_name": "晶核指挥杖",
		"category": "ranged_command",
		"desc": "发射追踪生物光弹刷新标记，重击切换「集火狂攻 / 活捕压血(留 20% HP)」指令。",
		"range": 52.0,
		"combo_steps": 1,
		"combo_multipliers": [1.0],
		"base_damage": 18.0,
		"heavy_damage": 0.0,
		"poise_damage": 14.0,
		"heavy_poise_damage": 18.0,
		"attack_interval": 0.42,
		"heavy_charge_time": 0.35,
		"crit_chance": 0.10,
		"crit_mult": 1.50,
		"armor_pierce": 0.20,
		"status_type": CombatTypes.STATUS_RESONANCE,
		"status_amount": 22.0,
		"heavy_status_amount": 0.0,
		"heavy_name": "切换契约指令",
		"heavy_desc": "切换战宠「集火狂攻」与「活捕压血(留 20% HP)」模式。",
		"weapon_art": {
			"id": "herd_tide_horn",
			"name": "兽群潮汐号角",
			"cooldown": 14.0,
			"range": 48.0,
			"damage_mult": 1.60,
			"poise_damage": 45.0,
			"status_type": CombatTypes.STATUS_RESONANCE,
			"status_amount": 50.0,
			"pet_buff_duration": 6.0,
			"pet_lifesteal": 0.25,
			"pet_hyper_armor": true,
			"armor_pierce": 0.25,
			"desc": "全宠协同冲锋并获得 6s 霸体与 25% 吸血。",
		},
		"star_bias": 3,
		"loot_bonus": 0.0,
		"non_lethal_stun": false,
		"uses_heat": false,
		"heat_per_shot": 0.0,
		"weakpoint_zero_heat": false,
		"supports_ads": false,
		"craft_cost": {"titanium": 1, "copper": 1},
	},
}

const MOD_ORDER: Array[String] = [
	"serrated_edge",
	"superconduct_optic",
	"cavitation_valve",
	"bio_battery_mod",
	"cryo_core",
	"acoustic_chamber",
	"anesthetic_coat",
	"hydro_fins",
]

const MODS := {
	"serrated_edge": {
		"id": "serrated_edge",
		"name": "锯齿骨刃模组",
		"desc": "伤害 +16%，裂伤积蓄 +30%，穿甲 +10%。",
		"craft_cost": {"creature_tooth": 2, "titanium": 1},
		"damage_mult": 1.16,
		"status_type_bonus": CombatTypes.STATUS_RUPTURE,
		"status_mult": 1.30,
		"armor_pierce_add": 0.10,
	},
	"superconduct_optic": {
		"id": "superconduct_optic",
		"name": "超导瞄准棱镜",
		"desc": "暴击率 +10%，暴伤 +25%，感电积蓄 +25%。",
		"craft_cost": {"quartz": 2, "copper": 2},
		"crit_chance_add": 0.10,
		"crit_mult_add": 0.25,
		"status_type_bonus": CombatTypes.STATUS_ELECTRO,
		"status_mult": 1.25,
	},
	"cavitation_valve": {
		"id": "cavitation_valve",
		"name": "空化增压阀",
		"desc": "削韧 +28%，攻击间隔缩短 10%。",
		"craft_cost": {"titanium": 2, "shark_fragment": 1},
		"poise_mult": 1.28,
		"attack_interval_mult": 0.90,
	},
	"bio_battery_mod": {
		"id": "bio_battery_mod",
		"name": "生物高能电容",
		"desc": "蓝光枪单发热耗 -25%，战技冷却缩短 15%。",
		"craft_cost": {"fish_meat": 2, "copper": 2},
		"heat_mult": 0.75,
		"art_cooldown_mult": 0.85,
	},
	"cryo_core": {
		"id": "cryo_core",
		"name": "深寒晶核模组",
		"desc": "静滞积蓄 +30%，重击伤害 +14%。",
		"craft_cost": {"quartz": 2, "abyss_fragment": 1},
		"heavy_damage_mult": 1.14,
		"status_type_bonus": CombatTypes.STATUS_STASIS,
		"status_mult": 1.30,
	},
	"acoustic_chamber": {
		"id": "acoustic_chamber",
		"name": "共鸣扩音腔",
		"desc": "声波积蓄 +30%，射程 +18%，穿甲 +15%。",
		"craft_cost": {"chitin": 2, "quartz": 1},
		"range_mult": 1.18,
		"armor_pierce_add": 0.15,
		"status_type_bonus": CombatTypes.STATUS_RESONANCE,
		"status_mult": 1.30,
	},
	"anesthetic_coat": {
		"id": "anesthetic_coat",
		"name": "麻醉活捕涂层",
		"desc": "致命一击改为留 1 HP 并震晕 3s，渔获星级倾向提升至 ★★★。",
		"craft_cost": {"kelp": 3, "creature_skin": 1},
		"non_lethal_stun": true,
		"star_bias_override": 3,
	},
	"hydro_fins": {
		"id": "hydro_fins",
		"name": "流体稳流翼片",
		"desc": "攻击间隔缩短 12%，射程 +15%，暴击率 +8%。",
		"craft_cost": {"titanium": 1, "kelp": 2, "creature_skin": 1},
		"attack_interval_mult": 0.88,
		"range_mult": 1.15,
		"crit_chance_add": 0.08,
	},
}


static func get_weapon(weapon_id: String) -> Dictionary:
	var key := weapon_id if WEAPONS.has(weapon_id) else "knife"
	return (WEAPONS[key] as Dictionary).duplicate(true)


static func get_all_weapons() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for wid in WEAPON_ORDER:
		result.append(get_weapon(wid))
	return result


static func get_mod(mod_id: String) -> Dictionary:
	if not MODS.has(mod_id):
		return {}
	return (MODS[mod_id] as Dictionary).duplicate(true)


static func get_all_mods() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for mid in MOD_ORDER:
		result.append(get_mod(mid))
	return result


static func get_tier_multiplier(tier: int) -> float:
	var clamped := clampi(tier, 1, MAX_WEAPON_TIER)
	return 1.0 + float(clamped - 1) * TIER_DAMAGE_STEP


static func get_tier_poise_multiplier(tier: int) -> float:
	var clamped := clampi(tier, 1, MAX_WEAPON_TIER)
	return 1.0 + float(clamped - 1) * TIER_POISE_STEP


static func get_upgrade_cost(weapon_id: String, next_tier: int) -> Dictionary:
	if next_tier <= 1 or next_tier > MAX_WEAPON_TIER:
		return {}
	var wid := weapon_id if WEAPONS.has(weapon_id) else "knife"
	var step := next_tier - 1
	var cost: Dictionary = {
		"titanium": step + 1,
		"copper": step,
	}
	match wid:
		"knife", "axe":
			cost["creature_tooth"] = step
			if next_tier >= 3:
				cost["shark_fragment"] = next_tier - 2
			if next_tier >= 5:
				cost["abyss_fragment"] = 1
		"harpoon":
			cost["copper"] = step + 1
			cost["creature_tooth"] = maxi(1, step - 1)
			if next_tier >= 3:
				cost["shark_fragment"] = next_tier - 2
			if next_tier >= 4:
				cost["abyss_fragment"] = next_tier - 3
		"sonar_cannon", "marker_gun":
			cost["quartz"] = step
			cost["chitin"] = maxi(1, step - 1)
			if next_tier >= 4:
				cost["abyss_fragment"] = next_tier - 3
		"sonic":
			cost["quartz"] = step + 1
			if next_tier >= 3:
				cost["abyss_fragment"] = next_tier - 2
	return cost


static func compute_weapon_stats(
	weapon_id: String,
	tier: int = 1,
	equipped_mods: Array = [],
	global_attack_bonus: float = 0.0
) -> Dictionary:
	var base := get_weapon(weapon_id)
	var clamped_tier := clampi(tier, 1, MAX_WEAPON_TIER)
	var dmg_tier_mult := get_tier_multiplier(clamped_tier)
	var poise_tier_mult := get_tier_poise_multiplier(clamped_tier)

	var dmg_mult := 1.0
	var heavy_dmg_mult := 1.0
	var poise_mult := 1.0
	var status_mult := 1.0
	var crit_chance_add := 0.0
	var crit_mult_add := 0.0
	var armor_pierce_add := 0.0
	var interval_mult := 1.0
	var range_mult := 1.0
	var heat_mult := 1.0
	var art_cd_mult := 1.0
	var non_lethal_stun := bool(base.get("non_lethal_stun", false))
	var star_bias := int(base.get("star_bias", 2))
	var valid_mods: Array[String] = []

	var weapon_status := String(base.get("status_type", ""))
	for raw_mod in equipped_mods:
		var mid := String(raw_mod)
		if not MODS.has(mid) or valid_mods.has(mid):
			continue
		valid_mods.append(mid)
		var mod: Dictionary = MODS[mid]
		dmg_mult *= float(mod.get("damage_mult", 1.0))
		heavy_dmg_mult *= float(mod.get("heavy_damage_mult", 1.0))
		poise_mult *= float(mod.get("poise_mult", 1.0))
		crit_chance_add += float(mod.get("crit_chance_add", 0.0))
		crit_mult_add += float(mod.get("crit_mult_add", 0.0))
		armor_pierce_add += float(mod.get("armor_pierce_add", 0.0))
		interval_mult *= float(mod.get("attack_interval_mult", 1.0))
		range_mult *= float(mod.get("range_mult", 1.0))
		heat_mult *= float(mod.get("heat_mult", 1.0))
		art_cd_mult *= float(mod.get("art_cooldown_mult", 1.0))
		if mod.has("status_mult"):
			var bonus_type := String(mod.get("status_type_bonus", ""))
			if bonus_type == "" or bonus_type == weapon_status:
				status_mult *= float(mod.get("status_mult", 1.0))
			else:
				status_mult *= 1.0 + (float(mod.get("status_mult", 1.0)) - 1.0) * 0.4
		if bool(mod.get("non_lethal_stun", false)):
			non_lethal_stun = true
		if mod.has("star_bias_override"):
			star_bias = maxi(star_bias, int(mod.get("star_bias_override", star_bias)))

	var bonus_attack := maxf(0.0, global_attack_bonus)
	var final_damage := (float(base.get("base_damage", 20.0)) + bonus_attack) * dmg_tier_mult * dmg_mult
	var base_heavy := float(base.get("heavy_damage", 0.0))
	var final_heavy_damage := 0.0
	if base_heavy > 0.0:
		final_heavy_damage = (base_heavy + bonus_attack * 1.35) * dmg_tier_mult * dmg_mult * heavy_dmg_mult

	var final_poise := float(base.get("poise_damage", 16.0)) * poise_tier_mult * poise_mult
	var final_heavy_poise := float(base.get("heavy_poise_damage", 32.0)) * poise_tier_mult * poise_mult
	var final_status := float(base.get("status_amount", 0.0)) * status_mult
	var final_heavy_status := float(base.get("heavy_status_amount", 0.0)) * status_mult

	var art: Dictionary = (base.get("weapon_art", {}) as Dictionary).duplicate(true)
	var art_cd := maxf(2.0, float(art.get("cooldown", 10.0)) * art_cd_mult)
	var art_dmg := final_damage * float(art.get("damage_mult", 1.8))
	var art_poise := float(art.get("poise_damage", 45.0)) * poise_tier_mult * poise_mult
	var art_status := float(art.get("status_amount", 50.0)) * status_mult
	art["cooldown"] = art_cd
	art["computed_damage"] = art_dmg
	art["computed_poise_damage"] = art_poise
	art["computed_status_amount"] = art_status

	return {
		"id": String(base["id"]),
		"name": String(base["name"]),
		"short_name": String(base["short_name"]),
		"category": String(base["category"]),
		"tier": clamped_tier,
		"tier_multiplier": dmg_tier_mult,
		"tier_poise_multiplier": poise_tier_mult,
		"equipped_mods": valid_mods,
		"damage": final_damage,
		"heavy_damage": final_heavy_damage,
		"poise_damage": final_poise,
		"heavy_poise_damage": final_heavy_poise,
		"status_type": weapon_status,
		"status_amount": final_status,
		"heavy_status_amount": final_heavy_status,
		"crit_chance": clampf(float(base.get("crit_chance", 0.1)) + crit_chance_add, 0.0, 0.95),
		"crit_mult": maxf(1.2, float(base.get("crit_mult", 1.5)) + crit_mult_add),
		"armor_pierce": clampf(float(base.get("armor_pierce", 0.0)) + armor_pierce_add, 0.0, 1.0),
		"range": float(base.get("range", 5.0)) * range_mult,
		"attack_interval": maxf(0.14, float(base.get("attack_interval", 0.4)) * interval_mult),
		"heavy_charge_time": float(base.get("heavy_charge_time", 0.7)),
		"combo_steps": int(base.get("combo_steps", 1)),
		"combo_multipliers": base.get("combo_multipliers", [1.0]),
		"uses_heat": bool(base.get("uses_heat", false)),
		"heat_per_shot": float(base.get("heat_per_shot", 0.0)) * heat_mult,
		"weakpoint_zero_heat": bool(base.get("weakpoint_zero_heat", false)),
		"supports_ads": bool(base.get("supports_ads", false)),
		"non_lethal_stun": non_lethal_stun,
		"star_bias": star_bias,
		"loot_bonus": float(base.get("loot_bonus", 0.0)),
		"heavy_name": String(base.get("heavy_name", "")),
		"weapon_art": art,
		"weapon_art_cooldown": art_cd,
		"weapon_art_cooldown_mult": art_cd_mult,
		"weapon_art_damage": art_dmg,
		"weapon_art_poise": art_poise,
		"weapon_art_status_amount": art_status,
	}
