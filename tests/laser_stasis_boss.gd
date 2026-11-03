extends SceneTree

const Game = preload("res://scripts/game.gd")
const Ocean = preload("res://scripts/ocean.gd")
const EnergyOrb = preload("res://scripts/energy_orb.gd")

func _initialize() -> void:
	_run.call_deferred()

func _key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _tap(code: int) -> void:
	_key(code, true)
	await process_frame
	_key(code, false)
	await process_frame

func _find_orb(game: Node) -> Node3D:
	for child in game.get_children():
		if child.get_script() == EnergyOrb:
			return child
	return null

func _wall(game: Node, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 4, 0.25)
	collision.shape = box
	body.add_child(collision)
	game.add_child(body)
	return body

func _run() -> void:
	create_timer(35.0).timeout.connect(func():
		printerr("FAIL: laser/stasis/Boss test timed out")
		quit(1)
	)
	var game := Game.new()
	root.add_child(game)
	game._start("explore")
	game.set_process(false)
	game.set_physics_process(false)
	game.ocean.set_process(false)
	game.diver.set_process(false)
	game.diver.set_physics_process(false)
	assert(game.ocean.sea_spiders.size() > 0 and game.ocean.seals.size() > 0)
	assert(game.ocean.water_dragon.get_meta("kind") == "water_dragon")

	# The same laser stays blue, while increasing contrast in dark water.
	game.ocean.set_depth(0.0)
	var surface: Color = game.ocean.get_laser_color()
	game.ocean.set_depth(90.0)
	var abyss: Color = game.ocean.get_laser_color()
	assert(surface.b > surface.g and abyss.b > abyss.g)
	assert(abyss.get_luminance() > surface.get_luminance() * 2.0)
	game.ocean.set_depth(6.0)

	# Isolate real colliders in open water, with two targets on the same line.
	game.diver.position = Vector3(180, -6, 70)
	game.diver.rotation = Vector3.ZERO
	game.diver.camera.rotation = Vector3.ZERO
	game.ocean.last_diver_pos = game.diver.position
	var first: Node3D = game.ocean.small_fish[0]
	var second: Node3D = game.ocean.small_fish[1]
	first.position = Vector3(180, -6, 62)
	second.position = Vector3(180, -6, 55)
	first.set_meta("health", 1000.0)
	second.set_meta("health", 1000.0)
	var neighbors: Array[Node3D] = [first, second, game.ocean.sea_spiders[0], game.ocean.seals[0], game.ocean.rays[0], game.ocean.jellies[0], game.ocean.turtles[0], game.ocean.squids[0], game.ocean.crabs[0]]
	for i in range(2, neighbors.size()):
		neighbors[i].position = Vector3(184 + (i % 2), -6, 62 - i * 0.5)
	var outside: Node3D = game.ocean.predators[0]
	outside.position = Vector3(180, -6, 40)
	await physics_frame
	await _tap(KEY_3)
	assert(game.diver.current_weapon == "sonic")
	game.diver.equip_anim_time = 0.0
	game.diver._process(0.01)

	await _tap(KEY_T)
	assert(game.diver.aiming and not game.diver.scoped)
	await _tap(KEY_Y)
	assert(game.diver.scoped)
	game.diver._physics_process(0.8)
	assert(game.diver.camera.fov < 12.0, "Y must produce actual optical magnification")
	game._process(0.0)
	assert(game.hud.scope_overlay.visible and game.ocean.scope_view_enabled)
	await _tap(KEY_Y)
	assert(not game.diver.scoped)
	game.diver._physics_process(0.8)
	game._process(0.0)
	assert(not game.ocean.scope_view_enabled)
	await physics_frame

	# A tap fires one beam and damages only the first collider.
	await _tap(KEY_R)
	assert(float(first.get_meta("health")) == 840.0)
	assert(float(second.get_meta("health")) == 1000.0)
	assert(game.has_node("BlueLaserBeam"))
	assert(_find_orb(game) == null)

	var wall := _wall(game, Vector3(180, -6, 66))
	await physics_frame
	game.diver.attack_cooldown = 0.0
	await _tap(KEY_R)
	assert(float(first.get_meta("health")) == 840.0, "A solid obstacle must block laser damage")
	wall.queue_free()
	await physics_frame

	# Full charge waits for release, appears at the muzzle, and moves slowly.
	for i in range(2, neighbors.size()):
		neighbors[i].position = Vector3(184 + (i % 2), -6, 62 - i * 0.5)
	game.diver.camera_punch = Vector3.ZERO
	game.diver.attack_cooldown = 0.0
	_key(KEY_R, true)
	await process_frame
	assert(game.diver.gun_trigger_held, "Pressing R after cooldown must begin charging")
	game.diver._process(3.0)
	assert(game.diver.charge_time == 3.0 and _find_orb(game) == null)
	assert(game.diver.charge_glow.visible and game.diver.charge_glow.scale.x > 4.0)
	var muzzle: Vector3 = game.diver.get_muzzle_position()
	_key(KEY_R, false)
	await process_frame
	var orb := _find_orb(game)
	assert(is_instance_valid(orb), "A charged release must create a projectile")
	orb.set_physics_process(false)
	assert(orb.global_position.distance_to(muzzle) < 0.5)
	var before_flight: Vector3 = orb.global_position
	var before_lifetime: float = orb.lifetime
	game._set_screen("pause")
	await process_frame
	await process_frame
	assert(orb.global_position == before_flight and orb.lifetime == before_lifetime, "Pause must stop the projectile")
	game._set_screen("play")
	orb._physics_process(0.25)
	assert(is_equal_approx(orb.global_position.distance_to(before_flight), EnergyOrb.SPEED * 0.25))
	for i in range(12):
		orb._physics_process(0.25)
		if orb.exploded:
			break
	assert(orb.exploded and game.stasis_fields.size() == 1, "Contact must detonate a stasis field")
	assert(float(outside.get_meta("freeze_timer")) == 0.0)
	var snapshots: Array[Transform3D] = []
	for creature in neighbors:
		assert(float(creature.get_meta("freeze_timer")) > 0.0, "Every nearby species must freeze")
		snapshots.append(creature.transform)
		if creature.has_meta("animation_player"):
			assert(not creature.get_meta("animation_player").is_playing())
	var leg_clock: float = game.ocean.sea_spiders[0].animation_clock
	game.ocean._process(0.25)
	var frozen_bites: Array = game.ocean.tick_predators(first.global_position, 0.25)
	for i in range(neighbors.size()):
		assert(neighbors[i].transform.is_equal_approx(snapshots[i]), "Frozen creatures must not move or wobble")
	assert(game.ocean.sea_spiders[0].animation_clock == leg_clock)
	game.ocean.damage_creature(first, 2000.0)
	game.ocean._tick_status(first, 0.25)
	assert(first.transform.is_equal_approx(snapshots[0]), "A creature killed inside stasis must stay frozen until expiry")
	for bite in frozen_bites:
		assert(bite.name != "海蜘蛛足刺")
	outside.position = first.position + Vector3(3, 0, 0)
	game._physics_process(0.1)
	assert(float(outside.get_meta("freeze_timer")) > 0.0, "Creatures entering an existing field must also freeze")
	game._physics_process(6.1)
	game.ocean._process(6.1)
	game.ocean._process(0.02)
	for creature in neighbors:
		assert(float(creature.get_meta("freeze_timer")) == 0.0)
	assert(game.ocean.sea_spiders[0].animation_clock > leg_clock, "Procedural animations must resume after stasis")

	# Sweep across a thin solid wall in one large step, and handle initial overlap.
	wall = _wall(game, Vector3(180, -6, 66))
	var swept := EnergyOrb.new()
	swept.excluded = [game.diver.get_rid()]
	game.add_child(swept)
	swept.set_physics_process(false)
	swept.global_position = Vector3(180, -6, 70)
	await physics_frame
	swept._physics_process(2.0)
	assert(swept.exploded and swept.global_position.z > 66.8, "A slow energy sphere must not tunnel through thin scenery")
	var overlapping := EnergyOrb.new()
	game.add_child(overlapping)
	overlapping.set_physics_process(false)
	overlapping.global_position = wall.global_position
	await physics_frame
	overlapping._physics_process(0.01)
	assert(overlapping.exploded, "An energy sphere spawned against an obstacle must detonate")
	wall.queue_free()
	await physics_frame

	# Changing screens cancels a pending charge; release must not create a ghost shot.
	game.diver.attack_cooldown = 0.0
	_key(KEY_R, true)
	game.diver._process(3.0)
	game._set_screen("pause")
	assert(not game.diver.gun_trigger_held and not game.diver.charge_glow.visible)
	_key(KEY_R, false)
	game._set_screen("play")
	assert(_find_orb(game) == null)

	# Boss starts by proximity, pauses its attack timer in stasis, then ends play on defeat.
	assert(not game.ocean.boss_active)
	game.ocean.check_boss_encounter(Ocean.BOSS_ARENA_CENTER + Vector3(0, 0, 36.5))
	assert(not game.ocean.boss_active)
	var boss: Node3D = game.ocean.water_dragon
	assert(game.ocean.damage_creature(boss, 100.0).is_empty(), "Dormant Boss must wait for its encounter")
	game.ocean.check_boss_encounter(Ocean.BOSS_ARENA_CENTER + Vector3(0, 0, 35.5))
	game.ocean.damage_creature(boss, 100.0)
	game.ocean.check_boss_encounter(Ocean.BOSS_ARENA_CENTER + Vector3(0, 0, 86.0))
	assert(not game.ocean.boss_active and float(boss.get_meta("health")) == Ocean.BOSS_MAX_HEALTH, "Leaving the arena must reset an unfinished encounter")
	game.ocean.check_boss_encounter(Ocean.BOSS_ARENA_CENTER + Vector3(0, 0, 35.5))
	assert(game.ocean.boss_active)
	game.ocean.freeze_creatures(boss.position, 12.0, 1.0)
	var boss_pose: Transform3D = boss.transform
	var boss_timer: float = game.ocean.boss_action_timer
	assert(game.ocean._tick_boss(boss.position, 0.5).is_empty())
	assert(boss.transform == boss_pose and game.ocean.boss_action_timer == boss_timer)
	game.ocean._tick_status(boss, 1.1)
	game.ocean.damage_creature(boss, 1000.0)
	game.ocean._tick_boss(boss.position + Vector3(0, 0, 20), 0.01)
	assert(bool(boss.get_meta("enraged")))
	for creature in game.ocean.get_creatures():
		if creature != boss:
			creature.position = Vector3(180, -6, 75)
	game.diver.position = boss.position + Vector3(0, 0, 24)
	game.diver.rotation = Vector3.ZERO
	game.diver.camera.rotation = Vector3.ZERO
	game.diver.equip_anim_time = 0.0
	game.diver.camera_punch = Vector3.ZERO
	game.diver._process(0.01)
	await physics_frame
	var laser: Dictionary = {"weapon": "sonic", "mode": "laser", "range": 2000.0, "damage": 160.0}
	for i in range(8):
		if float(boss.get_meta("health")) <= 0.0:
			break
		var hit: Dictionary = game._fire_laser(laser)
		assert(not hit.is_empty(), "The real laser must be able to damage the Boss")
	assert(float(boss.get_meta("health")) <= 0.0 and game.ocean.conquered_bosses.has("water_dragon"))

	# Test taming near-death boss with sonic gun
	var turtle: Node3D = game.ocean.turtle_boss
	turtle.set_meta("health", 500.0)
	game.ocean.freeze_creatures(turtle.position, 12.0, 5.0)
	game.diver.position = turtle.position + Vector3(0, 0, 5)
	assert(game._can_tame_creature(turtle))
	game._tame_creature(turtle)
	assert(game.tamed_beasts.size() == 1 and bool(turtle.get_meta("tamed")))
	assert(game.active_mount_idx == 0)

	# Test conquering all 4 bosses triggers Mother Tree
	game.ocean.damage_creature(game.ocean.flying_fish_boss, 5000.0)
	game.ocean.damage_creature(game.ocean.kraken_boss, 5000.0)
	assert(game.ocean.conquered_bosses.size() == 4)
	assert(game.ocean.mother_tree_spawned_flag and is_instance_valid(game.ocean.mother_tree))

	# Test collecting Mother Tree items
	for item in game.ocean.mother_tree_items.duplicate():
		game._collect_mother_tree_item(item)
	assert(game.state.inventory["mother_tree_essence"] >= 1)
	assert(game.state.inventory["ancient_star_core"] >= 1)
	assert(game.state.inventory["tree_seed"] >= 1)

	# Test returning to Escape Console and crafting to win
	game.diver.position = Ocean.HOME + Vector3(2.2, 0.4, 1.4)
	game._interact_escape_console()
	assert(game.screen == "win" and game.state.escape_crafted and paused)
	game._process(0.0)
	assert(game.hud.win_title.text == "深渊跃迁逃生成功")

	print("PASS: adaptive blue laser, first-hit/obstacle collision, T/Y optics, muzzle charge/release, slow swept orb, pause, complete multi-species stasis, Boss trigger/phases and final ending")
	paused = false
	game.queue_free()
	await process_frame
	quit()
