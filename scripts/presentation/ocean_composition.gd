extends Node3D
## Authored silhouettes and swimming corridors; all repeated artwork is batched.
## World coordinates, interaction anchors and the original seabed remain authoritative.
const Art = preload("res://scripts/art_direction.gd")
const Scenery = preload("res://shaders/scenery.gdshader")
const Ribbon = preload("res://shaders/fish_ribbon.gdshader")
var ocean: Node3D
var _batches: Dictionary = {}
var _assets: Dictionary = {}
var _materials: Dictionary = {}
var _rib_meshes: Dictionary = {}
var _arch_meshes: Dictionary = {}
var _pillar_meshes: Dictionary = {}
var _terrace_mesh: ArrayMesh
var _spire_mesh: ArrayMesh
var _sun_compass_mesh: ArrayMesh
var _cube := BoxMesh.new()
var _column := CylinderMesh.new()
var _reserved: Array[Vector2] = []
var _seed := RandomNumberGenerator.new()

func configure(world: Node3D) -> void:
	ocean = world
	name = "OceanComposition"
	_seed.seed = 671112
	_terrace_mesh = _make_terrace()
	_spire_mesh = _make_spire()
	_sun_compass_mesh = _make_sun_compass_emblem()
	_column.top_radius = 0.92
	_column.bottom_radius = 1.0
	_column.height = 1.0
	_column.radial_segments = 20
	for spec: Dictionary in ocean.OUTPOST_SPECS:
		_reserved.append(spec["xz"])
	for spec: Dictionary in ocean.RELIC_SPECS:
		_reserved.append(spec["xz"])
	_reserved.append(Vector2(ocean.HOME.x, ocean.HOME.z))
	for landmark: Vector2 in [Vector2(2, -25), Vector2(-50, -170), Vector2(15, -165), Vector2(-15, -180), Vector2(32, -152), Vector2(-2, -195), Vector2(45, -55), Vector2(95, -30), Vector2(-110, -185), Vector2(-85, -50)]:
		_reserved.append(landmark)
	_core()
	_atoll()
	_kelp()
	_ridge()
	_citadel()
	_wreck()
	_bones()
	_caldera()
	_hadal()
	_flush()
	set_meta("regions", Art.REGIONS.keys())

func _height(xz: Vector2) -> float:
	return ocean.terrain_height(xz.x, xz.y)

func _clear(xz: Vector2, radius: float) -> bool:
	for point in _reserved:
		if point.distance_to(xz) < radius + 6.0:
			return false
	return true

func _material(region: String, role: String = "rock") -> ShaderMaterial:
	var key := region + role
	if not _materials.has(key):
		var profile := Art.region_profile(region)
		var material := ShaderMaterial.new()
		material.shader = Scenery
		var glow := role == "glow"
		var pigment: Color = profile["rock"]
		var top_pigment: Color = profile["sand"].lerp(pigment, 0.36)
		var glow_strength := 0.0
		if role == "stone":
			var warm_limestone := Color("dcd2b6") if region in ["core", "atoll", "kelp", "citadel"] else Color("b6bcb0")
			pigment = profile["rock"].lerp(warm_limestone, 0.62)
			top_pigment = warm_limestone.lightened(0.10).lerp(profile["sand"], 0.28)
		elif role == "bone":
			pigment = profile["accent"].lerp(profile["rock"], 0.16)
			top_pigment = profile["accent"].lightened(0.10)
			glow_strength = 0.05
		elif role == "sand":
			pigment = profile["sand"].darkened(0.12)
			top_pigment = profile["sand"]
		elif glow or role == "accent":
			var gilded := Color("d8ab4e")
			pigment = profile["accent"] if glow else gilded.lerp(profile["accent"], 0.24)
			top_pigment = pigment.lightened(0.24)
			glow_strength = 0.65 if glow else 0.20
		material.set_shader_parameter("pigment", pigment)
		material.set_shader_parameter("top_pigment", top_pigment)
		material.set_shader_parameter("shadow_pigment", profile["shadow"])
		material.set_shader_parameter("glow_strength", glow_strength)
		_materials[key] = material
	return _materials[key]

func _record(key: String, mesh: Mesh, material: Material, at: Vector3, scale_value: Vector3, yaw: float = 0.0, tint: Color = Color.WHITE, solid: bool = false) -> void:
	if not _batches.has(key):
		_batches[key] = {"mesh": mesh, "material": material, "transforms": [], "colors": []}
	var transform_value := Transform3D(Basis(Vector3.UP, yaw).scaled_local(scale_value), at)
	_batches[key].transforms.append(transform_value)
	_batches[key].colors.append(tint)
	if solid:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		shape.shape = mesh.create_convex_shape(true, true)
		body.transform = transform_value
		body.add_child(shape)
		add_child(body)

func _rock(xz: Vector2, dimensions: Vector3, region: String, yaw: float = 0.0, spire: bool = false) -> float:
	if not _clear(xz, maxf(dimensions.x, dimensions.z)):
		return _height(xz)
	var height := minf(dimensions.y, -_height(xz) - 1.2)
	var top := _height(xz) + maxf(height, 0.8) - 0.75
	var bottom := _height(xz) - 0.75
	for i in range(9):
		var angle := float(i) / 9.0 * TAU + yaw
		var support := xz + Vector2(cos(angle) * dimensions.x, sin(angle) * dimensions.z) * 0.90
		bottom = minf(bottom, _height(support) - 0.6)
	var at := Vector3(xz.x, bottom, xz.y)
	var scale_value := Vector3(dimensions.x, top - bottom, dimensions.z)
	var mesh_ref := _spire_mesh if spire else _terrace_mesh
	var suffix := "_spires" if spire else "_mesas"
	_record(region + suffix, mesh_ref, _material(region), at, scale_value, yaw, Color.WHITE, true)
	return at.y + scale_value.y

func _asset(asset: String, at: Vector3, scale_value: Vector3, region: String, yaw: float = 0.0) -> void:
	if not _assets.has(asset):
		var instance: Node3D = load("res://assets/models/" + asset + ".glb").instantiate()
		ocean.apply_plant_shader(instance, 0.22 if asset == "kelp" else 0.07, 0.65, asset)
		var parts: Array = []
		for child: MeshInstance3D in instance.find_children("*", "MeshInstance3D", true, false):
			var local := child.transform
			var parent := child.get_parent()
			while parent != null and parent != instance.get_parent():
				if parent is Node3D:
					local = parent.transform * local
				parent = parent.get_parent()
			parts.append({"mesh": child.mesh, "material": child.get_active_material(0), "local": local})
		_assets[asset] = parts
		instance.free()
	var index := 0
	for part: Dictionary in _assets[asset]:
		var key := region + "_" + asset + str(index)
		var tint := Color.WHITE.lerp(Art.region_profile(region).flora, 0.16 if asset == "kelp" else 0.03)
		_record(key, part.mesh, part.material, at, scale_value, yaw, tint)
		# Retain the original GLB mesh-to-root transform, including skinned rest poses.
		_batches[key].transforms[-1] = _batches[key].transforms[-1] * part.local
		index += 1

func _garden(center: Vector2, region: String, size_value: float = 1.0) -> void:
	if not _clear(center, 7.0 * size_value):
		return
	var top := _rock(center, Vector3(6.2, 2.1, 5.2) * size_value, region, _seed.randf() * TAU, false)
	var species := ["table_coral", "staghorn_coral", "brain_coral"] if region in ["core", "atoll"] else ["sea_fan", "barrel_sponge", "sea_lily"]
	for i in range(5):
		var angle := float(i) * 2.4
		var xz := center + Vector2(cos(angle), sin(angle)) * size_value * 1.8
		var asset: String = species[i % 3]
		_asset(asset, Vector3(xz.x, top - 0.05, xz.y), Vector3.ONE * size_value * (0.62 if i > 1 else 1.0), region, angle)
	var rim_xz := center + Vector2(size_value * 2.1, -size_value * 1.2)
	_asset("starfish_urchin", Vector3(rim_xz.x, top - 0.06, rim_xz.y), Vector3.ONE * size_value * 0.72, region, size_value * 1.7)

func _arch(center: Vector2, width: float, requested_height: float, yaw: float, region: String, variation: int = 0) -> void:
	var at := Vector3(center.x, _height(center), center.y)
	var height := minf(requested_height, -at.y - 1.2)
	var turn := Basis(Vector3.UP, yaw)
	var thickness := width * 0.095
	var style := posmod(variation, 3)
	if not _arch_meshes.has(style):
		_arch_meshes[style] = _make_arch_band(style)
	var dimensions := Vector3(width, height, thickness)
	_record(region + "_vaults_" + str(style), _arch_meshes[style], _material(region, "stone"), at, dimensions, yaw)
	# The vault is one continuous silhouette, while its collision remains an open
	# chain of convex wedges. A single convex hull here would seal the swimway.
	var sections := _arch_sections(style)
	for index in range(sections.size() - 1):
		var points := PackedVector3Array()
		points.append_array(sections[index])
		points.append_array(sections[index + 1])
		var local_center := Vector3.ZERO
		for point: Vector3 in points:
			local_center += point
		local_center /= float(points.size())
		var shape_points := PackedVector3Array()
		var clearance := 0.0
		for point: Vector3 in points:
			var offset := (point - local_center) * dimensions
			shape_points.append(offset)
			clearance = maxf(clearance, Vector2(offset.x, offset.z).length())
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var wedge := ConvexPolygonShape3D.new()
		wedge.points = shape_points
		collision.shape = wedge
		body.transform = Transform3D(turn, at + turn * (local_center * dimensions))
		body.set_meta("ecology_clearance", clearance + 0.35)
		body.add_child(collision)
		add_child(body)
	# Extend the two buried feet to the real local seabed on sloping terrain.
	for side: float in [-1.0, 1.0]:
		var foot := at + turn * Vector3(side * width * 0.5, 0, 0)
		var bottom := _height(Vector2(foot.x, foot.z)) - 0.65
		if bottom < at.y:
			_record(region + "_footings", _column, _material(region, "stone"), Vector3(foot.x, (bottom + at.y) * 0.5, foot.z), Vector3(width * 0.043, at.y - bottom + 0.2, thickness * 0.43), yaw, Color.WHITE, true)
	# Sculpted gilded astronomical sun-compass wheels at the arch keystone and flanking piers.
	var emblem_role := "glow" if region in ["citadel", "hadal"] else "accent"
	var crown_scale := clampf(width * 0.068, 1.05, 2.35)
	for face_sign: float in [1.0, -1.0]:
		var emblem_at := at + turn * Vector3(0, height * 0.922, face_sign * thickness * 0.62)
		var face_basis := turn * (Basis.IDENTITY if face_sign > 0.0 else Basis(Vector3.UP, PI))
		_record(region + "_emblems", _sun_compass_mesh, _material(region, emblem_role), emblem_at, Vector3.ONE * crown_scale)
		_batches[region + "_emblems"].transforms[-1] = Transform3D(face_basis.scaled_local(Vector3.ONE * crown_scale), emblem_at)
		for pier_side: float in [-1.0, 1.0]:
			var pier_medallion_at := at + turn * Vector3(pier_side * width * 0.50, height * 0.34, face_sign * thickness * 0.58)
			var pier_scale := crown_scale * 0.48
			_record(region + "_emblems", _sun_compass_mesh, _material(region, emblem_role), pier_medallion_at, Vector3.ONE * pier_scale)
			_batches[region + "_emblems"].transforms[-1] = Transform3D(face_basis.scaled_local(Vector3.ONE * pier_scale), pier_medallion_at)
	if not _pillar_meshes.has(false):
		_pillar_meshes[false] = _make_pillar(false)
	for pier_side: float in [-1.0, 1.0]:
		var pier_pos := at + turn * Vector3(pier_side * width * 0.535, -0.35, 0.0)
		_record(region + "_stone_pillars", _pillar_meshes[false], _material(region, "stone"), pier_pos, Vector3(thickness * 0.52, height * 0.68, thickness * 0.56), yaw)

func _pillar(xz: Vector2, height: float, region: String, broken: bool = false) -> void:
	if not _clear(xz, 2.0):
		return
	var y := _height(xz)
	var h := height * (0.57 if broken else 1.0)
	if not _pillar_meshes.has(broken):
		_pillar_meshes[broken] = _make_pillar(broken)
	var yaw := sin(xz.x * 0.17 + xz.y * 0.11) * 0.22
	_record(region + ("_broken_pillars" if broken else "_stone_pillars"), _pillar_meshes[broken], _material(region, "stone"), Vector3(xz.x, y - 0.4, xz.y), Vector3(1.5, h, 1.5), yaw, Color.WHITE, true)
	_record(region + "_caps", _cube, _material(region, "stone"), Vector3(xz.x, y + 0.22, xz.y), Vector3(3.25, 0.58, 2.95), yaw)
	if not broken:
		_record(region + "_caps", _cube, _material(region, "stone"), Vector3(xz.x, y + h - 0.42, xz.y), Vector3(2.85, 0.52, 2.65), yaw)
	var inlay_role := "glow" if region in ["citadel", "hadal"] else "accent"
	_record(region + "_inlays", _column, _material(region, inlay_role), Vector3(xz.x, y + h * 0.77, xz.y), Vector3(1.29, 0.18, 1.29))

func _shoal(center: Vector2, region: String, height: float, radius: float = 15.0, curve_mode: int = 0, stretch: Vector2 = Vector2(1.0, 0.72), yaw: float = 0.0) -> void:
	var batch := MultiMeshInstance3D.new()
	batch.name = region + "_ribbon"
	batch.layers = 3
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _fish_mesh()
	mm.instance_count = 80 if region in ["core", "atoll", "kelp"] else 48
	for i in range(mm.instance_count):
		var scale_value := _seed.randf_range(0.68, 1.18) * (1.22 if i % 13 == 0 else 1.0)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * scale_value), Vector3.ZERO))
		# Two loose shoals leave a moving opening in the silhouette. All motion is
		# continuous: there is no wrap/teleport at an artificial path end.
		var phase := float(i) / float(mm.instance_count) * 0.72 + (0.10 if i >= mm.instance_count / 2 else 0.0)
		mm.set_instance_custom_data(i, Color(phase, _seed.randf(), _seed.randf(), _seed.randf()))
	# Shader displacement is in mesh space, hence the largest individual scale
	# must also expand the complete animated path envelope before culling.
	var reach := (radius * maxf(stretch.x, stretch.y) * 1.20 + 6.0) * 1.5
	mm.custom_aabb = AABB(Vector3(-reach, -8.0, -reach), Vector3(reach * 2.0, 16.0, reach * 2.0))
	var material := ShaderMaterial.new()
	material.shader = Ribbon
	material.set_shader_parameter("radius", radius)
	material.set_shader_parameter("curve_mode", curve_mode)
	material.set_shader_parameter("path_stretch", stretch)
	material.set_shader_parameter("path_yaw", yaw)
	material.set_shader_parameter("swim_speed", 0.105 if region in ["bones", "hadal"] else 0.14)
	material.set_shader_parameter("back_color", Art.region_profile(region).shadow)
	material.set_shader_parameter("belly_color", Art.region_profile(region).accent)
	batch.multimesh = mm
	batch.material_override = material
	batch.position = Vector3(center.x, minf(-3.0, _height(center) + height), center.y)
	batch.visibility_range_end = 140.0
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	batch.set_meta("curve_mode", curve_mode)
	batch.set_meta("path_radius", radius)
	batch.set_meta("path_stretch", stretch)
	add_child(batch)

func _core() -> void:
	for spec: Vector3 in [Vector3(-21, 8, 1.15), Vector3(23, 1, 1.30), Vector3(-26, -21, 1.05), Vector3(25, -33, 1.35)]:
		_garden(Vector2(spec.x, spec.y), "core", spec.z)
	_arch(Vector2(0, -28), 28.0, 23.0, -0.12, "core")
	var right_ledge := _rock(Vector2(31, -9), Vector3(7.6, 3.2, 6.2), "core", 0.38, false)
	var left_ledge := _rock(Vector2(-43, -25), Vector3(9.2, 4.3, 7.2), "core", -0.28, false)
	_asset("table_coral", Vector3(30, right_ledge - 0.08, -9), Vector3.ONE * 1.15, "core", 0.42)
	_asset("staghorn_coral", Vector3(-42, left_ledge - 0.08, -25), Vector3.ONE * 1.18, "core", -0.45)
	_rock(Vector2(-54, -52), Vector3(14, 24, 11), "core", -0.30, true)
	_rock(Vector2(-19, -98), Vector3(13, 28, 11), "core", -0.48, true)
	_rock(Vector2(48, -82), Vector3(16, 34, 12), "core", 0.35, true)
	_rock(Vector2(-44, -92), Vector3(15, 19, 11), "core", -0.65, false)
	_shoal(Vector2(-2, -16), "core", 9.0, 17.0, 1, Vector2(1.24, 0.72), -0.28)

func _atoll() -> void:
	var c := Vector2(40, 340)
	for spec: Vector3 in [Vector3(-37, -12, 1.68), Vector3(-26, -35, 0.96), Vector3(-6, -42, 0.76), Vector3(25, -32, 1.32), Vector3(38, -10, 1.48), Vector3(41, 13, 0.78), Vector3(20, 29, 0.95), Vector3(-25, 28, 1.18)]:
		_garden(c + Vector2(spec.x, spec.y), "atoll", spec.z)
	_arch(c + Vector2(-17, -26), 16.0, 12.0, 0.3, "atoll", 2)
	_rock(c + Vector2(-49, -43), Vector3(16, 15, 11), "atoll", -0.32, false)
	_rock(c + Vector2(50, -48), Vector3(12, 16, 10), "atoll", 0.44, true)
	_shoal(c, "atoll", 9.0, 23.0, 2, Vector2(1.12, 0.66), 0.32)

func _kelp() -> void:
	var c := Vector2(-260, 280)
	for side: float in [-1.0, 1.0]:
		for i in range(15):
			var corridor := 17.5 + sin(float(i) * 0.62 + side * 0.45) * 4.5 + (3.5 if i > 9 and side > 0.0 else 0.0)
			var point := c + Vector2(side * corridor, float(i) * 5.4 - 36.0)
			var y := _height(point)
			var h := minf(15.5 + sin(float(i) * 1.15 + side * 0.8) * 6.2, -y - 2.0)
			var breadth := 1.02 + sin(float(i) * 1.7 + side) * 0.22
			_asset("kelp", Vector3(point.x, y, point.y), Vector3(breadth, h / 5.114, breadth), "kelp", float(i) * 1.73)
			if i % 3 == 1:
				var outer := point + Vector2(side * 8.5, 2.2)
				var oy := _height(outer)
				var oh := minf(20.5 + cos(float(i) * 0.9) * 4.5, -oy - 1.8)
				_asset("kelp", Vector3(outer.x, oy, outer.y), Vector3(1.22, oh / 5.114, 1.22), "kelp", float(i) * 2.31)
			if i % 4 == 0:
				_rock(point + Vector2(side * 7.2, 0), Vector3(6.8, 9.5, 7.0), "kelp", float(i) * 0.9, i % 8 == 0)
	_arch(c + Vector2(0, -32), 21.0, 18.0, 0.1, "kelp", 2)
	_rock(c + Vector2(-32, -48), Vector3(12, 23, 11), "kelp", 0.42, true)
	_rock(c + Vector2(30, -52), Vector3(11, 20, 10), "kelp", -0.36, true)
	_shoal(c + Vector2(0, -5), "kelp", 11.0, 17.0, 1, Vector2(1.40, 0.42), PI * 0.5)

func _ridge() -> void:
	var c := Vector2(380, 290)
	for i in range(8):
		var point := c + Vector2(float(i) * 11.0 - 42.0, -18.0 - sin(float(i) * 0.9) * 10.0)
		_rock(point, Vector3(6.8, 18.0 + float(i % 3) * 7.5, 8.2), "ridge", float(i) * 0.55, true)
		if i in [1, 2, 4, 6, 7]:
			var crystal_xz := point + Vector2(2.5, 5.5)
			_asset("crystal_spire", Vector3(crystal_xz.x, _height(crystal_xz), crystal_xz.y), Vector3.ONE * (2.5 + float(i % 2) * 0.65), "ridge", float(i) * 0.8)
	for fore: Vector2 in [Vector2(-4, 24), Vector2(31, 18)]:
		var shelf_xz := c + fore
		var shelf_top := _rock(shelf_xz, Vector3(7.2, 5.2, 6.2), "ridge", fore.x * 0.08, false)
		_asset("crystal_spire", Vector3(shelf_xz.x + 0.8, shelf_top - 0.35, shelf_xz.y - 0.6), Vector3.ONE * 2.25, "ridge", fore.y * 0.12)
	_rock(c + Vector2(-18, 12), Vector3(7.5, 12.0, 8.5), "ridge", 1.1, true)
	_rock(c + Vector2(-46, -47), Vector3(12, 38, 12), "ridge", -0.32, true)
	_rock(c + Vector2(18, -54), Vector3(11, 33, 11), "ridge", 0.28, true)
	_garden(c + Vector2(-8, 8), "ridge", 1.35)
	_shoal(c, "ridge", 17.0, 23.0, 0, Vector2(1.30, 0.45), -0.45)
	var aurora := OmniLight3D.new()
	aurora.name = "AuroraRidgeLight"
	aurora.position = Vector3(c.x + 2.0, _height(c) + 12.0, c.y - 4.0)
	aurora.light_color = Color("8be6ec")
	aurora.light_energy = 3.4
	aurora.omni_range = 66.0
	aurora.distance_fade_enabled = true
	aurora.distance_fade_begin = 110.0
	aurora.distance_fade_length = 30.0
	aurora.set_meta("authored_light", true)
	add_child(aurora)

func _citadel() -> void:
	var c := Vector2(460, -60)
	_arch(c + Vector2(0, -22), 25.0, 25.0, 0, "citadel", 1)
	_arch(c + Vector2(-1, -42), 18.0, 22.0, -0.03, "citadel", 2)
	for side: float in [-1.0, 1.0]:
		for i in range(4):
			var broken := (side < 0.0 and i == 1) or (side > 0.0 and i == 2)
			_pillar(c + Vector2(side * 16.0, 17.0 - float(i) * 15.0 + (3.0 if side < 0 else 0.0)), 13.0 + float(i) * 1.5 + side * 0.75, "citadel", broken)
	_garden(c + Vector2(-26, 13), "citadel", 1.5)
	_garden(c + Vector2(24, -16), "citadel", 1.3)
	for point: Vector2 in [Vector2(-53, -54), Vector2(49, -68), Vector2(12, -88)]:
		_rock(c + point, Vector3(13, 34, 13), "citadel", point.x * 0.1, true)
	_rock(c + Vector2(0, -115), Vector3(23, 48, 14), "citadel", -0.22, true)
	_shoal(c + Vector2(0, -8), "citadel", 22.0, 24.0, 2, Vector2(0.95, 0.64), PI * 0.5)
	var sanctum_glow := OmniLight3D.new()
	sanctum_glow.name = "CitadelSanctumLight"
	sanctum_glow.position = Vector3(c.x, _height(c) + 15.0, c.y - 24.0)
	sanctum_glow.light_color = Color("ead08a")
	sanctum_glow.light_energy = 2.5
	sanctum_glow.omni_range = 54.0
	sanctum_glow.distance_fade_enabled = true
	sanctum_glow.distance_fade_begin = 110.0
	sanctum_glow.distance_fade_length = 30.0
	sanctum_glow.set_meta("authored_light", true)
	add_child(sanctum_glow)

func _wreck() -> void:
	var c := Vector2(420, -380)
	for i in range(2):
		var point := c + (Vector2(-16, -12) if i == 0 else Vector2(25, -26))
		var ship: Node3D = ocean.model("shipwreck", Vector3(point.x, _height(point) + 1.15, point.y), 1.85 if i == 0 else 1.38, 180.0)
		ship.rotation = Vector3(0.10 if i == 0 else -0.07, -0.58 if i == 0 else 1.18, -0.25 if i == 0 else 0.22)
		ocean._attach_landmark_collision(ship, "shipwreck")
		for gi: GeometryInstance3D in ship.find_children("*", "GeometryInstance3D", true, false):
			gi.layers = 3
		var mast_base := Vector3(point.x, _height(point) + (3.6 if i == 0 else 2.9), point.y + (2.4 if i == 0 else -1.8))
		var mast_top := mast_base + Vector3(0, 2.4 if i == 0 else 1.9, 0)
		_record("wreck_masts", _column, _material("wreck", "stone"), (mast_base + mast_top) * 0.5, Vector3(0.16, mast_top.y - mast_base.y, 0.16))
		_record("wreck_lanterns", _column, _material("wreck", "glow"), mast_top, Vector3(0.46, 0.78, 0.46))
	for spec: Vector3 in [Vector3(-35, 7, 0.90), Vector3(39, -44, 1.38), Vector3(-26, -41, 1.08)]:
		_rock(c + Vector2(spec.x, spec.y), Vector3(8.5, 14.5, 9.5) * spec.z, "wreck", spec.x * 0.15, true)
	_rock(c + Vector2(-14, 14), Vector3(8.0, 4.2, 6.8), "wreck", 0.42, false)
	_garden(c + Vector2(27, 8), "wreck", 1.1)
	_shoal(c + Vector2(-5, 0), "wreck", 14.0, 26.0, 1, Vector2(1.15, 0.48), -0.8)
	var beacon := OmniLight3D.new()
	beacon.name = "WreckChannelBeacon"
	beacon.position = Vector3(c.x + 3.0, _height(c) + 11.0, c.y - 16.0)
	beacon.light_color = Color("f2a45a")
	beacon.light_energy = 3.2
	beacon.omni_range = 54.0
	beacon.distance_fade_enabled = true
	beacon.distance_fade_begin = 110.0
	beacon.distance_fade_length = 30.0
	beacon.set_meta("authored_light", true)
	add_child(beacon)

func _bones() -> void:
	var c := Vector2(-480, -90)
	for i in range(9):
		var point := c + Vector2(sin(float(i) * 0.45) * 4.0, float(i) * 9.0 - 42.0)
		var y := _height(point)
		var spine_yaw := atan2(cos(float(i) * 0.45) * 1.8, 9.0)
		var spine_pos := Vector3(point.x, y + 1.25, point.y)
		_record("bones_spine", _column, _material("bones", "bone"), spine_pos, Vector3.ONE)
		_batches["bones_spine"].transforms[-1] = Transform3D(
			Basis(Vector3.UP, spine_yaw) * Basis(Vector3.RIGHT, PI * 0.5).scaled_local(Vector3(1.65, 3.8, 1.45)),
			spine_pos
		)
		_record("bones_crest", _cube, _material("bones", "bone"), spine_pos + Vector3(0, 1.48, 0), Vector3(0.46, 1.65, 2.25), spine_yaw)
		for side: float in [-1.0, 1.0]:
			var broken := (i == 1 and side > 0.0) or (i == 3 and side < 0.0) or (i == 6 and side > 0.0)
			var key := "bones_rib_%s_%s" % ["l" if side < 0.0 else "r", "broken" if broken else "whole"]
			if not _rib_meshes.has(key):
				_rib_meshes[key] = ocean._build_leviathan_rib_mesh(side, broken)
			var rib_scale := 0.78 + sin(float(i) / 8.0 * PI) * 0.42
			_record(key, _rib_meshes[key], _material("bones", "bone"), Vector3(point.x + side * (13.2 + rib_scale * 2.2), y - 0.5, point.y), Vector3.ONE * rib_scale)
	for point: Vector2 in [Vector2(-34, -36), Vector2(48, -18), Vector2(-44, 26)]:
		_rock(c + point, Vector3(9.5, 14.0, 8.5), "bones", point.x * 0.12, true)
	_rock(c + Vector2(18, -80), Vector3(13, 28, 10), "bones", 0.42, true)
	_shoal(c + Vector2(0, -6), "bones", 27.0, 29.0, 0, Vector2(1.28, 0.62), 0.1)
	var pale_light := OmniLight3D.new()
	pale_light.name = "BonefieldPaleLight"
	pale_light.position = Vector3(c.x + 6.0, _height(c) + 18.0, c.y - 6.0)
	pale_light.light_color = Color("9ed2eb")
	pale_light.light_energy = 3.8
	pale_light.omni_range = 64.0
	pale_light.distance_fade_enabled = true
	pale_light.distance_fade_begin = 110.0
	pale_light.distance_fade_length = 30.0
	pale_light.set_meta("authored_light", true)
	add_child(pale_light)

func _caldera() -> void:
	var c := Vector2(-440, -420)
	for i in range(9):
		var point := c + Vector2(float(i) * 10.0 - 42.0, -26.0 - cos(float(i)) * 8.0)
		_rock(point, Vector3(5.8 + sin(float(i) * 1.1) * 1.35, 17.0 + float(i % 4) * 5.5, 7.8), "caldera", float(i) * 0.42, true)
	for point: Vector2 in [Vector2(-32, 8), Vector2(34, 4)]:
		_rock(c + point, Vector3(6.8, 16.0, 7.2), "caldera", point.x * 0.1, true)
	for rim_ledge: Vector2 in [Vector2(-22, 18), Vector2(24, 16)]:
		_rock(c + rim_ledge, Vector3(7.5, 4.6, 6.4), "caldera", rim_ledge.x * 0.06, false)
	for point: Vector2 in [Vector2(-17, -4), Vector2(8, -16), Vector2(21, -22), Vector2(-25, -24)]:
		ocean._create_hydrothermal_vent(Vector3(c.x + point.x, _height(c + point), c.y + point.y))
	var magma_glow := OmniLight3D.new()
	magma_glow.name = "CalderaBasinGlow"
	magma_glow.position = Vector3(c.x - 2.0, _height(c) + 12.0, c.y - 15.0)
	magma_glow.light_color = Color("ff8836")
	magma_glow.light_energy = 4.2
	magma_glow.omni_range = 28.0
	magma_glow.distance_fade_enabled = true
	magma_glow.distance_fade_begin = 95.0
	magma_glow.distance_fade_length = 25.0
	magma_glow.set_meta("authored_light", true)
	add_child(magma_glow)
	_shoal(c, "caldera", 19.0, 25.0, 2, Vector2(1.0, 0.70), -0.24)

func _hadal() -> void:
	var c := Vector2(60, -640)
	_arch(c + Vector2(0, -28), 30.0, 31.0, 0.05, "hadal", 2)
	for side: float in [-1.0, 1.0]:
		_pillar(c + Vector2(side * 22.0, -12.0), 19.0, "hadal", false)
		_pillar(c + Vector2(side * 18.0, 6.0), 14.5, "hadal", side > 0.0)
	for i in range(5):
		var point := c + Vector2(-37.0 + float(i) * 19.0, -48.0 - absf(2.0 - float(i)) * 6.0)
		_rock(point, Vector3(7.8, 33.0 + float(i % 2) * 9.5, 9.5), "hadal", float(i) * 0.5, true)
	for approach: Vector2 in [Vector2(-24, 22), Vector2(26, 24)]:
		_rock(c + approach, Vector3(8.2, 3.8, 6.8), "hadal", approach.x * 0.05, false)
	for point: Vector2 in [Vector2(-22, 9), Vector2(24, -8), Vector2(-15, -22), Vector2(16, -24)]:
		_asset("crystal_spire", Vector3(c.x + point.x, _height(c + point), c.y + point.y), Vector3.ONE * 3.0, "hadal", point.x * 0.1)
	_shoal(c + Vector2(0, -4), "hadal", 27.0, 29.0, 1, Vector2(1.12, 0.50), -0.12)
	var light := OmniLight3D.new()
	light.name = "SanctumPearlLight"
	light.position = Vector3(c.x, _height(c) + 18.5, c.y - 18.0)
	light.light_color = Color("94e4fa")
	light.light_energy = 5.8
	light.omni_range = 52.0
	light.distance_fade_enabled = true
	light.distance_fade_begin = 110.0
	light.distance_fade_length = 30.0
	light.set_meta("authored_light", true)
	add_child(light)

func _add_tri(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (c - a).cross(b - a).normalized()
	surface.set_normal(normal)
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)

func _add_quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var normal := ((c - a).cross(b - a) + (c - b).cross(d - b)).normalized()
	surface.set_normal(normal)
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)
	surface.add_vertex(b)
	surface.add_vertex(d)
	surface.add_vertex(c)

func _arch_sections(style: int) -> Array[PackedVector3Array]:
	var centers: Array[Vector2] = [Vector2(-0.5, -0.025), Vector2(-0.5, 0.23), Vector2(-0.5, 0.48)]
	for i in range(1, 17):
		var phase := float(i) / 16.0 * PI
		var asymmetry := sin(phase) * sin(phase * 2.0) * (0.035 if style == 2 else 0.012)
		var rise := sin(phase) * 0.47
		if style == 1:
			rise = (sin(phase) * 0.76 + (1.0 - absf(cos(phase))) * 0.24) * 0.48
		centers.append(Vector2(-cos(phase) * 0.5 + asymmetry, 0.48 + rise))
	centers.append(Vector2(0.5, 0.23))
	centers.append(Vector2(0.5, -0.025))
	var sections: Array[PackedVector3Array] = []
	for i in range(centers.size()):
		var tangent := centers[mini(i + 1, centers.size() - 1)] - centers[maxi(i - 1, 0)]
		var outward := Vector2(-tangent.y, tangent.x).normalized()
		var phase := float(i) / float(centers.size() - 1)
		var width := 0.043 * (1.0 + sin(phase * PI * 3.0 + float(style)) * 0.13)
		var depth := 0.50 * (1.0 + sin(phase * PI * 2.0 + float(style)) * 0.12)
		var inner := centers[i] - outward * width
		var outer := centers[i] + outward * width
		sections.append(PackedVector3Array([
			Vector3(inner.x, inner.y, -depth), Vector3(outer.x, outer.y, -depth),
			Vector3(outer.x, outer.y, depth), Vector3(inner.x, inner.y, depth)
		]))
	return sections

func _make_arch_band(style: int) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	var raw_sections := _arch_sections(style)
	var sections: Array[PackedVector3Array] = []
	for i in range(raw_sections.size() - 1):
		sections.append(raw_sections[i])
		var mid := PackedVector3Array()
		for k in range(4):
			mid.append(raw_sections[i][k].lerp(raw_sections[i + 1][k], 0.5))
		sections.append(mid)
	sections.append(raw_sections[-1])
	var profiles: Array[PackedVector3Array] = []
	for i in range(sections.size()):
		var s: PackedVector3Array = sections[i]
		var inner := Vector2(s[0].x, s[0].y)
		var outer := Vector2(s[1].x, s[1].y)
		var center := (inner + outer) * 0.5
		var half_span := (outer - inner) * 0.5
		var phase := float(i) / float(sections.size() - 1)
		var is_plinth := phase < 0.055 or phase > 0.945
		var is_spring := (phase > 0.085 and phase < 0.135) or (phase > 0.865 and phase < 0.915)
		var is_keystone := absf(phase - 0.5) < 0.045
		var voussoir := 1.045 if (i % 2 == 0) else 0.975
		var keystone := 1.32 if is_plinth else (1.22 if is_spring else (1.18 if is_keystone else voussoir))
		var w := half_span * (keystone * 1.18)
		var wm := w * 0.78
		var wc := w * 0.46
		var d := absf(s[2].z) * keystone
		var dm := d * 0.82
		var dc := d * 0.54
		profiles.append(PackedVector3Array([
			Vector3(center.x - w.x, center.y - w.y, -dc),
			Vector3(center.x - wm.x, center.y - wm.y, -dm),
			Vector3(center.x - wc.x, center.y - wc.y, -d),
			Vector3(center.x + wc.x, center.y + wc.y, -d),
			Vector3(center.x + wm.x, center.y + wm.y, -dm),
			Vector3(center.x + w.x, center.y + w.y, -dc),
			Vector3(center.x + w.x, center.y + w.y, dc),
			Vector3(center.x + wm.x, center.y + wm.y, dm),
			Vector3(center.x + wc.x, center.y + wc.y, d),
			Vector3(center.x - wc.x, center.y - wc.y, d),
			Vector3(center.x - wm.x, center.y - wm.y, dm),
			Vector3(center.x - w.x, center.y - w.y, dc),
		]))
	var edge_count := 12
	for i in range(sections.size() - 1):
		for edge in range(edge_count):
			var next_edge := (edge + 1) % edge_count
			var a: Vector3 = profiles[i][edge]
			var b: Vector3 = profiles[i][next_edge]
			var c: Vector3 = profiles[i + 1][edge]
			var d: Vector3 = profiles[i + 1][next_edge]
			_add_quad(surface, a, c, b, d)
	for end in [0, sections.size() - 1]:
		var profile: PackedVector3Array = profiles[end]
		var cap_center := Vector3.ZERO
		for p: Vector3 in profile:
			cap_center += p
		cap_center /= float(profile.size())
		for edge in range(edge_count):
			var next_edge := (edge + 1) % edge_count
			if end == 0:
				_add_tri(surface, cap_center, profile[edge], profile[next_edge])
			else:
				_add_tri(surface, cap_center, profile[next_edge], profile[edge])
	return surface.commit()

func _make_sun_compass_emblem() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	# Two concentric graduated astrolabe rings in XY plane
	for ring_spec: Vector3 in [Vector3(0.92, 1.08, 0.085), Vector3(0.48, 0.59, 0.075)]:
		var r_in := ring_spec.x
		var r_out := ring_spec.y
		var hz := ring_spec.z
		var segs := 32
		for s in range(segs):
			var a0 := float(s) / float(segs) * TAU
			var a1 := float(s + 1) / float(segs) * TAU
			var p00 := Vector3(cos(a0) * r_in, sin(a0) * r_in, -hz)
			var p01 := Vector3(cos(a0) * r_out, sin(a0) * r_out, -hz)
			var p02 := Vector3(cos(a0) * r_out, sin(a0) * r_out, hz)
			var p03 := Vector3(cos(a0) * r_in, sin(a0) * r_in, hz)
			var p10 := Vector3(cos(a1) * r_in, sin(a1) * r_in, -hz)
			var p11 := Vector3(cos(a1) * r_out, sin(a1) * r_out, -hz)
			var p12 := Vector3(cos(a1) * r_out, sin(a1) * r_out, hz)
			var p13 := Vector3(cos(a1) * r_in, sin(a1) * r_in, hz)
			_add_quad(surface, p03, p13, p02, p12)
			_add_quad(surface, p00, p01, p10, p11)
			_add_quad(surface, p02, p12, p01, p11)
			_add_quad(surface, p00, p10, p03, p13)
	# 16 faceted compass-rose star rays + central sunburst boss
	for ray in range(16):
		var ang := float(ray) / 16.0 * TAU
		var cardinal := (ray % 2) == 0
		var tip_r := (1.28 if (ray % 4 == 0) else 1.12) if cardinal else 0.86
		var base_w := 0.11 if cardinal else 0.065
		var ridge_z := 0.14 if cardinal else 0.095
		var dir := Vector2(cos(ang), sin(ang))
		var perp := Vector2(-dir.y, dir.x)
		var root_c := Vector3(dir.x * 0.18, dir.y * 0.18, ridge_z)
		var tip := Vector3(dir.x * tip_r, dir.y * tip_r, 0.0)
		var left := Vector3(dir.x * 0.34 + perp.x * base_w, dir.y * 0.34 + perp.y * base_w, 0.0)
		var right := Vector3(dir.x * 0.34 - perp.x * base_w, dir.y * 0.34 - perp.y * base_w, 0.0)
		var root_back := Vector3(dir.x * 0.18, dir.y * 0.18, -ridge_z)
		_add_tri(surface, root_c, right, tip)
		_add_tri(surface, root_c, tip, left)
		_add_tri(surface, root_back, tip, right)
		_add_tri(surface, root_back, left, tip)
	var boss_segs := 16
	var apex_f := Vector3(0, 0, 0.22)
	var apex_b := Vector3(0, 0, -0.22)
	for s in range(boss_segs):
		var a0 := float(s) / float(boss_segs) * TAU
		var a1 := float(s + 1) / float(boss_segs) * TAU
		var rim0 := Vector3(cos(a0) * 0.28, sin(a0) * 0.28, 0.0)
		var rim1 := Vector3(cos(a1) * 0.28, sin(a1) * 0.28, 0.0)
		_add_tri(surface, apex_f, rim0, rim1)
		_add_tri(surface, apex_b, rim1, rim0)
	return surface.commit()

func _make_pillar(broken: bool) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	var sides := 24
	var levels: Array[Vector2] = [
		Vector2(0.0, 1.18), Vector2(0.06, 1.16), Vector2(0.10, 1.02),
		Vector2(0.32, 0.94), Vector2(0.62, 0.88), Vector2(0.88, 0.82),
		Vector2(0.94, 0.98), Vector2(1.0, 1.06)
	]
	var rings: Array[PackedVector3Array] = []
	for level in range(levels.size()):
		var y := levels[level].x
		var radius := levels[level].y
		var on_shaft := level >= 2 and level <= 5
		var ring := PackedVector3Array()
		for index in range(sides):
			var angle := float(index) / float(sides) * TAU
			var flute := (1.0 - 0.055 * maxf(0.0, cos(angle * 12.0))) if on_shaft else 1.0
			var top := y
			if broken and level >= 5:
				var frac_y := 0.86 + cos(angle - 0.55) * 0.11 + sin(angle * 3.0) * 0.035
				top = minf(y, frac_y)
				radius = levels[4].y
			ring.append(Vector3(cos(angle) * radius * flute + y * 0.02, top, sin(angle) * radius * flute))
		rings.append(ring)
	for level in range(levels.size() - 1):
		for index in range(sides):
			var next := (index + 1) % sides
			_add_quad(surface, rings[level][index], rings[level][next], rings[level + 1][index], rings[level + 1][next])
	var last_idx := levels.size() - 1
	var cap_apex := Vector3(0.02, 0.90 if broken else 1.01, -0.01)
	for index in range(sides):
		_add_tri(surface, rings[last_idx][index], rings[last_idx][(index + 1) % sides], cap_apex)
	return surface.commit()

func _flush() -> void:
	for key: String in _batches:
		var data: Dictionary = _batches[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = data.mesh
		mm.instance_count = data.transforms.size()
		var bounds := AABB()
		for transform_value: Transform3D in data.transforms:
			var box: AABB = transform_value * data.mesh.get_aabb()
			bounds = box if bounds.size == Vector3.ZERO else bounds.merge(box)
		var origin := bounds.get_center()
		for i in range(mm.instance_count):
			var transform_value: Transform3D = data.transforms[i]
			transform_value.origin -= origin
			mm.set_instance_transform(i, transform_value)
			mm.set_instance_color(i, data.colors[i])
		mm.custom_aabb = AABB(bounds.position - origin, bounds.size).grow(3.5)
		var batch := MultiMeshInstance3D.new()
		batch.name = key
		batch.layers = 3
		batch.multimesh = mm
		batch.material_override = data.material
		batch.position = origin
		batch.visibility_range_end = 210.0
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(batch)
	set_meta("batch_count", _batches.size())
	_batches.clear()

func _make_terrace() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	var sides := 16
	var vertices: Array[Vector3] = []
	var radii: Array[float] = [1.06, 0.98, 1.03, 0.76, 0.81, 0.56, 0.59, 0.40]
	var heights: Array[float] = [0.0, 0.28, 0.33, 0.56, 0.62, 0.80, 0.85, 0.98]
	for level in range(radii.size()):
		var radius: float = radii[level]
		var y: float = heights[level]
		var tier := level >> 1
		var shift := Vector2(0.035 * float(tier), -0.025 * float(tier))
		for i in range(sides):
			var angle := float(i) / float(sides) * TAU + float(tier) * 0.11
			var jag := 1.0 + sin(angle * 3.0 + 0.5) * 0.12 + cos(angle * 5.0 - float(tier) * 0.8) * 0.07
			var r := radius * jag
			var ledge := y + (sin(angle * 4.0 + float(tier)) * 0.014 if level > 0 and level < radii.size() - 1 else 0.0)
			vertices.append(Vector3(cos(angle) * r + shift.x, ledge, sin(angle) * r + shift.y))
	for level in range(radii.size() - 1):
		for i in range(sides):
			var a := level * sides + i
			var b := level * sides + (i + 1) % sides
			_add_quad(surface, vertices[a], vertices[b], vertices[a + sides], vertices[b + sides])
	var top_base := (radii.size() - 1) * sides
	var apex := Vector3(0.04, 1.0, -0.03)
	for i in range(sides):
		_add_tri(surface, vertices[top_base + i], vertices[top_base + (i + 1) % sides], apex)
	return surface.commit()

func _make_spire() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_smooth_group(-1)
	var sides := 14
	var vertices: Array[Vector3] = []
	var radii: Array[float] = [1.04, 0.88, 0.92, 0.68, 0.54, 0.36, 0.22, 0.09]
	var heights: Array[float] = [0.0, 0.22, 0.26, 0.48, 0.68, 0.83, 0.93, 0.98]
	for level in range(radii.size()):
		var radius: float = radii[level]
		var y: float = heights[level]
		var lean := Vector2(0.08 * y, -0.06 * y)
		for i in range(sides):
			var angle := float(i) / float(sides) * TAU + float(level >> 1) * 0.12
			var flute := 1.0 + sin(angle * 3.0 + 0.7) * 0.14 + cos(angle * 5.0 + float(level) * 0.5) * 0.08
			var crest := y + (0.022 * sin(angle * 3.0) if level == radii.size() - 1 else 0.0)
			vertices.append(Vector3(cos(angle) * radius * flute + lean.x, crest, sin(angle) * radius * flute + lean.y))
	for level in range(radii.size() - 1):
		for i in range(sides):
			var a := level * sides + i
			var b := level * sides + (i + 1) % sides
			_add_quad(surface, vertices[a], vertices[b], vertices[a + sides], vertices[b + sides])
	var top_base := (radii.size() - 1) * sides
	var peak := Vector3(0.08, 1.0, -0.06)
	for i in range(sides):
		_add_tri(surface, vertices[top_base + i], vertices[top_base + (i + 1) % sides], peak)
	return surface.commit()

func _fish_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var profiles: Array[Vector3] = [Vector3(-0.40, 0.025, 0.035), Vector3(-0.16, 0.11, 0.13), Vector3(0.14, 0.115, 0.15), Vector3(0.38, 0.065, 0.085), Vector3(0.54, 0.010, 0.018)]
	for ring in range(profiles.size() - 1):
		for side in range(8):
			var points: Array[Vector3] = []
			for offset: Vector2i in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 0)]:
				var profile: Vector3 = profiles[ring + offset.x]
				var angle := float((side + offset.y) % 8) / 8.0 * TAU
				points.append(Vector3(cos(angle) * profile.y, sin(angle) * profile.z, profile.x))
			for point: Vector3 in points:
				surface.add_vertex(point)
	# Forked tail, dorsal and pectoral fins keep the small silhouette readable.
	for point: Vector3 in [
		Vector3(0, 0, -0.35), Vector3(0, 0.24, -0.64), Vector3(0, 0.02, -0.53),
		Vector3(0, 0, -0.35), Vector3(0, -0.02, -0.53), Vector3(0, -0.20, -0.64),
		Vector3(0, 0.13, 0.12), Vector3(0, 0.25, -0.10), Vector3(0, 0.11, -0.24)
	]:
		surface.add_vertex(point)
	for side: float in [-1.0, 1.0]:
		for point: Vector3 in [Vector3(side * 0.08, -0.025, 0.13), Vector3(side * 0.25, -0.055, -0.12), Vector3(side * 0.08, -0.045, -0.06)]:
			surface.add_vertex(point)
	surface.generate_normals()
	return surface.commit()
