extends Node3D

const Ocean = preload("res://scripts/ocean.gd")
const OceanDepths = preload("res://scripts/ocean_depths.gd")
const Diver = preload("res://scripts/diver.gd")
const Survival = preload("res://scripts/survival.gd")
const HUD = preload("res://scripts/hud.gd")
const CombatVFX = preload("res://scripts/combat_vfx.gd")
const UnderwaterAudio = preload("res://scripts/underwater_audio.gd")
const EnergyOrb = preload("res://scripts/energy_orb.gd")
const Submarine = preload("res://scripts/submarine.gd")
const SubmarineTorpedoCls = preload("res://scripts/submarine_torpedo.gd")

const LANDMARK_SPECS := {
	"shallows": {"name": "逃生舱浅礁", "pos": Vector3(0, -9, 8), "radius": 28.0, "desc": "阳光明媚的浅海珊瑚林"},
	"coral_sanctuary": {"name": "琉璃珊瑚礁花园", "pos": Vector3(18, -14, -8), "radius": 24.0, "desc": "簇拥着迷宫脑珊瑚、鹿角珊瑚、层叠桌形珊瑚与发光巨砗磲的生态礁盘"},
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
	"outer_void": {"name": "外洋航道门户", "pos": Vector3(0, -12, -220), "radius": 42.0, "desc": "通往南北极渊与广袤开放外洋的洋流门户"},
	"mother_tree": {"name": "远古深海母树", "pos": Vector3(0, -125, -340), "radius": 48.0, "desc": "伫立在深海极渊核心的史前生命母树圣所"},
	"sunlit_atoll": {"name": "北境晴空珊瑚环礁", "pos": Vector3(40, -10, 340), "radius": 58.0, "desc": "阳光穿透碧绿泻湖的远北浅滩环礁与科考锚地"},
	"emerald_kelp_strait": {"name": "翡翠巨藻迷宫海峡", "pos": Vector3(-260, -20, 280), "radius": 55.0, "desc": "百米巨藻随洋流摇曳的幽绿生态海峡"},
	"aurora_crystal_ridge": {"name": "极光海山晶柱岭", "pos": Vector3(380, -26, 290), "radius": 55.0, "desc": "矗立于东北外洋的发光石英海山山脉"},
	"sunken_observatory": {"name": "东海沉没星象古都", "pos": Vector3(460, -38, -60), "radius": 60.0, "desc": "环状石柱拱门簇拥的史前海底星象观测神殿"},
	"ghost_fleet_shoal": {"name": "幽灵舰队沉船海滩", "pos": Vector3(420, -52, -380), "radius": 56.0, "desc": "多艘失事远洋科考舰静卧的东南大陆架"},
	"leviathan_graveyard": {"name": "西洋巨兽龙骨荒原", "pos": Vector3(-480, -58, -90), "radius": 60.0, "desc": "远古利维坦肋骨化石横亘的深海峡谷"},
	"obsidian_caldera": {"name": "黑曜石海底火山口", "pos": Vector3(-440, -82, -420), "radius": 62.0, "desc": "地心熔岩脉动与热泉黑烟囱环绕的海底火山盆地"},
	"hadal_starlight_sanctum": {"name": "南极渊星辉圣域", "pos": Vector3(60, -130, -640), "radius": 65.0, "desc": "水深逾百三十米、星辉晶簇照亮夜海的极南深渊"}
}

var LANDMARKS: Dictionary = _build_landmarks()
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
var waypoint_arrow: Label
var screen_shade: ColorRect
var damage_flash_time: float = 0.0
var map_reveal_timer: float = 0.0
var attack_input_buffered: bool = false
var attack_buffer_timer: float = 0.0
var stasis_fields: Array[Dictionary] = []
var scope_scan_timer := 0.0
var scope_distance := 2000.0
var _target_ray_query := PhysicsRayQueryParameters3D.new()
var _target_ray_exclude: Array[RID] = []
var _target_ray_excluded_rid: RID = RID()
const ATTACK_BUFFER_WINDOW: float = 0.18

static func _build_landmarks() -> Dictionary:
	var landmarks: Dictionary = LANDMARK_SPECS.duplicate(true)
	# Discovery, navigation and travel share positions attached to bathymetry.
	for id: String in ["sunlit_atoll", "emerald_kelp_strait", "aurora_crystal_ridge", "sunken_observatory", "ghost_fleet_shoal", "leviathan_graveyard", "obsidian_caldera", "hadal_starlight_sanctum"]:
		var at: Vector3 = landmarks[id]["pos"]
		at.y = Ocean.terrain_height(at.x, at.z) + 5.0
		landmarks[id]["pos"] = at
		landmarks[id]["desc"] = "%s · 水深约 %dm" % [str(landmarks[id]["desc"]), roundi(-at.y)]
	landmarks["hadal_starlight_sanctum"]["desc"] = "五百余米深的极渊裂谷，稀疏水母与锰结核黏土环绕星辉遗迹"
	return landmarks

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
	hud.sushi_cook_requested.connect(_on_sushi_cook)
	hud.sushi_serve_all_requested.connect(_on_sushi_serve_all)
	hud.cobra_buy_requested.connect(_on_cobra_buy)
	hud.open_sushi_requested.connect(func(): _set_screen("sushi"))
	hud.open_map_requested.connect(func(): _set_screen("map"))
	hud.mount_board_select_requested.connect(_on_mount_board_select)
	hud.mount_board_select_all_requested.connect(_on_mount_board_select_all)
	hud.mount_board_store_all_requested.connect(_store_all_tamed_beasts)
	hud.map_waypoint_set.connect(_on_map_waypoint_set)
	hud.map_waypoint_cleared.connect(_on_map_waypoint_cleared)
	hud.fast_travel_requested.connect(_on_fast_travel_requested)
	hud.sonar_ping_requested.connect(_trigger_sonar_ping)
	state.reveal_world_area(diver.position, 135.0)
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
		"salvage_drone": KEY_V,
		"sushi_menu": KEY_B,
		"mount_board": KEY_O,
		"world_map": KEY_M,
		"sonar_ping": KEY_N,
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
	diver.set_submarine_mode(false)
	diver.set_mount_mode(false)
	diver.position = Vector3(0, -9.0, 17.0)
	diver.rotation = Vector3.ZERO
	diver.camera.rotation.x = -0.16
	diver.velocity = Vector3.ZERO
	diver._update_third_person_camera(0.0)

func _start(chosen_mode: String = "survival") -> void:
	state.set_mode(chosen_mode)
	diver.exploration_mode = chosen_mode == "explore"
	diver.set_weapon("knife")
	state.reveal_world_area(diver.position, 140.0)
	_set_screen("play")
	if chosen_mode == "explore":
		hud.toast("开放海域漫游已开启 · 按 M 打开全域海图与洋流跃迁 · 按 N 释放声呐勘测脉冲 · 3 装备蓝光枪")
	else:
		hud.toast("欢迎来到开放深蓝海域 · 按 M 海图导航/跃迁 · N 声呐寻宝 · E 采集或激活科考前哨站 · Tab 制造台")

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
		target = null
		if is_instance_valid(home_arrow):
			home_arrow.visible = false
		if is_instance_valid(waypoint_arrow):
			waypoint_arrow.visible = false
	get_tree().paused = screen in ["pause", "craft", "sushi", "mount_board", "map", "win"]
	hud.set_screen(screen)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if screen == "play" else Input.MOUSE_MODE_VISIBLE

func _get_current_biome(pos: Vector3) -> String:
	var depth: float = maxf(0, -pos.y)
	var stratum := OceanDepths.zone_label(depth)
	var distance_to_home: float = pos.distance_to(Ocean.HOME)
	if pos.distance_to(Ocean.BOSS_ARENA_CENTER) < Ocean.BOSS_TRIGGER_RADIUS:
		return "水龙领域  /  终章 Boss 战"
	if pos.distance_to(Vector3(0, -125, -340)) < 52.0:
		return "远古深海母树圣所  /  %dm" % roundi(depth)
	for id: String in ["sunlit_atoll", "emerald_kelp_strait", "aurora_crystal_ridge", "sunken_observatory", "ghost_fleet_shoal", "leviathan_graveyard", "obsidian_caldera", "hadal_starlight_sanctum"]:
		var landmark: Dictionary = LANDMARKS[id]
		if pos.distance_to(landmark["pos"]) < float(landmark["radius"]) * 1.3:
			return "%s · %s  /  %dm" % [str(landmark["name"]), stratum, roundi(depth)]
	if pos.distance_to(Vector3(95, -36, -30)) < 34.0:
		return "碧蓝晶簇海盆 (深潜艇船坞)  /  %dm" % roundi(depth)
	if pos.distance_to(Vector3(-85, -42, -50)) < 32.0:
		return "海妖磷光珊瑚林  /  %dm" % roundi(depth)
	if pos.distance_to(Vector3(18, -14, -8)) < 22.0:
		return "琉璃珊瑚礁花园  /  %dm" % roundi(depth)
	if pos.distance_to(Vector3(145, -18, -40)) < 32.0:
		return "风暴海脊 (风暴飞鱼领地)  /  %dm" % roundi(depth)
	if pos.distance_to(Vector3(-105, -75, -85)) < 35.0:
		return "克拉肯海沟 (深渊巨章巢穴)  /  %dm" % roundi(depth)
	if pos.distance_to(Vector3(-140, -92, -145)) < 35.0:
		return "玄甲巨鳌盆地 (远古灵龟领地)  /  %dm" % roundi(depth)
	if distance_to_home < 7.0 or pos.y > -0.6:
		return "安全区  /  生命支持恢复"
	if is_instance_valid(ocean):
		var out_near: Node3D = ocean.find_nearby_outpost(pos, 9.5)
		if is_instance_valid(out_near) and bool(out_near.get_meta("activated", false)):
			return "科考前哨安全区 (%s)  /  %dm" % [str(out_near.get_meta("name", "前哨站")), roundi(depth)]
	if pos.distance_to(Vector3(-110, -96, -185)) < 42.0:
		return "深渊重装造船厂 (泰坦核潜艇)  /  %dm" % roundi(depth)
	if pos.distance_to(Vector3(45, -55.7, -55)) < 32.0:
		return "失事科考潜艇遗址  /  %dm" % roundi(depth)
	if pos.distance_to(Vector3(15, -95, -165)) < 42.0:
		return "深海地热喷口群  /  %dm" % roundi(depth)
	if pos.distance_to(Vector3(-50, -88, -170)) < 35.0:
		return "深渊史前祭坛  /  %dm" % roundi(depth)
	if pos.z > 140.0:
		return "北境暖流环礁外海 · %s  /  %dm" % [stratum, roundi(depth)]
	if pos.z < -380.0:
		return "南极渊深水海盆 · %s  /  %dm" % [stratum, roundi(depth)]
	if pos.x > 220.0:
		return "东海星盘大陆架 · %s  /  %dm" % [stratum, roundi(depth)]
	if pos.x < -220.0:
		return "西洋远古海谷外海 · %s  /  %dm" % [stratum, roundi(depth)]
	return "%s  /  %dm" % [stratum, roundi(depth)]

func _check_landmarks() -> void:
	for id: String in LANDMARKS:
		var landmark: Dictionary = LANDMARKS[id]
		var target_pos: Vector3 = landmark["pos"]
		if diver.position.distance_to(target_pos) < float(landmark["radius"]):
			if state.discover_landmark(id):
				state.reveal_world_area(target_pos, maxf(115.0, float(landmark["radius"]) * 2.4))
				state.gold += 35
				hud.toast("【发现新海域地标】%s · %s (已解锁海图跃迁 · +35G)" % [str(landmark["name"]), str(landmark["desc"])])
				effect.play()
				_check_explorer_rank_up()
				if state.landmarks_discovered.size() >= LANDMARKS.size():
					hud.toast("【全域二十四景勘测达成】你已探明整片开放大洋的全部生态地标！")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		if screen == "play":
			_set_screen("pause")
		elif screen in ["pause", "craft", "sushi", "mount_board", "map"]:
			_set_screen("play")
	elif event.is_action_pressed("world_map") and screen in ["play", "craft", "sushi", "mount_board", "map"]:
		_set_screen("play" if screen == "map" else "map")
	elif event.is_action_pressed("sonar_ping") and screen in ["play", "map"]:
		_trigger_sonar_ping()
	elif event.is_action_pressed("craft_menu") and screen in ["play", "craft", "sushi", "mount_board", "map"]:
		_set_screen("play" if screen == "craft" else "craft")
	elif event.is_action_pressed("sushi_menu") and screen in ["play", "craft", "sushi", "mount_board", "map"]:
		_set_screen("play" if screen == "sushi" else "sushi")
	elif event.is_action_pressed("mount_board") and screen in ["play", "mount_board"]:
		_handle_mount_board_key()
	elif event.is_action_pressed("salvage_drone") and screen == "play":
		_trigger_drone_salvage()
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
	var from: Vector3 = diver.get_aim_origin() if diver.has_method("get_aim_origin") else camera.global_position
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
	var aim_origin: Vector3 = diver.get_aim_origin() if diver.has_method("get_aim_origin") else camera.global_position
	var aim_hit: Dictionary = ocean.trace_laser(aim_origin, direction, float(atk["range"]), excluded)
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
		creature.set_meta("last_hit_weapon", "sonic")
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
		diver.global_position = active_submarine.get_camera_anchor_position()
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
			m_node.position.x = clampf(m_node.position.x, -900.0, 900.0)
			m_node.position.z = clampf(m_node.position.z, -900.0, 900.0)

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
			var kill_stars: int = clampi(int(hit.get("catch_stars", 2)), 1, 3)
			var star_txt := "★".repeat(kill_stars) + "☆".repeat(3 - kill_stars)
			if not hit_positions.is_empty():
				CombatVFX.spawn_star_rating(self, hit_positions[0], kill_stars, str(hit.get("name", "")))
			if hit_count > 1:
				hud.toast("击杀 %d 只生物（%s · 品质 %s），按 E 搜刮或按 V 无人机打捞%s" % [killed_names.size(), "、".join(killed_names), star_txt, drop_hint])
			else:
				hud.toast("击杀【%s】（食材品质 %s），按 E 搜刮或按 V 无人机打捞%s" % [hit["name"], star_txt, drop_hint])
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
	if screen == "play" and is_instance_valid(active_submarine):
		diver.global_position = active_submarine.get_camera_anchor_position()
		diver._update_third_person_camera(delta)
	var distance: float = diver.position.distance_to(Ocean.HOME)
	var depth: float = maxf(0, -diver.position.y)
	var nearby_outpost: Node3D = null
	var near_active_outpost: bool = false

	if screen == "play":
		if is_instance_valid(ocean):
			nearby_outpost = ocean.find_nearby_outpost(diver.global_position, 9.5)
			near_active_outpost = is_instance_valid(nearby_outpost) and bool(nearby_outpost.get_meta("activated", false))
		var safe: bool = distance < 7.0 or diver.position.y > -0.6 or near_active_outpost
		map_reveal_timer -= delta
		if map_reveal_timer <= 0.0:
			map_reveal_timer = 0.35
			var scan_r: float = 135.0 if is_instance_valid(active_submarine) else (105.0 if active_mount_idx >= 0 else 85.0)
			state.reveal_world_area(diver.global_position, scan_r)
			_check_explorer_rank_up()
		if state.has_custom_waypoint:
			var wp_horiz := Vector2(diver.global_position.x - state.custom_waypoint.x, diver.global_position.z - state.custom_waypoint.z).length()
			if wp_horiz < 14.0:
				state.clear_custom_waypoint()
				hud.toast("✦ 已抵达自定义海图标点海域！")
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
			# 契约坐骑战宠无法伤害主人
			if bite.get("is_tamed", false):
				continue
			# 方舟中立防卫机制：一旦野生生物先发动攻击，已解锁并召唤的坐骑立即锁定该生物反击
			var attacker_node: Node3D = bite.get("attacker", null)
			if is_instance_valid(attacker_node):
				register_creature_attack(attacker_node)
			# 探险模式生命无限，完全不扣血受害
			if state.mode == "explore":
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
	diver.overweight = state.is_overweight()
	diver.biomod_dash_unlocked = state.biomod_dash
	diver.biomod_vision_unlocked = state.biomod_vision
	diver.explorer_speed_mult = 1.0 + state.explorer_speed_bonus
	ocean.set_depth(depth, diver.scoped)
	if screen == "play" and diver.scoped:
		scope_scan_timer -= delta
		if scope_scan_timer <= 0.0:
			scope_scan_timer = 0.12
			var scope_exclusions: Array[RID] = [diver.get_rid()]
			var scope_origin: Vector3 = diver.get_aim_origin() if diver.has_method("get_aim_origin") else diver.camera.global_position
			var scan: Dictionary = ocean.trace_laser(scope_origin, -diver.camera.global_basis.z, 2000.0, scope_exclusions)
			scope_distance = scope_origin.distance_to(scan["position"])

	var prompt: String = ""
	if screen == "play":
		var nearby_sub: Node3D = ocean.find_nearby_submarine(diver.global_position, 8.5) if is_instance_valid(ocean) else null
		var tame_cand: Node3D = _find_tameable_candidate()
		var nearby_clam: Node3D = ocean.find_nearby_oxygen_clam(diver.global_position, 4.8) if is_instance_valid(ocean) else null
		var nearby_relic: Node3D = ocean.find_nearby_relic(diver.global_position, 4.6) if is_instance_valid(ocean) else null
		var salvage_cand: Node3D = _find_salvageable_creature()

		if is_instance_valid(active_submarine):
			prompt = ""
		elif active_mount_idx >= 0 and active_mount_idx < tamed_beasts.size():
			prompt = "G / E  离开坐骑【%s】(转为跟随护卫)" % str(tamed_beasts[active_mount_idx]["name"])
		elif is_instance_valid(tame_cand):
			prompt = "E  契约驯服【%s】  /  V  无人机气球活捕 (★★★ 完美食材)" % str(tame_cand.get_meta("name", "巨兽"))
		elif is_instance_valid(target) and str(target.get_meta("kind", "")) in ["mother_tree_essence", "ancient_star_core", "tree_seed"]:
			prompt = "E  采摘收取【%s】" % str(target.get_meta("name", "母树核心遗物"))
		elif is_instance_valid(target) and str(target.get_meta("kind", "")) == "explorer_relic" and not bool(target.get_meta("collected", false)):
			prompt = "E  收集远古遗珍【%s】(+120G · 全材料+1 · 攻击+10 · 泳速+4%%)" % str(target.get_meta("name", "远古遗珍"))
		elif is_instance_valid(nearby_relic):
			prompt = "E  收集远古遗珍【%s】(+120G · 全材料+1 · 攻击+10 · 泳速+4%%)" % str(nearby_relic.get_meta("name", "远古遗珍"))
		elif is_instance_valid(target) and str(target.get_meta("kind", "")) == "outpost_tower":
			var o_name_t: String = str(target.get_meta("name", "科考前哨站"))
			if bool(target.get_meta("activated", false)):
				prompt = "E  接入【%s】全域海图跃迁  /  Tab  前哨制造台 (自动补氧)" % o_name_t
			else:
				prompt = "E  激活【%s】声呐中继塔 (点亮海图 · 解锁跃迁 · +150G)" % o_name_t
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
			var c_stars: int = clampi(int(target.get_meta("catch_stars", 2)), 1, 3)
			var st_str := "★".repeat(c_stars) + "☆".repeat(3 - c_stars)
			prompt = "E  搜刮【%s】(%s)  /  V  无人机打捞回收 (直升 ★★★ 完美品质)" % [c_name, st_str]
		elif is_instance_valid(salvage_cand):
			var s_c_name: String = str(salvage_cand.get_meta("name", "海洋生物"))
			prompt = "V  召唤【柯布拉水下无人机】气球活捕【%s】(获 ★★★ 完美食材与图鉴)" % s_c_name
		elif is_instance_valid(nearby_clam):
			prompt = "E  触发【深海发光巨砗磲】氧气气泡泉涌 (+35 O₂ / +15 HP)"
		elif is_instance_valid(target) and str(target.get_meta("kind", "")) == "submarine":
			var sub: Node = target.get_meta("sub_ref", target)
			var s_name: String = str(sub.sub_name if "sub_name" in sub else "潜水艇")
			prompt = "E  登舰驾驶【%s】(高速航行 / 车载鱼雷系统)" % s_name
		elif is_instance_valid(nearby_sub):
			var s_name: String = str(nearby_sub.sub_name if "sub_name" in nearby_sub else "潜水艇")
			prompt = "E  登舰驾驶【%s】(高速航行 / 车载鱼雷系统)" % s_name
		elif is_instance_valid(nearby_outpost):
			var o_name_n: String = str(nearby_outpost.get_meta("name", "科考前哨站"))
			if bool(nearby_outpost.get_meta("activated", false)):
				prompt = "E  接入【%s】全域海图跃迁  /  Tab  前哨制造台 (自动补氧)" % o_name_n
			else:
				prompt = "E  激活【%s】声呐中继塔 (点亮海图 · 解锁跃迁 · +150G)" % o_name_n
		elif is_instance_valid(target):
			var target_kind: String = str(target.get_meta("kind"))
			if target_kind == "black_box":
				prompt = "E  调查失事科考潜艇黑匣子 (读取深渊日志)"
			elif target_kind == "fish_small":
				prompt = "E  活捕发光小金鱼 (+25 HP / +20 O₂ · ★★★ 寿司食材)"
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
		"deployed_beast_count": _get_deployed_beast_count(),
		"active_mount_idx": active_mount_idx,
		"is_mounted": active_mount_idx >= 0,
		"mother_tree_active": ocean.mother_tree_spawned_flag if is_instance_valid(ocean) else false,
		"distance_mother_tree": diver.global_position.distance_to(Vector3(0, -125, -340)),
		"tree_items_collected": int(state.inventory.get("mother_tree_essence", 0)) + int(state.inventory.get("ancient_star_core", 0)) + int(state.inventory.get("tree_seed", 0)),
		"conquered_bosses_count": ocean.conquered_bosses.size() if is_instance_valid(ocean) else 0,
		"escape_crafted": state.escape_crafted,
		"shield_active": diver.shield_active,
		"gold": state.gold,
		"dishes_served": state.dishes_served,
		"sushi_reputation": state.sushi_reputation,
		"drone_charges": state.drone_charges,
		"max_drone_charges": state.max_drone_charges,
		"current_weight": state.get_current_weight(),
		"max_weight": state.get_max_weight(),
		"overweight": state.is_overweight(),
		"marinca_cards": state.marinca_cards,
		"marinca_species": Survival.MARINCA_SPECIES,
		"three_star_count": state.get_three_star_count(),
		"sushi_recipes": Survival.SUSHI_RECIPES,
		"cobra_items": Survival.COBRA_SHOP_ITEMS,
		"player_pos": diver.global_position,
		"player_forward": -diver.camera.global_basis.z if is_instance_valid(diver.camera) else -diver.global_basis.z,
		"surveyed_cells": state.surveyed_cells,
		"survey_ratio": state.get_survey_ratio(),
		"exploration_progress": state.get_exploration_progress(LANDMARKS.size(), Ocean.OUTPOST_SPECS.size(), Ocean.RELIC_SPECS.size()),
		"explorer_rank": state.get_explorer_rank(LANDMARKS.size(), Ocean.OUTPOST_SPECS.size(), Ocean.RELIC_SPECS.size()),
		"landmarks_dict": LANDMARKS,
		"discovered_landmarks": state.landmarks_discovered,
		"map_outposts": ocean.get_map_outpost_snapshots() if is_instance_valid(ocean) else [],
		"unlocked_outposts": state.unlocked_outposts,
		"outposts_unlocked_count": state.unlocked_outposts.size(),
		"outposts_total": Ocean.OUTPOST_SPECS.size(),
		"map_relics": ocean.get_map_relic_snapshots() if is_instance_valid(ocean) else [],
		"relics_collected_count": state.collected_relics.size(),
		"relics_total": Ocean.RELIC_SPECS.size(),
		"map_submarines": ocean.get_map_submarine_snapshots() if is_instance_valid(ocean) else [],
		"pinged_targets": state.pinged_targets,
		"has_waypoint": state.has_custom_waypoint,
		"waypoint_pos": state.custom_waypoint,
		"sonar_cooldown": state.sonar_cooldown
	})
	if screen == "play":
		_update_home_marker(distance)
		_update_waypoint_marker()

	# 屏幕受击红光与低氧频闪
	if damage_flash_time > 0.0:
		damage_flash_time = maxf(0.0, damage_flash_time - delta)
		screen_shade.color = Color(0.85, 0.08, 0.05, clampf(damage_flash_time * 0.75, 0.0, 0.55))
	else:
		var low_oxy: bool = screen == "play" and state.mode != "explore" and state.oxygen < 15.0
		var shade_alpha: float = (0.22 if low_oxy else 0.0) * (0.65 + sin(Time.get_ticks_msec() * 0.006) * 0.35)
		var next_shade := Color(0.5, 0.05, 0.035, shade_alpha)
		if screen_shade.color != next_shade:
			screen_shade.color = next_shade

func _update_target() -> void:
	target = null
	var camera: Camera3D = diver.camera
	var from: Vector3 = diver.get_aim_origin() if diver.has_method("get_aim_origin") else camera.global_position
	var diver_rid: RID = diver.get_rid()
	if _target_ray_excluded_rid != diver_rid:
		_target_ray_excluded_rid = diver_rid
		_target_ray_exclude = [diver_rid]
		_target_ray_query.exclude = _target_ray_exclude
	_target_ray_query.collision_mask = 3
	_target_ray_query.from = from
	_target_ray_query.to = from - camera.global_basis.z * 6.5
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(_target_ray_query)
	if hit.is_empty() and is_instance_valid(camera):
		var cam_from := camera.global_position
		_target_ray_query.from = cam_from
		_target_ray_query.to = cam_from - camera.global_basis.z * 10.5
		hit = space.intersect_ray(_target_ray_query)
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
	if is_instance_valid(target) and str(target.get_meta("kind", "")) == "explorer_relic" and not bool(target.get_meta("collected", false)):
		_collect_explorer_relic(target)
		return
	var nearby_relic: Node3D = ocean.find_nearby_relic(diver.global_position, 4.6) if is_instance_valid(ocean) else null
	if is_instance_valid(nearby_relic):
		_collect_explorer_relic(nearby_relic)
		return
	if is_instance_valid(target) and str(target.get_meta("kind", "")) == "outpost_tower":
		_interact_outpost(target)
		return
	if (is_instance_valid(target) and str(target.get_meta("kind", "")) == "escape_console") or diver.global_position.distance_to(Ocean.HOME + Vector3(2.2, 0.4, 1.4)) < 4.5:
		_interact_escape_console()
		return
	if is_instance_valid(target) and bool(target.get_meta("dead", false)) and bool(target.get_meta("can_loot", false)) and not bool(target.get_meta("looted", false)):
		_loot_corpse(target)
		return
	var nearby_clam: Node3D = ocean.find_nearby_oxygen_clam(diver.global_position, 4.8) if is_instance_valid(ocean) else null
	if is_instance_valid(nearby_clam) and (not is_instance_valid(target) or str(target.get_meta("kind", "")) == "giant_clam"):
		_activate_oxygen_clam(nearby_clam)
		return
	if is_instance_valid(target) and str(target.get_meta("kind", "")) == "submarine":
		var sub: Node = target.get_meta("sub_ref", target)
		_board_submarine(sub)
		return
	var nearby_sub: Node3D = ocean.find_nearby_submarine(diver.global_position, 8.5) if is_instance_valid(ocean) else null
	if is_instance_valid(nearby_sub):
		_board_submarine(nearby_sub)
		return
	var nearby_outpost: Node3D = ocean.find_nearby_outpost(diver.global_position, 9.5) if is_instance_valid(ocean) else null
	if is_instance_valid(nearby_outpost) and not is_instance_valid(target):
		_interact_outpost(nearby_outpost)
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
		var m_fish: Dictionary = state.register_marinca_catch("fish_small", "发光小金鱼", 3)
		CombatVFX.spawn_star_rating(self, target.global_position, 3, "发光小金鱼")
		hud.toast("活捕发光小金鱼 (★★★)！生命 +%d · 氧气 +%d · 玛琳卡赏金 +%dG (按 B 可做握寿司)" % [
			int(result["health_gain"]), int(result["oxygen_gain"]), int(m_fish.get("reward_gold", 36))
		])
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
	var stars: int = clampi(int(body.get_meta("catch_stars", 2)), 1, 3)
	var star_str := "★".repeat(stars) + "☆".repeat(3 - stars)
	var is_pred: bool = k in ["predator", "abyss", "sea_spider"] or k.begins_with("boss")
	var meat_gain: int = 1 if stars == 1 else (2 if stars == 2 else 4)
	var skin_gain: int = 1 if stars < 3 else 2
	state.inventory["fish_meat"] = int(state.inventory.get("fish_meat", 0)) + meat_gain
	state.inventory["creature_skin"] = int(state.inventory.get("creature_skin", 0)) + skin_gain
	state.inventory["chitin"] = int(state.inventory.get("chitin", 0)) + 1
	if is_pred:
		state.inventory["creature_tooth"] = int(state.inventory.get("creature_tooth", 0)) + (2 if stars == 3 else 1)
	var m_info: Dictionary = state.register_marinca_catch(k, c_name, stars)
	CombatVFX.spawn_star_rating(self, body.global_position, stars, c_name)
	UnderwaterAudio.play_sound(get_tree(), "knife_hit", -4.0, 1.2)
	hud.toast("已搜刮【%s】(%s)：生肉 +%d、兽皮 +%d · 玛琳卡赏金 +%dG (按 B 进入深海寿司吧)" % [
		c_name, star_str, meat_gain, skin_gain, int(m_info.get("reward_gold", 20))
	])
	var tw := create_tween()
	tw.tween_interval(1.5)
	tw.tween_property(body, "scale", Vector3.ZERO, 0.4)
	tw.tween_callback(body.queue_free)

func _activate_oxygen_clam(clam: Node3D) -> void:
	if not is_instance_valid(clam):
		return
	clam.set_meta("clam_cooldown", 20.0)
	if state.mode != "explore":
		state.oxygen = minf(state.max_oxygen, state.oxygen + 35.0)
	state.health = minf(state.max_health, state.health + 15.0)
	CombatVFX.spawn_clam_bubbles(self, clam.global_position)
	UnderwaterAudio.play_sound(get_tree(), "clam_bubble", -3.0, 1.0)
	hud.toast("【发光巨砗磲氧气泉涌】吸入富氧珍珠气泡！氧气 +35 秒 · 生命 +15")

func _find_salvageable_creature() -> Node3D:
	if not is_instance_valid(ocean):
		return null
	if is_instance_valid(target) and bool(target.get_meta("dead", false)) and bool(target.get_meta("can_loot", false)) and not bool(target.get_meta("looted", false)):
		return target
	var best: Node3D = null
	var best_d: float = 10.5
	for c in ocean.get_creatures():
		if not is_instance_valid(c) or bool(c.get_meta("tamed", false)) or bool(c.get_meta("looted", false)):
			continue
		var kind: String = str(c.get_meta("kind", ""))
		if kind.begins_with("boss") or c == ocean.water_dragon or c in ocean.boss_nodes.values():
			continue
		var d: float = diver.global_position.distance_to(c.global_position)
		if d > best_d:
			continue
		var is_dead_lootable: bool = bool(c.get_meta("dead", false)) and bool(c.get_meta("can_loot", false))
		var is_controlled: bool = float(c.get_meta("freeze_timer", 0.0)) > 0.0 or c.has_node("StasisAura") or float(c.get_meta("stun_timer", 0.0)) > 0.0
		var hp_ratio: float = float(c.get_meta("health", 100.0)) / maxf(float(c.get_meta("max_health", 100.0)), 1.0)
		if is_dead_lootable or is_controlled or hp_ratio <= 0.45:
			best_d = d
			best = c
	return best

func _trigger_drone_salvage() -> void:
	if state.mode != "explore" and state.drone_charges <= 0:
		hud.toast("【无人机配额耗尽】返回逃生舱自动补满，或按 B 在柯布拉商店升级扩容箱！")
		return
	var cand: Node3D = _find_salvageable_creature()
	if not is_instance_valid(cand):
		hud.toast("【柯布拉打捞无人机】10米内无受控/残血生物或海兽遗骸！先用蓝光枪静滞或击伤猎物再按 V 打捞")
		return
	if state.mode != "explore":
		state.drone_charges = maxi(0, state.drone_charges - 1)
	var res: Dictionary = ocean.salvage_creature_with_drone(cand)
	var c_name: String = str(res.get("name", "海洋生物"))
	var kind: String = str(res.get("kind", "fish"))
	var pos: Vector3 = res.get("pos", diver.global_position)
	CombatVFX.spawn_salvage_balloon(self, pos)
	CombatVFX.spawn_star_rating(self, pos, 3, c_name)
	UnderwaterAudio.play_sound(get_tree(), "drone_salvage", -2.5, 1.0)
	state.inventory["fish_meat"] = int(state.inventory.get("fish_meat", 0)) + 4
	state.inventory["creature_skin"] = int(state.inventory.get("creature_skin", 0)) + 2
	state.inventory["chitin"] = int(state.inventory.get("chitin", 0)) + 2
	state.inventory["creature_tooth"] = int(state.inventory.get("creature_tooth", 0)) + 2
	var m_res: Dictionary = state.register_marinca_catch(kind, c_name, 3)
	hud.toast("🎈【无人机 ★★★ 完美打捞】已用浮力袋回收【%s】！获顶级生肉 ×4 · 玛琳卡赏金 +%dG (余 %d 次)" % [
		c_name, int(m_res.get("reward_gold", 45)), state.drone_charges
	])

func _on_sushi_cook(dish_id: String) -> void:
	var res: Dictionary = state.cook_and_serve_sushi(dish_id)
	if not bool(res.get("ok", false)):
		hud.toast(str(res.get("error", "食材不足")))
		return
	diver.damage_bonus = state.weapon_attack_bonus
	UnderwaterAudio.play_sound(get_tree(), "sushi_serve", -2.5, 1.0)
	hud.toast("🍣【班乔料理出锅】已售出【%s】！收入 +%d 金币 · %s" % [
		str(res.get("name", "料理")), int(res.get("gold_earned", 0)), str(res.get("buff", ""))
	])

func _on_sushi_serve_all() -> void:
	var res: Dictionary = state.serve_all_surplus_fish()
	if not bool(res.get("ok", false)):
		hud.toast(str(res.get("error", "暂无可售出的鲜鱼或生肉")))
		return
	UnderwaterAudio.play_sound(get_tree(), "sushi_serve", -2.0, 1.08)
	hud.toast("🏮【班乔寿司吧夜营业大捷】共售出 %d 份深海料理！赚取 +%d 金币 · 背包负重已清空！" % [
		int(res.get("plates", 1)), int(res.get("gold_earned", 0))
	])

func _on_cobra_buy(item_id: String) -> void:
	var res: Dictionary = state.buy_cobra_item(item_id)
	if not bool(res.get("ok", false)):
		hud.toast(str(res.get("error", "金币不足")))
		return
	diver.damage_bonus = state.weapon_attack_bonus
	UnderwaterAudio.play_sound(get_tree(), "sushi_serve", -2.5, 0.92)
	hud.toast("🛒【柯布拉深海商店】已购入【%s】！%s" % [
		str(res.get("name", "装备")), str(res.get("effect", ""))
	])

func _board_submarine(sub: Node3D) -> void:
	active_submarine = sub as Submarine
	if not active_submarine:
		return
	active_submarine.board(diver)
	diver.cancel_gun_charge()
	if diver.booster_active:
		diver.toggle_booster()
	diver.rotation.y = active_submarine.rotation.y
	diver.set_submarine_mode(true, active_submarine.sub_type, active_submarine.get_rid())
	diver.global_position = active_submarine.get_camera_anchor_position()
	diver._update_third_person_camera(0.0)
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
	diver.set_submarine_mode(false)
	if is_instance_valid(diver.weapon_mount):
		diver.weapon_mount.visible = true
	var sub_name_left := active_submarine.sub_name
	active_submarine = null
	UnderwaterAudio.play_sound(get_tree(), "sub_exit", -4.0, 1.0)
	hud.toast("已离开【%s】，恢复自由潜水游动" % sub_name_left)

func _craft(recipe: String) -> void:
	var near_outpost_station := false
	if is_instance_valid(ocean):
		var out_station: Node3D = ocean.find_nearby_outpost(diver.global_position, 9.5)
		near_outpost_station = is_instance_valid(out_station) and bool(out_station.get_meta("activated", false))
	var error: String = state.craft(recipe, diver.position.distance_to(Ocean.HOME) < 7.0 or near_outpost_station)
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
	waypoint_arrow = Label.new()
	waypoint_arrow.add_theme_font_override("font", preload("res://assets/fonts/NotoSansSC-Subset.otf"))
	waypoint_arrow.add_theme_font_size_override("font_size", 16)
	waypoint_arrow.add_theme_color_override("font_color", Color(1.0, 0.82, 0.32))
	waypoint_arrow.add_theme_color_override("font_shadow_color", Color(0.0, 0.08, 0.14, 0.85))
	waypoint_arrow.add_theme_constant_override("shadow_offset_x", 1)
	waypoint_arrow.add_theme_constant_override("shadow_offset_y", 1)
	waypoint_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	waypoint_arrow.visible = false
	overlay.add_child(waypoint_arrow)

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

func _update_waypoint_marker() -> void:
	if not is_instance_valid(waypoint_arrow):
		return
	waypoint_arrow.visible = screen == "play" and state.has_custom_waypoint
	if not waypoint_arrow.visible:
		return
	var camera: Camera3D = diver.camera
	var viewport_size := get_viewport().get_visible_rect().size
	var wp: Vector3 = state.custom_waypoint
	var dist_wp: float = diver.global_position.distance_to(wp)
	var p := camera.unproject_position(wp)
	if camera.is_position_behind(wp):
		p = Vector2(36.0, viewport_size.y * 0.5)
		waypoint_arrow.text = "✦ 标点 ↶  %dm" % roundi(dist_wp)
	else:
		waypoint_arrow.text = "✦ 导航标点  %dm" % roundi(dist_wp)
	waypoint_arrow.position = Vector2(clampf(p.x - 65, 24, viewport_size.x - 190), clampf(p.y - 26, 110, viewport_size.y - 190))

func _check_explorer_rank_up() -> void:
	var new_lv: int = state.get_explorer_rank_level(LANDMARKS.size(), Ocean.OUTPOST_SPECS.size(), Ocean.RELIC_SPECS.size())
	if new_lv > state.explorer_rank_level:
		state.explorer_rank_level = new_lv
		var rank_title: String = state.get_explorer_rank(LANDMARKS.size(), Ocean.OUTPOST_SPECS.size(), Ocean.RELIC_SPECS.size())
		var reward_g: int = new_lv * 100
		state.gold += reward_g
		UnderwaterAudio.play_sound(get_tree(), "tame_success", -2.0, 1.15)
		CombatVFX.spawn_tame_ring(self, diver.global_position, 5.5)
		hud.toast("★【探索家晋升 Lv.%d】荣获头衔「%s」！协会嘉奖 +%dG" % [new_lv, rank_title, reward_g])

func _interact_outpost(outpost: Node3D) -> void:
	if not is_instance_valid(outpost):
		return
	var outpost_id: String = str(outpost.get_meta("outpost_id", ""))
	var outpost_name: String = str(outpost.get_meta("name", "科考前哨站"))
	if state.unlocked_outposts.has(outpost_id):
		_set_screen("map")
		hud.toast("⬡ 已接入【%s】海图终端 · 选择已解锁节点即可洋流快速跃迁" % outpost_name)
		return
	var res: Dictionary = state.unlock_outpost(outpost_id, outpost_name)
	ocean.set_outpost_activated_visual(outpost)
	state.reveal_world_area(outpost.global_position, 290.0)
	for lm_id: String in LANDMARKS:
		var lpos: Vector3 = LANDMARKS[lm_id]["pos"]
		if outpost.global_position.distance_to(lpos) <= 360.0:
			state.pinged_targets["lm_" + lm_id] = true
	for rel in ocean.explorer_relics:
		if is_instance_valid(rel) and not bool(rel.get_meta("collected", false)):
			if outpost.global_position.distance_to(rel.global_position) <= 360.0:
				state.pinged_targets[str(rel.get_meta("relic_id", ""))] = true
	CombatVFX.spawn_tame_ring(self, outpost.global_position + Vector3(0, 3.0, 0), 8.5)
	UnderwaterAudio.play_sound(get_tree(), "tame_success", -2.0, 1.05)
	_check_explorer_rank_up()
	hud.toast("⬡【科考前哨联网】%s 已激活！周边海图已揭开 · 解锁跃迁与制造 · +%dG" % [
		outpost_name, int(res.get("gold_reward", 150))
	])

func _collect_explorer_relic(relic: Node3D) -> void:
	if not is_instance_valid(relic) or bool(relic.get_meta("collected", false)):
		return
	var relic_id: String = str(relic.get_meta("relic_id", ""))
	var relic_name: String = str(relic.get_meta("name", "远古遗珍"))
	relic.set_meta("collected", true)
	relic.visible = false
	if relic is CollisionObject3D:
		relic.collision_layer = 0
	if target == relic:
		target = null
	var res: Dictionary = state.collect_relic(relic_id, relic_name)
	diver.damage_bonus = state.weapon_attack_bonus
	diver.explorer_speed_mult = 1.0 + state.explorer_speed_bonus
	state.reveal_world_area(relic.global_position, 125.0)
	CombatVFX.spawn_tame_ring(self, diver.global_position, 4.2)
	UnderwaterAudio.play_sound(get_tree(), "tame_success", -2.0, 1.2)
	_check_explorer_rank_up()
	hud.toast("◆【远古遗珍入手】获得「%s」(%d/%d)！+120G · 全材料+1 · 攻击+10 · 泳速提升" % [
		relic_name, int(res.get("collected_count", state.collected_relics.size())), Ocean.RELIC_SPECS.size()
	])

func _trigger_sonar_ping() -> bool:
	if state.sonar_cooldown > 0.0:
		hud.toast("📡 广域声呐电容充能中 (%.1f 秒)" % state.sonar_cooldown)
		return false
	state.sonar_cooldown = 4.0 if state.mode == "explore" else 8.0
	var origin: Vector3 = diver.global_position
	state.reveal_world_area(origin, 220.0)
	var ping_count := 0
	var nearest_hint := ""
	var nearest_d := 99999.0
	for lm_id: String in LANDMARKS:
		if state.landmarks_discovered.has(lm_id):
			continue
		var lpos: Vector3 = LANDMARKS[lm_id]["pos"]
		var d_lm := origin.distance_to(lpos)
		if d_lm <= 340.0:
			state.pinged_targets["lm_" + lm_id] = true
			ping_count += 1
			if d_lm < nearest_d:
				nearest_d = d_lm
				nearest_hint = "%s (%dm)" % [str(LANDMARKS[lm_id]["name"]), roundi(d_lm)]
	if is_instance_valid(ocean):
		for rel in ocean.explorer_relics:
			if is_instance_valid(rel) and not bool(rel.get_meta("collected", false)):
				var d_rel := origin.distance_to(rel.global_position)
				if d_rel <= 340.0:
					state.pinged_targets[str(rel.get_meta("relic_id", ""))] = true
					ping_count += 1
					if d_rel < nearest_d:
						nearest_d = d_rel
						nearest_hint = "遗珍·%s (%dm)" % [str(rel.get_meta("name", "远古遗珍")), roundi(d_rel)]
		for out in ocean.outposts:
			if is_instance_valid(out) and not bool(out.get_meta("activated", false)):
				var d_out := origin.distance_to(out.global_position)
				if d_out < nearest_d:
					nearest_d = d_out
					nearest_hint = "%s (%dm)" % [str(out.get_meta("name", "科考前哨")), roundi(d_out)]
	CombatVFX.spawn_tame_ring(self, origin, 9.0)
	UnderwaterAudio.play_sound(get_tree(), "sonic_blast", -4.5, 1.25)
	_check_explorer_rank_up()
	if ping_count > 0:
		hud.toast("📡【广域声呐回波】已揭开周边海图，探测到 %d 处未知信标！最近：%s" % [ping_count, nearest_hint])
	elif not nearest_hint.is_empty():
		hud.toast("📡【广域声呐回波】周边海图已更新 · 最近未激活前哨：%s" % nearest_hint)
	else:
		hud.toast("📡【广域声呐回波】周边 220m 海图扇区已完整测绘！")
	return true

func _on_map_waypoint_set(world_xz: Vector2) -> void:
	var cx := clampf(world_xz.x, -890.0, 890.0)
	var cz := clampf(world_xz.y, -890.0, 890.0)
	var wy := clampf(Ocean.terrain_height(cx, cz) + 4.0, -OceanDepths.MAX_DIVE_DEPTH + 2.0, -2.5)
	state.set_custom_waypoint(Vector3(cx, wy, cz))
	hud.toast("✦ 已设置导航标点 [X:%+d Z:%+d]" % [roundi(cx), roundi(cz)])

func _on_map_waypoint_cleared() -> void:
	state.clear_custom_waypoint()
	hud.toast("已清除自定义导航标点")

func _on_fast_travel_requested(target_id: String, world_pos: Vector3, target_name: String) -> void:
	var allowed := false
	var dest_pos := world_pos
	var is_station := false
	if target_id == "home_lifepod":
		allowed = true
		is_station = true
		dest_pos = Vector3(0.0, -7.5, 15.0)
	elif state.unlocked_outposts.has(target_id):
		allowed = true
		is_station = true
		var fy := Ocean.terrain_height(world_pos.x, world_pos.z + 5.5)
		dest_pos = Vector3(world_pos.x, clampf(maxf(world_pos.y + 3.8, fy + 2.8), -OceanDepths.MAX_DIVE_DEPTH + 2.0, -1.8), world_pos.z + 5.5)
	elif target_id.begins_with("lm_") and state.landmarks_discovered.has(target_id.trim_prefix("lm_")):
		allowed = true
		var fy_lm := Ocean.terrain_height(world_pos.x, world_pos.z + 4.0)
		dest_pos = Vector3(world_pos.x, clampf(maxf(world_pos.y + 3.0, fy_lm + 3.0), -OceanDepths.MAX_DIVE_DEPTH + 2.0, -1.8), world_pos.z + 4.0)
	elif state.landmarks_discovered.has(target_id):
		allowed = true
		var fy_d := Ocean.terrain_height(world_pos.x, world_pos.z + 4.0)
		dest_pos = Vector3(world_pos.x, clampf(maxf(world_pos.y + 3.0, fy_d + 3.0), -OceanDepths.MAX_DIVE_DEPTH + 2.0, -1.8), world_pos.z + 4.0)
	if not allowed:
		hud.toast("🔒 该节点尚未解锁洋流跃迁，请先潜航前往勘测或激活前哨站")
		return
	if is_instance_valid(active_submarine):
		_disembark_submarine()
	if is_instance_valid(ocean) and ocean.boss_active:
		ocean.reset_boss_encounter()
	dest_pos.x = clampf(dest_pos.x, -890.0, 890.0)
	dest_pos.z = clampf(dest_pos.z, -890.0, 890.0)
	if active_mount_idx >= 0 and active_mount_idx < tamed_beasts.size():
		var m_node: Node3D = tamed_beasts[active_mount_idx].get("node")
		if is_instance_valid(m_node):
			m_node.position = dest_pos
			diver.global_position = m_node.global_position + m_node.global_basis * Vector3(0, 1.8, 0.2)
		else:
			diver.global_position = dest_pos
	else:
		diver.global_position = dest_pos
	diver.velocity = Vector3.ZERO
	diver._update_third_person_camera(0.0)
	var f_slot := 0
	for i in range(tamed_beasts.size()):
		if i == active_mount_idx or not bool(tamed_beasts[i].get("deployed", true)):
			continue
		var fn: Node3D = tamed_beasts[i].get("node")
		if is_instance_valid(fn) and not bool(fn.get_meta("dead", false)):
			fn.position = dest_pos + diver.global_basis.z * (4.0 + float(f_slot % 4) * 2.5)
			f_slot += 1
	if is_station and state.mode != "explore":
		state.oxygen = state.max_oxygen
		state.health = state.max_health
		state.drone_charges = state.max_drone_charges
	state.fast_travel_count += 1
	state.reveal_world_area(dest_pos, 150.0)
	_set_screen("play")
	CombatVFX.spawn_tame_ring(self, dest_pos, 5.5)
	UnderwaterAudio.play_sound(get_tree(), "warp_escape", -3.0, 1.1)
	hud.toast("⚡【洋流跃迁完成】已抵达【%s】" % target_name)

func _world_check() -> void:
	await get_tree().physics_frame
	# Verify expanded fish populations and predator counts
	var initial_res_count: int = ocean.resources.size()
	var initial_sfish_count: int = ocean.small_fish.size()
	assert(initial_res_count >= 100, "Should have at least 100 resources across open world")
	assert(ocean.fish.size() >= 134, "Should have at least 134 total fish across all tiers")
	assert(initial_sfish_count >= 54, "Should have at least 54 small edible fish")
	assert(ocean.predators.size() >= 32, "Should have at least 32 aggressive predators")
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
	assert(ocean.resources.size() == initial_res_count - 1)

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
	assert(ocean.small_fish.size() == initial_sfish_count - 1)

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
	diver.position = Vector3(0, -9.0, 17.0)
	diver.rotation = Vector3.ZERO
	diver.camera.rotation = Vector3(-0.08, 0, 0)
	diver._update_third_person_camera(0.0)
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
	if is_instance_valid(diver.lamp_fill):
		diver.lamp_fill.visible = true
	var deep_y: float = ocean.floor_height(15.0, -152.0) + 3.2
	diver.position = Vector3(15.0, deep_y, -152.0)
	diver.rotation = Vector3.ZERO
	diver.camera.rotation = Vector3(-0.14, 0.0, 0.0)
	diver._update_third_person_camera(0.0)
	ocean.set_depth(-deep_y)
	if ocean.has_node("SeabedEcology"):
		ocean.get_node("SeabedEcology").update_observer(diver.position, 0.1)
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs/deep-sea.png")

	# Capture sunken research submarine shipwreck in exploration mode
	var wreck_y: float = ocean.floor_height(37.5, -53.2) + 4.2
	diver.position = Vector3(37.5, wreck_y, -53.2)
	diver.rotation = Vector3.ZERO
	diver.camera.rotation = Vector3(-0.10, -1.28, 0.0)
	if is_instance_valid(diver.diver_model):
		diver.diver_model.rotation.y = -1.28
	diver._update_third_person_camera(0.0)
	ocean.set_depth(-wreck_y)
	if ocean.has_node("SeabedEcology"):
		ocean.get_node("SeabedEcology").update_observer(diver.position, 0.1)
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
		if not bool(b.get("deployed", true)):
			continue
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
		"damage": 55.0 if kind.begins_with("boss") else 32.0,
		"deployed": true
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
	tamed_beasts[idx]["deployed"] = true
	var m_node: Node3D = tamed_beasts[idx].get("node")
	if is_instance_valid(m_node):
		m_node.visible = true
	active_mount_idx = idx
	var kind_str: String = str(tamed_beasts[idx].get("kind", ""))
	diver.set_mount_mode(true, kind_str.begins_with("boss"))
	UnderwaterAudio.play_sound(get_tree(), "mount_ride")
	hud.toast("【驾驭坐骑】已骑乘【%s】· W 前进 / C 下降 / 空格 上升 / A D 转向 / G 离鞍 / O 收纳" % tamed_beasts[idx]["name"])

func _dismount_beast() -> void:
	if active_mount_idx >= 0:
		hud.toast("【已下坐骑】契约战兽进入护卫阵型跟随！")
		active_mount_idx = -1
	diver.set_mount_mode(false)

func _has_deployed_beasts() -> bool:
	return _get_deployed_beast_count() > 0

func _get_deployed_beast_count() -> int:
	var cnt := 0
	for b in tamed_beasts:
		var n: Node3D = b.get("node")
		if bool(b.get("deployed", true)) and is_instance_valid(n) and not bool(n.get_meta("dead", false)):
			cnt += 1
	return cnt

func _handle_mount_board_key() -> void:
	if screen == "mount_board":
		_set_screen("play")
		return
	if screen != "play":
		return
	# 平时不用坐骑按一下 O 键：将外面的坐骑全部收入囊中；再按一下 O 键：弹出【坐骑应援板】页面
	if _has_deployed_beasts():
		_store_all_tamed_beasts()
	else:
		_set_screen("mount_board")

func _store_all_tamed_beasts() -> void:
	if tamed_beasts.is_empty():
		hud.toast("尚未驯服任何坐骑！静滞残血生物后按 E 即可契约驯服")
		return
	if active_mount_idx >= 0:
		_dismount_beast()
	companion_attack_target = null
	has_target_pos = false
	if is_instance_valid(persistent_red_dot):
		persistent_red_dot.queue_free()
		persistent_red_dot = null
	for i in range(tamed_beasts.size()):
		tamed_beasts[i]["deployed"] = false
		var n: Node3D = tamed_beasts[i].get("node")
		if is_instance_valid(n):
			n.visible = false
	UnderwaterAudio.play_sound(get_tree(), "pet_recall")
	CombatVFX.spawn_tame_ring(self, diver.global_position, 3.5)
	hud.toast("【坐骑已收纳】全部契约坐骑已收入囊中！再按一下 O 键打开【坐骑应援板】召唤出战")

func _on_mount_board_select(idx: int) -> void:
	if idx < 0 or idx >= tamed_beasts.size():
		return
	tamed_beasts[idx]["deployed"] = true
	var n: Node3D = tamed_beasts[idx].get("node")
	if is_instance_valid(n):
		n.visible = true
		var row: int = int(idx / 4)
		var col: int = (idx % 4) - 2
		var rear_dist: float = 3.6 + float(row) * 3.2
		var lateral_spread: float = (float(col) + 0.5) * 2.4
		n.position = diver.global_position + diver.global_basis.z * rear_dist + diver.global_basis.x * lateral_spread
		n.set_meta("companion_atk_cd", 0.0)
	UnderwaterAudio.play_sound(get_tree(), "tame_success", -2.5, 1.08)
	CombatVFX.spawn_tame_ring(self, diver.global_position, 4.0)
	hud.toast("【应援板召唤】【%s】已从应援板召唤出战！" % str(tamed_beasts[idx].get("name", "契约坐骑")))

func _on_mount_board_select_all() -> void:
	if tamed_beasts.is_empty():
		hud.toast("当前应援板暂无已驯服生物！")
		return
	var summoned_cnt := 0
	for i in range(tamed_beasts.size()):
		tamed_beasts[i]["deployed"] = true
		var n: Node3D = tamed_beasts[i].get("node")
		if is_instance_valid(n) and not bool(n.get_meta("dead", false)):
			n.visible = true
			var row: int = int(summoned_cnt / 4)
			var col: int = (summoned_cnt % 4) - 2
			var rear_dist: float = 3.6 + float(row) * 3.2
			var lateral_spread: float = (float(col) + 0.5) * 2.4
			n.position = diver.global_position + diver.global_basis.z * rear_dist + diver.global_basis.x * lateral_spread
			n.set_meta("companion_atk_cd", 0.0)
			summoned_cnt += 1
	UnderwaterAudio.play_sound(get_tree(), "tame_success")
	CombatVFX.spawn_tame_ring(self, diver.global_position, 5.0)
	hud.toast("【全选应援出战】全部 %d 只契约坐骑已召唤出战！" % summoned_cnt)

func register_creature_attack(attacker: Node3D) -> void:
	if not is_instance_valid(attacker) or bool(attacker.get_meta("tamed", false)) or bool(attacker.get_meta("dead", false)):
		return
	attacker.set_meta("has_attacked_player", true)
	if _has_deployed_beasts() and companion_attack_target != attacker:
		companion_attack_target = attacker
		has_target_pos = false
		hud.toast("【方舟防卫反击】遭到【%s】先手攻击！出战坐骑立即反击！" % str(attacker.get_meta("name", "野生生物")))

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

	# 方舟中立防卫模式：仅当野生生物先发动攻击 (has_attacked_player == true) 时，所解锁并召唤的坐骑才会去反击；若对方未攻击，坐骑按兵不动
	if companion_attack_target == null and not has_target_pos and _has_deployed_beasts() and is_instance_valid(ocean):
		var living_creatures: Array[Node3D] = []
		for c in ocean.get_creatures(): living_creatures.append(c)
		for p in ocean.predators: living_creatures.append(p)
		for w in ocean.sea_wolves: living_creatures.append(w)
		var closest_aggressor: Node3D = null
		var closest_d: float = 16.0
		for cand in living_creatures:
			if is_instance_valid(cand) and not bool(cand.get_meta("tamed", false)) and not bool(cand.get_meta("dead", false)):
				if bool(cand.get_meta("has_attacked_player", false)):
					var d: float = cand.global_position.distance_to(player_leader_pos)
					if d <= closest_d:
						closest_d = d
						closest_aggressor = cand
		if closest_aggressor != null:
			companion_attack_target = closest_aggressor
			hud.toast("【方舟防卫反击】锁定先手攻击者【%s】！坐骑自动出击！" % str(closest_aggressor.get_meta("name", "敌对生物")))

	var num_followers := 0
	for b in tamed_beasts:
		if bool(b.get("deployed", true)) and is_instance_valid(b.get("node")) and not bool(b["node"].get_meta("dead", false)):
			num_followers += 1
	if active_mount_idx >= 0:
		num_followers = max(0, num_followers - 1)

	var follower_slot := 0
	for i in range(tamed_beasts.size()):
		var beast_entry: Dictionary = tamed_beasts[i]
		var f_node: Node3D = beast_entry.get("node")
		if not is_instance_valid(f_node) or bool(f_node.get_meta("dead", false)):
			continue
		if not bool(beast_entry.get("deployed", true)):
			f_node.visible = false
			continue
		f_node.visible = true
		if i == active_mount_idx:
			# 若当前正骑乘该坐骑且存在反击目标，接近目标时坐骑同样可撕咬反击
			if is_instance_valid(companion_attack_target):
				var m_cd: float = maxf(0.0, float(f_node.get_meta("companion_atk_cd", 0.0)) - delta)
				f_node.set_meta("companion_atk_cd", m_cd)
				var dist_m: float = f_node.global_position.distance_to(companion_attack_target.global_position)
				if dist_m < 5.0 and m_cd <= 0.0:
					f_node.set_meta("companion_atk_cd", 1.2)
					var m_mult: float = pow(2.0, maxf(0.0, float(tamed_beasts.size() - 1)))
					var m_dmg: float = float(beast_entry.get("damage", 40.0)) * m_mult
					ocean.damage_creature(companion_attack_target, m_dmg)
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
		if not bool(tamed_beasts[i].get("deployed", true)):
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
	var aim_origin: Vector3 = diver.get_aim_origin() if diver.has_method("get_aim_origin") else camera.global_position
	var scan: Dictionary = ocean.trace_laser(aim_origin, direction, 2500.0, excluded_rid)
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
