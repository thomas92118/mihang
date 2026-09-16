extends CanvasLayer

signal start_requested(mode: String)
signal resume_requested
signal restart_requested
signal craft_requested(recipe: String)
signal pin_requested(recipe: String)

const INK := Color("e4f7f4")
const MUTED := Color("8eafb4")
const CYAN := Color("75e1d4")
const ORANGE := Color("ffb46c")
const PANEL := Color(0.012, 0.065, 0.085, 0.88)

var root: Control
var instruments: Control
var menus: Dictionary = {}
var oxygen_value: Label
var oxygen_unit: Label
var oxygen_bar: ProgressBar
var health_value: Label
var depth_value: Label
var home_value: Label
var status_value: Label
var target_value: Label
var equipment_value: Label
var weapon_bar_label: Label
var mission_title: Label
var mission_detail: Label
var resource_labels: Dictionary = {}
var craft_buttons: Dictionary = {}
var craft_inventory: Label
var win_title: Label
var win_desc: Label
var win_time: Label
var toast_label: Label
var toast_time := 0.0
var active_screen := "main"
var visor_material: ShaderMaterial
var pinned_panel: Panel
var pinned_title: Label
var pinned_progress: Label
var pin_buttons: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["PingFang SC", "Noto Sans CJK SC", "Heiti SC"])
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 16
	theme.set_color("font_color", "Label", INK)
	root.theme = theme
	_build_instruments()
	_build_main()
	_build_pause()
	_build_craft()
	_build_win()
	toast_label = _label(root, "", Rect2(-290, 130, 580, 44), 15, CYAN, Vector2(0.5, 0))
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.add_theme_stylebox_override("normal", _style(PANEL, Color(0.46, 0.88, 0.83, 0.35)))
	toast_label.hide()
	set_screen("main")

func _process(delta: float) -> void:
	if toast_time > 0.0:
		toast_time = maxf(0.0, toast_time - delta)
		toast_label.modulate.a = minf(toast_time * 2.0, 1.0)
		toast_label.visible = toast_time > 0.0 and active_screen == "play"

func _build_instruments() -> void:
	instruments = _full(root)

	# 潜水头盔内壁曲面暗角与呼吸凝雾 Shader
	var visor_rect := ColorRect.new()
	_place(visor_rect, instruments, Rect2())
	visor_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visor_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v_shader := Shader.new()
	v_shader.code = """shader_type canvas_item;
	uniform float breath : hint_range(0.0, 1.0) = 0.0;
	uniform float frost : hint_range(0.0, 1.0) = 0.0;
	void fragment() {
		vec2 uv = (UV - 0.5) * 2.0;
		float dist = dot(uv, uv);
		float mask = smoothstep(0.85, 1.55, dist) * 0.38;
		float mist = smoothstep(0.68, 1.48, dist) * (breath * 0.32 + frost * 0.68);
		vec3 tint = mix(vec3(0.01, 0.04, 0.06), vec3(0.78, 0.95, 1.0), mist / max(mask + mist, 0.001));
		COLOR = vec4(tint, clamp(mask + mist, 0.0, 0.68));
	}"""
	visor_material = ShaderMaterial.new()
	visor_material.shader = v_shader
	visor_rect.material = visor_material
	_label(instruments, "◈  ABYSSAL ECHO", Rect2(42, 28, 250, 28), 18, INK)
	_label(instruments, "深蓝回声  /  海洋科考协议", Rect2(43, 58, 290, 24), 12, MUTED)
	_line(instruments, Rect2(43, 93, 38, 2), CYAN)
	_label(instruments, "当前目标", Rect2(43, 106, 250, 20), 11, CYAN)
	mission_title = _label(instruments, "收集材料 · 修复救生舱信标", Rect2(43, 129, 340, 26), 15, INK)
	mission_detail = _label(instruments, "3 钛  /  2 铜  /  2 石英", Rect2(43, 158, 300, 24), 12, MUTED)

	var compass := _label(instruments, "·     ·     ·    DEPTH    ·     ·     ·", Rect2(-190, 22, 380, 25), 12, MUTED, Vector2(0.5, 0))
	compass.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	depth_value = _label(instruments, "012 m", Rect2(-150, 45, 300, 55), 38, INK, Vector2(0.5, 0))
	depth_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_value = _label(instruments, "浅海珊瑚礁区  /  水下", Rect2(-240, 101, 480, 24), 12, CYAN, Vector2(0.5, 0))
	status_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_label(instruments, "⌂  救生舱", Rect2(-253, 31, 210, 25), 13, CYAN, Vector2(1, 0)).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	home_value = _label(instruments, "18 m", Rect2(-253, 57, 210, 35), 23, INK, Vector2(1, 0))
	home_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label(instruments, "返回救生舱补氧 · 制作", Rect2(-303, 97, 260, 22), 12, MUTED, Vector2(1, 0)).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# 右上角配方置顶追踪面板 (Recipe Pinning HUD)
	pinned_panel = _panel(instruments, Rect2(-265, 126, 245, 54), Vector2(1, 0))
	pinned_panel.hide()
	pinned_title = _label(pinned_panel, "【配方追踪】", Rect2(12, 6, 225, 20), 11, CYAN)
	pinned_progress = _label(pinned_panel, "", Rect2(12, 27, 225, 20), 11, INK)

	var reticle := _label(instruments, "+", Rect2(-12, -16, 24, 32), 22, Color(0.83, 1, 0.98, 0.8), Vector2(0.5, 0.5))
	reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# 左侧生命支持面板
	var life := _panel(instruments, Rect2(42, -175, 260, 117), Vector2(0, 1))
	_label(life, "O₂", Rect2(17, 12, 55, 41), 26, CYAN)
	oxygen_value = _label(life, "90", Rect2(78, 8, 100, 48), 35, INK)
	oxygen_unit = _label(life, "秒  /  氧气", Rect2(166, 25, 87, 23), 11, MUTED)
	oxygen_bar = ProgressBar.new()
	_place(oxygen_bar, life, Rect2(19, 62, 222, 5))
	oxygen_bar.show_percentage = false
	oxygen_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	oxygen_bar.add_theme_stylebox_override("background", _style(Color(0.3, 0.6, 0.65, 0.14), Color.TRANSPARENT, 2))
	oxygen_bar.add_theme_stylebox_override("fill", _style(CYAN, Color.TRANSPARENT, 2))
	health_value = _label(life, "＋  生命 100", Rect2(18, 82, 150, 21), 12, MUTED)
	_label(life, "生命支持", Rect2(174, 82, 78, 21), 10, MUTED)

	# 右侧样本储存面板 (包含小鱼与海兽碎片采集统计)
	var supplies := _panel(instruments, Rect2(-490, -175, 450, 117), Vector2(1, 1))
	_label(supplies, "样本与战利品储存", Rect2(17, 11, 160, 24), 12, CYAN)
	_label(supplies, "INVENTORY", Rect2(320, 12, 110, 22), 10, MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var kinds := ["titanium", "copper", "quartz", "kelp", "fish_small", "shark_fragment", "abyss_fragment"]
	var names := ["钛", "铜", "石英", "海藻", "鲜鱼", "鲨齿", "晶核"]
	for index in range(kinds.size()):
		var x := 12.0 + float(index) * 61.0
		resource_labels[kinds[index]] = _label(supplies, "0", Rect2(x, 40, 54, 35), 22, INK)
		_label(supplies, names[index], Rect2(x, 79, 56, 21), 11, MUTED)

	# 底部中央装备与武器栏
	equipment_value = _label(instruments, "基础潜水装备", Rect2(-235, -162, 470, 22), 11, MUTED, Vector2(0.5, 1))
	equipment_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var weapon_panel := _panel(instruments, Rect2(-240, -136, 480, 42), Vector2(0.5, 1))
	weapon_bar_label = _label(weapon_panel, "[1 潜水刀]    2 破拆斧    3 声波脉冲枪", Rect2(10, 10, 460, 24), 13, CYAN)
	weapon_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	target_value = _label(instruments, "", Rect2(-300, -88, 600, 33), 17, INK, Vector2(0.5, 1))
	target_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var hints := _label(instruments, "WASD 移动   空格 上浮   C/Ctrl 下潜   Shift 加速   Q 涡流冲刺   R 武器攻击   1/2/3 武器   E 交互/捕食   F 探照灯   Tab 制作   Esc 暂停", Rect2(-640, -36, 1280, 22), 11, MUTED, Vector2(0.5, 1))
	hints.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _build_main() -> void:
	var menu := _menu("main", false)
	var shade := ColorRect.new()
	_place(shade, menu, Rect2())
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){ COLOR = vec4(0.005,0.035,0.055,0.90 * (1.0-smoothstep(0.28,1.05,UV.x))); }"
	var material := ShaderMaterial.new()
	material.shader = shader
	shade.material = material
	_label(menu, "◈   PELAGIC RESEARCH  /  深海探索计划", Rect2(68, 37, 550, 28), 12, MUTED)
	_label(menu, "01  /  广袤海域探险系统", Rect2(72, 168, 540, 27), 14, CYAN)
	_label(menu, "深蓝回声", Rect2(64, 203, 620, 108), 76, INK)
	_label(menu, "A B Y S S A L   E C H O", Rect2(73, 323, 650, 31), 21, CYAN)
	_line(menu, Rect2(74, 380, 44, 2), CYAN)
	_label(menu, "浅海珊瑚林 · 暮光大断崖 · 百米深渊地热喷口", Rect2(74, 400, 620, 39), 20, INK)
	_label(menu, "开放式多层级海底世界。丰富鱼群生态、掠食巨兽伏击、水下防身武装与深海捕食机制。\n选择适合你的潜航方式，开启未知的海洋探索。", Rect2(74, 448, 620, 56), 14, MUTED)
	_label(menu, "01 浅海珊瑚礁     02 暮光大陆坡     03 深渊地热裂谷", Rect2(74, 526, 650, 30), 13, INK)

	_button(menu, "生存挑战模式     →", Rect2(74, 580, 270, 54), func() -> void: start_requested.emit("survival"), true)
	_label(menu, "有限氧气 · 规避巨兽 · 制作武器与装备 · 修复信标通关", Rect2(76, 642, 270, 22), 12, MUTED)

	var explore_btn := _button(menu, "自由探险模式     ✦", Rect2(364, 580, 270, 54), func() -> void: start_requested.emit("explore"), false)
	explore_btn.add_theme_color_override("font_color", CYAN)
	_label(menu, "无限氧气 · 全武器配备 · 勘探浅海与百米深渊", Rect2(366, 642, 270, 22), 12, CYAN)

	_label(menu, "WASD 游动 · 鼠标观察 · R 键攻击 · 1/2/3 武器 · E 采集/食用 · F 探照灯 · Tab 制作", Rect2(75, 686, 650, 26), 12, MUTED)
	_label(menu, "原创海域生存与探险  /  GODOT × BLENDER", Rect2(73, -49, 650, 23), 10, MUTED, Vector2(0, 1))
	_label(menu, "EXPEDITION ACTIVE\n多层深海生态系统已上线", Rect2(-280, -101, 230, 61), 14, INK, Vector2(1, 1)).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _build_pause() -> void:
	var menu := _menu("pause")
	var card := _panel(menu, Rect2(-260, -205, 520, 410), Vector2(0.5, 0.5))
	_label(card, "DIVE LOG  /  潜航暂停", Rect2(36, 29, 450, 24), 12, CYAN)
	_label(card, "在此稍作停留", Rect2(35, 77, 450, 57), 34, INK)
	_label(card, "生命支持已暂停。准备好后，继续探索。", Rect2(37, 150, 445, 30), 14, MUTED)
	_button(card, "继续潜航     →", Rect2(36, 212, 448, 52), func() -> void: resume_requested.emit(), true)
	_button(card, "重新开始", Rect2(36, 280, 448, 48), func() -> void: restart_requested.emit())
	_label(card, "ESC 返回海底", Rect2(36, 353, 448, 23), 11, MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _build_craft() -> void:
	var menu := _menu("craft")
	var card := _panel(menu, Rect2(-380, -360, 760, 720), Vector2(0.5, 0.5))
	_label(card, "POD FABRICATOR  /  逃生舱制造台", Rect2(32, 18, 600, 24), 12, CYAN)
	_label(card, "为更深处做好准备", Rect2(30, 48, 620, 42), 28, INK)
	craft_inventory = _label(card, "钛 0  /  铜 0  /  石英 0  /  海藻 0  /  食用小鱼 0", Rect2(33, 90, 690, 26), 12, MUTED)
	_line(card, Rect2(32, 120, 696, 1), Color(0.47, 0.82, 0.81, 0.2))

	_recipe(card, "tank", "01", "高容量氧气瓶", "延长单次潜水时间至 150 秒", "2 钛 + 2 海藻", 128)
	_recipe(card, "fins", "02", "轻量脚蹼", "提升水下游动速度 50%", "1 钛 + 2 海藻", 188)
	_recipe(card, "rebreather", "03", "深海循环呼吸器", "抵消深水压强耗氧惩罚 · 百米深渊必需", "2 钛 + 1 铜 + 2 海藻", 248)
	_recipe(card, "axe", "04", "破拆战斧", "近战重型劈砍 · 165° 范围横扫群伤 · 70 基础伤害", "2 钛 + 1 铜", 308)
	_recipe(card, "sonic", "05", "声波脉冲枪", "数千米超远距贯穿音波打击 · 100 基础伤害 · 震退眩晕", "2 钛 + 2 石英 + 1 铜", 368)
	_recipe(card, "biomod_dash", "06", "生体模组·涡流突进", "按 Q 爆发突进 16 米紧急避咬 · 强化武装等级", "1 鲨齿碎片 + 2 钛", 428)
	_recipe(card, "reinforce_sharp", "07", "深铸武器·锋锐硬化", "精研近战刃口 · 全武器攻击力额外 +20", "1 鲨齿碎片 + 1 钛", 488)
	_recipe(card, "reinforce_sonic", "08", "深铸武器·晶体共鸣", "聚焦渊底脉冲 · 全武器攻击力额外 +35", "1 晶核碎片 + 1 石英", 548)
	_recipe(card, "beacon", "09", "修复求救信标", "完成求救通信 · 达成救援任务", "3 钛 + 2 铜 + 2 石英", 608)

	_button(card, "返回潜航", Rect2(32, 668, 160, 38), func() -> void: resume_requested.emit())
	_label(card, "点击【追踪】可在水下实时监视材料 · Tab / Esc 关闭", Rect2(202, 674, 520, 25), 11, MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _recipe(parent: Control, key: String, number: String, title: String, detail: String, cost: String, y: float) -> void:
	_label(parent, number, Rect2(33, y + 4, 45, 32), 15, CYAN)
	_label(parent, title, Rect2(82, y, 320, 24), 16, INK)
	_label(parent, detail, Rect2(82, y + 24, 420, 18), 11, MUTED)
	_label(parent, cost, Rect2(82, y + 42, 420, 18), 10, CYAN)
	pin_buttons[key] = _button(parent, "追踪", Rect2(518, y + 8, 86, 36), func() -> void: pin_requested.emit(key))
	craft_buttons[key] = _button(parent, "制作", Rect2(612, y + 8, 102, 36), func() -> void: craft_requested.emit(key), key == "beacon")

func _build_win() -> void:
	var menu := _menu("win")
	var card := _panel(menu, Rect2(-320, -236, 640, 472), Vector2(0.5, 0.5))
	_label(card, "●  EXPEDITION RECORD", Rect2(40, 34, 520, 30), 14, CYAN)
	win_title = _label(card, "深海收到了回声", Rect2(37, 98, 560, 61), 36, INK)
	win_desc = _label(card, "求救信标已重新上线。\n救援船正在驶来，你将平安返航。", Rect2(40, 185, 560, 72), 16, MUTED)
	win_time = _label(card, "本次潜航  00:00", Rect2(40, 282, 560, 28), 13, CYAN)
	_button(card, "再次探索     →", Rect2(40, 353, 560, 56), func() -> void: restart_requested.emit(), true)

func update_hud(data: Dictionary) -> void:
	if not is_instance_valid(oxygen_value):
		return
	var mode := str(data.get("mode", "survival"))
	var is_explore := mode == "explore"

	if is_explore:
		oxygen_value.text = "∞"
		oxygen_value.add_theme_color_override("font_color", CYAN)
		oxygen_unit.text = "探险  /  无限制"
		oxygen_bar.max_value = 100.0
		oxygen_bar.value = 100.0
		oxygen_bar.modulate = CYAN
		mission_title.text = "全海域自由漫游 · 无时限探险"
		mission_detail.text = "已勘测核心地标: %d / %d" % [int(data.get("landmarks_count", 0)), int(data.get("landmarks_total", 7))]
	else:
		var oxygen := float(data.get("oxygen", 90.0))
		var maximum := maxf(float(data.get("max_oxygen", 90.0)), 1.0)
		oxygen_value.text = "%02d" % ceili(maxf(oxygen, 0.0))
		oxygen_value.add_theme_color_override("font_color", ORANGE if oxygen < maximum * 0.25 else INK)
		oxygen_unit.text = "秒  /  氧气"
		oxygen_bar.max_value = maximum
		oxygen_bar.value = oxygen
		oxygen_bar.modulate = ORANGE if oxygen < maximum * 0.25 else Color.WHITE
		mission_title.text = "收集材料 · 修复救生舱信标"
		mission_detail.text = "3 钛  /  2 铜  /  2 石英"

	health_value.text = "＋  生命 %d" % ceili(float(data.get("health", 100.0)))
	var depth := maxf(float(data.get("depth", 0.0)), 0.0)
	depth_value.text = "%03d m" % roundi(depth)

	var biome: String = str(data.get("biome", "浅海生态区"))
	var oxygen_level := float(data.get("oxygen", 90.0))
	var max_oxygen_level := maxf(float(data.get("max_oxygen", 90.0)), 1.0)
	if not is_explore and oxygen_level < max_oxygen_level * 0.25:
		status_value.text = "氧气不足  /  请上浮或返回救生舱"
		status_value.add_theme_color_override("font_color", ORANGE)
	else:
		status_value.text = biome + ("  [探险模式]" if is_explore else "")
		status_value.add_theme_color_override("font_color", CYAN)

	home_value.text = "%d m" % roundi(float(data.get("distance_home", 0.0)))
	var target := str(data.get("target", ""))
	target_value.text = target
	var inventory: Dictionary = data.get("inventory", {})
	for kind: String in resource_labels:
		var resource_label: Label = resource_labels[kind]
		resource_label.text = str(inventory.get(kind, 0))
	craft_inventory.text = "钛 %d   /   铜 %d   /   石英 %d   /   海藻 %d   /   鲜鱼 %d   /   鲨齿碎片 %d   /   晶核 %d" % [
		int(inventory.get("titanium", 0)),
		int(inventory.get("copper", 0)),
		int(inventory.get("quartz", 0)),
		int(inventory.get("kelp", 0)),
		int(inventory.get("fish_small", 0)),
		int(inventory.get("shark_fragment", 0)),
		int(inventory.get("abyss_fragment", 0))
	]

	var tank := bool(data.get("tank", false))
	var fins := bool(data.get("fins", false))
	var rebreather := bool(data.get("rebreather", false))
	var biomod_dash := bool(data.get("biomod_dash", false))
	var dash_cd := float(data.get("dash_cooldown", 0.0))
	if is_explore:
		equipment_value.text = "深潜抗压服  /  动力推进脚蹼  /  循环呼吸器  /  涡流冲刺 [Q 就绪]"
	else:
		var eq_tank := "高容量氧气瓶" if tank else "基础氧气瓶"
		var eq_reb := "  /  循环呼吸器" if rebreather else ""
		var eq_dash := ""
		if biomod_dash:
			eq_dash = "  /  涡流突进 [Q 就绪]" if dash_cd <= 0.0 else "  /  涡流突进 [Q 冷却 %.1fs]" % dash_cd
		equipment_value.text = eq_tank + eq_reb + eq_dash

	# 更新配方置顶追踪面板 (Recipe Pinning HUD)
	var pinned_info: Dictionary = data.get("pinned_info", {})
	if pinned_info.is_empty():
		pinned_panel.hide()
	else:
		pinned_panel.show()
		var p_name: String = str(pinned_info.get("name", "配方"))
		var is_all_ready: bool = bool(pinned_info.get("all_ready", false))
		pinned_title.text = "【配方追踪】%s %s" % [p_name, "✦ 材料齐备" if is_all_ready else ""]
		pinned_title.add_theme_color_override("font_color", ORANGE if is_all_ready else CYAN)
		var items_arr: Array = pinned_info.get("details", [])
		var parts: Array[String] = []
		for it: Dictionary in items_arr:
			var ready_mark := "✓" if bool(it.get("ready", false)) else ""
			parts.append("%s %d/%d%s" % [str(it.get("name")), int(it.get("current")), int(it.get("required")), ready_mark])
		pinned_progress.text = "   ".join(parts)

	# 更新潜水面罩 Shader 呼吸与冰霜凝雾
	if is_instance_valid(visor_material):
		var is_sprint: bool = bool(data.get("sprinting", false))
		var breath_val: float = (0.55 if is_sprint else 0.12) * (0.5 + sin(Time.get_ticks_msec() * 0.006) * 0.5)
		var frost_val: float = clampf((22.0 - oxygen_level) / 22.0, 0.0, 1.0) if not is_explore else 0.0
		visor_material.set_shader_parameter("breath", breath_val)
		visor_material.set_shader_parameter("frost", frost_val)

	var weapons: Array = data.get("weapons", ["knife"])
	var has_axe: bool = weapons.has("axe")
	var has_sonic: bool = weapons.has("sonic")

	var tank_button: Button = craft_buttons["tank"]
	var fins_button: Button = craft_buttons["fins"]
	tank_button.disabled = tank
	tank_button.text = "已装备" if tank else "制作"
	fins_button.disabled = fins
	fins_button.text = "已装备" if fins else "制作"

	if craft_buttons.has("rebreather"):
		craft_buttons["rebreather"].disabled = rebreather
		craft_buttons["rebreather"].text = "已装备" if rebreather else "制作"
	if craft_buttons.has("biomod_dash"):
		craft_buttons["biomod_dash"].disabled = biomod_dash
		craft_buttons["biomod_dash"].text = "已激活" if biomod_dash else "制作"

	var pinned_key: String = str(pinned_info.get("recipe", ""))
	for k: String in pin_buttons:
		pin_buttons[k].text = "取消追踪" if k == pinned_key else "追踪"

	if craft_buttons.has("axe"):
		var axe_button: Button = craft_buttons["axe"]
		axe_button.disabled = has_axe
		axe_button.text = "已拥有" if has_axe else "制作"
	if craft_buttons.has("sonic"):
		var sonic_button: Button = craft_buttons["sonic"]
		sonic_button.disabled = has_sonic
		sonic_button.text = "已拥有" if has_sonic else "制作"

	if craft_buttons.has("reinforce_sharp"):
		var can_sharp: bool = int(inventory.get("shark_fragment", 0)) >= 1 and int(inventory.get("titanium", 0)) >= 1
		craft_buttons["reinforce_sharp"].disabled = not can_sharp
		craft_buttons["reinforce_sharp"].text = "深铸锻造" if can_sharp else "材料不足"

	if craft_buttons.has("reinforce_sonic"):
		var can_sonic: bool = int(inventory.get("abyss_fragment", 0)) >= 1 and int(inventory.get("quartz", 0)) >= 1
		craft_buttons["reinforce_sonic"].disabled = not can_sonic
		craft_buttons["reinforce_sonic"].text = "深铸锻造" if can_sonic else "材料不足"

	# 更新底部武器状态栏与强化等级
	var cur_w: String = str(data.get("current_weapon", "knife"))
	var w_level: int = int(data.get("weapon_level", 0))
	var w_bonus: float = float(data.get("damage_bonus", 0.0))
	var k_txt: String = "【1 潜水刀】" if cur_w == "knife" else "1 潜水刀"
	var a_txt: String = ("【2 破拆斧】" if cur_w == "axe" else "2 破拆斧") + ("" if has_axe else " (未制作)")
	var s_txt: String = ("【3 声波脉冲枪】" if cur_w == "sonic" else "3 声波脉冲枪") + ("" if has_sonic else " (未制作)")
	var upgrade_info: String = "   ·   武装强化 Lv.%d (+%d 伤)" % [w_level, int(w_bonus)] if w_level > 0 else ""
	weapon_bar_label.text = "%s      %s      %s%s" % [k_txt, a_txt, s_txt, upgrade_info]

	var seconds := int(data.get("elapsed", 0.0))
	if is_explore:
		win_title.text = "全海域勘测已完成"
		win_desc.text = "你已探明浅海、暮光海沟与百米深渊的热液喷口全部核心地标。\n深蓝海域向勇敢的探险家致敬！"
		win_time.text = "本次探险  %02d:%02d  /  勘测度 100%%" % [floori(float(seconds) / 60.0), seconds % 60]
	else:
		win_title.text = "深海收到了回声"
		win_desc.text = "求救信标已重新上线。\n救援船正在驶来，你将平安返航。"
		win_time.text = "本次潜航  %02d:%02d  /  救援协议已启动" % [floori(float(seconds) / 60.0), seconds % 60]

func set_screen(screen: String) -> void:
	active_screen = screen
	instruments.visible = screen in ["play", "pause", "craft"]
	for key: String in menus:
		var menu: Control = menus[key]
		menu.visible = key == screen
		menu.mouse_filter = Control.MOUSE_FILTER_STOP if menu.visible else Control.MOUSE_FILTER_IGNORE
	if screen != "play":
		toast_label.hide()

func toast(message: String) -> void:
	toast_label.text = message
	toast_time = 3.6
	toast_label.modulate.a = 1.0
	toast_label.visible = active_screen in ["play", "craft"]

func _full(parent: Node) -> Control:
	var control := Control.new()
	parent.add_child(control)
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return control

func _menu(key: String, dim: bool = true) -> Control:
	var control := _full(root)
	menus[key] = control
	if dim:
		var shade := ColorRect.new()
		control.add_child(shade)
		shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		shade.color = Color(0.005, 0.025, 0.04, 0.7)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return control

func _place(control: Control, parent: Node, rect: Rect2, anchor := Vector2.ZERO) -> void:
	parent.add_child(control)
	control.anchor_left = anchor.x
	control.anchor_right = anchor.x
	control.anchor_top = anchor.y
	control.anchor_bottom = anchor.y
	control.offset_left = rect.position.x
	control.offset_top = rect.position.y
	control.offset_right = rect.end.x
	control.offset_bottom = rect.end.y

func _label(parent: Node, text: String, rect: Rect2, font_size: int, color: Color, anchor := Vector2.ZERO) -> Label:
	var label := Label.new()
	_place(label, parent, rect, anchor)
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _style(background: Color, border: Color = Color.TRANSPARENT, radius: int = 5) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	return style

func _panel(parent: Node, rect: Rect2, anchor := Vector2.ZERO) -> Panel:
	var panel := Panel.new()
	_place(panel, parent, rect, anchor)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(PANEL, Color(0.45, 0.82, 0.82, 0.22)))
	return panel

func _line(parent: Node, rect: Rect2, color: Color) -> void:
	var line := ColorRect.new()
	_place(line, parent, rect)
	line.color = color
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _button(parent: Node, text: String, rect: Rect2, callback: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	_place(button, parent, rect)
	button.text = text
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color("082c36") if primary else INK)
	button.add_theme_color_override("font_hover_color", Color("082c36") if primary else Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color("082c36") if primary else Color.WHITE)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.add_theme_stylebox_override("normal", _style(CYAN if primary else Color(0.1, 0.3, 0.34, 0.24), CYAN if primary else Color(0.45, 0.82, 0.82, 0.35)))
	button.add_theme_stylebox_override("hover", _style(Color("a4f5e4") if primary else Color(0.13, 0.42, 0.46, 0.5), CYAN))
	button.add_theme_stylebox_override("pressed", _style(Color("59baaf") if primary else Color(0.1, 0.26, 0.3, 0.8), CYAN))
	button.add_theme_stylebox_override("disabled", _style(Color(0.13, 0.23, 0.27, 0.25), Color(0.4, 0.7, 0.7, 0.15)))
	button.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, INK))
	button.pressed.connect(callback)
	return button
