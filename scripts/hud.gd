extends CanvasLayer

const WorldMap = preload("res://scripts/world_map.gd")
const Art = preload("res://scripts/art_direction.gd")
const OceanUiTheme = preload("res://scripts/presentation/ocean_ui_theme.gd")
const CharacterRoster = preload("res://scripts/presentation/character_roster.gd")
const GameplayGuide = preload("res://scripts/gameplay_guide.gd")
const GuidePanel = preload("res://scripts/presentation/guide_panel.gd")
const QuestPanel = preload("res://scripts/presentation/quest_panel.gd")
const LoadoutPanel = preload("res://scripts/presentation/loadout_panel.gd")
const SafeArea = preload("res://scripts/presentation/safe_area.gd")
const SCOPE_EXIT_ICON: Texture2D = preload("res://assets/ui/touch_icons/scope_exit.png")

signal start_requested(mode: String)
signal continue_requested
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
signal open_quests_requested
signal quest_track_requested(quest_id: String, objective_id: String)
signal quest_tracker_toggle_requested
signal quest_nav_requested(world_pos: Vector3, label: String, open_map: bool)
signal quest_bounty_refresh_requested
signal open_loadout_requested
signal loadout_equip_slot_requested(slot_idx: int, weapon_id: String)
signal loadout_upgrade_weapon_requested(weapon_id: String)
signal loadout_toggle_mod_requested(weapon_id: String, mod_id: String)
signal loadout_select_tactical_requested(skill_id: String)

const INK := Art.PAPER
const MUTED := Art.MUTED
const CYAN := Art.CYAN
const ORANGE := Art.AMBER
const AMBER_GOLD := Art.AMBER
const PANEL := Art.PANEL
const WARM_PANEL := Color(0.075, 0.10, 0.12, 0.97)
const GRAPHICS_QUALITY_VALUES := ["auto", "performance", "high"]
const MODAL_MENU_KEYS := ["pause", "craft", "sushi", "mount_board", "map", "quick", "controls", "guide", "quests", "loadout"]
const QUEST_BANNER_DURATION := 3.2
const QUEST_BANNER_FADE_IN := 0.25
const QUEST_BANNER_FADE_OUT := 0.45

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
var visor_rect: ColorRect
var visor_material: ShaderMaterial
var _last_frost := 0.0
var _last_breath := 0.0
var pinned_panel: Panel
var pinned_title: Label
var pinned_progress: Label
var _compact_pin_label: Label
var pin_buttons: Dictionary = {}
var hit_marker: Label
var hit_marker_timer: float = 0.0
var reticle: Label
var aim_frame: Panel
var _aim_frame_label: Label
var scope_overlay: ColorRect
var scope_label: Label
var charge_label: Label
var charge_bar: ProgressBar
var weapon_hint: Label
var boss_panel: Panel
var boss_name: Label
var boss_bar: ProgressBar
var boss_poise_bar: ProgressBar
var boss_warning: Label
var _boss_poise_normal_fill: StyleBoxFlat
var _boss_poise_stagger_fill: StyleBoxFlat
var _boss_stagger_active := false
var combat_strip: Panel
var _combat_strip_desktop_style: StyleBoxFlat
var _combat_strip_touch_style: StyleBoxFlat
var _combat_shield_lbl: Label
var _combat_shield_bar: ProgressBar
var _combat_shield_normal_fill: StyleBoxFlat
var _combat_shield_over_fill: StyleBoxFlat
var _combat_flux_lbl: Label
var _combat_flux_bar: ProgressBar
var _combat_flux_normal_fill: StyleBoxFlat
var _combat_flux_ready_fill: StyleBoxFlat
var _combat_heat_lbl: Label
var _combat_heat_bar: ProgressBar
var _combat_heat_normal_fill: StyleBoxFlat
var _combat_heat_over_fill: StyleBoxFlat
var _combat_art_lbl: Label
var _combat_tac_lbl: Label
var _combat_cmd_lbl: Label
var _combat_strip_want_visible := false
var _combat_ult_ready := false
var _combat_show_heat := false
var _combat_show_cmd := false
var _combat_pulse_clock := 0.0
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
var mount_board_slot_rows: Array[Control] = []
var mount_board_slot_buttons: Array[Button] = []
var mount_board_ride_buttons: Array[Button] = []
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
var quest_view: Dictionary = {}
var _quest_journal_synced := false
var loadout_view: Dictionary = {}
var _loadout_synced := false
var quest_banner_panel: Panel
var _quest_banner_accent: ColorRect
var _quest_banner_title: Label
var _quest_banner_detail: Label
var _quest_banner_queue: Array[Dictionary] = []
var _quest_banner_current: Dictionary = {}
var _quest_banner_timer := 0.0
var onboarding_panel: Panel
var onboarding_badge: Label
var onboarding_title: Label
var onboarding_bar: ProgressBar
var onboarding_desc: Label
var onboarding_sub: Label
var onboarding_close_btn: Button
var continue_voyage_btn: Button
var continue_summary_label: Label
var _can_continue_voyage := false
var scope_exit_btn: Button
var _scoped_active := false
var _weapon_flash_time := 0.0
var _is_narrow := false
var _is_short := false
var _is_portrait := false
var _is_compact := false
var _life_o2_label: Label
var _life_caption_label: Label
var _modal_cards: Dictionary = {}
var _backdrop_press_pos := Vector2.ZERO
var _backdrop_tracking := false
var _backdrop_max_drift := 0.0
var _backdrop_touches: Dictionary = {}
var _radar_press_pos := Vector2.ZERO
var _radar_tracking := false
var _safe_poll_clock := 0.0
var _last_safe_rect := Rect2()
var _main_shade_material: ShaderMaterial
var _touch_margins: Dictionary = {}
var _touch_margins_vp_size := Vector2.ZERO
var _overweight_active := false
var _cargo_wants_visible := false
var _main_ui: Dictionary = {}
var _pause_ui: Dictionary = {}
var _craft_ui: Dictionary = {}
var _sushi_ui: Dictionary = {}
var _sushi_active_tab := 0
var _mount_ui: Dictionary = {}
var _map_ui: Dictionary = {}
var _win_ui: Dictionary = {}
var _quick_ui: Dictionary = {}
var _controls_ui: Dictionary = {}

const QUICK_ACTIONS := [
	["weapon_1", "潜水战术刀"], ["weapon_2", "破拆战斧"], ["weapon_3", "蓝光静滞枪"], ["weapon_4", "光标指示枪"],
	["aim", "切换精准瞄准"], ["scope", "远距瞄准镜"], ["dash", "涡流突进"], ["toggle_shield", "能量护盾"],
	["sonar_ping", "声呐勘测脉冲"], ["salvage_drone", "无人机打捞"], ["booster", "手持助推器"], ["lamp", "潜水探照灯"],
	["mount_toggle", "骑乘 / 离鞍"], ["recall_pets", "召回伙伴"],
	["mount_board", "打开生物应援板"], ["recall_all_mounts", "收回全部伙伴"],
	["craft_menu", "装备制造台"], ["loadout_menu", "武装配置"], ["sushi_menu", "料理 / 商店 / 图鉴"], ["world_map", "海图与跃迁"],
	["camera_closer", "拉近第三人称视角"], ["camera_farther", "拉远第三人称视角"],
	["mount_slot_1", "选择伙伴 1"], ["mount_slot_2", "选择伙伴 2"], ["mount_slot_3", "选择伙伴 3"],
	["mount_slot_4", "选择伙伴 4"], ["mount_slot_5", "选择伙伴 5"], ["mount_slot_6", "选择伙伴 6"],
	["character_switch", "切换角色外观"], ["character_angle", "切换角色视角"], ["char_angle_reset", "角色角度回正"],
	["char_rotate_left", "角色左旋"], ["char_rotate_right", "角色右旋"],
	["char_tilt_up", "角色上仰"], ["char_tilt_down", "角色下俯"],
	["char_roll_left", "角色左倾"], ["char_roll_right", "角色右倾"],
	["quest_log", "潜航任务日志"],
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
	_build_quests()
	_build_loadout()
	_prepare_menu_scrolling()
	_cache_instrument_layout()
	_hint_regex.compile("(?<![A-Za-z0-9])(WASD|W/S|A/D|A D|空格/Ctrl|空格 Ctrl|L / F1|L/F1|T/Y|1—4|按住鼠标右键|鼠标右键|方向键|Home|Shift|Ctrl|Tab|Esc|F2|F1|空格|按 1|按 2|按 3|按 4|4(?=\\s*指示枪)|W(?=\\s*前进)|(?<=\\[)[XI~](?=\\])|[RTYCEMNOGZVHQFBPKLU])(?![A-Za-z0-9₂:.]|\\s*轴|\\s*北|\\s*东)")
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

func _notification(what: int) -> void:
	if what in [
		NOTIFICATION_WM_WINDOW_FOCUS_OUT,
		NOTIFICATION_APPLICATION_FOCUS_OUT,
		NOTIFICATION_APPLICATION_PAUSED,
		NOTIFICATION_EXIT_TREE,
	]:
		_backdrop_touches.clear()
		_backdrop_tracking = false
		_radar_tracking = false

func _process(delta: float) -> void:
	_detail_time = maxf(0.0, _detail_time - delta)
	_weapon_flash_time = maxf(0.0, _weapon_flash_time - delta)
	_safe_poll_clock -= delta
	if _safe_poll_clock <= 0.0:
		_safe_poll_clock = 0.2
		var cur_safe := _safe_area_rect()
		if not cur_safe.position.is_equal_approx(_last_safe_rect.position) or not cur_safe.size.is_equal_approx(_last_safe_rect.size):
			_apply_layout()
	_focus_refresh_clock -= delta
	if _focus_refresh_clock <= 0.0 and menus.has(active_screen):
		_focus_refresh_clock = 0.2
		_refresh_navigation()
	if toast_time > 0.0:
		toast_time = maxf(0.0, toast_time - delta)
		_layout_toast()
		toast_label.modulate.a = minf(toast_time * 2.0, 1.0)
		toast_label.visible = toast_time > 0.0 and active_screen in ["play", "craft", "sushi", "mount_board", "map", "quests", "loadout"]
	elif is_instance_valid(toast_label) and toast_label.visible:
		toast_label.hide()
	_process_quest_banner(delta)
	_process_combat_visuals(delta)
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
	visor_rect = ColorRect.new()
	visor_rect.name = "VisorOverlay"
	_place(visor_rect, root, Rect2())
	visor_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visor_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
	uniform float breath = 0.0;
	uniform float frost = 0.0;
	uniform float base_vignette = 0.06;
	void fragment() {
		vec2 p = (UV - 0.5) * 2.0;
		float edge = smoothstep(0.85, 1.9, dot(p,p));
		COLOR = vec4(mix(vec3(0.015,0.045,0.065), vec3(0.72,0.85,0.85), frost * 0.45), edge * (base_vignette + breath * 0.06 + frost * 0.18));
	}"""
	visor_material = ShaderMaterial.new()
	visor_material.shader = shader
	visor_rect.material = visor_material
	visor_rect.hide()
	scope_overlay = ColorRect.new()
	scope_overlay.name = "ScopeOverlay"
	_place(scope_overlay, root, Rect2())
	scope_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scope_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var scope_material := ShaderMaterial.new()
	scope_material.shader = preload("res://shaders/scope.gdshader")
	scope_overlay.material = scope_material
	scope_overlay.hide()
	instruments = _full(root)
	instruments.name = "FlightInstruments"
	_journal_bar = _line(instruments, Rect2(28, 27, 3, 22), AMBER_GOLD)
	_journal_heading = _label(instruments, "深 蓝 回 声   /   潜 航 日 志", Rect2(42, 26, 282, 22), 12, MUTED)
	mission_title = _label(instruments, "探索未知海域", Rect2(28, 60, 320, 24), 14, INK)
	mission_detail = _label(instruments, "M 勘测海图  /  N 声呐", Rect2(28, 88, 340, 72), 11, MUTED)
	mission_detail.clip_text = false
	mission_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest_banner_panel = _panel(instruments, Rect2(-240, 128, 480, 64), Vector2(0.5, 0))
	quest_banner_panel.name = "QuestBannerInstrument"
	quest_banner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quest_banner_panel.add_theme_stylebox_override("panel", _style(Color(Art.INK, 0.88), Color(CYAN, 0.56), 3))
	_quest_banner_accent = _line(quest_banner_panel, Rect2(0, 0, 4, 64), CYAN)
	_quest_banner_title = _label(quest_banner_panel, "", Rect2(16, 8, 448, 24), 14, CYAN)
	_quest_banner_title.set_meta("_no_hint", true)
	_quest_banner_detail = _label(quest_banner_panel, "", Rect2(16, 32, 448, 24), 14, INK)
	_quest_banner_detail.clip_text = false
	_quest_banner_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest_banner_panel.hide()
	onboarding_panel = _panel(instruments, Rect2(28, 56, 268, 148))
	onboarding_panel.name = "OnboardingInstrument"
	onboarding_panel.add_theme_stylebox_override("panel", _style(Color(Art.INK, 0.72), Color(CYAN, 0.28), 3))
	onboarding_badge = _label(onboarding_panel, "初航引导 · 1/6", Rect2(12, 6, 244, 22), 14, AMBER_GOLD)
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
	onboarding_close_btn = _button(onboarding_panel, "", Rect2(232, 4, 30, 30), func() -> void: onboarding_skip_requested.emit())
	onboarding_close_btn.name = "OnboardingSkipIconButton"
	onboarding_close_btn.custom_minimum_size = Vector2(28, 28)
	onboarding_close_btn.focus_mode = Control.FOCUS_NONE
	onboarding_close_btn.set_meta("_no_hint", true)
	_apply_pure_icon_button_style(onboarding_close_btn, SCOPE_EXIT_ICON)
	onboarding_close_btn.hide()
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
	minimap_radar.gui_input.connect(_handle_radar_gui_input)
	home_value = _label(instruments, "母港 18 m", Rect2(-230, 192, 202, 24), 12, INK, Vector2(1, 0))
	home_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	explore_summary_label = _label(instruments, "勘测 0%", Rect2(-230, 222, 202, 42), 11, MUTED, Vector2(1, 0))
	explore_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pinned_panel = _panel(instruments, Rect2(-320, 282, 292, 76), Vector2(1, 0))
	pinned_title = _label(pinned_panel, "配方追踪", Rect2(14, 10, 264, 24), 11, AMBER_GOLD)
	pinned_progress = _label(pinned_panel, "", Rect2(14, 40, 264, 24), 11, INK)
	pinned_panel.hide()
	_compact_pin_label = _label(instruments, "", Rect2(-184, 180, 172, 24), 14, CYAN, Vector2(1, 0))
	_compact_pin_label.name = "CompactPinnedRecipeLabel"
	_compact_pin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_compact_pin_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_compact_pin_label.clip_text = true
	_compact_pin_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_compact_pin_label.set_meta("_no_hint", true)
	var pin_pill := _style(Color(Art.INK, 0.78), Color(CYAN, 0.26), 3)
	pin_pill.content_margin_left = 8
	pin_pill.content_margin_right = 8
	pin_pill.content_margin_top = 1
	pin_pill.content_margin_bottom = 1
	_compact_pin_label.add_theme_stylebox_override("normal", pin_pill)
	_compact_pin_label.hide()
	reticle = _label(instruments, "+", Rect2(-12, -16, 24, 32), 20, Color(CYAN, 0.75), Vector2(0.5, 0.5))
	reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aim_frame = _panel(instruments, Rect2(-165, -110, 330, 220), Vector2(0.5, 0.5))
	aim_frame.add_theme_stylebox_override("panel", _style(Color.TRANSPARENT, Color(CYAN, 0.2), 2))
	_aim_frame_label = _label(aim_frame, "精密瞄准 / T", Rect2(12, 8, 250, 22), 14, CYAN)
	aim_frame.hide()
	scope_label = _label(instruments, "", Rect2(-240, 180, 480, 24), 12, CYAN, Vector2(0.5, 0.5))
	scope_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	scope_label.hide()
	scope_exit_btn = _button(instruments, "退出瞄准", Rect2(-124, 68, 108, 44), func() -> void: action_requested.emit("scope"), true)
	scope_exit_btn.name = "ScopeExitButton"
	scope_exit_btn.custom_minimum_size = Vector2(108, 44)
	scope_exit_btn.focus_mode = Control.FOCUS_NONE
	scope_exit_btn.set_meta("_no_hint", true)
	scope_exit_btn.hide()
	charge_label = _label(instruments, "", Rect2(-160, 40, 320, 24), 12, CYAN, Vector2(0.5, 0.5))
	charge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	charge_bar = ProgressBar.new()
	_place(charge_bar, instruments, Rect2(-80, 70, 160, 3), Vector2(0.5, 0.5))
	charge_bar.show_percentage = false
	charge_bar.max_value = 1.0
	charge_bar.add_theme_stylebox_override("background", _style(Color(Art.INK, 0.7)))
	charge_bar.add_theme_stylebox_override("fill", _style(CYAN))
	charge_bar.hide()
	boss_panel = _panel(instruments, Rect2(-260, 132, 520, 74), Vector2(0.5, 0))
	boss_name = _label(boss_panel, "深渊领主", Rect2(16, 6, 488, 22), 14, INK)
	boss_bar = ProgressBar.new()
	_place(boss_bar, boss_panel, Rect2(16, 30, 488, 5))
	boss_bar.show_percentage = false
	boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_bar.add_theme_stylebox_override("background", _style(Color(Art.DANGER, 0.15)))
	boss_bar.add_theme_stylebox_override("fill", _style(Art.DANGER))
	boss_poise_bar = ProgressBar.new()
	boss_poise_bar.name = "BossPoiseBar"
	_place(boss_poise_bar, boss_panel, Rect2(16, 37, 488, 3))
	boss_poise_bar.show_percentage = false
	boss_poise_bar.max_value = 1.0
	boss_poise_bar.value = 1.0
	boss_poise_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_poise_normal_fill = _style(Color(0.95, 0.76, 0.32, 0.96), Color.TRANSPARENT, 1)
	_boss_poise_stagger_fill = _style(Color(0.68, 0.96, 1.0, 1.0), Color.TRANSPARENT, 1)
	boss_poise_bar.add_theme_stylebox_override("background", _style(Color(AMBER_GOLD, 0.14), Color.TRANSPARENT, 1))
	boss_poise_bar.add_theme_stylebox_override("fill", _boss_poise_normal_fill)
	boss_warning = _label(boss_panel, "", Rect2(16, 44, 488, 24), 11, AMBER_GOLD)
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
	_life_o2_label = _label(life, "O₂", Rect2(15, 12, 48, 30), 23, CYAN)
	oxygen_value = _label(life, "90", Rect2(64, 8, 66, 38), 30, INK)
	oxygen_unit = _label(life, "秒 / 氧气", Rect2(131, 22, 100, 20), 14, MUTED)
	oxygen_unit.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	oxygen_bar = ProgressBar.new()
	_place(oxygen_bar, life, Rect2(15, 52, 216, 3))
	oxygen_bar.show_percentage = false
	oxygen_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	oxygen_bar.add_theme_stylebox_override("background", _style(Color(CYAN, 0.13), Color.TRANSPARENT, 1))
	oxygen_bar.add_theme_stylebox_override("fill", _style(CYAN, Color.TRANSPARENT, 1))
	health_value = _label(life, "生命 100", Rect2(15, 67, 142, 22), 11, INK)
	_life_caption_label = _label(life, "生命支持", Rect2(161, 67, 70, 22), 10, MUTED)
	_life_caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
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
	combat_strip = _panel(instruments, Rect2(-260, -148, 520, 28), Vector2(0.5, 1))
	combat_strip.name = "CombatStripInstrument"
	combat_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combat_strip_desktop_style = _style(Color(Art.INK, 0.72), Color(CYAN, 0.24), 3)
	_combat_strip_touch_style = _style(Color(Art.INK, 0.54), Color(CYAN, 0.18), 2)
	combat_strip.add_theme_stylebox_override("panel", _combat_strip_desktop_style)
	_combat_shield_normal_fill = _style(CYAN, Color.TRANSPARENT, 1)
	_combat_shield_over_fill = _style(Art.DANGER, Color.TRANSPARENT, 1)
	_combat_flux_normal_fill = _style(Color(0.36, 0.80, 0.96, 0.92), Color.TRANSPARENT, 1)
	_combat_flux_ready_fill = _style(AMBER_GOLD, Color.TRANSPARENT, 1)
	_combat_heat_normal_fill = _style(Color(0.96, 0.68, 0.28, 0.94), Color.TRANSPARENT, 1)
	_combat_heat_over_fill = _style(Art.DANGER, Color.TRANSPARENT, 1)
	_combat_shield_lbl = _label(combat_strip, "盾", Rect2(10, 4, 28, 20), 11, CYAN)
	_combat_shield_lbl.set_meta("_no_hint", true)
	_combat_shield_bar = ProgressBar.new()
	_combat_shield_bar.name = "CombatShieldBar"
	_place(_combat_shield_bar, combat_strip, Rect2(38, 11, 56, 6))
	_combat_shield_bar.show_percentage = false
	_combat_shield_bar.max_value = 1.0
	_combat_shield_bar.value = 1.0
	_combat_shield_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combat_shield_bar.add_theme_stylebox_override("background", _style(Color(CYAN, 0.16), Color.TRANSPARENT, 1))
	_combat_shield_bar.add_theme_stylebox_override("fill", _combat_shield_normal_fill)
	_combat_flux_lbl = _label(combat_strip, "共鸣", Rect2(102, 4, 34, 20), 11, CYAN)
	_combat_flux_bar = ProgressBar.new()
	_combat_flux_bar.name = "CombatFluxBar"
	_place(_combat_flux_bar, combat_strip, Rect2(138, 11, 56, 6))
	_combat_flux_bar.show_percentage = false
	_combat_flux_bar.max_value = 1.0
	_combat_flux_bar.value = 0.0
	_combat_flux_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combat_flux_bar.add_theme_stylebox_override("background", _style(Color(AMBER_GOLD, 0.14), Color.TRANSPARENT, 1))
	_combat_flux_bar.add_theme_stylebox_override("fill", _combat_flux_normal_fill)
	_combat_heat_lbl = _label(combat_strip, "热", Rect2(202, 4, 26, 20), 11, ORANGE)
	_combat_heat_lbl.set_meta("_no_hint", true)
	_combat_heat_bar = ProgressBar.new()
	_combat_heat_bar.name = "CombatHeatBar"
	_place(_combat_heat_bar, combat_strip, Rect2(228, 11, 46, 6))
	_combat_heat_bar.show_percentage = false
	_combat_heat_bar.max_value = 1.0
	_combat_heat_bar.value = 0.0
	_combat_heat_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combat_heat_bar.add_theme_stylebox_override("background", _style(Color(ORANGE, 0.15), Color.TRANSPARENT, 1))
	_combat_heat_bar.add_theme_stylebox_override("fill", _combat_heat_normal_fill)
	_combat_art_lbl = _label(combat_strip, "[X] 战技", Rect2(282, 4, 104, 20), 11, CYAN)
	_combat_art_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combat_tac_lbl = _label(combat_strip, "[I] 战术", Rect2(392, 4, 104, 20), 11, CYAN)
	_combat_tac_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combat_cmd_lbl = _label(combat_strip, "集火狂攻", Rect2(440, 4, 72, 20), 11, AMBER_GOLD)
	_combat_cmd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combat_cmd_lbl.set_meta("_no_hint", true)
	_combat_cmd_lbl.hide()
	combat_strip.modulate.a = 0.0
	combat_strip.hide()
	equipment_value = _label(instruments, "基础潜水装备", Rect2(-220, -72, 440, 22), 10, MUTED, Vector2(0.5, 1))
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
	shield_label = _label(instruments, "C / 能量盾收起", Rect2(28, -178, 246, 22), 10, MUTED, Vector2(0, 1))
	var hints := _label(instruments, "E 交互   Tab 制造   M 海图   U 任务   N 声呐   L 指南   K 视角   P 角色   Esc 暂停", Rect2(-440, -30, 880, 22), 10, MUTED, Vector2(0.5, 1))
	hints.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bottom_hints = hints

func _build_main() -> void:
	var menu := _menu("main", false)
	menu.gui_input.connect(func(event: InputEvent) -> void: _handle_main_stage_input(event, menu))
	var shade := ColorRect.new()
	_place(shade, menu, Rect2())
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
	uniform float aspect = 1.6;
	void fragment() {
		float veil_h = 1.0 - smoothstep(0.08, 0.70, UV.x);
		float veil_v = smoothstep(0.18, 0.76, UV.y);
		float veil = aspect < 1.0 ? mix(0.14, 0.88, veil_v) : veil_h * 0.83;
		COLOR = vec4(0.015, 0.07, 0.12, veil);
	}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	shade.material = material
	_main_shade_material = material
	var eyebrow_line := _line(menu, Rect2(74, 72, 38, 2), AMBER_GOLD)
	var eyebrow_lbl := _label(menu, "一 场 始 于 浅 礁 的 远 行", Rect2(126, 60, 430, 28), 14, Art.PAPER)
	var title_lbl := _label(menu, "深蓝回声", Rect2(68, 184, 510, 100), 76, INK)
	var en_lbl := _label(menu, "A B Y S S A L   E C H O", Rect2(78, 295, 490, 32), 18, CYAN)
	en_lbl.set_meta("_no_hint", true)
	var mid_line := _line(menu, Rect2(78, 365, 50, 1), AMBER_GOLD)
	var poetic_1 := _label(menu, "循着微光，游向未知。", Rect2(76, 389, 470, 40), 25, INK)
	var poetic_2 := _label(menu, "穿过摇曳的海底森林，\n在沉睡的古城，听见大海的回声。", Rect2(78, 450, 470, 68), 16, MUTED)
	continue_voyage_btn = _button(menu, "继续上次航程", Rect2(78, 476, 390, 48), func() -> void: continue_requested.emit(), true)
	continue_voyage_btn.name = "ContinueVoyageButton"
	continue_voyage_btn.custom_minimum_size = Vector2(0, 46)
	continue_voyage_btn.set_meta("_no_hint", true)
	continue_voyage_btn.hide()
	continue_summary_label = _label(menu, "", Rect2(78, 524, 390, 20), 12, CYAN)
	continue_summary_label.set_meta("_no_hint", true)
	continue_summary_label.hide()
	var explore_btn := _button(menu, "自由探险  /  EXPLORE", Rect2(78, 536, 390, 52), func() -> void: start_requested.emit("explore"), true)
	explore_btn.custom_minimum_size = Vector2(0, 46)
	var survive_btn := _button(menu, "生存航程  /  SURVIVE", Rect2(78, 598, 390, 46), func() -> void: start_requested.emit("survival"))
	survive_btn.custom_minimum_size = Vector2(0, 44)
	var main_guide_btn := _button(menu, "玩法说明 / 潜航指南", Rect2(78, 654, 190, 44), func() -> void: action_requested.emit("gameplay_guide"))
	main_guide_btn.name = "MainGuideButton"
	main_guide_btn.custom_minimum_size = Vector2(0, 44)
	var main_controls_btn := _button(menu, "操作与触控设置", Rect2(278, 654, 190, 44), func() -> void: action_requested.emit("controls"))
	main_controls_btn.name = "MainControlsButton"
	main_controls_btn.custom_minimum_size = Vector2(0, 44)
	var character_card := _panel(menu, Rect2(-356, 86, 336, 518), Vector2(1, 0))
	character_card.name = "CharacterSelectPanel"
	character_card.mouse_filter = Control.MOUSE_FILTER_PASS
	var char_line_top := _line(character_card, Rect2(20, 26, 26, 2), AMBER_GOLD)
	var char_eyebrow := _label(character_card, "潜航形态  /  P 切换", Rect2(56, 15, 260, 22), 14, CYAN)
	main_char_title = _label(character_card, "珊瑚晨曦人鱼", Rect2(20, 44, 296, 34), 24, INK)
	main_char_title.set_meta("_no_hint", true)
	main_char_subtitle = _label(character_card, "绯莓长发 · 珠母贝衣 · 碧海粉绡尾", Rect2(20, 82, 296, 22), 14, MUTED)
	main_char_subtitle.set_meta("_no_hint", true)
	var prev_btn := _button(character_card, "◀ 上一位", Rect2(20, 112, 144, 38), func() -> void: character_cycled.emit(-1))
	prev_btn.set_meta("_no_hint", true)
	var next_btn := _button(character_card, "下一位 ▶", Rect2(172, 112, 144, 38), func() -> void: character_cycled.emit(1))
	next_btn.set_meta("_no_hint", true)
	var char_line_mid := _line(character_card, Rect2(20, 160, 296, 1), Color(CYAN, 0.16))
	for i in range(CharacterRoster.CHARACTER_ORDER.size()):
		var cid: String = CharacterRoster.CHARACTER_ORDER[i]
		var prof: Dictionary = CharacterRoster.get_profile(cid)
		var c_btn := _button(character_card, str(prof["name"]), Rect2(20, 172 + i * 46, 296, 40), func() -> void: character_selected.emit(cid), cid == CharacterRoster.DEFAULT_CHARACTER)
		c_btn.name = "CharSelect_" + cid
		c_btn.set_meta("_no_hint", true)
		main_char_buttons[cid] = c_btn
	var char_line_bot := _line(character_card, Rect2(20, 452, 296, 1), Color(CYAN, 0.16))
	var rot_left_btn := _button(character_card, "◀ 左旋", Rect2(20, 462, 94, 38), func() -> void: showcase_rotated.emit(-PI * 0.25))
	rot_left_btn.name = "CharRotateLeft"
	rot_left_btn.set_meta("_no_hint", true)
	var rot_reset_btn := _button(character_card, "回正", Rect2(121, 462, 94, 38), func() -> void: showcase_reset_requested.emit())
	rot_reset_btn.name = "CharRotateReset"
	rot_reset_btn.set_meta("_no_hint", true)
	var rot_right_btn := _button(character_card, "右旋 ▶", Rect2(222, 462, 94, 38), func() -> void: showcase_rotated.emit(PI * 0.25))
	rot_right_btn.name = "CharRotateRight"
	rot_right_btn.set_meta("_no_hint", true)
	var footer_left := _label(menu, "九片海域  ·  一段属于你的潜航记录", Rect2(78, -52, 540, 28), 14, MUTED, Vector2(0, 1))
	var footer_right := _label(menu, "THE LIVING OCEAN\n00 — 600 m", Rect2(-300, -94, 240, 58), 14, Art.PAPER, Vector2(1, 1))
	footer_right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_main_ui = {
		"eyebrow_line": eyebrow_line,
		"eyebrow_lbl": eyebrow_lbl,
		"title_lbl": title_lbl,
		"en_lbl": en_lbl,
		"mid_line": mid_line,
		"poetic_1": poetic_1,
		"poetic_2": poetic_2,
		"explore_btn": explore_btn,
		"survive_btn": survive_btn,
		"guide_btn": main_guide_btn,
		"controls_btn": main_controls_btn,
		"char_card": character_card,
		"char_line_top": char_line_top,
		"char_eyebrow": char_eyebrow,
		"prev_btn": prev_btn,
		"next_btn": next_btn,
		"char_line_mid": char_line_mid,
		"char_line_bot": char_line_bot,
		"rot_left_btn": rot_left_btn,
		"rot_reset_btn": rot_reset_btn,
		"rot_right_btn": rot_right_btn,
		"footer_left": footer_left,
		"footer_right": footer_right,
	}

func _build_pause() -> void:
	var menu := _menu("pause")
	var card := _panel(menu, Rect2(0, 0, 500, 564))
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	_modal_cards["pause"] = card
	var accent := _line(card, Rect2(28, 28, 26, 2), AMBER_GOLD)
	var eyebrow := _label(card, "潜航日志 / 暂停", Rect2(64, 18, 300, 22), 11, MUTED)
	var title := _label(card, "在此稍作停留", Rect2(28, 66, 444, 44), 30, INK)
	var desc := _label(card, "生命支持已暂停。准备好后，继续你的航程。", Rect2(28, 118, 444, 38), 13, MUTED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var resume_btn := _button(card, "继续潜航", Rect2(28, 170, 444, 46), func() -> void: resume_requested.emit(), true)
	resume_btn.custom_minimum_size = Vector2(0, 46)
	var map_button := _button(card, "M / 勘测海图", Rect2(28, 226, 444, 44), func() -> void: open_map_requested.emit())
	map_button.name = "OpenSeaChartButton"
	map_button.custom_minimum_size = Vector2(0, 44)
	var loadout_button := _button(card, "F2 / 武装配置", Rect2(28, 278, 216, 44), func() -> void: open_loadout_requested.emit())
	loadout_button.name = "OpenLoadoutButton"
	loadout_button.custom_minimum_size = Vector2(0, 44)
	loadout_button.clip_text = true
	var quests_button := _button(card, "U / 潜航任务日志", Rect2(256, 278, 216, 44), func() -> void: open_quests_requested.emit())
	quests_button.name = "OpenQuestsButton"
	quests_button.custom_minimum_size = Vector2(0, 44)
	quests_button.clip_text = true
	var guide_button := _button(card, "L / 潜航指南与引导", Rect2(28, 330, 444, 44), func() -> void: action_requested.emit("gameplay_guide"))
	guide_button.name = "OpenGuideButton"
	guide_button.custom_minimum_size = Vector2(0, 44)
	var p_prev := _button(card, "◀", Rect2(28, 382, 52, 44), func() -> void: character_cycled.emit(-1))
	p_prev.custom_minimum_size = Vector2(44, 44)
	p_prev.set_meta("_no_hint", true)
	pause_char_btn = _button(card, "P / 角色：珊瑚晨曦人鱼", Rect2(88, 382, 324, 44), func() -> void: character_cycled.emit(1))
	pause_char_btn.name = "PauseCharacterButton"
	pause_char_btn.custom_minimum_size = Vector2(0, 44)
	pause_char_btn.clip_text = true
	var p_next := _button(card, "▶", Rect2(420, 382, 52, 44), func() -> void: character_cycled.emit(1))
	p_next.custom_minimum_size = Vector2(44, 44)
	p_next.set_meta("_no_hint", true)
	var controls_btn := _button(card, "操作设置", Rect2(28, 434, 216, 44), func() -> void: action_requested.emit("controls"))
	controls_btn.custom_minimum_size = Vector2(0, 44)
	var fullscreen_btn := _button(card, "全屏显示", Rect2(256, 434, 216, 44), func() -> void: action_requested.emit("toggle_fullscreen"))
	fullscreen_btn.name = "PauseFullscreenButton"
	fullscreen_btn.custom_minimum_size = Vector2(0, 44)
	fullscreen_btn.set_meta("_no_hint", true)
	var header_close := _add_modal_close_button(card, "PauseHeaderCloseButton")
	var restart_btn := _button(card, "重新开始", Rect2(28, 486, 444, 44), func() -> void: restart_requested.emit())
	restart_btn.custom_minimum_size = Vector2(0, 44)
	var hint_lbl := _label(card, "Esc 返回海底", Rect2(28, 536, 444, 22), 10, MUTED)
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_ui = {
		"card": card, "accent": accent, "eyebrow": eyebrow, "title": title, "desc": desc,
		"resume_btn": resume_btn, "map_btn": map_button, "loadout_btn": loadout_button, "quests_btn": quests_button, "guide_btn": guide_button,
		"p_prev": p_prev, "p_next": p_next, "controls_btn": controls_btn,
		"fullscreen_btn": fullscreen_btn, "restart_btn": restart_btn,
		"header_close": header_close, "hint_lbl": hint_lbl,
	}

func _build_craft() -> void:
	var menu := _menu("craft")
	var card := _panel(menu, Rect2(0, 0, 900, 712))
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	_modal_cards["craft"] = card
	var eyebrow := _label(card, "装备制造 / 逃生舱工作台", Rect2(28, 16, 740, 22), 11, CYAN)
	var title := _label(card, "为更深处做好准备", Rect2(27, 42, 740, 38), 28, INK)
	craft_inventory = _label(card, "", Rect2(28, 86, 844, 24), 11, MUTED)
	craft_inventory.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var top_div := _line(card, Rect2(28, 118, 844, 1), Color(CYAN, 0.15))
	_craft_ui = {"card": card, "eyebrow": eyebrow, "title": title, "top_div": top_div, "rows": []}
	_recipe(card, "tank", "01", "高容量氧气瓶", "单次潜水时间延长至 150 秒", "2 钛 + 2 海藻", 145)
	_recipe(card, "fins", "02", "轻量脚蹼", "水下游动速度提升 50%", "1 钛 + 2 海藻", 198)
	_recipe(card, "rebreather", "03", "深海循环呼吸器", "抵消深水压强带来的额外耗氧", "2 钛 + 1 铜 + 2 海藻", 251)
	_recipe(card, "axe", "04", "破拆战斧", "165° 范围横扫 · 基础伤害 70", "2 钛 + 1 铜", 304)
	_recipe(card, "sonic", "05", "蓝光静滞枪", "蓝色激光 · 蓄力静滞 · 远距瞄准", "2 钛 + 2 石英 + 1 铜", 357)
	_recipe(card, "biomod_dash", "06", "生体模组 · 涡流突进", "Q 突进 16 米，紧急躲避攻击", "1 鲨齿碎片 + 2 钛", 410)
	_recipe(card, "reinforce_sharp", "07", "深铸武器 · 锋锐硬化", "全武器攻击力永久增加 20", "1 鲨齿碎片 + 1 钛", 463)
	_recipe(card, "reinforce_sonic", "08", "深铸武器 · 晶体共鸣", "全武器攻击力永久增加 35", "1 晶核碎片 + 1 石英", 516)
	_recipe(card, "beacon", "09", "修复求救信标", "建立返航通信，继续探索深海主线", "3 钛 + 2 铜 + 2 石英", 569)
	var resume_btn := _button(card, "返回潜航", Rect2(28, 644, 144, 44), func() -> void: resume_requested.emit())
	resume_btn.custom_minimum_size = Vector2(0, 44)
	var header_close := _add_modal_close_button(card, "CraftHeaderCloseButton")
	var loadout_btn := _button(card, "武装配置 / F2", Rect2(180, 644, 168, 44), func() -> void: open_loadout_requested.emit())
	loadout_btn.name = "CraftOpenLoadoutButton"
	loadout_btn.custom_minimum_size = Vector2(0, 44)
	loadout_btn.clip_text = true
	var sushi_btn := _button(card, "料理与图鉴 / B", Rect2(356, 644, 168, 44), func() -> void: open_sushi_requested.emit())
	sushi_btn.custom_minimum_size = Vector2(0, 44)
	sushi_btn.clip_text = true
	var foot_note := _label(card, "追踪配方，便可在潜航时查看所需材料。", Rect2(534, 654, 338, 22), 11, MUTED)
	foot_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_craft_ui["resume_btn"] = resume_btn
	_craft_ui["loadout_btn"] = loadout_btn
	_craft_ui["sushi_btn"] = sushi_btn
	_craft_ui["header_close"] = header_close
	_craft_ui["foot_note"] = foot_note

func _build_sushi() -> void:
	var menu := _menu("sushi")
	var card := _panel(menu, Rect2(0, 0, 1000, 720))
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	_modal_cards["sushi"] = card
	var eyebrow := _label(card, "班乔料理吧 / 柯布拉商店 / 玛琳卡图鉴", Rect2(28, 14, 840, 20), 11, AMBER_GOLD)
	var title := _label(card, "来自海洋的馈赠", Rect2(27, 38, 840, 36), 26, INK)
	sushi_header_label = _label(card, "", Rect2(28, 80, 944, 24), 13, INK)
	sushi_header_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sushi_ingredients_label = _label(card, "", Rect2(28, 106, 944, 22), 11, MUTED)
	sushi_ingredients_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var top_div := _line(card, Rect2(28, 134, 944, 1), Color(CYAN, 0.15))

	var tab_bar := HBoxContainer.new()
	tab_bar.name = "SushiTabBar"
	_place(tab_bar, card, Rect2(28, 142, 944, 44))
	tab_bar.add_theme_constant_override("separation", 8)
	tab_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	tab_bar.hide()
	var tab_buttons: Array[Button] = []
	var tab_titles := ["料理吧", "柯布拉补给", "玛琳卡图鉴"]
	for t_idx in range(tab_titles.size()):
		var idx := t_idx
		var t_btn := _button(tab_bar, str(tab_titles[t_idx]), Rect2(0, 0, 120, 44), func() -> void: _select_sushi_tab(idx), t_idx == 0)
		t_btn.name = "SushiTab_%d" % t_idx
		t_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t_btn.custom_minimum_size = Vector2(0, 44)
		t_btn.set_meta("_no_hint", true)
		tab_buttons.append(t_btn)

	var sushi_section := Control.new()
	sushi_section.name = "SushiBarSection"
	_place(sushi_section, card, Rect2(28, 144, 540, 300))
	sushi_section.mouse_filter = Control.MOUSE_FILTER_PASS
	var cobra_section := Control.new()
	cobra_section.name = "CobraShopSection"
	_place(cobra_section, card, Rect2(28, 450, 540, 200))
	cobra_section.mouse_filter = Control.MOUSE_FILTER_PASS

	_sushi_ui = {
		"card": card, "eyebrow": eyebrow, "title": title, "top_div": top_div,
		"tab_bar": tab_bar, "tab_buttons": tab_buttons,
		"sushi_section": sushi_section, "cobra_section": cobra_section,
		"sushi_rows": [], "cobra_rows": [],
	}
	_sushi_row(sushi_section, "goldfish_nigiri", "荧光金鱼握寿司", "1 鲜鱼 · 65 金币", "恢复生命 35 / 氧气 30 · 氧气上限 +10s", 0)
	_sushi_row(sushi_section, "kelp_roll", "深海海藻鲜肉卷", "2 生肉 + 1 海藻 · 150 金币", "生命上限永久 +20，并立即回满生命", 60)
	_sushi_row(sushi_section, "shark_sashimi", "暗礁巨鲨厚切刺身", "2 生肉 + 1 骨齿 · 260 金币", "全武器攻击力永久 +18", 120)
	_sushi_row(sushi_section, "abyss_kaiseki", "深渊海王黄金怀石", "3 生肉 + 1 兽皮 + 1 甲壳 · 420 金币", "全武器攻击 +30 · 无人机 +1 · 负重 +15kg", 180)
	var serve_all_btn := _button(sushi_section, "挂牌营业 / 售出富余鲜鱼与生肉", Rect2(0, 246, 540, 44), func() -> void: sushi_serve_all_requested.emit(), true)
	serve_all_btn.custom_minimum_size = Vector2(0, 44)
	_sushi_ui["serve_all_btn"] = serve_all_btn

	var cobra_div := _line(cobra_section, Rect2(0, 0, 540, 1), Color(CYAN, 0.15))
	var cobra_heading := _label(cobra_section, "柯布拉潜航补给", Rect2(0, 6, 540, 20), 12, CYAN)
	_sushi_ui["cobra_div"] = cobra_div
	_sushi_ui["cobra_heading"] = cobra_heading
	_cobra_row(cobra_section, "cargo_box", "扩容生态箱 / 120 金币", "负重上限 +25kg · 无人机配额 +1，并补满", 30)
	_cobra_row(cobra_section, "oxygen_capsule", "浓缩氧气胶囊 / 80 金币", "氧气上限 +25 秒，立即补满氧气与生命", 84)
	_cobra_row(cobra_section, "duff_coating", "达夫超导涂层 / 180 金币", "全武器攻击力永久 +25", 138)

	var marinca_box := _panel(card, Rect2(592, 160, 380, 514))
	marinca_box.mouse_filter = Control.MOUSE_FILTER_PASS
	var marinca_title := _label(marinca_box, "玛琳卡 / 海洋生物图鉴", Rect2(18, 14, 344, 22), 14, INK)
	marinca_summary_label = _label(marinca_box, "", Rect2(18, 42, 344, 42), 11, AMBER_GOLD)
	marinca_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var marinca_div_top := _line(marinca_box, Rect2(18, 90, 344, 1), Color(CYAN, 0.15))
	marinca_grid_label = _label(marinca_box, "", Rect2(18, 98, 344, 344), 14, INK)
	marinca_grid_label.clip_text = false
	marinca_grid_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	marinca_grid_label.add_theme_constant_override("line_spacing", -1)
	var marinca_div_bot := _line(marinca_box, Rect2(18, 448, 344, 1), Color(CYAN, 0.12))
	var marinca_note := _label(marinca_box, "静滞活捕或无人机打捞可获得三星品质。\n每张三星图鉴使料理售价增加 12%。", Rect2(18, 456, 344, 48), 14, MUTED)
	marinca_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var header_close := _add_modal_close_button(card, "SushiHeaderCloseButton")
	var resume_btn := _button(card, "返回潜航 / B", Rect2(28, 662, 168, 44), func() -> void: resume_requested.emit())
	resume_btn.custom_minimum_size = Vector2(0, 44)
	var foot_note := _label(card, "V 无人机打捞 / E 采集与交互", Rect2(210, 674, 762, 20), 10, MUTED)
	foot_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_sushi_ui["marinca_box"] = marinca_box
	_sushi_ui["marinca_title"] = marinca_title
	_sushi_ui["marinca_div_top"] = marinca_div_top
	_sushi_ui["marinca_div_bot"] = marinca_div_bot
	_sushi_ui["marinca_note"] = marinca_note
	_sushi_ui["header_close"] = header_close
	_sushi_ui["resume_btn"] = resume_btn
	_sushi_ui["foot_note"] = foot_note

func _select_sushi_tab(tab_idx: int) -> void:
	_sushi_active_tab = clampi(tab_idx, 0, 2)
	var tabs: Array = _sushi_ui.get("tab_buttons", [])
	for i in range(tabs.size()):
		var tb: Button = tabs[i]
		if is_instance_valid(tb):
			OceanUiTheme.button(tb, i == _sushi_active_tab)
	if menu_scrolls.has("sushi") and is_instance_valid(menu_scrolls["sushi"]):
		(menu_scrolls["sushi"] as ScrollContainer).scroll_vertical = 0
	_apply_layout()
	_refresh_navigation.call_deferred()

func _sushi_row(parent: Control, dish_id: String, title: String, cost_str: String, desc_str: String, y: float) -> void:
	var t_lbl := _label(parent, title, Rect2(0, y, 416, 22), 14, INK)
	var c_lbl := _label(parent, cost_str, Rect2(0, y + 22, 416, 22), 10, AMBER_GOLD)
	var d_lbl := _label(parent, desc_str, Rect2(0, y + 44, 416, 22), 10, MUTED)
	var btn := _button(parent, "烹饪售出", Rect2(424, y + 6, 116, 44), func() -> void: sushi_cook_requested.emit(dish_id))
	btn.custom_minimum_size = Vector2(0, 44)
	sushi_cook_buttons[dish_id] = btn
	(_sushi_ui["sushi_rows"] as Array).append({"title": t_lbl, "cost": c_lbl, "desc": d_lbl, "btn": btn})

func _cobra_row(parent: Control, item_id: String, title: String, desc_str: String, y: float) -> void:
	var t_lbl := _label(parent, title, Rect2(0, y, 416, 22), 13, INK)
	var d_lbl := _label(parent, desc_str, Rect2(0, y + 22, 416, 22), 10, MUTED)
	var btn := _button(parent, "购买升级", Rect2(424, y + 2, 116, 44), func() -> void: cobra_buy_requested.emit(item_id))
	btn.custom_minimum_size = Vector2(0, 44)
	cobra_buy_buttons[item_id] = btn
	(_sushi_ui["cobra_rows"] as Array).append({"title": t_lbl, "desc": d_lbl, "btn": btn})

func _recipe(parent: Control, key: String, number: String, title: String, detail: String, cost: String, y: float) -> void:
	var num_lbl := _label(parent, number, Rect2(28, y + 3, 36, 24), 12, CYAN)
	var title_lbl := _label(parent, title, Rect2(72, y, 320, 22), 14, INK)
	var detail_lbl := _label(parent, detail, Rect2(72, y + 23, 560, 22), 10, MUTED)
	var cost_lbl := _label(parent, cost, Rect2(400, y + 2, 260, 22), 11, CYAN)
	var p_btn := _button(parent, "追踪", Rect2(672, y + 1, 82, 44), func() -> void: pin_requested.emit(key))
	p_btn.custom_minimum_size = Vector2(0, 44)
	var c_btn := _button(parent, "制作", Rect2(762, y + 1, 110, 44), func() -> void: craft_requested.emit(key), key == "beacon")
	c_btn.custom_minimum_size = Vector2(0, 44)
	pin_buttons[key] = p_btn
	craft_buttons[key] = c_btn
	var div_line := _line(parent, Rect2(72, y + 48, 800, 1), Color(CYAN, 0.07))
	(_craft_ui["rows"] as Array).append({
		"num": num_lbl, "title": title_lbl, "detail": detail_lbl, "cost": cost_lbl,
		"pin_btn": p_btn, "craft_btn": c_btn, "div": div_line,
	})

func _build_mount_board() -> void:
	var menu := _menu("mount_board")
	var card := _panel(menu, Rect2(0, 0, 940, 700))
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	_modal_cards["mount_board"] = card
	var eyebrow := _label(card, "生物契约 / 护卫与骑乘", Rect2(28, 16, 760, 22), 11, CYAN)
	var title := _label(card, "与你同行的伙伴", Rect2(27, 42, 760, 38), 28, INK)
	mount_board_summary_label = _label(card, "", Rect2(28, 88, 884, 22), 11, MUTED)
	mount_board_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mount_board_select_all_btn = _button(card, "全选出战", Rect2(28, 120, 160, 44), func() -> void: mount_board_select_all_requested.emit(), true)
	mount_board_select_all_btn.custom_minimum_size = Vector2(0, 44)
	mount_board_store_all_btn = _button(card, "全部收回", Rect2(198, 120, 160, 44), func() -> void: mount_board_store_all_requested.emit())
	mount_board_store_all_btn.custom_minimum_size = Vector2(0, 44)
	var top_note := _label(card, "选择生物即可召唤；护卫会在遭到攻击时迎击。", Rect2(374, 132, 538, 22), 11, MUTED)
	top_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mount_board_empty_label = _label(card, "尚未缔结生物契约。\n使用蓝光枪静滞受伤巨兽，再靠近按 E 驯服。", Rect2(90, 320, 760, 60), 15, MUTED)
	mount_board_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mount_board_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var grid := GridContainer.new()
	grid.name = "MountBoardGrid"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	_place(grid, card, Rect2(28, 176, 884, 448))
	mount_board_slot_rows.clear()
	mount_board_slot_buttons.clear()
	mount_board_ride_buttons.clear()
	for i in range(20):
		var slot_idx: int = i
		var slot_row := HBoxContainer.new()
		slot_row.name = "MountSlotRow_%d" % i
		slot_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_row.add_theme_constant_override("separation", 6)
		slot_row.mouse_filter = Control.MOUSE_FILTER_PASS
		grid.add_child(slot_row)
		var btn := _button(slot_row, "%02d / 尚未契约" % (i + 1), Rect2(0, 0, 160, 68), func() -> void: mount_board_select_requested.emit(slot_idx))
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 68)
		btn.add_theme_font_size_override("font_size", 14)
		btn.clip_text = true
		btn.disabled = true
		var ride_btn := _button(slot_row, "骑乘", Rect2(0, 0, 58, 44), func() -> void: action_requested.emit("ride_mount:%d" % slot_idx))
		ride_btn.name = "MountRideBtn_%d" % i
		ride_btn.custom_minimum_size = Vector2(58, 44)
		ride_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ride_btn.set_meta("_no_hint", true)
		ride_btn.disabled = true
		ride_btn.hide()
		mount_board_slot_rows.append(slot_row)
		mount_board_slot_buttons.append(btn)
		mount_board_ride_buttons.append(ride_btn)
	var header_close := _add_modal_close_button(card, "MountHeaderCloseButton")
	var resume_btn := _button(card, "返回潜航 / O", Rect2(28, 638, 176, 44), func() -> void: resume_requested.emit())
	resume_btn.custom_minimum_size = Vector2(0, 44)
	var foot_note := _label(card, "G 骑乘或离鞍 / Z 召回 / O 收纳与管理", Rect2(222, 650, 690, 20), 10, MUTED)
	foot_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_mount_ui = {
		"card": card, "eyebrow": eyebrow, "title": title, "top_note": top_note,
		"grid": grid, "header_close": header_close, "resume_btn": resume_btn, "foot_note": foot_note,
	}

func _build_map() -> void:
	var menu := _menu("map")
	var card := _panel(menu, Rect2(0, 0, 1060, 728))
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	_modal_cards["map"] = card
	var eyebrow := _label(card, "潜航档案 / 海域勘测与洋流跃迁", Rect2(24, 14, 900, 20), 11, CYAN)
	map_rank_label = _label(card, "勘测海图", Rect2(24, 38, 900, 28), 20, INK)
	var split := BoxContainer.new()
	split.name = "MapSplitContainer"
	split.vertical = false
	split.add_theme_constant_override("separation", 12)
	split.mouse_filter = Control.MOUSE_FILTER_PASS
	_place(split, card, Rect2(24, 74, 1012, 636))

	var chart_pane := Control.new()
	chart_pane.name = "MapChartPane"
	chart_pane.mouse_filter = Control.MOUSE_FILTER_PASS
	chart_pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chart_pane.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chart_pane.size_flags_stretch_ratio = 1.38
	split.add_child(chart_pane)

	sea_chart = WorldMap.SeaChartCanvas.new()
	sea_chart.set_bathymetry(bathy_texture)
	_place(sea_chart, chart_pane, Rect2(0, 0, 580, 584))
	sea_chart.waypoint_set.connect(func(xz: Vector2) -> void: map_waypoint_set.emit(xz))
	sea_chart.waypoint_cleared.connect(func() -> void: map_waypoint_cleared.emit())
	sea_chart.fast_travel_requested.connect(func(tid: String, wpos: Vector3, tname: String) -> void: fast_travel_requested.emit(tid, wpos, tname))
	sea_chart.selection_changed.connect(_on_sea_chart_selection)
	sea_chart.sidebar_focus_requested.connect(_focus_map_sidebar)
	map_focus_button = _button(chart_pane, "操作海图 / 中键平移 · 滚轮缩放 · 左键选点", Rect2(0, 592, 580, 44), func() -> void: sea_chart.grab_focus())
	map_focus_button.custom_minimum_size = Vector2(0, 44)
	map_focus_button.clip_text = true

	var side := _panel(split, Rect2(0, 0, 420, 636))
	side.name = "MapSidePanel"
	side.mouse_filter = Control.MOUSE_FILTER_PASS
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.size_flags_stretch_ratio = 1.0

	var side_scroll := ScrollContainer.new()
	side_scroll.name = "MapSideScroll"
	_place(side_scroll, side, Rect2(14, 12, 392, 612))
	side_scroll.follow_focus = true
	side_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	side_scroll.mouse_filter = Control.MOUSE_FILTER_PASS

	var side_vbox := VBoxContainer.new()
	side_vbox.name = "MapSideVBox"
	side_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_vbox.add_theme_constant_override("separation", 6)
	side_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	side_scroll.add_child(side_vbox)

	var stats_heading := _label(side_vbox, "海域勘测记录", Rect2(0, 0, 352, 22), 14, INK)
	map_stats_label = _label(side_vbox, "", Rect2(0, 0, 352, 76), 12, MUTED)
	map_stats_label.clip_text = false
	map_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var side_div := _line(side_vbox, Rect2(0, 0, 352, 1), Color(CYAN, 0.15))
	side_div.custom_minimum_size = Vector2(0, 1)
	var intel_heading := _label(side_vbox, "当前位置情报", Rect2(0, 0, 352, 20), 11, CYAN)
	map_sel_title = _label(side_vbox, "选择地标或海域坐标", Rect2(0, 0, 352, 24), 16, INK)
	map_sel_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	map_sel_title.clip_text = false
	map_sel_coords = _label(side_vbox, "坐标 -- / 水深 --", Rect2(0, 0, 352, 20), 11, AMBER_GOLD)
	map_sel_desc = _label(side_vbox, "探索并激活前哨，建立你的远洋航线。", Rect2(0, 0, 352, 44), 12, MUTED)
	map_sel_desc.clip_text = false
	map_sel_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	map_travel_btn = _button(side_vbox, "洋流跃迁至此", Rect2(0, 0, 352, 44), func() -> void:
		if not map_selected_info.is_empty() and bool(map_selected_info.get("can_travel", false)):
			fast_travel_requested.emit(str(map_selected_info["id"]), map_selected_info["pos"], str(map_selected_info["name"]))
	, true)
	map_travel_btn.custom_minimum_size = Vector2(0, 44)
	map_travel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_travel_btn.disabled = true

	var wp_row := BoxContainer.new()
	wp_row.vertical = false
	wp_row.add_theme_constant_override("separation", 8)
	wp_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wp_row.mouse_filter = Control.MOUSE_FILTER_PASS
	side_vbox.add_child(wp_row)
	map_waypoint_btn = _button(wp_row, "设为导航标点", Rect2(0, 0, 172, 44), func() -> void:
		if not map_selected_info.is_empty() and map_selected_info.has("pos"):
			var p3: Vector3 = map_selected_info["pos"]
			map_waypoint_set.emit(Vector2(p3.x, p3.z))
	)
	map_waypoint_btn.custom_minimum_size = Vector2(0, 44)
	map_waypoint_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_waypoint_btn.disabled = true
	map_clear_wp_btn = _button(wp_row, "清除标点", Rect2(0, 0, 172, 44), func() -> void: map_waypoint_cleared.emit())
	map_clear_wp_btn.custom_minimum_size = Vector2(0, 44)
	map_clear_wp_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var zoom_row := HBoxContainer.new()
	zoom_row.add_theme_constant_override("separation", 8)
	zoom_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zoom_row.mouse_filter = Control.MOUSE_FILTER_PASS
	side_vbox.add_child(zoom_row)
	var center_btn := _button(zoom_row, "居中", Rect2(0, 0, 104, 44), func() -> void: sea_chart.center_on_player())
	center_btn.custom_minimum_size = Vector2(0, 44)
	center_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var zoom_in_btn := _button(zoom_row, "+ 放大", Rect2(0, 0, 112, 44), func() -> void: sea_chart.adjust_zoom(1.25))
	zoom_in_btn.custom_minimum_size = Vector2(0, 44)
	zoom_in_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var zoom_out_btn := _button(zoom_row, "− 缩小", Rect2(0, 0, 112, 44), func() -> void: sea_chart.adjust_zoom(0.8))
	zoom_out_btn.custom_minimum_size = Vector2(0, 44)
	zoom_out_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var act_row := BoxContainer.new()
	act_row.vertical = false
	act_row.add_theme_constant_override("separation", 8)
	act_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	act_row.mouse_filter = Control.MOUSE_FILTER_PASS
	side_vbox.add_child(act_row)
	var sonar_btn := _button(act_row, "N / 声呐扫描", Rect2(0, 0, 172, 44), func() -> void: sonar_ping_requested.emit())
	sonar_btn.custom_minimum_size = Vector2(0, 44)
	sonar_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var resume_btn := _button(act_row, "返回潜航 / M", Rect2(0, 0, 172, 44), func() -> void: resume_requested.emit())
	resume_btn.custom_minimum_size = Vector2(0, 44)
	resume_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var legend_lbl := _label(side_vbox, "○ 母港  □ 前哨  ◇ 标点  △ 潜艇  · 遗珍", Rect2(0, 0, 352, 20), 10, MUTED)
	legend_lbl.clip_text = false
	legend_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var header_close := _add_modal_close_button(card, "MapHeaderCloseButton")
	_map_ui = {
		"card": card, "eyebrow": eyebrow, "split": split, "chart_pane": chart_pane,
		"side": side, "side_scroll": side_scroll, "side_vbox": side_vbox,
		"stats_heading": stats_heading, "intel_heading": intel_heading,
		"wp_row": wp_row, "act_row": act_row, "header_close": header_close,
	}

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
	var card := _panel(menu, Rect2(0, 0, 680, 480))
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var accent := _line(card, Rect2(36, 38, 38, 2), AMBER_GOLD)
	var eyebrow := _label(card, "潜航记录 / 航程里程碑", Rect2(90, 27, 554, 22), 11, CYAN)
	win_title = _label(card, "深海收到了回声", Rect2(35, 95, 610, 58), 32, INK)
	win_desc = _label(card, "", Rect2(36, 185, 608, 86), 15, MUTED)
	win_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	win_time = _label(card, "本次潜航 00:00", Rect2(36, 292, 608, 24), 12, CYAN)
	var resume_btn := _button(card, "继续探索", Rect2(36, 368, 330, 48), func() -> void: resume_requested.emit(), true)
	resume_btn.custom_minimum_size = Vector2(0, 46)
	var restart_btn := _button(card, "开启新航程", Rect2(382, 368, 262, 48), func() -> void: restart_requested.emit())
	restart_btn.custom_minimum_size = Vector2(0, 46)
	_win_ui = {
		"card": card, "accent": accent, "eyebrow": eyebrow,
		"resume_btn": resume_btn, "restart_btn": restart_btn,
	}

func _build_quick() -> void:
	var menu := _menu("quick")
	var card := _panel(menu, Rect2(0, 0, 860, 700))
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	_modal_cards["quick"] = card
	var eyebrow := _label(card, "潜航操作 / 快捷面板", Rect2(28, 16, 700, 22), 12, CYAN)
	var title_lbl := _label(card, "选择装备与能力", Rect2(27, 42, 700, 36), 28, INK)
	var desc_lbl := _label(card, "方向键选择 · 确认执行 · 返回继续潜航", Rect2(28, 82, 760, 22), 12, MUTED)
	desc_lbl.set_meta("_no_hint", true)
	var grid := GridContainer.new()
	grid.name = "QuickActionsGrid"
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	_place(grid, card, Rect2(28, 110, 804, 504))
	for i in range(QUICK_ACTIONS.size()):
		var entry: Array = QUICK_ACTIONS[i]
		var action := str(entry[0])
		var title := str(entry[1])
		var on_press := (func() -> void: open_loadout_requested.emit()) if action == "loadout_menu" else (func() -> void: action_requested.emit(action))
		var button := _button(grid, title, Rect2(0, 0, 254, 44), on_press)
		button.name = "Quick_" + action
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 44)
		button.clip_text = true
		quick_buttons[action] = button
	var header_close := _add_modal_close_button(card, "QuickHeaderCloseButton")
	var settings_btn := _button(card, "操作设置", Rect2(28, 628, 254, 44), func() -> void: action_requested.emit("controls"))
	settings_btn.custom_minimum_size = Vector2(0, 44)
	var resume_btn := _button(card, "返回潜航", Rect2(578, 628, 254, 44), func() -> void: close_requested.emit(), true)
	resume_btn.custom_minimum_size = Vector2(0, 44)
	_quick_ui = {
		"card": card, "eyebrow": eyebrow, "title": title_lbl, "desc": desc_lbl,
		"grid": grid, "header_close": header_close, "settings_btn": settings_btn, "resume_btn": resume_btn,
	}

func _build_controls() -> void:
	var menu := _menu("controls")
	var card := _panel(menu, Rect2(0, 0, 700, 680))
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	_modal_cards["controls"] = card
	var eyebrow := _label(card, "操作设置 / 自动保存", Rect2(28, 16, 530, 22), 12, CYAN)
	var title := _label(card, "调整你的潜航手感", Rect2(27, 42, 530, 36), 28, INK)
	var vbox := VBoxContainer.new()
	vbox.name = "ControlsVBox"
	vbox.add_theme_constant_override("separation", 8)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	_place(vbox, card, Rect2(28, 92, 644, 566))
	_controls_ui = {"card": card, "eyebrow": eyebrow, "title": title, "vbox": vbox, "rows": []}

	_setting_slider(vbox, "gamepad_sensitivity", "手柄视角灵敏度", 0, 0.2, 3.0, 0.1)
	_setting_slider(vbox, "touch_sensitivity", "触控视角灵敏度", 0, 0.2, 3.0, 0.1)
	_setting_slider(vbox, "deadzone", "手柄摇杆死区", 0, 0.05, 0.6, 0.05)
	_setting_slider(vbox, "touch_scale", "触控按钮大小", 0, 0.70, 1.5, 0.05)
	_setting_slider(vbox, "touch_opacity", "触控按钮透明度", 0, 0.2, 1.0, 0.05)

	var invert := CheckButton.new()
	invert.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	invert.custom_minimum_size = Vector2(0, 44)
	invert.text = "反转视角 Y 轴"
	invert.focus_mode = Control.FOCUS_ALL
	vbox.add_child(invert)
	invert.toggled.connect(func(enabled: bool) -> void:
		if not _settings_syncing:
			input_settings_requested.emit({"invert_y": enabled})
	)
	settings_controls["invert_y"] = invert

	var mode_row := BoxContainer.new()
	mode_row.vertical = false
	mode_row.add_theme_constant_override("separation", 8)
	mode_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_row.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(mode_row)
	var mode_lbl := _label(mode_row, "触控显示", Rect2(0, 0, 180, 24), 14, INK)
	mode_lbl.custom_minimum_size = Vector2(180, 24)
	var mode := OptionButton.new()
	mode.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode.custom_minimum_size = Vector2(140, 44)
	mode.focus_mode = Control.FOCUS_ALL
	mode.add_item("自动 / 根据输入设备")
	mode.add_item("始终显示")
	mode.add_item("隐藏触控")
	mode_row.add_child(mode)
	mode.item_selected.connect(func(index: int) -> void:
		if not _settings_syncing:
			input_settings_requested.emit({"touch_mode": ["auto", "on", "off"][index]})
	)
	settings_controls["touch_mode"] = mode
	(_controls_ui["rows"] as Array).append({"box": mode_row, "label": mode_lbl})

	var gfx_row := BoxContainer.new()
	gfx_row.vertical = false
	gfx_row.add_theme_constant_override("separation", 8)
	gfx_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gfx_row.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(gfx_row)
	var gfx_lbl := _label(gfx_row, "画面品质", Rect2(0, 0, 180, 24), 14, INK)
	gfx_lbl.custom_minimum_size = Vector2(180, 24)
	var gfx := OptionButton.new()
	gfx.name = "GraphicsQualityOption"
	gfx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gfx.custom_minimum_size = Vector2(140, 44)
	gfx.focus_mode = Control.FOCUS_ALL
	gfx.add_item("自动 (推荐)")
	gfx.add_item("流畅 (移动省电)")
	gfx.add_item("高清 (桌面原生)")
	gfx_row.add_child(gfx)
	gfx.item_selected.connect(func(index: int) -> void:
		if not _settings_syncing:
			var clamped_idx := clampi(index, 0, GRAPHICS_QUALITY_VALUES.size() - 1)
			input_settings_requested.emit({"graphics_quality": GRAPHICS_QUALITY_VALUES[clamped_idx]})
	)
	settings_controls["graphics_quality"] = gfx
	(_controls_ui["rows"] as Array).append({"box": gfx_row, "label": gfx_lbl})

	var fullscreen_btn := _button(vbox, "全屏显示 / 切换窗口模式", Rect2(0, 0, 644, 44), func() -> void: action_requested.emit("toggle_fullscreen"))
	fullscreen_btn.name = "ControlsFullscreenButton"
	fullscreen_btn.custom_minimum_size = Vector2(0, 44)
	fullscreen_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fullscreen_btn.set_meta("_no_hint", true)

	var note_lbl := _label(vbox, "手柄：左杆推进 / 转向，右杆观察，肩键升降。\n触屏：左摇杆移动，右侧滑动观察，攻击可长按蓄力。", Rect2(0, 0, 644, 44), 12, MUTED)
	note_lbl.clip_text = false
	note_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var footer_row := BoxContainer.new()
	footer_row.vertical = false
	footer_row.add_theme_constant_override("separation", 10)
	footer_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_row.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(footer_row)
	var controls_guide_btn := _button(footer_row, "查看潜航指南", Rect2(0, 0, 220, 44), func() -> void: action_requested.emit("gameplay_guide"))
	controls_guide_btn.name = "ControlsGuideButton"
	controls_guide_btn.custom_minimum_size = Vector2(0, 44)
	controls_guide_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var back_btn := _button(footer_row, "返回", Rect2(0, 0, 320, 44), func() -> void: close_requested.emit(), true)
	back_btn.custom_minimum_size = Vector2(0, 44)
	back_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var header_close := _add_modal_close_button(card, "ControlsHeaderCloseButton")
	_controls_ui["note_lbl"] = note_lbl
	_controls_ui["footer_row"] = footer_row
	_controls_ui["header_close"] = header_close

func _build_guide() -> void:
	var menu := _menu("guide")
	guide_view = GuidePanel.build(menu, GameplayGuide.get_chapters(), {
		"format_text": func(txt: String) -> String: return format_input_text(txt),
		"on_restart_onboarding": func() -> void: onboarding_restart_requested.emit(),
		"on_skip_onboarding": func() -> void: onboarding_skip_requested.emit(),
		"on_open_controls": func() -> void: action_requested.emit("controls"),
		"on_close": func() -> void: close_requested.emit(),
	})
	if guide_view.has("card") and is_instance_valid(guide_view["card"]):
		_modal_cards["guide"] = guide_view["card"]

func _build_quests() -> void:
	var menu := _menu("quests")
	quest_view = QuestPanel.build(menu, {
		"on_close": func() -> void: close_requested.emit(),
		"on_track": func(qid: String, oid: String) -> void: quest_track_requested.emit(qid, oid),
		"on_toggle_tracker": func() -> void: quest_tracker_toggle_requested.emit(),
		"on_navigate": func(pos: Vector3, lbl: String, open_map: bool) -> void: quest_nav_requested.emit(pos, lbl, open_map),
		"on_pin_recipe": func(rid: String) -> void: pin_requested.emit(rid),
		"on_refresh_bounties": func() -> void: quest_bounty_refresh_requested.emit(),
		"format_text": Callable(self, "format_input_text"),
	})
	if quest_view.has("card") and is_instance_valid(quest_view["card"]):
		_modal_cards["quests"] = quest_view["card"]

func _build_loadout() -> void:
	var menu := _menu("loadout")
	loadout_view = LoadoutPanel.build(menu, {
		"on_close": func() -> void: close_requested.emit(),
		"on_equip_slot": func(slot_idx: int, wid: String) -> void: loadout_equip_slot_requested.emit(slot_idx, wid),
		"on_upgrade_weapon": func(wid: String) -> void: loadout_upgrade_weapon_requested.emit(wid),
		"on_toggle_mod": func(wid: String, mid: String) -> void: loadout_toggle_mod_requested.emit(wid, mid),
		"on_select_tactical": func(sid: String) -> void: loadout_select_tactical_requested.emit(sid),
		"format_text": Callable(self, "format_input_text"),
	})
	if loadout_view.has("card") and is_instance_valid(loadout_view["card"]):
		_modal_cards["loadout"] = loadout_view["card"]

func _setting_slider(parent: Control, key: String, title: String, _y: float, minimum: float, maximum: float, increment: float) -> void:
	var row := BoxContainer.new()
	row.vertical = false
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(row)
	var title_lbl := _label(row, title, Rect2(0, 0, 180, 26), 14, INK)
	title_lbl.custom_minimum_size = Vector2(180, 26)
	var slider_row := HBoxContainer.new()
	slider_row.add_theme_constant_override("separation", 8)
	slider_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider_row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(slider_row)
	var pad_left := Control.new()
	pad_left.custom_minimum_size = Vector2(6, 0)
	pad_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slider_row.add_child(pad_left)
	var slider := HSlider.new()
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(120, 44)
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = increment
	slider.focus_mode = Control.FOCUS_ALL
	slider.mouse_filter = Control.MOUSE_FILTER_PASS
	slider_row.add_child(slider)
	settings_controls[key] = slider
	var value_label := _label(slider_row, "", Rect2(0, 0, 64, 26), 13, CYAN)
	value_label.custom_minimum_size = Vector2(64, 26)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	slider.value_changed.connect(func(value: float) -> void:
		value_label.text = "%.2f" % value
		if not _settings_syncing:
			input_settings_requested.emit({key: value})
	)
	slider.set_meta("value_label", value_label)
	if _controls_ui.has("rows"):
		(_controls_ui["rows"] as Array).append({"box": row, "label": title_lbl})

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
		if _touch_layout and _is_portrait:
			_apply_layout()
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
		"quest_markers": data.get("quest_markers", []),
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
	_overweight_active = overweight
	var gold_val: int = int(data.get("gold", 0))
	var drone_cur: int = int(data.get("drone_charges", 3))
	var drone_max: int = int(data.get("max_drone_charges", 3))
	var hp_num := ceili(float(data.get("health", 100.0)))
	var low_hp := float(data.get("health", 100.0)) < 30.0
	var show_compact_overweight := overweight and (_touch_layout or _is_narrow or _is_short)
	if _touch_layout:
		health_value.text = ("!超重 · %d" % hp_num) if show_compact_overweight else ("＋ %d" % hp_num)
	else:
		health_value.text = ("!超重 · 生命 %d" % hp_num) if show_compact_overweight else ("＋  生命 %d" % hp_num)
	_set_font_color(health_value, Art.DANGER if low_hp else (ORANGE if show_compact_overweight else INK))
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
		var joined_marinca := "\n".join(lines)
		var marinca_changed := marinca_grid_label.text != joined_marinca
		marinca_grid_label.text = joined_marinca
		if marinca_changed and active_screen == "sushi":
			_apply_layout()

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
		if is_instance_valid(_compact_pin_label):
			_compact_pin_label.text = ""
			_compact_pin_label.hide()
	else:
		pinned_panel.show()
		var p_name: String = str(pinned_info.get("name", "配方"))
		var is_all_ready: bool = bool(pinned_info.get("all_ready", false))
		pinned_title.text = "【配方追踪】%s %s" % [p_name, "✦ 材料齐备" if is_all_ready else ""]
		_set_font_color(pinned_title, ORANGE if is_all_ready else CYAN)
		var items_arr: Array = pinned_info.get("details", [])
		var parts: Array[String] = []
		var short_parts: Array[String] = []
		for it: Dictionary in items_arr:
			var ready_mark := "✓" if bool(it.get("ready", false)) else ""
			parts.append("%s %d/%d%s" % [str(it.get("name")), int(it.get("current")), int(it.get("required")), ready_mark])
			short_parts.append("%s%d/%d%s" % [str(it.get("name")), int(it.get("current")), int(it.get("required")), ready_mark])
		pinned_progress.text = "   ".join(parts)
		if is_instance_valid(_compact_pin_label):
			_compact_pin_label.add_theme_font_size_override("font_size", 12 if _touch_layout else 14)
			if _touch_layout:
				_compact_pin_label.text = ("✦ %s ✓" % p_name) if is_all_ready else ("✦ %s" % " ".join(short_parts))
			else:
				_compact_pin_label.text = ("✦ %s · 可制作✓" % p_name) if is_all_ready else ("✦ %s: %s" % [p_name, " ".join(short_parts)])
			_set_font_color(_compact_pin_label, ORANGE if is_all_ready else CYAN)

	# 更新潜水面罩 Shader 呼吸与冰霜凝雾
	if is_instance_valid(visor_material):
		var is_sprint: bool = bool(data.get("sprinting", false))
		var breath_val: float = (0.55 if is_sprint else 0.12) * (0.5 + sin(Time.get_ticks_msec() * 0.006) * 0.5)
		var frost_val: float = clampf((22.0 - oxygen_level) / 22.0, 0.0, 1.0) if not is_explore else 0.0
		_last_breath = breath_val
		_last_frost = frost_val
		visor_material.set_shader_parameter("breath", breath_val)
		visor_material.set_shader_parameter("frost", frost_val)
	_sync_visor_visibility()

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
	var raw_cs: Variant = data.get("combat_state", {})
	var cs: Dictionary = raw_cs if raw_cs is Dictionary else {}
	var weapon_names := {
		"knife": "潜水刀",
		"axe": "破拆战斧",
		"sonic": "蓝光静滞枪",
		"marker": "光标指示枪",
		"marker_gun": "光标指示枪",
		"harpoon": "电磁鱼叉枪",
		"sonar_cannon": "声呐震荡炮",
	}
	var short_weapon_names := {
		"knife": "战术刀",
		"axe": "破拆斧",
		"sonic": "蓝光枪",
		"marker": "指示枪",
		"marker_gun": "指示枪",
		"harpoon": "鱼叉枪",
		"sonar_cannon": "震荡炮",
	}
	var raw_slots: Variant = cs.get("equipped_slots", data.get("equipped_slots", []))
	var equipped_slots: Array = raw_slots if raw_slots is Array else []
	for s_i in range(mini(3, equipped_slots.size())):
		var qk := "weapon_%d" % (s_i + 1)
		if quick_buttons.has(qk) and is_instance_valid(quick_buttons[qk]):
			var sw_id := str(equipped_slots[s_i])
			var sw_label := str(weapon_names.get(sw_id, sw_id))
			if not sw_label.is_empty():
				(quick_buttons[qk] as Button).text = "%d · %s" % [s_i + 1, sw_label]
	var cur_w_name := str(weapon_names.get(cur_w, "潜水装备"))
	var upgrade_info := " · 强化 %d / +%d" % [w_level, int(w_bonus)] if w_level > 0 else ""
	if _touch_layout:
		weapon_bar_label.text = "%s%s" % [cur_w_name, upgrade_info]
	elif not equipped_slots.is_empty():
		var slot_parts: PackedStringArray = PackedStringArray()
		for s_i in range(mini(3, equipped_slots.size())):
			var sw_id := str(equipped_slots[s_i])
			if sw_id.is_empty():
				continue
			var sn := str(short_weapon_names.get(sw_id, weapon_names.get(sw_id, sw_id)))
			slot_parts.append(("◆%d %s" % [s_i + 1, sn]) if sw_id == cur_w else ("%d %s" % [s_i + 1, sn]))
		if cur_w in ["marker", "marker_gun"]:
			slot_parts.append("◆4 指示枪")
		weapon_bar_label.text = "%s%s" % ["  ·  ".join(slot_parts), upgrade_info] if not slot_parts.is_empty() else ("1—4 切换 / %s%s" % [cur_w_name, upgrade_info])
	else:
		weapon_bar_label.text = "1—4 切换 / %s%s" % [cur_w_name, upgrade_info]
	var is_gun := cur_w == "sonic"
	var aiming: bool = is_gun and bool(data.get("aiming", false))
	var scoped: bool = is_gun and bool(data.get("scoped", false))
	var charging: bool = is_gun and bool(data.get("charging", false))
	var prev_scoped := _scoped_active
	_scoped_active = scoped
	if prev_scoped != scoped and _touch_layout:
		_apply_layout()
	aim_frame.visible = aiming and not scoped
	if is_instance_valid(_aim_frame_label):
		var aim_txt := "精密瞄准" if _touch_layout else "精密瞄准 / T"
		_aim_frame_label.set_meta("_hint_source", aim_txt)
		_aim_frame_label.text = format_input_text(aim_txt)
		_aim_frame_label.set_meta("_hint_rendered", _aim_frame_label.text)
		_aim_frame_label.set_meta("_hint_generation", _hint_generation)
	_sync_visor_visibility()
	scope_label.visible = scoped
	if is_instance_valid(scope_exit_btn):
		scope_exit_btn.visible = scoped
	var in_sub: bool = bool(data.get("in_submarine", false))
	var booster_on: bool = bool(data.get("booster_active", false))
	equipment_value.visible = not scoped and not in_sub and not _touch_layout
	weapon_hint.visible = not scoped and not in_sub and not booster_on
	var scope_dist_m := roundi(float(data.get("scope_distance", 2000.0)))
	scope_label.text = ("8× 远距镜  ·  测距 %d m" % scope_dist_m) if _touch_layout else ("8× 远距镜  /  测距 %d m  /  Y 退出" % scope_dist_m)
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
	var stagger_t: float = float(boss.get("stagger_timer", 0.0))
	var is_staggered: bool = bool(boss.get("is_staggered", boss.get("staggered", false))) or stagger_t > 0.0
	_boss_stagger_active = fighting and is_staggered
	if is_instance_valid(boss_poise_bar):
		var poise_ratio := 1.0
		if is_staggered:
			var stagger_max := maxf(1.0, float(boss.get("stagger_max", 4.5)))
			poise_ratio = clampf(stagger_t / stagger_max, 0.0, 1.0) if stagger_t > 0.0 else 1.0
			boss_poise_bar.add_theme_stylebox_override("fill", _boss_poise_stagger_fill)
		else:
			if boss.has("poise_ratio"):
				poise_ratio = clampf(float(boss.get("poise_ratio", 1.0)), 0.0, 1.0)
			elif boss.has("poise") or boss.has("max_poise"):
				var max_p := maxf(1.0, float(boss.get("max_poise", 100.0)))
				poise_ratio = clampf(float(boss.get("poise", max_p)) / max_p, 0.0, 1.0)
			boss_poise_bar.add_theme_stylebox_override("fill", _boss_poise_normal_fill)
			boss_poise_bar.modulate = Color.WHITE
		boss_poise_bar.max_value = 1.0
		boss_poise_bar.value = poise_ratio
	var weakpoint_lbl := str(boss.get("weakpoint_label", boss.get("weakpoint", ""))).strip_edges()
	var status_tag := _format_boss_statuses(boss.get("statuses", boss.get("status_effects", boss.get("active_statuses", []))))
	var boss_warn_raw := str(boss.get("warning", "")).strip_edges()
	var boss_sub_parts: PackedStringArray = PackedStringArray()
	if is_staggered:
		boss_sub_parts.append(("破防失衡 %.1fs" % stagger_t) if stagger_t > 0.0 else "破防失衡")
		if not weakpoint_lbl.is_empty():
			boss_sub_parts.append("弱点: %s" % weakpoint_lbl)
		if not status_tag.is_empty():
			boss_sub_parts.append(status_tag)
		_set_font_color(boss_warning, CYAN)
	elif frozen > 0.0:
		boss_sub_parts.append("静滞冻结 %.1fs · 立即攻击" % frozen)
		if not status_tag.is_empty():
			boss_sub_parts.append(status_tag)
		_set_font_color(boss_warning, CYAN)
	elif not boss_warn_raw.is_empty():
		boss_sub_parts.append(boss_warn_raw)
		if not status_tag.is_empty():
			boss_sub_parts.append(status_tag)
		_set_font_color(boss_warning, AMBER_GOLD)
	else:
		if not weakpoint_lbl.is_empty():
			boss_sub_parts.append("弱点: %s" % weakpoint_lbl)
		if not status_tag.is_empty():
			boss_sub_parts.append(status_tag)
		_set_font_color(boss_warning, MUTED if boss_sub_parts.is_empty() else AMBER_GOLD)
	boss_warning.text = " · ".join(boss_sub_parts)
	_update_combat_strip(cs, cur_w, fighting, scoped, in_sub, data)

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
			sub_weapon_label.text = (("电磁脉冲炮 · 就绪" if _touch_layout else "电磁脉冲炮 [就绪 · T/Y瞄准]") if w_ready else "电磁脉冲炮 [冷却 %.1fs]" % w_cd)
		elif torp_guided:
			sub_weapon_label.text = "车载鱼雷 [飞行中]"
		elif w_ready:
			sub_weapon_label.text = "车载鱼雷 · 就绪" if _touch_layout else "车载鱼雷 [就绪 · R发射]"
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
			var s_row: Control = mount_board_slot_rows[idx] if idx < mount_board_slot_rows.size() else null
			var r_btn: Button = mount_board_ride_buttons[idx] if idx < mount_board_ride_buttons.size() else null
			if idx < beast_cnt:
				var b_entry: Dictionary = beasts[idx]
				var b_name: String = str(b_entry.get("name", "契约海兽"))
				var b_hp: int = roundi(float(b_entry.get("health", 600.0)))
				var is_dep: bool = bool(b_entry.get("deployed", true))
				if is_instance_valid(s_row):
					s_row.visible = true
				s_btn.visible = true
				s_btn.disabled = false
				var state_str := "出战中" if is_dep else "可召唤"
				s_btn.text = "%02d / %s\n生命 %d · %s" % [idx + 1, b_name, b_hp, state_str]
				_set_font_color(s_btn, AMBER_GOLD if is_dep else INK)
				if is_instance_valid(r_btn):
					var is_riding := mount_idx == idx
					r_btn.visible = true
					r_btn.disabled = false
					r_btn.text = "离鞍" if is_riding else "骑乘"
					OceanUiTheme.button(r_btn, is_riding)
			else:
				if is_instance_valid(s_row):
					s_row.visible = beast_cnt > 0
				s_btn.visible = beast_cnt > 0
				s_btn.disabled = true
				s_btn.text = "%02d / 尚未契约" % (idx + 1)
				if is_instance_valid(r_btn):
					r_btn.visible = false
					r_btn.disabled = true

	var is_shield: bool = bool(data.get("shield_active", false))
	shield_label.text = "C / 能量盾防御中" if is_shield else "C / 能量盾收起"
	_set_font_color(shield_label, CYAN if is_shield else MUTED)

	var q_tracker_raw: Variant = data.get("quest_tracker", {})
	var q_tracker: Dictionary = q_tracker_raw if q_tracker_raw is Dictionary else {}
	var has_q_tracker := not q_tracker.is_empty()
	var q_tracker_visible := has_q_tracker and bool(q_tracker.get("visible", false))
	var wp_dist: int = roundi(p_pos.distance_to(wp_pos)) if has_wp else 0

	if fighting:
		var b_title := str(boss.get("name", "深渊领主"))
		mission_title.text = ("巨兽领域 · %s (残血可静滞契约)" % b_title) if _is_compact else ("巨兽领域 / %s" % b_title)
		mission_detail.text = "残血时蓄力静滞，靠近按 E 契约驯服。"
	elif q_tracker_visible:
		var act_lbl := str(q_tracker.get("act_label", "")).strip_edges()
		var q_title := str(q_tracker.get("title", "")).strip_edges()
		var prog_txt := str(q_tracker.get("progress_text", "")).strip_edges()
		if _is_compact:
			mission_title.text = ("%s (%s)" % [q_title, prog_txt]) if not prog_txt.is_empty() else q_title
		else:
			mission_title.text = ("%s · %s" % [act_lbl, q_title]) if not act_lbl.is_empty() else q_title
		mission_detail.text = _format_quest_tracker_detail(q_tracker, has_wp, wp_dist)
	elif not has_q_tracker and bool(data.get("mother_tree_active", false)) and not bool(data.get("escape_crafted", false)):
		var items_cnt: int = int(data.get("tree_items_collected", 0))
		if items_cnt >= 3:
			mission_title.text = "母树圣物 (3/3) · 返回母港" if _is_compact else "母树圣物齐集 / 返回母港"
			mission_detail.text = "母树遗物 (3/3) · 或按 M 继续自由探索开放大海域"
		else:
			var dist_tree: float = float(data.get("distance_mother_tree", 300.0))
			mission_title.text = ("母树圣所 %dm · 圣物 (%d/3)" % [roundi(dist_tree), items_cnt]) if _is_compact else "潜入母树圣所"
			mission_detail.text = "深海极渊母树 %d 米 · 收集核心物资 (%d/3)" % [roundi(dist_tree), items_cnt]
	elif has_wp:
		mission_title.text = ("✦ 标点 %dm · 探索 %d%%" % [wp_dist, exp_pct]) if _is_compact else ("沿标点继续勘测 / %d%%" % exp_pct)
		mission_detail.text = "✦ 距离目标标点 %d 米 · 按 M 查看海图或切换跃迁点" % wp_dist
	else:
		if _is_compact:
			mission_title.text = ("探索 %d%% · 前哨 %dm" % [exp_pct, roundi(best_out_d)]) if has_near_out else ("探索 %d%% · 地标 %d/%d · 遗珍 %d/%d" % [exp_pct, lm_cnt, lm_tot, rel_cnt, rel_tot])
		else:
			mission_title.text = "开放海域探索 / %d%%" % exp_pct
		if has_near_out:
			mission_detail.text = "最近未激活前哨 %dm · 按 M 海图跃迁 / N 声呐寻宝" % roundi(best_out_d)
		else:
			mission_detail.text = "地标 %d/%d · 前哨 %d/%d · 遗珍 %d/%d · 按 M 海图自由跃迁" % [lm_cnt, lm_tot, out_cnt, out_tot, rel_cnt, rel_tot]

	if cur_w != _previous_weapon or inventory != _previous_inventory:
		_detail_time = 3.5
		if cur_w != _previous_weapon and not _previous_weapon.is_empty():
			_weapon_flash_time = 1.8
		_previous_weapon = cur_w
		_previous_inventory = inventory.duplicate()
	var details := _detail_time > 0.0 or aiming or charging or fighting or not target.is_empty()
	weapon_bar_label.get_parent().visible = ((_weapon_flash_time > 0.0 and not scoped) if _touch_layout else details) and not in_sub and not booster_on
	equipment_value.visible = details and not in_sub and not scoped and not _touch_layout
	_cargo_wants_visible = details or overweight
	_cargo.visible = details or overweight
	shield_label.visible = is_shield or details
	var onboarding: Dictionary = data.get("onboarding", {})
	sync_onboarding_state(onboarding)
	var ob_active := bool(onboarding.get("active", false))
	var show_onboarding := ob_active and not scoped and not fighting and not in_sub
	var story_route := q_tracker_visible if has_q_tracker else (bool(data.get("mother_tree_active", false)) and not bool(data.get("escape_crafted", false)))
	var show_mission := ((has_wp or fighting or story_route) if _touch_layout else (has_wp or fighting or details or story_route)) and not show_onboarding and not scoped
	mission_title.visible = show_mission
	mission_detail.visible = show_mission
	explore_summary_label.visible = details
	_journal_heading.modulate.a = 0.92 if (show_mission or show_onboarding) else 0.28
	if is_instance_valid(_journal_bar):
		_journal_bar.modulate.a = 0.92 if (show_mission or show_onboarding) else 0.26
	weapon_hint.visible = details and not scoped and not in_sub and not booster_on
	reticle.visible = not scoped and (aiming or charging or not target.is_empty() or in_sub or cur_w in ["sonic", "marker", "marker_gun", "harpoon", "sonar_cannon"])
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
			if is_instance_valid(toast_label) and toast_label.visible:
				_layout_toast()
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
	_layout_quest_banner()
	_layout_toast()
	var seconds := int(data.get("elapsed", 0.0))
	if bool(data.get("escape_crafted", false)):
		win_title.text = "深渊跃迁逃生成功"
		win_desc.text = "四大深海领主悉数平息，远古母树星核成功制作跃迁装置！\n你已顺利冲破深海极渊，踏上星际归航之路。"
		win_time.text = "本次潜航  %02d:%02d  /  母树终章完成 · 逃生成功" % [floori(float(seconds) / 60.0), seconds % 60]
	elif bool(boss.get("defeated", false)):
		win_title.text = "深渊水龙已被击败"
		win_desc.text = "潮汐君主沉入深渊，海域终于恢复平静。\n主线航程已抵达里程碑，你仍可继续探索深渊海域。"
		win_time.text = "本次潜航  %02d:%02d  /  领主平息 · 航程里程碑" % [floori(float(seconds) / 60.0), seconds % 60]
	elif is_explore:
		win_title.text = "全海域勘测已完成"
		win_desc.text = "你已探明阳光浅礁、暮光海沟与深海极渊的全部核心地标。\n深渊海域向勇敢的潜航勘测员致敬！"
		win_time.text = "本次探险  %02d:%02d  /  勘测度 100%%" % [floori(float(seconds) / 60.0), seconds % 60]
	else:
		win_title.text = "深海收到了回声"
		win_desc.text = "远洋科考回波信号已全频段上线。\n本次深海航程阶段目标已达成，可继续探索海域与回波委托。"
		win_time.text = "本次潜航  %02d:%02d  /  科考航程里程碑达成" % [floori(float(seconds) / 60.0), seconds % 60]
	var raw_journal: Variant = data.get("quest_journal", {})
	if raw_journal is Dictionary and not (raw_journal as Dictionary).is_empty():
		if active_screen == "quests" or not _quest_journal_synced:
			sync_quest_journal(raw_journal as Dictionary)
	if data.has("loadout") and data["loadout"] is Dictionary and not loadout_view.is_empty():
		sync_loadout(data["loadout"] as Dictionary)
	if data.has("character_id"):
		set_selected_character(str(data["character_id"]))
	_apply_device_hints()
	_apply_touch_visibility()

func _format_quest_tracker_detail(q_tracker: Dictionary, has_wp: bool, wp_dist: int) -> String:
	var raw_objs: Variant = q_tracker.get("objectives", [])
	var objs: Array = raw_objs if raw_objs is Array else []
	var ordered: Array[Dictionary] = []
	for item in objs:
		if item is Dictionary and not bool(item.get("done", false)):
			ordered.append(item)
	for item in objs:
		if item is Dictionary and bool(item.get("done", false)):
			ordered.append(item)
	var lines: PackedStringArray = []
	var limit := mini(2, ordered.size())
	for i in range(limit):
		var obj: Dictionary = ordered[i]
		var done := bool(obj.get("done", false))
		var mark := "✓" if done else "○"
		var lbl := str(obj.get("label", "")).strip_edges()
		var cur := int(obj.get("current", 0))
		var req := int(obj.get("required", 0))
		var dist_m := int(obj.get("distance_m", -1))
		var meta_parts: PackedStringArray = []
		if req > 1:
			meta_parts.append("%d/%d" % [mini(cur, req) if done else cur, req])
		if not done and dist_m >= 0:
			meta_parts.append("%dm" % dist_m)
		var line := "%s %s" % [mark, lbl]
		if not meta_parts.is_empty():
			line += " (%s)" % " · ".join(meta_parts)
		lines.append(line)
	if lines.is_empty():
		var fallback_prog := str(q_tracker.get("progress_text", "")).strip_edges()
		lines.append("进度 %s" % fallback_prog if not fallback_prog.is_empty() else "查看任务详情")
	var suffix := " · U 日志"
	if has_wp:
		suffix += " · ✦ 标点 %dm" % wp_dist
	lines[lines.size() - 1] = lines[lines.size() - 1] + suffix
	return "\n".join(lines)

func sync_quest_journal(journal_payload: Dictionary) -> void:
	if quest_view.is_empty() or journal_payload.is_empty():
		return
	QuestPanel.update_data(quest_view, journal_payload)
	_quest_journal_synced = true

func sync_loadout(loadout_payload: Dictionary) -> void:
	if loadout_view.is_empty():
		return
	LoadoutPanel.update_data(loadout_view, loadout_payload)
	_loadout_synced = true

static func _format_boss_statuses(raw_statuses: Variant) -> String:
	var status_names := {
		"electro": "感电",
		"rupture": "流血",
		"bleed": "流血",
		"stasis": "静滞",
		"resonance": "共鸣",
		"armor_shred": "破甲",
	}
	var tags: PackedStringArray = PackedStringArray()
	if raw_statuses is Dictionary:
		var sd: Dictionary = raw_statuses
		for k_v in sd.keys():
			var val: Variant = sd[k_v]
			if (val is float or val is int) and float(val) <= 0.0:
				continue
			if val is bool and not bool(val):
				continue
			var key := str(k_v).strip_edges()
			var lbl := str(status_names.get(key, key))
			if not lbl.is_empty() and not tags.has(lbl):
				tags.append(lbl)
	elif raw_statuses is Array:
		for item in (raw_statuses as Array):
			var key := ""
			if item is Dictionary:
				key = str((item as Dictionary).get("name", (item as Dictionary).get("id", ""))).strip_edges()
			else:
				key = str(item).strip_edges()
			var lbl := str(status_names.get(key, key))
			if not lbl.is_empty() and not tags.has(lbl):
				tags.append(lbl)
	if tags.is_empty():
		return ""
	return "[%s]" % "/".join(tags)

func _update_combat_strip(cs: Dictionary, cur_w: String, fighting: bool, scoped: bool, in_sub: bool, data: Dictionary) -> void:
	if not is_instance_valid(combat_strip):
		return
	if cs.is_empty():
		_combat_strip_want_visible = false
		_combat_ult_ready = false
		_combat_show_heat = false
		_combat_show_cmd = false
		combat_strip.modulate.a = 0.0
		combat_strip.hide()
		return
	var shield_ratio := clampf(float(cs.get("shield_ratio", 1.0)), 0.0, 1.0)
	var shield_over := bool(cs.get("shield_overloaded", false))
	var flux_ratio := clampf(float(cs.get("flux_ratio", 0.0)), 0.0, 1.0)
	var ult_ready := bool(cs.get("ultimate_ready", false))
	var show_heat := bool(cs.get("show_sonic_heat", false))
	var heat_ratio := clampf(float(cs.get("sonic_heat_ratio", 0.0)), 0.0, 1.0)
	var heat_over := bool(cs.get("sonic_overheated", false))
	var art_cd := float(cs.get("weapon_art_cd", 0.0))
	var tac_cd := float(cs.get("tactical_cd", 0.0))
	var in_combat := bool(cs.get("in_combat", data.get("in_combat", false)))
	var show_cmd := cur_w in ["marker", "marker_gun"]

	var layout_dirty := (
		ult_ready != _combat_ult_ready
		or show_heat != _combat_show_heat
		or show_cmd != _combat_show_cmd
	)
	_combat_ult_ready = ult_ready
	_combat_show_heat = show_heat
	_combat_show_cmd = show_cmd

	_combat_shield_bar.value = shield_ratio
	_combat_shield_bar.add_theme_stylebox_override("fill", _combat_shield_over_fill if shield_over else _combat_shield_normal_fill)
	_combat_shield_lbl.text = "过载" if shield_over else "盾"
	_set_font_color(_combat_shield_lbl, Art.DANGER if shield_over else CYAN)

	_combat_flux_bar.value = flux_ratio
	_combat_flux_bar.add_theme_stylebox_override("fill", _combat_flux_ready_fill if ult_ready else _combat_flux_normal_fill)
	if ult_ready:
		_combat_flux_lbl.text = "[~] 终极技就绪"
		_set_font_color(_combat_flux_lbl, AMBER_GOLD)
	else:
		_combat_flux_lbl.text = "共鸣"
		_set_font_color(_combat_flux_lbl, CYAN)
		_combat_flux_lbl.modulate = Color.WHITE

	_combat_heat_bar.value = heat_ratio
	_combat_heat_bar.add_theme_stylebox_override("fill", _combat_heat_over_fill if heat_over else _combat_heat_normal_fill)
	_combat_heat_lbl.text = "过热" if heat_over else "热"
	_set_font_color(_combat_heat_lbl, Art.DANGER if heat_over else ORANGE)

	var art_name := str(cs.get("weapon_art_name", "战技")).strip_edges()
	if art_name.is_empty():
		art_name = "战技"
	_combat_art_lbl.text = ("[X] %.1fs" % art_cd) if art_cd > 0.05 else ("[X] %s" % art_name)
	_set_font_color(_combat_art_lbl, MUTED if art_cd > 0.05 else CYAN)

	var tac_name := str(cs.get("tactical_name", "战术")).strip_edges()
	if tac_name.is_empty():
		tac_name = "战术"
	_combat_tac_lbl.text = ("[I] %.1fs" % tac_cd) if tac_cd > 0.05 else ("[I] %s" % tac_name)
	_set_font_color(_combat_tac_lbl, MUTED if tac_cd > 0.05 else CYAN)

	var cmd_mode := str(cs.get("command_mode", "focus"))
	var is_capture := cmd_mode == "capture"
	_combat_cmd_lbl.text = "活捕压血" if is_capture else "集火狂攻"
	_set_font_color(_combat_cmd_lbl, Color("63e0b8") if is_capture else AMBER_GOLD)

	var active_for_touch := (
		in_combat
		or fighting
		or shield_ratio < 0.99
		or shield_over
		or flux_ratio > 0.01
		or ult_ready
		or (show_heat and heat_ratio > 0.01)
		or heat_over
	)
	var active_for_desktop := active_for_touch or art_cd > 0.05 or tac_cd > 0.05
	var want_show := (not scoped) and (not in_sub) and (active_for_touch if _touch_layout else active_for_desktop)
	var vis_changed := want_show != _combat_strip_want_visible
	_combat_strip_want_visible = want_show

	if _touch_layout:
		combat_strip.visible = want_show
		combat_strip.modulate.a = 0.92 if want_show else 0.0
	elif want_show:
		combat_strip.visible = true
		if combat_strip.modulate.a < 0.05:
			combat_strip.modulate.a = 0.25
	if layout_dirty or vis_changed:
		_layout_combat_strip_contents(combat_strip.offset_right - combat_strip.offset_left, combat_strip.offset_bottom - combat_strip.offset_top)
		_sync_desktop_bottom_offsets()

func _process_combat_visuals(delta: float) -> void:
	_combat_pulse_clock += delta
	var pulse := 0.62 + 0.38 * (0.5 + 0.5 * sin(_combat_pulse_clock * 7.5))
	if _boss_stagger_active and is_instance_valid(boss_panel) and boss_panel.visible and is_instance_valid(boss_poise_bar):
		boss_poise_bar.modulate = Color(1.0, 1.0, 1.0, pulse)
	if is_instance_valid(combat_strip):
		if _touch_layout:
			if not _combat_strip_want_visible and combat_strip.visible:
				combat_strip.hide()
		else:
			var target_a := 0.96 if _combat_strip_want_visible else 0.0
			if absf(combat_strip.modulate.a - target_a) > 0.01:
				combat_strip.modulate.a = move_toward(combat_strip.modulate.a, target_a, delta * 5.0)
			else:
				combat_strip.modulate.a = target_a
			var should_vis := _combat_strip_want_visible or combat_strip.modulate.a > 0.01
			if combat_strip.visible != should_vis:
				combat_strip.visible = should_vis
				_sync_desktop_bottom_offsets()
		if combat_strip.visible and _combat_ult_ready and is_instance_valid(_combat_flux_lbl) and not _touch_layout:
			_combat_flux_lbl.modulate = Color(1.0, 1.0, 1.0, pulse)
		elif is_instance_valid(_combat_flux_lbl):
			_combat_flux_lbl.modulate = Color.WHITE

func _sync_desktop_bottom_offsets() -> void:
	if _touch_layout or _is_compact:
		return
	if not is_instance_valid(weapon_hint) or not is_instance_valid(target_value):
		return
	var lift := 28.0 if (is_instance_valid(combat_strip) and combat_strip.visible) else 0.0
	_set_control_rect(weapon_hint, Rect2(-290.0, -147.0 - lift, 580.0, 22.0), Vector2(0.5, 1.0))
	_set_control_rect(target_value, Rect2(-280.0, -188.0 - lift, 560.0, 30.0), Vector2(0.5, 1.0))

func _layout_combat_strip_contents(strip_w: float, strip_h: float) -> void:
	if not is_instance_valid(combat_strip):
		return
	var w := maxf(120.0, strip_w)
	var h := maxf(14.0, strip_h)
	combat_strip.add_theme_stylebox_override("panel", _combat_strip_touch_style if _touch_layout else _combat_strip_desktop_style)
	if _touch_layout:
		_combat_shield_lbl.visible = false
		_combat_flux_lbl.visible = false
		_combat_heat_lbl.visible = false
		_combat_art_lbl.visible = false
		_combat_tac_lbl.visible = false
		_combat_cmd_lbl.visible = false
		_combat_shield_bar.visible = true
		_combat_flux_bar.visible = true
		_combat_heat_bar.visible = _combat_show_heat
		var pad := 8.0
		var gap := 6.0
		var bar_h := 4.0
		var bar_y := floorf((h - bar_h) * 0.5)
		var count := 3 if _combat_show_heat else 2
		var seg_w := maxf(24.0, floorf((w - pad * 2.0 - gap * float(count - 1)) / float(count)))
		_set_control_rect(_combat_shield_bar, Rect2(pad, bar_y, seg_w, bar_h))
		_set_control_rect(_combat_flux_bar, Rect2(pad + seg_w + gap, bar_y, seg_w, bar_h))
		if _combat_show_heat:
			var hx := pad + (seg_w + gap) * 2.0
			_set_control_rect(_combat_heat_bar, Rect2(hx, bar_y, maxf(20.0, w - pad - hx), bar_h))
		return

	_combat_shield_lbl.visible = true
	_combat_shield_bar.visible = true
	_combat_flux_lbl.visible = true
	_combat_flux_bar.visible = true
	_combat_heat_lbl.visible = _combat_show_heat
	_combat_heat_bar.visible = _combat_show_heat
	_combat_art_lbl.visible = true
	_combat_tac_lbl.visible = true
	_combat_cmd_lbl.visible = _combat_show_cmd

	var pad_d := 10.0
	var x := pad_d
	var narrow_bar := w < 430.0
	var bar_h_d := 5.0
	var bar_y_d := floorf((h - bar_h_d) * 0.5)
	var lbl_y := floorf((h - 20.0) * 0.5)

	var sh_lbl_w := 32.0 if _combat_shield_lbl.text.length() >= 2 else 22.0
	var sh_bar_w := 36.0 if narrow_bar else 50.0
	_set_control_rect(_combat_shield_lbl, Rect2(x, lbl_y, sh_lbl_w, 20.0))
	x += sh_lbl_w + 2.0
	_set_control_rect(_combat_shield_bar, Rect2(x, bar_y_d, sh_bar_w, bar_h_d))
	x += sh_bar_w + 8.0

	if _combat_ult_ready:
		var ready_w := 92.0 if narrow_bar else 108.0
		_set_control_rect(_combat_flux_lbl, Rect2(x, lbl_y - 1.0, ready_w, 18.0))
		_set_control_rect(_combat_flux_bar, Rect2(x, h - 5.0, ready_w, 2.0))
		x += ready_w + 8.0
	else:
		var fl_lbl_w := 30.0
		var fl_bar_w := 36.0 if narrow_bar else 50.0
		_set_control_rect(_combat_flux_lbl, Rect2(x, lbl_y, fl_lbl_w, 20.0))
		x += fl_lbl_w + 2.0
		_set_control_rect(_combat_flux_bar, Rect2(x, bar_y_d, fl_bar_w, bar_h_d))
		x += fl_bar_w + 8.0

	if _combat_show_heat:
		var ht_lbl_w := 32.0 if _combat_heat_lbl.text.length() >= 2 else 22.0
		var ht_bar_w := 32.0 if narrow_bar else 42.0
		_set_control_rect(_combat_heat_lbl, Rect2(x, lbl_y, ht_lbl_w, 20.0))
		x += ht_lbl_w + 2.0
		_set_control_rect(_combat_heat_bar, Rect2(x, bar_y_d, ht_bar_w, bar_h_d))
		x += ht_bar_w + 8.0

	var rem_w := maxf(80.0, w - pad_d - x)
	var chip_count := 3 if _combat_show_cmd else 2
	var chip_gap := 6.0
	var chip_w := maxf(32.0, floorf((rem_w - chip_gap * float(chip_count - 1)) / float(chip_count)))
	_set_control_rect(_combat_art_lbl, Rect2(x, lbl_y, chip_w, 20.0))
	x += chip_w + chip_gap
	_set_control_rect(_combat_tac_lbl, Rect2(x, lbl_y, chip_w if _combat_show_cmd else maxf(32.0, w - pad_d - x), 20.0))
	if _combat_show_cmd:
		x += chip_w + chip_gap
		_set_control_rect(_combat_cmd_lbl, Rect2(x, lbl_y, maxf(32.0, w - pad_d - x), 20.0))

func push_quest_banners(banners: Array) -> void:
	for raw in banners:
		if not (raw is Dictionary):
			continue
		var title := str(raw.get("title", "")).strip_edges()
		var detail := str(raw.get("detail", "")).strip_edges()
		if title.is_empty() and detail.is_empty():
			continue
		_quest_banner_queue.append({
			"kind": str(raw.get("kind", "info")),
			"title": title,
			"detail": detail,
			"accent": str(raw.get("accent", "cyan")),
		})
	if _quest_banner_timer <= 0.0 and not _quest_banner_queue.is_empty():
		_advance_quest_banner()

func _advance_quest_banner() -> void:
	if _quest_banner_queue.is_empty():
		_quest_banner_current = {}
		_quest_banner_timer = 0.0
		if is_instance_valid(quest_banner_panel):
			quest_banner_panel.hide()
		return
	_quest_banner_current = _quest_banner_queue.pop_front()
	_quest_banner_timer = QUEST_BANNER_DURATION
	if not is_instance_valid(quest_banner_panel):
		return
	var accent_key := str(_quest_banner_current.get("accent", "cyan")).to_lower()
	var kind_key := str(_quest_banner_current.get("kind", "")).to_lower()
	var accent_color := CYAN
	if accent_key in ["gold", "amber"] or kind_key == "quest_complete":
		accent_color = AMBER_GOLD
	elif accent_key in ["done", "green"]:
		accent_color = Color("63e0b8")
	quest_banner_panel.add_theme_stylebox_override("panel", _style(Color(Art.INK, 0.92), Color(accent_color, 0.62), 3))
	if is_instance_valid(_quest_banner_accent):
		_quest_banner_accent.color = accent_color
	if is_instance_valid(_quest_banner_title):
		_quest_banner_title.text = str(_quest_banner_current.get("title", ""))
		_set_font_color(_quest_banner_title, accent_color)
	if is_instance_valid(_quest_banner_detail):
		var raw_detail := str(_quest_banner_current.get("detail", ""))
		_quest_banner_detail.set_meta("_hint_source", raw_detail)
		_quest_banner_detail.text = format_input_text(raw_detail)
		_quest_banner_detail.set_meta("_hint_rendered", _quest_banner_detail.text)
		_quest_banner_detail.set_meta("_hint_generation", _hint_generation)
	quest_banner_panel.modulate.a = 1.0
	quest_banner_panel.visible = active_screen == "play"
	_layout_quest_banner()
	_layout_toast()

func _process_quest_banner(delta: float) -> void:
	if not is_instance_valid(quest_banner_panel):
		return
	if _quest_banner_timer > 0.0:
		if active_screen != "play":
			quest_banner_panel.hide()
			return
		_quest_banner_timer = maxf(0.0, _quest_banner_timer - delta)
		if _quest_banner_timer <= 0.0:
			if not _quest_banner_queue.is_empty():
				_advance_quest_banner()
			else:
				_quest_banner_current = {}
				quest_banner_panel.hide()
				if is_instance_valid(toast_label) and toast_label.visible:
					_layout_toast()
			return
		var elapsed := QUEST_BANNER_DURATION - _quest_banner_timer
		var alpha := 1.0
		if elapsed < QUEST_BANNER_FADE_IN:
			alpha = clampf(elapsed / QUEST_BANNER_FADE_IN, 0.0, 1.0)
		elif _quest_banner_timer < QUEST_BANNER_FADE_OUT:
			alpha = clampf(_quest_banner_timer / QUEST_BANNER_FADE_OUT, 0.0, 1.0)
		_layout_quest_banner()
		quest_banner_panel.modulate.a = alpha
		quest_banner_panel.visible = true
	elif not _quest_banner_queue.is_empty() and active_screen == "play":
		_advance_quest_banner()
	elif quest_banner_panel.visible:
		quest_banner_panel.hide()

func _layout_quest_banner() -> void:
	if not is_instance_valid(quest_banner_panel) or not is_instance_valid(root):
		return
	var safe := _safe_area_rect()
	var max_w := safe.size.x - (240.0 if (_touch_layout and _is_short and not _is_portrait) else 32.0)
	var width := minf(480.0, maxf(210.0, max_w))
	var left := floorf((safe.size.x - width) * 0.5)
	var detail_text := _quest_banner_detail.text if is_instance_valid(_quest_banner_detail) else ""
	var has_detail := not detail_text.is_empty()
	var inner_w := maxf(140.0, width - 30.0)
	var detail_h := 0.0
	if has_detail:
		var font := _quest_banner_detail.get_theme_font("font") if is_instance_valid(_quest_banner_detail) else null
		var est_w := font.get_string_size(detail_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x if font != null else float(detail_text.length()) * 13.0
		var lines := clampi(ceili(est_w / maxf(120.0, inner_w)), 1, 2)
		detail_h = float(lines) * 19.0 + 2.0
	var height := (32.0 + detail_h + 8.0) if has_detail else 42.0
	var top := 74.0 if (_touch_layout and _is_short) else 128.0
	var avoid_nodes: Array[Control] = [compass_strip, depth_value, status_value, boss_panel, onboarding_panel]
	if _is_portrait:
		avoid_nodes.append(minimap_radar)
		avoid_nodes.append(_compact_pin_label)
	var banner_g_left := safe.position.x + left
	var banner_g_right := banner_g_left + width
	for node: Control in avoid_nodes:
		if not is_instance_valid(node):
			continue
		if not (node.is_visible_in_tree() or (instruments.visible and node.visible)):
			continue
		var g_rect := node.get_global_rect()
		if banner_g_left < g_rect.end.x and banner_g_right > g_rect.position.x:
			top = maxf(top, g_rect.end.y - safe.position.y + 8.0)
	top = minf(top, maxf(8.0, safe.size.y - height - 8.0))
	_set_control_rect(quest_banner_panel, Rect2(left, top, width, height))
	if is_instance_valid(_quest_banner_accent):
		_set_control_rect(_quest_banner_accent, Rect2(0.0, 0.0, 4.0, height))
	if is_instance_valid(_quest_banner_title):
		_set_control_rect(_quest_banner_title, Rect2(16.0, 8.0 if has_detail else 10.0, inner_w, 24.0))
	if is_instance_valid(_quest_banner_detail):
		_quest_banner_detail.visible = has_detail
		if has_detail:
			_set_control_rect(_quest_banner_detail, Rect2(16.0, 32.0, inner_w, detail_h))

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

func set_can_continue_voyage(available: bool, summary: String = "") -> void:
	_can_continue_voyage = available
	if is_instance_valid(continue_voyage_btn):
		continue_voyage_btn.visible = available
		continue_voyage_btn.tooltip_text = summary
		OceanUiTheme.button(continue_voyage_btn, true)
	if _main_ui.has("explore_btn") and is_instance_valid(_main_ui["explore_btn"]):
		OceanUiTheme.button(_main_ui["explore_btn"] as Button, not available)
	if is_instance_valid(continue_summary_label):
		continue_summary_label.text = summary
		continue_summary_label.tooltip_text = summary
		continue_summary_label.visible = available and not summary.is_empty()
	_apply_layout()
	_refresh_navigation.call_deferred()

func _add_modal_close_button(card: Control, btn_name: String) -> Button:
	var btn := _button(card, "✕ 返回", Rect2(card.size.x - 104.0, 14.0, 80.0, 44.0), func() -> void: close_requested.emit())
	btn.name = btn_name
	btn.custom_minimum_size = Vector2(76, 44)
	btn.set_meta("_no_hint", true)
	return btn

func _handle_main_stage_input(event: InputEvent, receiver: Control) -> void:
	if active_screen != "main":
		return
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_MIDDLE:
		showcase_reset_requested.emit()
		receiver.accept_event()
	elif event is InputEventMouseMotion and (event.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT)) != 0:
		showcase_dragged.emit(event.relative)
		receiver.accept_event()
	elif event is InputEventScreenDrag:
		showcase_dragged.emit(event.relative)
		receiver.accept_event()

func _sync_visor_visibility() -> void:
	var in_play := active_screen == "play"
	if is_instance_valid(scope_overlay):
		scope_overlay.visible = in_play and _scoped_active
	if is_instance_valid(visor_rect):
		var perf_mode := false
		if is_instance_valid(input_controller):
			perf_mode = str(input_controller.settings.get("graphics_quality", "auto")) == "performance"
		var suppress_idle := _touch_layout or _is_compact or perf_mode
		if is_instance_valid(visor_material):
			visor_material.set_shader_parameter("base_vignette", 0.0 if (suppress_idle and _last_frost < 0.01) else 0.06)
		if not in_play:
			visor_rect.visible = false
		elif _last_frost < 0.01 and (suppress_idle or _last_breath < 0.02):
			visor_rect.visible = false
		else:
			visor_rect.visible = true

func _handle_radar_gui_input(event: InputEvent) -> void:
	if not _touch_layout or active_screen != "play" or not is_instance_valid(minimap_radar):
		return
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled:
			_radar_tracking = true
			_radar_press_pos = event.position
			minimap_radar.accept_event()
		elif _radar_tracking:
			_radar_tracking = false
			minimap_radar.accept_event()
			if not event.canceled and event.position.distance_to(_radar_press_pos) < 16.0 and Rect2(Vector2.ZERO, minimap_radar.size).has_point(event.position):
				action_requested.emit("world_map")
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_radar_tracking = true
			_radar_press_pos = event.position
			minimap_radar.accept_event()
		elif _radar_tracking:
			_radar_tracking = false
			minimap_radar.accept_event()
			if event.position.distance_to(_radar_press_pos) < 16.0 and Rect2(Vector2.ZERO, minimap_radar.size).has_point(event.position):
				action_requested.emit("world_map")

func _handle_modal_backdrop_input(key: String, receiver: Control, event: InputEvent) -> void:
	if active_screen != key or not _modal_cards.has(key):
		return
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	var card: Control = _modal_cards[key]
	if not is_instance_valid(card) or not card.is_visible_in_tree():
		return
	var card_rect := card.get_global_rect()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var gpos: Vector2 = receiver.get_global_transform_with_canvas() * event.position
		if event.pressed:
			_backdrop_tracking = not card_rect.has_point(gpos)
			_backdrop_press_pos = gpos
			_backdrop_max_drift = 0.0
		elif _backdrop_tracking:
			_backdrop_tracking = false
			var drift := maxf(_backdrop_max_drift, gpos.distance_to(_backdrop_press_pos))
			if drift < 12.0 and not card_rect.has_point(gpos):
				receiver.accept_event()
				close_requested.emit()
	elif event is InputEventMouseMotion and _backdrop_tracking:
		var gpos_m: Vector2 = receiver.get_global_transform_with_canvas() * event.position
		_backdrop_max_drift = maxf(_backdrop_max_drift, gpos_m.distance_to(_backdrop_press_pos))
	elif event is InputEventScreenTouch:
		var gpos: Vector2 = receiver.get_global_transform_with_canvas() * event.position
		if event.pressed:
			if event.canceled:
				_backdrop_touches.erase(event.index)
				return
			_backdrop_touches[event.index] = {
				"origin": gpos,
				"max_drift": 0.0,
				"outside_on_press": not card_rect.has_point(gpos),
				"had_multi": _backdrop_touches.size() >= 1,
			}
			if _backdrop_touches.size() > 1:
				for k in _backdrop_touches:
					(_backdrop_touches[k] as Dictionary)["had_multi"] = true
		elif _backdrop_touches.has(event.index):
			var entry: Dictionary = _backdrop_touches[event.index]
			_backdrop_touches.erase(event.index)
			var max_drift := maxf(float(entry.get("max_drift", 0.0)), gpos.distance_to(entry.get("origin", gpos)))
			if (
				not event.canceled
				and _backdrop_touches.is_empty()
				and not bool(entry.get("had_multi", false))
				and bool(entry.get("outside_on_press", false))
				and max_drift < 12.0
				and not card_rect.has_point(gpos)
			):
				receiver.accept_event()
				close_requested.emit()
	elif event is InputEventScreenDrag and _backdrop_touches.has(event.index):
		var gpos_d: Vector2 = receiver.get_global_transform_with_canvas() * event.position
		var entry_d: Dictionary = _backdrop_touches[event.index]
		entry_d["max_drift"] = maxf(float(entry_d.get("max_drift", 0.0)), gpos_d.distance_to(entry_d.get("origin", gpos_d)))
		_backdrop_touches[event.index] = entry_d

func set_screen(screen: String) -> void:
	_backdrop_touches.clear()
	_backdrop_tracking = false
	_radar_tracking = false
	var focused := root.get_viewport().gui_get_focus_owner()
	if is_instance_valid(focused) and menus.has(active_screen) and menus[active_screen].is_ancestor_of(focused):
		_focus_memory[active_screen] = focused
	if screen == "play" and is_instance_valid(focused):
		focused.release_focus()
	active_screen = screen
	instruments.visible = screen == "play"
	_sync_visor_visibility()
	for key: String in menus:
		var menu: Control = menus[key]
		menu.visible = key == screen
		menu.mouse_filter = Control.MOUSE_FILTER_STOP if menu.visible else Control.MOUSE_FILTER_IGNORE
	if screen == "map" and is_instance_valid(sea_chart):
		sea_chart.center_on_player()
	if screen == "quests" and not quest_view.is_empty():
		QuestPanel.refresh_layout(quest_view)
	if screen == "loadout" and not loadout_view.is_empty():
		LoadoutPanel.refresh_layout(loadout_view)
	if screen != "play":
		toast_label.hide()
		if is_instance_valid(quest_banner_panel):
			quest_banner_panel.hide()
	if screen == "controls":
		_sync_input_settings()
	_refresh_navigation.call_deferred()

func toast(message: String) -> void:
	toast_label.text = format_input_text(message)
	toast_label.set_meta("_hint_source", message)
	toast_label.set_meta("_hint_rendered", toast_label.text)
	toast_time = 3.6
	toast_label.modulate.a = 1.0
	toast_label.visible = active_screen in ["play", "craft", "sushi", "mount_board", "map", "quests", "loadout"]
	_layout_toast()

func _layout_toast() -> void:
	if not is_instance_valid(toast_label):
		return
	var safe := _safe_area_rect()
	var max_toast_w := safe.size.x - (240.0 if (_touch_layout and _is_short and not _is_portrait) else 24.0)
	var width := minf(680.0, maxf(160.0, max_toast_w))
	var left := safe.position.x + (safe.size.x - width) * 0.5
	var top := safe.position.y + (76.0 if (_touch_layout and _is_short) else 134.0)
	if is_instance_valid(status_value) and (status_value.is_visible_in_tree() or (instruments.visible and status_value.visible)):
		var st_rect := status_value.get_global_rect()
		if left < st_rect.end.x and left + width > st_rect.position.x:
			top = maxf(top, st_rect.end.y + 10.0)
	if is_instance_valid(depth_value) and (depth_value.is_visible_in_tree() or (instruments.visible and depth_value.visible)):
		var dp_rect := depth_value.get_global_rect()
		if left < dp_rect.end.x and left + width > dp_rect.position.x:
			top = maxf(top, dp_rect.end.y + 8.0)
	if is_instance_valid(boss_panel) and (boss_panel.is_visible_in_tree() or (instruments.visible and boss_panel.visible)):
		var boss_rect := boss_panel.get_global_rect()
		if left < boss_rect.end.x and left + width > boss_rect.position.x:
			top = maxf(top, boss_rect.end.y + 10.0)
	if is_instance_valid(quest_banner_panel) and (quest_banner_panel.is_visible_in_tree() or (instruments.visible and quest_banner_panel.visible)):
		var qb_rect := quest_banner_panel.get_global_rect()
		if left < qb_rect.end.x and left + width > qb_rect.position.x:
			top = maxf(top, qb_rect.end.y + 8.0)
	if _is_portrait and is_instance_valid(minimap_radar) and (minimap_radar.is_visible_in_tree() or (instruments.visible and minimap_radar.visible)):
		var rd_rect := minimap_radar.get_global_rect()
		if left < rd_rect.end.x and left + width > rd_rect.position.x:
			top = maxf(top, rd_rect.end.y + 8.0)
	if _is_portrait and is_instance_valid(_compact_pin_label) and (_compact_pin_label.is_visible_in_tree() or (instruments.visible and _compact_pin_label.visible)):
		var pin_rect := _compact_pin_label.get_global_rect()
		if left < pin_rect.end.x and left + width > pin_rect.position.x:
			top = maxf(top, pin_rect.end.y + 8.0)
	# Allow long discoveries to wrap without crossing the depth or boss readouts.
	var height := 66.0 if toast_label.text.length() > int(width / 17.0) else 44.0
	if is_instance_valid(onboarding_panel) and (onboarding_panel.is_visible_in_tree() or (instruments.visible and onboarding_panel.visible)):
		var ob_rect := onboarding_panel.get_global_rect()
		if left < ob_rect.end.x and left + width > ob_rect.position.x and top < ob_rect.end.y and top + height > ob_rect.position.y:
			top = maxf(top, ob_rect.end.y + 8.0)
	if is_instance_valid(instruments) and instruments.has_node("LifeSupportInstrument"):
		var life_ctrl: Control = instruments.get_node("LifeSupportInstrument")
		if life_ctrl.is_visible_in_tree() or (instruments.visible and life_ctrl.visible):
			var lf_rect := life_ctrl.get_global_rect()
			if lf_rect.position.y < safe.position.y + safe.size.y * 0.48 and left < lf_rect.end.x and left + width > lf_rect.position.x and top < lf_rect.end.y and top + height > lf_rect.position.y:
				top = maxf(top, lf_rect.end.y + 8.0)
	top = minf(top, maxf(safe.position.y + 8.0, safe.end.y - height - 8.0))
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
	return str({"forward": "W", "backward": "S", "left": "A", "right": "D", "ascend": "空格", "descend": "Ctrl", "attack": "R", "aim": "T", "scope": "Y", "interact": "E", "craft_menu": "Tab", "pause_game": "Esc", "world_map": "M", "sonar_ping": "N", "mount_board": "O", "toggle_shield": "C", "dash": "Q", "booster": "H", "lamp": "F", "sprint": "Shift", "recall_pets": "Z", "mount_toggle": "G", "salvage_drone": "V", "sushi_menu": "B", "character_switch": "P", "character_angle": "K", "char_angle_reset": "Home", "weapon_1": "1", "weapon_2": "2", "weapon_3": "3", "weapon_4": "4", "weapon_cycle": "1-4", "quick_menu": "快捷操作", "gameplay_guide": "L", "quest_log": "U", "weapon_art": "X", "tactical_skill": "I", "ultimate_skill": "~", "loadout_menu": "F2"}.get(action, action))

func _join_hints(first_action: String, second_action: String, separator := "/") -> String:
	var first := get_input_hint(first_action)
	var second := get_input_hint(second_action)
	return first if first == second else first + separator + second

func format_input_text(text: String) -> String:
	if not is_instance_valid(input_controller) or str(input_controller.active_device) == "keyboard":
		return text
	if text == "A B Y S S A L   E C H O":
		return text
	var is_touch_dev := str(input_controller.active_device) == "touch"
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
			"1—4": get_input_hint("weapon_cycle"),
			"按住鼠标右键": "在右侧滑屏" if is_touch_dev else "推动右摇杆",
			"鼠标右键": "右侧滑屏" if is_touch_dev else "右摇杆",
			"方向键": "点按" if is_touch_dev else "十字键",
			"Home": get_input_hint("char_angle_reset"),
			"Shift": get_input_hint("sprint"),
			"Ctrl": get_input_hint("descend"), "空格": get_input_hint("ascend"),
			"按 1": "使用 " + get_input_hint("weapon_1"),
			"按 2": "使用 " + get_input_hint("weapon_2"),
			"按 3": "使用 " + get_input_hint("weapon_3"),
			"按 4": "使用 " + get_input_hint("weapon_4"),
			"4": get_input_hint("weapon_4"),
			"Tab": get_input_hint("craft_menu"),
			"Esc": get_input_hint("pause_game"), "F2": get_input_hint("loadout_menu"), "F1": get_input_hint("gameplay_guide"), "R": get_input_hint("attack"), "T": get_input_hint("aim"),
			"Y": get_input_hint("scope"), "C": get_input_hint("toggle_shield"), "E": get_input_hint("interact"),
			"M": get_input_hint("world_map"), "N": get_input_hint("sonar_ping"), "O": get_input_hint("mount_board"),
			"G": get_input_hint("mount_toggle"), "Z": get_input_hint("recall_pets"), "V": get_input_hint("salvage_drone"),
			"H": get_input_hint("booster"), "Q": get_input_hint("dash"), "F": get_input_hint("lamp"), "B": get_input_hint("sushi_menu"), "P": get_input_hint("character_switch"), "K": get_input_hint("character_angle"), "L": get_input_hint("gameplay_guide"), "U": get_input_hint("quest_log"),
			"X": get_input_hint("weapon_art"), "I": get_input_hint("tactical_skill"), "~": get_input_hint("ultimate_skill")
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
	var out := result + text.substr(cursor)
	return _polish_touch_hint_phrasing(out) if is_touch_dev else out

func _polish_touch_hint_phrasing(rendered: String) -> String:
	var s := rendered
	var seen := {}
	for k in _hint_cache:
		var h := str(_hint_cache[k]).strip_edges()
		if h.is_empty() or h.begins_with("使用 ") or h in ["右侧滑屏", "在右侧滑屏", "点按"]:
			continue
		seen[h] = true
	for act_key: String in ["weapon_1", "weapon_2", "weapon_3", "weapon_4"]:
		var wh := get_input_hint(act_key).strip_edges()
		if not wh.is_empty():
			seen[wh] = true
	for h: String in seen.keys():
		if h == "左摇杆":
			s = s.replace("使用 左摇杆", "推动左摇杆")
			s = s.replace("推动 左摇杆", "推动左摇杆")
			s = s.replace("按 左摇杆", "推动左摇杆")
			continue
		s = s.replace("再按一下 %s 键" % h, "点按「%s」" % h)
		s = s.replace("按一下 %s 键" % h, "点按「%s」" % h)
		s = s.replace("%s 键" % h, "「%s」按钮" % h)
		s = s.replace("按住 %s" % h, "长按「%s」" % h)
		s = s.replace("短按 %s" % h, "轻点「%s」" % h)
		s = s.replace("再按 %s" % h, "再次点按「%s」" % h)
		s = s.replace("按 %s" % h, "点按「%s」" % h)
		s = s.replace("使用 %s" % h, "切换「%s」" % h)
		s = s.replace("[%s] %s" % [h, h], "点按「%s」" % h)
		s = s.replace("[%s]" % h, "「%s」" % h)
	s = s.replace("推动左摇杆 ", "推动左摇杆")
	s = s.replace("点按「交互」 交互", "点按「交互」")
	s = s.replace("点按「上浮」 上浮", "点按「上浮」")
	s = s.replace("点按「下潜」 下潜", "点按「下潜」")
	s = s.replace("、下潜 下潜", "、「下潜」")
	s = s.replace("交互 交互", "点按「交互」")
	s = s.replace("攻击 攻击", "点按「攻击」")
	s = s.replace("上浮 上浮", "「上浮」")
	s = s.replace("下潜 下潜", "「下潜」")
	s = s.replace("」 ", "」")
	return s

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
			description = "操作海图 / 单指平移 · 双指缩放 · 点击选点 / 长按设标"
		elif device == "gamepad":
			description = "操作海图 / 左杆平移 · 十字键选点 · X/□ 操作栏"
		map_focus_button.text = description
		map_focus_button.set_meta("_hint_source", description)
	if _quick_ui.has("desc") and is_instance_valid(_quick_ui["desc"]):
		var q_desc: Label = _quick_ui["desc"]
		if device == "touch":
			q_desc.text = "点按按钮立即触发装备或能力 · 点按空白处返回潜航"
		elif device == "gamepad":
			q_desc.text = "方向键或摇杆选择 · 确认执行 · 返回继续潜航"
		else:
			q_desc.text = "方向键选择 · 确认执行 · 返回继续潜航"
	if is_instance_valid(minimap_radar):
		minimap_radar.map_hint = get_input_hint("world_map")
	var guide_changed := false
	var quest_changed := false
	var loadout_changed := false
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
			if menus.has("guide") and menus["guide"].is_ancestor_of(node):
				guide_changed = true
			if menus.has("quests") and menus["quests"].is_ancestor_of(node):
				quest_changed = true
			if menus.has("loadout") and menus["loadout"].is_ancestor_of(node):
				loadout_changed = true
	if guide_changed and not guide_view.is_empty():
		GuidePanel.refresh_layout(guide_view)
	if quest_changed and not quest_view.is_empty():
		QuestPanel.refresh_layout(quest_view)
	if loadout_changed and not loadout_view.is_empty():
		LoadoutPanel.refresh_layout(loadout_view)

func _sync_input_settings() -> void:
	if settings_controls.is_empty():
		return
	var values: Dictionary = {
		"gamepad_sensitivity": 1.0,
		"touch_sensitivity": 1.0,
		"deadzone": 0.2,
		"touch_scale": 1.0,
		"touch_opacity": 0.75,
		"invert_y": false,
		"touch_mode": "auto",
		"graphics_quality": "auto",
	}
	if is_instance_valid(input_controller):
		values.merge(input_controller.settings, true)
	_sync_settings_controls(values)

func _sync_settings_controls(values: Dictionary) -> void:
	if settings_controls.is_empty():
		return
	_settings_syncing = true
	for key: String in settings_controls:
		var control: Control = settings_controls[key]
		if control is HSlider:
			control.set_value_no_signal(float(values.get(key, 1.0)))
			(control.get_meta("value_label") as Label).text = "%.2f" % control.value
		elif control is CheckButton:
			control.set_pressed_no_signal(bool(values.get(key, false)))
		elif control is OptionButton:
			if key == "graphics_quality":
				control.select(maxi(0, GRAPHICS_QUALITY_VALUES.find(str(values.get(key, "auto")))))
			else:
				control.select(maxi(0, ["auto", "on", "off"].find(str(values.get(key, "auto")))))
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
	if is_instance_valid(input_controller) and str(input_controller.active_device) == "touch":
		if is_instance_valid(focused) and focused not in controls:
			focused.release_focus()
		return
	if focused not in controls:
		var remembered = _focus_memory.get(active_screen)
		if is_instance_valid(remembered) and remembered in controls:
			remembered.grab_focus()
		elif active_screen == "map":
			sea_chart.grab_focus()
		else:
			controls[0].grab_focus()

func _prepare_menu_scrolling() -> void:
	menu_min_sizes = {"main": Vector2(860, 740), "pause": Vector2(532, 568), "craft": Vector2(932, 732), "sushi": Vector2(1032, 748), "mount_board": Vector2(972, 732), "map": Vector2(1092, 760), "win": Vector2(712, 512), "quick": Vector2(892, 748), "controls": Vector2(732, 672), "guide": Vector2(992, 732), "quests": Vector2(992, 732), "loadout": Vector2(960, 700)}
	for key: String in menus:
		var menu: Control = menus[key]
		var children := menu.get_children()
		var scroll := ScrollContainer.new()
		menu.add_child(scroll)
		scroll.name = "AccessibleScroll"
		scroll.follow_focus = true
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
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
		if key == "main":
			content.gui_input.connect(func(event: InputEvent) -> void: _handle_main_stage_input(event, content))
		elif key in MODAL_MENU_KEYS:
			var modal_key := key
			menu.gui_input.connect(func(event: InputEvent) -> void: _handle_modal_backdrop_input(modal_key, menu, event))
		menu_scrolls[key] = scroll
		menu_contents[key] = content

func _safe_area_rect() -> Rect2:
	var vp := get_viewport()
	var size := root.size if (is_instance_valid(root) and root.size.x > 0.0 and root.size.y > 0.0) else (vp.get_visible_rect().size if vp != null else Vector2(1280.0, 800.0))
	var bounds := Rect2(Vector2.ZERO, size)
	var safe := SafeArea.get_safe_rect(vp)
	if vp != null and not vp.get_visible_rect().size.is_equal_approx(size):
		var insets: Dictionary = SafeArea.get_insets(vp)
		var l := float(insets.get("left", 0.0))
		var r := float(insets.get("right", 0.0))
		var t := float(insets.get("top", 0.0))
		var b := float(insets.get("bottom", 0.0))
		safe = Rect2(Vector2(l, t), Vector2(maxf(160.0, size.x - l - r), maxf(160.0, size.y - t - b)))
	return bounds.intersection(safe)

func get_layout_safe_rect() -> Rect2:
	return _safe_area_rect()

func set_touch_margins(margins: Dictionary) -> void:
	_touch_margins = margins.duplicate(true)
	var vp := get_viewport()
	_touch_margins_vp_size = vp.get_visible_rect().size if vp != null else (root.size if is_instance_valid(root) else Vector2.ZERO)
	if is_instance_valid(root) and not menu_scrolls.is_empty():
		_apply_layout()

static func _est_land_m(u: float, shrink: float = 1.0) -> Dictionary:
	var atk_d := clampf(80.0 * u, 66.0, 92.0) * shrink
	var sec_d := clampf(50.0 * u, 45.0, 58.0) * shrink
	var joy_box := clampf(156.0 * u, 124.0, 174.0) * shrink
	return {
		"pad": clampf(14.0 * u, 8.0, 18.0) * shrink,
		"gap": clampf(8.0 * u, 6.0, 10.0) * shrink,
		"joy_box": joy_box,
		"atk_d": atk_d,
		"sec_d": sec_d,
		"top_d": clampf(47.0 * u, 44.0, 54.0) * shrink,
		"qs_d": clampf(46.0 * u, 44.0, 52.0) * shrink,
		"center_min_w": 196.0 * shrink,
	}

static func _est_land_bounds(m: Dictionary) -> Vector2:
	var pad: float = m["pad"]
	var gap: float = m["gap"]
	var qs_span := maxf(4.0 * float(m["qs_d"]) + 3.0 * gap, float(m["center_min_w"]))
	var right_w := float(m["atk_d"]) + gap + float(m["sec_d"])
	var bottom_w: float = 2.0 * pad + float(m["joy_box"]) + gap + qs_span + gap + right_w
	var top_w: float = 2.0 * pad + 3.0 * float(m["top_d"]) + 2.0 * gap
	var left_h: float = 2.0 * pad + float(m["top_d"]) + gap + float(m["sec_d"]) + gap + float(m["joy_box"])
	var r1_h: float = 2.0 * pad + float(m["top_d"]) + gap + 2.0 * float(m["sec_d"]) + 2.0 * gap + float(m["atk_d"])
	var r2_h: float = 2.0 * pad + float(m["top_d"]) + gap + 3.0 * float(m["sec_d"]) + 2.0 * gap
	return Vector2(maxf(bottom_w, top_w), maxf(left_h, maxf(r1_h, r2_h)))

static func _est_port_m(u: float, shrink: float = 1.0) -> Dictionary:
	var atk_d := clampf(72.0 * u, 64.0, 84.0) * shrink
	var sec_d := clampf(46.0 * u, 44.0, 54.0) * shrink
	var joy_box := clampf(130.0 * u, 118.0, 150.0) * shrink
	return {
		"pad": clampf(9.0 * u, 8.0, 11.0) * shrink,
		"gap": clampf(7.0 * u, 6.0, 9.0) * shrink,
		"row_gap": clampf(8.0 * u, 6.0, 11.0) * shrink,
		"joy_box": joy_box,
		"atk_d": atk_d,
		"sec_d": sec_d,
		"top_d": clampf(46.0 * u, 44.0, 52.0) * shrink,
		"qs_d": clampf(45.0 * u, 44.0, 50.0) * shrink,
		"look_band": 96.0 * shrink,
	}

static func _est_port_bounds(m: Dictionary) -> Vector2:
	var pad: float = m["pad"]
	var gap: float = m["gap"]
	var bottom_w: float = 2.0 * pad + float(m["joy_box"]) + gap + float(m["sec_d"]) + gap + float(m["atk_d"])
	var qs_w: float = 2.0 * pad + 4.0 * float(m["qs_d"]) + 3.0 * gap
	var top_w: float = 2.0 * pad + 3.0 * float(m["top_d"]) + 2.0 * gap
	var l_h: float = float(m["joy_box"]) + gap + float(m["sec_d"])
	var r1_h: float = float(m["atk_d"]) + 2.0 * gap + 2.0 * float(m["sec_d"])
	var r2_h: float = 3.0 * float(m["sec_d"]) + 2.0 * gap
	var cluster_h := maxf(l_h, maxf(r1_h, r2_h))
	var total_h: float = 2.0 * pad + float(m["top_d"]) + gap + float(m["look_band"]) + float(m["qs_d"]) + float(m["row_gap"]) + cluster_h
	return Vector2(maxf(bottom_w, maxf(qs_w, top_w)), total_h)

func _compute_touch_envelopes(safe: Rect2) -> Dictionary:
	var touch_scale := 1.0
	if is_instance_valid(input_controller):
		touch_scale = clampf(float(input_controller.settings.get("touch_scale", 1.0)), 0.70, 1.50)
	var is_land := safe.size.x >= safe.size.y
	var env := {}
	if is_land:
		var base_u := clampf(minf(safe.size.x / 1280.0, safe.size.y / 800.0), 0.64, 1.20)
		var u := base_u * touch_scale
		var eff_u := u
		var m := _est_land_m(u)
		var b := _est_land_bounds(m)
		if b.x > safe.size.x - 0.5 or b.y > safe.size.y - 0.5:
			var m0 := _est_land_m(0.0)
			var b0 := _est_land_bounds(m0)
			if b0.x <= safe.size.x - 0.5 and b0.y <= safe.size.y - 0.5:
				var lo := 0.0
				var hi := u
				for _i in range(16):
					var mid := (lo + hi) * 0.5
					var bm := _est_land_bounds(_est_land_m(mid))
					if bm.x <= safe.size.x - 0.5 and bm.y <= safe.size.y - 0.5:
						lo = mid
					else:
						hi = mid
				eff_u = lo
				m = _est_land_m(lo)
			else:
				var shrink := clampf(minf((safe.size.x - 1.0) / maxf(b0.x, 1.0), (safe.size.y - 1.0) / maxf(b0.y, 1.0)), 0.25, 1.0)
				eff_u = 0.5 * shrink
				m = _est_land_m(0.0, shrink)
		var pad: float = m["pad"]
		var gap: float = m["gap"]
		var top_d: float = m["top_d"]
		var joy_box: float = m["joy_box"]
		var atk_d: float = m["atk_d"]
		var sec_d: float = m["sec_d"]
		var qs_d: float = m["qs_d"]
		var qs_total_w := 4.0 * qs_d + 3.0 * gap
		var center_min_w := maxf(qs_total_w, float(m["center_min_w"]))
		var right_w := atk_d + gap + sec_d
		var min_right_x := maxf(pad + joy_box + gap + center_min_w + gap, safe.size.x * 0.5 + 88.0)
		var atk_inset_x := clampf(16.0 * eff_u, 0.0, minf(22.0, maxf(0.0, (safe.size.x - pad - right_w) - min_right_x)))
		var right_needed_h := maxf(atk_d + 2.0 * gap + 2.0 * sec_d, 3.0 * sec_d + 2.0 * gap)
		var max_inset_y := maxf(0.0, (safe.size.y - pad - right_needed_h) - maxf(pad + top_d + gap + 6.0, 148.0))
		var atk_inset_y := clampf(12.0 * eff_u, 0.0, minf(18.0, max_inset_y))
		var r1_top := safe.size.y - pad - atk_inset_y - atk_d - 2.0 * gap - 2.0 * sec_d
		var r2_top := safe.size.y - pad - atk_inset_y - 3.0 * sec_d - 2.0 * gap
		env = {
			"top_pad": pad,
			"top_h": top_d,
			"gap": gap,
			"top_bar_bottom": pad + top_d,
			"top_left_right": pad + top_d,
			"top_right_left": safe.size.x - pad - 2.0 * top_d - gap,
			"quick_slots_top": safe.size.y - pad - qs_d,
			"left_cluster_top": safe.size.y - pad - joy_box - gap - sec_d,
			"right_cluster_top": minf(r1_top, r2_top),
			"joy_right": pad + joy_box,
			"right_cluster_left": safe.size.x - pad - atk_inset_x - right_w,
		}
	else:
		var base_u := clampf(minf(safe.size.x / 390.0, safe.size.y / 760.0), 0.72, 1.25)
		var u := base_u * touch_scale
		var m := _est_port_m(u)
		var b := _est_port_bounds(m)
		if b.x > safe.size.x - 0.5 or b.y > safe.size.y - 0.5:
			var m0 := _est_port_m(0.0)
			var b0 := _est_port_bounds(m0)
			if b0.x <= safe.size.x - 0.5 and b0.y <= safe.size.y - 0.5:
				var lo := 0.0
				var hi := u
				for _i in range(16):
					var mid := (lo + hi) * 0.5
					var bm := _est_port_bounds(_est_port_m(mid))
					if bm.x <= safe.size.x - 0.5 and bm.y <= safe.size.y - 0.5:
						lo = mid
					else:
						hi = mid
				m = _est_port_m(lo)
			else:
				var shrink := clampf(minf((safe.size.x - 1.0) / maxf(b0.x, 1.0), (safe.size.y - 1.0) / maxf(b0.y, 1.0)), 0.25, 1.0)
				m = _est_port_m(0.0, shrink)
		var pad: float = m["pad"]
		var gap: float = m["gap"]
		var row_gap: float = m["row_gap"]
		var top_d: float = m["top_d"]
		var joy_box: float = m["joy_box"]
		var atk_d: float = m["atk_d"]
		var sec_d: float = m["sec_d"]
		var qs_d: float = m["qs_d"]
		var l_top := safe.size.y - pad - joy_box - gap - sec_d
		var r1_top := safe.size.y - pad - atk_d - 2.0 * gap - 2.0 * sec_d
		var r2_top := safe.size.y - pad - 3.0 * sec_d - 2.0 * gap
		var cluster_top := minf(l_top, minf(r1_top, r2_top))
		env = {
			"top_pad": pad,
			"top_h": top_d,
			"gap": gap,
			"top_bar_bottom": pad + top_d,
			"top_left_right": pad + top_d,
			"top_right_left": safe.size.x - pad - 2.0 * top_d - gap,
			"quick_slots_top": cluster_top - row_gap - qs_d,
			"left_cluster_top": l_top,
			"right_cluster_top": minf(r1_top, r2_top),
			"joy_right": pad + joy_box,
			"right_cluster_left": safe.size.x - pad - atk_d - gap - sec_d,
		}
	if not _touch_margins.is_empty():
		var vp := get_viewport()
		var cur_vp := vp.get_visible_rect().size if vp != null else root.size
		var m_scale := float(_touch_margins.get("touch_scale", touch_scale))
		if cur_vp.distance_to(_touch_margins_vp_size) <= 2.0 and absf(m_scale - touch_scale) <= 0.02:
			if _touch_margins.has("top_bar_bottom"):
				env["top_bar_bottom"] = maxf(float(env["top_bar_bottom"]), float(_touch_margins["top_bar_bottom"]) - safe.position.y)
			if _touch_margins.has("quick_slots_top"):
				env["quick_slots_top"] = minf(float(env["quick_slots_top"]), float(_touch_margins["quick_slots_top"]) - safe.position.y)
			if _touch_margins.has("left_cluster_top"):
				env["left_cluster_top"] = minf(float(env["left_cluster_top"]), float(_touch_margins["left_cluster_top"]) - safe.position.y)
			if _touch_margins.has("right_cluster_top"):
				env["right_cluster_top"] = minf(float(env["right_cluster_top"]), float(_touch_margins["right_cluster_top"]) - safe.position.y)
			var jr = _touch_margins.get("joystick_rect")
			if jr is Rect2 and jr.size.x > 0.0:
				env["joy_right"] = maxf(float(env["joy_right"]), jr.end.x - safe.position.x)
			var rr = _touch_margins.get("right_cluster_rect")
			if rr is Rect2 and rr.size.x > 0.0:
				env["right_cluster_left"] = minf(float(env["right_cluster_left"]), rr.position.x - safe.position.x)
	return env

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
	var safe := _safe_area_rect()
	_last_safe_rect = safe
	_set_control_rect(instruments, safe)
	if is_instance_valid(_main_shade_material):
		_main_shade_material.set_shader_parameter("aspect", safe.size.x / maxf(safe.size.y, 1.0))
	_touch_layout = false
	if is_instance_valid(input_controller):
		var mode := str(input_controller.settings.get("touch_mode", "auto"))
		var active_dev := str(input_controller.active_device)
		var default_touch := SafeArea.is_default_touch_platform()
		_touch_layout = mode == "on" or (mode == "auto" and (active_dev == "touch" or (default_touch and active_dev != "gamepad")))
	elif SafeArea.is_default_touch_platform():
		_touch_layout = true

	var is_narrow := safe.size.x < 780.0
	var is_short := safe.size.y < 560.0
	var is_portrait := safe.size.x < safe.size.y
	var compact := is_narrow or is_short or _touch_layout
	_is_narrow = is_narrow
	_is_short = is_short
	_is_portrait = is_portrait
	_is_compact = compact

	var frame := Rect2(safe.position + Vector2(8.0, 8.0), Vector2(maxf(160.0, safe.size.x - 16.0), maxf(160.0, safe.size.y - 16.0)))
	_layout_menus(frame, safe.size)

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

	status_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	depth_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	health_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	depth_value.add_theme_font_size_override("font_size", 28)
	if is_instance_valid(_life_o2_label):
		_life_o2_label.add_theme_font_size_override("font_size", 23)
	if is_instance_valid(oxygen_value):
		oxygen_value.add_theme_font_size_override("font_size", 30)
	if is_instance_valid(oxygen_unit):
		oxygen_unit.visible = true
	if is_instance_valid(_life_caption_label):
		_life_caption_label.visible = true
	if is_instance_valid(minimap_radar):
		minimap_radar.mouse_filter = Control.MOUSE_FILTER_STOP if _touch_layout else Control.MOUSE_FILTER_IGNORE
		minimap_radar.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _touch_layout else Control.CURSOR_ARROW
		_set_control_rect(minimap_radar, Rect2(-172.0, 24.0, 148.0, 148.0), Vector2(1.0, 0.0))
	if is_instance_valid(scope_exit_btn):
		_sync_scope_exit_btn_appearance()
		if _touch_layout:
			_set_control_rect(scope_exit_btn, Rect2(-60.0, 20.0, 46.0, 46.0), Vector2(1.0, 0.0))
		else:
			_set_control_rect(scope_exit_btn, Rect2(-124.0, 20.0, 112.0, 44.0), Vector2(1.0, 0.0))
	if is_instance_valid(_journal_bar):
		_journal_bar.visible = not _touch_layout
	if is_instance_valid(_journal_heading):
		_journal_heading.visible = not _touch_layout
	if is_instance_valid(_aim_frame_label):
		_set_control_rect(_aim_frame_label, Rect2(12.0, 8.0, 250.0, 22.0))

	if compact:
		_apply_compact_hud_layout(safe, is_narrow, is_short, is_portrait)
	else:
		var boss_w := minf(520.0, maxf(220.0, safe.size.x - 360.0))
		_set_control_rect(boss_panel, Rect2(-boss_w * 0.5, 132.0, boss_w, 74.0), Vector2(0.5, 0.0))
		_set_control_rect(boss_name, Rect2(16.0, 6.0, boss_w - 32.0, 22.0))
		_set_control_rect(boss_bar, Rect2(16.0, 30.0, boss_w - 32.0, 5.0))
		if is_instance_valid(boss_poise_bar):
			_set_control_rect(boss_poise_bar, Rect2(16.0, 37.0, boss_w - 32.0, 3.0))
		_set_control_rect(boss_warning, Rect2(16.0, 44.0, boss_w - 32.0, 24.0))
		if is_instance_valid(combat_strip):
			var cs_w := minf(520.0, maxf(360.0, safe.size.x - 160.0))
			_set_control_rect(combat_strip, Rect2(-cs_w * 0.5, -148.0, cs_w, 28.0), Vector2(0.5, 1.0))
			_layout_combat_strip_contents(cs_w, 28.0)
			_sync_desktop_bottom_offsets()

	_layout_onboarding()
	_apply_touch_visibility()
	_layout_quest_banner()
	_layout_toast()
	_refresh_navigation.call_deferred()

func _apply_compact_hud_layout(safe: Rect2, _is_narrow: bool, is_short: bool, is_portrait: bool) -> void:
	var env := _compute_touch_envelopes(safe)
	var top_bar_bot: float = float(env["top_bar_bottom"]) if _touch_layout else 8.0
	var qs_top: float = float(env["quick_slots_top"]) if _touch_layout else (safe.size.y - 12.0)
	var left_cluster_top: float = float(env["left_cluster_top"]) if _touch_layout else (safe.size.y - 12.0)
	var right_cluster_top: float = float(env["right_cluster_top"]) if _touch_layout else (safe.size.y - 12.0)
	var life: Control = instruments.get_node("LifeSupportInstrument")
	var left_x := 12.0
	var left_w := 240.0
	var radar_sz := 92.0
	var radar_y := 18.0
	var bottom_hud_top := safe.size.y - 110.0

	if is_portrait:
		var y_start := (top_bar_bot + 6.0) if _touch_layout else 12.0
		radar_sz = (74.0 if safe.size.y < 620.0 else 80.0) if _touch_layout else (84.0 if safe.size.y < 620.0 else 92.0)
		radar_y = y_start
		if is_instance_valid(minimap_radar):
			_set_control_rect(minimap_radar, Rect2(-(radar_sz + 12.0), radar_y, radar_sz, radar_sz), Vector2(1.0, 0.0))
		if is_instance_valid(scope_exit_btn) and _touch_layout:
			_set_control_rect(scope_exit_btn, Rect2(-58.0, y_start, 46.0, 46.0), Vector2(1.0, 0.0))
		var right_top_w := 46.0 if (_scoped_active and _touch_layout) else radar_sz
		left_w = maxf(136.0, safe.size.x - right_top_w - 28.0)
		_set_control_rect(compass_strip, Rect2(left_x, y_start, left_w, 24.0))
		var cur_ly := y_start + 50.0
		if _touch_layout:
			depth_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			depth_value.add_theme_font_size_override("font_size", 16)
			if _low_oxygen_alert:
				_set_control_rect(depth_value, Rect2(left_x, y_start + 25.0, left_w, 20.0))
				_set_control_rect(status_value, Rect2(left_x, y_start + 46.0, left_w, 22.0))
				cur_ly = y_start + 69.0
			else:
				_set_control_rect(depth_value, Rect2(left_x, y_start + 25.0, 68.0, 22.0))
				_set_control_rect(status_value, Rect2(left_x + 72.0, y_start + 25.0, maxf(76.0, left_w - 72.0), 22.0))
				cur_ly = y_start + 48.0
		else:
			_set_control_rect(depth_value, Rect2(left_x, y_start + 26.0, left_w, 22.0))
			depth_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			depth_value.add_theme_font_size_override("font_size", 18)
		var show_jrnl := (not _touch_layout) and safe.size.y >= 680.0
		_journal_bar.visible = show_jrnl
		_journal_heading.visible = show_jrnl
		if show_jrnl:
			_set_control_rect(_journal_bar, Rect2(left_x, cur_ly + 3.0, 3.0, 16.0))
			_set_control_rect(_journal_heading, Rect2(left_x + 9.0, cur_ly, maxf(96.0, left_w - 9.0), 22.0))
			cur_ly += 22.0
		if not _touch_layout:
			_set_control_rect(status_value, Rect2(left_x, cur_ly, left_w, 22.0))
			cur_ly += 23.0
		status_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		status_value.clip_text = true
		_set_control_rect(mission_title, Rect2(left_x, cur_ly, left_w, 22.0))
		mission_title.clip_text = true
		_set_control_rect(target_value, Rect2(left_x, cur_ly + 22.0, left_w, 22.0))
		target_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		target_value.clip_text = true
		var left_bottom := cur_ly + 44.0
		if is_instance_valid(_compact_pin_label):
			var pin_w := clampf(radar_sz + 32.0, 108.0, 136.0) if _touch_layout else minf(safe.size.x - left_x - left_w - 20.0, radar_sz + 8.0)
			_set_control_rect(_compact_pin_label, Rect2(-(pin_w + 10.0), radar_y + radar_sz + 3.0, maxf(96.0, pin_w), 22.0), Vector2(1.0, 0.0))
		var life_h := 38.0 if _touch_layout else 42.0
		var life_w := minf(198.0 if _touch_layout else 260.0, maxf(172.0, safe.size.x - 24.0))
		var max_life_y := (qs_top - life_h - 6.0) if _touch_layout else (safe.size.y - life_h - 14.0)
		var min_life_y := y_start + (52.0 if _touch_layout else 76.0)
		var life_y := clampf(max_life_y, min_life_y, maxf(min_life_y, max_life_y)) if _touch_layout else clampf(maxf(left_bottom + 4.0, radar_y + radar_sz + 26.0), min_life_y, maxf(min_life_y, max_life_y))
		var life_x := (safe.size.x - life_w) * 0.5 if _touch_layout else 12.0
		_set_control_rect(life, Rect2(life_x, life_y, life_w, life_h))
		_layout_compact_life_contents(life_w)

		var band_top := (left_bottom + 4.0) if _touch_layout else (life_y + life_h + 4.0)
		var band_bot := (life_y - 4.0) if _touch_layout else (safe.size.y - 16.0)
		var center_w := minf(312.0, maxf(180.0, safe.size.x - 24.0))
		var wep_w := 148.0 if _touch_layout else center_w
		var wep_h := 28.0 if _touch_layout else 32.0
		var wep_top := clampf(band_bot - wep_h, band_top, maxf(band_top, safe.size.y - wep_h - 6.0))
		_set_control_rect(weapon_bar_label.get_parent(), Rect2(-wep_w * 0.5, wep_top, wep_w, wep_h), Vector2(0.5, 0.0))
		_set_control_rect(weapon_bar_label, Rect2(8.0, 3.0 if _touch_layout else 5.0, wep_w - 16.0, 22.0))
		weapon_bar_label.clip_text = true
		_set_control_rect(booster_indicator, Rect2(-center_w * 0.5, wep_top, center_w, wep_h), Vector2(0.5, 0.0))
		_set_control_rect(equipment_value, Rect2(-center_w * 0.5, wep_top + 34.0, center_w, 22.0), Vector2(0.5, 0.0))
		var sub_avail := maxf(52.0, band_bot - band_top)
		var sub_h := clampf(sub_avail, 52.0, 80.0)
		var sub_top := clampf(band_bot - sub_h, band_top, maxf(band_top, safe.size.y - sub_h - 6.0))
		_layout_compact_sub_panel(Rect2((safe.size.x - center_w) * 0.5, sub_top, center_w, sub_h))
		bottom_hud_top = minf(life_y, minf(wep_top, sub_top))

		var b_w := minf(340.0, maxf(180.0, safe.size.x - 24.0))
		var b_y := (maxf(left_bottom, radar_y + radar_sz) + 6.0) if _touch_layout else (life_y + life_h + 6.0)
		_set_control_rect(boss_panel, Rect2(-b_w * 0.5, b_y, b_w, 68.0), Vector2(0.5, 0.0))
		_set_control_rect(boss_name, Rect2(12.0, 5.0, b_w - 24.0, 20.0))
		_set_control_rect(boss_bar, Rect2(12.0, 27.0, b_w - 24.0, 4.0))
		if is_instance_valid(boss_poise_bar):
			_set_control_rect(boss_poise_bar, Rect2(12.0, 33.0, b_w - 24.0, 3.0))
		_set_control_rect(boss_warning, Rect2(12.0, 39.0, b_w - 24.0, 24.0))
		if is_instance_valid(combat_strip):
			if _touch_layout:
				var tcs_w := minf(192.0, life_w)
				var tcs_h := 16.0
				var tcs_y := maxf(band_top, life_y - tcs_h - 4.0)
				_set_control_rect(combat_strip, Rect2(-tcs_w * 0.5, tcs_y, tcs_w, tcs_h), Vector2(0.5, 0.0))
				_layout_combat_strip_contents(tcs_w, tcs_h)
			else:
				var dcs_w := minf(420.0, maxf(240.0, safe.size.x - 24.0))
				var dcs_h := 28.0
				var dcs_y := maxf(band_top, wep_top - dcs_h - 4.0)
				_set_control_rect(combat_strip, Rect2(-dcs_w * 0.5, dcs_y, dcs_w, dcs_h), Vector2(0.5, 0.0))
				_layout_combat_strip_contents(dcs_w, dcs_h)
	else:
		var sc_btn_w := 46.0 if _touch_layout else 98.0
		var sc_btn_x := safe.size.x - 120.0
		if _touch_layout and is_instance_valid(scope_exit_btn):
			var sc_btn_h := maxf(44.0, float(env["top_h"]))
			sc_btn_w = sc_btn_h
			sc_btn_x = maxf(float(env["top_left_right"]) + 8.0, float(env["top_right_left"]) - float(env["gap"]) - sc_btn_w)
			_set_control_rect(scope_exit_btn, Rect2(sc_btn_x, float(env["top_pad"]), sc_btn_w, sc_btn_h))
		var compass_y := maxf(8.0, float(env["top_pad"])) if _touch_layout else 10.0
		var compass_w := clampf(safe.size.x - 280.0, 140.0, 380.0)
		var compass_x := (safe.size.x - compass_w) * 0.5
		if _touch_layout:
			var c_left_lim := float(env["top_left_right"]) + 8.0
			var c_right_lim := (sc_btn_x - 8.0) if _scoped_active else (float(env["top_right_left"]) - 8.0)
			var avail_top_w := maxf(116.0, c_right_lim - c_left_lim)
			var half_sym := minf(safe.size.x * 0.5 - c_left_lim, c_right_lim - safe.size.x * 0.5)
			if half_sym * 2.0 >= 140.0:
				compass_w = clampf(half_sym * 2.0, 140.0, 360.0)
				compass_x = (safe.size.x - compass_w) * 0.5
			else:
				compass_w = clampf(avail_top_w, 116.0, 260.0)
				compass_x = clampf((safe.size.x - compass_w) * 0.5, c_left_lim, maxf(c_left_lim, c_right_lim - compass_w))
		_set_control_rect(compass_strip, Rect2(compass_x, compass_y, compass_w, 28.0))
		var depth_w := minf(168.0, compass_w)
		_set_control_rect(depth_value, Rect2(compass_x + (compass_w - depth_w) * 0.5, compass_y + 30.0, depth_w, 26.0))
		depth_value.add_theme_font_size_override("font_size", 20)

		radar_sz = (80.0 if is_short else 92.0) if _touch_layout else (92.0 if is_short else 108.0)
		radar_y = (top_bar_bot + 8.0) if _touch_layout else 18.0
		var radar_right_inset := 12.0
		if _touch_layout and radar_y + radar_sz > right_cluster_top - 6.0:
			var fit_sz := right_cluster_top - radar_y - 6.0
			if fit_sz >= 64.0:
				radar_sz = fit_sz
			else:
				radar_sz = 76.0
				radar_right_inset = maxf(12.0, safe.size.x - float(env["right_cluster_left"]) + 8.0)
		if is_instance_valid(minimap_radar):
			_set_control_rect(minimap_radar, Rect2(-(radar_sz + radar_right_inset), radar_y, radar_sz, radar_sz), Vector2(1.0, 0.0))

		left_w = minf(224.0 if _touch_layout else 310.0, maxf(144.0, safe.size.x * (0.29 if _touch_layout else 0.34)))
		var top_y := (top_bar_bot + 6.0) if _touch_layout else 14.0
		if _touch_layout and top_y + 46.0 > left_cluster_top - 4.0:
			left_x = float(env["joy_right"]) + 8.0
			top_y = maxf(top_y, compass_y + 58.0)
			left_w = clampf(safe.size.x - radar_right_inset - radar_sz - left_x - 12.0, 132.0, 236.0)
		var show_jrnl_l := not _touch_layout
		_journal_bar.visible = show_jrnl_l
		_journal_heading.visible = show_jrnl_l
		var cur_y_l := top_y
		if show_jrnl_l:
			_set_control_rect(_journal_bar, Rect2(left_x, cur_y_l + 3.0, 3.0, 16.0))
			_set_control_rect(_journal_heading, Rect2(left_x + 9.0, cur_y_l, maxf(96.0, left_w - 9.0), 22.0))
			cur_y_l += 22.0
		_set_control_rect(status_value, Rect2(left_x, cur_y_l, left_w, 22.0))
		status_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		status_value.clip_text = true
		_set_control_rect(mission_title, Rect2(left_x, cur_y_l + 23.0, left_w, 22.0))
		mission_title.clip_text = true
		_set_control_rect(target_value, Rect2(left_x, cur_y_l + 46.0, left_w, 22.0))
		target_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		target_value.clip_text = true

		if is_instance_valid(_compact_pin_label):
			var pin_w := (clampf(radar_sz + 36.0, 112.0, 142.0) if _touch_layout else clampf(radar_sz + 56.0, 132.0, 196.0))
			if not _touch_layout or radar_y + radar_sz + 28.0 <= right_cluster_top:
				_set_control_rect(_compact_pin_label, Rect2(-(pin_w + radar_right_inset), radar_y + radar_sz + 4.0, pin_w, 24.0), Vector2(1.0, 0.0))
			else:
				_set_control_rect(_compact_pin_label, Rect2(-(radar_sz + radar_right_inset + 6.0 + pin_w), radar_y, pin_w, 24.0), Vector2(1.0, 0.0))

		if safe.size.x >= 960.0 and safe.size.y >= 680.0 and _touch_layout and is_instance_valid(_cargo):
			var cargo_y := radar_y + radar_sz + (32.0 if (is_instance_valid(_compact_pin_label) and not _compact_pin_label.text.is_empty()) else 8.0)
			_set_control_rect(_cargo, Rect2(-264.0, cargo_y, 252.0, 114.0), Vector2(1.0, 0.0))

		if _touch_layout:
			var chan_left := float(env["joy_right"]) + 8.0
			var chan_right := float(env["right_cluster_left"]) - 8.0
			var chan_w := maxf(176.0, chan_right - chan_left)
			var chan_cx := (chan_left + chan_right) * 0.5
			var life_h := 38.0
			var life_w := clampf(chan_w - 8.0, 176.0, 206.0)
			var life_y := maxf(compass_y + 62.0, qs_top - life_h - 8.0)
			var life_x := clampf(chan_cx - life_w * 0.5, chan_left, maxf(chan_left, chan_right - life_w))
			_set_control_rect(life, Rect2(life_x, life_y, life_w, life_h))
			_layout_compact_life_contents(life_w)

			var center_w := clampf(chan_w - 4.0, 176.0, 340.0)
			var center_x := clampf(chan_cx - center_w * 0.5, chan_left, maxf(chan_left, chan_right - center_w))
			var wep_w_l := minf(152.0, center_w)
			var wep_x_l := clampf(chan_cx - wep_w_l * 0.5, chan_left, maxf(chan_left, chan_right - wep_w_l))
			var wep_y := maxf(compass_y + 58.0, life_y - 32.0)
			_set_control_rect(weapon_bar_label.get_parent(), Rect2(wep_x_l, wep_y, wep_w_l, 28.0))
			_set_control_rect(weapon_bar_label, Rect2(8.0, 3.0, wep_w_l - 16.0, 22.0))
			weapon_bar_label.clip_text = true
			_set_control_rect(booster_indicator, Rect2(center_x, wep_y, center_w, 32.0))
			_set_control_rect(equipment_value, Rect2(center_x, wep_y + 32.0, center_w, 22.0))
			var sub_h := 76.0 if is_short else 82.0
			var sub_y := maxf(compass_y + 58.0, life_y - sub_h - 6.0)
			_layout_compact_sub_panel(Rect2(center_x, sub_y, center_w, sub_h))
			bottom_hud_top = minf(life_y, minf(wep_y, sub_y))
			if is_instance_valid(combat_strip):
				var tcs_w_l := clampf(chan_w - 12.0, 120.0, 192.0)
				var tcs_h_l := 16.0
				var tcs_x_l := clampf(chan_cx - tcs_w_l * 0.5, chan_left, maxf(chan_left, chan_right - tcs_w_l))
				var tcs_y_l := maxf(compass_y + 56.0, life_y - tcs_h_l - 4.0)
				_set_control_rect(combat_strip, Rect2(tcs_x_l, tcs_y_l, tcs_w_l, tcs_h_l))
				_layout_combat_strip_contents(tcs_w_l, tcs_h_l)
		else:
			var center_w2 := minf(400.0, maxf(180.0, safe.size.x - 280.0))
			_set_control_rect(weapon_bar_label.get_parent(), Rect2(-center_w2 * 0.5, -110.0, center_w2, 36.0), Vector2(0.5, 1.0))
			_set_control_rect(weapon_bar_label, Rect2(10.0, 7.0, center_w2 - 20.0, 22.0))
			_set_control_rect(equipment_value, Rect2(-center_w2 * 0.5, -70.0, center_w2, 22.0), Vector2(0.5, 1.0))
			_set_control_rect(sub_panel, Rect2(-center_w2 * 0.5, -136.0, center_w2, 88.0), Vector2(0.5, 1.0))
			bottom_hud_top = safe.size.y - 136.0
			if is_instance_valid(combat_strip):
				var dcs_w2 := minf(460.0, maxf(280.0, safe.size.x - 120.0))
				_set_control_rect(combat_strip, Rect2(-dcs_w2 * 0.5, -142.0, dcs_w2, 28.0), Vector2(0.5, 1.0))
				_layout_combat_strip_contents(dcs_w2, 28.0)

		var boss_left_lim := left_x + left_w + 10.0
		var boss_right_lim := safe.size.x - radar_sz - radar_right_inset - 10.0
		var boss_gap := boss_right_lim - boss_left_lim
		if boss_gap >= 176.0:
			var b_w2 := minf(440.0, boss_gap)
			var b_x2 := boss_left_lim + (boss_gap - b_w2) * 0.5
			var b_y2 := maxf(depth_value.offset_bottom + 4.0, compass_y + 58.0)
			_set_control_rect(boss_panel, Rect2(b_x2, b_y2, b_w2, 68.0))
			_set_control_rect(boss_name, Rect2(10.0, 5.0, b_w2 - 20.0, 20.0))
			_set_control_rect(boss_bar, Rect2(10.0, 27.0, b_w2 - 20.0, 4.0))
			if is_instance_valid(boss_poise_bar):
				_set_control_rect(boss_poise_bar, Rect2(10.0, 33.0, b_w2 - 20.0, 3.0))
			_set_control_rect(boss_warning, Rect2(10.0, 39.0, b_w2 - 20.0, 24.0))
		else:
			var b_w3 := minf(320.0, maxf(180.0, safe.size.x - 24.0))
			var b_y3 := target_value.offset_bottom + 6.0
			_set_control_rect(boss_panel, Rect2(-b_w3 * 0.5, b_y3, b_w3, 68.0), Vector2(0.5, 0.0))
			_set_control_rect(boss_name, Rect2(10.0, 5.0, b_w3 - 20.0, 20.0))
			_set_control_rect(boss_bar, Rect2(10.0, 27.0, b_w3 - 20.0, 4.0))
			if is_instance_valid(boss_poise_bar):
				_set_control_rect(boss_poise_bar, Rect2(10.0, 33.0, b_w3 - 20.0, 3.0))
			_set_control_rect(boss_warning, Rect2(10.0, 39.0, b_w3 - 20.0, 24.0))
	boss_name.clip_text = true
	boss_warning.clip_text = true

	var sc_lbl_w := minf(360.0, maxf(160.0, safe.size.x - 32.0))
	var sc_lbl_y := (compass_strip.offset_bottom + 4.0) if is_portrait else (depth_value.offset_bottom + 4.0)
	_set_control_rect(scope_label, Rect2(-sc_lbl_w * 0.5, sc_lbl_y, sc_lbl_w, 24.0), Vector2(0.5, 0.0))

	var aim_w := clampf(safe.size.x * (0.52 if is_portrait else 0.34), 160.0, 280.0)
	var aim_h := clampf(safe.size.y * (0.22 if is_portrait else 0.32), 96.0, 180.0)
	_set_control_rect(aim_frame, Rect2(-aim_w * 0.5, -aim_h * 0.5, aim_w, aim_h), Vector2(0.5, 0.5))
	if is_instance_valid(_aim_frame_label):
		_set_control_rect(_aim_frame_label, Rect2(10.0, 6.0, aim_w - 20.0, 22.0))

	var chg_w := minf(260.0, maxf(160.0, safe.size.x - 32.0))
	var chg_bar_w := minf(156.0, chg_w - 24.0)
	var center_y := safe.size.y * 0.5
	var chg_off_y := -56.0 if (center_y + 56.0 > bottom_hud_top - 6.0) else 22.0
	_set_control_rect(charge_label, Rect2(-chg_w * 0.5, chg_off_y, chg_w, 24.0), Vector2(0.5, 0.5))
	_set_control_rect(charge_bar, Rect2(-chg_bar_w * 0.5, chg_off_y + 26.0, chg_bar_w, 3.0), Vector2(0.5, 0.5))

func _layout_compact_life_contents(life_w: float) -> void:
	_life_o2_label.add_theme_font_size_override("font_size", 15)
	oxygen_value.add_theme_font_size_override("font_size", 18)
	_set_control_rect(_life_o2_label, Rect2(8.0, 4.0, 28.0, 22.0))
	_set_control_rect(oxygen_value, Rect2(36.0, 2.0, 46.0, 24.0))
	oxygen_unit.visible = false
	_life_caption_label.visible = false
	_set_control_rect(health_value, Rect2(82.0, 4.0, maxf(72.0, life_w - 90.0), 22.0))
	health_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_set_control_rect(oxygen_bar, Rect2(8.0, 30.0 if _touch_layout else 33.0, maxf(80.0, life_w - 16.0), 4.0))

func _layout_compact_sub_panel(rect: Rect2) -> void:
	_set_control_rect(sub_panel, rect)
	var w := rect.size.x
	var h := rect.size.y
	var half_w := (w - 24.0) * 0.5
	if h < 68.0:
		_set_control_rect(sub_name_label, Rect2(8.0, 2.0, half_w, 22.0))
		_set_control_rect(sub_weapon_label, Rect2(8.0 + half_w + 4.0, 2.0, half_w, 22.0))
		sub_speed_label.visible = false
		_set_control_rect(sub_hull_bar, Rect2(8.0, 25.0, w - 16.0, 4.0))
		_set_control_rect(sub_hull_label, Rect2(8.0, maxf(29.0, h - 23.0), w - 16.0, 22.0))
	else:
		sub_speed_label.visible = true
		_set_control_rect(sub_name_label, Rect2(10.0, 3.0, w - 20.0, 22.0))
		_set_control_rect(sub_speed_label, Rect2(10.0, 24.0, half_w, 22.0))
		_set_control_rect(sub_weapon_label, Rect2(10.0 + half_w, 24.0, half_w, 22.0))
		_set_control_rect(sub_hull_bar, Rect2(10.0, 48.0, w - 20.0, 4.0))
		_set_control_rect(sub_hull_label, Rect2(10.0, 54.0, w - 20.0, 22.0))

func _layout_menus(frame: Rect2, safe_size: Vector2) -> void:
	for key: String in menu_scrolls:
		var scroll: ScrollContainer = menu_scrolls[key]
		_set_control_rect(scroll, frame)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.follow_focus = not _touch_layout

	var main_scroll: ScrollContainer = menu_scrolls["main"]
	main_scroll.follow_focus = not (_touch_layout or _is_compact)
	main_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_layout_main_menu(frame.size)
	menu_contents["main"].custom_minimum_size = frame.size
	menu_contents["main"].size = frame.size
	for child in menu_contents["main"].get_children():
		if child is OceanUiTheme.ExpeditionPlate:
			child.visible = frame.size.x >= 1050.0 and frame.size.y >= 640.0

	menu_scrolls["map"].vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	if _map_ui.has("side_scroll") and is_instance_valid(_map_ui["side_scroll"]):
		(_map_ui["side_scroll"] as ScrollContainer).follow_focus = not _touch_layout
	_layout_map_card(frame.size, safe_size)
	menu_contents["map"].custom_minimum_size = frame.size
	menu_contents["map"].size = frame.size

	menu_scrolls["guide"].vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	GuidePanel.set_touch_mode(guide_view, _touch_layout)
	GuidePanel.set_responsive_layout(guide_view, frame.size)
	menu_contents["guide"].custom_minimum_size = frame.size
	menu_contents["guide"].size = frame.size

	menu_scrolls["quests"].vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	QuestPanel.set_touch_mode(quest_view, _touch_layout)
	QuestPanel.set_responsive_layout(quest_view, frame.size)
	menu_contents["quests"].custom_minimum_size = frame.size
	menu_contents["quests"].size = frame.size

	menu_scrolls["loadout"].vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	LoadoutPanel.set_touch_mode(loadout_view, _touch_layout)
	LoadoutPanel.set_responsive_layout(loadout_view, frame.size)
	LoadoutPanel.refresh_layout(loadout_view)
	menu_contents["loadout"].custom_minimum_size = frame.size
	menu_contents["loadout"].size = frame.size

	_place_modal_card("pause", _pause_ui["card"], _layout_pause_card(frame.size), frame.size)
	_place_modal_card("craft", _craft_ui["card"], _layout_craft_card(frame.size), frame.size)
	_place_modal_card("sushi", _sushi_ui["card"], _layout_sushi_card(frame.size), frame.size)
	_place_modal_card("mount_board", _mount_ui["card"], _layout_mount_card(frame.size), frame.size)
	_place_modal_card("win", _win_ui["card"], _layout_win_card(frame.size), frame.size)
	_place_modal_card("quick", _quick_ui["card"], _layout_quick_card(frame.size), frame.size)
	_place_modal_card("controls", _controls_ui["card"], _layout_controls_card(frame.size), frame.size)

func _place_modal_card(key: String, card: Control, card_size: Vector2, avail: Vector2) -> void:
	var cx := maxf(0.0, floorf((avail.x - card_size.x) * 0.5))
	var cy := maxf(0.0, floorf((avail.y - card_size.y) * 0.5))
	_set_control_rect(card, Rect2(cx, cy, card_size.x, card_size.y))
	var content_h := maxf(avail.y, cy + card_size.y)
	var content: Control = menu_contents[key]
	content.custom_minimum_size = Vector2(avail.x, content_h)
	content.size = Vector2(avail.x, content_h)

func _layout_main_menu(avail: Vector2) -> void:
	var w := avail.x
	var h := avail.y
	var is_port := w < h
	var is_compact_land := (not is_port) and (h < 650.0 or w < 920.0)
	var eyebrow_line: Control = _main_ui["eyebrow_line"]
	var eyebrow_lbl: Label = _main_ui["eyebrow_lbl"]
	var title_lbl: Label = _main_ui["title_lbl"]
	var en_lbl: Label = _main_ui["en_lbl"]
	var mid_line: Control = _main_ui["mid_line"]
	var poetic_1: Label = _main_ui["poetic_1"]
	var poetic_2: Label = _main_ui["poetic_2"]
	var explore_btn: Button = _main_ui["explore_btn"]
	var survive_btn: Button = _main_ui["survive_btn"]
	var guide_btn: Button = _main_ui["guide_btn"]
	var controls_btn: Button = _main_ui["controls_btn"]
	var char_card: Panel = _main_ui["char_card"]
	var char_line_top: Control = _main_ui["char_line_top"]
	var char_eyebrow: Label = _main_ui["char_eyebrow"]
	var prev_btn: Button = _main_ui["prev_btn"]
	var next_btn: Button = _main_ui["next_btn"]
	var char_line_mid: Control = _main_ui["char_line_mid"]
	var char_line_bot: Control = _main_ui["char_line_bot"]
	var rot_left: Button = _main_ui["rot_left_btn"]
	var rot_reset: Button = _main_ui["rot_reset_btn"]
	var rot_right: Button = _main_ui["rot_right_btn"]
	var footer_left: Label = _main_ui["footer_left"]
	var footer_right: Label = _main_ui["footer_right"]
	prev_btn.custom_minimum_size = Vector2(0, 44)
	next_btn.custom_minimum_size = Vector2(0, 44)
	rot_left.custom_minimum_size = Vector2(0, 44)
	rot_reset.custom_minimum_size = Vector2(0, 44)
	rot_right.custom_minimum_size = Vector2(0, 44)

	if is_port:
		eyebrow_line.visible = false
		eyebrow_lbl.visible = h >= 620.0
		mid_line.visible = false
		poetic_1.visible = false
		poetic_2.visible = false
		footer_left.visible = false
		footer_right.visible = false
		var pad := 10.0
		var full_w := maxf(200.0, w - pad * 2.0)
		var top_y := 4.0
		if eyebrow_lbl.visible:
			_set_control_rect(eyebrow_lbl, Rect2(pad, top_y, full_w, 20.0))
			eyebrow_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			top_y += 20.0
		title_lbl.add_theme_font_size_override("font_size", 34)
		title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_set_control_rect(title_lbl, Rect2(pad, top_y, full_w, 42.0))
		en_lbl.add_theme_font_size_override("font_size", 14)
		en_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		en_lbl.visible = true
		_set_control_rect(en_lbl, Rect2(pad, top_y + 42.0, full_w, 20.0))

		explore_btn.text = "开始下潜 / 自由探险"
		survive_btn.text = "生存航程"
		guide_btn.text = "潜航指南"
		controls_btn.text = "操控设置"
		var half_w := floorf((full_w - 8.0) * 0.5)
		var bot_y := h - 46.0
		_set_control_rect(guide_btn, Rect2(pad, bot_y, half_w, 44.0))
		_set_control_rect(controls_btn, Rect2(pad + half_w + 8.0, bot_y, full_w - half_w - 8.0, 44.0))
		bot_y -= 50.0
		_set_control_rect(explore_btn, Rect2(pad, bot_y, half_w, 46.0))
		_set_control_rect(survive_btn, Rect2(pad + half_w + 8.0, bot_y, full_w - half_w - 8.0, 46.0))
		if _can_continue_voyage:
			if is_instance_valid(continue_summary_label) and not continue_summary_label.text.is_empty():
				continue_summary_label.visible = true
				bot_y -= 24.0
				_set_control_rect(continue_summary_label, Rect2(pad, bot_y, full_w, 22.0))
				continue_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			bot_y -= 50.0
			_set_control_rect(continue_voyage_btn, Rect2(pad, bot_y, full_w, 46.0))
		else:
			continue_summary_label.visible = false

		var card_h := 148.0
		_set_control_rect(char_card, Rect2(pad, maxf(top_y + 68.0, bot_y - card_h - 8.0), full_w, card_h))
		char_line_top.visible = false
		char_eyebrow.visible = false
		char_line_mid.visible = false
		char_line_bot.visible = false
		for cid: String in main_char_buttons:
			(main_char_buttons[cid] as Button).visible = false
		var cw := full_w - 20.0
		main_char_title.add_theme_font_size_override("font_size", 18)
		main_char_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_set_control_rect(main_char_title, Rect2(10.0, 6.0, cw, 24.0))
		main_char_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_set_control_rect(main_char_subtitle, Rect2(10.0, 30.0, cw, 20.0))
		var ch_half := floorf((cw - 8.0) * 0.5)
		_set_control_rect(prev_btn, Rect2(10.0, 54.0, ch_half, 44.0))
		_set_control_rect(next_btn, Rect2(10.0 + ch_half + 8.0, 54.0, cw - ch_half - 8.0, 44.0))
		var r_w := floorf((cw - 12.0) / 3.0)
		_set_control_rect(rot_left, Rect2(10.0, 102.0, r_w, 44.0))
		_set_control_rect(rot_reset, Rect2(10.0 + r_w + 6.0, 102.0, r_w, 44.0))
		_set_control_rect(rot_right, Rect2(10.0 + (r_w + 6.0) * 2.0, 102.0, cw - (r_w + 6.0) * 2.0, 44.0))
	elif is_compact_land:
		eyebrow_line.visible = false
		eyebrow_lbl.visible = false
		mid_line.visible = false
		poetic_1.visible = false
		poetic_2.visible = false
		footer_left.visible = false
		footer_right.visible = false
		var col_w := clampf(floorf(w * 0.36), 196.0, 268.0)
		var lx := 8.0
		var ly := 4.0
		title_lbl.add_theme_font_size_override("font_size", 28)
		title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_set_control_rect(title_lbl, Rect2(lx, ly, col_w, 34.0))
		ly += 34.0
		en_lbl.visible = h >= 336.0 or not _can_continue_voyage
		if en_lbl.visible:
			en_lbl.add_theme_font_size_override("font_size", 14)
			en_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			_set_control_rect(en_lbl, Rect2(lx, ly, col_w, 22.0))
			ly += 22.0
		if _can_continue_voyage:
			_set_control_rect(continue_voyage_btn, Rect2(lx, ly, col_w, 46.0))
			ly += 50.0
			if is_instance_valid(continue_summary_label) and not continue_summary_label.text.is_empty() and h >= 370.0:
				continue_summary_label.visible = true
				continue_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
				_set_control_rect(continue_summary_label, Rect2(lx, ly, col_w, 22.0))
				ly += 22.0
			else:
				continue_summary_label.visible = false
		else:
			continue_summary_label.visible = false
		explore_btn.text = "自由探险"
		survive_btn.text = "生存航程"
		guide_btn.text = "潜航指南"
		controls_btn.text = "操控设置"
		_set_control_rect(explore_btn, Rect2(lx, ly, col_w, 46.0))
		ly += 52.0
		_set_control_rect(survive_btn, Rect2(lx, ly, col_w, 44.0))
		ly += 50.0
		var sub_w := floorf((col_w - 6.0) * 0.5)
		_set_control_rect(guide_btn, Rect2(lx, ly, sub_w, 44.0))
		_set_control_rect(controls_btn, Rect2(lx + sub_w + 6.0, ly, col_w - sub_w - 6.0, 44.0))

		var rc_w := clampf(floorf(w * 0.36), 196.0, 268.0)
		var rc_h := minf(166.0, h - 12.0)
		_set_control_rect(char_card, Rect2(w - rc_w - 8.0, 6.0, rc_w, rc_h))
		char_line_top.visible = false
		char_eyebrow.visible = false
		char_line_mid.visible = false
		char_line_bot.visible = false
		for cid: String in main_char_buttons:
			(main_char_buttons[cid] as Button).visible = false
		var rc_in := rc_w - 16.0
		main_char_title.add_theme_font_size_override("font_size", 17)
		main_char_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_set_control_rect(main_char_title, Rect2(8.0, 6.0, rc_in, 24.0))
		main_char_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_set_control_rect(main_char_subtitle, Rect2(8.0, 30.0, rc_in, 20.0))
		var p_w := floorf((rc_in - 6.0) * 0.5)
		_set_control_rect(prev_btn, Rect2(8.0, 56.0, p_w, 44.0))
		_set_control_rect(next_btn, Rect2(8.0 + p_w + 6.0, 56.0, rc_in - p_w - 6.0, 44.0))
		var rt_w := floorf((rc_in - 12.0) / 3.0)
		_set_control_rect(rot_left, Rect2(8.0, 108.0, rt_w, 44.0))
		_set_control_rect(rot_reset, Rect2(8.0 + rt_w + 6.0, 108.0, rt_w, 44.0))
		_set_control_rect(rot_right, Rect2(8.0 + (rt_w + 6.0) * 2.0, 108.0, rc_in - (rt_w + 6.0) * 2.0, 44.0))
	else:
		var lx := 64.0 if w >= 1100.0 else 32.0
		var cta_w := minf(390.0, floorf(w * 0.38))
		eyebrow_line.visible = true
		eyebrow_lbl.visible = true
		eyebrow_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_set_control_rect(eyebrow_line, Rect2(lx, 46.0, 38.0, 2.0))
		_set_control_rect(eyebrow_lbl, Rect2(lx + 52.0, 34.0, 420.0, 28.0))
		title_lbl.add_theme_font_size_override("font_size", 72 if h >= 760.0 else 56)
		title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_set_control_rect(title_lbl, Rect2(lx - 6.0, 118.0 if h >= 760.0 else 84.0, 500.0, 92.0))
		en_lbl.visible = true
		en_lbl.add_theme_font_size_override("font_size", 18)
		en_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var en_y := 220.0 if h >= 760.0 else 178.0
		_set_control_rect(en_lbl, Rect2(lx + 4.0, en_y, 480.0, 30.0))
		mid_line.visible = true
		_set_control_rect(mid_line, Rect2(lx + 4.0, en_y + 48.0, 50.0, 1.0))
		poetic_1.visible = true
		_set_control_rect(poetic_1, Rect2(lx + 2.0, en_y + 66.0, 460.0, 36.0))
		poetic_2.visible = h >= 700.0
		_set_control_rect(poetic_2, Rect2(lx + 4.0, en_y + 112.0, 460.0, 60.0))

		explore_btn.text = "自由探险  /  EXPLORE"
		survive_btn.text = "生存航程  /  SURVIVE"
		guide_btn.text = "玩法说明 / 潜航指南"
		controls_btn.text = "操作与触控设置"
		var cta_bot := h - 62.0
		var half_cta := floorf((cta_w - 10.0) * 0.5)
		_set_control_rect(guide_btn, Rect2(lx + 4.0, cta_bot - 44.0, half_cta, 44.0))
		_set_control_rect(controls_btn, Rect2(lx + 4.0 + half_cta + 10.0, cta_bot - 44.0, cta_w - half_cta - 10.0, 44.0))
		var surv_y := cta_bot - 98.0
		_set_control_rect(survive_btn, Rect2(lx + 4.0, surv_y, cta_w, 46.0))
		var exp_y := surv_y - 58.0
		_set_control_rect(explore_btn, Rect2(lx + 4.0, exp_y, cta_w, 50.0))
		if _can_continue_voyage:
			var cont_y := exp_y - 56.0
			if is_instance_valid(continue_summary_label) and not continue_summary_label.text.is_empty():
				continue_summary_label.visible = true
				continue_summary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
				_set_control_rect(continue_summary_label, Rect2(lx + 4.0, exp_y - 24.0, cta_w, 22.0))
				cont_y = exp_y - 76.0
			else:
				continue_summary_label.visible = false
			_set_control_rect(continue_voyage_btn, Rect2(lx + 4.0, cont_y, cta_w, 48.0))
		else:
			continue_summary_label.visible = false

		var card_w := 336.0
		var card_h := 530.0
		var card_y := clampf(floorf((h - card_h) * 0.44), 16.0, maxf(16.0, h - card_h - 80.0))
		_set_control_rect(char_card, Rect2(w - card_w - 24.0, card_y, card_w, card_h))
		char_line_top.visible = true
		char_eyebrow.visible = true
		char_line_mid.visible = true
		char_line_bot.visible = true
		_set_control_rect(char_line_top, Rect2(20.0, 24.0, 26.0, 2.0))
		_set_control_rect(char_eyebrow, Rect2(56.0, 14.0, 260.0, 22.0))
		main_char_title.add_theme_font_size_override("font_size", 24)
		main_char_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_set_control_rect(main_char_title, Rect2(20.0, 42.0, 296.0, 32.0))
		main_char_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_set_control_rect(main_char_subtitle, Rect2(20.0, 76.0, 296.0, 22.0))
		_set_control_rect(prev_btn, Rect2(20.0, 104.0, 144.0, 44.0))
		_set_control_rect(next_btn, Rect2(172.0, 104.0, 144.0, 44.0))
		_set_control_rect(char_line_mid, Rect2(20.0, 156.0, 296.0, 1.0))
		for idx in range(CharacterRoster.CHARACTER_ORDER.size()):
			var cid: String = CharacterRoster.CHARACTER_ORDER[idx]
			var cb: Button = main_char_buttons[cid]
			cb.visible = true
			cb.custom_minimum_size = Vector2(0, 44)
			_set_control_rect(cb, Rect2(20.0, 164.0 + float(idx) * 48.0, 296.0, 44.0))
		_set_control_rect(char_line_bot, Rect2(20.0, 456.0, 296.0, 1.0))
		_set_control_rect(rot_left, Rect2(20.0, 466.0, 94.0, 44.0))
		_set_control_rect(rot_reset, Rect2(121.0, 466.0, 94.0, 44.0))
		_set_control_rect(rot_right, Rect2(222.0, 466.0, 94.0, 44.0))

		footer_left.visible = true
		footer_right.visible = (card_y + card_h) <= (h - 76.0)
		_set_control_rect(footer_left, Rect2(lx + 4.0, h - 38.0, 520.0, 24.0))
		_set_control_rect(footer_right, Rect2(w - 264.0, h - 72.0, 240.0, 56.0))

func _layout_pause_card(avail: Vector2) -> Vector2:
	var w := minf(500.0, avail.x)
	var pad := 16.0 if w < 420.0 else 28.0
	var iw := maxf(200.0, w - pad * 2.0)
	var close_btn: Button = _pause_ui["header_close"]
	_set_control_rect(close_btn, Rect2(w - pad - 80.0, 14.0, 80.0, 44.0))
	_set_control_rect(_pause_ui["accent"], Rect2(pad, 28.0, 24.0, 2.0))
	_set_control_rect(_pause_ui["eyebrow"], Rect2(pad + 34.0, 18.0, maxf(100.0, iw - 122.0), 22.0))
	_set_control_rect(_pause_ui["title"], Rect2(pad, 64.0, iw, 40.0))
	_set_control_rect(_pause_ui["desc"], Rect2(pad, 110.0, iw, 40.0))
	_set_control_rect(_pause_ui["resume_btn"], Rect2(pad, 160.0, iw, 46.0))
	_set_control_rect(_pause_ui["map_btn"], Rect2(pad, 214.0, iw, 44.0))
	var mid_half := floorf((iw - 10.0) * 0.5)
	_set_control_rect(_pause_ui["loadout_btn"], Rect2(pad, 266.0, mid_half, 44.0))
	_set_control_rect(_pause_ui["quests_btn"], Rect2(pad + mid_half + 10.0, 266.0, iw - mid_half - 10.0, 44.0))
	_set_control_rect(_pause_ui["guide_btn"], Rect2(pad, 318.0, iw, 44.0))
	_set_control_rect(_pause_ui["p_prev"], Rect2(pad, 370.0, 48.0, 44.0))
	_set_control_rect(pause_char_btn, Rect2(pad + 54.0, 370.0, maxf(100.0, iw - 108.0), 44.0))
	_set_control_rect(_pause_ui["p_next"], Rect2(pad + iw - 48.0, 370.0, 48.0, 44.0))
	var half := floorf((iw - 10.0) * 0.5)
	_set_control_rect(_pause_ui["controls_btn"], Rect2(pad, 424.0, half, 44.0))
	_set_control_rect(_pause_ui["fullscreen_btn"], Rect2(pad + half + 10.0, 424.0, iw - half - 10.0, 44.0))
	_set_control_rect(_pause_ui["restart_btn"], Rect2(pad, 476.0, iw, 44.0))
	_set_control_rect(_pause_ui["hint_lbl"], Rect2(pad, 528.0, iw, 22.0))
	return Vector2(w, 564.0)

func _layout_craft_card(avail: Vector2) -> Vector2:
	var w := minf(900.0, avail.x)
	var stacked := w < 620.0
	var pad := 14.0 if stacked else 28.0
	var iw := maxf(200.0, w - pad * 2.0)
	_set_control_rect(_craft_ui["header_close"], Rect2(w - pad - 80.0, 14.0, 80.0, 44.0))
	_set_control_rect(_craft_ui["eyebrow"], Rect2(pad, 14.0, maxf(120.0, iw - 90.0), 20.0))
	(_craft_ui["title"] as Label).add_theme_font_size_override("font_size", 22 if stacked else 28)
	_set_control_rect(_craft_ui["title"], Rect2(pad, 38.0, maxf(120.0, iw - 90.0), 34.0))
	var inv_h := 38.0 if stacked else 24.0
	_set_control_rect(craft_inventory, Rect2(pad, 76.0, iw, inv_h))
	var div_y := 76.0 + inv_h + 6.0
	_set_control_rect(_craft_ui["top_div"], Rect2(pad, div_y, iw, 1.0))
	var cur_y := div_y + 10.0
	var rows: Array = _craft_ui["rows"]
	for row: Dictionary in rows:
		var num_l: Label = row["num"]
		var title_l: Label = row["title"]
		var detail_l: Label = row["detail"]
		var cost_l: Label = row["cost"]
		var p_btn: Button = row["pin_btn"]
		var c_btn: Button = row["craft_btn"]
		var div_l: Control = row["div"]
		if stacked:
			_set_control_rect(num_l, Rect2(pad, cur_y, 28.0, 22.0))
			_set_control_rect(title_l, Rect2(pad + 30.0, cur_y, iw - 30.0, 22.0))
			_set_control_rect(detail_l, Rect2(pad, cur_y + 22.0, iw, 22.0))
			_set_control_rect(cost_l, Rect2(pad, cur_y + 44.0, iw, 22.0))
			var b_half := floorf((iw - 8.0) * 0.44)
			_set_control_rect(p_btn, Rect2(pad, cur_y + 70.0, b_half, 44.0))
			_set_control_rect(c_btn, Rect2(pad + b_half + 8.0, cur_y + 70.0, iw - b_half - 8.0, 44.0))
			_set_control_rect(div_l, Rect2(pad, cur_y + 120.0, iw, 1.0))
			cur_y += 128.0
		else:
			var act_w := 200.0
			var cost_w := clampf(floorf((iw - act_w - 44.0) * 0.40), 140.0, 240.0)
			var txt_w := maxf(160.0, iw - act_w - cost_w - 52.0)
			_set_control_rect(num_l, Rect2(pad, cur_y + 3.0, 32.0, 22.0))
			_set_control_rect(title_l, Rect2(pad + 36.0, cur_y, txt_w, 22.0))
			_set_control_rect(detail_l, Rect2(pad + 36.0, cur_y + 22.0, txt_w + cost_w, 22.0))
			_set_control_rect(cost_l, Rect2(pad + 42.0 + txt_w, cur_y + 1.0, cost_w, 22.0))
			var bx := pad + iw - act_w
			_set_control_rect(p_btn, Rect2(bx, cur_y, 86.0, 44.0))
			_set_control_rect(c_btn, Rect2(bx + 94.0, cur_y, act_w - 94.0, 44.0))
			_set_control_rect(div_l, Rect2(pad + 36.0, cur_y + 49.0, iw - 36.0, 1.0))
			cur_y += 54.0
	var foot_y := cur_y + 6.0
	var f_note: Label = _craft_ui["foot_note"]
	if stacked:
		var fh := floorf((iw - 8.0) * 0.5)
		_set_control_rect(_craft_ui["loadout_btn"], Rect2(pad, foot_y, fh, 44.0))
		_set_control_rect(_craft_ui["sushi_btn"], Rect2(pad + fh + 8.0, foot_y, iw - fh - 8.0, 44.0))
		_set_control_rect(_craft_ui["resume_btn"], Rect2(pad, foot_y + 52.0, iw, 44.0))
		f_note.visible = false
		return Vector2(w, foot_y + 112.0)
	_set_control_rect(_craft_ui["resume_btn"], Rect2(pad, foot_y, 128.0, 44.0))
	_set_control_rect(_craft_ui["loadout_btn"], Rect2(pad + 136.0, foot_y, 164.0, 44.0))
	_set_control_rect(_craft_ui["sushi_btn"], Rect2(pad + 308.0, foot_y, 168.0, 44.0))
	f_note.visible = iw >= 640.0
	_set_control_rect(f_note, Rect2(pad + 486.0, foot_y + 12.0, maxf(120.0, iw - 486.0), 22.0))
	return Vector2(w, foot_y + 60.0)

func _layout_sushi_card(avail: Vector2) -> Vector2:
	var w := minf(1000.0, avail.x)
	var tabbed := w < 840.0
	var pad := 14.0 if w < 560.0 else 28.0
	var iw := maxf(200.0, w - pad * 2.0)
	_set_control_rect(_sushi_ui["header_close"], Rect2(w - pad - 80.0, 14.0, 80.0, 44.0))
	_set_control_rect(_sushi_ui["eyebrow"], Rect2(pad, 14.0, maxf(120.0, iw - 90.0), 20.0))
	(_sushi_ui["title"] as Label).add_theme_font_size_override("font_size", 22 if tabbed else 26)
	_set_control_rect(_sushi_ui["title"], Rect2(pad, 36.0, maxf(120.0, iw - 90.0), 32.0))
	var hdr_h := 38.0 if w < 560.0 else 22.0
	_set_control_rect(sushi_header_label, Rect2(pad, 72.0, iw, hdr_h))
	var ing_y := 72.0 + hdr_h + 2.0
	var ing_h := 38.0 if w < 560.0 else 22.0
	_set_control_rect(sushi_ingredients_label, Rect2(pad, ing_y, iw, ing_h))
	var div_y := ing_y + ing_h + 6.0
	_set_control_rect(_sushi_ui["top_div"], Rect2(pad, div_y, iw, 1.0))

	var tab_bar: Control = _sushi_ui["tab_bar"]
	var sushi_sec: Control = _sushi_ui["sushi_section"]
	var cobra_sec: Control = _sushi_ui["cobra_section"]
	var marinca_box: Panel = _sushi_ui["marinca_box"]
	var body_y := div_y + 8.0
	if tabbed:
		tab_bar.visible = true
		_set_control_rect(tab_bar, Rect2(pad, body_y, iw, 44.0))
		body_y += 52.0
		sushi_sec.visible = _sushi_active_tab == 0
		cobra_sec.visible = _sushi_active_tab == 1
		marinca_box.visible = _sushi_active_tab == 2
		var sec_h := 0.0
		if _sushi_active_tab == 0:
			sec_h = _layout_sushi_rows(sushi_sec, iw)
			_set_control_rect(sushi_sec, Rect2(pad, body_y, iw, sec_h))
		elif _sushi_active_tab == 1:
			sec_h = _layout_cobra_rows(cobra_sec, iw, false)
			_set_control_rect(cobra_sec, Rect2(pad, body_y, iw, sec_h))
		else:
			sec_h = _layout_marinca_box(marinca_box, iw, 0.0)
			_set_control_rect(marinca_box, Rect2(pad, body_y, iw, sec_h))
		var foot_y := body_y + sec_h + 12.0
		_set_control_rect(_sushi_ui["resume_btn"], Rect2(pad, foot_y, minf(200.0, iw), 44.0))
		(_sushi_ui["foot_note"] as Label).visible = iw >= 460.0
		_set_control_rect(_sushi_ui["foot_note"], Rect2(pad + 210.0, foot_y + 12.0, maxf(100.0, iw - 210.0), 20.0))
		return Vector2(w, foot_y + 60.0)

	tab_bar.visible = false
	sushi_sec.visible = true
	cobra_sec.visible = true
	marinca_box.visible = true
	var left_w := floorf((iw - 20.0) * 0.58)
	var right_w := iw - left_w - 20.0
	var s_h := _layout_sushi_rows(sushi_sec, left_w)
	_set_control_rect(sushi_sec, Rect2(pad, body_y, left_w, s_h))
	var c_y := body_y + s_h + 8.0
	var c_h := _layout_cobra_rows(cobra_sec, left_w, true)
	_set_control_rect(cobra_sec, Rect2(pad, c_y, left_w, c_h))
	var left_bot := c_y + c_h
	var m_h := _layout_marinca_box(marinca_box, right_w, left_bot - body_y)
	_set_control_rect(marinca_box, Rect2(pad + left_w + 20.0, body_y, right_w, m_h))
	var foot_y2 := maxf(left_bot, body_y + m_h) + 12.0
	_set_control_rect(_sushi_ui["resume_btn"], Rect2(pad, foot_y2, 168.0, 44.0))
	(_sushi_ui["foot_note"] as Label).visible = true
	_set_control_rect(_sushi_ui["foot_note"], Rect2(pad + 180.0, foot_y2 + 12.0, iw - 180.0, 20.0))
	return Vector2(w, foot_y2 + 60.0)

func _layout_sushi_rows(sec: Control, w: float) -> float:
	var stack := w < 430.0
	var y := 0.0
	var rows: Array = _sushi_ui["sushi_rows"]
	for r: Dictionary in rows:
		var tl: Label = r["title"]
		var cl: Label = r["cost"]
		var dl: Label = r["desc"]
		var btn: Button = r["btn"]
		if stack:
			_set_control_rect(tl, Rect2(0, y, w, 22.0))
			_set_control_rect(cl, Rect2(0, y + 22.0, w, 22.0))
			_set_control_rect(dl, Rect2(0, y + 44.0, w, 22.0))
			_set_control_rect(btn, Rect2(0, y + 68.0, w, 44.0))
			y += 120.0
		else:
			var tw := maxf(160.0, w - 126.0)
			_set_control_rect(tl, Rect2(0, y, tw, 22.0))
			_set_control_rect(cl, Rect2(0, y + 22.0, tw, 22.0))
			_set_control_rect(dl, Rect2(0, y + 44.0, tw, 22.0))
			_set_control_rect(btn, Rect2(w - 118.0, y + 10.0, 118.0, 44.0))
			y += 70.0
	_set_control_rect(_sushi_ui["serve_all_btn"], Rect2(0, y + 2.0, w, 44.0))
	return y + 48.0

func _layout_cobra_rows(sec: Control, w: float, show_div: bool) -> float:
	var stack := w < 430.0
	var y := 0.0
	(_sushi_ui["cobra_div"] as Control).visible = show_div
	if show_div:
		_set_control_rect(_sushi_ui["cobra_div"], Rect2(0, 0, w, 1.0))
		y = 6.0
	_set_control_rect(_sushi_ui["cobra_heading"], Rect2(0, y, w, 22.0))
	y += 26.0
	var rows: Array = _sushi_ui["cobra_rows"]
	for r: Dictionary in rows:
		var tl: Label = r["title"]
		var dl: Label = r["desc"]
		var btn: Button = r["btn"]
		if stack:
			_set_control_rect(tl, Rect2(0, y, w, 22.0))
			_set_control_rect(dl, Rect2(0, y + 22.0, w, 22.0))
			_set_control_rect(btn, Rect2(0, y + 46.0, w, 44.0))
			y += 98.0
		else:
			var tw := maxf(160.0, w - 126.0)
			_set_control_rect(tl, Rect2(0, y, tw, 22.0))
			_set_control_rect(dl, Rect2(0, y + 22.0, tw, 22.0))
			_set_control_rect(btn, Rect2(w - 118.0, y, 118.0, 44.0))
			y += 50.0
	return y

static func _measure_label_height(label: Label, width: float, font_size: int, min_h: float) -> float:
	if not is_instance_valid(label) or label.text.is_empty():
		return min_h
	var font: Font = label.get_theme_font("font")
	if font == null:
		font = ThemeDB.fallback_font
	var safe_w := maxf(48.0, width - 6.0)
	if font != null:
		var brk_flags := TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE | TextServer.BREAK_GRAPHEME_BOUND
		var total_h := 0.0
		var line_h := maxf(float(font_size) + 4.0, font.get_height(font_size) + 1.0)
		var paras := label.text.split("\n", true)
		for i in range(paras.size()):
			var p := paras[i]
			if p.is_empty():
				total_h += line_h * 0.75
			else:
				var sz := font.get_multiline_string_size(p, HORIZONTAL_ALIGNMENT_LEFT, safe_w, font_size, -1, brk_flags)
				total_h += maxf(line_h, sz.y)
			if i + 1 < paras.size():
				total_h += 2.0
		return maxf(min_h, ceilf(total_h + 6.0))
	return min_h

func _layout_marinca_box(_box: Panel, w: float, target_h: float) -> float:
	var iw := maxf(180.0, w - 28.0)
	_set_control_rect(_sushi_ui["marinca_title"], Rect2(14.0, 12.0, iw, 22.0))
	var sum_h := _measure_label_height(marinca_summary_label, iw, 14, 44.0)
	_set_control_rect(marinca_summary_label, Rect2(14.0, 38.0, iw, sum_h))
	var div_top_y := 42.0 + sum_h
	_set_control_rect(_sushi_ui["marinca_div_top"], Rect2(14.0, div_top_y, iw, 1.0))
	var note_lbl: Label = _sushi_ui["marinca_note"]
	var note_h := _measure_label_height(note_lbl, iw, 14, 48.0)
	var grid_y := div_top_y + 6.0
	var measured_grid_h := _measure_label_height(marinca_grid_label, iw, 14, 290.0)
	var grid_h := maxf(measured_grid_h, target_h - grid_y - note_h - 22.0)
	_set_control_rect(marinca_grid_label, Rect2(14.0, grid_y, iw, grid_h))
	var bot_y := grid_y + grid_h + 6.0
	_set_control_rect(_sushi_ui["marinca_div_bot"], Rect2(14.0, bot_y, iw, 1.0))
	_set_control_rect(note_lbl, Rect2(14.0, bot_y + 6.0, iw, note_h))
	return maxf(target_h, bot_y + note_h + 14.0)

func _layout_mount_card(avail: Vector2) -> Vector2:
	var w := minf(940.0, avail.x)
	var pad := 14.0 if w < 560.0 else 28.0
	var iw := maxf(200.0, w - pad * 2.0)
	_set_control_rect(_mount_ui["header_close"], Rect2(w - pad - 80.0, 14.0, 80.0, 44.0))
	_set_control_rect(_mount_ui["eyebrow"], Rect2(pad, 14.0, maxf(120.0, iw - 90.0), 20.0))
	(_mount_ui["title"] as Label).add_theme_font_size_override("font_size", 22 if w < 560.0 else 28)
	_set_control_rect(_mount_ui["title"], Rect2(pad, 38.0, maxf(120.0, iw - 90.0), 34.0))
	_set_control_rect(mount_board_summary_label, Rect2(pad, 76.0, iw, 24.0))
	var btn_w := minf(160.0, floorf((iw - 10.0) * 0.5))
	_set_control_rect(mount_board_select_all_btn, Rect2(pad, 108.0, btn_w, 44.0))
	_set_control_rect(mount_board_store_all_btn, Rect2(pad + btn_w + 10.0, 108.0, btn_w, 44.0))
	var top_note: Label = _mount_ui["top_note"]
	top_note.visible = iw >= 640.0
	_set_control_rect(top_note, Rect2(pad + btn_w * 2.0 + 24.0, 120.0, maxf(120.0, iw - btn_w * 2.0 - 24.0), 22.0))

	var cols := 3 if w >= 760.0 else (2 if w >= 480.0 else 1)
	var grid: GridContainer = _mount_ui["grid"]
	grid.columns = cols
	var vis_slots := 0
	for r_node: Control in mount_board_slot_rows:
		if r_node.visible:
			vis_slots += 1
	var rows := maxi(2, ceili(float(maxi(vis_slots, 1)) / float(cols)))
	var grid_h := maxf(160.0, float(rows) * 68.0 + float(maxi(0, rows - 1)) * 10.0)
	_set_control_rect(grid, Rect2(pad, 164.0, iw, grid_h))
	_set_control_rect(mount_board_empty_label, Rect2(pad, 164.0 + (grid_h - 64.0) * 0.5, iw, 64.0))
	var foot_y := 164.0 + grid_h + 14.0
	_set_control_rect(_mount_ui["resume_btn"], Rect2(pad, foot_y, minf(180.0, iw), 44.0))
	var foot_note: Label = _mount_ui["foot_note"]
	foot_note.visible = iw >= 520.0
	_set_control_rect(foot_note, Rect2(pad + 192.0, foot_y + 12.0, maxf(120.0, iw - 192.0), 20.0))
	return Vector2(w, foot_y + 58.0)

func _layout_map_card(avail: Vector2, safe_size: Vector2) -> void:
	var card: Panel = _map_ui["card"]
	var is_desktop := avail.x >= 1060.0 and avail.y >= 728.0
	var cw := 1060.0 if is_desktop else avail.x
	var ch := 728.0 if is_desktop else avail.y
	var cx := maxf(0.0, floorf((avail.x - cw) * 0.5))
	var cy := maxf(0.0, floorf((avail.y - ch) * 0.5))
	_set_control_rect(card, Rect2(cx, cy, cw, ch))

	var pad := 12.0 if (cw < 760.0 or ch < 500.0) else 24.0
	var iw := maxf(200.0, cw - pad * 2.0)
	var compact_hdr := ch < 480.0 or cw < 640.0
	_set_control_rect(_map_ui["header_close"], Rect2(cw - pad - 80.0, 8.0 if compact_hdr else 14.0, 80.0, 44.0))
	(_map_ui["eyebrow"] as Label).visible = not compact_hdr
	var body_y := 74.0
	if compact_hdr:
		map_rank_label.add_theme_font_size_override("font_size", 16)
		_set_control_rect(map_rank_label, Rect2(pad, 14.0, maxf(120.0, iw - 88.0), 28.0))
		body_y = 56.0
	else:
		_set_control_rect(_map_ui["eyebrow"], Rect2(pad, 14.0, maxf(120.0, iw - 90.0), 20.0))
		map_rank_label.add_theme_font_size_override("font_size", 20)
		_set_control_rect(map_rank_label, Rect2(pad, 38.0, maxf(120.0, iw - 90.0), 28.0))

	var body_h := maxf(160.0, ch - body_y - pad)
	var split: BoxContainer = _map_ui["split"]
	var chart_pane: Control = _map_ui["chart_pane"]
	var side: Panel = _map_ui["side"]
	var side_scroll: ScrollContainer = _map_ui["side_scroll"]
	_set_control_rect(split, Rect2(pad, body_y, iw, body_h))

	var is_vert := _is_portrait or (safe_size.x < 720.0 and safe_size.y >= 520.0)
	split.vertical = is_vert
	var gap := 12.0
	var pane_w := iw
	var pane_h := body_h
	var side_w := iw
	var side_h := body_h
	if is_vert:
		pane_h = clampf(floorf((body_h - gap) * 0.52), minf(220.0, body_h * 0.62), maxf(180.0, body_h - 140.0))
		side_h = maxf(120.0, body_h - pane_h - gap)
	else:
		pane_w = floorf((iw - gap) * 0.58)
		side_w = maxf(180.0, iw - pane_w - gap)
	chart_pane.custom_minimum_size = Vector2(pane_w, pane_h)
	side.custom_minimum_size = Vector2(side_w, side_h)
	var chart_h := maxf(120.0, pane_h - 50.0)
	_set_control_rect(sea_chart, Rect2(0.0, 0.0, pane_w, chart_h))
	_set_control_rect(map_focus_button, Rect2(0.0, chart_h + 6.0, pane_w, 44.0))
	_set_control_rect(side_scroll, Rect2(10.0, 8.0, maxf(140.0, side_w - 20.0), maxf(96.0, side_h - 16.0)))
	var stack_side_btns := (side_w - 20.0) < 250.0
	(_map_ui["wp_row"] as BoxContainer).vertical = stack_side_btns
	(_map_ui["act_row"] as BoxContainer).vertical = stack_side_btns

func _layout_win_card(avail: Vector2) -> Vector2:
	var w := minf(680.0, avail.x)
	var pad := 16.0 if w < 460.0 else 36.0
	var iw := maxf(200.0, w - pad * 2.0)
	_set_control_rect(_win_ui["accent"], Rect2(pad, 30.0, 32.0, 2.0))
	_set_control_rect(_win_ui["eyebrow"], Rect2(pad + 44.0, 20.0, maxf(120.0, iw - 44.0), 22.0))
	win_title.add_theme_font_size_override("font_size", 24 if w < 460.0 else 32)
	_set_control_rect(win_title, Rect2(pad, 62.0, iw, 48.0))
	_set_control_rect(win_desc, Rect2(pad, 118.0, iw, 88.0))
	_set_control_rect(win_time, Rect2(pad, 214.0, iw, 24.0))
	if w < 440.0:
		_set_control_rect(_win_ui["resume_btn"], Rect2(pad, 252.0, iw, 46.0))
		_set_control_rect(_win_ui["restart_btn"], Rect2(pad, 306.0, iw, 46.0))
		return Vector2(w, 370.0)
	var rw := floorf((iw - 14.0) * 0.56)
	_set_control_rect(_win_ui["resume_btn"], Rect2(pad, 260.0, rw, 48.0))
	_set_control_rect(_win_ui["restart_btn"], Rect2(pad + rw + 14.0, 260.0, iw - rw - 14.0, 48.0))
	return Vector2(w, 336.0)

func _layout_quick_card(avail: Vector2) -> Vector2:
	var w := minf(860.0, avail.x)
	var cols := 3 if w >= 720.0 else 2
	var pad := 14.0 if w < 560.0 else 28.0
	var iw := maxf(200.0, w - pad * 2.0)
	_set_control_rect(_quick_ui["header_close"], Rect2(w - pad - 80.0, 14.0, 80.0, 44.0))
	_set_control_rect(_quick_ui["eyebrow"], Rect2(pad, 14.0, maxf(120.0, iw - 90.0), 20.0))
	(_quick_ui["title"] as Label).add_theme_font_size_override("font_size", 22 if w < 560.0 else 28)
	_set_control_rect(_quick_ui["title"], Rect2(pad, 38.0, maxf(120.0, iw - 90.0), 34.0))
	_set_control_rect(_quick_ui["desc"], Rect2(pad, 74.0, iw, 20.0))
	var grid: GridContainer = _quick_ui["grid"]
	grid.columns = cols
	var rows := ceili(float(QUICK_ACTIONS.size()) / float(cols))
	var grid_h := float(rows) * 44.0 + float(maxi(0, rows - 1)) * 6.0
	_set_control_rect(grid, Rect2(pad, 102.0, iw, grid_h))
	var foot_y := 102.0 + grid_h + 14.0
	var fw := minf(254.0, floorf((iw - 10.0) * 0.5))
	_set_control_rect(_quick_ui["settings_btn"], Rect2(pad, foot_y, fw, 44.0))
	_set_control_rect(_quick_ui["resume_btn"], Rect2(pad + iw - fw, foot_y, fw, 44.0))
	return Vector2(w, foot_y + 58.0)

func _layout_controls_card(avail: Vector2) -> Vector2:
	var w := minf(700.0, avail.x)
	var stack := w < 520.0
	var pad := 14.0 if stack else 28.0
	var iw := maxf(200.0, w - pad * 2.0)
	_set_control_rect(_controls_ui["header_close"], Rect2(w - pad - 80.0, 14.0, 80.0, 44.0))
	_set_control_rect(_controls_ui["eyebrow"], Rect2(pad, 14.0, maxf(120.0, iw - 90.0), 20.0))
	(_controls_ui["title"] as Label).add_theme_font_size_override("font_size", 22 if stack else 28)
	_set_control_rect(_controls_ui["title"], Rect2(pad, 38.0, maxf(120.0, iw - 90.0), 34.0))
	for entry: Dictionary in _controls_ui["rows"]:
		var row_box: BoxContainer = entry["box"]
		var lbl: Label = entry["label"]
		row_box.vertical = stack
		lbl.custom_minimum_size = Vector2(0.0 if stack else 176.0, 22.0 if stack else 26.0)
	(_controls_ui["footer_row"] as BoxContainer).vertical = w < 380.0
	(_controls_ui["note_lbl"] as Label).custom_minimum_size = Vector2(0.0, 56.0 if stack else 42.0)
	var vbox: VBoxContainer = _controls_ui["vbox"]
	var v_min_h := maxf(460.0, vbox.get_combined_minimum_size().y)
	_set_control_rect(vbox, Rect2(pad, 84.0, iw, v_min_h))
	return Vector2(w, 84.0 + v_min_h + 18.0)

func _layout_onboarding() -> void:
	if not is_instance_valid(onboarding_panel) or not is_instance_valid(root):
		return
	var safe := _safe_area_rect()
	var max_w := maxf(180.0, safe.size.x - 24.0)
	if is_instance_valid(onboarding_close_btn):
		onboarding_close_btn.visible = _touch_layout
	onboarding_desc.add_theme_font_size_override("font_size", 13 if _touch_layout else 14)
	var right_reserve := 38.0 if _touch_layout else 10.0
	if _touch_layout or _is_compact:
		if _is_portrait:
			var life_node: Control = instruments.get_node("LifeSupportInstrument")
			var y_top := status_value.offset_bottom + 8.0
			if mission_title.visible:
				y_top = maxf(y_top, mission_title.offset_bottom + 6.0)
			if not target_value.text.is_empty():
				y_top = maxf(y_top, target_value.offset_bottom + 6.0)
			if not _touch_layout:
				y_top = maxf(y_top, life_node.offset_bottom + 8.0)
			var ob_h := 112.0
			if _touch_layout and y_top + ob_h > life_node.offset_top - 6.0 and life_node.offset_top > y_top + 60.0:
				ob_h = life_node.offset_top - y_top - 6.0
			var right_col_x := safe.size.x - 12.0
			if is_instance_valid(minimap_radar) and minimap_radar.visible:
				var r_top := minimap_radar.anchor_top * safe.size.y + minimap_radar.offset_top
				var r_bot := minimap_radar.anchor_bottom * safe.size.y + minimap_radar.offset_bottom
				if y_top < r_bot + 4.0 and y_top + ob_h > r_top - 4.0:
					right_col_x = minf(right_col_x, minimap_radar.anchor_left * safe.size.x + minimap_radar.offset_left - 8.0)
			if is_instance_valid(_compact_pin_label) and _compact_pin_label.visible:
				var p_top := _compact_pin_label.anchor_top * safe.size.y + _compact_pin_label.offset_top
				var p_bot := _compact_pin_label.anchor_bottom * safe.size.y + _compact_pin_label.offset_bottom
				if y_top < p_bot + 4.0 and y_top + ob_h > p_top - 4.0:
					right_col_x = minf(right_col_x, _compact_pin_label.anchor_left * safe.size.x + _compact_pin_label.offset_left - 8.0)
			var ob_w := minf(276.0 if _touch_layout else 320.0, minf(max_w, maxf(180.0, right_col_x - 12.0)))
			_set_control_rect(onboarding_panel, Rect2(12.0, y_top, ob_w, ob_h))
			_set_control_rect(onboarding_badge, Rect2(10.0, 3.0, ob_w - 10.0 - right_reserve, 20.0))
			_set_control_rect(onboarding_title, Rect2(10.0, 22.0, ob_w - 10.0 - right_reserve, 20.0))
			_set_control_rect(onboarding_bar, Rect2(10.0, 44.0, ob_w - 20.0, 2.0))
			_set_control_rect(onboarding_desc, Rect2(10.0, 48.0, ob_w - 20.0, ob_h - 52.0))
			if is_instance_valid(onboarding_close_btn):
				_set_control_rect(onboarding_close_btn, Rect2(ob_w - 32.0, 4.0, 28.0, 28.0))
			onboarding_desc.clip_text = false
			onboarding_sub.visible = false
		elif _is_short:
			var left_limit := maxf(status_value.offset_right, target_value.offset_right) + 10.0
			var right_limit := safe.size.x + minimap_radar.offset_left - 10.0
			var avail_mid := right_limit - left_limit
			var ob_w := minf(244.0 if _touch_layout else 280.0, minf(max_w, maxf(180.0, avail_mid)))
			var ob_x := clampf((left_limit + right_limit - ob_w) * 0.5, 12.0, maxf(12.0, safe.size.x - ob_w - 12.0))
			var ob_y := maxf(depth_value.offset_bottom + 6.0, 70.0)
			if ob_x < left_limit:
				ob_y = maxf(ob_y, target_value.offset_bottom + 6.0)
			var ob_h_s := 72.0 if _touch_layout else 78.0
			_set_control_rect(onboarding_panel, Rect2(ob_x, ob_y, ob_w, ob_h_s))
			_set_control_rect(onboarding_badge, Rect2(8.0, 2.0, ob_w - 8.0 - right_reserve, 20.0))
			_set_control_rect(onboarding_title, Rect2(8.0, 21.0, ob_w - 8.0 - right_reserve, 20.0))
			_set_control_rect(onboarding_bar, Rect2(8.0, 43.0, ob_w - 16.0, 2.0))
			_set_control_rect(onboarding_desc, Rect2(8.0, 46.0, ob_w - 16.0, 24.0))
			if is_instance_valid(onboarding_close_btn):
				_set_control_rect(onboarding_close_btn, Rect2(ob_w - 31.0, 3.0, 28.0, 28.0))
			onboarding_desc.clip_text = true
			onboarding_sub.visible = false
		else:
			var life_node: Control = instruments.get_node("LifeSupportInstrument")
			var ob_w := minf(248.0 if _touch_layout else 268.0, max_w)
			var y_pos := maxf(target_value.offset_bottom + 8.0, maxf(status_value.offset_bottom + 10.0, 136.0))
			var life_top := life_node.anchor_top * safe.size.y + life_node.offset_top
			var life_bot := life_node.anchor_bottom * safe.size.y + life_node.offset_bottom
			var life_left := life_node.anchor_left * safe.size.x + life_node.offset_left
			if life_top < safe.size.y * 0.45 and life_left < 16.0 + ob_w + 8.0:
				y_pos = maxf(y_pos, life_bot + 12.0)
			if is_instance_valid(tame_panel) and tame_panel.visible:
				var tame_top := tame_panel.anchor_top * safe.size.y + tame_panel.offset_top
				var tame_bot := tame_panel.anchor_bottom * safe.size.y + tame_panel.offset_bottom
				var tame_left := tame_panel.anchor_left * safe.size.x + tame_panel.offset_left
				if tame_top < safe.size.y * 0.45 and tame_left < 16.0 + ob_w + 8.0:
					y_pos = maxf(y_pos, tame_bot + 10.0)
			var ob_h_l := 104.0 if _touch_layout else 146.0
			y_pos = minf(y_pos, maxf(12.0, safe.size.y - ob_h_l - 12.0))
			_set_control_rect(onboarding_panel, Rect2(16.0, y_pos, ob_w, ob_h_l))
			_set_control_rect(onboarding_badge, Rect2(12.0, 5.0, ob_w - 12.0 - right_reserve, 22.0))
			_set_control_rect(onboarding_title, Rect2(12.0, 26.0, ob_w - 12.0 - right_reserve, 22.0))
			_set_control_rect(onboarding_bar, Rect2(12.0, 50.0, ob_w - 24.0, 3.0))
			_set_control_rect(onboarding_desc, Rect2(12.0, 55.0, ob_w - 24.0, 44.0 if _touch_layout else 58.0))
			_set_control_rect(onboarding_sub, Rect2(12.0, 118.0, ob_w - 24.0, 22.0))
			if is_instance_valid(onboarding_close_btn):
				_set_control_rect(onboarding_close_btn, Rect2(ob_w - 34.0, 5.0, 28.0, 28.0))
			onboarding_desc.clip_text = false
			onboarding_sub.visible = not _touch_layout
	else:
		var ob_w := minf(268.0, max_w)
		_set_control_rect(onboarding_panel, Rect2(28.0, 56.0, ob_w, 148.0))
		_set_control_rect(onboarding_badge, Rect2(12.0, 6.0, ob_w - 24.0, 22.0))
		_set_control_rect(onboarding_title, Rect2(12.0, 28.0, ob_w - 24.0, 22.0))
		_set_control_rect(onboarding_bar, Rect2(12.0, 53.0, ob_w - 24.0, 3.0))
		_set_control_rect(onboarding_desc, Rect2(12.0, 60.0, ob_w - 24.0, 60.0))
		_set_control_rect(onboarding_sub, Rect2(12.0, 121.0, ob_w - 24.0, 22.0))
		onboarding_desc.clip_text = false
		onboarding_sub.visible = true

func _apply_touch_visibility() -> void:
	var compact := _is_compact
	var safe := _safe_area_rect()
	var large_tablet := safe.size.x >= 960.0 and safe.size.y >= 680.0
	if is_instance_valid(_cargo):
		if large_tablet:
			var env_chk := _compute_touch_envelopes(safe) if _touch_layout else {}
			var cargo_fits := (not _touch_layout) or (_cargo.offset_bottom <= float(env_chk.get("right_cluster_top", safe.size.y)) - 6.0)
			_cargo.visible = _cargo_wants_visible and not _scoped_active and cargo_fits
		elif _touch_layout or _is_narrow or _is_short:
			_cargo.hide()
	if is_instance_valid(minimap_radar):
		minimap_radar.visible = not _scoped_active
	home_value.visible = not compact
	if compact:
		mission_detail.hide()
		explore_summary_label.hide()
		pinned_panel.hide()
		if is_instance_valid(_compact_pin_label):
			_compact_pin_label.visible = not _scoped_active and not _compact_pin_label.text.is_empty()
		tame_panel.hide()
		weapon_hint.hide()
		if _touch_layout:
			shield_label.hide()
			equipment_value.hide()
	elif is_instance_valid(_compact_pin_label):
		_compact_pin_label.hide()
	if is_instance_valid(_bottom_hints):
		_bottom_hints.visible = not compact and not _touch_layout
	for node in sub_panel.get_children():
		if node is Label and str(node.get_meta("_hint_source", node.text)).begins_with("W/S"):
			node.visible = not _touch_layout and not compact
	_sync_visor_visibility()

func _apply_pure_icon_button_style(btn: Button, icon_tex: Texture2D) -> void:
	btn.text = ""
	btn.icon = icon_tex
	btn.expand_icon = true
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var empty_sb := StyleBoxEmpty.new()
	for st: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(st, empty_sb)

func _sync_scope_exit_btn_appearance() -> void:
	if not is_instance_valid(scope_exit_btn):
		return
	if _touch_layout:
		scope_exit_btn.custom_minimum_size = Vector2(46, 46)
		_apply_pure_icon_button_style(scope_exit_btn, SCOPE_EXIT_ICON)
	else:
		scope_exit_btn.icon = null
		scope_exit_btn.expand_icon = false
		scope_exit_btn.text = "退出瞄准"
		scope_exit_btn.custom_minimum_size = Vector2(108, 44)
		for st: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			scope_exit_btn.remove_theme_stylebox_override(st)
		OceanUiTheme.button(scope_exit_btn, true)

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
