extends RefCounted

const CANONICAL_IDS := {
	"water_dragon": "water_dragon",
	"flying_fish": "flying_fish",
	"boss_flying_fish": "flying_fish",
	"kraken": "kraken",
	"boss_kraken": "kraken",
	"colossus_turtle": "colossus_turtle",
	"boss_turtle": "colossus_turtle"
}

const WEAKPOINT_OFFSETS := {
	"water_dragon": Vector3(0.0, -0.9, 3.8),
	"flying_fish": Vector3(0.0, 0.42, 1.2),
	"kraken": Vector3(0.0, 0.9, 2.8),
	"colossus_turtle": Vector3(0.0, -1.65, 0.4)
}

const WEAKPOINT_LABELS := {
	"water_dragon": "咽喉逆鳞",
	"flying_fish": "双侧电光翼膜",
	"kraken": "中央巨眼",
	"colossus_turtle": "腹甲晶核缝隙"
}

const BASE_ARMOR := {
	"water_dragon": 0.15,
	"flying_fish": 0.08,
	"kraken": 0.20,
	"colossus_turtle": 0.55
}

const MAX_POISE := {
	"water_dragon": 180.0,
	"flying_fish": 140.0,
	"kraken": 210.0,
	"colossus_turtle": 240.0
}

const MOVE_ROTATIONS := {
	"water_dragon": ["tail_sweep", "hydro_breath", "vortex_pull"],
	"flying_fish": ["lightning_dive", "storm_orbs", "sky_plunge"],
	"kraken": ["tentacle_slam", "ink_shroud", "maelstrom_crush"],
	"colossus_turtle": ["shell_ram", "seismic_stomp", "vent_eruption"]
}

const BOSS_TITLES := {
	"water_dragon": "深渊水龙",
	"flying_fish": "风暴飞鱼",
	"kraken": "深渊巨章",
	"colossus_turtle": "远古灵龟"
}

var _states: Dictionary = {}

func _init() -> void:
	reset()

func _canonical_id(boss_id: String) -> String:
	return str(CANONICAL_IDS.get(boss_id, "water_dragon"))

func _make_default_state() -> Dictionary:
	return {
		"action": "circle",
		"substage": "idle",
		"timer": 2.4,
		"cycle": 0,
		"phase": 1,
		"direction": Vector3.FORWARD,
		"anchor_pos": Vector3.ZERO,
		"target_pos": Vector3.ZERO,
		"hit_sent": false,
		"telegraph_sent": false,
		"pulse_accum": 0.0,
		"hits_done": 0,
		"beam_hit_cd": 0.0,
		"sweep_angle": -1.0
	}

func reset() -> void:
	_states.clear()
	for id in ["water_dragon", "flying_fish", "kraken", "colossus_turtle"]:
		_states[id] = _make_default_state()

func reset_boss(boss_id: String) -> void:
	var cid := _canonical_id(boss_id)
	_states[cid] = _make_default_state()

func get_boss_timer(boss_id: String) -> float:
	var cid := _canonical_id(boss_id)
	if not _states.has(cid):
		return 2.4
	return float(_states[cid].get("timer", 2.4))

func get_weakpoint_world_pos(boss_id: String, boss_node: Node3D) -> Vector3:
	if not is_instance_valid(boss_node):
		return Vector3.ZERO
	var cid := _canonical_id(boss_id)
	var local_offset: Vector3 = WEAKPOINT_OFFSETS.get(cid, Vector3(0.0, 0.0, 2.0))
	var xform: Transform3D = boss_node.global_transform if boss_node.is_inside_tree() else boss_node.transform
	return xform * local_offset

func get_weakpoint_label(boss_id: String) -> String:
	var cid := _canonical_id(boss_id)
	return str(WEAKPOINT_LABELS.get(cid, "核心弱点"))

func get_base_armor(boss_id: String) -> float:
	var cid := _canonical_id(boss_id)
	return float(BASE_ARMOR.get(cid, 0.1))

func get_max_poise(boss_id: String) -> float:
	var cid := _canonical_id(boss_id)
	return float(MAX_POISE.get(cid, 160.0))

func _compute_phase(boss_node: Node3D) -> int:
	if not is_instance_valid(boss_node):
		return 1
	var max_hp: float = maxf(1.0, float(boss_node.get_meta("max_health", 1800.0)))
	var hp: float = float(boss_node.get_meta("health", max_hp))
	var ratio: float = hp / max_hp
	if ratio <= 0.35:
		return 3
	if ratio <= 0.65:
		return 2
	return 1

func _make_attack(
	attack_name: String,
	damage: float,
	pos: Vector3,
	attacker: Node3D,
	parryable: bool,
	status_type: String = "",
	status_amount: float = 0.0
) -> Dictionary:
	return {
		"name": attack_name,
		"damage": damage,
		"pos": pos,
		"attacker": attacker,
		"parryable": parryable,
		"status_type": status_type,
		"status_amount": status_amount
	}

func _make_telegraph(pos: Vector3, radius: float, unblockable: bool, duration: float) -> Dictionary:
	return {
		"pos": pos,
		"radius": radius,
		"unblockable": unblockable,
		"duration": duration
	}

func _make_vfx(kind: String, pos: Vector3, to: Vector3, radius: float, color: Color) -> Dictionary:
	return {
		"kind": kind,
		"pos": pos,
		"to": to,
		"radius": radius,
		"color": color
	}

func _face_direction(boss_node: Node3D, dir: Vector3) -> void:
	if dir.length_squared() <= 0.0001:
		return
	var norm_dir := dir.normalized()
	var up := Vector3.UP if absf(norm_dir.y) < 0.95 else Vector3.FORWARD
	boss_node.look_at(boss_node.position + norm_dir, up, true)

func _phase_damage_scale(phase: int) -> float:
	if phase == 3:
		return 1.32
	if phase == 2:
		return 1.16
	return 1.0

func _phase_speed_scale(phase: int) -> float:
	if phase == 3:
		return 1.35
	if phase == 2:
		return 1.18
	return 1.0

func _phase_cooldown_scale(phase: int) -> float:
	if phase == 3:
		return 0.72
	if phase == 2:
		return 0.85
	return 1.0

func _select_next_move(cid: String, state: Dictionary) -> String:
	var rotation: Array = MOVE_ROTATIONS.get(cid, ["tail_sweep"])
	var idx: int = int(state["cycle"]) % rotation.size()
	state["cycle"] = int(state["cycle"]) + 1
	return str(rotation[idx])

func _enter_circle(cid: String, state: Dictionary, phase: int) -> void:
	state["action"] = "circle"
	state["substage"] = "idle"
	state["hit_sent"] = false
	state["telegraph_sent"] = false
	state["pulse_accum"] = 0.0
	state["hits_done"] = 0
	var base_circle := 2.4
	match cid:
		"flying_fish":
			base_circle = 2.0
		"colossus_turtle":
			base_circle = 2.6
		"kraken":
			base_circle = 2.3
	state["timer"] = base_circle * _phase_cooldown_scale(phase)

func _enter_move(cid: String, move_name: String, state: Dictionary, boss_node: Node3D, diver_pos: Vector3, phase: int) -> void:
	state["action"] = move_name
	state["substage"] = "windup"
	state["hit_sent"] = false
	state["telegraph_sent"] = false
	state["pulse_accum"] = 0.0
	state["hits_done"] = 0
	state["beam_hit_cd"] = 0.0
	state["sweep_angle"] = -0.85
	var to_diver := diver_pos - boss_node.global_position
	state["direction"] = to_diver.normalized() if to_diver.length_squared() > 0.001 else Vector3.FORWARD
	state["anchor_pos"] = diver_pos
	state["target_pos"] = diver_pos
	var cd_scale := _phase_cooldown_scale(phase)
	match move_name:
		"tail_sweep":
			state["timer"] = 0.85 * cd_scale
		"hydro_breath":
			state["timer"] = 1.15 * cd_scale
		"vortex_pull":
			state["timer"] = 1.25 * cd_scale
		"lightning_dive":
			state["timer"] = 0.80 * cd_scale
		"storm_orbs":
			state["timer"] = 1.00 * cd_scale
		"sky_plunge":
			state["timer"] = 1.18 * cd_scale
		"tentacle_slam":
			state["timer"] = 0.82 * cd_scale
		"ink_shroud":
			state["timer"] = 0.95 * cd_scale
		"maelstrom_crush":
			state["timer"] = 1.22 * cd_scale
		"shell_ram":
			state["timer"] = 0.92 * cd_scale
		"seismic_stomp":
			state["timer"] = 1.15 * cd_scale
		"vent_eruption":
			state["timer"] = 1.12 * cd_scale
		_:
			state["timer"] = 0.95 * cd_scale

func tick_boss(
	boss_id: String,
	boss_node: Node3D,
	diver_pos: Vector3,
	floor_y: float,
	delta: float,
	clock: float,
	is_staggered: bool = false
) -> Dictionary:
	var cid := _canonical_id(boss_id)
	if not _states.has(cid):
		_states[cid] = _make_default_state()
	var state: Dictionary = _states[cid]
	var attacks: Array[Dictionary] = []
	var telegraphs: Array[Dictionary] = []
	var vfx_events: Array[Dictionary] = []
	var phase := _compute_phase(boss_node)
	var prev_phase := int(state.get("phase", 1))
	state["phase"] = phase
	var weakpoint_label := get_weakpoint_label(cid)
	var weakpoint_pos := get_weakpoint_world_pos(cid, boss_node)

	if not is_instance_valid(boss_node):
		return {
			"attacks": attacks,
			"telegraphs": telegraphs,
			"vfx_events": vfx_events,
			"warning": "",
			"phase": phase,
			"action": "idle",
			"weakpoint_pos": weakpoint_pos,
			"weakpoint_label": weakpoint_label,
			"timer": float(state.get("timer", 0.0))
		}

	boss_node.set_meta("enraged", phase >= 2)
	boss_node.set_meta("boss_phase", phase)

	if is_staggered:
		return {
			"attacks": attacks,
			"telegraphs": telegraphs,
			"vfx_events": vfx_events,
			"warning": "破防失衡！可爆发输出或蓄力静滞契约",
			"phase": phase,
			"action": "staggered",
			"weakpoint_pos": weakpoint_pos,
			"weakpoint_label": weakpoint_label,
			"timer": float(state.get("timer", 0.0))
		}

	if phase > prev_phase:
		var shift_color := Color(1.0, 0.42, 0.18) if phase == 2 else Color(0.28, 0.95, 0.88)
		vfx_events.append(_make_vfx("burst", boss_node.global_position, boss_node.global_position, 14.0, shift_color))

	state["timer"] = float(state["timer"]) - delta
	state["beam_hit_cd"] = maxf(0.0, float(state.get("beam_hit_cd", 0.0)) - delta)

	var warning := ""
	var action: String = str(state["action"])
	if action == "circle":
		warning = _tick_circle(cid, state, boss_node, diver_pos, floor_y, delta, clock, phase)
	else:
		match cid:
			"water_dragon":
				warning = _tick_water_dragon_move(state, boss_node, diver_pos, delta, phase, attacks, telegraphs, vfx_events)
			"flying_fish":
				warning = _tick_flying_fish_move(state, boss_node, diver_pos, delta, phase, attacks, telegraphs, vfx_events)
			"kraken":
				warning = _tick_kraken_move(state, boss_node, diver_pos, delta, phase, attacks, telegraphs, vfx_events)
			"colossus_turtle":
				warning = _tick_turtle_move(state, boss_node, diver_pos, floor_y, delta, phase, attacks, telegraphs, vfx_events)

	var min_clearance := 2.35 if (cid == "colossus_turtle" and str(state["action"]) == "seismic_stomp") else 3.0
	boss_node.position.y = clampf(boss_node.position.y, floor_y + min_clearance, -2.0)
	weakpoint_pos = get_weakpoint_world_pos(cid, boss_node)

	return {
		"attacks": attacks,
		"telegraphs": telegraphs,
		"vfx_events": vfx_events,
		"warning": warning,
		"phase": phase,
		"action": str(state["action"]),
		"weakpoint_pos": weakpoint_pos,
		"weakpoint_label": weakpoint_label,
		"timer": float(state["timer"])
	}

func _tick_circle(
	cid: String,
	state: Dictionary,
	boss_node: Node3D,
	diver_pos: Vector3,
	floor_y: float,
	delta: float,
	clock: float,
	phase: int
) -> String:
	var spd_scale := _phase_speed_scale(phase)
	var t := float(boss_node.get_meta("motion_clock", clock)) * (0.45 * spd_scale)
	var orbit_r := 18.0
	var height_offset := 2.2
	var base_speed := 6.0
	match cid:
		"flying_fish":
			orbit_r = 21.0
			height_offset = 5.5
			base_speed = 9.5
		"kraken":
			orbit_r = 16.0
			height_offset = 3.2
			base_speed = 5.6
		"colossus_turtle":
			orbit_r = 15.0
			height_offset = 0.0
			base_speed = 4.6
	var dest := diver_pos + Vector3(sin(t) * orbit_r, height_offset + sin(t * 1.4) * 2.5, cos(t) * orbit_r)
	if cid == "colossus_turtle":
		dest.y = floor_y + 3.6 + sin(t * 0.9) * 0.6
	boss_node.position = boss_node.position.move_toward(dest, delta * base_speed * spd_scale)
	_face_direction(boss_node, diver_pos - boss_node.global_position)

	if float(state["timer"]) <= 0.0:
		var next_move := _select_next_move(cid, state)
		_enter_move(cid, next_move, state, boss_node, diver_pos, phase)

	var title := str(BOSS_TITLES.get(cid, "深渊领主"))
	var wp := get_weakpoint_label(cid)
	if phase == 3:
		return "【%s · 三阶驯服窗口】弱点：%s · 蓄力静滞或破防可缔结契约！" % [title, wp]
	if phase == 2:
		return "【%s · 二阶狂暴】攻势强化 · 瞄准弱点【%s】破防" % [title, wp]
	return "【%s】盘旋戒备 · 弱点【%s】 · 留意金光弹反/红光闪避" % [title, wp]

func _tick_water_dragon_move(
	state: Dictionary,
	boss_node: Node3D,
	diver_pos: Vector3,
	delta: float,
	phase: int,
	attacks: Array[Dictionary],
	telegraphs: Array[Dictionary],
	vfx_events: Array[Dictionary]
) -> String:
	var action: String = str(state["action"])
	var substage: String = str(state["substage"])
	var dmg_scale := _phase_damage_scale(phase)
	var spd_scale := _phase_speed_scale(phase)
	var to_diver := diver_pos - boss_node.global_position

	if action == "tail_sweep":
		if substage == "windup":
			if not bool(state["telegraph_sent"]):
				state["telegraph_sent"] = true
				telegraphs.append(_make_telegraph(boss_node.global_position, 9.5, false, maxf(0.45, float(state["timer"]))))
			boss_node.position = boss_node.position.move_toward(diver_pos, delta * 11.0 * spd_scale)
			_face_direction(boss_node, to_diver)
			if float(state["timer"]) <= 0.0:
				state["substage"] = "active"
				state["timer"] = 0.55
				state["direction"] = to_diver.normalized() if to_diver.length_squared() > 0.001 else Vector3.FORWARD
				vfx_events.append(_make_vfx("burst", boss_node.global_position, diver_pos, 9.5, Color(0.95, 0.82, 0.28)))
			return "【深渊水龙】龙尾近身横扫蓄势！（金光 · 精准举盾可弹反）"
		else:
			var lunge_dir: Vector3 = state["direction"]
			boss_node.position += lunge_dir * delta * 14.0 * spd_scale
			_face_direction(boss_node, lunge_dir)
			if not bool(state["hit_sent"]) and to_diver.length() <= 9.5:
				state["hit_sent"] = true
				attacks.append(_make_attack("水龙逆鳞尾扫", 28.0 * dmg_scale, boss_node.global_position, boss_node, true))
			if float(state["timer"]) <= 0.0:
				_enter_circle("water_dragon", state, phase)
			return "【深渊水龙】龙尾横扫！"

	if action == "hydro_breath":
		if substage == "windup":
			if not bool(state["telegraph_sent"]):
				state["telegraph_sent"] = true
				state["anchor_pos"] = diver_pos
				telegraphs.append(_make_telegraph(boss_node.global_position, 14.0, true, maxf(0.55, float(state["timer"]))))
			var lock_dir := Vector3(to_diver.x, 0.0, to_diver.z)
			_face_direction(boss_node, lock_dir if lock_dir.length_squared() > 0.01 else to_diver)
			if float(state["timer"]) <= 0.0:
				state["substage"] = "active"
				state["timer"] = 1.25
				state["direction"] = lock_dir.normalized() if lock_dir.length_squared() > 0.01 else Vector3.FORWARD
				state["sweep_angle"] = -0.85 if phase == 1 else -1.05
			return "【深渊水龙】横向水龙吐息蓄能！（红光不可格挡 · 上浮/下潜闪避）"
		else:
			var sweep_span := 1.7 if phase == 1 else 2.1
			state["sweep_angle"] = float(state["sweep_angle"]) + (sweep_span / 1.25) * delta
			var base_dir: Vector3 = state["direction"]
			var beam_dir := base_dir.rotated(Vector3.UP, float(state["sweep_angle"])).normalized()
			var mouth_pos := boss_node.global_position + beam_dir * 4.2
			var anchor: Vector3 = state["anchor_pos"]
			mouth_pos.y = lerpf(boss_node.global_position.y, anchor.y, 0.55)
			var beam_end := mouth_pos + beam_dir * 26.0
			beam_end.y = anchor.y
			_face_direction(boss_node, beam_dir)
			state["pulse_accum"] = float(state["pulse_accum"]) + delta
			if float(state["pulse_accum"]) >= 0.18:
				state["pulse_accum"] = 0.0
				vfx_events.append(_make_vfx("beam", mouth_pos, beam_end, 1.8, Color(0.20, 0.85, 1.0)))
			var closest := Geometry3D.get_closest_point_to_segment(diver_pos, mouth_pos, beam_end)
			var vertical_gap := absf(diver_pos.y - closest.y)
			if diver_pos.distance_to(closest) <= 2.9 and vertical_gap <= 2.5 and float(state["beam_hit_cd"]) <= 0.0:
				state["beam_hit_cd"] = 0.5
				attacks.append(_make_attack("深渊水龙吐息", 24.0 * dmg_scale, closest, boss_node, false, "shock", 22.0))
			if float(state["timer"]) <= 0.0:
				_enter_circle("water_dragon", state, phase)
			return "【深渊水龙】高压水龙吐息横扫中！上浮或下潜避开射线"

	if action == "vortex_pull":
		var vortex_radius := 21.0 if phase >= 2 else 15.5
		if substage == "windup":
			if not bool(state["telegraph_sent"]):
				state["telegraph_sent"] = true
				telegraphs.append(_make_telegraph(boss_node.global_position, vortex_radius, true, maxf(0.6, float(state["timer"]))))
				vfx_events.append(_make_vfx("vortex", boss_node.global_position, diver_pos, vortex_radius, Color(0.18, 0.62, 1.0)))
			_face_direction(boss_node, to_diver)
			if float(state["timer"]) <= 0.0:
				state["substage"] = "active"
				state["timer"] = 0.42
			return "【深渊水龙】盘旋漩涡吸力聚集！（%s · 冲刺脱离爆裂圈）" % ("二阶强化范围" if phase >= 2 else "延迟爆裂")
		else:
			if not bool(state["hit_sent"]):
				state["hit_sent"] = true
				vfx_events.append(_make_vfx("burst", boss_node.global_position, boss_node.global_position, vortex_radius, Color(0.25, 0.78, 1.0)))
				if to_diver.length() <= vortex_radius:
					attacks.append(_make_attack("深渊漩涡爆裂", (34.0 if phase >= 2 else 26.0) * dmg_scale, boss_node.global_position, boss_node, false, "slow", 30.0))
			if float(state["timer"]) <= 0.0:
				_enter_circle("water_dragon", state, phase)
			return "【深渊水龙】漩涡爆裂！"

	_enter_circle("water_dragon", state, phase)
	return ""

func _tick_flying_fish_move(
	state: Dictionary,
	boss_node: Node3D,
	diver_pos: Vector3,
	delta: float,
	phase: int,
	attacks: Array[Dictionary],
	telegraphs: Array[Dictionary],
	vfx_events: Array[Dictionary]
) -> String:
	var action: String = str(state["action"])
	var substage: String = str(state["substage"])
	var dmg_scale := _phase_damage_scale(phase)
	var spd_scale := _phase_speed_scale(phase)
	var to_diver := diver_pos - boss_node.global_position

	if action == "lightning_dive":
		if substage == "windup":
			if not bool(state["telegraph_sent"]):
				state["telegraph_sent"] = true
				telegraphs.append(_make_telegraph(boss_node.global_position, 8.5, false, maxf(0.45, float(state["timer"]))))
			var pull_back := boss_node.global_position - to_diver.normalized() * 3.0 if to_diver.length_squared() > 0.01 else boss_node.global_position
			boss_node.position = boss_node.position.move_toward(pull_back + Vector3(0.0, 2.0, 0.0), delta * 6.0)
			_face_direction(boss_node, to_diver)
			if float(state["timer"]) <= 0.0:
				state["substage"] = "active"
				state["timer"] = 0.95
				state["direction"] = to_diver.normalized() if to_diver.length_squared() > 0.001 else Vector3.FORWARD
				vfx_events.append(_make_vfx("beam", boss_node.global_position, diver_pos, 1.2, Color(0.35, 0.92, 1.0)))
			return "【风暴飞鱼】高速雷光俯冲锁定！（金光 · 精准弹反可击落失衡）"
		else:
			var dive_dir: Vector3 = state["direction"]
			boss_node.position += dive_dir * delta * 26.0 * spd_scale
			_face_direction(boss_node, dive_dir)
			if not bool(state["hit_sent"]) and to_diver.length() <= 7.2:
				state["hit_sent"] = true
				vfx_events.append(_make_vfx("burst", boss_node.global_position, diver_pos, 7.0, Color(0.35, 0.95, 1.0)))
				attacks.append(_make_attack("空棘雷光俯冲", 26.0 * dmg_scale, boss_node.global_position, boss_node, true, "shock", 35.0))
			if float(state["timer"]) <= 0.0:
				_enter_circle("flying_fish", state, phase)
			return "【风暴飞鱼】雷光折返俯冲！"

	if action == "storm_orbs":
		var orb_radius := 18.0 if phase >= 2 else 14.5
		if substage == "windup":
			if not bool(state["telegraph_sent"]):
				state["telegraph_sent"] = true
				telegraphs.append(_make_telegraph(boss_node.global_position, orb_radius, true, maxf(0.5, float(state["timer"]))))
			_face_direction(boss_node, to_diver)
			if float(state["timer"]) <= 0.0:
				state["substage"] = "active"
				state["timer"] = 0.95
				state["pulse_accum"] = 0.45
			return "【风暴飞鱼】雷暴电球蓄电！脱离放电水域"
		else:
			state["pulse_accum"] = float(state["pulse_accum"]) + delta
			var max_pulses := 3 if phase >= 2 else 2
			if float(state["pulse_accum"]) >= 0.42 and int(state["hits_done"]) < max_pulses:
				state["pulse_accum"] = 0.0
				state["hits_done"] = int(state["hits_done"]) + 1
				vfx_events.append(_make_vfx("burst", boss_node.global_position, diver_pos, orb_radius, Color(0.30, 0.86, 1.0)))
				if to_diver.length() <= orb_radius:
					attacks.append(_make_attack("雷暴电球放电", 20.0 * dmg_scale, boss_node.global_position, boss_node, false, "shock", 40.0))
			_face_direction(boss_node, to_diver)
			if float(state["timer"]) <= 0.0:
				_enter_circle("flying_fish", state, phase)
			return "【风暴飞鱼】雷暴电球连锁放电中！"

	if action == "sky_plunge":
		var plunge_radius := 15.5 if phase >= 2 else 12.5
		if substage == "windup":
			if not bool(state["telegraph_sent"]):
				state["telegraph_sent"] = true
				state["anchor_pos"] = diver_pos
				telegraphs.append(_make_telegraph(diver_pos, plunge_radius, true, maxf(0.6, float(state["timer"]))))
			var high_point := Vector3(diver_pos.x, minf(-2.5, diver_pos.y + 14.0), diver_pos.z)
			boss_node.position = boss_node.position.move_toward(high_point, delta * 18.0 * spd_scale)
			_face_direction(boss_node, diver_pos - boss_node.global_position)
			if float(state["timer"]) <= 0.0:
				state["substage"] = "active"
				state["timer"] = 0.72
				state["anchor_pos"] = diver_pos
			return "【风暴飞鱼】跃升急坠轰击！（红光不可格挡 · 向侧面闪避）"
		else:
			var impact_pos: Vector3 = state["anchor_pos"]
			boss_node.position = boss_node.position.move_toward(impact_pos, delta * 34.0 * spd_scale)
			_face_direction(boss_node, impact_pos - boss_node.global_position)
			if not bool(state["hit_sent"]) and (boss_node.position.distance_to(impact_pos) <= 2.8 or float(state["timer"]) <= 0.08):
				state["hit_sent"] = true
				vfx_events.append(_make_vfx("burst", impact_pos, impact_pos, plunge_radius, Color(1.0, 0.36, 0.18)))
				if diver_pos.distance_to(impact_pos) <= plunge_radius:
					attacks.append(_make_attack("高空雷坠轰击", 34.0 * dmg_scale, impact_pos, boss_node, false, "shock", 45.0))
			if float(state["timer"]) <= 0.0:
				_enter_circle("flying_fish", state, phase)
			return "【风暴飞鱼】高空急坠轰击！"

	_enter_circle("flying_fish", state, phase)
	return ""

func _tick_kraken_move(
	state: Dictionary,
	boss_node: Node3D,
	diver_pos: Vector3,
	delta: float,
	phase: int,
	attacks: Array[Dictionary],
	telegraphs: Array[Dictionary],
	vfx_events: Array[Dictionary]
) -> String:
	var action: String = str(state["action"])
	var substage: String = str(state["substage"])
	var dmg_scale := _phase_damage_scale(phase)
	var spd_scale := _phase_speed_scale(phase)
	var to_diver := diver_pos - boss_node.global_position

	if action == "tentacle_slam":
		if substage == "windup":
			if not bool(state["telegraph_sent"]):
				state["telegraph_sent"] = true
				telegraphs.append(_make_telegraph(boss_node.global_position, 10.5, false, maxf(0.45, float(state["timer"]))))
			boss_node.position = boss_node.position.move_toward(diver_pos, delta * 10.5 * spd_scale)
			_face_direction(boss_node, to_diver)
			if float(state["timer"]) <= 0.0:
				state["substage"] = "active"
				state["timer"] = 1.32 if phase >= 2 else 0.96
				state["pulse_accum"] = 0.45
			return "【深渊巨章】连环触手拍击蓄势！（金光 · 精准举盾可弹反）"
		else:
			boss_node.position = boss_node.position.move_toward(diver_pos, delta * 6.5 * spd_scale)
			_face_direction(boss_node, to_diver)
			state["pulse_accum"] = float(state["pulse_accum"]) + delta
			var slam_cap := 3 if phase >= 2 else 2
			if float(state["pulse_accum"]) >= 0.44 and int(state["hits_done"]) < slam_cap:
				state["pulse_accum"] = 0.0
				state["hits_done"] = int(state["hits_done"]) + 1
				vfx_events.append(_make_vfx("burst", boss_node.global_position, diver_pos, 10.5, Color(0.86, 0.36, 1.0)))
				if to_diver.length() <= 10.5:
					attacks.append(_make_attack("克拉肯连环触手拍击", 24.0 * dmg_scale, boss_node.global_position, boss_node, true))
			if float(state["timer"]) <= 0.0:
				_enter_circle("kraken", state, phase)
			return "【深渊巨章】触手连环重拍！"

	if action == "ink_shroud":
		var ink_radius := 21.0 if phase >= 2 else 17.0
		if substage == "windup":
			if not bool(state["telegraph_sent"]):
				state["telegraph_sent"] = true
				telegraphs.append(_make_telegraph(boss_node.global_position, ink_radius, true, maxf(0.5, float(state["timer"]))))
			_face_direction(boss_node, to_diver)
			if float(state["timer"]) <= 0.0:
				state["substage"] = "active"
				state["timer"] = 0.50
			return "【深渊巨章】深海墨雾积蓄！声呐可驱散视野致盲"
		else:
			if not bool(state["hit_sent"]):
				state["hit_sent"] = true
				vfx_events.append(_make_vfx("ink", boss_node.global_position, diver_pos, ink_radius, Color(0.14, 0.05, 0.24)))
				if to_diver.length() <= ink_radius:
					attacks.append(_make_attack("深海致盲墨雾", 14.0 * dmg_scale, boss_node.global_position, boss_node, false, "ink_blind", 5.0))
			if float(state["timer"]) <= 0.0:
				_enter_circle("kraken", state, phase)
			return "【深渊巨章】深海墨雾弥漫！按声呐驱散致盲与减速"

	if action == "maelstrom_crush":
		var crush_radius := 19.5 if phase >= 2 else 15.5
		if substage == "windup":
			if not bool(state["telegraph_sent"]):
				state["telegraph_sent"] = true
				telegraphs.append(_make_telegraph(boss_node.global_position, crush_radius, true, maxf(0.6, float(state["timer"]))))
				vfx_events.append(_make_vfx("vortex", boss_node.global_position, diver_pos, crush_radius, Color(0.72, 0.24, 0.92)))
			_face_direction(boss_node, to_diver)
			if float(state["timer"]) <= 0.0:
				state["substage"] = "active"
				state["timer"] = 0.48
			return "【深渊巨章】漩涡绞杀震荡！（红光不可格挡 · 迅速抽身闪避）"
		else:
			if not bool(state["hit_sent"]):
				state["hit_sent"] = true
				vfx_events.append(_make_vfx("burst", boss_node.global_position, boss_node.global_position, crush_radius, Color(0.92, 0.22, 0.45)))
				if to_diver.length() <= crush_radius:
					attacks.append(_make_attack("克拉肯漩涡绞杀", 34.0 * dmg_scale, boss_node.global_position, boss_node, false, "bleed", 32.0))
			if float(state["timer"]) <= 0.0:
				_enter_circle("kraken", state, phase)
			return "【深渊巨章】漩涡绞杀震荡爆发！"

	_enter_circle("kraken", state, phase)
	return ""

func _tick_turtle_move(
	state: Dictionary,
	boss_node: Node3D,
	diver_pos: Vector3,
	floor_y: float,
	delta: float,
	phase: int,
	attacks: Array[Dictionary],
	telegraphs: Array[Dictionary],
	vfx_events: Array[Dictionary]
) -> String:
	var action: String = str(state["action"])
	var substage: String = str(state["substage"])
	var dmg_scale := _phase_damage_scale(phase)
	var spd_scale := _phase_speed_scale(phase)
	var to_diver := diver_pos - boss_node.global_position

	if action == "shell_ram":
		if substage == "windup":
			if not bool(state["telegraph_sent"]):
				state["telegraph_sent"] = true
				telegraphs.append(_make_telegraph(boss_node.global_position, 9.5, false, maxf(0.5, float(state["timer"]))))
			_face_direction(boss_node, to_diver)
			if float(state["timer"]) <= 0.0:
				state["substage"] = "active"
				state["timer"] = 1.2
				state["direction"] = to_diver.normalized() if to_diver.length_squared() > 0.001 else Vector3.FORWARD
			return "【远古灵龟】玄甲冲撞蓄力！（金光 · 精准弹反可破甲失衡）"
		else:
			var ram_dir: Vector3 = state["direction"]
			boss_node.position += ram_dir * delta * 21.0 * spd_scale
			_face_direction(boss_node, ram_dir)
			if not bool(state["hit_sent"]) and to_diver.length() <= 8.2:
				state["hit_sent"] = true
				vfx_events.append(_make_vfx("burst", boss_node.global_position, diver_pos, 8.5, Color(0.28, 0.95, 0.65)))
				attacks.append(_make_attack("巨岩玄甲冲撞", 32.0 * dmg_scale, boss_node.global_position, boss_node, true))
			if float(state["timer"]) <= 0.0:
				_enter_circle("colossus_turtle", state, phase)
			return "【远古灵龟】玄甲冲撞！"

	if action == "seismic_stomp":
		var stomp_radius := 23.0 if phase >= 2 else 19.0
		if substage == "windup":
			if not bool(state["telegraph_sent"]):
				state["telegraph_sent"] = true
				var ground_pos := Vector3(boss_node.global_position.x, floor_y + 0.6, boss_node.global_position.z)
				telegraphs.append(_make_telegraph(ground_pos, stomp_radius, true, maxf(0.55, float(state["timer"]))))
			boss_node.position.y = move_toward(boss_node.position.y, minf(-2.5, floor_y + 7.5), delta * 7.5)
			_face_direction(boss_node, to_diver)
			if float(state["timer"]) <= 0.0:
				state["substage"] = "active"
				state["timer"] = 0.55
			return "【远古灵龟】海床岩刺震荡蓄势！立即上浮脱离海床避开"
		else:
			boss_node.position.y = move_toward(boss_node.position.y, floor_y + 2.4, delta * 24.0)
			if not bool(state["hit_sent"]) and (boss_node.position.y <= floor_y + 3.0 or float(state["timer"]) <= 0.12):
				state["hit_sent"] = true
				var ground_center := Vector3(boss_node.global_position.x, floor_y + 0.6, boss_node.global_position.z)
				vfx_events.append(_make_vfx("burst", ground_center, ground_center, stomp_radius, Color(0.95, 0.58, 0.20)))
				var horiz_dist := Vector2(diver_pos.x - boss_node.global_position.x, diver_pos.z - boss_node.global_position.z).length()
				var diver_height_above_floor := diver_pos.y - floor_y
				if horiz_dist <= stomp_radius and diver_height_above_floor < 5.5:
					attacks.append(_make_attack("海床环形岩刺波", 34.0 * dmg_scale, ground_center, boss_node, false, "crush", 35.0))
			if float(state["timer"]) <= 0.0:
				_enter_circle("colossus_turtle", state, phase)
			return "【远古灵龟】环形岩刺波扩散！保持上浮高度"

	if action == "vent_eruption":
		var vent_radius := 17.5 if phase >= 2 else 14.0
		if substage == "windup":
			if not bool(state["telegraph_sent"]):
				state["telegraph_sent"] = true
				telegraphs.append(_make_telegraph(boss_node.global_position + Vector3(0.0, 2.0, 0.0), vent_radius, true, maxf(0.55, float(state["timer"]))))
			_face_direction(boss_node, to_diver)
			if float(state["timer"]) <= 0.0:
				state["substage"] = "active"
				state["timer"] = 0.85
			return "【远古灵龟】背甲热液蒸汽喷流蓄热！（红光 · 远离上方与四周）"
		else:
			var dorsal_pos := boss_node.global_position + Vector3(0.0, 2.4, 0.0)
			var plume_top := dorsal_pos + Vector3(0.0, 14.0, 0.0)
			state["pulse_accum"] = float(state["pulse_accum"]) + delta
			if float(state["pulse_accum"]) >= 0.22:
				state["pulse_accum"] = 0.0
				vfx_events.append(_make_vfx("beam", dorsal_pos, plume_top, 2.4, Color(1.0, 0.34, 0.14)))
			if not bool(state["hit_sent"]):
				state["hit_sent"] = true
				vfx_events.append(_make_vfx("burst", dorsal_pos, plume_top, vent_radius, Color(1.0, 0.38, 0.16)))
				var horiz_d := Vector2(diver_pos.x - boss_node.global_position.x, diver_pos.z - boss_node.global_position.z).length()
				var in_column := horiz_d <= 8.0 and diver_pos.y >= boss_node.global_position.y - 1.0 and diver_pos.y <= boss_node.global_position.y + 16.0
				if to_diver.length() <= vent_radius or in_column:
					attacks.append(_make_attack("背甲热液蒸汽喷流", 30.0 * dmg_scale, dorsal_pos, boss_node, false, "burn", 40.0))
			if float(state["timer"]) <= 0.0:
				_enter_circle("colossus_turtle", state, phase)
			return "【远古灵龟】热液蒸汽喷涌！"

	_enter_circle("colossus_turtle", state, phase)
	return ""
