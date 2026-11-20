extends RefCounted
## Ocean-glass combat loadout, deep-forge, tactical mods & resonance panel ("loadout" screen).

const OceanUiTheme = preload("res://scripts/presentation/ocean_ui_theme.gd")
const CharacterRoster = preload("res://scripts/presentation/character_roster.gd")

const COLOR_BG_CARD := Color(0.02745, 0.08235, 0.12941, 0.94)
const COLOR_BG_SUBPANEL := Color(0.03922, 0.10980, 0.16863, 0.80)
const COLOR_BG_ITEM := Color(0.04706, 0.12549, 0.19216, 0.72)
const COLOR_BG_ITEM_HOVER := Color(0.06667, 0.17255, 0.25490, 0.86)
const COLOR_BG_ITEM_SELECTED := Color(0.07843, 0.21569, 0.30588, 0.92)
const COLOR_CYAN := Color("4bbbd4")
const COLOR_GOLD := Color("efb25b")
const COLOR_TEXT := Color("eaf6fa")
const COLOR_MUTED := Color("8fb0be")
const COLOR_DONE := Color("63e0b8")
const COLOR_CORAL := Color("e67a73")
const COLOR_INK := Color("071521")

const MAX_EQUIP_SLOTS := 3
const MAX_WEAPON_MODS := 2
const MAX_WEAPON_TIER := 5

const TAB_DEFS := [
	{"id": "weapons", "label": "武器装配与深铸", "short_label": "武器深铸"},
	{"id": "mods", "label": "战术模组", "short_label": "战术模组"},
	{"id": "skills", "label": "技能与终极共鸣", "short_label": "技能共鸣"},
]

const ITEM_NAMES := {
	"titanium": "钛",
	"copper": "铜",
	"quartz": "石英",
	"kelp": "海藻",
	"fish_small": "小鱼",
	"fish_meat": "生肉",
	"creature_tooth": "生物利齿",
	"shark_fragment": "鲨齿",
	"abyss_fragment": "晶核",
	"mother_tree_essence": "生命精华",
	"ancient_star_core": "星核源石",
	"tree_seed": "启迪之种",
	"gold": "金币",
}

static func build(menu_root: Control, callbacks: Dictionary = {}) -> Dictionary:
	var view: Dictionary = {
		"touch_mode": false,
		"avail_size": Vector2(960.0, 700.0),
		"narrow_mode": false,
		"rendered_version": -1,
		"rendered_tab": "",
		"rendered_mod_weapon": "",
		"rendered_narrow": false,
		"rendered_touch": false,
		"selected_tab": "weapons",
		"selected_mod_weapon": "",
		"payload": {},
		"callbacks": callbacks,
		"weapons_grid": null,
		"slot_buttons": [],
	}

	var card := Panel.new()
	card.name = "LoadoutCard"
	_place(card, menu_root, Rect2(0.0, 0.0, 960.0, 700.0))
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_theme_stylebox_override("panel", OceanUiTheme.surface(COLOR_BG_CARD, Color(COLOR_CYAN, 0.34), 4))

	# Header
	var accent_line := _line(card, Rect2(26.0, 26.0, 30.0, 2.0), COLOR_GOLD)
	var eyebrow := _label(card, "ABYSSAL ARSENAL  /  深海武装与战术配置", Rect2(66.0, 16.0, 520.0, 22.0), 14, COLOR_CYAN)
	eyebrow.set_meta("_no_hint", true)

	var main_title := _label(card, "武装与战术配置", Rect2(26.0, 42.0, 360.0, 38.0), 26, COLOR_TEXT)
	main_title.set_meta("_no_hint", true)

	var status_label := _label(card, "金币 0 · 已装配 0/3 武器", Rect2(410.0, 48.0, 422.0, 24.0), 14, COLOR_GOLD)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.set_meta("_no_hint", true)

	var close_btn := _button(card, "关闭", Rect2(848.0, 20.0, 86.0, 42.0), func() -> void:
		_invoke_callback_0(callbacks, "on_close")
	, "neutral")
	close_btn.name = "LoadoutCloseButton"
	close_btn.custom_minimum_size = Vector2(78.0, 42.0)
	close_btn.set_meta("_no_hint", true)

	var header_divider := _line(card, Rect2(26.0, 88.0, 908.0, 1.0), Color(COLOR_CYAN, 0.22))

	# Tab bar
	var tab_bar := Control.new()
	tab_bar.name = "LoadoutTabBar"
	_place(tab_bar, card, Rect2(26.0, 96.0, 908.0, 44.0))
	tab_bar.mouse_filter = Control.MOUSE_FILTER_PASS

	var tab_buttons: Dictionary = {}
	for i in range(TAB_DEFS.size()):
		var def: Dictionary = TAB_DEFS[i]
		var tab_id: String = str(def["id"])
		var btn := _button(tab_bar, str(def["label"]), Rect2(float(i) * 304.0, 0.0, 296.0, 42.0), func() -> void:
			_on_tab_selected(view, tab_id)
		, "primary" if i == 0 else "neutral")
		btn.name = "LoadoutTab_%s" % tab_id
		btn.custom_minimum_size = Vector2(0.0, 40.0)
		btn.clip_text = true
		btn.set_meta("_no_hint", true)
		tab_buttons[tab_id] = btn

	var tab_divider := _line(card, Rect2(26.0, 146.0, 908.0, 1.0), Color(COLOR_CYAN, 0.16))

	# Body host (switches cleanly between single-scroll / two-column layouts)
	var body_host := Control.new()
	body_host.name = "LoadoutBodyHost"
	_place(body_host, card, Rect2(26.0, 156.0, 908.0, 518.0))
	body_host.mouse_filter = Control.MOUSE_FILTER_PASS

	var single_scroll := ScrollContainer.new()
	single_scroll.name = "LoadoutSingleScroll"
	_place(single_scroll, body_host, Rect2(0.0, 0.0, 908.0, 518.0))
	single_scroll.follow_focus = true
	single_scroll.scroll_deadzone = 10
	single_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	single_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	single_scroll.mouse_filter = Control.MOUSE_FILTER_PASS

	var single_vbox := VBoxContainer.new()
	single_vbox.name = "LoadoutSingleVBox"
	single_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	single_vbox.add_theme_constant_override("separation", 10)
	single_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	single_scroll.add_child(single_vbox)

	var left_scroll := ScrollContainer.new()
	left_scroll.name = "LoadoutLeftScroll"
	_place(left_scroll, body_host, Rect2(0.0, 0.0, 330.0, 518.0))
	left_scroll.follow_focus = true
	left_scroll.scroll_deadzone = 10
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	left_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	left_scroll.visible = false

	var left_vbox := VBoxContainer.new()
	left_vbox.name = "LoadoutLeftVBox"
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_vbox.add_theme_constant_override("separation", 8)
	left_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	left_scroll.add_child(left_vbox)

	var split_divider := _line(body_host, Rect2(342.0, 0.0, 1.0, 518.0), Color(COLOR_CYAN, 0.18))
	split_divider.visible = false

	var right_scroll := ScrollContainer.new()
	right_scroll.name = "LoadoutRightScroll"
	_place(right_scroll, body_host, Rect2(354.0, 0.0, 554.0, 518.0))
	right_scroll.follow_focus = true
	right_scroll.scroll_deadzone = 10
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	right_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	right_scroll.visible = false

	var right_vbox := VBoxContainer.new()
	right_vbox.name = "LoadoutRightVBox"
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 8)
	right_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	right_scroll.add_child(right_vbox)

	view["card"] = card
	view["close_btn"] = close_btn
	view["accent_line"] = accent_line
	view["eyebrow"] = eyebrow
	view["main_title"] = main_title
	view["status_label"] = status_label
	view["header_divider"] = header_divider
	view["tab_bar"] = tab_bar
	view["tab_buttons"] = tab_buttons
	view["tab_divider"] = tab_divider
	view["body_host"] = body_host
	view["single_scroll"] = single_scroll
	view["single_vbox"] = single_vbox
	view["left_scroll"] = left_scroll
	view["left_vbox"] = left_vbox
	view["split_divider"] = split_divider
	view["right_scroll"] = right_scroll
	view["right_vbox"] = right_vbox

	set_responsive_layout(view, Vector2(960.0, 700.0))
	return view

static func update_data(view: Dictionary, payload: Dictionary) -> void:
	if view.is_empty() or not is_instance_valid(view.get("card")):
		return
	view["payload"] = payload
	_update_header_meta(view, payload)

	var incoming_version := int(payload.get("version", -1))
	var rendered_version := int(view.get("rendered_version", -1))
	var current_tab := str(view.get("selected_tab", "weapons"))
	var current_narrow := bool(view.get("narrow_mode", false))
	var current_touch := bool(view.get("touch_mode", false))

	_ensure_valid_mod_weapon(view, payload)
	var current_mod_weapon := str(view.get("selected_mod_weapon", ""))

	var same_version := incoming_version >= 0 and incoming_version == rendered_version
	if (
		same_version
		and current_tab == str(view.get("rendered_tab", ""))
		and current_mod_weapon == str(view.get("rendered_mod_weapon", ""))
		and current_narrow == bool(view.get("rendered_narrow", false))
		and current_touch == bool(view.get("rendered_touch", false))
	):
		return

	_render_active_tab(view, payload)

static func set_responsive_layout(view: Dictionary, avail_size: Vector2) -> void:
	if view.is_empty() or not is_instance_valid(view.get("card")):
		return
	var clamped_avail := Vector2(maxf(300.0, avail_size.x), maxf(260.0, avail_size.y))
	view["avail_size"] = clamped_avail
	var is_narrow := clamped_avail.x < 720.0
	var narrow_changed := is_narrow != bool(view.get("narrow_mode", false))
	view["narrow_mode"] = is_narrow
	var is_compact_h := clamped_avail.y < 540.0
	var is_touch := bool(view.get("touch_mode", false))

	var card: Panel = view["card"]
	var card_w := minf(980.0, clamped_avail.x)
	var card_h := clamped_avail.y if (is_narrow or is_compact_h) else minf(700.0, clamped_avail.y)
	var card_x := maxf(0.0, floorf((clamped_avail.x - card_w) * 0.5))
	var card_y := maxf(0.0, floorf((clamped_avail.y - card_h) * 0.5))
	_set_rect(card, Rect2(card_x, card_y, card_w, card_h))
	card.custom_minimum_size = Vector2(minf(card_w, clamped_avail.x), minf(card_h, clamped_avail.y))

	var pad := 14.0 if is_narrow else 26.0
	var inner_w := maxf(240.0, card_w - pad * 2.0)
	var btn_h := 42.0 if is_touch else 40.0
	var close_w := 80.0 if is_narrow else 88.0

	var accent_line: ColorRect = view["accent_line"]
	var eyebrow: Label = view["eyebrow"]
	var main_title: Label = view["main_title"]
	var status_label: Label = view["status_label"]
	var close_btn: Button = view["close_btn"]
	var header_divider: ColorRect = view["header_divider"]

	_set_rect(close_btn, Rect2(card_w - pad - close_w, 12.0 if is_narrow else 20.0, close_w, btn_h))
	close_btn.custom_minimum_size = Vector2(close_w, btn_h)

	var header_bottom := 88.0
	if is_narrow:
		var super_short := card_h < 440.0
		accent_line.visible = not super_short
		eyebrow.visible = not super_short
		if super_short:
			_set_rect(main_title, Rect2(pad, 12.0, maxf(120.0, inner_w - close_w - 8.0), 28.0))
			main_title.add_theme_font_size_override("font_size", 20)
			status_label.visible = true
			_set_rect(status_label, Rect2(pad, 40.0, maxf(120.0, inner_w - close_w - 8.0), 20.0))
			status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			header_bottom = 64.0
		else:
			_set_rect(accent_line, Rect2(pad, 18.0, 24.0, 2.0))
			eyebrow.text = "ARSENAL  /  武装与战术配置"
			eyebrow.add_theme_font_size_override("font_size", 12)
			_set_rect(eyebrow, Rect2(pad + 32.0, 8.0, maxf(120.0, inner_w - close_w - 40.0), 20.0))
			_set_rect(main_title, Rect2(pad, 28.0, maxf(120.0, inner_w - close_w - 8.0), 30.0))
			main_title.add_theme_font_size_override("font_size", 22)
			status_label.visible = true
			_set_rect(status_label, Rect2(pad, 60.0, inner_w, 22.0))
			status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			header_bottom = 86.0
	else:
		accent_line.visible = true
		eyebrow.visible = true
		status_label.visible = true
		eyebrow.text = "ABYSSAL ARSENAL  /  深海武装与战术配置"
		eyebrow.add_theme_font_size_override("font_size", 14)
		_set_rect(accent_line, Rect2(pad, 26.0, 30.0, 2.0))
		var left_hdr_w := floorf((inner_w - close_w - 16.0) * 0.48)
		var right_hdr_x := pad + left_hdr_w + 8.0
		var right_hdr_w := maxf(140.0, card_w - pad - close_w - 14.0 - right_hdr_x)
		_set_rect(eyebrow, Rect2(pad + 40.0, 16.0, maxf(160.0, inner_w - close_w - 52.0), 22.0))
		_set_rect(main_title, Rect2(pad, 42.0, left_hdr_w, 38.0))
		main_title.add_theme_font_size_override("font_size", 26)
		_set_rect(status_label, Rect2(right_hdr_x, 48.0, right_hdr_w, 26.0))
		status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		header_bottom = 88.0

	_set_rect(header_divider, Rect2(pad, header_bottom, inner_w, 1.0))

	# Tab bar
	var tab_bar: Control = view["tab_bar"]
	var tab_buttons: Dictionary = view["tab_buttons"]
	var tab_divider: ColorRect = view["tab_divider"]
	var tab_top := header_bottom + 8.0
	var tab_h := btn_h
	_set_rect(tab_bar, Rect2(pad, tab_top, inner_w, tab_h))

	var gap_t := 6.0 if is_narrow else 10.0
	var tab_count := float(TAB_DEFS.size())
	var tab_col_w := floorf((inner_w - gap_t * (tab_count - 1.0)) / tab_count)
	var use_short_tabs := inner_w < 560.0
	for i in range(TAB_DEFS.size()):
		var def: Dictionary = TAB_DEFS[i]
		var tid: String = str(def["id"])
		var tb: Button = tab_buttons[tid]
		var x := float(i) * (tab_col_w + gap_t)
		var w := tab_col_w if i < TAB_DEFS.size() - 1 else maxf(76.0, inner_w - x)
		_set_rect(tb, Rect2(x, 0.0, w, tab_h))
		tb.custom_minimum_size = Vector2(w, tab_h)
		tb.text = str(def["short_label"] if use_short_tabs else def["label"])

	var tab_div_y := tab_top + tab_h + 8.0
	_set_rect(tab_divider, Rect2(pad, tab_div_y, inner_w, 1.0))

	var body_top := tab_div_y + 10.0
	var body_h := maxf(120.0, card_h - pad - body_top)
	var body_host: Control = view["body_host"]
	_set_rect(body_host, Rect2(pad, body_top, inner_w, body_h))

	if narrow_changed and not (view.get("payload", {}) as Dictionary).is_empty():
		_render_active_tab(view, view["payload"])
	else:
		refresh_layout(view)

static func set_touch_mode(view: Dictionary, touch_enabled: bool) -> void:
	if view.is_empty() or not is_instance_valid(view.get("card")):
		return
	var changed := bool(view.get("touch_mode", false)) != touch_enabled
	view["touch_mode"] = touch_enabled
	for key: String in ["single_scroll", "left_scroll", "right_scroll"]:
		var sc: ScrollContainer = view.get(key)
		if is_instance_valid(sc):
			sc.follow_focus = not touch_enabled
			sc.scroll_deadzone = 12 if touch_enabled else 8
	set_responsive_layout(view, view.get("avail_size", Vector2(960.0, 700.0)))
	if changed and not (view.get("payload", {}) as Dictionary).is_empty():
		_render_active_tab(view, view["payload"])

static func refresh_layout(view: Dictionary) -> void:
	if view.is_empty() or not is_instance_valid(view.get("card")):
		return
	var body_host: Control = view["body_host"]
	var single_scroll: ScrollContainer = view["single_scroll"]
	var left_scroll: ScrollContainer = view["left_scroll"]
	var split_divider: ColorRect = view["split_divider"]
	var right_scroll: ScrollContainer = view["right_scroll"]

	var host_w := maxf(240.0, body_host.offset_right - body_host.offset_left)
	var host_h := maxf(120.0, body_host.offset_bottom - body_host.offset_top)
	var is_narrow := bool(view.get("narrow_mode", false))
	var selected_tab := str(view.get("selected_tab", "weapons"))

	var use_two_column := (not is_narrow) and (selected_tab != "weapons")
	if use_two_column:
		single_scroll.visible = false
		left_scroll.visible = true
		split_divider.visible = true
		right_scroll.visible = true
		var left_ratio := 0.36 if selected_tab == "mods" else 0.38
		var left_w := floorf(host_w * left_ratio)
		var div_x := left_w + 10.0
		var right_x := div_x + 11.0
		var right_w := maxf(240.0, host_w - right_x)
		_set_rect(left_scroll, Rect2(0.0, 0.0, left_w, host_h))
		_set_rect(split_divider, Rect2(div_x, 0.0, 1.0, host_h))
		_set_rect(right_scroll, Rect2(right_x, 0.0, right_w, host_h))
	else:
		single_scroll.visible = true
		left_scroll.visible = false
		split_divider.visible = false
		right_scroll.visible = false
		_set_rect(single_scroll, Rect2(0.0, 0.0, host_w, host_h))

	var weapons_grid: Variant = view.get("weapons_grid")
	if weapons_grid is GridContainer and is_instance_valid(weapons_grid):
		(weapons_grid as GridContainer).columns = 1 if is_narrow else 2

static func _on_tab_selected(view: Dictionary, tab_id: String) -> void:
	if str(view.get("selected_tab", "")) == tab_id:
		return
	view["selected_tab"] = tab_id
	_update_tab_styles(view)
	_render_active_tab(view, view.get("payload", {}))

static func _update_tab_styles(view: Dictionary) -> void:
	var tab_buttons: Dictionary = view.get("tab_buttons", {})
	var selected := str(view.get("selected_tab", "weapons"))
	for def: Dictionary in TAB_DEFS:
		var tid: String = str(def["id"])
		var btn: Button = tab_buttons.get(tid)
		if is_instance_valid(btn):
			_style_button(btn, "primary" if tid == selected else "neutral")

static func _update_header_meta(view: Dictionary, payload: Dictionary) -> void:
	var status_label: Label = view.get("status_label")
	if not is_instance_valid(status_label):
		return
	var gold := int(payload.get("gold", 0))
	var equipped_slots: Array = payload.get("equipped_slots", [])
	var filled := 0
	for s in equipped_slots:
		if not str(s).is_empty():
			filled += 1
	var mode_tag := "探索模式" if str(payload.get("mode", "")) == "explore" else "深海生存"
	status_label.text = "%s · 金币 %d · 随身武装 %d/%d" % [mode_tag, gold, mini(filled, MAX_EQUIP_SLOTS), MAX_EQUIP_SLOTS]

static func _ensure_valid_mod_weapon(view: Dictionary, payload: Dictionary) -> void:
	var owned: Array = payload.get("owned_weapons", [])
	var current := str(view.get("selected_mod_weapon", ""))
	if not current.is_empty() and owned.has(current):
		return
	var equipped: Array = payload.get("equipped_slots", [])
	for s in equipped:
		var wid := str(s)
		if not wid.is_empty() and owned.has(wid):
			view["selected_mod_weapon"] = wid
			return
	if not owned.is_empty():
		view["selected_mod_weapon"] = str(owned[0])
		return
	var catalog: Array = payload.get("weapons_catalog", [])
	if not catalog.is_empty():
		var first_entry: Dictionary = catalog[0] if catalog[0] is Dictionary else {}
		view["selected_mod_weapon"] = _weapon_id(first_entry)
	else:
		view["selected_mod_weapon"] = ""

static func _render_active_tab(view: Dictionary, payload: Dictionary) -> void:
	_update_tab_styles(view)
	var single_vbox: VBoxContainer = view["single_vbox"]
	var left_vbox: VBoxContainer = view["left_vbox"]
	var right_vbox: VBoxContainer = view["right_vbox"]
	var single_scroll: ScrollContainer = view["single_scroll"]
	var left_scroll: ScrollContainer = view["left_scroll"]
	var right_scroll: ScrollContainer = view["right_scroll"]

	var prev_single_y := single_scroll.scroll_vertical
	var prev_left_y := left_scroll.scroll_vertical
	var prev_right_y := right_scroll.scroll_vertical
	var same_tab := str(view.get("rendered_tab", "")) == str(view.get("selected_tab", "weapons"))

	_clear_children(single_vbox)
	_clear_children(left_vbox)
	_clear_children(right_vbox)
	view["weapons_grid"] = null

	var tab := str(view.get("selected_tab", "weapons"))
	var is_narrow := bool(view.get("narrow_mode", false))

	if tab == "weapons":
		_build_weapons_tab(view, payload, single_vbox, is_narrow)
	elif tab == "mods":
		if is_narrow:
			_build_mods_weapon_pane(view, payload, single_vbox, true)
			_build_mods_catalog_pane(view, payload, single_vbox, true)
		else:
			_build_mods_weapon_pane(view, payload, left_vbox, false)
			_build_mods_catalog_pane(view, payload, right_vbox, false)
	else:
		if is_narrow:
			_build_ultimate_pane(view, payload, single_vbox, true)
			_build_tactical_skills_pane(view, payload, single_vbox, true)
		else:
			_build_ultimate_pane(view, payload, left_vbox, false)
			_build_tactical_skills_pane(view, payload, right_vbox, false)

	view["rendered_version"] = int(payload.get("version", -1))
	view["rendered_tab"] = tab
	view["rendered_mod_weapon"] = str(view.get("selected_mod_weapon", ""))
	view["rendered_narrow"] = is_narrow
	view["rendered_touch"] = bool(view.get("touch_mode", false))

	refresh_layout(view)

	if same_tab:
		single_scroll.scroll_vertical = prev_single_y
		left_scroll.scroll_vertical = prev_left_y
		right_scroll.scroll_vertical = prev_right_y
	else:
		single_scroll.scroll_vertical = 0
		left_scroll.scroll_vertical = 0
		right_scroll.scroll_vertical = 0

# --- Tab 1: 武器装配与深铸 ---

static func _build_weapons_tab(view: Dictionary, payload: Dictionary, parent: VBoxContainer, is_narrow: bool) -> void:
	var callbacks: Dictionary = view.get("callbacks", {})
	var equipped_slots: Array = payload.get("equipped_slots", [])
	var owned_weapons: Array = payload.get("owned_weapons", [])
	var weapon_tiers: Dictionary = payload.get("weapon_tiers", {})
	var inventory: Dictionary = payload.get("inventory", {})
	var gold := int(payload.get("gold", 0))
	var weapons_catalog: Array = payload.get("weapons_catalog", [])
	var btn_h := _btn_height(view)

	var weapon_lookup: Dictionary = {}
	for raw_item in weapons_catalog:
		if raw_item is Dictionary:
			var wid := _weapon_id(raw_item)
			if not wid.is_empty():
				weapon_lookup[wid] = raw_item

	# Top 3 equipped slots strip
	var slots_panel := PanelContainer.new()
	slots_panel.name = "EquippedSlotsPanel"
	slots_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	slots_panel.add_theme_stylebox_override("panel", OceanUiTheme.surface(COLOR_BG_SUBPANEL, Color(COLOR_GOLD, 0.34), 3))
	parent.add_child(slots_panel)

	var slots_margin := _margin(slots_panel, 12, 12, 10, 10)
	var slots_outer := VBoxContainer.new()
	slots_outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots_outer.add_theme_constant_override("separation", 8)
	slots_outer.mouse_filter = Control.MOUSE_FILTER_PASS
	slots_margin.add_child(slots_outer)

	var slots_hdr := HBoxContainer.new()
	slots_hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots_hdr.add_theme_constant_override("separation", 8)
	slots_outer.add_child(slots_hdr)

	var slots_title := _flow_label(slots_hdr, "随身武器槽位（3 槽快速切换）", 14, COLOR_GOLD, false)
	slots_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var slots_hint := _flow_label(slots_hdr, "", 13, COLOR_MUTED, false)
	_set_hintable_text(slots_hint, "战斗中按 [1-3] 或快捷轮盘切换", callbacks)
	slots_hint.visible = not is_narrow

	var slot_grid := GridContainer.new()
	slot_grid.columns = 1 if is_narrow else MAX_EQUIP_SLOTS
	slot_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slot_grid.add_theme_constant_override("h_separation", 8)
	slot_grid.add_theme_constant_override("v_separation", 8)
	slots_outer.add_child(slot_grid)

	for slot_idx in range(MAX_EQUIP_SLOTS):
		var slot_wid := str(equipped_slots[slot_idx]) if slot_idx < equipped_slots.size() else ""
		var w_info: Dictionary = weapon_lookup.get(slot_wid, {})
		var slot_card := PanelContainer.new()
		slot_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_card.mouse_filter = Control.MOUSE_FILTER_PASS
		var has_w := not slot_wid.is_empty()
		slot_card.add_theme_stylebox_override(
			"panel",
			OceanUiTheme.surface(
				COLOR_BG_ITEM_SELECTED if has_w else COLOR_BG_ITEM,
				Color(COLOR_CYAN, 0.56) if has_w else Color(COLOR_CYAN, 0.18),
				3
			)
		)
		slot_grid.add_child(slot_card)

		var sm := _margin(slot_card, 10, 10, 8, 8)
		var sh := HBoxContainer.new()
		sh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sh.add_theme_constant_override("separation", 8)
		sm.add_child(sh)

		_pill_label(sh, "槽 %d" % (slot_idx + 1), COLOR_GOLD if has_w else COLOR_MUTED, Color(COLOR_GOLD if has_w else COLOR_MUTED, 0.16))

		var name_col := VBoxContainer.new()
		name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_col.add_theme_constant_override("separation", 2)
		sh.add_child(name_col)

		if has_w:
			var w_name := str(w_info.get("name", w_info.get("title", slot_wid)))
			var tier := clampi(int(weapon_tiers.get(slot_wid, w_info.get("tier", 1))), 1, MAX_WEAPON_TIER)
			var w_lbl := _flow_label(name_col, "%s · Lv.%d" % [w_name, tier], 15, COLOR_TEXT, false)
			w_lbl.clip_text = true
			var art_name := _weapon_art_name(w_info)
			if not art_name.is_empty():
				var sub_lbl := _flow_label(name_col, "战技：%s" % art_name, 12, COLOR_CYAN, false)
				sub_lbl.clip_text = true
		else:
			var empty_lbl := _flow_label(name_col, "空槽位 · 从下方选择武器装配", 14, COLOR_MUTED, false)
			empty_lbl.clip_text = true

	# Section header
	var arsenal_hdr := _flow_label(parent, "深海武器库与深铸强化（Lv.1 ~ Lv.5）", 15, COLOR_CYAN, false)
	arsenal_hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if weapons_catalog.is_empty():
		_add_empty_notice(parent, "暂无武器目录数据。")
		return

	var weapons_grid := GridContainer.new()
	weapons_grid.name = "WeaponsCatalogGrid"
	weapons_grid.columns = 1 if is_narrow else 2
	weapons_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapons_grid.add_theme_constant_override("h_separation", 10)
	weapons_grid.add_theme_constant_override("v_separation", 10)
	weapons_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(weapons_grid)
	view["weapons_grid"] = weapons_grid

	for raw_item in weapons_catalog:
		if not (raw_item is Dictionary):
			continue
		var weapon: Dictionary = raw_item
		var wid := _weapon_id(weapon)
		if wid.is_empty():
			continue
		var w_name := str(weapon.get("name", weapon.get("title", wid)))
		var w_role := str(weapon.get("role", weapon.get("archetype", weapon.get("category", ""))))
		var w_desc := str(weapon.get("desc", weapon.get("description", "")))
		var is_owned := bool(weapon.get("owned", owned_weapons.has(wid)))
		var max_tier := maxi(1, int(weapon.get("max_tier", MAX_WEAPON_TIER)))
		var tier := clampi(int(weapon_tiers.get(wid, weapon.get("tier", weapon.get("level", 1)))), 1, max_tier)
		var equipped_slot_idx := _find_equipped_slot(equipped_slots, wid)

		var card_panel := PanelContainer.new()
		card_panel.name = "WeaponCard_%s" % wid
		card_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_panel.mouse_filter = Control.MOUSE_FILTER_PASS
		var border_col := Color(COLOR_GOLD, 0.56) if equipped_slot_idx >= 0 else (Color(COLOR_CYAN, 0.30) if is_owned else Color(COLOR_MUTED, 0.22))
		var bg_col := COLOR_BG_ITEM_SELECTED if equipped_slot_idx >= 0 else (COLOR_BG_ITEM if is_owned else Color(0.035, 0.088, 0.132, 0.56))
		card_panel.add_theme_stylebox_override("panel", OceanUiTheme.surface(bg_col, border_col, 3))
		weapons_grid.add_child(card_panel)

		var cm := _margin(card_panel, 12, 12, 10, 10)
		var cv := VBoxContainer.new()
		cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cv.add_theme_constant_override("separation", 7)
		cv.mouse_filter = Control.MOUSE_FILTER_PASS
		cm.add_child(cv)

		# Title + pills
		var top_row := HBoxContainer.new()
		top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_row.add_theme_constant_override("separation", 6)
		cv.add_child(top_row)

		var name_lbl := _flow_label(top_row, w_name, 17, COLOR_TEXT if is_owned else COLOR_MUTED, false)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.clip_text = true

		if not w_role.is_empty():
			_pill_label(top_row, w_role, COLOR_CYAN, Color(COLOR_CYAN, 0.14))
		if is_owned:
			_pill_label(top_row, "Lv.%d/%d" % [tier, max_tier], COLOR_GOLD if tier >= max_tier else COLOR_DONE, Color(COLOR_GOLD if tier >= max_tier else COLOR_DONE, 0.16))
		else:
			_pill_label(top_row, "未拥有", COLOR_MUTED, Color(COLOR_MUTED, 0.14))
		if equipped_slot_idx >= 0:
			_pill_label(top_row, "槽 %d" % (equipped_slot_idx + 1), COLOR_GOLD, Color(COLOR_GOLD, 0.22))

		# Tier bar
		var bar := _make_progress_bar(cv, 5.0)
		_set_progress_bar(bar, float(tier) / float(max_tier) if is_owned else 0.0, COLOR_GOLD if tier >= max_tier else COLOR_CYAN)

		if not w_desc.is_empty():
			var desc_lbl := _flow_label(cv, w_desc, 13, COLOR_MUTED, true)
			desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# Weapon Art box
		var art_name := _weapon_art_name(weapon)
		var art_desc := _weapon_art_desc(weapon)
		var art_cd := _weapon_art_cd(weapon)
		if not art_name.is_empty() or not art_desc.is_empty():
			var art_box := PanelContainer.new()
			art_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			art_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			art_box.add_theme_stylebox_override("panel", OceanUiTheme.surface(Color(0.028, 0.095, 0.148, 0.72), Color(COLOR_CYAN, 0.24), 3))
			cv.add_child(art_box)

			var am := _margin(art_box, 10, 10, 6, 6)
			var av := VBoxContainer.new()
			av.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			av.add_theme_constant_override("separation", 3)
			am.add_child(av)

			var art_title := "专属战技 · %s" % (art_name if not art_name.is_empty() else "特殊技")
			if art_cd > 0.0:
				art_title += "（冷却 %.0fs）" % art_cd
			var art_hdr := _flow_label(av, art_title, 13, COLOR_CYAN, true)
			art_hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			if not art_desc.is_empty():
				var art_body := _flow_label(av, "", 13, COLOR_TEXT, true)
				art_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				_set_hintable_text(art_body, art_desc, callbacks)

		# Deep-forge material requirement summary
		var is_max := tier >= max_tier
		var cost_text := ""
		var can_upgrade := false
		if not is_owned:
			cost_text = "深铸条件：需先在制造台或深海探索解锁该武器"
			can_upgrade = false
		elif is_max:
			cost_text = "深铸强化：已达最高阶位 Lv.%d" % max_tier
			can_upgrade = false
		else:
			var cost_eval := _evaluate_upgrade_cost(weapon, inventory, gold)
			cost_text = "Lv.%d → Lv.%d 所需：%s" % [tier, tier + 1, str(cost_eval["text"])]
			if weapon.has("can_upgrade"):
				can_upgrade = bool(weapon["can_upgrade"]) and is_owned and not is_max
			else:
				can_upgrade = bool(cost_eval["affordable"])

		var mat_lbl := _flow_label(cv, cost_text, 13, COLOR_DONE if can_upgrade else (COLOR_GOLD if is_max else COLOR_MUTED), true)
		mat_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# Action buttons row: Slot 1 / 2 / 3 equip + Deep-forge upgrade
		var equip_row := HBoxContainer.new()
		equip_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		equip_row.add_theme_constant_override("separation", 6)
		cv.add_child(equip_row)

		for slot_idx in range(MAX_EQUIP_SLOTS):
			var is_in_this_slot := equipped_slot_idx == slot_idx
			var slot_btn := Button.new()
			slot_btn.text = "✓槽%d" % (slot_idx + 1) if is_in_this_slot else "装槽%d" % (slot_idx + 1)
			slot_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			slot_btn.custom_minimum_size = Vector2(0.0, btn_h)
			slot_btn.clip_text = true
			slot_btn.disabled = not is_owned
			slot_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			slot_btn.set_meta("_no_hint", true)
			_style_button(slot_btn, "cyan" if is_in_this_slot else "neutral")
			var target_slot := slot_idx
			var target_wid := wid
			slot_btn.pressed.connect(func() -> void:
				_invoke_callback_2(callbacks, "on_equip_slot", target_slot, target_wid)
			)
			equip_row.add_child(slot_btn)

		var upgrade_btn := Button.new()
		if not is_owned:
			upgrade_btn.text = "未解锁"
		elif is_max:
			upgrade_btn.text = "已满阶 Lv.%d" % max_tier
		else:
			upgrade_btn.text = "深铸至 Lv.%d" % (tier + 1)
		upgrade_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		upgrade_btn.custom_minimum_size = Vector2(0.0, btn_h)
		upgrade_btn.clip_text = true
		upgrade_btn.disabled = not can_upgrade
		upgrade_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		upgrade_btn.set_meta("_no_hint", true)
		_style_button(upgrade_btn, "primary" if can_upgrade else "neutral")
		var upg_wid := wid
		upgrade_btn.pressed.connect(func() -> void:
			_invoke_callback_1(callbacks, "on_upgrade_weapon", upg_wid)
		)
		cv.add_child(upgrade_btn)

# --- Tab 2: 战术模组 ---

static func _build_mods_weapon_pane(view: Dictionary, payload: Dictionary, parent: VBoxContainer, is_narrow: bool) -> void:
	var callbacks: Dictionary = view.get("callbacks", {})
	var owned_weapons: Array = payload.get("owned_weapons", [])
	var weapons_catalog: Array = payload.get("weapons_catalog", [])
	var weapon_mods: Dictionary = payload.get("weapon_mods", {})
	var mods_catalog: Array = payload.get("mods_catalog", [])
	var selected_wid := str(view.get("selected_mod_weapon", ""))
	var btn_h := _btn_height(view)

	var mod_lookup: Dictionary = {}
	for raw_mod in mods_catalog:
		if raw_mod is Dictionary:
			var mid := _mod_id(raw_mod)
			if not mid.is_empty():
				mod_lookup[mid] = raw_mod

	var picker_panel := PanelContainer.new()
	picker_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	picker_panel.add_theme_stylebox_override("panel", OceanUiTheme.surface(COLOR_BG_SUBPANEL, Color(COLOR_CYAN, 0.28), 3))
	parent.add_child(picker_panel)

	var pm := _margin(picker_panel, 12, 12, 10, 10)
	var pv := VBoxContainer.new()
	pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pv.add_theme_constant_override("separation", 8)
	pm.add_child(pv)

	_flow_label(pv, "选择已拥有武器", 15, COLOR_CYAN, false)

	var weapon_entries: Array[Dictionary] = []
	for raw_w in weapons_catalog:
		if raw_w is Dictionary:
			var wid := _weapon_id(raw_w)
			if not wid.is_empty() and (bool(raw_w.get("owned", false)) or owned_weapons.has(wid)):
				weapon_entries.append(raw_w)
	for wid_v in owned_weapons:
		var wid := str(wid_v)
		var found := false
		for we in weapon_entries:
			if _weapon_id(we) == wid:
				found = true
				break
		if not found and not wid.is_empty():
			weapon_entries.append({"id": wid, "name": wid, "owned": true})

	if weapon_entries.is_empty():
		_flow_label(pv, "当前尚未拥有可装配模组的武器。", 14, COLOR_MUTED, true)
	else:
		var w_grid := GridContainer.new()
		w_grid.columns = 2 if is_narrow else 1
		w_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		w_grid.add_theme_constant_override("h_separation", 6)
		w_grid.add_theme_constant_override("v_separation", 6)
		pv.add_child(w_grid)

		for we in weapon_entries:
			var wid := _weapon_id(we)
			var w_name := str(we.get("name", we.get("title", wid)))
			var installed: Array = weapon_mods.get(wid, [])
			var is_sel := wid == selected_wid
			var w_btn := Button.new()
			w_btn.text = "%s (%d/%d)" % [w_name, installed.size(), MAX_WEAPON_MODS]
			w_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			w_btn.custom_minimum_size = Vector2(0.0, btn_h)
			w_btn.clip_text = true
			w_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			w_btn.set_meta("_no_hint", true)
			_style_button(w_btn, "primary" if is_sel else "neutral")
			var target_wid := wid
			w_btn.pressed.connect(func() -> void:
				if str(view.get("selected_mod_weapon", "")) != target_wid:
					view["selected_mod_weapon"] = target_wid
					_render_active_tab(view, view.get("payload", {}))
			)
			w_grid.add_child(w_btn)

	# Selected weapon's 2 active mod slots card
	var slots_panel := PanelContainer.new()
	slots_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	slots_panel.add_theme_stylebox_override("panel", OceanUiTheme.surface(COLOR_BG_SUBPANEL, Color(COLOR_GOLD, 0.34), 3))
	parent.add_child(slots_panel)

	var sm := _margin(slots_panel, 12, 12, 10, 10)
	var sv := VBoxContainer.new()
	sv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sv.add_theme_constant_override("separation", 8)
	sm.add_child(sv)

	var installed_mods: Array = weapon_mods.get(selected_wid, []) if not selected_wid.is_empty() else []
	_flow_label(sv, "当前武器模组插槽（%d/%d）" % [installed_mods.size(), MAX_WEAPON_MODS], 15, COLOR_GOLD, false)

	for slot_idx in range(MAX_WEAPON_MODS):
		var slot_box := PanelContainer.new()
		slot_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_box.mouse_filter = Control.MOUSE_FILTER_PASS
		var has_mod := slot_idx < installed_mods.size() and not str(installed_mods[slot_idx]).is_empty()
		slot_box.add_theme_stylebox_override(
			"panel",
			OceanUiTheme.surface(COLOR_BG_ITEM_SELECTED if has_mod else COLOR_BG_ITEM, Color(COLOR_CYAN, 0.50) if has_mod else Color(COLOR_CYAN, 0.16), 3)
		)
		sv.add_child(slot_box)

		var bm := _margin(slot_box, 10, 10, 8, 8)
		var bh := HBoxContainer.new()
		bh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bh.add_theme_constant_override("separation", 8)
		bm.add_child(bh)

		_pill_label(bh, "插槽 %d" % (slot_idx + 1), COLOR_CYAN if has_mod else COLOR_MUTED, Color(COLOR_CYAN if has_mod else COLOR_MUTED, 0.16))

		if has_mod:
			var mid := str(installed_mods[slot_idx])
			var minfo: Dictionary = mod_lookup.get(mid, {})
			var mname := str(minfo.get("name", minfo.get("title", mid)))
			var m_lbl := _flow_label(bh, mname, 14, COLOR_TEXT, false)
			m_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			m_lbl.clip_text = true

			var unequip_btn := Button.new()
			unequip_btn.text = "卸下"
			unequip_btn.custom_minimum_size = Vector2(68.0, maxf(38.0, btn_h - 2.0))
			unequip_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			unequip_btn.set_meta("_no_hint", true)
			_style_button(unequip_btn, "subtle")
			var target_wid := selected_wid
			var target_mid := mid
			unequip_btn.pressed.connect(func() -> void:
				_invoke_callback_2(callbacks, "on_toggle_mod", target_wid, target_mid)
			)
			bh.add_child(unequip_btn)
		else:
			var empty_m := _flow_label(bh, "空插槽 · 从模组库装入", 13, COLOR_MUTED, false)
			empty_m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			empty_m.clip_text = true

static func _build_mods_catalog_pane(view: Dictionary, payload: Dictionary, parent: VBoxContainer, _is_narrow: bool) -> void:
	var callbacks: Dictionary = view.get("callbacks", {})
	var unlocked_mods: Array = payload.get("unlocked_mods", [])
	var weapon_mods: Dictionary = payload.get("weapon_mods", {})
	var mods_catalog: Array = payload.get("mods_catalog", [])
	var selected_wid := str(view.get("selected_mod_weapon", ""))
	var installed_mods: Array = weapon_mods.get(selected_wid, []) if not selected_wid.is_empty() else []
	var btn_h := _btn_height(view)

	_flow_label(parent, "战术模组库（每把武器最多装配 2 枚）", 15, COLOR_CYAN, false)

	if mods_catalog.is_empty():
		_add_empty_notice(parent, "暂无战术模组目录数据。")
		return

	for raw_mod in mods_catalog:
		if not (raw_mod is Dictionary):
			continue
		var mod_item: Dictionary = raw_mod
		var mid := _mod_id(mod_item)
		if mid.is_empty():
			continue
		var m_name := str(mod_item.get("name", mod_item.get("title", mid)))
		var m_cat := str(mod_item.get("category", mod_item.get("type", "通用")))
		var m_desc := str(mod_item.get("desc", mod_item.get("description", "")))
		var is_unlocked := bool(mod_item.get("unlocked", unlocked_mods.has(mid)))
		var is_equipped := installed_mods.has(mid)
		var slots_full := installed_mods.size() >= MAX_WEAPON_MODS and not is_equipped

		var card := PanelContainer.new()
		card.name = "ModCard_%s" % mid
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.mouse_filter = Control.MOUSE_FILTER_PASS
		var border := Color(COLOR_GOLD, 0.64) if is_equipped else (Color(COLOR_CYAN, 0.28) if is_unlocked else Color(COLOR_MUTED, 0.18))
		var bg := COLOR_BG_ITEM_SELECTED if is_equipped else (COLOR_BG_ITEM if is_unlocked else Color(0.032, 0.082, 0.125, 0.54))
		card.add_theme_stylebox_override("panel", OceanUiTheme.surface(bg, border, 3))
		parent.add_child(card)

		var cm := _margin(card, 12, 12, 10, 10)
		var cv := VBoxContainer.new()
		cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cv.add_theme_constant_override("separation", 6)
		cm.add_child(cv)

		var top_row := HBoxContainer.new()
		top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_row.add_theme_constant_override("separation", 6)
		cv.add_child(top_row)

		var title_lbl := _flow_label(top_row, m_name, 16, COLOR_TEXT if is_unlocked else COLOR_MUTED, false)
		title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_lbl.clip_text = true

		_pill_label(top_row, m_cat, COLOR_CYAN, Color(COLOR_CYAN, 0.14))
		if is_equipped:
			_pill_label(top_row, "已装配", COLOR_GOLD, Color(COLOR_GOLD, 0.20))
		elif is_unlocked:
			_pill_label(top_row, "已解锁", COLOR_DONE, Color(COLOR_DONE, 0.14))
		else:
			_pill_label(top_row, "未解锁", COLOR_MUTED, Color(COLOR_MUTED, 0.14))

		if not m_desc.is_empty():
			var desc_lbl := _flow_label(cv, "", 13, COLOR_TEXT if is_unlocked else COLOR_MUTED, true)
			desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_set_hintable_text(desc_lbl, m_desc, callbacks)

		var unlock_hint := str(mod_item.get("unlock_hint", mod_item.get("source", "")))
		if not is_unlocked and not unlock_hint.is_empty():
			var hint_lbl := _flow_label(cv, "解锁途径：%s" % unlock_hint, 12, COLOR_GOLD, true)
			hint_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var toggle_btn := Button.new()
		if selected_wid.is_empty():
			toggle_btn.text = "请先选择已拥有武器"
			toggle_btn.disabled = true
			_style_button(toggle_btn, "neutral")
		elif not is_unlocked:
			toggle_btn.text = "未解锁模组"
			toggle_btn.disabled = true
			_style_button(toggle_btn, "neutral")
		elif is_equipped:
			toggle_btn.text = "卸下此模组"
			toggle_btn.disabled = false
			_style_button(toggle_btn, "cyan")
		elif slots_full:
			toggle_btn.text = "槽位已满（%d/%d）" % [installed_mods.size(), MAX_WEAPON_MODS]
			toggle_btn.disabled = true
			_style_button(toggle_btn, "neutral")
		else:
			toggle_btn.text = "装入当前武器"
			toggle_btn.disabled = false
			_style_button(toggle_btn, "primary")

		toggle_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		toggle_btn.custom_minimum_size = Vector2(0.0, btn_h)
		toggle_btn.clip_text = true
		toggle_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		toggle_btn.set_meta("_no_hint", true)
		var target_wid := selected_wid
		var target_mid := mid
		toggle_btn.pressed.connect(func() -> void:
			_invoke_callback_2(callbacks, "on_toggle_mod", target_wid, target_mid)
		)
		cv.add_child(toggle_btn)

# --- Tab 3: 技能与终极共鸣 ---

static func _build_ultimate_pane(view: Dictionary, payload: Dictionary, parent: VBoxContainer, _is_narrow: bool) -> void:
	var callbacks: Dictionary = view.get("callbacks", {})
	var char_id := str(payload.get("character_id", CharacterRoster.DEFAULT_CHARACTER))
	var ult_info: Dictionary = payload.get("ultimate_info", {})
	var profile: Dictionary = CharacterRoster.PROFILES.get(char_id, {})
	var char_name := str(ult_info.get("character_name", profile.get("name", char_id)))
	var char_sub := str(profile.get("subtitle", ""))
	var accent: Color = profile.get("badge_color", COLOR_GOLD) if profile.get("badge_color") is Color else COLOR_GOLD

	var ult_card := PanelContainer.new()
	ult_card.name = "UltimateResonanceCard"
	ult_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ult_card.mouse_filter = Control.MOUSE_FILTER_PASS
	ult_card.add_theme_stylebox_override("panel", OceanUiTheme.surface(Color(0.055, 0.132, 0.185, 0.88), Color(COLOR_GOLD, 0.60), 4))
	parent.add_child(ult_card)

	var um := _margin(ult_card, 14, 14, 14, 14)
	var uv := VBoxContainer.new()
	uv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	uv.add_theme_constant_override("separation", 8)
	um.add_child(uv)

	var badge_row := HBoxContainer.new()
	badge_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	badge_row.add_theme_constant_override("separation", 6)
	uv.add_child(badge_row)

	_pill_label(badge_row, "潮汐终极技", COLOR_GOLD, Color(COLOR_GOLD, 0.22))
	_pill_label(badge_row, char_name, accent, Color(accent, 0.16))

	var ult_name := str(ult_info.get("name", "潮汐共鸣爆发"))
	var ult_title := _flow_label(uv, "【%s】" % ult_name, 20, COLOR_GOLD, true)
	ult_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if not char_sub.is_empty():
		var sub_lbl := _flow_label(uv, char_sub, 12, COLOR_MUTED, true)
		sub_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var ult_desc := str(ult_info.get("desc", ult_info.get("description", "攻击命中、完美闪避与击倒敌对生物时积累潮汐共鸣值，满 100% 时释放专属终极爆发。")))
	var desc_lbl := _flow_label(uv, "", 14, COLOR_TEXT, true)
	desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_set_hintable_text(desc_lbl, ult_desc, callbacks)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0.0, 1.0)
	divider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	divider.color = Color(COLOR_GOLD, 0.24)
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	uv.add_child(divider)

	var key_tip := _flow_label(uv, "", 13, COLOR_CYAN, true)
	key_tip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_set_hintable_text(key_tip, "共鸣值达 100% 时按 [~] 或触控金色脉冲按钮释放。", callbacks)

	# Active tactical skill summary box
	var active_skill_id := str(payload.get("active_tactical_skill", ""))
	var skills_catalog: Array = payload.get("skills_catalog", [])
	var active_skill: Dictionary = {}
	for raw_s in skills_catalog:
		if raw_s is Dictionary and _skill_id(raw_s) == active_skill_id:
			active_skill = raw_s
			break

	var cur_panel := PanelContainer.new()
	cur_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cur_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	cur_panel.add_theme_stylebox_override("panel", OceanUiTheme.surface(COLOR_BG_SUBPANEL, Color(COLOR_CYAN, 0.30), 3))
	parent.add_child(cur_panel)

	var cm := _margin(cur_panel, 12, 12, 10, 10)
	var cv := VBoxContainer.new()
	cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cv.add_theme_constant_override("separation", 5)
	cm.add_child(cv)

	_flow_label(cv, "当前装配主动战术技", 13, COLOR_CYAN, false)
	if active_skill.is_empty():
		_flow_label(cv, "尚未装配主动战术技，请从右侧列表单选。", 14, COLOR_MUTED, true)
	else:
		var sname := str(active_skill.get("name", active_skill.get("title", active_skill_id)))
		var scd := float(active_skill.get("cooldown", active_skill.get("cd", 0.0)))
		var sschool := str(active_skill.get("school", active_skill.get("branch", "")))
		var hdr_text := sname
		if not sschool.is_empty():
			hdr_text += " · %s" % sschool
		if scd > 0.0:
			hdr_text += " · 冷却 %.0fs" % scd
		_flow_label(cv, hdr_text, 15, COLOR_TEXT, true)
		var sdesc := str(active_skill.get("desc", active_skill.get("description", "")))
		if not sdesc.is_empty():
			var sdesc_lbl := _flow_label(cv, "", 13, COLOR_MUTED, true)
			_set_hintable_text(sdesc_lbl, sdesc, callbacks)

static func _build_tactical_skills_pane(view: Dictionary, payload: Dictionary, parent: VBoxContainer, _is_narrow: bool) -> void:
	var callbacks: Dictionary = view.get("callbacks", {})
	var active_skill_id := str(payload.get("active_tactical_skill", ""))
	var skills_catalog: Array = payload.get("skills_catalog", [])
	var btn_h := _btn_height(view)

	var hdr := _flow_label(parent, "", 15, COLOR_CYAN, true)
	_set_hintable_text(hdr, "主动战术技单选装配（战斗中按 [I] 触发）", callbacks)

	if skills_catalog.is_empty():
		_add_empty_notice(parent, "暂无主动战术技目录数据。")
		return

	# Group by school while preserving catalog order
	var school_order: Array[String] = []
	var grouped: Dictionary = {}
	for raw_s in skills_catalog:
		if not (raw_s is Dictionary):
			continue
		var s: Dictionary = raw_s
		var sid := _skill_id(s)
		if sid.is_empty():
			continue
		var school := str(s.get("school", s.get("branch", s.get("category", "通用战术"))))
		if not grouped.has(school):
			school_order.append(school)
			grouped[school] = []
		(grouped[school] as Array).append(s)

	for school: String in school_order:
		var school_color := _school_accent_color(school)
		var group_hdr := _flow_label(parent, "◆ %s" % school, 14, school_color, false)
		group_hdr.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var list: Array = grouped[school]
		for s: Dictionary in list:
			var sid := _skill_id(s)
			var sname := str(s.get("name", s.get("title", sid)))
			var scd := float(s.get("cooldown", s.get("cd", 0.0)))
			var sdesc := str(s.get("desc", s.get("description", "")))
			var is_active := sid == active_skill_id

			var card := PanelContainer.new()
			card.name = "TacticalSkillCard_%s" % sid
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			card.mouse_filter = Control.MOUSE_FILTER_PASS
			card.add_theme_stylebox_override(
				"panel",
				OceanUiTheme.surface(
					COLOR_BG_ITEM_SELECTED if is_active else COLOR_BG_ITEM,
					Color(COLOR_GOLD, 0.68) if is_active else Color(school_color, 0.30),
					3
				)
			)
			parent.add_child(card)

			var cm := _margin(card, 12, 12, 10, 10)
			var cv := VBoxContainer.new()
			cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cv.add_theme_constant_override("separation", 6)
			cm.add_child(cv)

			var top_row := HBoxContainer.new()
			top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			top_row.add_theme_constant_override("separation", 6)
			cv.add_child(top_row)

			var name_lbl := _flow_label(top_row, sname, 16, COLOR_GOLD if is_active else COLOR_TEXT, false)
			name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_lbl.clip_text = true

			_pill_label(top_row, school, school_color, Color(school_color, 0.16))
			if scd > 0.0:
				_pill_label(top_row, "CD %.0fs" % scd, COLOR_CYAN, Color(COLOR_CYAN, 0.14))
			if is_active:
				_pill_label(top_row, "已装配", COLOR_GOLD, Color(COLOR_GOLD, 0.22))

			if not sdesc.is_empty():
				var desc_lbl := _flow_label(cv, "", 13, COLOR_TEXT, true)
				desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				_set_hintable_text(desc_lbl, sdesc, callbacks)

			var select_btn := Button.new()
			select_btn.text = "当前已装配" if is_active else "装配此战术技"
			select_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			select_btn.custom_minimum_size = Vector2(0.0, btn_h)
			select_btn.clip_text = true
			select_btn.disabled = is_active
			select_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			select_btn.set_meta("_no_hint", true)
			_style_button(select_btn, "cyan" if is_active else "primary")
			var target_sid := sid
			select_btn.pressed.connect(func() -> void:
				_invoke_callback_1(callbacks, "on_select_tactical", target_sid)
			)
			cv.add_child(select_btn)

# --- Helpers ---

static func _btn_height(view: Dictionary) -> float:
	return 42.0 if bool(view.get("touch_mode", false)) else 40.0

static func _weapon_id(entry: Dictionary) -> String:
	return str(entry.get("id", entry.get("weapon_id", "")))

static func _mod_id(entry: Dictionary) -> String:
	return str(entry.get("id", entry.get("mod_id", "")))

static func _skill_id(entry: Dictionary) -> String:
	return str(entry.get("id", entry.get("skill_id", "")))

static func _weapon_art_name(weapon: Dictionary) -> String:
	var art = weapon.get("weapon_art")
	if art is Dictionary:
		return str(art.get("name", art.get("title", "")))
	if art is String and not (art as String).is_empty():
		return str(art)
	return str(weapon.get("weapon_art_name", weapon.get("art_name", "")))

static func _weapon_art_desc(weapon: Dictionary) -> String:
	var art = weapon.get("weapon_art")
	if art is Dictionary:
		return str(art.get("desc", art.get("description", "")))
	return str(weapon.get("weapon_art_desc", weapon.get("art_desc", "")))

static func _weapon_art_cd(weapon: Dictionary) -> float:
	var art = weapon.get("weapon_art")
	if art is Dictionary:
		return float(art.get("cooldown", art.get("cd", 0.0)))
	return float(weapon.get("weapon_art_cooldown", weapon.get("art_cooldown", weapon.get("art_cd", 0.0))))

static func _find_equipped_slot(equipped_slots: Array, weapon_id: String) -> int:
	for i in range(mini(equipped_slots.size(), MAX_EQUIP_SLOTS)):
		if str(equipped_slots[i]) == weapon_id:
			return i
	return -1

static func _evaluate_upgrade_cost(weapon: Dictionary, inventory: Dictionary, gold: int) -> Dictionary:
	var cost_val = weapon.get("upgrade_cost", weapon.get("next_cost", weapon.get("materials", {})))
	var extra_gold := int(weapon.get("upgrade_gold", weapon.get("gold_cost", 0)))
	if cost_val is String:
		var raw_str := str(cost_val).strip_edges()
		if extra_gold > 0:
			raw_str = ("%s · %d 金币" % [raw_str, extra_gold]) if not raw_str.is_empty() else ("%d 金币" % extra_gold)
		return {"text": raw_str if not raw_str.is_empty() else "无", "affordable": gold >= extra_gold}

	var parts: PackedStringArray = PackedStringArray()
	var affordable := true
	var gold_checked := false

	if cost_val is Dictionary:
		var cost_dict: Dictionary = cost_val
		for kind_v in cost_dict.keys():
			var kind := str(kind_v)
			var req := int(cost_dict[kind_v])
			if req <= 0:
				continue
			if kind == "gold":
				gold_checked = true
				if gold < req:
					affordable = false
				parts.append("金币 %d/%d" % [gold, req])
			else:
				var cur := int(inventory.get(kind, 0))
				if cur < req:
					affordable = false
				var label_name := str(ITEM_NAMES.get(kind, kind))
				parts.append("%s %d/%d" % [label_name, cur, req])

	if extra_gold > 0 and not gold_checked:
		if gold < extra_gold:
			affordable = false
		parts.append("金币 %d/%d" % [gold, extra_gold])

	if parts.is_empty():
		return {"text": "无额外材料", "affordable": true}
	return {"text": " · ".join(parts), "affordable": affordable}

static func _school_accent_color(school: String) -> Color:
	if "猎" in school or "攻" in school or "突" in school or "锋" in school:
		return COLOR_CORAL
	if "护" in school or "御" in school or "生" in school or "盾" in school or "愈" in school:
		return COLOR_DONE
	if "控" in school or "潮" in school or "声" in school or "电" in school or "科" in school:
		return COLOR_CYAN
	return COLOR_GOLD

static func _add_empty_notice(parent: Node, text: String) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", OceanUiTheme.surface(COLOR_BG_SUBPANEL, Color(COLOR_CYAN, 0.18), 3))
	parent.add_child(panel)
	var m := _margin(panel, 16, 16, 18, 18)
	_flow_label(m, text, 14, COLOR_MUTED, true)

static func _margin(parent: Node, left: int, right: int, top: int, bottom: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", left)
	m.add_theme_constant_override("margin_right", right)
	m.add_theme_constant_override("margin_top", top)
	m.add_theme_constant_override("margin_bottom", bottom)
	m.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(m)
	return m

static func _flow_label(parent: Node, text: String, font_size: int, color: Color, wrap: bool) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.set_meta("_no_hint", true)
	if wrap:
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(lbl)
	return lbl

static func _make_progress_bar(parent: Node, height: float) -> Dictionary:
	var track := Panel.new()
	track.custom_minimum_size = Vector2(40.0, height)
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_theme_stylebox_override("panel", OceanUiTheme.surface(Color(0.020, 0.065, 0.105, 0.92), Color(COLOR_CYAN, 0.22), 2))
	parent.add_child(track)

	var fill := ColorRect.new()
	fill.anchor_left = 0.0
	fill.anchor_top = 0.0
	fill.anchor_bottom = 1.0
	fill.anchor_right = 0.0
	fill.offset_left = 1.0
	fill.offset_top = 1.0
	fill.offset_right = -1.0
	fill.offset_bottom = -1.0
	fill.color = COLOR_CYAN
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(fill)

	return {"track": track, "fill": fill}

static func _set_progress_bar(bar: Dictionary, ratio: float, color: Color) -> void:
	var fill: ColorRect = bar.get("fill")
	if not is_instance_valid(fill):
		return
	var clamped := clampf(ratio, 0.0, 1.0)
	fill.anchor_right = clamped
	fill.offset_right = -1.0 if clamped > 0.01 else 0.0
	fill.visible = clamped > 0.001
	fill.color = color

static func _pill_label(parent: Node, text: String, fg: Color, bg: Color) -> Dictionary:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", OceanUiTheme.surface(bg, Color(fg, 0.45), 3))
	parent.add_child(panel)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 8)
	m.add_theme_constant_override("margin_right", 8)
	m.add_theme_constant_override("margin_top", 2)
	m.add_theme_constant_override("margin_bottom", 2)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(m)

	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", fg)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.set_meta("_no_hint", true)
	m.add_child(lbl)

	return {"panel": panel, "label": lbl}

static func _style_button(control: Button, variant: String = "neutral") -> void:
	control.add_theme_font_size_override("font_size", 14)
	if variant == "primary":
		control.add_theme_color_override("font_color", COLOR_GOLD)
		control.add_theme_color_override("font_hover_color", COLOR_INK)
		control.add_theme_color_override("font_pressed_color", COLOR_INK)
		control.add_theme_color_override("font_disabled_color", Color(COLOR_GOLD, 0.55))
		control.add_theme_stylebox_override("normal", OceanUiTheme.surface(Color(COLOR_GOLD, 0.14), Color(COLOR_GOLD, 0.72), 3))
		control.add_theme_stylebox_override("hover", OceanUiTheme.surface(COLOR_GOLD, Color(COLOR_GOLD, 0.95), 3))
		control.add_theme_stylebox_override("pressed", OceanUiTheme.surface(COLOR_GOLD.darkened(0.12), COLOR_CYAN, 3))
		control.add_theme_stylebox_override("disabled", OceanUiTheme.surface(Color(COLOR_GOLD, 0.08), Color(COLOR_GOLD, 0.28), 3))
	elif variant == "cyan":
		control.add_theme_color_override("font_color", COLOR_CYAN)
		control.add_theme_color_override("font_hover_color", COLOR_INK)
		control.add_theme_color_override("font_pressed_color", COLOR_INK)
		control.add_theme_color_override("font_disabled_color", Color(COLOR_CYAN, 0.72))
		control.add_theme_stylebox_override("normal", OceanUiTheme.surface(Color(COLOR_CYAN, 0.14), Color(COLOR_CYAN, 0.56), 3))
		control.add_theme_stylebox_override("hover", OceanUiTheme.surface(COLOR_CYAN, Color(COLOR_CYAN, 0.95), 3))
		control.add_theme_stylebox_override("pressed", OceanUiTheme.surface(COLOR_CYAN.darkened(0.12), COLOR_TEXT, 3))
		control.add_theme_stylebox_override("disabled", OceanUiTheme.surface(Color(COLOR_CYAN, 0.10), Color(COLOR_CYAN, 0.36), 3))
	elif variant == "subtle":
		control.add_theme_color_override("font_color", COLOR_CYAN)
		control.add_theme_color_override("font_hover_color", COLOR_INK)
		control.add_theme_color_override("font_pressed_color", COLOR_INK)
		control.add_theme_color_override("font_disabled_color", Color(COLOR_MUTED, 0.50))
		control.add_theme_stylebox_override("normal", OceanUiTheme.surface(Color(COLOR_CYAN, 0.10), Color(COLOR_CYAN, 0.42), 3))
		control.add_theme_stylebox_override("hover", OceanUiTheme.surface(COLOR_CYAN, Color(COLOR_CYAN, 0.90), 3))
		control.add_theme_stylebox_override("pressed", OceanUiTheme.surface(COLOR_GOLD, COLOR_GOLD, 3))
		control.add_theme_stylebox_override("disabled", OceanUiTheme.surface(Color(0.04, 0.09, 0.13, 0.40), Color(COLOR_MUTED, 0.15), 3))
	else:
		control.add_theme_color_override("font_color", COLOR_TEXT)
		control.add_theme_color_override("font_hover_color", Color.WHITE)
		control.add_theme_color_override("font_pressed_color", COLOR_TEXT)
		control.add_theme_color_override("font_disabled_color", Color(COLOR_MUTED, 0.55))
		control.add_theme_stylebox_override("normal", OceanUiTheme.surface(Color(0.045, 0.140, 0.205, 0.56), Color(COLOR_CYAN, 0.24), 3))
		control.add_theme_stylebox_override("hover", OceanUiTheme.surface(Color(0.090, 0.255, 0.340, 0.86), Color(COLOR_CYAN, 0.65), 3))
		control.add_theme_stylebox_override("pressed", OceanUiTheme.surface(COLOR_INK, COLOR_CYAN, 3))
		control.add_theme_stylebox_override("disabled", OceanUiTheme.surface(Color(0.04, 0.09, 0.13, 0.55), Color(COLOR_MUTED, 0.14), 3))
	control.add_theme_stylebox_override("focus", OceanUiTheme.surface(Color.TRANSPARENT, COLOR_TEXT, 3))

static func _clear_children(container: Node) -> void:
	if not is_instance_valid(container):
		return
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

static func _set_hintable_text(label: Label, raw_text: String, callbacks: Dictionary) -> void:
	label.set_meta("_hint_source", raw_text)
	var fmt = callbacks.get("format_text")
	if fmt is Callable and fmt.is_valid():
		var rendered := str(fmt.call(raw_text))
		label.text = rendered
		label.set_meta("_hint_rendered", rendered)
	else:
		label.text = raw_text
		label.set_meta("_hint_rendered", raw_text)
	label.set_meta("_hint_generation", -1)

static func _invoke_callback_0(callbacks: Dictionary, key: String) -> void:
	var cb = callbacks.get(key)
	if cb is Callable and cb.is_valid():
		cb.call()

static func _invoke_callback_1(callbacks: Dictionary, key: String, arg1: Variant) -> void:
	var cb = callbacks.get(key)
	if cb is Callable and cb.is_valid():
		cb.call(arg1)

static func _invoke_callback_2(callbacks: Dictionary, key: String, arg1: Variant, arg2: Variant) -> void:
	var cb = callbacks.get(key)
	if cb is Callable and cb.is_valid():
		cb.call(arg1, arg2)

static func _place(control: Control, parent: Node, rect: Rect2, anchor := Vector2.ZERO) -> void:
	parent.add_child(control)
	_set_rect(control, rect, anchor)

static func _set_rect(control: Control, rect: Rect2, anchor := Vector2.ZERO) -> void:
	control.anchor_left = anchor.x
	control.anchor_right = anchor.x
	control.anchor_top = anchor.y
	control.anchor_bottom = anchor.y
	control.offset_left = rect.position.x
	control.offset_top = rect.position.y
	control.offset_right = rect.end.x
	control.offset_bottom = rect.end.y

static func _label(parent: Node, text: String, rect: Rect2, font_size: int, color: Color, clip: bool = true, anchor := Vector2.ZERO) -> Label:
	var label := Label.new()
	_place(label, parent, rect, anchor)
	label.text = text
	label.add_theme_font_size_override("font_size", maxi(font_size, 14))
	label.clip_text = clip
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

static func _line(parent: Node, rect: Rect2, color: Color) -> ColorRect:
	var line := ColorRect.new()
	_place(line, parent, rect)
	line.color = color
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line

static func _button(parent: Node, text: String, rect: Rect2, callback: Callable, variant: String = "neutral") -> Button:
	var button := Button.new()
	_place(button, parent, rect)
	button.text = text
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style_button(button, variant)
	button.pressed.connect(callback)
	return button
