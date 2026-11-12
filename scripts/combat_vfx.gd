# 3D Underwater Combat VFX System for Godot 4
# Spawns cavitation bubbles, bioluminescent fluid bursts, impact shockwaves and 3D damage numbers
class_name CombatVFX

const COMBAT_FONT = preload("res://assets/fonts/NotoSansSC-Subset.otf")
const ArtDirection = preload("res://scripts/art_direction.gd")

static var _stasis_shell_mesh: SphereMesh = null
static var _blood_particle_meshes: Dictionary = {}
static var _hit_bubble_mesh: SphereMesh = null
static var _slash_box_axe: BoxMesh = null
static var _slash_box_knife: BoxMesh = null
static var _red_dot_sphere_mesh: SphereMesh = null
static var _salvage_bag_sphere_mesh: SphereMesh = null
static var _clam_bubble_mesh: SphereMesh = null

static func _get_stasis_shell_mesh() -> SphereMesh:
	if _stasis_shell_mesh == null:
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		sphere.radial_segments = 48
		sphere.rings = 24
		_stasis_shell_mesh = sphere
	return _stasis_shell_mesh

static func _get_blood_particle_mesh(weapon_type: String, is_predator: bool) -> SphereMesh:
	var is_axe := weapon_type == "axe"
	var is_sonic := weapon_type == "sonic"
	var key: int = (1 if is_axe else 0) | (2 if is_predator else 0) | (4 if is_sonic else 0)
	if _blood_particle_meshes.has(key):
		return _blood_particle_meshes[key] as SphereMesh
	var p_mesh := SphereMesh.new()
	p_mesh.radius = 0.032 if is_axe else 0.022
	p_mesh.height = p_mesh.radius * 2.0
	p_mesh.radial_segments = 6
	p_mesh.rings = 3
	var p_mat := StandardMaterial3D.new()
	p_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	p_mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	p_mat.rim_enabled = false
	p_mat.roughness = 0.58
	p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p_mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	p_mat.emission_enabled = true
	if is_predator:
		var pred_col := ArtDirection.DANGER.darkened(0.08) if not is_sonic else Color("b56a68")
		p_mat.albedo_color = Color(pred_col, 0.78)
		p_mat.emission = pred_col
		p_mat.emission_energy_multiplier = 0.26
	else:
		p_mat.albedo_color = Color(ArtDirection.CYAN, 0.72)
		p_mat.emission = ArtDirection.CYAN
		p_mat.emission_energy_multiplier = 0.24
	p_mesh.material = p_mat
	_blood_particle_meshes[key] = p_mesh
	return p_mesh

static func _get_hit_bubble_mesh() -> SphereMesh:
	if _hit_bubble_mesh == null:
		var b_mesh := SphereMesh.new()
		b_mesh.radius = 0.025
		b_mesh.height = 0.05
		b_mesh.radial_segments = 6
		b_mesh.rings = 3
		var b_mat := StandardMaterial3D.new()
		b_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
		b_mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
		b_mat.rim_enabled = false
		b_mat.roughness = 0.22
		b_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		b_mat.albedo_color = Color(ArtDirection.PAPER.lerp(ArtDirection.CYAN, 0.38), 0.52)
		b_mesh.material = b_mat
		_hit_bubble_mesh = b_mesh
	return _hit_bubble_mesh

static func _get_slash_box_mesh(is_axe: bool) -> BoxMesh:
	if is_axe:
		if _slash_box_axe == null:
			var q_box := BoxMesh.new()
			q_box.size = Vector3(1.85, 0.045, 0.045)
			_slash_box_axe = q_box
		return _slash_box_axe
	if _slash_box_knife == null:
		var k_box := BoxMesh.new()
		k_box.size = Vector3(1.15, 0.028, 0.045)
		_slash_box_knife = k_box
	return _slash_box_knife

static func _get_red_dot_sphere_mesh() -> SphereMesh:
	if _red_dot_sphere_mesh == null:
		var s := SphereMesh.new()
		s.radius = 0.08
		s.height = 0.16
		s.radial_segments = 16
		s.rings = 8
		_red_dot_sphere_mesh = s
	return _red_dot_sphere_mesh

static func _get_salvage_bag_sphere_mesh() -> SphereMesh:
	if _salvage_bag_sphere_mesh == null:
		var sphere := SphereMesh.new()
		sphere.radius = 0.72
		sphere.height = 1.65
		_salvage_bag_sphere_mesh = sphere
	return _salvage_bag_sphere_mesh

static func _get_clam_bubble_mesh() -> SphereMesh:
	if _clam_bubble_mesh == null:
		var bubble_mesh := SphereMesh.new()
		bubble_mesh.radius = 0.072
		bubble_mesh.height = 0.144
		bubble_mesh.radial_segments = 8
		bubble_mesh.rings = 4
		var b_mat := StandardMaterial3D.new()
		b_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
		b_mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
		b_mat.rim_enabled = false
		b_mat.roughness = 0.18
		b_mat.metallic = 0.08
		b_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		b_mat.albedo_color = Color(ArtDirection.PAPER.lerp(ArtDirection.CYAN, 0.42), 0.64)
		b_mat.emission_enabled = true
		b_mat.emission = ArtDirection.CYAN
		b_mat.emission_energy_multiplier = 0.18
		bubble_mesh.material = b_mat
		_clam_bubble_mesh = bubble_mesh
	return _clam_bubble_mesh

static func spawn_laser(root_node: Node, from: Vector3, to: Vector3, color := Color(0.18, 0.72, 0.92)) -> Node3D:
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
	var is_crimson := color.r > color.b + 0.15
	var inner_col := Color(0.92, 0.18, 0.16) if is_crimson else Color(
		clampf(color.r * 0.65 + 0.10, 0.0, 1.0),
		clampf(maxf(color.g * 0.85, 0.68), 0.0, 1.0),
		clampf(maxf(color.b, 0.86), 0.0, 1.0)
	)
	var core_col := Color(0.98, 0.80, 0.76, 0.94) if is_crimson else Color(0.86, 0.96, 0.99, 0.96)
	var halo_col := Color(0.84, 0.24, 0.20, 0.16) if is_crimson else Color(0.34, 0.74, 0.86, 0.17)
	for layer in range(3):
		var line := MeshInstance3D.new()
		line.name = "LaserCore" if layer == 0 else ("LaserInner" if layer == 1 else "LaserHalo")
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.015 if layer == 0 else (0.034 if layer == 1 else 0.066)
		cylinder.bottom_radius = cylinder.top_radius
		cylinder.height = direction.length()
		cylinder.radial_segments = 10
		line.mesh = cylinder
		line.position = direction * 0.5
		line.quaternion = Quaternion(Vector3.UP, direction.normalized())
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
		material.disable_fog = layer < 2
		if layer == 0:
			material.albedo_color = core_col
		elif layer == 1:
			material.albedo_color = Color(inner_col.r, inner_col.g, inner_col.b, 0.56)
		else:
			material.albedo_color = halo_col
		line.material_override = material
		beam.add_child(line)
		var tween := line.create_tween()
		tween.tween_property(material, "albedo_color:a", 0.0, 0.24)
	var muzzle_ring := MeshInstance3D.new()
	var m_torus := TorusMesh.new()
	m_torus.inner_radius = 0.075
	m_torus.outer_radius = 0.125
	m_torus.rings = 16
	m_torus.ring_segments = 8
	muzzle_ring.mesh = m_torus
	muzzle_ring.quaternion = Quaternion(Vector3.UP, direction.normalized())
	var m_mat := StandardMaterial3D.new()
	m_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	m_mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	m_mat.rim_enabled = false
	m_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m_mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	m_mat.albedo_color = Color(inner_col, 0.64)
	m_mat.emission_enabled = true
	m_mat.emission = inner_col
	m_mat.emission_energy_multiplier = 0.55
	muzzle_ring.material_override = m_mat
	beam.add_child(muzzle_ring)
	var m_tween := muzzle_ring.create_tween()
	m_tween.tween_property(muzzle_ring, "scale", Vector3.ONE * 2.4, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	m_tween.parallel().tween_property(m_mat, "albedo_color:a", 0.0, 0.22)
	_auto_free(beam, 0.26)
	return beam

static func spawn_stasis_burst(root_node: Node, at: Vector3, radius: float, duration: float, color := Color("6bb8c4")) -> Node3D:
	var field := Node3D.new()
	field.name = "StasisField"
	field.process_mode = Node.PROCESS_MODE_PAUSABLE
	root_node.add_child(field)
	field.global_position = at
	var shell := MeshInstance3D.new()
	shell.mesh = _get_stasis_shell_mesh()
	shell.scale = Vector3.ONE * radius
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/stasis.gdshader")
	material.set_shader_parameter("field_color", color)
	material.set_shader_parameter("opacity", 0.32)
	shell.material_override = material
	field.add_child(shell)
	var ring_materials: Array[StandardMaterial3D] = []
	for axis in range(2):
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = maxf(0.1, radius - 0.045)
		torus.outer_radius = radius
		torus.rings = 48
		torus.ring_segments = 6
		ring.mesh = torus
		ring.rotation_degrees = Vector3(0.0 if axis == 0 else 72.0, 28.0 * axis, 18.0 * axis)
		var glow := StandardMaterial3D.new()
		glow.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
		glow.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
		glow.rim_enabled = false
		glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glow.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
		glow.albedo_color = Color(color.lerp(ArtDirection.PAPER, 0.25), 0.34)
		glow.emission_enabled = true
		glow.emission = color
		glow.emission_energy_multiplier = 0.35
		ring.material_override = glow
		ring_materials.append(glow)
		field.add_child(ring)
	field.scale = Vector3.ONE * 0.05
	var tween := field.create_tween()
	tween.tween_property(field, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_interval(maxf(0.0, duration - 0.6))
	tween.tween_method(func(alpha: float): material.set_shader_parameter("opacity", alpha), 0.32, 0.0, 0.3)
	for rm in ring_materials:
		tween.parallel().tween_property(rm, "albedo_color:a", 0.0, 0.3)
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

	blood_particles.mesh = _get_blood_particle_mesh(weapon_type, is_predator)
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

	bubbles.mesh = _get_hit_bubble_mesh()
	root_node.add_child(bubbles)
	_auto_free(bubbles, 0.95)

	# 3. 命中冲击波扩散环 (Expanding Torus Shockwave)
	var shock := MeshInstance3D.new()
	shock.process_mode = Node.PROCESS_MODE_PAUSABLE
	var t_mesh := TorusMesh.new()
	t_mesh.inner_radius = 0.22
	t_mesh.outer_radius = 0.31
	t_mesh.rings = 16
	t_mesh.ring_segments = 8
	shock.mesh = t_mesh
	var s_mat := StandardMaterial3D.new()
	s_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	s_mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	s_mat.rim_enabled = false
	s_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	s_mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	var shock_hue := ArtDirection.AMBER if weapon_type == "axe" else ArtDirection.CYAN
	s_mat.albedo_color = Color(shock_hue, 0.66 if weapon_type == "axe" else 0.58)
	s_mat.emission_enabled = true
	s_mat.emission = shock_hue
	s_mat.emission_energy_multiplier = 0.42
	shock.material_override = s_mat
	shock.position = pos
	root_node.add_child(shock)
	if normal.length_squared() > 0.01:
		shock.look_at(pos + normal, Vector3.UP if absf(normal.y) < 0.9 else Vector3.FORWARD)
	_animate_shockwave(shock, 0.32, 2.4 if weapon_type == "axe" else 1.65)

	if weapon_type == "knife" or weapon_type == "axe":
		var slash_cross := Node3D.new()
		slash_cross.process_mode = Node.PROCESS_MODE_PAUSABLE
		slash_cross.name = "HitSlashCross"
		slash_cross.position = pos
		root_node.add_child(slash_cross)
		if normal.length_squared() > 0.01:
			slash_cross.look_at(pos + normal, Vector3.UP if absf(normal.y) < 0.9 else Vector3.FORWARD)
		var streak_mesh := _get_slash_box_mesh(weapon_type == "axe")
		var streak_hue := ArtDirection.AMBER if weapon_type == "axe" else ArtDirection.PAPER.lerp(ArtDirection.CYAN, 0.55)
		for idx in range(2):
			var streak := MeshInstance3D.new()
			streak.mesh = streak_mesh
			streak.rotation_degrees = Vector3(0.0, 0.0, 38.0 if idx == 0 else -42.0)
			var st_mat := StandardMaterial3D.new()
			st_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
			st_mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
			st_mat.rim_enabled = false
			st_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			st_mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
			st_mat.albedo_color = Color(streak_hue, 0.80)
			st_mat.emission_enabled = true
			st_mat.emission = streak_hue
			st_mat.emission_energy_multiplier = 0.48
			streak.material_override = st_mat
			slash_cross.add_child(streak)
			var st_tween := streak.create_tween()
			st_tween.tween_property(streak, "scale", Vector3(1.4, 0.15, 1.0), 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			st_tween.parallel().tween_property(st_mat, "albedo_color:a", 0.0, 0.22)
		_auto_free(slash_cross, 0.25)

	var hit_light := OmniLight3D.new()
	hit_light.process_mode = Node.PROCESS_MODE_PAUSABLE
	hit_light.position = pos
	hit_light.light_color = ArtDirection.AMBER if weapon_type == "axe" else ArtDirection.CYAN
	hit_light.light_energy = 1.55 if (weapon_type == "axe" or is_kill) else 1.0
	hit_light.omni_range = 4.8 if weapon_type == "axe" else 3.4
	root_node.add_child(hit_light)
	_auto_free(hit_light, 0.22)

# 3D 浮动战斗伤害文字
static func spawn_damage_number(root_node: Node, pos: Vector3, damage: float, weapon_type: String, is_crit: bool = false) -> void:
	if not root_node or not root_node.is_inside_tree():
		return

	var label := Label3D.new()
	label.process_mode = Node.PROCESS_MODE_PAUSABLE
	label.name = "DmgNumber"
	label.font = COMBAT_FONT
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	var old_font_size := 24 if is_crit or weapon_type == "axe" else 19
	var old_pixel_size := label.pixel_size
	label.font_size = 28
	label.pixel_size = old_pixel_size * (float(old_font_size) / 28.0)

	var col := ArtDirection.PAPER
	if weapon_type == "axe":
		col = ArtDirection.AMBER
	elif weapon_type == "sonic":
		col = ArtDirection.CYAN.lightened(0.12)
	if is_crit:
		col = ArtDirection.DANGER.lightened(0.10)
	label.modulate = col
	label.outline_modulate = Color(ArtDirection.INK, 0.94)
	label.outline_size = roundi(4.0 * 28.0 / float(old_font_size))

	var prefix := "✦ " if is_crit else ""
	label.text = "%s-%d" % [prefix, int(damage)]
	var offset := Vector3(randf_range(-0.28, 0.28), randf_range(0.18, 0.5), randf_range(-0.28, 0.28))
	label.position = pos + offset
	label.scale = Vector3.ONE * 0.4
	root_node.add_child(label)
	_animate_damage_number(label, 0.75)

static func _auto_free(node: Node, delay: float) -> void:
	var tree := node.get_tree()
	if not tree:
		node.queue_free()
		return
	tree.create_timer(delay, false).timeout.connect(node.queue_free)

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
	tween.tween_property(label, "scale", Vector3.ONE * 1.12, 0.11).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "scale", Vector3.ONE * 1.0, 0.10)
	tween.parallel().tween_property(label, "position:y", label.position.y + 1.0, duration)
	tween.parallel().tween_property(label, "modulate:a", 0.0, duration).set_delay(0.25)
	tween.tween_callback(label.queue_free)

static func spawn_tame_ring(root_node: Node, pos: Vector3, radius: float = 3.5) -> void:
	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = radius * 0.88
	tor.outer_radius = radius
	ring.mesh = tor
	var mat := StandardMaterial3D.new()
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	mat.rim_enabled = false
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	mat.albedo_color = Color(ArtDirection.CYAN, 0.56)
	mat.emission_enabled = true
	mat.emission = ArtDirection.CYAN
	mat.emission_energy_multiplier = 0.42
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
	light.light_color = ArtDirection.CYAN
	light.light_energy = 1.35
	light.omni_range = radius * 2.5
	root_node.add_child(light)
	_auto_free(light, 1.2)

static func spawn_persistent_red_dot(pos: Vector3, parent_node: Node = null) -> Node3D:
	var dot_root := Node3D.new()
	dot_root.name = "MarkerRedDot"
	var dot_mesh := MeshInstance3D.new()
	dot_mesh.mesh = _get_red_dot_sphere_mesh()
	var mat := StandardMaterial3D.new()
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	mat.rim_enabled = false
	mat.roughness = 0.25
	mat.albedo_color = Color(0.94, 0.14, 0.14)
	mat.emission_enabled = true
	mat.emission = Color(0.96, 0.12, 0.12)
	mat.emission_energy_multiplier = 1.15
	mat.disable_fog = true
	dot_mesh.material_override = mat
	dot_root.add_child(dot_mesh)
	var halo := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.125
	tor.outer_radius = 0.168
	halo.mesh = tor
	var h_mat := StandardMaterial3D.new()
	h_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	h_mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	h_mat.rim_enabled = false
	h_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	h_mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	h_mat.albedo_color = Color(0.95, 0.22, 0.20, 0.78)
	h_mat.emission_enabled = true
	h_mat.emission = Color(0.94, 0.16, 0.16)
	h_mat.emission_energy_multiplier = 0.75
	h_mat.disable_fog = true
	halo.material_override = h_mat
	halo.rotation.x = PI * 0.5
	dot_root.add_child(halo)
	var light := OmniLight3D.new()
	light.light_color = Color(0.95, 0.16, 0.15)
	light.light_energy = 1.65
	light.omni_range = 3.2
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
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	mat.rim_enabled = false
	mat.roughness = 0.2
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	mat.albedo_color = Color(ArtDirection.CYAN.lerp(ArtDirection.PAPER, 0.25), 0.64)
	mat.emission_enabled = true
	mat.emission = ArtDirection.CYAN
	mat.emission_energy_multiplier = 0.48
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
		tween.tween_property(barrier, "scale", Vector3.ONE * 1.35, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.28)
		tween.tween_callback(barrier.queue_free)
	else:
		barrier.queue_free()
	var light := OmniLight3D.new()
	light.position = pos
	light.light_color = ArtDirection.CYAN
	light.light_energy = 1.35
	light.omni_range = 4.5
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
	label.font = COMBAT_FONT
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	var old_font_size := 23 if clamped_stars == 3 else 19
	var old_pixel_size := label.pixel_size
	label.font_size = 28
	label.pixel_size = old_pixel_size * (float(old_font_size) / 28.0)
	label.modulate = ArtDirection.AMBER.lightened(0.08) if clamped_stars == 3 else (ArtDirection.CYAN.lightened(0.08) if clamped_stars == 2 else ArtDirection.MUTED.lightened(0.12))
	label.outline_modulate = Color(ArtDirection.INK, 0.95)
	label.outline_size = roundi(4.0 * 28.0 / float(old_font_size))
	label.text = "%s %s %s" % [star_str, species_name, quality_tag] if not species_name.is_empty() else "%s %s" % [star_str, quality_tag]
	label.position = pos + Vector3(0.0, 1.05, 0.0)
	label.scale = Vector3.ONE * 0.42
	root_node.add_child(label)
	_animate_damage_number(label, 1.35)

static func spawn_salvage_balloon(root_node: Node, pos: Vector3) -> void:
	if not root_node or not root_node.is_inside_tree():
		return
	var rig := Node3D.new()
	rig.name = "SalvageBalloonRig"
	rig.position = pos
	root_node.add_child(rig)

	var bag := MeshInstance3D.new()
	bag.mesh = _get_salvage_bag_sphere_mesh()
	var bag_mat := StandardMaterial3D.new()
	bag_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	bag_mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	bag_mat.rim_enabled = false
	bag_mat.roughness = 0.62
	bag_mat.metallic = 0.05
	bag_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bag_mat.albedo_color = Color("d47a45")
	bag_mat.emission_enabled = true
	bag_mat.emission = Color("c96f36")
	bag_mat.emission_energy_multiplier = 0.22
	bag.material_override = bag_mat
	bag.position = Vector3(0.0, 1.35, 0.0)
	rig.add_child(bag)

	var rope := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.028
	cyl.bottom_radius = 0.028
	cyl.height = 1.1
	rope.mesh = cyl
	var rope_mat := StandardMaterial3D.new()
	rope_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	rope_mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	rope_mat.rim_enabled = false
	rope_mat.roughness = 0.78
	rope_mat.albedo_color = ArtDirection.PAPER.darkened(0.26)
	rope.material_override = rope_mat
	rope.position = Vector3(0.0, 0.6, 0.0)
	rig.add_child(rope)

	var light := OmniLight3D.new()
	light.light_color = ArtDirection.AMBER
	light.light_energy = 1.2
	light.omni_range = 5.0
	light.position = Vector3(0.0, 1.4, 0.0)
	rig.add_child(light)

	rig.scale = Vector3.ONE * 0.2
	var tree := rig.get_tree()
	if tree:
		var tw := rig.create_tween()
		tw.tween_property(rig, "scale", Vector3.ONE * 1.0, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
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
	particles.amount = 22
	particles.lifetime = 1.35
	particles.mesh = _get_clam_bubble_mesh()
	particles.direction = Vector3.UP
	particles.spread = 24.0
	particles.gravity = Vector3(0.0, 4.2, 0.0)
	particles.initial_velocity_min = 1.8
	particles.initial_velocity_max = 3.6
	root_node.add_child(particles)
	_auto_free(particles, 1.6)
