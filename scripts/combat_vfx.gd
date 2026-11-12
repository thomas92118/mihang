# 3D Underwater Combat VFX System for Godot 4
# Spawns cavitation bubbles, bioluminescent fluid bursts, impact shockwaves and 3D damage numbers
class_name CombatVFX

static func spawn_laser(root_node: Node, from: Vector3, to: Vector3, color := Color(0.08, 0.6, 1.0)) -> Node3D:
	if not root_node or not root_node.is_inside_tree():
		return null
	var beam := Node3D.new()
	beam.name = "BlueLaserBeam"
	beam.process_mode = Node.PROCESS_MODE_PAUSABLE
	root_node.add_child(beam)
	beam.global_position = from
	var direction := to - from
	if direction.length_squared() < 0.00001:
		beam.queue_free()
		return beam
	for layer in range(3):
		var line := MeshInstance3D.new()
		line.name = "LaserCore" if layer == 0 else ("LaserInner" if layer == 1 else "LaserHalo")
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.016 if layer == 0 else (0.038 if layer == 1 else 0.075)
		cylinder.bottom_radius = cylinder.top_radius
		cylinder.height = direction.length()
		cylinder.radial_segments = 10
		line.mesh = cylinder
		line.position = direction * 0.5
		line.quaternion = Quaternion(Vector3.UP, direction.normalized())
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX if layer == 0 else BaseMaterial3D.BLEND_MODE_ADD
		material.disable_fog = true
		if layer == 0:
			material.albedo_color = Color(0.92, 0.98, 1.0, 1.0)
		elif layer == 1:
			material.albedo_color = Color(color.r, color.g, color.b, 0.65)
		else:
			material.albedo_color = Color(color.r * 0.4, color.g * 0.65, color.b, 0.22)
		line.material_override = material
		beam.add_child(line)
		var tween := line.create_tween()
		tween.tween_property(material, "albedo_color:a", 0.0, 0.24)
	# Muzzle pulse ring at origin for third-person visual punch
	var muzzle_ring := MeshInstance3D.new()
	var m_torus := TorusMesh.new()
	m_torus.inner_radius = 0.08
	m_torus.outer_radius = 0.15
	m_torus.rings = 16
	m_torus.ring_segments = 8
	muzzle_ring.mesh = m_torus
	muzzle_ring.quaternion = Quaternion(Vector3.UP, direction.normalized())
	var m_mat := StandardMaterial3D.new()
	m_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m_mat.disable_fog = true
	m_mat.albedo_color = Color(0.55, 0.95, 1.0, 0.9)
	muzzle_ring.material_override = m_mat
	beam.add_child(muzzle_ring)
	var m_tween := muzzle_ring.create_tween()
	m_tween.tween_property(muzzle_ring, "scale", Vector3.ONE * 3.2, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	m_tween.parallel().tween_property(m_mat, "albedo_color:a", 0.0, 0.22)
	_auto_free(beam, 0.26)
	return beam

static func spawn_stasis_burst(root_node: Node, at: Vector3, radius: float, duration: float, color := Color(0.08, 0.4, 1.0)) -> Node3D:
	var field := Node3D.new()
	field.name = "StasisField"
	field.process_mode = Node.PROCESS_MODE_PAUSABLE
	root_node.add_child(field)
	field.global_position = at
	var shell := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 48
	sphere.rings = 24
	shell.mesh = sphere
	shell.scale = Vector3.ONE * radius
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/stasis.gdshader")
	material.set_shader_parameter("field_color", color)
	material.set_shader_parameter("opacity", 0.35)
	shell.material_override = material
	field.add_child(shell)
	for axis in range(3):
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = maxf(0.1, radius - 0.08)
		torus.outer_radius = radius
		torus.rings = 48
		torus.ring_segments = 6
		ring.mesh = torus
		ring.rotation_degrees = Vector3(90.0 * axis, 40.0 * axis, 0)
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		glow.albedo_color = Color(color, 0.45)
		ring.material_override = glow
		field.add_child(ring)
	field.scale = Vector3.ONE * 0.05
	var tween := field.create_tween()
	tween.tween_property(field, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_interval(maxf(0.0, duration - 0.6))
	tween.tween_method(func(alpha: float): material.set_shader_parameter("opacity", alpha), 0.35, 0.0, 0.3)
	tween.parallel().tween_property(field, "scale", Vector3.ONE * 1.03, 0.3)
	tween.tween_callback(field.queue_free)
	return field

# 在世界坐标生成受击爆点特效
static func spawn_hit_burst(root_node: Node, pos: Vector3, normal: Vector3, weapon_type: String, is_predator: bool = false, is_kill: bool = false) -> void:
	if not root_node or not root_node.is_inside_tree():
		return

	# 1. 生物荧光体液 / 撞击爆裂微粒
	var blood_particles := CPUParticles3D.new()
	blood_particles.process_mode = Node.PROCESS_MODE_PAUSABLE
	blood_particles.name = "HitIchorBurst"
	blood_particles.position = pos
	blood_particles.emitting = true
	blood_particles.one_shot = true
	blood_particles.explosiveness = 0.92
	blood_particles.lifetime = 0.55
	blood_particles.amount = 32 if (weapon_type == "axe" or is_kill) else 18
	blood_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	blood_particles.emission_sphere_radius = 0.2
	blood_particles.direction = normal if normal.length_squared() > 0.01 else Vector3.UP
	blood_particles.spread = 75.0
	blood_particles.initial_velocity_min = 2.5
	blood_particles.initial_velocity_max = 6.0 if weapon_type == "axe" else 4.0
	blood_particles.damping_min = 6.0
	blood_particles.damping_max = 8.5
	blood_particles.gravity = Vector3(0, 0.25, 0) # 悬浮微上浮

	var p_mesh := SphereMesh.new()
	p_mesh.radius = 0.032 if weapon_type == "axe" else 0.022
	p_mesh.height = p_mesh.radius * 2.0
	var p_mat := StandardMaterial3D.new()
	p_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD

	# 色彩策略：深渊巨兽与掠食鲨鱼喷散暗金猩红与紫光，浅海生物喷散青蓝与翠绿荧光
	if is_predator:
		p_mat.albedo_color = Color(1.0, 0.32, 0.28, 0.85) if weapon_type != "sonic" else Color(0.85, 0.42, 1.0, 0.9)
	else:
		p_mat.albedo_color = Color(0.35, 0.95, 0.9, 0.8)
	p_mesh.material = p_mat
	blood_particles.mesh = p_mesh
	root_node.add_child(blood_particles)
	_auto_free(blood_particles, 0.65)

	# 2. 水下空化气泡微羽流 (Cavitation Bubbles)
	var bubbles := CPUParticles3D.new()
	bubbles.process_mode = Node.PROCESS_MODE_PAUSABLE
	bubbles.name = "HitCavitationBubbles"
	bubbles.position = pos
	bubbles.emitting = true
	bubbles.one_shot = true
	bubbles.explosiveness = 0.88
	bubbles.lifetime = 0.85
	bubbles.amount = 28 if weapon_type == "axe" else 16
	bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	bubbles.emission_sphere_radius = 0.15
	bubbles.direction = Vector3.UP
	bubbles.spread = 65.0
	bubbles.initial_velocity_min = 1.2
	bubbles.initial_velocity_max = 3.5
	bubbles.damping_min = 4.0
	bubbles.damping_max = 6.0
	bubbles.gravity = Vector3(0, 1.8, 0) # 气泡浮力加速上浮

	var b_mesh := SphereMesh.new()
	b_mesh.radius = 0.025
	b_mesh.height = 0.05
	var b_mat := StandardMaterial3D.new()
	b_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	b_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	b_mat.albedo_color = Color(0.82, 0.96, 1.0, 0.6)
	bubbles.mesh = b_mesh
	root_node.add_child(bubbles)
	_auto_free(bubbles, 0.95)

	# 3. 命中冲击波扩散环 (Expanding Torus Shockwave)
	var shock := MeshInstance3D.new()
	shock.process_mode = Node.PROCESS_MODE_PAUSABLE
	var t_mesh := TorusMesh.new()
	t_mesh.inner_radius = 0.2
	t_mesh.outer_radius = 0.35
	t_mesh.rings = 16
	t_mesh.ring_segments = 8
	shock.mesh = t_mesh
	var s_mat := StandardMaterial3D.new()
	s_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	s_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	s_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	s_mat.albedo_color = Color(0.5, 0.95, 1.0, 0.85) if weapon_type != "axe" else Color(1.0, 0.75, 0.25, 0.9)
	shock.material_override = s_mat
	shock.position = pos
	root_node.add_child(shock)
	if normal.length_squared() > 0.01:
		shock.look_at(pos + normal, Vector3.UP if absf(normal.y) < 0.9 else Vector3.FORWARD)
	_animate_shockwave(shock, 0.32, 2.8 if weapon_type == "axe" else 1.8)

	# 4. 近战命中十字斩光痕与瞬态爆点闪光 (3D Crossed Slash Flash & Impact Light)
	if weapon_type == "knife" or weapon_type == "axe":
		var slash_cross := Node3D.new()
		slash_cross.process_mode = Node.PROCESS_MODE_PAUSABLE
		slash_cross.name = "HitSlashCross"
		slash_cross.position = pos
		root_node.add_child(slash_cross)
		if normal.length_squared() > 0.01:
			slash_cross.look_at(pos + normal, Vector3.UP if absf(normal.y) < 0.9 else Vector3.FORWARD)
		var fin_len := 1.85 if weapon_type == "axe" else 1.15
		var fin_col := Color(1.0, 0.78, 0.28, 0.95) if weapon_type == "axe" else Color(0.45, 0.98, 1.0, 0.95)
		for idx in range(2):
			var streak := MeshInstance3D.new()
			var q_box := BoxMesh.new()
			q_box.size = Vector3(fin_len, 0.045 if weapon_type == "axe" else 0.028, 0.045)
			streak.mesh = q_box
			streak.rotation_degrees = Vector3(0.0, 0.0, 38.0 if idx == 0 else -42.0)
			var st_mat := StandardMaterial3D.new()
			st_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			st_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			st_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			st_mat.disable_fog = true
			st_mat.albedo_color = fin_col
			streak.material_override = st_mat
			slash_cross.add_child(streak)
			var st_tween := streak.create_tween()
			st_tween.tween_property(streak, "scale", Vector3(1.55, 0.15, 1.0), 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			st_tween.parallel().tween_property(st_mat, "albedo_color:a", 0.0, 0.22)
		_auto_free(slash_cross, 0.25)

	var hit_light := OmniLight3D.new()
	hit_light.process_mode = Node.PROCESS_MODE_PAUSABLE
	hit_light.position = pos
	hit_light.light_color = Color(1.0, 0.72, 0.25) if weapon_type == "axe" else Color(0.35, 0.95, 1.0)
	hit_light.light_energy = 5.5 if (weapon_type == "axe" or is_kill) else 3.2
	hit_light.omni_range = 6.5 if weapon_type == "axe" else 4.2
	root_node.add_child(hit_light)
	_auto_free(hit_light, 0.22)

# 3D 浮动战斗伤害文字
static func spawn_damage_number(root_node: Node, pos: Vector3, damage: float, weapon_type: String, is_crit: bool = false) -> void:
	if not root_node or not root_node.is_inside_tree():
		return

	var label := Label3D.new()
	label.process_mode = Node.PROCESS_MODE_PAUSABLE
	label.name = "DmgNumber"
	label.font = preload("res://assets/fonts/NotoSansSC-Subset.otf")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.font_size = 28 if is_crit or weapon_type == "axe" else 22

	# 伤害数字配色
	var col := Color(0.42, 0.96, 1.0)
	if weapon_type == "axe":
		col = Color(1.0, 0.78, 0.25)
	elif weapon_type == "sonic":
		col = Color(0.25, 0.65, 1.0)
	if is_crit:
		col = Color(1.0, 0.35, 0.3)
	label.modulate = col
	label.outline_modulate = Color(0.01, 0.05, 0.08, 0.95)
	label.outline_size = 4

	var prefix := "💥 " if is_crit else ""
	label.text = "%s-%d" % [prefix, int(damage)]
	# 随机轻微错位防重叠
	var offset := Vector3(randf_range(-0.35, 0.35), randf_range(0.2, 0.6), randf_range(-0.35, 0.35))
	label.position = pos + offset
	label.scale = Vector3.ONE * 0.4
	root_node.add_child(label)
	_animate_damage_number(label, 0.75)

static func _auto_free(node: Node, delay: float) -> void:
	var tree := node.get_tree()
	if not tree:
		node.queue_free()
		return
	tree.create_timer(delay, false).timeout.connect(func():
		if is_instance_valid(node):
			node.queue_free()
	)

static func _animate_shockwave(shock: MeshInstance3D, duration: float, target_scale: float) -> void:
	var tree := shock.get_tree()
	if not tree:
		shock.queue_free()
		return
	var tween := shock.create_tween()
	tween.tween_property(shock, "scale", Vector3.ONE * target_scale, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var mat = shock.material_override
	if mat is StandardMaterial3D:
		tween.parallel().tween_property(mat, "albedo_color:a", 0.0, duration)
	tween.tween_callback(shock.queue_free)

static func _animate_damage_number(label: Label3D, duration: float) -> void:
	var tree := label.get_tree()
	if not tree:
		label.queue_free()
		return
	var tween := label.create_tween()
	# 弹性弹出 (Pop-in)
	tween.tween_property(label, "scale", Vector3.ONE * 1.25, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector3.ONE * 1.0, 0.10)
	# 缓缓浮起并淡出
	tween.parallel().tween_property(label, "position:y", label.position.y + 1.2, duration)
	tween.parallel().tween_property(label, "modulate:a", 0.0, duration).set_delay(0.25)
	tween.tween_callback(label.queue_free)

static func spawn_tame_ring(root_node: Node, pos: Vector3, radius: float = 3.5) -> void:
	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = radius * 0.8
	tor.outer_radius = radius
	ring.mesh = tor
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(0.2, 0.95, 1.0, 0.85)
	ring.material_override = mat
	ring.position = pos
	ring.rotation.x = PI * 0.5
	root_node.add_child(ring)
	var tree := ring.get_tree()
	if tree:
		var tween := ring.create_tween()
		tween.tween_property(ring, "scale", Vector3.ONE * 1.8, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 1.2)
		tween.tween_callback(ring.queue_free)
	else:
		ring.queue_free()
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = Color(0.25, 0.95, 1.0)
	light.light_energy = 5.0
	light.omni_range = radius * 4.0
	root_node.add_child(light)
	_auto_free(light, 1.2)

static func spawn_persistent_red_dot(pos: Vector3, parent_node: Node = null) -> Node3D:
	var dot_root := Node3D.new()
	dot_root.name = "MarkerRedDot"
	var dot_mesh := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.08
	s.height = 0.16
	s.radial_segments = 16
	s.rings = 8
	dot_mesh.mesh = s
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.05, 0.05)
	mat.disable_fog = true
	dot_mesh.material_override = mat
	dot_root.add_child(dot_mesh)
	var halo := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.12
	tor.outer_radius = 0.18
	halo.mesh = tor
	var h_mat := StandardMaterial3D.new()
	h_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	h_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	h_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	h_mat.albedo_color = Color(1.0, 0.15, 0.15, 0.85)
	halo.material_override = h_mat
	halo.rotation.x = PI * 0.5
	dot_root.add_child(halo)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.1, 0.1)
	light.light_energy = 3.5
	light.omni_range = 4.0
	dot_root.add_child(light)
	if parent_node != null:
		parent_node.add_child(dot_root)
		dot_root.global_position = pos
	else:
		dot_root.position = pos
	return dot_root

static func spawn_shield_deflect(root_node: Node, pos: Vector3, normal: Vector3) -> void:
	var barrier := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.65
	cyl.bottom_radius = 0.65
	cyl.height = 0.02
	cyl.radial_segments = 6
	barrier.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(0.25, 0.95, 1.0, 0.9)
	mat.disable_fog = true
	barrier.material_override = mat
	barrier.position = pos
	if normal.length_squared() > 0.001:
		var up := Vector3.UP if absf(normal.normalized().y) < 0.95 else Vector3.FORWARD
		barrier.look_at(pos + normal, up, true)
		barrier.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	root_node.add_child(barrier)
	var tree := barrier.get_tree()
	if tree:
		var tween := barrier.create_tween()
		tween.tween_property(barrier, "scale", Vector3.ONE * 1.5, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.28)
		tween.tween_callback(barrier.queue_free)
	else:
		barrier.queue_free()
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = Color(0.3, 0.95, 1.0)
	light.light_energy = 4.0
	light.omni_range = 6.0
	root_node.add_child(light)
	_auto_free(light, 0.3)

static func spawn_star_rating(root_node: Node, pos: Vector3, stars: int, species_name: String = "") -> void:
	if not root_node or not root_node.is_inside_tree():
		return
	var clamped_stars: int = clampi(stars, 1, 3)
	var star_str := "★".repeat(clamped_stars) + "☆".repeat(3 - clamped_stars)
	var quality_tag := "完美活捕" if clamped_stars == 3 else ("良等品质" if clamped_stars == 2 else "破损食材")
	var label := Label3D.new()
	label.process_mode = Node.PROCESS_MODE_PAUSABLE
	label.name = "StarRatingLabel"
	label.font = preload("res://assets/fonts/NotoSansSC-Subset.otf")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.font_size = 26 if clamped_stars == 3 else 21
	label.modulate = Color(1.0, 0.86, 0.22) if clamped_stars == 3 else (Color(0.35, 0.96, 1.0) if clamped_stars == 2 else Color(0.82, 0.86, 0.9))
	label.outline_modulate = Color(0.01, 0.05, 0.09, 0.95)
	label.outline_size = 5
	label.text = "%s %s %s" % [star_str, species_name, quality_tag] if not species_name.is_empty() else "%s %s" % [star_str, quality_tag]
	label.position = pos + Vector3(0.0, 1.15, 0.0)
	label.scale = Vector3.ONE * 0.45
	root_node.add_child(label)
	_animate_damage_number(label, 1.35)

static func spawn_salvage_balloon(root_node: Node, pos: Vector3) -> void:
	if not root_node or not root_node.is_inside_tree():
		return
	var rig := Node3D.new()
	rig.name = "SalvageBalloonRig"
	rig.position = pos
	root_node.add_child(rig)

	# 柯布拉橙黄充气浮力袋
	var bag := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.72
	sphere.height = 1.65
	bag.mesh = sphere
	var bag_mat := StandardMaterial3D.new()
	bag_mat.albedo_color = Color(1.0, 0.48, 0.12)
	bag_mat.emission_enabled = true
	bag_mat.emission = Color(1.0, 0.42, 0.08)
	bag_mat.emission_energy_multiplier = 1.4
	bag.material_override = bag_mat
	bag.position = Vector3(0.0, 1.35, 0.0)
	rig.add_child(bag)

	# 吊索连接杆
	var rope := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.04
	cyl.bottom_radius = 0.04
	cyl.height = 1.1
	rope.mesh = cyl
	var rope_mat := StandardMaterial3D.new()
	rope_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rope_mat.albedo_color = Color(0.35, 0.95, 1.0)
	rope.material_override = rope_mat
	rope.position = Vector3(0.0, 0.6, 0.0)
	rig.add_child(rope)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.65, 0.2)
	light.light_energy = 4.5
	light.omni_range = 7.5
	light.position = Vector3(0.0, 1.4, 0.0)
	rig.add_child(light)

	rig.scale = Vector3.ONE * 0.2
	var tree := rig.get_tree()
	if tree:
		var tw := rig.create_tween()
		tw.tween_property(rig, "scale", Vector3.ONE * 1.15, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(rig, "position:y", pos.y + 18.0, 1.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(bag_mat, "albedo_color:a", 0.0, 0.5).set_delay(0.95)
		tw.tween_callback(rig.queue_free)
	else:
		rig.queue_free()

static func spawn_clam_bubbles(root_node: Node, pos: Vector3) -> void:
	if not root_node or not root_node.is_inside_tree():
		return
	var particles := CPUParticles3D.new()
	particles.position = pos + Vector3(0.0, 0.35, 0.0)
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.45
	particles.amount = 28
	particles.lifetime = 1.35
	var bubble_mesh := SphereMesh.new()
	bubble_mesh.radius = 0.09
	bubble_mesh.height = 0.18
	var b_mat := StandardMaterial3D.new()
	b_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	b_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	b_mat.albedo_color = Color(0.45, 0.98, 1.0, 0.85)
	bubble_mesh.material = b_mat
	particles.mesh = bubble_mesh
	particles.direction = Vector3.UP
	particles.spread = 24.0
	particles.gravity = Vector3(0.0, 4.2, 0.0)
	particles.initial_velocity_min = 1.8
	particles.initial_velocity_max = 3.6
	root_node.add_child(particles)
	_auto_free(particles, 1.6)
