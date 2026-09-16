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
var cleave_mesh: MeshInstance3D
var sonic_ring: MeshInstance3D
var vfx_timer: float = 0.0
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

	# High-performance volumetric flashlight: increased brightness, range and wide beam
	lamp = SpotLight3D.new()
	lamp.light_color = Color(0.78, 0.96, 1.0)
	lamp.light_energy = 9.0       # Upgraded from 3.6 for crystal-clear deep sea visibility
	lamp.spot_range = 85.0        # Upgraded from 38.0m for penetrating deep twilight & trenches
	lamp.spot_angle = 55.0        # Upgraded from 42.0° for a broad cone of vision
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
	if is_instance_valid(muzzle_flash):
		muzzle_flash.light_energy = 4.0
	return {"success": true, "cost": 12.0}

func _setup_weapons() -> void:
	weapon_mount = Node3D.new()
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

	set_weapon("knife")

func _setup_vfx() -> void:
	# Dramatic curved cleave arc for wide-amplitude melee sweeps
	cleave_mesh = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.8
	torus.outer_radius = 1.25
	torus.rings = 16
	torus.ring_segments = 8
	cleave_mesh.mesh = torus
	var cleave_mat := StandardMaterial3D.new()
	cleave_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cleave_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cleave_mat.albedo_color = Color(0.35, 0.95, 1.0, 0.75)
	cleave_mesh.material_override = cleave_mat
	cleave_mesh.position = Vector3(0.0, -0.1, -1.3)
	cleave_mesh.rotation_degrees = Vector3(35.0, -25.0, 45.0)
	cleave_mesh.visible = false
	weapon_mount.add_child(cleave_mesh)

	# Kilometer-scale expanding sonic shockwave ring for sonic rifle
	sonic_ring = MeshInstance3D.new()
	var ring_torus := TorusMesh.new()
	ring_torus.inner_radius = 0.6
	ring_torus.outer_radius = 0.9
	ring_torus.rings = 24
	ring_torus.ring_segments = 12
	sonic_ring.mesh = ring_torus
	var sonic_mat := StandardMaterial3D.new()
	sonic_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sonic_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sonic_mat.albedo_color = Color(0.4, 0.92, 1.0, 0.85)
	sonic_ring.material_override = sonic_mat
	sonic_ring.position = Vector3(0.22, -0.16, -1.2)
	sonic_ring.visible = false
	weapon_mount.add_child(sonic_ring)

func set_weapon(weapon_id: String) -> void:
	if current_weapon != weapon_id and weapon_nodes.has(current_weapon):
		var old_base: Dictionary = weapon_base_trans.get(current_weapon, {})
		if not old_base.is_empty():
			weapon_nodes[current_weapon].position = old_base["pos"]
			weapon_nodes[current_weapon].rotation_degrees = old_base["rot"]
		attack_anim_time = 0.0
	current_weapon = weapon_id
	for id: String in weapon_nodes:
		weapon_nodes[id].visible = (id == current_weapon)

func attack() -> Dictionary:
	if attack_cooldown > 0.0:
		return {}
	var result := {}
	match current_weapon:
		"knife":
			attack_cooldown = 0.28
			attack_anim_duration = 0.26
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
				"max_targets": 3
			}
			camera_punch = Vector3(-0.025, 0.015, 0.0)
			if is_instance_valid(cleave_mesh):
				cleave_mesh.visible = true
				cleave_mesh.scale = Vector3(0.6, 0.6, 0.6)
				vfx_timer = 0.22
		"axe":
			# Heavy two-handed breaching axe: large 165° cleave sweeping through all targets in front
			attack_cooldown = 0.55
			attack_anim_duration = 0.50
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
				"max_targets": 99      # Hits all predators in front!
			}
			camera_punch = Vector3(-0.065, -0.045, 0.0)
			if is_instance_valid(cleave_mesh):
				cleave_mesh.visible = true
				cleave_mesh.scale = Vector3(1.25, 1.25, 1.25)
				vfx_timer = 0.35
		"sonic":
			# Super long-range sonic pulse gun: 3000m range, 100 base damage, penetrates along shockwave
			attack_cooldown = 0.45
			attack_anim_duration = 0.40
			if is_instance_valid(muzzle_flash):
				muzzle_flash.light_energy = 12.0
				muzzle_flash.omni_range = 36.0
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
				"max_targets": 99      # Penetrates all enemies along the acoustic beam!
			}
			camera_punch = Vector3(-0.085, 0.0, 0.0)
			if is_instance_valid(sonic_ring):
				sonic_ring.visible = true
				sonic_ring.scale = Vector3(0.5, 0.5, 0.5)
				sonic_ring.position = Vector3(0.22, -0.16, -0.8)
				vfx_timer = 0.38
	attack_anim_time = attack_anim_duration
	return result

func _unhandled_input(event: InputEvent) -> void:
	if active and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * 0.0022)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * 0.0022, -1.45, 1.45)

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
	if dash_cooldown > 0.0:
		dash_cooldown = maxf(0.0, dash_cooldown - delta)
	if is_instance_valid(muzzle_flash) and muzzle_flash.light_energy > 0.0:
		muzzle_flash.light_energy = maxf(0.0, muzzle_flash.light_energy - delta * 26.0)

	# Biomod Vision: adapt fill lighting in deep abyss
	if biomod_vision_unlocked and position.y < -45.0:
		lamp_fill.light_energy = 3.8
		lamp_fill.omni_range = 22.0
	elif not lamp_fill.visible:
		lamp_fill.light_energy = 2.4
		lamp_fill.omni_range = 16.0

	# Camera punch / shake recovery
	if camera_punch.length_squared() > 0.00001:
		camera.rotation += camera_punch * delta * 18.0
		camera_punch = camera_punch.lerp(Vector3.ZERO, delta * 12.0)

	# Visual effects update
	if vfx_timer > 0.0:
		vfx_timer = maxf(0.0, vfx_timer - delta)
		if is_instance_valid(cleave_mesh) and cleave_mesh.visible:
			cleave_mesh.scale += Vector3.ONE * delta * 4.0
			cleave_mesh.rotate_z(delta * 8.0)
			if vfx_timer <= 0.0:
				cleave_mesh.visible = false
		if is_instance_valid(sonic_ring) and sonic_ring.visible:
			sonic_ring.scale += Vector3.ONE * delta * 8.5
			sonic_ring.position.z -= delta * 18.0
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

	# Dynamic dramatic procedural attack swings & high-amplitude recoil
	var anim_offset_pos := Vector3.ZERO
	var anim_offset_rot := Vector3.ZERO
	if attack_anim_time > 0.0:
		attack_anim_time = maxf(0.0, attack_anim_time - delta)
		var progress: float = 1.0 - (attack_anim_time / attack_anim_duration)
		var strike: float = sin(progress * PI)
		match current_weapon:
			"knife":
				# Wide diagonal slashing sweep & deep thrust
				anim_offset_pos = Vector3(-0.24 * strike, 0.14 * strike, -0.36 * strike)
				anim_offset_rot = Vector3(-38.0 * strike, -50.0 * strike, 58.0 * strike)
			"axe":
				# Massive two-handed downward & horizontal cleaving arc across full screen
				anim_offset_pos = Vector3(-0.36 * strike, -0.34 * strike, -0.26 * strike)
				anim_offset_rot = Vector3(88.0 * strike, -76.0 * strike, -62.0 * strike)
			"sonic":
				# Tremendous kickback from thousands-meter acoustic discharge
				anim_offset_pos = Vector3(0.0, 0.10 * strike, 0.38 * strike)
				anim_offset_rot = Vector3(-36.0 * strike, 0.0, 0.0)

	active_node.position = base_pos + Vector3(sway_x, sway_y, 0) + anim_offset_pos
	active_node.rotation_degrees = base_rot + anim_offset_rot
