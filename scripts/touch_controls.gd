extends Control
## A multitouch surface. New contacts go through GUI handling first; once a
## finger is claimed it keeps its role until release, even outside that role.

const Art = preload("res://scripts/art_direction.gd")

signal action_changed(action: String, pressed: bool, cancelled: bool)
signal movement_changed(value: Vector2)
signal look_dragged(relative: Vector2)
signal quick_menu_requested
signal touch_used

const LABELS := {
	"attack": "攻击", "interact": "交互", "aim": "瞄准",
	"ascend": "上浮", "descend": "下潜", "sprint": "加速",
	"dash": "突进", "world_map": "海图", "pause_game": "暂停",
	"quick_menu": "快捷"
}

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
	if not is_equal_approx(old_scale, float(_settings["touch_scale"])) or _buttons.is_empty():
		_rebuild_layout()
	queue_redraw()

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
			look_dragged.emit(delta.limit_length(240.0 * _unit))
		"button":
			# A shooting finger can also aim; two thumbs can move and charge.
			if str(contact.get("action", "")) == "attack":
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
	# Desktop fallback is a monitor work area, not a safe rectangle for the
	# game window. Applying it to a movable desktop window would crop controls.
	if OS.get_name() not in ["Android", "iOS"]:
		return full
	var screen := DisplayServer.window_get_current_screen()
	var display_safe := Rect2(DisplayServer.get_display_safe_area())
	if display_safe.size.x <= 0.0 or display_safe.size.y <= 0.0:
		return full
	var window_origin := Vector2(DisplayServer.window_get_position()) - Vector2(DisplayServer.screen_get_position(screen))
	var window_safe := Rect2(display_safe.position - window_origin, display_safe.size)
	var local_safe: Rect2 = get_screen_transform().affine_inverse() * window_safe
	var clipped := full.intersection(local_safe)
	return clipped if clipped.size.x > 0.0 and clipped.size.y > 0.0 else full

func _rebuild_layout() -> void:
	cancel_all()
	_safe_rect = _calculate_safe_rect()
	if _safe_rect.size.x <= 0.0 or _safe_rect.size.y <= 0.0:
		return
	_unit = clampf(minf(_safe_rect.size.x / 1280.0, _safe_rect.size.y / 800.0), 0.58, 1.5) * float(_settings.get("touch_scale", 1.0))
	var pad := 18.0 * _unit
	var right := _safe_rect.end.x - pad
	var bottom := _safe_rect.end.y - pad
	var top := _safe_rect.position.y + pad
	var left := _safe_rect.position.x + pad
	_joystick_radius = 80.0 * _unit
	_joystick_center = Vector2(left + 106.0 * _unit, bottom - 106.0 * _unit)
	_movement_rect = Rect2(_joystick_center - Vector2.ONE * 100.0 * _unit, Vector2.ONE * 200.0 * _unit)
	_buttons = {
		"attack": Rect2(Vector2(right - 116.0 * _unit, bottom - 116.0 * _unit), Vector2.ONE * 104.0 * _unit),
		"interact": Rect2(Vector2(right - 234.0 * _unit, bottom - 106.0 * _unit), Vector2(98, 62) * _unit),
		"aim": Rect2(Vector2(right - 234.0 * _unit, bottom - 180.0 * _unit), Vector2(98, 62) * _unit),
		"ascend": Rect2(Vector2(right - 104.0 * _unit, bottom - 252.0 * _unit), Vector2(92, 54) * _unit),
		"descend": Rect2(Vector2(right - 104.0 * _unit, bottom - 188.0 * _unit), Vector2(92, 54) * _unit),
		"sprint": Rect2(Vector2(left + 10.0 * _unit, bottom - 266.0 * _unit), Vector2(104, 54) * _unit),
		"dash": Rect2(Vector2(right - 234.0 * _unit, bottom - 252.0 * _unit), Vector2(98, 60) * _unit),
		"world_map": Rect2(Vector2(left, top), Vector2(96, 46) * _unit),
		"quick_menu": Rect2(Vector2(right - 208.0 * _unit, top), Vector2(96, 46) * _unit),
		"pause_game": Rect2(Vector2(right - 96.0 * _unit, top), Vector2(96, 46) * _unit)
	}
	# Keep the instrument header available to ordinary HUD controls.
	var look_top := _safe_rect.position.y + maxf(_safe_rect.size.y * 0.20, 82.0 * _unit)
	_look_rect = Rect2(Vector2(_safe_rect.position.x + _safe_rect.size.x * 0.40, look_top), Vector2(_safe_rect.size.x * 0.60 - pad, maxf(0.0, bottom - look_top)))
	queue_redraw()

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
	_draw_centered(font, "推进 / 转向", Rect2(_joystick_center + Vector2(-110, 88) * _unit, Vector2(220, 26) * _unit), roundi(15.0 * _unit), Color(Art.PAPER, 0.80))
	for action: String in _buttons:
		var rect: Rect2 = _buttons[action]
		var pressed := _action_holders.has(action)
		var attack := action == "attack"
		var style := StyleBoxFlat.new()
		style.bg_color = Color(Art.AMBER if attack and pressed else Art.PANEL, 0.94 if pressed else 0.80)
		style.border_color = Color(Art.AMBER if attack else Art.CYAN, 0.95 if pressed else 0.64)
		style.set_border_width_all(maxi(1, roundi(_unit)))
		style.set_corner_radius_all(roundi((52.0 if attack else 12.0) * _unit))
		draw_style_box(style, rect)
		_draw_centered(font, str(LABELS[action]), rect, maxi(13, roundi((23.0 if attack else 19.0) * _unit)), Art.INK if attack and pressed else Art.PAPER)
	var look_hint := Rect2(Vector2(_look_rect.position.x, _look_rect.position.y + 10.0 * _unit), Vector2(_look_rect.size.x, 24.0 * _unit))
	_draw_centered(font, "滑动观察", look_hint, maxi(11, roundi(14.0 * _unit)), Color(Art.CYAN, 0.52))

func _draw_centered(font: Font, text: String, rect: Rect2, font_size: int, color: Color) -> void:
	var measured := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size)
	var at := Vector2(rect.position.x + (rect.size.x - measured.x) * 0.5, rect.position.y + (rect.size.y - font.get_height(font_size)) * 0.5 + font.get_ascent(font_size))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, color)
