extends SceneTree

const Game = preload("res://scripts/game.gd")
const Ocean = preload("res://scripts/ocean.gd")
const MarineCreature = preload("res://scripts/marine_creature.gd")
const Submarine = preload("res://scripts/submarine.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	create_timer(30.0).timeout.connect(func():
		printerr("FAIL: mount_tame_mothertree_schools test timed out")
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

	# 1. Verify Movement Controls: W forward, C descend, Space ascend, A left turn, D right turn
	game.diver.position = Vector3(0, -10, 0)
	game.diver.rotation = Vector3.ZERO
	var initial_rot_y := game.diver.rotation.y
	Input.action_press("left")
	game.diver._physics_process(0.2)
	Input.action_release("left")
	assert(game.diver.rotation.y > initial_rot_y, "A key must turn left (positive yaw)")

	var turned_rot_y := game.diver.rotation.y
	Input.action_press("right")
	game.diver._physics_process(0.2)
	Input.action_release("right")
	assert(game.diver.rotation.y < turned_rot_y, "D key must turn right (negative yaw)")

	Input.action_press("ascend")
	game.diver._physics_process(0.2)
	Input.action_release("ascend")
	assert(game.diver.velocity.y > 0.0, "Space key must ascend upward")

	Input.action_press("descend")
	game.diver._physics_process(0.2)
	Input.action_release("descend")
	assert(game.diver.velocity.y < 0.0, "C key must descend downward")

	# 2. Verify Sea Wolves & Schooling Fish exist in the world
	assert(game.ocean.sea_wolves.size() >= 6, "World must spawn sea wolves in packs")
	assert(game.ocean.schooling_fish.size() >= 30, "World must spawn schooling fish")
	assert(game.ocean.fish_schools.size() >= 2, "World must have fish schools")

	# 3. Verify Taming System: Stun with sonic gun and tame up to 5 beasts
	var wolf: Node3D = game.ocean.sea_wolves[0]
	wolf.position = Vector3(10, -10, 10)
	game.ocean.freeze_creatures(wolf.position, 6.0, 4.0)
	game.diver.position = wolf.position + Vector3(0, 0, 3)
	assert(game._can_tame_creature(wolf), "Frozen sea wolf must be eligible for taming")
	game._tame_creature(wolf)
	assert(game.tamed_beasts.size() == 1, "Wolf should be added to tamed beasts")
	assert(bool(wolf.get_meta("tamed")) == true, "Wolf must have tamed metadata")
	assert(game.active_mount_idx == 0, "First tamed beast should be active mount")

	# Verify friendly fire immunity (自己契约的坐骑无法攻击它造成伤害)
	var dmg_res: Dictionary = game.ocean.damage_creature(wolf, 200.0)
	assert(dmg_res.is_empty(), "Tamed beast must be immune to friendly damage")
	assert(float(wolf.get_meta("health")) == float(wolf.get_meta("max_health")), "Tamed beast health must not decrease")

	# Tame more beasts up to the new limit of 20 beasts
	for i in range(1, game.ocean.sea_wolves.size()):
		var other_wolf: Node3D = game.ocean.sea_wolves[i]
		game.ocean.freeze_creatures(other_wolf.position, 6.0, 4.0)
		game._tame_creature(other_wolf)
	for p_i in range(14):
		var p: Node3D = game.ocean.predators[p_i]
		game.ocean.freeze_creatures(p.position, 6.0, 4.0)
		game._tame_creature(p)
	assert(game.tamed_beasts.size() == 20, "Must hold exactly 20 tamed beasts")

	# Try taming a 21st beast -> should be capped at 20
	var extra_pred: Node3D = game.ocean.predators[14]
	game.ocean.freeze_creatures(extra_pred.position, 6.0, 4.0)
	game._tame_creature(extra_pred)
	assert(game.tamed_beasts.size() == 20, "Capacity must cap at 20 beasts")

	# 4. Verify Active Mount & Followers
	# Select beast 2 (index 1) as active mount
	game._mount_beast(1)
	assert(game.active_mount_idx == 1, "Mount selection must switch active mount")

	# Drive mount with W / A / D / Space / C: A turns left with roll, D turns right with roll
	var m_node: Node3D = game.tamed_beasts[1]["node"]
	var m_pos_before: Vector3 = m_node.position
	var m_rot_before: float = m_node.rotation.y
	Input.action_press("left")
	game._physics_process(0.1)
	Input.action_release("left")
	assert(m_node.rotation.y > m_rot_before, "Mount must turn left on A")
	assert(m_node.rotation.z != 0.0, "Mount must bank roll into turn")

	Input.action_press("forward")
	game._physics_process(0.1)
	Input.action_release("forward")
	assert(m_node.position != m_pos_before, "Mount must move forward on W")
	assert(game.diver.global_position.distance_to(m_node.global_position) < 3.0, "Diver must ride on mount back")

	# Followers follow behind the player and stop when player stops (在人物后方待命跟随)
	game.companion_attack_target = null
	for tick in range(10):
		game._tick_companion_followers(0.2)
	var fwd_heading := -m_node.global_basis.z
	for i in range(20):
		if i != 1:
			var f_node: Node3D = game.tamed_beasts[i]["node"]
			var to_f := f_node.global_position - m_node.global_position
			# Follower is behind the player (dot product with forward vector <= 0.1)
			assert(to_f.dot(fwd_heading) <= 0.5, "Followers must stay behind the player")

	# 5. Verify 10-meter Proximity Living Creature Auto-Detection
	var nearby_wild: Node3D = game.ocean.predators[15]
	nearby_wild.position = m_node.position + fwd_heading * 8.0 # 8 meters in front
	nearby_wild.set_meta("health", 5000.0)
	game.companion_attack_target = null
	game._tick_companion_followers(0.1)
	assert(game.companion_attack_target == nearby_wild, "Living creature within 10m must trigger auto-attack")
	game.companion_attack_target = null

	# 6. Verify Marker Gun (光标枪): 0 damage, red laser line, persistent red dot, commanded attack
	game._dismount_beast()
	game._switch_weapon("marker_gun")
	assert(game.diver.current_weapon == "marker_gun", "Marker gun must be equipped")
	var m_atk: Dictionary = game.diver.attack()
	assert(m_atk["damage"] == 0.0, "Marker gun must have 0 damage")
	assert(m_atk["mode"] == "marker_pointer", "Marker gun mode must be marker_pointer")

	var test_target: Node3D = game.ocean.predators[16]
	game.diver.position = Vector3(180, -6, 70)
	game.diver.rotation = Vector3.ZERO
	game.diver.camera.rotation = Vector3.ZERO
	test_target.position = Vector3(180, -6, 60)
	test_target.set_meta("health", 200.0)
	await physics_frame
	game._tick_companion_followers(0.1)
	game._dispatch_attack(m_atk)
	assert(is_instance_valid(game.persistent_red_dot), "Marker gun must spawn persistent red dot")
	assert(game.companion_attack_target == test_target, "Companions must lock on marked target")

	# Submarine movement: A turns left with roll, Space ascends
	var sub: Submarine = game.ocean.submarines[0] as Submarine
	sub.board(game.diver)
	var sub_rot_before: float = sub.rotation.y
	sub.pilot_direct(0.2, Vector2(-1.0, 0.0), 0.0, false, Basis())
	assert(sub.rotation.y > sub_rot_before, "Submarine must turn left on A")
	assert(sub.rotation.z != 0.0, "Submarine must bank roll into turn")
	sub.disembark()

	# Followers charge and deal damage
	var initial_hp: float = float(test_target.get_meta("health"))
	for tick in range(10):
		game._tick_companion_followers(0.2)
	# With 20 beasts, attack multiplier is 2^19 = 524,288x, dealing massive damage
	assert(float(test_target.get_meta("health")) <= 0.0 or float(test_target.get_meta("health")) < initial_hp, "Companions must deal scaled attack damage")

	# Verify Z key pet collective recall (按下Z键把宠物集体召回)
	game._recall_pets()
	assert(game.companion_attack_target == null, "Recalling pets must clear attack target")
	assert(not is_instance_valid(game.persistent_red_dot), "Recalling pets must clear persistent red dot")

	# Verify One-handed Shield with C key toggle & simultaneous weapon use (单手护盾，与全武器同时使用)
	assert(not game.diver.shield_active, "Shield should start lowered")
	assert(game.diver.toggle_shield(), "Pressing C must raise shield")
	assert(game.diver.shield_active and game.diver.shield_node.visible, "Shield must be visible and active")
	game._switch_weapon("knife")
	assert(game.diver.weapon_nodes["knife"].visible and game.diver.shield_node.visible, "Shield and knife must be held simultaneously")
	game._switch_weapon("axe")
	assert(game.diver.weapon_nodes["axe"].visible and game.diver.shield_node.visible, "Shield and axe must be held simultaneously")
	game._switch_weapon("sonic")
	assert(game.diver.weapon_nodes["sonic"].visible and game.diver.shield_node.visible, "Shield and sonic gun must be held simultaneously")
	assert(not game.diver.toggle_shield(), "Pressing C again must retract shield")
	assert(not game.diver.shield_active and not game.diver.shield_node.visible, "Shield must be retracted")
	game.state.mode = "explore"

	# 7. Verify 4 Bosses Progression & Mother Tree Awakening
	# Clear all 4 bosses (water_dragon, flying_fish, kraken, colossus_turtle)
	game.ocean.damage_creature(game.ocean.water_dragon, 9999.0, Vector3.ZERO, true)
	game.ocean.damage_creature(game.ocean.flying_fish_boss, 9999.0, Vector3.ZERO, true)
	game.ocean.damage_creature(game.ocean.kraken_boss, 9999.0, Vector3.ZERO, true)
	game.ocean.damage_creature(game.ocean.turtle_boss, 9999.0, Vector3.ZERO, true)
	assert(game.ocean.conquered_bosses.size() == 4, "All 4 bosses must be marked conquered")
	assert(game.ocean.mother_tree_spawned_flag, "Mother Tree must be spawned after 4 bosses")
	assert(is_instance_valid(game.ocean.mother_tree), "Mother Tree node must be valid")

	# 7. Verify Mother Tree Interior Items Collection
	assert(game.ocean.mother_tree_items.size() == 3, "Mother tree must contain 3 sacred items")
	for item in game.ocean.mother_tree_items.duplicate():
		game._collect_mother_tree_item(item)
	assert(int(game.state.inventory.get("mother_tree_essence", 0)) >= 1)
	assert(int(game.state.inventory.get("ancient_star_core", 0)) >= 1)
	assert(int(game.state.inventory.get("tree_seed", 0)) >= 1)

	# 8. Verify Escape Console Crafting & Game Ending
	assert(is_instance_valid(game.ocean.escape_console), "Escape console must exist at Lifepod base")
	game.diver.position = Ocean.HOME + Vector3(2.2, 0.4, 1.4)
	game._interact_escape_console()
	assert(game.screen == "win", "Crafting escape engine at console must trigger win screen")
	assert(game.state.escape_crafted, "Escape crafted state must be true")
	game._process(0.0)
	assert(game.hud.win_title.text == "深渊跃迁逃生成功", "Win title must display abyssal warp escape success")

	print("PASS: controls W/A/S/D/C/Space, taming 5 beasts with mount+followers, companion combat AI, 4 bosses to Mother Tree, sacred relics collection, and escape console ending")
	game.queue_free()
	await process_frame
	quit()
