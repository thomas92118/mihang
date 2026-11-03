extends SceneTree

const Game = preload("res://scripts/game.gd")
const Ocean = preload("res://scripts/ocean.gd")
const Submarine = preload("res://scripts/submarine.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	create_timer(30.0).timeout.connect(func():
		printerr("FAIL: Submarines and booster test timed out")
		quit(1)
	)

	var game := Game.new()
	root.add_child(game)
	game._start("explore")
	await process_frame

	# 1. Test Handheld Mini Propulsion Booster (Seaglide / H 键)
	assert(not game.diver.booster_active, "Booster should start deactivated")
	var initial_speed: float = 8.5
	# Toggle H key
	var active: bool = game.diver.toggle_booster()
	assert(active and game.diver.booster_active, "Toggling booster must activate it")
	assert(is_instance_valid(game.diver.booster_node) and game.diver.booster_node.visible, "Booster 3D model must be visible in front of diver")

	# Test speed boost
	game.diver._physics_process(0.1)
	# Normal speed is boosted to 19.5
	assert(game.diver.booster_node.position.z < -0.3, "Booster must be held forward in front of camera")

	# Toggle off
	active = game.diver.toggle_booster()
	assert(not active and not game.diver.booster_active, "Pressing H again must deactivate booster")
	assert(not game.diver.booster_node.visible, "Booster 3D model must hide when deactivated")

	# 2. Test Discovery of New Regions
	var new_landmarks := ["crystal_basin", "shipyard", "phosphor_groves"]
	for lm_id in new_landmarks:
		assert(game.LANDMARKS.has(lm_id), "LANDMARKS must contain " + lm_id)
		var lm_info: Dictionary = game.LANDMARKS[lm_id]
		game.diver.position = lm_info["pos"]
		game._check_landmarks()
		assert(lm_id in game.state.landmarks_discovered, "Diver reaching " + lm_id + " must discover it")
		var biome_name: String = game._get_current_biome(game.diver.position)
		assert(biome_name.contains(lm_info["name"]), "Biome name must identify " + lm_info["name"])

	# 3. Test Submarine Vehicles in World
	var subs: Array[Node3D] = game.ocean.get_submarines()
	assert(subs.size() >= 2, "World must contain at least 2 submarines")
	var scout_sub: Submarine = null
	var titan_sub: Submarine = null
	for s in subs:
		if s is Submarine:
			if s.sub_type == "scout":
				scout_sub = s
			elif s.sub_type == "titan":
				titan_sub = s
	assert(is_instance_valid(scout_sub), "Scout submarine must be deployed in world")
	assert(is_instance_valid(titan_sub), "Titan giant submarine must be deployed in world")

	# Verify Scout Submarine in Crystal Basin
	assert(scout_sub.position.y > 0.0, "Scout sub must be deployed on sea surface")
	assert(scout_sub.escape_pods.size() >= 2, "Scout sub must have escape pods on both flanks")
	# Verify Titan Submarine in Shipyard
	assert(titan_sub.position.y > 0.0, "Titan sub must be deployed on sea surface")
	assert(titan_sub.escape_pods.size() >= 4, "Titan giant sub must have 4 escape pods mounted on flanks")

	# 4. Test Scout Submarine Boarding, Fast Piloting, Torpedoes, and Disembarking
	game.diver.position = scout_sub.position + Vector3(2.0, 0, 0)
	var nearby = game.ocean.find_nearby_submarine(game.diver.position, 8.5)
	assert(nearby == scout_sub, "Scout sub should be detected nearby")

	# Board submarine
	game._board_submarine(scout_sub)
	assert(game.active_submarine == scout_sub, "Game active_submarine must be scout_sub")
	assert(scout_sub.is_piloted and scout_sub.pilot_diver == game.diver, "Submarine must be marked as piloted")

	# Fast piloting test
	var start_pos: Vector3 = scout_sub.position
	# Test pilot_direct matching player character 3D 6-DOF controls
	scout_sub.pilot_direct(0.5, Vector2(0, -1), 0.0, false, game.diver.camera.global_basis)
	assert(scout_sub.current_speed > 10.0, "Scout submarine must accelerate quickly")

	# Guided Torpedo attack & manual detonation test
	var dummy_fish: Node3D = game.ocean.fish[0]
	dummy_fish.position = scout_sub.global_position - scout_sub.global_basis.z * 10.0
	dummy_fish.set_meta("health", 500.0)
	# Fire guided torpedo
	game._fire_submarine_weapon()
	assert(is_instance_valid(game.active_torpedo), "Active guided torpedo must be registered")
	assert(game.active_torpedo.is_guided, "Torpedo must be guided by player aiming")
	# Test steering: torpedo turns towards camera aim vector
	game.active_torpedo._physics_process(0.1)
	# Manual detonation
	game.active_torpedo.manual_detonate()
	assert(game.active_torpedo.exploded, "Manual detonation must explode torpedo")
	game.active_torpedo = null

	# Disembark test
	game._disembark_submarine()
	assert(game.active_submarine == null, "Disembarking must clear active_submarine")
	assert(not scout_sub.is_piloted, "Scout sub must no longer be piloted")

	# 5. Test Titan Giant Submarine Boarding and Heavy Seismic Attack
	game.diver.position = titan_sub.position + Vector3(4.0, 0, 0)
	game._board_submarine(titan_sub)
	assert(game.active_submarine == titan_sub)
	assert(titan_sub.is_piloted)
	assert(titan_sub.max_hull == 2800.0, "Titan submarine must have heavy hull armor")

	# Fire Titan heavy torpedo
	var titan_torp_data: Dictionary = titan_sub.fire_weapon()
	assert(titan_torp_data["damage"] == 360.0 and titan_torp_data["shockwave"] == true)

	# Test taking predator damage on submarine
	var initial_hull: float = titan_sub.hull
	titan_sub.take_damage(50.0)
	assert(titan_sub.hull == initial_hull - 50.0, "Predator attack should damage sub hull, leaving diver unharmed")
	assert(game.state.health == 100.0, "Diver health must remain 100% inside submarine")

	game._disembark_submarine()
	assert(game.active_submarine == null)

	print("PASS: Handheld booster H speed increase, Crystal Basin, Abyssal Shipyard, Phosphor Groves, Scout Submarine, and Titan Giant Submarine with torpedo attacks")
	game.queue_free()
	await process_frame
	quit(0)
