extends RefCounted

const CATEGORY_LABELS := {
	"main": "主线航程",
	"side": "科考支线",
	"bounty": "回波委托"
}

const ACT_LABELS := {
	1: "主线 · 第一幕",
	2: "主线 · 第二幕",
	3: "主线 · 第三幕",
	4: "主线 · 第四幕",
	5: "主线 · 第五幕"
}

const OUTPOST_COORD_NAMES := [
	{"name": "北境环礁科考站", "xz": Vector2(40, 340)},
	{"name": "翡翠海峡前哨站", "xz": Vector2(-260, 280)},
	{"name": "东海星象前哨站", "xz": Vector2(460, -60)},
	{"name": "龙骨荒原前哨站", "xz": Vector2(-480, -90)},
	{"name": "黑曜火山科考站", "xz": Vector2(-440, -420)},
	{"name": "极渊星辉前哨站", "xz": Vector2(60, -640)}
]

static func get_category_label(category: String) -> String:
	return str(CATEGORY_LABELS.get(category, "任务"))

static func get_act_label(category: String, act: int) -> String:
	if category == "main":
		return str(ACT_LABELS.get(act, "主线航程"))
	return get_category_label(category)

static func resolve_outpost_name(pos: Vector3, fallback: String = "远洋科考前哨站") -> String:
	var target_xz := Vector2(pos.x, pos.z)
	var best_name := fallback
	var best_dist_sq := 900.0
	for spec in OUTPOST_COORD_NAMES:
		var spec_xz: Vector2 = spec["xz"]
		var dist_sq := target_xz.distance_squared_to(spec_xz)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			best_name = str(spec["name"])
	return best_name

static func get_all_quests() -> Array[Dictionary]:
	var quests: Array[Dictionary] = []

	quests.append({
		"id": "mq_01_shallow_foothold",
		"category": "main",
		"act": 1,
		"title": "浅礁立足与求救回波",
		"brief": "先升级基础潜水装备，潜入失事科考潜艇读取黑匣子，并回到逃生舱修复求救信标。",
		"unlock_requires": [],
		"objectives": [
			{
				"id": "craft_starter_gear",
				"label": "制作高容量氧气瓶或动力脚蹼",
				"type": "recipe_any_owned",
				"targets": ["tank", "fins"],
				"required": 1,
				"explore_auto_done": true,
				"recipe_hint": "tank",
				"nav_pos": Vector3(0, -3.5, 8),
				"nav_label": "逃生舱制造台"
			},
			{
				"id": "read_black_box",
				"label": "探查失事科考潜艇黑匣子",
				"type": "state_flag",
				"target": "black_box_read",
				"required": 1,
				"nav_pos": Vector3(45, -55.7, -55),
				"nav_label": "失事科考潜艇"
			},
			{
				"id": "repair_beacon",
				"label": "在逃生舱修复求救信标",
				"type": "state_flag",
				"target": "rescued",
				"required": 1,
				"recipe_hint": "beacon",
				"nav_pos": Vector3(0, -3.5, 8),
				"nav_label": "逃生舱工作台"
			}
		],
		"rewards": {
			"gold": 120,
			"items": {"titanium": 1, "quartz": 1},
			"summary": "+120G · 钛×1 · 石英×1"
		}
	})

	quests.append({
		"id": "mq_02_relay_network",
		"category": "main",
		"act": 2,
		"title": "建立远洋声呐中继网",
		"brief": "点亮至少 2 座远洋科考前哨站以重建深海声呐中继，并配齐深潜核心武装与循环供氧装备。",
		"unlock_requires": ["mq_01_shallow_foothold"],
		"objectives": [
			{
				"id": "unlock_two_outposts",
				"label": "激活任意 2 座远洋科考前哨站",
				"type": "collection_count",
				"target": "outposts",
				"required": 2,
				"nav_pos": Vector3(40, -10, 340),
				"nav_label": "北境环礁科考站"
			},
			{
				"id": "craft_deep_kit",
				"label": "装备蓝光静滞枪与深海循环呼吸器",
				"type": "recipe_all_owned",
				"targets": ["sonic", "rebreather"],
				"required": 2,
				"explore_auto_done": true,
				"recipe_hint": "sonic",
				"nav_pos": Vector3(0, -3.5, 8),
				"nav_label": "逃生舱制造台"
			}
		],
		"rewards": {
			"gold": 200,
			"items": {"copper": 2, "quartz": 2},
			"summary": "+200G · 铜×2 · 石英×2"
		}
	})

	quests.append({
		"id": "mq_03_four_lords",
		"category": "main",
		"act": 3,
		"title": "平息四方深渊领主",
		"brief": "击败或静滞驯服盘踞四方海域的深渊巨兽领主，令沉睡的远古深海母树重新苏醒。",
		"unlock_requires": ["mq_02_relay_network"],
		"objectives": [
			{
				"id": "lord_water_dragon",
				"label": "平息深渊水龙（深渊祭坛）",
				"type": "boss_conquer",
				"target": "water_dragon",
				"required": 1,
				"nav_pos": Vector3(-50, -76, -170),
				"nav_label": "深渊水龙领域"
			},
			{
				"id": "lord_flying_fish",
				"label": "平息风暴飞鱼·空棘龙皇",
				"type": "boss_conquer",
				"target": "flying_fish",
				"required": 1,
				"nav_pos": Vector3(145, -16, -40),
				"nav_label": "风暴海脊"
			},
			{
				"id": "lord_kraken",
				"label": "平息深渊巨章·克拉肯领主",
				"type": "boss_conquer",
				"target": "kraken",
				"required": 1,
				"nav_pos": Vector3(-105, -75, -85),
				"nav_label": "克拉肯海沟"
			},
			{
				"id": "lord_colossus_turtle",
				"label": "平息远古灵龟·巨岩神鳌",
				"type": "boss_conquer",
				"target": "colossus_turtle",
				"required": 1,
				"nav_pos": Vector3(-140, -92, -145),
				"nav_label": "玄甲巨鳌盆地"
			}
		],
		"rewards": {
			"gold": 360,
			"items": {"quartz": 2, "copper": 2},
			"summary": "+360G · 唤醒远古深海母树"
		}
	})

	quests.append({
		"id": "mq_04_mother_tree",
		"category": "main",
		"act": 4,
		"title": "潜入远古母树圣所",
		"brief": "四方领主平息后，前往深海远古母树圣所采摘三件创世圣物，解锁终极逃生舰配方。",
		"unlock_requires": ["mq_03_four_lords"],
		"objectives": [
			{
				"id": "collect_essence",
				"label": "采摘【母树生命精华】",
				"type": "item_owned",
				"target": "mother_tree_essence",
				"required": 1,
				"nav_pos": Vector3(0, -125, -340),
				"nav_label": "远古深海母树"
			},
			{
				"id": "collect_star_core",
				"label": "采摘【远古星核源石】",
				"type": "item_owned",
				"target": "ancient_star_core",
				"required": 1,
				"nav_pos": Vector3(0, -125, -340),
				"nav_label": "远古深海母树"
			},
			{
				"id": "collect_tree_seed",
				"label": "采摘【深海启迪之种】",
				"type": "item_owned",
				"target": "tree_seed",
				"required": 1,
				"nav_pos": Vector3(0, -125, -340),
				"nav_label": "远古深海母树"
			}
		],
		"rewards": {
			"gold": 300,
			"items": {},
			"summary": "+300G · 解锁终极逃生舰配方"
		}
	})

	quests.append({
		"id": "mq_05_warp_escape",
		"category": "main",
		"act": 5,
		"title": "星际跃迁归航",
		"brief": "携三件母树圣物返回逃生舱中央控制台，组装【深海跃迁逃逸器】启动归航。",
		"unlock_requires": ["mq_04_mother_tree"],
		"objectives": [
			{
				"id": "craft_escape_engine",
				"label": "返回母港控制台制作【深海跃迁逃逸器】",
				"type": "state_flag",
				"target": "escape_crafted",
				"required": 1,
				"recipe_hint": "abyssal_escape_engine",
				"nav_pos": Vector3(0, -3.5, 8),
				"nav_label": "逃生舱中央控制台"
			}
		],
		"rewards": {
			"gold": 500,
			"items": {},
			"summary": "+500G · 终章逃生达成"
		}
	})

	quests.append({
		"id": "sq_sushi_perfect_catch",
		"category": "side",
		"act": 0,
		"title": "完美活捕入门",
		"brief": "运用精准捕捞或蓝光静滞完成一次 ★★★ 完美捕获，获取最高鲜度食材。",
		"unlock_requires": [],
		"objectives": [
			{
				"id": "perfect_catch_once",
				"label": "达成 1 次 ★★★ 完美捕获",
				"type": "event_count",
				"target": "perfect_catch",
				"required": 1
			}
		],
		"rewards": {
			"gold": 90,
			"items": {"kelp": 2},
			"summary": "+90G · 海藻×2"
		}
	})

	quests.append({
		"id": "sq_sushi_bancho_chef",
		"category": "side",
		"act": 0,
		"title": "班乔深海料理吧",
		"brief": "将新鲜深海食材送往班乔料理吧烹制售出，赚取科考资金并提升体能上限。",
		"unlock_requires": ["sq_sushi_perfect_catch"],
		"objectives": [
			{
				"id": "serve_three_dishes",
				"label": "在班乔料理吧售出 3 道深海料理",
				"type": "collection_count",
				"target": "dishes_served",
				"required": 3,
				"nav_pos": Vector3(0, -3.5, 8),
				"nav_label": "班乔深海料理吧"
			}
		],
		"rewards": {
			"gold": 150,
			"items": {"fish_meat": 2},
			"summary": "+150G · 海兽生肉×2"
		}
	})

	quests.append({
		"id": "sq_sushi_marinca_codex",
		"category": "side",
		"act": 0,
		"title": "玛琳卡生态图鉴",
		"brief": "探索不同水层并收集多种海洋生物与 ★★★ 完美标本，扩充玛琳卡图鉴。",
		"unlock_requires": ["sq_sushi_bancho_chef"],
		"objectives": [
			{
				"id": "marinca_five_species",
				"label": "点亮玛琳卡图鉴 5 个物种",
				"type": "collection_count",
				"target": "marinca_species",
				"required": 5
			},
			{
				"id": "marinca_two_perfect",
				"label": "收集 2 张 ★★★ 完美卡片",
				"type": "collection_count",
				"target": "marinca_three_star",
				"required": 2
			}
		],
		"rewards": {
			"gold": 260,
			"items": {},
			"summary": "+260G"
		}
	})

	quests.append({
		"id": "sq_companion_first_tame",
		"category": "side",
		"act": 0,
		"title": "首次深海契约",
		"brief": "用蓝光静滞枪冻结深海猛兽并缔结契约，让其成为并肩作战的深海伙伴。",
		"unlock_requires": [],
		"objectives": [
			{
				"id": "tame_first_beast",
				"label": "静滞冻结并契约驯服 1 只深海猛兽",
				"type": "collection_count",
				"target": "tamed_beasts",
				"required": 1,
				"recipe_hint": "sonic"
			}
		],
		"rewards": {
			"gold": 120,
			"items": {"titanium": 2},
			"summary": "+120G · 钛×2"
		}
	})

	quests.append({
		"id": "sq_companion_sub_pilot",
		"category": "side",
		"act": 0,
		"title": "深潜艇领航演练",
		"brief": "登上科考潜艇适应水下巡航操控，并试射一次车载鱼雷检验火力系统。",
		"unlock_requires": [],
		"objectives": [
			{
				"id": "board_submarine",
				"label": "登舰驾驶深海潜艇",
				"type": "event_count",
				"target": "submarine_boarded",
				"required": 1,
				"nav_pos": Vector3(95, -36, -30),
				"nav_label": "碧蓝晶簇海盆船坞"
			},
			{
				"id": "fire_torpedo",
				"label": "发射 1 次车载鱼雷",
				"type": "event_count",
				"target": "torpedo_fired",
				"required": 1
			}
		],
		"rewards": {
			"gold": 160,
			"items": {"copper": 2},
			"summary": "+160G · 铜×2"
		}
	})

	quests.append({
		"id": "sq_companion_pack_leader",
		"category": "side",
		"act": 0,
		"title": "深渊兽群统帅",
		"brief": "集结三只契约战宠，并使用光标指示枪引导兽群发动协同集火。",
		"unlock_requires": ["sq_companion_first_tame"],
		"objectives": [
			{
				"id": "gather_three_beasts",
				"label": "集结 3 只契约战宠",
				"type": "collection_count",
				"target": "tamed_beasts",
				"required": 3
			},
			{
				"id": "command_marker_gun",
				"label": "使用光标指示枪标记集火 1 次",
				"type": "event_count",
				"target": "marker_commanded",
				"required": 1,
				"recipe_hint": "marker_gun"
			}
		],
		"rewards": {
			"gold": 240,
			"items": {},
			"summary": "+240G"
		}
	})

	quests.append({
		"id": "sq_explore_outposts",
		"category": "side",
		"act": 0,
		"title": "全域前哨站联调",
		"brief": "驶向六大远洋海域，将全部 6 座科考前哨站接入声呐与快速航行网络。",
		"unlock_requires": [],
		"objectives": [
			{
				"id": "activate_all_outposts",
				"label": "激活全部 6 座远洋科考前哨站",
				"type": "collection_count",
				"target": "outposts",
				"required": 6,
				"nav_pos": Vector3(40, -10, 340),
				"nav_label": "北境环礁科考站"
			}
		],
		"rewards": {
			"gold": 320,
			"items": {},
			"summary": "+320G"
		}
	})

	quests.append({
		"id": "sq_explore_relics",
		"category": "side",
		"act": 0,
		"title": "远古海渊考古志",
		"brief": "发掘散落于各片深海遗迹中的远古遗珍，还原失落文明的深海脉络。",
		"unlock_requires": [],
		"objectives": [
			{
				"id": "collect_six_relics",
				"label": "收集 6 处远古深海遗珍",
				"type": "collection_count",
				"target": "relics",
				"required": 6
			}
		],
		"rewards": {
			"gold": 280,
			"items": {"quartz": 2},
			"summary": "+280G · 石英×2"
		}
	})

	quests.append({
		"id": "sq_explore_master_rank",
		"category": "side",
		"act": 0,
		"title": "沧溟领航官认证",
		"brief": "持续测绘未知海图并探明各大海底地标，晋升至 4 阶探索家头衔。",
		"unlock_requires": [],
		"objectives": [
			{
				"id": "reach_rank_4",
				"label": "晋升至 4 阶探索家头衔（沧溟深渊领航官）",
				"type": "rank_reach",
				"target": "explorer_rank",
				"required": 4
			},
			{
				"id": "discover_twelve_landmarks",
				"label": "探明 12 处海洋地标",
				"type": "collection_count",
				"target": "landmarks",
				"required": 12
			}
		],
		"rewards": {
			"gold": 350,
			"items": {},
			"summary": "+350G"
		}
	})

	quests.append({
		"id": "sq_forge_deep_upgrade",
		"category": "side",
		"act": 0,
		"title": "深铸武装熔炼",
		"brief": "吸收巨兽碎片或深渊晶核的能量，并在逃生舱完成一次深铸强化或生体模组制作。",
		"unlock_requires": [],
		"objectives": [
			{
				"id": "absorb_fragment",
				"label": "拾取 1 枚巨兽碎片/晶核",
				"type": "event_count",
				"target": "fragment_absorbed",
				"required": 1
			},
			{
				"id": "complete_deep_forge",
				"label": "完成 1 次深铸强化或制作涡流突进",
				"type": "event_count",
				"target": "deep_forge_done",
				"required": 1,
				"recipe_hint": "reinforce_sharp",
				"nav_pos": Vector3(0, -3.5, 8),
				"nav_label": "逃生舱深铸工作台"
			}
		],
		"rewards": {
			"gold": 180,
			"items": {"titanium": 2},
			"summary": "+180G · 钛×2"
		}
	})

	return quests

static func get_quest(quest_id: String) -> Dictionary:
	for quest in get_all_quests():
		if str(quest.get("id", "")) == quest_id:
			return quest
	return {}

static func get_bounty_templates() -> Array[Dictionary]:
	var templates: Array[Dictionary] = []

	templates.append({
		"id": "bounty_depth_twilight",
		"category": "bounty",
		"title": "暮光陆坡声学采样",
		"brief": "下潜至暮光陆坡水层（深度 >100m）维持声学探测器稳定采样 4 秒。",
		"objectives": [
			{
				"id": "hold_twilight_depth",
				"label": "在暮光陆坡（>100m）采样 4 秒",
				"type": "depth_hold",
				"target": "depth_twilight",
				"target_depth": 100.0,
				"required": 4
			}
		],
		"rewards": {
			"gold": 100,
			"items": {"quartz": 1},
			"summary": "+100G · 石英×1"
		}
	})

	templates.append({
		"id": "bounty_depth_bathyal",
		"category": "bounty",
		"title": "深海盆地声学采样",
		"brief": "深入深海盆地水层（深度 >220m）采集低频声学剖面数据持续 4 秒。",
		"objectives": [
			{
				"id": "hold_bathyal_depth",
				"label": "在深海盆地（>220m）采样 4 秒",
				"type": "depth_hold",
				"target": "depth_bathyal",
				"target_depth": 220.0,
				"required": 4
			}
		],
		"rewards": {
			"gold": 140,
			"items": {"copper": 1},
			"summary": "+140G · 铜×1"
		}
	})

	templates.append({
		"id": "bounty_depth_hadal",
		"category": "bounty",
		"title": "极深海沟声学采样",
		"brief": "挑战极深海沟高压带（深度 >380m），完成 4 秒深渊回波声学校准。",
		"objectives": [
			{
				"id": "hold_hadal_depth",
				"label": "在极深海沟（>380m）采样 4 秒",
				"type": "depth_hold",
				"target": "depth_hadal",
				"target_depth": 380.0,
				"required": 4
			}
		],
		"rewards": {
			"gold": 180,
			"items": {"titanium": 2},
			"summary": "+180G · 钛×2"
		}
	})

	templates.append({
		"id": "bounty_quality_catch",
		"category": "bounty",
		"title": "优质生物活捕委托",
		"brief": "前哨站生物舱征集高鲜度样本，请捕获 ★★☆ 以上品质海洋生物 2 次。",
		"objectives": [
			{
				"id": "catch_quality_twice",
				"label": "捕获 ★★☆ 以上海洋生物 2 次",
				"type": "event_count",
				"target": "quality_catch",
				"required": 2
			}
		],
		"rewards": {
			"gold": 110,
			"items": {"kelp": 2},
			"summary": "+110G · 海藻×2"
		}
	})

	templates.append({
		"id": "bounty_perfect_catch",
		"category": "bounty",
		"title": "完美标本活捕委托",
		"brief": "科考船需要无损生态标本，请完成 1 次 ★★★ 完美活捕。",
		"objectives": [
			{
				"id": "catch_perfect_once",
				"label": "完成 ★★★ 完美活捕 1 次",
				"type": "event_count",
				"target": "perfect_catch",
				"required": 1
			}
		],
		"rewards": {
			"gold": 150,
			"items": {"quartz": 1},
			"summary": "+150G · 石英×1"
		}
	})

	templates.append({
		"id": "bounty_mineral_harvest",
		"category": "bounty",
		"title": "海底矿物勘采补给",
		"brief": "前哨站急需基础矿材维护，请在海底采集矿物样本 4 次。",
		"objectives": [
			{
				"id": "collect_four_minerals",
				"label": "采集海底矿物 4 次",
				"type": "event_count",
				"target": "mineral_collected",
				"required": 4
			}
		],
		"rewards": {
			"gold": 95,
			"items": {"titanium": 1},
			"summary": "+95G · 钛×1"
		}
	})

	templates.append({
		"id": "bounty_bancho_supply",
		"category": "bounty",
		"title": "班乔料理补给订单",
		"brief": "远洋科考队员发来补给需求，请在班乔料理吧售出 2 份深海料理。",
		"objectives": [
			{
				"id": "serve_two_dishes",
				"label": "在班乔料理吧售出料理 2 份",
				"type": "event_count",
				"target": "dish_served",
				"required": 2,
				"nav_pos": Vector3(0, -3.5, 8),
				"nav_label": "班乔深海料理吧"
			}
		],
		"rewards": {
			"gold": 120,
			"items": {"copper": 1},
			"summary": "+120G · 铜×1"
		}
	})

	templates.append({
		"id": "bounty_sonar_sweep",
		"category": "bounty",
		"title": "远洋声呐回波勘测",
		"brief": "校准海域地形与生物回波，请释放 2 次远洋声呐勘测脉冲。",
		"objectives": [
			{
				"id": "ping_sonar_twice",
				"label": "释放声呐勘测 2 次",
				"type": "event_count",
				"target": "sonar_pinged",
				"required": 2
			}
		],
		"rewards": {
			"gold": 75,
			"items": {"kelp": 1},
			"summary": "+75G · 海藻×1"
		}
	})

	return templates
