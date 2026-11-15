extends RefCounted
## Ocean-glass gameplay encyclopedia & onboarding control panel ("guide" screen).

const Art = preload("res://scripts/art_direction.gd")
const OceanUiTheme = preload("res://scripts/presentation/ocean_ui_theme.gd")

const MAX_ITEM_SLOTS := 5

const FALLBACK_CHAPTERS := [
	{
		"id": "basics",
		"number": "01",
		"title": "潜航基础与双模式",
		"subtitle": "移动 · 补氧 · 模式差异",
		"summary": "使用推进与升降控制探索立体海域，随时切换自由探险与生存航程。",
		"items": [
			{
				"heading": "三维潜航推进",
				"keys": "WASD / 空格 / Ctrl / Shift",
				"body": "推动方向巡游转向，独立按键控制上浮与下潜，按住加速快速穿越水道。"
			}
		],
		"tip_note": "提示：随时按 L 打开或关闭潜航指南。"
	}
]

static func build(menu_root: Control, chapters: Array, callbacks: Dictionary = {}) -> Dictionary:
	var safe_chapters: Array = chapters.duplicate(true) if not chapters.is_empty() else FALLBACK_CHAPTERS.duplicate(true)
	var state := {
		"selected_index": 0,
		"chapters": safe_chapters,
	}

	var card := Panel.new()
	card.name = "GuideCard"
	_place(card, menu_root, Rect2(-480, -350, 960, 700), Vector2(0.5, 0.5))
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_theme_stylebox_override("panel", OceanUiTheme.surface(Art.PANEL, Color(Art.CYAN, 0.18), 4))

	# Top header bar
	_line(card, Rect2(28, 28, 30, 2), Art.AMBER)
	var eyebrow := _label(card, "潜航日志 / 玩法百科与操作指南", Rect2(68, 18, 460, 22), 14, Art.CYAN)
	eyebrow.set_meta("_no_hint", true)
	var main_title := _label(card, "深蓝潜航指南", Rect2(28, 46, 520, 40), 28, Art.PAPER)
	main_title.set_meta("_no_hint", true)

	var status_label := _label(card, "初航实操引导：待开启", Rect2(560, 22, 372, 26), 14, Art.AMBER)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.set_meta("_no_hint", true)

	var shortcut_label := _label(card, "", Rect2(560, 52, 372, 22), 14, Art.MUTED)
	shortcut_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_set_hintable_text(shortcut_label, "L / F1 随时开关 · 方向键或触屏切换章节", callbacks)

	_line(card, Rect2(28, 96, 904, 1), Color(Art.CYAN, 0.16))

	# Left chapter navigation column
	var chapter_buttons: Array[Button] = []
	for i in range(safe_chapters.size()):
		var ch: Dictionary = safe_chapters[i]
		var btn_text := "  %s  %s" % [str(ch.get("number", "%02d" % (i + 1))), str(ch.get("title", "章节"))]
		var idx := i
		var btn := _button(card, btn_text, Rect2(28, 110 + i * 48, 236, 42), func() -> void:
			if state.has("select_fn"):
				(state["select_fn"] as Callable).call(idx)
		, i == 0)
		btn.name = "ChapterBtn_%d" % i
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.set_meta("_no_hint", true)
		chapter_buttons.append(btn)

	var nav_bottom_y := maxf(456.0, 110.0 + float(safe_chapters.size()) * 48.0 + 10.0)
	if nav_bottom_y <= 548.0:
		var device_box := Panel.new()
		device_box.name = "GuideDeviceHintCard"
		_place(device_box, card, Rect2(28, nav_bottom_y, 236, 614.0 - nav_bottom_y))
		device_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		device_box.add_theme_stylebox_override("panel", OceanUiTheme.surface(Color(Art.INK, 0.36), Color(Art.CYAN, 0.14), 3))
		var dev_title := _label(device_box, "实时设备适配", Rect2(14, 10, 208, 22), 14, Art.CYAN)
		dev_title.set_meta("_no_hint", true)
		var dev_desc := _label(device_box, "键鼠、手柄、触屏操作时，右侧键位提示会自动切换为当前设备对应按键。", Rect2(14, 36, 208, maxf(48.0, 614.0 - nav_bottom_y - 44.0)), 14, Art.MUTED, false)
		dev_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dev_desc.set_meta("_no_hint", true)

	_line(card, Rect2(272, 110, 1, 504), Color(Art.CYAN, 0.12))

	# Right chapter detail area
	var chapter_title_label := _label(card, "", Rect2(286, 108, 336, 30), 22, Art.AMBER)
	chapter_title_label.set_meta("_no_hint", true)

	var chapter_subtitle_label := _label(card, "", Rect2(626, 112, 306, 24), 14, Art.CYAN)
	chapter_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	chapter_subtitle_label.set_meta("_no_hint", true)

	var chapter_summary_label := _label(card, "", Rect2(286, 138, 646, 36), 14, Art.MUTED, false)
	chapter_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var item_slots: Array[Dictionary] = []
	for slot_idx in range(MAX_ITEM_SLOTS):
		var item_panel := Panel.new()
		item_panel.name = "ItemCard_%d" % slot_idx
		_place(item_panel, card, Rect2(286, 178 + slot_idx * 103, 646, 95))
		item_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_panel.add_theme_stylebox_override("panel", OceanUiTheme.surface(Color(Art.INK, 0.36), Color(Art.CYAN, 0.12), 3))

		var heading_lbl := _label(item_panel, "", Rect2(14, 8, 368, 22), 15, Art.CYAN)
		heading_lbl.set_meta("_no_hint", true)

		var keys_lbl := _label(item_panel, "", Rect2(386, 8, 246, 22), 14, Art.AMBER)
		keys_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

		var body_lbl := _label(item_panel, "", Rect2(14, 32, 618, 50), 14, Art.PAPER, false)
		body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

		item_slots.append({
			"panel": item_panel,
			"heading": heading_lbl,
			"keys": keys_lbl,
			"body": body_lbl,
		})

	var tip_note_label := _label(card, "", Rect2(286, 592, 646, 28), 14, Art.MUTED, false)
	tip_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Footer bar
	_line(card, Rect2(28, 626, 904, 1), Color(Art.CYAN, 0.16))

	var restart_btn := _button(card, "重温初航引导", Rect2(28, 638, 196, 42), func() -> void:
		_invoke_callback(callbacks, "on_restart_onboarding")
	)
	restart_btn.name = "GuideRestartOnboardingButton"
	restart_btn.set_meta("_no_hint", true)

	var skip_btn := _button(card, "跳过初航引导", Rect2(236, 638, 190, 42), func() -> void:
		_invoke_callback(callbacks, "on_skip_onboarding")
	)
	skip_btn.name = "GuideSkipOnboardingButton"
	skip_btn.set_meta("_no_hint", true)

	var controls_btn := _button(card, "操作与灵敏度设置", Rect2(438, 638, 224, 42), func() -> void:
		_invoke_callback(callbacks, "on_open_controls")
	)
	controls_btn.name = "GuideControlsButton"
	controls_btn.set_meta("_no_hint", true)

	var close_btn := _button(card, "返回", Rect2(674, 638, 258, 42), func() -> void:
		_invoke_callback(callbacks, "on_close")
	, true)
	close_btn.name = "GuideCloseButton"
	close_btn.set_meta("_no_hint", true)

	var select_chapter := func(index: int) -> void:
		var list: Array = state["chapters"]
		if list.is_empty():
			return
		var clamped := clampi(index, 0, list.size() - 1)
		state["selected_index"] = clamped
		for b_idx in range(chapter_buttons.size()):
			var b: Button = chapter_buttons[b_idx]
			if is_instance_valid(b):
				OceanUiTheme.button(b, b_idx == clamped)

		var ch_data: Dictionary = list[clamped]
		var num_str := str(ch_data.get("number", "%02d" % (clamped + 1)))
		var title_str := str(ch_data.get("title", ""))
		chapter_title_label.text = "%s / %s" % [num_str, title_str]
		chapter_subtitle_label.text = str(ch_data.get("subtitle", ""))
		_set_hintable_text(chapter_summary_label, str(ch_data.get("summary", "")), callbacks)
		_set_hintable_text(tip_note_label, str(ch_data.get("tip_note", "")), callbacks)

		var items: Array = ch_data.get("items", [])
		var visible_count := clampi(items.size(), 0, MAX_ITEM_SLOTS)
		var area_top := 178.0
		var area_height := 406.0
		var gap := 8.0
		var card_h := 95.0
		if visible_count > 0:
			card_h = floorf((area_height - gap * float(maxi(0, visible_count - 1))) / float(visible_count))
			card_h = clampf(card_h, 72.0, 152.0)

		for s_idx in range(MAX_ITEM_SLOTS):
			var slot: Dictionary = item_slots[s_idx]
			var p: Panel = slot["panel"]
			if s_idx < visible_count:
				var item: Dictionary = items[s_idx]
				var y_pos := area_top + float(s_idx) * (card_h + gap)
				p.offset_left = 286.0
				p.offset_top = y_pos
				p.offset_right = 286.0 + 646.0
				p.offset_bottom = y_pos + card_h
				var body_lbl: Label = slot["body"]
				body_lbl.offset_top = 31.0
				body_lbl.offset_bottom = maxf(52.0, card_h - 6.0)
				(slot["heading"] as Label).text = str(item.get("heading", ""))
				_set_hintable_text(slot["keys"] as Label, str(item.get("keys", "")), callbacks)
				_set_hintable_text(body_lbl, str(item.get("body", "")), callbacks)
				p.visible = true
			else:
				p.visible = false

	state["select_fn"] = select_chapter

	var sync_onboarding_status := func(onboarding: Dictionary) -> void:
		var completed := bool(onboarding.get("onboarding_completed", false))
		var skipped := bool(onboarding.get("onboarding_skipped", false))
		var active := bool(onboarding.get("active", false))
		var banner := bool(onboarding.get("completed_banner", false))
		if completed:
			status_label.text = "初航实操引导：已完成 ✦"
			status_label.add_theme_color_override("font_color", Art.CYAN)
		elif skipped:
			status_label.text = "初航实操引导：已跳过"
			status_label.add_theme_color_override("font_color", Art.MUTED)
		elif active:
			var step_i := int(onboarding.get("step_index", 1))
			var step_tot := maxi(1, int(onboarding.get("step_total", 6)))
			status_label.text = "初航实操引导：进行中 (%d/%d)" % [step_i, step_tot]
			status_label.add_theme_color_override("font_color", Art.AMBER)
		else:
			status_label.text = "初航实操引导：待开启"
			status_label.add_theme_color_override("font_color", Art.MUTED)
		skip_btn.disabled = (not active) or banner

	select_chapter.call(0)
	sync_onboarding_status.call({})

	return {
		"card": card,
		"chapter_buttons": chapter_buttons,
		"restart_btn": restart_btn,
		"skip_btn": skip_btn,
		"controls_btn": controls_btn,
		"close_btn": close_btn,
		"select_chapter": select_chapter,
		"sync_onboarding_status": sync_onboarding_status,
	}

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

static func _invoke_callback(callbacks: Dictionary, key: String) -> void:
	var cb = callbacks.get(key)
	if cb is Callable and cb.is_valid():
		cb.call()

static func _place(control: Control, parent: Node, rect: Rect2, anchor := Vector2.ZERO) -> void:
	parent.add_child(control)
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

static func _button(parent: Node, text: String, rect: Rect2, callback: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	_place(button, parent, rect)
	button.text = text
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	OceanUiTheme.button(button, primary)
	button.pressed.connect(callback)
	return button
