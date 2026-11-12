extends RefCounted

const RECIPES := {
	"tank": {"titanium": 2, "kelp": 2},
	"fins": {"titanium": 1, "kelp": 2},
	"axe": {"titanium": 2, "copper": 1},
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
	"sonic": "蓝光静滞枪",
	"biomod_dash": "生体模组·涡流突进",
	"beacon": "求救信标",
	"reinforced_suit": "海兽绝缘潜航服",
	"bio_battery": "生物高能电池",
	"serrated_blade": "深海锯齿骨刃",
	"reinforce_sharp": "深铸·锋锐硬化",
	"reinforce_sonic": "深铸·晶体共鸣"
	,"abyssal_escape_engine": "深海跃迁逃逸器 (终极逃生舰)"
	,"marker_gun": "光标指示枪 (激光引战)"
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
var inventory: Dictionary = {
	"titanium": 0, "copper": 0, "quartz": 0, "kelp": 0, "fish_small": 0,
	"shark_fragment": 0, "abyss_fragment": 0
	,"fish_meat": 0, "creature_skin": 0, "creature_tooth": 0, "chitin": 0
	,"mother_tree_essence": 0, "ancient_star_core": 0, "tree_seed": 0
}
var weapons: Array[String] = ["knife"]
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
		max_oxygen = 90.0
		oxygen = max_oxygen
		health = 100.0
		weapon_upgrade_level = 0
		weapon_attack_bonus = 0.0
		max_drone_charges = 3
		drone_charges = 3

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
		"reinforced_suit":
			reinforced_suit = true
			max_health = 150.0
			health = 150.0
		"bio_battery":
			bio_battery = true
		"serrated_blade":
			weapon_attack_bonus += 25.0
			weapon_upgrade_level += 1
		"biomod_dash":
			biomod_dash = true
			weapon_upgrade_level += 1
		"axe":
			if not weapons.has("axe"):
				weapons.append("axe")
		"sonic":
			if not weapons.has("sonic"):
				weapons.append("sonic")
		"marker_gun":
			if not weapons.has("marker_gun"):
				weapons.append("marker_gun")
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
