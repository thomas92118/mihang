extends CanvasLayer

const WorldMap = preload("res://scripts/world_map.gd")
const Art = preload("res://scripts/art_direction.gd")
const OceanUiTheme = preload("res://scripts/presentation/ocean_ui_theme.gd")
const CharacterRoster = preload("res://scripts/presentation/character_roster.gd")
const GameplayGuide = preload("res://scripts/gameplay_guide.gd")
const GuidePanel = preload("res://scripts/presentation/guide_panel.gd")

signal start_requested(mode: String)
signal resume_requested
signal restart_requested
signal craft_requested(recipe: String)
signal pin_requested(recipe: String)
signal sushi_cook_requested(dish_id: String)
signal sushi_serve_all_requested
signal cobra_buy_requested(item_id: String)
signal open_sushi_requested
signal open_map_requested
signal mount_board_select_requested(index: int)
signal mount_board_select_all_requested
signal mount_board_store_all_requested
signal map_waypoint_set(world_xz: Vector2)
signal map_waypoint_cleared
signal fast_travel_requested(target_id: String, world_pos: Vector3, target_name: String)
signal sonar_ping_requested
signal action_requested(action: String)
signal input_settings_requested(values: Dictionary)
signal character_selected(character_id: String)
signal character_cycled(step: int)
signal showcase_rotated(step: float)
signal showcase_reset_requested
signal showcase_dragged(relative: Vector2)
signal close_requested
signal onboarding_restart_requested
signal onboarding_skip_requested

const INK := Art.PAPER
const MUTED := Art.MUTED
const CYAN := Art.CYAN
const ORANGE := Art.AMBER
const AMBER_GOLD := Art.AMBER
const PANEL := Art.PANEL
const WARM_PANEL := Color(0.075, 0.10, 0.12, 0.97)

var _detail_time := 5.0
var _previous_weapon := ""
var _previous_inventory: Dictionary = {}
var _cargo: Panel
var _journal_heading: Label
var _journal_bar: ColorRect
var _bottom_hints: Label
var _life_normal_style: StyleBoxFlat
var _life_warning_style: StyleBoxFlat
var _status_normal_style: StyleBoxEmpty
var _status_alert_style: StyleBoxFlat
var _life_alert := false
var _low_oxygen_alert := false
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
var map_focus_button: Button
var map_selected_info: Dictionary = {}
var input_controller: Node
var quick_buttons: Dictionary = {}
var settings_controls: Dictionary = {}
var menu_scrolls: Dictionary = {}
var menu_contents: Dictionary = {}
var menu_min_sizes: Dictionary = {}
var _focus_memory: Dictionary = {}
var _focus_refresh_clock := 0.0
var _hint_regex := RegEx.new()
var _hint_cache: Dictionary = {}
var _hint_generation := 0
var _touch_layout := false
var _instrument_layout: Dictionary = {}
var _settings_syncing := false
var main_char_title: Label
var main_char_subtitle: Label
var main_char_buttons: Dictionary = {}
var pause_char_btn: Button
var _displayed_character_id := ""
var guide_view: Dictionary = {}
var onboarding_panel: Panel
var onboarding_badge: Label
var onboarding_title: Label
var onboarding_bar: ProgressBar
var onboarding_desc: Label
var onboarding_sub: Label

const QUICK_ACTIONS := [
	["weapon_1", "潜水战术刀"], ["weapon_2", "破拆战斧"], ["weapon_3", "蓝光静滞枪"], ["weapon_4", "光标指示枪"],
	["aim", "切换精准瞄准"], ["scope", "远距瞄准镜"], ["dash", "涡流突进"], ["toggle_shield", "能量护盾"],
	["sonar_ping", "声呐勘测脉冲"], ["salvage_drone", "无人机打捞"], ["booster", "手持助推器"], ["lamp", "潜水探照灯"],
	["mount_toggle", "骑乘 / 离鞍"], ["recall_pets", "召回伙伴"], ["mount_board", "收纳 / 生物应援板"],
	["craft_menu", "装备制造台"], ["sushi_menu", "料理 / 商店 / 图鉴"], ["world_map", "海图与跃迁"],
	["camera_closer", "拉近第三人称视角"], ["camera_farther", "拉远第三人称视角"],
	["mount_slot_1", "选择伙伴 1"], ["mount_slot_2", "选择伙伴 2"], ["mount_slot_3", "选择伙伴 3"],
	["mount_slot_4", "选择伙伴 4"], ["mount_slot_5", "选择伙伴 5"], ["mount_slot_6", "选择伙伴 6"],
	["character_switch", "切换角色外观"], ["character_angle", "切换角色视角"], ["char_angle_reset", "角色角度回正"],
	["gameplay_guide", "潜航指南"]
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font: FontFile = preload("res://assets/fonts/NotoSansSC-Subset.otf")
	var sym_font: FontFile = preload("res://assets/fonts/Symbols-Subset.ttf")
	var controls_font: FontFile = preload("res://assets/fonts/Controls-CJK-Subset.otf")
	var fallbacks: Array[Font] = font.fallbacks.duplicate()
	for fallback: Font in [controls_font, sym_font]:
		if not fallbacks.has(fallback):
			fallbacks.append(fallback)
	font.fallbacks = fallbacks
	ThemeDB.fallback_font = font
	root.theme = OceanUiTheme.build(font)
	bathy_texture = WorldMap.build_bathymetry_texture(128)
	_build_instruments()
	_build_main()
	_build_pause()
	_build_craft()
	_build_sushi()
	_build_mount_board()
	_build_map()
	_build_win()
	_build_quick()
	_build_controls()
	_build_guide()
	_prepare_menu_scrolling()
	_cache_instrument_layout()
	_hint_regex.compile("(?<![A-Za-z0-9])(WASD|W/S|A/D|A D|空格/Ctrl|空格 Ctrl|L / F1|L/F1|T/Y|1—4|Shift|Ctrl|Tab|Esc|F1|空格|按 2|按 3|W(?=\\s*前进)|[RTYCEMNOGZVHQFBPKL])(?![A-Za-z0-9₂:.]|\\s*轴|\\s*北|\\s*东)")
	root.resized.connect(_apply_layout)
	toast_label = _label(root, "", Rect2(-390, 130, 780, 44), 15, CYAN, Vector2(0.5, 0))
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var toast_style := _style(Color(Art.INK, 0.88), Color(CYAN, 0.26), 2)
	toast_style.content_margin_left = 16
	toast_style.content_margin_right = 16
	toast_style.content_margin_top = 6
	toast_style.content_margin_bottom = 6
	toast_label.add_theme_stylebox_override("normal", toast_style)
	toast_label.hide()
	set_selected_character(CharacterRoster.DEFAULT_CHARACTER)
	set_screen("main")
	_apply_layout()

func _process(delta: float) -> void:
	_detail_time = maxf(0.0, _detail_time - delta)
	_focus_refresh_clock -= delta
	if _focus_refresh_clock <= 0.0 and menus.has(active_screen):
		_focus_refresh_clock = 0.2
		_refresh_navigation()
	if toast_time > 0.0:
		toast_time = maxf(0.0, toast_time - delta)
		_layout_toast()
		toast_label.modulate.a = minf(toast_time * 2.0, 1.0)
		toast_label.visible = toast_time > 0.0 and active_screen in ["play", "craft", "sushi", "mount_board", "map"]
	elif is_instance_valid(toast_label) and toast_label.visible:
		toast_label.hide()
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
	hit_marker.modulate = Art.DANGER if is_kill else Art.PAPER
	hit_marker.scale = Vector2(1.35, 1.35)
	hit_marker.visible = true

func _build_instruments() -> void:
	instruments = _full(root)
	instruments.name = "FlightInstruments"
	var visor_rect := ColorRect.new()
	_place(visor_rect, instruments, Rect2())
	visor_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visor_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
	uniform float breath = 0.0;
	uniform float frost = 0.0;
	void fragment() {
		vec2 p = (UV - 0.5) * 2.0;
		float edge = smoothstep(0.85, 1.9, dot(p,p));
		COLOR = vec4(mix(vec3(0.015,0.045,0.065), vec3(0.72,0.85,0.85), frost * 0.45), edge * (0.06 + breath * 0.06 + frost * 0.18));
	}"""
	visor_material = ShaderMaterial.new()
	visor_material.shader = shader
	visor_rect.material = visor_material
	_journal_bar = _line(instruments, Rect2(28, 27, 3, 22), AMBER_GOLD)
	_journal_heading = _label(instruments, "深 蓝 回 声   /   潜 航 日 志", Rect2(42, 26, 282, 20), 12, MUTED)
	mission_title = _label(instruments, "探索未知海域", Rect2(28, 60, 300, 24), 14, INK)
	mission_detail = _label(instruments, "M 勘测海图  /  N 声呐", Rect2(28, 90, 300, 38), 11, MUTED)
	mission_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	onboarding_panel = _panel(instruments, Rect2(28, 56, 268, 148))
	onboarding_panel.name = "OnboardingInstrument"
	onboarding_panel.add_theme_stylebox_override("panel", _style(Color(Art.INK, 0.72), Color(CYAN, 0.28), 3))
	onboarding_badge = _label(onboarding_panel, "初航引导 · 1/6", Rect2(12, 8, 244, 18), 14, AMBER_GOLD)
	onboarding_badge.set_meta("_no_hint", true)
	onboarding_title = _label(onboarding_panel, "立体潜航与视野", Rect2(12, 28, 244, 22), 15, INK)
	onboarding_title.set_meta("_no_hint", true)
	onboarding_bar = ProgressBar.new()
	_place(onboarding_bar, onboarding_panel, Rect2(12, 53, 244, 3))
	onboarding_bar.show_percentage = false
	onboarding_bar.max_value = 1.0
	onboarding_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	onboarding_bar.add_theme_stylebox_override("background", _style(Color(CYAN, 0.15), Color.TRANSPARENT, 1))
	onboarding_bar.add_theme_stylebox_override("fill", _style(AMBER_GOLD, Color.TRANSPARENT, 1))
	onboarding_desc = _label(onboarding_panel, "", Rect2(12, 60, 244, 60), 14, CYAN)
	onboarding_desc.clip_text = false
	onboarding_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	onboarding_sub = _label(onboarding_panel, "", Rect2(12, 122, 244, 20), 14, MUTED)
	onboarding_panel.hide()
	compass_strip = WorldMap.CompassStrip.new()
	_place(compass_strip, instruments, Rect2(-160, 18, 320, 34), Vector2(0.5, 0))
	compass_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	depth_value = _label(instruments, "012 m", Rect2(-120, 55, 240, 36), 28, INK, Vector2(0.5, 0))
	depth_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_value = _label(instruments, "阳光浅礁带", Rect2(-250, 96, 500, 26), 11, MUTED, Vector2(0.5, 0))
	status_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status_normal_style = StyleBoxEmpty.new()
	_status_alert_style = _style(Color(Art.INK, 0.84), Color(Art.DANGER, 0.56), 2)
	_status_alert_style.content_margin_left = 12
	_status_alert_style.content_margin_right = 12
	status_value.add_theme_stylebox_override("normal", _status_normal_style)
	minimap_radar = WorldMap.MinimapRadar.new()
	minimap_radar.set_bathymetry(bathy_texture)
	_place(minimap_radar, instruments, Rect2(-172, 24, 144, 160), Vector2(1, 0))
	minimap_radar.name = "RadarInstrument"
	home_value = _label(instruments, "母港 18 m", Rect2(-230, 192, 202, 24), 12, INK, Vector2(1, 0))
	home_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	explore_summary_label = _label(instruments, "勘测 0%", Rect2(-230, 222, 202, 42), 11, MUTED, Vector2(1, 0))
	explore_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pinned_panel = _panel(instruments, Rect2(-320, 282, 292, 76), Vector2(1, 0))
	pinned_title = _label(pinned_panel, "配方追踪", Rect2(14, 10, 264, 24), 11, AMBER_GOLD)
	pinned_progress = _label(pinned_panel, "", Rect2(14, 40, 264, 24), 11, INK)
	pinned_panel.hide()
	reticle = _label(instruments, "+", Rect2(-12, -16, 24, 32), 20, Color(CYAN, 0.75), Vector2(0.5, 0.5))
	reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aim_frame = _panel(instruments, Rect2(-165, -110, 330, 220), Vector2(0.5, 0.5))
	aim_frame.add_theme_stylebox_override("panel", _style(Color.TRANSPARENT, Color(CYAN, 0.2), 2))
	_label(aim_frame, "精密瞄准 / T", Rect2(12, 9, 250, 20), 10, CYAN)
	aim_frame.hide()
	scope_overlay = ColorRect.new()
	_place(scope_overlay, instruments, Rect2())
	scope_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scope_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var scope_material := ShaderMaterial.new()
	scope_material.shader = preload("res://shaders/scope.gdshader")
	scope_overlay.material = scope_material
	scope_overlay.hide()
	scope_label = _label(instruments, "", Rect2(-240, 180, 480, 24), 12, CYAN, Vector2(0.5, 0.5))
	scope_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scope_label.hide()
	charge_label = _label(instruments, "", Rect2(-160, 40, 320, 24), 12, CYAN, Vector2(0.5, 0.5))
	charge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	charge_bar = ProgressBar.new()
	_place(charge_bar, instruments, Rect2(-80, 70, 160, 3), Vector2(0.5, 0.5))
	charge_bar.show_percentage = false
	charge_bar.max_value = 1.0
	charge_bar.add_theme_stylebox_override("background", _style(Color(Art.INK, 0.7)))
	charge_bar.add_theme_stylebox_override("fill", _style(CYAN))
	charge_bar.hide()
	boss_panel = _panel(instruments, Rect2(-260, 132, 520, 68), Vector2(0.5, 0))
	boss_name = _label(boss_panel, "深渊领主", Rect2(16, 8, 488, 22), 14, INK)
	boss_bar = ProgressBar.new()
	_place(boss_bar, boss_panel, Rect2(16, 34, 488, 4))
	boss_bar.show_percentage = false
	boss_bar.add_theme_stylebox_override("background", _style(Color(Art.DANGER, 0.15)))
	boss_bar.add_theme_stylebox_override("fill", _style(Art.DANGER))
	boss_warning = _label(boss_panel, "", Rect2(16, 42, 488, 20), 11, AMBER_GOLD)
	boss_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_panel.hide()
	hit_marker = _label(instruments, "×", Rect2(-14, -18, 28, 36), 22, Color(1, 1, 1, 0), Vector2(0.5, 0.5))
	hit_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hit_marker.visible = false
	var life := _panel(instruments, Rect2(28, -148, 246, 100), Vector2(0, 1))
	life.name = "LifeSupportInstrument"
	_life_normal_style = _style(Color(Art.INK, 0.16), Color(CYAN, 0.08), 2)
	_life_warning_style = _style(Color(Art.INK, 0.86), Color(Art.DANGER, 0.68), 2)
	life.add_theme_stylebox_override("panel", _life_normal_style)
	_label(life, "O₂", Rect2(15, 12, 48, 30), 23, CYAN)
	oxygen_value = _label(life, "90", Rect2(64, 8, 66, 38), 30, INK)
	oxygen_unit = _label(life, "秒 / 氧气", Rect2(131, 22, 100, 20), 14, MUTED)
	oxygen_unit.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	oxygen_bar = ProgressBar.new()
	_place(oxygen_bar, life, Rect2(15, 52, 216, 3))
	oxygen_bar.show_percentage = false
	oxygen_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	oxygen_bar.add_theme_stylebox_override("background", _style(Color(CYAN, 0.13), Color.TRANSPARENT, 1))
	oxygen_bar.add_theme_stylebox_override("fill", _style(CYAN, Color.TRANSPARENT, 1))
	health_value = _label(life, "生命 100", Rect2(15, 69, 138, 18), 11, INK)
	_label(life, "生命支持", Rect2(161, 69, 70, 18), 10, MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var supplies := _panel(instruments, Rect2(-280, -162, 252, 114), Vector2(1, 1))
	supplies.name = "CargoInstrument"
	_cargo = supplies
	_label(supplies, "采集与补给", Rect2(15, 10, 160, 20), 11, MUTED)
	dave_status_label = _label(supplies, "", Rect2(15, 34, 222, 46), 11, INK)
	_label(supplies, "B / 料理与图鉴", Rect2(15, 86, 222, 20), 10, MUTED)
	var resource_store := _full(supplies)
	resource_store.hide()
	for kind: String in ["titanium", "copper", "quartz", "kelp", "fish_small", "shark_fragment", "abyss_fragment"]:
		resource_labels[kind] = _label(resource_store, "0", Rect2(0, 0, 20, 20), 10, MUTED)
	var weapon_panel := _panel(instruments, Rect2(-220, -115, 440, 38), Vector2(0.5, 1))
	weapon_panel.name = "WeaponInstrument"
	weapon_bar_label = _label(weapon_panel, "潜水刀", Rect2(12, 9, 416, 22), 12, INK)
	weapon_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	equipment_value = _label(instruments, "基础潜水装备", Rect2(-220, -70, 440, 18), 10, MUTED, Vector2(0.5, 1))
	equipment_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weapon_hint = _label(instruments, "", Rect2(-290, -147, 580, 22), 11, CYAN, Vector2(0.5, 1))
	weapon_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_value = _label(instruments, "", Rect2(-280, -188, 560, 30), 14, INK, Vector2(0.5, 1))
	target_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_panel = _panel(instruments, Rect2(-310, -140, 620, 92), Vector2(0.5, 1))
	sub_panel.name = "SubmarineInstrument"
	sub_name_label = _label(sub_panel, "深海斥候号", Rect2(15, 10, 230, 22), 13, INK)
	sub_speed_label = _label(sub_panel, "航速 0.0 m/s", Rect2(250, 10, 156, 22), 11, CYAN)
	sub_weapon_label = _label(sub_panel, "鱼雷就绪", Rect2(408, 10, 197, 22), 11, AMBER_GOLD)
	sub_hull_bar = ProgressBar.new()
	_place(sub_hull_bar, sub_panel, Rect2(15, 41, 300, 4))
	sub_hull_bar.max_value = 1.0
	sub_hull_bar.value = 1.0
	sub_hull_bar.show_percentage = false
	sub_hull_bar.add_theme_stylebox_override("fill", _style(CYAN))
	sub_hull_bar.add_theme_stylebox_override("background", _style(Color(CYAN, 0.13)))
	sub_hull_label = _label(sub_panel, "耐压装甲 100%", Rect2(330, 33, 275, 20), 11, MUTED)
	_label(sub_panel, "W/S 推进  A/D 转向  空格/Ctrl 升降  Shift 加速  R 攻击  E 离舱", Rect2(15, 62, 590, 20), 10, MUTED)
	sub_panel.hide()
	booster_indicator = _label(instruments, "助推巡航 / H 收起", Rect2(-220, -115, 440, 38), 12, CYAN, Vector2(0.5, 1))
	booster_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	booster_indicator.add_theme_stylebox_override("normal", _style(PANEL, Color(CYAN, 0.22)))
	booster_indicator.hide()
	tame_panel = _panel(instruments, Rect2(28, -252, 246, 64), Vector2(0, 1))
	tame_panel.name = "CompanionInstrument"
	tame_title = _label(tame_panel, "契约生物 0/20", Rect2(15, 9, 216, 20), 11, CYAN)
	tame_slots_label = _label(tame_panel, "", Rect2(15, 9, 216, 20), 10, MUTED)
	tame_slots_label.hide()
	tame_mount_label = _label(tame_panel, "O 生物应援板", Rect2(15, 34, 216, 20), 10, MUTED)
	tame_panel.hide()
	shield_label = _label(instruments, "C / 能量盾收起", Rect2(28, -178, 246, 20), 10, MUTED, Vector2(0, 1))
	var hints := _label(instruments, "E 交互   Tab 制造   M 海图   N 声呐   L 指南   K 视角   P 角色   Esc 暂停", Rect2(-420, -27, 840, 18), 10, MUTED, Vector2(0.5, 1))
	hints.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bottom_hints = hints

func _build_main() -> void:
	var menu := _menu("main", false)
	menu.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_MIDDLE:
			showcase_reset_requested.emit()
		elif event is InputEventMouseMotion and (event.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT)) != 0:
			showcase_dragged.emit(event.relative)
		elif event is InputEventScreenDrag:
			showcase_dragged.emit(event.relative)
	)
	var shade := ColorRect.new()
	_place(shade, menu, Rect2())
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){ float veil=1.0-smoothstep(0.08,0.70,UV.x); COLOR=vec4(0.015,0.07,0.12,veil*0.83); }"
	var material := ShaderMaterial.new()
	material.shader = shader
	shade.material = material
	_line(menu, Rect2(74, 72, 38, 2), AMBER_GOLD)
	_label(menu, "一 场 始 于 浅 礁 的 远 行", Rect2(126, 60, 430, 28), 14, Art.PAPER)
	_label(menu, "深蓝回声", Rect2(68, 184, 510, 100), 76, INK)
	_label(menu, "A B Y S S A L   E C H O", Rect2(78, 295, 490, 32), 18, CYAN).set_meta("_no_hint", true)
	_line(menu, Rect2(78, 365, 50, 1), AMBER_GOLD)
	_label(menu, "循着微光，游向未知。", Rect2(76, 389, 470, 40), 25, INK)
	_label(menu, "穿过摇曳的海底森林，
在沉睡的古城，听见大海的回声。", Rect2(78, 450, 470, 68), 16, MUTED)
	_button(menu, "自由探险  /  EXPLORE", Rect2(78, 536, 390, 52), func() -> void: start_requested.emit("explore"), true)
	_button(menu, "生存航程  /  SURVIVE", Rect2(78, 598, 390, 46), func() -> void: start_requested.emit("survival"))
	var main_guide_btn := _button(menu, "玩法说明 / 潜航指南", Rect2(78, 654, 190, 42), func() -> void: action_requested.emit("gameplay_guide"))
	main_guide_btn.name = "MainGuideButton"
	var main_controls_btn := _button(menu, "操作与触控设置", Rect2(278, 654, 190, 42), func() -> void: action_requested.emit("controls"))
	main_controls_btn.name = "MainControlsButton"
	var character_card := _panel(menu, Rect2(-356, 86, 336, 518), Vector2(1, 0))
	character_card.name = "CharacterSelectPanel"
	_line(character_card, Rect2(20, 26, 26, 2), AMBER_GOLD)
	_label(character_card, "潜航形态  /  P 切换", Rect2(56, 15, 260, 22), 14, CYAN)
	main_char_title = _label(character_card, "珊瑚晨曦人鱼", Rect2(20, 44, 296, 34), 24, INK)
	main_char_title.set_meta("_no_hint", true)
	main_char_subtitle = _label(character_card, "绯莓长发 · 珠母贝衣 · 碧海粉绡尾", Rect2(20, 82, 296, 22), 14, MUTED)
	main_char_subtitle.set_meta("_no_hint", true)
	var prev_btn := _button(character_card, "◀ 上一位", Rect2(20, 112, 144, 38), func() -> void: character_cycled.emit(-1))
	prev_btn.set_meta("_no_hint", true)
	var next_btn := _button(character_card, "下一位 ▶", Rect2(172, 112, 144, 38), func() -> void: character_cycled.emit(1))
	next_btn.set_meta("_no_hint", true)
	_line(character_card, Rect2(20, 160, 296, 1), Color(CYAN, 0.16))
	for i in range(CharacterRoster.CHARACTER_ORDER.size()):
		var cid: String = CharacterRoster.CHARACTER_ORDER[i]
		var prof: Dictionary = CharacterRoster.get_profile(cid)
		var c_btn := _button(character_card, str(prof["name"]), Rect2(20, 172 + i * 46, 296, 40), func() -> void: character_selected.emit(cid), cid == CharacterRoster.DEFAULT_CHARACTER)
		c_btn.name = "CharSelect_" + cid
		c_btn.set_meta("_no_hint", true)
		main_char_buttons[cid] = c_btn
	_line(character_card, Rect2(20, 452, 296, 1), Color(CYAN, 0.16))
	var rot_left_btn := _button(character_card, "◀ 左旋", Rect2(20, 462, 94, 38), func() -> void: showcase_rotated.emit(-PI * 0.25))
	rot_left_btn.name = "CharRotateLeft"
	rot_left_btn.set_meta("_no_hint", true)
	var rot_reset_btn := _button(character_card, "回正", Rect2(121, 462, 94, 38), func() -> void: showcase_reset_requested.emit())
	rot_reset_btn.name = "CharRotateReset"
	rot_reset_btn.set_meta("_no_hint", true)
	var rot_right_btn := _button(character_card, "右旋 ▶", Rect2(222, 462, 94, 38), func() -> void: showcase_rotated.emit(PI * 0.25))
	rot_right_btn.name = "CharRotateRight"
	rot_right_btn.set_meta("_no_hint", true)
	_label(menu, "九片海域  ·  一段属于你的潜航记录", Rect2(78, -52, 540, 28), 14, MUTED, Vector2(0, 1))
	_label(menu, "THE LIVING OCEAN
00 — 600 m", Rect2(-300, -94, 240, 58), 14, Art.PAPER, Vector2(1, 1)).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _build_pause() -> void:
	var menu := _menu("pause")
	var card := _panel(menu, Rect2(-250, -268, 500, 536), Vector2(0.5, 0.5))
	_line(card, Rect2(32, 31, 28, 2), AMBER_GOLD)
	_label(card, "潜航日志 / 暂停", Rect2(75, 20, 380, 24), 11, MUTED)
	_label(card, "在此稍作停留", Rect2(31, 78, 438, 54), 31, INK)
	_label(card, "生命支持已暂停。准备好后，继续你的航程。", Rect2(33, 140, 434, 42), 13, MUTED)
	_button(card, "继续潜航", Rect2(32, 205, 436, 46), func() -> void: resume_requested.emit(), true)
	var map_button := _button(card, "M / 勘测海图", Rect2(32, 261, 436, 42), func() -> void: open_map_requested.emit())
	map_button.name = "OpenSeaChartButton"
	var guide_button := _button(card, "L / 潜航指南与引导", Rect2(32, 313, 436, 42), func() -> void: action_requested.emit("gameplay_guide"))
	guide_button.name = "OpenGuideButton"
	var p_prev := _button(card, "◀", Rect2(32, 365, 52, 42), func() -> void: character_cycled.emit(-1))
	p_prev.set_meta("_no_hint", true)
	pause_char_btn = _button(card, "P / 角色：珊瑚晨曦人鱼", Rect2(92, 365, 316, 42), func() -> void: character_cycled.emit(1))
	pause_char_btn.name = "PauseCharacterButton"
	var p_next := _button(card, "▶", Rect2(416, 365, 52, 42), func() -> void: character_cycled.emit(1))
	p_next.set_meta("_no_hint", true)
	_button(card, "操作设置", Rect2(32, 419, 208, 42), func() -> void: action_requested.emit("controls"))
	_button(card, "重新开始", Rect2(252, 419, 216, 42), func() -> void: restart_requested.emit())
	_label(card, "Esc 返回海底", Rect2(32, 486, 436, 20), 10, MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _build_craft() -> void:
	var menu := _menu("craft")
	var card := _panel(menu, Rect2(-450, -350, 900, 700), Vector2(0.5, 0.5))
	_label(card, "装备制造 / 逃生舱工作台", Rect2(28, 20, 844, 22), 11, CYAN)
	_label(card, "为更深处做好准备", Rect2(27, 50, 844, 40), 28, INK)
	craft_inventory = _label(card, "", Rect2(28, 101, 844, 22), 11, MUTED)
	_line(card, Rect2(28, 130, 844, 1), Color(CYAN, 0.15))
	_recipe(card, "tank", "01", "高容量氧气瓶", "单次潜水时间延长至 150 秒", "2 钛 + 2 海藻", 145)
	_recipe(card, "fins", "02", "轻量脚蹼", "水下游动速度提升 50%", "1 钛 + 2 海藻", 198)
	_recipe(card, "rebreather", "03", "深海循环呼吸器", "抵消深水压强带来的额外耗氧", "2 钛 + 1 铜 + 2 海藻", 251)
	_recipe(card, "axe", "04", "破拆战斧", "165° 范围横扫 · 基础伤害 70", "2 钛 + 1 铜", 304)
	_recipe(card, "sonic", "05", "蓝光静滞枪", "蓝色激光 · 蓄力静滞 · 远距瞄准", "2 钛 + 2 石英 + 1 铜", 357)
	_recipe(card, "biomod_dash", "06", "生体模组 · 涡流突进", "Q 突进 16 米，紧急躲避攻击", "1 鲨齿碎片 + 2 钛", 410)
	_recipe(card, "reinforce_sharp", "07", "深铸武器 · 锋锐硬化", "全武器攻击力永久增加 20", "1 鲨齿碎片 + 1 钛", 463)
	_recipe(card, "reinforce_sonic", "08", "深铸武器 · 晶体共鸣", "全武器攻击力永久增加 35", "1 晶核碎片 + 1 石英", 516)
	_recipe(card, "beacon", "09", "修复求救信标", "建立返航通信，继续探索深海主线", "3 钛 + 2 铜 + 2 石英", 569)
	_button(card, "返回潜航", Rect2(28, 643, 136, 38), func() -> void: resume_requested.emit())
	_button(card, "料理与图鉴 / B", Rect2(176, 643, 174, 38), func() -> void: open_sushi_requested.emit())
	_label(card, "追踪配方，便可在潜航时查看所需材料。", Rect2(368, 651, 504, 20), 11, MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _build_sushi() -> void:
	var menu := _menu("sushi")
	var card := _panel(menu, Rect2(-500, -358, 1000, 716), Vector2(0.5, 0.5))
	_label(card, "班乔料理吧 / 柯布拉商店 / 玛琳卡图鉴", Rect2(28, 18, 944, 22), 11, AMBER_GOLD)
	_label(card, "来自海洋的馈赠", Rect2(27, 47, 944, 38), 28, INK)
	sushi_header_label = _label(card, "", Rect2(28, 93, 944, 24), 13, INK)
	sushi_ingredients_label = _label(card, "", Rect2(28, 123, 944, 20), 11, MUTED)
	_line(card, Rect2(28, 152, 944, 1), Color(CYAN, 0.15))
	_sushi_row(card, "goldfish_nigiri", "荧光金鱼握寿司", "1 鲜鱼 · 65 金币", "恢复生命 35 / 氧气 30 · 氧气上限 +10s", 166)
	_sushi_row(card, "kelp_roll", "深海海藻鲜肉卷", "2 生肉 + 1 海藻 · 150 金币", "生命上限永久 +20，并立即回满生命", 228)
	_sushi_row(card, "shark_sashimi", "暗礁巨鲨厚切刺身", "2 生肉 + 1 骨齿 · 260 金币", "全武器攻击力永久 +18", 290)
	_sushi_row(card, "abyss_kaiseki", "深渊海王黄金怀石", "3 生肉 + 1 兽皮 + 1 甲壳 · 420 金币", "全武器攻击 +30 · 无人机 +1 · 负重 +15kg", 352)
	_button(card, "挂牌营业 / 售出富余鲜鱼与生肉", Rect2(28, 420, 540, 38), func() -> void: sushi_serve_all_requested.emit(), true)
	_line(card, Rect2(28, 477, 540, 1), Color(CYAN, 0.15))
	_label(card, "柯布拉潜航补给", Rect2(28, 484, 540, 20), 12, CYAN)
	_cobra_row(card, "cargo_box", "扩容生态箱 / 120 金币", "负重上限 +25kg · 无人机配额 +1，并补满", 512)
	_cobra_row(card, "oxygen_capsule", "浓缩氧气胶囊 / 80 金币", "氧气上限 +25 秒，立即补满氧气与生命", 560)
	_cobra_row(card, "duff_coating", "达夫超导涂层 / 180 金币", "全武器攻击力永久 +25", 608)
	var marinca_box := _panel(card, Rect2(592, 160, 380, 514))
	_label(marinca_box, "玛琳卡 / 海洋生物图鉴", Rect2(18, 14, 344, 22), 14, INK)
	marinca_summary_label = _label(marinca_box, "", Rect2(18, 42, 344, 42), 11, AMBER_GOLD)
	_line(marinca_box, Rect2(18, 90, 344, 1), Color(CYAN, 0.15))
	marinca_grid_label = _label(marinca_box, "", Rect2(18, 98, 344, 344), 14, INK)
	marinca_grid_label.add_theme_constant_override("line_spacing", -1)
	_line(marinca_box, Rect2(18, 448, 344, 1), Color(CYAN, 0.12))
	_label(marinca_box, "静滞活捕或无人机打捞可获得三星品质。\n每张三星图鉴使料理售价增加 12%。", Rect2(18, 456, 344, 48), 14, MUTED)
	_button(card, "返回潜航 / B", Rect2(28, 665, 156, 34), func() -> void: resume_requested.emit())
	_label(card, "V 无人机打捞 / E 采集与交互", Rect2(204, 673, 768, 18), 10, MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _sushi_row(parent: Control, dish_id: String, title: String, cost_str: String, desc_str: String, y: float) -> void:
	_label(parent, title, Rect2(28, y, 416, 21), 14, INK)
	_label(parent, cost_str, Rect2(28, y + 22, 416, 17), 10, AMBER_GOLD)
	_label(parent, desc_str, Rect2(28, y + 40, 416, 17), 10, MUTED)
	sushi_cook_buttons[dish_id] = _button(parent, "烹饪售出", Rect2(460, y + 12, 108, 34), func() -> void: sushi_cook_requested.emit(dish_id))

func _cobra_row(parent: Control, item_id: String, title: String, desc_str: String, y: float) -> void:
	_label(parent, title, Rect2(28, y, 416, 20), 13, INK)
	_label(parent, desc_str, Rect2(28, y + 23, 416, 18), 10, MUTED)
	cobra_buy_buttons[item_id] = _button(parent, "购买升级", Rect2(460, y + 3, 108, 34), func() -> void: cobra_buy_requested.emit(item_id))

func _recipe(parent: Control, key: String, number: String, title: String, detail: String, cost: String, y: float) -> void:
	_label(parent, number, Rect2(28, y + 3, 36, 26), 12, CYAN)
	_label(parent, title, Rect2(72, y, 330, 23), 14, INK)
	_label(parent, detail, Rect2(72, y + 24, 560, 18), 10, MUTED)
	_label(parent, cost, Rect2(410, y + 3, 248, 20), 11, CYAN)
	pin_buttons[key] = _button(parent, "追踪", Rect2(674, y + 2, 76, 34), func() -> void: pin_requested.emit(key))
	craft_buttons[key] = _button(parent, "制作", Rect2(762, y + 2, 110, 34), func() -> void: craft_requested.emit(key), key == "beacon")
	_line(parent, Rect2(72, y + 47, 800, 1), Color(CYAN, 0.07))

func _build_mount_board() -> void:
	var menu := _menu("mount_board")
	var card := _panel(menu, Rect2(-470, -350, 940, 700), Vector2(0.5, 0.5))
	_label(card, "生物契约 / 护卫与骑乘", Rect2(28, 18, 884, 22), 11, CYAN)
	_label(card, "与你同行的伙伴", Rect2(27, 47, 884, 38), 28, INK)
	mount_board_summary_label = _label(card, "", Rect2(28, 96, 884, 22), 11, MUTED)
	mount_board_select_all_btn = _button(card, "全选出战", Rect2(28, 132, 160, 36), func() -> void: mount_board_select_all_requested.emit(), true)
	mount_board_store_all_btn = _button(card, "全部收回", Rect2(200, 132, 160, 36), func() -> void: mount_board_store_all_requested.emit())
	_label(card, "选择生物即可召唤；护卫会在遭到攻击时迎击。", Rect2(382, 141, 530, 20), 11, MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mount_board_empty_label = _label(card, "尚未缔结生物契约。\n使用蓝光枪静滞受伤巨兽，再靠近按 E 驯服。", Rect2(90, 326, 760, 60), 15, MUTED)
	mount_board_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mount_board_slot_buttons.clear()
	for i in range(20):
		var col: int = i % 4
		var row: int = int(i / 4)
		var slot_idx: int = i
		var btn := _button(card, "%02d / 尚未契约" % (i + 1), Rect2(28 + col * 224, 189 + row * 87, 212, 73), func() -> void: mount_board_select_requested.emit(slot_idx))
		btn.add_theme_font_size_override("font_size", 14)
		btn.clip_text = true
		btn.disabled = true
		mount_board_slot_buttons.append(btn)
	_button(card, "返回潜航 / O", Rect2(28, 647, 170, 34), func() -> void: resume_requested.emit())
	_label(card, "G 骑乘或离鞍 / Z 召回 / O 收纳与管理", Rect2(222, 655, 690, 18), 10, MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _build_map() -> void:
	var menu := _menu("map")
	var card := _panel(menu, Rect2(-530, -364, 1060, 728), Vector2(0.5, 0.5))
	_label(card, "潜航档案 / 海域勘测与洋流跃迁", Rect2(24, 16, 1012, 20), 11, CYAN)
	map_rank_label = _label(card, "勘测海图", Rect2(24, 43, 1012, 28), 20, INK)
	sea_chart = WorldMap.SeaChartCanvas.new()
	sea_chart.set_bathymetry(bathy_texture)
	_place(sea_chart, card, Rect2(24, 84, 600, 600))
	sea_chart.waypoint_set.connect(func(xz: Vector2) -> void: map_waypoint_set.emit(xz))
	sea_chart.waypoint_cleared.connect(func() -> void: map_waypoint_cleared.emit())
	sea_chart.fast_travel_requested.connect(func(tid: String, wpos: Vector3, tname: String) -> void: fast_travel_requested.emit(tid, wpos, tname))
	sea_chart.selection_changed.connect(_on_sea_chart_selection)
	sea_chart.sidebar_focus_requested.connect(_focus_map_sidebar)
	map_focus_button = _button(card, "操作海图 / 中键平移 · 滚轮缩放 · 左键选点", Rect2(24, 689, 600, 27), func() -> void: sea_chart.grab_focus())
	var side := _panel(card, Rect2(648, 84, 388, 550))
	_label(side, "海域勘测记录", Rect2(18, 16, 352, 22), 14, INK)
	map_stats_label = _label(side, "", Rect2(18, 48, 352, 82), 12, MUTED)
	_line(side, Rect2(18, 140, 352, 1), Color(CYAN, 0.15))
	_label(side, "当前位置情报", Rect2(18, 155, 352, 20), 11, CYAN)
	map_sel_title = _label(side, "选择地标或海域坐标", Rect2(18, 184, 352, 24), 16, INK)
	map_sel_coords = _label(side, "坐标 -- / 水深 --", Rect2(18, 215, 352, 20), 11, AMBER_GOLD)
	map_sel_desc = _label(side, "探索并激活前哨，建立你的远洋航线。", Rect2(18, 245, 352, 56), 12, MUTED)
	map_sel_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_travel_btn = _button(side, "洋流跃迁至此", Rect2(18, 312, 352, 38), func() -> void:
		if not map_selected_info.is_empty() and bool(map_selected_info.get("can_travel", false)):
			fast_travel_requested.emit(str(map_selected_info["id"]), map_selected_info["pos"], str(map_selected_info["name"]))
	, true)
	map_travel_btn.disabled = true
	map_waypoint_btn = _button(side, "设为导航标点", Rect2(18, 360, 352, 34), func() -> void:
		if not map_selected_info.is_empty() and map_selected_info.has("pos"):
			var p3: Vector3 = map_selected_info["pos"]
			map_waypoint_set.emit(Vector2(p3.x, p3.z))
	)
	map_waypoint_btn.disabled = true
	map_clear_wp_btn = _button(side, "清除导航标点", Rect2(18, 404, 352, 32), func() -> void: map_waypoint_cleared.emit())
	_button(side, "居中", Rect2(18, 450, 104, 32), func() -> void: sea_chart.center_on_player())
	_button(side, "+ 放大", Rect2(134, 450, 112, 32), func() -> void: sea_chart.adjust_zoom(1.25))
	_button(side, "− 缩小", Rect2(258, 450, 112, 32), func() -> void: sea_chart.adjust_zoom(0.8))
	_button(side, "N / 声呐勘测脉冲", Rect2(18, 496, 352, 34), func() -> void: sonar_ping_requested.emit())
	_label(card, "○ 母港  □ 前哨  ◇ 标点  △ 潜艇  · 遗珍", Rect2(648, 643, 388, 18), 10, MUTED)
	_button(card, "返回潜航 / M", Rect2(648, 674, 388, 38), func() -> void: resume_requested.emit())

func _on_sea_chart_selection(info: Dictionary) -> void:
	map_selected_info = info
	if not is_instance_valid(map_sel_title):
		return
	if info.is_empty():
		map_sel_title.text = "点击左侧海图选择地标或标点"
		map_sel_coords.text = "坐标: -- · 水深: --"
		map_sel_desc.text = "点击任意位置放置标点，或选择已解锁的前哨站/地标进行快速跃迁。"
		map_travel_btn.disabled = true
		map_waypoint_btn.disabled = true
		return
	var p3: Vector3 = info.get("pos", Vector3.ZERO)
	var can_tr: bool = bool(info.get("can_travel", false))
	map_sel_title.text = str(info.get("name", "海域坐标"))
	map_sel_coords.text = "坐标 X:%+d  Z:%+d · 深度 %dm" % [roundi(p3.x), roundi(p3.z), maxi(0, roundi(-p3.y))]
	map_sel_desc.text = str(info.get("desc", ""))
	map_travel_btn.disabled = not can_tr
	map_travel_btn.text = "洋流跃迁至此" if can_tr else "尚未解锁 / 前往勘测或激活"
	map_waypoint_btn.disabled = false

func _build_win() -> void:
	var menu := _menu("win")
	var card := _panel(menu, Rect2(-340, -240, 680, 480), Vector2(0.5, 0.5))
	_line(card, Rect2(36, 38, 38, 2), AMBER_GOLD)
	_label(card, "潜航记录 / 航程里程碑", Rect2(90, 27, 554, 22), 11, CYAN)
	win_title = _label(card, "深海收到了回声", Rect2(35, 95, 610, 58), 32, INK)
	win_desc = _label(card, "", Rect2(36, 185, 608, 86), 15, MUTED)
	win_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	win_time = _label(card, "本次潜航 00:00", Rect2(36, 292, 608, 24), 12, CYAN)
	_button(card, "继续探索", Rect2(36, 368, 330, 48), func() -> void: resume_requested.emit(), true)
	_button(card, "开启新航程", Rect2(382, 368, 262, 48), func() -> void: restart_requested.emit())

func _build_quick() -> void:
	var menu := _menu("quick")
	var card := _panel(menu, Rect2(-430, -366, 860, 732), Vector2(0.5, 0.5))
	_label(card, "潜航操作 / 快捷面板", Rect2(28, 18, 804, 24), 12, CYAN)
	_label(card, "选择装备与能力", Rect2(27, 48, 804, 38), 28, INK)
	_label(card, "方向键选择 · 确认执行 · 返回继续潜航", Rect2(28, 90, 804, 22), 12, MUTED)
	for i in range(QUICK_ACTIONS.size()):
		var entry: Array = QUICK_ACTIONS[i]
		var action := str(entry[0])
		var title := str(entry[1])
		var button := _button(card, title, Rect2(28 + (i % 3) * 270, 122 + int(i / 3) * 50, 254, 42), func() -> void: action_requested.emit(action))
		button.name = "Quick_" + action
		quick_buttons[action] = button
	_button(card, "操作设置", Rect2(28, 668, 254, 44), func() -> void: action_requested.emit("controls"))
	_button(card, "返回潜航", Rect2(568, 668, 254, 44), func() -> void: close_requested.emit(), true)

func _build_controls() -> void:
	var menu := _menu("controls")
	var card := _panel(menu, Rect2(-350, -320, 700, 640), Vector2(0.5, 0.5))
	_label(card, "操作设置 / 自动保存", Rect2(28, 20, 644, 24), 12, CYAN)
	_label(card, "调整你的潜航手感", Rect2(27, 54, 644, 38), 28, INK)
	_setting_slider(card, "gamepad_sensitivity", "手柄视角灵敏度", 120, 0.2, 3.0, 0.1)
	_setting_slider(card, "touch_sensitivity", "触控视角灵敏度", 178, 0.2, 3.0, 0.1)
	_setting_slider(card, "deadzone", "手柄摇杆死区", 236, 0.05, 0.6, 0.05)
	_setting_slider(card, "touch_scale", "触控按钮大小", 294, 0.75, 1.5, 0.05)
	_setting_slider(card, "touch_opacity", "触控按钮透明度", 352, 0.2, 1.0, 0.05)
	var invert := CheckButton.new()
	_place(invert, card, Rect2(28, 414, 300, 44))
	invert.text = "反转视角 Y 轴"
	invert.focus_mode = Control.FOCUS_ALL
	invert.toggled.connect(func(enabled: bool) -> void:
		if not _settings_syncing:
			input_settings_requested.emit({"invert_y": enabled})
	)
	settings_controls["invert_y"] = invert
	_label(card, "触控显示", Rect2(28, 482, 250, 24), 14, INK)
	var mode := OptionButton.new()
	_place(mode, card, Rect2(320, 470, 352, 44))
	mode.add_item("自动 / 根据输入设备")
	mode.add_item("始终显示")
	mode.add_item("隐藏触控")
	mode.item_selected.connect(func(index: int) -> void:
		if not _settings_syncing:
			input_settings_requested.emit({"touch_mode": ["auto", "on", "off"][index]})
	)
	settings_controls["touch_mode"] = mode
	_label(card, "手柄：左杆推进 / 转向，右杆观察，肩键升降。\n触屏：左摇杆移动，右侧滑动观察，攻击可长按蓄力。", Rect2(28, 532, 644, 46), 12, MUTED)
	var controls_guide_btn := _button(card, "查看潜航指南", Rect2(28, 588, 220, 40), func() -> void: action_requested.emit("gameplay_guide"))
	controls_guide_btn.name = "ControlsGuideButton"
	_button(card, "返回", Rect2(260, 588, 412, 40), func() -> void: close_requested.emit(), true)

func _build_guide() -> void:
	var menu := _menu("guide")
	guide_view = GuidePanel.build(menu, GameplayGuide.get_chapters(), {
		"format_text": func(txt: String) -> String: return format_input_text(txt),
		"on_restart_onboarding": func() -> void: onboarding_restart_requested.emit(),
		"on_skip_onboarding": func() -> void: onboarding_skip_requested.emit(),
		"on_open_controls": func() -> void: action_requested.emit("controls"),
		"on_close": func() -> void: close_requested.emit(),
	})

func _setting_slider(parent: Control, key: String, title: String, y: float, minimum: float, maximum: float, increment: float) -> void:
	_label(parent, title, Rect2(28, y + 8, 274, 26), 14, INK)
	var slider := HSlider.new()
	_place(slider, parent, Rect2(320, y, 252, 44))
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = increment
	slider.focus_mode = Control.FOCUS_ALL
	settings_controls[key] = slider
	var value_label := _label(parent, "", Rect2(590, y + 8, 82, 26), 13, CYAN)
	slider.value_changed.connect(func(value: float) -> void:
		value_label.text = "%.2f" % value
		if not _settings_syncing:
			input_settings_requested.emit({key: value})
	)
	slider.set_meta("value_label", value_label)

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
		_set_font_color(oxygen_value, CYAN)
		oxygen_unit.text = "探险  /  无限制"
		oxygen_bar.max_value = 100.0
		oxygen_bar.value = 100.0
		oxygen_bar.modulate = CYAN
	else:
		var oxygen := float(data.get("oxygen", 90.0))
		var maximum := maxf(float(data.get("max_oxygen", 90.0)), 1.0)
		oxygen_value.text = "%02d" % ceili(maxf(oxygen, 0.0))
		_set_font_color(oxygen_value, ORANGE if oxygen < maximum * 0.25 else INK)
		oxygen_unit.text = "秒  /  氧气"
		oxygen_bar.max_value = maximum
		oxygen_bar.value = oxygen
		oxygen_bar.modulate = ORANGE if oxygen < maximum * 0.25 else Color.WHITE

	health_value.text = "＋  生命 %d" % ceili(float(data.get("health", 100.0)))
	_set_font_color(health_value, Art.DANGER if float(data.get("health", 100.0)) < 30.0 else INK)
	var depth := maxf(float(data.get("depth", 0.0)), 0.0)
	depth_value.text = "%03d m" % roundi(depth)

	var biome: String = str(data.get("biome", "浅海生态区"))
	var oxygen_level := float(data.get("oxygen", 90.0))
	var max_oxygen_level := maxf(float(data.get("max_oxygen", 90.0)), 1.0)
	var low_oxygen := not is_explore and oxygen_level < max_oxygen_level * 0.25
	if low_oxygen != _low_oxygen_alert:
		_low_oxygen_alert = low_oxygen
		status_value.add_theme_stylebox_override("normal", _status_alert_style if low_oxygen else _status_normal_style)
	if low_oxygen:
		status_value.text = "氧气不足  /  请上浮、靠近巨砗磲或前往科考前哨站"
		_set_font_color(status_value, ORANGE)
	else:
		status_value.text = biome
		_set_font_color(status_value, CYAN)

	home_value.text = "母港 %d m" % roundi(float(data.get("distance_home", 0.0)))
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
		map_rank_label.text = "探索家头衔：【%s】 · 全域探索度 %d%%" % [exp_rank, exp_pct]
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
		var w_str := ("超重" if overweight else "负重") + " %.1f/%.0f kg" % [cur_weight, max_weight]
		var d_str := "∞" if is_explore else "%d/%d" % [drone_cur, drone_max]
		dave_status_label.text = "%s · %d G\n无人机 %s / V 打捞" % [
			w_str, gold_val, d_str
		]
		_set_font_color(dave_status_label, ORANGE if overweight else CYAN)

	if is_instance_valid(sushi_header_label):
		var rep_lv: int = int(data.get("sushi_reputation", 1))
		var served_cnt: int = int(data.get("dishes_served", 0))
		sushi_header_label.text = " 深海金币: %d G · 餐厅声望 Lv.%d (已售 %d 份) · 背包负重: %.1f / %.0f kg" % [
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
		marinca_summary_label.text = "已收集物种: %d / %d · ★★★ 完美图鉴: %d\n三星料理售价加成: +%d%%" % [
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
		_set_font_color(pinned_title, ORANGE if is_all_ready else CYAN)
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
	var weapon_names := {"knife": "潜水刀", "axe": "破拆战斧", "sonic": "蓝光静滞枪", "marker": "光标指示枪"}
	var upgrade_info := " · 强化 %d / +%d" % [w_level, int(w_bonus)] if w_level > 0 else ""
	weapon_bar_label.text = "1—4 切换 / %s%s" % [str(weapon_names.get(cur_w, "潜水装备")), upgrade_info]
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
	weapon_hint.text = ("能量恢复 %.1f s" % cooldown) if is_gun and cooldown > 0.0 else ("R 激光 / 长按蓄力静滞 · T 瞄准 · Y 远距镜" if is_gun else "")
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
	tame_panel.visible = beast_cnt > 0 and not scoped
	tame_title.text = "契约 %d/20 · 出战 %d / O 管理" % [beast_cnt, deployed_cnt]
	if mount_idx >= 0 and mount_idx < beast_cnt:
		tame_mount_label.text = "骑乘 %s / G 离鞍" % str(beasts[mount_idx].get("name", "海兽"))
	else:
		tame_mount_label.text = "护卫待命 · 战力 ×%.0f" % atk_mult

	if is_instance_valid(mount_board_summary_label):
		mount_board_summary_label.text = "已契约 %d/20 · 出战 %d · 战力 ×%.0f · 中立防卫" % [
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
				var state_str := "出战中" if is_dep else "可召唤"
				s_btn.text = "%02d / %s\n生命 %d · %s" % [idx + 1, b_name, b_hp, state_str]
				_set_font_color(s_btn, AMBER_GOLD if is_dep else INK)
			else:
				s_btn.visible = beast_cnt > 0
				s_btn.disabled = true
				s_btn.text = "%02d / 尚未契约" % (idx + 1)

	var is_shield: bool = bool(data.get("shield_active", false))
	shield_label.text = "C / 能量盾防御中" if is_shield else "C / 能量盾收起"
	_set_font_color(shield_label, CYAN if is_shield else MUTED)

	if fighting:
		mission_title.text = "巨兽领域 / %s" % str(boss.get("name", "深渊领主"))
		mission_detail.text = "残血时蓄力静滞，靠近按 E 契约驯服。"
	elif bool(data.get("mother_tree_active", false)) and not bool(data.get("escape_crafted", false)):
		var items_cnt: int = int(data.get("tree_items_collected", 0))
		if items_cnt >= 3:
			mission_title.text = "母树圣物齐集 / 返回母港"
			mission_detail.text = "母树遗物 (3/3) · 或按 M 继续自由探索开放大海域"
		else:
			var dist_tree: float = float(data.get("distance_mother_tree", 300.0))
			mission_title.text = "潜入母树圣所"
			mission_detail.text = "深海极渊母树 %d 米 · 收集核心物资 (%d/3)" % [roundi(dist_tree), items_cnt]
	elif has_wp:
		var wp_dist: int = roundi(p_pos.distance_to(wp_pos))
		mission_title.text = "沿标点继续勘测 / %d%%" % exp_pct
		mission_detail.text = "✦ 距离目标标点 %d 米 · 按 M 查看海图或切换跃迁点" % wp_dist
	else:
		mission_title.text = "开放海域探索 / %d%%" % exp_pct
		if has_near_out:
			mission_detail.text = "最近未激活前哨 %dm · 按 M 海图跃迁 / N 声呐寻宝" % roundi(best_out_d)
		else:
			mission_detail.text = "地标 %d/%d · 前哨 %d/%d · 遗珍 %d/%d · 按 M 海图自由跃迁" % [lm_cnt, lm_tot, out_cnt, out_tot, rel_cnt, rel_tot]

	if cur_w != _previous_weapon or inventory != _previous_inventory:
		_detail_time = 3.5
		_previous_weapon = cur_w
		_previous_inventory = inventory.duplicate()
	var details := _detail_time > 0.0 or aiming or charging or fighting or not target.is_empty()
	weapon_bar_label.get_parent().visible = details and not in_sub and not booster_on
	equipment_value.visible = details and not in_sub and not scoped
	_cargo.visible = details or overweight
	shield_label.visible = is_shield or details
	var onboarding: Dictionary = data.get("onboarding", {})
	sync_onboarding_state(onboarding)
	var ob_active := bool(onboarding.get("active", false))
	var show_onboarding := ob_active and not scoped and not fighting and not in_sub
	var story_route := bool(data.get("mother_tree_active", false)) and not bool(data.get("escape_crafted", false))
	var show_mission := (has_wp or fighting or details or story_route) and not show_onboarding
	mission_title.visible = show_mission
	mission_detail.visible = show_mission
	explore_summary_label.visible = details
	_journal_heading.modulate.a = 0.92 if (show_mission or show_onboarding) else 0.28
	if is_instance_valid(_journal_bar):
		_journal_bar.modulate.a = 0.92 if (show_mission or show_onboarding) else 0.26
	weapon_hint.visible = details and not scoped and not in_sub and not booster_on
	reticle.visible = not scoped and (aiming or charging or not target.is_empty() or in_sub or cur_w in ["sonic", "marker", "marker_gun"])
	tame_panel.visible = beast_cnt > 0 and not scoped and (details or mount_idx >= 0 or fighting)
	if is_instance_valid(onboarding_panel):
		onboarding_panel.visible = show_onboarding
		if show_onboarding:
			var completed_banner := bool(onboarding.get("completed_banner", false))
			var step_idx := int(onboarding.get("step_index", 1))
			var step_tot := maxi(1, int(onboarding.get("step_total", 6)))
			onboarding_badge.text = "初航引导 · 已完成" if completed_banner else ("初航引导 · %d/%d" % [step_idx, step_tot])
			_set_font_color(onboarding_badge, CYAN if completed_banner else AMBER_GOLD)
			onboarding_title.text = str(onboarding.get("title", "初航实操引导"))
			onboarding_bar.value = clampf(float(onboarding.get("progress_ratio", 0.0)), 0.0, 1.0)
			var raw_desc := str(onboarding.get("instruction", ""))
			onboarding_desc.set_meta("_hint_source", raw_desc)
			onboarding_desc.text = format_input_text(raw_desc)
			onboarding_desc.set_meta("_hint_rendered", onboarding_desc.text)
			onboarding_desc.set_meta("_hint_generation", _hint_generation)
			var raw_sub := str(onboarding.get("sub_hint", ""))
			onboarding_sub.set_meta("_hint_source", raw_sub)
			onboarding_sub.text = format_input_text(raw_sub)
			onboarding_sub.set_meta("_hint_rendered", onboarding_sub.text)
			onboarding_sub.set_meta("_hint_generation", _hint_generation)
			onboarding_panel.modulate.a = 0.52 if low_oxygen else 0.96
			_layout_onboarding()
	var life_alert := low_oxygen or float(data.get("health", 100.0)) < 30.0
	var quiet_explore := not show_mission and not show_onboarding and not life_alert and not in_sub and not booster_on and not scoped
	var life_panel: Panel = instruments.get_node("LifeSupportInstrument")
	if life_alert != _life_alert:
		_life_alert = life_alert
		life_panel.add_theme_stylebox_override("panel", _life_warning_style if life_alert else _life_normal_style)
	life_panel.modulate.a = 1.0 if life_alert else (0.88 if quiet_explore else 0.98)
	if is_instance_valid(compass_strip):
		compass_strip.modulate.a = 0.72 if quiet_explore else 0.96
	depth_value.modulate.a = 0.90 if quiet_explore else 1.0
	status_value.modulate.a = 1.0 if low_oxygen else (0.68 if quiet_explore else 0.90)
	if is_instance_valid(minimap_radar):
		minimap_radar.modulate.a = 0.80 if quiet_explore else 0.98
	home_value.modulate.a = 0.68 if quiet_explore else 0.92
	if is_instance_valid(_bottom_hints):
		_bottom_hints.modulate.a = 0.48 if quiet_explore else 0.86
	_layout_toast()
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
	if data.has("character_id"):
		set_selected_character(str(data["character_id"]))
	_apply_device_hints()
	_apply_touch_visibility()

func set_selected_character(character_id: String) -> void:
	var cid := CharacterRoster.normalize_id(character_id)
	if _displayed_character_id == cid:
		return
	_displayed_character_id = cid
	var profile: Dictionary = CharacterRoster.get_profile(cid)
	var cname := str(profile.get("name", cid))
	if is_instance_valid(main_char_title):
		main_char_title.text = cname
		_set_font_color(main_char_title, profile.get("badge_color", INK))
	if is_instance_valid(main_char_subtitle):
		main_char_subtitle.text = str(profile.get("subtitle", ""))
	for id: String in main_char_buttons:
		var btn: Button = main_char_buttons[id]
		if not is_instance_valid(btn):
			continue
		var p: Dictionary = CharacterRoster.get_profile(id)
		var active_sel := id == cid
		btn.text = ("✦  " if active_sel else "") + str(p.get("name", id))
		OceanUiTheme.button(btn, active_sel)
	if is_instance_valid(pause_char_btn):
		var src := "P / 角色：" + cname
		pause_char_btn.set_meta("_hint_source", src)
		pause_char_btn.text = format_input_text(src)
		pause_char_btn.set_meta("_hint_rendered", pause_char_btn.text)
		pause_char_btn.set_meta("_hint_generation", _hint_generation)

func sync_onboarding_state(onboarding: Dictionary) -> void:
	if guide_view.has("sync_onboarding_status"):
		(guide_view["sync_onboarding_status"] as Callable).call(onboarding)

func set_screen(screen: String) -> void:
	var focused := root.get_viewport().gui_get_focus_owner()
	if is_instance_valid(focused) and menus.has(active_screen) and menus[active_screen].is_ancestor_of(focused):
		_focus_memory[active_screen] = focused
	if screen == "play" and is_instance_valid(focused):
		focused.release_focus()
	active_screen = screen
	instruments.visible = screen == "play"
	for key: String in menus:
		var menu: Control = menus[key]
		menu.visible = key == screen
		menu.mouse_filter = Control.MOUSE_FILTER_STOP if menu.visible else Control.MOUSE_FILTER_IGNORE
	if screen == "map" and is_instance_valid(sea_chart):
		sea_chart.center_on_player()
	if screen != "play":
		toast_label.hide()
	if screen == "controls":
		_sync_input_settings()
	_refresh_navigation.call_deferred()

func toast(message: String) -> void:
	toast_label.text = format_input_text(message)
	toast_label.set_meta("_hint_source", message)
	toast_label.set_meta("_hint_rendered", toast_label.text)
	toast_time = 3.6
	toast_label.modulate.a = 1.0
	toast_label.visible = active_screen in ["play", "craft", "sushi", "mount_board", "map"]
	_layout_toast()

func _layout_toast() -> void:
	if not is_instance_valid(toast_label):
		return
	var safe := get_layout_safe_rect()
	var width := minf(680.0, maxf(160.0, safe.size.x - 40.0))
	var left := safe.position.x + (safe.size.x - width) * 0.5
	var top := safe.position.y + 134.0
	if is_instance_valid(status_value) and (status_value.is_visible_in_tree() or (instruments.visible and status_value.visible)):
		top = maxf(top, status_value.get_global_rect().end.y + 12.0)
	if is_instance_valid(boss_panel) and (boss_panel.is_visible_in_tree() or (instruments.visible and boss_panel.visible)):
		var boss_rect := boss_panel.get_global_rect()
		if left < boss_rect.end.x and left + width > boss_rect.position.x:
			top = maxf(top, boss_rect.end.y + 12.0)
	# Allow long discoveries to wrap without crossing the depth or boss readouts.
	var height := 66.0 if toast_label.text.length() > int(width / 17.0) else 44.0
	if is_instance_valid(onboarding_panel) and (onboarding_panel.is_visible_in_tree() or (instruments.visible and onboarding_panel.visible)):
		var ob_rect := onboarding_panel.get_global_rect()
		if left < ob_rect.end.x and left + width > ob_rect.position.x and top < ob_rect.end.y and top + height > ob_rect.position.y:
			top = maxf(top, ob_rect.end.y + 10.0)
	_set_control_rect(toast_label, Rect2(left, top, width, height))

func configure_input(controller: Node) -> void:
	input_controller = controller
	_hint_cache.clear()
	_hint_generation += 1
	if is_instance_valid(controller):
		if not controller.device_changed.is_connected(_on_input_device_changed):
			controller.device_changed.connect(_on_input_device_changed)
		if not controller.settings_changed.is_connected(_on_input_settings_changed):
			controller.settings_changed.connect(_on_input_settings_changed)
		sea_chart.input_controller = controller
	_sync_input_settings()
	_apply_layout()
	_apply_device_hints()

func _on_input_device_changed(_device: String) -> void:
	_hint_cache.clear()
	_hint_generation += 1
	_apply_layout()
	_apply_device_hints()
	_refresh_navigation.call_deferred()

func _on_input_settings_changed() -> void:
	_hint_cache.clear()
	_hint_generation += 1
	_sync_input_settings()
	_apply_layout()
	_apply_device_hints()

func get_input_hint(action: String) -> String:
	if is_instance_valid(input_controller):
		return str(input_controller.hint(action))
	return str({"forward": "W", "backward": "S", "left": "A", "right": "D", "ascend": "空格", "descend": "Ctrl", "attack": "R", "aim": "T", "scope": "Y", "interact": "E", "craft_menu": "Tab", "pause_game": "Esc", "world_map": "M", "sonar_ping": "N", "mount_board": "O", "toggle_shield": "C", "dash": "Q", "booster": "H", "lamp": "F", "sprint": "Shift", "recall_pets": "Z", "mount_toggle": "G", "salvage_drone": "V", "sushi_menu": "B", "character_switch": "P", "character_angle": "K", "char_angle_reset": "Home", "weapon_2": "2", "weapon_3": "3", "quick_menu": "快捷操作", "gameplay_guide": "L"}.get(action, action))

func _join_hints(first_action: String, second_action: String, separator := "/") -> String:
	var first := get_input_hint(first_action)
	var second := get_input_hint(second_action)
	return first if first == second else first + separator + second

func format_input_text(text: String) -> String:
	if not is_instance_valid(input_controller) or str(input_controller.active_device) == "keyboard":
		return text
	if text == "A B Y S S A L   E C H O":
		return text
	var matches := _hint_regex.search_all(text)
	if matches.is_empty():
		return text
	if _hint_cache.is_empty():
		_hint_cache = {
			"WASD": get_input_hint("forward"),
			"W": get_input_hint("forward"),
			"W/S": _join_hints("forward", "backward"),
			"A/D": _join_hints("left", "right"),
			"A D": _join_hints("left", "right", " "),
			"空格/Ctrl": _join_hints("ascend", "descend"),
			"空格 Ctrl": _join_hints("ascend", "descend", " / "),
			"L / F1": get_input_hint("gameplay_guide"),
			"L/F1": get_input_hint("gameplay_guide"),
			"T/Y": _join_hints("aim", "scope"),
			"1—4": get_input_hint("quick_menu"), "Shift": get_input_hint("sprint"),
			"Ctrl": get_input_hint("descend"), "空格": get_input_hint("ascend"),
			"按 2": "使用 " + get_input_hint("weapon_2"),
			"按 3": "使用 " + get_input_hint("weapon_3"), "Tab": get_input_hint("craft_menu"),
			"Esc": get_input_hint("pause_game"), "F1": get_input_hint("gameplay_guide"), "R": get_input_hint("attack"), "T": get_input_hint("aim"),
			"Y": get_input_hint("scope"), "C": get_input_hint("toggle_shield"), "E": get_input_hint("interact"),
			"M": get_input_hint("world_map"), "N": get_input_hint("sonar_ping"), "O": get_input_hint("mount_board"),
			"G": get_input_hint("mount_toggle"), "Z": get_input_hint("recall_pets"), "V": get_input_hint("salvage_drone"),
			"H": get_input_hint("booster"), "Q": get_input_hint("dash"), "F": get_input_hint("lamp"), "B": get_input_hint("sushi_menu"), "P": get_input_hint("character_switch"), "K": get_input_hint("character_angle"), "L": get_input_hint("gameplay_guide")
		}
	var result := ""
	var cursor := 0
	for match_result: RegExMatch in matches:
		var start := match_result.get_start()
		var token := match_result.get_string()
		result += text.substr(cursor, start - cursor)
		if token == "G" and _is_currency_unit(text, start):
			result += token
		else:
			result += str(_hint_cache.get(token, token))
		cursor = match_result.get_end()
	return result + text.substr(cursor)

static func _is_currency_unit(text: String, index: int) -> bool:
	var pos := index - 1
	while pos >= 0 and (text[pos] == " " or text[pos] == "\t"):
		pos -= 1
	return pos >= 0 and text.unicode_at(pos) >= 48 and text.unicode_at(pos) <= 57

func _apply_device_hints() -> void:
	if not is_instance_valid(root):
		return
	var device := str(input_controller.active_device) if is_instance_valid(input_controller) else "keyboard"
	if is_instance_valid(map_focus_button):
		var description := "操作海图 / 中键平移 · 滚轮缩放 · 左键选点"
		if device == "touch":
			description = "操作海图 / 单指平移 · 双指缩放 · 点选坐标"
		elif device == "gamepad":
			description = "操作海图 / 左杆平移 · 十字键选点 · X/□ 操作栏"
		map_focus_button.text = description
		map_focus_button.set_meta("_hint_source", description)
	if is_instance_valid(minimap_radar):
		minimap_radar.map_hint = get_input_hint("world_map")
	for node in root.find_children("*", "Control", true, false):
		if not (node is Label or node is Button):
			continue
		if bool(node.get_meta("_no_hint", false)):
			continue
		if menus.has("controls") and menus["controls"].is_ancestor_of(node):
			continue
		var current := str(node.text)
		if int(node.get_meta("_hint_generation", -1)) == _hint_generation and current == str(node.get_meta("_hint_rendered", "")):
			continue
		var source := str(node.get_meta("_hint_source", current))
		if current != str(node.get_meta("_hint_rendered", current)):
			source = current
		var rendered := format_input_text(source)
		node.set_meta("_hint_source", source)
		node.set_meta("_hint_rendered", rendered)
		node.set_meta("_hint_generation", _hint_generation)
		if current != rendered:
			node.text = rendered

func _sync_input_settings() -> void:
	if settings_controls.is_empty():
		return
	_settings_syncing = true
	var values: Dictionary = {"gamepad_sensitivity": 1.0, "touch_sensitivity": 1.0, "deadzone": 0.2, "touch_scale": 1.0, "touch_opacity": 0.75, "invert_y": false, "touch_mode": "auto"}
	if is_instance_valid(input_controller):
		values.merge(input_controller.settings, true)
	for key: String in settings_controls:
		var control: Control = settings_controls[key]
		if control is HSlider:
			control.set_value_no_signal(float(values[key]))
			(control.get_meta("value_label") as Label).text = "%.2f" % control.value
		elif control is CheckButton:
			control.set_pressed_no_signal(bool(values[key]))
		elif control is OptionButton:
			control.select(maxi(0, ["auto", "on", "off"].find(str(values[key]))))
	_settings_syncing = false

func _unhandled_input(event: InputEvent) -> void:
	if not menus.has(active_screen):
		return
	if event.is_action_pressed("ui_cancel") and active_screen != "main":
		close_requested.emit()
		get_viewport().set_input_as_handled()
	elif active_screen == "map" and event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_X:
		if sea_chart.has_focus():
			_focus_map_sidebar()
		else:
			sea_chart.grab_focus()
		get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	# Tab keeps its existing workbench shortcut after menus gain keyboard focus.
	# Shift+Tab and the direction keys remain available for focus navigation.
	if active_screen in ["craft", "sushi", "mount_board", "map"] and event is InputEventKey and event.pressed and not event.echo and not event.shift_pressed and event.is_action_pressed("craft_menu"):
		action_requested.emit("craft_menu")
		get_viewport().set_input_as_handled()

func _focus_map_sidebar() -> void:
	if not map_waypoint_btn.disabled:
		map_waypoint_btn.grab_focus()
	else:
		map_clear_wp_btn.grab_focus()

func _focusable_controls() -> Array[Control]:
	var controls: Array[Control] = []
	if not menus.has(active_screen):
		return controls
	for node in menus[active_screen].find_children("*", "Control", true, false):
		if not node.is_visible_in_tree() or node.focus_mode == Control.FOCUS_NONE:
			continue
		if node is BaseButton and not node.disabled:
			controls.append(node)
		elif node is HSlider or node == sea_chart:
			controls.append(node)
	return controls

func _refresh_navigation() -> void:
	var controls := _focusable_controls()
	if controls.is_empty():
		return
	for i in range(controls.size()):
		var control: Control = controls[i]
		control.focus_next = control.get_path_to(controls[(i + 1) % controls.size()])
		control.focus_previous = control.get_path_to(controls[posmod(i - 1, controls.size())])
		for direction: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			var best: Control = control
			var best_score := INF
			var axis: Vector2 = {SIDE_LEFT: Vector2.LEFT, SIDE_TOP: Vector2.UP, SIDE_RIGHT: Vector2.RIGHT, SIDE_BOTTOM: Vector2.DOWN}[direction]
			for candidate: Control in controls:
				if candidate == control:
					continue
				var delta := candidate.get_global_rect().get_center() - control.get_global_rect().get_center()
				var projection := delta.dot(axis)
				if projection <= 4.0:
					continue
				var perpendicular := absf(delta.cross(axis))
				var score := projection + perpendicular * 3.0
				if score < best_score:
					best = candidate
					best_score = score
			control.set_focus_neighbor(direction, control.get_path_to(best))
	var focused := root.get_viewport().gui_get_focus_owner()
	if focused not in controls:
		var remembered = _focus_memory.get(active_screen)
		if is_instance_valid(remembered) and remembered in controls:
			remembered.grab_focus()
		elif active_screen == "map":
			sea_chart.grab_focus()
		else:
			controls[0].grab_focus()

func _prepare_menu_scrolling() -> void:
	menu_min_sizes = {"main": Vector2(860, 740), "pause": Vector2(532, 568), "craft": Vector2(932, 732), "sushi": Vector2(1032, 748), "mount_board": Vector2(972, 732), "map": Vector2(1092, 760), "win": Vector2(712, 512), "quick": Vector2(892, 748), "controls": Vector2(732, 672), "guide": Vector2(992, 732)}
	for key: String in menus:
		var menu: Control = menus[key]
		var children := menu.get_children()
		var scroll := ScrollContainer.new()
		menu.add_child(scroll)
		scroll.name = "AccessibleScroll"
		scroll.follow_focus = true
		scroll.scroll_deadzone = 12
		scroll.mouse_filter = Control.MOUSE_FILTER_PASS
		var content := Control.new()
		scroll.add_child(content)
		content.name = "MenuContent"
		content.mouse_filter = Control.MOUSE_FILTER_PASS
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.size_flags_vertical = Control.SIZE_EXPAND_FILL
		for child in children:
			if child is ColorRect:
				continue
			child.reparent(content, false)
		menu_scrolls[key] = scroll
		menu_contents[key] = content

func get_layout_safe_rect() -> Rect2:
	var available := Rect2(Vector2.ZERO, root.size)
	if DisplayServer.get_name() != "headless" and (OS.has_feature("android") or OS.has_feature("ios")):
		var safe := DisplayServer.get_display_safe_area()
		var window_size := Vector2(DisplayServer.window_get_size())
		if safe.size.x > 0 and safe.size.y > 0 and window_size.x > 0 and window_size.y > 0:
			var scale_factor := root.size / window_size
			available = available.intersection(Rect2(Vector2(safe.position) * scale_factor, Vector2(safe.size) * scale_factor))
	return available

func _cache_instrument_layout() -> void:
	for node in instruments.find_children("*", "Control", true, false):
		_instrument_layout[node] = [node.anchor_left, node.anchor_top, node.anchor_right, node.anchor_bottom, node.offset_left, node.offset_top, node.offset_right, node.offset_bottom]

func _set_control_rect(control: Control, rect: Rect2, anchor := Vector2.ZERO) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.anchor_left = anchor.x
	control.anchor_right = anchor.x
	control.anchor_top = anchor.y
	control.anchor_bottom = anchor.y
	control.offset_left = rect.position.x
	control.offset_top = rect.position.y
	control.offset_right = rect.end.x
	control.offset_bottom = rect.end.y

func _apply_layout() -> void:
	if not is_instance_valid(root) or menu_scrolls.is_empty():
		return
	var safe := get_layout_safe_rect()
	_set_control_rect(instruments, safe)
	var frame := safe.grow(-16.0)
	for key: String in menu_scrolls:
		var scroll: ScrollContainer = menu_scrolls[key]
		_set_control_rect(scroll, frame)
		var content: Control = menu_contents[key]
		content.custom_minimum_size = menu_min_sizes[key]
		content.size = frame.size.max(content.custom_minimum_size)
		if key == "main":
			for child in content.get_children():
				if child is OceanUiTheme.ExpeditionPlate:
					child.visible = frame.size.x >= 1050.0
	_touch_layout = false
	if is_instance_valid(input_controller):
		var mode := str(input_controller.settings.get("touch_mode", "auto"))
		_touch_layout = mode == "on" or (mode == "auto" and (str(input_controller.active_device) == "touch" or (DisplayServer.is_touchscreen_available() and str(input_controller.active_device) != "gamepad")))
	for node: Control in _instrument_layout:
		var old: Array = _instrument_layout[node]
		node.anchor_left = old[0]
		node.anchor_top = old[1]
		node.anchor_right = old[2]
		node.anchor_bottom = old[3]
		node.offset_left = old[4]
		node.offset_top = old[5]
		node.offset_right = old[6]
		node.offset_bottom = old[7]
	if _touch_layout:
		var life: Control = instruments.get_node("LifeSupportInstrument")
		_set_control_rect(life, Rect2(20, 96 if safe.size.y < 650.0 else 144, 246, 100))
		_set_control_rect(shield_label, Rect2(20, 202 if safe.size.y < 650.0 else 250, 246, 20))
		_set_control_rect(tame_panel, Rect2(20, 282, 246, 64))
		var center_width := minf(440.0, maxf(200.0, safe.size.x * 0.38))
		_set_control_rect(weapon_bar_label.get_parent(), Rect2(-center_width * 0.5, -115, center_width, 38), Vector2(0.5, 1))
		_set_control_rect(weapon_bar_label, Rect2(12, 9, center_width - 24, 22))
		weapon_bar_label.clip_text = true
		_set_control_rect(equipment_value, Rect2(-center_width * 0.5, -70, center_width, 18), Vector2(0.5, 1))
		equipment_value.clip_text = true
		_set_control_rect(booster_indicator, Rect2(-center_width * 0.5, -115, center_width, 38), Vector2(0.5, 1))
		_set_control_rect(sub_panel, Rect2(-center_width * 0.5, -160, center_width, 112), Vector2(0.5, 1))
		_set_control_rect(sub_name_label, Rect2(12, 6, center_width - 24, 22))
		_set_control_rect(sub_speed_label, Rect2(12, 28, center_width - 24, 22))
		_set_control_rect(sub_weapon_label, Rect2(12, 50, center_width - 24, 22))
		_set_control_rect(sub_hull_bar, Rect2(12, 78, center_width - 24, 4))
		_set_control_rect(sub_hull_label, Rect2(12, 86, center_width - 24, 20))
		if safe.size.y < 650.0:
			_set_control_rect(boss_panel, Rect2(-294, 100, 274, 68), Vector2(1, 0))
			_set_control_rect(boss_name, Rect2(16, 8, 242, 22))
			_set_control_rect(boss_bar, Rect2(16, 34, 242, 4))
			_set_control_rect(boss_warning, Rect2(16, 42, 242, 20))
			boss_name.clip_text = true
			boss_warning.clip_text = true
	_layout_onboarding()
	_apply_touch_visibility()
	_layout_toast()
	_refresh_navigation.call_deferred()

func _layout_onboarding() -> void:
	if not is_instance_valid(onboarding_panel) or not is_instance_valid(root):
		return
	var safe := get_layout_safe_rect()
	if _touch_layout:
		if safe.size.y < 650.0:
			_set_control_rect(onboarding_panel, Rect2(-248, 125, 232, 72), Vector2(1, 0))
			_set_control_rect(onboarding_badge, Rect2(8, 4, 216, 16))
			_set_control_rect(onboarding_title, Rect2(8, 20, 216, 18))
			_set_control_rect(onboarding_bar, Rect2(8, 40, 216, 2))
			_set_control_rect(onboarding_desc, Rect2(8, 44, 216, 24))
			onboarding_desc.clip_text = true
			onboarding_sub.visible = false
		else:
			var y_pos := 354.0 if (is_instance_valid(tame_panel) and tame_panel.visible) else 278.0
			_set_control_rect(onboarding_panel, Rect2(20, y_pos, 260, 148))
			_set_control_rect(onboarding_badge, Rect2(12, 8, 236, 18))
			_set_control_rect(onboarding_title, Rect2(12, 28, 236, 22))
			_set_control_rect(onboarding_bar, Rect2(12, 53, 236, 3))
			_set_control_rect(onboarding_desc, Rect2(12, 60, 236, 60))
			_set_control_rect(onboarding_sub, Rect2(12, 122, 236, 20))
			onboarding_desc.clip_text = false
			onboarding_sub.visible = true
	else:
		_set_control_rect(onboarding_panel, Rect2(28, 56, 268, 148))
		_set_control_rect(onboarding_badge, Rect2(12, 8, 244, 18))
		_set_control_rect(onboarding_title, Rect2(12, 28, 244, 22))
		_set_control_rect(onboarding_bar, Rect2(12, 53, 244, 3))
		_set_control_rect(onboarding_desc, Rect2(12, 60, 244, 60))
		_set_control_rect(onboarding_sub, Rect2(12, 122, 244, 20))
		onboarding_desc.clip_text = false
		onboarding_sub.visible = true

func _apply_touch_visibility() -> void:
	var compact := _touch_layout and root.size.y < 650.0
	if _touch_layout:
		instruments.get_node("CargoInstrument").hide()
	minimap_radar.visible = not compact
	home_value.visible = not compact
	if compact:
		mission_detail.hide()
		explore_summary_label.hide()
		pinned_panel.hide()
		tame_panel.hide()
		weapon_hint.hide()
	if is_instance_valid(_bottom_hints):
		_bottom_hints.visible = not compact
	for node in sub_panel.get_children():
		if node is Label and str(node.get_meta("_hint_source", node.text)).begins_with("W/S"):
			node.visible = not _touch_layout

func _set_font_color(ctrl: Control, col: Color) -> void:
	if ctrl.get_meta("_fc", Color(-1.0, -1.0, -1.0, -1.0)) != col:
		ctrl.set_meta("_fc", col)
		ctrl.add_theme_color_override("font_color", col)

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
	label.add_theme_font_size_override("font_size", maxi(font_size, 14))
	label.clip_text = true
	label.tooltip_text = text
	label.add_theme_color_override("font_color", color)
	if parent == instruments:
		label.add_theme_color_override("font_outline_color", Color(0.012, 0.036, 0.055, 0.88))
		label.add_theme_constant_override("outline_size", 2)
		label.add_theme_color_override("font_shadow_color", Color(0.008, 0.024, 0.038, 0.62))
		label.add_theme_constant_override("shadow_offset_x", 0)
		label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _style(background: Color, border: Color = Color.TRANSPARENT, radius: int = 4) -> StyleBoxFlat:
	return OceanUiTheme.surface(background, border, radius)

func _panel(parent: Node, rect: Rect2, anchor := Vector2.ZERO) -> Panel:
	var panel := Panel.new()
	_place(panel, parent, rect, anchor)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _style(Color(Art.INK, 0.28) if parent == instruments else PANEL, Color(CYAN, 0.09) if parent == instruments else Color(CYAN, 0.18)))
	return panel

func _line(parent: Node, rect: Rect2, color: Color) -> ColorRect:
	var line := ColorRect.new()
	_place(line, parent, rect)
	line.color = color
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line

func _button(parent: Node, text: String, rect: Rect2, callback: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	_place(button, parent, rect)
	button.text = text
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	OceanUiTheme.button(button, primary)
	button.pressed.connect(callback)
	return button
