extends RefCounted

const Ocean = preload("res://scripts/ocean.gd")
const OceanDepths = preload("res://scripts/ocean_depths.gd")

const WORLD_HALF := 900.0
const WORLD_SPAN := 1800.0
const SURVEY_GRID := 24

const CYAN := Color("38f6e8")
const INK := Color("f4fcff")
const MUTED := Color("9ce0f4")
const AMBER := Color("ffbe42")
const ORANGE := Color("ff9e38")
const EMERALD := Color("4dffb8")
const MAGENTA := Color("ff6ad5")

const REGION_LABELS := [
	{"name": "北境晴空环礁", "pos": Vector2(40, 380), "sub": "SUNLIT ATOLL"},
	{"name": "翡翠巨藻海峡", "pos": Vector2(-310, 310), "sub": "KELP STRAIT"},
	{"name": "极光晶洞海岭", "pos": Vector2(410, 320), "sub": "AURORA RIDGE"},
	{"name": "核心蓝洞海域", "pos": Vector2(0, -40), "sub": "CENTRAL BLUE HOLE"},
	{"name": "东海星象古都", "pos": Vector2(510, -60), "sub": "SUNKEN CITADEL"},
	{"name": "西洋龙骨荒原", "pos": Vector2(-520, -90), "sub": "LEVIATHAN WASTES"},
	{"name": "黑曜石火山口", "pos": Vector2(-460, -450), "sub": "OBSIDIAN CALDERA"},
	{"name": "沉船幽灵浅滩", "pos": Vector2(450, -410), "sub": "GHOST FLEET"},
	{"name": "极渊星辉圣域", "pos": Vector2(60, -670), "sub": "HADAL SANCTUM"}
]

static func _bathymetry_color(depth: float, world_x: float, world_z: float) -> Color:
	var c_surface := Color(0.10, 0.58, 0.60)
	var c_reef := Color(0.07, 0.43, 0.52)
	var c_shelf := Color(0.045, 0.29, 0.44)
	var c_twilight := Color(0.035, 0.18, 0.34)
	var c_bathyal := Color(0.026, 0.103, 0.235)
	var c_hadal := Color(0.014, 0.042, 0.13)
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
	# Subtle volcanic warmth near caldera & vents
	var caldera_d := Vector2(world_x - (-440.0), world_z - (-420.0)).length()
	if caldera_d < 170.0:
		base = base.lerp(Color(0.24, 0.09, 0.08), (1.0 - caldera_d / 170.0) * 0.42)
	# Fixed 50m contours read consistently across all five depth zones. Feather
	# their edges so the chart remains continuous when crossing a depth boundary.
	var phase := fposmod(chart_depth, 50.0)
	var contour_distance := minf(phase, 50.0 - phase)
	var contour_strength := 1.0 - smoothstep(0.0, 0.9, contour_distance)
	base = base.lightened(contour_strength * 0.075)
	return base

static func build_bathymetry_texture(resolution: int = 128) -> ImageTexture:
	var img := Image.create(resolution, resolution, false, Image.FORMAT_RGBA8)
	for py in range(resolution):
		var wz := lerpf(-WORLD_HALF, WORLD_HALF, (float(py) + 0.5) / float(resolution))
		for px in range(resolution):
			var wx := lerpf(-WORLD_HALF, WORLD_HALF, (float(px) + 0.5) / float(resolution))
			var d := maxf(0.0, -Ocean.floor_height(wx, wz))
			img.set_pixel(px, py, _bathymetry_color(d, wx, wz))
	return ImageTexture.create_from_image(img)


class CompassStrip extends Control:
	var heading_yaw: float = 0.0
	var player_pos: Vector3 = Vector3.ZERO
	var home_pos: Vector3 = Ocean.HOME
	var has_waypoint: bool = false
	var waypoint_pos: Vector3 = Vector3.ZERO
	var nearest_outpost_pos: Vector3 = Vector3.ZERO
	var has_nearest_outpost: bool = false

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
		draw_rect(bg_rect, Color(0.02, 0.09, 0.16, 0.72), true)
		draw_rect(bg_rect, Color(0.22, 0.85, 0.96, 0.35), false, 1.0)
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
			draw_line(Vector2(x, h - tick_h), Vector2(x, h - 1.0), Color(0.55, 0.9, 0.98, 0.45 if not is_card else 0.8), 1.0)

		if font:
			for d in dirs:
				var rad := deg_to_rad(float(d["deg"]))
				var diff := _angle_diff(rad, heading_yaw)
				if absf(diff) > half_fov:
					continue
				var x := cx + (diff / half_fov) * (w * 0.46)
				var col: Color = CYAN if bool(d["major"]) else MUTED
				if int(d["deg"]) == 0:
					col = AMBER
				var txt: String = str(d["txt"])
				var fsz: int = 12 if bool(d["major"]) else 10
				draw_string(font, Vector2(x - float(txt.length()) * 3.8, 15.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fsz, col)

			# Draw POI pips (Home, Outpost, Custom Waypoint)
			_draw_pip(font, _bearing_to(home_pos), "⌂", EMERALD, half_fov, cx, w)
			if has_nearest_outpost:
				_draw_pip(font, _bearing_to(nearest_outpost_pos), "⬡", CYAN, half_fov, cx, w)
			if has_waypoint:
				_draw_pip(font, _bearing_to(waypoint_pos), "✦", AMBER, half_fov, cx, w)

		# Center heading indicator triangle
		var tri := PackedVector2Array([Vector2(cx - 4, 1), Vector2(cx + 4, 1), Vector2(cx, 6)])
		draw_colored_polygon(tri, CYAN)

	func _draw_pip(font: Font, bearing: float, icon: String, col: Color, half_fov: float, cx: float, w: float) -> void:
		var diff := clampf(_angle_diff(bearing, heading_yaw), -half_fov, half_fov)
		var x := cx + (diff / half_fov) * (w * 0.45)
		draw_string(font, Vector2(x - 5.0, 23.0), icon, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)


class MinimapRadar extends Control:
	var bathy_tex: ImageTexture
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

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

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
		var map_side := minf(size.x - 12.0, size.y - 28.0)
		var map_rect := Rect2((size.x - map_side) * 0.5, 6.0, map_side, map_side)
		var center := map_rect.get_center()
		var half_r := map_side * 0.5

		draw_rect(Rect2(0, 0, size.x, size.y), Color(0.02, 0.09, 0.17, 0.88), true)
		draw_rect(Rect2(0, 0, size.x, size.y), Color(0.25, 0.90, 1.0, 0.45), false, 1.5)

		# Draw local bathymetry slice
		if bathy_tex != null:
			var u0 := clampf((player_pos.x - radar_range + WORLD_HALF) / WORLD_SPAN, 0.0, 1.0)
			var v0 := clampf((player_pos.z - radar_range + WORLD_HALF) / WORLD_SPAN, 0.0, 1.0)
			var u1 := clampf((player_pos.x + radar_range + WORLD_HALF) / WORLD_SPAN, 0.0, 1.0)
			var v1 := clampf((player_pos.z + radar_range + WORLD_HALF) / WORLD_SPAN, 0.0, 1.0)
			var tw := float(bathy_tex.get_width())
			var th := float(bathy_tex.get_height())
			var src := Rect2(u0 * tw, v0 * th, maxf(1.0, (u1 - u0) * tw), maxf(1.0, (v1 - v0) * th))
			draw_texture_rect_region(bathy_tex, map_rect, src, Color(1, 1, 1, 0.92))
		else:
			draw_rect(map_rect, Color(0.02, 0.14, 0.24, 0.95), true)

		# Fog of war cells in radar window
		var cell_span := WORLD_SPAN / float(SURVEY_GRID)
		var gx_min := maxi(0, floori((player_pos.x - radar_range + WORLD_HALF) / cell_span))
		var gx_max := mini(SURVEY_GRID - 1, floori((player_pos.x + radar_range + WORLD_HALF) / cell_span))
		var gz_min := maxi(0, floori((player_pos.z - radar_range + WORLD_HALF) / cell_span))
		var gz_max := mini(SURVEY_GRID - 1, floori((player_pos.z + radar_range + WORLD_HALF) / cell_span))
		for gz in range(gz_min, gz_max + 1):
			for gx in range(gx_min, gx_max + 1):
				var key := "%d_%d" % [gx, gz]
				if surveyed_cells.has(key):
					continue
				var wx0 := -WORLD_HALF + float(gx) * cell_span
				var wz0 := -WORLD_HALF + float(gz) * cell_span
				var p0 := _world_to_radar(wx0, wz0, center, half_r)
				var p1 := _world_to_radar(wx0 + cell_span, wz0 + cell_span, center, half_r)
				var clipped := Rect2(p0, p1 - p0).intersection(map_rect)
				if clipped.size.x > 0.1 and clipped.size.y > 0.1:
					draw_rect(clipped, Color(0.01, 0.05, 0.09, 0.80), true)

		# Sonar rings & crosshairs
		draw_arc(center, half_r * 0.45, 0.0, TAU, 36, Color(0.25, 0.9, 1.0, 0.16), 1.0)
		draw_arc(center, half_r * 0.85, 0.0, TAU, 48, Color(0.25, 0.9, 1.0, 0.22), 1.0)
		draw_line(Vector2(map_rect.position.x, center.y), Vector2(map_rect.end.x, center.y), Color(0.25, 0.9, 1.0, 0.12), 1.0)
		draw_line(Vector2(center.x, map_rect.position.y), Vector2(center.x, map_rect.end.y), Color(0.25, 0.9, 1.0, 0.12), 1.0)

		# Rotating sonar sweep line
		var sweep_ang := fmod(pulse_clock * 1.35, TAU)
		var sweep_end := center + Vector2(sin(sweep_ang), -cos(sweep_ang)) * (half_r * 0.92)
		draw_line(center, sweep_end, Color(0.25, 1.0, 0.88, 0.28), 1.2)

		# Landmarks
		for lm_id in landmarks:
			var lm: Dictionary = landmarks[lm_id]
			var lpos: Vector3 = lm["pos"]
			var is_disc: bool = discovered_landmarks.has(lm_id)
			var is_pinged: bool = pinged_targets.has("lm_" + str(lm_id))
			if not is_disc and not is_pinged:
				continue
			var rp := _world_to_radar(lpos.x, lpos.z, center, half_r)
			if map_rect.has_point(rp):
				draw_circle(rp, 2.8 if is_disc else 2.4, CYAN if is_disc else Color(1.0, 0.78, 0.25, 0.85))

		# Outposts
		for out in outposts:
			var opos: Vector3 = out["pos"]
			var oid: String = str(out["id"])
			var unlocked: bool = unlocked_outposts.has(oid)
			var rp := _world_to_radar(opos.x, opos.z, center, half_r)
			if map_rect.has_point(rp):
				var c := EMERALD if unlocked else AMBER
				draw_rect(Rect2(rp - Vector2(3.2, 3.2), Vector2(6.4, 6.4)), c, true)

		# Pinged / nearby relics
		for rel in relics:
			if bool(rel.get("collected", false)):
				continue
			var rid: String = str(rel.get("id", ""))
			var rpos: Vector3 = rel["pos"]
			if not pinged_targets.has(rid) and rpos.distance_to(player_pos) > 85.0:
				continue
			var rp := _world_to_radar(rpos.x, rpos.z, center, half_r)
			if map_rect.has_point(rp):
				draw_circle(rp, 2.6, MAGENTA)

		# Submarines
		for sub in submarines:
			var spos: Vector3 = sub["pos"]
			var rp := _world_to_radar(spos.x, spos.z, center, half_r)
			if map_rect.has_point(rp):
				draw_circle(rp, 3.2, Color(0.4, 0.95, 1.0))

		# Lifepod Home (clamped to radar edge if far)
		var hp := _world_to_radar(Ocean.HOME.x, Ocean.HOME.z, center, half_r)
		hp.x = clampf(hp.x, map_rect.position.x + 4.0, map_rect.end.x - 4.0)
		hp.y = clampf(hp.y, map_rect.position.y + 4.0, map_rect.end.y - 4.0)
		draw_circle(hp, 3.6, EMERALD)

		# Custom Waypoint (with dashed line + clamped edge diamond)
		if has_waypoint:
			var wp := _world_to_radar(waypoint_pos.x, waypoint_pos.z, center, half_r)
			wp.x = clampf(wp.x, map_rect.position.x + 5.0, map_rect.end.x - 5.0)
			wp.y = clampf(wp.y, map_rect.position.y + 5.0, map_rect.end.y - 5.0)
			draw_line(center, wp, Color(1.0, 0.78, 0.25, 0.45), 1.2)
			var dia := PackedVector2Array([wp + Vector2(0, -4.5), wp + Vector2(4.5, 0), wp + Vector2(0, 4.5), wp + Vector2(-4.5, 0)])
			draw_colored_polygon(dia, AMBER)

		# Player directional chevron at center
		var dir2 := Vector2(sin(heading_yaw), -cos(heading_yaw))
		var side2 := Vector2(-dir2.y, dir2.x)
		var chev := PackedVector2Array([
			center + dir2 * 6.5,
			center - dir2 * 4.5 + side2 * 4.2,
			center - dir2 * 2.0,
			center - dir2 * 4.5 - side2 * 4.2
		])
		draw_colored_polygon(chev, INK)
		draw_rect(map_rect, Color(0.28, 0.92, 1.0, 0.42), false, 1.0)

		var font: Font = get_theme_default_font()
		if font:
			var coord_txt := "X:%+d  Z:%+d  [M海图]" % [roundi(player_pos.x), roundi(player_pos.z)]
			draw_string(font, Vector2(8.0, size.y - 6.0), coord_txt, HORIZONTAL_ALIGNMENT_LEFT, size.x - 12.0, 11, CYAN)


class SeaChartCanvas extends Control:
	signal waypoint_set(world_xz: Vector2)
	signal waypoint_cleared
	signal fast_travel_requested(target_id: String, world_pos: Vector3, target_name: String)
	signal selection_changed(info: Dictionary)

	var bathy_tex: ImageTexture
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

	func _ready() -> void:
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_STOP

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
		var best_d := 16.0
		for item in _collect_interactive_nodes():
			var p3: Vector3 = item["pos"]
			var cp := _world_to_canvas(p3.x, p3.z)
			var d := cp.distance_to(pt)
			if d <= best_d:
				best_d = d
				best = item
		return best

	func _gui_input(event: InputEvent) -> void:
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
		draw_rect(rect, Color(0.015, 0.07, 0.13, 0.98), true)

		# 1. Bathymetric background
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
		for gz in range(SURVEY_GRID):
			for gx in range(SURVEY_GRID):
				var key := "%d_%d" % [gx, gz]
				if surveyed_cells.has(key):
					continue
				var wx0 := -WORLD_HALF + float(gx) * cell_span
				var wz0 := -WORLD_HALF + float(gz) * cell_span
				var p0 := _world_to_canvas(wx0, wz0)
				var p1 := _world_to_canvas(wx0 + cell_span, wz0 + cell_span)
				var crect := Rect2(p0, p1 - p0).intersection(rect)
				if crect.size.x > 0.2 and crect.size.y > 0.2:
					draw_rect(crect, Color(0.012, 0.045, 0.085, 0.84), true)

		# 3. Coordinate nautical grid every 225m
		var font: Font = get_theme_default_font()
		for g in range(-900, 901, 225):
			var gp := _world_to_canvas(float(g), float(g))
			var col := Color(0.28, 0.88, 1.0, 0.22 if g == 0 else 0.09)
			draw_line(Vector2(gp.x, 0), Vector2(gp.x, size.y), col, 1.0)
			draw_line(Vector2(0, gp.y), Vector2(size.x, gp.y), col, 1.0)
			if font and g != -900 and g != 900:
				draw_string(font, Vector2(gp.x + 3.0, 13.0), "%+dm" % g, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.6, 0.88, 0.96, 0.45))

		# 4. Region titles in surveyed zones
		if font:
			for reg in REGION_LABELS:
				var rpos: Vector2 = reg["pos"]
				var rgx := clampi(floori((rpos.x + WORLD_HALF) / cell_span), 0, SURVEY_GRID - 1)
				var rgz := clampi(floori((rpos.y + WORLD_HALF) / cell_span), 0, SURVEY_GRID - 1)
				var seen := surveyed_cells.has("%d_%d" % [rgx, rgz])
				var cp := _world_to_canvas(rpos.x, rpos.y)
				if not rect.has_point(cp):
					continue
				var rcol := Color(0.72, 0.96, 1.0, 0.62 if seen else 0.20)
				var rtxt := str(reg["name"]) if seen else "未勘测海域"
				draw_string(font, cp - Vector2(42, 0), rtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, rcol)

		# 5. Relics (pinged or collected)
		for rel in relics:
			var rpos: Vector3 = rel["pos"]
			var collected: bool = bool(rel.get("collected", false))
			var rid: String = str(rel.get("id", ""))
			if not collected and not pinged_targets.has(rid):
				continue
			var cp := _world_to_canvas(rpos.x, rpos.z)
			if rect.has_point(cp):
				var rcol := Color(0.55, 0.75, 0.8, 0.45) if collected else MAGENTA
				draw_circle(cp, 4.0, rcol)

		# 6. Interactive POIs (Landmarks, Outposts, Submarines, Home)
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
				draw_arc(cp, 11.5, 0.0, TAU, 24, AMBER if is_sel else INK, 1.8)
			match kind:
				"home":
					draw_circle(cp, 6.5, EMERALD)
					draw_arc(cp, 9.0, 0.0, TAU, 20, EMERALD, 1.4)
					if font:
						draw_string(font, cp + Vector2(9, 4), "⌂ 逃生舱母港", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, EMERALD)
				"outpost":
					var unlocked := bool(item["can_travel"])
					var ocol := EMERALD if unlocked else AMBER
					draw_rect(Rect2(cp - Vector2(5.5, 5.5), Vector2(11, 11)), ocol, true)
					draw_rect(Rect2(cp - Vector2(8.0, 8.0), Vector2(16, 16)), Color(ocol.r, ocol.g, ocol.b, 0.55), false, 1.2)
					if font:
						draw_string(font, cp + Vector2(9, 4), str(item["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ocol)
				"submarine":
					var tri := PackedVector2Array([cp + Vector2(0, -5.5), cp + Vector2(5.2, 4.5), cp + Vector2(-5.2, 4.5)])
					draw_colored_polygon(tri, CYAN)
				"landmark":
					var is_disc := bool(item["can_travel"])
					var lcol := CYAN if is_disc else AMBER
					draw_circle(cp, 4.5 if is_disc else 3.8, lcol)
					if font and (is_hov or is_sel or zoom >= 1.45):
						draw_string(font, cp + Vector2(7, 4), str(item["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, lcol)

		# 7. Custom Waypoint & Navigation Line
		var player_cp := _world_to_canvas(player_pos.x, player_pos.z)
		if has_waypoint:
			var wp_cp := _world_to_canvas(waypoint_pos.x, waypoint_pos.z)
			draw_line(player_cp, wp_cp, Color(1.0, 0.78, 0.25, 0.65), 1.6)
			var dia := PackedVector2Array([wp_cp + Vector2(0, -7), wp_cp + Vector2(7, 0), wp_cp + Vector2(0, 7), wp_cp + Vector2(-7, 0)])
			draw_colored_polygon(dia, AMBER)
			if font:
				var dist_m := roundi(Vector2(player_pos.x, player_pos.z).distance_to(Vector2(waypoint_pos.x, waypoint_pos.z)))
				draw_string(font, wp_cp + Vector2(9, 4), "✦ 标点 (%dm)" % dist_m, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, AMBER)

		# 8. Player live position & heading cone
		if rect.has_point(player_cp):
			var dir2 := Vector2(sin(heading_yaw), -cos(heading_yaw))
			var side2 := Vector2(-dir2.y, dir2.x)
			var cone := PackedVector2Array([
				player_cp,
				player_cp + (dir2 * 26.0 + side2 * 14.0),
				player_cp + (dir2 * 26.0 - side2 * 14.0)
			])
			draw_colored_polygon(cone, Color(0.25, 0.95, 1.0, 0.18))
			var p_chev := PackedVector2Array([
				player_cp + dir2 * 8.5,
				player_cp - dir2 * 5.5 + side2 * 5.5,
				player_cp - dir2 * 2.5,
				player_cp - dir2 * 5.5 - side2 * 5.5
			])
			draw_colored_polygon(p_chev, INK)
			draw_polyline(PackedVector2Array([p_chev[0], p_chev[1], p_chev[2], p_chev[3], p_chev[0]]), CYAN, 1.4)

		draw_rect(rect, Color(0.28, 0.92, 1.0, 0.55), false, 2.0)
