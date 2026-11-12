extends CanvasLayer

const WorldMap = preload("res://scripts/world_map.gd")

signal start_requested(mode: String)
signal resume_requested
signal restart_requested
signal craft_requested(recipe: String)
signal pin_requested(recipe: String)
signal sushi_cook_requested(dish_id: String)
signal sushi_serve_all_requested
signal cobra_buy_requested(item_id: String)
signal open_sushi_requested
signal mount_board_select_requested(index: int)
signal mount_board_select_all_requested
signal mount_board_store_all_requested
signal map_waypoint_set(world_xz: Vector2)
signal map_waypoint_cleared
signal fast_travel_requested(target_id: String, world_pos: Vector3, target_name: String)
signal sonar_ping_requested

const INK := Color("f4fcff")
const MUTED := Color("9ce0f4")
const CYAN := Color("38f6e8")
const ORANGE := Color("ff9e38")
const AMBER_GOLD := Color("ffbe42")
const PANEL := Color(0.035, 0.14, 0.26, 0.86)
const WARM_PANEL := Color(0.11, 0.09, 0.07, 0.90)

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
var hit_marker: Label
var hit_marker_timer: float = 0.0
var reticle: Label
var aim_frame: Panel
var scope_overlay: ColorRect
var scope_label: Label
var charge_label: Label
var charge_bar: ProgressBar
var weapon_hint: Label
var boss_panel: Panel
var boss_name: Label
var boss_bar: ProgressBar
var boss_warning: Label
var sub_panel: Panel
var sub_name_label: Label
var sub_hull_bar: ProgressBar
var sub_hull_label: Label
var sub_speed_label: Label
var sub_weapon_label: Label
var booster_indicator: Label
var torpedo_panel: Panel
var torpedo_title: Label
var torpedo_telemetry: Label
var torpedo_reticle: Label
var tame_panel: Panel
var tame_title: Label
var tame_slots_label: Label
var tame_mount_label: Label
var shield_label: Label
var dave_status_label: Label
var sushi_header_label: Label
var sushi_ingredients_label: Label
var sushi_cook_buttons: Dictionary = {}
var cobra_buy_buttons: Dictionary = {}
var marinca_summary_label: Label
var marinca_grid_label: Label
var mount_board_summary_label: Label
var mount_board_empty_label: Label
var mount_board_slot_buttons: Array[Button] = []
var mount_board_select_all_btn: Button
var mount_board_store_all_btn: Button
var bathy_texture: ImageTexture
var compass_strip: Control
var minimap_radar: Control
var sea_chart: Control
var explore_summary_label: Label
var map_rank_label: Label
var map_stats_label: Label
var map_sel_title: Label
var map_sel_coords: Label
var map_sel_desc: Label
var map_travel_btn: Button
var map_waypoint_btn: Button
var map_clear_wp_btn: Button
var map_selected_info: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font: FontFile = preload("res://assets/fonts/NotoSansSC-Subset.otf")
	var sym_font: FontFile = preload("res://assets/fonts/Symbols-Subset.ttf")
	if not font.fallbacks.has(sym_font):
		font.fallbacks = [sym_font]
	ThemeDB.fallback_font = font
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 16
	theme.set_color("font_color", "Label", INK)
	root.theme = theme
	bathy_texture = WorldMap.build_bathymetry_texture(128)
	_build_instruments()
	_build_main()
	_build_pause()
	_build_craft()
	_build_sushi()
	_build_mount_board()
	_build_map()
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
	if hit_marker_timer > 0.0:
		hit_marker_timer = maxf(0.0, hit_marker_timer - delta)
		if is_instance_valid(hit_marker):
			hit_marker.modulate.a = clampf(hit_marker_timer / 0.22, 0.0, 1.0)
			hit_marker.scale = hit_marker.scale.lerp(Vector2.ONE, delta * 16.0)
			hit_marker.visible = hit_marker_timer > 0.0
	elif is_instance_valid(hit_marker) and hit_marker.visible:
		hit_marker.visible = false

func trigger_hit_marker(is_kill: bool = false) -> void:
	if not is_instance_valid(hit_marker):
		return
	hit_marker_timer = 0.22
	hit_marker.modulate = Color(1.0, 0.28, 0.28, 1.0) if is_kill else Color(1.0, 1.0, 1.0, 1.0)
	hit_marker.scale = Vector2(1.35, 1.35)
	hit_marker.visible = true

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
		float mask = smoothstep(1.05, 1.75, dist) * 0.16;
		float mist = smoothstep(0.82, 1.58, dist) * (breath * 0.18 + frost * 0.55);
		vec3 tint = mix(vec3(0.01, 0.04, 0.06), vec3(0.78, 0.95, 1.0), mist / max(mask + mist, 0.001));
		COLOR = vec4(tint, clamp(mask + mist, 0.0, 0.45));
	}"""
	visor_material = ShaderMaterial.new()
	visor_material.shader = v_shader
	visor_rect.material = visor_material
	_label(instruments, "◈  ABYSSAL ECHO", Rect2(42, 28, 250, 28), 18, INK)
	_label(instruments, "深蓝回声  /  开放海域探索协议", Rect2(43, 58, 290, 24), 12, MUTED)
	_line(instruments, Rect2(43, 93, 38, 2), CYAN)
	_label(instruments, "开放海域勘测日志  [M 海图 · N 声呐]", Rect2(43, 106, 310, 20), 11, CYAN)
	mission_title = _label(instruments, "全域自由漫游 · 勘测未知海域", Rect2(43, 129, 360, 26), 15, INK)
	mission_detail = _label(instruments, "按 M 打开海图设置标点或跃迁传送", Rect2(43, 158, 360, 24), 12, MUTED)

	compass_strip = WorldMap.CompassStrip.new()
	_place(compass_strip, instruments, Rect2(-195, 16, 390, 28), Vector2(0.5, 0))
	compass_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	depth_value = _label(instruments, "012 m", Rect2(-150, 46, 300, 54), 38, INK, Vector2(0.5, 0))
	depth_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_value = _label(instruments, "浅海珊瑚礁区  /  水下", Rect2(-240, 101, 480, 24), 12, CYAN, Vector2(0.5, 0))
	status_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_label(instruments, "⌂  母港信标", Rect2(-416, 26, 192, 22), 12, CYAN, Vector2(1, 0)).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	home_value = _label(instruments, "18 m", Rect2(-416, 48, 192, 32), 22, INK, Vector2(1, 0))
	home_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	explore_summary_label = _label(instruments, "勘测 0% · 地标 0/24\n前哨 0/6 · 遗珍 0/12", Rect2(-426, 82, 202, 40), 11, MUTED, Vector2(1, 0))
	explore_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	minimap_radar = WorldMap.MinimapRadar.new()
	minimap_radar.set_bathymetry(bathy_texture)
	_place(minimap_radar, instruments, Rect2(-214, 22, 180, 198), Vector2(1, 0))

	# 右上角配方置顶追踪面板 (Recipe Pinning HUD)
	pinned_panel = _panel(instruments, Rect2(-279, 228, 245, 54), Vector2(1, 0))
	pinned_panel.hide()
	pinned_title = _label(pinned_panel, "【配方追踪】", Rect2(12, 6, 225, 20), 11, CYAN)
	pinned_progress = _label(pinned_panel, "", Rect2(12, 27, 225, 20), 11, INK)

	reticle = _label(instruments, "+", Rect2(-12, -16, 24, 32), 22, Color(0.83, 1, 0.98, 0.8), Vector2(0.5, 0.5))
	reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aim_frame = _panel(instruments, Rect2(-165, -110, 330, 220), Vector2(0.5, 0.5))
	aim_frame.add_theme_stylebox_override("panel", _style(Color.TRANSPARENT, Color(0.2, 0.6, 1.0, 0.35), 12))
	_label(aim_frame, "精密瞄准  /  T 退出", Rect2(12, 9, 250, 20), 11, CYAN)
	aim_frame.hide()
	scope_overlay = ColorRect.new()
	_place(scope_overlay, instruments, Rect2())
	scope_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scope_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var scope_material := ShaderMaterial.new()
	scope_material.shader = preload("res://shaders/scope.gdshader")
	scope_overlay.material = scope_material
	scope_overlay.hide()
	scope_label = _label(instruments, "", Rect2(-240, 180, 480, 24), 13, CYAN, Vector2(0.5, 0.5))
	scope_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scope_label.hide()
	charge_label = _label(instruments, "", Rect2(-160, 35, 320, 24), 14, CYAN, Vector2(0.5, 0.5))
	charge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	charge_label.add_theme_stylebox_override("normal", _style(Color(0.015, 0.055, 0.09, 0.92), Color(0.1, 0.4, 0.8, 0.8)))
	charge_bar = ProgressBar.new()
	_place(charge_bar, instruments, Rect2(-90, 65, 180, 5), Vector2(0.5, 0.5))
	charge_bar.show_percentage = false
	charge_bar.max_value = 1.0
	charge_bar.add_theme_stylebox_override("background", _style(Color(0.08, 0.2, 0.3, 0.8)))
	charge_bar.add_theme_stylebox_override("fill", _style(Color(0.15, 0.55, 1.0)))
	charge_bar.hide()
	boss_panel = _panel(instruments, Rect2(-270, 192, 540, 80), Vector2(0.5, 0))
	boss_name = _label(boss_panel, "深渊水龙 · 潮汐君主", Rect2(16, 8, 508, 25), 16, INK)
	boss_bar = ProgressBar.new()
	_place(boss_bar, boss_panel, Rect2(16, 38, 508, 7))
	boss_bar.show_percentage = false
	boss_bar.add_theme_stylebox_override("background", _style(Color(0.08, 0.19, 0.27)))
	boss_bar.add_theme_stylebox_override("fill", _style(Color(0.12, 0.55, 1.0)))
	boss_warning = _label(boss_panel, "", Rect2(16, 51, 508, 21), 12, ORANGE)
	boss_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_panel.hide()

	hit_marker = _label(instruments, "✕", Rect2(-14, -18, 28, 36), 22, Color(1, 1, 1, 0), Vector2(0.5, 0.5))
	hit_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hit_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hit_marker.visible = false

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
	var supplies := _panel(instruments, Rect2(-490, -198, 450, 140), Vector2(1, 1))
	_label(supplies, "样本与战利品储存", Rect2(17, 11, 160, 24), 12, CYAN)
	_label(supplies, "INVENTORY", Rect2(320, 12, 110, 22), 10, MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var kinds := ["titanium", "copper", "quartz", "kelp", "fish_small", "shark_fragment", "abyss_fragment"]
	var names := ["钛", "铜", "石英", "海藻", "鲜鱼", "鲨齿", "晶核"]
	for index in range(kinds.size()):
		var x := 12.0 + float(index) * 61.0
		resource_labels[kinds[index]] = _label(supplies, "0", Rect2(x, 40, 54, 35), 22, INK)
		_label(supplies, names[index], Rect2(x, 79, 56, 21), 11, MUTED)
	dave_status_label = _label(supplies, "⚖ 负重 0.0/40kg  ·  💰 0 金币  ·  🎈 无人机 3 [V打捞]  ·  ★ 图鉴 0/13 [B寿司吧]", Rect2(14, 108, 424, 22), 11, CYAN)

	# 底部中央装备与武器栏
	equipment_value = _label(instruments, "基础潜水装备", Rect2(-235, -162, 470, 22), 11, MUTED, Vector2(0.5, 1))
	equipment_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var weapon_panel := _panel(instruments, Rect2(-240, -136, 480, 42), Vector2(0.5, 1))
	weapon_bar_label = _label(weapon_panel, "[1 潜水刀]    2 破拆斧    3 蓝光静滞枪", Rect2(10, 10, 460, 24), 13, CYAN)
	weapon_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weapon_hint = _label(instruments, "", Rect2(-370, -208, 740, 24), 13, CYAN, Vector2(0.5, 1))
	weapon_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	target_value = _label(instruments, "", Rect2(-300, -88, 600, 33), 17, INK, Vector2(0.5, 1))
	target_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# 潜水艇驾驶舱 HUD 面板
	sub_panel = _panel(instruments, Rect2(-320, -150, 640, 72), Vector2(0.5, 1))
	sub_name_label = _label(sub_panel, "【深海斥候号】巡航潜艇", Rect2(15, 8, 260, 22), 14, CYAN)
	sub_speed_label = _label(sub_panel, "航速: 0.0 m/s", Rect2(280, 8, 160, 22), 13, INK)
	sub_weapon_label = _label(sub_panel, "车载鱼雷 [就绪]", Rect2(445, 8, 180, 22), 13, CYAN)
	sub_hull_bar = ProgressBar.new()
	_place(sub_hull_bar, sub_panel, Rect2(15, 34, 420, 16))
	sub_hull_bar.max_value = 1.0
	sub_hull_bar.value = 1.0
	sub_hull_bar.show_percentage = false
	sub_hull_bar.add_theme_stylebox_override("fill", _style(Color(0.12, 0.75, 0.85)))
	sub_hull_bar.add_theme_stylebox_override("background", _style(Color(0.04, 0.1, 0.15, 0.9)))
	sub_hull_label = _label(sub_panel, "耐压装甲 100%", Rect2(15, 34, 420, 16), 11, INK)
	sub_hull_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub_ctrl := _label(sub_panel, "WASD 航行  ·  空格/C 升降  ·  Shift 加速  ·  R/左键 鱼雷火炮  ·  E 离开潜艇", Rect2(15, 52, 610, 16), 11, MUTED)
	sub_ctrl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_panel.hide()

	# 手持迷你助推器状态指示
	booster_indicator = _label(instruments, "⚡ 水下迷你助推器巡航中 [按 H 收起 · 移速翻倍]", Rect2(-240, -136, 480, 42), 13, CYAN, Vector2(0.5, 1))
	booster_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	booster_indicator.add_theme_stylebox_override("normal", _style(PANEL, Color(0.12, 0.72, 0.95, 0.6)))
	booster_indicator.hide()

	# 导引鱼雷机载前视摄像机 HUD

	# 契约坐骑与战宠随从面板 (Tamed Beasts / Mounts HUD)
	tame_panel = _panel(instruments, Rect2(42, -188, 480, 102), Vector2(0, 1))
	tame_title = _label(tame_panel, "◈ 契约坐骑与应援 (0/20) · 按 O 一键收纳 / 坐骑应援板", Rect2(12, 6, 456, 18), 11, CYAN)
	tame_slots_label = _label(tame_panel, "方舟防卫模式：生物先攻击时坐骑自动反击；未攻击时按兵不动", Rect2(12, 28, 456, 42), 11, MUTED)
	tame_mount_label = _label(tame_panel, "按 O 键可将坐骑收入囊中；再按 O 键打开【坐骑应援板】点击召唤或全选", Rect2(12, 72, 456, 18), 11, INK)

	# 单手能量护盾状态指示标签
	shield_label = _label(instruments, "[C] 单手能量盾: [收起]", Rect2(42, -225, 260, 24), 12, MUTED, Vector2(0, 1))
	shield_label.add_theme_stylebox_override("normal", _style(PANEL, Color(0.12, 0.72, 0.95, 0.4)))

	var hints := _label(instruments, "WASD 移动  空格/Ctrl 升降  M 全域海图/跃迁  N 声呐扫描  C 护盾  O 坐骑板  G 骑乘  V 打捞  B 寿司吧  1-4 武器  R 攻击  E 交互  Tab 制造", Rect2(-640, -36, 1280, 22), 11, MUTED, Vector2(0.5, 1))
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
	_label(menu, "◈   OPEN OCEAN EXPEDITION  /  无缝开放海域探索", Rect2(68, 37, 550, 28), 12, MUTED)
	_label(menu, "01  /  1800m × 1800m 开放地图探索游戏", Rect2(72, 168, 580, 27), 14, CYAN)
	_label(menu, "深蓝回声", Rect2(64, 203, 620, 108), 76, INK)
	_label(menu, "A B Y S S A L   E C H O", Rect2(73, 323, 650, 31), 21, CYAN)
	_line(menu, Rect2(74, 380, 44, 2), CYAN)
	_label(menu, "晴空环礁 · 巨藻海峡 · 星象古都 · 龙骨荒原 · 极渊圣域", Rect2(74, 400, 680, 39), 20, INK)
	_label(menu, "无缝开放立体海洋世界：按 M 展开迷雾勘测海图、自由标点与科考前哨跃迁传送；\n按 N 释放广域声呐寻找远古遗珍，驾驭潜艇与契约海兽自由漫游九大海域。", Rect2(74, 448, 660, 56), 14, MUTED)
	_label(menu, "M 全域交互海图     N 广域声呐脉冲     6 大前哨跃迁站     24 大生态地标", Rect2(74, 526, 680, 30), 13, INK)

	_button(menu, "开放海域探索     ✦", Rect2(74, 580, 270, 54), func() -> void: start_requested.emit("explore"), true)
	_label(menu, "无限氧气 · 全域自由漫游 · 海图跃迁与收集", Rect2(76, 642, 275, 22), 12, CYAN)

	var survival_btn := _button(menu, "生存探索沙盒     →", Rect2(364, 580, 270, 54), func() -> void: start_requested.emit("survival"), false)
	survival_btn.add_theme_color_override("font_color", INK)
	_label(menu, "完整开放海图 · 氧气装备制造 · 前哨建站成长", Rect2(366, 642, 285, 22), 12, MUTED)

	_label(menu, "M 打开海图/标点/快速传送 · N 声呐扫描 · E 激活前哨站与搜集遗珍 · B 深海寿司吧", Rect2(75, 686, 760, 26), 12, MUTED)
	_label(menu, "原创海域生存与探险  /  GODOT × BLENDER", Rect2(73, -49, 650, 23), 10, MUTED, Vector2(0, 1))
	_label(menu, "OPEN WORLD READY\n九大无缝海域已开放", Rect2(-280, -101, 230, 61), 14, INK, Vector2(1, 1)).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _build_pause() -> void:
	var menu := _menu("pause")
	var card := _panel(menu, Rect2(-260, -205, 520, 410), Vector2(0.5, 0.5))
	_label(card, "DIVE LOG  /  潜航暂停", Rect2(36, 29, 450, 24), 12, CYAN)
	_label(card, "在此稍作停留", Rect2(35, 77, 450, 57), 34, INK)
	_label(card, "生命支持已暂停。可随时按 M 查看开放海图与前哨跃迁点。", Rect2(37, 142, 445, 30), 14, MUTED)
	_button(card, "继续潜航     →", Rect2(36, 192, 448, 48), func() -> void: resume_requested.emit(), true)
	_button(card, "打开全域勘测海图 [M]", Rect2(36, 250, 448, 44), func() -> void: set_screen("map"))
	_button(card, "重新开始", Rect2(36, 304, 448, 44), func() -> void: restart_requested.emit())
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
	_recipe(card, "sonic", "05", "蓝光静滞枪", "环境自适应蓝色激光 · 蓄力 3 秒静滞球 · Y 远距镜", "2 钛 + 2 石英 + 1 铜", 368)
	_recipe(card, "biomod_dash", "06", "生体模组·涡流突进", "按 Q 爆发突进 16 米紧急避咬 · 强化武装等级", "1 鲨齿碎片 + 2 钛", 428)
	_recipe(card, "reinforce_sharp", "07", "深铸武器·锋锐硬化", "精研近战刃口 · 全武器攻击力额外 +20", "1 鲨齿碎片 + 1 钛", 488)
	_recipe(card, "reinforce_sonic", "08", "深铸武器·晶体共鸣", "聚焦渊底脉冲 · 全武器攻击力额外 +35", "1 晶核碎片 + 1 石英", 548)
	_recipe(card, "beacon", "09", "修复求救信标", "完成返航通信准备 · 最终击败水龙通关", "3 钛 + 2 铜 + 2 石英", 608)

	_button(card, "返回潜航", Rect2(32, 668, 145, 38), func() -> void: resume_requested.emit())
	_button(card, "🍣 班乔寿司吧 & 玛琳卡 [B]", Rect2(188, 668, 228, 38), func() -> void: open_sushi_requested.emit(), true)
	_label(card, "点击【追踪】监视材料 · 按 B 进入寿司吧与图鉴", Rect2(424, 674, 304, 25), 11, MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _build_sushi() -> void:
	var menu := _menu("sushi")
	var card := _panel(menu, Rect2(-460, -365, 920, 730), Vector2(0.5, 0.5))
	card.add_theme_stylebox_override("panel", _style(WARM_PANEL, Color(0.96, 0.68, 0.28, 0.42)))
	_label(card, "BANCHO ABYSSAL SUSHI & MARINCA  /  班乔深海料理吧 · 柯布拉商店 · 玛琳卡图鉴", Rect2(28, 16, 860, 22), 12, AMBER_GOLD)
	sushi_header_label = _label(card, "💰 深海金币: 0    ·    🍣 餐厅声望 Lv.1 (已售 0 份)    ·    ⚖ 背包负重: 0.0 / 40.0 kg", Rect2(28, 42, 860, 28), 18, INK)
	sushi_ingredients_label = _label(card, "食材库存：鲜活小金鱼 0  /  海兽生肉 0  /  海藻 0  /  骨齿 0  /  韧性兽皮 0  /  甲壳 0", Rect2(28, 72, 860, 22), 12, MUTED)
	_line(card, Rect2(28, 98, 864, 1), Color(0.98, 0.72, 0.32, 0.32))

	# 左栏：班乔深海料理台 (Bancho Sushi Bar)
	_label(card, "🍣 班乔深海料理研发与售卖（烹饪即获金币 + 永久/即时主厨强化）", Rect2(28, 108, 520, 22), 14, AMBER_GOLD)
	_sushi_row(card, "goldfish_nigiri", "荧光金鱼握寿司", "食材: 1 鲜活小鱼  ·  售价 65G", "恢复 35 生命/30 氧气 · 氧气上限 +10s", 136)
	_sushi_row(card, "kelp_roll", "深海海藻鲜肉卷", "食材: 2 海兽生肉 + 1 海藻  ·  售价 150G", "生命上限永久 +20 并立即回满生命", 198)
	_sushi_row(card, "shark_sashimi", "暗礁巨鲨厚切刺身", "食材: 2 海兽生肉 + 1 骨齿  ·  售价 260G", "激发猎食潜能 · 全武器攻击力永久 +18", 260)
	_sushi_row(card, "abyss_kaiseki", "深渊海王黄金怀石", "食材: 3 海兽生肉 + 1 兽皮 + 1 甲壳  ·  售价 420G", "全武器攻击 +30 · 无人机配额 +1 · 负重上限 +15kg", 322)

	_button(card, "🏮 夜间挂牌营业 · 一键料理售出全部富余鲜鱼与生肉", Rect2(28, 390, 510, 40), func() -> void: sushi_serve_all_requested.emit(), true)

	# 左下栏：柯布拉深海补给商店 (Cobra Shop)
	_line(card, Rect2(28, 442, 510, 1), Color(0.47, 0.82, 0.81, 0.22))
	_label(card, "🛒 柯布拉深海战术商店（使用料理金币升级潜航装备）", Rect2(28, 450, 510, 22), 14, ORANGE)
	_cobra_row(card, "cargo_box", "柯布拉扩容生态箱 (120 金币)", "负重上限永久 +25 kg · 无人机打捞配额 +1 并补满", 478)
	_cobra_row(card, "oxygen_capsule", "高能浓缩氧气胶囊 (80 金币)", "氧气上限永久 +25 秒 · 立即补满氧气与生命", 534)
	_cobra_row(card, "duff_coating", "达夫特制超导涂层 (180 金币)", "达夫军工强化 · 全武器攻击力永久 +25", 590)

	# 右栏：玛琳卡海洋生物三星图鉴 (Marinca Collection)
	var marinca_box := _panel(card, Rect2(556, 108, 336, 536))
	_label(marinca_box, "🃏 玛琳卡海洋生物图鉴 (MARINCA)", Rect2(14, 10, 308, 22), 14, CYAN)
	marinca_summary_label = _label(marinca_box, "已收集物种: 0 / 13   ·   ★★★ 完美图鉴: 0\n三星料理售价加成: +0%", Rect2(14, 34, 308, 38), 11, ORANGE)
	_line(marinca_box, Rect2(14, 76, 308, 1), Color(0.47, 0.82, 0.81, 0.2))
	marinca_grid_label = _label(marinca_box, "", Rect2(14, 84, 308, 400), 12, INK)
	_label(marinca_box, "提示：按 V 无人机气球活捕或静滞冻结下捕获\n必定获得 ★★★ 完美星级与双倍食材产出！", Rect2(14, 490, 308, 38), 10, MUTED)

	_button(card, "返回潜航 (B / Esc)", Rect2(28, 668, 180, 40), func() -> void: resume_requested.emit())
	_label(card, "水下按 V 召唤无人机气球打捞 (★★★) · 靠近发光巨砗磲按 E 气泡补氧 · 按 B 随时开关此面板", Rect2(224, 676, 668, 24), 11, MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _sushi_row(parent: Control, dish_id: String, title: String, cost_str: String, desc_str: String, y: float) -> void:
	_label(parent, title, Rect2(28, y, 220, 22), 15, INK)
	_label(parent, cost_str, Rect2(240, y + 2, 185, 20), 11, ORANGE)
	_label(parent, desc_str, Rect2(28, y + 23, 395, 20), 11, MUTED)
	sushi_cook_buttons[dish_id] = _button(parent, "烹饪售出", Rect2(432, y + 4, 106, 36), func() -> void: sushi_cook_requested.emit(dish_id))

func _cobra_row(parent: Control, item_id: String, title: String, desc_str: String, y: float) -> void:
	_label(parent, title, Rect2(28, y, 380, 20), 14, INK)
	_label(parent, desc_str, Rect2(28, y + 21, 395, 18), 11, MUTED)
	cobra_buy_buttons[item_id] = _button(parent, "购买升级", Rect2(432, y + 2, 106, 34), func() -> void: cobra_buy_requested.emit(item_id))

func _recipe(parent: Control, key: String, number: String, title: String, detail: String, cost: String, y: float) -> void:
	_label(parent, number, Rect2(33, y + 4, 45, 32), 15, CYAN)
	_label(parent, title, Rect2(82, y, 320, 24), 16, INK)
	_label(parent, detail, Rect2(82, y + 24, 420, 18), 11, MUTED)
	_label(parent, cost, Rect2(82, y + 42, 420, 18), 10, CYAN)
	pin_buttons[key] = _button(parent, "追踪", Rect2(518, y + 8, 86, 36), func() -> void: pin_requested.emit(key))
	craft_buttons[key] = _button(parent, "制作", Rect2(612, y + 8, 102, 36), func() -> void: craft_requested.emit(key), key == "beacon")

func _build_mount_board() -> void:
	var menu := _menu("mount_board")
	var card := _panel(menu, Rect2(-460, -355, 920, 710), Vector2(0.5, 0.5))
	_label(card, "ARK MOUNT SUPPORT BOARD  /  方舟坐骑应援板 · 契约生物收纳与召唤中心", Rect2(28, 16, 860, 22), 12, AMBER_GOLD)
	_label(card, "契约生物应援板", Rect2(28, 40, 420, 34), 26, INK)
	mount_board_summary_label = _label(card, "已驯服生物: 0 / 20   ·   当前出战: 0 只   ·   防卫姿态: 方舟中立反击（野生生物先手攻击时自动迎击，未攻击时按兵不动）", Rect2(28, 76, 864, 22), 12, CYAN)
	_line(card, Rect2(28, 104, 864, 1), Color(0.28, 0.92, 1.0, 0.30))

	# 顶部操作栏：全选出战 & 全部收回
	mount_board_select_all_btn = _button(card, "☑ 全选出战 · 一键召唤全部契约生物", Rect2(28, 116, 320, 42), func() -> void: mount_board_select_all_requested.emit(), true)
	mount_board_store_all_btn = _button(card, "📥 全部收回囊中", Rect2(362, 116, 200, 42), func() -> void: mount_board_store_all_requested.emit(), false)
	_label(card, "点击下方应援板上的已驯服生物，即可将其立即召唤出来！", Rect2(576, 126, 316, 24), 12, AMBER_GOLD).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	mount_board_empty_label = _label(card, "当前尚未驯服任何海洋生物。\n在水下使用 3号【蓝光静滞枪】蓄力冻结残血巨兽后，靠近按 E 键即可契约驯服并载入应援板！", Rect2(60, 310, 800, 64), 15, MUTED)
	mount_board_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	mount_board_slot_buttons.clear()
	for i in range(20):
		var col: int = i % 4
		var row: int = int(i / 4)
		var bx: float = 28.0 + float(col) * 219.0
		var by: float = 172.0 + float(row) * 92.0
		var slot_idx: int = i
		var btn := _button(card, "槽位 #%02d\n[待驯服]" % (i + 1), Rect2(bx, by, 207, 80), func() -> void: mount_board_select_requested.emit(slot_idx), false)
		btn.add_theme_font_size_override("font_size", 13)
		btn.disabled = true
		mount_board_slot_buttons.append(btn)

	_button(card, "返回潜航 (O / Esc)", Rect2(28, 650, 190, 42), func() -> void: resume_requested.emit())
	_label(card, "操作说明：水下按一下 O 键将坐骑收入里面；再按一下 O 键弹出此应援板，点选单个生物或点击【全选出战】即可召唤！", Rect2(230, 660, 662, 24), 11, MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _build_map() -> void:
	var menu := _menu("map")
	var card := _panel(menu, Rect2(-485, -370, 970, 740), Vector2(0.5, 0.5))
	_label(card, "OPEN OCEAN SEA CHART  /  深蓝回声 · 全域开放勘测海图 & 洋流跃迁系统", Rect2(24, 14, 720, 22), 12, CYAN)
	map_rank_label = _label(card, "探索家头衔：浅礁见习潜航员   ·   全域探索度 0%", Rect2(24, 36, 620, 26), 19, INK)

	sea_chart = WorldMap.SeaChartCanvas.new()
	sea_chart.set_bathymetry(bathy_texture)
	_place(sea_chart, card, Rect2(24, 68, 616, 616))
	sea_chart.waypoint_set.connect(func(xz: Vector2) -> void: map_waypoint_set.emit(xz))
	sea_chart.waypoint_cleared.connect(func() -> void: map_waypoint_cleared.emit())
	sea_chart.fast_travel_requested.connect(func(tid: String, wpos: Vector3, tname: String) -> void:
		fast_travel_requested.emit(tid, wpos, tname)
	)
	sea_chart.selection_changed.connect(_on_sea_chart_selection)

	_label(card, "左键海面/右键：放置或取消导航标点  ·  左键图标：查看情报  ·  双击已解锁前哨/地标：立即跃迁  ·  滚轮/中键：缩放平移", Rect2(24, 694, 624, 22), 11, MUTED)

	# 右侧勘测仪表与传送控制栏
	var side := _panel(card, Rect2(656, 68, 290, 560))
	_label(side, "🗺️ 开放海域勘测总览", Rect2(14, 12, 260, 22), 14, AMBER_GOLD)
	map_stats_label = _label(side, "海图迷雾揭开: 0%\n已发现生态地标: 0 / 24\n已联网科考前哨: 0 / 6\n已收集远古遗珍: 0 / 12", Rect2(14, 38, 262, 82), 12, INK)
	_line(side, Rect2(14, 126, 262, 1), Color(0.28, 0.92, 1.0, 0.25))

	_label(side, "◈ 当前选中海图坐标", Rect2(14, 136, 260, 20), 12, CYAN)
	map_sel_title = _label(side, "点击左侧海图选择地标或标点", Rect2(14, 158, 262, 24), 15, INK)
	map_sel_coords = _label(side, "坐标: --   ·   水深: --", Rect2(14, 184, 262, 20), 11, AMBER_GOLD)
	map_sel_desc = _label(side, "在海图上点击任意已发现的地标、已激活的科考前哨站或逃生舱母港，即可启动洋流跃迁瞬间抵达。", Rect2(14, 208, 262, 68), 11, MUTED)
	map_sel_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	map_travel_btn = _button(side, "⚡ 洋流跃迁传送至此", Rect2(14, 284, 262, 42), func() -> void:
		if not map_selected_info.is_empty() and bool(map_selected_info.get("can_travel", false)):
			fast_travel_requested.emit(str(map_selected_info["id"]), map_selected_info["pos"], str(map_selected_info["name"]))
	, true)
	map_travel_btn.disabled = true

	map_waypoint_btn = _button(side, "✦ 将选中处设为导航标点", Rect2(14, 334, 262, 36), func() -> void:
		if not map_selected_info.is_empty() and map_selected_info.has("pos"):
			var p3: Vector3 = map_selected_info["pos"]
			map_waypoint_set.emit(Vector2(p3.x, p3.z))
	)
	map_waypoint_btn.disabled = true

	map_clear_wp_btn = _button(side, "✕ 清除自定义导航标点", Rect2(14, 376, 262, 34), func() -> void:
		map_waypoint_cleared.emit()
	)

	_line(side, Rect2(14, 420, 262, 1), Color(0.28, 0.92, 1.0, 0.22))
	_button(side, "⊕ 居中我", Rect2(14, 430, 102, 34), func() -> void: sea_chart.center_on_player())
	_button(side, "＋ 放大", Rect2(122, 430, 74, 34), func() -> void: sea_chart.adjust_zoom(1.25))
	_button(side, "－ 缩小", Rect2(202, 430, 74, 34), func() -> void: sea_chart.adjust_zoom(0.8))
	_button(side, "📡 释放广域声呐勘测脉冲 [N]", Rect2(14, 470, 262, 36), func() -> void: sonar_ping_requested.emit())
	_label(side, "⌂ 母港   ⬡ 科考前哨   ◈ 地标   ⚓ 潜艇   ◆ 遗珍   ✦ 标点", Rect2(14, 516, 262, 34), 11, MUTED)

	_button(card, "返回潜航 (M / Esc)", Rect2(656, 642, 290, 44), func() -> void: resume_requested.emit())

func _on_sea_chart_selection(info: Dictionary) -> void:
	map_selected_info = info
	if not is_instance_valid(map_sel_title):
		return
	if info.is_empty():
		map_sel_title.text = "点击左侧海图选择地标或标点"
		map_sel_coords.text = "坐标: --   ·   水深: --"
		map_sel_desc.text = "点击任意位置放置标点，或选择已解锁的前哨站/地标进行快速跃迁。"
		map_travel_btn.disabled = true
		map_waypoint_btn.disabled = true
		return
	var p3: Vector3 = info.get("pos", Vector3.ZERO)
	var can_tr: bool = bool(info.get("can_travel", false))
	map_sel_title.text = str(info.get("name", "海域坐标"))
	map_sel_coords.text = "坐标 X:%+d  Z:%+d   ·   深度 %dm" % [roundi(p3.x), roundi(p3.z), maxi(0, roundi(-p3.y))]
	map_sel_desc.text = str(info.get("desc", ""))
	map_travel_btn.disabled = not can_tr
	map_travel_btn.text = "⚡ 洋流跃迁传送至此" if can_tr else "🔒 尚未解锁跃迁 (前往勘测/激活)"
	map_waypoint_btn.disabled = false

func _build_win() -> void:
	var menu := _menu("win")
	var card := _panel(menu, Rect2(-320, -236, 640, 472), Vector2(0.5, 0.5))
	_label(card, "●  EXPEDITION RECORD", Rect2(40, 34, 520, 30), 14, CYAN)
	win_title = _label(card, "深海收到了回声", Rect2(37, 98, 560, 61), 36, INK)
	win_desc = _label(card, "求救信标已重新上线。\n救援船正在驶来，你将平安返航。", Rect2(40, 185, 560, 72), 16, MUTED)
	win_time = _label(card, "本次潜航  00:00", Rect2(40, 282, 560, 28), 13, CYAN)
	_button(card, "继续漫游开放海域     ✦", Rect2(40, 346, 332, 56), func() -> void: resume_requested.emit(), true)
	_button(card, "开启新航程     →", Rect2(386, 346, 214, 56), func() -> void: restart_requested.emit(), false)

func update_hud(data: Dictionary) -> void:
	if not is_instance_valid(oxygen_value):
		return
	var mode := str(data.get("mode", "survival"))
	var is_explore := mode == "explore"
	var exp_pct: int = roundi(float(data.get("exploration_progress", 0.0)) * 100.0)
	var exp_rank: String = str(data.get("explorer_rank", "浅礁见习潜航员"))
	var lm_cnt: int = int(data.get("landmarks_count", 0))
	var lm_tot: int = int(data.get("landmarks_total", 24))
	var out_cnt: int = int(data.get("outposts_unlocked_count", 0))
	var out_tot: int = int(data.get("outposts_total", 6))
	var rel_cnt: int = int(data.get("relics_collected_count", 0))
	var rel_tot: int = int(data.get("relics_total", 12))
	var has_wp: bool = bool(data.get("has_waypoint", false))
	var wp_pos: Vector3 = data.get("waypoint_pos", Vector3.ZERO)
	var p_pos: Vector3 = data.get("player_pos", Vector3.ZERO)
	var p_fwd: Vector3 = data.get("player_forward", Vector3.FORWARD)

	if is_explore:
		oxygen_value.text = "∞"
		oxygen_value.add_theme_color_override("font_color", CYAN)
		oxygen_unit.text = "探险  /  无限制"
		oxygen_bar.max_value = 100.0
		oxygen_bar.value = 100.0
		oxygen_bar.modulate = CYAN
	else:
		var oxygen := float(data.get("oxygen", 90.0))
		var maximum := maxf(float(data.get("max_oxygen", 90.0)), 1.0)
		oxygen_value.text = "%02d" % ceili(maxf(oxygen, 0.0))
		oxygen_value.add_theme_color_override("font_color", ORANGE if oxygen < maximum * 0.25 else INK)
		oxygen_unit.text = "秒  /  氧气"
		oxygen_bar.max_value = maximum
		oxygen_bar.value = oxygen
		oxygen_bar.modulate = ORANGE if oxygen < maximum * 0.25 else Color.WHITE

	health_value.text = "＋  生命 %d" % ceili(float(data.get("health", 100.0)))
	var depth := maxf(float(data.get("depth", 0.0)), 0.0)
	depth_value.text = "%03d m" % roundi(depth)

	var biome: String = str(data.get("biome", "浅海生态区"))
	var oxygen_level := float(data.get("oxygen", 90.0))
	var max_oxygen_level := maxf(float(data.get("max_oxygen", 90.0)), 1.0)
	if not is_explore and oxygen_level < max_oxygen_level * 0.25:
		status_value.text = "氧气不足  /  请上浮、靠近巨砗磲或前往科考前哨站"
		status_value.add_theme_color_override("font_color", ORANGE)
	else:
		status_value.text = "%s   [X:%+d Z:%+d]" % [biome, roundi(p_pos.x), roundi(p_pos.z)]
		status_value.add_theme_color_override("font_color", CYAN)

	home_value.text = "%d m" % roundi(float(data.get("distance_home", 0.0)))
	if is_instance_valid(explore_summary_label):
		explore_summary_label.text = "勘测 %d%% · 地标 %d/%d\n前哨 %d/%d · 遗珍 %d/%d" % [
			exp_pct, lm_cnt, lm_tot, out_cnt, out_tot, rel_cnt, rel_tot
		]

	# Update Compass, Minimap Radar, and Full-Screen Sea Chart
	var outposts_arr: Array = data.get("map_outposts", [])
	var unlocked_out: Array = data.get("unlocked_outposts", [])
	var near_out_pos := Vector3.ZERO
	var has_near_out := false
	var best_out_d := 99999.0
	for o in outposts_arr:
		var oid := str(o.get("id", ""))
		if not unlocked_out.has(oid):
			var od := p_pos.distance_to(o["pos"])
			if od < best_out_d:
				best_out_d = od
				near_out_pos = o["pos"]
				has_near_out = true
	if is_instance_valid(compass_strip):
		compass_strip.update_compass(p_pos, p_fwd, has_wp, wp_pos, has_near_out, near_out_pos)

	var chart_payload := {
		"player_pos": p_pos,
		"player_forward": p_fwd,
		"surveyed_cells": data.get("surveyed_cells", {}),
		"landmarks": data.get("landmarks_dict", {}),
		"discovered_landmarks": data.get("discovered_landmarks", []),
		"outposts": outposts_arr,
		"unlocked_outposts": unlocked_out,
		"submarines": data.get("map_submarines", []),
		"relics": data.get("map_relics", []),
		"pinged_targets": data.get("pinged_targets", {}),
		"has_waypoint": has_wp,
		"waypoint_pos": wp_pos
	}
	if is_instance_valid(minimap_radar):
		minimap_radar.update_radar(chart_payload, get_process_delta_time())
	if is_instance_valid(sea_chart) and active_screen == "map":
		sea_chart.update_chart(chart_payload)
	if is_instance_valid(map_rank_label):
		map_rank_label.text = "探索家头衔：【%s】   ·   全域探索度 %d%%" % [exp_rank, exp_pct]
	if is_instance_valid(map_stats_label):
		var survey_pct := roundi(float(data.get("survey_ratio", 0.0)) * 100.0)
		map_stats_label.text = "海图扇区揭开: %d%%\n已发现生态地标: %d / %d\n已联网科考前哨: %d / %d\n已收集远古遗珍: %d / %d" % [
			survey_pct, lm_cnt, lm_tot, out_cnt, out_tot, rel_cnt, rel_tot
		]
	if is_instance_valid(map_clear_wp_btn):
		map_clear_wp_btn.disabled = not has_wp

	var target := str(data.get("target", ""))
	target_value.text = target
	var inventory: Dictionary = data.get("inventory", {})
	for kind: String in resource_labels:
		var resource_label: Label = resource_labels[kind]
		resource_label.text = str(inventory.get(kind, 0))
	var cur_weight: float = float(data.get("current_weight", 0.0))
	var max_weight: float = float(data.get("max_weight", 40.0))
	var overweight: bool = bool(data.get("overweight", false))
	var gold_val: int = int(data.get("gold", 0))
	var drone_cur: int = int(data.get("drone_charges", 3))
	var drone_max: int = int(data.get("max_drone_charges", 3))
	var marinca_cards: Dictionary = data.get("marinca_cards", {})
	var marinca_species: Dictionary = data.get("marinca_species", {})
	var marinca_total: int = maxi(13, marinca_species.size())
	if is_instance_valid(dave_status_label):
		var w_str := "⚖ 超重 %.1f/%.0fkg" % [cur_weight, max_weight] if overweight else "⚖ 负重 %.1f/%.0fkg" % [cur_weight, max_weight]
		var d_str := "∞" if is_explore else "%d/%d" % [drone_cur, drone_max]
		dave_status_label.text = "%s  ·  💰 %dG  ·  🎈 无人机 %s [V打捞]  ·  ★ 图鉴 %d/%d [B寿司吧]" % [
			w_str, gold_val, d_str, marinca_cards.size(), marinca_total
		]
		dave_status_label.add_theme_color_override("font_color", ORANGE if overweight else CYAN)

	if is_instance_valid(sushi_header_label):
		var rep_lv: int = int(data.get("sushi_reputation", 1))
		var served_cnt: int = int(data.get("dishes_served", 0))
		sushi_header_label.text = "💰 深海金币: %d G    ·    🍣 餐厅声望 Lv.%d (已售 %d 份)    ·    ⚖ 背包负重: %.1f / %.0f kg" % [
			gold_val, rep_lv, served_cnt, cur_weight, max_weight
		]
		sushi_ingredients_label.text = "食材库存：鲜活小金鱼 %d   /   海兽生肉 %d   /   海藻 %d   /   骨齿 %d   /   韧性兽皮 %d   /   甲壳 %d" % [
			int(inventory.get("fish_small", 0)),
			int(inventory.get("fish_meat", 0)),
			int(inventory.get("kelp", 0)),
			int(inventory.get("creature_tooth", 0)),
			int(inventory.get("creature_skin", 0)),
			int(inventory.get("chitin", 0))
		]
		var three_stars: int = int(data.get("three_star_count", 0))
		marinca_summary_label.text = "已收集物种: %d / %d   ·   ★★★ 完美图鉴: %d\n三星料理售价加成: +%d%%" % [
			marinca_cards.size(), marinca_total, three_stars, three_stars * 12
		]
		var lines: Array[String] = []
		for sp_key in marinca_species:
			var sp_name: String = str(marinca_species[sp_key])
			if marinca_cards.has(sp_key):
				var c_info: Dictionary = marinca_cards[sp_key]
				var st: int = clampi(int(c_info.get("stars", 1)), 1, 3)
				var st_txt := "★".repeat(st) + "☆".repeat(3 - st)
				lines.append("%s  %s  (捕获 ×%d)" % [st_txt, sp_name, int(c_info.get("count", 1))])
			else:
				lines.append("☆☆☆  %s  [未捕获]" % sp_name)
		marinca_grid_label.text = "\n".join(lines)

		if active_screen == "sushi":
			var sushi_recipes: Dictionary = data.get("sushi_recipes", {})
			for d_id in sushi_cook_buttons:
				var btn: Button = sushi_cook_buttons[d_id]
				var can_cook := true
				if sushi_recipes.has(d_id):
					var c_dict: Dictionary = sushi_recipes[d_id].get("cost", {})
					for k in c_dict:
						if int(inventory.get(k, 0)) < int(c_dict[k]):
							can_cook = false
				btn.disabled = not can_cook
				btn.text = "烹饪售出" if can_cook else "食材不足"
			var cobra_items: Dictionary = data.get("cobra_items", {})
			for c_id in cobra_buy_buttons:
				var c_btn: Button = cobra_buy_buttons[c_id]
				var price: int = int(cobra_items.get(c_id, {}).get("price", 100))
				var can_buy: bool = gold_val >= price
				c_btn.disabled = not can_buy
				c_btn.text = "购买升级" if can_buy else "金币不足"

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

	if active_screen == "craft":
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
	var s_txt: String = ("【3 蓝光枪】" if cur_w == "sonic" else "3 蓝光枪") + ("" if has_sonic else " (未制作)")
	var upgrade_info: String = "   ·   武装强化 Lv.%d (+%d 伤)" % [w_level, int(w_bonus)] if w_level > 0 else ""
	weapon_bar_label.text = "%s      %s      %s%s" % [k_txt, a_txt, s_txt, upgrade_info]
	var is_gun := cur_w == "sonic"
	var aiming: bool = is_gun and bool(data.get("aiming", false))
	var scoped: bool = is_gun and bool(data.get("scoped", false))
	var charging: bool = is_gun and bool(data.get("charging", false))
	aim_frame.visible = aiming and not scoped
	scope_overlay.visible = scoped
	scope_label.visible = scoped
	var in_sub: bool = bool(data.get("in_submarine", false))
	var booster_on: bool = bool(data.get("booster_active", false))
	equipment_value.visible = not scoped and not in_sub
	weapon_hint.visible = not scoped and not in_sub and not booster_on
	scope_label.text = "8× 远距镜  /  测距 %d m  /  Y 退出" % roundi(float(data.get("scope_distance", 2000.0)))
	reticle.visible = not scoped
	reticle.text = "·" if aiming else "+"
	charge_label.visible = charging
	charge_bar.visible = charging
	charge_bar.value = float(data.get("charge_ratio", 0.0))
	charge_label.text = "静滞大招就绪 · 松开发射" if bool(data.get("charge_ready", false)) else "蓄能  %.1f / 3.0 秒" % (charge_bar.value * 3.0)
	var cooldown: float = float(data.get("gun_cooldown", 0.0))
	weapon_hint.text = ("能量恢复 %.1f 秒" % cooldown) if is_gun and cooldown > 0.0 else ("短按 R / 左键：激光    蓄力 3 秒松手：静滞大招    T 瞄准 / Y 远距镜" if is_gun else "")
	var boss: Dictionary = data.get("boss", {})
	var fighting: bool = bool(boss.get("active", false))
	boss_panel.visible = fighting
	boss_bar.max_value = float(boss.get("max_health", 1800.0))
	boss_bar.value = float(boss.get("health", 1800.0))
	boss_name.text = "%s  %d / %d" % [str(boss.get("name", "深渊水龙")), ceili(boss_bar.value), int(boss_bar.max_value)]
	var frozen: float = float(boss.get("frozen", 0.0))
	boss_warning.text = "静滞冻结 %.1f 秒 · 立即用激光攻击" % frozen if frozen > 0.0 else str(boss.get("warning", ""))

	# 潜水艇驾驶舱状态更新
	sub_panel.visible = in_sub
	booster_indicator.visible = booster_on and not in_sub
	weapon_bar_label.get_parent().visible = not in_sub and not booster_on
	if in_sub:
		sub_name_label.text = "【%s】" % str(data.get("sub_name", "潜水艇"))
		var hull_cur: float = float(data.get("sub_hull", 800.0))
		var hull_max: float = float(data.get("sub_max_hull", 800.0))
		var hull_pct: float = clampf(hull_cur / maxf(hull_max, 1.0), 0.0, 1.0)
		sub_hull_bar.value = hull_pct
		sub_hull_label.text = "耐压装甲 %d / %d (%d%%)" % [roundi(hull_cur), roundi(hull_max), roundi(hull_pct * 100.0)]
		var sub_spd: float = float(data.get("sub_speed", 0.0))
		sub_speed_label.text = "航速: %.1f m/s (%d节)" % [sub_spd, roundi(sub_spd * 1.944)]
		var torp_guided: bool = bool(data.get("torpedo_guided", false))
		var w_ready: bool = bool(data.get("sub_weapon_ready", true))
		var w_cd: float = float(data.get("sub_cooldown", 0.0))
		var s_name_str := str(data.get("sub_name", ""))
		if s_name_str.contains("微型"):
			sub_weapon_label.text = "电磁脉冲炮 [就绪 · T/Y瞄准]" if w_ready else "电磁脉冲炮 [冷却 %.1fs]" % w_cd
		elif torp_guided:
			sub_weapon_label.text = "车载鱼雷 [飞行中]"
		elif w_ready:
			sub_weapon_label.text = "车载鱼雷 [就绪 · R发射]"
		else:
			sub_weapon_label.text = "车载鱼雷 [装填 %.1fs]" % w_cd

	# 更新契约坐骑面板状态
	var beasts: Array = data.get("tamed_beasts", [])
	var deployed_cnt: int = int(data.get("deployed_beast_count", beasts.size()))
	var mount_idx: int = int(data.get("active_mount_idx", -1))
	var beast_cnt: int = beasts.size()
	var atk_mult: float = pow(2.0, maxf(0.0, float(beast_cnt - 1))) if beast_cnt > 0 else 1.0
	tame_title.text = "◈ 契约坐骑 (%d/20 · 出战 %d) · 攻击 ×%.0f · O 收纳/应援板" % [beast_cnt, deployed_cnt, atk_mult]
	if beast_cnt == 0:
		tame_slots_label.text = "大型猛兽/Boss近血时，用声波枪蓄力静滞后靠近按 E 驯服 (上限20只)！"
		tame_mount_label.text = "方舟中立防卫：野生生物先手攻击时坐骑自动反击 · 按 O 打开坐骑应援板"
	else:
		var slots_str := ""
		for i in range(mini(beast_cnt, 10)):
			var b_info: Dictionary = beasts[i]
			var is_dep: bool = bool(b_info.get("deployed", true))
			var tag := "[★]" if i == mount_idx else ("[出]" if is_dep else "[收]")
			var hotkey_str := str(i + 5) if i < 5 else str((i - 5) % 10)
			slots_str += "%s:%s%s " % [hotkey_str, tag, str(b_info.get("name", "海兽")).substr(0, 3)]
		if beast_cnt > 10:
			slots_str += "...(+%d)" % (beast_cnt - 10)
		tame_slots_label.text = slots_str
		if mount_idx >= 0 and mount_idx < beast_cnt:
			tame_mount_label.text = "★ 骑乘: %s (WASD/空格/C 机动 · 按 O 一键收纳坐骑)" % beasts[mount_idx].get("name", "海兽")
		elif deployed_cnt == 0:
			tame_mount_label.text = "📥 全部 %d 只坐骑已收入囊中 · 再按 O 键打开【坐骑应援板】点选或全选出战" % beast_cnt
		else:
			tame_mount_label.text = "🛡️ %d/%d 只坐骑出战护卫 · 生物先手攻击时自动反击 · 按 O 收入囊中" % [deployed_cnt, beast_cnt]

	if is_instance_valid(mount_board_summary_label):
		mount_board_summary_label.text = "已驯服生物: %d / 20   ·   当前出战: %d 只   ·   战力倍率: ×%.0f   ·   防卫姿态: 方舟中立反击（敌方先攻击才出击）" % [
			beast_cnt, deployed_cnt, atk_mult
		]
		if is_instance_valid(mount_board_empty_label):
			mount_board_empty_label.visible = beast_cnt == 0
		if is_instance_valid(mount_board_select_all_btn):
			mount_board_select_all_btn.disabled = beast_cnt == 0
		if is_instance_valid(mount_board_store_all_btn):
			mount_board_store_all_btn.disabled = deployed_cnt == 0
		for idx in range(mount_board_slot_buttons.size()):
			var s_btn: Button = mount_board_slot_buttons[idx]
			if idx < beast_cnt:
				var b_entry: Dictionary = beasts[idx]
				var b_name: String = str(b_entry.get("name", "契约海兽"))
				var b_hp: int = roundi(float(b_entry.get("health", 600.0)))
				var is_dep: bool = bool(b_entry.get("deployed", true))
				s_btn.visible = true
				s_btn.disabled = false
				var state_str := "● 已召唤出战" if is_dep else "○ 点击召唤出战"
				s_btn.text = "#%02d 【%s】\nHP %d  ·  %s" % [idx + 1, b_name, b_hp, state_str]
				s_btn.add_theme_color_override("font_color", AMBER_GOLD if is_dep else INK)
			else:
				s_btn.visible = beast_cnt > 0
				s_btn.disabled = true
				s_btn.text = "应援槽位 #%02d\n[ 空闲待驯服 ]" % (idx + 1)
				s_btn.add_theme_color_override("font_color", MUTED)

	var is_shield: bool = bool(data.get("shield_active", false))
	shield_label.text = "[C] 单手能量盾: [防御中 🛡️]" if is_shield else "[C] 单手能量盾: [收起]"
	shield_label.add_theme_color_override("font_color", CYAN if is_shield else MUTED)

	if fighting:
		mission_title.text = "【巨兽决战】%s" % str(boss.get("name", "深渊领主"))
		mission_detail.text = "近血时用声波枪静滞可按 E 契约驯服为坐骑！"
	elif bool(data.get("mother_tree_active", false)) and not bool(data.get("escape_crafted", false)):
		var items_cnt: int = int(data.get("tree_items_collected", 0))
		if items_cnt >= 3:
			mission_title.text = "【母树圣物齐集】可前往母港控制台解锁跃迁纪念"
			mission_detail.text = "母树遗物 (3/3) · 或按 M 继续自由探索开放大海域"
		else:
			var dist_tree: float = float(data.get("distance_mother_tree", 300.0))
			mission_title.text = "【深海母树现世】潜入母树圣所收集核心遗物"
			mission_detail.text = "深海极渊母树 %d 米 · 收集核心物资 (%d/3)" % [roundi(dist_tree), items_cnt]
	elif has_wp:
		var wp_dist: int = roundi(p_pos.distance_to(wp_pos))
		mission_title.text = "【%s】勘测度 %d%% · 航向自定义标点" % [exp_rank, exp_pct]
		mission_detail.text = "✦ 距离目标标点 %d 米 · 按 M 查看海图或切换跃迁点" % wp_dist
	else:
		mission_title.text = "【%s】开放海域自由探索 (%d%%)" % [exp_rank, exp_pct]
		if has_near_out:
			mission_detail.text = "最近未激活前哨 %dm · 按 M 海图跃迁 / N 声呐寻宝" % roundi(best_out_d)
		else:
			mission_detail.text = "地标 %d/%d · 前哨 %d/%d · 遗珍 %d/%d · 按 M 海图自由跃迁" % [lm_cnt, lm_tot, out_cnt, out_tot, rel_cnt, rel_tot]

	var seconds := int(data.get("elapsed", 0.0))
	if bool(data.get("escape_crafted", false)):
		win_title.text = "深渊跃迁逃生成功"
		win_desc.text = "四大深海领主悉数平息，远古母树星核成功制作跃迁装置！\n你已顺利冲破深海极渊，踏上星际归航之路。"
		win_time.text = "本次潜航  %02d:%02d  /  母树终章完成 · 逃生成功" % [floori(float(seconds) / 60.0), seconds % 60]
	elif bool(boss.get("defeated", false)):
		win_title.text = "深渊水龙已被击败"
		win_desc.text = "潮汐君主沉入深渊，海域终于恢复平静。\n潜航任务完成，感谢游玩《深蓝回声》。"
		win_time.text = "本次潜航  %02d:%02d  /  终章完成 · 游戏结束" % [floori(float(seconds) / 60.0), seconds % 60]
	elif is_explore:
		win_title.text = "全海域勘测已完成"
		win_desc.text = "你已探明浅海、暮光海沟与百米深渊的热液喷口全部核心地标。\n深蓝海域向勇敢的探险家致敬！"
		win_time.text = "本次探险  %02d:%02d  /  勘测度 100%%" % [floori(float(seconds) / 60.0), seconds % 60]
	else:
		win_title.text = "深海收到了回声"
		win_desc.text = "求救信标已重新上线。\n救援船正在驶来，你将平安返航。"
		win_time.text = "本次潜航  %02d:%02d  /  救援协议已启动" % [floori(float(seconds) / 60.0), seconds % 60]

func set_screen(screen: String) -> void:
	active_screen = screen
	instruments.visible = screen in ["play", "pause", "craft", "sushi", "mount_board", "map"]
	for key: String in menus:
		var menu: Control = menus[key]
		menu.visible = key == screen
		menu.mouse_filter = Control.MOUSE_FILTER_STOP if menu.visible else Control.MOUSE_FILTER_IGNORE
	if screen == "map" and is_instance_valid(sea_chart):
		sea_chart.center_on_player()
	if screen != "play":
		toast_label.hide()

func toast(message: String) -> void:
	toast_label.text = message
	toast_time = 3.6
	toast_label.modulate.a = 1.0
	toast_label.visible = active_screen in ["play", "craft", "sushi", "mount_board", "map"]

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

func _style(background: Color, border: Color = Color.TRANSPARENT, radius: int = 10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	return style

func _panel(parent: Node, rect: Rect2, anchor := Vector2.ZERO) -> Panel:
	var panel := Panel.new()
	_place(panel, parent, rect, anchor)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(PANEL, Color(0.28, 0.92, 1.0, 0.42)))
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
