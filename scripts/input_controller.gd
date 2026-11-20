extends Node
## One player's input, aggregated by physical control or virtual input source.
## Gameplay calls handle_event only after the GUI has had a chance to consume it.

const SafeArea = preload("res://scripts/presentation/safe_area.gd")

signal action_changed(action: String, pressed: bool, cancelled: bool)
signal device_changed(device: String)
signal settings_changed

const SETTINGS_PATH := "user://input_settings.cfg"
const TOUCH_SCALE_MIN := 0.70
const TOUCH_SCALE_MAX := 1.50
const TOUCH_OPACITY_MIN := 0.20
const TOUCH_OPACITY_MAX := 1.00
const DEFAULT_SETTINGS := {
	"gamepad_sensitivity": 1.0,
	"touch_sensitivity": 1.0,
	"invert_y": false,
	"deadzone": 0.2,
	"touch_mode": "auto",
	"touch_scale": 1.0,
	"touch_opacity": 0.75,
	"graphics_quality": "auto",
}
const ACTIONS: Array[String] = [
	"forward", "backward", "left", "right", "ascend", "descend", "sprint",
	"interact", "craft_menu", "lamp", "pause_game", "weapon_1", "weapon_2",
	"weapon_3", "weapon_4", "weapon_cycle", "attack", "aim", "scope", "dash", "booster",
	"mount_toggle", "toggle_shield", "recall_pets", "salvage_drone", "sushi_menu",
	"mount_board", "world_map", "sonar_ping", "mount_slot_1", "mount_slot_2",
	"mount_slot_3", "mount_slot_4", "mount_slot_5", "mount_slot_6",
	"quick_menu", "gameplay_guide", "quest_log", "character_switch", "character_angle", "char_angle_reset",
	"char_rotate_left", "char_rotate_right", "char_tilt_up", "char_tilt_down",
	"char_roll_left", "char_roll_right", "camera_closer", "camera_farther", "ui_cancel",
	"weapon_art", "tactical_skill", "ultimate_skill", "loadout_menu",
]
const MENU_ACTIONS: Array[String] = [
	"pause_game", "world_map", "craft_menu", "sushi_menu", "mount_board",
	"sonar_ping", "quick_menu", "gameplay_guide", "quest_log", "loadout_menu", "character_switch", "character_angle", "char_angle_reset",
	"char_rotate_left", "char_rotate_right", "char_tilt_up", "char_tilt_down", "ui_cancel",
]
const CONTINUOUS_ACTIONS: Array[String] = [
	"forward", "backward", "left", "right", "ascend", "descend", "sprint",
	"char_rotate_left", "char_rotate_right", "char_tilt_up", "char_tilt_down",
	"char_roll_left", "char_roll_right",
]
const KEY_HINTS := {
	"forward": "W", "backward": "S", "left": "A", "right": "D",
	"ascend": "空格", "descend": "Ctrl", "sprint": "Shift", "interact": "E",
	"craft_menu": "Tab", "lamp": "F", "pause_game": "Esc", "weapon_1": "1",
	"weapon_2": "2", "weapon_3": "3", "weapon_4": "4", "weapon_cycle": "1-4", "attack": "R / 左键",
	"aim": "T", "scope": "Y", "dash": "Q", "booster": "H", "mount_toggle": "G",
	"toggle_shield": "C", "recall_pets": "Z", "salvage_drone": "V", "sushi_menu": "B",
	"mount_board": "O", "world_map": "M", "sonar_ping": "N", "mount_slot_1": "5",
	"mount_slot_2": "6", "mount_slot_3": "7", "mount_slot_4": "8", "mount_slot_5": "9",
	"mount_slot_6": "0", "quick_menu": "J", "gameplay_guide": "L", "quest_log": "U", "character_switch": "P",
	"character_angle": "K", "char_angle_reset": "Home",
	"char_rotate_left": "方向键左", "char_rotate_right": "方向键右",
	"char_tilt_up": "方向键上", "char_tilt_down": "方向键下",
	"char_roll_left": ",", "char_roll_right": ".", "camera_closer": "滚轮上",
	"camera_farther": "滚轮下", "ui_cancel": "Esc",
	"weapon_art": "X", "tactical_skill": "I", "ultimate_skill": "~", "loadout_menu": "F2",
}
const ACTION_LABELS := {
	"forward": "左摇杆", "backward": "左摇杆", "left": "左摇杆", "right": "左摇杆",
	"attack": "攻击", "aim": "瞄准", "scope": "远镜", "interact": "交互",
	"ascend": "上浮", "descend": "下潜", "sprint": "加速", "dash": "突进",
	"toggle_shield": "护盾", "world_map": "海图", "pause_game": "暂停",
	"craft_menu": "制造", "sushi_menu": "料理 / 图鉴", "mount_board": "契约板",
	"mount_toggle": "骑乘 / 离鞍", "recall_pets": "召回", "salvage_drone": "无人机",
	"sonar_ping": "声呐", "booster": "助推器", "lamp": "头灯", "quick_menu": "快捷",
	"gameplay_guide": "潜航指南", "quest_log": "任务",
	"character_switch": "切换角色",
	"character_angle": "切换视角", "char_angle_reset": "角度回正",
	"char_rotate_left": "角色左旋", "char_rotate_right": "角色右旋",
	"char_tilt_up": "角色上仰", "char_tilt_down": "角色下俯",
	"char_roll_left": "左倾横滚", "char_roll_right": "右倾横滚",
	"weapon_1": "战术刀", "weapon_2": "战斧", "weapon_3": "蓝光枪", "weapon_4": "指示枪",
	"weapon_cycle": "武器",
	"mount_slot_1": "伙伴 1", "mount_slot_2": "伙伴 2", "mount_slot_3": "伙伴 3",
	"mount_slot_4": "伙伴 4", "mount_slot_5": "伙伴 5", "mount_slot_6": "伙伴 6",
	"camera_closer": "拉近视角", "camera_farther": "拉远视角", "ui_cancel": "返回",
	"weapon_art": "战技", "tactical_skill": "战术技", "ultimate_skill": "终极技", "loadout_menu": "武装",
}
const PAD_HINTS := {
	"forward": "左摇杆", "backward": "左摇杆", "left": "左摇杆", "right": "左摇杆",
	"ascend": "RB / R1", "descend": "LB / L1", "sprint": "L3", "attack": "RT / R2",
	"aim": "LT / L2", "interact": "A / ×", "dash": "B / ○", "ui_cancel": "B / ○",
	"toggle_shield": "X / □", "quick_menu": "Y / △", "world_map": "View / Touchpad",
	"gameplay_guide": "Y / △ · 潜航指南",
	"quest_log": "Y / △ · 任务",
	"weapon_art": "Y / △ · 战技",
	"tactical_skill": "Y / △ · 战术技",
	"ultimate_skill": "Y / △ · 终极技",
	"loadout_menu": "Y / △ · 武装",
	"weapon_cycle": "Y / △ · 切换武器",
	"pause_game": "Menu / Options", "sonar_ping": "方向键上", "recall_pets": "方向键下",
	"camera_closer": "方向键左", "camera_farther": "方向键右", "character_angle": "R3",
}

var active_device: String = "keyboard"
var settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)
var context: String = "main"
var _sources: Dictionary = {}
var _raw_sources: Dictionary = {}
var _blocked_sources: Dictionary = {}
var _blocked_actions: Dictionary = {}
var _look_axes: Dictionary = {}
var _loaded_settings: bool = false
var _last_screen_touch_msec: int = -10000

func _is_synthetic_touch_mouse(event: InputEvent) -> bool:
	if not (event is InputEventMouse):
		return false
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return true
	if active_device == "touch" and _last_screen_touch_msec >= 0 and (Time.get_ticks_msec() - _last_screen_touch_msec) < 120:
		return true
	return false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	setup_defaults()
	if SafeArea.is_default_touch_platform() and get_connected_gamepad_count() == 0:
		active_device = "touch"
	if not Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.connect(_on_joy_connection_changed)

func _exit_tree() -> void:
	if Input.joy_connection_changed.is_connected(_on_joy_connection_changed):
		Input.joy_connection_changed.disconnect(_on_joy_connection_changed)

func setup_defaults() -> void:
	for action: String in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, float(settings["deadzone"]))
	_add_joy_button("ascend", JOY_BUTTON_RIGHT_SHOULDER)
	_add_joy_button("descend", JOY_BUTTON_LEFT_SHOULDER)
	_add_joy_button("sprint", JOY_BUTTON_LEFT_STICK)
	_add_joy_button("character_angle", JOY_BUTTON_RIGHT_STICK)
	_add_joy_button("interact", JOY_BUTTON_A)
	_add_joy_button("dash", JOY_BUTTON_B)
	_add_joy_button("toggle_shield", JOY_BUTTON_X)
	_add_joy_button("quick_menu", JOY_BUTTON_Y)
	_add_joy_button("world_map", JOY_BUTTON_BACK)
	_add_joy_button("pause_game", JOY_BUTTON_START)
	_add_joy_button("sonar_ping", JOY_BUTTON_DPAD_UP)
	_add_joy_button("recall_pets", JOY_BUTTON_DPAD_DOWN)
	_add_joy_button("camera_closer", JOY_BUTTON_DPAD_LEFT)
	_add_joy_button("camera_farther", JOY_BUTTON_DPAD_RIGHT)
	_add_joy_axis("left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis("right", JOY_AXIS_LEFT_X, 1.0)
	_add_joy_axis("forward", JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_axis("backward", JOY_AXIS_LEFT_Y, 1.0)
	_add_joy_axis("attack", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_add_joy_axis("aim", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_add_joy_button("ui_accept", JOY_BUTTON_A)
	_add_joy_button("ui_cancel", JOY_BUTTON_B)
	_add_joy_button("ui_up", JOY_BUTTON_DPAD_UP)
	_add_joy_button("ui_down", JOY_BUTTON_DPAD_DOWN)
	_add_joy_button("ui_left", JOY_BUTTON_DPAD_LEFT)
	_add_joy_button("ui_right", JOY_BUTTON_DPAD_RIGHT)
	_add_joy_axis("ui_left", JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis("ui_right", JOY_AXIS_LEFT_X, 1.0)
	_add_joy_axis("ui_up", JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_axis("ui_down", JOY_AXIS_LEFT_Y, 1.0)
	var quick_key := InputEventKey.new()
	quick_key.physical_keycode = KEY_J
	_add_binding("quick_menu", quick_key)
	for guide_keycode: int in [KEY_L, KEY_F1, KEY_SLASH]:
		var guide_key := InputEventKey.new()
		guide_key.physical_keycode = guide_keycode
		_add_binding("gameplay_guide", guide_key)
	var quest_key := InputEventKey.new()
	quest_key.physical_keycode = KEY_U
	_add_binding("quest_log", quest_key)
	var weapon_art_key := InputEventKey.new()
	weapon_art_key.physical_keycode = KEY_X
	_add_binding("weapon_art", weapon_art_key)
	var tactical_key := InputEventKey.new()
	tactical_key.physical_keycode = KEY_I
	_add_binding("tactical_skill", tactical_key)
	for ult_keycode: int in [KEY_QUOTELEFT, KEY_SEMICOLON]:
		var ult_key := InputEventKey.new()
		ult_key.physical_keycode = ult_keycode
		_add_binding("ultimate_skill", ult_key)
	var loadout_key := InputEventKey.new()
	loadout_key.physical_keycode = KEY_F2
	_add_binding("loadout_menu", loadout_key)
	_update_deadzones()

func _add_joy_button(action: String, button: int) -> void:
	var event := InputEventJoypadButton.new()
	event.device = -1
	event.button_index = button
	_add_binding(action, event)

func _add_joy_axis(action: String, axis: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = -1
	event.axis = axis
	event.axis_value = value
	_add_binding(action, event)

func _add_binding(action: String, event: InputEvent) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	if not InputMap.action_has_event(action, event):
		InputMap.action_add_event(action, event)

func _update_deadzones() -> void:
	for action: String in ["forward", "backward", "left", "right", "attack", "aim"]:
		if InputMap.has_action(action):
			InputMap.action_set_deadzone(action, float(settings["deadzone"]))

func _input(event: InputEvent) -> void:
	# Observe consumed physical presses as well: polling must not turn a menu
	# click into a held attack after that menu closes.
	_observe_event(event)
	_release_event(event)

func handle_event(event: InputEvent) -> bool:
	if event is InputEventKey and event.echo:
		return false
	_observe_event(event)
	if _is_synthetic_touch_mouse(event):
		return false
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		return false
	var source: String = _event_source(event)
	if source.is_empty():
		return false
	if event is InputEventJoypadMotion and event.axis in [JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]:
		if context != "play" or _source_blocked(source, "__look"):
			return false
		var look: Vector2 = _look_axes.get(event.device, Vector2.ZERO)
		if event.axis == JOY_AXIS_RIGHT_X:
			look.x = event.axis_value
		else:
			look.y = event.axis_value
		_look_axes[event.device] = look
		return true
	var matched: bool = false
	for action: String in _event_actions(event):
		var strength: float = _event_strength(event, action)
		if strength <= 0.0:
			_set_strength(source, action, 0.0, false)
			continue
		if not _action_allowed(action) or _source_blocked(source, action):
			continue
		_set_strength(source, action, strength, false)
		matched = true
	return matched

func _observe_event(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if event is InputEventMouse and _is_synthetic_touch_mouse(event):
		return
	if event is InputEventScreenTouch:
		_last_screen_touch_msec = Time.get_ticks_msec()
		if event.pressed:
			notify_device("touch")
		return
	if event is InputEventScreenDrag:
		_last_screen_touch_msec = Time.get_ticks_msec()
		if event.relative.length_squared() > 1.0:
			notify_device("touch")
		return
	if event is InputEventMouseMotion:
		var allow_mouse_switch := (not SafeArea.is_default_touch_platform()) or str(settings.get("touch_mode", "auto")) == "off"
		if allow_mouse_switch and event.device != InputEvent.DEVICE_ID_EMULATION and event.relative.length_squared() > 4.0:
			notify_device("keyboard")
		return
	var source: String = _event_source(event)
	if source.is_empty():
		return
	var values: Dictionary = {}
	var meaningful: bool = false
	for action: String in _event_actions(event):
		var strength: float = _event_strength(event, action)
		if strength > 0.0:
			values[action] = strength
			meaningful = true
		else:
			_unblock(source, action)
	if event is InputEventJoypadMotion and event.axis in [JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]:
		if absf(event.axis_value) > float(settings["deadzone"]):
			values["__look"] = absf(event.axis_value)
			meaningful = true
		else:
			_unblock(source, "__look")
			if _look_axes.has(event.device):
				var look: Vector2 = _look_axes[event.device]
				if event.axis == JOY_AXIS_RIGHT_X:
					look.x = 0.0
				else:
					look.y = 0.0
				_look_axes[event.device] = look
	if values.is_empty():
		_raw_sources.erase(source)
	else:
		_raw_sources[source] = values
	var block_mouse_dev := (event is InputEventMouse) and SafeArea.is_default_touch_platform() and str(settings.get("touch_mode", "auto")) != "off"
	if meaningful and not block_mouse_dev:
		notify_device("gamepad" if event is InputEventJoypadButton or event is InputEventJoypadMotion else "keyboard")

func _release_event(event: InputEvent) -> void:
	var source: String = _event_source(event)
	if source.is_empty() or not _sources.has(source):
		return
	for action: String in _event_actions(event):
		if _event_strength(event, action) <= 0.0:
			_set_strength(source, action, 0.0, false)

func _event_source(event: InputEvent) -> String:
	if event is InputEventKey:
		return "key:%d" % (event.physical_keycode if event.physical_keycode != 0 else event.keycode)
	if event is InputEventMouseButton:
		return "mouse:%d:%d" % [event.device, event.button_index]
	if event is InputEventJoypadButton:
		return "joy:%d:button:%d" % [event.device, event.button_index]
	if event is InputEventJoypadMotion:
		return "joy:%d:axis:%d" % [event.device, event.axis]
	if event is InputEventAction:
		return "action:%d:%s" % [event.device, event.action]
	return ""

func _event_actions(event: InputEvent) -> Array[String]:
	var actions: Array[String] = []
	if event is InputEventAction:
		if str(event.action) in ACTIONS:
			actions.append(str(event.action))
		return actions
	for action: String in ACTIONS:
		if not InputMap.has_action(action):
			continue
		if event is InputEventJoypadMotion:
			# Check both signs so crossing the axis releases the old direction.
			for binding: InputEvent in InputMap.action_get_events(action):
				if binding is InputEventJoypadMotion and binding.axis == event.axis and (binding.device < 0 or binding.device == event.device):
					actions.append(action)
					break
		elif InputMap.event_is_action(event, action):
			actions.append(action)
	return actions

func _event_strength(event: InputEvent, action: String) -> float:
	if event is InputEventAction:
		return clampf(event.strength, 0.0, 1.0) if event.pressed else 0.0
	if event is InputEventJoypadMotion:
		var strength: float = 0.0
		for binding: InputEvent in InputMap.action_get_events(action):
			if binding is InputEventJoypadMotion and binding.axis == event.axis and (binding.device < 0 or binding.device == event.device):
				strength = maxf(strength, event.axis_value * signf(binding.axis_value))
		return _filter_axis(strength)
	return 1.0 if event.is_pressed() else 0.0

func _filter_axis(value: float) -> float:
	var deadzone: float = float(settings["deadzone"])
	return clampf((value - deadzone) / (1.0 - deadzone), 0.0, 1.0)

func _action_allowed(action: String) -> bool:
	if action == "ui_cancel":
		return context != "play"
	return context == "play" or action in MENU_ACTIONS

func _source_blocked(source: String, action: String) -> bool:
	var blocked: Dictionary = _blocked_sources.get(source, {})
	return bool(blocked.get(action, false))

func _unblock(source: String, action: String) -> void:
	if _blocked_sources.has(source):
		var blocked: Dictionary = _blocked_sources[source]
		blocked.erase(action)
		if blocked.is_empty():
			_blocked_sources.erase(source)
	_blocked_actions.erase(action)

func set_action(source: String, action: String, pressed: bool, cancelled: bool = false) -> void:
	if pressed and (not _action_allowed(action) or _source_blocked(source, action)):
		return
	if pressed:
		_note_virtual_device(source)
	_set_strength(source, action, 1.0 if pressed else 0.0, cancelled)

func set_axis(source: String, negative: String, positive: String, value: float) -> void:
	var axis: float = clampf(value, -1.0, 1.0) if context == "play" else 0.0
	if absf(axis) > 0.01:
		_note_virtual_device(source)
	_set_strength(source, negative, maxf(0.0, -axis), false)
	_set_strength(source, positive, maxf(0.0, axis), false)

func _note_virtual_device(source: String) -> void:
	if source.begins_with("touch"):
		notify_device("touch")
	elif source.begins_with("joy") or source.begins_with("gamepad"):
		notify_device("gamepad")

func _set_strength(source: String, action: String, strength: float, cancelled: bool) -> void:
	var was_pressed: bool = _aggregate_strength(action) > 0.0
	var values: Dictionary = _sources.get(source, {})
	if strength > 0.0:
		values[action] = clampf(strength, 0.0, 1.0)
		_sources[source] = values
	else:
		values.erase(action)
		if values.is_empty():
			_sources.erase(source)
		else:
			_sources[source] = values
	var pressed: bool = _aggregate_strength(action) > 0.0
	if pressed != was_pressed:
		action_changed.emit(action, pressed, cancelled and not pressed)

func _aggregate_strength(action: String) -> float:
	var strength: float = 0.0
	for values: Dictionary in _sources.values():
		strength = maxf(strength, float(values.get(action, 0.0)))
	return strength

func _raw_strength(action: String) -> float:
	var strength: float = 0.0
	for values: Dictionary in _raw_sources.values():
		strength = maxf(strength, float(values.get(action, 0.0)))
	return strength

func get_strength(action: String) -> float:
	if not _action_allowed(action):
		return 0.0
	var strength: float = _aggregate_strength(action)
	# Programmatic action_press is used by existing movement regressions. Only
	# continuous movement may fall back to polling. Attack and other commands
	# must use accepted sources: an emulated mouse press can be consumed before
	# this node sees it, while still changing the global Input singleton.
	if action in CONTINUOUS_ACTIONS and InputMap.has_action(action) and _raw_strength(action) <= 0.0:
		var fallback: float = Input.get_action_strength(action)
		if fallback <= 0.0:
			_blocked_actions.erase(action)
		elif not _blocked_actions.has(action):
			strength = maxf(strength, fallback)
	return strength

func get_axis(negative: String, positive: String) -> float:
	return clampf(get_strength(positive) - get_strength(negative), -1.0, 1.0)

func is_action_pressed(action: String) -> bool:
	return get_strength(action) > 0.0

func get_look_vector() -> Vector2:
	if context != "play":
		return Vector2.ZERO
	var strongest := Vector2.ZERO
	for value: Vector2 in _look_axes.values():
		if value.length_squared() > strongest.length_squared():
			strongest = value
	var length: float = strongest.length()
	var deadzone: float = float(settings["deadzone"])
	if length <= deadzone:
		return Vector2.ZERO
	return strongest.normalized() * clampf((length - deadzone) / (1.0 - deadzone), 0.0, 1.0)

func _block_physical_action(source: String, action: String) -> void:
	if source.begins_with("key:") or source.begins_with("mouse:") or source.begins_with("joy:") or source.begins_with("action:"):
		var blocked: Dictionary = _blocked_sources.get(source, {})
		blocked[action] = true
		_blocked_sources[source] = blocked

func cancel_action(action: String) -> void:
	for source: String in _raw_sources.keys():
		var raw: Dictionary = _raw_sources[source]
		if float(raw.get(action, 0.0)) > 0.0:
			_block_physical_action(source, action)
	for source: String in _sources.keys():
		var values: Dictionary = _sources.get(source, {})
		if values.has(action):
			_block_physical_action(source, action)
			_set_strength(source, action, 0.0, true)
	if InputMap.has_action(action) and Input.is_action_pressed(action):
		_blocked_actions[action] = true
		Input.action_release(action)

func cancel_source(source: String) -> void:
	# Prefix support allows a device or the entire touch overlay to be cancelled.
	for existing: String in _sources.keys():
		if existing != source and not existing.begins_with(source + ":"):
			continue
		var values: Dictionary = _sources[existing].duplicate()
		for action: String in values.keys():
			_block_physical_action(existing, action)
			_set_strength(existing, action, 0.0, true)
			if InputMap.has_action(action) and _aggregate_strength(action) <= 0.0:
				Input.action_release(action)
	if source.begins_with("joy:"):
		var parts: PackedStringArray = source.split(":")
		if parts.size() >= 2:
			_look_axes.erase(int(parts[1]))
		for existing: String in _raw_sources.keys():
			if existing == source or existing.begins_with(source + ":"):
				var raw: Dictionary = _raw_sources[existing]
				for action: String in raw.keys():
					_block_physical_action(existing, action)

func cancel_all() -> void:
	for source: String in _raw_sources.keys():
		var raw: Dictionary = _raw_sources[source]
		for action: String in raw.keys():
			_block_physical_action(source, action)
	for action: String in ACTIONS:
		cancel_action(action)
	_look_axes.clear()

func set_context(screen: String) -> void:
	if context == screen:
		return
	cancel_all()
	context = screen

func notify_device(device: String) -> void:
	if device not in ["keyboard", "gamepad", "touch"] or active_device == device:
		return
	active_device = device
	device_changed.emit(device)

func get_connected_gamepad_count() -> int:
	return Input.get_connected_joypads().size()

func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		return
	var prefix: String = "joy:%d" % device
	cancel_source(prefix)
	for source: String in _raw_sources.keys():
		if source.begins_with(prefix + ":"):
			_raw_sources.erase(source)
	for source: String in _blocked_sources.keys():
		if source.begins_with(prefix + ":"):
			_blocked_sources.erase(source)
	if active_device == "gamepad" and get_connected_gamepad_count() == 0:
		notify_device("touch" if SafeArea.is_default_touch_platform() else "keyboard")

func hint(action: String) -> String:
	if active_device == "gamepad":
		return str(PAD_HINTS.get(action, "Y / △ · " + str(ACTION_LABELS.get(action, action))))
	if active_device == "touch":
		return str(ACTION_LABELS.get(action, "快捷操作"))
	return str(KEY_HINTS.get(action, action))

func apply_settings(values: Dictionary, persist: bool = true) -> void:
	for key: String in DEFAULT_SETTINGS:
		if values.has(key):
			settings[key] = values[key]
	settings["gamepad_sensitivity"] = clampf(float(settings["gamepad_sensitivity"]), 0.2, 3.0)
	settings["touch_sensitivity"] = clampf(float(settings["touch_sensitivity"]), 0.2, 3.0)
	settings["deadzone"] = clampf(float(settings["deadzone"]), 0.05, 0.6)
	settings["touch_scale"] = clampf(float(settings["touch_scale"]), TOUCH_SCALE_MIN, TOUCH_SCALE_MAX)
	settings["touch_opacity"] = clampf(float(settings["touch_opacity"]), TOUCH_OPACITY_MIN, TOUCH_OPACITY_MAX)
	settings["invert_y"] = bool(settings["invert_y"])
	if str(settings["touch_mode"]) not in ["auto", "on", "off"]:
		settings["touch_mode"] = "auto"
	if str(settings["graphics_quality"]) not in ["auto", "performance", "high"]:
		settings["graphics_quality"] = "auto"
	_update_deadzones()
	if persist:
		_save_settings()
	settings_changed.emit()

func _save_settings() -> void:
	var config := ConfigFile.new()
	for key: String in DEFAULT_SETTINGS:
		config.set_value("controls", key, settings[key])
	var error: Error = config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("无法保存操作设置：%s" % error_string(error))

func _load_settings() -> void:
	if _loaded_settings:
		return
	_loaded_settings = true
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	var values: Dictionary = {}
	for key: String in DEFAULT_SETTINGS:
		values[key] = config.get_value("controls", key, DEFAULT_SETTINGS[key])
	apply_settings(values, false)
