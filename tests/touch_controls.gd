extends SceneTree

const TouchControls = preload("res://scripts/touch_controls.gd")

var _actions: Array[Dictionary] = []
var _moves: Array[Vector2] = []
var _looks: Array[Vector2] = []
var _orbits: Array[Vector2] = []
var _pinches: Array[float] = []
var _quick_menu_count := 0
var _touch_use_count := 0

func _initialize() -> void:
	_run.call_deferred()

func _touch(surface: TouchControls, index: int, position: Vector2, pressed: bool, cancelled: bool = false, allow_new: bool = true) -> bool:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = surface.get_global_transform_with_canvas() * position
	event.pressed = pressed
	event.canceled = cancelled
	return surface.handle_touch_event(event, allow_new)

func _drag(surface: TouchControls, index: int, position: Vector2) -> bool:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = surface.get_global_transform_with_canvas() * position
	return surface.handle_touch_event(event, false)

func _action_count(action: String, pressed: bool, cancelled: bool = false) -> int:
	var count := 0
	for change: Dictionary in _actions:
		if change["action"] == action and change["pressed"] == pressed and change["cancelled"] == cancelled:
			count += 1
	return count

func _run() -> void:
	create_timer(15.0).timeout.connect(func():
		printerr("FAIL: touch control test timed out")
		quit(1)
	)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	root.add_child(viewport)
	var layer := CanvasLayer.new()
	viewport.add_child(layer)
	var surface := TouchControls.new()
	layer.add_child(surface)
	surface.action_changed.connect(func(action: String, pressed: bool, cancelled: bool):
		_actions.append({"action": action, "pressed": pressed, "cancelled": cancelled})
	)
	surface.movement_changed.connect(func(value: Vector2): _moves.append(value))
	surface.look_dragged.connect(func(value: Vector2): _looks.append(value))
	surface.orbit_dragged.connect(func(value: Vector2): _orbits.append(value))
	surface.zoom_pinched.connect(func(delta: float): _pinches.append(delta))
	surface.quick_menu_requested.connect(func(): _quick_menu_count += 1)
	surface.touch_used.connect(func(): _touch_use_count += 1)
	surface.set_gameplay_enabled(true)
	await process_frame
	await process_frame
	assert(surface.mouse_filter == Control.MOUSE_FILTER_IGNORE, "The full-screen overlay must not block GUI controls")
	assert(surface.size.is_equal_approx(Vector2(1280, 800)))

	var joystick: Rect2 = surface.get_joystick_rect()
	var attack: Rect2 = surface.get_control_rect("attack")
	var look: Rect2 = surface.get_look_rect()
	var look_at := look.position + Vector2(24, 30)
	# A new touch is intentionally left to the GUI before the unhandled phase.
	assert(not _touch(surface, 0, joystick.get_center(), true, false, false))
	assert(surface.get_active_touch_count() == 0)

	# Three independent fingers can move, observe, and charge simultaneously.
	assert(_touch(surface, 0, joystick.get_center() + Vector2(0, -40), true))
	assert(surface.get_movement().y < -0.2 and surface.get_movement().y > -0.8)
	assert(_touch(surface, 1, look_at, true))
	assert(_touch(surface, 2, attack.get_center(), true))
	assert(surface.get_active_touch_count() == 3)
	assert(_action_count("attack", true) == 1)
	assert(_drag(surface, 1, look_at + Vector2(15, -8)))
	assert(_looks.back().is_equal_approx(Vector2(15, -8)))
	assert(_drag(surface, 2, attack.get_center() + Vector2(-18, -6)))
	assert(_looks.back().is_equal_approx(Vector2(-18, -6)), "The attack finger must be able to adjust aim while charging")
	# The movement finger can leave its original area and release off screen.
	assert(_drag(surface, 0, Vector2(-150, -150)))
	assert(surface.get_movement().length() <= 1.001)
	assert(_touch(surface, 0, Vector2(-150, -150), false))
	assert(surface.get_movement().is_zero_approx())
	assert(surface.get_active_touch_count() == 2)
	assert(_action_count("attack", false) == 0, "Releasing movement must not release another finger's attack")
	assert(_touch(surface, 1, Vector2(3000, 3000), false))
	assert(_touch(surface, 2, Vector2(3000, 3000), false))
	assert(_action_count("attack", false) == 1)

	# Two contacts on one button still represent a single held action.
	assert(_touch(surface, 3, attack.get_center(), true))
	assert(_touch(surface, 4, attack.get_center(), true))
	assert(_action_count("attack", true) == 2)
	assert(_touch(surface, 3, Vector2.ZERO, false))
	assert(_action_count("attack", false) == 1)
	assert(_touch(surface, 4, Vector2.ZERO, false, true))
	assert(_action_count("attack", false, true) == 1, "A cancelled charging finger must cancel rather than fire")
	assert(surface.get_active_touch_count() == 0)

	# Ascend/descend and sprint are held buttons; dragging them does not look.
	var old_look_count := _looks.size()
	for action: String in ["ascend", "descend", "sprint"]:
		var rect: Rect2 = surface.get_control_rect(action)
		assert(_touch(surface, 5, rect.get_center(), true))
		assert(_drag(surface, 5, rect.get_center() + Vector2(40, 10)))
		assert(_touch(surface, 5, Vector2.ZERO, false))
		assert(_action_count(action, true) == 1 and _action_count(action, false) == 1)
	assert(_looks.size() == old_look_count)
	var quick: Rect2 = surface.get_control_rect("quick_menu")
	assert(_touch(surface, 6, quick.get_center(), true))
	assert(_quick_menu_count == 1)
	assert(_action_count("quick_menu", true) == 0, "Quick menu has its own signal and must not dispatch twice")
	assert(_touch(surface, 6, quick.get_center(), false))

	# The top HUD band is not a look target.
	assert(not _touch(surface, 7, Vector2(640, 80), true))
	assert(not surface.handle_touch_event(InputEventMouseButton.new()))
	assert(not surface.handle_touch_event(InputEventKey.new()))
	assert(_touch_use_count >= 9)

	# Screen changes, hidden layers, and focus loss cancel every held contact.
	assert(_touch(surface, 8, attack.get_center(), true))
	assert(_touch(surface, 9, joystick.get_center() + Vector2(40, 0), true))
	surface.set_gameplay_enabled(false)
	assert(surface.get_active_touch_count() == 0 and surface.get_movement().is_zero_approx())
	assert(_action_count("attack", false, true) == 2)
	assert(not _touch(surface, 10, attack.get_center(), true))
	assert(_drag(surface, 8, Vector2.ZERO), "An old contact stays consumed while the menu is open")
	assert(_touch(surface, 8, Vector2.ZERO, false))
	assert(_touch(surface, 9, Vector2.ZERO, false))
	surface.set_gameplay_enabled(true)
	assert(_touch(surface, 8, attack.get_center(), true))
	surface.hide()
	assert(surface.get_active_touch_count() == 0)
	assert(_action_count("attack", false, true) == 3)
	assert(not _touch(surface, 10, attack.get_center(), true))
	surface.show()
	assert(_touch(surface, 8, attack.get_center(), true), "A fresh contact may reuse an index after cancellation")
	surface._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	assert(surface.get_active_touch_count() == 0)
	assert(_action_count("attack", false, true) == 4)
	_touch(surface, 8, Vector2.ZERO, false)

	# Dual-finger pinch zoom in look area and seamless single-finger look fallback.
	var pinch_p0 := look.position + Vector2(36, 48)
	var pinch_p1 := look.position + Vector2(116, 48)
	_pinches.clear()
	assert(_touch(surface, 20, pinch_p0, true))
	assert(_touch(surface, 21, pinch_p1, true))
	assert(surface.get_active_touch_count() == 2)
	assert(_drag(surface, 20, pinch_p0 + Vector2(-24, 0)))
	assert(_drag(surface, 21, pinch_p1 + Vector2(24, 0)))
	assert(not _pinches.is_empty(), "Two-finger reverse spread in look area must emit zoom_pinched")
	var total_pinch := 0.0
	for pd: float in _pinches:
		total_pinch += pd
	assert(total_pinch > 30.0, "Two-finger spread must report positive pinch distance delta")
	assert(_touch(surface, 21, pinch_p1 + Vector2(24, 0), false))
	assert(surface.get_active_touch_count() == 1)
	var looks_before_fallback := _looks.size()
	var orbits_before_fallback := _orbits.size()
	assert(_drag(surface, 20, pinch_p0 + Vector2(6, -12)))
	assert(_looks.size() == looks_before_fallback + 1, "Lifting one finger must seamlessly fall back to single-finger look_dragged")
	assert(_looks.back().is_equal_approx(Vector2(30, -12)))
	assert(_orbits.size() == orbits_before_fallback, "Remaining single finger must not stay stuck in orbit mode")
	assert(_touch(surface, 20, pinch_p0 + Vector2(6, -12), false))
	assert(surface.get_active_touch_count() == 0)

	# Dynamic same-orientation resize (mobile browser address bar collapse/expand) preserves active touches.
	viewport.size = Vector2i(844, 390)
	await process_frame
	await process_frame
	surface.configure({"touch_scale": 1.0, "touch_opacity": 0.75})
	var joy_hold_pos := surface.get_joystick_rect().get_center() + Vector2(0, -36)
	var atk_hold_pos := surface.get_control_rect("attack").get_center()
	var atk_cancel_before := _action_count("attack", false, true)
	var atk_release_before := _action_count("attack", false, false)
	assert(_touch(surface, 30, joy_hold_pos, true))
	assert(_touch(surface, 31, atk_hold_pos, true))
	assert(surface.get_active_touch_count() == 2 and surface.get_movement().y < -0.15)
	viewport.size = Vector2i(844, 356)
	surface.size = Vector2(844, 356)
	await process_frame
	await process_frame
	assert(not surface._touches.is_empty() and surface.get_active_touch_count() == 2, "Same-orientation resize must not clear _touches")
	assert(_action_count("attack", false, true) == atk_cancel_before, "Same-orientation resize must not cancel held attack")
	assert(_action_count("attack", false, false) == atk_release_before, "Same-orientation resize must not release held attack")
	var post_resize_drag := surface._active_joystick_center + Vector2(58, 10)
	assert(_drag(surface, 30, post_resize_drag))
	assert(surface.get_movement().x > 0.35, "InputEventScreenDrag after same-orientation resize must still update joystick movement")
	assert(_touch(surface, 30, post_resize_drag, false))
	assert(_touch(surface, 31, atk_hold_pos, false))
	assert(surface.get_active_touch_count() == 0)
	assert(_action_count("attack", false, false) == atk_release_before + 1)

	# Main controls stay within bounds and clear of each other at practical
	# landscape phone, tablet, and desktop sizes, including enlarged controls.
	var resolutions := [Vector2i(640, 360), Vector2i(844, 390), Vector2i(1024, 768), Vector2i(1280, 800)]
	for resolution: Vector2i in resolutions:
		viewport.size = resolution
		await process_frame
		await process_frame
		for scale: float in [0.7, 1.0, 1.5]:
			surface.configure({"touch_scale": scale, "touch_opacity": 0.6})
			var safe: Rect2 = surface.get_safe_rect()
			assert(safe.position.is_zero_approx() and safe.size.is_equal_approx(Vector2(resolution)), "Desktop windows must use viewport bounds, not monitor work areas")
			var actions: Array = TouchControls.LABELS.keys()
			for i in actions.size():
				var a: Rect2 = surface.get_control_rect(str(actions[i]))
				assert(safe.encloses(a), "%s at %s / scale %.1f exceeds safe area: %s" % [actions[i], resolution, scale, a])
				assert(not a.intersects(surface.get_joystick_rect()), "A touch button must not cover the movement joystick")
				for j in range(i + 1, actions.size()):
					assert(not a.intersects(surface.get_control_rect(str(actions[j]))), "Touch button heat areas overlap")
			assert(safe.encloses(surface.get_joystick_rect()))
			assert(is_equal_approx(surface.modulate.a, 0.6))
	viewport.queue_free()
	await process_frame
	print("PASS: multitouch movement/look/attack, ownership, cancellation, GUI priority, responsive control bounds")
	quit(0)
