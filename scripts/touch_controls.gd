extends Control
## A multitouch surface. New contacts go through GUI handling first; once a
## finger is claimed it keeps its role until release, even outside that role.

const Art = preload("res://scripts/art_direction.gd")
const SafeArea = preload("res://scripts/presentation/safe_area.gd")

signal action_changed(action: String, pressed: bool, cancelled: bool)
signal movement_changed(value: Vector2)
signal look_dragged(relative: Vector2)
signal orbit_dragged(relative: Vector2)
signal zoom_pinched(distance_delta: float)
signal scope_requested
signal quick_menu_requested
signal touch_used

const LABELS := {
	"attack": "攻击", "interact": "交互", "aim": "瞄准",
	"ascend": "上浮", "descend": "下潜", "sprint": "加速",
	"dash": "突进", "weapon_cycle": "武器", "toggle_shield": "护盾",
	"sonar_ping": "声呐", "lamp": "头灯", "world_map": "海图",
	"pause_game": "暂停", "quick_menu": "快捷"
}
const ICONS := {
	"attack": preload("res://assets/ui/touch_icons/attack.png"),
	"interact": preload("res://assets/ui/touch_icons/interact.png"),
	"aim": preload("res://assets/ui/touch_icons/aim.png"),
	"ascend": preload("res://assets/ui/touch_icons/ascend.png"),
	"descend": preload("res://assets/ui/touch_icons/descend.png"),
	"sprint": preload("res://assets/ui/touch_icons/sprint.png"),
	"dash": preload("res://assets/ui/touch_icons/dash.png"),
	"weapon_cycle": preload("res://assets/ui/touch_icons/weapon_cycle.png"),
	"toggle_shield": preload("res://assets/ui/touch_icons/toggle_shield.png"),
	"sonar_ping": preload("res://assets/ui/touch_icons/sonar_ping.png"),
	"lamp": preload("res://assets/ui/touch_icons/lamp.png"),
	"world_map": preload("res://assets/ui/touch_icons/world_map.png"),
	"pause_game": preload("res://assets/ui/touch_icons/pause_game.png"),
	"quick_menu": preload("res://assets/ui/touch_icons/quick_menu.png"),
	"scope_exit": preload("res://assets/ui/touch_icons/scope_exit.png"),
	"torpedo": preload("res://assets/ui/touch_icons/torpedo.png"),
	"sub_exit": preload("res://assets/ui/touch_icons/sub_exit.png"),
}
const QUICK_SLOTS: Array[String] = ["weapon_cycle", "toggle_shield", "sonar_ping", "lamp"]
const MEDALLION_FILL_RATIO := 180.0 / 192.0

var _gameplay_enabled := false
var _settings := {"touch_scale": 1.0, "touch_opacity": 0.75}
var _touches: Dictionary = {}
var _cancelled_touches: Dictionary = {}
var _action_holders: Dictionary = {}
var _buttons: Dictionary = {}
var _safe_rect := Rect2()
var _movement_rect := Rect2()
var _look_rect := Rect2()
var _right_cluster_rect := Rect2()
var _quick_slots_rect := Rect2()
var _joystick_center := Vector2.ZERO
var _joystick_radius := 80.0
var _active_joystick_center := Vector2.ZERO
var _active_joystick_radius := 80.0
var _movement := Vector2.ZERO
var _move_touch := -1
var _look_touches: Array[int] = []
var _orbit_prev_mid := Vector2.ZERO
var _pinch_prev_dist := 0.0
var _last_aim_tap_msec: int = -10000
var _unit := 1.0
var _emulated_pointer_owned := false
var _emulated_clear_queued := false
var _has_orientation_init := false
var _was_landscape := true
var _in_submarine := false
var _sub_type := ""
var _has_active_torpedo := false
var _is_scoped := false
var _shield_on := false
var _lamp_on := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_on_resized)
	visibility_changed.connect(_on_visibility_changed)
	_rebuild_layout()
	configure(_settings)

func configure(settings: Dictionary) -> void:
	var old_scale := float(_settings.get("touch_scale", 1.0))
	_settings = {
		"touch_scale": clampf(float(settings.get("touch_scale", 1.0)), 0.7, 1.5),
		"touch_opacity": clampf(float(settings.get("touch_opacity", 0.75)), 0.20, 1.0)
	}
	modulate.a = float(_settings["touch_opacity"])
	var next_safe := _calculate_safe_rect()
	if not is_equal_approx(old_scale, float(_settings["touch_scale"])) or _buttons.is_empty() or not _safe_rect.is_equal_approx(next_safe):
		_apply_responsive_relayout()
	queue_redraw()

func set_vehicle_context(in_submarine: bool, sub_type: String = "", has_active_torpedo: bool = false, is_scoped: bool = false, shield_on: bool = false, lamp_on: bool = false) -> void:
	if _in_submarine == in_submarine and _sub_type == sub_type and _has_active_torpedo == has_active_torpedo and _is_scoped == is_scoped and _shield_on == shield_on and _lamp_on == lamp_on:
		return
	_in_submarine = in_submarine
	_sub_type = sub_type
	_has_active_torpedo = has_active_torpedo
	_is_scoped = is_scoped
	_shield_on = shield_on
	_lamp_on = lamp_on
	queue_redraw()

func _process(_delta: float) -> void:
	if not _gameplay_enabled or not is_visible_in_tree():
		return
	var next_safe := _calculate_safe_rect()
	if not _safe_rect.is_equal_approx(next_safe):
		_apply_responsive_relayout()

func _on_resized() -> void:
	_apply_responsive_relayout()

func _apply_responsive_relayout() -> void:
	var next_safe := _calculate_safe_rect()
	if next_safe.size.x <= 0.0 or next_safe.size.y <= 0.0:
		return
	var next_landscape := next_safe.size.x >= next_safe.size.y
	var preserve_active := _gameplay_enabled and is_visible_in_tree() and not _touches.is_empty() and _has_orientation_init and next_landscape == _was_landscape
	if not preserve_active and not _touches.is_empty():
		cancel_all()
	_relayout_rects(next_safe, preserve_active)

func set_gameplay_enabled(enabled: bool) -> void:
	if not enabled:
		cancel_all()
	_gameplay_enabled = enabled
	queue_redraw()

func cancel_all() -> void:
	# A held contact must not click the menu that has just replaced this surface.
	for index: int in _touches:
		_cancelled_touches[index] = true
	var released_actions := _action_holders.keys()
	var had_movement := _move_touch != -1 or not _movement.is_zero_approx()
	_touches.clear()
	_action_holders.clear()
	_move_touch = -1
	_look_touches.clear()
	_pinch_prev_dist = 0.0
	_movement = Vector2.ZERO
	for action: String in released_actions:
		action_changed.emit(action, false, true)
	if had_movement:
		movement_changed.emit(Vector2.ZERO)
	queue_redraw()

func get_control_rect(action: String) -> Rect2:
	return _buttons.get(action, Rect2())

func get_joystick_rect() -> Rect2:
	return _movement_rect

func get_look_rect() -> Rect2:
	return _look_rect

func get_safe_rect() -> Rect2:
	return _safe_rect

func get_active_touch_count() -> int:
	return _touches.size()

func get_movement() -> Vector2:
	return _movement

func get_hud_safe_margins() -> Dictionary:
	var top_bottom := _safe_rect.position.y
	for top_key: String in ["world_map", "quick_menu", "pause_game"]:
		if _buttons.has(top_key):
			top_bottom = maxf(top_bottom, (_buttons[top_key] as Rect2).end.y)
	var qs_top := _safe_rect.end.y
	for qs_key: String in QUICK_SLOTS:
		if _buttons.has(qs_key):
			qs_top = minf(qs_top, (_buttons[qs_key] as Rect2).position.y)
	var left_top := _movement_rect.position.y
	if _buttons.has("sprint"):
		left_top = minf(left_top, (_buttons["sprint"] as Rect2).position.y)
	var right_top := _right_cluster_rect.position.y if _right_cluster_rect.size.y > 0.0 else _safe_rect.end.y
	return {
		"top_bar_bottom": top_bottom,
		"quick_slots_top": qs_top,
		"left_cluster_top": left_top,
		"right_cluster_top": right_top,
		"joystick_rect": _movement_rect,
		"right_cluster_rect": _right_cluster_rect,
		"touch_scale": float(_settings.get("touch_scale", 1.0)),
	}

func _schedule_emulated_pointer_clear() -> void:
	if _emulated_clear_queued:
		return
	_emulated_clear_queued = true
	_clear_emulated_pointer_deferred.call_deferred()

func _clear_emulated_pointer_deferred() -> void:
	_emulated_clear_queued = false
	if not _touches.has(0) and not _cancelled_touches.has(0):
		_emulated_pointer_owned = false

func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		cancel_all()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_EXIT_TREE]:
		cancel_all()

func _input(event: InputEvent) -> void:
	# Mouse emulation is only swallowed for a contact owned by this surface.
	# Other HUD controls continue to receive mouse/touch input normally.
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == InputEvent.DEVICE_ID_EMULATION:
		if _emulated_pointer_owned:
			if event is InputEventMouseButton and not event.pressed:
				_emulated_pointer_owned = false
			get_viewport().set_input_as_handled()
		return
	if handle_touch_event(event, false):
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	# UI buttons get the first opportunity to accept a new finger. This matters
	# for HUD buttons beneath the right-hand look region.
	if handle_touch_event(event, true):
		get_viewport().set_input_as_handled()

func handle_touch_event(event: InputEvent, allow_new: bool = true) -> bool:
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag):
		return false
	var index: int = event.index
	if _cancelled_touches.has(index):
		if event is InputEventScreenTouch and event.pressed and not event.canceled:
			# A fresh press may reuse an index after a platform cancellation.
			_cancelled_touches.erase(index)
		else:
			if event is InputEventScreenTouch:
				_cancelled_touches.erase(index)
				if not _cancelled_touches.has(0) and not _touches.has(0):
					_schedule_emulated_pointer_clear()
			return true
	if _touches.has(index):
		if event is InputEventScreenTouch:
			if event.canceled or not event.pressed:
				_release_touch(index, event.canceled)
		elif event is InputEventScreenDrag:
			_drag_touch(index, _to_local(event.position))
		return true
	if not allow_new or not _gameplay_enabled or not is_visible_in_tree():
		return false
	if event is InputEventScreenTouch and event.pressed and not event.canceled:
		return _begin_touch(index, _to_local(event.position))
	return false

func _to_local(viewport_position: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * viewport_position

func _find_button_at(at: Vector2) -> String:
	for candidate: String in _buttons:
		var rect: Rect2 = _buttons[candidate]
		if rect.has_point(at):
			return candidate
	if _movement_rect.has_point(at):
		return ""
	var best_action := ""
	var best_dist_sq := 26.0
	for candidate: String in _buttons:
		var rect: Rect2 = _buttons[candidate]
		if not rect.grow(5.0).has_point(at):
			continue
		var clamped := Vector2(clampf(at.x, rect.position.x, rect.end.x), clampf(at.y, rect.position.y, rect.end.y))
		var d_sq := at.distance_squared_to(clamped)
		if d_sq < best_dist_sq:
			best_dist_sq = d_sq
			best_action = candidate
	return best_action

func _is_in_button_deadzone(at: Vector2) -> bool:
	for candidate: String in _buttons:
		var rect: Rect2 = _buttons[candidate]
		if rect.grow(6.0).has_point(at):
			return true
	return false

func _sync_dual_look_baseline() -> void:
	if _look_touches.size() < 2:
		_pinch_prev_dist = 0.0
		return
	var c0: Dictionary = _touches.get(_look_touches[0], {})
	var c1: Dictionary = _touches.get(_look_touches[1], {})
	if c0.is_empty() or c1.is_empty():
		return
	var p0 := Vector2(c0["last"])
	var p1 := Vector2(c1["last"])
	_orbit_prev_mid = (p0 + p1) * 0.5
	_pinch_prev_dist = p0.distance_to(p1)

func _begin_touch(index: int, at: Vector2) -> bool:
	var action := _find_button_at(at)
	if not action.is_empty():
		_touches[index] = {"kind": "button", "action": action, "last": at}
		if index == 0:
			_emulated_pointer_owned = true
		if action == "quick_menu":
			touch_used.emit()
			if not _touches.has(index):
				return true
			quick_menu_requested.emit()
		elif action == "aim" and _is_scoped:
			touch_used.emit()
			if not _touches.has(index):
				return true
			_last_aim_tap_msec = -10000
			scope_requested.emit()
		else:
			var holders: Array = _action_holders.get(action, [])
			var was_released := holders.is_empty()
			holders.append(index)
			_action_holders[action] = holders
			touch_used.emit()
			if not _touches.has(index):
				return true
			if was_released:
				action_changed.emit(action, true, false)
				if action == "aim":
					var now_msec := Time.get_ticks_msec()
					if _last_aim_tap_msec >= 0 and (now_msec - _last_aim_tap_msec) <= 300:
						_last_aim_tap_msec = -10000
						scope_requested.emit()
					else:
						_last_aim_tap_msec = now_msec
		queue_redraw()
		return true
	if _move_touch == -1 and _movement_rect.has_point(at):
		_move_touch = index
		_active_joystick_center = _joystick_center
		_active_joystick_radius = _joystick_radius
		_touches[index] = {"kind": "move", "last": at}
		if index == 0:
			_emulated_pointer_owned = true
		touch_used.emit()
		if _touches.has(index):
			_update_movement(at)
		return true
	if _look_touches.size() < 2 and _look_rect.has_point(at) and not _is_in_button_deadzone(at):
		_look_touches.append(index)
		_touches[index] = {"kind": "look", "last": at}
		if index == 0:
			_emulated_pointer_owned = true
		_sync_dual_look_baseline()
		touch_used.emit()
		return true
	return false

func _drag_touch(index: int, at: Vector2) -> void:
	var contact: Dictionary = _touches[index]
	var delta: Vector2 = at - Vector2(contact["last"])
	contact["last"] = at
	_touches[index] = contact
	match str(contact["kind"]):
		"move":
			_update_movement(at)
		"look":
			if _look_touches.size() == 1:
				look_dragged.emit(delta.limit_length(240.0 * _unit))
			elif _look_touches.size() >= 2:
				var c0: Dictionary = _touches.get(_look_touches[0], {})
				var c1: Dictionary = _touches.get(_look_touches[1], {})
				if not c0.is_empty() and not c1.is_empty():
					var p0 := Vector2(c0["last"])
					var p1 := Vector2(c1["last"])
					var mid := (p0 + p1) * 0.5
					var mid_delta := mid - _orbit_prev_mid
					_orbit_prev_mid = mid
					var dist := p0.distance_to(p1)
					var dist_delta := dist - _pinch_prev_dist
					_pinch_prev_dist = dist
					if mid_delta.length_squared() > 0.01:
						orbit_dragged.emit(mid_delta.limit_length(240.0 * _unit))
					if absf(dist_delta) > 0.25:
						zoom_pinched.emit(dist_delta)
		"button":
			# A shooting or aiming finger can also aim; utility pills do not.
			if str(contact.get("action", "")) in ["attack", "aim"]:
				look_dragged.emit(delta.limit_length(240.0 * _unit))

func _release_touch(index: int, cancelled: bool) -> void:
	var contact: Dictionary = _touches[index]
	_touches.erase(index)
	if not _touches.has(0) and not _cancelled_touches.has(0):
		_schedule_emulated_pointer_clear()
	match str(contact["kind"]):
		"move":
			_move_touch = -1
			_movement = Vector2.ZERO
			movement_changed.emit(Vector2.ZERO)
		"look":
			_look_touches.erase(index)
			_sync_dual_look_baseline()
		"button":
			var action := str(contact.get("action", ""))
			if _action_holders.has(action):
				var holders: Array = _action_holders[action]
				holders.erase(index)
				if holders.is_empty():
					_action_holders.erase(action)
					action_changed.emit(action, false, cancelled)
				else:
					_action_holders[action] = holders
	queue_redraw()

func _update_movement(at: Vector2) -> void:
	var center := _active_joystick_center if _move_touch != -1 else _joystick_center
	var radius := _active_joystick_radius if _move_touch != -1 else _joystick_radius
	var raw := ((at - center) / maxf(radius, 1.0)).limit_length()
	# A short circular dead zone avoids motion while resting a thumb.
	var length := raw.length()
	_movement = Vector2.ZERO if length <= 0.10 else raw.normalized() * ((length - 0.10) / 0.90)
	movement_changed.emit(_movement)
	queue_redraw()

func _calculate_safe_rect() -> Rect2:
	var full := Rect2(Vector2.ZERO, size)
	if not is_inside_tree():
		return full
	var vp := get_viewport()
	if vp == null:
		return full
	if full.size.x <= 0.0 or full.size.y <= 0.0:
		full = Rect2(Vector2.ZERO, vp.get_visible_rect().size)
	var safe := SafeArea.get_safe_rect(vp)
	if not vp.get_visible_rect().size.is_equal_approx(full.size):
		var insets: Dictionary = SafeArea.get_insets(vp)
		var l := float(insets.get("left", 0.0))
		var r := float(insets.get("right", 0.0))
		var t := float(insets.get("top", 0.0))
		var b := float(insets.get("bottom", 0.0))
		safe = Rect2(Vector2(l, t), Vector2(maxf(160.0, full.size.x - l - r), maxf(160.0, full.size.y - t - b)))
	var clipped := full.intersection(safe)
	return clipped if clipped.size.x > 0.0 and clipped.size.y > 0.0 else full

func _rebuild_layout() -> void:
	var next_safe := _calculate_safe_rect()
	if next_safe.size.x <= 0.0 or next_safe.size.y <= 0.0:
		cancel_all()
		_safe_rect = next_safe
		return
	var next_landscape := next_safe.size.x >= next_safe.size.y
	var preserve_active := _gameplay_enabled and is_visible_in_tree() and not _touches.is_empty() and _has_orientation_init and next_landscape == _was_landscape
	if not preserve_active:
		cancel_all()
	_relayout_rects(next_safe, preserve_active)

func _relayout_rects(next_safe: Rect2, preserve_active_joystick: bool = false) -> void:
	_safe_rect = next_safe
	_was_landscape = _safe_rect.size.x >= _safe_rect.size.y
	_has_orientation_init = true
	if _safe_rect.size.x >= _safe_rect.size.y:
		_build_landscape_layout()
	else:
		_build_portrait_layout()
	if not preserve_active_joystick or _move_touch == -1:
		_active_joystick_center = _joystick_center
		_active_joystick_radius = _joystick_radius
	_update_cluster_bounds()
	queue_redraw()

func _update_cluster_bounds() -> void:
	var has_right := false
	var r_box := Rect2()
	for key: String in ["attack", "descend", "ascend", "interact", "aim", "dash"]:
		if _buttons.has(key):
			var b: Rect2 = _buttons[key]
			r_box = b if not has_right else r_box.merge(b)
			has_right = true
	_right_cluster_rect = r_box if has_right else Rect2()
	var has_qs := false
	var q_box := Rect2()
	for qs_key: String in QUICK_SLOTS:
		if _buttons.has(qs_key):
			var qb: Rect2 = _buttons[qs_key]
			q_box = qb if not has_qs else q_box.merge(qb)
			has_qs = true
	_quick_slots_rect = q_box if has_qs else Rect2()

func _landscape_metrics(u: float, shrink: float = 1.0) -> Dictionary:
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

func _landscape_bounds(m: Dictionary) -> Vector2:
	var pad: float = m["pad"]
	var gap: float = m["gap"]
	var qs_span := maxf(4.0 * float(m["qs_d"]) + 3.0 * gap, float(m["center_min_w"]))
	var right_w := float(m["atk_d"]) + gap + float(m["sec_d"])
	var bottom_w: float = 2.0 * pad + float(m["joy_box"]) + gap + qs_span + gap + right_w
	var top_w: float = 2.0 * pad + 3.0 * float(m["top_d"]) + 2.0 * gap
	var left_h: float = 2.0 * pad + float(m["top_d"]) + gap + float(m["sec_d"]) + gap + float(m["joy_box"])
	var right1_h: float = 2.0 * pad + float(m["top_d"]) + gap + 2.0 * float(m["sec_d"]) + 2.0 * gap + float(m["atk_d"])
	var right2_h: float = 2.0 * pad + float(m["top_d"]) + gap + 3.0 * float(m["sec_d"]) + 2.0 * gap
	return Vector2(maxf(bottom_w, top_w), maxf(left_h, maxf(right1_h, right2_h)))

func _landscape_fits(m: Dictionary, safe_size: Vector2) -> bool:
	var req := _landscape_bounds(m)
	return req.x <= safe_size.x - 0.5 and req.y <= safe_size.y - 0.5

func _build_landscape_layout() -> void:
	var touch_scale := float(_settings.get("touch_scale", 1.0))
	var base_u := clampf(minf(_safe_rect.size.x / 1280.0, _safe_rect.size.y / 800.0), 0.64, 1.20)
	var desired_u := base_u * touch_scale
	var u := desired_u
	var m := _landscape_metrics(u)
	if not _landscape_fits(m, _safe_rect.size):
		var m0 := _landscape_metrics(0.0)
		if _landscape_fits(m0, _safe_rect.size):
			var lo := 0.0
			var hi := desired_u
			for _step in range(18):
				var mid := (lo + hi) * 0.5
				if _landscape_fits(_landscape_metrics(mid), _safe_rect.size):
					lo = mid
				else:
					hi = mid
			u = lo
			m = _landscape_metrics(u)
		else:
			var req0 := _landscape_bounds(m0)
			var shrink := clampf(minf((_safe_rect.size.x - 1.0) / maxf(req0.x, 1.0), (_safe_rect.size.y - 1.0) / maxf(req0.y, 1.0)), 0.25, 1.0)
			u = 0.5 * shrink
			m = _landscape_metrics(0.0, shrink)
	_unit = clampf(maxf(u, 0.52), 0.50, 1.50)
	var pad: float = m["pad"]
	var gap: float = m["gap"]
	var left := _safe_rect.position.x + pad
	var right := _safe_rect.end.x - pad
	var top := _safe_rect.position.y + pad
	var bottom := _safe_rect.end.y - pad
	var joy_box: float = m["joy_box"]
	var atk_d: float = m["atk_d"]
	var sec_d: float = m["sec_d"]
	var top_d: float = m["top_d"]
	var qs_d: float = m["qs_d"]

	_movement_rect = Rect2(Vector2(left, bottom - joy_box), Vector2(joy_box, joy_box))
	_joystick_center = _movement_rect.get_center()
	_joystick_radius = joy_box * 0.41

	var sprint_x := left + clampf(6.0 * u, 0.0, maxf(0.0, joy_box - sec_d))
	var qs_total_w := 4.0 * qs_d + 3.0 * gap
	var center_min_w := maxf(qs_total_w, float(m["center_min_w"]))
	var right_w := atk_d + gap + sec_d
	var min_right_x := maxf(_movement_rect.end.x + gap + center_min_w + gap, _safe_rect.get_center().x + 88.0)
	var atk_inset_x := clampf(16.0 * u, 0.0, minf(22.0, maxf(0.0, (right - right_w) - min_right_x)))
	var right_needed_h := maxf(atk_d + 2.0 * gap + 2.0 * sec_d, 3.0 * sec_d + 2.0 * gap)
	var max_inset_y := maxf(0.0, (bottom - right_needed_h) - maxf(top + top_d + gap + 6.0, _safe_rect.position.y + 148.0))
	var atk_inset_y := clampf(12.0 * u, 0.0, minf(18.0, max_inset_y))
	var atk_right := right - atk_inset_x
	var atk_bottom := bottom - atk_inset_y
	var atk_x := atk_right - atk_d
	var atk_y := atk_bottom - atk_d
	var right_cluster_left := atk_x - gap - sec_d
	var aim_y := atk_bottom - 2.0 * sec_d - gap
	var descend_y := atk_y - gap - sec_d
	var qs_start_x := _movement_rect.end.x + ((right_cluster_left - _movement_rect.end.x) - qs_total_w) * 0.5
	var qs_y := bottom - qs_d

	_buttons = {
		"attack": Rect2(Vector2(atk_x, atk_y), Vector2(atk_d, atk_d)),
		"descend": Rect2(Vector2(atk_right - sec_d, descend_y), Vector2(sec_d, sec_d)),
		"ascend": Rect2(Vector2(atk_right - sec_d, descend_y - gap - sec_d), Vector2(sec_d, sec_d)),
		"interact": Rect2(Vector2(right_cluster_left, atk_bottom - sec_d), Vector2(sec_d, sec_d)),
		"aim": Rect2(Vector2(atk_x - gap * 0.5 - sec_d, aim_y), Vector2(sec_d, sec_d)),
		"dash": Rect2(Vector2(atk_right - 2.0 * sec_d - gap, aim_y - gap - sec_d), Vector2(sec_d, sec_d)),
		"sprint": Rect2(Vector2(sprint_x, _movement_rect.position.y - gap - sec_d), Vector2(sec_d, sec_d)),
		"world_map": Rect2(Vector2(left, top), Vector2(top_d, top_d)),
		"quick_menu": Rect2(Vector2(right - 2.0 * top_d - gap, top), Vector2(top_d, top_d)),
		"pause_game": Rect2(Vector2(right - top_d, top), Vector2(top_d, top_d)),
	}
	for i in range(QUICK_SLOTS.size()):
		_buttons[QUICK_SLOTS[i]] = Rect2(Vector2(qs_start_x + float(i) * (qs_d + gap), qs_y), Vector2(qs_d, qs_d))

	# Keep the instrument header available to ordinary HUD controls.
	var look_top := maxf(_safe_rect.position.y + _safe_rect.size.y * 0.14, top + top_d + gap)
	if _safe_rect.size.y >= 460.0:
		look_top = maxf(look_top, _safe_rect.position.y + 92.0)
	var look_left := maxf(_movement_rect.end.x + 8.0, _safe_rect.position.x + _safe_rect.size.x * 0.24)
	_look_rect = Rect2(Vector2(look_left, look_top), Vector2(maxf(0.0, right - look_left), maxf(0.0, bottom - look_top)))

func _portrait_metrics(u: float, shrink: float = 1.0) -> Dictionary:
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

func _portrait_bounds(m: Dictionary) -> Vector2:
	var pad: float = m["pad"]
	var gap: float = m["gap"]
	var bottom_w: float = 2.0 * pad + float(m["joy_box"]) + gap + float(m["sec_d"]) + gap + float(m["atk_d"])
	var qs_row_w: float = 2.0 * pad + 4.0 * float(m["qs_d"]) + 3.0 * gap
	var top_row_w: float = 2.0 * pad + 3.0 * float(m["top_d"]) + 2.0 * gap
	var left_cluster_h: float = float(m["joy_box"]) + gap + float(m["sec_d"])
	var right1_cluster_h: float = float(m["atk_d"]) + 2.0 * gap + 2.0 * float(m["sec_d"])
	var right2_cluster_h: float = 3.0 * float(m["sec_d"]) + 2.0 * gap
	var cluster_h := maxf(left_cluster_h, maxf(right1_cluster_h, right2_cluster_h))
	var total_h: float = 2.0 * pad + float(m["top_d"]) + gap + float(m["look_band"]) + float(m["qs_d"]) + float(m["row_gap"]) + cluster_h
	return Vector2(maxf(bottom_w, maxf(qs_row_w, top_row_w)), total_h)

func _portrait_fits(m: Dictionary, safe_size: Vector2) -> bool:
	var req := _portrait_bounds(m)
	return req.x <= safe_size.x - 0.5 and req.y <= safe_size.y - 0.5

func _build_portrait_layout() -> void:
	var touch_scale := float(_settings.get("touch_scale", 1.0))
	var base_u := clampf(minf(_safe_rect.size.x / 390.0, _safe_rect.size.y / 760.0), 0.72, 1.25)
	var desired_u := base_u * touch_scale
	var u := desired_u
	var m := _portrait_metrics(u)
	if not _portrait_fits(m, _safe_rect.size):
		var m0 := _portrait_metrics(0.0)
		if _portrait_fits(m0, _safe_rect.size):
			var lo := 0.0
			var hi := desired_u
			for _step in range(18):
				var mid := (lo + hi) * 0.5
				if _portrait_fits(_portrait_metrics(mid), _safe_rect.size):
					lo = mid
				else:
					hi = mid
			u = lo
			m = _portrait_metrics(u)
		else:
			var req0 := _portrait_bounds(m0)
			var shrink := clampf(minf((_safe_rect.size.x - 1.0) / maxf(req0.x, 1.0), (_safe_rect.size.y - 1.0) / maxf(req0.y, 1.0)), 0.25, 1.0)
			u = 0.55 * shrink
			m = _portrait_metrics(0.0, shrink)
	_unit = clampf(maxf(u, 0.56), 0.50, 1.35)
	var pad: float = m["pad"]
	var gap: float = m["gap"]
	var row_gap: float = m["row_gap"]
	var left := _safe_rect.position.x + pad
	var right := _safe_rect.end.x - pad
	var top := _safe_rect.position.y + pad
	var bottom := _safe_rect.end.y - pad
	var joy_box: float = m["joy_box"]
	var atk_d: float = m["atk_d"]
	var sec_d: float = m["sec_d"]
	var top_d: float = m["top_d"]
	var qs_d: float = m["qs_d"]

	_movement_rect = Rect2(Vector2(left, bottom - joy_box), Vector2(joy_box, joy_box))
	_joystick_center = _movement_rect.get_center()
	_joystick_radius = joy_box * 0.43

	var atk_x := right - atk_d
	var atk_y := bottom - atk_d
	var right_cluster_left := atk_x - gap - sec_d
	var aim_y := bottom - 2.0 * sec_d - gap
	var descend_y := atk_y - gap - sec_d
	_buttons = {
		"attack": Rect2(Vector2(atk_x, atk_y), Vector2(atk_d, atk_d)),
		"descend": Rect2(Vector2(right - sec_d, descend_y), Vector2(sec_d, sec_d)),
		"ascend": Rect2(Vector2(right - sec_d, descend_y - gap - sec_d), Vector2(sec_d, sec_d)),
		"interact": Rect2(Vector2(right_cluster_left, bottom - sec_d), Vector2(sec_d, sec_d)),
		"aim": Rect2(Vector2(atk_x - gap * 0.5 - sec_d, aim_y), Vector2(sec_d, sec_d)),
		"dash": Rect2(Vector2(right - 2.0 * sec_d - gap, aim_y - gap - sec_d), Vector2(sec_d, sec_d)),
		"sprint": Rect2(Vector2(left, _movement_rect.position.y - gap - sec_d), Vector2(sec_d, sec_d)),
		"world_map": Rect2(Vector2(left, top), Vector2(top_d, top_d)),
		"quick_menu": Rect2(Vector2(right - 2.0 * top_d - gap, top), Vector2(top_d, top_d)),
		"pause_game": Rect2(Vector2(right - top_d, top), Vector2(top_d, top_d)),
	}

	var cluster_top := minf(_buttons["sprint"].position.y, minf(_buttons["ascend"].position.y, _buttons["dash"].position.y))
	var qs_y := cluster_top - row_gap - qs_d
	var qs_total_w := 4.0 * qs_d + 3.0 * gap
	var qs_start_x := left + ((right - left) - qs_total_w) * 0.5
	for i in range(QUICK_SLOTS.size()):
		_buttons[QUICK_SLOTS[i]] = Rect2(Vector2(qs_start_x + float(i) * (qs_d + gap), qs_y), Vector2(qs_d, qs_d))

	var min_look_top := top + top_d + gap
	var look_top := min_look_top
	var look_bottom := maxf(look_top + 48.0, minf(bottom, qs_y - 4.0))
	_look_rect = Rect2(Vector2(left, look_top), Vector2(maxf(0.0, right - left), maxf(0.0, look_bottom - look_top)))

func _resolve_icon(action: String) -> Texture2D:
	if action == "aim" and _is_scoped:
		return ICONS["scope_exit"]
	if _in_submarine:
		match action:
			"interact":
				return ICONS["sub_exit"]
			"attack":
				return ICONS["torpedo"]
	return ICONS.get(action)

func _is_toggled_active(action: String) -> bool:
	if action == "aim" and _is_scoped:
		return true
	if action == "toggle_shield" and _shield_on and not _in_submarine:
		return true
	if action == "lamp" and _lamp_on and not _in_submarine:
		return true
	if action == "attack" and _in_submarine and _has_active_torpedo:
		return true
	return false

func _is_dimmed_in_context(action: String) -> bool:
	if _in_submarine and action in ["weapon_cycle", "toggle_shield", "dash"]:
		return true
	if _in_submarine and _sub_type != "mini" and action == "aim" and not _is_scoped:
		return true
	return false

func _draw() -> void:
	if not _gameplay_enabled or _buttons.is_empty():
		return
	var draw_center := _active_joystick_center if _move_touch != -1 else _joystick_center
	var draw_radius := _active_joystick_radius if _move_touch != -1 else _joystick_radius
	var joy_active := _move_touch != -1
	draw_circle(draw_center, draw_radius, Color(Art.PANEL, 0.36 if joy_active else 0.20), true, -1.0, true)
	draw_arc(draw_center, draw_radius, 0.0, TAU, 56, Color(Art.CYAN, 0.76 if joy_active else 0.44), 1.5 * _unit, true)
	draw_arc(draw_center, draw_radius * 0.48, 0.0, TAU, 36, Color(Art.CYAN, 0.16), _unit, true)
	for dir_v: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(draw_center + dir_v * (draw_radius * 0.76), draw_center + dir_v * (draw_radius * 0.90), Color(Art.PAPER, 0.28), _unit, true)
	var knob := draw_center + _movement * draw_radius * 0.64
	var knob_r := draw_radius * 0.27
	draw_circle(knob, knob_r, Color(Art.CYAN, 0.56 if joy_active else 0.28), true, -1.0, true)
	draw_arc(knob, knob_r, 0.0, TAU, 32, Color(Art.PAPER, 0.72 if joy_active else 0.46), 1.2 * _unit, true)

	for action: String in _buttons:
		var rect: Rect2 = _buttons[action]
		var tex := _resolve_icon(action)
		if tex == null:
			continue
		var pressed := _action_holders.has(action)
		var attack := action == "attack"
		var dimmed := _is_dimmed_in_context(action)
		var toggled := _is_toggled_active(action)
		var draw_box := rect.grow(-rect.size.x * 0.04) if pressed else rect
		var center := draw_box.get_center()
		var medallion_r := minf(draw_box.size.x, draw_box.size.y) * 0.5 * MEDALLION_FILL_RATIO
		if not dimmed:
			draw_circle(center + Vector2(0.0, 1.5 * _unit), medallion_r * 0.98, Color(0.01, 0.04, 0.08, 0.28), true, -1.0, true)
		var mod_col := Color(0.68, 0.76, 0.82, 0.38) if dimmed else (Color(1.16, 1.14, 1.06, 1.0) if pressed or toggled else Color(1.0, 1.0, 1.0, 0.95))
		draw_texture_rect(tex, draw_box, false, mod_col)
		if not dimmed and (pressed or toggled):
			var ring_col := Art.AMBER if (attack or action in ["aim", "lamp"]) else Art.CYAN
			draw_arc(center, medallion_r + 1.4 * _unit, 0.0, TAU, 48, Color(ring_col, 0.92 if pressed else 0.78), 1.8 * _unit, true)
