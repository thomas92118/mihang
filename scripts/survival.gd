extends RefCounted

const WeaponCatalog = preload("res://scripts/combat/weapon_catalog.gd")
const SkillCatalog = preload("res://scripts/combat/skill_catalog.gd")

const RECIPES := {
	"tank": {"titanium": 2, "kelp": 2},
	"fins": {"titanium": 1, "kelp": 2},
	"axe": {"titanium": 2, "copper": 1},
	"harpoon": {"titanium": 2, "copper": 2, "creature_tooth": 1},
	"sonar_cannon": {"titanium": 2, "quartz": 2, "chitin": 1},
	"sonic": {"titanium": 2, "quartz": 2, "copper": 1},
	"beacon": {"titanium": 3, "copper": 2, "quartz": 2},
	"rebreather": {"titanium": 2, "copper": 1, "kelp": 2},
	"biomod_dash": {"shark_fragment": 1, "titanium": 2},
	"reinforced_suit": {"creature_skin": 2, "chitin": 1},
	"bio_battery": {"fish_meat": 2, "copper": 1},
	"serrated_blade": {"creature_tooth": 2, "titanium": 1},
	"reinforce_sharp": {"shark_fragment": 1, "titanium": 1},
	"reinforce_sonic": {"abyss_fragment": 1, "quartz": 1}
	,"abyssal_escape_engine": {"mother_tree_essence": 1, "ancient_star_core": 1, "tree_seed": 1}
	,"marker_gun": {"titanium": 1, "copper": 1}
}

const RECIPE_NAMES := {
	"tank": "高容量氧气瓶",
	"fins": "动力脚蹼",
	"rebreather": "深海循环呼吸器",
	"axe": "破拆战斧",
	"harpoon": "潮汐电磁鱼叉枪",
	"sonar_cannon": "声呐共鸣冲击炮",
	"sonic": "蓝光静滞枪",
	"biomod_dash": "生体模组·涡流突进",
	"beacon": "求救信标",
	"reinforced_suit": "海兽绝缘潜航服",
	"bio_battery": "生物高能电池",
	"serrated_blade": "深海锯齿骨刃",
	"reinforce_sharp": "深铸·锋锐硬化",
	"reinforce_sonic": "深铸·晶体共鸣"
	,"abyssal_escape_engine": "深海跃迁逃逸器 (终极逃生舰)"
	,"marker_gun": "深渊晶核指挥杖 (御兽指令)"
}

const MAX_EQUIPPED_WEAPONS := 3
const MAX_WEAPON_MODS := 2
const MAX_DEPLOYED_PETS := 3

const WEAPON_ROLE_LABELS := {
	"knife": "轻近战 · 4连裂伤",
	"axe": "重近战 · 破甲削韧",
	"harpoon": "中距电磁 · 钩锁",
	"sonar_cannon": "锥形声呐 · 活捕",
	"sonic": "远距开镜 · 静滞",
	"marker_gun": "御兽指挥 · 标记",
}

const MOD_CATEGORY_LABELS := {
	"serrated_edge": "伤害 · 裂伤",
	"superconduct_optic": "暴击 · 感电",
	"cavitation_valve": "削韧 · 攻速",
	"bio_battery_mod": "散热 · 冷却",
	"cryo_core": "重击 · 静滞",
	"acoustic_chamber": "射程 · 穿甲",
	"anesthetic_coat": "活捕 · 三星",
	"hydro_fins": "攻速 · 射程",
}

const ITEM_WEIGHTS := {
	"titanium": 0.8,
	"copper": 0.8,
	"quartz": 0.7,
	"kelp": 0.4,
	"fish_small": 0.5,
	"fish_meat": 1.2,
	"creature_skin": 1.4,
	"creature_tooth": 0.9,
	"chitin": 1.1,
	"shark_fragment": 1.6,
	"abyss_fragment": 1.8
}

const MARINCA_SPECIES := {
	"fish_small": "发光小金鱼",
	"school_fish": "荧光幻梭鱼",
	"fish": "浅海热带鱼",
	"predator": "巡弋暗礁鲨",
	"abyss": "深渊鮟鱇巨兽",
	"sea_wolf": "幽影海狼",
	"sea_spider": "八足海蜘蛛",
	"seal": "斑纹海豹",
	"sea_turtle": "深海绿海龟",
	"manta_ray": "巨型鬼蝠鲼",
	"squid": "深渊发光巨乌贼",
	"crab": "底栖巨螯蟹",
	"boss": "深渊传奇领主"
}

const SUSHI_RECIPES := {
	"goldfish_nigiri": {
		"name": "荧光金鱼握寿司",
		"cost": {"fish_small": 1},
		"cost_text": "1 鲜活小金鱼",
		"price": 65,
		"desc": "售出获 65 金币 · 主厨品尝恢复 35 生命/30 氧气，氧气上限永久 +10s"
	},
	"kelp_roll": {
		"name": "深海海藻鲜肉卷",
		"cost": {"fish_meat": 2, "kelp": 1},
		"cost_text": "2 海兽生肉 + 1 海藻",
		"price": 150,
		"desc": "售出获 150 金币 · 生命上限永久 +20 并立即回满生命"
	},
	"shark_sashimi": {
		"name": "暗礁巨鲨厚切刺身",
		"cost": {"fish_meat": 2, "creature_tooth": 1},
		"cost_text": "2 海兽生肉 + 1 骨齿",
		"price": 260,
		"desc": "售出获 260 金币 · 激发猎食潜能，全武器攻击力永久 +18"
	},
	"abyss_kaiseki": {
		"name": "深渊海王黄金怀石",
		"cost": {"fish_meat": 3, "creature_skin": 1, "chitin": 1},
		"cost_text": "3 海兽生肉 + 1 兽皮 + 1 甲壳",
		"price": 420,
		"desc": "售出获 420 金币 · 全武器攻击 +30、无人机配额 +1、负重上限 +15kg"
	}
}

const COBRA_SHOP_ITEMS := {
	"cargo_box": {
		"name": "柯布拉扩容生态箱",
		"price": 120,
		"desc": "负重上限永久 +25 kg · 无人机打捞配额上限 +1 并补满"
	},
	"oxygen_capsule": {
		"name": "高能浓缩氧气胶囊",
		"price": 80,
		"desc": "氧气瓶上限永久 +25 秒 · 立即补满当前氧气与生命"
	},
	"duff_coating": {
		"name": "达夫特制超导涂层",
		"price": 180,
		"desc": "达夫军工武器强化 · 全武器攻击力永久 +25 (强化等级 +1)"
	}
}

const MAP_WORLD_HALF := 900.0
const MAP_WORLD_SPAN := 1800.0
const SURVEY_GRID_SIZE := 24

const EXPLORER_RANKS := [
	"浅礁见习潜航员",
	"蓝洞生态勘测员",
	"远洋深潜开拓者",
	"沧溟深渊领航官",
	"星海传奇探索家"
]

var mode: String = "survival"
var selected_character: String = "coral_mermaid"
var inventory: Dictionary = {
	"titanium": 0, "copper": 0, "quartz": 0, "kelp": 0, "fish_small": 0,
	"shark_fragment": 0, "abyss_fragment": 0
	,"fish_meat": 0, "creature_skin": 0, "creature_tooth": 0, "chitin": 0
	,"mother_tree_essence": 0, "ancient_star_core": 0, "tree_seed": 0
}
var weapons: Array[String] = ["knife"]
var unlocked_tools: Dictionary = {
	"knife": true,
	"axe": false,
	"harpoon": false,
	"sonar_cannon": false,
	"sonic": false,
	"marker_gun": false,
}
var equipped_weapons: Array[String] = ["knife"]
var weapon_tiers: Dictionary = {
	"knife": 1,
	"axe": 1,
	"harpoon": 1,
	"sonar_cannon": 1,
	"sonic": 1,
	"marker_gun": 1,
}
var unlocked_mods: Array[String] = ["serrated_edge", "anesthetic_coat"]
var weapon_mods: Dictionary = {}
var active_tactical_skill: String = "hydro_grapple"
var tamed_creatures: Array[Dictionary] = []
var deployed_pet_indices: Array[int] = []
var loadout_version: int = 1
var weapon_upgrade_level: int = 0
var weapon_attack_bonus: float = 0.0
var oxygen: float = 90.0
var max_oxygen: float = 90.0
var max_health: float = 100.0
var health: float = 100.0
var tank: bool = false
var fins: bool = false
var rebreather: bool = false
var biomod_dash: bool = false
var biomod_vision: bool = false
var black_box_read: bool = false
var pinned_recipe: String = "tank"
var reinforced_suit: bool = false
var bio_battery: bool = false
var rescued: bool = false
var boss_defeated: bool = false
var all_bosses_defeated: bool = false
var mother_tree_active: bool = false
var escape_crafted: bool = false
var tamed_beast_count: int = 0
var elapsed: float = 0.0
var landmarks_discovered: Array[String] = []
var gold: int = 0
var dishes_served: int = 0
var sushi_reputation: int = 1
var drone_charges: int = 3
var max_drone_charges: int = 3
var base_max_weight: float = 40.0
var cargo_upgrade_level: int = 0
var marinca_cards: Dictionary = {}
var surveyed_cells: Dictionary = {}
var unlocked_outposts: Array[String] = []
var collected_relics: Array[String] = []
var pinged_targets: Dictionary = {}
var has_custom_waypoint: bool = false
var custom_waypoint: Vector3 = Vector3.ZERO
var sonar_cooldown: float = 0.0
var fast_travel_count: int = 0
var explorer_speed_bonus: float = 0.0
var explorer_rank_level: int = 1

func set_mode(new_mode: String) -> void:
	mode = new_mode
	boss_defeated = false
	if mode == "explore":
		tank = true
		fins = true
		rebreather = true
		biomod_dash = true
		biomod_vision = true
		weapons = ["knife", "axe", "sonic"]
		unlocked_tools = _default_unlocked_tools(true)
		equipped_weapons = ["axe", "harpoon", "sonic"]
		weapon_tiers = _default_weapon_tiers(1)
		unlocked_mods = WeaponCatalog.MOD_ORDER.duplicate()
		weapon_mods = {}
		active_tactical_skill = SkillCatalog.TACTICAL_ORDER[0]
		deployed_pet_indices = []
		max_oxygen = 999.0
		oxygen = max_oxygen
		health = 100.0
		weapon_upgrade_level = 3
		weapon_attack_bonus = 40.0
		max_drone_charges = 99
		drone_charges = 99
		gold = 500
	else:
		mode = "survival"
		tank = false
		fins = false
		rebreather = false
		biomod_dash = false
		biomod_vision = false
		weapons = ["knife"]
		unlocked_tools = _default_unlocked_tools(false)
		equipped_weapons = ["knife"]
		weapon_tiers = _default_weapon_tiers(1)
		unlocked_mods = _default_survival_mods()
		weapon_mods = {}
		active_tactical_skill = SkillCatalog.TACTICAL_ORDER[0]
		deployed_pet_indices = []
		max_oxygen = 90.0
		oxygen = max_oxygen
		health = 100.0
		weapon_upgrade_level = 0
		weapon_attack_bonus = 0.0
		max_drone_charges = 3
		drone_charges = 3
	loadout_version += 1

func reset(mode_name: String = "survival") -> void:
	inventory = _default_inventory()
	landmarks_discovered.clear()
	unlocked_outposts.clear()
	collected_relics.clear()
	marinca_cards.clear()
	surveyed_cells.clear()
	pinged_targets.clear()
	tamed_creatures.clear()
	clear_custom_waypoint()
	max_health = 100.0
	reinforced_suit = false
	bio_battery = false
	rescued = false
	boss_defeated = false
	all_bosses_defeated = false
	mother_tree_active = false
	escape_crafted = false
	black_box_read = false
	pinned_recipe = "tank"
	tamed_beast_count = 0
	elapsed = 0.0
	gold = 0
	dishes_served = 0
	sushi_reputation = 1
	base_max_weight = 40.0
	cargo_upgrade_level = 0
	sonar_cooldown = 0.0
	fast_travel_count = 0
	explorer_speed_bonus = 0.0
	explorer_rank_level = 1
	set_mode(mode_name)

static func _default_unlocked_tools(unlock_all: bool = false) -> Dictionary:
	var result: Dictionary = {}
	for wid in WeaponCatalog.WEAPON_ORDER:
		result[wid] = true if (wid == "knife" or unlock_all) else false
	return result

static func _default_weapon_tiers(default_tier: int = 1) -> Dictionary:
	var clamped := clampi(default_tier, 1, WeaponCatalog.MAX_WEAPON_TIER)
	var result: Dictionary = {}
	for wid in WeaponCatalog.WEAPON_ORDER:
		result[wid] = clamped
	return result

static func _default_survival_mods() -> Array[String]:
	return ["serrated_edge", "anesthetic_coat"]

func _auto_equip_weapon_if_space(weapon_id: String) -> void:
	if not WeaponCatalog.WEAPONS.has(weapon_id):
		return
	if equipped_weapons.has(weapon_id):
		return
	if equipped_weapons.size() < MAX_EQUIPPED_WEAPONS:
		equipped_weapons.append(weapon_id)

func _unlock_weapon(weapon_id: String) -> bool:
	if not WeaponCatalog.WEAPONS.has(weapon_id):
		return false
	var was_owned := has_weapon(weapon_id)
	unlocked_tools[weapon_id] = true
	if not weapons.has(weapon_id):
		weapons.append(weapon_id)
	_auto_equip_weapon_if_space(weapon_id)
	if not was_owned:
		loadout_version += 1
	return not was_owned

func unlock_tool(tool_id: String) -> bool:
	if WeaponCatalog.WEAPONS.has(tool_id):
		return _unlock_weapon(tool_id)
	var already := bool(unlocked_tools.get(tool_id, false))
	unlocked_tools[tool_id] = true
	if not already:
		loadout_version += 1
	return not already

func has_weapon(weapon_id: String) -> bool:
	if weapon_id == "knife":
		return true
	return bool(unlocked_tools.get(weapon_id, false)) or weapons.has(weapon_id)

func get_owned_weapons() -> Array[String]:
	var owned: Array[String] = []
	for wid in WeaponCatalog.WEAPON_ORDER:
		if has_weapon(wid):
			owned.append(wid)
	return owned

func get_weapon_tier(weapon_id: String) -> int:
	return clampi(int(weapon_tiers.get(weapon_id, 1)), 1, WeaponCatalog.MAX_WEAPON_TIER)

func get_weapon_mods(weapon_id: String) -> Array[String]:
	var result: Array[String] = []
	var raw: Variant = weapon_mods.get(weapon_id, [])
	if raw is Array:
		for item in raw:
			var mid := str(item)
			if WeaponCatalog.MODS.has(mid) and not result.has(mid):
				result.append(mid)
				if result.size() >= MAX_WEAPON_MODS:
					break
	return result

func equip_weapon_to_slot(slot_idx: int, weapon_id: String) -> Dictionary:
	if slot_idx < 0 or slot_idx >= MAX_EQUIPPED_WEAPONS:
		return {
			"ok": false,
			"message": "无效武装槽位",
			"equipped_weapons": equipped_weapons.duplicate(),
		}
	if not WeaponCatalog.WEAPONS.has(weapon_id) or not has_weapon(weapon_id):
		return {
			"ok": false,
			"message": "尚未拥有该武器",
			"equipped_weapons": equipped_weapons.duplicate(),
		}
	var existing_idx := equipped_weapons.find(weapon_id)
	if existing_idx == slot_idx:
		return {
			"ok": true,
			"message": "该武器已位于槽位 %d" % (slot_idx + 1),
			"equipped_weapons": equipped_weapons.duplicate(),
		}
	if existing_idx >= 0:
		if slot_idx < equipped_weapons.size():
			var prev := equipped_weapons[slot_idx]
			equipped_weapons[slot_idx] = weapon_id
			equipped_weapons[existing_idx] = prev
		else:
			equipped_weapons.remove_at(existing_idx)
			equipped_weapons.append(weapon_id)
	elif slot_idx < equipped_weapons.size():
		equipped_weapons[slot_idx] = weapon_id
	else:
		equipped_weapons.append(weapon_id)
	loadout_version += 1
	var w_name := str(WeaponCatalog.get_weapon(weapon_id).get("short_name", weapon_id))
	var final_slot := equipped_weapons.find(weapon_id)
	return {
		"ok": true,
		"message": "已将 %s 装配至槽位 %d" % [w_name, final_slot + 1],
		"equipped_weapons": equipped_weapons.duplicate(),
	}

static func _split_upgrade_cost(weapon_id: String, next_tier: int) -> Dictionary:
	var raw_cost: Dictionary = WeaponCatalog.get_upgrade_cost(weapon_id, next_tier)
	var materials: Dictionary = {}
	var gold_cost: int = 0
	if raw_cost.has("materials") and raw_cost["materials"] is Dictionary:
		var raw_mats: Dictionary = raw_cost["materials"]
		for k in raw_mats:
			var req := int(raw_mats[k])
			if req > 0:
				materials[str(k)] = req
		gold_cost = maxi(0, int(raw_cost.get("gold", 0)))
	else:
		for k in raw_cost:
			var ks := str(k)
			var req := int(raw_cost[k])
			if req <= 0:
				continue
			if ks == "gold":
				gold_cost += req
			else:
				materials[ks] = req
	return {"materials": materials, "gold": gold_cost}

func _can_afford_upgrade(materials: Dictionary, gold_cost: int) -> bool:
	if gold < gold_cost:
		return false
	for kind in materials:
		if int(inventory.get(kind, 0)) < int(materials[kind]):
			return false
	return true

func upgrade_weapon_tier(weapon_id: String) -> Dictionary:
	if not WeaponCatalog.WEAPONS.has(weapon_id) or not has_weapon(weapon_id):
		return {"ok": false, "tier": get_weapon_tier(weapon_id), "message": "尚未拥有该武器"}
	var current_tier := get_weapon_tier(weapon_id)
	if current_tier >= WeaponCatalog.MAX_WEAPON_TIER:
		return {"ok": false, "tier": current_tier, "message": "该武器已达最高阶位 Lv.%d" % WeaponCatalog.MAX_WEAPON_TIER}
	var next_tier := current_tier + 1
	var cost_info := _split_upgrade_cost(weapon_id, next_tier)
	var materials: Dictionary = cost_info["materials"]
	var gold_cost: int = int(cost_info["gold"])
	if mode != "explore":
		if gold < gold_cost:
			return {"ok": false, "tier": current_tier, "message": "金币不足（需要 %d 金币）" % gold_cost}
		for kind in materials:
			if int(inventory.get(kind, 0)) < int(materials[kind]):
				return {"ok": false, "tier": current_tier, "message": "深铸材料不足"}
		gold -= gold_cost
		for kind in materials:
			inventory[kind] = int(inventory.get(kind, 0)) - int(materials[kind])
	weapon_tiers[weapon_id] = next_tier
	loadout_version += 1
	var w_name := str(WeaponCatalog.get_weapon(weapon_id).get("short_name", weapon_id))
	return {"ok": true, "tier": next_tier, "message": "%s 已深铸至 Lv.%d" % [w_name, next_tier]}

func toggle_weapon_mod(weapon_id: String, mod_id: String) -> Dictionary:
	if not WeaponCatalog.WEAPONS.has(weapon_id) or not has_weapon(weapon_id):
		return {"ok": false, "equipped": false, "mods": [], "message": "尚未拥有该武器"}
	if not WeaponCatalog.MODS.has(mod_id):
		return {"ok": false, "equipped": false, "mods": get_weapon_mods(weapon_id), "message": "未知战术模组"}
	if not unlocked_mods.has(mod_id):
		return {"ok": false, "equipped": false, "mods": get_weapon_mods(weapon_id), "message": "该模组尚未解锁"}
	var current_mods := get_weapon_mods(weapon_id)
	var mod_name := str((WeaponCatalog.MODS[mod_id] as Dictionary).get("name", mod_id))
	if current_mods.has(mod_id):
		current_mods.erase(mod_id)
		weapon_mods[weapon_id] = current_mods
		loadout_version += 1
		return {"ok": true, "equipped": false, "mods": current_mods.duplicate(), "message": "已卸下 %s" % mod_name}
	if current_mods.size() >= MAX_WEAPON_MODS:
		return {"ok": false, "equipped": false, "mods": current_mods.duplicate(), "message": "模组槽已满（最多 2 个）"}
	current_mods.append(mod_id)
	weapon_mods[weapon_id] = current_mods
	loadout_version += 1
	return {"ok": true, "equipped": true, "mods": current_mods.duplicate(), "message": "已装配 %s" % mod_name}

func unlock_mod(mod_id: String) -> bool:
	if not WeaponCatalog.MODS.has(mod_id):
		return false
	if unlocked_mods.has(mod_id):
		return false
	unlocked_mods.append(mod_id)
	loadout_version += 1
	return true

func set_active_tactical_skill(skill_id: String) -> Dictionary:
	if not SkillCatalog.TACTICAL_SKILLS.has(skill_id):
		return {"ok": false, "skill_id": active_tactical_skill, "message": "未知战术技能"}
	active_tactical_skill = skill_id
	loadout_version += 1
	var skill_name := str((SkillCatalog.TACTICAL_SKILLS[skill_id] as Dictionary).get("name", skill_id))
	return {"ok": true, "skill_id": active_tactical_skill, "message": "已装配战术技：%s" % skill_name}

func add_tamed_creature(entry: Dictionary) -> int:
	tamed_creatures.append(entry)
	tamed_beast_count = maxi(tamed_beast_count, tamed_creatures.size())
	sync_deployed_pets()
	loadout_version += 1
	return tamed_creatures.size() - 1

func sync_deployed_pets() -> void:
	var total := tamed_creatures.size()
	var cleaned: Array[int] = []
	for raw_idx in deployed_pet_indices:
		var idx := int(raw_idx)
		if idx >= 0 and idx < total and not cleaned.has(idx):
			cleaned.append(idx)
			if cleaned.size() >= MAX_DEPLOYED_PETS:
				break
	var target_count := mini(MAX_DEPLOYED_PETS, total)
	if total > 0 and cleaned.size() < target_count:
		for idx in range(total):
			if not cleaned.has(idx):
				cleaned.append(idx)
				if cleaned.size() >= target_count:
					break
	deployed_pet_indices = cleaned

func set_deployed_pet_indices(indices: Array) -> void:
	var limit := tamed_creatures.size() if not tamed_creatures.is_empty() else tamed_beast_count
	var cleaned: Array[int] = []
	for raw_idx in indices:
		if not (raw_idx is int or raw_idx is float):
			continue
		var idx := int(raw_idx)
		if idx < 0:
			continue
		if limit > 0 and idx >= limit:
			continue
		if limit == 0:
			continue
		if not cleaned.has(idx):
			cleaned.append(idx)
			if cleaned.size() >= MAX_DEPLOYED_PETS:
				break
	deployed_pet_indices = cleaned
	loadout_version += 1

func get_deployed_pets() -> Array[Dictionary]:
	sync_deployed_pets()
	var result: Array[Dictionary] = []
	for idx in deployed_pet_indices:
		if idx >= 0 and idx < tamed_creatures.size():
			result.append(tamed_creatures[idx])
	return result

func build_loadout_payload(character_id: String, in_submarine: bool) -> Dictionary:
	var owned := get_owned_weapons()
	var tiers_copy: Dictionary = {}
	var mods_copy: Dictionary = {}
	var weapons_catalog: Array[Dictionary] = []
	for base_w in WeaponCatalog.get_all_weapons():
		var wid := str(base_w.get("id", ""))
		var is_owned := has_weapon(wid)
		var tier := get_weapon_tier(wid)
		tiers_copy[wid] = tier
		mods_copy[wid] = get_weapon_mods(wid)
		var next_tier := tier + 1
		var mat_cost: Dictionary = {}
		var gold_cost: int = 0
		if tier < WeaponCatalog.MAX_WEAPON_TIER:
			var split_cost := _split_upgrade_cost(wid, next_tier)
			mat_cost = split_cost["materials"]
			gold_cost = int(split_cost["gold"])
		var entry := base_w.duplicate(true)
		entry["owned"] = is_owned
		entry["tier"] = tier
		entry["max_tier"] = WeaponCatalog.MAX_WEAPON_TIER
		entry["role"] = str(WEAPON_ROLE_LABELS.get(wid, entry.get("category", "")))
		entry["upgrade_cost"] = mat_cost
		entry["upgrade_gold"] = gold_cost
		entry["can_upgrade"] = is_owned and tier < WeaponCatalog.MAX_WEAPON_TIER and (mode == "explore" or _can_afford_upgrade(mat_cost, gold_cost))
		weapons_catalog.append(entry)

	var mods_catalog: Array[Dictionary] = []
	for base_m in WeaponCatalog.get_all_mods():
		var mid := str(base_m.get("id", ""))
		var m_entry := base_m.duplicate(true)
		m_entry["unlocked"] = unlocked_mods.has(mid)
		m_entry["category"] = str(MOD_CATEGORY_LABELS.get(mid, "通用"))
		mods_catalog.append(m_entry)

	var skills_catalog: Array[Dictionary] = []
	for base_s in SkillCatalog.get_all_tactical_skills():
		var s_entry := base_s.duplicate(true)
		s_entry["school"] = str(base_s.get("branch_name", base_s.get("branch", "战术")))
		skills_catalog.append(s_entry)

	return {
		"version": loadout_version,
		"mode": mode,
		"gold": gold,
		"inventory": inventory.duplicate(),
		"equipped_slots": equipped_weapons.duplicate(),
		"owned_weapons": owned,
		"weapon_tiers": tiers_copy,
		"weapon_mods": mods_copy,
		"unlocked_mods": unlocked_mods.duplicate(),
		"weapons_catalog": weapons_catalog,
		"mods_catalog": mods_catalog,
		"skills_catalog": skills_catalog,
		"active_tactical_skill": active_tactical_skill,
		"character_id": character_id,
		"ultimate_info": SkillCatalog.get_ultimate_for_context(character_id, in_submarine),
		"deployed_pet_indices": deployed_pet_indices.duplicate(),
	}

func discover_landmark(id: String) -> bool:
	if landmarks_discovered.has(id):
		return false
	landmarks_discovered.append(id)
	return true

func reveal_world_area(world_pos: Vector3, radius: float) -> int:
	var cell_span: float = MAP_WORLD_SPAN / float(SURVEY_GRID_SIZE)
	var gx_min: int = clampi(floori((world_pos.x - radius + MAP_WORLD_HALF) / cell_span), 0, SURVEY_GRID_SIZE - 1)
	var gx_max: int = clampi(floori((world_pos.x + radius + MAP_WORLD_HALF) / cell_span), 0, SURVEY_GRID_SIZE - 1)
	var gz_min: int = clampi(floori((world_pos.z - radius + MAP_WORLD_HALF) / cell_span), 0, SURVEY_GRID_SIZE - 1)
	var gz_max: int = clampi(floori((world_pos.z + radius + MAP_WORLD_HALF) / cell_span), 0, SURVEY_GRID_SIZE - 1)
	var newly_revealed: int = 0
	var r_sq: float = (radius + cell_span * 0.45) * (radius + cell_span * 0.45)
	for gz in range(gz_min, gz_max + 1):
		var cz: float = -MAP_WORLD_HALF + (float(gz) + 0.5) * cell_span
		for gx in range(gx_min, gx_max + 1):
			var cx: float = -MAP_WORLD_HALF + (float(gx) + 0.5) * cell_span
			var dx: float = cx - world_pos.x
			var dz: float = cz - world_pos.z
			if dx * dx + dz * dz <= r_sq:
				var key := "%d_%d" % [gx, gz]
				if not surveyed_cells.has(key):
					surveyed_cells[key] = true
					newly_revealed += 1
	return newly_revealed

func is_cell_surveyed(gx: int, gz: int) -> bool:
	return surveyed_cells.has("%d_%d" % [gx, gz])

func get_survey_ratio() -> float:
	var total_cells: float = float(SURVEY_GRID_SIZE * SURVEY_GRID_SIZE)
	return clampf(float(surveyed_cells.size()) / maxf(total_cells, 1.0), 0.0, 1.0)

func get_exploration_progress(total_landmarks: int = 24, total_outposts: int = 6, total_relics: int = 12) -> float:
	var map_part: float = clampf(get_survey_ratio() / 0.72, 0.0, 1.0) * 0.40
	var lm_part: float = clampf(float(landmarks_discovered.size()) / maxf(float(total_landmarks), 1.0), 0.0, 1.0) * 0.30
	var out_part: float = clampf(float(unlocked_outposts.size()) / maxf(float(total_outposts), 1.0), 0.0, 1.0) * 0.15
	var rel_part: float = clampf(float(collected_relics.size()) / maxf(float(total_relics), 1.0), 0.0, 1.0) * 0.15
	return clampf(map_part + lm_part + out_part + rel_part, 0.0, 1.0)

func get_explorer_rank_level(total_landmarks: int = 24, total_outposts: int = 6, total_relics: int = 12) -> int:
	var p: float = get_exploration_progress(total_landmarks, total_outposts, total_relics)
	if p >= 0.85:
		return 5
	elif p >= 0.60:
		return 4
	elif p >= 0.35:
		return 3
	elif p >= 0.15:
		return 2
	return 1

func get_explorer_rank(total_landmarks: int = 24, total_outposts: int = 6, total_relics: int = 12) -> String:
	var lv: int = get_explorer_rank_level(total_landmarks, total_outposts, total_relics)
	return EXPLORER_RANKS[clampi(lv - 1, 0, EXPLORER_RANKS.size() - 1)]

func set_custom_waypoint(pos: Vector3) -> void:
	has_custom_waypoint = true
	custom_waypoint = pos

func clear_custom_waypoint() -> void:
	has_custom_waypoint = false
	custom_waypoint = Vector3.ZERO

func unlock_outpost(outpost_id: String, outpost_name: String) -> Dictionary:
	if unlocked_outposts.has(outpost_id):
		return {"is_new": false, "name": outpost_name, "gold_reward": 0}
	unlocked_outposts.append(outpost_id)
	var gold_gain: int = 150
	gold += gold_gain
	if mode != "explore":
		max_oxygen += 15.0
		oxygen = max_oxygen
	health = max_health
	max_drone_charges += 1
	drone_charges = max_drone_charges
	return {
		"is_new": true,
		"id": outpost_id,
		"name": outpost_name,
		"gold_reward": gold_gain,
		"unlocked_count": unlocked_outposts.size()
	}

func collect_relic(relic_id: String, relic_name: String) -> Dictionary:
	if collected_relics.has(relic_id):
		return {"is_new": false, "name": relic_name}
	collected_relics.append(relic_id)
	var gold_gain: int = 120
	gold += gold_gain
	inventory["titanium"] = int(inventory.get("titanium", 0)) + 1
	inventory["copper"] = int(inventory.get("copper", 0)) + 1
	inventory["quartz"] = int(inventory.get("quartz", 0)) + 1
	weapon_attack_bonus += 10.0
	weapon_upgrade_level += 1
	explorer_speed_bonus = minf(0.48, explorer_speed_bonus + 0.04)
	return {
		"is_new": true,
		"id": relic_id,
		"name": relic_name,
		"gold_reward": gold_gain,
		"collected_count": collected_relics.size()
	}

func pin_recipe(recipe: String) -> void:
	if pinned_recipe == recipe:
		pinned_recipe = ""
	else:
		pinned_recipe = recipe

func get_pinned_info() -> Dictionary:
	if pinned_recipe.is_empty() or not RECIPES.has(pinned_recipe):
		return {}
	var cost: Dictionary = RECIPES[pinned_recipe]
	var details: Array[Dictionary] = []
	var all_ready: bool = true
	var item_names := {
		"titanium": "钛", "copper": "铜", "quartz": "石英", "kelp": "海藻",
		"fish_small": "小鱼", "shark_fragment": "鲨齿", "abyss_fragment": "晶核"
		,"fish_meat": "生肉", "creature_skin": "兽皮", "creature_tooth": "生物利齿", "chitin": "甲壳"
		,"mother_tree_essence": "生命精华", "ancient_star_core": "星核源石", "tree_seed": "启迪之种"
	}
	for kind in cost:
		var req: int = int(cost[kind])
		var cur: int = int(inventory.get(kind, 0))
		if cur < req:
			all_ready = false
		details.append({
			"kind": kind,
			"name": item_names.get(kind, kind),
			"current": cur,
			"required": req,
			"ready": cur >= req
		})
	return {
		"recipe": pinned_recipe,
		"name": RECIPE_NAMES.get(pinned_recipe, pinned_recipe),
		"details": details,
		"all_ready": all_ready
	}

func collect(kind: String) -> bool:
	if not inventory.has(kind):
		return false
	inventory[kind] += 1
	return true

func collect_fragment(kind: String) -> Dictionary:
	if not inventory.has(kind):
		inventory[kind] = 0
	inventory[kind] += 1
	var bonus: float = 12.0 if kind == "shark_fragment" else 25.0
	weapon_attack_bonus += bonus
	weapon_upgrade_level += 1
	if kind == "shark_fragment":
		biomod_dash = true
	else:
		biomod_vision = true
	var name_str: String = "巨鲨齿骨碎片" if kind == "shark_fragment" else "深渊巨兽晶核"
	return {
		"kind": kind,
		"name": name_str,
		"bonus": bonus,
		"total_bonus": weapon_attack_bonus,
		"level": weapon_upgrade_level
	}

func eat_fish() -> Dictionary:
	var hp_gain: float = 25.0
	var oxy_gain: float = 20.0
	health = minf(max_health, health + hp_gain)
	if mode != "explore":
		oxygen = minf(max_oxygen, oxygen + oxy_gain)
	inventory["fish_small"] += 1
	return {"health_gain": hp_gain, "oxygen_gain": oxy_gain}

func get_current_weight() -> float:
	var total: float = 0.0
	for kind in inventory:
		var cnt: int = int(inventory.get(kind, 0))
		if cnt > 0 and ITEM_WEIGHTS.has(kind):
			total += float(cnt) * float(ITEM_WEIGHTS[kind])
	return snappedf(total, 0.1)

func get_max_weight() -> float:
	if mode == "explore":
		return 999.0
	var bonus: float = (10.0 if fins else 0.0) + (15.0 if reinforced_suit else 0.0) + float(cargo_upgrade_level) * 25.0
	return base_max_weight + bonus

func is_overweight() -> bool:
	if mode == "explore":
		return false
	return get_current_weight() > get_max_weight()

func get_three_star_count() -> int:
	var cnt: int = 0
	for k in marinca_cards:
		if int(marinca_cards[k].get("stars", 0)) >= 3:
			cnt += 1
	return cnt

func register_marinca_catch(kind: String, creature_name: String, stars: int) -> Dictionary:
	var clamped_stars: int = clampi(stars, 1, 3)
	var species_key: String = kind
	if kind.begins_with("boss") or kind == "water_dragon":
		species_key = "boss"
	elif not MARINCA_SPECIES.has(species_key):
		species_key = "fish"
	var display_name: String = creature_name if not creature_name.is_empty() else str(MARINCA_SPECIES.get(species_key, "海洋生物"))
	var is_new: bool = not marinca_cards.has(species_key)
	var old_stars: int = int(marinca_cards[species_key].get("stars", 0)) if not is_new else 0
	var old_count: int = int(marinca_cards[species_key].get("count", 0)) if not is_new else 0
	var best_stars: int = maxi(old_stars, clamped_stars)
	var upgraded: bool = (not is_new) and (clamped_stars > old_stars)
	marinca_cards[species_key] = {
		"name": display_name,
		"stars": best_stars,
		"count": old_count + 1
	}
	var reward_gold: int = 0
	if is_new:
		reward_gold = 35 * clamped_stars
	elif upgraded:
		reward_gold = 25 * (clamped_stars - old_stars)
	else:
		reward_gold = 12 * clamped_stars
	gold += reward_gold
	sushi_reputation = 1 + int(marinca_cards.size() / 3) + int(get_three_star_count() / 2)
	return {
		"species": species_key,
		"name": display_name,
		"stars": clamped_stars,
		"best_stars": best_stars,
		"count": old_count + 1,
		"is_new": is_new,
		"upgraded": upgraded,
		"reward_gold": reward_gold,
		"total_unlocked": marinca_cards.size(),
		"total_species": MARINCA_SPECIES.size()
	}

func cook_and_serve_sushi(dish_id: String) -> Dictionary:
	if not SUSHI_RECIPES.has(dish_id):
		return {"ok": false, "error": "未知深海料理配方"}
	var dish: Dictionary = SUSHI_RECIPES[dish_id]
	var cost: Dictionary = dish["cost"]
	for kind in cost:
		if int(inventory.get(kind, 0)) < int(cost[kind]):
			return {"ok": false, "error": "食材不足！需 %s（水下狩猎或按 V 无人机打捞获取）" % str(dish.get("cost_text", ""))}
	for kind in cost:
		inventory[kind] = int(inventory.get(kind, 0)) - int(cost[kind])
	var star_mult: float = 1.0 + float(get_three_star_count()) * 0.12
	var earned: int = roundi(float(dish["price"]) * star_mult)
	gold += earned
	dishes_served += 1
	sushi_reputation = maxi(sushi_reputation, 1 + int(dishes_served / 3) + int(get_three_star_count() / 2))
	var buff_msg := ""
	match dish_id:
		"goldfish_nigiri":
			if mode != "explore":
				max_oxygen += 10.0
				oxygen = minf(max_oxygen, oxygen + 30.0)
			health = minf(max_health, health + 35.0)
			buff_msg = "生命 +35 · 氧气 +30 · 氧气上限 +10s"
		"kelp_roll":
			max_health += 20.0
			health = max_health
			buff_msg = "生命上限永久 +20 (当前 %d) 并回满生命" % int(max_health)
		"shark_sashimi":
			weapon_attack_bonus += 18.0
			weapon_upgrade_level += 1
			buff_msg = "全武器攻击力永久 +18 (强化 Lv.%d)" % weapon_upgrade_level
		"abyss_kaiseki":
			weapon_attack_bonus += 30.0
			weapon_upgrade_level += 1
			max_drone_charges += 1
			drone_charges = max_drone_charges
			base_max_weight += 15.0
			buff_msg = "全武器攻击 +30 · 无人机配额 +1 · 负重上限 +15kg"
	return {
		"ok": true,
		"dish_id": dish_id,
		"name": str(dish["name"]),
		"gold_earned": earned,
		"buff": buff_msg,
		"total_gold": gold
	}

func serve_all_surplus_fish() -> Dictionary:
	var small_cnt: int = int(inventory.get("fish_small", 0))
	var meat_cnt: int = int(inventory.get("fish_meat", 0))
	if small_cnt <= 0 and meat_cnt <= 0:
		return {"ok": false, "error": "当前没有可挂牌售卖的鲜鱼或海兽生肉！请先下海捕鱼"}
	inventory["fish_small"] = 0
	inventory["fish_meat"] = 0
	var star_mult: float = 1.0 + float(get_three_star_count()) * 0.12
	var base_rev: int = small_cnt * 55 + meat_cnt * 65
	var earned: int = roundi(float(base_rev) * star_mult)
	gold += earned
	var plates: int = small_cnt + meat_cnt
	dishes_served += plates
	sushi_reputation = maxi(sushi_reputation, 1 + int(dishes_served / 3) + int(get_three_star_count() / 2))
	health = minf(max_health, health + 25.0)
	if mode != "explore":
		oxygen = minf(max_oxygen, oxygen + 25.0)
	return {
		"ok": true,
		"plates": plates,
		"gold_earned": earned,
		"total_gold": gold
	}

func buy_cobra_item(item_id: String) -> Dictionary:
	if not COBRA_SHOP_ITEMS.has(item_id):
		return {"ok": false, "error": "未知商店商品"}
	var item: Dictionary = COBRA_SHOP_ITEMS[item_id]
	var price: int = int(item["price"])
	if gold < price:
		return {"ok": false, "error": "金币不足！需 %d 金币（当前 %d 金币，可在深海寿司吧售卖料理赚取）" % [price, gold]}
	gold -= price
	var effect_msg := ""
	match item_id:
		"cargo_box":
			cargo_upgrade_level += 1
			max_drone_charges += 1
			drone_charges = max_drone_charges
			effect_msg = "负重上限提升至 %.0f kg · 无人机打捞配额升至 %d 次" % [get_max_weight(), max_drone_charges]
		"oxygen_capsule":
			if mode != "explore":
				max_oxygen += 25.0
				oxygen = max_oxygen
			health = max_health
			effect_msg = "氧气上限提升至 %.0f 秒 · 氧气与生命已完全补满" % max_oxygen
		"duff_coating":
			weapon_attack_bonus += 25.0
			weapon_upgrade_level += 1
			effect_msg = "全武器攻击力永久 +25 (总加成 +%.0f · Lv.%d)" % [weapon_attack_bonus, weapon_upgrade_level]
	return {
		"ok": true,
		"item_id": item_id,
		"name": str(item["name"]),
		"effect": effect_msg,
		"gold_left": gold
	}

func take_damage(amount: float) -> bool:
	if mode == "explore":
		return false
	var actual_dmg := amount * (0.6 if reinforced_suit else 1.0)
	health = maxf(0.0, health - actual_dmg)
	return health <= 0.0

func craft(recipe: String, near_home: bool) -> String:
	if not RECIPES.has(recipe):
		return "未知配方"
	if (recipe == "tank" and tank) or (recipe == "fins" and fins) or (recipe == "beacon" and rescued):
		return "已完成此项制作"
	if (recipe == "reinforced_suit" and reinforced_suit) or (recipe == "bio_battery" and bio_battery):
		return "该强化已完成，无需重复升级"
	if recipe == "rebreather" and rebreather:
		return "已拥有深海循环呼吸器"
	if recipe == "biomod_dash" and biomod_dash:
		return "已激活涡流突进模组"
	if recipe in ["axe", "harpoon", "sonar_cannon", "sonic", "marker_gun"] and has_weapon(recipe):
		return "已拥有此项武器"
	if not near_home and mode != "explore":
		return "请回到逃生舱附近使用制造台（7 米内）"
	var cost: Dictionary = RECIPES[recipe]
	for kind in cost:
		if inventory.get(kind, 0) < cost[kind]:
			return "材料不足，继续探索海床"
	for kind in cost:
		inventory[kind] -= cost[kind]
	match recipe:
		"tank":
			tank = true
			max_oxygen = 150.0
			oxygen = max_oxygen
		"fins":
			fins = true
		"rebreather":
			rebreather = true
		"reinforced_suit":
			reinforced_suit = true
			max_health = 150.0
			health = 150.0
		"bio_battery":
			bio_battery = true
			unlock_mod("bio_battery_mod")
		"serrated_blade":
			weapon_attack_bonus += 25.0
			weapon_upgrade_level += 1
		"biomod_dash":
			biomod_dash = true
			weapon_upgrade_level += 1
		"axe":
			_unlock_weapon("axe")
		"harpoon":
			_unlock_weapon("harpoon")
		"sonar_cannon":
			_unlock_weapon("sonar_cannon")
		"sonic":
			_unlock_weapon("sonic")
		"marker_gun":
			_unlock_weapon("marker_gun")
		"beacon":
			rescued = true
		"reinforce_sharp":
			weapon_attack_bonus += 20.0
			weapon_upgrade_level += 1
		"reinforce_sonic":
			weapon_attack_bonus += 35.0
			weapon_upgrade_level += 1
		"abyssal_escape_engine":
			escape_crafted = true
			rescued = true
	return ""

func craft_recipe(recipe: String, near_home: bool = true) -> String:
	return craft(recipe, near_home)

func tick(delta: float, safe: bool, sprinting: bool, depth: float = 0.0) -> bool:
	elapsed += delta
	if sonar_cooldown > 0.0:
		sonar_cooldown = maxf(0.0, sonar_cooldown - delta)
	if mode == "explore":
		oxygen = max_oxygen
		health = 100.0
		return false
	if safe:
		oxygen = minf(max_oxygen, oxygen + delta * 24.0)
		health = minf(max_health, health + delta * 6.0)
		drone_charges = max_drone_charges
	else:
		var depth_factor: float = 1.0
		if depth > 25.0 and not rebreather:
			depth_factor += clampf((depth - 25.0) / 45.0, 0.0, 1.0) * 0.8
		var rate: float = (1.5 if sprinting else 1.0) * depth_factor
		oxygen = maxf(0.0, oxygen - delta * rate)
		if oxygen <= 0.0:
			health = maxf(0.0, health - delta * 9.0)
	return health <= 0.0

func recover() -> void:
	oxygen = max_oxygen
	health = max_health
	drone_charges = max_drone_charges

static func _default_inventory() -> Dictionary:
	return {
		"titanium": 0, "copper": 0, "quartz": 0, "kelp": 0, "fish_small": 0,
		"shark_fragment": 0, "abyss_fragment": 0,
		"fish_meat": 0, "creature_skin": 0, "creature_tooth": 0, "chitin": 0,
		"mother_tree_essence": 0, "ancient_star_core": 0, "tree_seed": 0
	}

static func _read_float(data: Dictionary, key: String, fallback: float) -> float:
	if not data.has(key):
		return fallback
	var val: Variant = data[key]
	if val is float or val is int:
		var f := float(val)
		return f if is_finite(f) else fallback
	return fallback

static func _read_int(data: Dictionary, key: String, fallback: int) -> int:
	if not data.has(key):
		return fallback
	var val: Variant = data[key]
	if val is int:
		return val
	if val is float and is_finite(val):
		return roundi(val)
	return fallback

static func _read_bool(data: Dictionary, key: String, fallback: bool) -> bool:
	if not data.has(key):
		return fallback
	var val: Variant = data[key]
	if val is bool:
		return val
	if val is int or val is float:
		return float(val) != 0.0
	return fallback

static func _read_string(data: Dictionary, key: String, fallback: String) -> String:
	if not data.has(key):
		return fallback
	var val: Variant = data[key]
	if val is String:
		return val
	return fallback

func to_save_dict() -> Dictionary:
	var inv_out: Dictionary = {}
	for k in inventory:
		inv_out[str(k)] = int(inventory[k])
	var cells_out: Array = []
	for cell_key in surveyed_cells:
		if not bool(surveyed_cells[cell_key]):
			continue
		var parts := str(cell_key).split("_")
		if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
			cells_out.append([int(parts[0]), int(parts[1])])
		else:
			cells_out.append(str(cell_key))
	var marinca_out: Dictionary = {}
	for sp_key in marinca_cards:
		var entry: Variant = marinca_cards[sp_key]
		if entry is Dictionary:
			var ed: Dictionary = entry
			marinca_out[str(sp_key)] = {
				"name": str(ed.get("name", MARINCA_SPECIES.get(str(sp_key), "海洋生物"))),
				"stars": clampi(int(ed.get("stars", 1)), 1, 3),
				"count": maxi(1, int(ed.get("count", 1)))
			}
	var pinged_out: Array = []
	for p_key in pinged_targets:
		if bool(pinged_targets[p_key]):
			pinged_out.append(str(p_key))
	var weapon_mods_out: Dictionary = {}
	for wid in weapon_mods:
		weapon_mods_out[str(wid)] = get_weapon_mods(str(wid))
	return {
		"mode": mode,
		"selected_character": selected_character,
		"inventory": inv_out,
		"weapons": weapons.duplicate(),
		"unlocked_tools": unlocked_tools.duplicate(),
		"equipped_weapons": equipped_weapons.duplicate(),
		"weapon_tiers": weapon_tiers.duplicate(),
		"unlocked_mods": unlocked_mods.duplicate(),
		"weapon_mods": weapon_mods_out,
		"active_tactical_skill": active_tactical_skill,
		"deployed_pet_indices": deployed_pet_indices.duplicate(),
		"loadout_version": loadout_version,
		"weapon_upgrade_level": weapon_upgrade_level,
		"weapon_attack_bonus": weapon_attack_bonus,
		"oxygen": oxygen,
		"max_oxygen": max_oxygen,
		"max_health": max_health,
		"health": health,
		"tank": tank,
		"fins": fins,
		"rebreather": rebreather,
		"biomod_dash": biomod_dash,
		"biomod_vision": biomod_vision,
		"black_box_read": black_box_read,
		"pinned_recipe": pinned_recipe,
		"reinforced_suit": reinforced_suit,
		"bio_battery": bio_battery,
		"rescued": rescued,
		"boss_defeated": boss_defeated,
		"all_bosses_defeated": all_bosses_defeated,
		"mother_tree_active": mother_tree_active,
		"escape_crafted": escape_crafted,
		"tamed_beast_count": tamed_beast_count,
		"elapsed": elapsed,
		"landmarks_discovered": landmarks_discovered.duplicate(),
		"gold": gold,
		"dishes_served": dishes_served,
		"sushi_reputation": sushi_reputation,
		"drone_charges": drone_charges,
		"max_drone_charges": max_drone_charges,
		"base_max_weight": base_max_weight,
		"cargo_upgrade_level": cargo_upgrade_level,
		"marinca_cards": marinca_out,
		"surveyed_cells": cells_out,
		"unlocked_outposts": unlocked_outposts.duplicate(),
		"collected_relics": collected_relics.duplicate(),
		"pinged_targets": pinged_out,
		"has_custom_waypoint": has_custom_waypoint,
		"custom_waypoint": [custom_waypoint.x, custom_waypoint.y, custom_waypoint.z],
		"sonar_cooldown": sonar_cooldown,
		"fast_travel_count": fast_travel_count,
		"explorer_speed_bonus": explorer_speed_bonus,
		"explorer_rank_level": explorer_rank_level
	}

func to_dict() -> Dictionary:
	return to_save_dict()

func load_save_dict(data: Dictionary) -> void:
	if data == null or not (data is Dictionary):
		return
	var saved_mode := _read_string(data, "mode", "survival")
	if saved_mode != "explore":
		saved_mode = "survival"
	inventory = _default_inventory()
	landmarks_discovered.clear()
	unlocked_outposts.clear()
	collected_relics.clear()
	marinca_cards.clear()
	surveyed_cells.clear()
	pinged_targets.clear()
	clear_custom_waypoint()
	max_health = 100.0
	reinforced_suit = false
	bio_battery = false
	rescued = false
	boss_defeated = false
	all_bosses_defeated = false
	mother_tree_active = false
	escape_crafted = false
	black_box_read = false
	pinned_recipe = "tank"
	tamed_beast_count = 0
	elapsed = 0.0
	gold = 0
	dishes_served = 0
	sushi_reputation = 1
	base_max_weight = 40.0
	cargo_upgrade_level = 0
	sonar_cooldown = 0.0
	fast_travel_count = 0
	explorer_speed_bonus = 0.0
	explorer_rank_level = 1
	set_mode(saved_mode)

	selected_character = _read_string(data, "selected_character", selected_character)
	if data.get("inventory") is Dictionary:
		var inv_in: Dictionary = data["inventory"]
		for k in inv_in:
			var v: Variant = inv_in[k]
			if v is int or v is float:
				inventory[str(k)] = maxi(0, roundi(float(v)))

	if data.get("weapons") is Array:
		var w_arr: Array[String] = []
		for item in data["weapons"]:
			var wid := str(item)
			if not wid.is_empty() and not w_arr.has(wid):
				w_arr.append(wid)
		if not w_arr.has("knife"):
			w_arr.push_front("knife")
		weapons = w_arr

	unlocked_tools = _default_unlocked_tools(saved_mode == "explore")
	if data.get("unlocked_tools") is Dictionary:
		var ut_in: Dictionary = data["unlocked_tools"]
		for tk in ut_in:
			unlocked_tools[str(tk)] = bool(ut_in[tk])
	unlocked_tools["knife"] = true
	for wid in weapons:
		if WeaponCatalog.WEAPONS.has(wid):
			unlocked_tools[wid] = true
	for required_wid in WeaponCatalog.WEAPON_ORDER:
		if not unlocked_tools.has(required_wid):
			unlocked_tools[required_wid] = (required_wid == "knife") or (saved_mode == "explore")

	weapon_tiers = _default_weapon_tiers(1)
	if data.get("weapon_tiers") is Dictionary:
		var wt_in: Dictionary = data["weapon_tiers"]
		for wid in WeaponCatalog.WEAPON_ORDER:
			if wt_in.has(wid):
				weapon_tiers[wid] = clampi(_read_int(wt_in, wid, 1), 1, WeaponCatalog.MAX_WEAPON_TIER)

	if data.get("unlocked_mods") is Array:
		var mods_loaded: Array[String] = []
		for raw_mod in data["unlocked_mods"]:
			var mid := str(raw_mod)
			if WeaponCatalog.MODS.has(mid) and not mods_loaded.has(mid):
				mods_loaded.append(mid)
		if mods_loaded.is_empty():
			mods_loaded = WeaponCatalog.MOD_ORDER.duplicate() if saved_mode == "explore" else _default_survival_mods()
		unlocked_mods = mods_loaded
	else:
		unlocked_mods = WeaponCatalog.MOD_ORDER.duplicate() if saved_mode == "explore" else _default_survival_mods()

	weapon_mods = {}
	if data.get("weapon_mods") is Dictionary:
		var wm_in: Dictionary = data["weapon_mods"]
		for raw_wid in wm_in:
			var wid := str(raw_wid)
			if not WeaponCatalog.WEAPONS.has(wid):
				continue
			var raw_list: Variant = wm_in[raw_wid]
			if raw_list is Array:
				var cleaned_mods: Array[String] = []
				for rm in raw_list:
					var mid := str(rm)
					if WeaponCatalog.MODS.has(mid) and unlocked_mods.has(mid) and not cleaned_mods.has(mid):
						cleaned_mods.append(mid)
						if cleaned_mods.size() >= MAX_WEAPON_MODS:
							break
				if not cleaned_mods.is_empty():
					weapon_mods[wid] = cleaned_mods

	var eq_loaded: Array[String] = []
	if data.get("equipped_weapons") is Array:
		for raw_eq in data["equipped_weapons"]:
			var wid := str(raw_eq)
			if WeaponCatalog.WEAPONS.has(wid) and has_weapon(wid) and not eq_loaded.has(wid):
				eq_loaded.append(wid)
				if eq_loaded.size() >= MAX_EQUIPPED_WEAPONS:
					break
	if eq_loaded.is_empty():
		if saved_mode == "explore" and has_weapon("axe") and has_weapon("harpoon") and has_weapon("sonic"):
			eq_loaded = ["axe", "harpoon", "sonic"]
		else:
			for wid in get_owned_weapons():
				eq_loaded.append(wid)
				if eq_loaded.size() >= MAX_EQUIPPED_WEAPONS:
					break
	if eq_loaded.is_empty():
		eq_loaded.append("knife")
	equipped_weapons = eq_loaded

	var loaded_skill := _read_string(data, "active_tactical_skill", SkillCatalog.TACTICAL_ORDER[0])
	active_tactical_skill = loaded_skill if SkillCatalog.TACTICAL_SKILLS.has(loaded_skill) else SkillCatalog.TACTICAL_ORDER[0]

	weapon_upgrade_level = maxi(0, _read_int(data, "weapon_upgrade_level", weapon_upgrade_level))
	weapon_attack_bonus = maxf(0.0, _read_float(data, "weapon_attack_bonus", weapon_attack_bonus))
	max_oxygen = maxf(10.0, _read_float(data, "max_oxygen", max_oxygen))
	oxygen = clampf(_read_float(data, "oxygen", oxygen), 0.0, max_oxygen)
	max_health = maxf(10.0, _read_float(data, "max_health", max_health))
	health = clampf(_read_float(data, "health", health), 0.0, max_health)
	tank = _read_bool(data, "tank", tank)
	fins = _read_bool(data, "fins", fins)
	rebreather = _read_bool(data, "rebreather", rebreather)
	biomod_dash = _read_bool(data, "biomod_dash", biomod_dash)
	biomod_vision = _read_bool(data, "biomod_vision", biomod_vision)
	black_box_read = _read_bool(data, "black_box_read", black_box_read)
	pinned_recipe = _read_string(data, "pinned_recipe", pinned_recipe)
	reinforced_suit = _read_bool(data, "reinforced_suit", reinforced_suit)
	bio_battery = _read_bool(data, "bio_battery", bio_battery)
	rescued = _read_bool(data, "rescued", rescued)
	boss_defeated = _read_bool(data, "boss_defeated", boss_defeated)
	all_bosses_defeated = _read_bool(data, "all_bosses_defeated", all_bosses_defeated)
	mother_tree_active = _read_bool(data, "mother_tree_active", mother_tree_active)
	escape_crafted = _read_bool(data, "escape_crafted", escape_crafted)
	tamed_beast_count = maxi(0, _read_int(data, "tamed_beast_count", tamed_beast_count))
	deployed_pet_indices.clear()
	if data.get("deployed_pet_indices") is Array:
		var pet_limit := tamed_creatures.size() if not tamed_creatures.is_empty() else tamed_beast_count
		for raw_pi in data["deployed_pet_indices"]:
			if not (raw_pi is int or raw_pi is float):
				continue
			var pi := int(raw_pi)
			if pi >= 0 and (pet_limit <= 0 or pi < pet_limit) and not deployed_pet_indices.has(pi):
				deployed_pet_indices.append(pi)
				if deployed_pet_indices.size() >= MAX_DEPLOYED_PETS:
					break
	if not tamed_creatures.is_empty():
		sync_deployed_pets()
	loadout_version = maxi(1, _read_int(data, "loadout_version", loadout_version))
	elapsed = maxf(0.0, _read_float(data, "elapsed", elapsed))
	gold = maxi(0, _read_int(data, "gold", gold))
	dishes_served = maxi(0, _read_int(data, "dishes_served", dishes_served))
	sushi_reputation = maxi(1, _read_int(data, "sushi_reputation", sushi_reputation))
	max_drone_charges = maxi(0, _read_int(data, "max_drone_charges", max_drone_charges))
	drone_charges = clampi(_read_int(data, "drone_charges", drone_charges), 0, max_drone_charges)
	base_max_weight = maxf(10.0, _read_float(data, "base_max_weight", base_max_weight))
	cargo_upgrade_level = maxi(0, _read_int(data, "cargo_upgrade_level", cargo_upgrade_level))
	sonar_cooldown = maxf(0.0, _read_float(data, "sonar_cooldown", sonar_cooldown))
	fast_travel_count = maxi(0, _read_int(data, "fast_travel_count", fast_travel_count))
	var spd_fallback := _read_float(data, "speed_bonus", explorer_speed_bonus)
	explorer_speed_bonus = clampf(_read_float(data, "explorer_speed_bonus", spd_fallback), 0.0, 0.48)
	explorer_rank_level = clampi(_read_int(data, "explorer_rank_level", explorer_rank_level), 1, EXPLORER_RANKS.size())

	var lm_raw: Variant = data.get("landmarks_discovered", data.get("discovered_landmarks", []))
	if lm_raw is Array:
		for item in lm_raw:
			var lid := str(item)
			if not lid.is_empty() and not landmarks_discovered.has(lid):
				landmarks_discovered.append(lid)

	if data.get("unlocked_outposts") is Array:
		for item in data["unlocked_outposts"]:
			var oid := str(item)
			if not oid.is_empty() and not unlocked_outposts.has(oid):
				unlocked_outposts.append(oid)

	if data.get("collected_relics") is Array:
		for item in data["collected_relics"]:
			var rid := str(item)
			if not rid.is_empty() and not collected_relics.has(rid):
				collected_relics.append(rid)

	var marinca_raw: Variant = data.get("marinca_cards", data.get("marinca_caught", {}))
	if marinca_raw is Dictionary:
		var md: Dictionary = marinca_raw
		for sp_key in md:
			var entry: Variant = md[sp_key]
			if entry is Dictionary:
				var ed: Dictionary = entry
				var s_name := _read_string(ed, "name", str(MARINCA_SPECIES.get(str(sp_key), "海洋生物")))
				var s_stars := clampi(_read_int(ed, "stars", 1), 1, 3)
				var s_count := maxi(1, _read_int(ed, "count", 1))
				marinca_cards[str(sp_key)] = {
					"name": s_name,
					"stars": s_stars,
					"count": s_count
				}

	var cells_raw: Variant = data.get("surveyed_cells", [])
	if cells_raw is Array:
		for cell in cells_raw:
			if cell is Array and (cell as Array).size() >= 2:
				var ca: Array = cell
				if (ca[0] is int or ca[0] is float) and (ca[1] is int or ca[1] is float):
					var gx := clampi(roundi(float(ca[0])), 0, SURVEY_GRID_SIZE - 1)
					var gz := clampi(roundi(float(ca[1])), 0, SURVEY_GRID_SIZE - 1)
					surveyed_cells["%d_%d" % [gx, gz]] = true
			elif cell is String:
				var s := String(cell)
				var sep := "," if s.contains(",") else "_"
				var parts := s.split(sep)
				if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
					var gx := clampi(int(parts[0]), 0, SURVEY_GRID_SIZE - 1)
					var gz := clampi(int(parts[1]), 0, SURVEY_GRID_SIZE - 1)
					surveyed_cells["%d_%d" % [gx, gz]] = true
	elif cells_raw is Dictionary:
		var cd: Dictionary = cells_raw
		for ck in cd:
			if bool(cd[ck]):
				var s := str(ck)
				var sep := "," if s.contains(",") else "_"
				var parts := s.split(sep)
				if parts.size() == 2 and parts[0].is_valid_int() and parts[1].is_valid_int():
					var gx := clampi(int(parts[0]), 0, SURVEY_GRID_SIZE - 1)
					var gz := clampi(int(parts[1]), 0, SURVEY_GRID_SIZE - 1)
					surveyed_cells["%d_%d" % [gx, gz]] = true

	var pinged_raw: Variant = data.get("pinged_targets", [])
	if pinged_raw is Array:
		for pk in pinged_raw:
			var ps := str(pk)
			if not ps.is_empty():
				pinged_targets[ps] = true
	elif pinged_raw is Dictionary:
		var pd: Dictionary = pinged_raw
		for pk in pd:
			if bool(pd[pk]):
				pinged_targets[str(pk)] = true

	has_custom_waypoint = _read_bool(data, "has_custom_waypoint", false)
	var wp_raw: Variant = data.get("custom_waypoint", null)
	if wp_raw is Array and (wp_raw as Array).size() >= 3:
		var wa: Array = wp_raw
		if (wa[0] is int or wa[0] is float) and (wa[1] is int or wa[1] is float) and (wa[2] is int or wa[2] is float):
			custom_waypoint = Vector3(float(wa[0]), float(wa[1]), float(wa[2]))
		else:
			has_custom_waypoint = false
			custom_waypoint = Vector3.ZERO
	elif not has_custom_waypoint:
		custom_waypoint = Vector3.ZERO
	else:
		has_custom_waypoint = false
		custom_waypoint = Vector3.ZERO

func from_dict(data: Dictionary) -> void:
	load_save_dict(data)
