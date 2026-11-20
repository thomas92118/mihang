extends SceneTree

const CombatTypes = preload("res://scripts/combat/combat_types.gd")
const WeaponCatalog = preload("res://scripts/combat/weapon_catalog.gd")
const SkillCatalog = preload("res://scripts/combat/skill_catalog.gd")
const StatusSystem = preload("res://scripts/combat/status_system.gd")
const CombatController = preload("res://scripts/combat/combat_controller.gd")
const BossAIController = preload("res://scripts/combat/boss_ai_controller.gd")
const SurvivalState = preload("res://scripts/survival.gd")
const LoadoutPanel = preload("res://scripts/presentation/loadout_panel.gd")
const InputController = preload("res://scripts/input_controller.gd")
const TouchControls = preload("res://scripts/touch_controls.gd")
const Game = preload("res://scripts/game.gd")

const TEMP_SAVE_PATH := "user://test_combat_system_voyage.json"


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		_cleanup_temp_files()
		paused = false
		printerr("FAIL: combat system test timed out")
		quit(1)
	)
	_run.call_deferred()


func _cleanup_temp_files() -> void:
	var abs_path := ProjectSettings.globalize_path(TEMP_SAVE_PATH)
	if FileAccess.file_exists(TEMP_SAVE_PATH) or FileAccess.file_exists(abs_path):
		DirAccess.remove_absolute(abs_path)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_cleanup_temp_files()
		paused = false
		printerr("FAIL: ", message)
		quit(1)


func _approx(a: float, b: float, eps: float = 0.01) -> bool:
	return absf(a - b) <= eps


func _run() -> void:
	_cleanup_temp_files()
	_test_weapons_upgrades_and_mods()
	_test_status_reactions_stagger_and_non_lethal()
	_test_combat_controller_defense_dodge_heat()
	_test_skills_and_ultimates()
	_test_companions_roles_and_bond_scaling()
	await _test_boss_ai_four_lords()
	await _test_loadout_inputs_touch_diver_and_game_e2e()
	_cleanup_temp_files()
	paused = false
	print("COMBAT_SYSTEM_OK")
	quit(0)


# ---------------------------------------------------------------------------
# 1. 6大武器原型、5阶深铸升级与8战术模组
# ---------------------------------------------------------------------------
func _test_weapons_upgrades_and_mods() -> void:
	var expected_weapons: Array[String] = [
		"knife",
		"axe",
		"harpoon",
		"sonar_cannon",
		"sonic",
		"marker_gun",
	]
	_expect(WeaponCatalog.WEAPON_ORDER.size() == 6, "WeaponCatalog.WEAPON_ORDER must contain 6 weapons")
	_expect(WeaponCatalog.WEAPON_ORDER == expected_weapons, "WeaponCatalog.WEAPON_ORDER mismatch: %s" % [str(WeaponCatalog.WEAPON_ORDER)])
	_expect(WeaponCatalog.get_all_weapons().size() == 6, "get_all_weapons() must return 6 items")

	var seen_art_ids := {}
	for wid in expected_weapons:
		var w := WeaponCatalog.get_weapon(wid)
		_expect(str(w.get("id", "")) == wid, "Weapon id mismatch for %s" % wid)
		_expect(not str(w.get("name", "")).is_empty(), "Weapon %s must have name" % wid)
		var art: Variant = w.get("weapon_art", {})
		_expect(art is Dictionary and not (art as Dictionary).is_empty(), "Weapon %s must define weapon_art" % wid)
		var art_dict: Dictionary = art
		var art_id := str(art_dict.get("id", ""))
		_expect(not art_id.is_empty(), "Weapon %s weapon_art must have id" % wid)
		_expect(not seen_art_ids.has(art_id), "Weapon %s weapon_art id '%s' must be exclusive" % [wid, art_id])
		seen_art_ids[art_id] = true
		_expect(not str(art_dict.get("name", "")).is_empty(), "Weapon %s weapon_art must have name" % wid)
		_expect(float(art_dict.get("cooldown", 0.0)) > 0.0, "Weapon %s weapon_art must have positive cooldown" % wid)

	_expect(WeaponCatalog.MOD_ORDER.size() == 8, "WeaponCatalog.MOD_ORDER must contain 8 tactical mods")
	_expect(WeaponCatalog.get_all_mods().size() == 8, "get_all_mods() must return 8 mods")
	_expect(WeaponCatalog.MODS.has("anesthetic_coat"), "WeaponCatalog.MODS must include anesthetic_coat")

	# Craft harpoon & sonar_cannon in survival mode, slot equip/swap, Lv.1->Lv.5 deep-forge
	var state := SurvivalState.new()
	state.reset("survival")
	_expect(state.has_weapon("knife"), "Survival starts with knife")
	_expect(not state.has_weapon("harpoon"), "Survival must not start with harpoon")
	_expect(not state.has_weapon("sonar_cannon"), "Survival must not start with sonar_cannon")

	# Lack of materials rejects crafting
	var fail_craft := state.craft("harpoon", true)
	_expect(not fail_craft.is_empty(), "Crafting harpoon without materials must fail")

	# Seed exact materials for harpoon, sonar_cannon, and axe
	state.inventory["titanium"] = 6
	state.inventory["copper"] = 3
	state.inventory["creature_tooth"] = 1
	state.inventory["quartz"] = 2
	state.inventory["chitin"] = 1

	_expect(state.craft("harpoon", true) == "", "Crafting harpoon with required materials must succeed")
	_expect(state.has_weapon("harpoon"), "harpoon must be owned after crafting")
	_expect(state.craft("sonar_cannon", true) == "", "Crafting sonar_cannon with required materials must succeed")
	_expect(state.has_weapon("sonar_cannon"), "sonar_cannon must be owned after crafting")
	_expect(state.craft("axe", true) == "", "Crafting axe with required materials must succeed")
	_expect(state.has_weapon("axe"), "axe must be owned after crafting")
	_expect(int(state.inventory.get("titanium", -1)) == 0, "Crafting must consume titanium")
	_expect(int(state.inventory.get("copper", -1)) == 0, "Crafting must consume copper")
	_expect(int(state.inventory.get("creature_tooth", -1)) == 0, "Crafting must consume creature_tooth")
	_expect(int(state.inventory.get("quartz", -1)) == 0, "Crafting must consume quartz")
	_expect(int(state.inventory.get("chitin", -1)) == 0, "Crafting must consume chitin")

	# Slot equipping and swapping across 3 slots
	var eq0 := state.equip_weapon_to_slot(0, "harpoon")
	_expect(bool(eq0.get("ok", false)), "Equipping harpoon to slot 0 must succeed")
	var eq1 := state.equip_weapon_to_slot(1, "sonar_cannon")
	_expect(bool(eq1.get("ok", false)), "Equipping sonar_cannon to slot 1 must succeed")
	var eq2 := state.equip_weapon_to_slot(2, "axe")
	_expect(bool(eq2.get("ok", false)), "Equipping axe to slot 2 must succeed")
	_expect(state.equipped_weapons == ["harpoon", "sonar_cannon", "axe"], "3 slots must match assigned weapons, got %s" % [str(state.equipped_weapons)])

	var swap_res := state.equip_weapon_to_slot(0, "axe")
	_expect(bool(swap_res.get("ok", false)), "Swapping axe into slot 0 must succeed")
	_expect(state.equipped_weapons == ["axe", "sonar_cannon", "harpoon"], "Swapping slot 0 and 2 must exchange weapons, got %s" % [str(state.equipped_weapons)])

	var bad_slot := state.equip_weapon_to_slot(3, "knife")
	_expect(not bool(bad_slot.get("ok", true)), "Slot index 3 must be rejected (max 3 slots)")
	var bad_weapon := state.equip_weapon_to_slot(0, "sonic")
	_expect(not bool(bad_weapon.get("ok", true)), "Equipping unowned weapon sonic must fail")

	# Deep-forge Lv.1 -> Lv.5 in survival mode with material checks & consumption
	_expect(state.get_weapon_tier("harpoon") == 1, "New weapon must start at Lv.1")
	var no_mat_upg := state.upgrade_weapon_tier("harpoon")
	_expect(not bool(no_mat_upg.get("ok", true)), "Upgrading without materials in survival must fail")
	_expect(state.get_weapon_tier("harpoon") == 1, "Failed upgrade must keep tier at Lv.1")

	for target_tier in range(2, WeaponCatalog.MAX_WEAPON_TIER + 1):
		var cost := WeaponCatalog.get_upgrade_cost("harpoon", target_tier)
		_expect(not cost.is_empty(), "Upgrade cost for harpoon Lv.%d must not be empty" % target_tier)
		for mat_k in cost.keys():
			if str(mat_k) == "gold":
				state.gold += int(cost[mat_k])
			else:
				state.inventory[str(mat_k)] = int(state.inventory.get(str(mat_k), 0)) + int(cost[mat_k])
		var upg := state.upgrade_weapon_tier("harpoon")
		_expect(bool(upg.get("ok", false)), "Upgrade harpoon to Lv.%d must succeed: %s" % [target_tier, str(upg)])
		_expect(int(upg.get("tier", 0)) == target_tier and state.get_weapon_tier("harpoon") == target_tier, "Harpoon tier must reach Lv.%d" % target_tier)
		for mat_k in cost.keys():
			if str(mat_k) != "gold":
				_expect(int(state.inventory.get(str(mat_k), -1)) == 0, "Material %s must be consumed on Lv.%d upgrade" % [str(mat_k), target_tier])

	var cap_upg := state.upgrade_weapon_tier("harpoon")
	_expect(not bool(cap_upg.get("ok", true)), "Upgrading past Lv.5 must fail")
	_expect(state.get_weapon_tier("harpoon") == 5, "Weapon tier must cap at Lv.5")

	# Tactical mod install/uninstall & 2-slot cap (including anesthetic_coat)
	_expect(state.unlock_mod("cavitation_valve"), "Unlocking cavitation_valve must succeed")
	var m1 := state.toggle_weapon_mod("harpoon", "serrated_edge")
	_expect(bool(m1.get("ok", false)) and bool(m1.get("equipped", false)), "Installing mod 1 (serrated_edge) must succeed")
	var m2 := state.toggle_weapon_mod("harpoon", "anesthetic_coat")
	_expect(bool(m2.get("ok", false)) and bool(m2.get("equipped", false)), "Installing mod 2 (anesthetic_coat) must succeed")
	_expect(state.get_weapon_mods("harpoon").size() == 2, "Weapon must hold 2 mods")
	var m3 := state.toggle_weapon_mod("harpoon", "cavitation_valve")
	_expect(not bool(m3.get("ok", true)), "Installing 3rd mod must be rejected by 2-slot limit")
	_expect(state.get_weapon_mods("harpoon").size() == 2, "Mod count must remain 2 after rejected 3rd mod")
	var rem := state.toggle_weapon_mod("harpoon", "serrated_edge")
	_expect(bool(rem.get("ok", false)) and not bool(rem.get("equipped", true)), "Removing serrated_edge must succeed")
	_expect(state.get_weapon_mods("harpoon") == ["anesthetic_coat"], "Remaining mod must be anesthetic_coat")
	var m3_ok := state.toggle_weapon_mod("harpoon", "cavitation_valve")
	_expect(bool(m3_ok.get("ok", false)) and bool(m3_ok.get("equipped", false)), "Installing cavitation_valve after freeing slot must succeed")
	_expect(state.get_weapon_mods("harpoon").size() == 2, "Weapon must again have 2 mods")

	# Explore mode free Lv.1 -> Lv.5 upgrade without materials
	var explore_state := SurvivalState.new()
	explore_state.reset("explore")
	for k in explore_state.inventory.keys():
		explore_state.inventory[k] = 0
	explore_state.gold = 0
	for target_tier in range(2, WeaponCatalog.MAX_WEAPON_TIER + 1):
		var exp_upg := explore_state.upgrade_weapon_tier("sonar_cannon")
		_expect(bool(exp_upg.get("ok", false)), "Explore mode upgrade to Lv.%d must be free" % target_tier)
		_expect(explore_state.get_weapon_tier("sonar_cannon") == target_tier, "Explore sonar_cannon must reach Lv.%d" % target_tier)

	# WeaponCatalog.compute_weapon_stats scaling across tier and mods
	var s_lv1 := WeaponCatalog.compute_weapon_stats("harpoon", 1, [])
	var s_lv5 := WeaponCatalog.compute_weapon_stats("harpoon", 5, [])
	var s_mod := WeaponCatalog.compute_weapon_stats("harpoon", 5, ["serrated_edge", "cavitation_valve"])
	var s_anes := WeaponCatalog.compute_weapon_stats("harpoon", 1, ["anesthetic_coat"])

	_expect(_approx(float(s_lv5["damage"]), float(s_lv1["damage"]) * 1.56, 0.05), "Lv.5 damage must scale by 1.56x")
	_expect(_approx(float(s_lv5["poise_damage"]), float(s_lv1["poise_damage"]) * 1.40, 0.05), "Lv.5 poise must scale by 1.40x")
	_expect(_approx(float(s_mod["damage"]), float(s_lv5["damage"]) * 1.16, 0.05), "serrated_edge must boost damage by 1.16x")
	_expect(_approx(float(s_mod["poise_damage"]), float(s_lv5["poise_damage"]) * 1.28, 0.05), "cavitation_valve must boost poise by 1.28x")
	_expect(_approx(float(s_mod["armor_pierce"]), float(s_lv5["armor_pierce"]) + 0.10, 0.005), "serrated_edge must add +0.10 armor_pierce")
	_expect(not bool(s_lv1["non_lethal_stun"]), "Base harpoon must be lethal")
	_expect(bool(s_anes["non_lethal_stun"]), "anesthetic_coat must enable non_lethal_stun")
	_expect(int(s_anes["star_bias"]) == 3, "anesthetic_coat must elevate star_bias to 3")


# ---------------------------------------------------------------------------
# 2. 4种深海异常与4种元素反应 + 韧性条与破防失衡 + 无损活捕
# ---------------------------------------------------------------------------
func _test_status_reactions_stagger_and_non_lethal() -> void:
	var sys := StatusSystem.new()

	# Verify buildup & trigger for all 4 statuses
	var tid_base := 100
	for i in range(CombatTypes.ALL_STATUSES.size()):
		var status_id := CombatTypes.ALL_STATUSES[i]
		var tid := tid_base + i
		sys.register_target(tid, 1000.0, 0.40)
		var hit_half := sys.apply_hit(tid, {
			"base_damage": 10.0,
			"poise_damage": 0.0,
			"status_type": status_id,
			"status_amount": 55.0,
			"crit_chance": 0.0,
		}, 1000.0, 1000.0)
		_expect(str(hit_half["status_triggered"]) == "", "55 buildup must not trigger %s yet" % status_id)
		var st_mid := sys.get_target_state(tid)
		_expect(_approx(float((st_mid["buildup"] as Dictionary)[status_id]), 55.0), "Buildup for %s must track 55.0" % status_id)

		var hit_full := sys.apply_hit(tid, {
			"base_damage": 10.0,
			"poise_damage": 0.0,
			"status_type": status_id,
			"status_amount": 50.0,
			"crit_chance": 0.0,
		}, 990.0, 1000.0)
		_expect(str(hit_full["status_triggered"]) == status_id, "100+ buildup must trigger %s" % status_id)
		var st_after := sys.get_target_state(tid)
		_expect((st_after["active"] as Dictionary).has(status_id), "Active map must contain %s after trigger" % status_id)
		_expect(_approx(float((st_after["buildup"] as Dictionary)[status_id]), 0.0), "Buildup must reset to 0 after trigger")
		if status_id == CombatTypes.STATUS_RESONANCE:
			_expect(bool(st_after["armor_shredded"]) and _approx(float(st_after["armor"]), 0.0), "Resonance must shred armor to 0")

	# Verify DoT tick for electro & rupture
	var dot_events := sys.tick(1.05)
	var saw_electro_dot := false
	var saw_rupture_dot := false
	for ev in dot_events:
		if str(ev.get("status_type", "")) == CombatTypes.STATUS_ELECTRO and float(ev.get("damage", 0.0)) > 0.0:
			saw_electro_dot = true
		if str(ev.get("status_type", "")) == CombatTypes.STATUS_RUPTURE and float(ev.get("damage", 0.0)) > 0.0:
			saw_rupture_dot = true
	_expect(saw_electro_dot and saw_rupture_dot, "StatusSystem.tick must emit DoT events for electro and rupture")

	# Verify all 4 elemental reactions
	var reaction_cases: Array[Array] = [
		[CombatTypes.STATUS_ELECTRO, CombatTypes.STATUS_STASIS, CombatTypes.REACTION_SUPERCONDUCT],
		[CombatTypes.STATUS_RUPTURE, CombatTypes.STATUS_RESONANCE, CombatTypes.REACTION_IMPLOSION],
		[CombatTypes.STATUS_ELECTRO, CombatTypes.STATUS_RUPTURE, CombatTypes.REACTION_OVERCHARGE],
		[CombatTypes.STATUS_STASIS, CombatTypes.STATUS_RESONANCE, CombatTypes.REACTION_CRYSTAL_FREEZE],
	]
	for idx in range(reaction_cases.size()):
		var pair := reaction_cases[idx]
		var s_a := str(pair[0])
		var s_b := str(pair[1])
		var expected_rxn := str(pair[2])
		var tid := 200 + idx
		sys.register_target(tid, 1000.0, 0.35)
		var r1 := sys.apply_hit(tid, {
			"base_damage": 10.0,
			"poise_damage": 0.0,
			"status_type": s_a,
			"status_amount": 100.0,
			"crit_chance": 0.0,
		}, 1000.0, 1000.0)
		_expect(str(r1["status_triggered"]) == s_a, "First status %s must activate for reaction %s" % [s_a, expected_rxn])
		var r2 := sys.apply_hit(tid, {
			"base_damage": 10.0,
			"poise_damage": 0.0,
			"status_type": s_b,
			"status_amount": 100.0,
			"crit_chance": 0.0,
		}, 980.0, 1000.0)
		var rxns: Array = r2["reactions"]
		_expect(rxns.size() == 1, "Combining %s + %s must trigger exactly 1 reaction, got %d" % [s_a, s_b, rxns.size()])
		var payload: Dictionary = rxns[0]
		_expect(str(payload.get("id", "")) == expected_rxn, "Expected reaction %s, got %s" % [expected_rxn, str(payload.get("id", ""))])
		_expect(float(payload.get("damage", 0.0)) > 0.0, "Reaction %s must deal positive damage" % expected_rxn)
		_expect(float(payload.get("poise_damage", 0.0)) > 0.0, "Reaction %s must deal positive poise_damage" % expected_rxn)
		_expect(float(r2["reaction_damage"]) >= float(payload["damage"]), "Hit result must include reaction_damage for %s" % expected_rxn)
		var post_state := sys.get_target_state(tid)
		var post_active: Dictionary = post_state["active"]
		_expect(not post_active.has(s_a) and not post_active.has(s_b), "Reaction %s must consume both statuses" % expected_rxn)
		if expected_rxn == CombatTypes.REACTION_CRYSTAL_FREEZE:
			_expect(int(payload.get("star_bonus", 0)) >= 1 and bool(r2["capture_ready"]), "crystal_freeze must grant star_bonus and capture_ready stun")

	# Verify poise break -> stagger (4.5s, 1.45x damage) & weakpoint (1.5x damage)
	var tid_poise := 300
	sys.register_target(tid_poise, 100.0, 0.0)
	var wp_only := sys.apply_hit(tid_poise, {
		"base_damage": 100.0,
		"poise_damage": 40.0,
		"crit_chance": 0.0,
		"weakpoint_hit": true,
	}, 2000.0, 2000.0)
	_expect(_approx(float(wp_only["direct_damage"]), 150.0, 0.05), "Weakpoint hit must deal 1.5x damage (150.0), got %f" % float(wp_only["direct_damage"]))
	_expect(not bool(wp_only["stagger_broken"]) and _approx(float(wp_only["poise_remaining"]), 60.0), "Poise must drop to 60 without staggering")

	var break_hit := sys.apply_hit(tid_poise, {
		"base_damage": 100.0,
		"poise_damage": 65.0,
		"crit_chance": 0.0,
		"weakpoint_hit": false,
	}, 1850.0, 2000.0)
	_expect(bool(break_hit["stagger_broken"]), "Depleting poise to 0 must trigger stagger_broken")
	_expect(bool(break_hit["is_staggered"]) and _approx(float(break_hit["stagger_timer"]), 4.5, 0.01), "Stagger must last 4.5s")

	var stag_hit := sys.apply_hit(tid_poise, {
		"base_damage": 100.0,
		"poise_damage": 10.0,
		"crit_chance": 0.0,
		"weakpoint_hit": false,
	}, 1750.0, 2000.0)
	_expect(_approx(float(stag_hit["direct_damage"]), 145.0, 0.05), "Staggered target must take 1.45x damage (145.0), got %f" % float(stag_hit["direct_damage"]))

	var stag_wp_hit := sys.apply_hit(tid_poise, {
		"base_damage": 100.0,
		"poise_damage": 0.0,
		"crit_chance": 0.0,
		"weakpoint_hit": true,
	}, 1605.0, 2000.0)
	_expect(_approx(float(stag_wp_hit["direct_damage"]), 217.5, 0.05), "Stagger + weakpoint must stack to 2.175x (217.5), got %f" % float(stag_wp_hit["direct_damage"]))

	sys.tick(4.6)
	_expect(not sys.is_staggered(tid_poise), "Stagger must end after 4.5s")
	_expect(_approx(float(sys.get_target_state(tid_poise)["poise"]), 100.0), "Poise must restore to max after stagger ends")

	# Verify non_lethal_stun in StatusSystem (anesthetic_coat lethal clamp -> 1 HP + capture_ready)
	var tid_nl := 301
	sys.register_target(tid_nl, 80.0, 0.0)
	var nl_res := sys.apply_hit(tid_nl, {
		"base_damage": 200.0,
		"poise_damage": 20.0,
		"crit_chance": 0.0,
		"non_lethal_stun": true,
		"star_bias": 3,
	}, 35.0, 100.0)
	_expect(bool(nl_res["non_lethal_clamped"]), "Lethal hit with non_lethal_stun must set non_lethal_clamped")
	_expect(_approx(float(nl_res["resulting_hp"]), 1.0, 0.001), "Non-lethal lethal hit must clamp HP to 1.0")
	_expect(bool(nl_res["stun_applied"]) and float(nl_res["stun_timer"]) >= 3.0, "Non-lethal clamp must apply >=3.0s stun")
	_expect(bool(nl_res["capture_ready"]) and sys.is_capture_ready(tid_nl), "Target must be capture_ready after non-lethal stun")


# ---------------------------------------------------------------------------
# 3. 护盾电容、0.25s精准弹反、0.28s极限闪避、开局基础闪避与蓝光枪热量
# ---------------------------------------------------------------------------
func _test_combat_controller_defense_dodge_heat() -> void:
	var ctrl := CombatController.new()
	ctrl.reset(false)

	_expect(_approx(ctrl.shield_energy, 100.0), "Shield energy must start at 100")
	_expect(ctrl.dodge_max_charges == 1 and ctrl.dodge_charges == 1, "Starter survival diver without biomod_dash must have 1 dodge charge")

	# Perfect parry within 0.25s window
	ctrl.shield_energy = 70.0
	_expect(ctrl.on_shield_pressed(), "on_shield_pressed must return true when shield ready")
	_expect(_approx(ctrl.parry_window_timer, 0.25, 0.005), "Parry window must be 0.25s")
	ctrl.tick(0.15, true)
	var parry_res := ctrl.evaluate_incoming_hit(35.0, true, true)
	_expect(str(parry_res["outcome"]) == "perfect_parry", "Parryable hit within 0.25s must return perfect_parry, got %s" % str(parry_res["outcome"]))
	_expect(_approx(float(parry_res["damage_taken"]), 0.0), "Perfect parry must take 0 damage")
	_expect(ctrl.shield_energy > 70.0, "Perfect parry must restore shield energy")
	_expect(float(parry_res["flux_gained"]) > 0.0 and ctrl.flux >= 25.0, "Perfect parry must grant resonance flux")
	_expect(float(parry_res["attacker_poise_damage"]) >= 60.0, "Perfect parry must deal heavy attacker poise damage")
	_expect(bool(parry_res["trigger_bullet_time"]), "Perfect parry must trigger bullet time")

	# Non-parryable (red glow) attack cannot be parried
	_expect(ctrl.on_shield_pressed(), "on_shield_pressed must succeed for red-attack test")
	ctrl.tick(0.05, true)
	var red_res := ctrl.evaluate_incoming_hit(30.0, true, false)
	_expect(str(red_res["outcome"]) != "perfect_parry", "Red-glow unblockable/non-parryable attack must NOT trigger perfect_parry")
	_expect(float(red_res["damage_taken"]) > 0.0, "Non-parryable attack must still deal chip/full damage")

	# Parry window expires after 0.25s
	_expect(ctrl.on_shield_pressed(), "on_shield_pressed must succeed for expiry test")
	ctrl.tick(0.26, true)
	var late_res := ctrl.evaluate_incoming_hit(25.0, true, true)
	_expect(str(late_res["outcome"]) == "block", "Blocking after 0.25s parry window must downgrade to block, got %s" % str(late_res["outcome"]))

	# Shield overload when energy insufficient
	ctrl.shield_energy = 10.0
	ctrl.parry_window_timer = 0.0
	var break_res := ctrl.evaluate_incoming_hit(50.0, true, true)
	_expect(str(break_res["outcome"]) == "shield_break" and ctrl.shield_overloaded, "Insufficient shield energy must cause shield_break and overload")
	_expect(not ctrl.on_shield_pressed(), "Cannot deploy shield while overloaded")

	# Starter dodge (1 charge) & 0.28s perfect dodge -> bullet time + guaranteed next crit
	ctrl.reset(false)
	var d1 := ctrl.try_dodge(false)
	_expect(bool(d1["ok"]) and int(d1["charges"]) == 0 and int(d1["max_charges"]) == 1, "First base dodge must consume 1/1 charge")
	_expect(_approx(float(d1["invuln_duration"]), 0.28, 0.005), "Dodge invulnerability window must be 0.28s")
	var d1_fail := ctrl.try_dodge(false)
	_expect(not bool(d1_fail["ok"]) and str(d1_fail["reason"]) == "cooldown", "Second immediate dodge without biomod_dash must fail on cooldown")

	ctrl.tick(0.12, false)
	var pd_res := ctrl.evaluate_incoming_hit(60.0, false, false)
	_expect(str(pd_res["outcome"]) == "perfect_dodge", "Hit inside 0.28s dodge window must trigger perfect_dodge")
	_expect(_approx(float(pd_res["damage_taken"]), 0.0), "Perfect dodge must take 0 damage")
	_expect(bool(pd_res["trigger_bullet_time"]) and ctrl.bullet_time_timer > 0.0, "Perfect dodge must trigger bullet time")
	_expect(ctrl.consume_perfect_dodge_crit(), "Perfect dodge must grant next-attack guaranteed crit")
	_expect(not ctrl.consume_perfect_dodge_crit(), "Guaranteed crit from perfect dodge must be consumed once")

	# Unlocking biomod_dash grants 2 dodge charges
	ctrl.tick(4.0, false)
	var d_bio1 := ctrl.try_dodge(true)
	_expect(bool(d_bio1["ok"]) and int(d_bio1["max_charges"]) == 2 and int(d_bio1["charges"]) == 1, "biomod_dash must expand dodge to 2 charges and leave 1 after first dodge")
	var d_bio2 := ctrl.try_dodge(true)
	_expect(bool(d_bio2["ok"]) and int(d_bio2["charges"]) == 0, "Second consecutive dodge with biomod_dash must succeed")
	var d_bio3 := ctrl.try_dodge(true)
	_expect(not bool(d_bio3["ok"]), "Third consecutive dodge must fail on cooldown")

	# Sonic rifle heat: normal hit builds heat to overheat, weakpoint adds 0 heat, cool_sonic_completely clears
	ctrl.reset(false)
	_expect(ctrl.consume_sonic_heat(18.0, true), "Weakpoint shot must succeed")
	_expect(_approx(ctrl.sonic_heat, 0.0) and not ctrl.sonic_overheated, "Weakpoint hit must generate 0 sonic heat")
	for _s in range(4):
		_expect(ctrl.consume_sonic_heat(25.0, false), "Normal shot before overheat must succeed")
	_expect(_approx(ctrl.sonic_heat, 100.0) and ctrl.sonic_overheated, "4x25 heat must overheat sonic rifle")
	_expect(not ctrl.consume_sonic_heat(18.0, false), "Overheated sonic rifle must block normal fire")
	_expect(not ctrl.consume_sonic_heat(18.0, true), "Overheated sonic rifle must block fire even on weakpoint")
	ctrl.cool_sonic_completely()
	_expect(_approx(ctrl.sonic_heat, 0.0) and not ctrl.sonic_overheated, "cool_sonic_completely must clear heat and overheat flag")
	_expect(ctrl.consume_sonic_heat(18.0, false), "Sonic rifle must fire normally after cool_sonic_completely")


# ---------------------------------------------------------------------------
# 4. 3系6个主动战术技与3套潮汐终极技
# ---------------------------------------------------------------------------
func _test_skills_and_ultimates() -> void:
	_expect(SkillCatalog.TACTICAL_ORDER.size() == 6, "SkillCatalog must have 6 tactical skills")
	_expect(SkillCatalog.get_all_tactical_skills().size() == 6, "get_all_tactical_skills must return 6 items")
	for branch in [SkillCatalog.BRANCH_HUNTER, SkillCatalog.BRANCH_CAPTURE, SkillCatalog.BRANCH_COMMANDER]:
		var branch_skills := SkillCatalog.get_tactical_skills_by_branch(branch)
		_expect(branch_skills.size() == 2, "Branch %s must have 2 tactical skills, got %d" % [branch, branch_skills.size()])

	var expected_ults: Array[String] = [
		"mermaid_tide_domain",
		"diver_orbital_sonar",
		"sub_torpedo_barrage",
	]
	_expect(SkillCatalog.ULTIMATE_ORDER == expected_ults, "SkillCatalog.ULTIMATE_ORDER must match 3 ultimates")
	_expect(SkillCatalog.get_all_ultimates().size() == 3, "get_all_ultimates must return 3 ultimates")

	_expect(str(SkillCatalog.get_ultimate_for_context("coral_mermaid", false)["id"]) == "mermaid_tide_domain", "Mermaid must map to mermaid_tide_domain")
	_expect(str(SkillCatalog.get_ultimate_for_context("expedition_diver", false)["id"]) == "diver_orbital_sonar", "Expedition diver must map to diver_orbital_sonar")
	_expect(str(SkillCatalog.get_ultimate_for_context("coral_mermaid", true)["id"]) == "sub_torpedo_barrage", "Submarine context must map to sub_torpedo_barrage")

	var ctrl := CombatController.new()
	ctrl.reset(false)

	# Tactical skill oxygen check & cooldown (blood_surge costs 15 oxygen, 16s CD)
	var low_oxy := ctrl.try_tactical_skill("blood_surge", 10.0)
	_expect(not bool(low_oxy["ok"]) and str(low_oxy["reason"]) == "low_oxygen", "blood_surge must reject when oxygen < 15")
	var ok_tac := ctrl.try_tactical_skill("blood_surge", 25.0)
	_expect(bool(ok_tac["ok"]) and _approx(float(ok_tac["oxygen_cost"]), 15.0) and _approx(float(ok_tac["cooldown"]), 16.0), "blood_surge must succeed with sufficient oxygen and start 16s CD")
	var cd_tac := ctrl.try_tactical_skill("hydro_grapple", 100.0)
	_expect(not bool(cd_tac["ok"]) and str(cd_tac["reason"]) == "cooldown", "Tactical skill must be blocked while on cooldown")
	ctrl.tick(16.1, false)
	var after_cd := ctrl.try_tactical_skill("hydro_grapple", 100.0)
	_expect(bool(after_cd["ok"]), "Tactical skill must become available after cooldown expires")

	# Ultimate requires full 100 flux and switches by character/submarine context
	ctrl.reset(false)
	ctrl.add_flux(99.0)
	_expect(not ctrl.ultimate_ready(), "Ultimate must not be ready at 99 flux")
	var fail_ult := ctrl.try_ultimate("coral_mermaid", false)
	_expect(not bool(fail_ult["ok"]) and str(fail_ult["reason"]) == "insufficient_flux", "try_ultimate must fail below 100 flux")

	ctrl.add_flux(1.0)
	_expect(ctrl.ultimate_ready(), "Ultimate must be ready at 100 flux")
	var u_mermaid := ctrl.try_ultimate("coral_mermaid", false)
	_expect(bool(u_mermaid["ok"]) and str(u_mermaid["ultimate_id"]) == "mermaid_tide_domain" and _approx(ctrl.flux, 0.0), "Mermaid ultimate must trigger and spend 100 flux")

	ctrl.add_flux(100.0)
	var u_diver := ctrl.try_ultimate("expedition_diver", false)
	_expect(bool(u_diver["ok"]) and str(u_diver["ultimate_id"]) == "diver_orbital_sonar" and _approx(ctrl.flux, 0.0), "Diver ultimate must trigger diver_orbital_sonar")

	ctrl.add_flux(100.0)
	var u_sub := ctrl.try_ultimate("coral_mermaid", true)
	_expect(bool(u_sub["ok"]) and str(u_sub["ultimate_id"]) == "sub_torpedo_barrage" and _approx(ctrl.flux, 0.0), "Submarine ultimate must trigger sub_torpedo_barrage")


# ---------------------------------------------------------------------------
# 5. 战宠3出战席位、4类职能与温和羁绊倍率
# ---------------------------------------------------------------------------
func _test_companions_roles_and_bond_scaling() -> void:
	var prev_mult := 0.0
	for n in range(1, 21):
		var mult := CombatController.compute_companion_damage_multiplier(n, 3)
		var expected := 1.0 + minf(0.60, float(n - 1) * 0.04)
		_expect(_approx(mult, expected, 0.0005), "Companion multiplier for n=%d expected %.3f, got %.3f" % [n, expected, mult])
		_expect(mult >= prev_mult, "Companion multiplier must be monotonically non-decreasing")
		_expect(mult <= 1.6001, "Companion multiplier must cap at 1.60, got %.3f" % mult)
		prev_mult = mult
	_expect(_approx(CombatController.compute_companion_damage_multiplier(1, 3), 1.0), "1 pet multiplier must be 1.0")
	_expect(_approx(CombatController.compute_companion_damage_multiplier(20, 3), 1.60), "20 pets multiplier must cap at 1.60")

	var state := SurvivalState.new()
	state.reset("survival")
	var sample_species: Array[String] = ["predator", "angler", "sea_turtle", "seal", "kraken"]
	for i in range(sample_species.size()):
		state.add_tamed_creature({"kind": sample_species[i], "name": "Pet_%d" % i})
	_expect(state.tamed_creatures.size() == 5, "Must store all 5 tamed creatures")
	_expect(state.get_deployed_pets().size() == 3, "Deployed pets must be capped at 3 when 5 are tamed, got %d" % state.get_deployed_pets().size())
	state.set_deployed_pet_indices([0, 1, 2, 3, 4])
	_expect(state.get_deployed_pets().size() <= 3, "set_deployed_pet_indices must enforce <= 3 deployed pets")

	# Verify all 4 pet roles in CombatTypes.get_pet_role
	var role_checks := {
		"predator": CombatTypes.PET_ROLE_STRIKER,
		"shark": CombatTypes.PET_ROLE_STRIKER,
		"angler": CombatTypes.PET_ROLE_CONTROL,
		"kraken": CombatTypes.PET_ROLE_CONTROL,
		"water_dragon": CombatTypes.PET_ROLE_CONTROL,
		"sea_turtle": CombatTypes.PET_ROLE_TANK,
		"colossus_turtle": CombatTypes.PET_ROLE_TANK,
		"seal": CombatTypes.PET_ROLE_SUPPORT,
		"flying_fish": CombatTypes.PET_ROLE_SUPPORT,
	}
	var seen_roles := {}
	for species_k in role_checks.keys():
		var role := CombatTypes.get_pet_role(str(species_k))
		var expected_role := str(role_checks[species_k])
		_expect(role == expected_role, "Species %s expected role %s, got %s" % [str(species_k), expected_role, role])
		seen_roles[role] = true
	_expect(seen_roles.size() == 4, "CombatTypes.get_pet_role must cover all 4 distinct roles")


# ---------------------------------------------------------------------------
# 6. 四大领主独立3阶段AI、弱点、护甲与失衡暂停
# ---------------------------------------------------------------------------
func _test_boss_ai_four_lords() -> void:
	var ai := BossAIController.new()
	var bosses: Array[String] = ["water_dragon", "flying_fish", "kraken", "colossus_turtle"]
	var seen_weakpoints := {}

	for bid in bosses:
		var wp_label := ai.get_weakpoint_label(bid)
		_expect(not wp_label.is_empty(), "Boss %s must have weakpoint label" % bid)
		_expect(not seen_weakpoints.has(wp_label), "Boss %s weakpoint label %s must be unique" % [bid, wp_label])
		seen_weakpoints[wp_label] = true

		var armor := ai.get_base_armor(bid)
		var poise := ai.get_max_poise(bid)
		_expect(armor > 0.0 and armor < 0.9, "Boss %s must have valid base armor, got %f" % [bid, armor])
		_expect(poise >= 120.0, "Boss %s must have boss-grade max poise >= 120, got %f" % [bid, poise])

		var boss_node := Node3D.new()
		boss_node.position = Vector3(0.0, -18.0, 0.0)
		boss_node.set_meta("max_health", 2000.0)
		boss_node.set_meta("health", 2000.0)
		boss_node.set_meta("kind", bid)
		root.add_child(boss_node)
		await process_frame

		ai.reset_boss(bid)
		var floor_y := -22.0
		var diver_pos := Vector3(0.0, -18.0, 5.5)

		# Phase 1 at 100% HP
		var p1 := ai.tick_boss(bid, boss_node, diver_pos, floor_y, 0.1, 0.1, false)
		_expect(int(p1["phase"]) == 1, "Boss %s at 100%% HP must be Phase 1" % bid)
		_expect(str(p1["weakpoint_label"]) == wp_label, "Boss %s tick must return matching weakpoint_label" % bid)
		_expect(p1["weakpoint_pos"] is Vector3, "Boss %s must return Vector3 weakpoint_pos" % bid)

		# Phase 2 at 55% HP
		boss_node.set_meta("health", 1100.0)
		var p2 := ai.tick_boss(bid, boss_node, diver_pos, floor_y, 0.1, 0.2, false)
		_expect(int(p2["phase"]) == 2, "Boss %s at 55%% HP must shift to Phase 2" % bid)
		_expect(bool(boss_node.get_meta("enraged", false)), "Boss %s at Phase 2 must be enraged" % bid)

		# Phase 3 at 30% HP
		boss_node.set_meta("health", 600.0)
		var p3 := ai.tick_boss(bid, boss_node, diver_pos, floor_y, 0.1, 0.3, false)
		_expect(int(p3["phase"]) == 3, "Boss %s at 30%% HP must shift to Phase 3" % bid)

		# Drive full move rotation so both parryable and unblockable attacks fire
		var saw_parryable := false
		var saw_unblockable := false
		var saw_telegraph := false
		var clock := 0.4
		var dt := 0.1
		var prev_action := str(p3["action"])
		for _step in range(220):
			clock += dt
			if prev_action == "circle":
				diver_pos = boss_node.global_position + Vector3(0.0, 0.0, 5.5)
				diver_pos.y = clampf(diver_pos.y, floor_y + 2.5, -4.0)
			var res := ai.tick_boss(bid, boss_node, diver_pos, floor_y, dt, clock, false)
			var cur_action := str(res["action"])
			if cur_action != prev_action and cur_action != "circle":
				diver_pos = boss_node.global_position + Vector3(0.0, 0.0, 5.5)
				diver_pos.y = clampf(diver_pos.y, floor_y + 2.5, -4.0)
			prev_action = cur_action
			for _tg in (res["telegraphs"] as Array):
				saw_telegraph = true
			for atk_v in (res["attacks"] as Array):
				var atk: Dictionary = atk_v
				if bool(atk.get("parryable", false)):
					saw_parryable = true
				else:
					saw_unblockable = true
			if saw_parryable and saw_unblockable and saw_telegraph:
				break

		_expect(saw_telegraph, "Boss %s must emit telegraphs during move rotation" % bid)
		_expect(saw_parryable, "Boss %s must generate at least one parryable attack" % bid)
		_expect(saw_unblockable, "Boss %s must generate at least one non-parryable attack" % bid)

		# Staggered pause check
		var stag := ai.tick_boss(bid, boss_node, diver_pos, floor_y, 0.1, clock + 0.1, true)
		_expect(str(stag["action"]) == "staggered", "Staggered boss %s must report action='staggered'" % bid)
		_expect((stag["attacks"] as Array).is_empty(), "Staggered boss %s must emit 0 attacks" % bid)
		_expect((stag["telegraphs"] as Array).is_empty(), "Staggered boss %s must emit 0 telegraphs" % bid)
		_expect("失衡" in str(stag["warning"]), "Staggered boss %s must display stagger warning" % bid)

		boss_node.queue_free()
		await process_frame


# ---------------------------------------------------------------------------
# 7. 武装配置面板、输入动作、触控新按钮、Diver 6武器模型、旧存档迁移与Game E2E
# ---------------------------------------------------------------------------
func _test_loadout_inputs_touch_diver_and_game_e2e() -> void:
	# 7a. Legacy save migration -> build_loadout_payload -> LoadoutPanel.build / update_data
	var migrated := SurvivalState.new()
	var legacy_save := {
		"mode": "survival",
		"weapons": ["knife", "axe"],
		"gold": 180,
		"inventory": {"titanium": 6, "copper": 4, "creature_tooth": 2},
		"health": 88.0,
		"oxygen": 62.0,
	}
	migrated.from_dict(legacy_save)
	_expect(migrated.has_weapon("knife") and migrated.has_weapon("axe"), "Legacy migration must preserve knife & axe")
	_expect(migrated.equipped_weapons.size() >= 2, "Legacy migration must populate equipped_weapons")
	_expect(migrated.get_weapon_tier("knife") == 1 and migrated.get_weapon_tier("axe") == 1, "Legacy migration must initialize weapon_tiers to 1")
	_expect(migrated.unlocked_mods.size() >= 2, "Legacy migration must initialize default unlocked_mods")
	_expect(SkillCatalog.TACTICAL_SKILLS.has(migrated.active_tactical_skill), "Legacy migration must initialize valid active_tactical_skill")

	var payload := migrated.build_loadout_payload("coral_mermaid", false)
	_expect(payload.has("weapons_catalog") and (payload["weapons_catalog"] as Array).size() == 6, "Loadout payload must contain 6 weapons")
	_expect(payload.has("mods_catalog") and (payload["mods_catalog"] as Array).size() == 8, "Loadout payload must contain 8 mods")
	_expect(payload.has("skills_catalog") and (payload["skills_catalog"] as Array).size() == 6, "Loadout payload must contain 6 tactical skills")

	var host := Control.new()
	host.size = Vector2(1280.0, 720.0)
	root.add_child(host)
	var view := LoadoutPanel.build(host, {})
	_expect(not view.is_empty() and is_instance_valid(view.get("card")), "LoadoutPanel.build must create valid card")
	LoadoutPanel.update_data(view, payload)
	# Switch across all 3 tabs and narrow/touch layout without errors
	var tab_buttons: Dictionary = view["tab_buttons"]
	for tab_id in ["mods", "skills", "weapons"]:
		var btn: Button = tab_buttons[tab_id]
		btn.pressed.emit()
		LoadoutPanel.update_data(view, payload)
	LoadoutPanel.set_touch_mode(view, true)
	LoadoutPanel.set_responsive_layout(view, Vector2(540.0, 680.0))
	LoadoutPanel.set_touch_mode(view, false)
	LoadoutPanel.set_responsive_layout(view, Vector2(1100.0, 720.0))
	host.queue_free()
	await process_frame

	# 7b. InputController registers the 4 new actions
	var input_ctrl := InputController.new()
	root.add_child(input_ctrl)
	await process_frame
	for action_name in ["weapon_art", "tactical_skill", "ultimate_skill", "loadout_menu"]:
		_expect(InputMap.has_action(action_name), "InputController must register action '%s'" % action_name)
		_expect(not InputMap.action_get_events(action_name).is_empty(), "Action '%s' must have input binding" % action_name)
	input_ctrl.queue_free()
	await process_frame

	# 7c. TouchControls new combat buttons & signals
	var touch := TouchControls.new()
	touch.size = Vector2(1280.0, 720.0)
	root.add_child(touch)
	await process_frame
	_expect(touch.has_signal("weapon_art_requested"), "TouchControls must expose weapon_art_requested signal")
	_expect(touch.has_signal("tactical_skill_requested"), "TouchControls must expose tactical_skill_requested signal")
	_expect(touch.has_signal("ultimate_skill_requested"), "TouchControls must expose ultimate_skill_requested signal")
	_expect(touch._buttons.has("weapon_art"), "TouchControls must lay out weapon_art button")
	_expect(touch._ultimate_rect.size.x > 0.0 and touch._ultimate_rect.size.y > 0.0, "TouchControls must lay out ultimate_skill rect")
	touch.queue_free()
	await process_frame

	# 7d. Full Game E2E in explore mode
	var game := Game.new()
	game.voyage_save_path = TEMP_SAVE_PATH
	root.add_child(game)
	game._start("explore")
	await process_frame
	await physics_frame

	# Freeze autonomous loops so assertions stay deterministic
	game.set_process(false)
	game.set_physics_process(false)
	game.ocean.set_process(false)
	game.diver.set_process(false)
	game.diver.set_physics_process(false)

	# Verify Diver 6 weapon switching, new animation APIs & zero camera yaw drift
	game.diver.position = Vector3(180.0, -12.0, 70.0)
	game.diver.rotation = Vector3.ZERO
	game.diver.camera.rotation = Vector3.ZERO
	var base_diver_yaw: float = float(game.diver.rotation.y)
	var base_cam_yaw: float = float(game.diver.camera.rotation.y)

	for wid in WeaponCatalog.WEAPON_ORDER:
		game._switch_weapon(wid)
		_expect(game.diver.current_weapon == wid, "Diver must switch to weapon '%s', got '%s'" % [wid, str(game.diver.current_weapon)])
		_expect(game.diver.weapon_nodes.has(wid), "Diver must build 3D model node for '%s'" % wid)
		_expect((game.diver.weapon_nodes[wid] as Node3D).visible, "Active weapon node '%s' must be visible" % wid)
		game.diver.attack_cooldown = 0.0
		var atk_res: Dictionary = game.diver.attack()
		_expect(not atk_res.is_empty(), "Diver.attack() must succeed for weapon '%s'" % wid)
		game.diver.trigger_weapon_art_pose(wid)
		game.diver.trigger_parry_flash()
		game.diver.trigger_dodge_impulse(Vector3.FORWARD, 18.0, 0.2)
		game.diver.trigger_grapple_pull(game.diver.global_position + Vector3(0.0, 0.0, -6.0), 3.0, 24.0)
		for _f in range(45):
			game.diver._process(0.05)
			game.diver._physics_process(0.05)
		_expect(absf(game.diver.rotation.y - base_diver_yaw) < 0.02, "Diver yaw must not drift after weapon '%s' anims (diff=%.4f)" % [wid, absf(game.diver.rotation.y - base_diver_yaw)])
		_expect(absf(game.diver.camera.rotation.y - base_cam_yaw) < 0.02, "Camera local yaw must not drift after weapon '%s' anims (diff=%.4f)" % [wid, absf(game.diver.camera.rotation.y - base_cam_yaw)])

	# Verify ocean.damage_creature non_lethal_stun integration (anesthetic_coat live capture)
	_expect(not game.ocean.small_fish.is_empty(), "Ocean must spawn small_fish for live non-lethal test")
	var live_fish: Node3D = game.ocean.small_fish[0]
	live_fish.set_meta("dead", false)
	live_fish.set_meta("tamed", false)
	live_fish.set_meta("health", 25.0)
	var nl_live: Dictionary = game.ocean.damage_creature(live_fish, 999.0, Vector3.ZERO, false, {"non_lethal_stun": true})
	_expect(bool(nl_live.get("hit", false)), "ocean.damage_creature must register hit")
	_expect(not bool(nl_live.get("killed", true)), "Non-lethal ocean hit must NOT kill creature")
	_expect(_approx(float(nl_live.get("health_left", -1.0)), 1.0, 0.001), "Non-lethal ocean hit must leave 1.0 HP")
	_expect(bool(nl_live.get("stunned_for_capture", false)), "Non-lethal ocean hit must return stunned_for_capture=true")
	_expect(bool(live_fish.get_meta("stunned_for_capture", false)), "Creature meta must record stunned_for_capture=true")
	_expect(not bool(live_fish.get_meta("dead", false)), "Creature must remain alive after non-lethal stun")

	# Verify combat execution inside Game: weapon art, tactical skill, ultimate, shield parry, dodge
	game._switch_weapon("harpoon")
	game.combat_ctrl.weapon_art_cd = 0.0
	game._trigger_weapon_art()
	_expect(game.combat_ctrl.weapon_art_cd > 0.0, "Game._trigger_weapon_art must execute and start weapon_art_cd")

	game.combat_ctrl.tactical_cd = 0.0
	game._trigger_tactical_skill()
	_expect(game.combat_ctrl.tactical_cd > 0.0, "Game._trigger_tactical_skill must execute and start tactical_cd")

	game.combat_ctrl.add_flux(100.0)
	game._trigger_ultimate_skill()
	_expect(_approx(game.combat_ctrl.flux, 0.0) and game.ultimate_active_timer > 0.0, "Game._trigger_ultimate_skill must spend flux and activate ultimate")

	if not game.diver.shield_active:
		game.diver.toggle_shield()
	_expect(game.diver.shield_active, "Diver shield must be active")
	_expect(game.combat_ctrl.on_shield_pressed(), "Game shield press must open parry window")
	var live_parry: Dictionary = game.combat_ctrl.evaluate_incoming_hit(25.0, game.diver.shield_active, true)
	_expect(str(live_parry["outcome"]) == "perfect_parry", "Shield parry evaluation inside Game must succeed")

	game.combat_ctrl.dodge_charges = game.combat_ctrl.dodge_max_charges
	game._perform_dash()
	_expect(game.combat_ctrl.dodge_invuln_timer > 0.0, "Game._perform_dash must activate dodge_invuln_timer")

	# Verify opening and operating the "loadout" screen in Game
	game._toggle_loadout_screen()
	_expect(game.screen == "loadout", "Opening loadout screen must set game.screen='loadout'")
	_expect(game.hud.menus.has("loadout") and (game.hud.menus["loadout"] as Control).visible, "HUD loadout menu must be visible")
	game._on_loadout_equip_slot_requested(0, "sonar_cannon")
	game._on_loadout_upgrade_weapon_requested("sonar_cannon")
	game._on_loadout_toggle_mod_requested("sonar_cannon", "anesthetic_coat")
	game._on_loadout_select_tactical_requested("sonar_net")
	_expect(game.state.get_weapon_tier("sonar_cannon") >= 2, "Loadout upgrade callback must raise sonar_cannon tier")
	_expect(game.state.get_weapon_mods("sonar_cannon").has("anesthetic_coat"), "Loadout mod callback must equip anesthetic_coat")
	_expect(game.state.active_tactical_skill == "sonar_net", "Loadout tactical callback must switch to sonar_net")
	game._toggle_loadout_screen()
	_expect(game.screen == "play", "Toggling loadout screen again must return to 'play'")

	# Regression: non_lethal_stun through Game pipeline must stun & clamp live fish to 1 HP
	var non_lethal_fish: Node3D = null
	for c in game.ocean.small_fish:
		if is_instance_valid(c) and not bool(c.get_meta("dead", false)):
			non_lethal_fish = c
			break
	_expect(is_instance_valid(non_lethal_fish), "Must find a live small fish for non_lethal_stun Game pipeline test")
	non_lethal_fish.set_meta("health", 25.0)
	non_lethal_fish.set_meta("max_health", 25.0)
	non_lethal_fish.set_meta("stunned_for_capture", false)
	non_lethal_fish.set_meta("stun_timer", 0.0)
	non_lethal_fish.set_meta("freeze_timer", 0.0)
	var nl_res: Dictionary = game._apply_combat_damage_to_creature(
		non_lethal_fish,
		{"source_weapon": "sonar_cannon", "base_damage": 200.0, "non_lethal_stun": true},
		non_lethal_fish.global_position
	)
	_expect(bool(nl_res.get("stunned_for_capture", false)), "Game._apply_combat_damage_to_creature non_lethal_stun must set stunned_for_capture=true")
	_expect(bool(non_lethal_fish.get_meta("stunned_for_capture", false)), "Target metadata stunned_for_capture must be true")
	_expect(_approx(float(non_lethal_fish.get_meta("health", 0.0)), 1.0), "Non-lethal stun through Game pipeline must clamp HP to 1.0")

	game.queue_free()
	await process_frame
