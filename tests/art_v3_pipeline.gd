extends SceneTree
## Authored libraries must be consumed by the actual gameplay builders.
const BlenderArt = preload("res://scripts/presentation/blender_art.gd")
const MarineCreature = preload("res://scripts/marine_creature.gd")
const Submarine = preload("res://scripts/submarine.gd")
const Ocean = preload("res://scripts/ocean.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	assert(BlenderArt.available(), "Missing imported Blender part library")
	for species: String in ["sea_spider", "seal", "water_dragon", "flying_fish", "kraken", "colossus_turtle", "sea_wolf", "school_fish"]:
		var creature := MarineCreature.new()
		creature.configure(species)
		root.add_child(creature)
		var count := 0
		for part: MeshInstance3D in creature.find_children("*", "MeshInstance3D", true, false):
			if bool(part.get_meta("blender_surface", false)):
				count += 1
		assert(count > 0, species + ": gameplay builder did not use authored Blender surfaces")
		creature.animate(0.16)
		creature.free()
		print("PASS authored creature ", species, ": ", count, " surfaces")
	for kind: String in ["scout", "titan", "mini"]:
		var sub := Submarine.new()
		root.add_child(sub)
		sub.configure(kind)
		var count := 0
		for part: MeshInstance3D in sub.find_children("*", "MeshInstance3D", true, false):
			if bool(part.get_meta("blender_surface", false)):
				count += 1
		assert(count > 0, kind + ": gameplay builder did not use authored Blender hull")
		sub.free()
		print("PASS authored vehicle ", kind, ": ", count, " surfaces")
	var ocean := Ocean.new()
	root.add_child(ocean)
	ocean.process_mode = Node.PROCESS_MODE_DISABLED
	var surface: MeshInstance3D = ocean.get_node("WaterSurface")
	assert(surface.get_meta("authored_model", "") == "ocean-surface-3")
	assert(surface.mesh is ArrayMesh)
	var arrays := surface.mesh.surface_get_arrays(0)
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	assert(indices.size() / 3 <= 26000, "Ocean tessellation exceeded previous triangle budget")
	var near_ring := false
	for point: Vector3 in vertices:
		assert(point.is_finite() and absf(point.y) < 0.001)
		if point.length() > 0.5 and point.length() < 1.0:
			near_ring = true
	assert(near_ring and surface.get_aabb().size.x >= 4399.0, "Missing near/far radial topology")
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.make_current()
	camera.position = Vector3(621.0, -4.0, -732.0)
	ocean._update_water_surface_state(false)
	assert(surface.position.distance_to(Vector3(620, 0, -732)) < 0.01)
	assert(surface.material_override == ocean.water_underwater_mat)
	camera.free()
	ocean.free()
	print("PASS: 8 creature types, 3 submarine types, imported adaptive ocean mesh and observer tracking")
	quit(0)
