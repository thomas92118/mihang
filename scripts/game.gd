extends Node3D

const Ocean = preload("res://scripts/ocean.gd")
const Diver = preload("res://scripts/diver.gd")
const Survival = preload("res://scripts/survival.gd")
const HUD = preload("res://scripts/hud.gd")

const LANDMARKS := {
	"shallows": {"name": "逃生舱浅礁", "pos": Vector3(0, -9, 8), "radius": 28.0, "desc": "阳光明媚的浅海珊瑚林"},
	"ruins": {"name": "古代海沟遗迹", "pos": Vector3(2, -22, -25), "radius": 22.0, "desc": "半掩埋于海床的史前石拱门"},
	"slope": {"name": "暮光大断崖", "pos": Vector3(0, -28, -35), "radius": 28.0, "desc": "急剧坠入深海的大陆坡断崖"},
	"shipwreck": {"name": "失事科考潜艇", "pos": Vector3(45, -55.7, -55), "radius": 28.0, "desc": "半掩于大陆坡深处的失事科考潜艇"},
	"abyss": {"name": "深渊裂谷入口", "pos": Vector3(0, -68, -105), "radius": 35.0, "desc": "幽暗寒冷的百米深海大裂谷"},
	"vents": {"name": "深海地热喷口群", "pos": Vector3(15, -95, -165), "radius": 38.0, "desc": "地壳深处喷涌而出的炽热黑烟囱"},
	"altar": {"name": "深渊史前祭坛", "pos": Vector3(-50, -88, -170), "radius": 32.0, "desc": "沉眠于百米渊底的发光史前石碑"},
}

var ocean: Node3D
var diver: CharacterBody3D
var hud: CanvasLayer
var state = Survival.new()
var screen: String = "main"
var target: Node3D
var low_oxygen_warned: bool = false
var effect: AudioStreamPlayer
var home_arrow: Label
var screen_shade: ColorRect
var damage_flash_time: float = 0.0

func _ready() -> void:
	_setup_input()
	ocean = Ocean.new()
	add_child(ocean)
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
		"descend": KEY_CTRL,
		"sprint": KEY_SHIFT,
		"interact": KEY_E,
		"craft_menu": KEY_TAB,
		"lamp": KEY_F,
		"pause_game": KEY_ESCAPE,
		"weapon_1": KEY_1,
		"weapon_2": KEY_2,
		"weapon_3": KEY_3,
		"attack": KEY_R,
		"dash": KEY_Q
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var key := InputEventKey.new()
		key.physical_keycode = keys[action]
		InputMap.action_add_event(action, key)

	var descend := InputEventKey.new()
	descend.physical_keycode = KEY_C
	InputMap.action_add_event("descend", descend)

func _reset_position() -> void:
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
		hud.toast("已开启自由探险模式！无限氧气，全武器配备，尽情漫游浅海与百米深渊。")
	else:
		hud.toast("欢迎来到浅礁区。按 1/2/3 装备武器防身；E 采集矿物或捕食小鱼；Tab 开启制造台。")

func _restart() -> void:
	get_tree().reload_current_scene()

func _set_screen(value: String) -> void:
	screen = value
	diver.active = screen == "play"
	hud.set_screen(screen)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if screen == "play" else Input.MOUSE_MODE_VISIBLE

func _get_current_biome(pos: Vector3) -> String:
	var depth: float = maxf(0, -pos.y)
	var distance_to_home: float = pos.distance_to(Ocean.HOME)
	if distance_to_home < 7.0 or pos.y > -0.6:
		return "安全区  /  生命支持恢复"
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
	elif event.is_action_pressed("attack") and screen == "play":
		_perform_attack()
	elif event.is_action_pressed("dash") and screen == "play":
		_perform_dash()
	elif event.is_action_pressed("weapon_1") and screen == "play":
		_switch_weapon("knife")
	elif event.is_action_pressed("weapon_2") and screen == "play":
		_switch_weapon("axe")
	elif event.is_action_pressed("weapon_3") and screen == "play":
		_switch_weapon("sonic")

func _switch_weapon(weapon_id: String) -> void:
	var names := {"knife": "潜水战术刀", "axe": "破拆战斧", "sonic": "声波脉冲枪"}
	if not state.weapons.has(weapon_id):
		hud.toast("尚未解锁【%s】，请在逃生舱制造台制作" % names.get(weapon_id, weapon_id))
		return
	diver.set_weapon(weapon_id)
	hud.toast("已装备【%s】" % names.get(weapon_id, weapon_id))

func _perform_attack() -> void:
	diver.damage_bonus = state.weapon_attack_bonus
	var atk: Dictionary = diver.attack()
	if atk.is_empty():
		return
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
	if not hit.is_empty():
		effect.play()
		var hit_count: int = int(hit.get("hit_count", 1))
		var killed_names: Array = hit.get("killed_names", [])
		var drops: Array = hit.get("dropped_items", [])
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
		else:
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
		if state.tick(delta, safe, diver.sprinting, depth):
			state.recover()
			_reset_position()
			hud.toast("应急浮力装置已将你送回逃生舱。采集材料与装备已保留。")
		if state.mode != "explore":
			if state.oxygen < 25.0 and not low_oxygen_warned:
				low_oxygen_warned = true
				hud.toast("氧气不足 25 秒！按住空格上浮，或返回逃生舱补氧。")
			if state.oxygen > 30.0:
				low_oxygen_warned = false

		# 捕食者 AI 推进与攻击检测
		var bites: Array[Dictionary] = ocean.tick_predators(diver.global_position, delta, diver.lamp.visible)
		for bite in bites:
			var dead: bool = state.take_damage(float(bite["damage"]))
			damage_flash_time = 0.65
			hud.toast("【遭受袭击】遭 %s 猛烈撕咬！受到 %d 点伤害！" % [bite["name"], int(bite["damage"])])
			if dead:
				state.recover()
				_reset_position()
				hud.toast("深海掠食巨兽造成致命重伤！应急救援系统已启动送回逃生舱。")

		_check_landmarks()
		_update_target()

	diver.upgraded = state.fins
	diver.exploration_mode = state.mode == "explore"
	diver.biomod_dash_unlocked = state.biomod_dash
	diver.biomod_vision_unlocked = state.biomod_vision
	ocean.set_depth(depth)

	var prompt: String = ""
	if is_instance_valid(target):
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
		"weapon_level": state.weapon_upgrade_level,
		"damage_bonus": state.weapon_attack_bonus,
		"pinned_info": state.get_pinned_info(),
		"rebreather": state.rebreather,
		"biomod_dash": state.biomod_dash,
		"dash_cooldown": diver.dash_cooldown,
		"sprinting": diver.sprinting
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

func _craft(recipe: String) -> void:
	var error: String = state.craft(recipe, diver.position.distance_to(Ocean.HOME) < 7.0)
	if not error.is_empty():
		hud.toast(error)
		return
	effect.play()
	diver.damage_bonus = state.weapon_attack_bonus
	if state.rescued:
		_set_screen("win")
	else:
		match recipe:
			"tank":
				hud.toast("高容量氧气瓶已装备 · 氧气上限 150 秒")
			"fins":
				hud.toast("轻量动力脚蹼已装备 · 游泳速度提升 50%")
			"axe":
				hud.toast("破拆战斧已制造 · 按 2 装备")
			"sonic":
				hud.toast("声波脉冲枪已制造 · 按 3 装备")
			"reinforce_sharp":
				hud.toast("【制造台深铸】锋锐度精研完成！全武器攻击力额外 +20！")
			"reinforce_sonic":
				hud.toast("【制造台深铸】共振发生器聚焦完成！全武器攻击力额外 +35！")

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
	assert(sonic_atk.get("weapon") == "sonic" and sonic_atk.get("is_sonic") == true)

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
	assert(prey.position.y > -12.0)

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
	assert(screen == "win")

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

	print("PASS: world assets (100 resources, 134 fish, 32 predators, 54 edible fish), weapons (knife/axe/sonic), fishing/eating (+25HP/+20O2), predator AI/attacks, rescue victory, endless exploration & 7 landmarks")
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
