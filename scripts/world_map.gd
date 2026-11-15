extends RefCounted

const Ocean = preload("res://scripts/ocean.gd")
const OceanDepths = preload("res://scripts/ocean_depths.gd")
const ArtDirection = preload("res://scripts/art_direction.gd")

const WORLD_HALF := 900.0
const WORLD_SPAN := 1800.0
const SURVEY_GRID := 24
const FOG_UNSURVEYED := Color(0.028, 0.068, 0.096, 0.64)
const FOG_SURVEYED := Color(0.032, 0.072, 0.098, 0.0)
const RADAR_FOG_MODULATE := Color(1.0, 1.0, 1.0, 1.0)

const INK := ArtDirection.INK
const PAPER := ArtDirection.PAPER
const CYAN := ArtDirection.CYAN
const AMBER := ArtDirection.AMBER
const DANGER := ArtDirection.DANGER
const PANEL := ArtDirection.PANEL
const MUTED := ArtDirection.MUTED
const HARBOR_SAGE := Color("8eaa74")
const BOSS_LANDMARK_IDS := ["altar", "storm_ridge", "kraken_trench", "turtle_basin", "obsidian_caldera"]

const REGION_LABELS := [
	{"name": "北境珊瑚环礁", "pos": Vector2(40, 445), "sub": "SUNLIT ATOLL"},
	{"name": "翡翠巨藻海峡", "pos": Vector2(-340, 375), "sub": "KELP STRAIT"},
	{"name": "极光晶柱海岭", "pos": Vector2(415, 320), "sub": "AURORA RIDGE"},
	{"name": "中央出生浅礁", "pos": Vector2(-115, -75), "sub": "CENTRAL REEF"},
	{"name": "沉没星象古都", "pos": Vector2(535, -135), "sub": "SUNKEN CITADEL"},
	{"name": "巨兽龙骨荒原", "pos": Vector2(-555, -165), "sub": "LEVIATHAN WASTES"},
	{"name": "黑曜石火山口", "pos": Vector2(-470, -505), "sub": "OBSIDIAN CALDERA"},
	{"name": "幽灵沉船海滩", "pos": Vector2(450, -420), "sub": "GHOST FLEET"},
	{"name": "极渊星辉圣域", "pos": Vector2(60, -725), "sub": "HADAL SANCTUM"}
]

static var _bathy_cache: Dictionary = {}
static var _region_palettes: Dictionary = {}

static func _get_region_palettes() -> Dictionary:
	if _region_palettes.is_empty():
		for key: String in ArtDirection.REGIONS:
			_region_palettes[key] = ArtDirection.region_profile(key)
	return _region_palettes

static func _bathymetry_color(depth: float, world_x: float, world_z: float) -> Color:
	var palettes := _get_region_palettes()
	var weights := ArtDirection.region_weights(Vector2(world_x, world_z))
	var reg_water := Color(0.0, 0.0, 0.0, 1.0)
	var reg_sand := Color(0.0, 0.0, 0.0, 1.0)
	var reg_rock := Color(0.0, 0.0, 0.0, 1.0)
	var reg_shadow := Color(0.0, 0.0, 0.0, 1.0)
	for key: String in weights:
		var w: float = float(weights[key])
		var prof: Dictionary = palettes.get(key, palettes["core"])
		var cw: Color = prof["water"]
		var cs: Color = prof["sand"]
		var cr: Color = prof["rock"]
		var csh: Color = prof["shadow"]
		reg_water.r += cw.r * w
		reg_water.g += cw.g * w
		reg_water.b += cw.b * w
		reg_sand.r += cs.r * w
		reg_sand.g += cs.g * w
		reg_sand.b += cs.b * w
		reg_rock.r += cr.r * w
		reg_rock.g += cr.g * w
		reg_rock.b += cr.b * w
		reg_shadow.r += csh.r * w
		reg_shadow.g += csh.g * w
		reg_shadow.b += csh.b * w
	var hadal_w: float = float(weights.get("hadal", 0.0))
	var caldera_w: float = float(weights.get("caldera", 0.0))
	var c_surface := Color("22b0b8").lerp(reg_water.lerp(reg_sand, 0.42), 0.46)
	var c_reef := Color("168fa8").lerp(reg_water.lerp(reg_sand, 0.22), 0.44)
	var c_shelf := Color("157092").lerp(reg_water.lerp(reg_rock, 0.30), 0.42)
	var c_twilight := Color("18597f").lerp(reg_water.lerp(reg_shadow, 0.55), 0.38)
	var c_bathyal := Color("183e63").lerp(reg_shadow.lerp(INK, 0.55), 0.25)
	var c_hadal := Color("122b4d").lerp(Color("0a1624"), hadal_w)
	var chart_depth := clampf(depth, 0.0, OceanDepths.MAX_SEAFLOOR_DEPTH)
	var base: Color
	if chart_depth < 35.0:
		base = c_surface.lerp(c_reef, chart_depth / 35.0)
	elif chart_depth < 90.0:
		base = c_reef.lerp(c_shelf, (chart_depth - 35.0) / 55.0)
	elif chart_depth < 200.0:
		base = c_shelf.lerp(c_twilight, (chart_depth - 90.0) / 110.0)
	elif chart_depth < 360.0:
		base = c_twilight.lerp(c_bathyal, (chart_depth - 200.0) / 160.0)
	else:
		base = c_bathyal.lerp(c_hadal, (chart_depth - 360.0) / (OceanDepths.MAX_SEAFLOOR_DEPTH - 360.0))
	if caldera_w > 0.0:
		base = base.lerp(Color("38211b"), caldera_w * 0.34)
	var phase_50 := fposmod(chart_depth, 50.0)
	var dist_50 := minf(phase_50, 50.0 - phase_50)
	var strength_50 := 1.0 - smoothstep(0.0, 0.85, dist_50)
	var phase_100 := fposmod(chart_depth, 100.0)
	var dist_100 := minf(phase_100, 100.0 - phase_100)
	var strength_100 := 1.0 - smoothstep(0.0, 1.05, dist_100)
	var contour_ink := CYAN.lerp(PAPER, 0.35)
	base = base.lerp(contour_ink, strength_50 * 0.075 + strength_100 * 0.065)
	return base

static func build_bathymetry_texture(resolution: int = 128) -> ImageTexture:
	if _bathy_cache.has(resolution):
		var cached: ImageTexture = _bathy_cache[resolution]
		if is_instance_valid(cached):
			return cached
	var img := Image.create(resolution, resolution, false, Image.FORMAT_RGBA8)
	for py in range(resolution):
		var wz := lerpf(-WORLD_HALF, WORLD_HALF, (float(py) + 0.5) / float(resolution))
		for px in range(resolution):
			var wx := lerpf(-WORLD_HALF, WORLD_HALF, (float(px) + 0.5) / float(resolution))
			var d := maxf(0.0, -Ocean.floor_height(wx, wz))
			img.set_pixel(px, py, _bathymetry_color(d, wx, wz))
	var tex := ImageTexture.create_from_image(img)
	_bathy_cache[resolution] = tex
	return tex


class FogOverlay extends RefCounted:
	static var _survey_keys: PackedStringArray = PackedStringArray()
	var fog_img: Image
	var fog_tex: ImageTexture
	var _last_surveyed_count: int = -1

	static func _get_survey_keys() -> PackedStringArray:
		if _survey_keys.is_empty():
			_survey_keys.resize(SURVEY_GRID * SURVEY_GRID)
			for gz in range(SURVEY_GRID):
				var row_off := gz * SURVEY_GRID
				for gx in range(SURVEY_GRID):
					_survey_keys[row_off + gx] = "%d_%d" % [gx, gz]
		return _survey_keys

	func get_texture(surveyed_cells: Dictionary) -> ImageTexture:
		var count := surveyed_cells.size()
		if fog_tex == null:
			fog_img = Image.create(SURVEY_GRID, SURVEY_GRID, false, Image.FORMAT_RGBA8)
			_rebuild(surveyed_cells)
			fog_tex = ImageTexture.create_from_image(fog_img)
			_last_surveyed_count = count
		elif count != _last_surveyed_count:
			_rebuild(surveyed_cells)
			fog_tex.update(fog_img)
			_last_surveyed_count = count
		return fog_tex

	func _rebuild(surveyed_cells: Dictionary) -> void:
		fog_img.fill(FOG_UNSURVEYED)
		if surveyed_cells.is_empty():
			return
		var keys := _get_survey_keys()
		for gz in range(SURVEY_GRID):
			var row_off := gz * SURVEY_GRID
			for gx in range(SURVEY_GRID):
				if surveyed_cells.has(keys[row_off + gx]):
					fog_img.set_pixel(gx, gz, FOG_SURVEYED)


class CompassStrip extends Control:
	var heading_yaw: float = 0.0
	var player_pos: Vector3 = Vector3.ZERO
	var home_pos: Vector3 = Ocean.HOME
	var has_waypoint: bool = false
	var waypoint_pos: Vector3 = Vector3.ZERO
	var nearest_outpost_pos: Vector3 = Vector3.ZERO
	var has_nearest_outpost: bool = false

	func _ready() -> void:
		resized.connect(queue_redraw)

	func update_compass(p_pos: Vector3, forward_vec: Vector3, wp_active: bool, wp_pos: Vector3, out_active: bool, out_pos: Vector3) -> void:
		player_pos = p_pos
		var flat := Vector2(forward_vec.x, forward_vec.z)
		if flat.length_squared() > 0.0001:
			# North = -Z (angle 0), East = +X (+PI/2), South = +Z (PI), West = -X (-PI/2)
			heading_yaw = atan2(flat.x, -flat.y)
		has_waypoint = wp_active
		waypoint_pos = wp_pos
		has_nearest_outpost = out_active
		nearest_outpost_pos = out_pos
		queue_redraw()

	func _bearing_to(target: Vector3) -> float:
		var dx := target.x - player_pos.x
		var dz := target.z - player_pos.z
		return atan2(dx, -dz)

	func _angle_diff(a: float, b: float) -> float:
		return wrapf(a - b, -PI, PI)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var bg_rect := Rect2(0, 0, w, h)
		draw_rect(bg_rect, Color(PANEL.r, PANEL.g, PANEL.b, 0.86), true)
		draw_rect(bg_rect, Color(CYAN, 0.24), false, 1.0)
		var font: Font = get_theme_default_font()
		var half_fov := deg_to_rad(85.0)
		var cx := w * 0.5

		var dirs := [
			{"deg": 0, "txt": "N 北", "major": true},
			{"deg": 45, "txt": "NE", "major": false},
			{"deg": 90, "txt": "E 东", "major": true},
			{"deg": 135, "txt": "SE", "major": false},
			{"deg": 180, "txt": "S 南", "major": true},
			{"deg": 225, "txt": "SW", "major": false},
			{"deg": 270, "txt": "W 西", "major": true},
			{"deg": 315, "txt": "NW", "major": false}
		]
		for deg in range(0, 360, 15):
			var rad := deg_to_rad(float(deg))
			var diff := _angle_diff(rad, heading_yaw)
			if absf(diff) > half_fov:
				continue
			var x := cx + (diff / half_fov) * (w * 0.46)
			var is_card := deg % 45 == 0
			var tick_h := 7.0 if is_card else 4.0
			var tick_col := Color(CYAN, 0.62) if is_card else Color(MUTED, 0.34)
			draw_line(Vector2(x, h - tick_h), Vector2(x, h - 1.0), tick_col, 1.0)

		if font:
			var compact_strip := w < 190.0
			for d in dirs:
				if compact_strip and not bool(d["major"]):
					continue
				var rad := deg_to_rad(float(d["deg"]))
				var diff := _angle_diff(rad, heading_yaw)
				if absf(diff) > half_fov:
					continue
				var x := cx + (diff / half_fov) * (w * 0.46)
				var col: Color = PAPER if bool(d["major"]) else MUTED
				if int(d["deg"]) == 0:
					col = AMBER
				var txt: String = str(d["txt"])
				var fsz: int = (11 if compact_strip else 12) if bool(d["major"]) else 10
				draw_string(font, Vector2(x - float(txt.length()) * 3.8, 14.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, col)

			var pip_y := minf(h - 3.0, 29.0)
			_draw_pip(font, _bearing_to(home_pos), "⌂", HARBOR_SAGE, half_fov, cx, w, pip_y)
			if has_nearest_outpost:
				_draw_pip(font, _bearing_to(nearest_outpost_pos), "⬡", CYAN, half_fov, cx, w, pip_y)
			if has_waypoint:
				_draw_pip(font, _bearing_to(waypoint_pos), "✦", AMBER, half_fov, cx, w, pip_y)

		var tri := PackedVector2Array([Vector2(cx - 4, 1), Vector2(cx + 4, 1), Vector2(cx, 6)])
		draw_colored_polygon(tri, AMBER)

	func _draw_pip(font: Font, bearing: float, icon: String, col: Color, half_fov: float, cx: float, w: float, pip_y: float = 29.0) -> void:
		var diff := clampf(_angle_diff(bearing, heading_yaw), -half_fov, half_fov)
		var x := cx + (diff / half_fov) * (w * 0.45)
		draw_string(font, Vector2(x - 5.0, pip_y), icon, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)


class MinimapRadar extends Control:
	var bathy_tex: ImageTexture
	var fog_overlay := FogOverlay.new()
	var player_pos: Vector3 = Vector3.ZERO
	var heading_yaw: float = 0.0
	var surveyed_cells: Dictionary = {}
	var landmarks: Dictionary = {}
	var discovered_landmarks: Array = []
	var outposts: Array = []
	var unlocked_outposts: Array = []
	var submarines: Array = []
	var relics: Array = []
	var pinged_targets: Dictionary = {}
	var has_waypoint: bool = false
	var waypoint_pos: Vector3 = Vector3.ZERO
	var radar_range: float = 220.0
	var pulse_clock: float = 0.0
	var map_hint: String = "M"

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func set_bathymetry(tex: ImageTexture) -> void:
		bathy_tex = tex

	func update_radar(data: Dictionary, delta: float) -> void:
		pulse_clock += delta
		player_pos = data.get("player_pos", Vector3.ZERO)
		var fwd: Vector3 = data.get("player_forward", Vector3.FORWARD)
		var flat := Vector2(fwd.x, fwd.z)
		if flat.length_squared() > 0.0001:
			heading_yaw = atan2(flat.x, -flat.y)
		surveyed_cells = data.get("surveyed_cells", {})
		landmarks = data.get("landmarks", {})
		discovered_landmarks = data.get("discovered_landmarks", [])
		outposts = data.get("outposts", [])
		unlocked_outposts = data.get("unlocked_outposts", [])
		submarines = data.get("submarines", [])
		relics = data.get("relics", [])
		pinged_targets = data.get("pinged_targets", {})
		has_waypoint = bool(data.get("has_waypoint", false))
		waypoint_pos = data.get("waypoint_pos", Vector3.ZERO)
		queue_redraw()

	func _world_to_radar(wx: float, wz: float, center: Vector2, half_r: float) -> Vector2:
		var dx := (wx - player_pos.x) / radar_range * half_r
		var dz := (wz - player_pos.z) / radar_range * half_r
		return center + Vector2(dx, dz)

	func _draw() -> void:
		var compact_radar := size.y < 118.0
		var pad_x := 8.0 if compact_radar else 12.0
		var reserve_y := 18.0 if compact_radar else 28.0
		var top_y := 4.0 if compact_radar else 6.0
		var map_side := maxf(32.0, minf(size.x - pad_x, size.y - reserve_y))
		var map_rect := Rect2((size.x - map_side) * 0.5, top_y, map_side, map_side)
		var center := map_rect.get_center()
		var half_r := map_side * 0.5

		draw_rect(Rect2(0, 0, size.x, size.y), PANEL, true)
		draw_rect(Rect2(0, 0, size.x, size.y), Color(CYAN, 0.28), false, 1.0)

		if bathy_tex != null:
			var u0 := clampf((player_pos.x - radar_range + WORLD_HALF) / WORLD_SPAN, 0.0, 1.0)
			var v0 := clampf((player_pos.z - radar_range + WORLD_HALF) / WORLD_SPAN, 0.0, 1.0)
			var u1 := clampf((player_pos.x + radar_range + WORLD_HALF) / WORLD_SPAN, 0.0, 1.0)
			var v1 := clampf((player_pos.z + radar_range + WORLD_HALF) / WORLD_SPAN, 0.0, 1.0)
			var tw := float(bathy_tex.get_width())
			var th := float(bathy_tex.get_height())
			var src := Rect2(u0 * tw, v0 * th, maxf(1.0, (u1 - u0) * tw), maxf(1.0, (v1 - v0) * th))
			draw_texture_rect_region(bathy_tex, map_rect, src, Color(1, 1, 1, 0.95))
		else:
			draw_rect(map_rect, INK, true)

		var f_wx0 := clampf(player_pos.x - radar_range, -WORLD_HALF, WORLD_HALF)
		var f_wz0 := clampf(player_pos.z - radar_range, -WORLD_HALF, WORLD_HALF)
		var f_wx1 := clampf(player_pos.x + radar_range, -WORLD_HALF, WORLD_HALF)
		var f_wz1 := clampf(player_pos.z + radar_range, -WORLD_HALF, WORLD_HALF)
		if f_wx1 > f_wx0 and f_wz1 > f_wz0:
			var f_tex := fog_overlay.get_texture(surveyed_cells)
			var f_p0 := _world_to_radar(f_wx0, f_wz0, center, half_r)
			var f_p1 := _world_to_radar(f_wx1, f_wz1, center, half_r)
			var f_src := Rect2(
				(f_wx0 + WORLD_HALF) / WORLD_SPAN * float(SURVEY_GRID),
				(f_wz0 + WORLD_HALF) / WORLD_SPAN * float(SURVEY_GRID),
				maxf(0.001, (f_wx1 - f_wx0) / WORLD_SPAN * float(SURVEY_GRID)),
				maxf(0.001, (f_wz1 - f_wz0) / WORLD_SPAN * float(SURVEY_GRID))
			)
			draw_texture_rect_region(f_tex, Rect2(f_p0, f_p1 - f_p0), f_src, RADAR_FOG_MODULATE)

		draw_arc(center, half_r * 0.45, 0.0, TAU, 36, Color(CYAN, 0.15), 1.0)
		draw_arc(center, half_r * 0.85, 0.0, TAU, 48, Color(CYAN, 0.22), 1.0)
		draw_line(Vector2(map_rect.position.x, center.y), Vector2(map_rect.end.x, center.y), Color(CYAN, 0.11), 1.0)
		draw_line(Vector2(center.x, map_rect.position.y), Vector2(center.x, map_rect.end.y), Color(CYAN, 0.11), 1.0)

		var sweep_ang := fmod(pulse_clock * 1.35, TAU)
		var sweep_end := center + Vector2(sin(sweep_ang), -cos(sweep_ang)) * (half_r * 0.92)
		draw_line(center, sweep_end, Color(CYAN, 0.34), 1.1)

		for lm_id in landmarks:
			var lm: Dictionary = landmarks[lm_id]
			var lpos: Vector3 = lm["pos"]
			var is_disc: bool = discovered_landmarks.has(lm_id)
			var is_pinged: bool = pinged_targets.has("lm_" + str(lm_id))
			if not is_disc and not is_pinged:
				continue
			var rp := _world_to_radar(lpos.x, lpos.z, center, half_r)
			if map_rect.has_point(rp):
				var is_hazard := BOSS_LANDMARK_IDS.has(str(lm_id))
				var lm_col := (DANGER if is_hazard else CYAN) if is_disc else Color(AMBER, 0.88)
				draw_circle(rp, 2.8 if is_disc else 2.4, lm_col)

		for out in outposts:
			var opos: Vector3 = out["pos"]
			var oid: String = str(out["id"])
			var unlocked: bool = unlocked_outposts.has(oid)
			var rp := _world_to_radar(opos.x, opos.z, center, half_r)
			if map_rect.has_point(rp):
				var c := HARBOR_SAGE if unlocked else AMBER
				draw_rect(Rect2(rp - Vector2(3.2, 3.2), Vector2(6.4, 6.4)), c, true)

		for rel in relics:
			if bool(rel.get("collected", false)):
				continue
			var rid: String = str(rel.get("id", ""))
			var rpos: Vector3 = rel["pos"]
			if not pinged_targets.has(rid) and rpos.distance_to(player_pos) > 85.0:
				continue
			var rp := _world_to_radar(rpos.x, rpos.z, center, half_r)
			if map_rect.has_point(rp):
				draw_circle(rp, 2.6, DANGER)

		for sub in submarines:
			var spos: Vector3 = sub["pos"]
			var rp := _world_to_radar(spos.x, spos.z, center, half_r)
			if map_rect.has_point(rp):
				draw_circle(rp, 3.2, PAPER)

		var hp := _world_to_radar(Ocean.HOME.x, Ocean.HOME.z, center, half_r)
		hp.x = clampf(hp.x, map_rect.position.x + 4.0, map_rect.end.x - 4.0)
		hp.y = clampf(hp.y, map_rect.position.y + 4.0, map_rect.end.y - 4.0)
		draw_circle(hp, 3.6, HARBOR_SAGE)

		if has_waypoint:
			var wp := _world_to_radar(waypoint_pos.x, waypoint_pos.z, center, half_r)
			wp.x = clampf(wp.x, map_rect.position.x + 5.0, map_rect.end.x - 5.0)
			wp.y = clampf(wp.y, map_rect.position.y + 5.0, map_rect.end.y - 5.0)
			draw_line(center, wp, Color(AMBER, 0.48), 1.1)
			var dia := PackedVector2Array([wp + Vector2(0, -4.5), wp + Vector2(4.5, 0), wp + Vector2(0, 4.5), wp + Vector2(-4.5, 0)])
			draw_colored_polygon(dia, AMBER)

		var dir2 := Vector2(sin(heading_yaw), -cos(heading_yaw))
		var side2 := Vector2(-dir2.y, dir2.x)
		var chev := PackedVector2Array([
			center + dir2 * 6.5,
			center - dir2 * 4.5 + side2 * 4.2,
			center - dir2 * 2.0,
			center - dir2 * 4.5 - side2 * 4.2
		])
		draw_colored_polygon(chev, PAPER)
		draw_rect(map_rect, Color(CYAN, 0.26), false, 1.0)

		var font: Font = get_theme_default_font()
		if font:
			var coord_txt := ("X:%+d Z:%+d" % [roundi(player_pos.x), roundi(player_pos.z)]) if compact_radar else ("X:%+d  Z:%+d  [%s海图]" % [roundi(player_pos.x), roundi(player_pos.z), map_hint])
			var x_off := 5.0 if compact_radar else 8.0
			var y_off := 4.0 if compact_radar else 6.0
			draw_string(font, Vector2(x_off, size.y - y_off), coord_txt, HORIZONTAL_ALIGNMENT_LEFT, maxf(24.0, size.x - x_off * 2.0), 10 if compact_radar else 11, MUTED)


class SeaChartCanvas extends Control:
	signal waypoint_set(world_xz: Vector2)
	signal waypoint_cleared
	signal fast_travel_requested(target_id: String, world_pos: Vector3, target_name: String)
	signal selection_changed(info: Dictionary)
	signal sidebar_focus_requested

	var bathy_tex: ImageTexture
	var fog_overlay := FogOverlay.new()
	var zoom: float = 1.0
	var pan_world: Vector2 = Vector2.ZERO
	var dragging: bool = false
	var player_pos: Vector3 = Vector3.ZERO
	var heading_yaw: float = 0.0
	var surveyed_cells: Dictionary = {}
	var landmarks: Dictionary = {}
	var discovered_landmarks: Array = []
	var outposts: Array = []
	var unlocked_outposts: Array = []
	var submarines: Array = []
	var relics: Array = []
	var pinged_targets: Dictionary = {}
	var has_waypoint: bool = false
	var waypoint_pos: Vector3 = Vector3.ZERO
	var selected_node: Dictionary = {}
	var hovered_node: Dictionary = {}
	var input_controller: Node
	var _touches: Dictionary = {}
	var _touch_origins: Dictionary = {}
	var _touch_moved: Dictionary = {}
	var _pinch_distance := 0.0
	var _had_multitouch := false
	var _last_touch_time := -1000
	var _gamepad_device := -1

	func _ready() -> void:
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_ALL
		resized.connect(queue_redraw)
		visibility_changed.connect(func() -> void:
			if not is_visible_in_tree():
				cancel_touches()
		)

	func cancel_touches() -> void:
		_touches.clear()
		_touch_origins.clear()
		_touch_moved.clear()
		_pinch_distance = 0.0
		_had_multitouch = false
		dragging = false

	func _input(event: InputEvent) -> void:
		# Keep the original touch owner after a finger leaves the map bounds.
		if not is_visible_in_tree():
			return
		if event is InputEventScreenDrag and _touches.has(event.index):
			var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
			_handle_touch_drag(event.index, local)
			get_viewport().set_input_as_handled()
		elif event is InputEventScreenTouch and not event.pressed and _touches.has(event.index):
			var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
			_handle_touch_release(event.index, local, event.canceled)
			get_viewport().set_input_as_handled()

	func _process(delta: float) -> void:
		if not is_visible_in_tree() or not has_focus():
			return
		var connected := Input.get_connected_joypads()
		if not connected.has(_gamepad_device):
			_gamepad_device = int(connected[0]) if not connected.is_empty() else -1
		if _gamepad_device < 0:
			return
		var stick := Vector2(Input.get_joy_axis(_gamepad_device, JOY_AXIS_LEFT_X), Input.get_joy_axis(_gamepad_device, JOY_AXIS_LEFT_Y))
		var deadzone := 0.2
		if is_instance_valid(input_controller):
			deadzone = float(input_controller.settings.get("deadzone", 0.2))
		if stick.length() > deadzone:
			stick = stick.normalized() * clampf((stick.length() - deadzone) / maxf(1.0 - deadzone, 0.01), 0.0, 1.0)
			pan_world += stick * (WORLD_SPAN / zoom) * delta * 0.45
			_clamp_pan()
			queue_redraw()

	func set_bathymetry(tex: ImageTexture) -> void:
		bathy_tex = tex

	func center_on_player() -> void:
		pan_world = Vector2(player_pos.x, player_pos.z)
		_clamp_pan()
		queue_redraw()

	func adjust_zoom(factor: float) -> void:
		zoom = clampf(zoom * factor, 1.0, 3.2)
		_clamp_pan()
		queue_redraw()

	func _clamp_pan() -> void:
		var half_vis := (WORLD_HALF / zoom)
		var max_pan := maxf(0.0, WORLD_HALF - half_vis)
		pan_world.x = clampf(pan_world.x, -max_pan, max_pan)
		pan_world.y = clampf(pan_world.y, -max_pan, max_pan)

	func update_chart(data: Dictionary) -> void:
		player_pos = data.get("player_pos", Vector3.ZERO)
		var fwd: Vector3 = data.get("player_forward", Vector3.FORWARD)
		var flat := Vector2(fwd.x, fwd.z)
		if flat.length_squared() > 0.0001:
			heading_yaw = atan2(flat.x, -flat.y)
		surveyed_cells = data.get("surveyed_cells", {})
		landmarks = data.get("landmarks", {})
		discovered_landmarks = data.get("discovered_landmarks", [])
		outposts = data.get("outposts", [])
		unlocked_outposts = data.get("unlocked_outposts", [])
		submarines = data.get("submarines", [])
		relics = data.get("relics", [])
		pinged_targets = data.get("pinged_targets", {})
		has_waypoint = bool(data.get("has_waypoint", false))
		waypoint_pos = data.get("waypoint_pos", Vector3.ZERO)
		queue_redraw()

	func _world_to_canvas(wx: float, wz: float) -> Vector2:
		var half_vis := WORLD_HALF / zoom
		var nx := (wx - (pan_world.x - half_vis)) / (half_vis * 2.0)
		var nz := (wz - (pan_world.y - half_vis)) / (half_vis * 2.0)
		return Vector2(nx * size.x, nz * size.y)

	func _canvas_to_world(pt: Vector2) -> Vector2:
		var half_vis := WORLD_HALF / zoom
		var wx := (pan_world.x - half_vis) + (pt.x / maxf(size.x, 1.0)) * (half_vis * 2.0)
		var wz := (pan_world.y - half_vis) + (pt.y / maxf(size.y, 1.0)) * (half_vis * 2.0)
		return Vector2(clampf(wx, -WORLD_HALF, WORLD_HALF), clampf(wz, -WORLD_HALF, WORLD_HALF))

	func _collect_interactive_nodes() -> Array[Dictionary]:
		var list: Array[Dictionary] = []
		list.append({
			"id": "home_lifepod",
			"kind": "home",
			"name": "逃生舱母港 (中央基地)",
			"desc": "安全补氧、全功能制造台与跃迁母港",
			"pos": Ocean.HOME,
			"can_travel": true
		})
		for out in outposts:
			var oid := str(out["id"])
			var unlocked := unlocked_outposts.has(oid)
			list.append({
				"id": oid,
				"kind": "outpost",
				"name": str(out["name"]),
				"desc": str(out.get("region", "远洋前哨")) + (" · 已激活跃迁与声呐网" if unlocked else " · 前往现场按 E 激活声呐塔与快速传送"),
				"pos": out["pos"],
				"can_travel": unlocked
			})
		for lm_id in landmarks:
			var lm: Dictionary = landmarks[lm_id]
			var is_disc := discovered_landmarks.has(lm_id)
			var is_pinged := pinged_targets.has("lm_" + str(lm_id))
			var lpos: Vector3 = lm["pos"]
			var gx := clampi(floori((lpos.x + WORLD_HALF) / (WORLD_SPAN / float(SURVEY_GRID))), 0, SURVEY_GRID - 1)
			var gz := clampi(floori((lpos.z + WORLD_HALF) / (WORLD_SPAN / float(SURVEY_GRID))), 0, SURVEY_GRID - 1)
			var cell_seen := surveyed_cells.has("%d_%d" % [gx, gz])
			if not is_disc and not is_pinged and not cell_seen:
				continue
			list.append({
				"id": "lm_" + str(lm_id),
				"raw_id": str(lm_id),
				"kind": "landmark",
				"name": str(lm["name"]) if is_disc else "未知声呐地标 (?)",
				"desc": str(lm.get("desc", "")) if is_disc else "该海域存在明显地质或遗迹回波，潜航靠近即可完成勘测并解锁跃迁",
				"pos": lpos,
				"can_travel": is_disc
			})
		for sub in submarines:
			list.append({
				"id": "sub_" + str(sub.get("name", "")),
				"kind": "submarine",
				"name": str(sub.get("name", "深海潜艇")),
				"desc": "海面/水下系泊载具 · 可设为标点前往登舰驾驶",
				"pos": sub["pos"],
				"can_travel": false
			})
		return list

	func _find_node_at(pt: Vector2) -> Dictionary:
		var best := {}
		var best_d := 26.0
		for item in _collect_interactive_nodes():
			var p3: Vector3 = item["pos"]
			var cp := _world_to_canvas(p3.x, p3.z)
			var d := cp.distance_to(pt)
			if d <= best_d:
				best_d = d
				best = item
		return best

	func select_at(pt: Vector2) -> void:
		# Touch and gamepad selection never travel or place a waypoint implicitly.
		var hit := _find_node_at(pt)
		if hit.is_empty():
			var xz := _canvas_to_world(pt)
			hit = {
				"id": "custom_waypoint", "kind": "waypoint", "name": "海域坐标",
				"desc": "选择「设为导航标点」记录此处；已解锁地标可在操作栏确认跃迁。",
				"pos": Vector3(xz.x, minf(-2.5, Ocean.floor_height(xz.x, xz.y) + 6.0), xz.y),
				"can_travel": false
			}
		selected_node = hit
		selection_changed.emit(hit)
		queue_redraw()

	func cycle_node(step: int) -> void:
		var nodes := _collect_interactive_nodes()
		if nodes.is_empty():
			return
		var index := -1
		for i in range(nodes.size()):
			if nodes[i].get("id", "") == selected_node.get("id", ""):
				index = i
		if index < 0 and step < 0:
			index = 0
		index = posmod(index + step, nodes.size())
		selected_node = nodes[index]
		var pos: Vector3 = selected_node["pos"]
		pan_world = Vector2(pos.x, pos.z)
		_clamp_pan()
		selection_changed.emit(selected_node)
		queue_redraw()

	func _handle_touch_drag(index: int, point: Vector2) -> void:
		_last_touch_time = Time.get_ticks_msec()
		var previous: Vector2 = _touches[index]
		_touches[index] = point
		if point.distance_to(_touch_origins[index]) > 12.0:
			_touch_moved[index] = true
		if _touches.size() >= 2:
			_had_multitouch = true
			var positions := _touches.values()
			var distance: float = (positions[0] as Vector2).distance_to(positions[1])
			if _pinch_distance > 1.0 and distance > 1.0:
				adjust_zoom(distance / _pinch_distance)
			_pinch_distance = distance
		elif bool(_touch_moved.get(index, false)):
			var world_per_pixel := Vector2(WORLD_SPAN / zoom / maxf(size.x, 1.0), WORLD_SPAN / zoom / maxf(size.y, 1.0))
			pan_world -= (point - previous) * world_per_pixel
			_clamp_pan()
			queue_redraw()

	func _handle_touch_release(index: int, point: Vector2, canceled: bool) -> void:
		_last_touch_time = Time.get_ticks_msec()
		var can_select := not canceled and not _had_multitouch and not bool(_touch_moved.get(index, false))
		_touches.erase(index)
		_touch_origins.erase(index)
		_touch_moved.erase(index)
		_pinch_distance = 0.0
		if _touches.is_empty():
			_had_multitouch = false
		if can_select and Rect2(Vector2.ZERO, size).has_point(point):
			select_at(point)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			_last_touch_time = Time.get_ticks_msec()
			if event.pressed:
				_touches[event.index] = event.position
				_touch_origins[event.index] = event.position
				_touch_moved[event.index] = false
				if _touches.size() >= 2:
					_had_multitouch = true
					var positions := _touches.values()
					_pinch_distance = (positions[0] as Vector2).distance_to(positions[1])
			elif _touches.has(event.index):
				_handle_touch_release(event.index, event.position, event.canceled)
			accept_event()
			return
		if event is InputEventScreenDrag:
			if _touches.has(event.index):
				_handle_touch_drag(event.index, event.position)
				accept_event()
			return
		if event is InputEventJoypadButton and event.pressed:
			_gamepad_device = event.device
			match event.button_index:
				JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_LEFT:
					cycle_node(-1)
					accept_event()
				JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_RIGHT:
					cycle_node(1)
					accept_event()
				JOY_BUTTON_LEFT_SHOULDER:
					adjust_zoom(0.8)
					accept_event()
				JOY_BUTTON_RIGHT_SHOULDER:
					adjust_zoom(1.25)
					accept_event()
				JOY_BUTTON_A:
					select_at(size * 0.5)
					accept_event()
				JOY_BUTTON_X:
					sidebar_focus_requested.emit()
					accept_event()
			return
		if event is InputEventJoypadMotion:
			_gamepad_device = event.device
			accept_event()
			return
		if event.is_action_pressed("ui_accept"):
			select_at(size * 0.5)
			accept_event()
			return
		if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == InputEvent.DEVICE_ID_EMULATION and Time.get_ticks_msec() - _last_touch_time < 800:
			accept_event()
			return
		if event is InputEventMouseButton:
			var mb: InputEventMouseButton = event
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
				adjust_zoom(1.18)
				accept_event()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
				adjust_zoom(1.0 / 1.18)
				accept_event()
			elif mb.button_index == MOUSE_BUTTON_MIDDLE:
				dragging = mb.pressed
				accept_event()
			elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
				var w_xz := _canvas_to_world(mb.position)
				if has_waypoint and _world_to_canvas(waypoint_pos.x, waypoint_pos.z).distance_to(mb.position) < 16.0:
					waypoint_cleared.emit()
				else:
					waypoint_set.emit(w_xz)
				accept_event()
			elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				var hit := _find_node_at(mb.position)
				if not hit.is_empty():
					selected_node = hit
					selection_changed.emit(hit)
					if mb.double_click and bool(hit.get("can_travel", false)):
						fast_travel_requested.emit(str(hit["id"]), hit["pos"], str(hit["name"]))
					queue_redraw()
				else:
					var w_xz := _canvas_to_world(mb.position)
					if has_waypoint and _world_to_canvas(waypoint_pos.x, waypoint_pos.z).distance_to(mb.position) < 16.0:
						waypoint_cleared.emit()
					else:
						waypoint_set.emit(w_xz)
						var est_y := minf(-2.5, Ocean.floor_height(w_xz.x, w_xz.y) + 6.0)
						selected_node = {
							"id": "custom_waypoint",
							"kind": "waypoint",
							"name": "自定义导航标点",
							"desc": "已在海图标记目标航点，水下 HUD 与罗盘将实时指引航向",
							"pos": Vector3(w_xz.x, est_y, w_xz.y),
							"can_travel": false
						}
						selection_changed.emit(selected_node)
				accept_event()
		elif event is InputEventMouseMotion:
			var mm: InputEventMouseMotion = event
			if dragging or (mm.button_mask & MOUSE_BUTTON_MASK_MIDDLE) != 0:
				var world_per_px := (WORLD_SPAN / zoom) / maxf(size.x, 1.0)
				pan_world -= mm.relative * world_per_px
				_clamp_pan()
				queue_redraw()
			else:
				var hov := _find_node_at(mm.position)
				if hov.get("id", "") != hovered_node.get("id", ""):
					hovered_node = hov
					queue_redraw()

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		draw_rect(rect, Color(INK.r, INK.g, INK.b, 0.98), true)

		if bathy_tex != null:
			var half_vis := WORLD_HALF / zoom
			var u0 := clampf((pan_world.x - half_vis + WORLD_HALF) / WORLD_SPAN, 0.0, 1.0)
			var v0 := clampf((pan_world.y - half_vis + WORLD_HALF) / WORLD_SPAN, 0.0, 1.0)
			var u1 := clampf((pan_world.x + half_vis + WORLD_HALF) / WORLD_SPAN, 0.0, 1.0)
			var v1 := clampf((pan_world.y + half_vis + WORLD_HALF) / WORLD_SPAN, 0.0, 1.0)
			var tw := float(bathy_tex.get_width())
			var th := float(bathy_tex.get_height())
			var src := Rect2(u0 * tw, v0 * th, maxf(1.0, (u1 - u0) * tw), maxf(1.0, (v1 - v0) * th))
			draw_texture_rect_region(bathy_tex, rect, src)

		# 2. Fog of War (24 x 24 survey sectors)
		var cell_span := WORLD_SPAN / float(SURVEY_GRID)
		var f_half_vis := WORLD_HALF / zoom
		var f_wx0 := clampf(pan_world.x - f_half_vis, -WORLD_HALF, WORLD_HALF)
		var f_wz0 := clampf(pan_world.y - f_half_vis, -WORLD_HALF, WORLD_HALF)
		var f_wx1 := clampf(pan_world.x + f_half_vis, -WORLD_HALF, WORLD_HALF)
		var f_wz1 := clampf(pan_world.y + f_half_vis, -WORLD_HALF, WORLD_HALF)
		if f_wx1 > f_wx0 and f_wz1 > f_wz0:
			var f_tex := fog_overlay.get_texture(surveyed_cells)
			var f_p0 := _world_to_canvas(f_wx0, f_wz0)
			var f_p1 := _world_to_canvas(f_wx1, f_wz1)
			var f_src := Rect2(
				(f_wx0 + WORLD_HALF) / WORLD_SPAN * float(SURVEY_GRID),
				(f_wz0 + WORLD_HALF) / WORLD_SPAN * float(SURVEY_GRID),
				maxf(0.001, (f_wx1 - f_wx0) / WORLD_SPAN * float(SURVEY_GRID)),
				maxf(0.001, (f_wz1 - f_wz0) / WORLD_SPAN * float(SURVEY_GRID))
			)
			draw_texture_rect_region(f_tex, Rect2(f_p0, f_p1 - f_p0), f_src)

		var font: Font = get_theme_default_font()
		var compact_chart := minf(size.x, size.y) < 300.0
		for g in range(-900, 901, 225):
			var gp := _world_to_canvas(float(g), float(g))
			var col := Color(CYAN, 0.22 if g == 0 else 0.09)
			draw_line(Vector2(gp.x, 0), Vector2(gp.x, size.y), col, 1.0)
			draw_line(Vector2(0, gp.y), Vector2(size.x, gp.y), col, 1.0)
			if font and g != -900 and g != 900 and (not compact_chart or g % 450 == 0):
				draw_string(font, Vector2(gp.x + 3.0, 13.0), "%+dm" % g, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(MUTED, 0.58))

		if font:
			var anchor_pts: Array[Vector2] = [_world_to_canvas(Ocean.HOME.x, Ocean.HOME.z)]
			for out in outposts:
				var op: Vector3 = out["pos"]
				anchor_pts.append(_world_to_canvas(op.x, op.z))
			for reg in REGION_LABELS:
				var rpos: Vector2 = reg["pos"]
				var rgx := clampi(floori((rpos.x + WORLD_HALF) / cell_span), 0, SURVEY_GRID - 1)
				var rgz := clampi(floori((rpos.y + WORLD_HALF) / cell_span), 0, SURVEY_GRID - 1)
				var seen := surveyed_cells.has("%d_%d" % [rgx, rgz])
				var cp := _world_to_canvas(rpos.x, rpos.y)
				if not rect.has_point(cp):
					continue
				if not seen:
					var label_rect := Rect2(cp - Vector2(46.0, 16.0), Vector2(92.0, 26.0))
					var crowded := false
					for ap in anchor_pts:
						if Rect2(ap - Vector2(16.0, 18.0), Vector2(142.0, 36.0)).intersects(label_rect):
							crowded = true
							break
					if crowded:
						continue
				var rcol := Color(PAPER, 0.76) if seen else Color(MUTED, 0.26)
				var rtxt := str(reg["name"]) if seen else "未勘测海域"
				draw_string(font, cp - Vector2(42, 0), rtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, rcol)

		for rel in relics:
			var rpos: Vector3 = rel["pos"]
			var collected: bool = bool(rel.get("collected", false))
			var rid: String = str(rel.get("id", ""))
			if not collected and not pinged_targets.has(rid):
				continue
			var cp := _world_to_canvas(rpos.x, rpos.z)
			if rect.has_point(cp):
				var rcol := Color(MUTED, 0.45) if collected else DANGER
				draw_circle(cp, 4.0, rcol)
				if not collected:
					draw_arc(cp, 6.8, 0.0, TAU, 20, Color(DANGER, 0.36), 1.0)

		var nodes := _collect_interactive_nodes()
		for item in nodes:
			var p3: Vector3 = item["pos"]
			var cp := _world_to_canvas(p3.x, p3.z)
			if not rect.has_point(cp):
				continue
			var kind := str(item["kind"])
			var is_sel: bool = str(selected_node.get("id", "")) == str(item.get("id", ""))
			var is_hov: bool = str(hovered_node.get("id", "")) == str(item.get("id", ""))
			if is_sel or is_hov:
				draw_arc(cp, 11.5, 0.0, TAU, 24, AMBER if is_sel else PAPER, 1.6)
			match kind:
				"home":
					draw_circle(cp, 6.0, HARBOR_SAGE)
					draw_arc(cp, 8.8, 0.0, TAU, 20, Color(HARBOR_SAGE, 0.78), 1.3)
					if font:
						draw_string(font, cp + Vector2(9, 4), "⌂ 逃生舱母港", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, PAPER)
				"outpost":
					var unlocked := bool(item["can_travel"])
					var ocol := HARBOR_SAGE if unlocked else AMBER
					draw_rect(Rect2(cp - Vector2(5.0, 5.0), Vector2(10, 10)), ocol, true)
					draw_rect(Rect2(cp - Vector2(7.5, 7.5), Vector2(15, 15)), Color(AMBER if not unlocked else ocol, 0.55), false, 1.1)
					if font:
						draw_string(font, cp + Vector2(9, 4), str(item["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, PAPER if unlocked else AMBER)
				"submarine":
					var tri := PackedVector2Array([cp + Vector2(0, -5.5), cp + Vector2(5.2, 4.5), cp + Vector2(-5.2, 4.5)])
					draw_colored_polygon(tri, PAPER)
					draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), CYAN, 1.1)
				"landmark":
					var is_disc := bool(item["can_travel"])
					var is_hazard := BOSS_LANDMARK_IDS.has(str(item.get("raw_id", "")))
					var lcol := (DANGER if is_hazard else CYAN) if is_disc else AMBER
					draw_circle(cp, 4.5 if is_disc else 3.8, lcol)
					if font and (is_hov or is_sel or zoom >= 1.45):
						var lbl_col := DANGER.lightened(0.14) if (is_disc and is_hazard) else (PAPER if is_disc else AMBER)
						draw_string(font, cp + Vector2(7, 4), str(item["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, lbl_col)

		var player_cp := _world_to_canvas(player_pos.x, player_pos.z)
		if has_waypoint:
			var wp_cp := _world_to_canvas(waypoint_pos.x, waypoint_pos.z)
			draw_line(player_cp, wp_cp, Color(AMBER, 0.62), 1.4)
			var dia := PackedVector2Array([wp_cp + Vector2(0, -7), wp_cp + Vector2(7, 0), wp_cp + Vector2(0, 7), wp_cp + Vector2(-7, 0)])
			draw_colored_polygon(dia, AMBER)
			if font:
				var dist_m := roundi(Vector2(player_pos.x, player_pos.z).distance_to(Vector2(waypoint_pos.x, waypoint_pos.z)))
				draw_string(font, wp_cp + Vector2(9, 4), "✦ 标点 (%dm)" % dist_m, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, AMBER)

		if rect.has_point(player_cp):
			var dir2 := Vector2(sin(heading_yaw), -cos(heading_yaw))
			var side2 := Vector2(-dir2.y, dir2.x)
			var cone := PackedVector2Array([
				player_cp,
				player_cp + (dir2 * 26.0 + side2 * 14.0),
				player_cp + (dir2 * 26.0 - side2 * 14.0)
			])
			draw_colored_polygon(cone, Color(CYAN, 0.16))
			var p_chev := PackedVector2Array([
				player_cp + dir2 * 8.5,
				player_cp - dir2 * 5.5 + side2 * 5.5,
				player_cp - dir2 * 2.5,
				player_cp - dir2 * 5.5 - side2 * 5.5
			])
			draw_colored_polygon(p_chev, PAPER)
			draw_polyline(PackedVector2Array([p_chev[0], p_chev[1], p_chev[2], p_chev[3], p_chev[0]]), CYAN, 1.4)

		draw_rect(rect, Color(CYAN, 0.30), false, 1.5)
		if has_focus():
			var center := size * 0.5
			draw_line(center - Vector2(13, 0), center + Vector2(13, 0), PAPER, 1.5)
			draw_line(center - Vector2(0, 13), center + Vector2(0, 13), PAPER, 1.5)
			draw_circle(center, 19.0, Color(CYAN, 0.7), false, 1.0)
			draw_rect(rect.grow(-2.0), Color(CYAN, 0.8), false, 3.0)
