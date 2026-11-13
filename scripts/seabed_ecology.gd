extends Node3D

# Decorative benthos is streamed independently of the gameplay RNG and colliders.
# A chunk holds a few detailed colonies plus inexpensive instanced ground cover.
const CHUNK_SIZE := 48.0
const CHUNK_RADIUS := 2
const MAX_CHUNKS := 25
const WORLD_HALF_EXTENT := 900.0
const WORLD_SEED := 381193
const MAX_INSTANCES_PER_CHUNK := 128
const MAX_FISH_PER_CHUNK := 8
const OceanDepths := preload("res://scripts/ocean_depths.gd")
const ArtDirection := preload("res://scripts/art_direction.gd")
const PLANT_SHADER := preload("res://shaders/plant_sway.gdshader")
const FISH_SHADER := preload("res://shaders/ecosystem_fish.gdshader")

var _ocean: Node3D
var _chunks: Dictionary = {}
var _pending: Array[Vector2i] = []
var _asset_parts: Dictionary = {}
var _asset_bounds: Dictionary = {}
var _rock_support_points: Dictionary = {}
var _observer := Vector3(0, -9, 17)
var _center := Vector2i(100000, 100000)
var _exclusion_zones: Array[Vector3] = []
var _patch_noise := FastNoiseLite.new()
var _ambient_creature_meshes: Dictionary = {}
var _material_cache: Dictionary = {}
var _pending_ambient: Array[Vector2i] = []
var _observer_depth_band := 0
var _observer_water_zone := "sunlit_reef"

func configure(ocean: Node3D) -> void:
	_ocean = ocean
	name = "SeabedEcology"
	_patch_noise.seed = WORLD_SEED
	_patch_noise.frequency = 0.024
	_patch_noise.fractal_octaves = 2
	_collect_exclusion_zones()
	_request_neighborhood(_observer)
	# Fill the starting view before the first rendered frame. The outer ring is
	# finished incrementally while the player is swimming.
	for index in range(mini(9, _pending.size())):
		_build_chunk(_pending.pop_front())

func update_observer(world_position: Vector3, _delta: float) -> void:
	if not is_instance_valid(_ocean):
		return
	_observer = world_position
	var cell := Vector2i(floori(world_position.x / CHUNK_SIZE), floori(world_position.z / CHUNK_SIZE))
	if cell != _center:
		_request_neighborhood(world_position)
	var depth_band := floori(maxf(-world_position.y, 0.0) / 25.0)
	var water_zone: String = OceanDepths.zone_id(maxf(-world_position.y, 0.0))
	if depth_band != _observer_depth_band or water_zone != _observer_water_zone:
		_observer_depth_band = depth_band
		_observer_water_zone = water_zone
		_pending_ambient.assign(_chunks.keys())
		_pending_ambient.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			return (a - _center).length_squared() < (b - _center).length_squared()
		)
	if not _pending.is_empty():
		_build_chunk(_pending.pop_front())
	if not _pending_ambient.is_empty():
		var refresh_cell: Vector2i = _pending_ambient.pop_front()
		if _chunks.has(refresh_cell):
			_build_ambient_shoal(_chunks[refresh_cell], refresh_cell)

func _request_neighborhood(at: Vector3) -> void:
	_center = Vector2i(floori(at.x / CHUNK_SIZE), floori(at.z / CHUNK_SIZE))
	var wanted: Dictionary = {}
	_pending.clear()
	for dx in range(-CHUNK_RADIUS, CHUNK_RADIUS + 1):
		for dz in range(-CHUNK_RADIUS, CHUNK_RADIUS + 1):
			var cell := _center + Vector2i(dx, dz)
			var origin := Vector2(cell.x, cell.y) * CHUNK_SIZE
			if origin.x >= WORLD_HALF_EXTENT or origin.x + CHUNK_SIZE <= -WORLD_HALF_EXTENT:
				continue
			if origin.y >= WORLD_HALF_EXTENT or origin.y + CHUNK_SIZE <= -WORLD_HALF_EXTENT:
				continue
			wanted[cell] = true
			if not _chunks.has(cell):
				_pending.append(cell)
	for cell: Vector2i in _chunks.keys():
		if not wanted.has(cell):
			var old: Node3D = _chunks[cell]
			remove_child(old)
			old.queue_free()
			_chunks.erase(cell)
	_pending.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (Vector2(a) + Vector2.ONE * 0.5 - Vector2(_center)).length_squared() < (Vector2(b) + Vector2.ONE * 0.5 - Vector2(_center)).length_squared()
	)

func _collect_exclusion_zones() -> void:
	_exclusion_zones.append(Vector3(0, 8, 7.0))
	for property_name: String in ["outposts", "explorer_relics"]:
		var nodes: Array = _ocean.get(property_name)
		for item: Node3D in nodes:
			var radius := 8.0 if property_name == "outposts" else 3.0
			_exclusion_zones.append(Vector3(item.position.x, item.position.z, radius))
	var composition := _ocean.get_node_or_null("OceanComposition")
	if composition != null:
		for node: Node in composition.get_children():
			if node is StaticBody3D:
				var pos: Vector3 = node.position
				var radius := float(node.get_meta("ecology_clearance", maxf(node.scale.x, node.scale.z) * 1.05))
				_exclusion_zones.append(Vector3(pos.x, pos.z, radius))
	var tree: Node3D = _ocean.get("mother_tree")
	if is_instance_valid(tree):
		_exclusion_zones.append(Vector3(tree.position.x, tree.position.z, 14.0))

func _is_reserved(x: float, z: float, clearance: float = 0.0) -> bool:
	for zone in _exclusion_zones:
		if Vector2(x - zone.x, z - zone.y).length_squared() < pow(zone.z + clearance, 2.0):
			return true
	return false

# Sample the actual rendered triangle, including the coarser outer seabed.
# Merely sampling the analytic floor leaves small decorations floating above it.
func sample_floor_height(x: float, z: float) -> float:
	return float(_ocean.call("terrain_height", x, z))

func _floor_normal(x: float, z: float) -> Vector3:
	var left := sample_floor_height(x - 0.4, z)
	var right := sample_floor_height(x + 0.4, z)
	var back := sample_floor_height(x, z - 0.4)
	var front := sample_floor_height(x, z + 0.4)
	return Vector3(left - right, 0.8, back - front).normalized()

func sample_habitat(x: float, z: float) -> Dictionary:
	var depth := maxf(0.0, -sample_floor_height(x, z))
	var slope := 1.0 - _floor_normal(x, z).y
	var depth_zone := OceanDepths.zone_id(depth)
	var biome: String = depth_zone
	var patch := _patch_noise.get_noise_2d(x, z)
	var caldera_distance := Vector2(x + 440.0, z + 420.0).length()
	var kelp_distance := Vector2(x + 260.0, z - 280.0).length()
	if caldera_distance < 180.0 and depth > 90.0:
		biome = "vent_field"
	elif depth <= 55.0 and (kelp_distance < 190.0 or patch > 0.34):
		biome = "kelp_forest"
	return {"biome": biome, "depth_zone": depth_zone, "depth": depth, "slope": slope, "region": ArtDirection.region_id_at(x, z)}

# A broad, world-continuous sand channel creates negative space across chunk
# seams. It is scenery only: neither terrain nor gameplay collision is changed.
func _is_sand_channel(xz: Vector2) -> bool:
	var flow := xz.x * 0.021 + xz.y * 0.012 + sin(xz.y * 0.008) * 1.2
	return absf(sin(flow)) < 0.28

func build_chunk_plan(cell: Vector2i) -> Array[Dictionary]:
	var plan: Array[Dictionary] = []
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = WORLD_SEED + cell.x * 73856093 + cell.y * 19349663
	var origin := Vector2(cell) * CHUNK_SIZE
	# Each patch is a little composition: one strong geological form, a lower
	# satellite and colonies attached to their shoulders. Hierarchy replaces the
	# previous evenly scattered rocks and same-sized plants without more draws.
	for cluster in range(2):
		var center := origin + Vector2(12.0 + float(cluster % 2) * 21.0, 12.0 + floorf(float(cluster) * 0.5) * 22.0)
		center += Vector2(local_rng.randf_range(-4, 4), local_rng.randf_range(-4, 4))
		if _is_sand_channel(center):
			center.x += 7.0
		var center_habitat := sample_habitat(center.x, center.y)
		var depth := float(center_habitat["depth"])
		var yaw := local_rng.randf() * TAU
		var direction := Vector2(cos(yaw), sin(yaw))
		var size := local_rng.randf_range(1.5, 2.3) * (1.5 if cluster == 0 else 0.85)
		var rock_kind := "limestone_boulder"
		var rock_scale := Vector3(size * 1.7, size * 0.85, size * 1.2)
		match str(center_habitat["depth_zone"]):
			"shelf_garden":
				rock_kind = "shelf_ledge_boulder"
				rock_scale = Vector3(size * 2.0, size * 0.65, size * 1.25)
			"twilight_slope":
				rock_kind = "escarpment_boulder"
				rock_scale = Vector3(size * 1.2, size * 2.2, size * 0.9)
			"bathyal_basin":
				rock_kind = "silt_boulder"
				rock_scale = Vector3(size * 1.7, size * 0.85, size * 1.3)
			"hadal_trench":
				rock_kind = "trench_spire_boulder"
				rock_scale = Vector3(size * 0.9, size * 2.9, size * 0.8)
		if str(center_habitat["biome"]) == "vent_field":
			rock_kind = "vent_chimney" if cluster == 0 else "basalt_boulder"
			rock_scale = Vector3(size * 0.65, size * 0.85, size * 0.65)
		if not _is_sand_channel(center):
			_add_to_plan(plan, rock_kind, center, rock_scale, yaw)
		var satellite := center + direction * size * 1.6
		if not _is_sand_channel(satellite):
			_add_to_plan(plan, "limestone_boulder" if depth < 90.0 else "silt_boulder", satellite, rock_scale * Vector3(0.42, 0.45, 0.65), yaw + 0.35)
		var colony_count := 5 if depth < 200.0 else (3 if depth < 360.0 else 2)
		if str(center_habitat["biome"]) == "kelp_forest":
			colony_count = 8
		var dominant := _choose_colony(str(center_habitat["biome"]), local_rng)
		if str(center_habitat["biome"]) == "kelp_forest":
			dominant = "kelp"
		for index in range(colony_count):
			var angle := yaw + float(index) * 0.68 - 1.7 + local_rng.randf_range(-0.15, 0.15)
			var offset := Vector2(cos(angle), sin(angle)) * (size * 1.7 + local_rng.randf_range(0.8, 2.6))
			var p := center + offset
			if _is_sand_channel(p):
				continue
			var habitat := sample_habitat(p.x, p.y)
			var asset := dominant if index % 3 != 2 and str(habitat["biome"]) == str(center_habitat["biome"]) else _choose_colony(str(habitat["biome"]), local_rng)
			var max_slope := 0.78 if asset == "cold_water_coral" else 0.50
			if float(habitat["slope"]) > max_slope:
				continue
			var colony_size := local_rng.randf_range(0.8, 1.1) * (1.6 if index < 2 else (0.85 if index < 4 else 0.48))
			var shape := Vector3.ONE * colony_size
			if asset == "cold_water_coral":
				shape *= local_rng.randf_range(1.15, 1.65)
			elif asset == "glass_sponge":
				shape *= local_rng.randf_range(1.2, 1.8)
			elif asset == "sea_pen":
				shape *= local_rng.randf_range(0.85, 1.6)
			if asset == "kelp":
				shape = Vector3(colony_size * 1.08, colony_size * local_rng.randf_range(1.75, 2.55), colony_size * 1.08)
				# Kelp never pierces the water surface.
				shape.y = minf(shape.y, (float(habitat["depth"]) - 1.5) / 5.2)
			_add_to_plan(plan, asset, p, shape, yaw + local_rng.randf_range(-0.5, 0.5))
		# Low-cost blades form the understory only where photosynthesis is possible.
		for index in range(7):
			# Understory follows the colony's shoulder as one crescent-shaped patch;
			# it no longer peppers each exposed sand square with separate tufts.
			var angle := yaw - 1.1 + float(index) * 0.34
			var drift_radius := size * 2.3 + local_rng.randf_range(-1.1, 1.1)
			var p := center + Vector2(cos(angle), sin(angle)) * drift_radius
			var habitat := sample_habitat(p.x, p.y)
			if float(habitat["depth"]) > 35.0 or float(habitat["slope"]) > 0.32 or _is_sand_channel(p):
				continue
			var blade_scale := local_rng.randf_range(0.8, 1.45)
			_add_to_plan(plan, "seagrass", p, Vector3(blade_scale, blade_scale * local_rng.randf_range(0.85, 1.3), blade_scale), local_rng.randf() * TAU)
	# Pebble drifts and shell hash remain visible across all depth bands, including
	# map edges. Drift noise leaves rippled sand exposed between the patches.
	for index in range(18):
		var p := origin + Vector2(local_rng.randf_range(1.0, 47.0), local_rng.randf_range(1.0, 47.0))
		if _is_sand_channel(p) and index % 4 != 0:
			continue
		var drift := _patch_noise.get_noise_2d(p.x * 2.1, p.y * 2.1)
		if drift < -0.22 and index > 10:
			continue
		var size := local_rng.randf_range(0.45, 1.8)
		var asset := "shell" if index % 5 == 0 else "pebble"
		_add_to_plan(plan, asset, p, Vector3(size * local_rng.randf_range(0.8, 1.8), size * 0.7, size), local_rng.randf() * TAU)
	return plan

func _choose_colony(biome: String, local_rng: RandomNumberGenerator) -> String:
	var options: Array
	match biome:
		"sunlit_reef":
			options = ["brain_coral", "staghorn_coral", "table_coral", "barrel_sponge", "coral", "starfish_urchin"]
		"kelp_forest":
			options = ["kelp", "kelp", "kelp", "barrel_sponge", "starfish_urchin"]
		"shelf_garden":
			options = ["sea_fan", "barrel_sponge", "sea_fan", "sea_lily", "starfish_urchin"]
		"twilight_slope":
			options = ["cold_water_coral", "cold_water_coral", "sea_fan", "glass_sponge", "sea_lily"]
		"bathyal_basin":
			options = ["glass_sponge", "glass_sponge", "sea_pen", "sea_lily", "silt_boulder"]
		"hadal_trench":
			options = ["sea_cucumber", "sea_pen", "silt_boulder", "silt_boulder", "sea_cucumber"]
		"vent_field":
			options = ["tubeworms", "tubeworms", "basalt_boulder", "barrel_sponge", "basalt_boulder"]
		_:
			options = ["glass_sponge", "sea_pen", "silt_boulder", "sea_lily"]
	return str(options[local_rng.randi_range(0, options.size() - 1)])

func _add_to_plan(plan: Array[Dictionary], asset: String, xz: Vector2, size: Vector3, yaw: float) -> void:
	if plan.size() >= MAX_INSTANCES_PER_CHUNK or absf(xz.x) > WORLD_HALF_EXTENT or absf(xz.y) > WORLD_HALF_EXTENT:
		return
	var clearance := maxf(size.x, size.z) * 1.15 if asset.ends_with("_boulder") or asset == "vent_chimney" else 0.0
	if _is_reserved(xz.x, xz.y, clearance):
		return
	var habitat := sample_habitat(xz.x, xz.y)
	plan.append({
		"asset": asset, "position": Vector3(xz.x, sample_floor_height(xz.x, xz.y), xz.y),
		"scale": size, "yaw": yaw, "normal": _floor_normal(xz.x, xz.y), "biome": str(habitat["biome"]), "depth_zone": str(habitat["depth_zone"]), "region": str(habitat["region"])
	})

func _build_chunk(cell: Vector2i) -> void:
	if _chunks.has(cell):
		return
	var plan := build_chunk_plan(cell)
	var chunk := Node3D.new()
	chunk.name = "Benthos_%d_%d" % [cell.x, cell.y]
	chunk.position = Vector3(float(cell.x) * CHUNK_SIZE, 0, float(cell.y) * CHUNK_SIZE)
	add_child(chunk)
	_chunks[cell] = chunk
	chunk.set_meta("instance_count", plan.size())
	var by_asset: Dictionary = {}
	var biomes: Dictionary = {}
	var zones: Dictionary = {}
	for entry in plan:
		var asset: String = entry["asset"]
		if not by_asset.has(asset):
			by_asset[asset] = []
		by_asset[asset].append(entry)
		biomes[entry["biome"]] = int(biomes.get(entry["biome"], 0)) + 1
		zones[entry["depth_zone"]] = int(zones.get(entry["depth_zone"], 0)) + 1
	chunk.set_meta("biomes", biomes)
	chunk.set_meta("depth_zones", zones)
	for asset: String in by_asset:
		_load_asset(asset)
		var records: Array = by_asset[asset]
		for part: Dictionary in _asset_parts.get(asset, []):
			var batch := MultiMeshInstance3D.new()
			batch.name = asset
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = part["mesh"]
			mm.instance_count = records.size()
			var bounds: AABB = _asset_bounds[asset]
			var animated_bounds := AABB()
			for index in range(records.size()):
				var record: Dictionary = records[index]
				var normal: Vector3 = record["normal"]
				var alignment := 0.85 if asset in ["rock", "pebble", "shell", "seagrass"] or asset.ends_with("_boulder") else 0.35
				if asset in ["escarpment_boulder", "trench_spire_boulder", "vent_chimney"]:
					alignment = 0.18
				elif asset == "cold_water_coral":
					alignment = 0.58
				var up := Vector3.UP.slerp(normal, alignment).normalized()
				var yaw: float = record["yaw"]
				var right := up.cross(Vector3(sin(yaw), 0, cos(yaw))).normalized()
				var forward := right.cross(up).normalized()
				var size: Vector3 = record["scale"]
				var basis := Basis(right * size.x, up * size.y, forward * size.z)
				var position: Vector3 = record["position"] - chunk.position
				# The exported meshes have different origins; place their actual
				# lower bound into the ground, rather than their scene origin.
				position -= up * bounds.position.y * size.y
				position -= up * (0.16 if asset == "rock" or asset.ends_with("_boulder") else 0.025)
				if _rock_support_points.has(asset):
					# A near-vertical pillar on sloping ground needs its whole base
					# buried, not just its center. Test the actual lowest vertex ring
					# after rotation/scaling so the downhill edge cannot float.
					var exposed_base := 0.0
					for support: Vector3 in _rock_support_points[asset]:
						var world_support := basis * support + position + chunk.position
						exposed_base = maxf(exposed_base, world_support.y - sample_floor_height(world_support.x, world_support.z))
					if exposed_base > 0.0:
						position.y -= exposed_base + 0.06
				var instance_transform: Transform3D = Transform3D(basis, position) * part["transform"]
				mm.set_instance_transform(index, instance_transform)
				var profile := ArtDirection.region_profile(str(record["region"]))
				var variation := 0.94 + 0.10 * (0.5 + 0.5 * sin(float(record["position"].x) * 1.37 + float(record["position"].z) * 0.73))
				var tint := Color.WHITE.lerp(profile["flora"], 0.07 if asset in ["kelp", "seagrass", "sea_lily"] else 0.025)
				mm.set_instance_color(index, Color(tint.r * variation, tint.g * variation, tint.b * variation, 1.0))
				var part_mesh: Mesh = part["mesh"]
				var envelope := (instance_transform * part_mesh.get_aabb()).grow(2.5)
				animated_bounds = envelope if index == 0 else animated_bounds.merge(envelope)
			mm.custom_aabb = animated_bounds
			batch.multimesh = mm
			batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			batch.visibility_range_end = 130.0 if asset == "rock" or asset.ends_with("_boulder") or asset == "vent_chimney" else (64.0 if asset in ["seagrass", "shell", "pebble"] else 88.0)
			batch.visibility_range_end_margin = 6.0
			chunk.add_child(batch)
	_build_ambient_shoal(chunk, cell)

func _load_asset(asset: String) -> void:
	if _asset_parts.has(asset):
		return
	if asset in ["pebble", "shell", "seagrass", "cold_water_coral", "glass_sponge", "sea_pen", "sea_cucumber", "vent_chimney"] or asset.ends_with("_boulder"):
		_create_groundcover_asset(asset)
		return
	var scene: PackedScene = load("res://assets/models/" + asset + ".glb")
	if scene == null:
		_asset_parts[asset] = []
		return
	var instance: Node3D = scene.instantiate()
	var parts: Array[Dictionary] = []
	var bounds := AABB()
	var has_bounds := false
	var meshes := instance.find_children("*", "MeshInstance3D", true, false)
	if instance is MeshInstance3D:
		meshes.append(instance)
	for child: MeshInstance3D in meshes:
		if child.mesh == null:
			continue
		var local_transform := child.transform
		var parent := child.get_parent()
		while parent != null and parent != instance.get_parent():
			if parent is Node3D:
				local_transform = parent.transform * local_transform
			parent = parent.get_parent()
		var mesh: Mesh = child.mesh.duplicate()
		for surface in range(mesh.get_surface_count()):
			var source := child.get_active_material(surface)
			mesh.surface_set_material(surface, _natural_material(source, asset))
		parts.append({"mesh": mesh, "transform": local_transform})
		var part_bounds: AABB = local_transform * mesh.get_aabb()
		bounds = bounds.merge(part_bounds) if has_bounds else part_bounds
		has_bounds = true
	_asset_parts[asset] = parts
	_asset_bounds[asset] = bounds
	_cache_rock_support_points(asset)
	instance.free()

func _cache_rock_support_points(asset: String) -> void:
	if asset != "rock" and asset != "vent_chimney" and not asset.ends_with("_boulder"):
		return
	var bounds: AABB = _asset_bounds[asset]
	var bottom_band := bounds.position.y + maxf(0.015, bounds.size.y * 0.005)
	var unique: Dictionary = {}
	for part: Dictionary in _asset_parts[asset]:
		var mesh: Mesh = part["mesh"]
		var local_transform: Transform3D = part["transform"]
		for surface in range(mesh.get_surface_count()):
			var arrays := mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				var support := local_transform * vertex
				if support.y <= bottom_band:
					unique[support] = true
	_rock_support_points[asset] = unique.keys()

func _natural_material(source: Material, asset: String) -> ShaderMaterial:
	var cache_key := asset + ":" + str(source.get_instance_id() if source != null else 0)
	if _material_cache.has(cache_key):
		return _material_cache[cache_key]
	var material := ShaderMaterial.new()
	material.shader = PLANT_SHADER
	var profile := ArtDirection.material_profile(asset)
	material.set_shader_parameter("sway_strength", 0.22 if asset in ["kelp", "sea_fan", "sea_lily", "seagrass", "sea_pen"] else 0.0)
	material.set_shader_parameter("sway_frequency", 0.72)
	material.set_shader_parameter("emission_energy", 0.0)
	material.set_shader_parameter("roughness", float(profile["roughness"]))
	if source is BaseMaterial3D:
		var base: BaseMaterial3D = source
		material.set_shader_parameter("albedo", base.albedo_color)
		material.set_shader_parameter("roughness", float(profile["roughness"]))
		material.set_shader_parameter("metallic", 0.0)
		material.set_shader_parameter("albedo_texture", base.albedo_texture)
		material.set_shader_parameter("normal_texture", base.normal_texture)
		material.set_shader_parameter("normal_scale", base.normal_scale * 0.88)
		material.set_shader_parameter("orm_texture", base.roughness_texture)
		material.set_shader_parameter("uv_scale", base.uv1_scale)
		material.set_shader_parameter("uv_offset", base.uv1_offset)
		if _ocean.has_method("configure_natural_palette"):
			_ocean.call("configure_natural_palette", material, asset)
	_material_cache[cache_key] = material
	return material

func _create_groundcover_asset(asset: String) -> void:
	var mesh: Mesh
	var color := Color(0.34, 0.33, 0.29)
	if asset == "seagrass":
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		# Each instance is a small meadow, not a barely visible tuft of needles.
		# Only three segments per blade keeps this below 250 triangles per patch.
		for blade in range(40):
			var angle := float(blade) * 2.39996
			var spread := sqrt((float(blade) + 0.5) / 40.0) * 1.35
			var offset := Vector3(cos(angle) * spread, 0, sin(angle) * spread)
			var sideways := Vector3(cos(angle), 0, sin(angle)) * (0.055 + float(blade % 3) * 0.012)
			var height := 0.58 + float(blade % 5) * 0.12
			for segment in range(3):
				var t0 := float(segment) / 3.0
				var t1 := float(segment + 1) / 3.0
				var bend := Vector3(cos(angle + 0.8), 0, sin(angle + 0.8)) * 0.28
				var a := offset + bend * t0 * t0 + Vector3.UP * height * t0
				var b := offset + bend * t1 * t1 + Vector3.UP * height * t1
				var points := [a - sideways * (1.0 - t0 * 0.7), a + sideways * (1.0 - t0 * 0.7), b - sideways * (1.0 - t1 * 0.7), b + sideways * (1.0 - t1 * 0.7)]
				for index in [0, 1, 2, 1, 3, 2]:
					surface.set_color(Color(0.64, 0.72, 0.48).lerp(Color(1.0, 1.0, 0.90), t0 if index < 2 else t1))
					surface.add_vertex(points[index])
		surface.generate_normals()
		mesh = surface.commit()
		color = Color("899d60")
	elif asset == "cold_water_coral":
		mesh = _create_cold_water_coral_mesh()
		color = Color("d6bdad")
	elif asset == "glass_sponge":
		mesh = _create_glass_sponge_mesh()
		color = Color("a3bec1")
	elif asset == "sea_pen":
		mesh = _create_sea_pen_mesh()
		color = Color("b48b8b")
	elif asset == "sea_cucumber":
		mesh = _create_ellipsoid_mesh(Vector3(0.18, 0.12, 0.75))
		color = Color("736d65")
	elif asset == "vent_chimney":
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		_append_tube(surface, Vector3.ZERO, Vector3(0.12, 4.0, 0.04), 0.72, 0.45, 8)
		_append_tube(surface, Vector3(0.48, 0, 0.15), Vector3(0.66, 2.7, 0.16), 0.34, 0.22, 7)
		surface.generate_normals()
		mesh = surface.commit()
	elif asset.ends_with("_boulder"):
		mesh = _create_boulder_mesh()
		match asset:
			"limestone_boulder": color = Color(0.57, 0.55, 0.46)
			"silt_boulder": color = Color(0.34, 0.35, 0.32)
			_: color = Color(0.20, 0.21, 0.20)
	else:
		var stone := SphereMesh.new()
		stone.radial_segments = 8
		stone.rings = 3
		stone.radius = 0.24 if asset == "pebble" else 0.17
		stone.height = 0.26 if asset == "pebble" else 0.07
		mesh = stone
		if asset == "shell":
			color = Color(0.59, 0.57, 0.46)
	var material: Material
	if asset.ends_with("_boulder") or asset == "vent_chimney":
		# Reuse world-space sediment, strata and bump detail so reef boulders
		# weather into the same geology as the seabed rather than smooth plaster.
		var seabed: MeshInstance3D = _ocean.get_node("Seabed")
		material = seabed.material_override
	else:
		var cover_material := _natural_material(null, asset)
		cover_material.set_shader_parameter("albedo", color)
		cover_material.set_shader_parameter("roughness", 0.94)
		material = cover_material
	if mesh is ArrayMesh:
		mesh.surface_set_material(0, material)
	elif mesh is PrimitiveMesh:
		mesh.material = material
	_asset_parts[asset] = [{"mesh": mesh, "transform": Transform3D.IDENTITY}]
	_asset_bounds[asset] = mesh.get_aabb()
	_cache_rock_support_points(asset)

func _append_tube(surface: SurfaceTool, start: Vector3, end: Vector3, bottom_radius: float, top_radius: float, sides: int = 6) -> void:
	var direction := (end - start).normalized()
	var tangent := direction.cross(Vector3.FORWARD if absf(direction.z) < 0.85 else Vector3.UP).normalized()
	var bitangent := tangent.cross(direction).normalized()
	var tube := CylinderMesh.new()
	tube.height = start.distance_to(end)
	tube.bottom_radius = bottom_radius
	tube.top_radius = top_radius
	tube.radial_segments = sides
	tube.rings = 1
	tube.cap_top = false
	tube.cap_bottom = false
	var arrays := tube.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var basis := Basis(tangent, direction, bitangent)
	var midpoint := (start + end) * 0.5
	for index in indices:
		surface.add_vertex(basis * vertices[index] + midpoint)

func _create_cold_water_coral_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for stem in range(3):
		var angle := float(stem) * 2.4
		var sideways := Vector3(cos(angle), 0, sin(angle))
		var base := sideways * 0.16
		var tip := base + Vector3(0.08 * sin(angle), 1.35 + float(stem) * 0.18, 0)
		_append_tube(surface, base, tip, 0.038, 0.012)
		for level in range(4):
			var anchor := base.lerp(tip, 0.30 + float(level) * 0.17)
			for side: float in [-1.0, 1.0]:
				var endpoint := anchor + sideways * side * (0.50 - float(level) * 0.07) + Vector3.UP * 0.22
				_append_tube(surface, anchor, endpoint, 0.023, 0.009)
				for twig in range(2):
					var twig_start := anchor.lerp(endpoint, 0.48 + float(twig) * 0.32)
					var twig_end := twig_start + sideways * side * 0.16 + Vector3.UP * (0.18 + float(twig) * 0.06)
					_append_tube(surface, twig_start, twig_end, 0.012, 0.004, 5)
	surface.generate_normals()
	return surface.commit()

func _create_glass_sponge_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(5):
		var angle := float(index) * 2.39996
		var base := Vector3(cos(angle) * 0.38, 0, sin(angle) * 0.38)
		var height := 1.2 + float(index % 3) * 0.32
		_append_tube(surface, base, base + Vector3(0.10 * cos(angle), height, 0.10 * sin(angle)), 0.095, 0.21, 8)
	surface.generate_normals()
	return surface.commit()

func _create_sea_pen_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	_append_tube(surface, Vector3.ZERO, Vector3(0.08, 1.85, 0), 0.035, 0.012)
	for index in range(9):
		var height := 0.42 + float(index) * 0.155
		var width := 0.44 * (1.0 - pow((height - 0.9) / 1.25, 2.0))
		for side: float in [-1.0, 1.0]:
			_append_tube(surface, Vector3(0.04, height, 0), Vector3(side * width, height + 0.16, 0.035 * sin(float(index))), 0.016, 0.008, 5)
	surface.generate_normals()
	return surface.commit()

func _create_ellipsoid_mesh(shape: Vector3) -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 10
	sphere.rings = 5
	var arrays := sphere.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in indices:
		var v := vertices[index]
		v *= 1.0 + sin(v.x * 9.0 + v.z * 7.0) * 0.045
		surface.add_vertex(v * shape)
	surface.generate_normals()
	return surface.commit()

func _create_boulder_mesh() -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	var arrays := sphere.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in indices:
		var v := vertices[index]
		# Smooth coordinate noise is continuous across the sphere's UV seam.
		var n := sin(v.x * 4.7 + v.z * 3.1) * 0.095 + cos(v.y * 5.3 - v.x * 2.8) * 0.075
		v *= 1.0 + n
		v.y = maxf(-0.70, v.y * 0.90)
		surface.set_uv(uvs[index])
		surface.add_vertex(v)
	surface.generate_normals()
	return surface.commit()

func _build_ambient_shoal(chunk: Node3D, cell: Vector2i) -> void:
	var old: Node3D = chunk.get_node_or_null("AmbientWaterColumn")
	if old != null:
		chunk.remove_child(old)
		old.queue_free()
	var column := Node3D.new()
	column.name = "AmbientWaterColumn"
	chunk.add_child(column)
	var community := sample_ambient_community(cell)
	var by_species: Dictionary = {}
	var species_counts: Dictionary = {}
	for creature in community:
		var species: String = creature["species"]
		if not by_species.has(species):
			by_species[species] = []
		by_species[species].append(creature)
		species_counts[species] = int(species_counts.get(species, 0)) + 1
	for species: String in by_species:
		if not _ambient_creature_meshes.has(species):
			_ambient_creature_meshes[species] = _create_ambient_creature_mesh(species)
		var records: Array = by_species[species]
		var batch := MultiMeshInstance3D.new()
		batch.name = "Ambient_" + species
		batch.set_meta("species", species)
		batch.set_meta("depth_zone", str(records[0]["depth_zone"]))
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.use_colors = true
		mm.mesh = _ambient_creature_meshes[species]
		mm.instance_count = records.size()
		var bounds := AABB()
		for index in range(records.size()):
			var record: Dictionary = records[index]
			var size: float = record["size"]
			var at: Vector3 = record["position"] - chunk.position
			var basis := Basis(Vector3.UP, float(record["yaw"])).scaled(Vector3.ONE * size)
			mm.set_instance_transform(index, Transform3D(basis, at))
			mm.set_instance_custom_data(index, Color(float(record["phase"]), float(record["lane"]), fposmod(float(index) * 0.17, 1.0), 1.0))
			var tint := Color.WHITE
			if species == "silverside":
				var profile := ArtDirection.region_profile(ArtDirection.region_id_at(float(record["position"].x), float(record["position"].z)))
				tint = tint.lerp(profile["accent"], 0.12)
			mm.set_instance_color(index, tint)
			# A large squid includes the complete tentacle chain after its path and
			# instance scale; a fixed eight-metre radius clipped the largest ones.
			var horizontal := size * (5.2 if species == "squid" else 3.8) + 0.5
			var vertical := size * (1.9 if species in ["jellyfish", "abyss_jelly"] else 0.65) + 0.5
			var half_size := Vector3(horizontal, vertical, horizontal)
			var envelope := AABB(at - half_size, half_size * 2.0)
			bounds = bounds.merge(envelope) if index > 0 else envelope
		mm.custom_aabb = bounds
		batch.multimesh = mm
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		batch.visibility_range_end = 100.0
		column.add_child(batch)
	chunk.set_meta("ambient_fish_count", community.size())
	chunk.set_meta("ambient_species", species_counts)
	chunk.set_meta("ambient_depth_band", _observer_depth_band)

# Pelagic life follows the water layer the player actually visits. Seabed
# species stay attached to their habitat while these schools occupy the whole
# 600m water column, with a small fixed budget and deterministic depth bands.
func sample_ambient_community(cell: Vector2i, observer_depth: float = -1.0) -> Array[Dictionary]:
	var community: Array[Dictionary] = []
	var observed_depth := maxf(-_observer.y, 0.0) if observer_depth < 0.0 else maxf(observer_depth, 0.0)
	var band := floori(observed_depth / 25.0)
	var fish_rng := RandomNumberGenerator.new()
	fish_rng.seed = WORLD_SEED + 97531 + cell.x * 16127 + cell.y * 31337 + band * 17011
	var origin := Vector2(cell) * CHUNK_SIZE
	var center := origin + Vector2(fish_rng.randf_range(16, 32), fish_rng.randf_range(16, 32))
	var highest_floor := sample_floor_height(center.x, center.y)
	for index in range(8):
		var angle := float(index) * TAU / 8.0
		highest_floor = maxf(highest_floor, sample_floor_height(center.x + cos(angle) * 10.5, center.y + sin(angle) * 10.5))
	var available_depth := -highest_floor
	if available_depth <= 6.0:
		return community
	var water_depth := clampf(observed_depth, 2.2, available_depth - 4.0)
	if absf(water_depth - observed_depth) > 65.0:
		return community
	var zone: String = OceanDepths.zone_id(water_depth)
	var species_list: Array[String]
	match zone:
		"sunlit_reef":
			species_list = ["silverside", "silverside", "silverside", "silverside", "silverside", "silverside", "silverside", "silverside"]
		"shelf_garden":
			species_list = ["silverside", "silverside", "silverside", "silverside", "silverside", "silverside", "jellyfish", "jellyfish"]
		"twilight_slope":
			species_list = ["lanternfish", "lanternfish", "lanternfish", "lanternfish", "squid", "squid", "jellyfish", "jellyfish"]
		"bathyal_basin":
			species_list = ["lanternfish", "lanternfish", "squid", "squid", "squid", "jellyfish", "jellyfish"]
		_:
			species_list = ["lanternfish", "squid", "squid", "abyss_jelly", "abyss_jelly", "abyss_jelly"]
	var heading := fish_rng.randf() * TAU
	var phase := fish_rng.randf()
	for index in range(mini(MAX_FISH_PER_CHUNK, species_list.size())):
		var species := species_list[index]
		var offset := Vector2(fish_rng.randf_range(-3.5, 3.5), fish_rng.randf_range(-3.5, 3.5))
		var xz := center + offset
		if absf(xz.x) > WORLD_HALF_EXTENT - 6.0 or absf(xz.y) > WORLD_HALF_EXTENT - 6.0:
			continue
		var size := fish_rng.randf_range(0.65, 1.05)
		if species == "squid":
			size = fish_rng.randf_range(1.0, 1.45) if water_depth < 200.0 else fish_rng.randf_range(1.4, 2.0)
		elif species == "jellyfish":
			size = fish_rng.randf_range(0.7, 1.3)
		elif species == "abyss_jelly":
			size = fish_rng.randf_range(1.2, 1.75)
		var position := Vector3(xz.x, -water_depth, xz.y)
		community.append({"species": species, "position": position, "size": size,
			"yaw": heading + fish_rng.randf_range(-0.12, 0.12), "phase": phase + float(index) * 0.018 + fish_rng.randf_range(-0.012, 0.012),
			"lane": fish_rng.randf(), "depth_zone": zone})
	return community

func _create_ambient_creature_mesh(species: String) -> ArrayMesh:
	var mesh: ArrayMesh
	if species in ["silverside", "lanternfish"]:
		mesh = _create_ambient_fish_mesh(species == "lanternfish")
	elif species == "squid":
		mesh = _create_ambient_squid_mesh()
	else:
		mesh = _create_ambient_jelly_mesh(species == "abyss_jelly")
	var material := ShaderMaterial.new()
	material.shader = FISH_SHADER
	var kinds := {"silverside": 0, "lanternfish": 1, "squid": 2, "jellyfish": 3, "abyss_jelly": 4}
	material.set_shader_parameter("creature_kind", int(kinds[species]))
	mesh.surface_set_material(0, material)
	return mesh

func _create_ambient_fish_mesh(lantern: bool = false) -> ArrayMesh:
	var body := SphereMesh.new()
	body.radius = 1.0
	body.height = 2.0
	body.radial_segments = 8
	body.rings = 3
	var arrays := body.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in indices:
		var v := vertices[index]
		surface.add_vertex(v * (Vector3(0.17, 0.20, 0.42) if lantern else Vector3(0.11, 0.15, 0.39)))
	# Forked tail and dorsal fin are real geometry, rather than glowing sprites.
	for v: Vector3 in [
		Vector3(0, 0, -0.28), Vector3(0, 0.22, -0.63), Vector3(0, 0, -0.52),
		Vector3(0, 0, -0.28), Vector3(0, 0, -0.52), Vector3(0, -0.22, -0.63),
		Vector3(0, 0.11, 0.16), Vector3(0, 0.25, -0.10), Vector3(0, 0.11, -0.23)
	]:
		surface.add_vertex(v)
	surface.generate_normals()
	return surface.commit()

func _create_ambient_squid_mesh() -> ArrayMesh:
	var mantle := _create_ellipsoid_mesh(Vector3(0.20, 0.22, 0.62))
	var arrays := mantle.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for vertex in vertices:
		surface.add_vertex(vertex)
	for side: float in [-1.0, 1.0]:
		for vertex: Vector3 in [Vector3(side * 0.12, 0, 0.44), Vector3(side * 0.48, 0, 0.10), Vector3(side * 0.12, 0, -0.18)]:
			surface.add_vertex(vertex)
	for arm in range(8):
		var angle := float(arm) * TAU / 8.0
		var root := Vector3(cos(angle) * 0.10, sin(angle) * 0.10, -0.48)
		var middle := root + Vector3(cos(angle) * 0.10, sin(angle) * 0.10, -0.43)
		var tip := middle + Vector3(cos(angle) * 0.07, sin(angle) * 0.07, -0.34 - float(arm % 3) * 0.12)
		_append_tube(surface, root, middle, 0.024, 0.015, 5)
		_append_tube(surface, middle, tip, 0.015, 0.004, 5)
	surface.generate_normals()
	return surface.commit()

func _create_ambient_jelly_mesh(abyss: bool = false) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radius := 0.58 if abyss else 0.45
	for ring in range(5):
		var phi0 := float(ring) * PI * 0.53 / 5.0
		var phi1 := float(ring + 1) * PI * 0.53 / 5.0
		for segment in range(12):
			var a0 := float(segment) * TAU / 12.0
			var a1 := float(segment + 1) * TAU / 12.0
			var points := [Vector3(cos(a0) * sin(phi0) * radius, cos(phi0) * radius * 0.7, sin(a0) * sin(phi0) * radius),
				Vector3(cos(a1) * sin(phi0) * radius, cos(phi0) * radius * 0.7, sin(a1) * sin(phi0) * radius),
				Vector3(cos(a0) * sin(phi1) * radius, cos(phi1) * radius * 0.7, sin(a0) * sin(phi1) * radius),
				Vector3(cos(a1) * sin(phi1) * radius, cos(phi1) * radius * 0.7, sin(a1) * sin(phi1) * radius)]
			for index in [0, 1, 2, 1, 3, 2]:
				surface.add_vertex(points[index])
	for arm in range(6):
		var angle := float(arm) * TAU / 6.0
		var start := Vector3(cos(angle) * radius * 0.65, -0.04, sin(angle) * radius * 0.65)
		var middle := start + Vector3(0.08 * sin(angle), -0.55, 0.08 * cos(angle))
		var tip := middle + Vector3(0.12 * sin(angle), -0.78 if abyss else -0.42, 0.12 * cos(angle))
		_append_tube(surface, start, middle, 0.020, 0.013, 5)
		_append_tube(surface, middle, tip, 0.013, 0.004, 5)
	surface.generate_normals()
	return surface.commit()

func get_ecology_snapshot() -> Dictionary:
	var count := 0
	var fish_count := 0
	var biomes: Dictionary = {}
	var zones: Dictionary = {}
	var ambient_species: Dictionary = {}
	for chunk: Node3D in _chunks.values():
		count += int(chunk.get_meta("instance_count", 0))
		fish_count += int(chunk.get_meta("ambient_fish_count", 0))
		var species: Dictionary = chunk.get_meta("ambient_species", {})
		for key: String in species:
			ambient_species[key] = int(ambient_species.get(key, 0)) + int(species[key])
		var chunk_zones: Dictionary = chunk.get_meta("depth_zones", {})
		for key: String in chunk_zones:
			zones[key] = int(zones.get(key, 0)) + int(chunk_zones[key])
		var chunk_biomes: Dictionary = chunk.get_meta("biomes", {})
		for key: String in chunk_biomes:
			biomes[key] = int(biomes.get(key, 0)) + int(chunk_biomes[key])
	return {"active_chunks": _chunks.size(), "pending_chunks": _pending.size(), "instance_count": count,
		"ambient_fish_count": fish_count, "max_ambient_fish": MAX_CHUNKS * MAX_FISH_PER_CHUNK,
		"ambient_species": ambient_species, "observer_depth_band": _observer_depth_band, "observer_depth_zone": _observer_water_zone,
		"pending_ambient_chunks": _pending_ambient.size(), "depth_zones": zones,
		"max_chunks": MAX_CHUNKS, "max_instances_per_chunk": MAX_INSTANCES_PER_CHUNK,
		"chunk_size": CHUNK_SIZE, "observer": _observer, "biomes": biomes}
