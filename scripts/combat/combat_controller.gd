extends RefCounted

const CombatTypes = preload("res://scripts/combat/combat_types.gd")
const WeaponCatalog = preload("res://scripts/combat/weapon_catalog.gd")
const SkillCatalog = preload("res://scripts/combat/skill_catalog.gd")

const MAX_SHIELD_ENERGY := 100.0
const SHIELD_OVERLOAD_DURATION := 5.0
const SHIELD_REGEN_PER_SEC := 14.0
const SHIELD_HELD_DRAIN_PER_SEC := 4.5
const PARRY_WINDOW_DURATION := 0.25

const MAX_FLUX := 100.0
const MAX_SONIC_HEAT := 100.0
const SONIC_COOL_PER_SEC := 24.0
const SONIC_OVERHEAT_COOL_PER_SEC := 34.0

const DODGE_RECHARGE_TIME := 3.2
const DODGE_INVULN_DURATION := 0.28
const PERFECT_DODGE_BUFF_DURATION := 3.0
const BULLET_TIME_DURATION := 0.35
const MAX_EQUIPPED_SLOTS := 3

const COMMAND_MODE_FOCUS := "focus"
const COMMAND_MODE_CAPTURE := "capture"

var shield_energy: float = MAX_SHIELD_ENERGY
var shield_overloaded: bool = false
var shield_overload_timer: float = 0.0
var parry_window_timer: float = 0.0

var flux: float = 0.0

var sonic_heat: float = 0.0
var sonic_overheated: bool = false

var dodge_charges: int = 1
var dodge_max_charges: int = 1
var dodge_cooldown: float = 0.0
var dodge_invuln_timer: float = 0.0
var perfect_dodge_buff_timer: float = 0.0

var weapon_art_cd: float = 0.0
var weapon_art_max_cd: float = 8.0
var tactical_cd: float = 0.0
var tactical_max_cd: float = 10.0
var bullet_time_timer: float = 0.0

var equipped_slots: Array[String] = ["knife"]
var active_slot_idx: int = 0
var command_mode: String = COMMAND_MODE_FOCUS


static func compute_companion_damage_multiplier(total_tamed: int, _deployed_count: int) -> float:
	return 1.0 + minf(0.60, float(maxi(0, total_tamed - 1)) * 0.04)


func reset(is_explore: bool = false) -> void:
	shield_energy = MAX_SHIELD_ENERGY
	shield_overloaded = false
	shield_overload_timer = 0.0
	parry_window_timer = 0.0

	flux = 0.0

	sonic_heat = 0.0
	sonic_overheated = false

	dodge_max_charges = 2 if is_explore else 1
	dodge_charges = dodge_max_charges
	dodge_cooldown = 0.0
	dodge_invuln_timer = 0.0
	perfect_dodge_buff_timer = 0.0

	weapon_art_cd = 0.0
	weapon_art_max_cd = 8.0
	tactical_cd = 0.0
	tactical_max_cd = 10.0
	bullet_time_timer = 0.0

	if is_explore:
		equipped_slots = ["knife", "axe", "sonic"]
	else:
		equipped_slots = ["knife"]
	active_slot_idx = 0
	command_mode = COMMAND_MODE_FOCUS


func ultimate_ready() -> bool:
	return flux >= MAX_FLUX


func tick(delta: float, shield_held: bool) -> void:
	var dt := maxf(0.0, delta)
	if dt <= 0.0:
		return

	parry_window_timer = maxf(0.0, parry_window_timer - dt)
	dodge_invuln_timer = maxf(0.0, dodge_invuln_timer - dt)
	perfect_dodge_buff_timer = maxf(0.0, perfect_dodge_buff_timer - dt)
	weapon_art_cd = maxf(0.0, weapon_art_cd - dt)
	tactical_cd = maxf(0.0, tactical_cd - dt)
	bullet_time_timer = maxf(0.0, bullet_time_timer - dt)

	if shield_overloaded:
		shield_overload_timer = maxf(0.0, shield_overload_timer - dt)
		var progress := 1.0 - (shield_overload_timer / SHIELD_OVERLOAD_DURATION)
		shield_energy = clampf(progress * 35.0, 0.0, 35.0)
		if shield_overload_timer <= 0.0:
			shield_overloaded = false
			shield_energy = maxf(shield_energy, 35.0)
	elif shield_held:
		shield_energy = maxf(0.0, shield_energy - SHIELD_HELD_DRAIN_PER_SEC * dt)
		if shield_energy <= 0.0:
			shield_overloaded = true
			shield_overload_timer = SHIELD_OVERLOAD_DURATION
			parry_window_timer = 0.0
	else:
		shield_energy = minf(MAX_SHIELD_ENERGY, shield_energy + SHIELD_REGEN_PER_SEC * dt)

	if sonic_heat > 0.0:
		var cool_rate := SONIC_OVERHEAT_COOL_PER_SEC if sonic_overheated else SONIC_COOL_PER_SEC
		sonic_heat = maxf(0.0, sonic_heat - cool_rate * dt)
		if sonic_overheated and sonic_heat <= 0.0:
			sonic_overheated = false

	if dodge_charges < dodge_max_charges:
		dodge_cooldown -= dt
		while dodge_cooldown <= 0.0 and dodge_charges < dodge_max_charges:
			dodge_charges += 1
			if dodge_charges < dodge_max_charges:
				dodge_cooldown += DODGE_RECHARGE_TIME
			else:
				dodge_cooldown = 0.0


func on_shield_pressed() -> bool:
	if shield_overloaded or shield_energy <= 0.0:
		return false
	parry_window_timer = PARRY_WINDOW_DURATION
	return true


func evaluate_incoming_hit(raw_damage: float, shield_held: bool, parryable: bool = true) -> Dictionary:
	var dmg := maxf(0.0, raw_damage)

	if dodge_invuln_timer > 0.0:
		dodge_invuln_timer = 0.0
		perfect_dodge_buff_timer = PERFECT_DODGE_BUFF_DURATION
		bullet_time_timer = BULLET_TIME_DURATION
		var dodge_flux := 18.0
		add_flux(dodge_flux)
		return {
			"outcome": "perfect_dodge",
			"damage_taken": 0.0,
			"attacker_poise_damage": 24.0,
			"flux_gained": dodge_flux,
			"trigger_bullet_time": true,
		}

	if shield_held and not shield_overloaded and parryable and parry_window_timer > 0.0:
		parry_window_timer = 0.0
		shield_energy = minf(MAX_SHIELD_ENERGY, shield_energy + 18.0)
		bullet_time_timer = BULLET_TIME_DURATION
		var parry_flux := 25.0
		add_flux(parry_flux)
		return {
			"outcome": "perfect_parry",
			"damage_taken": 0.0,
			"attacker_poise_damage": 65.0,
			"flux_gained": parry_flux,
			"trigger_bullet_time": true,
		}

	if shield_held and not shield_overloaded and shield_energy > 0.0:
		var energy_cost := maxf(12.0, dmg * 1.15)
		if shield_energy >= energy_cost:
			shield_energy = maxf(0.0, shield_energy - energy_cost)
			var block_flux := 8.0
			add_flux(block_flux)
			return {
				"outcome": "block",
				"damage_taken": dmg * 0.15,
				"attacker_poise_damage": 12.0,
				"flux_gained": block_flux,
				"trigger_bullet_time": false,
			}
		var overflow_ratio := clampf((energy_cost - shield_energy) / maxf(1.0, energy_cost), 0.25, 1.0)
		shield_energy = 0.0
		shield_overloaded = true
		shield_overload_timer = SHIELD_OVERLOAD_DURATION
		parry_window_timer = 0.0
		var break_flux := 4.0
		add_flux(break_flux)
		return {
			"outcome": "shield_break",
			"damage_taken": dmg * (0.45 + 0.40 * overflow_ratio),
			"attacker_poise_damage": 0.0,
			"flux_gained": break_flux,
			"trigger_bullet_time": false,
		}

	var hit_flux := 6.0
	add_flux(hit_flux)
	return {
		"outcome": "hit",
		"damage_taken": dmg,
		"attacker_poise_damage": 0.0,
		"flux_gained": hit_flux,
		"trigger_bullet_time": false,
	}


func try_dodge(has_biomod_dash: bool) -> Dictionary:
	var target_max := 2 if has_biomod_dash else 1
	if target_max > dodge_max_charges:
		if dodge_cooldown <= 0.0 and dodge_charges == dodge_max_charges:
			dodge_charges = target_max
		dodge_max_charges = target_max
	elif target_max < dodge_max_charges:
		dodge_max_charges = target_max
		dodge_charges = mini(dodge_charges, dodge_max_charges)

	if dodge_charges <= 0:
		return {
			"ok": false,
			"reason": "cooldown",
			"charges": dodge_charges,
			"max_charges": dodge_max_charges,
			"cooldown": dodge_cooldown,
		}

	dodge_charges -= 1
	if dodge_cooldown <= 0.0:
		dodge_cooldown = DODGE_RECHARGE_TIME
	dodge_invuln_timer = DODGE_INVULN_DURATION
	return {
		"ok": true,
		"charges": dodge_charges,
		"max_charges": dodge_max_charges,
		"invuln_duration": DODGE_INVULN_DURATION,
		"cooldown": dodge_cooldown,
	}


func consume_perfect_dodge_crit() -> bool:
	if perfect_dodge_buff_timer <= 0.0:
		return false
	perfect_dodge_buff_timer = 0.0
	return true


func try_weapon_art(weapon_id: String, cooldown_mult: float = 1.0) -> Dictionary:
	var weapon := WeaponCatalog.get_weapon(weapon_id)
	var art: Dictionary = weapon.get("weapon_art", {})
	if weapon_art_cd > 0.0:
		return {
			"ok": false,
			"reason": "cooldown",
			"remaining": weapon_art_cd,
			"weapon_id": String(weapon["id"]),
			"art": art,
		}
	var base_cd := float(art.get("cooldown", 10.0))
	weapon_art_max_cd = maxf(2.0, base_cd * clampf(cooldown_mult, 0.4, 2.0))
	weapon_art_cd = weapon_art_max_cd
	if bool(art.get("clear_heat", false)):
		cool_sonic_completely()
	add_flux(12.0)
	return {
		"ok": true,
		"weapon_id": String(weapon["id"]),
		"art": art,
		"cooldown": weapon_art_cd,
	}


func try_tactical_skill(skill_id: String, oxygen_available: float) -> Dictionary:
	var skill := SkillCatalog.get_tactical_skill(skill_id)
	if tactical_cd > 0.0:
		return {
			"ok": false,
			"reason": "cooldown",
			"remaining": tactical_cd,
			"skill_id": String(skill["id"]),
			"skill": skill,
		}
	var oxy_cost := float(skill.get("oxygen_cost", 0.0))
	if oxy_cost > 0.0 and oxygen_available < oxy_cost:
		return {
			"ok": false,
			"reason": "low_oxygen",
			"oxygen_cost": oxy_cost,
			"skill_id": String(skill["id"]),
			"skill": skill,
		}
	tactical_max_cd = maxf(2.0, float(skill.get("cooldown", 12.0)))
	tactical_cd = tactical_max_cd
	var shield_restore := float(skill.get("shield_energy_restore", 0.0))
	if shield_restore > 0.0:
		shield_energy = minf(MAX_SHIELD_ENERGY, shield_energy + shield_restore)
		if shield_overloaded and shield_energy >= 35.0:
			shield_overloaded = false
			shield_overload_timer = 0.0
	add_flux(10.0)
	return {
		"ok": true,
		"skill_id": String(skill["id"]),
		"skill": skill,
		"oxygen_cost": oxy_cost,
		"cooldown": tactical_cd,
	}


func try_ultimate(character_id: String, in_submarine: bool) -> Dictionary:
	var ult := SkillCatalog.get_ultimate_for_context(character_id, in_submarine)
	if not ultimate_ready():
		return {
			"ok": false,
			"reason": "insufficient_flux",
			"flux": flux,
			"required": MAX_FLUX,
			"ultimate_id": String(ult["id"]),
			"ultimate": ult,
		}
	flux = 0.0
	bullet_time_timer = maxf(bullet_time_timer, 0.25)
	var shield_restore := float(ult.get("shield_energy_restore", 0.0))
	if shield_restore > 0.0:
		shield_energy = minf(MAX_SHIELD_ENERGY, shield_energy + shield_restore)
		if shield_overloaded and shield_energy >= 35.0:
			shield_overloaded = false
			shield_overload_timer = 0.0
	return {
		"ok": true,
		"ultimate_id": String(ult["id"]),
		"ultimate": ult,
	}


func add_flux(amount: float) -> void:
	flux = clampf(flux + maxf(0.0, amount), 0.0, MAX_FLUX)


func consume_sonic_heat(amount: float, weakpoint_hit: bool = false) -> bool:
	if sonic_overheated:
		return false
	if weakpoint_hit:
		return true
	sonic_heat = clampf(sonic_heat + maxf(0.0, amount), 0.0, MAX_SONIC_HEAT)
	if sonic_heat >= MAX_SONIC_HEAT:
		sonic_overheated = true
	return true


func cool_sonic_completely() -> void:
	sonic_heat = 0.0
	sonic_overheated = false


func set_equipped_slots(slots: Array) -> void:
	var cleaned: Array[String] = []
	for raw_id in slots:
		var wid := String(raw_id)
		if WeaponCatalog.WEAPONS.has(wid) and not cleaned.has(wid):
			cleaned.append(wid)
			if cleaned.size() >= MAX_EQUIPPED_SLOTS:
				break
	if cleaned.is_empty():
		cleaned.append("knife")
	equipped_slots = cleaned
	active_slot_idx = clampi(active_slot_idx, 0, equipped_slots.size() - 1)


func equip_slot_weapon(slot_idx: int, weapon_id: String) -> void:
	if not WeaponCatalog.WEAPONS.has(weapon_id):
		return
	var target_idx := clampi(slot_idx, 0, MAX_EQUIPPED_SLOTS - 1)
	var existing_idx := equipped_slots.find(weapon_id)
	if existing_idx >= 0 and existing_idx != target_idx:
		if target_idx < equipped_slots.size():
			var prev := equipped_slots[target_idx]
			equipped_slots[target_idx] = weapon_id
			equipped_slots[existing_idx] = prev
		else:
			equipped_slots.remove_at(existing_idx)
			equipped_slots.append(weapon_id)
	elif target_idx < equipped_slots.size():
		equipped_slots[target_idx] = weapon_id
	else:
		equipped_slots.append(weapon_id)
	active_slot_idx = clampi(active_slot_idx, 0, equipped_slots.size() - 1)


func select_slot(slot_idx: int) -> String:
	if equipped_slots.is_empty():
		equipped_slots = ["knife"]
	active_slot_idx = clampi(slot_idx, 0, equipped_slots.size() - 1)
	return equipped_slots[active_slot_idx]


func cycle_slot(step: int = 1) -> String:
	if equipped_slots.is_empty():
		equipped_slots = ["knife"]
	active_slot_idx = posmod(active_slot_idx + step, equipped_slots.size())
	return equipped_slots[active_slot_idx]


func get_active_weapon() -> String:
	if equipped_slots.is_empty():
		return "knife"
	active_slot_idx = clampi(active_slot_idx, 0, equipped_slots.size() - 1)
	return equipped_slots[active_slot_idx]


func toggle_command_mode() -> String:
	command_mode = COMMAND_MODE_CAPTURE if command_mode == COMMAND_MODE_FOCUS else COMMAND_MODE_FOCUS
	return command_mode


func set_command_mode(mode_name: String) -> void:
	command_mode = COMMAND_MODE_CAPTURE if mode_name == COMMAND_MODE_CAPTURE else COMMAND_MODE_FOCUS


func get_hud_payload(
	current_weapon: String,
	active_tactical_id: String,
	character_id: String,
	in_submarine: bool
) -> Dictionary:
	var weapon := WeaponCatalog.get_weapon(current_weapon)
	var art: Dictionary = weapon.get("weapon_art", {})
	var tactical := SkillCatalog.get_tactical_skill(active_tactical_id)
	var ult := SkillCatalog.get_ultimate_for_context(character_id, in_submarine)
	return {
		"shield_energy": shield_energy,
		"shield_max": MAX_SHIELD_ENERGY,
		"shield_ratio": clampf(shield_energy / MAX_SHIELD_ENERGY, 0.0, 1.0),
		"shield_overloaded": shield_overloaded,
		"shield_overload_timer": shield_overload_timer,
		"parry_active": parry_window_timer > 0.0,
		"flux": flux,
		"flux_max": MAX_FLUX,
		"flux_ratio": clampf(flux / MAX_FLUX, 0.0, 1.0),
		"ultimate_ready": ultimate_ready(),
		"ultimate_id": String(ult["id"]),
		"ultimate_name": String(ult["name"]),
		"ultimate_desc": String(ult["desc"]),
		"weapon_id": String(weapon["id"]),
		"weapon_name": String(weapon["name"]),
		"weapon_art_id": String(art.get("id", "")),
		"weapon_art_name": String(art.get("name", "")),
		"weapon_art_cd": weapon_art_cd,
		"weapon_art_max_cd": maxf(1.0, weapon_art_max_cd),
		"weapon_art_ready": weapon_art_cd <= 0.0,
		"tactical_id": String(tactical["id"]),
		"tactical_name": String(tactical["name"]),
		"tactical_cd": tactical_cd,
		"tactical_max_cd": maxf(1.0, tactical_max_cd),
		"tactical_ready": tactical_cd <= 0.0,
		"sonic_heat": sonic_heat,
		"sonic_heat_max": MAX_SONIC_HEAT,
		"sonic_heat_ratio": clampf(sonic_heat / MAX_SONIC_HEAT, 0.0, 1.0),
		"sonic_overheated": sonic_overheated,
		"show_sonic_heat": String(weapon["id"]) == "sonic" or sonic_heat > 0.0,
		"dodge_charges": dodge_charges,
		"dodge_max_charges": dodge_max_charges,
		"dodge_cooldown": dodge_cooldown,
		"perfect_dodge_active": perfect_dodge_buff_timer > 0.0,
		"perfect_dodge_buff_timer": perfect_dodge_buff_timer,
		"bullet_time_active": bullet_time_timer > 0.0,
		"bullet_time_timer": bullet_time_timer,
		"equipped_slots": equipped_slots.duplicate(),
		"active_slot_idx": active_slot_idx,
		"command_mode": command_mode,
		"command_mode_name": "活捕压血(20%)" if command_mode == COMMAND_MODE_CAPTURE else "集火狂攻",
	}
