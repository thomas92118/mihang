extends RefCounted
## Ocean-glass expedition mission log & quest journal panel ("quests" screen).

const OceanUiTheme = preload("res://scripts/presentation/ocean_ui_theme.gd")

const COLOR_BG_CARD := Color(0.02745, 0.08235, 0.12941, 0.94)
const COLOR_BG_SUBPANEL := Color(0.03922, 0.10980, 0.16863, 0.78)
const COLOR_BG_ITEM := Color(0.04706, 0.12549, 0.19216, 0.68)
const COLOR_BG_ITEM_HOVER := Color(0.06667, 0.17255, 0.25490, 0.84)
const COLOR_BG_ITEM_SELECTED := Color(0.07843, 0.21569, 0.30588, 0.90)
const COLOR_CYAN := Color("4bbbd4")
const COLOR_GOLD := Color("efb25b")
const COLOR_TEXT := Color("eaf6fa")
const COLOR_MUTED := Color("8fb0be")
const COLOR_DONE := Color("63e0b8")
const COLOR_INK := Color("071521")

const TAB_DEFS := [
	{"id": "main", "label": "主线航程", "short_label": "主线"},
	{"id": "side", "label": "科考支线", "short_label": "支线"},
	{"id": "bounty", "label": "回波委托", "short_label": "委托"},
	{"id": "completed", "label": "已完成", "short_label": "已完成"},
]

const BOUNTY_LOCKED_TEXT := "激活任意 1 座远洋科考前哨站后开启回波委托"

static func build(menu_root: Control, callbacks: Dictionary = {}) -> Dictionary:
	var view: Dictionary = {
		"touch_mode": false,
		"avail_size": Vector2(960.0, 700.0),
		"narrow_mode": false,
		"rendered_version": -1,
		"rendered_tab": "",
		"rendered_quest_id": "",
		"rendered_tracked_quest_id": "",
		"rendered_tracked_objective_id": "",
		"rendered_tracker_hidden": false,
		"rendered_bounties_unlocked": false,
		"selected_tab": "main",
		"selected_quest_id": "",
		"has_initialized_selection": false,
		"payload": {},
		"callbacks": callbacks,
		"objective_distance_labels": {},
		"list_card_entries": [],
	}

	var card := Panel.new()
	card.name = "QuestLogCard"
	_place(card, menu_root, Rect2(0.0, 0.0, 960.0, 700.0))
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_theme_stylebox_override("panel", OceanUiTheme.surface(COLOR_BG_CARD, Color(COLOR_CYAN, 0.34), 4))

	# Header
	var accent_line := _line(card, Rect2(26.0, 26.0, 30.0, 2.0), COLOR_GOLD)
	var eyebrow := _label(card, "ABYSSAL MISSION LOG  /  深海科考日志", Rect2(66.0, 16.0, 480.0, 22.0), 14, COLOR_CYAN)
	eyebrow.set_meta("_no_hint", true)

	var main_title := _label(card, "潜航任务日志", Rect2(26.0, 42.0, 360.0, 38.0), 26, COLOR_TEXT)
	main_title.set_meta("_no_hint", true)

	var rank_label := _label(card, "深海见习勘测员 · 勘测 0%", Rect2(420.0, 48.0, 412.0, 24.0), 14, COLOR_GOLD)
	rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rank_label.set_meta("_no_hint", true)

	var close_btn := _button(card, "关闭", Rect2(848.0, 20.0, 86.0, 42.0), func() -> void:
		_invoke_callback_0(callbacks, "on_close")
	, "neutral")
	close_btn.name = "QuestCloseButton"
	close_btn.custom_minimum_size = Vector2(78.0, 42.0)
	close_btn.set_meta("_no_hint", true)

	var header_divider := _line(card, Rect2(26.0, 88.0, 908.0, 1.0), Color(COLOR_CYAN, 0.22))

	# Category tab bar
	var tab_bar := Control.new()
	tab_bar.name = "QuestTabBar"
	_place(tab_bar, card, Rect2(26.0, 96.0, 908.0, 44.0))
	tab_bar.mouse_filter = Control.MOUSE_FILTER_PASS

	var tab_buttons: Dictionary = {}
	for i in range(TAB_DEFS.size()):
		var def: Dictionary = TAB_DEFS[i]
		var tab_id: String = str(def["id"])
		var btn := _button(tab_bar, "%s (0)" % str(def["label"]), Rect2(float(i) * 228.0, 0.0, 220.0, 42.0), func() -> void:
			_on_tab_selected(view, tab_id)
		, "primary" if i == 0 else "neutral")
		btn.name = "QuestTab_%s" % tab_id
		btn.custom_minimum_size = Vector2(0.0, 40.0)
		btn.clip_text = true
		btn.set_meta("_no_hint", true)
		tab_buttons[tab_id] = btn

	var tab_divider := _line(card, Rect2(26.0, 146.0, 908.0, 1.0), Color(COLOR_CYAN, 0.16))

	# Bounty sub-bar (visible only on "bounty" tab)
	var bounty_bar := Panel.new()
	bounty_bar.name = "QuestBountyBar"
	_place(bounty_bar, card, Rect2(26.0, 154.0, 908.0, 50.0))
	bounty_bar.mouse_filter = Control.MOUSE_FILTER_PASS
	bounty_bar.add_theme_stylebox_override("panel", OceanUiTheme.surface(COLOR_BG_SUBPANEL, Color(COLOR_GOLD, 0.34), 3))
	bounty_bar.visible = false

	var bounty_info_label := _label(bounty_bar, BOUNTY_LOCKED_TEXT, Rect2(14.0, 12.0, 720.0, 26.0), 14, COLOR_GOLD, false)
	bounty_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bounty_info_label.set_meta("_no_hint", true)

	var refresh_bounties_btn := _button(bounty_bar, "刷新委托", Rect2(768.0, 5.0, 126.0, 40.0), func() -> void:
		_invoke_callback_0(callbacks, "on_refresh_bounties")
	, "cyan")
	refresh_bounties_btn.name = "QuestRefreshBountiesButton"
	refresh_bounties_btn.custom_minimum_size = Vector2(110.0, 40.0)
	refresh_bounties_btn.set_meta("_no_hint", true)

	# Left pane: quest list
	var list_scroll := ScrollContainer.new()
	list_scroll.name = "QuestListScroll"
	_place(list_scroll, card, Rect2(26.0, 156.0, 326.0, 518.0))
	list_scroll.follow_focus = true
	list_scroll.scroll_deadzone = 8
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	list_scroll.mouse_filter = Control.MOUSE_FILTER_PASS

	var list_vbox := VBoxContainer.new()
	list_vbox.name = "QuestListVBox"
	list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	list_vbox.add_theme_constant_override("separation", 8)
	list_scroll.add_child(list_vbox)

	# Split divider (vertical on desktop, horizontal on narrow screens)
	var split_divider := _line(card, Rect2(362.0, 156.0, 1.0, 518.0), Color(COLOR_CYAN, 0.18))

	# Right pane container: detail scroll + bottom action bar
	var detail_pane := Control.new()
	detail_pane.name = "QuestDetailPane"
	_place(detail_pane, card, Rect2(374.0, 156.0, 560.0, 518.0))
	detail_pane.mouse_filter = Control.MOUSE_FILTER_PASS

	var detail_scroll := ScrollContainer.new()
	detail_scroll.name = "QuestDetailScroll"
	_place(detail_scroll, detail_pane, Rect2(0.0, 0.0, 560.0, 456.0))
	detail_scroll.follow_focus = true
	detail_scroll.scroll_deadzone = 10
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	detail_scroll.mouse_filter = Control.MOUSE_FILTER_PASS

	var detail_vbox := VBoxContainer.new()
	detail_vbox.name = "QuestDetailVBox"
	detail_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	detail_vbox.add_theme_constant_override("separation", 10)
	detail_scroll.add_child(detail_vbox)

	# Empty detail placeholder (inside detail_vbox when no quest selected)
	var detail_empty_panel := PanelContainer.new()
	detail_empty_panel.name = "QuestDetailEmptyPanel"
	detail_empty_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_empty_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_empty_panel.add_theme_stylebox_override("panel", OceanUiTheme.surface(COLOR_BG_SUBPANEL, Color(COLOR_CYAN, 0.18), 3))
	var empty_margin := MarginContainer.new()
	empty_margin.add_theme_constant_override("margin_left", 18)
	empty_margin.add_theme_constant_override("margin_right", 18)
	empty_margin.add_theme_constant_override("margin_top", 22)
	empty_margin.add_theme_constant_override("margin_bottom", 22)
	detail_empty_panel.add_child(empty_margin)
	var detail_empty_label := Label.new()
	detail_empty_label.text = "当前分类暂无可查看的潜航任务。"
	detail_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_empty_label.add_theme_font_size_override("font_size", 15)
	detail_empty_label.add_theme_color_override("font_color", COLOR_MUTED)
	detail_empty_label.set_meta("_no_hint", true)
	empty_margin.add_child(detail_empty_label)
	detail_vbox.add_child(detail_empty_panel)

	# Detail content container (visible when a quest is selected)
	var detail_body_vbox := VBoxContainer.new()
	detail_body_vbox.name = "QuestDetailBodyVBox"
	detail_body_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_body_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	detail_body_vbox.add_theme_constant_override("separation", 10)
	detail_body_vbox.visible = false
	detail_vbox.add_child(detail_body_vbox)

	# 1) Detail Header Card
	var detail_header_panel := PanelContainer.new()
	detail_header_panel.name = "QuestDetailHeader"
	detail_header_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_header_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_header_panel.add_theme_stylebox_override("panel", OceanUiTheme.surface(COLOR_BG_SUBPANEL, Color(COLOR_CYAN, 0.24), 3))
	detail_body_vbox.add_child(detail_header_panel)

	var hdr_margin := MarginContainer.new()
	hdr_margin.add_theme_constant_override("margin_left", 14)
	hdr_margin.add_theme_constant_override("margin_right", 14)
	hdr_margin.add_theme_constant_override("margin_top", 12)
	hdr_margin.add_theme_constant_override("margin_bottom", 12)
	hdr_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_header_panel.add_child(hdr_margin)

	var hdr_vbox := VBoxContainer.new()
	hdr_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_vbox.add_theme_constant_override("separation", 8)
	hdr_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hdr_margin.add_child(hdr_vbox)

	var badge_row := HBoxContainer.new()
	badge_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	badge_row.add_theme_constant_override("separation", 8)
	badge_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hdr_vbox.add_child(badge_row)

	var detail_act_badge := _pill_label(badge_row, "主线航程", COLOR_CYAN, Color(COLOR_CYAN, 0.14))
	var detail_status_badge := _pill_label(badge_row, "进行中", COLOR_GOLD, Color(COLOR_GOLD, 0.16))

	var badge_spacer := Control.new()
	badge_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	badge_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_row.add_child(badge_spacer)

	var detail_progress_label := Label.new()
	detail_progress_label.text = "0/0"
	detail_progress_label.add_theme_font_size_override("font_size", 14)
	detail_progress_label.add_theme_color_override("font_color", COLOR_CYAN)
	detail_progress_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_progress_label.set_meta("_no_hint", true)
	badge_row.add_child(detail_progress_label)

	var detail_title_label := Label.new()
	detail_title_label.text = ""
	detail_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_title_label.add_theme_font_size_override("font_size", 21)
	detail_title_label.add_theme_color_override("font_color", COLOR_TEXT)
	detail_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_title_label.set_meta("_no_hint", true)
	hdr_vbox.add_child(detail_title_label)

	var detail_progress_bar := _make_progress_bar(hdr_vbox, 7.0)

	# 2) Mission Brief Card
	var brief_panel := PanelContainer.new()
	brief_panel.name = "QuestBriefPanel"
	brief_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brief_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brief_panel.add_theme_stylebox_override("panel", OceanUiTheme.surface(COLOR_BG_ITEM, Color(COLOR_CYAN, 0.14), 3))
	detail_body_vbox.add_child(brief_panel)

	var brief_margin := MarginContainer.new()
	brief_margin.add_theme_constant_override("margin_left", 14)
	brief_margin.add_theme_constant_override("margin_right", 14)
	brief_margin.add_theme_constant_override("margin_top", 10)
	brief_margin.add_theme_constant_override("margin_bottom", 10)
	brief_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brief_panel.add_child(brief_margin)

	var brief_vbox := VBoxContainer.new()
	brief_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brief_vbox.add_theme_constant_override("separation", 4)
	brief_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brief_margin.add_child(brief_vbox)

	var brief_heading := Label.new()
	brief_heading.text = "科考简报"
	brief_heading.add_theme_font_size_override("font_size", 14)
	brief_heading.add_theme_color_override("font_color", COLOR_CYAN)
	brief_heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brief_heading.set_meta("_no_hint", true)
	brief_vbox.add_child(brief_heading)

	var detail_brief_label := Label.new()
	detail_brief_label.text = ""
	detail_brief_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_brief_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_brief_label.add_theme_font_size_override("font_size", 14)
	detail_brief_label.add_theme_color_override("font_color", COLOR_TEXT)
	detail_brief_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brief_vbox.add_child(detail_brief_label)

	# 3) Objectives Section
	var obj_heading := Label.new()
	obj_heading.text = "任务目标"
	obj_heading.add_theme_font_size_override("font_size", 14)
	obj_heading.add_theme_color_override("font_color", COLOR_CYAN)
	obj_heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	obj_heading.set_meta("_no_hint", true)
	detail_body_vbox.add_child(obj_heading)

	var objectives_vbox := VBoxContainer.new()
	objectives_vbox.name = "QuestObjectivesVBox"
	objectives_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	objectives_vbox.add_theme_constant_override("separation", 6)
	objectives_vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	detail_body_vbox.add_child(objectives_vbox)

	# 4) Rewards Summary Bar
	var reward_panel := PanelContainer.new()
	reward_panel.name = "QuestRewardPanel"
	reward_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reward_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_panel.add_theme_stylebox_override("panel", OceanUiTheme.surface(Color(0.066, 0.130, 0.160, 0.72), Color(COLOR_GOLD, 0.36), 3))
	detail_body_vbox.add_child(reward_panel)

	var reward_margin := MarginContainer.new()
	reward_margin.add_theme_constant_override("margin_left", 14)
	reward_margin.add_theme_constant_override("margin_right", 14)
	reward_margin.add_theme_constant_override("margin_top", 9)
	reward_margin.add_theme_constant_override("margin_bottom", 9)
	reward_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_panel.add_child(reward_margin)

	var reward_vbox := VBoxContainer.new()
	reward_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reward_vbox.add_theme_constant_override("separation", 3)
	reward_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_margin.add_child(reward_vbox)

	var reward_heading := Label.new()
	reward_heading.text = "任务奖励"
	reward_heading.add_theme_font_size_override("font_size", 14)
	reward_heading.add_theme_color_override("font_color", COLOR_GOLD)
	reward_heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reward_heading.set_meta("_no_hint", true)
	reward_vbox.add_child(reward_heading)

	var detail_reward_label := Label.new()
	detail_reward_label.text = ""
	detail_reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_reward_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_reward_label.add_theme_font_size_override("font_size", 14)
	detail_reward_label.add_theme_color_override("font_color", COLOR_TEXT)
	detail_reward_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_reward_label.set_meta("_no_hint", true)
	reward_vbox.add_child(detail_reward_label)

	# 5) Detail Bottom Action Bar
	var action_divider := _line(detail_pane, Rect2(0.0, 464.0, 560.0, 1.0), Color(COLOR_CYAN, 0.18))
	var action_bar := Control.new()
	action_bar.name = "QuestActionBar"
	_place(action_bar, detail_pane, Rect2(0.0, 472.0, 560.0, 46.0))
	action_bar.mouse_filter = Control.MOUSE_FILTER_PASS

	var track_btn := _button(action_bar, "设为追踪", Rect2(0.0, 0.0, 134.0, 42.0), func() -> void:
		var q_id: String = str(view.get("selected_quest_id", ""))
		if not q_id.is_empty():
			_invoke_callback_2(callbacks, "on_track", q_id, "")
	, "primary")
	track_btn.name = "QuestTrackButton"
	track_btn.custom_minimum_size = Vector2(0.0, 40.0)
	track_btn.clip_text = true
	track_btn.set_meta("_no_hint", true)

	var toggle_tracker_btn := _button(action_bar, "隐藏 HUD 追踪", Rect2(142.0, 0.0, 146.0, 42.0), func() -> void:
		_invoke_callback_0(callbacks, "on_toggle_tracker")
	, "neutral")
	toggle_tracker_btn.name = "QuestToggleTrackerButton"
	toggle_tracker_btn.custom_minimum_size = Vector2(0.0, 40.0)
	toggle_tracker_btn.clip_text = true
	toggle_tracker_btn.set_meta("_no_hint", true)

	var nav_btn := _button(action_bar, "海图定位", Rect2(296.0, 0.0, 126.0, 42.0), func() -> void:
		var q: Dictionary = _find_selected_quest(view)
		if q.is_empty() or not bool(q.get("primary_nav_available", false)):
			return
		var pos_v = q.get("primary_nav_pos", Vector3.ZERO)
		var nav_pos: Vector3 = pos_v if pos_v is Vector3 else Vector3.ZERO
		var nav_label: String = str(q.get("primary_nav_label", q.get("title", "")))
		_invoke_callback_3(callbacks, "on_navigate", nav_pos, nav_label, true)
	, "cyan")
	nav_btn.name = "QuestNavigateButton"
	nav_btn.custom_minimum_size = Vector2(0.0, 40.0)
	nav_btn.clip_text = true
	nav_btn.set_meta("_no_hint", true)

	var pin_recipe_btn := _button(action_bar, "追踪配方", Rect2(430.0, 0.0, 126.0, 42.0), func() -> void:
		var q: Dictionary = _find_selected_quest(view)
		if q.is_empty():
			return
		var recipe_id: String = _resolve_recipe_hint(q)
		if not recipe_id.is_empty():
			_invoke_callback_1(callbacks, "on_pin_recipe", recipe_id)
	, "cyan")
	pin_recipe_btn.name = "QuestPinRecipeButton"
	pin_recipe_btn.custom_minimum_size = Vector2(0.0, 40.0)
	pin_recipe_btn.clip_text = true
	pin_recipe_btn.set_meta("_no_hint", true)

	view["card"] = card
	view["close_btn"] = close_btn
	view["accent_line"] = accent_line
	view["eyebrow"] = eyebrow
	view["main_title"] = main_title
	view["rank_label"] = rank_label
	view["header_divider"] = header_divider
	view["tab_bar"] = tab_bar
	view["tab_buttons"] = tab_buttons
	view["tab_divider"] = tab_divider
	view["bounty_bar"] = bounty_bar
	view["bounty_info_label"] = bounty_info_label
	view["refresh_bounties_btn"] = refresh_bounties_btn
	view["list_scroll"] = list_scroll
	view["list_vbox"] = list_vbox
	view["split_divider"] = split_divider
	view["detail_pane"] = detail_pane
	view["detail_scroll"] = detail_scroll
	view["detail_vbox"] = detail_vbox
	view["detail_empty_panel"] = detail_empty_panel
	view["detail_empty_label"] = detail_empty_label
	view["detail_body_vbox"] = detail_body_vbox
	view["detail_act_badge"] = detail_act_badge
	view["detail_status_badge"] = detail_status_badge
	view["detail_progress_label"] = detail_progress_label
	view["detail_title_label"] = detail_title_label
	view["detail_progress_bar"] = detail_progress_bar
	view["detail_brief_label"] = detail_brief_label
	view["objectives_vbox"] = objectives_vbox
	view["reward_panel"] = reward_panel
	view["detail_reward_label"] = detail_reward_label
	view["action_divider"] = action_divider
	view["action_bar"] = action_bar
	view["track_btn"] = track_btn
	view["toggle_tracker_btn"] = toggle_tracker_btn
	view["nav_btn"] = nav_btn
	view["pin_recipe_btn"] = pin_recipe_btn

	set_responsive_layout(view, Vector2(960.0, 700.0))
	return view

static func update_data(view: Dictionary, payload: Dictionary) -> void:
	if view.is_empty() or not is_instance_valid(view.get("card")):
		return
	view["payload"] = payload
	_update_header_meta(view, payload)

	var incoming_version := int(payload.get("version", -1))
	var rendered_version := int(view.get("rendered_version", -1))
	var current_tab := str(view.get("selected_tab", "main"))
	var current_quest := str(view.get("selected_quest_id", ""))
	var tracked_quest_id := str(payload.get("tracked_quest_id", ""))
	var tracked_objective_id := str(payload.get("tracked_objective_id", ""))
	var tracker_hidden := bool(payload.get("tracker_hidden", false))
	var bounties_unlocked := bool(payload.get("bounties_unlocked", false))

	var same_version := incoming_version >= 0 and incoming_version == rendered_version
	var same_state := (
		same_version
		and current_tab == str(view.get("rendered_tab", ""))
		and current_quest == str(view.get("rendered_quest_id", ""))
		and tracked_quest_id == str(view.get("rendered_tracked_quest_id", ""))
		and tracked_objective_id == str(view.get("rendered_tracked_objective_id", ""))
		and tracker_hidden == bool(view.get("rendered_tracker_hidden", false))
		and bounties_unlocked == bool(view.get("rendered_bounties_unlocked", false))
	)
	if same_state:
		_refresh_live_distances(view, payload)
		return

	_ensure_valid_selection(view, payload)
	_render_all(view, payload)

static func set_responsive_layout(view: Dictionary, avail_size: Vector2) -> void:
	if view.is_empty() or not is_instance_valid(view.get("card")):
		return
	var clamped_avail := Vector2(maxf(300.0, avail_size.x), maxf(260.0, avail_size.y))
	view["avail_size"] = clamped_avail
	var is_narrow := clamped_avail.x < 720.0
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
	var rank_label: Label = view["rank_label"]
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
			rank_label.visible = true
			_set_rect(rank_label, Rect2(pad, 40.0, maxf(120.0, inner_w - close_w - 8.0), 20.0))
			rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			header_bottom = 64.0
		else:
			_set_rect(accent_line, Rect2(pad, 18.0, 24.0, 2.0))
			eyebrow.text = "MISSION LOG  /  深海科考日志"
			eyebrow.add_theme_font_size_override("font_size", 12)
			_set_rect(eyebrow, Rect2(pad + 32.0, 8.0, maxf(120.0, inner_w - close_w - 40.0), 20.0))
			_set_rect(main_title, Rect2(pad, 28.0, maxf(120.0, inner_w - close_w - 8.0), 30.0))
			main_title.add_theme_font_size_override("font_size", 22)
			rank_label.visible = true
			_set_rect(rank_label, Rect2(pad, 60.0, inner_w, 22.0))
			rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			header_bottom = 86.0
	else:
		accent_line.visible = true
		eyebrow.visible = true
		rank_label.visible = true
		eyebrow.text = "ABYSSAL MISSION LOG  /  深海科考日志"
		eyebrow.add_theme_font_size_override("font_size", 14)
		_set_rect(accent_line, Rect2(pad, 26.0, 30.0, 2.0))
		var left_hdr_w := floorf((inner_w - close_w - 16.0) * 0.50)
		var right_hdr_x := pad + left_hdr_w + 8.0
		var right_hdr_w := maxf(140.0, card_w - pad - close_w - 14.0 - right_hdr_x)
		_set_rect(eyebrow, Rect2(pad + 40.0, 16.0, maxf(160.0, inner_w - close_w - 52.0), 22.0))
		_set_rect(main_title, Rect2(pad, 42.0, left_hdr_w, 38.0))
		main_title.add_theme_font_size_override("font_size", 26)
		_set_rect(rank_label, Rect2(right_hdr_x, 48.0, right_hdr_w, 26.0))
		rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		header_bottom = 88.0

	_set_rect(header_divider, Rect2(pad, header_bottom, inner_w, 1.0))

	# Tab bar layout
	var tab_bar: Control = view["tab_bar"]
	var tab_buttons: Dictionary = view["tab_buttons"]
	var tab_divider: ColorRect = view["tab_divider"]
	var tab_top := header_bottom + 8.0
	var two_row_tabs := inner_w < 420.0
	var tab_h := btn_h
	var tab_bar_h := (tab_h * 2.0 + 6.0) if two_row_tabs else tab_h
	_set_rect(tab_bar, Rect2(pad, tab_top, inner_w, tab_bar_h))

	var gap_t := 8.0 if not is_narrow else 6.0
	if two_row_tabs:
		var col_w := floorf((inner_w - gap_t) * 0.5)
		for i in range(TAB_DEFS.size()):
			var tid: String = str(TAB_DEFS[i]["id"])
			var tb: Button = tab_buttons[tid]
			var col := i % 2
			var row := i >> 1
			var x := float(col) * (col_w + gap_t)
			var w := col_w if col == 0 else maxf(80.0, inner_w - x)
			var y := float(row) * (tab_h + 6.0)
			_set_rect(tb, Rect2(x, y, w, tab_h))
			tb.custom_minimum_size = Vector2(w, tab_h)
	else:
		var count := float(TAB_DEFS.size())
		var col_w := floorf((inner_w - gap_t * (count - 1.0)) / count)
		for i in range(TAB_DEFS.size()):
			var tid: String = str(TAB_DEFS[i]["id"])
			var tb: Button = tab_buttons[tid]
			var x := float(i) * (col_w + gap_t)
			var w := col_w if i < TAB_DEFS.size() - 1 else maxf(70.0, inner_w - x)
			_set_rect(tb, Rect2(x, 0.0, w, tab_h))
			tb.custom_minimum_size = Vector2(w, tab_h)

	_update_tab_labels(view, view.get("payload", {}))

	var tab_div_y := tab_top + tab_bar_h + 8.0
	_set_rect(tab_divider, Rect2(pad, tab_div_y, inner_w, 1.0))

	# Optional bounty bar
	var bounty_bar: Panel = view["bounty_bar"]
	var bounty_info_label: Label = view["bounty_info_label"]
	var refresh_bounties_btn: Button = view["refresh_bounties_btn"]
	var content_top := tab_div_y + 10.0
	if bounty_bar.visible:
		var show_refresh := refresh_bounties_btn.visible
		var rbtn_w := 116.0 if is_narrow else 128.0
		var info_w := maxf(120.0, inner_w - 28.0 - (rbtn_w + 10.0 if show_refresh else 0.0))
		var info_h := _measure_multiline_height(bounty_info_label, bounty_info_label.text, info_w, 14, 24.0, 6.0)
		var bar_h := maxf(btn_h + 10.0, info_h + 16.0)
		_set_rect(bounty_bar, Rect2(pad, content_top, inner_w, bar_h))
		_set_rect(bounty_info_label, Rect2(14.0, floorf((bar_h - info_h) * 0.5), info_w, info_h))
		if show_refresh:
			_set_rect(refresh_bounties_btn, Rect2(inner_w - 12.0 - rbtn_w, floorf((bar_h - btn_h) * 0.5), rbtn_w, btn_h))
			refresh_bounties_btn.custom_minimum_size = Vector2(rbtn_w, btn_h)
		content_top += bar_h + 10.0

	var content_bottom := card_h - pad
	var content_h := maxf(150.0, content_bottom - content_top)

	var list_scroll: ScrollContainer = view["list_scroll"]
	var split_divider: ColorRect = view["split_divider"]
	var detail_pane: Control = view["detail_pane"]

	if is_narrow:
		var list_h := clampf(floorf(content_h * 0.25), 88.0, 164.0)
		_set_rect(list_scroll, Rect2(pad, content_top, inner_w, list_h))
		var div_y := content_top + list_h + 8.0
		_set_rect(split_divider, Rect2(pad, div_y, inner_w, 1.0))
		var det_y := div_y + 9.0
		var det_h := maxf(120.0, content_bottom - det_y)
		_set_rect(detail_pane, Rect2(pad, det_y, inner_w, det_h))
	else:
		var list_w := floorf(inner_w * 0.36)
		var div_x := pad + list_w + 10.0
		var det_x := div_x + 11.0
		var det_w := maxf(280.0, card_w - pad - det_x)
		_set_rect(list_scroll, Rect2(pad, content_top, list_w, content_h))
		_set_rect(split_divider, Rect2(div_x, content_top, 1.0, content_h))
		_set_rect(detail_pane, Rect2(det_x, content_top, det_w, content_h))

	refresh_layout(view)

static func set_touch_mode(view: Dictionary, touch_enabled: bool) -> void:
	if view.is_empty() or not is_instance_valid(view.get("card")):
		return
	view["touch_mode"] = touch_enabled
	var list_scroll: ScrollContainer = view["list_scroll"]
	var detail_scroll: ScrollContainer = view["detail_scroll"]
	if is_instance_valid(list_scroll):
		list_scroll.follow_focus = not touch_enabled
		list_scroll.scroll_deadzone = 12 if touch_enabled else 8
	if is_instance_valid(detail_scroll):
		detail_scroll.follow_focus = not touch_enabled
		detail_scroll.scroll_deadzone = 14 if touch_enabled else 10
	set_responsive_layout(view, view.get("avail_size", Vector2(960.0, 700.0)))

static func refresh_layout(view: Dictionary) -> void:
	if view.is_empty() or not is_instance_valid(view.get("card")):
		return
	var detail_pane: Control = view["detail_pane"]
	var detail_scroll: ScrollContainer = view["detail_scroll"]
	var action_divider: ColorRect = view["action_divider"]
	var action_bar: Control = view["action_bar"]
	var is_touch := bool(view.get("touch_mode", false))
	var btn_h := 42.0 if is_touch else 40.0

	var det_w := maxf(220.0, detail_pane.offset_right - detail_pane.offset_left)
	var det_h := maxf(120.0, detail_pane.offset_bottom - detail_pane.offset_top)

	var visible_actions: Array[Button] = []
	for key in ["track_btn", "toggle_tracker_btn", "nav_btn", "pin_recipe_btn"]:
		var b: Button = view.get(key)
		if is_instance_valid(b) and b.visible:
			visible_actions.append(b)

	var action_area_h := 0.0
	if not visible_actions.is_empty():
		var two_rows := det_w < 460.0 and visible_actions.size() > 2
		var bar_h := (btn_h * 2.0 + 8.0) if two_rows else btn_h
		action_area_h = bar_h + 14.0
		var div_y := maxf(64.0, det_h - action_area_h)
		action_divider.visible = true
		action_bar.visible = true
		_set_rect(action_divider, Rect2(0.0, div_y, det_w, 1.0))
		_set_rect(action_bar, Rect2(0.0, div_y + 8.0, det_w, bar_h))

		var gap_a := 8.0
		if two_rows:
			var col_w := floorf((det_w - gap_a) * 0.5)
			for i in range(visible_actions.size()):
				var b: Button = visible_actions[i]
				var col := i % 2
				var row := i >> 1
				var is_last_odd := (i == visible_actions.size() - 1) and (visible_actions.size() % 2 == 1)
				var x := 0.0 if is_last_odd else float(col) * (col_w + gap_a)
				var w := det_w if is_last_odd else (col_w if col == 0 else maxf(80.0, det_w - x))
				var y := float(row) * (btn_h + 8.0)
				_set_rect(b, Rect2(x, y, w, btn_h))
				b.custom_minimum_size = Vector2(w, btn_h)
		else:
			var count := float(visible_actions.size())
			var col_w := floorf((det_w - gap_a * (count - 1.0)) / count)
			for i in range(visible_actions.size()):
				var b: Button = visible_actions[i]
				var x := float(i) * (col_w + gap_a)
				var w := col_w if i < visible_actions.size() - 1 else maxf(76.0, det_w - x)
				_set_rect(b, Rect2(x, 0.0, w, btn_h))
				b.custom_minimum_size = Vector2(w, btn_h)
	else:
		action_divider.visible = false
		action_bar.visible = false

	var scroll_h := maxf(72.0, det_h - action_area_h - 4.0)
	_set_rect(detail_scroll, Rect2(0.0, 0.0, det_w, scroll_h))

	# Re-measure wrapped labels in detail pane to prevent vertical truncation
	var content_w := maxf(180.0, det_w - 18.0)
	var title_lbl: Label = view["detail_title_label"]
	if is_instance_valid(title_lbl):
		var title_sz := 19 if bool(view.get("narrow_mode", false)) else 21
		title_lbl.add_theme_font_size_override("font_size", title_sz)
		title_lbl.custom_minimum_size = Vector2(0.0, _measure_multiline_height(title_lbl, title_lbl.text, content_w - 28.0, title_sz, 26.0, 4.0))

	var brief_lbl: Label = view["detail_brief_label"]
	if is_instance_valid(brief_lbl):
		brief_lbl.custom_minimum_size = Vector2(0.0, _measure_multiline_height(brief_lbl, brief_lbl.text, content_w - 28.0, 14, 24.0, 6.0))

	var reward_lbl: Label = view["detail_reward_label"]
	if is_instance_valid(reward_lbl):
		reward_lbl.custom_minimum_size = Vector2(0.0, _measure_multiline_height(reward_lbl, reward_lbl.text, content_w - 28.0, 14, 22.0, 4.0))

	var objectives_vbox: VBoxContainer = view["objectives_vbox"]
	if is_instance_valid(objectives_vbox):
		for child in objectives_vbox.get_children():
			var text_lbl = child.get_meta("_obj_text_label", null)
			if text_lbl is Label and is_instance_valid(text_lbl):
				var has_btn := bool(child.get_meta("_obj_has_nav", false))
				var avail_obj_w := maxf(110.0, content_w - (130.0 if has_btn else 56.0))
				text_lbl.custom_minimum_size = Vector2(0.0, _measure_multiline_height(text_lbl, text_lbl.text, avail_obj_w, 14, 22.0, 4.0))

static func _on_tab_selected(view: Dictionary, tab_id: String) -> void:
	if str(view.get("selected_tab", "")) == tab_id:
		return
	view["selected_tab"] = tab_id
	var payload: Dictionary = view.get("payload", {})
	var filtered := _filter_quests(payload, tab_id)
	var tracked_id := str(payload.get("tracked_quest_id", ""))
	var next_id := ""
	for q in filtered:
		if str(q.get("id", "")) == tracked_id:
			next_id = tracked_id
			break
	if next_id.is_empty() and not filtered.is_empty():
		next_id = str(filtered[0].get("id", ""))
	view["selected_quest_id"] = next_id
	_render_all(view, payload)
	var list_scroll: ScrollContainer = view["list_scroll"]
	if is_instance_valid(list_scroll):
		list_scroll.scroll_vertical = 0
	var detail_scroll: ScrollContainer = view["detail_scroll"]
	if is_instance_valid(detail_scroll):
		detail_scroll.scroll_vertical = 0

static func _on_quest_selected(view: Dictionary, quest_id: String) -> void:
	if str(view.get("selected_quest_id", "")) == quest_id:
		return
	view["selected_quest_id"] = quest_id
	view["rendered_quest_id"] = quest_id
	_update_list_selection_styles(view)
	var payload: Dictionary = view.get("payload", {})
	_render_detail(view, payload)
	var detail_scroll: ScrollContainer = view["detail_scroll"]
	if is_instance_valid(detail_scroll):
		detail_scroll.scroll_vertical = 0

static func _ensure_valid_selection(view: Dictionary, payload: Dictionary) -> void:
	var quests: Array = payload.get("quests", [])
	var tracked_id := str(payload.get("tracked_quest_id", ""))

	if not bool(view.get("has_initialized_selection", false)):
		view["has_initialized_selection"] = true
		if not tracked_id.is_empty():
			for q in quests:
				if q is Dictionary and str(q.get("id", "")) == tracked_id:
					view["selected_tab"] = _tab_for_quest(q)
					view["selected_quest_id"] = tracked_id
					return
		for def in TAB_DEFS:
			var tid: String = str(def["id"])
			var bucket := _filter_quests(payload, tid)
			if not bucket.is_empty():
				view["selected_tab"] = tid
				view["selected_quest_id"] = str(bucket[0].get("id", ""))
				return
		view["selected_tab"] = "main"
		view["selected_quest_id"] = ""
		return

	var current_tab := str(view.get("selected_tab", "main"))
	var filtered := _filter_quests(payload, current_tab)
	var cur_id := str(view.get("selected_quest_id", ""))
	for q in filtered:
		if str(q.get("id", "")) == cur_id:
			return
	for q in filtered:
		if str(q.get("id", "")) == tracked_id:
			view["selected_quest_id"] = tracked_id
			return
	view["selected_quest_id"] = str(filtered[0].get("id", "")) if not filtered.is_empty() else ""

static func _render_all(view: Dictionary, payload: Dictionary) -> void:
	var selected_tab := str(view.get("selected_tab", "main"))
	var bounties_unlocked := bool(payload.get("bounties_unlocked", false))
	var completed_bounties := int(payload.get("completed_bounty_count", 0))

	_update_header_meta(view, payload)
	_update_tab_labels(view, payload)

	var tab_buttons: Dictionary = view["tab_buttons"]
	for def in TAB_DEFS:
		var tid: String = str(def["id"])
		var tb: Button = tab_buttons.get(tid)
		if is_instance_valid(tb):
			_style_button(tb, "primary" if tid == selected_tab else "neutral")

	# Bounty bar state
	var bounty_bar: Panel = view["bounty_bar"]
	var bounty_info_label: Label = view["bounty_info_label"]
	var refresh_bounties_btn: Button = view["refresh_bounties_btn"]
	var show_bounty_bar := selected_tab == "bounty"
	bounty_bar.visible = show_bounty_bar
	if show_bounty_bar:
		if bounties_unlocked:
			var suffix := " · 已完成委托 %d 次" % completed_bounties if completed_bounties > 0 else ""
			bounty_info_label.text = "远洋科考前哨站回波频道已连通%s" % suffix
			bounty_info_label.add_theme_color_override("font_color", COLOR_CYAN)
			refresh_bounties_btn.visible = true
			refresh_bounties_btn.disabled = false
		else:
			bounty_info_label.text = BOUNTY_LOCKED_TEXT
			bounty_info_label.add_theme_color_override("font_color", COLOR_GOLD)
			refresh_bounties_btn.visible = false

	_render_quest_list(view, payload)
	_render_detail(view, payload)

	view["rendered_version"] = int(payload.get("version", -1))
	view["rendered_tab"] = selected_tab
	view["rendered_quest_id"] = str(view.get("selected_quest_id", ""))
	view["rendered_tracked_quest_id"] = str(payload.get("tracked_quest_id", ""))
	view["rendered_tracked_objective_id"] = str(payload.get("tracked_objective_id", ""))
	view["rendered_tracker_hidden"] = bool(payload.get("tracker_hidden", false))
	view["rendered_bounties_unlocked"] = bounties_unlocked

	set_responsive_layout(view, view.get("avail_size", Vector2(960.0, 700.0)))

static func _update_header_meta(view: Dictionary, payload: Dictionary) -> void:
	var rank_label: Label = view.get("rank_label")
	if not is_instance_valid(rank_label):
		return
	var rank := str(payload.get("explorer_rank", "深海见习勘测员"))
	var pct := clampi(int(payload.get("exploration_pct", 0)), 0, 100)
	rank_label.text = "%s · 勘测 %d%%" % [rank, pct]

static func _update_tab_labels(view: Dictionary, payload: Dictionary) -> void:
	var tab_buttons: Dictionary = view.get("tab_buttons", {})
	var counts: Dictionary = payload.get("counts", {})
	var avail_x := float((view.get("avail_size", Vector2(960.0, 700.0)) as Vector2).x)
	var use_short := avail_x < 600.0 and avail_x >= 420.0
	for def in TAB_DEFS:
		var tid: String = str(def["id"])
		var tb: Button = tab_buttons.get(tid)
		if not is_instance_valid(tb):
			continue
		var cnt := int(counts.get(tid, _filter_quests(payload, tid).size()))
		var title := str(def["short_label"]) if use_short else str(def["label"])
		tb.text = "%s (%d)" % [title, cnt]

static func _render_quest_list(view: Dictionary, payload: Dictionary) -> void:
	var list_vbox: VBoxContainer = view["list_vbox"]
	_clear_children(list_vbox)
	var entries: Array = []
	view["list_card_entries"] = entries

	var selected_tab := str(view.get("selected_tab", "main"))
	var selected_id := str(view.get("selected_quest_id", ""))
	var tracked_id := str(payload.get("tracked_quest_id", ""))
	var bounties_unlocked := bool(payload.get("bounties_unlocked", false))

	if selected_tab == "bounty" and not bounties_unlocked:
		var lock_card := PanelContainer.new()
		lock_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lock_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock_card.add_theme_stylebox_override("panel", OceanUiTheme.surface(COLOR_BG_SUBPANEL, Color(COLOR_GOLD, 0.35), 3))
		var m := MarginContainer.new()
		m.add_theme_constant_override("margin_left", 14)
		m.add_theme_constant_override("margin_right", 14)
		m.add_theme_constant_override("margin_top", 16)
		m.add_theme_constant_override("margin_bottom", 16)
		lock_card.add_child(m)
		var lbl := Label.new()
		lbl.text = BOUNTY_LOCKED_TEXT
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 14)
		lbl.add_theme_color_override("font_color", COLOR_GOLD)
		lbl.set_meta("_no_hint", true)
		m.add_child(lbl)
		list_vbox.add_child(lock_card)
		return

	var quests := _filter_quests(payload, selected_tab)
	if quests.is_empty():
		var empty_card := PanelContainer.new()
		empty_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		empty_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		empty_card.add_theme_stylebox_override("panel", OceanUiTheme.surface(COLOR_BG_ITEM, Color(COLOR_CYAN, 0.14), 3))
		var m := MarginContainer.new()
		m.add_theme_constant_override("margin_left", 14)
		m.add_theme_constant_override("margin_right", 14)
		m.add_theme_constant_override("margin_top", 16)
		m.add_theme_constant_override("margin_bottom", 16)
		empty_card.add_child(m)
		var empty_lbl := Label.new()
		empty_lbl.text = "当前分类暂无任务记录。"
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_lbl.add_theme_font_size_override("font_size", 14)
		empty_lbl.add_theme_color_override("font_color", COLOR_MUTED)
		empty_lbl.set_meta("_no_hint", true)
		m.add_child(empty_lbl)
		list_vbox.add_child(empty_card)
		return

	for q in quests:
		var q_id := str(q.get("id", ""))
		var is_selected := q_id == selected_id
		var is_tracked := bool(q.get("tracked", false)) or (not tracked_id.is_empty() and q_id == tracked_id)
		var is_done := str(q.get("status", "active")) == "completed"

		var item_btn := Button.new()
		item_btn.name = "QuestCard_%s" % q_id
		item_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		item_btn.custom_minimum_size = Vector2(0.0, 82.0)
		item_btn.mouse_filter = Control.MOUSE_FILTER_PASS
		item_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		item_btn.text = ""
		item_btn.set_meta("_no_hint", true)
		_style_quest_card_button(item_btn, is_selected, is_tracked)
		var captured_id := q_id
		item_btn.pressed.connect(func() -> void:
			_on_quest_selected(view, captured_id)
		)
		list_vbox.add_child(item_btn)

		var margin := MarginContainer.new()
		margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", 12)
		margin.add_theme_constant_override("margin_right", 12)
		margin.add_theme_constant_override("margin_top", 8)
		margin.add_theme_constant_override("margin_bottom", 8)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_btn.add_child(margin)

		var vb := VBoxContainer.new()
		vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vb.add_theme_constant_override("separation", 5)
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(vb)

		var top_row := HBoxContainer.new()
		top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_row.add_theme_constant_override("separation", 6)
		top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(top_row)

		var tag_text := str(q.get("act_label", "")).strip_edges()
		if tag_text.is_empty():
			tag_text = str(q.get("category_label", "任务"))
		var tag_lbl := Label.new()
		tag_lbl.text = tag_text
		tag_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tag_lbl.clip_text = true
		tag_lbl.add_theme_font_size_override("font_size", 12)
		tag_lbl.add_theme_color_override("font_color", COLOR_DONE if is_done else COLOR_CYAN)
		tag_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag_lbl.set_meta("_no_hint", true)
		top_row.add_child(tag_lbl)

		if is_tracked and not is_done:
			var trk_lbl := Label.new()
			trk_lbl.text = "[追踪中]"
			trk_lbl.add_theme_font_size_override("font_size", 12)
			trk_lbl.add_theme_color_override("font_color", COLOR_GOLD)
			trk_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			trk_lbl.set_meta("_no_hint", true)
			top_row.add_child(trk_lbl)
		elif is_done:
			var done_lbl := Label.new()
			done_lbl.text = "✓ 已完成"
			done_lbl.add_theme_font_size_override("font_size", 12)
			done_lbl.add_theme_color_override("font_color", COLOR_DONE)
			done_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			done_lbl.set_meta("_no_hint", true)
			top_row.add_child(done_lbl)

		var title_lbl := Label.new()
		title_lbl.text = str(q.get("title", "未命名任务"))
		title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_lbl.clip_text = true
		title_lbl.add_theme_font_size_override("font_size", 15)
		title_lbl.add_theme_color_override("font_color", COLOR_TEXT if not is_done else COLOR_MUTED)
		title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_lbl.set_meta("_no_hint", true)
		vb.add_child(title_lbl)

		var bottom_row := HBoxContainer.new()
		bottom_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bottom_row.add_theme_constant_override("separation", 8)
		bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
		bottom_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(bottom_row)

		var bar_info := _make_progress_bar(bottom_row, 5.0)
		(bar_info["track"] as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		(bar_info["track"] as Control).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var ratio := clampf(float(q.get("progress_ratio", 1.0 if is_done else 0.0)), 0.0, 1.0)
		_set_progress_bar(bar_info, ratio, COLOR_DONE if is_done else (COLOR_GOLD if is_tracked else COLOR_CYAN))

		var prog_lbl := Label.new()
		prog_lbl.text = str(q.get("progress_text", "%d%%" % int(round(ratio * 100.0))))
		prog_lbl.add_theme_font_size_override("font_size", 12)
		prog_lbl.add_theme_color_override("font_color", COLOR_MUTED)
		prog_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		prog_lbl.set_meta("_no_hint", true)
		bottom_row.add_child(prog_lbl)

		entries.append({
			"id": q_id,
			"button": item_btn,
			"tracked": is_tracked and not is_done,
		})

static func _update_list_selection_styles(view: Dictionary) -> void:
	var selected_id := str(view.get("selected_quest_id", ""))
	var entries: Array = view.get("list_card_entries", [])
	for entry in entries:
		if not (entry is Dictionary):
			continue
		var btn: Button = entry.get("button")
		if is_instance_valid(btn):
			var is_sel := str(entry.get("id", "")) == selected_id
			_style_quest_card_button(btn, is_sel, bool(entry.get("tracked", false)))

static func _render_detail(view: Dictionary, payload: Dictionary) -> void:
	var detail_empty_panel: Control = view["detail_empty_panel"]
	var detail_empty_label: Label = view["detail_empty_label"]
	var detail_body_vbox: Control = view["detail_body_vbox"]
	var objectives_vbox: VBoxContainer = view["objectives_vbox"]
	var dist_map: Dictionary = {}
	view["objective_distance_labels"] = dist_map

	var track_btn: Button = view["track_btn"]
	var toggle_tracker_btn: Button = view["toggle_tracker_btn"]
	var nav_btn: Button = view["nav_btn"]
	var pin_recipe_btn: Button = view["pin_recipe_btn"]

	var selected_tab := str(view.get("selected_tab", "main"))
	var bounties_unlocked := bool(payload.get("bounties_unlocked", false))
	var tracker_hidden := bool(payload.get("tracker_hidden", false))
	var callbacks: Dictionary = view.get("callbacks", {})

	var quest := _find_selected_quest(view)
	if quest.is_empty():
		detail_body_vbox.visible = false
		detail_empty_panel.visible = true
		if selected_tab == "bounty" and not bounties_unlocked:
			detail_empty_label.text = BOUNTY_LOCKED_TEXT + "。\n激活远洋前哨站信标后，可在此接取并刷新动态回波委托。"
		else:
			detail_empty_label.text = "当前分类暂无可查看的潜航任务。"
		track_btn.visible = false
		nav_btn.visible = false
		pin_recipe_btn.visible = false
		toggle_tracker_btn.visible = true
		toggle_tracker_btn.text = "显示 HUD 追踪" if tracker_hidden else "隐藏 HUD 追踪"
		_clear_children(objectives_vbox)
		refresh_layout(view)
		return

	detail_empty_panel.visible = false
	detail_body_vbox.visible = true

	var q_id := str(quest.get("id", ""))
	var is_done := str(quest.get("status", "active")) == "completed"
	var tracked_q_id := str(payload.get("tracked_quest_id", ""))
	var tracked_o_id := str(payload.get("tracked_objective_id", ""))
	var is_tracked := bool(quest.get("tracked", false)) or (not tracked_q_id.is_empty() and tracked_q_id == q_id)

	var act_text := str(quest.get("act_label", "")).strip_edges()
	var cat_text := str(quest.get("category_label", "")).strip_edges()
	var badge_text := act_text if not act_text.is_empty() else cat_text
	if not act_text.is_empty() and not cat_text.is_empty() and act_text != cat_text and not act_text.begins_with("主线"):
		badge_text = "%s · %s" % [cat_text, act_text]
	if badge_text.is_empty():
		badge_text = "潜航任务"

	_set_pill_label(view["detail_act_badge"], badge_text, COLOR_CYAN, Color(COLOR_CYAN, 0.14))
	if is_done:
		_set_pill_label(view["detail_status_badge"], "已完成", COLOR_DONE, Color(COLOR_DONE, 0.16))
	elif is_tracked:
		_set_pill_label(view["detail_status_badge"], "追踪中", COLOR_GOLD, Color(COLOR_GOLD, 0.18))
	else:
		_set_pill_label(view["detail_status_badge"], "进行中", COLOR_TEXT, Color(COLOR_CYAN, 0.10))

	var ratio := clampf(float(quest.get("progress_ratio", 1.0 if is_done else 0.0)), 0.0, 1.0)
	var prog_text := str(quest.get("progress_text", "%d%%" % int(round(ratio * 100.0))))
	(view["detail_progress_label"] as Label).text = "%s · %d%%" % [prog_text, int(round(ratio * 100.0))]
	(view["detail_title_label"] as Label).text = str(quest.get("title", "未命名任务"))
	_set_progress_bar(view["detail_progress_bar"], ratio, COLOR_DONE if is_done else (COLOR_GOLD if is_tracked else COLOR_CYAN))

	var brief_raw := str(quest.get("brief", "")).strip_edges()
	if brief_raw.is_empty():
		brief_raw = "暂无科考简报记录。"
	_set_hintable_text(view["detail_brief_label"], brief_raw, callbacks)

	# Objectives list
	_clear_children(objectives_vbox)
	var objectives: Array = quest.get("objectives", [])
	if objectives.is_empty():
		var none_lbl := Label.new()
		none_lbl.text = "无细分目标。"
		none_lbl.add_theme_font_size_override("font_size", 14)
		none_lbl.add_theme_color_override("font_color", COLOR_MUTED)
		none_lbl.set_meta("_no_hint", true)
		objectives_vbox.add_child(none_lbl)
	else:
		for obj in objectives:
			if not (obj is Dictionary):
				continue
			var obj_id := str(obj.get("id", ""))
			var obj_done := bool(obj.get("done", false))
			var obj_cur := int(obj.get("current", 0))
			var obj_req := int(obj.get("required", 0))
			var nav_avail := bool(obj.get("nav_available", false)) and not obj_done
			var is_tracked_obj := is_tracked and not obj_done and not tracked_o_id.is_empty() and obj_id == tracked_o_id

			var row_panel := PanelContainer.new()
			row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row_panel.mouse_filter = Control.MOUSE_FILTER_PASS
			var row_border := Color(COLOR_DONE, 0.28) if obj_done else (Color(COLOR_GOLD, 0.56) if is_tracked_obj else Color(COLOR_CYAN, 0.16))
			var row_bg := Color(0.04, 0.13, 0.16, 0.55) if obj_done else COLOR_BG_ITEM
			row_panel.add_theme_stylebox_override("panel", OceanUiTheme.surface(row_bg, row_border, 3))
			row_panel.set_meta("_obj_has_nav", nav_avail)
			objectives_vbox.add_child(row_panel)

			var rm := MarginContainer.new()
			rm.add_theme_constant_override("margin_left", 10)
			rm.add_theme_constant_override("margin_right", 10)
			rm.add_theme_constant_override("margin_top", 8)
			rm.add_theme_constant_override("margin_bottom", 8)
			rm.mouse_filter = Control.MOUSE_FILTER_PASS
			row_panel.add_child(rm)

			var hbox := HBoxContainer.new()
			hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hbox.add_theme_constant_override("separation", 10)
			hbox.alignment = BoxContainer.ALIGNMENT_CENTER
			hbox.mouse_filter = Control.MOUSE_FILTER_PASS
			rm.add_child(hbox)

			var mark_lbl := Label.new()
			mark_lbl.text = "✓" if obj_done else "○"
			mark_lbl.custom_minimum_size = Vector2(20.0, 24.0)
			mark_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			mark_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			mark_lbl.add_theme_font_size_override("font_size", 16)
			mark_lbl.add_theme_color_override("font_color", COLOR_DONE if obj_done else COLOR_GOLD)
			mark_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			mark_lbl.set_meta("_no_hint", true)
			hbox.add_child(mark_lbl)

			var text_col := VBoxContainer.new()
			text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			text_col.add_theme_constant_override("separation", 3)
			text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hbox.add_child(text_col)

			var obj_lbl := Label.new()
			obj_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			obj_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			obj_lbl.add_theme_font_size_override("font_size", 14)
			obj_lbl.add_theme_color_override("font_color", COLOR_MUTED if obj_done else COLOR_TEXT)
			obj_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_set_hintable_text(obj_lbl, str(obj.get("label", "")), callbacks)
			text_col.add_child(obj_lbl)
			row_panel.set_meta("_obj_text_label", obj_lbl)

			var meta_row := HBoxContainer.new()
			meta_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			meta_row.add_theme_constant_override("separation", 10)
			meta_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			text_col.add_child(meta_row)

			var has_meta := false
			if obj_req > 0:
				var cnt_lbl := Label.new()
				cnt_lbl.text = "(%d/%d)" % [mini(obj_cur, obj_req) if obj_done else obj_cur, obj_req]
				cnt_lbl.add_theme_font_size_override("font_size", 13)
				cnt_lbl.add_theme_color_override("font_color", COLOR_DONE if obj_done else COLOR_CYAN)
				cnt_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
				cnt_lbl.set_meta("_no_hint", true)
				meta_row.add_child(cnt_lbl)
				has_meta = true

			var dist_lbl := Label.new()
			dist_lbl.add_theme_font_size_override("font_size", 13)
			dist_lbl.add_theme_color_override("font_color", COLOR_GOLD)
			dist_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			dist_lbl.set_meta("_no_hint", true)
			var dist_str := "" if obj_done else _format_distance(obj.get("distance_m", -1.0))
			dist_lbl.text = dist_str
			dist_lbl.visible = not dist_str.is_empty()
			if dist_lbl.visible:
				has_meta = true
			meta_row.add_child(dist_lbl)
			if not obj_id.is_empty():
				dist_map[obj_id] = dist_lbl

			meta_row.visible = has_meta

			if nav_avail:
				var pin_btn := Button.new()
				pin_btn.text = "标点"
				pin_btn.custom_minimum_size = Vector2(68.0, 38.0)
				pin_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				pin_btn.mouse_filter = Control.MOUSE_FILTER_PASS
				pin_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
				pin_btn.set_meta("_no_hint", true)
				_style_button(pin_btn, "subtle")
				var pos_v = obj.get("nav_pos", Vector3.ZERO)
				var captured_pos: Vector3 = pos_v if pos_v is Vector3 else Vector3.ZERO
				var captured_nav_label := str(obj.get("nav_label", obj.get("label", "")))
				var captured_qid := q_id
				var captured_oid := obj_id
				pin_btn.pressed.connect(func() -> void:
					_invoke_callback_3(callbacks, "on_navigate", captured_pos, captured_nav_label, false)
					_invoke_callback_2(callbacks, "on_track", captured_qid, captured_oid)
				)
				hbox.add_child(pin_btn)

	# Rewards summary
	var reward_panel: Control = view["reward_panel"]
	var reward_lbl: Label = view["detail_reward_label"]
	var rewards_summary := str(quest.get("rewards_summary", "")).strip_edges()
	reward_panel.visible = not rewards_summary.is_empty()
	reward_lbl.text = rewards_summary

	# Bottom action buttons
	track_btn.visible = true
	if is_done:
		track_btn.text = "任务已完成"
		track_btn.disabled = true
		_style_button(track_btn, "neutral")
	elif is_tracked:
		track_btn.text = "当前追踪中"
		track_btn.disabled = true
		_style_button(track_btn, "primary")
	else:
		track_btn.text = "设为追踪"
		track_btn.disabled = false
		_style_button(track_btn, "primary")

	toggle_tracker_btn.visible = true
	toggle_tracker_btn.text = "显示 HUD 追踪" if tracker_hidden else "隐藏 HUD 追踪"
	_style_button(toggle_tracker_btn, "neutral")

	nav_btn.visible = true
	nav_btn.disabled = not bool(quest.get("primary_nav_available", false))
	_style_button(nav_btn, "cyan")

	var recipe_id := _resolve_recipe_hint(quest)
	pin_recipe_btn.visible = not recipe_id.is_empty()
	pin_recipe_btn.disabled = recipe_id.is_empty()
	_style_button(pin_recipe_btn, "cyan")

	refresh_layout(view)

static func _refresh_live_distances(view: Dictionary, payload: Dictionary) -> void:
	var dist_map: Dictionary = view.get("objective_distance_labels", {})
	if dist_map.is_empty():
		return
	var selected_id := str(view.get("selected_quest_id", ""))
	if selected_id.is_empty():
		return
	var quests: Array = payload.get("quests", [])
	for q in quests:
		if not (q is Dictionary) or str(q.get("id", "")) != selected_id:
			continue
		var objectives: Array = q.get("objectives", [])
		for obj in objectives:
			if not (obj is Dictionary):
				continue
			var oid := str(obj.get("id", ""))
			var lbl = dist_map.get(oid)
			if lbl is Label and is_instance_valid(lbl):
				var obj_done := bool(obj.get("done", false))
				var dist_str := "" if obj_done else _format_distance(obj.get("distance_m", -1.0))
				lbl.text = dist_str
				lbl.visible = not dist_str.is_empty()
				if lbl.visible and lbl.get_parent() is Control:
					(lbl.get_parent() as Control).visible = true
		break

static func _find_selected_quest(view: Dictionary) -> Dictionary:
	var selected_id := str(view.get("selected_quest_id", ""))
	if selected_id.is_empty():
		return {}
	var payload: Dictionary = view.get("payload", {})
	var quests: Array = payload.get("quests", [])
	for q in quests:
		if q is Dictionary and str(q.get("id", "")) == selected_id:
			return q
	return {}

static func _resolve_recipe_hint(quest: Dictionary) -> String:
	var direct := str(quest.get("recipe_hint", "")).strip_edges()
	if not direct.is_empty():
		return direct
	if str(quest.get("status", "active")) == "completed":
		return ""
	var objectives: Array = quest.get("objectives", [])
	for obj in objectives:
		if obj is Dictionary and not bool(obj.get("done", false)):
			var hint := str(obj.get("recipe_hint", "")).strip_edges()
			if not hint.is_empty():
				return hint
	return ""

static func _filter_quests(payload: Dictionary, tab_id: String) -> Array:
	var result: Array = []
	var quests: Array = payload.get("quests", [])
	for q in quests:
		if not (q is Dictionary):
			continue
		var status := str(q.get("status", "active"))
		var cat := str(q.get("category", "side"))
		if tab_id == "completed":
			if status == "completed":
				result.append(q)
		else:
			if status != "completed" and cat == tab_id:
				result.append(q)
	return result

static func _tab_for_quest(quest: Dictionary) -> String:
	if str(quest.get("status", "active")) == "completed":
		return "completed"
	var cat := str(quest.get("category", "main"))
	if cat == "main" or cat == "side" or cat == "bounty":
		return cat
	return "main"

static func _format_distance(raw_dist: Variant) -> String:
	if raw_dist is int or raw_dist is float:
		var d := float(raw_dist)
		if is_finite(d) and d >= 0.0:
			return "%dm" % int(round(d))
	return ""

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

static func _set_pill_label(pill: Dictionary, text: String, fg: Color, bg: Color) -> void:
	var panel: PanelContainer = pill.get("panel")
	var lbl: Label = pill.get("label")
	if is_instance_valid(panel):
		panel.add_theme_stylebox_override("panel", OceanUiTheme.surface(bg, Color(fg, 0.45), 3))
	if is_instance_valid(lbl):
		lbl.text = text
		lbl.add_theme_color_override("font_color", fg)

static func _style_button(control: Button, variant: String = "neutral") -> void:
	control.add_theme_font_size_override("font_size", 14)
	if variant == "primary":
		control.add_theme_color_override("font_color", COLOR_GOLD)
		control.add_theme_color_override("font_hover_color", COLOR_INK)
		control.add_theme_color_override("font_pressed_color", COLOR_INK)
		control.add_theme_color_override("font_disabled_color", Color(COLOR_GOLD, 0.60))
		control.add_theme_stylebox_override("normal", OceanUiTheme.surface(Color(COLOR_GOLD, 0.14), Color(COLOR_GOLD, 0.72), 3))
		control.add_theme_stylebox_override("hover", OceanUiTheme.surface(COLOR_GOLD, Color(COLOR_GOLD, 0.95), 3))
		control.add_theme_stylebox_override("pressed", OceanUiTheme.surface(COLOR_GOLD.darkened(0.12), COLOR_CYAN, 3))
		control.add_theme_stylebox_override("disabled", OceanUiTheme.surface(Color(COLOR_GOLD, 0.08), Color(COLOR_GOLD, 0.30), 3))
	elif variant == "cyan":
		control.add_theme_color_override("font_color", COLOR_CYAN)
		control.add_theme_color_override("font_hover_color", COLOR_INK)
		control.add_theme_color_override("font_pressed_color", COLOR_INK)
		control.add_theme_color_override("font_disabled_color", Color(COLOR_MUTED, 0.55))
		control.add_theme_stylebox_override("normal", OceanUiTheme.surface(Color(COLOR_CYAN, 0.12), Color(COLOR_CYAN, 0.52), 3))
		control.add_theme_stylebox_override("hover", OceanUiTheme.surface(COLOR_CYAN, Color(COLOR_CYAN, 0.95), 3))
		control.add_theme_stylebox_override("pressed", OceanUiTheme.surface(COLOR_CYAN.darkened(0.12), COLOR_TEXT, 3))
		control.add_theme_stylebox_override("disabled", OceanUiTheme.surface(Color(0.04, 0.10, 0.14, 0.55), Color(COLOR_MUTED, 0.16), 3))
	elif variant == "subtle":
		control.add_theme_color_override("font_color", COLOR_CYAN)
		control.add_theme_color_override("font_hover_color", COLOR_INK)
		control.add_theme_color_override("font_pressed_color", COLOR_INK)
		control.add_theme_color_override("font_disabled_color", Color(COLOR_MUTED, 0.5))
		control.add_theme_stylebox_override("normal", OceanUiTheme.surface(Color(COLOR_CYAN, 0.10), Color(COLOR_CYAN, 0.42), 3))
		control.add_theme_stylebox_override("hover", OceanUiTheme.surface(COLOR_CYAN, Color(COLOR_CYAN, 0.9), 3))
		control.add_theme_stylebox_override("pressed", OceanUiTheme.surface(COLOR_GOLD, COLOR_GOLD, 3))
		control.add_theme_stylebox_override("disabled", OceanUiTheme.surface(Color(0.04, 0.09, 0.13, 0.4), Color(COLOR_MUTED, 0.15), 3))
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

static func _style_quest_card_button(button: Button, selected: bool, tracked: bool) -> void:
	var bg := COLOR_BG_ITEM_SELECTED if selected else COLOR_BG_ITEM
	var border := Color(COLOR_GOLD, 0.78) if (selected and tracked) else (Color(COLOR_CYAN, 0.72) if selected else (Color(COLOR_GOLD, 0.36) if tracked else Color(COLOR_CYAN, 0.16)))
	button.add_theme_stylebox_override("normal", OceanUiTheme.surface(bg, border, 3))
	button.add_theme_stylebox_override("hover", OceanUiTheme.surface(COLOR_BG_ITEM_HOVER, Color(COLOR_CYAN, 0.58), 3))
	button.add_theme_stylebox_override("pressed", OceanUiTheme.surface(COLOR_BG_ITEM_SELECTED, COLOR_GOLD, 3))
	button.add_theme_stylebox_override("focus", OceanUiTheme.surface(bg, COLOR_TEXT, 3))

static func _clear_children(container: Node) -> void:
	if not is_instance_valid(container):
		return
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

static func _measure_multiline_height(label: Label, text: String, width: float, font_size: int, min_h: float, extra_pad: float = 6.0) -> float:
	if text.is_empty():
		return min_h
	var font: Font = label.get_theme_font("font") if is_instance_valid(label) else null
	if font == null:
		font = ThemeDB.fallback_font
	var safe_w := maxf(48.0, width - 6.0)
	if font != null:
		var brk_flags := TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE | TextServer.BREAK_GRAPHEME_BOUND
		var total_h := 0.0
		var paragraphs := text.split("\n", true)
		var line_h := maxf(float(font_size) + 5.0, font.get_height(font_size) + 2.0)
		for i in range(paragraphs.size()):
			var para := paragraphs[i]
			if para.is_empty():
				total_h += line_h * 0.75
			else:
				var sz := font.get_multiline_string_size(para, HORIZONTAL_ALIGNMENT_LEFT, safe_w, font_size, -1, brk_flags)
				total_h += maxf(line_h, sz.y)
			if i + 1 < paragraphs.size():
				total_h += 2.0
		return maxf(min_h, ceilf(total_h + extra_pad))
	var approx_chars := maxf(8.0, floorf(safe_w / maxf(12.0, float(font_size) * 0.98)))
	var approx_lines := 0
	for para in text.split("\n", true):
		approx_lines += maxi(1, ceili(float(para.length()) / approx_chars))
	return maxf(min_h, float(approx_lines) * (float(font_size) + 6.0) + extra_pad)

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

static func _invoke_callback_3(callbacks: Dictionary, key: String, arg1: Variant, arg2: Variant, arg3: Variant) -> void:
	var cb = callbacks.get(key)
	if cb is Callable and cb.is_valid():
		cb.call(arg1, arg2, arg3)

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
