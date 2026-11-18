extends RefCounted
## Unified safe-area & mobile platform helper across Desktop, Native Mobile, Web JS Bridge, and Headless Tests.

static var _mock_insets: Dictionary = {}
static var _cached_web_insets: Dictionary = {"top": 0.0, "right": 0.0, "bottom": 0.0, "left": 0.0, "coarse": false}
static var _last_web_poll_msec: int = -10000
static var _last_coarse_poll_msec: int = -10000
static var _last_web_viewport_size: Vector2 = Vector2.ZERO
static var _cached_coarse_pointer: bool = false

static func set_mock_insets(top: float, right: float, bottom: float, left: float) -> void:
	_mock_insets = {
		"top": maxf(0.0, top),
		"right": maxf(0.0, right),
		"bottom": maxf(0.0, bottom),
		"left": maxf(0.0, left),
	}

static func clear_mock_insets() -> void:
	_mock_insets.clear()

static func has_mock_insets() -> bool:
	return not _mock_insets.is_empty()

static func invalidate_web_cache() -> void:
	_last_web_poll_msec = -10000
	_last_coarse_poll_msec = -10000

static func get_display_scale() -> float:
	var s := DisplayServer.screen_get_scale()
	if OS.get_name() == "Android" and s <= 1.01:
		var dpi := DisplayServer.screen_get_dpi()
		if dpi > 0:
			s = clampf(float(dpi) / 160.0, 1.0, 4.0)
		else:
			var win := Vector2(DisplayServer.window_get_size())
			if win.x > 0.0 and win.y > 0.0:
				s = clampf(minf(win.x, win.y) / 390.0, 1.0, 3.5)
	return maxf(1.0, s)

static func _poll_web_coarse_pointer() -> void:
	if not OS.has_feature("web") or not Engine.has_singleton("JavaScriptBridge"):
		return
	var now_msec := Time.get_ticks_msec()
	if (now_msec - _last_coarse_poll_msec) < 500 and _last_coarse_poll_msec >= 0:
		return
	_last_coarse_poll_msec = now_msec
	var raw: Variant = JavaScriptBridge.eval(
		"(window.__abyssalGetSafeInsetsJson ? window.__abyssalGetSafeInsetsJson() : '')",
		true
	)
	if typeof(raw) != TYPE_STRING or String(raw).is_empty():
		return
	var parsed: Variant = JSON.parse_string(String(raw))
	if typeof(parsed) == TYPE_DICTIONARY:
		_cached_coarse_pointer = bool((parsed as Dictionary).get("coarsePointer", false))
		_cached_web_insets["coarse"] = _cached_coarse_pointer

static func is_mobile_web() -> bool:
	if OS.has_feature("web_android") or OS.has_feature("web_ios"):
		return true
	if OS.has_feature("web"):
		_poll_web_coarse_pointer()
		if _cached_coarse_pointer:
			return true
	return false

static func is_default_touch_platform() -> bool:
	return (
		OS.has_feature("android")
		or OS.has_feature("ios")
		or OS.has_feature("web_android")
		or OS.has_feature("web_ios")
		or is_mobile_web()
	)

static func _poll_web_bridge(viewport_size: Vector2) -> void:
	if not OS.has_feature("web") or not Engine.has_singleton("JavaScriptBridge"):
		return
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		_poll_web_coarse_pointer()
		return
	var now_msec := Time.get_ticks_msec()
	if viewport_size.is_equal_approx(_last_web_viewport_size) and (now_msec - _last_web_poll_msec) < 180 and _last_web_poll_msec >= 0:
		return
	_last_web_poll_msec = now_msec
	_last_web_viewport_size = viewport_size
	var raw: Variant = JavaScriptBridge.eval(
		"(window.__abyssalGetSafeInsetsJson ? window.__abyssalGetSafeInsetsJson() : '')",
		true
	)
	if typeof(raw) != TYPE_STRING or String(raw).is_empty():
		return
	var parsed: Variant = JSON.parse_string(String(raw))
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var d: Dictionary = parsed
	var css_w := maxf(1.0, float(d.get("canvasWidth", d.get("innerWidth", viewport_size.x))))
	var css_h := maxf(1.0, float(d.get("canvasHeight", d.get("innerHeight", viewport_size.y))))
	var sx := (viewport_size.x / css_w) if viewport_size.x > 0.0 else 1.0
	var sy := (viewport_size.y / css_h) if viewport_size.y > 0.0 else 1.0
	_cached_coarse_pointer = bool(d.get("coarsePointer", false))
	_cached_web_insets = {
		"top": maxf(0.0, float(d.get("top", 0.0)) * sy),
		"right": maxf(0.0, float(d.get("right", 0.0)) * sx),
		"bottom": maxf(0.0, float(d.get("bottom", 0.0)) * sy),
		"left": maxf(0.0, float(d.get("left", 0.0)) * sx),
		"coarse": _cached_coarse_pointer,
	}

static func get_insets(viewport: Viewport) -> Dictionary:
	var size := viewport.get_visible_rect().size if viewport != null else Vector2(1280.0, 800.0)
	if size.x <= 0.0 or size.y <= 0.0:
		size = Vector2(1280.0, 800.0)
	if not _mock_insets.is_empty():
		return {
			"top": float(_mock_insets.get("top", 0.0)),
			"right": float(_mock_insets.get("right", 0.0)),
			"bottom": float(_mock_insets.get("bottom", 0.0)),
			"left": float(_mock_insets.get("left", 0.0)),
		}
	if OS.has_feature("web"):
		_poll_web_bridge(size)
		return {
			"top": float(_cached_web_insets.get("top", 0.0)),
			"right": float(_cached_web_insets.get("right", 0.0)),
			"bottom": float(_cached_web_insets.get("bottom", 0.0)),
			"left": float(_cached_web_insets.get("left", 0.0)),
		}
	if OS.get_name() in ["Android", "iOS"]:
		var window_size := Vector2(DisplayServer.window_get_size())
		var display_safe := Rect2(DisplayServer.get_display_safe_area())
		if window_size.x > 0.0 and window_size.y > 0.0 and display_safe.size.x > 0.0 and display_safe.size.y > 0.0:
			var scale := Vector2(size.x / window_size.x, size.y / window_size.y)
			var left := maxf(0.0, display_safe.position.x * scale.x)
			var top := maxf(0.0, display_safe.position.y * scale.y)
			var right := maxf(0.0, (window_size.x - (display_safe.position.x + display_safe.size.x)) * scale.x)
			var bottom := maxf(0.0, (window_size.y - (display_safe.position.y + display_safe.size.y)) * scale.y)
			return {"top": top, "right": right, "bottom": bottom, "left": left}
	return {"top": 0.0, "right": 0.0, "bottom": 0.0, "left": 0.0}

static func get_safe_rect(viewport: Viewport, min_margin: Vector2 = Vector2.ZERO, extra_inset_pad: float = 0.0) -> Rect2:
	var size := viewport.get_visible_rect().size if viewport != null else Vector2(1280.0, 800.0)
	if size.x <= 0.0 or size.y <= 0.0:
		size = Vector2(1280.0, 800.0)
	var insets := get_insets(viewport)
	var raw_left := float(insets.get("left", 0.0))
	var raw_right := float(insets.get("right", 0.0))
	var raw_top := float(insets.get("top", 0.0))
	var raw_bottom := float(insets.get("bottom", 0.0))
	var left := maxf(min_margin.x, raw_left + (extra_inset_pad if raw_left > 0.0 else 0.0))
	var right := maxf(min_margin.x, raw_right + (extra_inset_pad if raw_right > 0.0 else 0.0))
	var top := maxf(min_margin.y, raw_top + (extra_inset_pad if raw_top > 0.0 else 0.0))
	var bottom := maxf(min_margin.y, raw_bottom + (extra_inset_pad if raw_bottom > 0.0 else 0.0))
	var w := maxf(160.0, size.x - left - right)
	var h := maxf(160.0, size.y - top - bottom)
	return Rect2(Vector2(left, top), Vector2(w, h))
