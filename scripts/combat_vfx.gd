# 3D Underwater Combat VFX System for Godot 4
# Spawns cavitation bubbles, bioluminescent fluid bursts, impact shockwaves and 3D damage numbers
class_name CombatVFX

# 在世界坐标生成受击爆点特效
static func spawn_hit_burst(root_node: Node, pos: Vector3, normal: Vector3, weapon_type: String, is_predator: bool = false, is_kill: bool = false) -> void:
	if not root_node or not root_node.is_inside_tree():
		return

	# 1. 生物荧光体液 / 撞击爆裂微粒
	var blood_particles := CPUParticles3D.new()
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
	if normal.length_squared() > 0.01:
		shock.look_at(pos + normal, Vector3.UP if absf(normal.y) < 0.9 else Vector3.FORWARD)
	root_node.add_child(shock)
	_animate_shockwave(shock, 0.32, 2.8 if weapon_type == "axe" else 1.8)

# 3D 浮动战斗伤害文字
static func spawn_damage_number(root_node: Node, pos: Vector3, damage: float, weapon_type: String, is_crit: bool = false) -> void:
	if not root_node or not root_node.is_inside_tree():
		return

	var label := Label3D.new()
	label.name = "DmgNumber"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.font_size = 28 if is_crit or weapon_type == "axe" else 22

	# 伤害数字配色
	var col := Color(0.42, 0.96, 1.0)
	if weapon_type == "axe":
		col = Color(1.0, 0.78, 0.25)
	elif weapon_type == "sonic":
		col = Color(0.88, 0.55, 1.0)
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
	tree.create_timer(delay).timeout.connect(func():
		if is_instance_valid(node):
			node.queue_free()
	)

static func _animate_shockwave(shock: MeshInstance3D, duration: float, target_scale: float) -> void:
	var tree := shock.get_tree()
	if not tree:
		shock.queue_free()
		return
	var tween := tree.create_tween()
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
	var tween := tree.create_tween()
	# 弹性弹出 (Pop-in)
	tween.tween_property(label, "scale", Vector3.ONE * 1.25, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector3.ONE * 1.0, 0.10)
	# 缓缓浮起并淡出
	tween.parallel().tween_property(label, "position:y", label.position.y + 1.2, duration)
	tween.parallel().tween_property(label, "modulate:a", 0.0, duration).set_delay(0.25)
	tween.tween_callback(label.queue_free)
