extends SceneTree

const Controls = preload("res://scripts/input_controller.gd")

var edges: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func _key(code: int, pressed: bool, echo: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	event.echo = echo
	return event

func _mouse(pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	return event

func _axis(axis: int, value: float, device: int = 0) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.device = device
	event.axis = axis
	event.axis_value = value
	return event

func _feed(controls: Node, event: InputEvent, accepted: bool = true) -> void:
	controls._input(event)
	if accepted:
		controls.handle_event(event)

func _run() -> void:
	create_timer(10.0).timeout.connect(func():
		printerr("FAIL: input controller regression timed out")
		quit(1)
	)
	var controls := Controls.new()
	root.add_child(controls)
	controls.apply_settings(Controls.DEFAULT_SETTINGS, false)
	controls.action_changed.connect(func(action: String, pressed: bool, cancelled: bool):
		if action == "attack":
			edges.append({"pressed": pressed, "cancelled": cancelled})
	)
	for action: String in ["attack", "forward"]:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	var attack_key := _key(KEY_R, false)
	var custom_key := _key(KEY_F12, false)
	InputMap.action_add_event("attack", attack_key)
	InputMap.action_add_event("attack", custom_key)
	InputMap.action_add_event("attack", _mouse(false))
	controls.setup_defaults()
	var attack_bindings: int = InputMap.action_get_events("attack").size()
	var ui_bindings: int = InputMap.action_get_events("ui_accept").size()
	controls.setup_defaults()
	assert(InputMap.action_get_events("attack").size() == attack_bindings)
	assert(InputMap.action_get_events("ui_accept").size() == ui_bindings)
	assert(InputMap.action_has_event("attack", custom_key), "Defaults must preserve existing/custom bindings")
	controls.set_context("play")

	# A release belongs to its source; the last held source owns the release edge.
	controls.set_action("touch:attack", "attack", true)
	controls.set_action("gamepad:test", "attack", true)
	assert(edges.size() == 1 and edges[0].pressed)
	controls.set_action("touch:attack", "attack", false)
	assert(controls.is_action_pressed("attack") and edges.size() == 1)
	controls.set_action("gamepad:test", "attack", false)
	assert(edges.size() == 2 and not edges[1].pressed and not edges[1].cancelled)
	assert(not controls.is_action_pressed("attack"))

	edges.clear()
	controls.set_action("touch:attack", "attack", true)
	controls.set_action("gamepad:test", "attack", true)
	controls.cancel_source("gamepad:test")
	assert(edges.size() == 1 and controls.is_action_pressed("attack"))
	controls.set_action("touch:attack", "attack", false)
	assert(edges.size() == 2 and not edges[1].cancelled, "An unaffected held source may finish its normal attack")

	# Cancelling attack (weapon/vehicle change) leaves movement untouched.
	edges.clear()
	controls.set_axis("touch:move", "left", "right", 0.4)
	controls.set_action("touch:attack", "attack", true)
	controls.cancel_action("attack")
	assert(edges.size() == 2 and edges[1].cancelled)
	assert(is_equal_approx(controls.get_axis("left", "right"), 0.4))
	controls.cancel_all()
	assert(is_zero_approx(controls.get_axis("left", "right")))

	# Native controls use the same aggregate and reject keyboard repeat.
	edges.clear()
	_feed(controls, _key(KEY_R, true))
	_feed(controls, _key(KEY_R, true, true))
	_feed(controls, _mouse(true))
	assert(edges.size() == 1)
	_feed(controls, _key(KEY_R, false))
	assert(edges.size() == 1 and controls.is_action_pressed("attack"))
	_feed(controls, _mouse(false))
	assert(edges.size() == 2 and not edges[1].cancelled)

	# Pausing cancels charging; resuming while a physical key is held cannot fire.
	edges.clear()
	_feed(controls, _key(KEY_R, true))
	controls.set_context("pause")
	assert(edges.size() == 2 and edges[1].cancelled)
	controls.set_context("play")
	_feed(controls, _key(KEY_R, true))
	assert(edges.size() == 2 and not controls.is_action_pressed("attack"))
	_feed(controls, _key(KEY_R, false))
	_feed(controls, _key(KEY_R, true))
	assert(edges.size() == 3 and edges[2].pressed)
	_feed(controls, _key(KEY_R, false))

	# A GUI-consumed click must not become an attack through Input polling.
	edges.clear()
	_feed(controls, _mouse(true), false)
	Input.action_press("attack")
	assert(edges.is_empty() and not controls.is_action_pressed("attack"))
	Input.action_release("attack")
	_feed(controls, _mouse(false), false)
	# Touch controls can consume emulated LMB before the controller observes it.
	# That global mouse state must not keep a real source's attack held forever.
	edges.clear()
	Input.action_press("attack")
	assert(not controls.is_action_pressed("attack"), "Unaccepted/emulated mouse polling cannot create an attack source")
	controls.set_action("gamepad:test", "attack", true)
	assert(controls.is_action_pressed("attack"))
	controls.set_action("gamepad:test", "attack", false)
	assert(edges.size() == 2 and not edges[1].pressed and not edges[1].cancelled)
	assert(not controls.is_action_pressed("attack"), "Final accepted release wins over an emulated mouse still held globally")
	Input.action_release("attack")
	# Keep supporting the project's existing programmatic movement tests.
	Input.action_press("forward", 0.45)
	assert(is_equal_approx(controls.get_strength("forward"), 0.45))
	controls.set_context("craft")
	assert(is_zero_approx(controls.get_strength("forward")))
	controls.set_context("play")
	assert(not controls.is_action_pressed("forward"))

	# Analog inputs retain fractional strength and reject rest noise.
	controls.notify_device("keyboard")
	_feed(controls, _axis(JOY_AXIS_LEFT_X, 0.1))
	assert(controls.active_device == "keyboard")
	assert(is_zero_approx(controls.get_axis("left", "right")))
	_feed(controls, _axis(JOY_AXIS_LEFT_X, 0.6))
	assert(controls.active_device == "gamepad")
	assert(controls.get_axis("left", "right") > 0.0 and controls.get_axis("left", "right") < 1.0)
	_feed(controls, _axis(JOY_AXIS_LEFT_X, -0.6))
	assert(controls.get_strength("left") > 0.0 and is_zero_approx(controls.get_strength("right")))
	_feed(controls, _axis(JOY_AXIS_LEFT_X, 0.0))
	assert(is_zero_approx(controls.get_axis("left", "right")))
	_feed(controls, _axis(JOY_AXIS_RIGHT_X, 0.1))
	assert(controls.get_look_vector() == Vector2.ZERO)
	_feed(controls, _axis(JOY_AXIS_RIGHT_X, 0.8))
	assert(controls.get_look_vector().x > 0.0 and controls.get_look_vector().length() <= 1.0)
	controls.set_context("pause")
	controls.set_context("play")
	_feed(controls, _axis(JOY_AXIS_RIGHT_X, 0.8))
	assert(controls.get_look_vector() == Vector2.ZERO)
	_feed(controls, _axis(JOY_AXIS_RIGHT_X, 0.0))
	_feed(controls, _axis(JOY_AXIS_RIGHT_X, 0.8))
	assert(controls.get_look_vector().x > 0.0)
	_feed(controls, _axis(JOY_AXIS_RIGHT_X, 0.0))

	# Hot unplug cancels only that controller, including its charge edge.
	edges.clear()
	_feed(controls, _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0, 1))
	controls.set_action("touch:attack", "attack", true)
	controls._on_joy_connection_changed(1, false)
	assert(edges.size() == 1 and controls.is_action_pressed("attack"))
	controls.set_action("touch:attack", "attack", false)
	assert(edges.size() == 2 and not edges[1].cancelled)
	edges.clear()
	_feed(controls, _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0, 1))
	controls._on_joy_connection_changed(1, false)
	assert(edges.size() == 2 and edges[1].cancelled)
	assert(not controls.is_action_pressed("attack"))

	# B is a gameplay dash or menu back, never both in one context.
	var back := InputEventJoypadButton.new()
	back.button_index = JOY_BUTTON_B
	back.pressed = true
	_feed(controls, back)
	assert(controls.is_action_pressed("dash") and not controls.is_action_pressed("ui_cancel"))
	back.pressed = false
	_feed(controls, back)
	controls.set_context("pause")
	back.pressed = true
	_feed(controls, back)
	assert(controls.is_action_pressed("ui_cancel") and not controls.is_action_pressed("dash"))
	back.pressed = false
	_feed(controls, back)

	controls.apply_settings({"deadzone": 1.0, "touch_opacity": -1.0, "touch_mode": "invalid"}, false)
	assert(controls.settings.deadzone == 0.6 and controls.settings.touch_opacity == 0.2)
	assert(controls.settings.touch_mode == "auto")
	controls.notify_device("touch")
	assert(controls.hint("attack") == "攻击")
	controls.notify_device("gamepad")
	assert("RT" in controls.hint("attack"))
	controls.cancel_all()
	controls.queue_free()
	await process_frame
	print("PASS: input sources, analog controls, cancellation, GUI consumption, hot unplug and settings")
	quit(0)
