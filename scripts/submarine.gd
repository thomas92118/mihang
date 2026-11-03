extends CharacterBody3D
class_name Submarine

signal fired_torpedo(data: Dictionary)

var sub_type: String = "scout"
var sub_name: String = "深海斥候号"
var is_piloted: bool = false
var pilot_diver: Node3D = null

var max_hull: float = 950.0
var hull: float = 950.0
var cruise_speed: float = 26.0
var boost_speed: float = 38.0
var current_speed: float = 0.0

var attack_cooldown: float = 0.0
var attack_interval: float = 0.35
var interact_radius: float = 5.8
var is_scoped: bool = false

var cockpit_seat: Marker3D
var headlights: Array[Light3D] = []
var propellers: Array[Node3D] = []
var muzzles: Array[Marker3D] = []
var escape_pods: Array[Node3D] = []
var wake_particles: CPUParticles3D
var prop_spin_speed: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = 1 | 4
	collision_mask = 1 | 2
	set_meta("kind", "submarine")
	set_meta("sub_ref", self)

func configure(type: String) -> void:
	sub_type = type
	for child in get_children():
		child.queue_free()
	headlights.clear()
	propellers.clear()
	muzzles.clear()
	escape_pods.clear()

	if type == "scout":
		_build_scout()
	elif type == "titan":
		_build_titan()
	else:
		_build_mini()

func _build_scout() -> void:
	sub_name = "深海斥候号"
	max_hull = 900.0
	hull = max_hull
	cruise_speed = 25.0
	boost_speed = 36.0
	attack_interval = 0.35
	interact_radius = 5.8

	# Main Collision Shape
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 1.45
	cap.height = 5.8
	col.shape = cap
	col.rotation.x = PI * 0.5
	add_child(col)

	var mat_hull := _mat(Color(0.92, 0.95, 0.98), 0.35, 0.25)
	var mat_accent := _mat(Color(0.08, 0.58, 0.95), 0.5, 0.2)
	var mat_dark := _mat(Color(0.08, 0.12, 0.16), 0.75, 0.35)
	var mat_glass := _mat(Color(0.18, 0.88, 1.0, 0.42), 0.1, 0.08)
	mat_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# 1. Approximate Ellipsoid Main Fuselage Hull (近似椭圆形流线型主躯干)
	_ellipsoid("MainOvalHull", Vector3(0, 0, 0), Vector3(2.7, 2.05, 5.8), mat_hull)
	_ellipsoid("VentralKeel", Vector3(0, -0.65, 0.2), Vector3(1.7, 0.85, 4.6), mat_accent)

	# 2. Transparent Oval Bubble Canopy Cockpit (椭圆全景观察座舱盖)
	_ellipsoid("CockpitCanopy", Vector3(0, 0.38, -0.7), Vector3(1.75, 1.35, 2.3), mat_glass)

	# Cockpit seat for driver camera
	cockpit_seat = Marker3D.new()
	cockpit_seat.position = Vector3(0, 0.45, -0.65)
	add_child(cockpit_seat)

	# 3. Front Torpedo Launch Hardpoints (前置双联装导引鱼雷发射管)
	for side in [-1.0, 1.0]:
		_tube(Vector3(side * 0.95, -0.32, -1.8), Vector3(side * 0.95, -0.32, -2.7), 0.16, mat_dark)
		var muzzle := Marker3D.new()
		muzzle.position = Vector3(side * 0.95, -0.32, -2.8)
		add_child(muzzle)
		muzzles.append(muzzle)

	# 4. Escape Pods on Both Flanks (在潜艇两旁挂载救生舱)
	for side in [-1.0, 1.0]:
		var pod_pos := Vector3(side * 1.85, -0.05, 0.25)
		_build_escape_pod(pod_pos, Vector3(0.85, 0.72, 2.2), "斥候救生舱 " + ("左" if side < 0 else "右"), side)

	# 5. Lateral Ducted Thrusters with Spinning Screws
	for side in [-1.0, 1.0]:
		var pylon_pos := Vector3(side * 1.6, -0.15, 0.6)
		_tube(Vector3(side * 1.2, -0.15, 0.6), pylon_pos, 0.12, mat_dark)
		_tube(pylon_pos - Vector3(0, 0, 0.9), pylon_pos + Vector3(0, 0, 0.9), 0.45, mat_hull)
		_ring(pylon_pos + Vector3(0, 0, 0.92), 0.46, 0.05, mat_accent)

		var prop := Node3D.new()
		prop.position = pylon_pos + Vector3(0, 0, 1.05)
		add_child(prop)
		_box("Blade1", Vector3.ZERO, Vector3(0.08, 0.72, 0.06), mat_dark, prop)
		_box("Blade2", Vector3.ZERO, Vector3(0.72, 0.08, 0.06), mat_dark, prop)
		propellers.append(prop)

	# Stabilizer Oval Fins
	var fin_top := _ellipsoid("FinTop", Vector3(0, 1.05, 1.6), Vector3(0.12, 0.75, 1.4), mat_accent)
	fin_top.rotation.x = -0.35
	for side in [-1.0, 1.0]:
		var fin_side := _ellipsoid("FinSide", Vector3(side * 1.45, 0.1, 1.8), Vector3(0.95, 0.12, 1.1), mat_accent)
		fin_side.rotation.z = side * 0.18

	# Dual Front High-Power Floodlights
	for side in [-1.0, 1.0]:
		var light := SpotLight3D.new()
		light.position = Vector3(side * 0.75, 0.12, -2.2)
		light.spot_range = 75.0
		light.spot_angle = 50.0
		light.light_color = Color(0.88, 0.98, 1.0)
		light.light_energy = 5.8
		add_child(light)
		headlights.append(light)

	_setup_wake_particles(Vector3(0, 0, 2.7), 0.45)

func _build_titan() -> void:
	sub_name = "泰坦远征号"
	max_hull = 2800.0
	hull = max_hull
	cruise_speed = 20.0
	boost_speed = 28.0
	attack_interval = 0.95
	interact_radius = 12.0

	# Collision Shape matching giant hull
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 3.2
	cap.height = 24.0
	col.shape = cap
	col.rotation.x = PI * 0.5
	add_child(col)

	var mat_armor := _mat(Color(0.12, 0.16, 0.22), 0.75, 0.35)
	var mat_stripe := _mat(Color(0.95, 0.58, 0.12), 0.5, 0.35)
	var mat_dark := _mat(Color(0.04, 0.06, 0.08), 0.8, 0.45)
	var mat_glass := _mat(Color(0.15, 0.95, 0.85, 0.55), 0.1, 0.1)
	mat_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# 1. Approximate Ellipsoid Giant Hull (百米海沟巨型近似椭圆形重装耐压壳体)
	_ellipsoid("TitanOvalHull", Vector3(0, 0, 0), Vector3(7.4, 6.4, 24.5), mat_armor)
	_ellipsoid("TitanKeelPod", Vector3(0, -2.4, 0.5), Vector3(5.6, 2.6, 20.0), mat_dark)

	# 2. Forward Panoramic Command Bridge Viewports (椭圆穹顶前瞻指挥桥楼)
	_ellipsoid("BridgeDome", Vector3(0, 2.1, -7.5), Vector3(4.4, 2.2, 5.8), mat_armor)
	for i in range(4):
		var x_pos: float = (i - 1.5) * 1.05
		_box("WindowPane", Vector3(x_pos, 2.25, -10.1), Vector3(0.9, 0.85, 0.25), mat_glass)

	cockpit_seat = Marker3D.new()
	cockpit_seat.position = Vector3(0, 2.35, -9.0)
	add_child(cockpit_seat)

	# 3. Streamlined Oval Conning Tower Sail & Sensors
	_ellipsoid("SailFin", Vector3(0, 3.8, -1.0), Vector3(2.2, 3.2, 6.5), mat_stripe)
	_tube(Vector3(0, 5.4, 0.5), Vector3(0, 7.8, 0.5), 0.18, mat_dark)
	_tube(Vector3(0.5, 5.4, -1.5), Vector3(0.5, 7.2, -1.5), 0.14, mat_dark)

	# 4. Four Large Heavy Rescue Escape Pods on Both Flanks (在巨型潜艇两旁放4座大型救生舱)
	for side in [-1.0, 1.0]:
		var pod_f := Vector3(side * 3.8, 0.4, -3.8)
		_build_escape_pod(pod_f, Vector3(1.65, 1.35, 4.2), "泰坦重装救生舱 " + ("左前" if side < 0 else "右前"), side)
		var pod_r := Vector3(side * 3.8, 0.4, 4.2)
		_build_escape_pod(pod_r, Vector3(1.65, 1.35, 4.2), "泰坦重装救生舱 " + ("左后" if side < 0 else "右后"), side)

	# 5. Heavy Torpedo Hardpoints (Quad Launch Tubes)
	for side in [-1.0, 1.0]:
		for row in [-1.0, 1.0]:
			var tube_pos := Vector3(side * 1.6, -1.2 + row * 0.7, -11.6)
			_tube(tube_pos + Vector3(0, 0, 1.5), tube_pos - Vector3(0, 0, 0.8), 0.32, mat_dark)
			var muzzle := Marker3D.new()
			muzzle.position = tube_pos - Vector3(0, 0, 1.0)
			add_child(muzzle)
			muzzles.append(muzzle)

	# 6. Four Massive Propulsion Turbines at Stern
	for side in [-1.0, 1.0]:
		for row in [-1.0, 1.0]:
			var duct_pos := Vector3(side * 2.0, row * 1.5, 11.2)
			_tube(duct_pos - Vector3(0, 0, 2.0), duct_pos + Vector3(0, 0, 1.5), 0.95, mat_dark)
			_ring(duct_pos + Vector3(0, 0, 1.5), 0.98, 0.12, mat_stripe)

			var prop := Node3D.new()
			prop.position = duct_pos + Vector3(0, 0, 1.7)
			add_child(prop)
			_box("TitanBlade1", Vector3.ZERO, Vector3(0.16, 1.6, 0.12), mat_armor, prop)
			_box("TitanBlade2", Vector3.ZERO, Vector3(1.6, 0.16, 0.12), mat_armor, prop)
			propellers.append(prop)

	# Quad High-Power Floodlight Array
	for side in [-1.0, 1.0]:
		var light_upper := SpotLight3D.new()
		light_upper.position = Vector3(side * 1.8, 2.4, -10.4)
		light_upper.spot_range = 95.0
		light_upper.spot_angle = 55.0
		light_upper.light_color = Color(1.0, 0.95, 0.88)
		light_upper.light_energy = 8.0
		add_child(light_upper)
		headlights.append(light_upper)

		var light_lower := SpotLight3D.new()
		light_lower.position = Vector3(side * 2.2, -1.8, -10.4)
		light_lower.spot_range = 85.0
		light_lower.spot_angle = 60.0
		light_lower.light_color = Color(0.4, 0.92, 1.0)
		light_lower.light_energy = 6.0
		add_child(light_lower)
		headlights.append(light_lower)

	# Top Warning Strobe Light
	var beacon := OmniLight3D.new()
	beacon.position = Vector3(0, 7.8, 0.5)
	beacon.light_color = Color(1.0, 0.35, 0.1)
	beacon.light_energy = 4.5
	beacon.omni_range = 35.0
	add_child(beacon)

	_setup_wake_particles(Vector3(0, 0, 13.5), 1.6)

func _build_mini() -> void:
	sub_name = "微型脉冲潜艇"
	max_hull = 650.0
	hull = max_hull
	cruise_speed = 28.0
	boost_speed = 40.0
	attack_interval = 0.28
	interact_radius = 4.8

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 1.15
	cap.height = 3.2
	col.shape = cap
	add_child(col)

	var mat_hull := _mat(Color(0.85, 0.94, 1.0), 0.45, 0.2)
	var mat_accent := _mat(Color(0.12, 0.75, 1.0), 0.6, 0.2)
	var mat_dark := _mat(Color(0.06, 0.1, 0.14), 0.8, 0.35)
	var mat_glass := _mat(Color(0.25, 0.95, 0.9, 0.45), 0.1, 0.05)
	mat_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# 1. Vertical Upright Ellipsoid Hull (竖着的椭圆形微型潜艇机体)
	_ellipsoid("VerticalOvalHull", Vector3(0, 0, 0), Vector3(1.8, 2.8, 2.0), mat_hull)
	_ellipsoid("VerticalAccentRing", Vector3(0, 0, 0), Vector3(1.85, 2.85, 0.45), mat_accent)

	# 2. Front Circular Panoramic Observation Dome Viewport
	_ellipsoid("FrontGlassDome", Vector3(0, 0.2, -0.78), Vector3(1.35, 1.4, 0.95), mat_glass)

	cockpit_seat = Marker3D.new()
	cockpit_seat.position = Vector3(0, 0.2, -0.55)
	add_child(cockpit_seat)

	# 3. EMP Pulse Cannon ventral hardpoint (电磁脉冲炮发射口)
	_tube(Vector3(0, -1.05, -0.3), Vector3(0, -1.05, -1.3), 0.14, mat_dark)
	var muzzle := Marker3D.new()
	muzzle.position = Vector3(0, -1.05, -1.4)
	add_child(muzzle)
	muzzles.append(muzzle)

	# 4. Flank Mini Escape Pods (两旁微型应急救生舱)
	for side in [-1.0, 1.0]:
		_build_escape_pod(Vector3(side * 1.35, 0.0, 0.1), Vector3(0.65, 0.65, 1.4), "微型救生舱 " + ("左" if side < 0 else "右"), side)

	# 5. Dual Vertical Stabilizer Fins
	_ellipsoid("FinTop", Vector3(0, 1.55, 0.4), Vector3(0.08, 0.65, 0.95), mat_accent)
	_ellipsoid("FinBottom", Vector3(0, -1.55, 0.4), Vector3(0.08, 0.65, 0.95), mat_accent)

	# 6. Stern Ducted Propeller
	_tube(Vector3(0, 0, 0.8), Vector3(0, 0, 1.25), 0.38, mat_dark)
	_ring(Vector3(0, 0, 1.26), 0.40, 0.05, mat_accent)
	var prop := Node3D.new()
	prop.position = Vector3(0, 0, 1.35)
	add_child(prop)
	_box("MiniBlade1", Vector3.ZERO, Vector3(0.06, 0.62, 0.05), mat_dark, prop)
	_box("MiniBlade2", Vector3.ZERO, Vector3(0.62, 0.06, 0.05), mat_dark, prop)
	propellers.append(prop)

	# Headlight
	var light := SpotLight3D.new()
	light.position = Vector3(0, -0.4, -1.2)
	light.spot_range = 65.0
	light.spot_angle = 45.0
	light.light_color = Color(0.3, 0.92, 1.0)
	light.light_energy = 5.2
	add_child(light)
	headlights.append(light)

	_setup_wake_particles(Vector3(0, 0, 1.8), 0.35)

func toggle_scope() -> bool:
	is_scoped = not is_scoped
	return is_scoped

# Modular Emergency Escape Pod Builder (两旁救生舱建造)
func _build_escape_pod(at: Vector3, size: Vector3, pod_label: String, side: float) -> Node3D:
	var pod_root := Node3D.new()
	pod_root.name = "EscapePod"
	pod_root.position = at
	add_child(pod_root)

	var mat_pod := _mat(Color(0.95, 0.96, 0.98), 0.35, 0.25)
	var mat_trim := _mat(Color(1.0, 0.45, 0.1), 0.4, 0.3)
	var mat_dark := _mat(Color(0.08, 0.1, 0.14), 0.7, 0.4)
	var mat_win := _mat(Color(0.2, 0.9, 1.0, 0.6), 0.1, 0.1)
	mat_win.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# Pod Capsule Ellipsoid (流线型椭圆救生舱胶囊体)
	_ellipsoid("PodBody", Vector3.ZERO, size, mat_pod, pod_root)
	_ellipsoid("PodTrim", Vector3(0, 0, 0), Vector3(size.x * 1.02, size.y * 0.4, size.z * 0.6), mat_trim, pod_root)

	# Observation Viewport Window
	_ellipsoid("PodWindow", Vector3(side * size.x * 0.3, size.y * 0.15, -size.z * 0.32), Vector3(size.x * 0.45, size.y * 0.35, size.z * 0.25), mat_win, pod_root)

	# Quick-release Docking Pylons (侧向液压快速脱离挂架)
	var pylon_len: float = 0.55
	_tube(Vector3.ZERO, Vector3(-side * pylon_len, 0, 0), size.x * 0.12, mat_dark, pod_root)
	_tube(Vector3(0, 0, size.z * 0.25), Vector3(-side * pylon_len, 0, size.z * 0.25), size.x * 0.10, mat_dark, pod_root)

	# Flashing Emergency Recovery Beacon Light (救生舱自备遇险搜救光标)
	var strobe := OmniLight3D.new()
	strobe.position = Vector3(side * size.x * 0.35, size.y * 0.55, 0)
	strobe.light_color = Color(1.0, 0.6, 0.15) if sub_type == "titan" else Color(0.2, 0.9, 1.0)
	strobe.light_energy = 2.8
	strobe.omni_range = 14.0
	pod_root.add_child(strobe)

	# Pod Stencil Label (救生舱标识)
	var label := Label3D.new()
	label.font = preload("res://assets/fonts/NotoSansSC-Subset.otf")
	label.text = "◈ " + pod_label
	label.position = Vector3(side * size.x * 0.55, size.y * 0.4, 0)
	label.font_size = 28
	label.pixel_size = 0.007
	label.modulate = Color(1.0, 0.85, 0.3)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	pod_root.add_child(label)

	escape_pods.append(pod_root)
	return pod_root

func _setup_wake_particles(at: Vector3, radius: float) -> void:
	wake_particles = CPUParticles3D.new()
	wake_particles.name = "SubmarineWake"
	wake_particles.position = at
	wake_particles.emitting = false
	wake_particles.amount = 48
	wake_particles.lifetime = 1.6
	wake_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	wake_particles.emission_sphere_radius = radius
	wake_particles.direction = Vector3(0, 0, 1)
	wake_particles.spread = 25.0
	wake_particles.initial_velocity_min = 3.5
	wake_particles.initial_velocity_max = 8.5
	wake_particles.gravity = Vector3(0, 0.8, 0)

	var p_mesh := SphereMesh.new()
	p_mesh.radius = radius * 0.15
	p_mesh.height = p_mesh.radius * 2.0
	var p_mat := StandardMaterial3D.new()
	p_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	p_mat.albedo_color = Color(0.65, 0.92, 1.0, 0.45)
	p_mesh.material = p_mat
	wake_particles.mesh = p_mesh
	add_child(wake_particles)

func board(diver: Node3D) -> void:
	is_piloted = true
	pilot_diver = diver

func disembark() -> Vector3:
	is_piloted = false
	pilot_diver = null
	current_speed = 0.0
	velocity = Vector3.ZERO
	if is_instance_valid(wake_particles):
		wake_particles.emitting = false
	var side_offset := 3.2 if sub_type == "scout" else 7.5
	var b: Basis = global_basis if is_inside_tree() else basis
	var p: Vector3 = global_position if is_inside_tree() else position
	return p + b * Vector3(side_offset, 0.6, 0.0)

func fire_weapon() -> Dictionary:
	if attack_cooldown > 0.0:
		return {}
	attack_cooldown = attack_interval
	var b: Basis = global_basis if is_inside_tree() else basis
	var p: Vector3 = global_position if is_inside_tree() else position
	var muzzle_pos := p - b.z * (2.8 if sub_type == "scout" else 12.0)
	if not muzzles.is_empty():
		var idx: int = randi() % muzzles.size()
		if is_instance_valid(muzzles[idx]):
			muzzle_pos = muzzles[idx].global_position if muzzles[idx].is_inside_tree() else (p + muzzles[idx].position)

	var dir := -b.z
	if sub_type == "mini":
		var data := {
			"sub_type": "mini",
			"sub_name": sub_name,
			"mode": "emp_beam",
			"from": muzzle_pos,
			"direction": dir,
			"damage": 140.0,
			"range": 2000.0,
			"speed": 0.0,
			"radius": 1.5,
			"shockwave": false
		}
		fired_torpedo.emit(data)
		return data
	var data := {
		"sub_type": sub_type,
		"sub_name": sub_name,
		"from": muzzle_pos,
		"direction": dir,
		"damage": 120.0 if sub_type == "scout" else 360.0,
		"speed": 48.0 if sub_type == "scout" else 38.0,
		"radius": 5.5 if sub_type == "scout" else 22.0,
		"shockwave": sub_type == "titan"
	}
	fired_torpedo.emit(data)
	return data

func take_damage(amount: float) -> bool:
	hull = maxf(0.0, hull - amount)
	return hull <= 0.0

func repair(amount: float) -> void:
	hull = minf(max_hull, hull + amount)

func get_hull_ratio() -> float:
	return hull / maxf(max_hull, 1.0)

# 潜水艇行动方式与人物完全一致：以摄像机3D视角为基准的即时敏捷 6-DOF 游动操作
func pilot_direct(delta: float, input_vec: Vector2, ascend_descend: float, is_boost: bool, camera_basis: Basis) -> void:
	if not is_piloted:
		velocity = velocity.lerp(Vector3.ZERO, delta * 3.0)
		move_and_slide()
		return

	# 1. 转向机动舵效 (A 左拐, D 右拐)：偏航 Yaw 旋转并伴随真实水动力倾侧 Roll
	var turn_yaw: float = -input_vec.x
	var turn_rate: float = 2.4 if sub_type == "scout" else (1.6 if sub_type == "titan" else 2.8)
	if absf(turn_yaw) > 0.05:
		rotation.y += turn_yaw * turn_rate * delta

	var roll_target: float = clampf(-turn_yaw * (0.26 if sub_type == "scout" else 0.15), -0.32, 0.32)
	rotation.z = lerp_angle(rotation.z, roll_target, delta * 7.5)

	# 2. 升降压载与俯仰 (空格 上升, C 下降)
	var pitch_target: float = clampf(-ascend_descend * 0.30, -0.38, 0.38)
	rotation.x = lerp_angle(rotation.x, pitch_target, delta * 6.5)

	# 3. 螺旋桨推进与倒车 (W 前进, S 后退)
	var fwd_thrust: float = -input_vec.y
	var sub_heading: Vector3 = -global_basis.z
	var thrust_dir: Vector3 = sub_heading * (fwd_thrust if fwd_thrust >= 0.0 else fwd_thrust * 0.55)
	thrust_dir.y += ascend_descend * 0.95

	var max_spd: float = boost_speed if is_boost else cruise_speed
	velocity = velocity.lerp(thrust_dir.limit_length() * max_spd, 1.0 - exp(-delta * 4.8))
	move_and_slide()

	current_speed = velocity.length()

	# 3. 边界限制
	position.x = clampf(position.x, -440.0, 440.0)
	position.z = clampf(position.z, -470.0, 210.0)
	position.y = clampf(position.y, -160.0, 0.5)

	# 4. 驱动螺旋桨旋转与尾流气泡喷射
	prop_spin_speed = (current_speed / max_spd) * (42.0 if is_boost else 26.0) + 4.0
	for prop in propellers:
		if is_instance_valid(prop):
			prop.rotate_z(delta * prop_spin_speed)

	if is_instance_valid(wake_particles):
		wake_particles.emitting = current_speed > 1.5

func pilot_physics(delta: float, move_vec: Vector3, is_boost: bool, look_rotation: Vector3) -> void:
	# Backward compatibility wrapper
	var b := Basis.from_euler(look_rotation)
	pilot_direct(delta, Vector2(move_vec.x, move_vec.z), move_vec.y, is_boost, b)

func _process(delta: float) -> void:
	if attack_cooldown > 0.0:
		attack_cooldown = maxf(0.0, attack_cooldown - delta)

func _mat(color: Color, metallic: float = 0.0, roughness: float = 0.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	return m

func _ellipsoid(p_name: String, at: Vector3, size: Vector3, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = p_name
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 24
	sphere.rings = 14
	part.mesh = sphere
	part.position = at
	part.scale = size
	part.material_override = material
	(parent if parent != null else self).add_child(part)
	return part

func _box(p_name: String, at: Vector3, size: Vector3, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = p_name
	var box := BoxMesh.new()
	box.size = size
	part.mesh = box
	part.position = at
	part.material_override = material
	(parent if parent != null else self).add_child(part)
	return part

func _tube(start: Vector3, finish: Vector3, radius: float, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = start.distance_to(finish)
	cyl.radial_segments = 16
	part.mesh = cyl
	part.position = (start + finish) * 0.5
	var dir := (finish - start).normalized()
	if dir.length_squared() > 0.001:
		part.quaternion = Quaternion(Vector3.UP, dir)
	part.material_override = material
	(parent if parent != null else self).add_child(part)
	return part

func _ring(at: Vector3, radius: float, thickness: float, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius - thickness
	torus.outer_radius = radius
	torus.rings = 24
	torus.ring_segments = 8
	part.mesh = torus
	part.position = at
	part.rotation.x = PI * 0.5
	part.material_override = material
	(parent if parent != null else self).add_child(part)
	return part
