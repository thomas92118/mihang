extends SceneTree

# Godot --headless --path . --log-file .tools/depth-regions.log -s tests/depth_regions.gd
const Game = preload("res://scripts/game.gd")
const Ocean = preload("res://scripts/ocean.gd")
const OceanDepths = preload("res://scripts/ocean_depths.gd")
const Submarine = preload("res://scripts/submarine.gd")
const WorldMap = preload("res://scripts/world_map.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var finished := [false]
	create_timer(50.0).timeout.connect(func() -> void:
		if not finished[0]:
			printerr("FAIL: Expanded depth regions test timed out")
			quit(1)
	)
	_check_depth_contract()
	_check_chart()
	var game = Game.new()
	root.add_child(game)
	game._start("explore")
	game.set_process(false)
	game.set_physics_process(false)
	game.diver.set_physics_process(false)
	game.ocean.set_process(false)
	await physics_frame
	await process_frame
	var ecology = game.ocean.get_node("SeabedEcology")
	var regions := [
		{"id": "atoll", "at": Vector2(40, 340), "min": 10.0, "max": 30.0},
		{"id": "kelp", "at": Vector2(-260, 280), "min": 25.0, "max": 55.0},
		{"id": "ridge", "at": Vector2(380, 290), "min": 60.0, "max": 110.0},
		{"id": "citadel", "at": Vector2(460, -60), "min": 100.0, "max": 170.0},
		{"id": "bonefield", "at": Vector2(-480, -90), "min": 180.0, "max": 260.0},
		{"id": "ghost_fleet", "at": Vector2(420, -380), "min": 160.0, "max": 220.0},
		{"id": "caldera", "at": Vector2(-440, -420), "min": 260.0, "max": 380.0},
		{"id": "hadal", "at": Vector2(40, -700), "min": 460.0, "max": 600.0},
	]
	for region: Dictionary in regions:
		var at: Vector2 = region["at"]
		var depth := -Ocean.floor_height(at.x, at.y)
		assert(depth >= float(region["min"]) and depth <= float(region["max"]), "Regional depth must match its ecological identity: " + str(region["id"]) + " is " + str(depth))
		var floor_y: float = ecology.sample_floor_height(at.x, at.y)
		# Stations and ruins can sit directly above these region centers. Test
		# the seabed itself rather than their platform roofs along the full ray.
		var query := PhysicsRayQueryParameters3D.create(Vector3(at.x, floor_y + 0.25, at.y), Vector3(at.x, floor_y - 0.25, at.y), 1)
		query.exclude = [game.diver.get_rid()]
		var hit: Dictionary = game.ocean.get_world_3d().direct_space_state.intersect_ray(query)
		assert(not hit.is_empty(), "Every deeper frontier needs a real seabed collider")
		assert(absf(float(hit["position"].y) - floor_y) < 0.03, "Bathymetry, streamed ecology and physical seabed must agree at " + str(region["id"]))
		print("DEPTH: " + str(region["id"]) + " " + str(snappedf(depth, 0.1)) + "m / " + OceanDepths.zone_label(depth))
	_check_core_transitions()
	_check_depth_ecology(ecology)
	_check_frontier_wildlife(game.ocean)

	# Find the deepest navigable seabed instead of assuming a label's old Y value.
	var deepest := Vector3.ZERO
	for x in range(-40, 121, 20):
		for z in range(-860, -619, 20):
			var floor_y: float = ecology.sample_floor_height(x, z)
			if floor_y < deepest.y:
				deepest = Vector3(x, floor_y, z)
	assert(-deepest.y >= 560.0 and -deepest.y <= OceanDepths.MAX_SEAFLOOR_DEPTH + 0.01, "The physical world must reach close to the 600m seabed target")
	var deep_query := PhysicsRayQueryParameters3D.create(deepest + Vector3.UP * 3, deepest - Vector3.UP * 3, 1)
	assert(not game.ocean.get_world_3d().direct_space_state.intersect_ray(deep_query).is_empty(), "The deepest terrain must be solid, not merely a height-map value")

	# Exercise the actual swimming and driving code below the former 185m clamp.
	game.diver.global_position = deepest + Vector3.UP * 8.0
	game.diver.velocity = Vector3.ZERO
	game.diver.active = true
	var swim_y: float = game.diver.position.y
	Input.action_press("descend")
	for step in range(10):
		game.diver._physics_process(0.1)
	Input.action_release("descend")
	assert(game.diver.position.y < swim_y - 0.01 and game.diver.position.y < -500.0, "Normal swimming must work near the 600m floor")
	assert(game.diver.toggle_booster())
	Input.action_press("ascend")
	var booster_y: float = game.diver.position.y
	for step in range(10):
		game.diver._physics_process(0.1)
	Input.action_release("ascend")
	assert(game.diver.position.y > booster_y and game.diver.position.y < -500.0, "The handheld booster must remain usable in the hadal zone")
	game.diver.toggle_booster()
	var submarine = Submarine.new()
	root.add_child(submarine)
	submarine.configure("scout")
	submarine.global_position = deepest + Vector3.UP * 14.0
	submarine.board(game.diver)
	var submarine_y: float = submarine.position.y
	for step in range(8):
		submarine.pilot_direct(0.1, Vector2.ZERO, -1.0, false, Basis.IDENTITY)
	assert(submarine.position.y < submarine_y - 0.01 and submarine.position.y < -500.0, "Submarines must descend through the expanded depth range")
	submarine.disembark()
	submarine.queue_free()

	var hadal_id := "hadal_starlight_sanctum"
	game.state.discover_landmark(hadal_id)
	var landmark: Dictionary = game.LANDMARKS[hadal_id]
	game._on_fast_travel_requested("lm_" + hadal_id, landmark["pos"], str(landmark["name"]))
	assert(game.diver.position.y < -440.0, "Fast travel must preserve the destination's expanded depth")
	assert(game.diver.position.y > ecology.sample_floor_height(game.diver.position.x, game.diver.position.z), "Fast travel must arrive above the triangulated seabed")
	assert(game.diver.position.y >= -OceanDepths.MAX_DIVE_DEPTH)
	finished[0] = true
	print("PASS: distinct 10–600m regions, solid deepest seabed, depth-specific life, continuous chart and terrain transitions, swimming/booster/submarine controls and hadal fast travel")
	game.queue_free()
	await process_frame
	quit()

func _check_depth_contract() -> void:
	assert(OceanDepths.MAX_SEAFLOOR_DEPTH == 600.0)
	assert(OceanDepths.MAX_DIVE_DEPTH > OceanDepths.MAX_SEAFLOOR_DEPTH)
	for sample: Array in [[0.0, "sunlit_reef"], [34.9, "sunlit_reef"], [35.0, "shelf_garden"], [89.9, "shelf_garden"], [90.0, "twilight_slope"], [199.9, "twilight_slope"], [200.0, "bathyal_basin"], [359.9, "bathyal_basin"], [360.0, "hadal_trench"], [600.0, "hadal_trench"]]:
		assert(OceanDepths.zone_id(float(sample[0])) == str(sample[1]))
		assert(not OceanDepths.zone_label(float(sample[0])).is_empty())

func _check_chart() -> void:
	var previous_luminance := 1.0
	for depth in [15.0, 65.0, 155.0, 285.0, 465.0, 585.0]:
		var color: Color = WorldMap._bathymetry_color(depth, 700.0, 700.0)
		var luminance := color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
		assert(luminance < previous_luminance - 0.005, "The chart must distinguish successive depth zones all the way to 600m")
		previous_luminance = luminance
	for boundary in [35.0, 90.0, 200.0, 360.0]:
		var before: Color = WorldMap._bathymetry_color(boundary - 0.01, 700.0, 700.0)
		var after: Color = WorldMap._bathymetry_color(boundary + 0.01, 700.0, 700.0)
		assert(Vector3(before.r, before.g, before.b).distance_to(Vector3(after.r, after.g, after.b)) < 0.001, "Map color transitions must be seamless at ecological boundaries")
	assert(WorldMap.build_bathymetry_texture(64).get_width() == 64)

func _check_core_transitions() -> void:
	for boundary: Vector2 in [Vector2(210, 0), Vector2(-210, -170), Vector2(40, 120), Vector2(0, -360)]:
		for offset: Vector2 in [Vector2(0.1, 0), Vector2(0, 0.1)]:
			var a := Ocean.floor_height(boundary.x - offset.x, boundary.y - offset.y)
			var b := Ocean.floor_height(boundary.x + offset.x, boundary.y + offset.y)
			assert(absf(a - b) < 1.0, "Expanded depth regions must join the original basin without a height discontinuity")

func _check_depth_ecology(ecology) -> void:
	var asset_sets: Dictionary = {}
	var species_sets: Dictionary = {}
	for at: Vector2 in [Vector2(40, 340), Vector2(380, 290), Vector2(460, -60), Vector2(-480, -90), Vector2(40, -740)]:
		var depth := -Ocean.floor_height(at.x, at.y)
		var zone: String = OceanDepths.zone_id(depth)
		var assets: Dictionary = {}
		var species: Dictionary = {}
		var cell := Vector2i(floori(at.x / 48.0), floori(at.y / 48.0))
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				var local_cell := cell + Vector2i(dx, dz)
				for item: Dictionary in ecology.build_chunk_plan(local_cell):
					if str(item["depth_zone"]) == zone:
						assets[str(item["asset"])] = true
				for animal: Dictionary in ecology.sample_ambient_community(local_cell, depth - 8.0):
					species[str(animal["species"])] = true
		assert(not assets.is_empty() and not species.is_empty(), "Each depth zone needs both scenery and ambient animals: " + zone)
		asset_sets[zone] = assets
		species_sets[zone] = species
	assert(asset_sets["sunlit_reef"].has("seagrass"))
	assert(asset_sets["twilight_slope"].has("cold_water_coral"))
	assert(asset_sets["bathyal_basin"].has("glass_sponge") or asset_sets["bathyal_basin"].has("sea_pen"))
	assert(asset_sets["hadal_trench"].has("sea_cucumber") or asset_sets["hadal_trench"].has("trench_spire_boulder"))
	assert(species_sets["sunlit_reef"].has("silverside"))
	assert(not species_sets["hadal_trench"].has("silverside"), "Sunlit fish schools must not be reused throughout the hadal zone")
	assert(species_sets["hadal_trench"].has("abyss_jelly"))

func _check_frontier_wildlife(ocean) -> void:
	var communities: Dictionary = {}
	var interactive_creatures: Array = ocean.get_creatures()
	for creature: Node3D in ocean.frontier_wildlife:
		var zone: String = str(creature.get_meta("depth_zone"))
		var habitat_depth: float = float(creature.get_meta("habitat_depth"))
		var kind: String = str(creature.get_meta("kind"))
		assert(zone == OceanDepths.zone_id(habitat_depth))
		assert(interactive_creatures.has(creature), "Regional fauna must participate in the actual creature systems")
		assert(creature is CollisionObject3D or creature.has_node("CreatureHitbox"), "Regional fauna needs an interaction/combat hitbox")
		assert(creature.position.y >= Ocean.terrain_height(creature.position.x, creature.position.z) - 0.1, "Deep regional animals must spawn above the triangulated seabed")
		if not communities.has(zone):
			communities[zone] = {}
		communities[zone][kind] = true
	assert(communities.size() == 5, "All five depth zones must contain interactive wildlife")
	assert(communities["sunlit_reef"].has("sea_turtle"))
	assert(communities["twilight_slope"].has("squid"))
	assert(communities["bathyal_basin"].has("crab") and communities["bathyal_basin"].has("abyss"))
	assert(communities["hadal_trench"].has("jellyfish") and communities["hadal_trench"].has("crab"))
	assert(not communities["hadal_trench"].has("fish_small") and not communities["hadal_trench"].has("sea_turtle"), "Hadal wildlife must differ from the sunlit reef community")
