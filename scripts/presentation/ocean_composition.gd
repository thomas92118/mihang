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
var _terrace_mesh: ArrayMesh
var _spire_mesh: ArrayMesh
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
	_column.top_radius = 0.92
	_column.bottom_radius = 1.0
	_column.height = 1.0
	_column.radial_segments = 10
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
		var pigment_role := "accent" if glow else role
		material.set_shader_parameter("pigment", profile[pigment_role])
		material.set_shader_parameter("top_pigment", profile["sand"].lerp(profile[pigment_role], 0.35))
		material.set_shader_parameter("glow_strength", 0.58 if glow else (0.14 if role == "accent" else 0.0))
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

func _arch(center: Vector2, width: float, requested_height: float, yaw: float, region: String) -> void:
	var at := Vector3(center.x, _height(center), center.y)
	var height := minf(requested_height, -at.y - 1.2)
	var turn := Basis(Vector3.UP, yaw)
	var thickness := width * 0.095
	for side: float in [-1.0, 1.0]:
		var foot := at + turn * Vector3(side * width * 0.5, 0, 0)
		var bottom := _height(Vector2(foot.x, foot.z)) - 0.6
		var leg_height := at.y + height * 0.54 - bottom
		_record(region + "_columns", _column, _material(region, "sand"), Vector3(foot.x, bottom + leg_height * 0.5, foot.z), Vector3(thickness * 0.72, leg_height, thickness * 0.72), yaw, Color.WHITE, true)
	for i in range(13):
		var a := float(i) / 13.0 * PI
		var b := float(i + 1) / 13.0 * PI
		var start := Vector3(cos(a) * width * 0.5, height * 0.54 + sin(a) * height * 0.46, 0)
		var end := Vector3(cos(b) * width * 0.5, height * 0.54 + sin(b) * height * 0.46, 0)
		var delta := end - start
		var up := delta.normalized()
		var right := up.cross(Vector3.FORWARD).normalized()
		var basis := turn * Basis(right, up, right.cross(up)).scaled_local(Vector3(thickness, delta.length() * 1.06, thickness * 1.35))
		var point := at + turn * (start + end) * 0.5
		_record(region + "_arches", _cube, _material(region, "sand"), point, Vector3.ONE)
		_batches[region + "_arches"].transforms[-1] = Transform3D(basis, point)
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3.ONE
		collision.shape = box
		body.transform = Transform3D(basis, point)
		body.add_child(collision)
		add_child(body)
	# A gold keystone emblem links ancient architecture to the interface inlays.
	var emblem := TorusMesh.new()
	emblem.inner_radius = 0.65
	emblem.outer_radius = 0.85
	emblem.rings = 24
	emblem.ring_segments = 6
	var emblem_at := at + turn * Vector3(0, height - thickness * 0.3, thickness * 0.76)
	var emblem_role := "glow" if region in ["citadel", "hadal"] else "accent"
	_record(region + "_emblems", emblem, _material(region, emblem_role), emblem_at, Vector3.ONE)
	_batches[region + "_emblems"].transforms[-1] = Transform3D(turn * Basis(Vector3.RIGHT, PI * 0.5), emblem_at)

func _pillar(xz: Vector2, height: float, region: String, broken: bool = false) -> void:
	if not _clear(xz, 2.0):
		return
	var y := _height(xz)
	var h := height * (0.57 if broken else 1.0)
	_record(region + "_columns", _column, _material(region, "sand"), Vector3(xz.x, y + h * 0.5 - 0.4, xz.y), Vector3(1.25, h, 1.25), 0, Color.WHITE, true)
	for level: float in [0.4, h - 0.5]:
		_record(region + "_caps", _cube, _material(region, "rock"), Vector3(xz.x, y + level, xz.y), Vector3(3.0, 0.7, 3.0), 0.12)
	var inlay_role := "glow" if region in ["citadel", "hadal"] else "accent"
	_record(region + "_inlays", _column, _material(region, inlay_role), Vector3(xz.x, y + h * 0.77, xz.y), Vector3(1.29, 0.18, 1.29))

func _shoal(center: Vector2, region: String, height: float, radius: float = 15.0) -> void:
	var batch := MultiMeshInstance3D.new()
	batch.name = region + "_ribbon"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _fish_mesh()
	mm.instance_count = 80 if region in ["core", "atoll", "kelp"] else 48
	for i in range(mm.instance_count):
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * _seed.randf_range(0.7, 1.3)), Vector3.ZERO))
		mm.set_instance_custom_data(i, Color(float(i) / float(mm.instance_count), _seed.randf(), _seed.randf(), 1))
	mm.custom_aabb = AABB(Vector3(-radius - 8, -6, -radius - 8), Vector3(radius * 2 + 16, 12, radius * 2 + 16))
	var material := ShaderMaterial.new()
	material.shader = Ribbon
	material.set_shader_parameter("radius", radius)
	material.set_shader_parameter("back_color", Art.region_profile(region).shadow)
	material.set_shader_parameter("belly_color", Art.region_profile(region).accent)
	batch.multimesh = mm
	batch.material_override = material
	batch.position = Vector3(center.x, minf(-3.0, _height(center) + height), center.y)
	batch.visibility_range_end = 140.0
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(batch)

func _core() -> void:
	for point: Vector2 in [Vector2(-21, 5), Vector2(21, -2), Vector2(-27, -14), Vector2(22, -28)]:
		_garden(point, "core", 1.15)
	_arch(Vector2(0, -28), 28.0, 23.0, -0.12, "core")
	for point: Vector2 in [Vector2(-49, -40), Vector2(22, -78), Vector2(-38, -72)]:
		_rock(point, Vector3(14, 20, 12), "core", point.x * 0.08, true)
	_shoal(Vector2(-2, -12), "core", 8.0, 15.0)

func _atoll() -> void:
	var c := Vector2(40, 340)
	for i in range(8):
		var angle := 0.9 + float(i) * 0.63
		var point := c + Vector2(cos(angle), sin(angle)) * 32.0
		_garden(point, "atoll", 1.2 + float(i % 3) * 0.25)
	_arch(c + Vector2(-17, -26), 16.0, 12.0, 0.3, "atoll")
	_shoal(c, "atoll", 9.0, 23.0)

func _kelp() -> void:
	var c := Vector2(-260, 280)
	for side: float in [-1.0, 1.0]:
		for i in range(15):
			var point := c + Vector2(side * (14.0 + sin(float(i) * 0.65) * 5.0), float(i) * 5.4 - 35.0)
			var y := _height(point)
			var h := minf(18.0 + sin(float(i)) * 4.0, -y - 2.0)
			_asset("kelp", Vector3(point.x, y, point.y), Vector3(1.4, h / 5.114, 1.4), "kelp", float(i) * 1.73)
			if i % 4 == 0:
				_rock(point + Vector2(side * 6.5, 0), Vector3(6.5, 8.5, 7.0), "kelp", float(i) * 0.9, true)
	_arch(c + Vector2(0, -32), 21.0, 18.0, 0.1, "kelp")
	_shoal(c + Vector2(0, -5), "kelp", 11.0, 10.0)

func _ridge() -> void:
	var c := Vector2(380, 290)
	for i in range(8):
		var point := c + Vector2(float(i) * 11.0 - 40.0, -18.0 - sin(float(i) * 0.9) * 10.0)
		_rock(point, Vector3(6.5, 16.0 + float(i % 3) * 7.0, 8.0), "ridge", float(i) * 0.55, true)
		if i in [1, 3, 5, 7]:
			var crystal_xz := point + Vector2(2.5, 5.5)
			_asset("crystal_spire", Vector3(crystal_xz.x, _height(crystal_xz), crystal_xz.y), Vector3.ONE * (2.4 + float(i % 2) * 0.6), "ridge", float(i) * 0.8)
	_rock(c + Vector2(-18, 12), Vector3(7.5, 12.0, 8.5), "ridge", 1.1, true)
	_garden(c + Vector2(-8, 8), "ridge", 1.35)
	_shoal(c, "ridge", 13.0, 18.0)
	var aurora := OmniLight3D.new()
	aurora.name = "AuroraRidgeLight"
	aurora.position = Vector3(c.x, _height(c) + 10.0, c.y - 8.0)
	aurora.light_color = Color("8be6ec")
	aurora.light_energy = 2.2
	aurora.omni_range = 62.0
	aurora.set_meta("authored_light", true)
	add_child(aurora)

func _citadel() -> void:
	var c := Vector2(460, -60)
	_arch(c + Vector2(0, -22), 25.0, 25.0, 0, "citadel")
	_arch(c + Vector2(-1, -42), 18.0, 22.0, -0.03, "citadel")
	for side: float in [-1.0, 1.0]:
		for i in range(4):
			_pillar(c + Vector2(side * 16.0, 17.0 - float(i) * 15.0), 13.0 + float(i) * 1.5, "citadel", side < 0 and i == 1)
	_garden(c + Vector2(-26, 13), "citadel", 1.5)
	_garden(c + Vector2(24, -16), "citadel", 1.3)
	for point: Vector2 in [Vector2(-53, -54), Vector2(49, -68), Vector2(12, -88)]:
		_rock(c + point, Vector3(13, 34, 13), "citadel", point.x * 0.1, true)
	_shoal(c + Vector2(0, -8), "citadel", 18.0, 21.0)

func _wreck() -> void:
	var c := Vector2(420, -380)
	for i in range(2):
		var point := c + (Vector2(-16, -12) if i == 0 else Vector2(24, -25))
		var ship: Node3D = ocean.model("shipwreck", Vector3(point.x, _height(point) + 1.0, point.y), 1.8 if i == 0 else 1.3, 180.0)
		ship.rotation = Vector3(0.08, -0.55 if i == 0 else 1.15, -0.22 if i == 0 else 0.18)
		ocean._attach_landmark_collision(ship, "shipwreck")
		var mast_pos := Vector3(point.x, _height(point) + (5.2 if i == 0 else 4.0), point.y + (2.5 if i == 0 else -1.8))
		_record("wreck_lanterns", _column, _material("wreck", "glow"), mast_pos, Vector3(0.32, 0.55, 0.32))
	for point: Vector2 in [Vector2(-35, 7), Vector2(38, -43), Vector2(-26, -41)]:
		_rock(c + point, Vector3(7.5, 12.5, 9.5), "wreck", point.x * 0.15, true)
	_garden(c + Vector2(27, 8), "wreck", 1.1)
	_shoal(c + Vector2(-5, 0), "wreck", 12.0, 19.0)

func _bones() -> void:
	var c := Vector2(-480, -90)
	for i in range(9):
		var point := c + Vector2(sin(float(i) * 0.45) * 4.0, float(i) * 9.0 - 42.0)
		var y := _height(point)
		var spine_yaw := atan2(cos(float(i) * 0.45) * 1.8, 9.0)
		var spine_pos := Vector3(point.x, y + 1.25, point.y)
		_record("bones_spine", _column, _material("bones", "accent"), spine_pos, Vector3.ONE)
		_batches["bones_spine"].transforms[-1] = Transform3D(
			Basis(Vector3.UP, spine_yaw) * Basis(Vector3.RIGHT, PI * 0.5).scaled_local(Vector3(1.65, 3.8, 1.45)),
			spine_pos
		)
		_record("bones_crest", _cube, _material("bones", "sand"), spine_pos + Vector3(0, 1.45, 0), Vector3(0.42, 1.5, 2.2), spine_yaw)
		for side: float in [-1.0, 1.0]:
			var broken := (i == 2 and side < 0.0) or (i == 6 and side > 0.0)
			var key := "bones_rib_%s_%s" % ["l" if side < 0.0 else "r", "broken" if broken else "whole"]
			if not _rib_meshes.has(key):
				_rib_meshes[key] = ocean._build_leviathan_rib_mesh(side, broken)
			_record(key, _rib_meshes[key], _material("bones", "accent"), Vector3(point.x + side * 14.5, y - 0.5, point.y), Vector3.ONE * (0.85 + sin(float(i) / 8.0 * PI) * 0.25))
	for point: Vector2 in [Vector2(-36, -32), Vector2(48, -18), Vector2(-44, 26)]:
		_rock(c + point, Vector3(9.5, 14.0, 8.5), "bones", point.x * 0.12, true)
	_shoal(c + Vector2(0, -6), "bones", 21.0, 23.0)

func _caldera() -> void:
	var c := Vector2(-440, -420)
	for i in range(9):
		var point := c + Vector2(float(i) * 10.0 - 42.0, -26.0 - cos(float(i)) * 8.0)
		_rock(point, Vector3(5.5, 16.0 + float(i % 4) * 5.0, 7.5), "caldera", float(i) * 0.42, true)
	for point: Vector2 in [Vector2(-32, 8), Vector2(34, 4)]:
		_rock(c + point, Vector3(6.5, 15.0, 7.0), "caldera", point.x * 0.1, true)
	for point: Vector2 in [Vector2(-17, -4), Vector2(8, -16), Vector2(21, -22), Vector2(-25, -24)]:
		ocean._create_hydrothermal_vent(Vector3(c.x + point.x, _height(c + point), c.y + point.y))
	var magma_glow := OmniLight3D.new()
	magma_glow.name = "CalderaBasinGlow"
	magma_glow.position = Vector3(c.x - 2.0, _height(c) + 11.0, c.y - 16.0)
	magma_glow.light_color = Color("ff8c3b")
	magma_glow.light_energy = 3.4
	magma_glow.omni_range = 48.0
	magma_glow.set_meta("authored_light", true)
	add_child(magma_glow)
	_shoal(c, "caldera", 16.0, 24.0)

func _hadal() -> void:
	var c := Vector2(60, -640)
	_arch(c + Vector2(0, -28), 30.0, 31.0, 0.05, "hadal")
	for side: float in [-1.0, 1.0]:
		_pillar(c + Vector2(side * 22.0, -12.0), 19.0, "hadal", false)
		_pillar(c + Vector2(side * 18.0, 6.0), 14.5, "hadal", side > 0.0)
	for i in range(5):
		var point := c + Vector2(-37.0 + float(i) * 19.0, -48.0 - absf(2.0 - float(i)) * 6.0)
		_rock(point, Vector3(7.5, 32.0 + float(i % 2) * 9.0, 9.5), "hadal", float(i) * 0.5, true)
	for point: Vector2 in [Vector2(-20, 9), Vector2(24, -8), Vector2(-14, -22), Vector2(15, -24)]:
		_asset("crystal_spire", Vector3(c.x + point.x, _height(c + point), c.y + point.y), Vector3.ONE * 3.0, "hadal", point.x * 0.1)
	_shoal(c + Vector2(0, -4), "hadal", 24.0, 24.0)
	var light := OmniLight3D.new()
	light.name = "SanctumPearlLight"
	light.position = Vector3(c.x, _height(c) + 17.0, c.y - 22.0)
	light.light_color = Color("8ee0f6")
	light.light_energy = 3.9
	light.omni_range = 54.0
	light.set_meta("authored_light", true)
	add_child(light)

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
	var sides := 11
	var vertices: Array[Vector3] = []
	for level in range(5):
		var radius: float = [1.02, 0.96, 0.84, 0.75, 0.60][level]
		var y: float = [0.0, 0.28, 0.56, 0.84, 0.98][level]
		var shift := Vector2(0.03 * float(level), -0.02 * float(level))
		for i in range(sides):
			var angle := float(i) / float(sides) * TAU + float(level) * 0.08
			var jag := 1.0 + sin(float(i) * 2.3 + 0.4) * 0.13 + cos(float(i) * 3.7 - float(level)) * 0.07
			var r := radius * jag
			vertices.append(Vector3(cos(angle) * r + shift.x, y, sin(angle) * r + shift.y))
	for level in range(4):
		for i in range(sides):
			var a := level * sides + i
			var b := level * sides + (i + 1) % sides
			for index: int in [a, b, a + sides, b, b + sides, a + sides]:
				surface.add_vertex(vertices[index])
	var top_base := 4 * sides
	var apex := Vector3(0.05, 1.0, -0.04)
	for i in range(sides):
		surface.add_vertex(vertices[top_base + i])
		surface.add_vertex(vertices[top_base + (i + 1) % sides])
		surface.add_vertex(apex)
	surface.generate_normals()
	return surface.commit()

func _make_spire() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 8
	var vertices: Array[Vector3] = []
	for level in range(5):
		var radius: float = [1.0, 0.86, 0.66, 0.45, 0.22][level]
		var y: float = [0.0, 0.24, 0.54, 0.80, 0.94][level]
		var lean := Vector2(0.07 * float(level) / 4.0, -0.05 * float(level) / 4.0)
		for i in range(sides):
			var angle := float(i) / float(sides) * TAU + float(level) * 0.14
			var flute := 1.0 + sin(float(i) * 3.0 + 0.7) * 0.16 + cos(float(i) * 2.0 + float(level)) * 0.09
			var crest := y + (0.04 * sin(float(i) * 2.0) if level == 4 else 0.0)
			vertices.append(Vector3(cos(angle) * radius * flute + lean.x, crest, sin(angle) * radius * flute + lean.y))
	for level in range(4):
		for i in range(sides):
			var a := level * sides + i
			var b := level * sides + (i + 1) % sides
			for index: int in [a, b, a + sides, b, b + sides, a + sides]:
				surface.add_vertex(vertices[index])
	var top_base := 4 * sides
	var peak := Vector3(0.07, 1.0, -0.05)
	for i in range(sides):
		surface.add_vertex(vertices[top_base + i])
		surface.add_vertex(vertices[top_base + (i + 1) % sides])
		surface.add_vertex(peak)
	surface.generate_normals()
	return surface.commit()

func _fish_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var points := [Vector3(0, 0, 0.55), Vector3(-0.13, 0, 0.05), Vector3(0, 0.18, 0.05), Vector3(0.13, 0, 0.05), Vector3(0, -0.10, 0.05), Vector3(0, 0, -0.42), Vector3(0, 0.23, -0.62), Vector3(0, -0.20, -0.62)]
	for index: int in [0,2,1, 0,3,2, 0,4,3, 0,1,4, 5,1,2, 5,2,3, 5,3,4, 5,4,1, 5,6,7]:
		surface.add_vertex(points[index])
	surface.generate_normals()
	return surface.commit()
