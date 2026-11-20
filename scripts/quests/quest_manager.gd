extends RefCounted

const QuestCatalog := preload("res://scripts/quests/quest_catalog.gd")
const Survival := preload("res://scripts/survival.gd")

const MAX_ACTIVE_BOUNTIES := 3

var mode: String = "survival"
var version: int = 1
var tracked_quest_id: String = ""
var tracked_objective_id: String = ""
var tracker_hidden: bool = false
var quest_states: Dictionary = {}
var active_bounties: Array[Dictionary] = []
var completed_bounty_count: int = 0
var bounties_unlocked: bool = false

var _catalog_cache: Array[Dictionary] = []
var _catalog_by_id: Dictionary = {}
var _bounty_templates_cache: Array[Dictionary] = []
var _bounty_templates_by_id: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _bounty_serial: int = 0

func _init() -> void:
	_rng.randomize()
	_ensure_catalog_loaded()
	reset("survival")

func _ensure_catalog_loaded() -> void:
	if _catalog_cache.is_empty():
		_catalog_cache = QuestCatalog.get_all_quests()
		_catalog_by_id.clear()
		for quest_def in _catalog_cache:
			var quest_id := str(quest_def.get("id", ""))
			if not quest_id.is_empty():
				_catalog_by_id[quest_id] = quest_def
	if _bounty_templates_cache.is_empty():
		_bounty_templates_cache = QuestCatalog.get_bounty_templates()
		_bounty_templates_by_id.clear()
		for tpl in _bounty_templates_cache:
			var tpl_id := str(tpl.get("id", ""))
			if not tpl_id.is_empty():
				_bounty_templates_by_id[tpl_id] = tpl

func reset(chosen_mode: String = "survival") -> void:
	_ensure_catalog_loaded()
	mode = "explore" if chosen_mode == "explore" else "survival"
	tracked_quest_id = ""
	tracked_objective_id = ""
	tracker_hidden = false
	quest_states.clear()
	active_bounties.clear()
	completed_bounty_count = 0
	bounties_unlocked = false
	_bounty_serial = 0

	for quest_def in _catalog_cache:
		var quest_id := str(quest_def.get("id", ""))
		var unlock_requires: Array = quest_def.get("unlock_requires", [])
		var obj_states: Dictionary = {}
		var obj_defs: Array = quest_def.get("objectives", [])
		for obj_def in obj_defs:
			var obj_id := str(obj_def.get("id", ""))
			var required := maxi(1, int(obj_def.get("required", 1)))
			var auto_done := (mode == "explore") and bool(obj_def.get("explore_auto_done", false))
			obj_states[obj_id] = {
				"current": required if auto_done else 0,
				"done": auto_done,
				"hold_sec": 0.0
			}
		quest_states[quest_id] = {
			"status": "active" if unlock_requires.is_empty() else "locked",
			"rewarded": false,
			"objectives": obj_states
		}

	_ensure_valid_tracked_quest()
	version += 1

func set_mode(chosen_mode: String) -> void:
	var next_mode := "explore" if chosen_mode == "explore" else "survival"
	if mode == next_mode:
		return
	mode = next_mode
	if mode == "explore":
		for quest_def in _catalog_cache:
			var quest_id := str(quest_def.get("id", ""))
			if not quest_states.has(quest_id):
				continue
			var state: Dictionary = quest_states[quest_id]
			var obj_states: Dictionary = state.get("objectives", {})
			for obj_def in quest_def.get("objectives", []):
				if bool(obj_def.get("explore_auto_done", false)):
					var obj_id := str(obj_def.get("id", ""))
					var required := maxi(1, int(obj_def.get("required", 1)))
					if obj_states.has(obj_id):
						var obj_state: Dictionary = obj_states[obj_id]
						obj_state["current"] = required
						obj_state["done"] = true
	_ensure_valid_tracked_quest()
	version += 1

func reconcile(snapshot: Dictionary, silent: bool = false) -> Dictionary:
	_ensure_catalog_loaded()
	var result := _make_empty_result()
	if snapshot.has("mode") and not str(snapshot.get("mode", "")).is_empty():
		var snap_mode := "explore" if str(snapshot.get("mode", "")) == "explore" else "survival"
		if mode != snap_mode:
			mode = snap_mode
			result["changed"] = true

	var newly_unlocked_ids: Array[String] = []
	var newly_completed_ids: Array[String] = []
	var pending_obj_banners: Array[Dictionary] = []

	# First sync all deterministic snapshot-backed objective progress (including locked quests for anti-softlock).
	for quest_def in _catalog_cache:
		var quest_id := str(quest_def.get("id", ""))
		if not quest_states.has(quest_id):
			continue
		var state: Dictionary = quest_states[quest_id]
		var status := str(state.get("status", "locked"))
		if status == "completed":
			continue
		var obj_states: Dictionary = state.get("objectives", {})
		for obj_def in quest_def.get("objectives", []):
			var obj_id := str(obj_def.get("id", ""))
			if not obj_states.has(obj_id):
				obj_states[obj_id] = {"current": 0, "done": false, "hold_sec": 0.0}
			var obj_state: Dictionary = obj_states[obj_id]
			var prev_current := int(obj_state.get("current", 0))
			var prev_done := bool(obj_state.get("done", false))
			var eval_val := _evaluate_objective_from_snapshot(obj_def, obj_state, snapshot)
			var required := maxi(1, int(obj_def.get("required", 1)))
			var next_current := mini(required, maxi(prev_current, eval_val))
			var next_done := prev_done or (next_current >= required)
			if next_current != prev_current or next_done != prev_done:
				obj_state["current"] = next_current
				obj_state["done"] = next_done
				result["changed"] = true
				if status == "active" and next_done and not prev_done:
					var comp_obj := {
						"quest_id": quest_id,
						"quest_title": str(quest_def.get("title", "")),
						"objective_id": obj_id,
						"label": str(obj_def.get("label", ""))
					}
					(result["completed_objectives"] as Array[Dictionary]).append(comp_obj)
					if not silent:
						pending_obj_banners.append({
							"quest_id": quest_id,
							"banner": {
								"kind": "objective",
								"title": "目标达成 · %s" % str(quest_def.get("title", "")),
								"detail": str(obj_def.get("label", "")),
								"accent": "cyan"
							}
						})

	# Convergence loop: complete active quests and unlock downstream quests in a single pass.
	var progress_made := true
	var guard_iters := 0
	while progress_made and guard_iters < 32:
		progress_made = false
		guard_iters += 1

		for quest_def in _catalog_cache:
			var quest_id := str(quest_def.get("id", ""))
			if not quest_states.has(quest_id):
				continue
			var state: Dictionary = quest_states[quest_id]
			if str(state.get("status", "locked")) != "active":
				continue
			if _are_all_objectives_done(quest_def, state):
				_complete_catalog_quest(quest_def, state, silent, result)
				newly_completed_ids.append(quest_id)
				progress_made = true

		for quest_def in _catalog_cache:
			var quest_id := str(quest_def.get("id", ""))
			if not quest_states.has(quest_id):
				continue
			var state: Dictionary = quest_states[quest_id]
			if str(state.get("status", "locked")) != "locked":
				continue
			if _are_unlock_requirements_met(quest_def):
				state["status"] = "active"
				result["changed"] = true
				newly_unlocked_ids.append(quest_id)
				(result["unlocked_quests"] as Array[Dictionary]).append({
					"id": quest_id,
					"title": str(quest_def.get("title", "")),
					"category": str(quest_def.get("category", "main"))
				})
				progress_made = true

	# Unlock dynamic bounties once >= 1 outpost is activated.
	var outposts_count := int(snapshot.get("outposts_count", 0))
	if not bounties_unlocked and outposts_count >= 1:
		bounties_unlocked = true
		_fill_bounties()
		result["changed"] = true
		if not silent:
			(result["banners"] as Array[Dictionary]).append({
				"kind": "unlock",
				"title": "远洋回波委托已开启",
				"detail": "前哨站声呐中继已上线，可在任务日志查看 3 条动态科考委托",
				"accent": "cyan"
			})
	elif bounties_unlocked and active_bounties.size() < MAX_ACTIVE_BOUNTIES:
		_fill_bounties()
		result["changed"] = true

	# Emit intermediate objective banners only for quests that did not complete in this same call.
	if not silent:
		for entry in pending_obj_banners:
			var qid := str(entry.get("quest_id", ""))
			if not newly_completed_ids.has(qid):
				(result["banners"] as Array[Dictionary]).append(entry["banner"])
		for unlock_qid in newly_unlocked_ids:
			if not newly_completed_ids.has(unlock_qid) and _catalog_by_id.has(unlock_qid):
				var u_def: Dictionary = _catalog_by_id[unlock_qid]
				var u_cat := str(u_def.get("category", "main"))
				var u_act := int(u_def.get("act", 0))
				(result["banners"] as Array[Dictionary]).append({
					"kind": "unlock",
					"title": "新任务解锁 · %s" % QuestCatalog.get_act_label(u_cat, u_act),
					"detail": str(u_def.get("title", "")),
					"accent": "cyan"
				})

	var prev_tracked_q := tracked_quest_id
	var prev_tracked_o := tracked_objective_id
	_ensure_valid_tracked_quest()
	if prev_tracked_q != tracked_quest_id or prev_tracked_o != tracked_objective_id:
		result["changed"] = true

	if bool(result.get("changed", false)):
		version += 1
	return result

func notify_event(event_id: String, context: Dictionary = {}, snapshot: Dictionary = {}) -> Dictionary:
	_ensure_catalog_loaded()
	var result := _make_empty_result()
	var amount := maxi(1, int(context.get("amount", 1)))
	var newly_completed_ids: Array[String] = []
	var pending_obj_banners: Array[Dictionary] = []

	# Advance event_count objectives on active catalog quests.
	for quest_def in _catalog_cache:
		var quest_id := str(quest_def.get("id", ""))
		if not quest_states.has(quest_id):
			continue
		var state: Dictionary = quest_states[quest_id]
		if str(state.get("status", "locked")) != "active":
			continue
		var obj_states: Dictionary = state.get("objectives", {})
		var quest_touched := false
		for obj_def in quest_def.get("objectives", []):
			if str(obj_def.get("type", "")) != "event_count":
				continue
			if str(obj_def.get("target", "")) != event_id:
				continue
			var obj_id := str(obj_def.get("id", ""))
			if not obj_states.has(obj_id):
				obj_states[obj_id] = {"current": 0, "done": false, "hold_sec": 0.0}
			var obj_state: Dictionary = obj_states[obj_id]
			if bool(obj_state.get("done", false)):
				continue
			var required := maxi(1, int(obj_def.get("required", 1)))
			var next_current := mini(required, int(obj_state.get("current", 0)) + amount)
			var next_done := next_current >= required
			obj_state["current"] = next_current
			obj_state["done"] = next_done
			result["changed"] = true
			quest_touched = true
			if next_done:
				(result["completed_objectives"] as Array[Dictionary]).append({
					"quest_id": quest_id,
					"quest_title": str(quest_def.get("title", "")),
					"objective_id": obj_id,
					"label": str(obj_def.get("label", ""))
				})
				pending_obj_banners.append({
					"quest_id": quest_id,
					"banner": {
						"kind": "objective",
						"title": "目标达成 · %s" % str(quest_def.get("title", "")),
						"detail": str(obj_def.get("label", "")),
						"accent": "cyan"
					}
				})
		if quest_touched and _are_all_objectives_done(quest_def, state):
			_complete_catalog_quest(quest_def, state, false, result)
			newly_completed_ids.append(quest_id)

	# Advance event_count objectives on active bounties.
	var remaining_bounties: Array[Dictionary] = []
	var completed_any_bounty := false
	for bounty in active_bounties:
		var bounty_completed := false
		var b_objs: Array = bounty.get("objectives", [])
		for obj in b_objs:
			if str(obj.get("type", "")) != "event_count":
				continue
			if str(obj.get("target", "")) != event_id:
				continue
			if bool(obj.get("done", false)):
				continue
			var required := maxi(1, int(obj.get("required", 1)))
			var next_current := mini(required, int(obj.get("current", 0)) + amount)
			obj["current"] = next_current
			result["changed"] = true
			if next_current >= required:
				obj["done"] = true
				(result["completed_objectives"] as Array[Dictionary]).append({
					"quest_id": str(bounty.get("id", "")),
					"quest_title": str(bounty.get("title", "")),
					"objective_id": str(obj.get("id", "")),
					"label": str(obj.get("label", ""))
				})
		if _are_bounty_objectives_done(bounty):
			_complete_bounty(bounty, result)
			bounty_completed = true
			completed_any_bounty = true
		if not bounty_completed:
			remaining_bounties.append(bounty)

	if completed_any_bounty:
		active_bounties = remaining_bounties
		if bounties_unlocked:
			_fill_bounties()

	for entry in pending_obj_banners:
		var qid := str(entry.get("quest_id", ""))
		if not newly_completed_ids.has(qid):
			(result["banners"] as Array[Dictionary]).append(entry["banner"])

	if not snapshot.is_empty():
		var event_changed := bool(result.get("changed", false))
		var rec := reconcile(snapshot, false)
		_merge_results(result, rec)
		if event_changed and not bool(rec.get("changed", false)):
			version += 1
	else:
		# Unlock downstream quests even when called without snapshot.
		if not newly_completed_ids.is_empty():
			var unlocked_now := _unlock_ready_quests(result)
			for u_id in unlocked_now:
				if _catalog_by_id.has(u_id):
					var u_def: Dictionary = _catalog_by_id[u_id]
					var u_cat := str(u_def.get("category", "main"))
					var u_act := int(u_def.get("act", 0))
					(result["banners"] as Array[Dictionary]).append({
						"kind": "unlock",
						"title": "新任务解锁 · %s" % QuestCatalog.get_act_label(u_cat, u_act),
						"detail": str(u_def.get("title", "")),
						"accent": "cyan"
					})
		var prev_tracked_q := tracked_quest_id
		var prev_tracked_o := tracked_objective_id
		_ensure_valid_tracked_quest()
		if prev_tracked_q != tracked_quest_id or prev_tracked_o != tracked_objective_id:
			result["changed"] = true
		if bool(result.get("changed", false)):
			version += 1

	return result

func tick_depth(delta: float, depth: float) -> Dictionary:
	var result := _make_empty_result()
	if delta <= 0.0 or not bounties_unlocked or active_bounties.is_empty():
		return result

	var remaining_bounties: Array[Dictionary] = []
	var completed_any := false
	for bounty in active_bounties:
		var b_objs: Array = bounty.get("objectives", [])
		for obj in b_objs:
			if str(obj.get("type", "")) != "depth_hold":
				continue
			if bool(obj.get("done", false)):
				continue
			var target_depth := float(obj.get("target_depth", 100.0))
			var required_sec := maxf(1.0, float(obj.get("required", 4)))
			if depth >= target_depth:
				var prev_sec := float(obj.get("hold_sec", 0.0))
				var next_sec := minf(required_sec, prev_sec + delta)
				obj["hold_sec"] = next_sec
				var prev_int := int(obj.get("current", 0))
				var next_int := mini(int(required_sec), int(floorf(next_sec)))
				if next_int != prev_int:
					obj["current"] = next_int
					result["changed"] = true
				if next_sec >= required_sec - 0.0001:
					obj["current"] = int(required_sec)
					obj["done"] = true
					result["changed"] = true
					(result["completed_objectives"] as Array[Dictionary]).append({
						"quest_id": str(bounty.get("id", "")),
						"quest_title": str(bounty.get("title", "")),
						"objective_id": str(obj.get("id", "")),
						"label": str(obj.get("label", ""))
					})
		if _are_bounty_objectives_done(bounty):
			_complete_bounty(bounty, result)
			completed_any = true
		else:
			remaining_bounties.append(bounty)

	if completed_any:
		active_bounties = remaining_bounties
		_fill_bounties()
		_ensure_valid_tracked_quest()

	if bool(result.get("changed", false)):
		version += 1
	return result

func set_tracked_quest(quest_id: String, objective_id: String = "") -> bool:
	_ensure_catalog_loaded()
	if quest_id.is_empty():
		return false
	if _catalog_by_id.has(quest_id) and quest_states.has(quest_id):
		var state: Dictionary = quest_states[quest_id]
		if str(state.get("status", "locked")) != "active":
			return false
		tracked_quest_id = quest_id
		tracked_objective_id = _pick_objective_for_catalog_quest(_catalog_by_id[quest_id], state, objective_id)
		tracker_hidden = false
		version += 1
		return true

	for bounty in active_bounties:
		if str(bounty.get("id", "")) == quest_id:
			tracked_quest_id = quest_id
			tracked_objective_id = _pick_objective_for_bounty(bounty, objective_id)
			tracker_hidden = false
			version += 1
			return true

	return false

func toggle_tracker_hidden() -> bool:
	tracker_hidden = not tracker_hidden
	version += 1
	return tracker_hidden

func set_tracker_hidden(hidden: bool) -> void:
	if tracker_hidden == hidden:
		return
	tracker_hidden = hidden
	version += 1

func refresh_bounties() -> bool:
	_ensure_catalog_loaded()
	if not bounties_unlocked:
		return false
	var previous_tpl_ids: Array[String] = []
	for bounty in active_bounties:
		previous_tpl_ids.append(str(bounty.get("template_id", "")))
	active_bounties.clear()
	_fill_bounties(previous_tpl_ids)
	_ensure_valid_tracked_quest()
	version += 1
	return true

func get_hud_tracker_payload(player_pos: Vector3, snapshot: Dictionary = {}) -> Dictionary:
	_ensure_catalog_loaded()
	_ensure_valid_tracked_quest()
	var empty_objectives: Array[Dictionary] = []
	if tracker_hidden or tracked_quest_id.is_empty():
		return {
			"visible": false,
			"quest_id": "",
			"category": "",
			"category_label": "",
			"act_label": "",
			"title": "",
			"progress_ratio": 0.0,
			"progress_text": "0/0",
			"objectives": empty_objectives,
			"nav_available": false,
			"nav_pos": Vector3.ZERO,
			"nav_label": "",
			"nav_distance_m": -1,
			"recipe_hint": ""
		}

	var quest_entry := _build_quest_view(tracked_quest_id, player_pos, snapshot)
	if quest_entry.is_empty() or str(quest_entry.get("status", "")) != "active":
		return {
			"visible": false,
			"quest_id": "",
			"category": "",
			"category_label": "",
			"act_label": "",
			"title": "",
			"progress_ratio": 0.0,
			"progress_text": "0/0",
			"objectives": empty_objectives,
			"nav_available": false,
			"nav_pos": Vector3.ZERO,
			"nav_label": "",
			"nav_distance_m": -1,
			"recipe_hint": ""
		}

	var all_objs: Array[Dictionary] = quest_entry.get("objectives", [])
	var focused_obj: Dictionary = {}
	var incomplete_objs: Array[Dictionary] = []
	var complete_objs: Array[Dictionary] = []
	for obj in all_objs:
		var obj_id := str(obj.get("id", ""))
		var obj_done := bool(obj.get("done", false))
		if obj_id == tracked_objective_id and not obj_done:
			focused_obj = obj
		elif not obj_done:
			incomplete_objs.append(obj)
		else:
			complete_objs.append(obj)

	var selected_objs: Array[Dictionary] = []
	if not focused_obj.is_empty():
		selected_objs.append(_compact_hud_objective(focused_obj))
	for inc_obj in incomplete_objs:
		if selected_objs.size() >= 3:
			break
		selected_objs.append(_compact_hud_objective(inc_obj))
	for done_obj in complete_objs:
		if selected_objs.size() >= 3:
			break
		selected_objs.append(_compact_hud_objective(done_obj))

	var nav_available := false
	var nav_pos := Vector3.ZERO
	var nav_label := ""
	var nav_distance_m := -1
	var recipe_hint := ""

	var ordered_candidates: Array[Dictionary] = []
	if not focused_obj.is_empty():
		ordered_candidates.append(focused_obj)
	for inc_obj in incomplete_objs:
		ordered_candidates.append(inc_obj)

	for cand in ordered_candidates:
		if not nav_available and bool(cand.get("nav_available", false)):
			nav_available = true
			nav_pos = cand.get("nav_pos", Vector3.ZERO)
			nav_label = str(cand.get("nav_label", ""))
			nav_distance_m = int(cand.get("distance_m", -1))
		if recipe_hint.is_empty() and not str(cand.get("recipe_hint", "")).is_empty():
			recipe_hint = str(cand.get("recipe_hint", ""))

	return {
		"visible": true,
		"quest_id": str(quest_entry.get("id", "")),
		"category": str(quest_entry.get("category", "")),
		"category_label": str(quest_entry.get("category_label", "")),
		"act_label": str(quest_entry.get("act_label", "")),
		"title": str(quest_entry.get("title", "")),
		"progress_ratio": float(quest_entry.get("progress_ratio", 0.0)),
		"progress_text": str(quest_entry.get("progress_text", "0/0")),
		"objectives": selected_objs,
		"nav_available": nav_available,
		"nav_pos": nav_pos,
		"nav_label": nav_label,
		"nav_distance_m": nav_distance_m,
		"recipe_hint": recipe_hint
	}

func get_journal_payload(player_pos: Vector3, snapshot: Dictionary = {}) -> Dictionary:
	_ensure_catalog_loaded()
	_ensure_valid_tracked_quest()

	var quests_out: Array[Dictionary] = []
	var main_count := 0
	var side_count := 0
	var bounty_count := 0
	var completed_count := 0

	for quest_def in _catalog_cache:
		var quest_id := str(quest_def.get("id", ""))
		if not quest_states.has(quest_id):
			continue
		var state: Dictionary = quest_states[quest_id]
		var status := str(state.get("status", "locked"))
		if status != "active" and status != "completed":
			continue
		var view := _build_catalog_quest_view(quest_def, state, player_pos, snapshot)
		quests_out.append(view)
		if status == "completed":
			completed_count += 1
		else:
			var cat := str(quest_def.get("category", "main"))
			if cat == "main":
				main_count += 1
			elif cat == "side":
				side_count += 1

	for bounty in active_bounties:
		var b_view := _build_bounty_view(bounty, player_pos, snapshot)
		quests_out.append(b_view)
		bounty_count += 1

	var exploration_pct := 0
	if snapshot.has("exploration_pct"):
		exploration_pct = clampi(int(snapshot.get("exploration_pct", 0)), 0, 100)
	else:
		var lm_part := clampf(float(int(snapshot.get("landmarks_count", 0))) / 24.0, 0.0, 1.0) * 0.45
		var op_part := clampf(float(int(snapshot.get("outposts_count", 0))) / 6.0, 0.0, 1.0) * 0.30
		var rl_part := clampf(float(int(snapshot.get("relics_count", 0))) / 12.0, 0.0, 1.0) * 0.25
		exploration_pct = int(roundf((lm_part + op_part + rl_part) * 100.0))

	var explorer_rank := ""
	if snapshot.has("explorer_rank") and not str(snapshot.get("explorer_rank", "")).is_empty():
		explorer_rank = str(snapshot.get("explorer_rank", ""))
	else:
		var rank_level := clampi(int(snapshot.get("explorer_rank_level", 1)), 1, Survival.EXPLORER_RANKS.size())
		explorer_rank = str(Survival.EXPLORER_RANKS[rank_level - 1])

	return {
		"version": version,
		"mode": mode,
		"tracked_quest_id": tracked_quest_id,
		"tracked_objective_id": tracked_objective_id,
		"tracker_hidden": tracker_hidden,
		"bounties_unlocked": bounties_unlocked,
		"completed_bounty_count": completed_bounty_count,
		"exploration_pct": exploration_pct,
		"explorer_rank": explorer_rank,
		"counts": {
			"main": main_count,
			"side": side_count,
			"bounty": bounty_count,
			"completed": completed_count
		},
		"quests": quests_out
	}

func get_map_markers(snapshot: Dictionary = {}) -> Array[Dictionary]:
	_ensure_catalog_loaded()
	_ensure_valid_tracked_quest()
	var markers: Array[Dictionary] = []
	if tracked_quest_id.is_empty():
		return markers

	var quest_entry := _build_quest_view(tracked_quest_id, Vector3.ZERO, snapshot)
	if quest_entry.is_empty() or str(quest_entry.get("status", "")) != "active":
		return markers

	var title := str(quest_entry.get("title", ""))
	var category := str(quest_entry.get("category", "main"))
	var objs: Array[Dictionary] = quest_entry.get("objectives", [])
	var has_focused := false
	for obj in objs:
		if bool(obj.get("done", false)):
			continue
		if not bool(obj.get("nav_available", false)):
			continue
		var obj_id := str(obj.get("id", ""))
		var is_focused := (obj_id == tracked_objective_id)
		if is_focused:
			has_focused = true
		markers.append({
			"quest_id": tracked_quest_id,
			"objective_id": obj_id,
			"title": title,
			"label": str(obj.get("nav_label", obj.get("label", ""))),
			"category": category,
			"pos": obj.get("nav_pos", Vector3.ZERO),
			"focused": is_focused
		})
	if not has_focused and not markers.is_empty():
		markers[0]["focused"] = true
	return markers

func to_save_dict() -> Dictionary:
	var saved_states: Dictionary = {}
	for quest_id in quest_states:
		var state: Dictionary = quest_states[quest_id]
		var saved_objs: Dictionary = {}
		var obj_states: Dictionary = state.get("objectives", {})
		for obj_id in obj_states:
			var obj_state: Dictionary = obj_states[obj_id]
			saved_objs[obj_id] = {
				"current": int(obj_state.get("current", 0)),
				"done": bool(obj_state.get("done", false)),
				"hold_sec": float(obj_state.get("hold_sec", 0.0))
			}
		saved_states[quest_id] = {
			"status": str(state.get("status", "locked")),
			"rewarded": bool(state.get("rewarded", false)),
			"objectives": saved_objs
		}

	var saved_bounties: Array[Dictionary] = []
	for bounty in active_bounties:
		var b_objs: Array[Dictionary] = []
		for obj in bounty.get("objectives", []):
			b_objs.append({
				"id": str(obj.get("id", "")),
				"current": int(obj.get("current", 0)),
				"done": bool(obj.get("done", false)),
				"hold_sec": float(obj.get("hold_sec", 0.0))
			})
		saved_bounties.append({
			"id": str(bounty.get("id", "")),
			"template_id": str(bounty.get("template_id", "")),
			"objectives": b_objs
		})

	return {
		"schema": 1,
		"mode": mode,
		"tracked_quest_id": tracked_quest_id,
		"tracked_objective_id": tracked_objective_id,
		"tracker_hidden": tracker_hidden,
		"completed_bounty_count": completed_bounty_count,
		"bounties_unlocked": bounties_unlocked,
		"bounty_serial": _bounty_serial,
		"quest_states": saved_states,
		"active_bounties": saved_bounties
	}

func from_save_dict(data: Dictionary, snapshot: Dictionary = {}) -> void:
	_ensure_catalog_loaded()
	if data.is_empty():
		migrate_from_legacy(snapshot)
		return

	var chosen_mode := str(data.get("mode", snapshot.get("mode", "survival")))
	reset(chosen_mode)
	tracker_hidden = bool(data.get("tracker_hidden", false))
	completed_bounty_count = maxi(0, int(data.get("completed_bounty_count", 0)))
	bounties_unlocked = bool(data.get("bounties_unlocked", false))
	_bounty_serial = maxi(0, int(data.get("bounty_serial", 0)))

	var raw_states: Variant = data.get("quest_states", {})
	if raw_states is Dictionary:
		var saved_states: Dictionary = raw_states
		for quest_id in quest_states:
			if not saved_states.has(quest_id):
				continue
			var raw_q: Variant = saved_states[quest_id]
			if not (raw_q is Dictionary):
				continue
			var saved_q: Dictionary = raw_q
			var target_q: Dictionary = quest_states[quest_id]
			var saved_status := str(saved_q.get("status", target_q.get("status", "locked")))
			if saved_status in ["locked", "active", "completed"]:
				target_q["status"] = saved_status
			target_q["rewarded"] = bool(saved_q.get("rewarded", saved_status == "completed"))
			var raw_objs: Variant = saved_q.get("objectives", {})
			if raw_objs is Dictionary:
				var saved_objs: Dictionary = raw_objs
				var target_objs: Dictionary = target_q.get("objectives", {})
				for obj_id in target_objs:
					if not saved_objs.has(obj_id):
						continue
					var raw_obj: Variant = saved_objs[obj_id]
					if not (raw_obj is Dictionary):
						continue
					var saved_obj: Dictionary = raw_obj
					var target_obj: Dictionary = target_objs[obj_id]
					target_obj["current"] = maxi(0, int(saved_obj.get("current", 0)))
					target_obj["done"] = bool(saved_obj.get("done", false))
					target_obj["hold_sec"] = maxf(0.0, float(saved_obj.get("hold_sec", 0.0)))

	active_bounties.clear()
	var raw_bounties: Variant = data.get("active_bounties", [])
	if raw_bounties is Array:
		for raw_b in raw_bounties:
			if not (raw_b is Dictionary):
				continue
			var saved_b: Dictionary = raw_b
			var tpl_id := str(saved_b.get("template_id", ""))
			if not _bounty_templates_by_id.has(tpl_id):
				continue
			var restored := _instantiate_bounty(_bounty_templates_by_id[tpl_id], str(saved_b.get("id", "")))
			var saved_b_objs: Variant = saved_b.get("objectives", [])
			if saved_b_objs is Array:
				var obj_map: Dictionary = {}
				for saved_bo in saved_b_objs:
					if saved_bo is Dictionary:
						obj_map[str(saved_bo.get("id", ""))] = saved_bo
				for inst_obj in restored.get("objectives", []):
					var inst_id := str(inst_obj.get("id", ""))
					if obj_map.has(inst_id):
						var bo: Dictionary = obj_map[inst_id]
						inst_obj["current"] = maxi(0, int(bo.get("current", 0)))
						inst_obj["done"] = bool(bo.get("done", false))
						inst_obj["hold_sec"] = maxf(0.0, float(bo.get("hold_sec", 0.0)))
			active_bounties.append(restored)

	if bounties_unlocked and active_bounties.size() < MAX_ACTIVE_BOUNTIES:
		_fill_bounties()

	tracked_quest_id = str(data.get("tracked_quest_id", ""))
	tracked_objective_id = str(data.get("tracked_objective_id", ""))

	if not snapshot.is_empty():
		reconcile(snapshot, true)
	else:
		_ensure_valid_tracked_quest()
		version += 1

func migrate_from_legacy(snapshot: Dictionary) -> void:
	_ensure_catalog_loaded()
	var chosen_mode := str(snapshot.get("mode", "survival"))
	reset(chosen_mode)
	if int(snapshot.get("marinca_three_star_count", 0)) > 0 and quest_states.has("sq_sushi_perfect_catch"):
		var catch_state: Dictionary = quest_states["sq_sushi_perfect_catch"]
		var catch_objs: Dictionary = catch_state.get("objectives", {})
		if catch_objs.has("perfect_catch_once"):
			var obj_state: Dictionary = catch_objs["perfect_catch_once"]
			obj_state["current"] = 1
			obj_state["done"] = true
	reconcile(snapshot, true)
	_ensure_valid_tracked_quest()
	version += 1

func _make_empty_result() -> Dictionary:
	var completed_quests: Array[Dictionary] = []
	var completed_objectives: Array[Dictionary] = []
	var unlocked_quests: Array[Dictionary] = []
	var banners: Array[Dictionary] = []
	return {
		"changed": false,
		"completed_quests": completed_quests,
		"completed_objectives": completed_objectives,
		"unlocked_quests": unlocked_quests,
		"granted_gold": 0,
		"granted_items": {},
		"banners": banners
	}

func _merge_results(target: Dictionary, extra: Dictionary) -> void:
	if bool(extra.get("changed", false)):
		target["changed"] = true
	for item in extra.get("completed_quests", []):
		(target["completed_quests"] as Array[Dictionary]).append(item)
	for item in extra.get("completed_objectives", []):
		(target["completed_objectives"] as Array[Dictionary]).append(item)
	for item in extra.get("unlocked_quests", []):
		(target["unlocked_quests"] as Array[Dictionary]).append(item)
	for item in extra.get("banners", []):
		(target["banners"] as Array[Dictionary]).append(item)
	target["granted_gold"] = int(target.get("granted_gold", 0)) + int(extra.get("granted_gold", 0))
	var target_items: Dictionary = target.get("granted_items", {})
	var extra_items: Dictionary = extra.get("granted_items", {})
	for item_key in extra_items:
		target_items[item_key] = int(target_items.get(item_key, 0)) + int(extra_items[item_key])
	target["granted_items"] = target_items

func _evaluate_objective_from_snapshot(obj_def: Dictionary, obj_state: Dictionary, snapshot: Dictionary) -> int:
	var obj_type := str(obj_def.get("type", ""))
	var required := maxi(1, int(obj_def.get("required", 1)))
	if mode == "explore" and bool(obj_def.get("explore_auto_done", false)):
		return required

	match obj_type:
		"recipe_any_owned":
			var targets: Array = obj_def.get("targets", [])
			var owned_count := 0
			for target_id in targets:
				if _is_recipe_owned(str(target_id), snapshot):
					owned_count += 1
			return mini(owned_count, required)
		"recipe_all_owned":
			var targets: Array = obj_def.get("targets", [])
			var owned_count := 0
			for target_id in targets:
				if _is_recipe_owned(str(target_id), snapshot):
					owned_count += 1
			return mini(owned_count, required)
		"state_flag":
			var flag_key := str(obj_def.get("target", ""))
			return required if bool(snapshot.get(flag_key, false)) else 0
		"boss_conquer":
			var boss_id := str(obj_def.get("target", ""))
			return required if _is_boss_conquered(boss_id, snapshot) else 0
		"item_owned":
			var item_key := str(obj_def.get("target", ""))
			var count := 0
			var raw_inv: Variant = snapshot.get("inventory", {})
			if raw_inv is Dictionary:
				count = int((raw_inv as Dictionary).get(item_key, 0))
			if count < required and bool(snapshot.get("escape_crafted", false)):
				if item_key in ["mother_tree_essence", "ancient_star_core", "tree_seed"]:
					count = required
			return mini(count, required)
		"collection_count":
			var col_target := str(obj_def.get("target", ""))
			var col_val := _read_collection_count(col_target, snapshot)
			return mini(col_val, required)
		"rank_reach":
			var rank_lv := int(snapshot.get("explorer_rank_level", 1))
			return mini(rank_lv, required)
		"event_count", "depth_hold":
			return int(obj_state.get("current", 0))
		_:
			return int(obj_state.get("current", 0))

func _is_recipe_owned(recipe_id: String, snapshot: Dictionary) -> bool:
	match recipe_id:
		"tank":
			return bool(snapshot.get("tank", false))
		"fins":
			return bool(snapshot.get("fins", false))
		"rebreather":
			return bool(snapshot.get("rebreather", false))
		"beacon":
			return bool(snapshot.get("rescued", false))
		"abyssal_escape_engine":
			return bool(snapshot.get("escape_crafted", false))
		_:
			var raw_weapons: Variant = snapshot.get("weapons", [])
			if raw_weapons is Array and (raw_weapons as Array).has(recipe_id):
				return true
			return bool(snapshot.get(recipe_id, false))

func _is_boss_conquered(boss_id: String, snapshot: Dictionary) -> bool:
	var raw_bosses: Variant = snapshot.get("conquered_bosses", [])
	if raw_bosses is Dictionary:
		var boss_dict: Dictionary = raw_bosses
		if boss_dict.has(boss_id):
			var val: Variant = boss_dict[boss_id]
			if val is bool:
				return val
			return true
	elif raw_bosses is Array:
		if (raw_bosses as Array).has(boss_id):
			return true
	if bool(snapshot.get("escape_crafted", false)):
		return true
	return false

func _read_collection_count(col_target: String, snapshot: Dictionary) -> int:
	match col_target:
		"outposts":
			return int(snapshot.get("outposts_count", 0))
		"relics":
			return int(snapshot.get("relics_count", 0))
		"landmarks":
			return int(snapshot.get("landmarks_count", 0))
		"dishes_served":
			return int(snapshot.get("dishes_served", 0))
		"marinca_species":
			return int(snapshot.get("marinca_species_count", 0))
		"marinca_three_star":
			return int(snapshot.get("marinca_three_star_count", 0))
		"tamed_beasts":
			return int(snapshot.get("tamed_beasts_count", 0))
		_:
			return int(snapshot.get(col_target, 0))

func _are_all_objectives_done(quest_def: Dictionary, state: Dictionary) -> bool:
	var obj_states: Dictionary = state.get("objectives", {})
	var obj_defs: Array = quest_def.get("objectives", [])
	if obj_defs.is_empty():
		return false
	for obj_def in obj_defs:
		var obj_id := str(obj_def.get("id", ""))
		if not obj_states.has(obj_id):
			return false
		if not bool((obj_states[obj_id] as Dictionary).get("done", false)):
			return false
	return true

func _are_bounty_objectives_done(bounty: Dictionary) -> bool:
	var objs: Array = bounty.get("objectives", [])
	if objs.is_empty():
		return false
	for obj in objs:
		if not bool(obj.get("done", false)):
			return false
	return true

func _are_unlock_requirements_met(quest_def: Dictionary) -> bool:
	var requires: Array = quest_def.get("unlock_requires", [])
	for req_id in requires:
		var key := str(req_id)
		if not quest_states.has(key):
			return false
		if str((quest_states[key] as Dictionary).get("status", "locked")) != "completed":
			return false
	return true

func _unlock_ready_quests(result: Dictionary) -> Array[String]:
	var unlocked: Array[String] = []
	for quest_def in _catalog_cache:
		var quest_id := str(quest_def.get("id", ""))
		if not quest_states.has(quest_id):
			continue
		var state: Dictionary = quest_states[quest_id]
		if str(state.get("status", "locked")) != "locked":
			continue
		if _are_unlock_requirements_met(quest_def):
			state["status"] = "active"
			result["changed"] = true
			unlocked.append(quest_id)
			(result["unlocked_quests"] as Array[Dictionary]).append({
				"id": quest_id,
				"title": str(quest_def.get("title", "")),
				"category": str(quest_def.get("category", "main"))
			})
	return unlocked

func _complete_catalog_quest(quest_def: Dictionary, state: Dictionary, silent: bool, result: Dictionary) -> void:
	state["status"] = "completed"
	result["changed"] = true
	var already_rewarded := bool(state.get("rewarded", false))
	state["rewarded"] = true

	var rewards_def: Dictionary = quest_def.get("rewards", {})
	var reward_gold := int(rewards_def.get("gold", 0))
	var reward_items: Dictionary = rewards_def.get("items", {}).duplicate(true)
	var reward_summary := str(rewards_def.get("summary", ""))

	(result["completed_quests"] as Array[Dictionary]).append({
		"id": str(quest_def.get("id", "")),
		"title": str(quest_def.get("title", "")),
		"category": str(quest_def.get("category", "main")),
		"rewards": {
			"gold": reward_gold,
			"items": reward_items,
			"summary": reward_summary
		}
	})

	if not silent and not already_rewarded:
		result["granted_gold"] = int(result.get("granted_gold", 0)) + reward_gold
		var granted_items: Dictionary = result.get("granted_items", {})
		for item_key in reward_items:
			granted_items[item_key] = int(granted_items.get(item_key, 0)) + int(reward_items[item_key])
		result["granted_items"] = granted_items
		(result["banners"] as Array[Dictionary]).append({
			"kind": "quest",
			"title": "任务完成 · %s" % str(quest_def.get("title", "")),
			"detail": reward_summary if not reward_summary.is_empty() else "任务目标已全部达成",
			"accent": "gold"
		})

func _complete_bounty(bounty: Dictionary, result: Dictionary) -> void:
	completed_bounty_count += 1
	result["changed"] = true
	var rewards_def: Dictionary = bounty.get("rewards", {})
	var reward_gold := int(rewards_def.get("gold", 0))
	var reward_items: Dictionary = rewards_def.get("items", {}).duplicate(true)
	var reward_summary := str(rewards_def.get("summary", ""))

	(result["completed_quests"] as Array[Dictionary]).append({
		"id": str(bounty.get("id", "")),
		"title": str(bounty.get("title", "")),
		"category": "bounty",
		"rewards": {
			"gold": reward_gold,
			"items": reward_items,
			"summary": reward_summary
		}
	})

	result["granted_gold"] = int(result.get("granted_gold", 0)) + reward_gold
	var granted_items: Dictionary = result.get("granted_items", {})
	for item_key in reward_items:
		granted_items[item_key] = int(granted_items.get(item_key, 0)) + int(reward_items[item_key])
	result["granted_items"] = granted_items
	(result["banners"] as Array[Dictionary]).append({
		"kind": "quest",
		"title": "回波委托完成 · %s" % str(bounty.get("title", "")),
		"detail": reward_summary if not reward_summary.is_empty() else "委托奖励已发放",
		"accent": "gold"
	})

func _fill_bounties(avoid_template_ids: Array[String] = []) -> void:
	_ensure_catalog_loaded()
	var active_tpl_ids: Dictionary = {}
	for existing in active_bounties:
		active_tpl_ids[str(existing.get("template_id", ""))] = true

	while active_bounties.size() < MAX_ACTIVE_BOUNTIES:
		var preferred: Array[Dictionary] = []
		var fallback: Array[Dictionary] = []
		for tpl in _bounty_templates_cache:
			var tpl_id := str(tpl.get("id", ""))
			if active_tpl_ids.has(tpl_id):
				continue
			if avoid_template_ids.has(tpl_id):
				fallback.append(tpl)
			else:
				preferred.append(tpl)
		var pool: Array[Dictionary] = preferred if not preferred.is_empty() else fallback
		if pool.is_empty():
			break
		var pick_idx := _rng.randi_range(0, pool.size() - 1)
		var picked: Dictionary = pool[pick_idx]
		active_tpl_ids[str(picked.get("id", ""))] = true
		active_bounties.append(_instantiate_bounty(picked))

func _instantiate_bounty(tpl: Dictionary, explicit_id: String = "") -> Dictionary:
	var tpl_id := str(tpl.get("id", ""))
	var inst_id := explicit_id
	if inst_id.is_empty():
		_bounty_serial += 1
		inst_id = "bounty_%d_%s" % [_bounty_serial, tpl_id]

	var inst_objs: Array[Dictionary] = []
	for obj_def in tpl.get("objectives", []):
		var obj_copy: Dictionary = obj_def.duplicate(true)
		obj_copy["current"] = 0
		obj_copy["hold_sec"] = 0.0
		obj_copy["done"] = false
		inst_objs.append(obj_copy)

	return {
		"id": inst_id,
		"template_id": tpl_id,
		"category": "bounty",
		"title": str(tpl.get("title", "")),
		"brief": str(tpl.get("brief", "")),
		"rewards": (tpl.get("rewards", {}) as Dictionary).duplicate(true),
		"objectives": inst_objs
	}

func _ensure_valid_tracked_quest() -> void:
	if not tracked_quest_id.is_empty():
		if _catalog_by_id.has(tracked_quest_id) and quest_states.has(tracked_quest_id):
			var state: Dictionary = quest_states[tracked_quest_id]
			if str(state.get("status", "locked")) == "active":
				tracked_objective_id = _pick_objective_for_catalog_quest(_catalog_by_id[tracked_quest_id], state, tracked_objective_id)
				return
		for bounty in active_bounties:
			if str(bounty.get("id", "")) == tracked_quest_id:
				tracked_objective_id = _pick_objective_for_bounty(bounty, tracked_objective_id)
				return

	# Priority 1: active main quest (lowest act first).
	for quest_def in _catalog_cache:
		if str(quest_def.get("category", "")) != "main":
			continue
		var quest_id := str(quest_def.get("id", ""))
		if quest_states.has(quest_id) and str((quest_states[quest_id] as Dictionary).get("status", "")) == "active":
			tracked_quest_id = quest_id
			tracked_objective_id = _pick_objective_for_catalog_quest(quest_def, quest_states[quest_id], "")
			return

	# Priority 2: active side quest.
	for quest_def in _catalog_cache:
		if str(quest_def.get("category", "")) != "side":
			continue
		var quest_id := str(quest_def.get("id", ""))
		if quest_states.has(quest_id) and str((quest_states[quest_id] as Dictionary).get("status", "")) == "active":
			tracked_quest_id = quest_id
			tracked_objective_id = _pick_objective_for_catalog_quest(quest_def, quest_states[quest_id], "")
			return

	# Priority 3: active bounty.
	if not active_bounties.is_empty():
		var first_bounty: Dictionary = active_bounties[0]
		tracked_quest_id = str(first_bounty.get("id", ""))
		tracked_objective_id = _pick_objective_for_bounty(first_bounty, "")
		return

	tracked_quest_id = ""
	tracked_objective_id = ""

func _pick_objective_for_catalog_quest(quest_def: Dictionary, state: Dictionary, preferred_obj_id: String) -> String:
	var obj_states: Dictionary = state.get("objectives", {})
	var obj_defs: Array = quest_def.get("objectives", [])
	if not preferred_obj_id.is_empty() and obj_states.has(preferred_obj_id):
		if not bool((obj_states[preferred_obj_id] as Dictionary).get("done", false)):
			return preferred_obj_id
	for obj_def in obj_defs:
		var obj_id := str(obj_def.get("id", ""))
		if obj_states.has(obj_id) and not bool((obj_states[obj_id] as Dictionary).get("done", false)):
			return obj_id
	if not obj_defs.is_empty():
		return str((obj_defs[0] as Dictionary).get("id", ""))
	return ""

func _pick_objective_for_bounty(bounty: Dictionary, preferred_obj_id: String) -> String:
	var objs: Array = bounty.get("objectives", [])
	if not preferred_obj_id.is_empty():
		for obj in objs:
			if str(obj.get("id", "")) == preferred_obj_id and not bool(obj.get("done", false)):
				return preferred_obj_id
	for obj in objs:
		if not bool(obj.get("done", false)):
			return str(obj.get("id", ""))
	if not objs.is_empty():
		return str((objs[0] as Dictionary).get("id", ""))
	return ""

func _resolve_objective_nav(obj_def: Dictionary, snapshot: Dictionary) -> Dictionary:
	var nav_available := obj_def.has("nav_pos")
	var nav_pos: Vector3 = obj_def.get("nav_pos", Vector3.ZERO)
	var nav_label := str(obj_def.get("nav_label", ""))

	if str(obj_def.get("type", "")) == "collection_count" and str(obj_def.get("target", "")) == "outposts":
		if bool(snapshot.get("has_nearest_outpost", false)) and snapshot.has("nearest_outpost_pos"):
			var raw_pos: Variant = snapshot["nearest_outpost_pos"]
			if raw_pos is Vector3:
				nav_available = true
				nav_pos = raw_pos
				if snapshot.has("nearest_outpost_name") and not str(snapshot.get("nearest_outpost_name", "")).is_empty():
					nav_label = str(snapshot.get("nearest_outpost_name", ""))
				else:
					nav_label = QuestCatalog.resolve_outpost_name(nav_pos, nav_label if not nav_label.is_empty() else "最近未激活前哨站")

	return {
		"nav_available": nav_available,
		"nav_pos": nav_pos,
		"nav_label": nav_label
	}

func _build_quest_view(quest_id: String, player_pos: Vector3, snapshot: Dictionary) -> Dictionary:
	if _catalog_by_id.has(quest_id) and quest_states.has(quest_id):
		return _build_catalog_quest_view(_catalog_by_id[quest_id], quest_states[quest_id], player_pos, snapshot)
	for bounty in active_bounties:
		if str(bounty.get("id", "")) == quest_id:
			return _build_bounty_view(bounty, player_pos, snapshot)
	return {}

func _build_catalog_quest_view(quest_def: Dictionary, state: Dictionary, player_pos: Vector3, snapshot: Dictionary) -> Dictionary:
	var quest_id := str(quest_def.get("id", ""))
	var category := str(quest_def.get("category", "main"))
	var act := int(quest_def.get("act", 0))
	var status := str(state.get("status", "locked"))
	var obj_states: Dictionary = state.get("objectives", {})
	var obj_defs: Array = quest_def.get("objectives", [])
	var built_objs: Array[Dictionary] = []
	var done_count := 0
	var primary_nav_available := false
	var primary_nav_pos := Vector3.ZERO
	var primary_nav_label := ""
	var primary_recipe_hint := ""

	for obj_def in obj_defs:
		var obj_id := str(obj_def.get("id", ""))
		var obj_state: Dictionary = obj_states.get(obj_id, {"current": 0, "done": false})
		var required := maxi(1, int(obj_def.get("required", 1)))
		var done := bool(obj_state.get("done", false)) or status == "completed"
		var current := required if done else mini(required, int(obj_state.get("current", 0)))
		if done:
			done_count += 1
		var nav_info := _resolve_objective_nav(obj_def, snapshot)
		var nav_available := bool(nav_info["nav_available"])
		var nav_pos: Vector3 = nav_info["nav_pos"]
		var nav_label := str(nav_info["nav_label"])
		var distance_m := int(roundf(player_pos.distance_to(nav_pos))) if nav_available else -1
		var obj_recipe := str(obj_def.get("recipe_hint", ""))
		built_objs.append({
			"id": obj_id,
			"label": str(obj_def.get("label", "")),
			"done": done,
			"current": current,
			"required": required,
			"nav_available": nav_available,
			"nav_pos": nav_pos,
			"nav_label": nav_label,
			"distance_m": distance_m,
			"recipe_hint": obj_recipe
		})
		if not done:
			if not primary_nav_available and nav_available:
				primary_nav_available = true
				primary_nav_pos = nav_pos
				primary_nav_label = nav_label
			if primary_recipe_hint.is_empty() and not obj_recipe.is_empty():
				primary_recipe_hint = obj_recipe

	var progress_ratio := 0.0
	var progress_text := "0/0"
	if built_objs.size() == 1:
		var only_obj: Dictionary = built_objs[0]
		var only_cur := int(only_obj.get("current", 0))
		var only_req := maxi(1, int(only_obj.get("required", 1)))
		progress_ratio = clampf(float(only_cur) / float(only_req), 0.0, 1.0)
		progress_text = "%d/%d" % [only_cur, only_req]
	elif not built_objs.is_empty():
		progress_ratio = clampf(float(done_count) / float(built_objs.size()), 0.0, 1.0)
		progress_text = "%d/%d" % [done_count, built_objs.size()]

	var rewards_def: Dictionary = quest_def.get("rewards", {})
	return {
		"id": quest_id,
		"category": category,
		"category_label": QuestCatalog.get_category_label(category),
		"act": act,
		"act_label": QuestCatalog.get_act_label(category, act),
		"status": status,
		"tracked": tracked_quest_id == quest_id and status == "active",
		"title": str(quest_def.get("title", "")),
		"brief": str(quest_def.get("brief", "")),
		"progress_ratio": progress_ratio,
		"progress_text": progress_text,
		"rewards_summary": str(rewards_def.get("summary", "")),
		"recipe_hint": primary_recipe_hint,
		"primary_nav_available": primary_nav_available,
		"primary_nav_pos": primary_nav_pos,
		"primary_nav_label": primary_nav_label,
		"objectives": built_objs
	}

func _build_bounty_view(bounty: Dictionary, player_pos: Vector3, snapshot: Dictionary) -> Dictionary:
	var bounty_id := str(bounty.get("id", ""))
	var raw_objs: Array = bounty.get("objectives", [])
	var built_objs: Array[Dictionary] = []
	var done_count := 0
	var primary_nav_available := false
	var primary_nav_pos := Vector3.ZERO
	var primary_nav_label := ""
	var primary_recipe_hint := ""

	for obj in raw_objs:
		var required := maxi(1, int(obj.get("required", 1)))
		var done := bool(obj.get("done", false))
		var current := required if done else mini(required, int(obj.get("current", 0)))
		if done:
			done_count += 1
		var nav_info := _resolve_objective_nav(obj, snapshot)
		var nav_available := bool(nav_info["nav_available"])
		var nav_pos: Vector3 = nav_info["nav_pos"]
		var nav_label := str(nav_info["nav_label"])
		var distance_m := int(roundf(player_pos.distance_to(nav_pos))) if nav_available else -1
		var obj_recipe := str(obj.get("recipe_hint", ""))
		built_objs.append({
			"id": str(obj.get("id", "")),
			"label": str(obj.get("label", "")),
			"done": done,
			"current": current,
			"required": required,
			"nav_available": nav_available,
			"nav_pos": nav_pos,
			"nav_label": nav_label,
			"distance_m": distance_m,
			"recipe_hint": obj_recipe
		})
		if not done:
			if not primary_nav_available and nav_available:
				primary_nav_available = true
				primary_nav_pos = nav_pos
				primary_nav_label = nav_label
			if primary_recipe_hint.is_empty() and not obj_recipe.is_empty():
				primary_recipe_hint = obj_recipe

	var progress_ratio := 0.0
	var progress_text := "0/0"
	if built_objs.size() == 1:
		var only_obj: Dictionary = built_objs[0]
		var only_cur := int(only_obj.get("current", 0))
		var only_req := maxi(1, int(only_obj.get("required", 1)))
		progress_ratio = clampf(float(only_cur) / float(only_req), 0.0, 1.0)
		progress_text = "%d/%d" % [only_cur, only_req]
	elif not built_objs.is_empty():
		progress_ratio = clampf(float(done_count) / float(built_objs.size()), 0.0, 1.0)
		progress_text = "%d/%d" % [done_count, built_objs.size()]

	var rewards_def: Dictionary = bounty.get("rewards", {})
	return {
		"id": bounty_id,
		"category": "bounty",
		"category_label": QuestCatalog.get_category_label("bounty"),
		"act": 0,
		"act_label": QuestCatalog.get_act_label("bounty", 0),
		"status": "active",
		"tracked": tracked_quest_id == bounty_id,
		"title": str(bounty.get("title", "")),
		"brief": str(bounty.get("brief", "")),
		"progress_ratio": progress_ratio,
		"progress_text": progress_text,
		"rewards_summary": str(rewards_def.get("summary", "")),
		"recipe_hint": primary_recipe_hint,
		"primary_nav_available": primary_nav_available,
		"primary_nav_pos": primary_nav_pos,
		"primary_nav_label": primary_nav_label,
		"objectives": built_objs
	}

func _compact_hud_objective(obj: Dictionary) -> Dictionary:
	return {
		"id": str(obj.get("id", "")),
		"label": str(obj.get("label", "")),
		"done": bool(obj.get("done", false)),
		"current": int(obj.get("current", 0)),
		"required": int(obj.get("required", 1)),
		"distance_m": int(obj.get("distance_m", -1))
	}
