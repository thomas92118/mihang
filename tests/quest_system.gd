extends SceneTree
## End-to-end tests for the Abyssal Echo quest system:
## catalog integrity, 5-act main progression, out-of-order anti-softlock,
## explore mode exemptions, side quests & dynamic echo bounties,
## serialization & legacy voyage save migration, HUD/QuestPanel/WorldMap layout & Game return stack.

const QuestCatalog = preload("res://scripts/quests/quest_catalog.gd")
const QuestManager = preload("res://scripts/quests/quest_manager.gd")
const QuestPanel = preload("res://scripts/presentation/quest_panel.gd")
const HUD = preload("res://scripts/hud.gd")
const Game = preload("res://scripts/game.gd")

const TEMP_LEGACY_SAVE := "user://test_quest_system_legacy_voyage.json"
const TEMP_E2E_SAVE := "user://test_quest_system_e2e_voyage.json"

class FakeInputs extends Node:
	signal device_changed(device: String)
	signal settings_changed
	var active_device := "keyboard"
	var settings := {
		"gamepad_sensitivity": 1.0,
		"touch_sensitivity": 1.0,
		"deadzone": 0.2,
		"touch_scale": 1.0,
		"touch_opacity": 0.75,
		"invert_y": false,
		"touch_mode": "auto",
	}
	func hint(action: String) -> String:
		if active_device == "touch":
			return "TOUCH_" + action
		if active_device == "gamepad":
			return "PAD_" + action
		return "KEY_" + action

func _initialize() -> void:
	create_timer(45.0).timeout.connect(func() -> void:
		_cleanup_temp_files()
		printerr("QUEST_SYSTEM_TEST_TIMEOUT")
		quit(1)
	)
	_run.call_deferred()

func _cleanup_temp_files() -> void:
	for path in [TEMP_LEGACY_SAVE, TEMP_E2E_SAVE]:
		var abs_path := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(path) or FileAccess.file_exists(abs_path):
			DirAccess.remove_absolute(abs_path)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_cleanup_temp_files()
		paused = false
		printerr("ASSERTION_FAILED: ", message)
		quit(1)

func _make_base_snapshot(chosen_mode: String = "survival") -> Dictionary:
	return {
		"mode": chosen_mode,
		"black_box_read": false,
		"rescued": false,
		"escape_crafted": false,
		"mother_tree_active": false,
		"tank": false,
		"fins": false,
		"rebreather": false,
		"weapons": ["knife"],
		"inventory": {},
		"conquered_bosses": {},
		"outposts_count": 0,
		"relics_count": 0,
		"landmarks_count": 0,
		"dishes_served": 0,
		"marinca_species_count": 0,
		"marinca_three_star_count": 0,
		"tamed_beasts_count": 0,
		"explorer_rank_level": 1,
		"has_nearest_outpost": true,
		"nearest_outpost_pos": Vector3(40.0, -10.0, 340.0),
		"nearest_outpost_name": "北境环礁科考站",
		"exploration_pct": 0,
		"explorer_rank": "深海见习勘测员"
	}

func _make_action_event(action_name: String) -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = action_name
	ev.pressed = true
	return ev

func _run() -> void:
	_cleanup_temp_files()
	_test_catalog_integrity()
	_test_main_quest_survival_progression()
	_test_out_of_order_anti_softlock()
	_test_explore_mode_exemptions()
	_test_side_quests_and_bounties()
	await _test_save_serialization_and_legacy_migration()
	await _test_hud_quest_panel_world_map_and_banners()
	await _test_game_quests_e2e_and_return_stack()
	_cleanup_temp_files()
	print("PASS: quest catalog, 5-act survival progression, anti-softlock, explore exemptions, side quests & bounties, save/legacy migration, HUD/QuestPanel/WorldMap & Game return stack")
	quit(0)

func _test_catalog_integrity() -> void:
	var all_quests := QuestCatalog.get_all_quests()
	var main_quests: Array[Dictionary] = []
	var side_quests: Array[Dictionary] = []
	var quest_ids := {}

	for q in all_quests:
		var qid := str(q.get("id", ""))
		_expect(not qid.is_empty(), "Quest ID must not be empty")
		_expect(not quest_ids.has(qid), "Duplicate quest ID: %s" % qid)
		quest_ids[qid] = q
		_expect(not str(q.get("title", "")).strip_edges().is_empty(), "Quest %s must have non-empty title" % qid)
		_expect(not str(q.get("brief", "")).strip_edges().is_empty(), "Quest %s must have non-empty brief" % qid)

		var cat := str(q.get("category", ""))
		_expect(cat == "main" or cat == "side", "Catalog quest %s has invalid category: %s" % [qid, cat])
		if cat == "main":
			main_quests.append(q)
		else:
			side_quests.append(q)

		var objs: Array = q.get("objectives", [])
		_expect(not objs.is_empty(), "Quest %s must have at least one objective" % qid)
		var obj_ids := {}
		for obj in objs:
			var oid := str(obj.get("id", ""))
			_expect(not oid.is_empty() and not obj_ids.has(oid), "Quest %s has invalid/duplicate objective ID: %s" % [qid, oid])
			obj_ids[oid] = true
			_expect(not str(obj.get("label", "")).strip_edges().is_empty(), "Objective %s.%s missing label" % [qid, oid])
			_expect(not str(obj.get("type", "")).strip_edges().is_empty(), "Objective %s.%s missing type" % [qid, oid])
			_expect(int(obj.get("required", 0)) >= 1, "Objective %s.%s must have required >= 1" % [qid, oid])
			if obj.has("nav_pos"):
				var np: Variant = obj.get("nav_pos")
				_expect(np is Vector3, "Objective %s.%s nav_pos must be Vector3" % [qid, oid])
				var np_v: Vector3 = np
				_expect(np_v.is_finite() and np_v.length_squared() > 0.01, "Objective %s.%s nav_pos must be finite non-zero Vector3, got %s" % [qid, oid, str(np_v)])
				_expect(not str(obj.get("nav_label", "")).strip_edges().is_empty(), "Objective %s.%s with nav_pos must define nav_label" % [qid, oid])

		var rewards: Dictionary = q.get("rewards", {})
		_expect(not str(rewards.get("summary", "")).strip_edges().is_empty(), "Quest %s missing rewards.summary" % qid)

	_expect(main_quests.size() == 5, "Expected 5 main quests, got %d" % main_quests.size())
	_expect(side_quests.size() == 10, "Expected 10 side quests, got %d" % side_quests.size())
	for i in range(5):
		var act_num := int(main_quests[i].get("act", 0))
		_expect(act_num == i + 1, "Main quest index %d must have act=%d, got %d" % [i, i + 1, act_num])
		var fetched := QuestCatalog.get_quest(str(main_quests[i]["id"]))
		_expect(str(fetched.get("id", "")) == str(main_quests[i]["id"]), "QuestCatalog.get_quest lookup mismatch")

	for q in all_quests:
		var qid := str(q.get("id", ""))
		for req_id in q.get("unlock_requires", []):
			var req_s := str(req_id)
			_expect(quest_ids.has(req_s), "Quest %s unlock_requires missing target: %s" % [qid, req_s])
			_expect(req_s != qid, "Quest %s cannot require itself" % qid)

	var bounties := QuestCatalog.get_bounty_templates()
	_expect(bounties.size() == 8, "Expected 8 bounty templates, got %d" % bounties.size())
	var bounty_ids := {}
	var depth_bounty_count := 0
	for tpl in bounties:
		var tid := str(tpl.get("id", ""))
		_expect(not tid.is_empty() and not bounty_ids.has(tid), "Invalid/duplicate bounty template ID: %s" % tid)
		bounty_ids[tid] = true
		_expect(str(tpl.get("category", "")) == "bounty", "Bounty template %s must have category='bounty'" % tid)
		_expect(not str(tpl.get("title", "")).strip_edges().is_empty(), "Bounty %s missing title" % tid)
		_expect(not str(tpl.get("brief", "")).strip_edges().is_empty(), "Bounty %s missing brief" % tid)
		var b_objs: Array = tpl.get("objectives", [])
		_expect(not b_objs.is_empty(), "Bounty %s must have objectives" % tid)
		for obj in b_objs:
			_expect(int(obj.get("required", 0)) >= 1, "Bounty %s objective required must be >= 1" % tid)
			if str(obj.get("type", "")) == "depth_hold":
				depth_bounty_count += 1
				_expect(float(obj.get("target_depth", 0.0)) > 0.0, "Depth bounty %s must have target_depth > 0" % tid)
			if obj.has("nav_pos"):
				var bpos: Variant = obj.get("nav_pos")
				_expect(bpos is Vector3 and (bpos as Vector3).is_finite() and (bpos as Vector3).length_squared() > 0.01, "Bounty %s nav_pos must be finite non-zero Vector3" % tid)
		var b_rew: Dictionary = tpl.get("rewards", {})
		_expect(int(b_rew.get("gold", 0)) > 0 and not str(b_rew.get("summary", "")).strip_edges().is_empty(), "Bounty %s must define valid rewards" % tid)
	_expect(depth_bounty_count >= 3, "Expected at least 3 depth_hold bounty templates, got %d" % depth_bounty_count)

	_expect(QuestCatalog.OUTPOST_COORD_NAMES.size() == 6, "Expected 6 outpost coordinate entries")
	for spec in QuestCatalog.OUTPOST_COORD_NAMES:
		var xz: Vector2 = spec["xz"]
		_expect(xz.length_squared() > 1.0, "Outpost coord %s must be non-zero" % str(spec["name"]))
		var resolved := QuestCatalog.resolve_outpost_name(Vector3(xz.x, -12.0, xz.y))
		_expect(resolved == str(spec["name"]), "resolve_outpost_name failed for %s" % str(spec["name"]))

	print("  [OK] 1. Catalog integrity (5 main, 10 side, 8 bounties, valid coords & unlock graph)")

func _test_main_quest_survival_progression() -> void:
	var qm := QuestManager.new()
	qm.reset("survival")
	var snap := _make_base_snapshot("survival")

	_expect(qm.quest_states["mq_01_shallow_foothold"]["status"] == "active", "Act 1 must start active")
	_expect(qm.quest_states["mq_02_relay_network"]["status"] == "locked", "Act 2 must start locked")
	_expect(qm.quest_states["mq_03_four_lords"]["status"] == "locked", "Act 3 must start locked")
	_expect(qm.quest_states["mq_04_mother_tree"]["status"] == "locked", "Act 4 must start locked")
	_expect(qm.quest_states["mq_05_warp_escape"]["status"] == "locked", "Act 5 must start locked")
	_expect(qm.tracked_quest_id == "mq_01_shallow_foothold", "Act 1 must be tracked initially")
	_expect(not qm.bounties_unlocked and qm.active_bounties.is_empty(), "Bounties must stay locked initially")

	snap["tank"] = true
	snap["black_box_read"] = true
	snap["rescued"] = true
	var res1 := qm.reconcile(snap, false)
	_expect(bool(res1["changed"]), "Act 1 completion should report changed")
	_expect(qm.quest_states["mq_01_shallow_foothold"]["status"] == "completed", "Act 1 must complete")
	_expect(bool(qm.quest_states["mq_01_shallow_foothold"]["rewarded"]), "Act 1 must mark rewarded")
	_expect(int(res1["granted_gold"]) == 120, "Act 1 must grant 120G, got %d" % int(res1["granted_gold"]))
	var items1: Dictionary = res1["granted_items"]
	_expect(int(items1.get("titanium", 0)) == 1 and int(items1.get("quartz", 0)) == 1, "Act 1 must grant titanium x1 and quartz x1")
	_expect(qm.quest_states["mq_02_relay_network"]["status"] == "active", "Act 2 must unlock after Act 1")
	_expect(qm.tracked_quest_id == "mq_02_relay_network", "Tracker must advance to Act 2")
	_expect((res1["banners"] as Array).size() >= 2, "Act 1 completion + Act 2 unlock should emit banners")

	var res1_dup := qm.reconcile(snap, false)
	_expect(int(res1_dup["granted_gold"]) == 0 and (res1_dup["granted_items"] as Dictionary).is_empty(), "Re-reconciling Act 1 must not duplicate rewards")

	snap["outposts_count"] = 2
	snap["weapons"] = ["knife", "sonic"]
	snap["rebreather"] = true
	var res2 := qm.reconcile(snap, false)
	_expect(qm.quest_states["mq_02_relay_network"]["status"] == "completed", "Act 2 must complete")
	_expect(int(res2["granted_gold"]) == 200, "Act 2 must grant 200G, got %d" % int(res2["granted_gold"]))
	var items2: Dictionary = res2["granted_items"]
	_expect(int(items2.get("copper", 0)) == 2 and int(items2.get("quartz", 0)) == 2, "Act 2 must grant copper x2 and quartz x2")
	_expect(qm.quest_states["mq_03_four_lords"]["status"] == "active", "Act 3 must unlock after Act 2")
	_expect(qm.tracked_quest_id == "mq_03_four_lords", "Tracker must advance to Act 3")
	_expect(qm.bounties_unlocked, "Bounties must unlock once outposts >= 1")
	_expect(qm.active_bounties.size() == 3, "Expected 3 active bounties upon unlock, got %d" % qm.active_bounties.size())
	var seen_tpl := {}
	for b in qm.active_bounties:
		var tid := str(b.get("template_id", ""))
		_expect(not tid.is_empty() and not seen_tpl.has(tid), "Unlocked bounties must have 3 distinct templates")
		seen_tpl[tid] = true

	var lords := ["water_dragon", "flying_fish", "kraken", "colossus_turtle"]
	var boss_dict: Dictionary = {}
	for idx in range(lords.size()):
		boss_dict[lords[idx]] = true
		snap["conquered_bosses"] = boss_dict.duplicate()
		var r_boss := qm.reconcile(snap, false)
		if idx < 3:
			_expect(qm.quest_states["mq_03_four_lords"]["status"] == "active", "Act 3 must remain active after %d/4 lords" % (idx + 1))
			_expect(qm.quest_states["mq_04_mother_tree"]["status"] == "locked", "Act 4 must stay locked until all 4 lords are conquered")
			_expect((r_boss["completed_objectives"] as Array).size() == 1, "Each conquered lord should complete 1 objective")
		else:
			_expect(qm.quest_states["mq_03_four_lords"]["status"] == "completed", "Act 3 must complete after 4th lord")
			_expect(int(r_boss["granted_gold"]) == 360, "Act 3 must grant 360G, got %d" % int(r_boss["granted_gold"]))
			_expect(qm.quest_states["mq_04_mother_tree"]["status"] == "active", "Act 4 must unlock after Act 3")
			_expect(qm.tracked_quest_id == "mq_04_mother_tree", "Tracker must advance to Act 4")

	snap["mother_tree_active"] = true
	snap["inventory"] = {
		"mother_tree_essence": 1,
		"ancient_star_core": 1,
		"tree_seed": 1
	}
	var res4 := qm.reconcile(snap, false)
	_expect(qm.quest_states["mq_04_mother_tree"]["status"] == "completed", "Act 4 must complete after 3 relics")
	_expect(int(res4["granted_gold"]) == 300, "Act 4 must grant 300G, got %d" % int(res4["granted_gold"]))
	_expect(qm.quest_states["mq_05_warp_escape"]["status"] == "active", "Act 5 must unlock after Act 4")
	_expect(qm.tracked_quest_id == "mq_05_warp_escape", "Tracker must advance to Act 5")

	snap["escape_crafted"] = true
	var res5 := qm.reconcile(snap, false)
	_expect(qm.quest_states["mq_05_warp_escape"]["status"] == "completed", "Act 5 must complete after escape_crafted")
	_expect(int(res5["granted_gold"]) == 500, "Act 5 must grant 500G, got %d" % int(res5["granted_gold"]))
	for mq_id in ["mq_01_shallow_foothold", "mq_02_relay_network", "mq_03_four_lords", "mq_04_mother_tree", "mq_05_warp_escape"]:
		_expect(qm.quest_states[mq_id]["status"] == "completed", "Main quest %s should be completed" % mq_id)

	print("  [OK] 2. Survival 5-act main progression & bounty unlock")

func _test_out_of_order_anti_softlock() -> void:
	var qm := QuestManager.new()
	qm.reset("survival")
	var snap := _make_base_snapshot("survival")

	snap["conquered_bosses"] = {
		"water_dragon": true,
		"flying_fish": true,
		"kraken": true,
		"colossus_turtle": true
	}
	snap["inventory"] = {
		"mother_tree_essence": 1,
		"ancient_star_core": 1,
		"tree_seed": 1
	}
	var early_res := qm.reconcile(snap, false)
	_expect(qm.quest_states["mq_01_shallow_foothold"]["status"] == "active", "Act 1 must remain active when prerequisites are missing")
	_expect(qm.quest_states["mq_03_four_lords"]["status"] == "locked", "Act 3 must remain locked until Act 2 completes")
	_expect(qm.quest_states["mq_04_mother_tree"]["status"] == "locked", "Act 4 must remain locked until Act 3 completes")
	_expect(int(early_res["granted_gold"]) == 0, "No premature main quest rewards should be granted")

	snap["tank"] = true
	snap["black_box_read"] = true
	snap["rescued"] = true
	snap["outposts_count"] = 2
	snap["weapons"] = ["knife", "sonic"]
	snap["rebreather"] = true

	var chain_res := qm.reconcile(snap, false)
	_expect(qm.quest_states["mq_01_shallow_foothold"]["status"] == "completed", "Chain reconcile must complete Act 1")
	_expect(qm.quest_states["mq_02_relay_network"]["status"] == "completed", "Chain reconcile must complete Act 2")
	_expect(qm.quest_states["mq_03_four_lords"]["status"] == "completed", "Chain reconcile must complete Act 3")
	_expect(qm.quest_states["mq_04_mother_tree"]["status"] == "completed", "Chain reconcile must complete Act 4")
	_expect(qm.quest_states["mq_05_warp_escape"]["status"] == "active", "Chain reconcile must smoothly enter Act 5")
	_expect(qm.tracked_quest_id == "mq_05_warp_escape", "Tracked quest must jump straight to Act 5")
	_expect(int(chain_res["granted_gold"]) == 120 + 200 + 360 + 300, "Single chain reconcile must sum rewards from Acts 1-4 (980G), got %d" % int(chain_res["granted_gold"]))

	var noop_res := qm.reconcile(snap, false)
	_expect(int(noop_res["granted_gold"]) == 0 and (noop_res["completed_quests"] as Array).is_empty(), "No duplicate completion after chain reconcile")

	print("  [OK] 3. Out-of-order anti-softlock chain convergence to Act 5")

func _test_explore_mode_exemptions() -> void:
	var qm := QuestManager.new()
	qm.reset("explore")

	var act1_objs: Dictionary = qm.quest_states["mq_01_shallow_foothold"]["objectives"]
	var act2_objs: Dictionary = qm.quest_states["mq_02_relay_network"]["objectives"]
	_expect(bool(act1_objs["craft_starter_gear"]["done"]), "Explore mode must auto-complete Act 1 gear craft objective")
	_expect(bool(act2_objs["craft_deep_kit"]["done"]), "Explore mode must auto-complete Act 2 deep kit craft objective")
	_expect(qm.quest_states["mq_01_shallow_foothold"]["status"] == "active", "Act 1 must still wait for black_box_read & rescued in explore mode")

	var snap := _make_base_snapshot("explore")
	snap["black_box_read"] = true
	snap["rescued"] = true
	var r1 := qm.reconcile(snap, false)
	_expect(qm.quest_states["mq_01_shallow_foothold"]["status"] == "completed", "Act 1 must complete without gear crafting in explore mode")
	_expect(int(r1["granted_gold"]) == 120, "Act 1 should grant 120G once")
	_expect(qm.quest_states["mq_02_relay_network"]["status"] == "active", "Act 2 must unlock in explore mode")

	snap["outposts_count"] = 2
	var r2 := qm.reconcile(snap, false)
	_expect(qm.quest_states["mq_02_relay_network"]["status"] == "completed", "Act 2 must complete without sonic/rebreather crafting in explore mode")
	_expect(int(r2["granted_gold"]) == 200, "Act 2 should grant 200G once")
	_expect(qm.quest_states["mq_03_four_lords"]["status"] == "active", "Act 3 must unlock in explore mode")

	var r_repeat := qm.reconcile(snap, false)
	_expect(int(r_repeat["granted_gold"]) == 0, "Explore mode must not duplicate rewards on re-reconcile")

	var qm_switch := QuestManager.new()
	qm_switch.reset("survival")
	_expect(not bool(qm_switch.quest_states["mq_01_shallow_foothold"]["objectives"]["craft_starter_gear"]["done"]), "Survival mode must not auto-complete craft_starter_gear")
	qm_switch.set_mode("explore")
	_expect(bool(qm_switch.quest_states["mq_01_shallow_foothold"]["objectives"]["craft_starter_gear"]["done"]), "set_mode('explore') must auto-complete craft_starter_gear")

	print("  [OK] 4. Explore mode gear-crafting exemptions without reward duplication")

func _test_side_quests_and_bounties() -> void:
	var qm := QuestManager.new()
	qm.reset("survival")
	var snap := _make_base_snapshot("survival")

	_expect(qm.quest_states["sq_sushi_perfect_catch"]["status"] == "active", "sq_sushi_perfect_catch must start active")
	_expect(qm.quest_states["sq_sushi_bancho_chef"]["status"] == "locked", "sq_sushi_bancho_chef must start locked")
	var r_catch := qm.notify_event("perfect_catch", {}, snap)
	_expect(qm.quest_states["sq_sushi_perfect_catch"]["status"] == "completed", "perfect_catch must complete sq_sushi_perfect_catch")
	_expect(int(r_catch["granted_gold"]) == 90, "sq_sushi_perfect_catch must grant 90G")
	_expect(qm.quest_states["sq_sushi_bancho_chef"]["status"] == "active", "sq_sushi_bancho_chef must unlock")

	snap["dishes_served"] = 3
	var r_chef := qm.reconcile(snap, false)
	_expect(qm.quest_states["sq_sushi_bancho_chef"]["status"] == "completed", "3 served dishes must complete sq_sushi_bancho_chef")
	_expect(int(r_chef["granted_gold"]) == 150, "sq_sushi_bancho_chef must grant 150G")
	_expect(qm.quest_states["sq_sushi_marinca_codex"]["status"] == "active", "sq_sushi_marinca_codex must unlock")

	snap["marinca_species_count"] = 5
	snap["marinca_three_star_count"] = 2
	var r_codex := qm.reconcile(snap, false)
	_expect(qm.quest_states["sq_sushi_marinca_codex"]["status"] == "completed", "Marinca milestones must complete sq_sushi_marinca_codex")
	_expect(int(r_codex["granted_gold"]) == 260, "sq_sushi_marinca_codex must grant 260G")

	snap["tamed_beasts_count"] = 1
	var r_tame := qm.reconcile(snap, false)
	_expect(qm.quest_states["sq_companion_first_tame"]["status"] == "completed", "1 tamed beast must complete sq_companion_first_tame")
	_expect(int(r_tame["granted_gold"]) == 120, "sq_companion_first_tame must grant 120G")
	_expect(qm.quest_states["sq_companion_pack_leader"]["status"] == "active", "sq_companion_pack_leader must unlock")

	qm.notify_event("submarine_boarded", {}, snap)
	_expect(qm.quest_states["sq_companion_sub_pilot"]["status"] == "active", "sq_companion_sub_pilot still needs torpedo_fired")
	var r_sub := qm.notify_event("torpedo_fired", {}, snap)
	_expect(qm.quest_states["sq_companion_sub_pilot"]["status"] == "completed", "Submarine boarding + torpedo must complete sq_companion_sub_pilot")
	_expect(int(r_sub["granted_gold"]) == 160, "sq_companion_sub_pilot must grant 160G")

	snap["tamed_beasts_count"] = 3
	qm.reconcile(snap, false)
	_expect(qm.quest_states["sq_companion_pack_leader"]["status"] == "active", "sq_companion_pack_leader still needs marker_commanded")
	var r_pack := qm.notify_event("marker_commanded", {}, snap)
	_expect(qm.quest_states["sq_companion_pack_leader"]["status"] == "completed", "3 beasts + marker_commanded must complete sq_companion_pack_leader")
	_expect(int(r_pack["granted_gold"]) == 240, "sq_companion_pack_leader must grant 240G")

	snap["outposts_count"] = 6
	snap["relics_count"] = 6
	snap["explorer_rank_level"] = 4
	snap["landmarks_count"] = 12
	var r_exp := qm.reconcile(snap, false)
	_expect(qm.quest_states["sq_explore_outposts"]["status"] == "completed", "6 outposts must complete sq_explore_outposts")
	_expect(qm.quest_states["sq_explore_relics"]["status"] == "completed", "6 relics must complete sq_explore_relics")
	_expect(qm.quest_states["sq_explore_master_rank"]["status"] == "completed", "Rank 4 + 12 landmarks must complete sq_explore_master_rank")
	_expect(int(r_exp["granted_gold"]) == 320 + 280 + 350, "Exploration side quests should grant 950G total, got %d" % int(r_exp["granted_gold"]))

	qm.notify_event("fragment_absorbed", {}, snap)
	_expect(qm.quest_states["sq_forge_deep_upgrade"]["status"] == "active", "sq_forge_deep_upgrade still needs deep_forge_done")
	var r_forge := qm.notify_event("deep_forge_done", {}, snap)
	_expect(qm.quest_states["sq_forge_deep_upgrade"]["status"] == "completed", "fragment_absorbed + deep_forge_done must complete sq_forge_deep_upgrade")
	_expect(int(r_forge["granted_gold"]) == 180, "sq_forge_deep_upgrade must grant 180G")

	_expect(qm.bounties_unlocked and qm.active_bounties.size() == 3, "Bounties must be active after outposts unlocked")
	var before_tpls: Array[String] = []
	for b in qm.active_bounties:
		before_tpls.append(str(b["template_id"]))
	var refreshed := qm.refresh_bounties()
	_expect(refreshed, "refresh_bounties() must return true when unlocked")
	_expect(qm.active_bounties.size() == 3, "refresh_bounties() must maintain 3 active bounties")
	var after_tpls := {}
	for b in qm.active_bounties:
		var tid := str(b["template_id"])
		_expect(not after_tpls.has(tid), "Refreshed bounties must not have duplicate templates")
		_expect(not before_tpls.has(tid), "Refreshed bounties should avoid immediately repeating previous 3 templates")
		after_tpls[tid] = true

	var saved_for_bounty := qm.to_save_dict()
	saved_for_bounty["active_bounties"] = [
		{
			"id": "bounty_test_depth_1",
			"template_id": "bounty_depth_twilight",
			"objectives": [{"id": "hold_twilight_depth", "current": 0, "done": false, "hold_sec": 0.0}]
		},
		{
			"id": "bounty_test_sonar_2",
			"template_id": "bounty_sonar_sweep",
			"objectives": [{"id": "ping_sonar_twice", "current": 0, "done": false, "hold_sec": 0.0}]
		},
		{
			"id": "bounty_test_mineral_3",
			"template_id": "bounty_mineral_harvest",
			"objectives": [{"id": "collect_four_minerals", "current": 0, "done": false, "hold_sec": 0.0}]
		}
	]
	qm.from_save_dict(saved_for_bounty)
	var prev_completed_bounties := qm.completed_bounty_count

	var r_shallow := qm.tick_depth(2.0, 45.0)
	_expect(not bool(r_shallow["changed"]), "tick_depth below target_depth must not advance depth_hold bounty")

	var r_partial := qm.tick_depth(2.5, 135.0)
	_expect(bool(r_partial["changed"]) and (r_partial["completed_quests"] as Array).is_empty(), "2.5s hold should advance progress without completing")
	_expect(int(qm.active_bounties[0]["objectives"][0]["current"]) == 2, "Expected current=2 after 2.5s hold")

	var r_depth_done := qm.tick_depth(1.6, 135.0)
	_expect(int(r_depth_done["granted_gold"]) == 100, "bounty_depth_twilight must grant 100G")
	_expect(int((r_depth_done["granted_items"] as Dictionary).get("quartz", 0)) == 1, "bounty_depth_twilight must grant quartz x1")
	_expect(qm.completed_bounty_count == prev_completed_bounties + 1, "completed_bounty_count must increment after depth bounty completion")
	_expect(qm.active_bounties.size() == 3, "Completed bounty must be replenished back to 3 active bounties")
	var post_depth_tpls := {}
	for b in qm.active_bounties:
		_expect(str(b["id"]) != "bounty_test_depth_1", "Completed depth bounty must be removed from active_bounties")
		var tid := str(b["template_id"])
		_expect(not post_depth_tpls.has(tid), "Replenished bounties must remain deduplicated")
		post_depth_tpls[tid] = true

	qm.notify_event("sonar_pinged")
	var r_sonar_bounty := qm.notify_event("sonar_pinged")
	_expect(int(r_sonar_bounty["granted_gold"]) == 75, "bounty_sonar_sweep must grant 75G after 2 pings")
	_expect(qm.completed_bounty_count == prev_completed_bounties + 2, "completed_bounty_count must increment after sonar bounty")
	_expect(qm.active_bounties.size() == 3, "Active bounties must replenish back to 3 after event bounty")

	print("  [OK] 5. All 10 side quests + dynamic echo bounties (tick_depth, events, refresh & refill)")

func _test_save_serialization_and_legacy_migration() -> void:
	var qm1 := QuestManager.new()
	qm1.reset("survival")
	var snap := _make_base_snapshot("survival")
	snap["tank"] = true
	snap["black_box_read"] = true
	snap["rescued"] = true
	snap["outposts_count"] = 1
	qm1.reconcile(snap, false)
	qm1.notify_event("submarine_boarded", {}, snap)

	var tmp_save := qm1.to_save_dict()
	tmp_save["active_bounties"][0] = {
		"id": "bounty_rt_depth",
		"template_id": "bounty_depth_bathyal",
		"objectives": [{"id": "hold_bathyal_depth", "current": 2, "done": false, "hold_sec": 2.35}]
	}
	qm1.from_save_dict(tmp_save)
	_expect(qm1.set_tracked_quest("sq_companion_sub_pilot", "fire_torpedo"), "Tracking sq_companion_sub_pilot must succeed")
	qm1.set_tracker_hidden(true)
	qm1.completed_bounty_count = 4

	var serialized := qm1.to_save_dict()
	var qm2 := QuestManager.new()
	qm2.from_save_dict(serialized)

	_expect(qm2.mode == "survival", "Round-trip must preserve mode")
	_expect(qm2.tracked_quest_id == "sq_companion_sub_pilot", "Round-trip must preserve tracked_quest_id")
	_expect(qm2.tracked_objective_id == "fire_torpedo", "Round-trip must preserve tracked_objective_id")
	_expect(qm2.tracker_hidden == true, "Round-trip must preserve tracker_hidden")
	_expect(qm2.bounties_unlocked == true, "Round-trip must preserve bounties_unlocked")
	_expect(qm2.completed_bounty_count == 4, "Round-trip must preserve completed_bounty_count")
	_expect(qm2.quest_states["mq_01_shallow_foothold"]["status"] == "completed", "Round-trip must preserve Act 1 completion")
	_expect(bool(qm2.quest_states["sq_companion_sub_pilot"]["objectives"]["board_submarine"]["done"]), "Round-trip must preserve partial side objective")
	_expect(qm2.active_bounties.size() == 3, "Round-trip must restore 3 active bounties")
	_expect(str(qm2.active_bounties[0]["id"]) == "bounty_rt_depth", "Round-trip must preserve bounty ID")
	_expect(is_equal_approx(float(qm2.active_bounties[0]["objectives"][0]["hold_sec"]), 2.35), "Round-trip must preserve bounty hold_sec")

	var legacy_payload := {
		"version": 1,
		"timestamp": int(Time.get_unix_time_from_system()),
		"mode": "survival",
		"character_id": "diver",
		"diver_pos": [0.0, -8.0, 14.0],
		"diver_rot_y": 0.0,
		"cam_pitch": -0.16,
		"current_weapon": "sonic",
		"lamp_on": false,
		"shield_active": false,
		"booster_active": false,
		"conquered_bosses": ["water_dragon", "kraken"],
		"tamed_beasts": [],
		"survival": {
			"mode": "survival",
			"selected_character": "diver",
			"inventory": {
				"titanium": 5,
				"copper": 4,
				"quartz": 3,
				"kelp": 2,
				"fish_meat": 1
			},
			"weapons": ["knife", "sonic"],
			"tank": true,
			"fins": false,
			"rebreather": true,
			"black_box_read": true,
			"rescued": true,
			"unlocked_outposts": ["outpost_atoll", "outpost_kelp"],
			"collected_relics": [],
			"landmarks_discovered": [],
			"gold": 425,
			"dishes_served": 0,
			"marinca_cards": {}
		}
	}
	_expect(not legacy_payload.has("quests"), "Legacy save fixture must omit 'quests' field")
	var wf := FileAccess.open(TEMP_LEGACY_SAVE, FileAccess.WRITE)
	_expect(wf != null, "Failed to create temporary legacy save file")
	wf.store_string(JSON.stringify(legacy_payload))
	wf.close()

	var game := Game.new()
	game.gameplay_guide.persist_enabled = false
	game.voyage_save_path = TEMP_LEGACY_SAVE
	root.add_child(game)
	game.gameplay_guide.persist_enabled = false
	game.set_process(false)
	game.set_physics_process(false)
	game.ocean.process_mode = Node.PROCESS_MODE_DISABLED
	game.diver.set_physics_process(false)
	game.diver.set_process(false)
	await process_frame

	var loaded := game.load_voyage()
	_expect(loaded, "Game.load_voyage() must succeed on legacy save")
	_expect(game.quest_manager.quest_states["mq_01_shallow_foothold"]["status"] == "completed", "Legacy migration must complete Act 1")
	_expect(bool(game.quest_manager.quest_states["mq_01_shallow_foothold"]["rewarded"]), "Legacy migration must mark Act 1 rewarded")
	_expect(game.quest_manager.quest_states["mq_02_relay_network"]["status"] == "completed", "Legacy migration must complete Act 2")
	_expect(bool(game.quest_manager.quest_states["mq_02_relay_network"]["rewarded"]), "Legacy migration must mark Act 2 rewarded")
	_expect(game.quest_manager.quest_states["mq_03_four_lords"]["status"] == "active", "Legacy migration must land cleanly on Act 3")
	var act3_objs: Dictionary = game.quest_manager.quest_states["mq_03_four_lords"]["objectives"]
	_expect(bool(act3_objs["lord_water_dragon"]["done"]), "Legacy migration must check off water_dragon")
	_expect(bool(act3_objs["lord_kraken"]["done"]), "Legacy migration must check off kraken")
	_expect(not bool(act3_objs["lord_flying_fish"]["done"]), "Legacy migration must keep flying_fish incomplete")
	_expect(not bool(act3_objs["lord_colossus_turtle"]["done"]), "Legacy migration must keep colossus_turtle incomplete")
	_expect(game.quest_manager.tracked_quest_id == "mq_03_four_lords", "Legacy migration must auto-track Act 3")
	_expect(game.quest_manager.bounties_unlocked and game.quest_manager.active_bounties.size() == 3, "Legacy migration with 2 outposts must unlock 3 bounties")

	_expect(game.state.gold == 425, "Legacy migration must not re-grant gold (expected 425, got %d)" % game.state.gold)
	_expect(int(game.state.inventory.get("titanium", 0)) == 5, "Legacy migration must not re-grant titanium")
	_expect(int(game.state.inventory.get("quartz", 0)) == 3, "Legacy migration must not re-grant quartz")
	_expect(int(game.state.inventory.get("copper", 0)) == 4, "Legacy migration must not re-grant copper")

	game._reconcile_quests(false)
	_expect(game.state.gold == 425, "Post-migration reconcile must not duplicate gold")

	_expect(game.save_voyage(), "save_voyage() must succeed on temp path")
	var rf := FileAccess.open(TEMP_LEGACY_SAVE, FileAccess.READ)
	_expect(rf != null, "Saved temp file should be readable")
	var parsed: Variant = JSON.parse_string(rf.get_as_text())
	rf.close()
	_expect(parsed is Dictionary and (parsed as Dictionary).has("quests"), "Saved voyage JSON must include 'quests' block")

	paused = false
	game.free()
	await process_frame
	_cleanup_temp_files()

	print("  [OK] 6. Serialization round-trip & legacy voyage_save.json silent migration")

func _test_hud_quest_panel_world_map_and_banners() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	root.add_child(viewport)
	var inputs := FakeInputs.new()
	viewport.add_child(inputs)
	var hud := HUD.new()
	viewport.add_child(hud)
	await process_frame
	hud.configure_input(inputs)
	hud.set_process(false)
	await process_frame

	var qm := QuestManager.new()
	qm.reset("survival")
	var snap := _make_base_snapshot("survival")
	snap["outposts_count"] = 1
	qm.reconcile(snap, true)

	var player_pos := Vector3(0.0, -8.0, 12.0)
	var journal := qm.get_journal_payload(player_pos, snap)
	var tracker := qm.get_hud_tracker_payload(player_pos, snap)
	var markers := qm.get_map_markers(snap)
	_expect(not markers.is_empty(), "Active main quest with nav objectives must produce map markers")

	var layout_cases := [
		{"size": Vector2i(1280, 720), "device": "keyboard", "touch_mode": "auto", "expect_narrow": false},
		{"size": Vector2i(420, 840), "device": "touch", "touch_mode": "on", "expect_narrow": true},
	]
	for lc: Dictionary in layout_cases:
		var sz: Vector2i = lc["size"]
		viewport.size = sz
		hud.root.size = Vector2(sz)
		inputs.active_device = str(lc["device"])
		inputs.settings["touch_mode"] = str(lc["touch_mode"])
		inputs.settings_changed.emit()
		inputs.device_changed.emit(inputs.active_device)
		hud.set_screen("quests")
		hud.sync_quest_journal(journal)
		hud._process(0.1)
		await process_frame

		var vp_rect := Rect2(Vector2.ZERO, Vector2(sz))
		var card: Panel = hud.quest_view["card"]
		_expect(card.is_visible_in_tree(), "QuestLogCard must be visible at %s" % [sz])
		_expect(bool(hud.quest_view.get("narrow_mode", false)) == bool(lc["expect_narrow"]), "QuestPanel narrow_mode mismatch at %s" % [sz])
		var card_rect := card.get_global_rect()
		_expect(vp_rect.encloses(card_rect.grow(-1.0)), "QuestLogCard overflows viewport at %s (card=%s)" % [sz, card_rect])

		for key in ["close_btn", "tab_bar", "list_scroll", "detail_pane", "action_bar"]:
			var ctrl: Control = hud.quest_view[key]
			if is_instance_valid(ctrl) and ctrl.is_visible_in_tree():
				var r := ctrl.get_global_rect()
				_expect(card_rect.grow(1.0).encloses(r.grow(-1.0)), "QuestPanel child '%s' overflows card at %s (child=%s, card=%s)" % [key, sz, r, card_rect])
				_expect(vp_rect.encloses(r.grow(-1.0)), "QuestPanel child '%s' overflows viewport at %s (child=%s)" % [key, sz, r])

		var tab_buttons: Dictionary = hud.quest_view["tab_buttons"]
		for tid in ["main", "side", "bounty", "completed"]:
			(tab_buttons[tid] as Button).pressed.emit()
			await process_frame
			var r_after := card.get_global_rect()
			_expect(vp_rect.encloses(r_after.grow(-1.0)), "QuestLogCard overflows viewport on tab '%s' at %s" % [tid, sz])
		(tab_buttons["main"] as Button).pressed.emit()
		await process_frame

	viewport.size = Vector2i(1280, 720)
	hud.root.size = Vector2(1280, 720)
	inputs.active_device = "keyboard"
	inputs.settings["touch_mode"] = "auto"
	inputs.settings_changed.emit()
	hud.set_screen("map")
	var hud_data := {
		"mode": "survival",
		"oxygen": 85.0,
		"max_oxygen": 90.0,
		"health": 100.0,
		"depth": 8.0,
		"biome": "阳光浅礁带",
		"current_weapon": "knife",
		"inventory": {"titanium": 1},
		"player_pos": player_pos,
		"player_forward": Vector3.FORWARD,
		"quest_tracker": tracker,
		"quest_markers": markers,
		"quest_journal": journal,
	}
	hud.update_hud(hud_data)
	await process_frame
	_expect(hud.minimap_radar.quest_markers.size() == markers.size(), "MinimapRadar must receive quest_markers")
	_expect(hud.sea_chart.quest_markers.size() == markers.size(), "SeaChart must receive quest_markers")
	var chart_nodes: Array = hud.sea_chart._collect_interactive_nodes()
	var found_quest_node := false
	for node in chart_nodes:
		if str(node.get("kind", "")) == "quest" and str(node.get("quest_id", "")) == qm.tracked_quest_id:
			found_quest_node = true
			break
	_expect(found_quest_node, "SeaChart interactive nodes must expose tracked quest markers")

	hud.set_screen("play")
	hud.update_hud(hud_data)
	hud.push_quest_banners([
		{"kind": "objective", "title": "目标达成 · 浅礁立足", "detail": "探查失事科考潜艇黑匣子", "accent": "cyan"},
		{"kind": "quest_complete", "title": "任务完成 · 浅礁立足", "detail": "奖励已发放：+120G", "accent": "gold"},
	])
	_expect(hud.quest_banner_panel.visible, "First quest banner must become visible on play screen")
	_expect(hud._quest_banner_title.text == "目标达成 · 浅礁立足", "First banner title mismatch")
	hud._process(1.0)
	await process_frame
	_expect(hud.quest_banner_panel.visible and hud._quest_banner_title.text == "目标达成 · 浅礁立足", "First banner should remain visible mid-duration")
	var banner_rect := hud.quest_banner_panel.get_global_rect()
	_expect(Rect2(Vector2.ZERO, Vector2(1280, 720)).encloses(banner_rect.grow(-1.0)), "Quest banner must stay inside viewport")

	hud._process(2.5)
	await process_frame
	_expect(hud.quest_banner_panel.visible, "Second queued banner must show after first expires")
	_expect(hud._quest_banner_title.text == "任务完成 · 浅礁立足", "Banner queue must advance to second banner")

	hud._process(3.5)
	await process_frame
	_expect(not hud.quest_banner_panel.visible, "Quest banner must hide after queue drains")

	viewport.queue_free()
	await process_frame
	print("  [OK] 7a. HUD QuestPanel responsive layout (1280x720 & 420x840), WorldMap markers & banner queue")

func _test_game_quests_e2e_and_return_stack() -> void:
	var game := Game.new()
	game.gameplay_guide.persist_enabled = false
	game.voyage_save_path = TEMP_E2E_SAVE
	root.add_child(game)
	game.gameplay_guide.persist_enabled = false
	game.set_process(false)
	game.set_physics_process(false)
	game.ocean.process_mode = Node.PROCESS_MODE_DISABLED
	game.diver.set_physics_process(false)
	game.diver.set_process(false)
	await process_frame

	game._start("survival")
	await process_frame
	_expect(game.screen == "play" and not paused, "Game must start in play screen unpaused")

	game._handle_action_event(_make_action_event("quest_log"))
	_expect(game.screen == "quests" and paused and game.quests_return_screen == "play", "quest_log from play must open quests and remember play")
	game._handle_action_event(_make_action_event("quest_log"))
	_expect(game.screen == "play" and not paused, "Pressing quest_log again must return to play")

	game._open_quests_screen()
	_expect(game.screen == "quests" and paused, "_open_quests_screen must open quests")
	game._handle_action_event(_make_action_event("pause_game"))
	_expect(game.screen == "play" and not paused, "Esc from quests must return to play")

	game._set_screen("pause")
	game.hud.open_quests_requested.emit()
	_expect(game.screen == "quests" and game.quests_return_screen == "pause", "Opening quests from pause must remember pause")
	game._on_hud_action_requested("controls")
	_expect(game.screen == "controls" and game.controls_return_screen == "quests", "Opening controls from quests must remember quests")
	game._handle_action_event(_make_action_event("pause_game"))
	_expect(game.screen == "quests", "Esc from controls must return to quests")
	game._handle_action_event(_make_action_event("pause_game"))
	_expect(game.screen == "pause", "Esc from quests must return to pause")
	game._handle_action_event(_make_action_event("pause_game"))
	_expect(game.screen == "play" and not paused, "Esc from pause must return to play")

	game._set_screen("pause")
	game._open_quests_screen()
	game._on_hud_action_requested("gameplay_guide")
	_expect(game.screen == "guide" and game.guide_return_screen == "pause", "Switching quests -> guide must inherit pause return screen")
	game._handle_action_event(_make_action_event("pause_game"))
	_expect(game.screen == "pause", "Esc from guide must return to pause without loop")
	game._set_screen("play")

	game._open_quests_screen()
	await process_frame

	var tab_btns: Dictionary = game.hud.quest_view["tab_buttons"]
	(tab_btns["side"] as Button).pressed.emit()
	await process_frame
	var selected_outpost := false
	for entry in game.hud.quest_view.get("list_card_entries", []):
		if str(entry.get("id", "")) == "sq_explore_outposts":
			(entry["button"] as Button).pressed.emit()
			selected_outpost = true
			break
	_expect(selected_outpost, "QuestPanel side tab must contain sq_explore_outposts card")
	await process_frame
	var track_btn: Button = game.hud.quest_view["track_btn"]
	_expect(not track_btn.disabled, "Untracked active side quest must allow clicking track button")
	track_btn.pressed.emit()
	await process_frame
	_expect(game.quest_manager.tracked_quest_id == "sq_explore_outposts", "Clicking track button must switch tracked_quest_id to sq_explore_outposts")
	_expect(track_btn.disabled and track_btn.text == "当前追踪中", "Track button must reflect active tracking state")

	var toggle_btn: Button = game.hud.quest_view["toggle_tracker_btn"]
	_expect(not game.quest_manager.tracker_hidden, "HUD tracker starts visible")
	toggle_btn.pressed.emit()
	await process_frame
	_expect(game.quest_manager.tracker_hidden, "Clicking toggle button must hide HUD tracker")
	_expect(toggle_btn.text == "显示 HUD 追踪", "Toggle button label must switch to show when hidden")
	_expect(not bool(game.quest_manager.get_hud_tracker_payload(Vector3.ZERO, game._build_quest_snapshot())["visible"]), "Hidden tracker payload must report visible=false")

	toggle_btn.pressed.emit()
	await process_frame
	_expect(not game.quest_manager.tracker_hidden, "Second click must restore HUD tracker visibility")
	_expect(toggle_btn.text == "隐藏 HUD 追踪", "Toggle button label must switch back to hide")
	_expect(bool(game.quest_manager.get_hud_tracker_payload(Vector3.ZERO, game._build_quest_snapshot())["visible"]), "Restored tracker payload must report visible=true")

	_expect(not game.state.has_custom_waypoint, "Custom waypoint should start unset")
	var nav_btn: Button = game.hud.quest_view["nav_btn"]
	_expect(not nav_btn.disabled, "sq_explore_outposts must have primary navigation target enabled")
	nav_btn.pressed.emit()
	await process_frame
	_expect(game.state.has_custom_waypoint, "Clicking navigate button must set state.has_custom_waypoint = true")
	_expect(game.state.custom_waypoint.length_squared() > 1.0, "Custom waypoint position must be non-zero")
	_expect(game.screen == "map", "Primary navigate button must open sea chart ('map')")

	game._process(0.016)
	await process_frame
	_expect(not game.hud.sea_chart.quest_markers.is_empty(), "SeaChart must receive quest_markers from Game._process")
	_expect(str(game.hud.sea_chart.quest_markers[0].get("quest_id", "")) == "sq_explore_outposts", "SeaChart quest_markers must match tracked quest")
	_expect(not game.hud.minimap_radar.quest_markers.is_empty(), "MinimapRadar must receive quest_markers from Game._process")

	game.state.clear_custom_waypoint()
	game.hud.quest_nav_requested.emit(Vector3(45.0, -55.7, -55.0), "失事科考潜艇", false)
	await process_frame
	_expect(game.state.has_custom_waypoint and game.state.custom_waypoint.is_equal_approx(Vector3(45.0, -55.7, -55.0)), "Objective pin must set exact custom waypoint")
	_expect(game.screen == "play" and not paused, "Objective pin with open_map=false must return to play")

	game._process(0.016)
	await process_frame
	_expect(game.hud.mission_title.text.contains("全域前哨站联调"), "HUD mission card must display currently tracked quest title")

	paused = false
	game.free()
	await process_frame
	_cleanup_temp_files()
	print("  [OK] 7b. Game return stack, tracking toggle, HUD hide/show, waypoint nav & SeaChart marker sync")
