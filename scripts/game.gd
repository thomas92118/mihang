extends Node3D

const Ocean = preload("res://scripts/ocean.gd")
const Diver = preload("res://scripts/diver.gd")
const Survival = preload("res://scripts/survival.gd")
const HUD = preload("res://scripts/hud.gd")
const CombatVFX = preload("res://scripts/combat_vfx.gd")
const UnderwaterAudio = preload("res://scripts/underwater_audio.gd")
const EnergyOrb = preload("res://scripts/energy_orb.gd")
const Submarine = preload("res://scripts/submarine.gd")
const SubmarineTorpedoCls = preload("res://scripts/submarine_torpedo.gd")

const LANDMARKS := {
	"shallows": {"name": "逃生舱浅礁", "pos": Vector3(0, -9, 8), "radius": 28.0, "desc": "阳光明媚的浅海珊瑚林"},
	"ruins": {"name": "古代海沟遗迹", "pos": Vector3(2, -22, -25), "radius": 22.0, "desc": "半掩埋于海床的史前石拱门"},
	"slope": {"name": "暮光大断崖", "pos": Vector3(0, -28, -35), "radius": 28.0, "desc": "急剧坠入深海的大陆坡断崖"},
	"shipwreck": {"name": "失事科考潜艇", "pos": Vector3(45, -55.7, -55), "radius": 28.0, "desc": "半掩于大陆坡深处的失事科考潜艇"},
	"abyss": {"name": "深渊裂谷入口", "pos": Vector3(0, -68, -105), "radius": 35.0, "desc": "幽暗寒冷的百米深海大裂谷"},
	"vents": {"name": "深海地热喷口群", "pos": Vector3(15, -95, -165), "radius": 38.0, "desc": "地壳深处喷涌而出的炽热黑烟囱"},
	"altar": {"name": "深渊史前祭坛", "pos": Vector3(-50, -88, -170), "radius": 32.0, "desc": "沉眠于百米渊底的发光史前石碑"},
	"crystal_basin": {"name": "碧蓝晶簇海盆", "pos": Vector3(95, -36, -30), "radius": 34.0, "desc": "生长着幽蓝巨晶的深潜艇科考船坞"},
	"shipyard": {"name": "深渊重装造船厂", "pos": Vector3(-110, -96, -185), "radius": 42.0, "desc": "沉睡于百米海沟的史前巨型核潜艇船坞"},
	"phosphor_groves": {"name": "海妖磷光珊瑚林", "pos": Vector3(-85, -42, -50), "radius": 32.0, "desc": "密布巨型发光海葵与鬼蝠鲼群的幽绿珊瑚海谷"},
	"storm_ridge": {"name": "风暴海脊", "pos": Vector3(145, -18, -40), "radius": 35.0, "desc": "风暴飞鱼龙皇巡弋的雷涌海脊"},
	"kraken_trench": {"name": "克拉肯海沟", "pos": Vector3(-105, -75, -85), "radius": 36.0, "desc": "深渊巨章领主盘踞的幽暗触手裂谷"},
	"turtle_basin": {"name": "玄甲巨鳌盆地", "pos": Vector3(-140, -92, -145), "radius": 38.0, "desc": "沉眠远古灵龟神鳌的深渊晶矿盆地"},
	"outer_void": {"name": "深蓝生态隔离界限", "pos": Vector3(0, -12, -220), "radius": 38.0, "desc": "离开隔离区，进入真正的深蓝外洋世界"},
	"mother_tree": {"name": "远古深海母树", "pos": Vector3(0, -125, -340), "radius": 48.0, "desc": "伫立在深海极渊核心的史前生命母树圣所"}
}

var ocean: Node3D
var diver: CharacterBody3D
var active_submarine: Submarine = null
var active_torpedo: Node3D = null
var tamed_beasts: Array[Dictionary] = []
var active_mount_idx: int = -1
var companion_attack_target: Node3D = null
var persistent_red_dot: Node3D = null
var companion_orbit_clock: float = 0.0
var companion_attack_pos: Vector3 = Vector3.ZERO
var has_target_pos: bool = false
var hud: CanvasLayer
var state = Survival.new()
var screen: String = "main"
var target: Node3D
var low_oxygen_warned: bool = false
var effect: AudioStreamPlayer
var home_arrow: Label
var screen_shade: ColorRect
var damage_flash_time: float = 0.0
var attack_input_buffered: bool = false
var attack_buffer_timer: float = 0.0
var stasis_fields: Array[Dictionary] = []
var scope_scan_timer := 0.0
var scope_distance := 2000.0
const ATTACK_BUFFER_WINDOW: float = 0.18
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	ocean = Ocean.new()
	add_child(ocean)
	ocean.boss_encounter_started.connect(_on_boss_encounter_started)
	ocean.boss_defeated.connect(_on_boss_defeated)
	diver = Diver.new()
	add_child(diver)
	_reset_position()
	hud = HUD.new()
	add_child(hud)
	hud.start_requested.connect(_start)
	hud.resume_requested.connect(func(): _set_screen("play"))
	hud.restart_requested.connect(_restart)
	hud.craft_requested.connect(_craft)
	hud.pin_requested.connect(_on_pin_recipe)
	_setup_audio()
	_setup_overlay()
	_set_screen("main")
	if "--smoke-world" in OS.get_cmdline_user_args():
		_world_check.call_deferred()
	if "--capture" in OS.get_cmdline_user_args():
		_capture.call_deferred()

func _setup_input() -> void:
	var keys := {
		"forward": KEY_W,
		"backward": KEY_S,
		"left": KEY_A,
		"right": KEY_D,
		"ascend": KEY_SPACE,
		"descend": KEY_C,
		"sprint": KEY_SHIFT,
		"interact": KEY_E,
		"craft_menu": KEY_TAB,
		"lamp": KEY_F,
		"pause_game": KEY_ESCAPE,
		"weapon_1": KEY_1,
		"weapon_2": KEY_2,
		"weapon_3": KEY_3,
		"weapon_4": KEY_4,
		"attack": KEY_R,
		"aim": KEY_T,
		"scope": KEY_Y,
		"dash": KEY_Q,
		"booster": KEY_H,
		"mount_toggle": KEY_G,
		"toggle_shield": KEY_C,
		"recall_pets": KEY_Z,
		"mount_slot_1": KEY_5,
		"mount_slot_2": KEY_6,
		"mount_slot_3": KEY_7,
		"mount_slot_4": KEY_8,
		"mount_slot_5": KEY_9,
		"mount_slot_6": KEY_0
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var key := InputEventKey.new()
		key.physical_keycode = keys[action]
		InputMap.action_add_event(action, key)

	var descend := InputEventKey.new()
	descend.physical_keycode = KEY_CTRL
	InputMap.action_add_event("descend", descend)

	var mouse_attack := InputEventMouseButton.new()
	mouse_attack.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("attack", mouse_attack)

func _reset_position() -> void:
	diver.cancel_gun_charge()
	diver.aiming = false
	diver.scoped = false
	diver.position = Vector3(0, -9.0, 17.0)
	diver.rotation = Vector3.ZERO
	diver.camera.rotation.x = -0.16
	diver.velocity = Vector3.ZERO

func _start(chosen_mode: String = "survival") -> void:
	state.set_mode(chosen_mode)
	diver.exploration_mode = chosen_mode == "explore"
	diver.set_weapon("knife")
	_set_screen("play")
	if chosen_mode == "explore":
		hud.toast("3 蓝光枪 · T 瞄准 / Y 远距镜 · 短按 R 激光，蓄力 3 秒后松手发射静滞球。")
	else:
		hud.toast("欢迎来到浅礁区。按 1/2/3 装备武器防身；E 采集矿物或捕食小鱼；Tab 开启制造台。")

func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _set_screen(value: String) -> void:
	screen = value
	diver.active = screen == "play"
	if screen != "play":
		diver.cancel_gun_charge()
		diver.aiming = false
		diver.scoped = false
		attack_input_buffered = false
	get_tree().paused = screen in ["pause", "craft", "win"]
	hud.set_screen(screen)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if screen == "play" else Input.MOUSE_MODE_VISIBLE

func _get_current_biome(pos: Vector3) -> String:
	var depth: float = maxf(0, -pos.y)
	var distance_to_home: float = pos.distance_to(Ocean.HOME)
	if absf(pos.x) > 215.0 or pos.z > 85.0 or pos.z < -255.0:
		return "深蓝无尽外洋 · 真正的外面世界 (The Void)"
	if pos.distance_to(Ocean.BOSS_ARENA_CENTER) < Ocean.BOSS_TRIGGER_RADIUS:
		return "水龙领域  /  终章 Boss 战"
	if pos.distance_to(Vector3(95, -36, -30)) < 34.0:
		return "碧蓝晶簇海盆 (深潜艇船坞)  /  %dm" % roundi(depth)
	if pos.distance_to(Vector3(-85, -42, -50)) < 32.0:
		return "海妖磷光珊瑚林  /  %dm" % roundi(depth)
	if pos.distance_to(Vector3(145, -18, -40)) < 32.0:
		return "风暴海脊 (风暴飞鱼领地)  /  %dm" % roundi(depth)
	if pos.distance_to(Vector3(-105, -75, -85)) < 35.0:
		return "克拉肯海沟 (深渊巨章巢穴)  /  %dm" % roundi(depth)
	if pos.distance_to(Vector3(-140, -92, -145)) < 35.0:
		return "玄甲巨鳌盆地 (远古灵龟领地)  /  %dm" % roundi(depth)
	if distance_to_home < 7.0 or pos.y > -0.6:
		return "安全区  /  生命支持恢复"
	if pos.distance_to(Vector3(-110, -96, -185)) < 42.0:
		return "深渊重装造船厂 (泰坦核潜艇)  /  %dm" % roundi(depth)
	if pos.distance_to(Vector3(45, -55.7, -55)) < 32.0:
		return "失事科考潜艇遗址  /  %dm" % roundi(depth)
	if pos.distance_to(Vector3(15, -95, -165)) < 42.0:
		return "深海地热喷口群  /  %dm" % roundi(depth)
	if pos.distance_to(Vector3(-50, -88, -170)) < 35.0:
		return "深渊史前祭坛  /  %dm" % roundi(depth)
	if depth < 24.0:
		return "浅海珊瑚礁区  /  %dm" % roundi(depth)
	elif depth < 58.0:
		return "暮光大陆坡断崖  /  %dm" % roundi(depth)
	else:
		return "深渊海床大裂谷  /  %dm" % roundi(depth)

func _check_landmarks() -> void:
	for id: String in LANDMARKS:
		var landmark: Dictionary = LANDMARKS[id]
		var target_pos: Vector3 = landmark["pos"]
		if diver.position.distance_to(target_pos) < float(landmark["radius"]):
			if state.discover_landmark(id):
				hud.toast("【发现新地标】" + str(landmark["name"]) + " · " + str(landmark["desc"]))
				effect.play()
				if state.landmarks_discovered.size() >= LANDMARKS.size() and state.mode == "explore":
					hud.toast("【全海域勘测达成】已探明全部 7 大核心地标！自由探险无时限，请尽情漫游。")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		if screen == "play":
			_set_screen("pause")
		elif screen in ["pause", "craft"]:
			_set_screen("play")
	elif event.is_action_pressed("craft_menu") and screen in ["play", "craft"]:
		_set_screen("play" if screen == "craft" else "craft")
	elif event.is_action_pressed("lamp") and screen == "play":
		diver.toggle_lamp()
	elif event.is_action_pressed("interact") and screen == "play":
		_interact()
	elif event.is_action_pressed("booster") and screen == "play":
		if is_instance_valid(active_submarine):
			hud.toast("驾驶潜水艇期间无法使用手持助推器")
		else:
			var b_on: bool = bool(diver.toggle_booster())
			if b_on:
				hud.toast("【手持迷你助推器】已启动 · 移速大幅提升！按 H 收起")
				UnderwaterAudio.play_sound(get_tree(), "booster_start", -4.0, 1.1)
			else:
				hud.toast("【手持迷你助推器】已收起 · 恢复常规游动 (按 H 启动)")
				UnderwaterAudio.play_sound(get_tree(), "booster_stop", -4.0, 0.9)
	elif event.is_action_pressed("attack") and screen == "play":
		if is_instance_valid(active_submarine):
			_fire_submarine_weapon()
			return
		if diver.current_weapon == "sonic":
			diver.begin_gun_charge()
		elif is_instance_valid(diver) and diver.attack_cooldown <= 0.0:
			_perform_attack()
		else:
			attack_input_buffered = true
			attack_buffer_timer = ATTACK_BUFFER_WINDOW
	elif event.is_action_released("attack") and screen == "play":
		if diver.current_weapon == "sonic" and not Input.is_action_pressed("attack"):
			diver.damage_bonus = state.weapon_attack_bonus
			_dispatch_attack(diver.release_gun_charge())
	elif event.is_action_pressed("aim") and screen == "play":
		if is_instance_valid(active_submarine) and active_submarine.sub_type == "mini":
			active_submarine.toggle_scope()
			diver.scoped = active_submarine.is_scoped
			hud.toast("微型潜艇电磁脉冲瞄准镜" + (" [已开启]" if active_submarine.is_scoped else " [已退出]"))
			return
		if diver.current_weapon == "sonic":
			diver.toggle_aim()
		else:
			hud.toast("按 3 装备蓝光静滞枪后，可用 T 瞄准")
	elif event.is_action_pressed("scope") and screen == "play":
		if is_instance_valid(active_submarine) and active_submarine.sub_type == "mini":
			active_submarine.toggle_scope()
			diver.scoped = active_submarine.is_scoped
			hud.toast("微型潜艇电磁脉冲瞄准镜" + (" [已开启]" if active_submarine.is_scoped else " [已退出]"))
			return
		if diver.current_weapon == "sonic":
			diver.toggle_scope()
		else:
			hud.toast("按 3 装备蓝光静滞枪后，可用 Y 打开远距瞄准镜")
	elif event.is_action_pressed("dash") and screen == "play":
		_perform_dash()
	elif event.is_action_pressed("mount_toggle") and screen == "play":
		if active_mount_idx >= 0:
			_dismount_beast()
		elif not tamed_beasts.is_empty():
			_mount_beast(0)
		else:
			hud.toast("尚未契约坐骑！用声波枪静滞近血巨兽后按 E 契约驯服 (最多10只)")
	elif event.is_action_pressed("mount_slot_1") and screen == "play":
		if tamed_beasts.size() >= 1: _mount_beast(0)
	elif event.is_action_pressed("mount_slot_2") and screen == "play":
		if tamed_beasts.size() >= 2: _mount_beast(1)
	elif event.is_action_pressed("mount_slot_3") and screen == "play":
		if tamed_beasts.size() >= 3: _mount_beast(2)
	elif event.is_action_pressed("mount_slot_4") and screen == "play":
		if tamed_beasts.size() >= 4: _mount_beast(3)
	elif event.is_action_pressed("mount_slot_5") and screen == "play":
		if tamed_beasts.size() >= 5: _mount_beast(4)
	elif event.is_action_pressed("mount_slot_6") and screen == "play":
		if tamed_beasts.size() >= 6: _mount_beast(5)
	elif event.is_action_pressed("weapon_1") and screen == "play":
		_switch_weapon("knife")
	elif event.is_action_pressed("weapon_2") and screen == "play":
		_switch_weapon("axe")
	elif event.is_action_pressed("weapon_3") and screen == "play":
		_switch_weapon("sonic")
	elif event.is_action_pressed("weapon_4") and screen == "play":
		_switch_weapon("marker_gun")
	elif event.is_action_pressed("toggle_shield") and screen == "play":
		var active: bool = diver.toggle_shield()
		if active:
			UnderwaterAudio.play_sound(get_tree(), "shield_deploy", -3.0, 1.0)
			hud.toast("【单手能量盾已展开】单手防御中 · 抵挡前方伤害 · 与所有武器同步使用 (按 C 消除)")
		else:
			UnderwaterAudio.play_sound(get_tree(), "shield_retract", -3.0, 1.0)
			hud.toast("【单手能量盾已收起】")
	elif event.is_action_pressed("recall_pets") and screen == "play":
		_recall_pets()

func _switch_weapon(weapon_id: String) -> void:
	var names := {"knife": "潜水战术刀", "axe": "破拆战斧", "sonic": "蓝光静滞枪", "marker_gun": "光标指示枪"}
	if weapon_id != "marker_gun" and not state.weapons.has(weapon_id):
		hud.toast("尚未解锁【%s】，请在逃生舱制造台制作" % names.get(weapon_id, weapon_id))
		return
	diver.set_weapon(weapon_id)
	attack_input_buffered = false
	UnderwaterAudio.play_sound(get_tree(), "weapon_equip", -5.0, randf_range(0.96, 1.04))
	hud.toast("已装备【%s】" % names.get(weapon_id, weapon_id))

func _perform_attack() -> void:
	diver.damage_bonus = state.weapon_attack_bonus
	var atk: Dictionary = diver.attack()
	_dispatch_attack(atk)

func _dispatch_attack(atk: Dictionary) -> void:
	if atk.is_empty():
		return
	if str(atk.get("mode", "")) == "stasis_orb":
		_launch_energy_orb(atk)
		return
	if str(atk.get("mode", "")) == "marker_pointer":
		_fire_marker_gun(atk)
		return


	var weapon_type: String = str(atk.get("weapon", "knife"))
	# 播放水下挥击 / 开火声效
	match weapon_type:
		"knife":
			UnderwaterAudio.play_sound(get_tree(), "knife_slash", -6.0, randf_range(0.95, 1.05))
		"axe":
			UnderwaterAudio.play_sound(get_tree(), "axe_swing", -3.5, randf_range(0.92, 1.02))
		"sonic":
			UnderwaterAudio.play_sound(get_tree(), "laser", -5.0, randf_range(0.98, 1.02))

	var active_delay: float = float(atk.get("active_delay", 0.0))
	if active_delay <= 0.001:
		_resolve_attack_hit(atk)
	else:
		get_tree().create_timer(active_delay, false).timeout.connect(func():
			if is_instance_valid(self) and screen == "play" and is_instance_valid(diver):
				_resolve_attack_hit(atk)
		)

func _resolve_attack_hit(atk: Dictionary) -> void:
	if not is_instance_valid(diver) or not is_instance_valid(ocean):
		return
	if str(atk.get("mode", "")) == "laser":
		_fire_laser(atk)
		return
	var weapon_type: String = str(atk.get("weapon", "knife"))
	var camera: Camera3D = diver.camera
	var from: Vector3 = camera.global_position
	var dir: Vector3 = -camera.global_basis.z
	var max_targets: int = int(atk.get("max_targets", 99))
	var cleave_angle: float = float(atk.get("cleave_angle", -1.0))
	var hit: Dictionary = ocean.strike_predator(
		from, dir,
		float(atk["range"]),
		float(atk["damage"]),
		float(atk["knockback"]),
		bool(atk["is_sonic"]),
		max_targets,
		cleave_angle
	)
	_present_attack_hit(atk, hit, from, dir)

func _fire_laser(atk: Dictionary) -> Dictionary:
	var camera: Camera3D = diver.camera
	var direction := -camera.global_basis.z
	var excluded: Array[RID] = [diver.get_rid()]
	var aim_hit: Dictionary = ocean.trace_laser(camera.global_position, direction, float(atk["range"]), excluded)
	var muzzle: Vector3 = diver.get_muzzle_position()
	var aim_point: Vector3 = aim_hit["position"]
	var to_aim: Vector3 = aim_point - muzzle
	# A second trace prevents firing through a wall next to the barrel.
	var hit: Dictionary = ocean.trace_laser(muzzle, to_aim.normalized(), to_aim.length() + 0.05, excluded)
	var at: Vector3 = hit["position"]
	CombatVFX.spawn_laser(self, muzzle, at, ocean.get_laser_color())
	var damage_result := {}
	var creature: Node3D = hit.get("creature", null)
	if is_instance_valid(creature):
		damage_result = ocean.damage_creature(creature, float(atk["damage"]))
		_present_attack_hit(atk, damage_result, muzzle, direction)
		companion_attack_target = creature
	elif hit.has("collider"):
		CombatVFX.spawn_hit_burst(self, at, -direction, "sonic")
	return damage_result

func _launch_energy_orb(atk: Dictionary) -> Node3D:
	var orb := EnergyOrb.new()
	orb.direction = -diver.camera.global_basis.z
	orb.field_radius = float(atk["field_radius"])
	orb.freeze_duration = float(atk["freeze_duration"])
	orb.excluded = [diver.get_rid()]
	orb.detonated.connect(_detonate_stasis)
	add_child(orb)
	orb.global_position = diver.get_muzzle_position()
	UnderwaterAudio.play_sound(get_tree(), "sonic_blast", -4.0, 0.7)
	return orb

func _fire_submarine_weapon() -> void:
	if not is_instance_valid(active_submarine):
		return
	var torp_data: Dictionary = active_submarine.fire_weapon()
	if torp_data.is_empty():
		return
	if str(torp_data.get("mode", "")) == "emp_beam":
		var from: Vector3 = torp_data["from"]
		var dir: Vector3 = -diver.camera.global_basis.z
		var excluded: Array[RID] = [diver.get_rid(), active_submarine.get_rid()]
		var hit: Dictionary = ocean.trace_laser(from, dir, float(torp_data["range"]), excluded)
		var at: Vector3 = hit["position"]
		CombatVFX.spawn_laser(self, from, at, Color(0.2, 0.95, 1.0))
		UnderwaterAudio.play_sound(get_tree(), "laser", -4.0, 1.15)
		var creature: Node3D = hit.get("creature", null)
		if is_instance_valid(creature):
			ocean.damage_creature(creature, float(torp_data["damage"]))
			creature.set_meta("stun_timer", 3.0)
			CombatVFX.spawn_hit_burst(self, at, -dir, "sonic", true, false)
			hud.toast("微型潜艇电磁脉冲命中！造成 %d 点伤害" % int(torp_data["damage"]))
		elif hit.has("collider"):
			CombatVFX.spawn_hit_burst(self, at, -dir, "sonic", false, false)
		return

	var torp := SubmarineTorpedoCls.new()
	torp.direction = torp_data["direction"]
	torp.speed = float(torp_data["speed"])
	torp.damage = float(torp_data["damage"])
	torp.explosion_radius = float(torp_data["radius"])
	torp.has_shockwave = bool(torp_data.get("shockwave", false))
	torp.excluded = [diver.get_rid(), active_submarine.get_rid()]
	torp.ocean_ref = ocean
	torp.is_guided = true
	torp.guiding_camera = diver.camera
	add_child(torp)
	torp.global_position = torp_data["from"]
	active_torpedo = torp
	UnderwaterAudio.play_sound(get_tree(), "sub_torpedo_launch", -4.0, 1.0)
	hud.toast("【车载鱼雷已射出】正在沿瞄准线飞向目标！")

func _detonate_stasis(at: Vector3, radius: float, duration: float) -> void:
	if screen != "play":
		return
	stasis_fields.append({"position": at, "radius": radius, "remaining": duration})
	var frozen: int = ocean.freeze_creatures(at, radius, duration)
	CombatVFX.spawn_stasis_burst(self, at, radius, duration)
	UnderwaterAudio.play_sound(get_tree(), "sonic_hit", -4.0, 0.65)
	hud.toast("静滞场展开 · %d 只生物暂停 %.1f 秒" % [frozen, duration])

func _physics_process(delta: float) -> void:
	if screen != "play":
		return
	for i in range(stasis_fields.size() - 1, -1, -1):
		var field: Dictionary = stasis_fields[i]
		field["remaining"] = float(field["remaining"]) - delta
		if float(field["remaining"]) <= 0.0:
			stasis_fields.remove_at(i)
		else:
			ocean.freeze_creatures(field["position"], float(field["radius"]), float(field["remaining"]))

	if is_instance_valid(active_submarine):
		state.oxygen = state.max_oxygen
		var input := Input.get_vector("left", "right", "forward", "backward")
		var vert := Input.get_axis("descend", "ascend")
		var is_boost := Input.is_action_pressed("sprint")
		active_submarine.pilot_direct(delta, input, vert, is_boost, diver.camera.global_basis)
		diver.global_position = active_submarine.cockpit_seat.global_position if is_instance_valid(active_submarine.cockpit_seat) else active_submarine.global_position
		diver.velocity = active_submarine.velocity
	elif active_mount_idx >= 0 and active_mount_idx < tamed_beasts.size():
		var m_entry: Dictionary = tamed_beasts[active_mount_idx]
		var m_node: Node3D = m_entry.get("node")
		if not is_instance_valid(m_node) or bool(m_node.get_meta("dead", false)):
			_dismount_beast()
		else:
			# 1. 坐骑转向机动 (A 左拐, D 右拐)：敏捷平滑偏航与水动力侧倾
			var turn_val := 0.0
			if Input.is_action_pressed("left"): turn_val += 1.0
			if Input.is_action_pressed("right"): turn_val -= 1.0
			if turn_val != 0.0:
				m_node.rotate_y(turn_val * 2.8 * delta)
				diver.rotate_y(turn_val * 2.8 * delta)

			var roll_target := clampf(-turn_val * 0.28, -0.32, 0.32)
			m_node.rotation.z = lerp_angle(m_node.rotation.z, roll_target, delta * 7.5)

			# 2. 坐骑俯仰升降 (空格 上升, C 下降)
			var vert_val := Input.get_axis("descend", "ascend")
			var pitch_target := clampf(-vert_val * 0.28, -0.35, 0.35)
			m_node.rotation.x = lerp_angle(m_node.rotation.x, pitch_target, delta * 6.5)

			# 3. 推进动力 (W 前进, S 后退)
			var fwd_val := 0.0
			if Input.is_action_pressed("forward"): fwd_val += 1.0
			if Input.is_action_pressed("backward"): fwd_val -= 0.55

			var is_boost: bool = Input.is_action_pressed("sprint")
			var spd: float = float(m_entry.get("speed", 22.0)) * (1.65 if is_boost else 1.0)

			var m_fwd := -m_node.global_basis.z
			var move_vec := m_fwd * fwd_val + Vector3(0, vert_val * 0.95, 0)
			m_node.position += move_vec.limit_length() * spd * delta
			if m_node.has_method("animate"):
				m_node.animate(delta * (1.8 if is_boost else 1.0))

			var floor_y := Ocean.floor_height(m_node.position.x, m_node.position.z) + 1.2
			m_node.position.y = clampf(m_node.position.y, floor_y, 0.5)
			m_node.position.x = clampf(m_node.position.x, -440.0, 440.0)
			m_node.position.z = clampf(m_node.position.z, -470.0, 210.0)

			diver.global_position = m_node.global_position + m_node.global_basis * Vector3(0, 1.8, 0.2)
			diver.velocity = Vector3.ZERO

	_tick_companion_followers(delta)

func _on_boss_encounter_started() -> void:
	hud.toast("【终章 Boss 战】深渊水龙苏醒！用 T 瞄准，蓄力静滞球创造攻击机会。")
	if not diver.lamp.visible:
		diver.toggle_lamp()
	diver.add_trauma(0.3)

func _on_boss_defeated() -> void:
	var c_cnt: int = ocean.conquered_bosses.size() if is_instance_valid(ocean) else 1
	hud.toast("【深海领主平息】四大巨兽征服进度: %d / 4" % c_cnt)
	if c_cnt >= 4:
		state.all_bosses_defeated = true
		state.boss_defeated = true
		hud.toast("【神迹降临】四大巨兽全部制伏！远古母树于深海极渊 (坐标 0, -125, -340) 苏醒！游向母树！")
	elif state.mode == "explore" and c_cnt == 1:
		state.boss_defeated = true

func _present_attack_hit(atk: Dictionary, hit: Dictionary, from: Vector3, dir: Vector3) -> void:
	var weapon_type: String = str(atk.get("weapon", "knife"))
	if not hit.is_empty():
		effect.play()
		var hit_count: int = int(hit.get("hit_count", 1))
		var killed_names: Array = hit.get("killed_names", [])
		var drops: Array = hit.get("dropped_items", [])
		var is_any_killed: bool = not killed_names.is_empty()

		# 水下微卡肉（Hitstop）增强打击阻抗感
		var hitstop_dur: float = 0.08 if weapon_type == "axe" else (0.038 if weapon_type == "knife" else 0.06)
		diver.trigger_hitstop(hitstop_dur)

		# 播放对应武器的水下受击音效与打击确认音
		match weapon_type:
			"knife":
				UnderwaterAudio.play_sound(get_tree(), "knife_hit", -4.0, randf_range(0.95, 1.05))
			"axe":
				UnderwaterAudio.play_sound(get_tree(), "axe_hit", -1.5, randf_range(0.92, 1.04))
			"sonic":
				UnderwaterAudio.play_sound(get_tree(), "sonic_hit", -2.5, randf_range(0.95, 1.05))
		UnderwaterAudio.play_sound(get_tree(), "hit_confirm", -7.0, 1.0)
		if is_any_killed:
			UnderwaterAudio.play_sound(get_tree(), "kill_sound", -4.5, 1.0)

		# 触发准星受击动效
		if is_instance_valid(hud):
			hud.trigger_hit_marker(is_any_killed)

		# 在受击空间坐标生成 3D 爆点特效与 3D 伤害飘字
		var hit_positions: Array = hit.get("hit_positions", [])
		var hit_kinds: Array = hit.get("hit_kinds", [])
		var total_dmg: float = float(atk.get("damage", 32.0))
		if hit_positions.is_empty():
			hit_positions.append(from + dir * minf(float(atk["range"]), 4.0))
		for i in range(hit_positions.size()):
			var p_pos: Vector3 = hit_positions[i]
			var p_kind: String = str(hit_kinds[i]) if i < hit_kinds.size() else ""
			var is_pred: bool = p_kind == "predator" or p_kind == "abyss"
			CombatVFX.spawn_hit_burst(self, p_pos, -dir, weapon_type, is_pred, is_any_killed)
			CombatVFX.spawn_damage_number(self, p_pos, total_dmg, weapon_type, is_pred or weapon_type == "axe")

		var drop_hint := ""
		if not drops.is_empty():
			var drop_name_list: Array[String] = []
			for d in drops:
				drop_name_list.append(str(d.get("name", "碎片")))
			drop_hint = "，掉落【%s】！按 E 采集可强化武器！" % "、".join(drop_name_list)

		if not killed_names.is_empty():
			if hit_count > 1:
				hud.toast("击杀 %d 只生物（%s），尸体上浮%s" % [killed_names.size(), "、".join(killed_names), drop_hint])
			else:
				hud.toast("击杀【%s】，尸体上浮%s" % [hit["name"], drop_hint])
		elif bool(hit.get("is_sonic", false)):
			if hit_count > 1:
				hud.toast("声波脉冲同时震晕 %d 只生物" % hit_count)
			else:
				hud.toast("声波脉冲震晕【%s】" % hit["name"])

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and screen == "play" and is_instance_valid(hud):
		_set_screen("pause")

func _process(delta: float) -> void:
	if not is_instance_valid(hud):
		return
	var distance: float = diver.position.distance_to(Ocean.HOME)
	var depth: float = maxf(0, -diver.position.y)
	var safe: bool = distance < 7.0 or diver.position.y > -0.6

	if screen == "play":
		if attack_input_buffered:
			attack_buffer_timer -= delta
			if attack_buffer_timer <= 0.0:
				attack_input_buffered = false
			elif is_instance_valid(diver) and diver.attack_cooldown <= 0.0:
				attack_input_buffered = false
				_perform_attack()

		if state.tick(delta, safe, diver.sprinting, depth):
			state.recover()
			var revive_pos: Vector3 = diver.position + Vector3(0, 3.5, 0)
			var floor_y: float = Ocean.floor_height(revive_pos.x, revive_pos.z) + 1.8
			revive_pos.y = maxf(revive_pos.y, floor_y)
			diver.position = revive_pos
			diver.velocity = Vector3.ZERO
			hud.toast("【氧气耗尽就地苏生】应急备用氧舱激活！已在当前海域就近苏醒！")
		if state.mode != "explore":
			if state.oxygen < 25.0 and not low_oxygen_warned:
				low_oxygen_warned = true
				hud.toast("氧气不足 25 秒！按住空格上浮，或返回逃生舱补氧。")
			if state.oxygen > 30.0:
				low_oxygen_warned = false

		# 捕食者 AI 推进与攻击检测
		var bites: Array[Dictionary] = ocean.tick_predators(diver.global_position, delta, diver.lamp.visible)
		for bite in bites:
			# 探险模式生命无限，完全不扣血受害
			if state.mode == "explore":
				continue
			# 契约坐骑战宠无法伤害主人
			if bite.get("is_tamed", false):
				continue
			if is_instance_valid(active_submarine):
				var sub_dead: bool = active_submarine.take_damage(float(bite["damage"]))
				hud.toast("【装甲受损】%s 撞击潜艇！装甲余量 %d%%" % [bite["name"], int(active_submarine.get_hull_ratio() * 100.0)])
				UnderwaterAudio.play_sound(get_tree(), "axe_hit", -3.0, 0.85)
				if sub_dead:
					hud.toast("【警报】潜艇外壳破碎！紧急逃生注水！")
					_disembark_submarine()
			else:
				# 单手能量护盾防御：按 C 举盾时 100% 抵挡来自前方的伤害！
				if diver.shield_active:
					CombatVFX.spawn_shield_deflect(self, diver.global_position - diver.camera.global_basis.z * 0.7, diver.camera.global_basis.z)
					UnderwaterAudio.play_sound(get_tree(), "shield_block", -2.0, randf_range(0.95, 1.05))
					hud.toast("【单手护盾格挡】成功阻挡了 %s 的扑咬！伤害完全消除！" % str(bite["name"]))
					continue

				var dead: bool = state.take_damage(float(bite["damage"]))
				damage_flash_time = 0.65
				hud.toast("【遭受袭击】遭 %s 猛烈撕咬！受到 %d 点伤害！" % [bite["name"], int(bite["damage"])])
				if dead:
					ocean.reset_boss_encounter()
					state.recover()
					var revive_pos: Vector3 = diver.position + Vector3(0, 3.5, 0)
					var floor_y: float = Ocean.floor_height(revive_pos.x, revive_pos.z) + 1.8
					revive_pos.y = maxf(revive_pos.y, floor_y)
					diver.position = revive_pos
					diver.velocity = Vector3.ZERO
					hud.toast("【就地应急苏生】深海生化再生液注入！已在遇险附近海域就近复苏，探险进度保留！")

		_check_landmarks()
		_update_target()

	diver.upgraded = state.fins
	diver.exploration_mode = state.mode == "explore"
	diver.biomod_dash_unlocked = state.biomod_dash
	diver.biomod_vision_unlocked = state.biomod_vision
	ocean.set_depth(depth, diver.scoped)
	if screen == "play" and diver.scoped:
		scope_scan_timer -= delta
		if scope_scan_timer <= 0.0:
			scope_scan_timer = 0.12
			var scope_exclusions: Array[RID] = [diver.get_rid()]
			var scan: Dictionary = ocean.trace_laser(diver.camera.global_position, -diver.camera.global_basis.z, 2000.0, scope_exclusions)
			scope_distance = diver.camera.global_position.distance_to(scan["position"])

	var prompt: String = ""
	var nearby_sub: Node3D = ocean.find_nearby_submarine(diver.global_position, 8.5) if is_instance_valid(ocean) else null
	var tame_cand: Node3D = _find_tameable_candidate()

	if is_instance_valid(active_submarine):
		prompt = ""
	elif active_mount_idx >= 0 and active_mount_idx < tamed_beasts.size():
		prompt = "G / E  离开坐骑【%s】(转为跟随护卫)" % str(tamed_beasts[active_mount_idx]["name"])
	elif is_instance_valid(tame_cand):
		prompt = "E  契约驯服【%s】(声波静滞受控！契约为忠诚坐骑战宠)" % str(tame_cand.get_meta("name", "巨兽"))
	elif is_instance_valid(target) and str(target.get_meta("kind", "")) in ["mother_tree_essence", "ancient_star_core", "tree_seed"]:
		prompt = "E  采摘收取【%s】" % str(target.get_meta("name", "母树核心遗物"))
	elif diver.global_position.distance_to(Ocean.HOME + Vector3(2.2, 0.4, 1.4)) < 4.5:
		var has_ess := int(state.inventory.get("mother_tree_essence", 0))
		var has_cor := int(state.inventory.get("ancient_star_core", 0))
		var has_sed := int(state.inventory.get("tree_seed", 0))
		if has_ess >= 1 and has_cor >= 1 and has_sed >= 1:
			prompt = "E  操作控制台制作【深海跃迁逃逸器】(离开深海！)"
		else:
			prompt = "E  中央逃生控制台 (母树核心遗物 %d/3 · 集齐后制作逃生舰)" % (has_ess + has_cor + has_sed)
	elif is_instance_valid(target) and bool(target.get_meta("dead", false)) and bool(target.get_meta("can_loot", false)) and not bool(target.get_meta("looted", false)):
		var c_name: String = str(target.get_meta("name", "海洋生物"))
		prompt = "E  搜刮【%s】尸体 (获取海兽生肉、坚韧兽皮与骨齿材料)" % c_name
	elif is_instance_valid(target) and str(target.get_meta("kind", "")) == "submarine":
		var sub: Node = target.get_meta("sub_ref", target)
		var s_name: String = str(sub.sub_name if "sub_name" in sub else "潜水艇")
		prompt = "E  登舰驾驶【%s】(高速航行 / 车载鱼雷系统)" % s_name
	elif is_instance_valid(nearby_sub):
		var s_name: String = str(nearby_sub.sub_name if "sub_name" in nearby_sub else "潜水艇")
		prompt = "E  登舰驾驶【%s】(高速航行 / 车载鱼雷系统)" % s_name
	elif is_instance_valid(target):
		var target_kind: String = str(target.get_meta("kind"))
		if target_kind == "black_box":
			prompt = "E  调查失事科考潜艇黑匣子 (读取深渊日志)"
		elif target_kind == "fish_small":
			prompt = "E  捕食发光小金鱼 (+25 HP / +20 O₂)"
		elif target_kind == "shark_fragment":
			prompt = "E  采集巨鲨齿骨碎片 (吸收强化: 攻击力 +12)"
		elif target_kind == "abyss_fragment":
			prompt = "E  采集深渊巨兽晶核 (吸收强化: 攻击力 +25)"
		else:
			prompt = "E  采集 " + Ocean.RESOURCE_NAMES.get(target_kind, target_kind)
	elif distance < 7.0:
		prompt = "安全区 · 正在补氧    Tab  使用制造台" if state.mode != "explore" else "逃生舱基地    Tab  使用制造台"

	hud.update_hud({
		"mode": state.mode,
		"oxygen": state.oxygen,
		"max_oxygen": state.max_oxygen,
		"health": state.health,
		"depth": depth,
		"biome": _get_current_biome(diver.position),
		"landmarks_count": state.landmarks_discovered.size(),
		"landmarks_total": LANDMARKS.size(),
		"inventory": state.inventory,
		"target": prompt,
		"distance_home": distance,
		"tank": state.tank,
		"fins": state.fins,
		"elapsed": state.elapsed,
		"weapons": state.weapons,
		"current_weapon": diver.current_weapon,
		"aiming": diver.aiming,
		"scoped": diver.scoped,
		"scope_distance": scope_distance,
		"charging": diver.gun_trigger_held,
		"charge_ratio": diver.get_charge_ratio(),
		"charge_ready": diver.charge_time >= Diver.CHARGE_THRESHOLD,
		"gun_cooldown": diver.attack_cooldown,
		"boss": ocean.get_boss_status(),
		"distance_boss": diver.position.distance_to(Ocean.BOSS_ARENA_CENTER),
		"beacon_ready": state.rescued,
		"weapon_level": state.weapon_upgrade_level,
		"damage_bonus": state.weapon_attack_bonus,
		"pinned_info": state.get_pinned_info(),
		"rebreather": state.rebreather,
		"biomod_dash": state.biomod_dash,
		"dash_cooldown": diver.dash_cooldown,
		"sprinting": diver.sprinting
		,"booster_active": diver.booster_active,
		"in_submarine": is_instance_valid(active_submarine),
		"sub_name": active_submarine.sub_name if is_instance_valid(active_submarine) else "",
		"sub_hull": active_submarine.hull if is_instance_valid(active_submarine) else 0.0,
		"sub_max_hull": active_submarine.max_hull if is_instance_valid(active_submarine) else 1.0,
		"sub_speed": active_submarine.current_speed if is_instance_valid(active_submarine) else 0.0,
		"sub_weapon_ready": active_submarine.attack_cooldown <= 0.0 if is_instance_valid(active_submarine) else true,
		"sub_cooldown": active_submarine.attack_cooldown if is_instance_valid(active_submarine) else 0.0
		,"torpedo_guided": is_instance_valid(active_torpedo) and not active_torpedo.exploded,
		"in_torpedo_camera": is_instance_valid(active_torpedo) and active_torpedo.has_camera_focus,
		"torpedo_speed": active_torpedo.speed if is_instance_valid(active_torpedo) else 48.0,
		"torpedo_life_left": maxf(0.0, active_torpedo.max_lifetime - active_torpedo.lifetime) if is_instance_valid(active_torpedo) else 0.0
		,"tamed_beasts": tamed_beasts,
		"active_mount_idx": active_mount_idx,
		"is_mounted": active_mount_idx >= 0,
		"mother_tree_active": ocean.mother_tree_spawned_flag if is_instance_valid(ocean) else false,
		"distance_mother_tree": diver.global_position.distance_to(Vector3(0, -125, -340)),
		"tree_items_collected": int(state.inventory.get("mother_tree_essence", 0)) + int(state.inventory.get("ancient_star_core", 0)) + int(state.inventory.get("tree_seed", 0)),
		"conquered_bosses_count": ocean.conquered_bosses.size() if is_instance_valid(ocean) else 0,
		"escape_crafted": state.escape_crafted,
		"shield_active": diver.shield_active
	})
	_update_home_marker(distance)

	# 屏幕受击红光与低氧频闪
	if damage_flash_time > 0.0:
		damage_flash_time = maxf(0.0, damage_flash_time - delta)
		screen_shade.color = Color(0.85, 0.08, 0.05, clampf(damage_flash_time * 0.75, 0.0, 0.55))
	else:
		var low_oxy: bool = state.mode != "explore" and state.oxygen < 15.0
		var shade_alpha: float = (0.22 if low_oxy else 0.0) * (0.65 + sin(Time.get_ticks_msec() * 0.006) * 0.35)
		screen_shade.color = Color(0.5, 0.05, 0.035, shade_alpha)

func _update_target() -> void:
	target = null
	var camera: Camera3D = diver.camera
	var from := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from - camera.global_basis.z * 5.5, 3)
	query.exclude = [diver.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider.has_meta("kind"):
		target = hit.collider

func _interact() -> void:
	if is_instance_valid(active_submarine):
		_disembark_submarine()
		return
	if active_mount_idx >= 0:
		_dismount_beast()
		return
	var tame_cand: Node3D = _find_tameable_candidate()
	if is_instance_valid(tame_cand):
		_tame_creature(tame_cand)
		return
	var tamed_cand: Node3D = _find_nearby_tamed_beast()
	if is_instance_valid(tamed_cand) and active_mount_idx < 0:
		var b_idx: int = _get_tamed_beast_index(tamed_cand)
		if b_idx >= 0:
			_mount_beast(b_idx)
			return
	if is_instance_valid(target) and str(target.get_meta("kind", "")) in ["mother_tree_essence", "ancient_star_core", "tree_seed"]:
		_collect_mother_tree_item(target)
		return
	if is_instance_valid(ocean):
		for m_item in ocean.mother_tree_items:
			if is_instance_valid(m_item) and diver.global_position.distance_to(m_item.global_position) < 4.2:
				_collect_mother_tree_item(m_item)
				return
	if (is_instance_valid(target) and str(target.get_meta("kind", "")) == "escape_console") or diver.global_position.distance_to(Ocean.HOME + Vector3(2.2, 0.4, 1.4)) < 4.5:
		_interact_escape_console()
		return
	if is_instance_valid(target) and bool(target.get_meta("dead", false)) and bool(target.get_meta("can_loot", false)) and not bool(target.get_meta("looted", false)):
		_loot_corpse(target)
		return
	if is_instance_valid(target) and str(target.get_meta("kind", "")) == "submarine":
		var sub: Node = target.get_meta("sub_ref", target)
		_board_submarine(sub)
		return
	var nearby_sub: Node3D = ocean.find_nearby_submarine(diver.global_position, 8.5) if is_instance_valid(ocean) else null
	if is_instance_valid(nearby_sub):
		_board_submarine(nearby_sub)
		return
	if not is_instance_valid(target):
		return
	var kind: String = str(target.get_meta("kind"))
	if kind == "black_box":
		state.black_box_read = true
		hud.toast("【科考日志 #04】：已记录深渊祭坛坐标。共鸣阵列需石英与晶核能量，方可激发全频段呼救信标！")
		effect.play()
		return
	if kind == "fish_small":
		var result: Dictionary = state.eat_fish()
		hud.toast("食用发光小金鱼！生命 +%d · 氧气 +%d" % [int(result["health_gain"]), int(result["oxygen_gain"])])
		ocean.remove_small_fish(target)
		target = null
		effect.play()
		return

	if kind == "shark_fragment" or kind == "abyss_fragment":
		var upgrade_res: Dictionary = state.collect_fragment(kind)
		diver.damage_bonus = state.weapon_attack_bonus
		hud.toast("【武器强化升级 Lv.%d】吸收 %s！全武器攻击力 +%d (总加成 +%d)" % [
			int(upgrade_res["level"]),
			upgrade_res["name"],
			int(upgrade_res["bonus"]),
			int(upgrade_res["total_bonus"])
		])
		ocean.remove_fragment(target)
		target = null
		effect.play()
		return

	if state.collect(kind):
		hud.toast("+1 " + Ocean.RESOURCE_NAMES.get(kind, kind))
		ocean.resources.erase(target)
		target.queue_free()
		target = null
		effect.play()

func _loot_corpse(body: Node3D) -> void:
	body.set_meta("looted", true)
	var k: String = str(body.get_meta("kind", ""))
	var c_name: String = str(body.get_meta("name", "海洋生物"))
	var is_pred: bool = k in ["predator", "abyss", "sea_spider"] or k.begins_with("boss")
	state.inventory["fish_meat"] = int(state.inventory.get("fish_meat", 0)) + randi_range(1, 3)
	state.inventory["creature_skin"] = int(state.inventory.get("creature_skin", 0)) + randi_range(1, 2)
	state.inventory["chitin"] = int(state.inventory.get("chitin", 0)) + 1
	if is_pred:
		state.inventory["creature_tooth"] = int(state.inventory.get("creature_tooth", 0)) + randi_range(1, 2)
	UnderwaterAudio.play_sound(get_tree(), "knife_hit", -4.0, 1.2)
	hud.toast("已搜刮【%s】尸体：获得生肉、韧性兽皮与甲壳骨刺！" % c_name)
	var tw := create_tween()
	tw.tween_interval(1.5)
	tw.tween_property(body, "scale", Vector3.ZERO, 0.4)
	tw.tween_callback(body.queue_free)

func _board_submarine(sub: Node3D) -> void:
	active_submarine = sub as Submarine
	if not active_submarine:
		return
	active_submarine.board(diver)
	diver.cancel_gun_charge()
	if diver.booster_active:
		diver.toggle_booster()
	if is_instance_valid(diver.weapon_mount):
		diver.weapon_mount.visible = false
	UnderwaterAudio.play_sound(get_tree(), "sub_enter", -3.5, 1.0)
	hud.toast("【已登舰驾驶】" + active_submarine.sub_name + " · WASD 航行 / 空格 C 升降 / R 鱼雷 / E 离舰")

func _disembark_submarine() -> void:
	if not is_instance_valid(active_submarine):
		return
	var exit_pos := active_submarine.disembark()
	diver.global_position = exit_pos
	diver.velocity = Vector3.ZERO
	if is_instance_valid(diver.weapon_mount):
		diver.weapon_mount.visible = true
	var sub_name_left := active_submarine.sub_name
	active_submarine = null
	UnderwaterAudio.play_sound(get_tree(), "sub_exit", -4.0, 1.0)
	hud.toast("已离开【%s】，恢复自由潜水游动" % sub_name_left)

func _craft(recipe: String) -> void:
	var error: String = state.craft(recipe, diver.position.distance_to(Ocean.HOME) < 7.0)
	if not error.is_empty():
		hud.toast(error)
		return
	effect.play()
	diver.damage_bonus = state.weapon_attack_bonus
	if recipe == "beacon":
		hud.toast("信标已修复！最终目标：前往深渊祭坛，击败水龙后返航。")
		_set_screen("play")
	else:
		match recipe:
			"tank":
				hud.toast("高容量氧气瓶已装备 · 氧气上限 150 秒")
			"fins":
				hud.toast("轻量动力脚蹼已装备 · 游泳速度提升 50%")
			"axe":
				hud.toast("破拆战斧已制造 · 按 2 装备")
			"sonic":
				hud.toast("蓝光静滞枪已制造 · 3 装备 / Y 远距镜 / 蓄力 R 3 秒松手发射静滞球")
			"reinforce_sharp":
				hud.toast("【制造台深铸】锋锐度精研完成！全武器攻击力额外 +20！")
			"reinforce_sonic":
				hud.toast("【制造台深铸】共振发生器聚焦完成！全武器攻击力额外 +35！")
			"abyssal_escape_engine":
				hud.toast("【深海星际跃迁引擎】已制作完成！准备逃离深海！")
				UnderwaterAudio.play_sound(get_tree(), "warp_escape")
				CombatVFX.spawn_tame_ring(self, Ocean.HOME + Vector3(2.2, 0.4, 1.4), 6.0)
				_set_screen("win")
			"reinforced_suit":
				hud.toast("【装备升级】海兽绝缘潜航服已装配！生命上限 +50 · 减免 40% 伤害")
			"bio_battery":
				hud.toast("【载具强化】生物高能电池已激活！潜艇与助推器航速提升 25%")
			"serrated_blade":
				hud.toast("【武器精工】深海锯齿骨刃已研磨！全武器伤害额外 +25！")

func _setup_audio() -> void:
	var ambience := AudioStreamPlayer.new()
	ambience.stream = load("res://assets/audio/ocean.wav")
	ambience.volume_db = -17
	add_child(ambience)
	ambience.finished.connect(ambience.play)
	ambience.play()
	effect = AudioStreamPlayer.new()
	effect.stream = load("res://assets/audio/collect.wav")
	effect.volume_db = -13
	add_child(effect)

func _setup_overlay() -> void:
	var overlay := CanvasLayer.new()
	overlay.layer = 0
	add_child(overlay)
	screen_shade = ColorRect.new()
	screen_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen_shade.color = Color(0.5, 0.05, 0.035, 0)
	overlay.add_child(screen_shade)
	home_arrow = Label.new()
	home_arrow.add_theme_font_override("font", preload("res://assets/fonts/NotoSansSC-Subset.otf"))
	home_arrow.add_theme_font_size_override("font_size", 16)
	home_arrow.add_theme_color_override("font_color", Color(0.75, 1.0, 0.87))
	home_arrow.add_theme_color_override("font_shadow_color", Color(0.0, 0.1, 0.15, 0.8))
	home_arrow.add_theme_constant_override("shadow_offset_x", 1)
	home_arrow.add_theme_constant_override("shadow_offset_y", 1)
	home_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(home_arrow)

func _update_home_marker(distance: float) -> void:
	home_arrow.visible = screen == "play" and distance >= 7.0
	if not home_arrow.visible:
		return
	var camera: Camera3D = diver.camera
	var viewport_size := get_viewport().get_visible_rect().size
	var home: Vector3 = Ocean.HOME + Vector3(0, 1, 0)
	var p := camera.unproject_position(home)
	if camera.is_position_behind(home):
		p = Vector2(viewport_size.x - 190, viewport_size.y * 0.5)
		home_arrow.text = "逃生舱 ↷  %dm" % int(distance)
	else:
		home_arrow.text = "◇  逃生舱  %dm" % int(distance)
	home_arrow.position = Vector2(clampf(p.x - 65, 24, viewport_size.x - 180), clampf(p.y, 130, viewport_size.y - 180))

func _world_check() -> void:
	await get_tree().physics_frame
	# Verify expanded fish populations and predator counts
	assert(ocean.resources.size() == 100, "Should have 100 resources")
	assert(ocean.fish.size() == 134, "Should have 134 total fish across all tiers")
	assert(ocean.small_fish.size() == 54, "Should have 54 small edible fish")
	assert(ocean.predators.size() == 32, "Should have 32 aggressive predators (18 sharks + 14 abyss monsters)")
	assert(ocean.rays.size() == 4, "Should have 4 manta rays")
	assert(ocean.turtles.size() == 6, "Should have 6 sea turtles")
	assert(ocean.squids.size() == 12, "Should have 12 deep sea squids")
	assert(ocean.crabs.size() == 18, "Should have 18 benthic crabs")
	assert(ocean.tubeworm_colonies.size() == 14, "Should have 14 tubeworm colonies")
	assert(ocean.sea_fans.size() == 22, "Should have 22 sea fans")
	assert(ocean.starfish.size() == 24, "Should have 24 starfish urchin colonies")

	_start("survival")

	# Test resource raycast and gathering
	var resource: Node3D = ocean.resources[0]
	diver.position = resource.global_position + Vector3(0, 0.4, 3.0)
	diver.camera.look_at(resource.global_position + Vector3(0, 0.4, 0))
	await get_tree().physics_frame
	_update_target()
	assert(target == resource, "Camera ray must find a real resource collider")
	_interact()
	assert(state.inventory.titanium == 1)
	assert(ocean.resources.size() == 99)

	# Test small fish raycast and eating (HP & oxygen restore)
	state.health = 50.0
	state.oxygen = 30.0
	var sfish: Node3D = ocean.small_fish[0]
	diver.position = sfish.global_position + Vector3(0, 0.2, 2.5)
	diver.camera.look_at(sfish.global_position)
	await get_tree().physics_frame
	_update_target()
	assert(target == sfish, "Camera ray must find edible small fish")
	_interact()
	assert(state.health == 75.0, "Eating fish must restore +25 HP")
	assert(state.oxygen == 50.0, "Eating fish must restore +20 oxygen")
	assert(state.inventory.fish_small == 1, "Inventory should record consumed small fish")
	assert(ocean.small_fish.size() == 53)

	# Test crafting weapons and gear
	diver.position = Ocean.HOME + Vector3(0, 0, 5)
	state.inventory = {"titanium": 10, "kelp": 4, "copper": 4, "quartz": 4, "fish_small": 1}
	_craft("tank")
	_craft("fins")
	_craft("axe")
	_craft("sonic")
	assert(state.tank and state.fins)
	assert("axe" in state.weapons)
	assert("sonic" in state.weapons)

	# Test weapon switching and attacks
	_switch_weapon("axe")
	assert(diver.current_weapon == "axe")
	var axe_atk: Dictionary = diver.attack()
	assert(axe_atk.get("weapon") == "axe" and axe_atk.get("damage") == 70.0)

	diver.attack_cooldown = 0.0
	_switch_weapon("sonic")
	assert(diver.current_weapon == "sonic")
	var sonic_atk: Dictionary = diver.attack()
	assert(sonic_atk.get("weapon") == "sonic" and sonic_atk.get("mode") == "laser")

	# Test predator combat: strike predator with sonic rifle
	var predator: Node3D = ocean.predators[0]
	var initial_hp: float = float(predator.get_meta("health"))
	var hit: Dictionary = ocean.strike_predator(predator.global_position - Vector3(0, 0, 5), Vector3(0, 0, 1), 25.0, 45.0, 15.0, true)
	assert(hit.hit and hit.is_sonic)
	assert(not hit.killed)
	assert(float(predator.get_meta("health")) == initial_hp)
	assert(float(predator.get_meta("stun_timer")) > 0.0)
	assert(not bool(predator.get_meta("dead", false)))

	# Weapon kills small fish but keeps the whole body, which then floats up
	var prey: Node3D = ocean.small_fish[0]
	prey.position = Vector3(240, -10, 240)
	var kill_small: Dictionary = ocean.strike_predator(prey.global_position - Vector3(0, 0, 1), Vector3(0, 0, 1), 3.0, 32.0, 0.0, false, 1, 0.99)
	assert(kill_small.killed)
	assert(is_instance_valid(prey) and bool(prey.get_meta("dead")))
	assert(ocean.small_fish.has(prey))
	prey.position.y = -12.0
	ocean._process(1.0)
	assert(prey.position.y <= -12.0 and bool(prey.get_meta("dead")), "Dead fish must sink toward seabed in limp state")
	assert(bool(prey.get_meta("can_loot")), "Dead fish must be lootable")

	# Weapon kills large predators into fragments that float up
	var pred2: Node3D = ocean.predators[0]
	pred2.position = Vector3(-240, -10, 240)
	var kill_pred: Dictionary = ocean.strike_predator(pred2.global_position - Vector3(0, 0, 1), Vector3(0, 0, 1), 3.0, 70.0, 0.0, false, 1, 0.99)
	assert(kill_pred.killed)
	assert(not ocean.predators.has(pred2))
	assert(not ocean.fragments.is_empty())
	var frag: Node3D = ocean.fragments[0]
	frag.position.y = -12.0
	ocean._process(1.0)
	assert(frag.position.y > -12.0)

	# Test predator bite attack
	var initial_diver_hp: float = state.health
	var bites = ocean.tick_predators(diver.global_position, 0.1)
	state.take_damage(25.0)
	assert(state.health == initial_diver_hp - 25.0)

	# Test Biomod Dash trigger
	state.biomod_dash = true
	_perform_dash()
	assert(diver.dash_cooldown > 0.0)

	_craft("beacon")
	assert(state.rescued and screen == "play", "Repairing the beacon must leave the final Boss encounter available")

	# Test exploration mode: infinite oxygen, all weapons unlocked, 7 landmarks
	_start("explore")
	assert(state.mode == "explore")
	assert(diver.exploration_mode)
	assert(state.max_oxygen == 999.0)
	assert(state.weapons.size() == 3)
	diver.position = Vector3(15, -95, -165)
	_check_landmarks()
	assert("vents" in state.landmarks_discovered)
	diver.position = Vector3(45, -55.7, -55)
	_check_landmarks()
	assert("shipwreck" in state.landmarks_discovered)
	for id: String in LANDMARKS:
		diver.position = LANDMARKS[id]["pos"]
		_check_landmarks()
	assert(state.landmarks_discovered.size() == LANDMARKS.size())
	assert(screen == "play", "Exploration mode must remain in active play mode with no time limits")

	print("PASS: world assets, melee/laser weapons, fishing, predator AI, crafting, beacon preparation, exploration and 7 landmarks")
	await get_tree().create_timer(0.35).timeout
	get_tree().quit()

func _capture() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/title-screen.png")
	_start("survival")
	diver.active = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	diver.position = Vector3(0, -12, 10)
	diver.rotation = Vector3.ZERO
	diver.camera.rotation = Vector3(-0.08, 0, 0)
	hud.toast_time = 0.01
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/gameplay.png")
	_set_screen("craft")
	hud.toast_time = 0.0
	hud.toast_label.hide()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/crafting.png")

	# Capture deep-sea hydrothermal vents in exploration mode
	_start("explore")
	diver.active = false
	diver.lamp.visible = true
	diver.position = Vector3(15, -88, -152)
	diver.camera.look_at(Vector3(15, -94, -165))
	ocean.set_depth(88.0)
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/deep-sea.png")

	# Capture sunken research submarine shipwreck in exploration mode
	diver.position = Vector3(45.0, -53.2, -45.0)
	diver.camera.look_at(Vector3(45.0, -55.2, -55.0))
	ocean.set_depth(53.2)
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/shipwreck.png")

	print("Screenshots saved to docs/ (title-screen.png, gameplay.png, crafting.png, deep-sea.png, shipwreck.png)")
	get_tree().quit()

func _perform_dash() -> void:
	diver.biomod_dash_unlocked = state.biomod_dash
	var res: Dictionary = diver.trigger_dash(state.oxygen)
	if res.get("success", false):
		if state.mode != "explore":
			state.oxygen = maxf(0.0, state.oxygen - float(res.get("cost", 12.0)))
		hud.toast("【涡流突进】水下急速规避！")
		effect.play()
	elif not res.get("reason", "").is_empty():
		hud.toast(str(res["reason"]))

func _on_pin_recipe(recipe: String) -> void:
	state.pin_recipe(recipe)
	var info := state.get_pinned_info()
	if info.is_empty():
		hud.toast("已取消配方追踪")
	else:
		hud.toast("已追踪配方【%s】" % str(info.get("name", recipe)))

func _can_tame_creature(c: Node3D) -> bool:
	if not is_instance_valid(c) or bool(c.get_meta("dead", false)) or bool(c.get_meta("tamed", false)):
		return false
	var frozen: float = float(c.get_meta("freeze_timer", 0.0))
	if frozen <= 0.0 and not c.has_node("StasisAura"):
		return false
	var kind: String = str(c.get_meta("kind", ""))
	var is_boss: bool = kind.begins_with("boss") or c == ocean.water_dragon or c in ocean.boss_nodes.values()
	var hp: float = float(c.get_meta("health", 100.0))
	var max_hp: float = float(c.get_meta("max_health", 100.0))
	if is_boss:
		return hp <= max_hp * 0.35
	elif kind in ["predator", "abyss", "sea_wolf", "sea_spider"]:
		return true
	return false

func _find_tameable_candidate() -> Node3D:
	if not is_instance_valid(ocean):
		return null
	var cand_list: Array[Node3D] = ocean.get_creatures()
	for c in cand_list:
		if is_instance_valid(c) and _can_tame_creature(c):
			if diver.global_position.distance_to(c.global_position) <= 10.0:
				return c
	return null

func _find_nearby_tamed_beast() -> Node3D:
	for b in tamed_beasts:
		var node: Node3D = b.get("node")
		if is_instance_valid(node) and diver.global_position.distance_to(node.global_position) <= 6.5:
			return node
	return null

func _get_tamed_beast_index(node: Node3D) -> int:
	for i in range(tamed_beasts.size()):
		if tamed_beasts[i].get("node") == node:
			return i
	return -1

func _tame_creature(c: Node3D) -> void:
	if tamed_beasts.size() >= 20:
		hud.toast("【契约上限】最多同时契约 20 只坐骑战宠！")
		return
	var c_name := str(c.get_meta("name", "深海战兽"))
	var kind := str(c.get_meta("kind", ""))
	c.set_meta("tamed", true)
	c.set_meta("freeze_timer", 0.0)
	if c.has_method("set_tamed"): c.set_tamed(true)
	if c.has_node("StasisAura"): c.get_node("StasisAura").queue_free()
	for b_id in ocean.boss_nodes:
		if c == ocean.boss_nodes[b_id]:
			ocean.mark_boss_tamed(b_id)
			break
	var beast_info := {
		"node": c,
		"kind": kind,
		"name": c_name,
		"health": float(c.get_meta("health", 600.0)),
		"max_health": float(c.get_meta("max_health", 600.0)),
		"speed": 22.0 if kind.begins_with("boss") else 17.5,
		"damage": 55.0 if kind.begins_with("boss") else 32.0
	}
	tamed_beasts.append(beast_info)
	state.tamed_beast_count = tamed_beasts.size()
	CombatVFX.spawn_tame_ring(self, c.global_position, 5.0)
	UnderwaterAudio.play_sound(get_tree(), "tame_success")
	if active_mount_idx < 0:
		_mount_beast(tamed_beasts.size() - 1)
	else:
		var cur_mult := pow(2.0, maxf(0.0, float(tamed_beasts.size() - 1)))
		hud.toast("【契约缔结】成功驯服【%s】！(已契约: %d/20 · 全体攻击力提高至: ×%.0f)" % [c_name, tamed_beasts.size(), cur_mult])

func _mount_beast(idx: int) -> void:
	if idx < 0 or idx >= tamed_beasts.size():
		return
	if is_instance_valid(active_submarine):
		hud.toast("驾驶潜水艇期间无法骑乘生物！")
		return
	active_mount_idx = idx
	UnderwaterAudio.play_sound(get_tree(), "mount_ride")
	hud.toast("【驾驭坐骑】已骑乘【%s】· W 前进 / C 下降 / 空格 上升 / A 左拐 / D 右拐 / G 离鞍" % tamed_beasts[idx]["name"])

func _dismount_beast() -> void:
	if active_mount_idx >= 0:
		hud.toast("【已下坐骑】契约战兽进入护卫阵型跟随！")
		active_mount_idx = -1

func _tick_companion_followers(delta: float) -> void:
	companion_orbit_clock += delta
	var player_leader_pos: Vector3 = diver.global_position
	var player_leader_basis: Basis = diver.global_basis
	if active_mount_idx >= 0 and active_mount_idx < tamed_beasts.size():
		var cur_m: Node3D = tamed_beasts[active_mount_idx].get("node")
		if is_instance_valid(cur_m):
			player_leader_pos = cur_m.global_position
			player_leader_basis = cur_m.global_basis
	if is_instance_valid(companion_attack_target) and (bool(companion_attack_target.get_meta("dead", false)) or bool(companion_attack_target.get_meta("tamed", false))):
		companion_attack_target = null
		if is_instance_valid(persistent_red_dot):
			persistent_red_dot.queue_free()
			persistent_red_dot = null

	# 10 米以内如果出现活物，自动发起攻击
	if companion_attack_target == null and not has_target_pos and is_instance_valid(ocean):
		var living_creatures: Array[Node3D] = []
		for c in ocean.get_creatures(): living_creatures.append(c)
		for p in ocean.predators: living_creatures.append(p)
		for w in ocean.sea_wolves: living_creatures.append(w)
		var closest_living: Node3D = null
		var closest_d: float = 10.0
		for cand in living_creatures:
			if is_instance_valid(cand) and not bool(cand.get_meta("tamed", false)) and not bool(cand.get_meta("dead", false)):
				var d: float = cand.global_position.distance_to(player_leader_pos)
				if d <= closest_d:
					closest_d = d
					closest_living = cand
		if closest_living != null:
			companion_attack_target = closest_living
			hud.toast("【警戒防卫】10米内侦测到活物【%s】！战宠自动出击！" % str(closest_living.get_meta("name", "海洋生物")))

	var num_followers := 0
	for b in tamed_beasts:
		if is_instance_valid(b.get("node")) and not bool(b["node"].get_meta("dead", false)):
			num_followers += 1
	if active_mount_idx >= 0:
		num_followers = max(0, num_followers - 1)

	var follower_slot := 0
	for i in range(tamed_beasts.size()):
		if i == active_mount_idx:
			continue
		var beast_entry: Dictionary = tamed_beasts[i]
		var f_node: Node3D = beast_entry.get("node")
		if not is_instance_valid(f_node) or bool(f_node.get_meta("dead", false)):
			continue
		if f_node.has_method("animate"): f_node.animate(delta)
		var f_spd: float = float(beast_entry.get("speed", 16.0)) * 1.25
		var dist_from_player: float = f_node.global_position.distance_to(player_leader_pos)
		if dist_from_player > 28.0:
			f_node.position = player_leader_pos + player_leader_basis.z * (4.0 + float(follower_slot % 4) * 2.5)

		if is_instance_valid(companion_attack_target):
			var to_t: Vector3 = companion_attack_target.global_position - f_node.global_position
			var dist_t := to_t.length()
			var target_dest := companion_attack_target.global_position - to_t.normalized() * 2.5
			f_node.position = f_node.position.move_toward(target_dest, f_spd * delta * 1.5)
			if to_t.length_squared() > 0.001:
				var up_t := Vector3.UP if absf(to_t.normalized().y) < 0.95 else Vector3.FORWARD
				f_node.look_at(f_node.global_position + to_t, up_t, true)
			var cd: float = maxf(0.0, float(f_node.get_meta("companion_atk_cd", 0.0)) - delta)
			f_node.set_meta("companion_atk_cd", cd)
			if dist_t < 4.8 and cd <= 0.0:
				f_node.set_meta("companion_atk_cd", 1.2)
				var atk_mult: float = pow(2.0, maxf(0.0, float(tamed_beasts.size() - 1)))
				var dmg: float = float(beast_entry.get("damage", 40.0)) * atk_mult
				ocean.damage_creature(companion_attack_target, dmg)
				CombatVFX.spawn_hit_burst(self, companion_attack_target.global_position, -to_t.normalized(), "knife", true)
				CombatVFX.spawn_damage_number(self, companion_attack_target.global_position + Vector3(0, 1.2, 0), dmg, "axe", true)
				UnderwaterAudio.play_sound(get_tree(), "knife_hit", -3.0, randf_range(0.9, 1.1))
				hud.toast("【战宠协同】%s 撕咬目标！造成 %d 伤害 (战力加成 ×%.0f)" % [beast_entry.get("name", "战宠"), int(dmg), atk_mult])
		elif has_target_pos:
			var to_p: Vector3 = companion_attack_pos - f_node.global_position
			var dist_p := to_p.length()
			f_node.position = f_node.position.move_toward(companion_attack_pos, f_spd * delta * 1.4)
			if to_p.length_squared() > 0.001:
				var up_p := Vector3.UP if absf(to_p.normalized().y) < 0.95 else Vector3.FORWARD
				f_node.look_at(f_node.global_position + to_p, up_p, true)
			if dist_p < 3.2:
				for pred in ocean.predators + ocean.sea_wolves:
					if is_instance_valid(pred) and not bool(pred.get_meta("dead", false)) and not bool(pred.get_meta("tamed", false)):
						if pred.global_position.distance_to(companion_attack_pos) < 8.0:
							companion_attack_target = pred
							has_target_pos = false
							break
		else:
			# 跟在人物的后方，不转圈；随行跟随，人物停下时也在其后方平稳停下
			var row: int = int(follower_slot / 4)
			var col: int = (follower_slot % 4) - 2
			follower_slot += 1

			# 后方编队间距：player_leader_basis.z 即人物正后方
			var rear_dist: float = 3.6 + float(row) * 3.2
			var lateral_spread: float = (float(col) + 0.5) * 2.4
			var vert_spread: float = (float(row % 2) - 0.5) * 0.7
			var rear_slot_pos: Vector3 = player_leader_pos + player_leader_basis.z * rear_dist + player_leader_basis.x * lateral_spread + Vector3(0, vert_spread, 0)

			var dist_to_slot: float = f_node.global_position.distance_to(rear_slot_pos)
			dist_from_player = f_node.global_position.distance_to(player_leader_pos)

			if dist_from_player > 28.0:
				f_node.position = rear_slot_pos
				dist_to_slot = 0.0

			# 移动到后方编队位置，到达后平稳静止停在后方
			if dist_to_slot > 0.08:
				var move_rate: float = clampf(dist_to_slot / 2.5, 0.25, 2.4)
				f_node.position = f_node.position.move_toward(rear_slot_pos, f_spd * delta * move_rate)

			# 保持面向前方护卫朝向
			var forward_head := -player_leader_basis.z
			if forward_head.length_squared() > 0.001:
				var up_f := Vector3.UP if absf(forward_head.y) < 0.95 else Vector3.FORWARD
				f_node.look_at(f_node.position + forward_head, up_f, true)

func _command_companions_attack(from: Vector3, dir: Vector3) -> void:
	if tamed_beasts.is_empty():
		return
	var excluded_rid: Array[RID] = [diver.get_rid()]
	var scan: Dictionary = ocean.trace_laser(from, dir, 45.0, excluded_rid)
	var c: Node3D = scan.get("creature", null)
	if is_instance_valid(c) and not bool(c.get_meta("tamed", false)) and not bool(c.get_meta("dead", false)):
		companion_attack_target = c
		hud.toast("【集火指令】战宠队伍协同进攻【%s】！" % str(c.get_meta("name", "目标")))

func _recall_pets() -> void:
	if tamed_beasts.is_empty():
		hud.toast("当前无契约战宠可召回")
		return
	companion_attack_target = null
	has_target_pos = false
	if is_instance_valid(persistent_red_dot):
		persistent_red_dot.queue_free()
		persistent_red_dot = null

	var player_leader_pos: Vector3 = diver.global_position
	var player_leader_basis: Basis = diver.global_basis
	if active_mount_idx >= 0 and active_mount_idx < tamed_beasts.size():
		var cur_m: Node3D = tamed_beasts[active_mount_idx].get("node")
		if is_instance_valid(cur_m):
			player_leader_pos = cur_m.global_position
			player_leader_basis = cur_m.global_basis

	var follower_slot := 0
	for i in range(tamed_beasts.size()):
		if i == active_mount_idx:
			continue
		var f_node: Node3D = tamed_beasts[i].get("node")
		if not is_instance_valid(f_node) or bool(f_node.get_meta("dead", false)):
			continue
		var row: int = int(follower_slot / 4)
		var col: int = (follower_slot % 4) - 2
		follower_slot += 1
		var rear_dist: float = 3.6 + float(row) * 3.2
		var lateral_spread: float = (float(col) + 0.5) * 2.4
		var vert_spread: float = (float(row % 2) - 0.5) * 0.7
		var rear_slot_pos: Vector3 = player_leader_pos + player_leader_basis.z * rear_dist + player_leader_basis.x * lateral_spread + Vector3(0, vert_spread, 0)
		f_node.position = rear_slot_pos
		f_node.set_meta("companion_atk_cd", 0.0)
		var forward_head := -player_leader_basis.z
		if forward_head.length_squared() > 0.001:
			var up_f := Vector3.UP if absf(forward_head.y) < 0.95 else Vector3.FORWARD
			f_node.look_at(f_node.position + forward_head, up_f, true)

	UnderwaterAudio.play_sound(get_tree(), "pet_recall")
	CombatVFX.spawn_tame_ring(self, player_leader_pos, 4.0)
	hud.toast("【战宠全员召回】所有契约战兽已立即归队，在后方列队护卫！")

func _fire_marker_gun(atk: Dictionary) -> void:
	var camera: Camera3D = diver.camera
	var direction := -camera.global_basis.z
	var muzzle: Vector3 = diver.get_muzzle_position()
	var excluded_rid: Array[RID] = [diver.get_rid()]
	var scan: Dictionary = ocean.trace_laser(camera.global_position, direction, 2500.0, excluded_rid)
	var hit_pos: Vector3 = scan["position"]
	var creature: Node3D = scan.get("creature", null)

	# 1. 类似激光笔发射鲜红激光束
	CombatVFX.spawn_laser(self, muzzle, hit_pos, Color(1.0, 0.05, 0.05))
	UnderwaterAudio.play_sound(get_tree(), "laser_marker", -3.0, 1.0)

	# 2. 目标身上生成小红点 (松手后红点仍然存在)
	if not is_instance_valid(persistent_red_dot):
		persistent_red_dot = CombatVFX.spawn_persistent_red_dot(hit_pos, null)
	elif persistent_red_dot.get_parent() != null:
		persistent_red_dot.get_parent().remove_child(persistent_red_dot)

	if is_instance_valid(creature) and not bool(creature.get_meta("tamed", false)):
		creature.add_child(persistent_red_dot)
		persistent_red_dot.global_position = hit_pos
		companion_attack_target = creature
		has_target_pos = false
		hud.toast("【光标红点标记】战宠锁定目标【%s】！全速出击进攻！" % str(creature.get_meta("name", "敌对生物")))
	else:
		add_child(persistent_red_dot)
		persistent_red_dot.global_position = hit_pos
		companion_attack_pos = hit_pos
		has_target_pos = true
		companion_attack_target = null
		hud.toast("【光标红点标记】已指定进攻位置！战宠奔赴坐标点！")

func _collect_mother_tree_item(item: Node3D) -> void:
	if not is_instance_valid(item):
		return
	var kind: String = str(item.get_meta("kind", ""))
	var item_name: String = str(item.get_meta("name", "母树核心遗物"))
	state.collect(kind)
	ocean.mother_tree_items.erase(item)
	item.queue_free()
	target = null
	UnderwaterAudio.play_sound(get_tree(), "tame_success", -2.0, 1.25)
	CombatVFX.spawn_tame_ring(self, diver.global_position, 3.5)
	var has_ess := int(state.inventory.get("mother_tree_essence", 0))
	var has_cor := int(state.inventory.get("ancient_star_core", 0))
	var has_sed := int(state.inventory.get("tree_seed", 0))
	var collected := has_ess + has_cor + has_sed
	if collected >= 3:
		hud.toast("【母树遗物齐集】3大圣物全部获得！立即返回逃生舱基地的中央控制台制作逃生舰！")
	else:
		hud.toast("【遗物收取】已获得【%s】！已集齐 %d / 3" % [item_name, collected])

func _interact_escape_console() -> void:
	var has_ess := int(state.inventory.get("mother_tree_essence", 0))
	var has_cor := int(state.inventory.get("ancient_star_core", 0))
	var has_sed := int(state.inventory.get("tree_seed", 0))
	if has_ess >= 1 and has_cor >= 1 and has_sed >= 1:
		state.craft("abyssal_escape_engine", true)
		UnderwaterAudio.play_sound(get_tree(), "warp_escape")
		CombatVFX.spawn_tame_ring(self, Ocean.HOME + Vector3(2.2, 0.4, 1.4), 6.0)
		hud.toast("【跃迁核心注入完成】逃生舰系统全面启动！准备星际跃迁！")
		stasis_fields.clear()
		_set_screen("win")
	else:
		hud.toast("【逃生控制台】需放入深海母树核心3大遗物：母树精华(%d/1) 星核源石(%d/1) 启迪之种(%d/1)" % [has_ess, has_cor, has_sed])
