extends SceneTree

# Godot --headless --path . --log-file .tools/seabed-ecology.log -s tests/seabed_ecology.gd
const Ocean = preload("res://scripts/ocean.gd")
const OceanDepths = preload("res://scripts/ocean_depths.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var finished := [false]
	create_timer(45.0).timeout.connect(func() -> void:
		if not finished[0]:
			printerr("FAIL: Seabed ecology/depth verification timed out")
			quit(1)
	)
	_check_depth_profiles()
	var ocean = Ocean.new()
	root.add_child(ocean)
	ocean.set_process(false)
	var ecology = ocean.get_node("SeabedEcology")
	await physics_frame
	await process_frame

	# Check widely separated frontiers and remote corners, rather than only authored POIs.
	var sites := [Vector2(80, 380), Vector2(-315, 325), Vector2(625, -80), Vector2(-600, -95), Vector2(445, -400), Vector2(-450, -450), Vector2(90, -700), Vector2(820, 780), Vector2(-820, -780)]
	var seen_assets: Dictionary = {}
	var seen_biomes: Dictionary = {}
	var samples_checked := 0
	for site: Vector2 in sites:
		var cell := Vector2i(floori(site.x / 48.0), floori(site.y / 48.0))
		var plan: Array = ecology.build_chunk_plan(cell)
		assert(not plan.is_empty(), "Remote seabed must receive ecological detail at " + str(site))
		assert(plan == ecology.build_chunk_plan(cell), "Revisiting a chunk must reproduce exactly the same ecology")
		for entry: Dictionary in plan:
			var asset: String = str(entry["asset"])
			var at: Vector3 = entry["position"]
			var scale_value: Vector3 = entry["scale"]
			var normal: Vector3 = entry["normal"]
			assert(absf(at.x) <= 900.0 and absf(at.z) <= 900.0, "Ecology must stay inside the playable sea")
			assert(absf(at.y - float(ecology.sample_floor_height(at.x, at.z))) < 0.001, "Scenery contact points must follow the rendered terrain")
			assert(scale_value.x > 0.0 and scale_value.y > 0.0 and scale_value.z > 0.0)
			assert(absf(normal.length() - 1.0) < 0.001, "Terrain attachment normals must be normalized")
			if -at.y >= 90.0:
				assert(asset not in ["kelp", "seagrass", "brain_coral", "staghorn_coral", "table_coral", "giant_clam"], "Sunlit reef plants must not grow across the abyss")
			seen_assets[asset] = true
			seen_biomes[str(entry["biome"])] = true
		# Compare the sampler with the actual physics trimesh, including outer 16m chunks.
		for index in range(mini(3, plan.size())):
			var at: Vector3 = plan[index]["position"]
			var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.25, at - Vector3.UP * 0.25, 1)
			var hit: Dictionary = ocean.get_world_3d().direct_space_state.intersect_ray(query)
			assert(not hit.is_empty(), "Streamed scenery must rest on a solid seabed at " + str(at))
			assert(absf(float(hit["position"].y) - at.y) < 0.02, "Ecology must match triangulated ground rather than float above the analytic height function")
			samples_checked += 1
	assert(seen_assets.size() >= 8, "Open sea should contain diverse seabed detail")
	assert(seen_biomes.size() >= 4, "Ecological communities should vary across depth and geography")

	# Moving and teleporting must replace chunks, preserve world generation RNG and respect a fixed budget.
	var original_rng_state: int = ocean.rng.state
	var previous_shoals: Array[WeakRef] = []
	for site: Vector2 in [Vector2(820, 780), Vector2(90, -700), Vector2(-820, -780), Vector2(80, 380), Vector2(0, 0)]:
		var observer := Vector3(site.x, ecology.sample_floor_height(site.x, site.y) + 4.0, site.y)
		for frame in range(32):
			ecology.update_observer(observer, 0.1)
			await process_frame
		var snapshot: Dictionary = ecology.get_ecology_snapshot()
		assert(int(snapshot["pending_chunks"]) == 0, "Chunk streaming must finish after a bounded number of updates")
		assert(int(snapshot.get("pending_ambient_chunks", 0)) == 0, "Water-column communities must finish refreshing after depth changes")
		assert(int(snapshot["active_chunks"]) > 0 and int(snapshot["active_chunks"]) <= int(snapshot["max_chunks"]))
		assert(int(snapshot["max_chunks"]) <= 25, "Open-world detail must keep a bounded active radius")
		var instance_budget: int = int(snapshot["max_chunks"]) * int(snapshot["max_instances_per_chunk"])
		assert(instance_budget <= 3200, "The active ecology budget must remain bounded independently of world size")
		assert(int(snapshot["instance_count"]) > 0 and int(snapshot["instance_count"]) <= instance_budget, "Scenery count must remain bounded after long-distance travel")
		assert(int(snapshot["max_ambient_fish"]) <= 200, "Ambient shoals must have a fixed world-independent budget")
		assert(int(snapshot["ambient_fish_count"]) > 0 and int(snapshot["ambient_fish_count"]) <= int(snapshot["max_ambient_fish"]))
		for previous: WeakRef in previous_shoals:
			assert(not is_instance_valid(previous.get_ref()), "Fish batches from the previous distant neighborhood must be freed with their chunks")
		previous_shoals.clear()
		assert(ecology.get_child_count() == int(snapshot["active_chunks"]))
		var observer_cell := Vector2i(floori(site.x / 48.0), floori(site.y / 48.0))
		var rendered_fish_count := 0
		for chunk: Node3D in ecology.get_children():
			var chunk_cell := Vector2i(roundi(chunk.position.x / 48.0), roundi(chunk.position.z / 48.0))
			assert(absi(chunk_cell.x - observer_cell.x) <= 2 and absi(chunk_cell.y - observer_cell.y) <= 2, "Old distant chunks must be removed from the rendered scene after teleporting")
			var community: Node3D = chunk.get_node_or_null("AmbientWaterColumn")
			if community != null:
				for shoal: MultiMeshInstance3D in community.get_children():
					assert(shoal.multimesh.instance_count > 0 and shoal.multimesh.instance_count <= 8)
					rendered_fish_count += shoal.multimesh.instance_count
					previous_shoals.append(weakref(shoal))
		assert(rendered_fish_count == int(snapshot["ambient_fish_count"]), "The fish budget must include every rendered shoal")
		assert((snapshot["observer"] as Vector3).is_equal_approx(observer))
	assert(ocean.rng.state == original_rng_state, "Streaming decoration must not consume gameplay-world RNG")

	for depth in [0.0, 12.0, 40.0, 80.0, 140.0, 240.0, 380.0, 560.0, OceanDepths.MAX_DIVE_DEPTH]:
		var profile: Dictionary = Ocean.sample_depth_profile(depth)
		ocean.set_depth(depth)
		assert(is_equal_approx(ocean.sun.light_energy, float(profile["sun_energy"])))
		assert(is_equal_approx(ocean.environment.ambient_light_energy, float(profile["ambient_energy"])))
		assert(is_equal_approx(ocean.environment.fog_light_energy, float(profile["fog_energy"])))
		assert(is_equal_approx(ocean.environment.fog_density, float(profile["fog_density"])))
	var regular_fog: float = ocean.environment.fog_density
	ocean.set_depth(OceanDepths.MAX_DIVE_DEPTH, true)
	assert(ocean.environment.fog_density < regular_fog, "Scope must retain its intended long-range visibility")
	ocean.set_depth(OceanDepths.MAX_DIVE_DEPTH, false)
	assert(is_equal_approx(ocean.environment.fog_density, regular_fog), "Leaving scope must restore depth-dependent fog")
	finished[0] = true
	print("PASS: continuous depth lighting, diverse deterministic frontier ecology, " + str(samples_checked) + " terrain contact raycasts, and bounded streaming across the open sea")
	ocean.queue_free()
	await process_frame
	quit()

func _check_depth_profiles() -> void:
	var previous: Dictionary = Ocean.sample_depth_profile(0.0)
	for step in range(1, int(OceanDepths.MAX_DIVE_DEPTH * 10.0) + 1):
		var depth: float = float(step) * 0.1
		var current: Dictionary = Ocean.sample_depth_profile(depth)
		for key: String in ["sun_energy", "ambient_energy", "fog_energy"]:
			assert(float(current[key]) >= 0.0)
			assert(float(current[key]) <= float(previous[key]) + 0.00001, "Sunlight, ambient fill and scattering must diminish with depth: " + key)
			assert(absf(float(current[key]) - float(previous[key])) < 0.025, "Depth changes must not cause abrupt lighting bands: " + key)
		assert(float(current["fog_density"]) >= float(previous["fog_density"]) - 0.00001)
		assert(absf(float(current["fog_density"]) - float(previous["fog_density"])) < 0.001)
		previous = current
	var shallow: Dictionary = Ocean.sample_depth_profile(5.0)
	var abyss: Dictionary = Ocean.sample_depth_profile(560.0)
	assert(float(abyss["sun_energy"]) < float(shallow["sun_energy"]) * 0.08, "Deep-sea light must be materially dimmer than the sunlit reef")
	assert(float(abyss["ambient_energy"]) < float(shallow["ambient_energy"]) * 0.5)
