extends RefCounted

const RECIPES := {
	"tank": {"titanium": 2, "kelp": 2},
	"fins": {"titanium": 1, "kelp": 2},
	"axe": {"titanium": 2, "copper": 1},
	"sonic": {"titanium": 2, "quartz": 2, "copper": 1},
	"beacon": {"titanium": 3, "copper": 2, "quartz": 2},
	"rebreather": {"titanium": 2, "copper": 1, "kelp": 2},
	"biomod_dash": {"shark_fragment": 1, "titanium": 2},
	"reinforce_sharp": {"shark_fragment": 1, "titanium": 1},
	"reinforce_sonic": {"abyss_fragment": 1, "quartz": 1}
}

const RECIPE_NAMES := {
	"tank": "高容量氧气瓶",
	"fins": "动力脚蹼",
	"rebreather": "深海循环呼吸器",
	"axe": "破拆战斧",
	"sonic": "声波脉冲枪",
	"biomod_dash": "生体模组·涡流突进",
	"beacon": "求救信标",
	"reinforce_sharp": "深铸·锋锐硬化",
	"reinforce_sonic": "深铸·晶体共鸣"
}

var mode: String = "survival"
var inventory: Dictionary = {
	"titanium": 0, "copper": 0, "quartz": 0, "kelp": 0, "fish_small": 0,
	"shark_fragment": 0, "abyss_fragment": 0
}
var weapons: Array[String] = ["knife"]
var weapon_upgrade_level: int = 0
var weapon_attack_bonus: float = 0.0
var oxygen: float = 90.0
var max_oxygen: float = 90.0
var health: float = 100.0
var tank: bool = false
var fins: bool = false
var rebreather: bool = false
var biomod_dash: bool = false
var biomod_vision: bool = false
var black_box_read: bool = false
var pinned_recipe: String = "tank"
var rescued: bool = false
var elapsed: float = 0.0
var landmarks_discovered: Array[String] = []

func set_mode(new_mode: String) -> void:
	mode = new_mode
	if mode == "explore":
		tank = true
		fins = true
		rebreather = true
		biomod_dash = true
		biomod_vision = true
		weapons = ["knife", "axe", "sonic"]
		max_oxygen = 999.0
		oxygen = max_oxygen
		health = 100.0
		weapon_upgrade_level = 3
		weapon_attack_bonus = 40.0
	else:
		mode = "survival"
		tank = false
		fins = false
		rebreather = false
		biomod_dash = false
		biomod_vision = false
		weapons = ["knife"]
		max_oxygen = 90.0
		oxygen = max_oxygen
		health = 100.0
		weapon_upgrade_level = 0
		weapon_attack_bonus = 0.0

func discover_landmark(id: String) -> bool:
	if landmarks_discovered.has(id):
		return false
	landmarks_discovered.append(id)
	return true

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
	health = minf(100.0, health + hp_gain)
	if mode != "explore":
		oxygen = minf(max_oxygen, oxygen + oxy_gain)
	inventory["fish_small"] += 1
	return {"health_gain": hp_gain, "oxygen_gain": oxy_gain}

func take_damage(amount: float) -> bool:
	if mode == "explore":
		return false
	health = maxf(0.0, health - amount)
	return health <= 0.0

func craft(recipe: String, near_home: bool) -> String:
	if not RECIPES.has(recipe):
		return "未知配方"
	if (recipe == "tank" and tank) or (recipe == "fins" and fins) or (recipe == "beacon" and rescued):
		return "已完成此项制作"
	if recipe == "rebreather" and rebreather:
		return "已拥有深海循环呼吸器"
	if recipe == "biomod_dash" and biomod_dash:
		return "已激活涡流突进模组"
	if (recipe == "axe" and weapons.has("axe")) or (recipe == "sonic" and weapons.has("sonic")):
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
		"biomod_dash":
			biomod_dash = true
			weapon_upgrade_level += 1
		"axe":
			if not weapons.has("axe"):
				weapons.append("axe")
		"sonic":
			if not weapons.has("sonic"):
				weapons.append("sonic")
		"beacon":
			rescued = true
		"reinforce_sharp":
			weapon_attack_bonus += 20.0
			weapon_upgrade_level += 1
		"reinforce_sonic":
			weapon_attack_bonus += 35.0
			weapon_upgrade_level += 1
	return ""

func tick(delta: float, safe: bool, sprinting: bool, depth: float = 0.0) -> bool:
	elapsed += delta
	if mode == "explore":
		oxygen = max_oxygen
		health = 100.0
		return false
	if safe:
		oxygen = minf(max_oxygen, oxygen + delta * 24.0)
		health = minf(100.0, health + delta * 6.0)
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
	health = 100.0
