extends SceneTree

const Game = preload("res://scripts/game.gd")
const Ocean = preload("res://scripts/ocean.gd")
const OceanDepths = preload("res://scripts/ocean_depths.gd")
const WorldMap = preload("res://scripts/world_map.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var finished := [false]
	create_timer(30.0).timeout.connect(func() -> void:
		if not finished[0]:
			printerr("FAIL: Open world exploration test timed out")
			quit(1)
	)

	var game := Game.new()
	root.add_child(game)
	game._start("survival")
	await physics_frame
	await process_frame

	# 1. Input bindings & UI components check
	assert(InputMap.has_action("world_map"), "M key world_map action must be registered")
	assert(InputMap.has_action("sonar_ping"), "N key sonar_ping action must be registered")
	assert(is_instance_valid(game.hud.compass_strip), "CompassStrip must exist on HUD")
	assert(is_instance_valid(game.hud.minimap_radar), "MinimapRadar must exist on HUD")
	assert(is_instance_valid(game.hud.sea_chart), "SeaChartCanvas must exist on HUD")
	var bathy := WorldMap.build_bathymetry_texture(64)
	assert(bathy != null and bathy.get_width() == 64 and bathy.get_height() == 64, "Bathymetry sea chart texture must bake cleanly")

	# 2. Verify expanded open-world scale, outer seabed physics collision & POIs
	assert(game.LANDMARKS.size() == 24, "Open world must feature 24 landmarks across core and outer frontiers")
	assert(game.ocean.outposts.size() == 6, "Open world must spawn 6 research outposts")
	assert(game.ocean.explorer_relics.size() == 12, "Open world must spawn 12 ancient explorer relics")
	assert(game.ocean.outer_seabed_chunks.size() == 4, "Outer seabed must have 4 stitched collision chunks")
	assert(game.ocean.get_submarines().size() >= 4, "Open world must include the northern expedition submarine")
	assert(is_instance_valid(game.ocean.mother_tree) and not game.ocean.mother_tree_spawned_flag, "Dormant Mother Tree sanctuary must be visible in the world before awakening")

	# Verify Diver can travel freely beyond old 450m boundary up to ±850m
	game.diver.position = Vector3(820.0, -20.0, -780.0)
	game.diver.velocity = Vector3.ZERO
	game.diver._physics_process(0.05)
	assert(game.diver.position.x > 750.0 and game.diver.position.z < -700.0, "Diver must not be clamped to legacy 450m bounds")

	# Raycast outer seabed trimesh colliders in North, East, West, and South frontiers
	var space := game.get_world_3d().direct_space_state
	for sample_xz: Vector2 in [Vector2(115, 360), Vector2(545, -60), Vector2(-545, -90), Vector2(135, -640)]:
		var q := PhysicsRayQueryParameters3D.create(
			Vector3(sample_xz.x, 5.0, sample_xz.y),
			Vector3(sample_xz.x, -OceanDepths.MAX_DIVE_DEPTH, sample_xz.y),
			1
		)
		q.exclude = [game.diver.get_rid()]
		var hit := space.intersect_ray(q)
		assert(not hit.is_empty(), "Outer seabed chunk must have solid trimesh collision at " + str(sample_xz))
		var expected_y := Ocean.floor_height(sample_xz.x, sample_xz.y)
		assert(absf(float(hit["position"].y) - expected_y) < 6.0, "Outer seabed collision height must match floor_height at " + str(sample_xz))

	# Verify watertight seam stitching across all 4 inner/outer chunk boundaries & outer seams
	for xi in range(-600, 601, 3):
		var sx := float(xi) + 0.5
		assert(absf(Ocean.terrain_height(sx, 143.999) - Ocean.terrain_height(sx, 144.001)) < 0.01, "North seam must be continuous at x=" + str(sx))
		assert(absf(Ocean.terrain_height(sx, -383.999) - Ocean.terrain_height(sx, -384.001)) < 0.01, "South seam must be continuous at x=" + str(sx))
	for zi in range(-384, 144, 3):
		var sz := float(zi) + 0.5
		assert(absf(Ocean.terrain_height(-287.999, sz) - Ocean.terrain_height(-288.001, sz)) < 0.01, "West seam must be continuous at z=" + str(sz))
		assert(absf(Ocean.terrain_height(287.999, sz) - Ocean.terrain_height(288.001, sz)) < 0.01, "East seam must be continuous at z=" + str(sz))

	# Verify stitched transition triangles match physics raycast height and upward normals
	var stitched_samples: Array[Vector2] = [
		Vector2(-178.0, 146.0), Vector2(-174.0, 151.0), Vector2(-170.0, 146.0),
		Vector2(-178.0, -386.0), Vector2(-174.0, -391.0), Vector2(-170.0, -386.0),
		Vector2(-290.0, -178.0), Vector2(-295.0, -174.0), Vector2(-290.0, -170.0),
		Vector2(290.0, -178.0), Vector2(295.0, -174.0), Vector2(290.0, -170.0)
	]
	for st_xz: Vector2 in stitched_samples:
		var sq := PhysicsRayQueryParameters3D.create(
			Vector3(st_xz.x, 5.0, st_xz.y),
			Vector3(st_xz.x, -OceanDepths.MAX_DIVE_DEPTH, st_xz.y),
			1
		)
		sq.exclude = [game.diver.get_rid()]
		var shit := space.intersect_ray(sq)
		assert(not shit.is_empty(), "Stitched transition band must have solid collision at " + str(st_xz))
		assert(Vector3(shit["normal"]).y > 0.2, "Stitched triangle normal must point upward at " + str(st_xz))
		var st_expected := Ocean.terrain_height(st_xz.x, st_xz.y)
		assert(absf(float(shit["position"].y) - st_expected) < 0.02, "Stitched raycast height must match terrain_height at " + str(st_xz))

	# Regression check: Diver must swim across the z=-384 South seam (~458m from Lifepod) without wedging or clipping
	var seam_start := Vector3(-174.5, Ocean.terrain_height(-174.5, -383.4) + 0.7, -383.4)
	game.diver.global_position = seam_start
	game.diver.velocity = Vector3.ZERO
	game.diver.rotation = Vector3(0.0, 0.45, 0.0)
	game.diver.camera.rotation = Vector3(-0.18, 0.0, 0.0)
	Input.action_press("forward")
	for _step in range(30):
		game.diver._physics_process(0.05)
		await physics_frame
	Input.action_release("forward")
	assert(game.diver.global_position.z < -384.5, "Diver must smoothly cross z=-384 seam without getting wedged")
	assert(game.diver.global_position.distance_to(seam_start) > 4.0, "Diver must maintain forward traversal across seabed seam")
	assert(game.diver.global_position.y >= Ocean.terrain_height(game.diver.global_position.x, game.diver.global_position.z) + 0.64, "Diver must remain above triangulated seabed")
	game.diver.velocity = Vector3.ZERO
	game.diver.rotation = Vector3.ZERO
	game.diver.camera.rotation = Vector3.ZERO

	# 3. Verify outer landmark discovery & biome identification
	for outer_id: String in ["sunlit_atoll", "sunken_observatory", "obsidian_caldera", "hadal_starlight_sanctum"]:
		var lm: Dictionary = game.LANDMARKS[outer_id]
		game.diver.position = lm["pos"]
		game._check_landmarks()
		assert(outer_id in game.state.landmarks_discovered, "Visiting outer landmark must discover " + outer_id)
		var b_txt: String = game._get_current_biome(game.diver.position)
		assert(b_txt.contains(str(lm["name"])), "Biome label must identify outer region " + str(lm["name"]))

	# 4. Research Outpost activation, O2 safe zone, forward crafting & Sea Chart terminal
	var east_outpost: Node3D = null
	for out in game.ocean.outposts:
		if str(out.get_meta("outpost_id", "")) == "outpost_east":
			east_outpost = out
			break
	assert(is_instance_valid(east_outpost), "East Observatory Outpost must exist")

	game.diver.global_position = east_outpost.global_position + Vector3(0.0, 2.0, 4.0)
	game.state.inventory["titanium"] = 2
	game.state.inventory["kelp"] = 2
	game._craft("fins")
	assert(not game.state.fins, "Unactivated outpost must not allow survival crafting yet")

	var ratio_before_outpost: float = game.state.get_survey_ratio()
	var gold_before_outpost: int = game.state.gold
	game.target = east_outpost
	game._interact()
	assert("outpost_east" in game.state.unlocked_outposts, "Interacting with outpost must unlock it")
	assert(bool(east_outpost.get_meta("activated", false)), "Outpost visual metadata must be marked activated")
	assert(game.state.get_survey_ratio() > ratio_before_outpost, "Activating outpost must reveal surrounding sea chart fog")
	assert(game.state.gold >= gold_before_outpost + 150, "Activating outpost must grant research bounty gold")

	# Activated outpost acts as forward oxygen & crafting base
	game.state.oxygen = 40.0
	game._process(1.0)
	assert(game.state.oxygen > 40.0, "Activated outpost must replenish diver oxygen in survival mode")
	game._craft("fins")
	assert(game.state.fins, "Activated outpost must allow crafting equipment in the field")

	# Pressing E again on an activated outpost opens the full-screen Sea Chart
	game.target = east_outpost
	game._interact()
	assert(game.screen == "map" and paused, "Interacting with unlocked outpost must open Sea Chart screen")
	game._set_screen("play")
	assert(game.screen == "play" and not paused)

	# 5. Sunken Explorer Relic collection & permanent explorer speed / attack scaling
	var first_relic: Node3D = game.ocean.explorer_relics[0]
	var relic_id: String = str(first_relic.get_meta("relic_id", ""))
	var bonus_before: float = game.state.weapon_attack_bonus
	game.diver.global_position = first_relic.global_position + Vector3(0.0, 1.2, 2.0)
	game.target = null
	game._interact()
	assert(relic_id in game.state.collected_relics, "Nearby relic must be collected on E interact")
	assert(bool(first_relic.get_meta("collected", false)) and not first_relic.visible, "Collected relic must hide in 3D")
	assert(game.state.weapon_attack_bonus == bonus_before + 10.0, "Relic must permanently boost weapon attack")
	game._process(0.05)
	assert(game.diver.explorer_speed_mult > 1.0, "Relic must increase diver open-world swim speed multiplier")

	# 6. Wide-area Sonar Survey Pulse (N)
	var uncollected_relic: Node3D = game.ocean.explorer_relics[1]
	var rel2_id: String = str(uncollected_relic.get_meta("relic_id", ""))
	game.diver.global_position = uncollected_relic.global_position + Vector3(60.0, 8.0, -40.0)
	game.state.sonar_cooldown = 0.0
	var ping_ok: bool = game._trigger_sonar_ping()
	assert(ping_ok and game.state.sonar_cooldown > 0.0, "Sonar ping must trigger and start cooldown")
	assert(game.state.pinged_targets.has(rel2_id), "Sonar ping must tag nearby uncollected relics on sea chart")
	assert(not game._trigger_sonar_ping(), "Sonar ping must respect cooldown while recharging")

	# 7. Custom Waypoint placement & auto-arrival clearing
	game.hud.map_waypoint_set.emit(Vector2(380.0, 290.0))
	assert(game.state.has_custom_waypoint, "Setting map waypoint must activate custom waypoint")
	game._process(0.05)
	assert(game.waypoint_arrow.visible, "3D HUD waypoint marker must appear while waypoint is active")
	game.diver.global_position = Vector3(382.0, -22.0, 292.0)
	game._process(0.05)
	assert(not game.state.has_custom_waypoint, "Reaching custom waypoint within 14m must auto-clear it")

	# 8. Fast Travel (Ocean Current Warp) validation & execution
	game._set_screen("map")
	var pos_before_locked := game.diver.global_position
	game.hud.fast_travel_requested.emit("outpost_hadal", Vector3(60, -138, -640), "极渊星辉前哨站")
	assert(game.screen == "map" and game.diver.global_position == pos_before_locked, "Locked outpost must reject fast travel")

	game.state.oxygen = 35.0
	game.hud.fast_travel_requested.emit("outpost_east", east_outpost.global_position, "东海星象前哨站")
	assert(game.screen == "play", "Fast travel must return to active play")
	assert(game.diver.global_position.distance_to(east_outpost.global_position) < 20.0, "Fast travel must warp diver to unlocked outpost")
	assert(game.state.oxygen == game.state.max_oxygen, "Fast traveling to a station must restore full oxygen")
	assert(game.state.fast_travel_count == 1, "Fast travel counter must increment")

	# Fast travel to discovered landmark & back to Lifepod Home
	var atoll_pos: Vector3 = game.LANDMARKS["sunlit_atoll"]["pos"]
	game.hud.fast_travel_requested.emit("lm_sunlit_atoll", atoll_pos, "北境晴空珊瑚环礁")
	assert(Vector2(game.diver.global_position.x - atoll_pos.x, game.diver.global_position.z - atoll_pos.z).length() < 12.0, "Fast travel must warp to discovered landmark")
	game.hud.fast_travel_requested.emit("home_lifepod", Ocean.HOME, "逃生舱母港")
	assert(game.diver.global_position.distance_to(Ocean.HOME) < 12.0, "Fast travel must warp back to Lifepod Home")

	# 9. Explorer Rank progression & Post-Win Open-World Free Roam continuation
	for lm_key: String in game.LANDMARKS:
		game.state.discover_landmark(lm_key)
	for out_node in game.ocean.outposts:
		game.state.unlock_outpost(str(out_node.get_meta("outpost_id", "")), str(out_node.get_meta("name", "")))
	for rel_node in game.ocean.explorer_relics:
		game.state.collect_relic(str(rel_node.get_meta("relic_id", "")), str(rel_node.get_meta("name", "")))
	game.state.reveal_world_area(Vector3.ZERO, 1200.0)
	game._check_explorer_rank_up()
	assert(game.state.get_explorer_rank_level() == 5, "Completing world survey must reach max Explorer Rank Lv.5")

	game._set_screen("win")
	assert(game.screen == "win" and paused)
	game.hud.resume_requested.emit()
	assert(game.screen == "play" and not paused, "Win screen Continue Roaming button must return cleanly to open-world play")

	finished[0] = true
	print("PASS: 1800x1800 open-world ocean, 4 outer seabed chunks, 24 landmarks, 6 outposts, 12 relics, fog-of-war sea chart, sonar ping, custom waypoints, fast travel, explorer ranks, and endless free roam")
	paused = false
	game.queue_free()
	await process_frame
	quit()
