extends RefCounted

const CombatTypes = preload("res://scripts/combat/combat_types.gd")
const CharacterRoster = preload("res://scripts/presentation/character_roster.gd")

const BRANCH_HUNTER := "hunter"
const BRANCH_CAPTURE := "capture"
const BRANCH_COMMANDER := "commander"

const TACTICAL_ORDER: Array[String] = [
	"hydro_grapple",
	"blood_surge",
	"stasis_beacon",
	"sonar_net",
	"symbiosis_shield",
	"pack_domain",
]

const TACTICAL_SKILLS := {
	"hydro_grapple": {
		"id": "hydro_grapple",
		"name": "水压喷射锁链",
		"branch": BRANCH_HUNTER,
		"branch_name": "猎杀系",
		"cooldown": 10.0,
		"oxygen_cost": 0.0,
		"range": 30.0,
		"damage": 38.0,
		"poise_damage": 48.0,
		"status_type": CombatTypes.STATUS_ELECTRO,
		"status_amount": 42.0,
		"pull_small_targets": true,
		"zip_to_boss": true,
		"desc": "喷射高压锚链，拉近小型猎物或快速牵引至巨兽身侧并施加感电。",
	},
	"blood_surge": {
		"id": "blood_surge",
		"name": "血涌过载",
		"branch": BRANCH_HUNTER,
		"branch_name": "猎杀系",
		"cooldown": 16.0,
		"oxygen_cost": 15.0,
		"heal_pct": 0.35,
		"buff_duration": 8.0,
		"lifesteal": 0.25,
		"status_type": CombatTypes.STATUS_RUPTURE,
		"bonus_status_amount": 26.0,
		"desc": "消耗 15s 氧气立即回复 35% 生命，并在 8s 内附带裂伤与 25% 攻击吸血。",
	},
	"stasis_beacon": {
		"id": "stasis_beacon",
		"name": "深海静滞信标",
		"branch": BRANCH_CAPTURE,
		"branch_name": "活捕系",
		"cooldown": 15.0,
		"oxygen_cost": 0.0,
		"duration": 8.0,
		"radius": 11.0,
		"slow_ratio": 0.55,
		"status_type": CombatTypes.STATUS_STASIS,
		"status_per_sec": 28.0,
		"desc": "投掷持续 8s 的静滞信标，大范围减速敌群并持续叠加静滞异常。",
	},
	"sonar_net": {
		"id": "sonar_net",
		"name": "声波麻醉网",
		"branch": BRANCH_CAPTURE,
		"branch_name": "活捕系",
		"cooldown": 13.0,
		"oxygen_cost": 0.0,
		"range": 24.0,
		"width": 10.0,
		"damage": 24.0,
		"poise_damage": 72.0,
		"stun_duration": 4.0,
		"non_lethal_stun": true,
		"interrupt_boss": true,
		"status_type": CombatTypes.STATUS_RESONANCE,
		"status_amount": 65.0,
		"star_bias": 3,
		"desc": "发射 10m 宽声波麻醉网，无伤震晕鱼群活捕或强行打断领主蓄力。",
	},
	"symbiosis_shield": {
		"id": "symbiosis_shield",
		"name": "契约共生护盾",
		"branch": BRANCH_COMMANDER,
		"branch_name": "御兽系",
		"cooldown": 16.0,
		"oxygen_cost": 0.0,
		"duration": 7.0,
		"shield_amount": 55.0,
		"shield_energy_restore": 45.0,
		"pet_shield_pct": 0.35,
		"desc": "为自身与所有出战战宠套上共生护盾，并立即恢复 45 点护盾电容。",
	},
	"pack_domain": {
		"id": "pack_domain",
		"name": "合击领域标记",
		"branch": BRANCH_COMMANDER,
		"branch_name": "御兽系",
		"cooldown": 15.0,
		"oxygen_cost": 0.0,
		"radius": 14.0,
		"duration": 9.0,
		"pet_crit_bonus": 0.35,
		"pet_damage_mult": 1.25,
		"pet_status_mult": 1.60,
		"desc": "展开 14m 合击领域，大幅提升领域内战宠的暴击率与异常积累。",
	},
}

const ULTIMATE_ORDER: Array[String] = [
	"mermaid_tide_domain",
	"diver_orbital_sonar",
	"sub_torpedo_barrage",
]

const ULTIMATES := {
	"mermaid_tide_domain": {
		"id": "mermaid_tide_domain",
		"name": "沧溟潮汐领域",
		"context": "mermaid",
		"flux_cost": 100.0,
		"radius": 24.0,
		"duration": 8.0,
		"burst_damage": 120.0,
		"tick_damage": 26.0,
		"poise_damage": 110.0,
		"status_type": CombatTypes.STATUS_STASIS,
		"status_amount": 100.0,
		"secondary_status_type": CombatTypes.STATUS_RESONANCE,
		"secondary_status_amount": 75.0,
		"heal_pct": 0.25,
		"shield_energy_restore": 50.0,
		"desc": "唤起 24m 沧溟潮汐领域，卷束敌群叠加静滞与声波并回复自身与战宠生命。",
	},
	"diver_orbital_sonar": {
		"id": "diver_orbital_sonar",
		"name": "轨道声呐过载炮",
		"context": "diver",
		"flux_cost": 100.0,
		"range": 55.0,
		"beam_radius": 4.2,
		"burst_damage": 210.0,
		"poise_damage": 145.0,
		"armor_pierce": 1.0,
		"status_type": CombatTypes.STATUS_RESONANCE,
		"status_amount": 100.0,
		"secondary_status_type": CombatTypes.STATUS_ELECTRO,
		"secondary_status_amount": 80.0,
		"desc": "发射 55m 穿透轨道声呐过载光束，完全无视护甲并造成超高削韧与感电。",
	},
	"sub_torpedo_barrage": {
		"id": "sub_torpedo_barrage",
		"name": "深渊齐射矩阵",
		"context": "submarine",
		"flux_cost": 100.0,
		"range": 68.0,
		"salvo_count": 8,
		"damage_per_torpedo": 64.0,
		"poise_per_torpedo": 36.0,
		"aoe_radius": 9.0,
		"status_type": CombatTypes.STATUS_ELECTRO,
		"status_amount": 45.0,
		"desc": "锁定周边目标齐射 8 枚声导鱼雷矩阵，造成大范围爆裂与链式感电。",
	},
}


static func get_tactical_skill(skill_id: String) -> Dictionary:
	var key := skill_id if TACTICAL_SKILLS.has(skill_id) else "hydro_grapple"
	return (TACTICAL_SKILLS[key] as Dictionary).duplicate(true)


static func get_all_tactical_skills() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for sid in TACTICAL_ORDER:
		result.append(get_tactical_skill(sid))
	return result


static func get_tactical_skills_by_branch(branch: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for sid in TACTICAL_ORDER:
		var skill: Dictionary = TACTICAL_SKILLS[sid]
		if String(skill.get("branch", "")) == branch:
			result.append(skill.duplicate(true))
	return result


static func get_ultimate(ultimate_id: String) -> Dictionary:
	var key := ultimate_id if ULTIMATES.has(ultimate_id) else "mermaid_tide_domain"
	return (ULTIMATES[key] as Dictionary).duplicate(true)


static func get_all_ultimates() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for uid in ULTIMATE_ORDER:
		result.append(get_ultimate(uid))
	return result


static func get_ultimate_for_context(character_id: String, in_submarine: bool) -> Dictionary:
	if in_submarine:
		return get_ultimate("sub_torpedo_barrage")
	var profile := CharacterRoster.get_profile(character_id)
	var is_mermaid := bool(profile.get("is_mermaid", true))
	if is_mermaid:
		return get_ultimate("mermaid_tide_domain")
	return get_ultimate("diver_orbital_sonar")
