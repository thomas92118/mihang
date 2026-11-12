extends SceneTree

const Game = preload("res://scripts/game.gd")
const EnergyOrb = preload("res://scripts/energy_orb.gd")

class InputRecoveryGame extends Game:
	# Headless has no cursor; observe whether recovery runs inside the click.
	var input_sync_count := 0
	func _sync_input_presentation() -> void:
		input_sync_count += 1
		super._sync_input_presentation()

func _initialize() -> void:
	_run.call_deferred()

func _orbs(game: Node) -> int:
	var count := 0
	for child: Node in game.get_children():
		if child.get_script() == EnergyOrb:
			count += 1
	return count

func _mouse(pressed: bool, emulated: bool = false) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	if emulated:
		event.device = InputEvent.DEVICE_ID_EMULATION
	return event

func _run() -> void:
	create_timer(45.0).timeout.connect(func():
		printerr("FAIL: input integration timed out")
		quit(1)
	)
	var game := InputRecoveryGame.new()
	root.add_child(game)
	var controls: Node = game.input_controller
	controls.apply_settings(controls.DEFAULT_SETTINGS, false)
	game._start("explore")
	game.set_process(false)
	game.set_physics_process(false)
	game.ocean.set_process(false)
	game.diver.set_process(false)
	game.diver.set_physics_process(false)
	await process_frame

	# Rebuilding keyboard defaults must preserve controller events and be idempotent.
	var bindings_before: int = InputMap.action_get_events("attack").size()
	game._setup_input()
	controls.setup_defaults()
	assert(InputMap.action_get_events("attack").size() == bindings_before)
	var has_trigger := false
	for binding: InputEvent in InputMap.action_get_events("attack"):
		if binding is InputEventJoypadMotion:
			has_trigger = true
	assert(has_trigger)
	for binding: InputEvent in InputMap.action_get_events("descend"):
		assert(not (binding is InputEventKey and binding.physical_keycode == KEY_C), "C must only toggle the shield; Ctrl descends")

	controls.notify_device("touch")
	await process_frame
	assert(game.touch_controls.visible)
	assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	controls.notify_device("gamepad")
	await process_frame
	assert(not game.touch_controls.visible)
	assert(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE)
	controls.notify_device("keyboard")
	await process_frame
	assert(not game.touch_controls.visible)
	if DisplayServer.get_name() != "headless":
		assert(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)

	# A charge is shared across devices and fires only when the last source releases.
	game._switch_weapon("sonic")
	game.diver.equip_anim_time = 0.0
	controls.set_action("touch_button_attack", "attack", true)
	assert(game.diver.gun_trigger_held)
	controls.set_action("gamepad_test", "attack", true)
	game.diver.charge_time = 0.2
	controls.set_action("touch_button_attack", "attack", false)
	assert(game.diver.gun_trigger_held)
	controls.set_action("gamepad_test", "attack", false)
	assert(not game.diver.gun_trigger_held)
	assert(_orbs(game) == 0)

	game.diver.attack_cooldown = 0.0
	controls.set_action("touch_button_attack", "attack", true)
	game.diver.charge_time = 3.0
	controls.cancel_source("touch_button_attack")
	assert(not game.diver.gun_trigger_held and _orbs(game) == 0, "A canceled touch must not fire a charged orb")
	controls.set_action("touch_button_attack", "attack", true)
	game.diver.charge_time = 3.0
	controls.set_action("touch_button_attack", "attack", false)
	assert(_orbs(game) == 1)
	controls.set_action("touch_button_attack", "attack", false)
	assert(_orbs(game) == 1, "Duplicate releases must not fire twice")

	# Opening a menu cancels combat and exposes all shortcuts without unpausing early.
	game.diver.attack_cooldown = 0.0
	controls.set_action("touch_button_attack", "attack", true)
	game.diver.charge_time = 3.0
	game._on_hud_action_requested("quick_menu")
	assert(game.screen == "quick" and paused)
	assert(not game.diver.gun_trigger_held and not game.touch_controls.visible)
	assert(_orbs(game) == 1)
	assert(is_zero_approx(float(controls.get_strength("attack"))))
	game._on_hud_action_requested("toggle_shield")
	assert(game.screen == "play" and not paused and game.diver.shield_active)
	game._set_screen("pause")
	game._on_hud_action_requested("controls")
	assert(game.screen == "controls")
	game._close_input_screen()
	assert(game.screen == "pause" and paused)
	game._set_screen("quick")
	game._on_hud_action_requested("controls")
	game._close_input_screen()
	assert(game.screen == "quick" and paused)
	game._close_input_screen()

	# A half-strength virtual stick must produce half the swimming velocity.
	game.diver.position = Vector3(180, -6, 70)
	game.diver.rotation = Vector3.ZERO
	game.diver.camera.rotation = Vector3.ZERO
	game.diver.velocity = Vector3.ZERO
	controls.set_axis("touch_move_y", "forward", "backward", -1.0)
	game.diver._physics_process(0.1)
	var full_speed: float = game.diver.velocity.length()
	game.diver.position = Vector3(180, -6, 70)
	game.diver.velocity = Vector3.ZERO
	controls.set_axis("touch_move_y", "forward", "backward", -0.5)
	game.diver._physics_process(0.1)
	assert(is_equal_approx(game.diver.velocity.length(), full_speed * 0.5))
	controls.set_axis("touch_move_y", "forward", "backward", 0.0)
	controls.set_axis("touch_move_x", "left", "right", 0.5)
	game.diver._physics_process(0.1)
	assert(game.diver.rotation.y < 0.0, "Right stick movement keeps the game's right-turn semantics")
	controls.cancel_all()

	# Displacement-based touch look and rate-based stick look have distinct time units.
	game.diver.rotation = Vector3.ZERO
	game.diver.apply_look_rate(Vector2(1, 0), 0.1)
	var yaw_once: float = game.diver.rotation.y
	game.diver.rotation = Vector3.ZERO
	for index in range(10):
		game.diver.apply_look_rate(Vector2(1, 0), 0.01)
	assert(is_equal_approx(game.diver.rotation.y, yaw_once))
	game.diver.rotation = Vector3.ZERO
	game.diver.apply_look_delta(Vector2(100, 0), true)
	var touch_yaw: float = game.diver.rotation.y
	assert(touch_yaw < 0.0)

	# The same virtual axes reach the actual submarine piloting path.
	var sub: Node3D = game.ocean.get_submarines()[0]
	game._board_submarine(sub)
	sub.position = Vector3(180, -20, 70)
	sub.rotation = Vector3.ZERO
	game.diver.rotation = Vector3.ZERO
	sub.velocity = Vector3.ZERO
	controls.set_axis("touch_move_y", "forward", "backward", -0.5)
	controls.set_action("touch_button_ascend", "ascend", true)
	game._physics_process(0.1)
	assert(sub.velocity.y > 0.0 and sub.velocity.z < 0.0)
	controls.cancel_all()
	game._disembark_submarine()

	# Losing focus while charging pauses and cancels, rather than firing on resume.
	game._switch_weapon("sonic")
	game.diver.equip_anim_time = 0.0
	game.diver.attack_cooldown = 0.0
	controls.set_action("touch_button_attack", "attack", true)
	game.diver.charge_time = 3.0
	game._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	assert(game.screen == "pause" and not game.diver.gun_trigger_held, "Web canvas blur must pause and cancel held attacks")
	# Desktop can send both notifications for one focus loss.
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert(game.screen == "pause" and not game.diver.gun_trigger_held)
	assert(_orbs(game) == 1)
	game._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	assert(game.screen == "pause", "Focus alone must not resume gameplay or request capture")
	game._set_screen("play")
	assert(not controls.is_action_pressed("attack"))

	# A real click retries a lost/rejected pointer lock synchronously, even when
	# the active device did not change. The recovery click must not charge/fire.
	for device: String in ["keyboard", "gamepad", "keyboard"]:
		controls.notify_device(device)
		await process_frame
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		var click := _mouse(true)
		controls._input(click)
		var syncs_before: int = game.input_sync_count
		game._unhandled_input(click)
		assert(game.input_sync_count > syncs_before, "Mouse capture must be retried in the pressed event, without waiting for a device change")
		assert(controls.active_device == "keyboard")
		assert(not controls.is_action_pressed("attack") and not game.diver.gun_trigger_held)
		if DisplayServer.get_name() != "headless":
			assert(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
			var motion := InputEventMouseMotion.new()
			motion.relative = Vector2(40, 10)
			var yaw: float = game.diver.rotation.y
			game.diver._unhandled_input(motion)
			assert(not is_equal_approx(game.diver.rotation.y, yaw), "Mouse look must work after recapture")
		click = _mouse(false)
		controls._input(click)
		game._unhandled_input(click)
		assert(not controls.is_action_pressed("attack") and _orbs(game) == 1)

	# Touch-emulated mouse events and menu clicks must never capture the cursor.
	var ignored_click := _mouse(true, true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var syncs_before: int = game.input_sync_count
	game._unhandled_input(ignored_click)
	assert(game.input_sync_count == syncs_before)
	ignored_click = _mouse(true)
	game._set_screen("pause")
	syncs_before = game.input_sync_count
	game._unhandled_input(ignored_click)
	assert(game.input_sync_count == syncs_before and game.screen == "pause")
	ignored_click = _mouse(false)
	controls._input(ignored_click)
	game._unhandled_input(ignored_click)
	game._set_screen("play")
	controls.apply_settings({"touch_mode": "on"}, false)
	ignored_click = _mouse(true)
	syncs_before = game.input_sync_count
	controls._input(ignored_click)
	game._unhandled_input(ignored_click)
	assert(game.input_sync_count == syncs_before and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Forced touch controls must keep the cursor visible")
	assert(controls.is_action_pressed("attack"), "Clicks with forced touch controls must retain their normal action")
	controls.cancel_all()
	game.queue_free()
	paused = false
	await process_frame
	print("PASS: integrated touch/gamepad actions, charging, menus, movement, camera, submarine, focus cancellation and mouse recapture")
	quit(0)
