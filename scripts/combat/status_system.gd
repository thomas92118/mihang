extends RefCounted

const CombatTypes = preload("res://scripts/combat/combat_types.gd")

const BUILDUP_THRESHOLD := 100.0
const STAGGER_DURATION := 4.5
const STAGGER_DAMAGE_MULT := 1.45
const WEAKPOINT_DAMAGE_MULT := 1.5
const RESONANCE_VULN_MULT := 1.12
const NON_LETHAL_STUN_DURATION := 3.0
const BUILDUP_DECAY_PER_SEC := 6.0
const POISE_REGEN_DELAY := 4.0
const POISE_REGEN_PER_SEC := 8.0
const DOT_INTERVAL := 1.0

const STATUS_DURATIONS := {
	CombatTypes.STATUS_ELECTRO: 7.0,
	CombatTypes.STATUS_RUPTURE: 8.0,
	CombatTypes.STATUS_STASIS: 6.0,
	CombatTypes.STATUS_RESONANCE: 8.0,
}

var _targets: Dictionary = {}


func register_target(target_id: int, max_poise: float = 100.0, armor: float = 0.0) -> void:
	var clamped_poise := maxf(1.0, max_poise)
	var clamped_armor := clampf(armor, 0.0, 0.92)
	if _targets.has(target_id):
		var existing: Dictionary = _targets[target_id]
		existing["max_poise"] = clamped_poise
		existing["poise"] = minf(float(existing["poise"]), clamped_poise)
		existing["base_armor"] = clamped_armor
		_refresh_effective_armor(existing)
		return
	_targets[target_id] = {
		"target_id": target_id,
		"buildup": {
			CombatTypes.STATUS_ELECTRO: 0.0,
			CombatTypes.STATUS_RUPTURE: 0.0,
			CombatTypes.STATUS_STASIS: 0.0,
			CombatTypes.STATUS_RESONANCE: 0.0,
		},
		"active": {},
		"poise": clamped_poise,
		"max_poise": clamped_poise,
		"poise_regen_delay": 0.0,
		"stagger_timer": 0.0,
		"base_armor": clamped_armor,
		"armor": clamped_armor,
		"armor_shred_timer": 0.0,
		"stun_timer": 0.0,
		"dot_accumulators": {
			CombatTypes.STATUS_ELECTRO: 0.0,
			CombatTypes.STATUS_RUPTURE: 0.0,
		},
		"last_max_hp": 100.0,
		"star_bonus": 0,
	}


func unregister_target(target_id: int) -> void:
	_targets.erase(target_id)


func has_target(target_id: int) -> bool:
	return _targets.has(target_id)


func clear_all() -> void:
	_targets.clear()


func apply_stun(target_id: int, duration: float) -> void:
	if not _targets.has(target_id):
		register_target(target_id)
	var state: Dictionary = _targets[target_id]
	state["stun_timer"] = maxf(float(state["stun_timer"]), maxf(0.0, duration))


func apply_hit(target_id: int, packet: Dictionary, target_hp: float, target_max_hp: float) -> Dictionary:
	if not _targets.has(target_id):
		register_target(target_id)
	var state: Dictionary = _targets[target_id]
	var max_hp := maxf(1.0, target_max_hp)
	state["last_max_hp"] = max_hp

	var norm := CombatTypes.make_damage_packet(packet)
	var active: Dictionary = state["active"]
	var buildup: Dictionary = state["buildup"]
	_refresh_effective_armor(state)

	var effective_armor := clampf(float(state["armor"]) * (1.0 - float(norm["armor_pierce"])), 0.0, 0.92)
	var weakpoint_hit := bool(norm["weakpoint_hit"])
	var weakpoint_mult := WEAKPOINT_DAMAGE_MULT if weakpoint_hit else 1.0
	var staggered_before := float(state["stagger_timer"]) > 0.0
	var stagger_mult := STAGGER_DAMAGE_MULT if staggered_before else 1.0
	var resonance_mult := RESONANCE_VULN_MULT if active.has(CombatTypes.STATUS_RESONANCE) else 1.0

	var crit_chance := float(norm["crit_chance"])
	var is_crit := crit_chance >= 1.0 or (crit_chance > 0.0 and randf() < crit_chance)
	var crit_mult := float(norm["crit_mult"]) if is_crit else 1.0

	var direct_damage := float(norm["base_damage"]) * weakpoint_mult * stagger_mult * crit_mult * (1.0 - effective_armor) * resonance_mult

	var poise_dmg := float(norm["poise_damage"])
	var stagger_broken := false
	if poise_dmg > 0.0 and float(state["stagger_timer"]) <= 0.0:
		state["poise"] = maxf(0.0, float(state["poise"]) - poise_dmg)
		state["poise_regen_delay"] = POISE_REGEN_DELAY
		if float(state["poise"]) <= 0.0:
			stagger_broken = true
			state["stagger_timer"] = STAGGER_DURATION

	var status_type := String(norm["status_type"])
	var status_amount := float(norm["status_amount"])
	var status_triggered := ""
	var reactions: Array[Dictionary] = []
	var reaction_damage := 0.0
	var reaction_poise := 0.0
	var reaction_star_bonus := 0
	var reaction_stun_applied := false

	if status_type != "" and status_amount > 0.0:
		buildup[status_type] = minf(BUILDUP_THRESHOLD, float(buildup.get(status_type, 0.0)) + status_amount)
		if float(buildup[status_type]) >= BUILDUP_THRESHOLD:
			buildup[status_type] = 0.0
			active[status_type] = float(STATUS_DURATIONS.get(status_type, 6.0))
			status_triggered = status_type
			if status_type == CombatTypes.STATUS_RESONANCE:
				state["armor_shred_timer"] = maxf(float(state["armor_shred_timer"]), float(STATUS_DURATIONS[CombatTypes.STATUS_RESONANCE]))
			reactions = _resolve_reactions(state, status_type, max_hp)
			for reaction in reactions:
				reaction_damage += float(reaction.get("damage", 0.0))
				reaction_poise += float(reaction.get("poise_damage", 0.0))
				reaction_star_bonus += int(reaction.get("star_bonus", 0))
				if float(reaction.get("armor_shred_duration", 0.0)) > 0.0:
					state["armor_shred_timer"] = maxf(float(state["armor_shred_timer"]), float(reaction["armor_shred_duration"]))
				if float(reaction.get("stun_duration", 0.0)) > 0.0:
					state["stun_timer"] = maxf(float(state["stun_timer"]), float(reaction["stun_duration"]))
					reaction_stun_applied = true

	if reaction_poise > 0.0 and float(state["stagger_timer"]) <= 0.0:
		state["poise"] = maxf(0.0, float(state["poise"]) - reaction_poise)
		state["poise_regen_delay"] = POISE_REGEN_DELAY
		if float(state["poise"]) <= 0.0:
			stagger_broken = true
			state["stagger_timer"] = STAGGER_DURATION

	if reaction_star_bonus > 0:
		state["star_bonus"] = mini(2, int(state["star_bonus"]) + reaction_star_bonus)

	_refresh_effective_armor(state)

	var total_damage := direct_damage + reaction_damage
	var non_lethal_clamped := false
	var stun_applied := false
	if bool(norm["non_lethal_stun"]) and target_hp > 0.0 and total_damage >= target_hp:
		total_damage = maxf(0.0, target_hp - 1.0)
		state["stun_timer"] = maxf(float(state["stun_timer"]), NON_LETHAL_STUN_DURATION)
		non_lethal_clamped = true
		stun_applied = true

	var resulting_hp := maxf(0.0, target_hp - total_damage)
	return {
		"target_id": target_id,
		"final_damage": total_damage,
		"direct_damage": direct_damage,
		"reaction_damage": reaction_damage,
		"resulting_hp": resulting_hp,
		"is_crit": is_crit,
		"weakpoint_hit": weakpoint_hit,
		"effective_armor": effective_armor,
		"poise_damage": poise_dmg + reaction_poise,
		"poise_remaining": float(state["poise"]),
		"max_poise": float(state["max_poise"]),
		"stagger_broken": stagger_broken,
		"is_staggered": float(state["stagger_timer"]) > 0.0,
		"stagger_timer": float(state["stagger_timer"]),
		"status_triggered": status_triggered,
		"reactions": reactions,
		"non_lethal_clamped": non_lethal_clamped,
		"stun_applied": stun_applied or reaction_stun_applied,
		"stun_timer": float(state["stun_timer"]),
		"capture_ready": is_capture_ready(target_id),
		"star_bias": int(norm["star_bias"]),
		"star_bonus": int(state["star_bonus"]),
		"impulse": norm["impulse"],
		"world_pos": norm["world_pos"],
	}


func tick(delta: float) -> Array[Dictionary]:
	var dt := maxf(0.0, delta)
	var events: Array[Dictionary] = []
	if dt <= 0.0:
		return events

	for tid_variant in _targets.keys():
		var target_id := int(tid_variant)
		var state: Dictionary = _targets[target_id]
		var active: Dictionary = state["active"]
		var buildup: Dictionary = state["buildup"]
		var dot_acc: Dictionary = state["dot_accumulators"]
		var max_hp := maxf(1.0, float(state["last_max_hp"]))

		var stagger_t := float(state["stagger_timer"])
		if stagger_t > 0.0:
			stagger_t = maxf(0.0, stagger_t - dt)
			state["stagger_timer"] = stagger_t
			if stagger_t <= 0.0:
				state["poise"] = float(state["max_poise"])
		else:
			var delay_t := float(state["poise_regen_delay"])
			if delay_t > 0.0:
				state["poise_regen_delay"] = maxf(0.0, delay_t - dt)
			elif float(state["poise"]) < float(state["max_poise"]):
				state["poise"] = minf(float(state["max_poise"]), float(state["poise"]) + POISE_REGEN_PER_SEC * dt)

		if float(state["armor_shred_timer"]) > 0.0:
			state["armor_shred_timer"] = maxf(0.0, float(state["armor_shred_timer"]) - dt)
		if float(state["stun_timer"]) > 0.0:
			state["stun_timer"] = maxf(0.0, float(state["stun_timer"]) - dt)

		var expired_statuses: Array[String] = []
		for s_key_variant in active.keys():
			var s_key := String(s_key_variant)
			var rem := float(active[s_key]) - dt
			if s_key == CombatTypes.STATUS_RUPTURE or s_key == CombatTypes.STATUS_ELECTRO:
				var acc := float(dot_acc.get(s_key, 0.0)) + dt
				while acc >= DOT_INTERVAL:
					acc -= DOT_INTERVAL
					if s_key == CombatTypes.STATUS_RUPTURE:
						var bleed_dmg := clampf(max_hp * 0.024, 6.0, 48.0)
						events.append({
							"target_id": target_id,
							"status_type": CombatTypes.STATUS_RUPTURE,
							"damage": bleed_dmg,
							"poise_damage": 2.0,
							"arc_radius": 0.0,
							"color": CombatTypes.get_status_color(CombatTypes.STATUS_RUPTURE),
						})
					else:
						var shock_dmg := clampf(max_hp * 0.018, 5.0, 36.0)
						events.append({
							"target_id": target_id,
							"status_type": CombatTypes.STATUS_ELECTRO,
							"damage": shock_dmg,
							"poise_damage": 6.0,
							"arc_radius": 8.5,
							"color": CombatTypes.get_status_color(CombatTypes.STATUS_ELECTRO),
						})
				dot_acc[s_key] = acc
			if rem <= 0.0:
				expired_statuses.append(s_key)
			else:
				active[s_key] = rem

		for expired_key in expired_statuses:
			active.erase(expired_key)
			if dot_acc.has(expired_key):
				dot_acc[expired_key] = 0.0

		for status_id in CombatTypes.ALL_STATUSES:
			if not active.has(status_id):
				var cur_b := float(buildup.get(status_id, 0.0))
				if cur_b > 0.0:
					buildup[status_id] = maxf(0.0, cur_b - BUILDUP_DECAY_PER_SEC * dt)

		_refresh_effective_armor(state)

	return events


func get_target_state(target_id: int) -> Dictionary:
	if not _targets.has(target_id):
		return {}
	var state: Dictionary = _targets[target_id]
	var max_poise := maxf(1.0, float(state["max_poise"]))
	var poise := float(state["poise"])
	var active_copy: Dictionary = (state["active"] as Dictionary).duplicate(true)
	return {
		"target_id": target_id,
		"buildup": (state["buildup"] as Dictionary).duplicate(true),
		"active": active_copy,
		"poise": poise,
		"max_poise": max_poise,
		"poise_ratio": clampf(poise / max_poise, 0.0, 1.0),
		"stagger_timer": float(state["stagger_timer"]),
		"is_staggered": float(state["stagger_timer"]) > 0.0,
		"armor": float(state["armor"]),
		"base_armor": float(state["base_armor"]),
		"armor_shredded": float(state["base_armor"]) > 0.0 and float(state["armor"]) <= 0.001,
		"armor_shred_timer": float(state["armor_shred_timer"]),
		"stun_timer": float(state["stun_timer"]),
		"capture_ready": is_capture_ready(target_id),
		"star_bonus": int(state["star_bonus"]),
	}


func is_staggered(target_id: int) -> bool:
	if not _targets.has(target_id):
		return false
	return float((_targets[target_id] as Dictionary)["stagger_timer"]) > 0.0


func is_capture_ready(target_id: int) -> bool:
	if not _targets.has(target_id):
		return false
	var state: Dictionary = _targets[target_id]
	return float(state["stun_timer"]) > 0.0


func _refresh_effective_armor(state: Dictionary) -> void:
	var active: Dictionary = state["active"]
	if float(state["armor_shred_timer"]) > 0.0 or active.has(CombatTypes.STATUS_RESONANCE):
		state["armor"] = 0.0
	else:
		state["armor"] = float(state["base_armor"])


func _resolve_reactions(state: Dictionary, incoming_status: String, target_max_hp: float) -> Array[Dictionary]:
	var active: Dictionary = state["active"]
	var triggered: Array[Dictionary] = []

	var pairs: Array[Array] = [
		[CombatTypes.STATUS_ELECTRO, CombatTypes.STATUS_STASIS, CombatTypes.REACTION_SUPERCONDUCT],
		[CombatTypes.STATUS_RESONANCE, CombatTypes.STATUS_RUPTURE, CombatTypes.REACTION_IMPLOSION],
		[CombatTypes.STATUS_ELECTRO, CombatTypes.STATUS_RUPTURE, CombatTypes.REACTION_OVERCHARGE],
		[CombatTypes.STATUS_RESONANCE, CombatTypes.STATUS_STASIS, CombatTypes.REACTION_CRYSTAL_FREEZE],
	]

	for pair in pairs:
		var a := String(pair[0])
		var b := String(pair[1])
		var reaction_id := String(pair[2])
		if incoming_status != a and incoming_status != b:
			continue
		if not active.has(a) or not active.has(b):
			continue
		active.erase(a)
		active.erase(b)
		var dot_acc: Dictionary = state["dot_accumulators"]
		if dot_acc.has(a):
			dot_acc[a] = 0.0
		if dot_acc.has(b):
			dot_acc[b] = 0.0
		triggered.append(_build_reaction_payload(reaction_id, target_max_hp))
		break

	return triggered


func _build_reaction_payload(reaction_id: String, target_max_hp: float) -> Dictionary:
	match reaction_id:
		CombatTypes.REACTION_SUPERCONDUCT:
			return {
				"id": reaction_id,
				"name": CombatTypes.get_reaction_name(reaction_id),
				"color": CombatTypes.get_reaction_color(reaction_id),
				"damage": clampf(target_max_hp * 0.085, 48.0, 260.0),
				"poise_damage": 55.0,
				"armor_shred_duration": 8.0,
				"stun_duration": 0.0,
				"aoe_radius": 6.0,
				"star_bonus": 0,
			}
		CombatTypes.REACTION_IMPLOSION:
			return {
				"id": reaction_id,
				"name": CombatTypes.get_reaction_name(reaction_id),
				"color": CombatTypes.get_reaction_color(reaction_id),
				"damage": clampf(target_max_hp * 0.115, 64.0, 340.0),
				"poise_damage": 72.0,
				"armor_shred_duration": 4.0,
				"stun_duration": 0.0,
				"aoe_radius": 8.0,
				"star_bonus": 0,
			}
		CombatTypes.REACTION_OVERCHARGE:
			return {
				"id": reaction_id,
				"name": CombatTypes.get_reaction_name(reaction_id),
				"color": CombatTypes.get_reaction_color(reaction_id),
				"damage": clampf(target_max_hp * 0.095, 54.0, 290.0),
				"poise_damage": 44.0,
				"armor_shred_duration": 0.0,
				"stun_duration": 1.2,
				"aoe_radius": 10.0,
				"star_bonus": 0,
			}
		CombatTypes.REACTION_CRYSTAL_FREEZE:
			return {
				"id": reaction_id,
				"name": CombatTypes.get_reaction_name(reaction_id),
				"color": CombatTypes.get_reaction_color(reaction_id),
				"damage": clampf(target_max_hp * 0.06, 36.0, 180.0),
				"poise_damage": 66.0,
				"armor_shred_duration": 0.0,
				"stun_duration": 4.0,
				"aoe_radius": 6.0,
				"star_bonus": 1,
			}
	return {
		"id": reaction_id,
		"name": CombatTypes.get_reaction_name(reaction_id),
		"color": CombatTypes.get_reaction_color(reaction_id),
		"damage": 40.0,
		"poise_damage": 35.0,
		"armor_shred_duration": 0.0,
		"stun_duration": 0.0,
		"aoe_radius": 0.0,
		"star_bonus": 0,
	}
