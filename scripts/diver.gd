extends CharacterBody3D

var camera: Camera3D
var lamp: SpotLight3D
var lamp_fill: OmniLight3D
var active: bool = false
var upgraded: bool = false
var exploration_mode: bool = false
var sprinting: bool = false

# Weapon viewmodel system
var weapon_mount: Node3D
var weapon_nodes: Dictionary = {}
var weapon_base_trans: Dictionary = {}
var current_weapon: String = "knife"
var attack_cooldown: float = 0.0
var attack_anim_time: float = 0.0
var attack_anim_duration: float = 0.25
var muzzle_flash: OmniLight3D

# Attack reinforcement and procedural impact feedback
var damage_bonus: float = 0.0
var camera_punch: Vector3 = Vector3.ZERO
var camera_trauma: float = 0.0
var hitstop_timer: float = 0.0
var hitstop_jitter: Vector3 = Vector3.ZERO
var mouse_lag: Vector2 = Vector2.ZERO
var mouse_lag_target: Vector2 = Vector2.ZERO

# Procedural weapon attack combos & dynamic feedback
var combo_index: int = 0
var combo_timer: float = 0.0
var equip_anim_time: float = 0.0
var equip_duration: float = 0.22
var fluid_drag_pos: Vector3 = Vector3.ZERO
var fluid_drag_rot: Vector3 = Vector3.ZERO
# VFX Nodes
var cleave_mesh: MeshInstance3D
var sonic_ring: MeshInstance3D
var blade_bubbles: CPUParticles3D
var vfx_timer: float = 0.0
var vfx_max_timer: float = 0.0
var marine_snow: CPUParticles3D
var biomod_dash_unlocked: bool = false
var biomod_vision_unlocked: bool = false
var dash_cooldown: float = 0.0

func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.3
	shape.shape = capsule
	add_child(shape)

	camera = Camera3D.new()
	camera.fov = 78.0
	camera.near = 0.12
	camera.far = 240.0
	camera.current = true
	add_child(camera)

	# High-performance volumetric flashlight: wide beam penetrating deep sea
	lamp = SpotLight3D.new()
	lamp.light_color = Color(0.78, 0.96, 1.0)
	lamp.light_energy = 9.0
	lamp.spot_range = 85.0
	lamp.spot_angle = 55.0
	lamp.spot_attenuation = 0.8
	lamp.visible = false
	camera.add_child(lamp)

	# Soft ambient fill light for immediate diver perimeter
	lamp_fill = OmniLight3D.new()
	lamp_fill.light_color = Color(0.68, 0.92, 1.0)
	lamp_fill.light_energy = 2.4
	lamp_fill.omni_range = 16.0
	lamp_fill.omni_attenuation = 0.85
	lamp_fill.visible = false
	camera.add_child(lamp_fill)

	# Marine snow micro-plankton particles attached to diver viewpoint
	marine_snow = CPUParticles3D.new()
	marine_snow.name = "MarineSnow"
	marine_snow.amount = 75
	marine_snow.lifetime = 4.0
	marine_snow.preprocess = 2.0
	marine_snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	marine_snow.emission_box_extents = Vector3(6.5, 4.5, 7.5)
	marine_snow.position = Vector3(0, 0, -5.0)
	marine_snow.direction = Vector3(0, -0.2, -0.6)
	marine_snow.gravity = Vector3(0, -0.05, 0)
	marine_snow.initial_velocity_min = 0.08
	marine_snow.initial_velocity_max = 0.22
	var s_mesh := SphereMesh.new()
	s_mesh.radius = 0.018
	s_mesh.height = 0.036
	var s_mat := StandardMaterial3D.new()
	s_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	s_mat.albedo_color = Color(0.72, 0.94, 1.0, 0.38)
	s_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	s_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	s_mesh.material = s_mat
	marine_snow.mesh = s_mesh
	camera.add_child(marine_snow)

	_setup_weapons()
	_setup_vfx()

func toggle_lamp() -> bool:
	lamp.visible = not lamp.visible
	if is_instance_valid(lamp_fill):
		lamp_fill.visible = lamp.visible
	return lamp.visible

func trigger_dash(oxygen_available: float = 90.0) -> Dictionary:
	if not biomod_dash_unlocked:
		return {"success": false, "reason": "尚未激活涡流突进模组"}
	if dash_cooldown > 0.0:
		return {"success": false, "reason": "涡流冲刺充能中 (%.1fs)" % dash_cooldown}
	if not exploration_mode and oxygen_available < 10.0:
		return {"success": false, "reason": "氧气不足无法启动涡流推进"}
	dash_cooldown = 4.5
	var forward: Vector3 = -camera.global_basis.z if (is_instance_valid(camera) and camera.is_inside_tree()) else -basis.z
	velocity += forward * 16.0
	camera_punch = Vector3(-0.065, 0.0, 0.035)
	add_trauma(0.35)
	if is_instance_valid(muzzle_flash):
		muzzle_flash.light_energy = 4.0
	return {"success": true, "cost": 12.0}

func _setup_weapons() -> void:
	weapon_mount = Node3D.new()
	weapon_mount.name = "WeaponMount"
	camera.add_child(weapon_mount)
	var weapon_files := {
		"knife": "res://assets/models/weapon_knife.glb",
		"axe": "res://assets/models/weapon_axe.glb",
		"sonic": "res://assets/models/weapon_sonic.glb"
	}
	var transforms := {
		"knife": {"pos": Vector3(0.24, -0.18, -0.42), "rot": Vector3(8.0, -12.0, -15.0), "scale": 0.85},
		"axe": {"pos": Vector3(0.26, -0.22, -0.45), "rot": Vector3(15.0, -15.0, -12.0), "scale": 0.9},
		"sonic": {"pos": Vector3(0.22, -0.18, -0.48), "rot": Vector3(2.0, -6.0, 0.0), "scale": 0.85}
	}
	for id: String in weapon_files:
		var scene_res = load(weapon_files[id])
		if scene_res:
			var node: Node3D = scene_res.instantiate()
			weapon_mount.add_child(node)
			var cfg: Dictionary = transforms[id]
			node.position = cfg["pos"]
			node.rotation_degrees = cfg["rot"]
			node.scale = Vector3.ONE * cfg["scale"]
			weapon_base_trans[id] = {"pos": node.position, "rot": node.rotation_degrees}
			weapon_nodes[id] = node

	muzzle_flash = OmniLight3D.new()
	muzzle_flash.light_color = Color(0.35, 0.92, 1.0)
	muzzle_flash.light_energy = 0.0
	muzzle_flash.omni_range = 16.0
	muzzle_flash.position = Vector3(0.22, -0.16, -0.9)
	weapon_mount.add_child(muzzle_flash)

	# 空化微气泡发射器（安装在挥刃轨迹前端）
	blade_bubbles = CPUParticles3D.new()
	blade_bubbles.name = "BladeCavitationBubbles"
	blade_bubbles.emitting = false
	blade_bubbles.one_shot = true
	blade_bubbles.explosiveness = 0.85
	blade_bubbles.lifetime = 0.45
	blade_bubbles.amount = 24
	blade_bubbles.position = Vector3(0.12, -0.1, -0.8)
	blade_bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	blade_bubbles.emission_box_extents = Vector3(0.3, 0.25, 0.3)
	blade_bubbles.direction = Vector3(-0.5, 0.2, -1.0)
	blade_bubbles.spread = 45.0
	blade_bubbles.initial_velocity_min = 1.2
	blade_bubbles.initial_velocity_max = 3.2
	blade_bubbles.damping_min = 4.0
	blade_bubbles.damping_max = 6.0
	blade_bubbles.gravity = Vector3(0, 0.8, 0)
	var bb_mesh := SphereMesh.new()
	bb_mesh.radius = 0.016
	bb_mesh.height = 0.032
	var bb_mat := StandardMaterial3D.new()
	bb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bb_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bb_mat.albedo_color = Color(0.8, 0.96, 1.0, 0.55)
	bb_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bb_mesh.material = bb_mat
	blade_bubbles.mesh = bb_mesh
	weapon_mount.add_child(blade_bubbles)

	set_weapon("knife")

func _setup_vfx() -> void:
	# 动态水下光弧 (Dynamic Crescent Cleave Slash Ribbon)
	cleave_mesh = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.82
	torus.outer_radius = 1.35
	torus.rings = 24
	torus.ring_segments = 12
	cleave_mesh.mesh = torus
	var cleave_mat := StandardMaterial3D.new()
	cleave_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cleave_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cleave_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	cleave_mat.albedo_color = Color(0.4, 0.95, 1.0, 0.85)
	cleave_mesh.material_override = cleave_mat
	cleave_mesh.position = Vector3(0.0, -0.05, -1.25)
	cleave_mesh.rotation_degrees = Vector3(35.0, -25.0, 45.0)
	cleave_mesh.visible = false
	weapon_mount.add_child(cleave_mesh)

	# 水下千米声波激波同心环 (Kilometer Sonic Shockwave Ring)
	sonic_ring = MeshInstance3D.new()
	var ring_torus := TorusMesh.new()
	ring_torus.inner_radius = 0.65
	ring_torus.outer_radius = 0.95
	ring_torus.rings = 28
	ring_torus.ring_segments = 14
	sonic_ring.mesh = ring_torus
	var sonic_mat := StandardMaterial3D.new()
	sonic_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sonic_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sonic_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sonic_mat.albedo_color = Color(0.55, 0.88, 1.0, 0.9)
	sonic_ring.material_override = sonic_mat
	sonic_ring.position = Vector3(0.22, -0.16, -1.2)
	sonic_ring.visible = false
	weapon_mount.add_child(sonic_ring)

func set_weapon(weapon_id: String) -> void:
	if current_weapon != weapon_id:
		if weapon_nodes.has(current_weapon):
			var old_base: Dictionary = weapon_base_trans.get(current_weapon, {})
			if not old_base.is_empty():
				weapon_nodes[current_weapon].position = old_base["pos"]
				weapon_nodes[current_weapon].rotation_degrees = old_base["rot"]
		attack_anim_time = 0.0
		equip_anim_time = equip_duration
		_trigger_equip_vfx()
	current_weapon = weapon_id
	combo_index = 0
	combo_timer = 0.0
	for id: String in weapon_nodes:
		weapon_nodes[id].visible = (id == current_weapon)

func _trigger_equip_vfx() -> void:
	if is_instance_valid(blade_bubbles):
		blade_bubbles.restart()
		blade_bubbles.emitting = true
func add_trauma(amount: float) -> void:
	camera_trauma = clampf(camera_trauma + amount, 0.0, 1.0)

func trigger_hitstop(duration: float = 0.05) -> void:
	hitstop_timer = duration

func attack() -> Dictionary:
	if attack_cooldown > 0.0:
		return {}
	equip_anim_time = 0.0
	# 连击推进与超时重置
	if combo_timer > 0.0:
		if current_weapon == "knife":
			combo_index = (combo_index + 1) % 3
		elif current_weapon == "axe":
			combo_index = (combo_index + 1) % 2
		else:
			combo_index = 0
	else:
		combo_index = 0

	var result := {}
	match current_weapon:
		"knife":
			attack_cooldown = 0.28
			attack_anim_duration = 0.26
			combo_timer = attack_cooldown + 0.40
			var final_dmg: float = 32.0 + damage_bonus
			result = {
				"weapon": "knife",
				"name": "潜水战术刀",
				"damage": final_dmg,
				"base_damage": 32.0,
				"bonus": damage_bonus,
				"range": 6.2,
				"is_sonic": false,
				"knockback": 6.5,
				"cleave_angle": 0.42,
				"max_targets": 3,
				"combo": combo_index + 1,
				"active_delay": 0.06 if combo_index < 2 else 0.08
			}
			# 3段连击不同的打击后坐力与光刃姿态
			if combo_index == 0:
				camera_punch = Vector3(-0.022, 0.018, 0.0)
				add_trauma(0.12)
				_trigger_slash_vfx(Vector3(32.0, -38.0, 48.0), Vector3(0.65, 0.65, 0.65), Color(0.35, 0.95, 1.0, 0.85), 0.22)
			elif combo_index == 1:
				camera_punch = Vector3(0.018, -0.022, 0.0)
				add_trauma(0.14)
				_trigger_slash_vfx(Vector3(-28.0, 36.0, -42.0), Vector3(0.72, 0.72, 0.72), Color(0.42, 1.0, 0.88, 0.85), 0.22)
			else:
				# 第3段贯通刺
				camera_punch = Vector3(-0.035, 0.0, 0.0)
				add_trauma(0.20)
				_trigger_slash_vfx(Vector3(0.0, 0.0, 0.0), Vector3(0.5, 0.5, 0.95), Color(0.25, 0.92, 1.0, 0.9), 0.24)

		"axe":
			attack_cooldown = 0.55
			attack_anim_duration = 0.50
			combo_timer = attack_cooldown + 0.45
			var final_dmg: float = 70.0 + damage_bonus
			result = {
				"weapon": "axe",
				"name": "破拆战斧",
				"damage": final_dmg,
				"base_damage": 70.0,
				"bonus": damage_bonus,
				"range": 8.5,
				"is_sonic": false,
				"knockback": 16.0,
				"cleave_angle": 0.12,  # Wide 165° forward arc
				"max_targets": 99,     # Sweeps all predators in front
				"combo": combo_index + 1,
				"active_delay": 0.13
			}
			camera_punch = Vector3(-0.075, -0.052, 0.0) if combo_index == 0 else Vector3(-0.075, 0.052, 0.0)
			add_trauma(0.42)
			var arc_rot := Vector3(42.0, -22.0, 58.0) if combo_index == 0 else Vector3(-35.0, 26.0, -52.0)
			_trigger_slash_vfx(arc_rot, Vector3(1.38, 1.38, 1.38), Color(0.5, 0.98, 1.0, 0.95), 0.38)

		"sonic":
			attack_cooldown = 0.45
			attack_anim_duration = 0.40
			combo_timer = 0.0
			var final_dmg: float = 100.0 + damage_bonus * 1.5
			result = {
				"weapon": "sonic",
				"name": "声波脉冲枪",
				"damage": final_dmg,
				"base_damage": 100.0,
				"bonus": damage_bonus,
				"range": 3000.0,       # Kilometers long range!
				"is_sonic": true,
				"knockback": 35.0,
				"cleave_angle": 0.35,  # Broad penetrating shockwave cone
				"max_targets": 99,
				"combo": 1,
				"active_delay": 0.0
			}
			camera_punch = Vector3(-0.095, 0.0, 0.0)
			add_trauma(0.38)
			if is_instance_valid(muzzle_flash):
				muzzle_flash.light_energy = 14.0
				muzzle_flash.omni_range = 38.0
			if is_instance_valid(sonic_ring):
				sonic_ring.visible = true
				sonic_ring.scale = Vector3(0.45, 0.45, 0.45)
				sonic_ring.position = Vector3(0.22, -0.16, -0.75)
				vfx_timer = 0.42
				vfx_max_timer = 0.42

	attack_anim_time = attack_anim_duration
	return result

func _trigger_slash_vfx(rot_deg: Vector3, target_scale: Vector3, color: Color, duration: float) -> void:
	if is_instance_valid(cleave_mesh):
		cleave_mesh.visible = true
		cleave_mesh.rotation_degrees = rot_deg
		cleave_mesh.scale = target_scale
		var mat = cleave_mesh.material_override
		if mat is StandardMaterial3D:
			mat.albedo_color = color
		vfx_timer = duration
		vfx_max_timer = duration
	if is_instance_valid(blade_bubbles):
		blade_bubbles.restart()
		blade_bubbles.emitting = true

func _unhandled_input(event: InputEvent) -> void:
	if active and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * 0.0022)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * 0.0022, -1.45, 1.45)
		# 视角转动惯性滞后 (Viewmodel lag behind mouse)
		mouse_lag_target.x = clampf(mouse_lag_target.x - event.relative.x * 0.0006, -0.04, 0.04)
		mouse_lag_target.y = clampf(mouse_lag_target.y + event.relative.y * 0.0006, -0.035, 0.035)

func _physics_process(delta: float) -> void:
	if not active:
		velocity = Vector3.ZERO
		return
	var input := Input.get_vector("left", "right", "forward", "backward")
	var direction := camera.global_basis * Vector3(input.x, 0, input.y)
	direction.y += Input.get_axis("descend", "ascend")
	sprinting = Input.is_action_pressed("sprint") and direction.length_squared() > 0.1
	var base_speed: float = 8.5 if (upgraded or exploration_mode) else 5.2
	var speed: float = base_speed * (1.6 if sprinting else 1.0)
	velocity = velocity.lerp(direction.limit_length() * speed, 1.0 - exp(-delta * 4.0))
	move_and_slide()

	# Expanded ocean world boundary clamping (500m wide, depth down to 115m)
	position.x = clampf(position.x, -240.0, 240.0)
	position.z = clampf(position.z, -270.0, 110.0)
	position.y = clampf(position.y, -115.0, 1.2)

	camera.fov = lerpf(camera.fov, 84.0 if sprinting else 78.0, delta * 3.0)

func _process(delta: float) -> void:
	if attack_cooldown > 0.0:
		attack_cooldown = maxf(0.0, attack_cooldown - delta)
	if combo_timer > 0.0:
		combo_timer = maxf(0.0, combo_timer - delta)
		if combo_timer <= 0.0:
			combo_index = 0
	if dash_cooldown > 0.0:
		dash_cooldown = maxf(0.0, dash_cooldown - delta)
	hitstop_jitter = Vector3.ZERO
	if hitstop_timer > 0.0:
		hitstop_timer = maxf(0.0, hitstop_timer - delta)
		hitstop_jitter = Vector3(randf() - 0.5, randf() - 0.5, randf() - 0.5) * 0.018
	elif attack_anim_time > 0.0:
		attack_anim_time = maxf(0.0, attack_anim_time - delta)
	if is_instance_valid(muzzle_flash):
		if muzzle_flash.light_energy > 0.0:
			muzzle_flash.light_energy = maxf(0.0, muzzle_flash.light_energy - delta * 28.0)
		elif current_weapon == "sonic":
			# 声波脉冲枪待机能量核心呼吸发光
			var idle_glow := sin(Time.get_ticks_msec() * 0.005) * 0.5 + 0.5
			muzzle_flash.light_energy = idle_glow * 1.5
			muzzle_flash.omni_range = 6.0

	# Biomod Vision: adapt fill lighting in deep abyss
	if is_instance_valid(lamp_fill):
		if biomod_vision_unlocked and position.y < -45.0:
			lamp_fill.light_energy = 3.8
			lamp_fill.omni_range = 22.0
		elif not lamp_fill.visible:
			lamp_fill.light_energy = 2.4
			lamp_fill.omni_range = 16.0
	# 鼠标惯性阻尼滞后解算 (Spring-damper mouse lag)
	mouse_lag = mouse_lag.lerp(mouse_lag_target, delta * 14.0)
	mouse_lag_target = mouse_lag_target.lerp(Vector2.ZERO, delta * 8.0)

	# Camera punch & trauma-based shake
	if is_instance_valid(camera):
		if camera_punch.length_squared() > 0.00001:
			camera.rotation += camera_punch * delta * 18.0
			camera_punch = camera_punch.lerp(Vector3.ZERO, delta * 12.0)

		if camera_trauma > 0.0:
			var trauma_pwr: float = camera_trauma * camera_trauma
			var shake_roll := (randf() * 2.0 - 1.0) * trauma_pwr * 0.024
			var shake_pitch := (randf() * 2.0 - 1.0) * trauma_pwr * 0.020
			camera.rotation.z += shake_roll
			camera.rotation.x += shake_pitch
			camera_trauma = maxf(0.0, camera_trauma - delta * 3.2)
	# Visual effects update
	if vfx_timer > 0.0:
		vfx_timer = maxf(0.0, vfx_timer - delta)
		var progress: float = 1.0 - (vfx_timer / maxf(vfx_max_timer, 0.001))
		if is_instance_valid(cleave_mesh) and cleave_mesh.visible:
			cleave_mesh.scale += Vector3.ONE * delta * 4.2
			cleave_mesh.rotate_z(delta * 9.5)
			var mat = cleave_mesh.material_override
			if mat is StandardMaterial3D:
				mat.albedo_color.a = clampf((1.0 - progress) * 0.9, 0.0, 1.0)
			if vfx_timer <= 0.0:
				cleave_mesh.visible = false

		if is_instance_valid(sonic_ring) and sonic_ring.visible:
			sonic_ring.scale += Vector3.ONE * delta * 9.5
			sonic_ring.position.z -= delta * 24.0
			var s_mat = sonic_ring.material_override
			if s_mat is StandardMaterial3D:
				s_mat.albedo_color.a = clampf((1.0 - progress) * 0.95, 0.0, 1.0)
			if vfx_timer <= 0.0:
				sonic_ring.visible = false

	if not is_instance_valid(weapon_mount):
		return
	var active_node: Node3D = weapon_nodes.get(current_weapon, null)
	if not active_node:
		return
	var base: Dictionary = weapon_base_trans.get(current_weapon, {})
	if base.is_empty():
		return
	var base_pos: Vector3 = base["pos"]
	var base_rot: Vector3 = base["rot"]

	# Subtle natural swimming sway
	var sway_time := Time.get_ticks_msec() * 0.003
	var sway_x := sin(sway_time) * (0.012 if sprinting else 0.006)
	var sway_y := cos(sway_time * 2.0) * (0.010 if sprinting else 0.005)

	# 冲刺姿态调整 (冲刺时压枪下移，平稳贴胸)
	var sprint_offset := Vector3(0.02, -0.06, 0.08) if sprinting else Vector3.ZERO
	var sprint_rot := Vector3(-12.0, 8.0, 5.0) if sprinting else Vector3.ZERO

	# 攻击微卡肉（Hitstop）冻结动画进度推进
	var anim_offset_pos := Vector3.ZERO
	var anim_offset_rot := Vector3.ZERO

	# 冻结动画解算与抖动叠加
	var jitter := hitstop_jitter
	if attack_anim_time > 0.0:
		var progress: float = 1.0 - (attack_anim_time / attack_anim_duration)
		match current_weapon:
			"knife":
				# 战术刀 3 段水下连击动作解算
				if combo_index == 0:
					# Combo 1: 右上至左下深切斜扫
					var strike := sin(progress * PI)
					anim_offset_pos = Vector3(-0.26 * strike, -0.12 * strike, -0.34 * strike)
					anim_offset_rot = Vector3(-32.0 * strike, -62.0 * strike, 55.0 * strike)
				elif combo_index == 1:
					# Combo 2: 左下至右上反手挑削
					var strike := sin(progress * PI)
					anim_offset_pos = Vector3(0.22 * strike, 0.20 * strike, -0.28 * strike)
					anim_offset_rot = Vector3(42.0 * strike, 52.0 * strike, -48.0 * strike)
				else:
					# Combo 3: 蓄力贯通突刺 (Pull back then burst thrust)
					if progress < 0.22:
						var p0 := progress / 0.22
						anim_offset_pos = Vector3(0.0, 0.02 * p0, 0.06 * p0)
						anim_offset_rot = Vector3(-5.0 * p0, 0.0, 5.0 * p0)
					else:
						var p1 := (progress - 0.22) / 0.78
						var strike := sin(p1 * PI)
						anim_offset_pos = Vector3(0.02 * strike, -0.03 * strike, -0.52 * strike)
						anim_offset_rot = Vector3(-12.0 * strike, -15.0 * strike, 26.0 * strike)

			"axe":
				if combo_index == 0:
					# 战斧 Combo 1: 右上至左下顺手重劈 (Anticipation -> Cleave -> Overshoot -> Settle)
					if progress < 0.26:
						# 阶段1: 克服水阻沉重蓄力
						var p0 := progress / 0.26
						anim_offset_pos = Vector3(0.12 * p0, 0.18 * p0, 0.06 * p0)
						anim_offset_rot = Vector3(-35.0 * p0, 48.0 * p0, -22.0 * p0)
					elif progress < 0.68:
						# 阶段2: 爆发性全屏弧面广角横扫
						var p1 := (progress - 0.26) / 0.42
						var strike := sin(p1 * PI)
						anim_offset_pos = Vector3(0.12 - 0.54 * p1, 0.18 - 0.52 * p1, -0.32 * strike)
						anim_offset_rot = Vector3(-35.0 + 130.0 * p1, 48.0 - 132.0 * p1, -22.0 - 46.0 * p1)
					else:
						# 阶段3: 惯性过冲与流体阻尼回弹
						var p2 := (progress - 0.68) / 0.32
						var settle := (1.0 - p2) * exp(-p2 * 4.5) * sin(p2 * PI * 2.5)
						anim_offset_pos = Vector3(-0.42 * (1.0 - p2), -0.34 * (1.0 - p2) + settle * 0.03, settle * 0.04)
						anim_offset_rot = Vector3(95.0 * (1.0 - p2), -84.0 * (1.0 - p2), -68.0 * (1.0 - p2) + settle * 10.0)
				else:
					# 战斧 Combo 2: 左侧至右侧反手回劈 (Mirrored reverse cleave matching reversed VFX arc)
					if progress < 0.26:
						# 阶段1: 左侧沉重收缩蓄力
						var p0 := progress / 0.26
						anim_offset_pos = Vector3(-0.16 * p0, 0.16 * p0, 0.06 * p0)
						anim_offset_rot = Vector3(-30.0 * p0, -45.0 * p0, 25.0 * p0)
					elif progress < 0.68:
						# 阶段2: 爆发性反向横扫撕裂
						var p1 := (progress - 0.26) / 0.42
						var strike := sin(p1 * PI)
						anim_offset_pos = Vector3(-0.16 + 0.58 * p1, 0.16 - 0.48 * p1, -0.32 * strike)
						anim_offset_rot = Vector3(-30.0 + 125.0 * p1, -45.0 + 130.0 * p1, 25.0 + 42.0 * p1)
					else:
						# 阶段3: 右侧过冲与流体回弹稳定
						var p2 := (progress - 0.68) / 0.32
						var settle := (1.0 - p2) * exp(-p2 * 4.5) * sin(p2 * PI * 2.5)
						anim_offset_pos = Vector3(0.42 * (1.0 - p2), -0.32 * (1.0 - p2) + settle * 0.03, settle * 0.04)
						anim_offset_rot = Vector3(95.0 * (1.0 - p2), 85.0 * (1.0 - p2), 67.0 * (1.0 - p2) - settle * 10.0)
			"sonic":
				if progress < 0.12:
					var p0 := progress / 0.12
					anim_offset_pos = Vector3(0.0, 0.12 * p0, 0.44 * p0)
					anim_offset_rot = Vector3(-42.0 * p0, 0.0, 0.0)
				else:
					var p1 := (progress - 0.12) / 0.88
					var spring := exp(-p1 * 6.5) * cos(p1 * 14.0)
					anim_offset_pos = Vector3(0.0, 0.12 * spring, 0.44 * spring)
					anim_offset_rot = Vector3(-42.0 * spring, 0.0, 0.0)
	anim_offset_pos += jitter

	# 叠加待机晃动、冲刺姿态、攻击位移动态与鼠标惯性迟滞
	var lag_pos := Vector3(mouse_lag.x, mouse_lag.y, 0)
	var lag_rot := Vector3(-mouse_lag.y * 30.0, mouse_lag.x * 40.0, -mouse_lag.x * 20.0)

	# 切换武器拔刀 procedural equip 动画
	var equip_offset_pos := Vector3.ZERO
	var equip_offset_rot := Vector3.ZERO
	if equip_anim_time > 0.0:
		equip_anim_time = maxf(0.0, equip_anim_time - delta)
		var eq_p := 1.0 - (equip_anim_time / maxf(equip_duration, 0.001))
		var eq_ease := 1.0 - pow(1.0 - eq_p, 3.0)
		var factor := 1.0 - eq_ease
		equip_offset_pos = Vector3(0.02 * factor, -0.22 * factor, 0.10 * factor)
		equip_offset_rot = Vector3(-18.0 * factor, 12.0 * factor, -8.0 * factor)

	# 水下 3D 流体阻力响应 (Dynamic fluid drag from swimming velocity)
	var local_vel := (camera.global_basis.inverse() * velocity) if is_instance_valid(camera) else velocity
	var target_fluid_pos := Vector3(
		clampf(-local_vel.x * 0.0025, -0.035, 0.035),
		clampf(-local_vel.y * 0.003, -0.04, 0.04),
		clampf(local_vel.z * 0.002, -0.03, 0.03)
	)
	var target_fluid_rot := Vector3(
		clampf(local_vel.y * 1.6, -15.0, 15.0),
		clampf(-local_vel.x * 2.2, -18.0, 18.0),
		clampf(local_vel.x * 1.4, -12.0, 12.0)
	)
	fluid_drag_pos = fluid_drag_pos.lerp(target_fluid_pos, delta * 7.5)
	fluid_drag_rot = fluid_drag_rot.lerp(target_fluid_rot, delta * 7.5)

	active_node.position = base_pos + Vector3(sway_x, sway_y, 0) + sprint_offset + anim_offset_pos + lag_pos + equip_offset_pos + fluid_drag_pos
	active_node.rotation_degrees = base_rot + sprint_rot + anim_offset_rot + lag_rot + equip_offset_rot + fluid_drag_rot
