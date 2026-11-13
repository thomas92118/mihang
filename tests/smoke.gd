extends SceneTree

const Survival = preload("res://scripts/survival.gd")

func _initialize() -> void:
	var state = Survival.new()
	assert(not state.collect("invalid"))
	assert(not state.craft("tank", true).is_empty())
	assert(state.inventory.titanium == 0)
	for kind in ["titanium", "titanium", "kelp", "kelp"]:
		assert(state.collect(kind))
	assert(not state.craft("tank", false).is_empty())
	assert(state.inventory.titanium == 2)
	assert(state.craft("tank", true).is_empty())
	assert(state.tank and state.max_oxygen == 150.0)
	assert(not state.craft("tank", true).is_empty())
	state.oxygen = 1.0
	assert(not state.tick(1.0, false, false))
	assert(state.oxygen == 0.0 and state.health < 100.0)
	assert(state.tick(12.0, false, false))
	state.recover()
	assert(state.health == 100.0 and state.oxygen == 150.0)
	state.oxygen = 25.0
	state.tick(1.0, true, false)
	assert(state.oxygen == 49.0)

	# Verify small fish consumption (HP +25, Oxygen +20)
	state.health = 40.0
	state.oxygen = 30.0
	var eat_res = state.eat_fish()
	assert(state.health == 65.0)
	assert(state.oxygen == 50.0)
	assert(state.inventory.fish_small == 1)
	assert(eat_res.health_gain == 25.0 and eat_res.oxygen_gain == 20.0)

	# Verify damage taking and predator attacks
	assert(not state.take_damage(20.0))
	assert(state.health == 45.0)
	assert(state.take_damage(50.0)) # fatal blow returns true
	assert(state.health == 0.0)
	state.recover()

	# Verify crafting weapons (axe and sonic rifle)
	assert(state.weapons == ["knife"])
	state.inventory = {"titanium": 4, "copper": 2, "quartz": 2, "kelp": 0, "fish_small": 1}
	assert(state.craft("axe", true).is_empty())
	assert("axe" in state.weapons)
	assert(not state.craft("axe", true).is_empty()) # Duplicate check

	assert(state.craft("sonic", true).is_empty())
	assert("sonic" in state.weapons)
	assert(not state.craft("sonic", true).is_empty()) # Duplicate check

	state.inventory = {"titanium": 3, "copper": 2, "quartz": 2, "kelp": 0, "fish_small": 1}
	assert(not state.craft("beacon", false).is_empty())
	assert(state.craft("beacon", true).is_empty() and state.rescued)
	assert(state.inventory.titanium == 0 and state.inventory.copper == 0)

	# Verify exploration mode: infinite oxygen, no damage, all weapons unlocked, landmarks
	var explore = Survival.new()
	explore.set_mode("explore")
	assert(explore.mode == "explore" and explore.tank and explore.fins)
	assert(explore.weapons.size() == 3 and "knife" in explore.weapons and "axe" in explore.weapons and "sonic" in explore.weapons)
	assert(not explore.take_damage(50.0))
	assert(explore.health == 100.0)
	assert(not explore.tick(100.0, false, true))
	assert(explore.oxygen == explore.max_oxygen and explore.health == 100.0)
	assert(explore.discover_landmark("vents"))
	assert(not explore.discover_landmark("vents")) # duplicate discovery returns false
	assert("vents" in explore.landmarks_discovered)

	# Verify body fragment collection and weapon attack reinforcement
	assert(state.weapon_attack_bonus == 0.0 and state.weapon_upgrade_level == 0)
	var frag_shark = state.collect_fragment("shark_fragment")
	assert(frag_shark.bonus == 12.0 and frag_shark.level == 1)
	assert(state.weapon_attack_bonus == 12.0 and state.weapon_upgrade_level == 1)
	assert(state.inventory["shark_fragment"] == 1)

	var frag_abyss = state.collect_fragment("abyss_fragment")
	assert(frag_abyss.bonus == 25.0 and frag_abyss.level == 2)
	assert(state.weapon_attack_bonus == 37.0 and state.weapon_upgrade_level == 2)
	assert(state.inventory["abyss_fragment"] == 1)

	# Verify fabricator deep forging recipes (reinforce_sharp and reinforce_sonic)
	state.inventory["titanium"] = 1
	state.inventory["quartz"] = 1
	assert(state.craft("reinforce_sharp", true).is_empty())
	assert(state.weapon_attack_bonus == 57.0 and state.weapon_upgrade_level == 3) # 37 + 20
	assert(state.inventory["shark_fragment"] == 0 and state.inventory["titanium"] == 0)

	assert(state.craft("reinforce_sonic", true).is_empty())
	assert(state.weapon_attack_bonus == 92.0 and state.weapon_upgrade_level == 4) # 57 + 35
	assert(state.inventory["abyss_fragment"] == 0 and state.inventory["quartz"] == 0)

	# Verify Diver weapon stats: 100 dmg & 3000m range for sonic rifle, wide-amplitude cleave
	var Diver = load("res://scripts/diver.gd")
	var diver = Diver.new()
	root.add_child(diver)
	diver.damage_bonus = state.weapon_attack_bonus # 92.0

	# Test knife
	diver.set_weapon("knife")
	var atk_knife = diver.attack()
	assert(atk_knife.weapon == "knife")
	assert(atk_knife.base_damage == 32.0)
	assert(atk_knife.damage == 124.0) # 32 + 92
	assert(atk_knife.range == 6.2)
	assert(atk_knife.max_targets == 3)
	assert(atk_knife.cleave_angle == 0.42)
	diver.attack_cooldown = 0.0

	# Test heavy axe wide cleave
	diver.set_weapon("axe")
	var atk_axe = diver.attack()
	assert(atk_axe.weapon == "axe")
	assert(atk_axe.base_damage == 70.0)
	assert(atk_axe.damage == 162.0) # 70 + 92
	assert(atk_axe.range == 8.5)
	assert(atk_axe.max_targets == 99) # Sweeps all targets in front
	assert(atk_axe.cleave_angle == 0.12) # 165° arc
	diver.attack_cooldown = 0.0

	# Laser rifle uses one precise damaging hit, with a long-range scope.
	diver.set_weapon("sonic")
	var atk_sonic = diver.attack()
	assert(atk_sonic.weapon == "sonic")
	assert(atk_sonic.base_damage == 100.0)
	assert(atk_sonic.damage == 100.0 + 92.0 * 1.5) # 238.0
	assert(atk_sonic.range == 2000.0)
	assert(atk_sonic.mode == "laser")
	assert(atk_sonic.is_sonic == false)
	assert(atk_sonic.max_targets == 1)
	assert(atk_sonic.cleave_angle == 0.999)
	diver.attack_cooldown = 0.0
	assert(diver.begin_gun_charge())
	diver._process(2.99)
	assert(diver.release_gun_charge().mode == "laser", "A partial charge must not launch the ultimate")
	diver.attack_cooldown = 0.0
	assert(diver.begin_gun_charge())
	diver._process(3.1)
	assert(diver.gun_trigger_held and diver.get_charge_ratio() == 1.0, "Full charge must wait for release")
	var ultimate: Dictionary = diver.release_gun_charge()
	assert(ultimate.mode == "stasis_orb" and ultimate.field_radius == 12.0 and ultimate.freeze_duration == 6.0)
	assert(not diver.gun_trigger_held)
	assert(diver.third_person_mode and is_instance_valid(diver.diver_model) and diver.diver_model.visible, "Third-person diver 3D model must be active and visible")
	assert(diver.camera.position.length() > 1.5, "Camera must follow behind the diver in third-person")
	assert(diver.toggle_aim())
	assert(diver.toggle_scope() and diver.scoped)
	diver._process(0.05)
	assert(not diver.diver_model.visible, "Diver model must hide during 8x optical scope view")
	diver.set_weapon("knife")
	diver._process(0.05)
	assert(diver.diver_model.visible, "Diver model must reappear when leaving scope")
	assert(not diver.aiming and not diver.scoped and not diver.gun_trigger_held)
	diver.queue_free()

	# Verify unified attack key mapping is bound to KEY_R
	var Game = load("res://scripts/game.gd")
	var game = Game.new()
	game._setup_input()
	assert(InputMap.has_action("attack"))
	var attack_events = InputMap.action_get_events("attack")
	assert(attack_events.size() > 0)
	var has_r_key: bool = false
	for ev in attack_events:
		if ev is InputEventKey and ev.physical_keycode == KEY_R:
			has_r_key = true
	assert(has_r_key)
	for binding in [["aim", KEY_T], ["scope", KEY_Y]]:
		var found := false
		for ev in InputMap.action_get_events(binding[0]):
			if ev is InputEventKey and ev.physical_keycode == binding[1]:
				found = true
		assert(found, "Both aim modes need their advertised key bindings")

	# Verify dash key mapping is bound to KEY_Q
	assert(InputMap.has_action("dash"))
	var dash_events = InputMap.action_get_events("dash")
	assert(dash_events.size() > 0)
	var has_q_key: bool = false
	for ev in dash_events:
		if ev is InputEventKey and ev.physical_keycode == KEY_Q:
			has_q_key = true
	assert(has_q_key)

	# Verify Recipe Pinning functionality
	state.pin_recipe("rebreather")
	var pin_info := state.get_pinned_info()
	assert(pin_info.recipe == "rebreather")
	assert(pin_info.all_ready == false)
	state.inventory["titanium"] = 2
	state.inventory["copper"] = 1
	state.inventory["kelp"] = 2
	var pin_ready := state.get_pinned_info()
	assert(pin_ready.all_ready == true)

	# Verify Rebreather crafting and Depth Pressure Oxygen scaling
	var test_surv := Survival.new()
	test_surv.oxygen = 100.0
	# At depth 10m (shallow): rate is 1.0/s
	test_surv.tick(1.0, false, false, 10.0)
	assert(is_equal_approx(test_surv.oxygen, 99.0))
	# At depth 70m (abyss) without rebreather: penalty is +0.8x -> rate is 1.8/s
	test_surv.tick(1.0, false, false, 70.0)
	assert(is_equal_approx(test_surv.oxygen, 97.2))
	# Craft rebreather
	test_surv.inventory = {"titanium": 2, "copper": 1, "kelp": 2}
	assert(test_surv.craft("rebreather", true).is_empty())
	assert(test_surv.rebreather)
	# At depth 70m with rebreather: penalty is 0.0 -> rate returns to 1.0/s
	test_surv.tick(1.0, false, false, 70.0)
	assert(is_equal_approx(test_surv.oxygen, 96.2))

	# Verify Biomod Dash trigger and cooldown
	var diver2 = Diver.new()
	root.add_child(diver2)
	diver2.biomod_dash_unlocked = true
	var d_res1 = diver2.trigger_dash(50.0)
	assert(d_res1.success == true and d_res1.cost == 12.0)
	assert(diver2.dash_cooldown > 0.0)
	var d_res2 = diver2.trigger_dash(50.0)
	assert(d_res2.success == false) # cooldown blocks
	# Verify mouse left click is bound to attack action
	var has_lmb: bool = false
	for ev in attack_events:
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
			has_lmb = true
	assert(has_lmb, "Mouse left click must be bound to attack")

	# Verify Underwater Audio procedural synthesis
	var UnderwaterAudio = load("res://scripts/underwater_audio.gd")
	for s_name in ["knife_slash", "knife_hit", "axe_swing", "axe_hit", "sonic_blast", "sonic_hit", "hit_confirm", "kill_sound", "weapon_equip", "booster_start", "booster_stop", "sub_torpedo_launch", "sub_torpedo_hit", "sub_heavy_blast", "sub_enter", "sub_exit", "drone_salvage", "sushi_serve", "clam_bubble"]:
		var stream = UnderwaterAudio.get_stream(s_name)
		assert(stream is AudioStreamWAV, "Stream must be AudioStreamWAV")
		assert(stream.data.size() > 0, "Audio data must not be empty for " + s_name)
		assert(stream.format == AudioStreamWAV.FORMAT_16_BITS)

	# Verify Diver 3-hit knife combo & trauma & hitstop
	var diver_test = Diver.new()
	root.add_child(diver_test)
	diver_test.set_weapon("knife")
	var c1 = diver_test.attack()
	assert(c1.combo == 1, "First knife attack should be combo 1")
	assert(c1.active_delay == 0.06, "Knife combo 1 active delay should be 0.06s")
	assert(diver_test.cleave_mesh.mesh is ArrayMesh and diver_test.cleave_mesh.visible, "Crescent slash ribbon should be visible on slash")
	assert(is_instance_valid(diver_test.cleave_core_mesh) and is_instance_valid(diver_test.slash_sparks), "Inner core ribbon and slash sparks must exist")
	assert(is_instance_valid(diver_test.left_forearm_pivot) and is_instance_valid(diver_test.right_forearm_pivot), "Third-person diver must have articulated elbow pivots")
	diver_test.attack_cooldown = 0.0
	var c2 = diver_test.attack()
	assert(c2.combo == 2, "Second knife attack should be combo 2")
	diver_test.attack_cooldown = 0.0
	var c3 = diver_test.attack()
	assert(c3.combo == 3, "Third knife attack should be combo 3")
	assert(c3.active_delay == 0.08, "Knife combo 3 active delay should be 0.08s")
	assert(is_instance_valid(diver_test.thrust_cone_mesh) and diver_test.thrust_cone_mesh.visible, "Combo 3 thrust must display hydro-vortex piercing cone")
	diver_test.attack_anim_time = diver_test.attack_anim_duration * 0.50
	diver_test._process(0.02)
	assert(absf(diver_test.body_combat_yaw) > 0.001 or diver_test.body_combat_lunge.length() > 0.001, "Third-person body must twist/lunge during attack choreography")
	var knife_node: Node3D = diver_test.weapon_nodes["knife"]
	var hand_in_diver: Transform3D = diver_test.diver_model.transform * diver_test.body_pivot.transform * diver_test.right_arm_pivot.transform * diver_test.right_forearm_pivot.transform * diver_test.right_hand_socket.transform
	var knife_in_diver: Transform3D = diver_test.equipment_rig.transform * diver_test.weapon_mount.transform * knife_node.transform
	var grip_world_pos: Vector3 = knife_in_diver * Vector3(0.0, 0.0, -0.085)
	assert(hand_in_diver.origin.distance_to(grip_world_pos) < 0.005, "Knife handle grip must stay locked inside the diver's right hand")
	var thrust_blade_dir: Vector3 = knife_in_diver.basis.z.normalized()
	assert(thrust_blade_dir.z < -0.95, "Combo 3 lunge thrust must point the knife blade straight forward (-Z)")
	diver_test.attack_cooldown = 0.0
	var c4 = diver_test.attack()
	assert(c4.combo == 1, "Fourth knife attack should loop to combo 1")
	diver_test.attack_anim_time = diver_test.attack_anim_duration * 0.85
	diver_test._process(0.01)
	var c1_windup_hand: Vector3 = (diver_test.diver_model.transform * diver_test.body_pivot.transform * diver_test.right_arm_pivot.transform * diver_test.right_forearm_pivot.transform * diver_test.right_hand_socket.transform).origin
	diver_test.attack_anim_time = diver_test.attack_anim_duration * 0.40
	diver_test._process(0.01)
	var c1_slash_hand: Vector3 = (diver_test.diver_model.transform * diver_test.body_pivot.transform * diver_test.right_arm_pivot.transform * diver_test.right_forearm_pivot.transform * diver_test.right_hand_socket.transform).origin
	assert(c1_windup_hand.x > c1_slash_hand.x + 0.35 and c1_windup_hand.y > c1_slash_hand.y + 0.20, "Combo 1 must sweep diagonally from upper-right to lower-left")

	# Verify trauma and hitstop methods
	assert(diver_test.camera_trauma == 0.0 or diver_test.camera_trauma > 0.0)
	diver_test.add_trauma(0.5)
	assert(diver_test.camera_trauma >= 0.5)
	diver_test.trigger_hitstop(0.08)
	assert(diver_test.hitstop_timer == 0.08)


	# Verify Hitstop preserves animation progress without zero-resetting
	diver_test.attack_anim_time = 0.15
	diver_test.trigger_hitstop(0.08)
	diver_test._process(0.02)
	assert(diver_test.attack_anim_time == 0.15, "Attack anim time must remain frozen during hitstop")
	assert(is_equal_approx(diver_test.hitstop_timer, 0.06), "Hitstop timer should decrement")

	# Verify Axe 2-hit combo & reverse cleave
	diver_test.set_weapon("axe")
	diver_test.attack_cooldown = 0.0
	var axe1 = diver_test.attack()
	assert(axe1.combo == 1 and axe1.active_delay == 0.13, "Axe combo 1 active delay should be 0.13s")
	assert(diver_test.camera_punch.y < 0.0, "First axe swing camera punch should yaw left")
	diver_test.attack_cooldown = 0.0
	var axe2 = diver_test.attack()
	assert(axe2.combo == 2, "Second axe swing should be combo 2")
	assert(diver_test.camera_punch.y > 0.0, "Reverse axe cleave camera punch must be mirrored to the right")

	# Verify repeated single axe swings and large frame deltas never leave camera/character sideways
	diver_test.active = true
	diver_test.reset_camera_alignment(-0.16)
	for _swing_idx in range(24):
		diver_test.combo_timer = 0.0
		diver_test.attack_cooldown = 0.0
		diver_test.attack()
		for _step in range(8):
			diver_test._process(0.05)
	for _settle in range(15):
		diver_test._process(0.05)
	assert(absf(diver_test.camera.rotation.y) < 0.001, "Repeated single axe swings must not accumulate sideways camera yaw")
	assert(is_equal_approx(diver_test.camera.rotation.x, -0.16), "Camera pitch must return to base pitch after melee recoil")

	# Verify lag hitch / large delta stability and recovery when camera yaw is perturbed sideways
	diver_test.combo_timer = 0.0
	diver_test.attack_cooldown = 0.0
	diver_test.attack()
	diver_test._process(2.5)
	assert(absf(diver_test.camera.rotation.y) < 0.001, "Large frame delta during camera punch must not overshoot or drift")
	diver_test.camera.rotation.y = -PI * 0.5
	diver_test.apply_look_delta(Vector2(24.0, 0.0))
	assert(absf(diver_test.camera.rotation.y) < 0.001, "Adjusting view when sideways must immediately re-align camera behind diver")

	# Verify procedural equip animation & attack cancel
	diver_test.set_weapon("sonic")
	assert(diver_test.equip_anim_time > 0.0, "Equip anim time should be set on weapon switch")
	diver_test.attack_cooldown = 0.0
	var sonic1 = diver_test.attack()
	assert(diver_test.equip_anim_time == 0.0, "Attack should immediately cancel equip animation")
	assert(sonic1.active_delay == 0.0, "Sonic rifle fires immediately")

	# Verify input buffering in Game
	assert(game.ATTACK_BUFFER_WINDOW == 0.18)
	game.attack_input_buffered = true
	game.attack_buffer_timer = 0.18
	# Verify CombatVFX spawning
	var CombatVFX = load("res://scripts/combat_vfx.gd")
	CombatVFX.spawn_hit_burst(root, Vector3(0, -10, 0), Vector3.UP, "knife", false, false)
	CombatVFX.spawn_hit_burst(root, Vector3(0, -10, 0), Vector3.UP, "axe", true, true)
	CombatVFX.spawn_damage_number(root, Vector3(0, -10, 0), 124.0, "knife", false)
	CombatVFX.spawn_damage_number(root, Vector3(0, -10, 0), 162.0, "axe", true)

	# Verify Handheld Mini Propulsion Booster (Seaglide / H 助推器)
	var booster_diver = Diver.new()
	root.add_child(booster_diver)
	assert(not booster_diver.booster_active)
	assert(booster_diver.toggle_booster())
	assert(booster_diver.booster_active)
	assert(is_instance_valid(booster_diver.booster_node) and booster_diver.booster_node.visible)
	var has_h_key := false
	for ev in InputMap.action_get_events("booster"):
		if ev is InputEventKey and ev.physical_keycode == KEY_H:
			has_h_key = true
	assert(has_h_key, "Booster must be mapped to KEY_H")
	assert(not booster_diver.toggle_booster())
	assert(not booster_diver.booster_active)
	booster_diver.queue_free()

	# Verify Submarines (Scout and Titan vehicles)
	var SubmarineCls = load("res://scripts/submarine.gd")
	var scout = SubmarineCls.new()
	scout.configure("scout")
	root.add_child(scout)
	assert(scout.sub_type == "scout")
	assert(scout.cruise_speed == 25.0 and scout.boost_speed == 36.0)
	assert(scout.max_hull == 900.0)
	var atk_s: Dictionary = scout.fire_weapon()
	assert(not atk_s.is_empty() and atk_s["damage"] == 120.0 and atk_s["speed"] == 48.0)

	var titan = SubmarineCls.new()
	titan.configure("titan")
	root.add_child(titan)
	assert(titan.sub_type == "titan")
	assert(titan.cruise_speed == 20.0 and titan.max_hull == 2800.0)
	var atk_t: Dictionary = titan.fire_weapon()
	assert(not atk_t.is_empty() and atk_t["damage"] == 360.0 and atk_t["shockwave"] == true)

	# Test Submarine boarding and disembarking
	var d_test = Diver.new()
	root.add_child(d_test)
	scout.board(d_test)
	assert(scout.is_piloted and scout.pilot_diver == d_test)
	var exit_p: Vector3 = scout.disembark()
	assert(not scout.is_piloted and exit_p.distance_to(scout.position) > 2.0)
	d_test.queue_free()
	scout.queue_free()
	titan.queue_free()

	# Interactive showcase species stay available; bulk scenery is now instanced
	# by OceanComposition and streamed ecology (covered in art_composition.gd).
	var OceanCls = load("res://scripts/ocean.gd")
	var ocean = OceanCls.new()
	root.add_child(ocean)
	ocean._spawn_coral_reef_colonies()
	assert(ocean.brain_corals.size() > 0, "Brain coral showcase must remain available")
	assert(ocean.staghorn_corals.size() > 0, "Staghorn coral showcase must remain available")
	assert(ocean.table_corals.size() > 0, "Table coral showcase must remain available")
	assert(ocean.barrel_sponges.size() > 0, "Barrel sponge showcase must remain available")
	assert(ocean.giant_clams.size() >= 12, "Bioluminescent giant clams must populate the seabed")
	assert(ocean.sea_lilies.size() > 0, "Sea lily showcase must remain available")
	# Test giant clam proximity contraction when diver swims near
	var sample_clam: Node3D = ocean.giant_clams[0]
	assert(is_equal_approx(float(sample_clam.get_meta("retract_progress", 0.0)), 0.0))
	ocean.last_diver_pos = sample_clam.position + Vector3(0.5, 0.5, 0.5)
	assert(sample_clam.get_meta("name") == "深海发光巨砗磲")
	assert(sample_clam.get_meta("kind") == "giant_clam")
	var found_clam: Node3D = ocean.find_nearby_oxygen_clam(sample_clam.position + Vector3(1.0, 0.0, 1.0), 4.8)
	assert(found_clam == sample_clam, "Giant clam must be discoverable as an underwater oxygen station")
	assert(game.LANDMARKS.has("coral_sanctuary"), "Coral Sanctuary landmark must be registered")

	# Verify Dave the Diver classic mechanics: Marinca 3-star cards, Weight, Bancho Sushi Bar, Cobra Shop & Salvage Drone
	var dave_state := Survival.new()
	assert(dave_state.get_max_weight() == 40.0 and dave_state.get_current_weight() == 0.0)
	dave_state.inventory["fish_small"] = 2
	dave_state.inventory["fish_meat"] = 6
	dave_state.inventory["kelp"] = 2
	dave_state.inventory["creature_tooth"] = 2
	assert(dave_state.get_current_weight() > 8.0)

	# Register 2-star then upgrade to 3-star Marinca card
	var m1: Dictionary = dave_state.register_marinca_catch("predator", "巡弋暗礁鲨", 2)
	assert(m1.is_new and m1.best_stars == 2 and dave_state.gold == 70)
	var m2: Dictionary = dave_state.register_marinca_catch("predator", "巡弋暗礁鲨", 3)
	assert(m2.upgraded and m2.best_stars == 3 and dave_state.get_three_star_count() == 1)

	# Cook & serve dishes at Bancho Sushi Bar
	var cook1: Dictionary = dave_state.cook_and_serve_sushi("goldfish_nigiri")
	assert(cook1.ok and dave_state.inventory["fish_small"] == 1 and dave_state.max_oxygen == 100.0)
	var cook2: Dictionary = dave_state.cook_and_serve_sushi("kelp_roll")
	assert(cook2.ok and dave_state.max_health == 120.0 and dave_state.health == 120.0)
	var cook3: Dictionary = dave_state.cook_and_serve_sushi("shark_sashimi")
	assert(cook3.ok and dave_state.weapon_attack_bonus == 18.0)

	# Serve all surplus fish in night shift
	var night_res: Dictionary = dave_state.serve_all_surplus_fish()
	assert(night_res.ok and dave_state.inventory["fish_small"] == 0 and dave_state.inventory["fish_meat"] == 0)

	# Buy upgrades at Cobra Shop
	var buy_box: Dictionary = dave_state.buy_cobra_item("cargo_box")
	assert(buy_box.ok and dave_state.get_max_weight() == 65.0 and dave_state.max_drone_charges == 4)
	var buy_oxy: Dictionary = dave_state.buy_cobra_item("oxygen_capsule")
	assert(buy_oxy.ok and dave_state.max_oxygen == 125.0)
	var buy_duff: Dictionary = dave_state.buy_cobra_item("duff_coating")
	assert(buy_duff.ok and dave_state.weapon_attack_bonus == 43.0)

	# Verify V (salvage_drone) and B (sushi_menu) key bindings and VFX
	assert(InputMap.has_action("salvage_drone") and InputMap.has_action("sushi_menu"))
	CombatVFX.spawn_star_rating(root, Vector3(0, -8, 0), 3, "巡弋暗礁鲨")
	CombatVFX.spawn_salvage_balloon(root, Vector3(0, -8, 0))
	CombatVFX.spawn_clam_bubbles(root, Vector3(0, -8, 0))

	ocean.queue_free()

	diver_test.queue_free()
	diver2.queue_free()

	game.free()

	print("PASS: survival, crafting, laser rifle, T/Y aiming, 3-second charge with release, handheld booster H, scout/titan submarines, coral reef & benthic ecosystems, procedural audio, combat VFX, exploration, rebreather and biomods")
	quit()
