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
		"avail_size": Vector2(960.0, 700.0),
		"vertical_mode": false,
		"touch_mode": false,
	}

	var card := Panel.new()
	card.name = "GuideCard"
	_place(card, menu_root, Rect2(0, 0, 960, 700), Vector2.ZERO)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_theme_stylebox_override("panel", OceanUiTheme.surface(Art.PANEL, Color(Art.CYAN, 0.18), 4))

	# Top header bar
	var accent_line := _line(card, Rect2(28, 28, 30, 2), Art.AMBER)
	var eyebrow := _label(card, "潜航日志 / 玩法百科与操作指南", Rect2(68, 18, 460, 22), 14, Art.CYAN)
	eyebrow.set_meta("_no_hint", true)
	var main_title := _label(card, "深蓝潜航指南", Rect2(28, 46, 520, 40), 28, Art.PAPER)
	main_title.set_meta("_no_hint", true)

	var status_label := _label(card, "初航实操引导：待开启", Rect2(500, 18, 336, 24), 14, Art.AMBER)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_label.set_meta("_no_hint", true)

	var shortcut_label := _label(card, "", Rect2(500, 46, 336, 22), 14, Art.MUTED)
	shortcut_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_set_hintable_text(shortcut_label, "L / F1 随时开关 · 方向键或触屏切换章节", callbacks)

	var header_divider := _line(card, Rect2(28, 92, 904, 1), Color(Art.CYAN, 0.16))

	# Chapter navigation (vertical column on desktop, horizontal pill strip on compact/mobile)
	var chapter_scroll := ScrollContainer.new()
	chapter_scroll.name = "GuideChapterScroll"
	_place(chapter_scroll, card, Rect2(28, 104, 236, 344))
	chapter_scroll.follow_focus = true
	chapter_scroll.scroll_deadzone = 8
	chapter_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	chapter_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	chapter_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO

	var chapter_box := BoxContainer.new()
	chapter_box.name = "GuideChapterBox"
	chapter_box.vertical = true
	chapter_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chapter_box.mouse_filter = Control.MOUSE_FILTER_PASS
	chapter_box.add_theme_constant_override("separation", 6)
	chapter_scroll.add_child(chapter_box)

	var chapter_buttons: Array[Button] = []
	for i in range(safe_chapters.size()):
		var ch: Dictionary = safe_chapters[i]
		var btn_text := "  %s  %s" % [str(ch.get("number", "%02d" % (i + 1))), str(ch.get("title", "章节"))]
		var idx := i
		var btn := _button(chapter_box, btn_text, Rect2(0, 0, 236, 44), func() -> void:
			if state.has("select_fn"):
				(state["select_fn"] as Callable).call(idx)
		, i == 0)
		btn.name = "ChapterBtn_%d" % i
		btn.custom_minimum_size = Vector2(220, 44)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.clip_text = true
		btn.set_meta("_no_hint", true)
		chapter_buttons.append(btn)

	var device_box := Panel.new()
	device_box.name = "GuideDeviceHintCard"
	_place(device_box, card, Rect2(28, 468, 236, 146))
	device_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	device_box.add_theme_stylebox_override("panel", OceanUiTheme.surface(Color(Art.INK, 0.36), Color(Art.CYAN, 0.14), 3))
	var dev_title := _label(device_box, "实时设备适配", Rect2(14, 10, 208, 22), 14, Art.CYAN)
	dev_title.set_meta("_no_hint", true)
	var dev_desc := _label(device_box, "键鼠、手柄、触屏操作时，右侧键位提示会自动切换为当前设备对应按键。", Rect2(14, 36, 208, 100), 14, Art.MUTED, false)
	dev_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dev_desc.set_meta("_no_hint", true)

	var split_divider := _line(card, Rect2(272, 104, 1, 510), Color(Art.CYAN, 0.12))

	# Chapter detail scrollable area
	var body_scroll := ScrollContainer.new()
	body_scroll.name = "GuideBodyScroll"
	_place(body_scroll, card, Rect2(286, 104, 646, 514))
	body_scroll.follow_focus = true
	body_scroll.scroll_deadzone = 10
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	body_scroll.mouse_filter = Control.MOUSE_FILTER_PASS

	var body_content := Control.new()
	body_content.name = "GuideBodyContent"
	body_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_content.mouse_filter = Control.MOUSE_FILTER_PASS
	body_scroll.add_child(body_content)

	var chapter_title_label := _label(body_content, "", Rect2(0, 0, 340, 30), 22, Art.AMBER)
	chapter_title_label.set_meta("_no_hint", true)

	var chapter_subtitle_label := _label(body_content, "", Rect2(344, 4, 302, 24), 14, Art.CYAN)
	chapter_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	chapter_subtitle_label.set_meta("_no_hint", true)

	var chapter_summary_label := _label(body_content, "", Rect2(0, 32, 646, 36), 14, Art.MUTED, false)
	chapter_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var item_slots: Array[Dictionary] = []
	for slot_idx in range(MAX_ITEM_SLOTS):
		var item_panel := Panel.new()
		item_panel.name = "ItemCard_%d" % slot_idx
		_place(item_panel, body_content, Rect2(0, 72 + slot_idx * 100, 646, 92))
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

	var tip_note_label := _label(body_content, "", Rect2(0, 484, 646, 28), 14, Art.MUTED, false)
	tip_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Footer bar
	var footer_divider := _line(card, Rect2(28, 626, 904, 1), Color(Art.CYAN, 0.16))

	var restart_btn := _button(card, "重温初航引导", Rect2(28, 638, 196, 44), func() -> void:
		_invoke_callback(callbacks, "on_restart_onboarding")
	)
	restart_btn.name = "GuideRestartOnboardingButton"
	restart_btn.custom_minimum_size = Vector2(0, 44)
	restart_btn.set_meta("_no_hint", true)

	var skip_btn := _button(card, "跳过初航引导", Rect2(236, 638, 190, 44), func() -> void:
		_invoke_callback(callbacks, "on_skip_onboarding")
	)
	skip_btn.name = "GuideSkipOnboardingButton"
	skip_btn.custom_minimum_size = Vector2(0, 44)
	skip_btn.set_meta("_no_hint", true)

	var controls_btn := _button(card, "操作与灵敏度设置", Rect2(438, 638, 224, 44), func() -> void:
		_invoke_callback(callbacks, "on_open_controls")
	)
	controls_btn.name = "GuideControlsButton"
	controls_btn.custom_minimum_size = Vector2(0, 44)
	controls_btn.set_meta("_no_hint", true)

	var header_close_btn := _button(card, "✕ 返回", Rect2(852, 18, 80, 44), func() -> void:
		_invoke_callback(callbacks, "on_close")
	)
	header_close_btn.name = "GuideHeaderCloseButton"
	header_close_btn.custom_minimum_size = Vector2(76, 44)
	header_close_btn.set_meta("_no_hint", true)

	var close_btn := _button(card, "返回", Rect2(674, 638, 258, 44), func() -> void:
		_invoke_callback(callbacks, "on_close")
	, true)
	close_btn.name = "GuideCloseButton"
	close_btn.custom_minimum_size = Vector2(0, 44)
	close_btn.set_meta("_no_hint", true)

	var layout_body_items := func() -> void:
		var list: Array = state["chapters"]
		if list.is_empty():
			return
		var clamped := clampi(int(state["selected_index"]), 0, list.size() - 1)
		var ch_data: Dictionary = list[clamped]
		var items: Array = ch_data.get("items", [])
		var visible_count := clampi(items.size(), 0, MAX_ITEM_SLOTS)
		var is_vert := bool(state.get("vertical_mode", false))
		var body_w := maxf(220.0, body_scroll.offset_right - body_scroll.offset_left - (10.0 if is_vert else 4.0))
		var body_view_h := maxf(140.0, body_scroll.offset_bottom - body_scroll.offset_top)
		var stack_head := body_w < 460.0

		var cur_y := 0.0
		if stack_head:
			_set_rect(chapter_title_label, Rect2(0, cur_y, body_w, 26))
			chapter_title_label.add_theme_font_size_override("font_size", 18)
			cur_y += 26.0
			_set_rect(chapter_subtitle_label, Rect2(0, cur_y, body_w, 22))
			chapter_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			cur_y += 24.0
		else:
			var title_w := floorf(body_w * 0.56)
			_set_rect(chapter_title_label, Rect2(0, cur_y, title_w, 28))
			chapter_title_label.add_theme_font_size_override("font_size", 20 if is_vert else 22)
			_set_rect(chapter_subtitle_label, Rect2(title_w + 6.0, cur_y + 4.0, maxf(80.0, body_w - title_w - 6.0), 22))
			chapter_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			cur_y += 30.0

		var sum_h := _measure_multiline_height(chapter_summary_label, chapter_summary_label.text, body_w, 14, 26.0, 6.0)
		_set_rect(chapter_summary_label, Rect2(0, cur_y, body_w, sum_h))
		cur_y += sum_h + 8.0

		var gap := 8.0
		var desktop_fit := not is_vert and body_view_h >= 460.0
		var fixed_card_h := 92.0
		if desktop_fit and visible_count > 0:
			var avail_items_h := maxf(240.0, body_view_h - cur_y - 36.0)
			fixed_card_h = clampf(floorf((avail_items_h - gap * float(maxi(0, visible_count - 1))) / float(visible_count)), 72.0, 148.0)

		for s_idx in range(MAX_ITEM_SLOTS):
			var slot: Dictionary = item_slots[s_idx]
			var p: Panel = slot["panel"]
			if s_idx < visible_count:
				var heading_lbl: Label = slot["heading"]
				var keys_lbl: Label = slot["keys"]
				var body_lbl: Label = slot["body"]
				var inner_item_w := maxf(180.0, body_w - 24.0)
				var body_top := 32.0
				if stack_head:
					_set_rect(heading_lbl, Rect2(12, 6, inner_item_w, 22))
					_set_rect(keys_lbl, Rect2(12, 28, inner_item_w, 22))
					keys_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
					body_top = 52.0
				else:
					var h_w := floorf(inner_item_w * 0.56)
					_set_rect(heading_lbl, Rect2(14, 7, h_w, 22))
					_set_rect(keys_lbl, Rect2(14 + h_w + 6.0, 7, maxf(80.0, inner_item_w - h_w - 6.0), 22))
					keys_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
					body_top = 32.0
				var body_text_h := _measure_multiline_height(body_lbl, body_lbl.text, inner_item_w, 14, 42.0, 8.0)
				var needed_card_h := body_top + body_text_h + 8.0
				var card_h := maxf(fixed_card_h, needed_card_h) if desktop_fit else needed_card_h
				_set_rect(p, Rect2(0, cur_y, body_w, card_h))
				_set_rect(body_lbl, Rect2(12 if stack_head else 14, body_top, inner_item_w, maxf(36.0, card_h - body_top - 6.0)))
				cur_y += card_h + gap
				p.visible = true
			else:
				p.visible = false

		var tip_h := _measure_multiline_height(tip_note_label, tip_note_label.text, body_w, 14, 24.0, 6.0)
		_set_rect(tip_note_label, Rect2(0, cur_y + 2.0, body_w, tip_h))
		cur_y += tip_h + 8.0
		body_content.custom_minimum_size = Vector2(0.0, cur_y)

	state["layout_body_fn"] = layout_body_items

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
		for s_idx in range(MAX_ITEM_SLOTS):
			var slot: Dictionary = item_slots[s_idx]
			var p: Panel = slot["panel"]
			if s_idx < visible_count:
				var item: Dictionary = items[s_idx]
				var body_lbl: Label = slot["body"]
				(slot["heading"] as Label).text = str(item.get("heading", ""))
				_set_hintable_text(slot["keys"] as Label, str(item.get("keys", "")), callbacks)
				_set_hintable_text(body_lbl, str(item.get("body", "")), callbacks)
				p.visible = true
			else:
				p.visible = false
		body_scroll.scroll_vertical = 0
		layout_body_items.call()

	state["select_fn"] = select_chapter

	var apply_responsive := func(avail_size: Vector2) -> void:
		var clamped_avail := Vector2(maxf(260.0, avail_size.x), maxf(240.0, avail_size.y))
		state["avail_size"] = clamped_avail
		var is_vert := clamped_avail.x < 760.0 or clamped_avail.y < 520.0
		state["vertical_mode"] = is_vert
		var card_w := minf(960.0, clamped_avail.x)
		var card_h := clamped_avail.y if is_vert else minf(700.0, clamped_avail.y)
		var card_x := maxf(0.0, floorf((clamped_avail.x - card_w) * 0.5))
		var card_y := maxf(0.0, floorf((clamped_avail.y - card_h) * 0.5))
		_set_rect(card, Rect2(card_x, card_y, card_w, card_h))
		card.custom_minimum_size = Vector2(minf(card_w, clamped_avail.x), minf(card_h, clamped_avail.y))

		var pad := 14.0 if is_vert else 28.0
		var inner_w := maxf(220.0, card_w - pad * 2.0)
		var close_w := 80.0
		_set_rect(header_close_btn, Rect2(card_w - pad - close_w, 10.0 if is_vert else 18.0, close_w, 44.0))

		var header_bottom := 92.0
		if is_vert:
			var compact_short := card_h < 430.0
			accent_line.visible = not compact_short
			eyebrow.visible = not compact_short
			shortcut_label.visible = false
			if compact_short:
				_set_rect(main_title, Rect2(pad, 10, maxf(120.0, inner_w - close_w - 8.0), 28))
				main_title.add_theme_font_size_override("font_size", 20)
				status_label.visible = card_w >= 480.0
				if status_label.visible:
					_set_rect(status_label, Rect2(pad + 170.0, 14, maxf(100.0, inner_w - close_w - 182.0), 22))
					status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				header_bottom = 58.0
			else:
				_set_rect(accent_line, Rect2(pad, 18, 24, 2))
				_set_rect(eyebrow, Rect2(pad + 32.0, 8, maxf(120.0, inner_w - close_w - 40.0), 20))
				_set_rect(main_title, Rect2(pad, 30, maxf(120.0, inner_w - close_w - 8.0), 30))
				main_title.add_theme_font_size_override("font_size", 22)
				status_label.visible = true
				_set_rect(status_label, Rect2(pad, 62, inner_w, 20))
				status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
				header_bottom = 86.0
		else:
			accent_line.visible = true
			eyebrow.visible = true
			status_label.visible = true
			shortcut_label.visible = true
			_set_rect(accent_line, Rect2(pad, 28, 30, 2))
			var left_hdr_w := floorf((inner_w - close_w - 16.0) * 0.54)
			var right_hdr_x := pad + left_hdr_w + 8.0
			var right_hdr_w := maxf(140.0, card_w - pad - close_w - 12.0 - right_hdr_x)
			_set_rect(eyebrow, Rect2(pad + 40.0, 18, maxf(140.0, left_hdr_w - 40.0), 22))
			_set_rect(main_title, Rect2(pad, 46, left_hdr_w, 40))
			main_title.add_theme_font_size_override("font_size", 28)
			_set_rect(status_label, Rect2(right_hdr_x, 18, right_hdr_w, 24))
			status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			_set_rect(shortcut_label, Rect2(right_hdr_x, 46, right_hdr_w, 22))
			header_bottom = 92.0

		_set_rect(header_divider, Rect2(pad, header_bottom, inner_w, 1))

		var two_row_footer := card_w < 560.0
		var footer_h := 102.0 if two_row_footer else 56.0
		var footer_top := card_h - footer_h
		_set_rect(footer_divider, Rect2(pad, footer_top, inner_w, 1))
		if two_row_footer:
			var btn_w := floorf((inner_w - 8.0) * 0.5)
			restart_btn.text = "重温引导"
			skip_btn.text = "跳过引导"
			controls_btn.text = "操作设置"
			_set_rect(restart_btn, Rect2(pad, footer_top + 6.0, btn_w, 44.0))
			_set_rect(skip_btn, Rect2(pad + btn_w + 8.0, footer_top + 6.0, inner_w - btn_w - 8.0, 44.0))
			_set_rect(controls_btn, Rect2(pad, footer_top + 54.0, btn_w, 44.0))
			_set_rect(close_btn, Rect2(pad + btn_w + 8.0, footer_top + 54.0, inner_w - btn_w - 8.0, 44.0))
		elif is_vert:
			var gap_f := 8.0
			var btn_w4 := floorf((inner_w - gap_f * 3.0) * 0.25)
			restart_btn.text = "重温引导"
			skip_btn.text = "跳过引导"
			controls_btn.text = "操作设置"
			_set_rect(restart_btn, Rect2(pad, footer_top + 6.0, btn_w4, 44.0))
			_set_rect(skip_btn, Rect2(pad + (btn_w4 + gap_f), footer_top + 6.0, btn_w4, 44.0))
			_set_rect(controls_btn, Rect2(pad + (btn_w4 + gap_f) * 2.0, footer_top + 6.0, btn_w4, 44.0))
			_set_rect(close_btn, Rect2(pad + (btn_w4 + gap_f) * 3.0, footer_top + 6.0, inner_w - (btn_w4 + gap_f) * 3.0, 44.0))
		else:
			restart_btn.text = "重温初航引导"
			skip_btn.text = "跳过初航引导"
			controls_btn.text = "操作与灵敏度设置"
			var w1 := floorf(inner_w * 0.21)
			var w2 := floorf(inner_w * 0.21)
			var w3 := floorf(inner_w * 0.25)
			var x2 := pad + w1 + 10.0
			var x3 := x2 + w2 + 10.0
			var x4 := x3 + w3 + 10.0
			_set_rect(restart_btn, Rect2(pad, footer_top + 6.0, w1, 44.0))
			_set_rect(skip_btn, Rect2(x2, footer_top + 6.0, w2, 44.0))
			_set_rect(controls_btn, Rect2(x3, footer_top + 6.0, w3, 44.0))
			_set_rect(close_btn, Rect2(x4, footer_top + 6.0, maxf(96.0, card_w - pad - x4), 44.0))

		var content_top := header_bottom + 8.0
		var content_bottom := footer_top - 8.0
		if is_vert:
			device_box.visible = false
			split_divider.visible = false
			chapter_box.vertical = false
			chapter_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
			chapter_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			_set_rect(chapter_scroll, Rect2(pad, content_top, inner_w, 50.0))
			for b_idx in range(chapter_buttons.size()):
				var ch_b: Button = chapter_buttons[b_idx]
				var ch_d: Dictionary = safe_chapters[b_idx]
				ch_b.text = "%s %s" % [str(ch_d.get("number", "%02d" % (b_idx + 1))), str(ch_d.get("title", "章节"))]
				ch_b.custom_minimum_size = Vector2(148.0, 44.0)
				ch_b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
				ch_b.alignment = HORIZONTAL_ALIGNMENT_CENTER
			var body_top := content_top + 56.0
			_set_rect(body_scroll, Rect2(pad, body_top, inner_w, maxf(96.0, content_bottom - body_top)))
		else:
			split_divider.visible = true
			chapter_box.vertical = true
			chapter_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			chapter_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
			var nav_w := 236.0
			var nav_need_h := float(safe_chapters.size()) * 50.0
			var total_col_h := maxf(180.0, content_bottom - content_top)
			var show_dev := total_col_h - nav_need_h >= 104.0
			var nav_h := (total_col_h - 118.0) if show_dev else total_col_h
			_set_rect(chapter_scroll, Rect2(pad, content_top, nav_w, maxf(140.0, nav_h)))
			device_box.visible = show_dev
			if show_dev:
				var dev_y := content_top + nav_h + 10.0
				var dev_h := maxf(88.0, content_bottom - dev_y)
				_set_rect(device_box, Rect2(pad, dev_y, nav_w, dev_h))
				_set_rect(dev_desc, Rect2(14, 34, nav_w - 28.0, maxf(44.0, dev_h - 42.0)))
			for b_idx in range(chapter_buttons.size()):
				var ch_b: Button = chapter_buttons[b_idx]
				var ch_d: Dictionary = safe_chapters[b_idx]
				ch_b.text = "  %s  %s" % [str(ch_d.get("number", "%02d" % (b_idx + 1))), str(ch_d.get("title", "章节"))]
				ch_b.custom_minimum_size = Vector2(nav_w - 8.0, 44.0)
				ch_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				ch_b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			var split_x := pad + nav_w + 10.0
			_set_rect(split_divider, Rect2(split_x, content_top, 1.0, total_col_h))
			var body_x := split_x + 12.0
			_set_rect(body_scroll, Rect2(body_x, content_top, maxf(240.0, card_w - pad - body_x), total_col_h))
		layout_body_items.call()

	state["responsive_fn"] = apply_responsive

	var set_touch_mode := func(touch_enabled: bool) -> void:
		state["touch_mode"] = touch_enabled
		chapter_scroll.follow_focus = not touch_enabled
		body_scroll.follow_focus = not touch_enabled

	state["set_touch_mode_fn"] = set_touch_mode

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
	apply_responsive.call(Vector2(960.0, 700.0))

	return {
		"card": card,
		"chapter_buttons": chapter_buttons,
		"chapter_scroll": chapter_scroll,
		"body_scroll": body_scroll,
		"restart_btn": restart_btn,
		"skip_btn": skip_btn,
		"controls_btn": controls_btn,
		"close_btn": close_btn,
		"header_close_btn": header_close_btn,
		"select_chapter": select_chapter,
		"sync_onboarding_status": sync_onboarding_status,
		"set_responsive_layout": apply_responsive,
		"set_touch_mode": set_touch_mode,
		"refresh_layout": layout_body_items,
	}

static func set_responsive_layout(view: Dictionary, avail_size: Vector2) -> void:
	var fn = view.get("set_responsive_layout")
	if fn is Callable and fn.is_valid():
		fn.call(avail_size)

static func set_touch_mode(view: Dictionary, touch_enabled: bool) -> void:
	var fn = view.get("set_touch_mode")
	if fn is Callable and fn.is_valid():
		fn.call(touch_enabled)

static func refresh_layout(view: Dictionary) -> void:
	var fn = view.get("refresh_layout")
	if fn is Callable and fn.is_valid():
		fn.call()

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

static func _invoke_callback(callbacks: Dictionary, key: String) -> void:
	var cb = callbacks.get(key)
	if cb is Callable and cb.is_valid():
		cb.call()

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

static func _button(parent: Node, text: String, rect: Rect2, callback: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	_place(button, parent, rect)
	button.text = text
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	OceanUiTheme.button(button, primary)
	button.pressed.connect(callback)
	return button
