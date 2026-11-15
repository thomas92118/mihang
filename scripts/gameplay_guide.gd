extends RefCounted
## Structured gameplay encyclopedia, 6-step interactive first-voyage onboarding,
## and one-time contextual discovery tips persisted in user://onboarding_state.cfg.

const SAVE_PATH := "user://onboarding_state.cfg"
const TIP_COOLDOWN_SECONDS := 12.0
const MOTION_HORIZ_THRESHOLD := 8.0
const MOTION_VERT_THRESHOLD := 1.5
const MAX_FRAME_MOTION := 18.0
const COMPLETION_HOLD_SECONDS := 2.6

const CHAPTERS: Array[Dictionary] = [
	{
		"id": "basics",
		"number": "01",
		"title": "潜航基础与双模式",
		"subtitle": "立体游动、视角控制与氧气生命循环",
		"summary": "掌握三维水域推进、探照灯色彩还原以及自由探险与生存航程两套核心规则。",
		"items": [
			{
				"heading": "三维推进与多角度观察",
				"keys": "WASD / 空格/Ctrl / Shift / K",
				"body": "使用 WASD 前后推进与左右转向，按 空格 上浮、Ctrl 下潜，按住 Shift 冲刺游动。按 K 循环切换 7 种观赏视角，按住鼠标右键自由环绕观察，按 Home 一键回正。"
			},
			{
				"heading": "深海照明与便携助推器",
				"keys": "F / H / P",
				"body": "水深增加后红光会先于蓝光衰减，按 F 开启强力潜水探照灯可穿透幽暗并还原礁石与生物本色；按 H 开关手持助推器大幅提升巡航速度；按 P 随时切换人鱼与科考潜水员形态。"
			},
			{
				"heading": "自由探险 vs 生存航程",
				"keys": "双模式差异",
				"body": "【自由探险】拥有无限氧气、免疫伤害、无限打捞无人机与预解锁装备，专注漫游全收集；【生存航程】初始 90 秒氧气与 100 点生命，深水高压会加快耗氧，遇险将在当前海域就地应急苏生。"
			},
			{
				"heading": "四大氧气与生命补给途径",
				"keys": "E 互动补给",
				"body": "生存模式下可通过：① 上浮至海面；② 靠近逃生舱母港 7m 安全区；③ 靠近已激活的科考前哨站；④ 对准海底发光巨砗磲按 E 触发气泡泉涌（+35 秒氧气 / +15 生命）或按 E 捕食发光小金鱼（+25 生命 / +20 氧气）。"
			}
		],
		"tip_note": "提示：随时可按 L 打开本潜航指南，或在暂停菜单进入操作设置调整手柄与触控灵敏度。"
	},
	{
		"id": "navigation",
		"number": "02",
		"title": "海图勘测与洋流跃迁",
		"subtitle": "九大无缝海域、声呐脉冲与前哨传送网",
		"summary": "在 1800m × 1800m、纵深 600m 的开放海域中揭开迷雾，建立远洋科考航线。",
		"items": [
			{
				"heading": "广域声呐勘测脉冲",
				"keys": "N 声呐扫描",
				"body": "按 N 释放 220m 至 340m 广域声呐回波，立即揭开周边战争迷雾，并在海图与视野中标记隐藏的生态地标、未激活前哨站与远古深海遗珍。"
			},
			{
				"heading": "全域等深线海图与标点",
				"keys": "M 全域海图",
				"body": "按 M 打开 24×24 扇区等深线海图，支持缩放平移、选点设置 3D 航向标点。设置标点后顶部 360° 罗盘与画面指引箭头会实时引导目标方向与距离。"
			},
			{
				"heading": "科考前哨站与快速跃迁",
				"keys": "E 激活中继 / M 跃迁",
				"body": "靠近散落远洋的 6 座科考前哨站按 E 激活声呐中继塔（获赠 150G），即可点亮周边 290m 海图，并将其升级为前线补氧安全区、野外制造台与洋流快速跃迁节点。"
			},
			{
				"heading": "二十四景地标与远古遗珍",
				"keys": "E 收集遗珍",
				"body": "探明 24 处海洋地标可解锁对应跃迁点；按 E 收集 12 处远古遗珍每处可获 120G、全系材料 +1、全武器攻击 +10 与泳速 +4%，随勘测度晋升五阶探索家头衔。"
			}
		],
		"tip_note": "提示：母港、已激活的科考前哨站以及已发现的生态地标之间，均可通过 M 海图随时免费洋流跃迁。"
	},
	{
		"id": "crafting",
		"number": "03",
		"title": "采集、制造与成长",
		"subtitle": "海底矿物搜集、逃生舱工作台与双轨强化",
		"summary": "搜集浅礁至海沟的关键资源，升级耐压潜水装具并锻造高阶深海武装。",
		"items": [
			{
				"heading": "基础矿物与配方置顶追踪",
				"keys": "E 采集 / Tab 制造台",
				"body": "准星对准钛、铜、石英、海藻按 E 采集。按 Tab 打开制造台可点击「追踪」将目标配方置顶在右上角 HUD，潜航途中实时查看材料收集进度。"
			},
			{
				"heading": "核心生存装具升级",
				"keys": "Tab 装备制造",
				"body": "优先推荐制作【高容量氧气瓶】（续航提升至 150 秒）、【轻量脚蹼】（泳速 +50%）、【深海循环呼吸器】（抵消深水额外水压耗氧）以及【生体模组·涡流突进】（按 Q 急速位移 16m 闪避）。"
			},
			{
				"heading": "巨兽碎片吸收与深铸锻造",
				"keys": "E 吸收 / Tab 深铸",
				"body": "击败暗礁巨鲨与深渊鮟鱇会掉落高亮【巨鲨齿骨碎片】与【深渊巨兽晶核】：按 E 拾取现场直接提升 +12 或 +25 攻击力，还可在 Tab 制造台进行【锋锐硬化】与【晶体共鸣】二次深铸叠加伤害。"
			}
		],
		"tip_note": "提示：修复求救信标属于返航通信里程碑，完成后仍可点击继续探索推进深渊主线。"
	},
	{
		"id": "combat",
		"number": "04",
		"title": "深海武装与能量护盾",
		"subtitle": "四类战术武器、3 秒蓄力静滞与单手格挡",
		"summary": "灵活切换近战横扫、远距激光、范围静滞冻结与左臂全息护盾应对深海掠食者。",
		"items": [
			{
				"heading": "近战利器：战术刀与破拆战斧",
				"keys": "1—4 切枪 / R 攻击",
				"body": "按 1 装备潜水战术刀（快速刺击，击杀获 ★★☆ 良等食材）；解锁后按 2 装备破拆战斧，具备 165° 超广角横扫、70 点高额基础伤害与强力击退，适合应对群居猎手。"
			},
			{
				"heading": "蓝光静滞枪与双倍镜测距",
				"keys": "按 3 / R 蓄力 / T/Y",
				"body": "按 3 装备蓝光静滞枪：短按 R 发射 2000m 瞬时激光（基础伤害 100）；按住 R 蓄力满 3 秒后松开发射静滞光球，命中展开 12m 半径、持续 6 秒的静滞冻结场！按 T 精准瞄准，按 Y 开启 8× 远距测距镜。"
			},
			{
				"heading": "左臂单手全息能量护盾",
				"keys": "C 护盾开关",
				"body": "按 C 在左臂常驻展开六边形能量护盾（再按 C 收起）。展开期间可 100% 抵挡正前方捕食者扑咬伤害，且与右手全部四种武器完全独立共存，支持举盾挥砍或蓄力射击。"
			},
			{
				"heading": "光标指示枪：战宠集火指挥",
				"keys": "4 指示枪 / Z 召回",
				"body": "按 4 切换零伤害光标指示枪，射击可在目标身上锁定持久脉动红点，指挥身边所有契约战宠全速扑击围攻；按 Z 鸣哨一键召回所有伙伴回到后方列队护卫。"
			}
		],
		"tip_note": "提示：暂停、打开菜单、切换武器或上下载具会自动安全取消未发射的静滞蓄力。"
	},
	{
		"id": "sushi",
		"number": "05",
		"title": "三星捕捞与深海料理",
		"subtitle": "捕鱼品质评定、无人机打捞、寿司吧与图鉴",
		"summary": "无损活捕高星海洋生物，经营班乔深海料理吧获取金币与永久属性成长。",
		"items": [
			{
				"heading": "捕鱼星级评价机制（★ ~ ★★★）",
				"keys": "E 捕获 / V 无人机",
				"body": "★☆☆ 破损：用战斧、激光或鱼雷直接轰杀（1 份生肉）；★★☆ 良等：用战术刀精准刺杀（2 份生肉）；★★★ 完美：在静滞冻结状态下捕获，或靠近受控/残血生物按 V 召唤柯布拉无人机浮力袋无损回收（4 份生肉 + 双倍素材）。"
			},
			{
				"heading": "班乔深海料理吧与夜间营业",
				"keys": "B 料理与商店",
				"body": "按 B 打开料理吧，可将鲜鱼、生肉、海藻、骨齿、兽皮与甲壳烹制四大招牌寿司，售出赚取金币并永久提升氧气上限、生命上限、全武器伤害、无人机配额与负重上限；亦支持一键售出全部富余渔获。"
			},
			{
				"heading": "玛琳卡三星图鉴与柯布拉商店",
				"keys": "B 图鉴与扩容",
				"body": "自动收录全海域 13 大物种最高星级，每张 ★★★ 完美图鉴使全部料理售价永久 +12%。矿物与食材均具重量（初始上限 40kg），超重会减速，可在 B 面板商店用金币购买扩容生态箱、浓缩氧气胶囊与超导涂层。"
			}
		],
		"tip_note": "提示：生存模式下无人机初始拥有 3 次打捞配额，每次返回逃生舱母港会自动补满。"
	},
	{
		"id": "companions",
		"number": "06",
		"title": "猛兽驯服与深海潜艇",
		"subtitle": "20 槽位契约战宠编队与重装深潜载具",
		"summary": "用静滞光球驯服深海巨兽组建护航战队，或驾驶武装深潜艇穿越高压海沟。",
		"items": [
			{
				"heading": "猛兽与传奇领主契约驯服",
				"keys": "R 蓄力静滞 / E 契约",
				"body": "普通猛兽（暗礁鲨、幽影海狼、海蜘蛛等）被静滞球冻结后靠近按 E 即可直接驯服；四大深渊领主需先削减至 35% 生命值以下，再用静滞球冻结并靠近按 E 缔结契约。"
			},
			{
				"heading": "战力倍增编队与坐骑驾乘",
				"keys": "G 骑乘 / O 应援板 / Z",
				"body": "最多可契约 20 只伙伴，每多契约 1 只全队攻击力翻倍（2^(N-1) 倍率）且双向绝对免伤！按 G 骑乘或离鞍，按 O 打开生物应援板管理出战/收纳，按 Z 一键召回列队。"
			},
			{
				"heading": "深海潜艇驾驶与车载鱼雷",
				"keys": "E 登舰 / W/S / A/D",
				"body": "前往碧蓝晶簇海盆或深渊重装造船厂，靠近潜艇按 E 登舰。潜艇拥有独立耐压装甲，WASD 推进转向、空格/Ctrl 升降、Shift 加速、R 发射车载鱼雷或脉冲炮（微型潜艇支持 T/Y 电磁瞄准镜）。"
			}
		],
		"tip_note": "提示：随行伙伴会在 10m 内自动防卫反击来袭野怪，清剿完毕后自动归队。"
	},
	{
		"id": "endgame",
		"number": "07",
		"title": "四大领主与终章逃生",
		"subtitle": "远古深海母树苏醒与中央逃生控制台",
		"summary": "征服四方海域霸主解除极渊封印，集齐三大母树圣物完成星际跃迁归航。",
		"items": [
			{
				"heading": "第一步：平息或驯服四大深渊领主",
				"keys": "击败或残血驯服",
				"body": "探索四方领地挑战【深渊水龙】、【风暴飞鱼】、【深渊巨章】与【远古灵龟】。无论是将其正面击败，还是在残血（<35% 生命）时静滞契约驯服，均计入领主平息进度。"
			},
			{
				"heading": "第二步：潜入远古深海母树圣所",
				"keys": "E 采摘三大圣物",
				"body": "四大领主悉数平息后，极渊海域将苏醒高达 70m 的远古深海母树。前往母树内部圣所，按 E 依次搜集【母树生命精华】、【远古星核源石】与【深海启迪之种】三件核心圣物。"
			},
			{
				"heading": "第三步：制作深海跃迁逃逸器",
				"keys": "返回母港按 E 通关",
				"body": "集齐 3 件母树圣物后返回逃生舱基地，靠近中央逃生控制台按 E 制作【深海跃迁逃逸器】，即可激发星际跃迁引擎达成终章胜利！达成终章后仍可点击「继续探索」无限畅游九大海域。"
			}
		],
		"tip_note": "提示：左上角潜航日志与 M 海图会全程动态追踪领主进度与母树圣所方位。"
	}
]

const ONBOARDING_STEPS: Array[Dictionary] = [
	{
		"id": "swim",
		"title": "立体潜航与视野",
		"instruction": "推动 WASD 向前巡游并转动视角观察，按 空格 上浮、Ctrl 下潜体验立体游动。"
	},
	{
		"id": "light_shield",
		"title": "深海照明与护盾",
		"instruction": "按 F 开启潜水探照灯照亮礁石本色，或按 C 展开左臂单手能量护盾（按 Shift 可加速）。"
	},
	{
		"id": "sonar",
		"title": "广域声呐勘测",
		"instruction": "按 N 释放广域声呐脉冲，穿透迷雾标记周边生态地标、科考前哨站与远古遗珍。"
	},
	{
		"id": "sea_chart",
		"title": "等深线海图导航",
		"instruction": "按 M 打开全域等深线海图查看点亮扇区与标点功能，再按 M 或 Esc 返回潜航。"
	},
	{
		"id": "gather",
		"title": "海底采集与补给",
		"instruction": "靠近礁石矿物、小金鱼或发光巨砗磲按 E 采集补氧（逃生舱 7m 内自动恢复氧气）。",
		"instruction_survival": "靠近礁石矿物、小金鱼或发光巨砗磲按 E 采集补氧（逃生舱 7m 内自动恢复氧气）。",
		"instruction_explore": "靠近海底矿物、远古遗珍或科考前哨站按 E 互动，或按 3 装备蓝光静滞枪体验射击。"
	},
	{
		"id": "workbench",
		"title": "工作台与潜航指南",
		"instruction": "按 Tab 打开制造台查看装备与配方追踪（或按 B 查看料理图鉴）；随时按 L 打开潜航指南。"
	}
]

const CONTEXTUAL_TIPS := {
	"tip_sonic_charge": "【潜航提示】蓝光静滞枪：短按 R 发射激光；按住 3 秒后松开发射静滞球冻结范围内生物，按 T/Y 切换瞄准镜。",
	"tip_tame_or_salvage": "【潜航提示】目标已静滞冻结！靠近按 E 可缔结契约驯服为伙伴，或按 V 召唤无人机气球无损活捕（★★★ 完美品质）。",
	"tip_sushi_marinca": "【潜航提示】已获得深海食材 · 按 B 打开班乔料理吧烹饪永久属性料理，并点亮玛琳卡三星图鉴加成。",
	"tip_overweight": "【潜航提示】背包负重超限已降低泳速 · 按 B 可一键料理售出富余渔获，或在商店购买扩容生态箱。",
	"tip_outpost_discover": "【潜航提示】发现远洋科考前哨站 · 靠近中继塔按 E 激活，解锁前线补氧安全区、制造台与海图跃迁。",
	"tip_submarine_dock": "【潜航提示】发现深海潜艇 · 靠近船体按 E 登舰驾驶，具备耐压装甲与车载鱼雷武器系统。",
	"tip_marker_command": "【潜航提示】光标指示枪：发射红点标记目标可指挥全部契约伙伴集火围攻；按 Z 一键召回列队。"
}

const EVENT_TO_STEP := {
	"lamp_toggled": "light_shield",
	"shield_toggled": "light_shield",
	"sonar_pinged": "sonar",
	"resource_collected": "gather",
	"fish_eaten": "gather",
	"clam_activated": "gather",
	"outpost_activated": "gather",
	"relic_collected": "gather",
	"loot_collected": "gather",
	"craft_opened": "workbench",
	"sushi_opened": "workbench",
	"guide_opened": "workbench"
}

var persist_enabled: bool = true
var save_path: String = SAVE_PATH
var mode: String = "survival"
var onboarding_completed: bool = false
var onboarding_skipped: bool = false
var session_active: bool = false
var current_step_index: int = 0
var completed_flags: Dictionary = {}
var seen_tips: Dictionary = {}
var horiz_moved: float = 0.0
var vert_moved: float = 0.0
var map_visited_in_session: bool = false
var tip_cooldown: float = 0.0
var completion_banner_timer: float = 0.0

static func get_chapters() -> Array[Dictionary]:
	return CHAPTERS

func _init(enable_persist: bool = true, custom_path: String = SAVE_PATH) -> void:
	persist_enabled = enable_persist
	save_path = custom_path
	if persist_enabled:
		load_state()

func load_state() -> void:
	if not persist_enabled:
		return
	var config := ConfigFile.new()
	if config.load(save_path) != OK:
		return
	onboarding_completed = bool(config.get_value("onboarding", "completed", false))
	onboarding_skipped = bool(config.get_value("onboarding", "skipped", false))
	current_step_index = clampi(int(config.get_value("onboarding", "step_index", 0)), 0, ONBOARDING_STEPS.size() - 1)
	horiz_moved = maxf(0.0, float(config.get_value("onboarding", "horiz_moved", 0.0)))
	vert_moved = maxf(0.0, float(config.get_value("onboarding", "vert_moved", 0.0)))
	completed_flags.clear()
	var saved_flags: Variant = config.get_value("onboarding", "completed_flags", {})
	if saved_flags is Dictionary:
		for key in saved_flags:
			if bool(saved_flags[key]):
				completed_flags[str(key)] = true
	seen_tips.clear()
	var saved_tips: Variant = config.get_value("tips", "seen_tips", {})
	if saved_tips is Dictionary:
		for key in saved_tips:
			if bool(saved_tips[key]):
				seen_tips[str(key)] = true
	_advance_completed_steps()

func save_state() -> void:
	if not persist_enabled:
		return
	var config := ConfigFile.new()
	config.set_value("onboarding", "completed", onboarding_completed)
	config.set_value("onboarding", "skipped", onboarding_skipped)
	config.set_value("onboarding", "step_index", current_step_index)
	config.set_value("onboarding", "horiz_moved", horiz_moved)
	config.set_value("onboarding", "vert_moved", vert_moved)
	config.set_value("onboarding", "completed_flags", completed_flags.duplicate())
	config.set_value("tips", "seen_tips", seen_tips.duplicate())
	var err: Error = config.save(save_path)
	if err != OK:
		push_warning("无法保存引导进度：%s" % error_string(err))

func start_voyage(chosen_mode: String) -> void:
	set_mode(chosen_mode)
	completion_banner_timer = 0.0
	if not onboarding_completed and not onboarding_skipped:
		session_active = true
		_advance_completed_steps()
	else:
		session_active = false

func set_mode(chosen_mode: String) -> void:
	mode = "explore" if chosen_mode == "explore" else "survival"

func tick(delta: float) -> void:
	var dt := maxf(0.0, delta)
	if tip_cooldown > 0.0:
		tip_cooldown = maxf(0.0, tip_cooldown - dt)
	if completion_banner_timer > 0.0:
		completion_banner_timer = maxf(0.0, completion_banner_timer - dt)
		if completion_banner_timer <= 0.0 and onboarding_completed:
			session_active = false

func record_motion(delta_pos: Vector3) -> Dictionary:
	var result := _empty_result()
	if not session_active or onboarding_completed or onboarding_skipped:
		return result
	if bool(completed_flags.get("swim", false)):
		return result
	var horiz := Vector2(delta_pos.x, delta_pos.z).length()
	var vert := absf(delta_pos.y)
	if horiz > MAX_FRAME_MOTION or vert > MAX_FRAME_MOTION:
		return result
	if horiz <= 0.0001 and vert <= 0.0001:
		return result
	horiz_moved = minf(MOTION_HORIZ_THRESHOLD, horiz_moved + horiz)
	vert_moved = minf(MOTION_VERT_THRESHOLD, vert_moved + vert)
	if horiz_moved >= MOTION_HORIZ_THRESHOLD and vert_moved >= MOTION_VERT_THRESHOLD:
		var transition := _mark_step_completed("swim")
		result["step_advanced"] = transition["step_advanced"]
		result["completed_now"] = transition["completed_now"]
		result["step_title"] = _current_step_title()
	return result

func notify_event(event_id: String, context: Dictionary = {}) -> Dictionary:
	var result := _empty_result()
	if session_active and not onboarding_completed and not onboarding_skipped:
		var step_id := ""
		if event_id == "map_opened":
			map_visited_in_session = true
		elif event_id == "map_closed":
			if map_visited_in_session:
				step_id = "sea_chart"
		elif event_id == "sonic_fired":
			if mode == "explore":
				step_id = "gather"
		elif EVENT_TO_STEP.has(event_id):
			step_id = str(EVENT_TO_STEP[event_id])

		if step_id != "" and not bool(completed_flags.get(step_id, false)):
			var transition := _mark_step_completed(step_id)
			result["step_advanced"] = transition["step_advanced"]
			result["completed_now"] = transition["completed_now"]
			result["step_title"] = _current_step_title()

	var candidate_tip := _match_contextual_tip(event_id, context)
	if candidate_tip != "" and CONTEXTUAL_TIPS.has(candidate_tip):
		if not bool(seen_tips.get(candidate_tip, false)) and tip_cooldown <= 0.0:
			seen_tips[candidate_tip] = true
			tip_cooldown = TIP_COOLDOWN_SECONDS
			result["tip_id"] = candidate_tip
			result["tip_text"] = str(CONTEXTUAL_TIPS[candidate_tip])
			save_state()

	return result

func skip_onboarding() -> void:
	onboarding_skipped = true
	session_active = false
	completion_banner_timer = 0.0
	save_state()

func restart_onboarding(chosen_mode: String = "") -> void:
	if chosen_mode != "":
		set_mode(chosen_mode)
	onboarding_completed = false
	onboarding_skipped = false
	completed_flags.clear()
	horiz_moved = 0.0
	vert_moved = 0.0
	map_visited_in_session = false
	current_step_index = 0
	completion_banner_timer = 0.0
	session_active = true
	save_state()

func is_onboarding_visible() -> bool:
	return (session_active and not onboarding_completed and not onboarding_skipped) or completion_banner_timer > 0.0

func get_hud_payload(pointer_locked: bool = true, is_web: bool = false) -> Dictionary:
	var total := ONBOARDING_STEPS.size()
	var completed_banner := completion_banner_timer > 0.0 and onboarding_completed
	var idx := clampi(current_step_index, 0, total - 1)
	var step: Dictionary = ONBOARDING_STEPS[idx]
	var step_id := str(step["id"])
	var title := "✦ 初航实操引导已完成" if completed_banner else str(step["title"])
	var instruction := "你已掌握基础潜航闭环！随时按 L 打开潜航指南查阅进阶玩法。"
	if not completed_banner:
		if step_id == "gather":
			var key := "instruction_explore" if mode == "explore" else "instruction_survival"
			instruction = str(step.get(key, step["instruction"]))
		else:
			instruction = str(step["instruction"])

	var done_count := 0
	for entry: Dictionary in ONBOARDING_STEPS:
		if bool(completed_flags.get(str(entry["id"]), false)):
			done_count += 1
	var swim_partial := 0.0
	if not bool(completed_flags.get("swim", false)):
		swim_partial = 0.5 * clampf(horiz_moved / MOTION_HORIZ_THRESHOLD, 0.0, 1.0) + 0.5 * clampf(vert_moved / MOTION_VERT_THRESHOLD, 0.0, 1.0)
	var progress_ratio := 1.0 if completed_banner or onboarding_completed else clampf((float(done_count) + swim_partial) / float(maxi(1, total)), 0.0, 1.0)

	var sub_hint := ""
	if completed_banner:
		sub_hint = "进度 %d/%d · 即将切换为静谧探索视图" % [total, total]
	elif step_id == "swim":
		sub_hint = "巡游 %.0f/%.0fm · 升降 %.1f/%.1fm" % [horiz_moved, MOTION_HORIZ_THRESHOLD, vert_moved, MOTION_VERT_THRESHOLD]
		if is_web and not pointer_locked:
			sub_hint += " · 点击锁定视角"
		else:
			sub_hint += " · L 指南"
	else:
		sub_hint = "步骤 %d/%d · L 打开潜航指南" % [idx + 1, total]

	return {
		"active": is_onboarding_visible(),
		"completed_banner": completed_banner,
		"step_index": total if completed_banner else (idx + 1),
		"step_total": total,
		"step_id": "completed" if completed_banner else step_id,
		"title": title,
		"instruction": instruction,
		"progress_ratio": progress_ratio,
		"sub_hint": sub_hint,
		"onboarding_completed": onboarding_completed,
		"onboarding_skipped": onboarding_skipped
	}

func _mark_step_completed(step_id: String) -> Dictionary:
	var prev_index := current_step_index
	var was_completed := onboarding_completed
	completed_flags[step_id] = true
	_advance_completed_steps()
	var completed_now := (not was_completed) and onboarding_completed
	if completed_now:
		completion_banner_timer = COMPLETION_HOLD_SECONDS
	var advanced := completed_now or (current_step_index != prev_index)
	save_state()
	return {
		"step_advanced": advanced,
		"completed_now": completed_now
	}

func _advance_completed_steps() -> void:
	if onboarding_completed:
		current_step_index = ONBOARDING_STEPS.size() - 1
		return
	var idx := 0
	while idx < ONBOARDING_STEPS.size():
		var sid := str(ONBOARDING_STEPS[idx]["id"])
		if not bool(completed_flags.get(sid, false)):
			break
		idx += 1
	if idx >= ONBOARDING_STEPS.size():
		onboarding_completed = true
		current_step_index = ONBOARDING_STEPS.size() - 1
	else:
		current_step_index = idx

func _current_step_title() -> String:
	if onboarding_completed:
		return "✦ 初航实操引导已完成"
	var idx := clampi(current_step_index, 0, ONBOARDING_STEPS.size() - 1)
	return str(ONBOARDING_STEPS[idx]["title"])

func _match_contextual_tip(event_id: String, context: Dictionary) -> String:
	match event_id:
		"weapon_equipped":
			var weapon := str(context.get("weapon", ""))
			if weapon == "sonic":
				return "tip_sonic_charge"
			if weapon in ["marker_gun", "marker"] and int(context.get("companion_count", 0)) > 0:
				return "tip_marker_command"
		"stasis_tameable_hit":
			return "tip_tame_or_salvage"
		"ingredients_gained":
			if int(context.get("total_food", 0)) >= 2:
				return "tip_sushi_marinca"
		"overweight_entered":
			return "tip_overweight"
		"outpost_approached":
			return "tip_outpost_discover"
		"submarine_approached":
			return "tip_submarine_dock"
	return ""

static func _empty_result() -> Dictionary:
	return {
		"step_advanced": false,
		"completed_now": false,
		"step_title": "",
		"tip_id": "",
		"tip_text": ""
	}
