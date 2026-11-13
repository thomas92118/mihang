extends SceneTree
## Regression for authored scenes, traversable arches and contextual instruments.
const Ocean = preload("res://scripts/ocean.gd")
const HUD = preload("res://scripts/hud.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var ocean := Ocean.new()
	root.add_child(ocean)
	ocean.set_process(false)
	await physics_frame
	var composition := ocean.get_node("OceanComposition")
	assert(composition.get_meta("regions").size() == 9)
	var batches := composition.find_children("*", "MultiMeshInstance3D", true, false)
	assert(batches.size() > 30 and batches.size() < 150, "All nine scenes must use bounded batches")
	var fish_paths: Dictionary = {}
	for region: String in ["core", "atoll", "kelp", "ridge", "citadel", "wreck", "bones", "caldera", "hadal"]:
		var shoal: MultiMeshInstance3D = composition.get_node_or_null(region + "_ribbon")
		assert(shoal != null, region + ": missing living fish composition")
		fish_paths[int(shoal.get_meta("curve_mode"))] = true
		assert(shoal.multimesh.instance_count <= 80, "Richer fish motion must retain a bounded instance budget")
		# Fish displacement happens before each instance's scale, so its animated
		# envelope must exceed the unscaled centre path in every horizontal view.
		var radius: float = shoal.get_meta("path_radius")
		var stretch: Vector2 = shoal.get_meta("path_stretch")
		var reach := radius * maxf(stretch.x, stretch.y) * 1.5 + 3.0
		for point: Vector3 in [Vector3(reach, 0, 0), Vector3(-reach, 0, 0), Vector3(0, 0, reach), Vector3(0, 0, -reach)]:
			assert(shoal.multimesh.custom_aabb.has_point(point), "Animated fish must not disappear at a path extremity: " + region)
	assert(fish_paths.size() == 3, "The authored ocean needs ellipse, S-stream and crescent fish rhythms")
	for species: String in ["table_coral", "staghorn_coral", "brain_coral", "kelp", "sea_fan", "barrel_sponge", "sea_lily"]:
		var found := false
		for batch: MultiMeshInstance3D in batches:
			found = found or (String(batch.name).contains(species) and batch.multimesh.instance_count > 0)
		assert(found, "Missing instanced scenery species: " + species)
	# Shoot horizontally through the middle of each principal arch's opening.
	for center: Vector2 in [Vector2(0, -28), Vector2(-260, 248), Vector2(460, -82), Vector2(60, -668)]:
		var y := ocean.terrain_height(center.x, center.y) + 8.0
		for offset: float in [-2.5, 0.0, 2.5]:
			var query := PhysicsRayQueryParameters3D.create(Vector3(center.x + offset, y, center.y + 3), Vector3(center.x + offset, y, center.y - 3), 1)
			var hit := ocean.get_world_3d().direct_space_state.intersect_ray(query)
			assert(hit.is_empty(), "Principal arch must retain a wide swimway, not only a clear center ray: " + str(center))
	var hud := HUD.new()
	root.add_child(hud)
	hud.set_screen("play")
	var payload := {"mode": "survival", "current_weapon": "knife", "oxygen": 80.0, "health": 100.0}
	hud.update_hud(payload)
	hud._detail_time = 0.0
	hud.update_hud(payload)
	assert(hud.oxygen_value.is_visible_in_tree() and hud.health_value.is_visible_in_tree())
	assert(not hud._cargo.visible and not hud.weapon_bar_label.get_parent().visible)
	payload["oxygen"] = 8.0
	payload["health"] = 15.0
	hud.update_hud(payload)
	assert(hud.status_value.text.contains("氧气不足"))
	assert(hud.status_value.is_visible_in_tree() and hud.health_value.is_visible_in_tree())
	payload["current_weapon"] = "sonic"
	hud.update_hud(payload)
	assert(hud.weapon_bar_label.get_parent().visible, "Equipment changes must bring back contextual hints")
	hud.free()
	ocean.free()
	print("PASS: nine authored regions, batched scenery species, traversable arches and critical/contextual HUD")
	quit()
