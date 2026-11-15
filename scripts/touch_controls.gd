extends Control
## A multitouch surface. New contacts go through GUI handling first; once a
## finger is claimed it keeps its role until release, even outside that role.

const Art = preload("res://scripts/art_direction.gd")
const SafeArea = preload("res://scripts/presentation/safe_area.gd")

signal action_changed(action: String, pressed: bool, cancelled: bool)
signal movement_changed(value: Vector2)
signal look_dragged(relative: Vector2)
signal orbit_dragged(relative: Vector2)
signal quick_menu_requested
signal touch_used

const LABELS := {
	"attack": "攻击", "interact": "交互", "aim": "瞄准",
	"ascend": "上浮", "descend": "下潜", "sprint": "加速",
	"dash": "突进", "weapon_cycle": "武器", "toggle_shield": "护盾",
	"sonar_ping": "声呐", "lamp": "头灯", "world_map": "海图",
	"pause_game": "暂停", "quick_menu": "快捷"
}
const QUICK_SLOTS: Array[String] = ["weapon_cycle", "toggle_shield", "sonar_ping", "lamp"]

var _gameplay_enabled := false
var _settings := {"touch_scale": 1.0, "touch_opacity": 0.75}
var _touches: Dictionary = {}
var _cancelled_touches: Dictionary = {}
var _action_holders: Dictionary = {}
var _buttons: Dictionary = {}
var _safe_rect := Rect2()
var _movement_rect := Rect2()
var _look_rect := Rect2()
var _joystick_center := Vector2.ZERO
var _joystick_radius := 80.0
var _movement := Vector2.ZERO
var _move_touch := -1
var _look_touch := -1
var _orbit_touch := -1
var _unit := 1.0
var _emulated_pointer_owned := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var base_font: FontFile = preload("res://assets/fonts/NotoSansSC-Subset.otf")
	var controls_font: FontFile = preload("res://assets/fonts/Controls-CJK-Subset.otf")
	var sym_font: FontFile = preload("res://assets/fonts/Symbols-Subset.ttf")
	var fallbacks: Array[Font] = base_font.fallbacks.duplicate()
	for fallback: Font in [controls_font, sym_font]:
		if not fallbacks.has(fallback):
			fallbacks.append(fallback)
	base_font.fallbacks = fallbacks
	resized.connect(_rebuild_layout)
	visibility_changed.connect(_on_visibility_changed)
	_rebuild_layout()
	configure(_settings)

func configure(settings: Dictionary) -> void:
	var old_scale := float(_settings.get("touch_scale", 1.0))
	_settings = {
		"touch_scale": clampf(float(settings.get("touch_scale", 1.0)), 0.7, 1.5),
		"touch_opacity": clampf(float(settings.get("touch_opacity", 0.75)), 0.25, 1.0)
	}
	modulate.a = float(_settings["touch_opacity"])
	var next_safe := _calculate_safe_rect()
	if not is_equal_approx(old_scale, float(_settings["touch_scale"])) or _buttons.is_empty() or not _safe_rect.is_equal_approx(next_safe):
		_rebuild_layout()
	queue_redraw()

func _process(_delta: float) -> void:
	if not _gameplay_enabled or not is_visible_in_tree() or not _touches.is_empty():
		return
	var next_safe := _calculate_safe_rect()
	if not _safe_rect.is_equal_approx(next_safe):
		_rebuild_layout()

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
	_look_touch = -1
	_orbit_touch = -1
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

func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		cancel_all()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_EXIT_TREE:
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
					_emulated_pointer_owned = false
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

func _begin_touch(index: int, at: Vector2) -> bool:
	var action := ""
	for candidate: String in _buttons:
		var rect: Rect2 = _buttons[candidate]
		if rect.has_point(at):
			action = candidate
			break
	if not action.is_empty():
		_touches[index] = {"kind": "button", "action": action, "last": at}
		if index == 0:
			_emulated_pointer_owned = true
		if action == "quick_menu":
			touch_used.emit()
			if not _touches.has(index):
				return true
			quick_menu_requested.emit()
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
		queue_redraw()
		return true
	if _move_touch == -1 and _movement_rect.has_point(at):
		_move_touch = index
		_touches[index] = {"kind": "move", "last": at}
		if index == 0:
			_emulated_pointer_owned = true
		touch_used.emit()
		if _touches.has(index):
			_update_movement(at)
		return true
	if _look_touch == -1 and _look_rect.has_point(at):
		_look_touch = index
		_touches[index] = {"kind": "look", "last": at}
		if index == 0:
			_emulated_pointer_owned = true
		touch_used.emit()
		return true
	if _orbit_touch == -1 and _look_rect.has_point(at):
		_orbit_touch = index
		_touches[index] = {"kind": "orbit", "last": at}
		if index == 0:
			_emulated_pointer_owned = true
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
			if _orbit_touch == -1:
				look_dragged.emit(delta.limit_length(240.0 * _unit))
		"orbit":
			orbit_dragged.emit(delta.limit_length(240.0 * _unit))
		"button":
			# A shooting or aiming finger can also aim; utility pills do not.
			if str(contact.get("action", "")) in ["attack", "aim"]:
				look_dragged.emit(delta.limit_length(240.0 * _unit))

func _release_touch(index: int, cancelled: bool) -> void:
	var contact: Dictionary = _touches[index]
	_touches.erase(index)
	if not _touches.has(0) and not _cancelled_touches.has(0):
		_emulated_pointer_owned = false
	match str(contact["kind"]):
		"move":
			_move_touch = -1
			_movement = Vector2.ZERO
			movement_changed.emit(Vector2.ZERO)
		"look":
			_look_touch = -1
		"orbit":
			_orbit_touch = -1
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
	var raw := ((at - _joystick_center) / maxf(_joystick_radius, 1.0)).limit_length()
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
	var safe := SafeArea.get_safe_rect(vp, Vector2.ZERO, 8.0)
	var clipped := full.intersection(safe)
	return clipped if clipped.size.x > 0.0 and clipped.size.y > 0.0 else full

func _rebuild_layout() -> void:
	cancel_all()
	_safe_rect = _calculate_safe_rect()
	if _safe_rect.size.x <= 0.0 or _safe_rect.size.y <= 0.0:
		return
	if _safe_rect.size.x >= _safe_rect.size.y:
		_build_landscape_layout()
	else:
		_build_portrait_layout()
	queue_redraw()

func _landscape_metrics(u: float, shrink: float = 1.0) -> Dictionary:
	var atk_size := maxf(64.0, 104.0 * u) * shrink
	var joy_box := maxf(128.0, 200.0 * u) * shrink
	return {
		"pad": maxf(8.0, 18.0 * u) * shrink,
		"gap": maxf(6.0, 10.0 * u) * shrink,
		"joy_box": joy_box,
		"atk_size": atk_size,
		"col1_w": minf(atk_size, maxf(54.0, 92.0 * u) * shrink),
		"col2_w": maxf(52.0, 96.0 * u) * shrink,
		"col2_h": maxf(44.0, 60.0 * u) * shrink,
		"pill_h": maxf(44.0, 52.0 * u) * shrink,
		"sprint_w": minf(joy_box, maxf(64.0, 104.0 * u) * shrink),
		"top_w": maxf(64.0, 96.0 * u) * shrink,
		"top_h": maxf(44.0, 46.0 * u) * shrink,
		"qs_w": maxf(48.0, 74.0 * u) * shrink,
		"qs_h": maxf(44.0, 48.0 * u) * shrink,
	}

func _landscape_bounds(m: Dictionary) -> Vector2:
	var pad: float = m["pad"]
	var gap: float = m["gap"]
	var bottom_w: float = 2.0 * pad + float(m["joy_box"]) + gap + (4.0 * float(m["qs_w"]) + 3.0 * gap) + gap + float(m["col2_w"]) + gap + float(m["atk_size"])
	var top_w: float = 2.0 * pad + 3.0 * float(m["top_w"]) + 2.0 * gap
	var left_h: float = 2.0 * pad + float(m["top_h"]) + gap + float(m["pill_h"]) + gap + float(m["joy_box"])
	var right1_h: float = 2.0 * pad + float(m["top_h"]) + gap + 2.0 * float(m["pill_h"]) + 2.0 * gap + float(m["atk_size"])
	var right2_h: float = 2.0 * pad + float(m["top_h"]) + gap + float(m["pill_h"]) + 2.0 * gap + 2.0 * float(m["col2_h"])
	return Vector2(maxf(bottom_w, top_w), maxf(left_h, maxf(right1_h, right2_h)))

func _landscape_fits(m: Dictionary, safe_size: Vector2) -> bool:
	var req := _landscape_bounds(m)
	return req.x <= safe_size.x - 0.5 and req.y <= safe_size.y - 0.5

func _build_landscape_layout() -> void:
	var touch_scale := float(_settings.get("touch_scale", 1.0))
	var base_u := clampf(minf(_safe_rect.size.x / 1280.0, _safe_rect.size.y / 800.0), 0.56, 1.25)
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
	var atk_size: float = m["atk_size"]
	var col1_w: float = m["col1_w"]
	var col2_w: float = m["col2_w"]
	var col2_h: float = m["col2_h"]
	var pill_h: float = m["pill_h"]
	var sprint_w: float = m["sprint_w"]
	var top_w: float = m["top_w"]
	var top_h: float = m["top_h"]
	var qs_w: float = m["qs_w"]
	var qs_h: float = m["qs_h"]

	_movement_rect = Rect2(Vector2(left, bottom - joy_box), Vector2(joy_box, joy_box))
	_joystick_center = _movement_rect.get_center()
	_joystick_radius = joy_box * 0.40

	var sprint_x := left + clampf(10.0 * u, 0.0, maxf(0.0, joy_box - sprint_w))
	var col2_x := right - atk_size - gap - col2_w
	var qs_total_w := 4.0 * qs_w + 3.0 * gap
	var qs_start_x := _movement_rect.end.x + ((col2_x - _movement_rect.end.x) - qs_total_w) * 0.5
	var qs_y := bottom - qs_h

	_buttons = {
		"attack": Rect2(Vector2(right - atk_size, bottom - atk_size), Vector2(atk_size, atk_size)),
		"descend": Rect2(Vector2(right - col1_w, bottom - atk_size - gap - pill_h), Vector2(col1_w, pill_h)),
		"ascend": Rect2(Vector2(right - col1_w, bottom - atk_size - 2.0 * gap - 2.0 * pill_h), Vector2(col1_w, pill_h)),
		"interact": Rect2(Vector2(col2_x, bottom - col2_h), Vector2(col2_w, col2_h)),
		"aim": Rect2(Vector2(col2_x, bottom - 2.0 * col2_h - gap), Vector2(col2_w, col2_h)),
		"dash": Rect2(Vector2(col2_x, bottom - 2.0 * col2_h - 2.0 * gap - pill_h), Vector2(col2_w, pill_h)),
		"sprint": Rect2(Vector2(sprint_x, _movement_rect.position.y - gap - pill_h), Vector2(sprint_w, pill_h)),
		"world_map": Rect2(Vector2(left, top), Vector2(top_w, top_h)),
		"quick_menu": Rect2(Vector2(right - 2.0 * top_w - gap, top), Vector2(top_w, top_h)),
		"pause_game": Rect2(Vector2(right - top_w, top), Vector2(top_w, top_h)),
	}
	for i in range(QUICK_SLOTS.size()):
		_buttons[QUICK_SLOTS[i]] = Rect2(Vector2(qs_start_x + float(i) * (qs_w + gap), qs_y), Vector2(qs_w, qs_h))

	# Keep the instrument header available to ordinary HUD controls.
	var look_top := maxf(_safe_rect.position.y + _safe_rect.size.y * 0.20, top + top_h + gap)
	if _safe_rect.size.y >= 460.0:
		look_top = maxf(look_top, _safe_rect.position.y + 92.0)
	var look_left := _safe_rect.position.x + _safe_rect.size.x * 0.40
	_look_rect = Rect2(Vector2(look_left, look_top), Vector2(maxf(0.0, right - look_left), maxf(0.0, bottom - look_top)))

func _portrait_metrics(u: float, shrink: float = 1.0) -> Dictionary:
	var atk_size := maxf(68.0, 84.0 * u) * shrink
	var joy_box := maxf(144.0, 168.0 * u) * shrink
	return {
		"pad": maxf(8.0, 12.0 * u) * shrink,
		"gap": maxf(6.0, 8.0 * u) * shrink,
		"row_gap": maxf(8.0, 14.0 * u) * shrink,
		"joy_box": joy_box,
		"atk_size": atk_size,
		"col1_w": minf(atk_size, maxf(58.0, 74.0 * u) * shrink),
		"col2_w": maxf(56.0, 72.0 * u) * shrink,
		"col2_h": maxf(44.0, 50.0 * u) * shrink,
		"pill_h": maxf(44.0, 48.0 * u) * shrink,
		"sprint_w": minf(joy_box, maxf(68.0, 92.0 * u) * shrink),
		"top_w": maxf(64.0, 84.0 * u) * shrink,
		"top_h": maxf(44.0, 46.0 * u) * shrink,
		"qs_w": maxf(52.0, 74.0 * u) * shrink,
		"qs_h": maxf(44.0, 46.0 * u) * shrink,
		"look_band": 64.0 * shrink,
	}

func _portrait_bounds(m: Dictionary) -> Vector2:
	var pad: float = m["pad"]
	var gap: float = m["gap"]
	var bottom_w: float = 2.0 * pad + float(m["joy_box"]) + gap + float(m["col2_w"]) + gap + float(m["atk_size"])
	var qs_row_w: float = 2.0 * pad + 4.0 * float(m["qs_w"]) + 3.0 * gap
	var top_row_w: float = 2.0 * pad + 3.0 * float(m["top_w"]) + 2.0 * gap
	var left_cluster_h: float = float(m["joy_box"]) + gap + float(m["pill_h"])
	var right1_cluster_h: float = float(m["atk_size"]) + 2.0 * gap + 2.0 * float(m["pill_h"])
	var right2_cluster_h: float = 2.0 * float(m["col2_h"]) + 2.0 * gap + float(m["pill_h"])
	var cluster_h := maxf(left_cluster_h, maxf(right1_cluster_h, right2_cluster_h))
	var total_h: float = 2.0 * pad + float(m["top_h"]) + gap + float(m["look_band"]) + float(m["qs_h"]) + float(m["row_gap"]) + cluster_h
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
	var atk_size: float = m["atk_size"]
	var col1_w: float = m["col1_w"]
	var col2_w: float = m["col2_w"]
	var col2_h: float = m["col2_h"]
	var pill_h: float = m["pill_h"]
	var sprint_w: float = m["sprint_w"]
	var top_w: float = m["top_w"]
	var top_h: float = m["top_h"]
	var qs_w: float = m["qs_w"]
	var qs_h: float = m["qs_h"]

	_movement_rect = Rect2(Vector2(left, bottom - joy_box), Vector2(joy_box, joy_box))
	_joystick_center = _movement_rect.get_center()
	_joystick_radius = joy_box * 0.43

	var col2_x := right - atk_size - gap - col2_w
	_buttons = {
		"attack": Rect2(Vector2(right - atk_size, bottom - atk_size), Vector2(atk_size, atk_size)),
		"descend": Rect2(Vector2(right - col1_w, bottom - atk_size - gap - pill_h), Vector2(col1_w, pill_h)),
		"ascend": Rect2(Vector2(right - col1_w, bottom - atk_size - 2.0 * gap - 2.0 * pill_h), Vector2(col1_w, pill_h)),
		"interact": Rect2(Vector2(col2_x, bottom - col2_h), Vector2(col2_w, col2_h)),
		"aim": Rect2(Vector2(col2_x, bottom - 2.0 * col2_h - gap), Vector2(col2_w, col2_h)),
		"dash": Rect2(Vector2(col2_x, bottom - 2.0 * col2_h - 2.0 * gap - pill_h), Vector2(col2_w, pill_h)),
		"sprint": Rect2(Vector2(left, _movement_rect.position.y - gap - pill_h), Vector2(sprint_w, pill_h)),
		"world_map": Rect2(Vector2(left, top), Vector2(top_w, top_h)),
		"quick_menu": Rect2(Vector2(right - 2.0 * top_w - gap, top), Vector2(top_w, top_h)),
		"pause_game": Rect2(Vector2(right - top_w, top), Vector2(top_w, top_h)),
	}

	var cluster_top := minf(_buttons["sprint"].position.y, minf(_buttons["ascend"].position.y, _buttons["dash"].position.y))
	var qs_y := cluster_top - row_gap - qs_h
	var qs_total_w := 4.0 * qs_w + 3.0 * gap
	var qs_start_x := left + ((right - left) - qs_total_w) * 0.5
	for i in range(QUICK_SLOTS.size()):
		_buttons[QUICK_SLOTS[i]] = Rect2(Vector2(qs_start_x + float(i) * (qs_w + gap), qs_y), Vector2(qs_w, qs_h))

	var min_look_top := top + top_h + gap
	var look_top := maxf(_safe_rect.position.y + _safe_rect.size.y * 0.14, min_look_top)
	if qs_y - 52.0 > min_look_top:
		look_top = minf(look_top, qs_y - 52.0)
	else:
		look_top = min_look_top
	_look_rect = Rect2(Vector2(left, look_top), Vector2(maxf(0.0, right - left), maxf(0.0, bottom - look_top)))

func _draw() -> void:
	if not _gameplay_enabled or _buttons.is_empty():
		return
	var font: Font = preload("res://assets/fonts/NotoSansSC-Subset.otf")
	var ring_color := Color(Art.CYAN, 0.75)
	draw_circle(_joystick_center, _joystick_radius, Color(Art.PANEL, 0.74), true, -1.0, true)
	draw_circle(_joystick_center, _joystick_radius, ring_color, false, 1.5 * _unit, true)
	draw_circle(_joystick_center, _joystick_radius * 0.5, Color(Art.CYAN, 0.16), false, _unit, true)
	var knob := _joystick_center + _movement * _joystick_radius * 0.66
	draw_circle(knob, _joystick_radius * 0.30, Color(Art.CYAN, 0.52 if _move_touch != -1 else 0.26), true, -1.0, true)
	draw_circle(knob, _joystick_radius * 0.30, Color(Art.PAPER, 0.65), false, _unit, true)
	var joy_label_h := maxf(18.0, 24.0 * _unit)
	var joy_label_y := _joystick_center.y + _joystick_radius + 2.0
	if joy_label_y + joy_label_h > _safe_rect.end.y:
		joy_label_y = _joystick_center.y + _joystick_radius * 0.52
	_draw_centered(font, "推进 / 转向", Rect2(Vector2(_movement_rect.position.x, joy_label_y), Vector2(_movement_rect.size.x, joy_label_h)), clampi(roundi(14.0 * _unit), 11, 18), Color(Art.PAPER, 0.78))
	for action: String in _buttons:
		var rect: Rect2 = _buttons[action]
		var pressed := _action_holders.has(action)
		var attack := action == "attack"
		var quick_slot := action in QUICK_SLOTS
		var style := StyleBoxFlat.new()
		style.bg_color = Color(Art.AMBER if attack and pressed else Art.PANEL, 0.94 if pressed else 0.80)
		style.border_color = Color(Art.AMBER if attack else Art.CYAN, 0.95 if pressed else (0.54 if quick_slot else 0.64))
		style.set_border_width_all(maxi(1, roundi(_unit)))
		style.set_corner_radius_all(roundi(minf(rect.size.x, rect.size.y) * 0.5) if attack else maxi(8, roundi((10.0 if quick_slot else 12.0) * _unit)))
		draw_style_box(style, rect)
		var label_size := clampi(roundi(rect.size.y * 0.24), 14, 26) if attack else clampi(roundi(minf(rect.size.y * 0.38, rect.size.x * 0.34)), 12, 21)
		_draw_centered(font, str(LABELS[action]), rect, label_size, Art.INK if attack and pressed else Art.PAPER)
	var look_hint := Rect2(Vector2(_look_rect.position.x, _look_rect.position.y + 10.0 * _unit), Vector2(_look_rect.size.x, 24.0 * _unit))
	_draw_centered(font, "滑动观察", look_hint, maxi(11, roundi(14.0 * _unit)), Color(Art.CYAN, 0.52))

func _draw_centered(font: Font, text: String, rect: Rect2, font_size: int, color: Color) -> void:
	var measured := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var at := Vector2(rect.position.x + (rect.size.x - measured.x) * 0.5, rect.position.y + (rect.size.y - font.get_height(font_size)) * 0.5 + font.get_ascent(font_size))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
