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

	# Test sonic rifle kilometer range & 100 damage
	diver.set_weapon("sonic")
	var atk_sonic = diver.attack()
	assert(atk_sonic.weapon == "sonic")
	assert(atk_sonic.base_damage == 100.0)
	assert(atk_sonic.damage == 100.0 + 92.0 * 1.5) # 238.0
	assert(atk_sonic.range == 3000.0) # 3000 meters range
	assert(atk_sonic.is_sonic == true)
	assert(atk_sonic.max_targets == 99) # Pierces all enemies along acoustic cone
	assert(atk_sonic.cleave_angle == 0.35)
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
	diver2.queue_free()

	game.free()

	print("PASS: gathering, recipes, weapons (knife/axe/sonic), fragments (+12/+25), forging (+20/+35), sonic 100dmg/3000m, 165deg cleave, R-key attack, eat fish, rescue, explore mode, rebreather, depth oxygen, recipe pinning, biomod dash")
	quit()
