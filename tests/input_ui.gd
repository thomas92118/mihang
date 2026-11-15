extends SceneTree

const HUD = preload("res://scripts/hud.gd")

class FakeInputs extends Node:
	signal device_changed(device: String)
	signal settings_changed
	var active_device := "keyboard"
	var settings := {"gamepad_sensitivity": 1.0, "touch_sensitivity": 1.0, "deadzone": 0.2, "touch_scale": 1.0, "touch_opacity": 0.75, "invert_y": false, "touch_mode": "auto"}
	func hint(action: String) -> String:
		return "PAD_" + action

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func() -> void:
		printerr("INPUT_UI_TIMEOUT: an assertion or input navigation failed")
		quit(1)
	)
	_run.call_deferred()

func _touch(index: int, at: Vector2, pressed: bool, canceled := false) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = pressed
	event.canceled = canceled
	return event

func _drag(index: int, at: Vector2) -> InputEventScreenDrag:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = at
	return event

func _pad(button: int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	return event

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	root.add_child(viewport)
	var inputs := FakeInputs.new()
	viewport.add_child(inputs)
	var hud := HUD.new()
	viewport.add_child(hud)
	await process_frame
	hud.configure_input(inputs)
	await process_frame

	# Every screen has a usable default focus, and navigation stays in that screen.
	for screen: String in ["main", "pause", "craft", "sushi", "mount_board", "map", "win", "quick", "controls", "guide"]:
		hud.set_screen(screen)
		await process_frame
		var focused := viewport.gui_get_focus_owner()
		assert(is_instance_valid(focused), "%s must have a default focus" % screen)
		assert(hud.menus[screen].is_ancestor_of(focused), "Focus must belong to the visible screen")
		for control: Control in hud._focusable_controls():
			assert(control.get_node(control.focus_next) in hud._focusable_controls(), "Tab navigation cannot leave the screen")

	hud.set_screen("quick")
	await process_frame
	var chosen: Array[String] = []
	hud.action_requested.connect(func(action: String) -> void: chosen.append(action))
	for action: String in ["weapon_4", "mount_slot_6", "scope", "camera_farther", "sushi_menu", "salvage_drone", "gameplay_guide"]:
		assert(hud.quick_buttons.has(action), "%s must be reachable without a keyboard" % action)
		hud.quick_buttons[action].pressed.emit()
		assert(chosen.back() == action)

	# A focused control becoming disabled moves focus to an available control.
	var old_focus: Button = hud.quick_buttons["weapon_1"]
	old_focus.grab_focus()
	old_focus.disabled = true
	hud._refresh_navigation()
	assert(viewport.gui_get_focus_owner() != old_focus)
	assert(not (viewport.gui_get_focus_owner() as BaseButton).disabled)

	# Device hints change as a whole; generated RT/LT-style labels are not rescanned.
	inputs.active_device = "gamepad"
	inputs.device_changed.emit("gamepad")
	assert(hud.format_input_text("R 攻击 / [E] 交互 / 按 3 装备") == "PAD_attack 攻击 / [PAD_interact] 交互 / 使用 PAD_weapon_3 装备")
	assert(hud.format_input_text("A B Y S S A L   E C H O") == "A B Y S S A L   E C H O")
	assert(hud.format_input_text("O₂ +35 · 深海金币: 120 G · 坐标 X:+12 Z:-40") == "O₂ +35 · 深海金币: 120 G · 坐标 X:+12 Z:-40")
	assert(hud.format_input_text("WASD 航行 / 空格 Ctrl 升降") == "PAD_forward 航行 / PAD_ascend / PAD_descend 升降")
	assert(hud.format_input_text("按 L 打开指南 · 声望 Lv.2") == "按 PAD_gameplay_guide 打开指南 · 声望 Lv.2")
	hud.toast("按 E 采集")
	assert(hud.toast_label.text == "按 PAD_interact 采集")
	inputs.active_device = "keyboard"
	inputs.device_changed.emit("keyboard")
	assert(hud.toast_label.text == "按 E 采集")

	# Settings emit their values without forcing the UI to save configuration itself.
	var changes: Array[Dictionary] = []
	hud.input_settings_requested.connect(func(values: Dictionary) -> void: changes.append(values))
	hud.settings_controls["gamepad_sensitivity"].value = 1.5
	assert(is_equal_approx(float(changes.back()["gamepad_sensitivity"]), 1.5))
	hud.settings_controls["touch_mode"].item_selected.emit(1)
	assert(changes.back()["touch_mode"] == "on")

	hud.set_screen("map")
	await process_frame
	var chart: Control = hud.sea_chart
	var events := {"selection": 0, "travel": 0, "waypoint": 0}
	chart.selection_changed.connect(func(_info: Dictionary) -> void: events["selection"] += 1)
	chart.fast_travel_requested.connect(func(_id: String, _pos: Vector3, _title: String) -> void: events["travel"] += 1)
	chart.waypoint_set.connect(func(_xz: Vector2) -> void: events["waypoint"] += 1)
	chart.zoom = 2.0
	chart._gui_input(_touch(1, Vector2(140, 140), true))
	chart._gui_input(_touch(1, Vector2(140, 140), false))
	assert(events["selection"] == 1 and events["travel"] == 0 and events["waypoint"] == 0, "Touch selection requires explicit waypoint/travel confirmation")
	chart._gui_input(_touch(2, Vector2(140, 140), true))
	chart._gui_input(_drag(2, Vector2(240, 140)))
	chart._gui_input(_touch(2, Vector2(240, 140), false))
	assert(events["selection"] == 1, "Dragging must not select or travel on release")
	assert(chart.pan_world.length() > 0.0)
	chart._gui_input(_touch(3, Vector2(100, 100), true))
	chart._gui_input(_touch(4, Vector2(200, 100), true))
	chart._gui_input(_drag(4, Vector2(280, 100)))
	chart._gui_input(_touch(3, Vector2(100, 100), false))
	chart._gui_input(_touch(4, Vector2(280, 100), false))
	assert(chart.zoom > 2.0 and events["selection"] == 1, "Pinch zoom must not become a click")
	chart._gui_input(_touch(5, Vector2(100, 100), true))
	chart._gui_input(_touch(5, Vector2(100, 100), false, true))
	assert(events["selection"] == 1 and chart._touches.is_empty())
	var emulated := InputEventMouseButton.new()
	emulated.device = InputEvent.DEVICE_ID_EMULATION
	emulated.button_index = MOUSE_BUTTON_LEFT
	emulated.position = Vector2(200, 200)
	emulated.pressed = true
	emulated.double_click = true
	chart._gui_input(emulated)
	assert(events["travel"] == 0 and events["waypoint"] == 0)
	chart._gui_input(_pad(JOY_BUTTON_DPAD_RIGHT))
	assert(not chart.selected_node.is_empty())
	chart._gui_input(_pad(JOY_BUTTON_X))
	assert(viewport.gui_get_focus_owner() != chart, "X must reach the map action buttons")
	hud._unhandled_input(_pad(JOY_BUTTON_X))
	assert(viewport.gui_get_focus_owner() == chart)

	# Small screens use clipped scrolling rather than shrinking controls out of reach.
	for resolution: Vector2i in [Vector2i(844, 390), Vector2i(640, 360), Vector2i(1024, 768)]:
		viewport.size = resolution
		hud.root.size = Vector2(resolution)
		hud._apply_layout()
		await process_frame
		for screen: String in ["main", "craft", "sushi", "mount_board", "map", "quick", "controls", "guide"]:
			hud.set_screen(screen)
			await process_frame
			var scroll: ScrollContainer = hud.menu_scrolls[screen]
			assert(Rect2(Vector2.ZERO, Vector2(resolution)).encloses(scroll.get_global_rect()), "Scroll viewport must stay in the safe screen")
			var controls: Array[Control] = hud._focusable_controls()
			assert(not controls.is_empty())
			controls.back().grab_focus()
			scroll.ensure_control_visible(controls.back())
			await process_frame
			assert(scroll.get_global_rect().intersects(controls.back().get_global_rect()), "Focus must scroll an off-screen action into reach")

	viewport.queue_free()
	await process_frame
	print("INPUT_UI_OK: menu focus, action access, hints, settings, map gestures and responsive scrolling")
	quit()
