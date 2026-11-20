# 3D Underwater Combat VFX System for Godot 4
# Spawns cavitation bubbles, bioluminescent fluid bursts, impact shockwaves and 3D damage numbers
class_name CombatVFX

const COMBAT_FONT = preload("res://assets/fonts/NotoSansSC-Subset.otf")
const ArtDirection = preload("res://scripts/art_direction.gd")
const SafeArea = preload("res://scripts/presentation/safe_area.gd")

static var mobile_performance_mode := false
static var _stasis_shell_mesh: SphereMesh = null
static var _blood_particle_meshes: Dictionary = {}
static var _hit_bubble_mesh: SphereMesh = null
static var _slash_box_axe: BoxMesh = null
static var _slash_box_knife: BoxMesh = null
static var _red_dot_sphere_mesh: SphereMesh = null
static var _salvage_bag_sphere_mesh: SphereMesh = null
static var _clam_bubble_mesh: SphereMesh = null
static var _unit_torus_mesh: TorusMesh = null
static var _thin_torus_mesh: TorusMesh = null
static var _unit_sphere_mesh: SphereMesh = null
static var _hex_disc_mesh: CylinderMesh = null
static var _dodge_silhouette_mesh: CapsuleMesh = null
static var _arc_streak_mesh: BoxMesh = null
static var _crosshair_bar_mesh: BoxMesh = null
static var _spark_particle_meshes: Dictionary = {}

static func _align_y_to(dir: Vector3) -> Quaternion:
	if dir.length_squared() < 0.00001:
		return Quaternion.IDENTITY
	var target := dir.normalized()
	if target.dot(Vector3.UP) < -0.999:
		return Quaternion(Vector3.RIGHT, PI)
	return Quaternion(Vector3.UP, target)

static func _get_unit_torus_mesh() -> TorusMesh:
	if _unit_torus_mesh == null:
		var torus := TorusMesh.new()
		torus.inner_radius = 0.86
		torus.outer_radius = 1.0
		torus.rings = 28
		torus.ring_segments = 8
		_unit_torus_mesh = torus
	return _unit_torus_mesh

static func _get_thin_torus_mesh() -> TorusMesh:
	if _thin_torus_mesh == null:
		var torus := TorusMesh.new()
		torus.inner_radius = 0.93
		torus.outer_radius = 1.0
		torus.rings = 32
		torus.ring_segments = 8
		_thin_torus_mesh = torus
	return _thin_torus_mesh

static func _get_unit_sphere_mesh() -> SphereMesh:
	if _unit_sphere_mesh == null:
		var sphere := SphereMesh.new()
		sphere.radius = 0.5
		sphere.height = 1.0
		sphere.radial_segments = 16
		sphere.rings = 8
		_unit_sphere_mesh = sphere
	return _unit_sphere_mesh

static func _get_hex_disc_mesh() -> CylinderMesh:
	if _hex_disc_mesh == null:
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.68
		cyl.bottom_radius = 0.68
		cyl.height = 0.03
		cyl.radial_segments = 6
		_hex_disc_mesh = cyl
	return _hex_disc_mesh

static func _get_dodge_silhouette_mesh() -> CapsuleMesh:
	if _dodge_silhouette_mesh == null:
		var cap := CapsuleMesh.new()
		cap.radius = 0.34
		cap.height = 1.35
		cap.radial_segments = 12
		cap.rings = 6
		_dodge_silhouette_mesh = cap
	return _dodge_silhouette_mesh

static func _get_arc_streak_mesh() -> BoxMesh:
	if _arc_streak_mesh == null:
		var box := BoxMesh.new()
		box.size = Vector3(2.2, 0.055, 0.055)
		_arc_streak_mesh = box
	return _arc_streak_mesh

static func _get_crosshair_bar_mesh() -> BoxMesh:
	if _crosshair_bar_mesh == null:
		var box := BoxMesh.new()
		box.size = Vector3(0.08, 0.025, 0.52)
		_crosshair_bar_mesh = box
	return _crosshair_bar_mesh

static func _get_spark_particle_mesh(color: Color, radius: float = 0.035) -> SphereMesh:
	var key := "%s_%.3f" % [color.to_html(false), radius]
	if _spark_particle_meshes.has(key):
		return _spark_particle_meshes[key] as SphereMesh
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 6
	sphere.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	mat.disable_fog = true
	mat.albedo_color = Color(color.r, color.g, color.b, 0.92)
	sphere.material = mat
	_spark_particle_meshes[key] = sphere
	return sphere

static func _make_glow_material(color: Color, alpha: float = 0.72, emission_energy: float = 0.7, unshaded: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	mat.disable_fog = true
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	if unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	else:
		mat.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
		mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
		mat.rim_enabled = false
		mat.roughness = 0.28
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission_energy
	return mat

static func _particle_budget_scale() -> float:
	return 0.55 if (mobile_performance_mode or SafeArea.is_default_touch_platform()) else 1.0

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
	var p_scale := _particle_budget_scale()

	# 1. 生物荧光体液 / 撞击爆裂微粒
	var blood_particles := CPUParticles3D.new()
	blood_particles.process_mode = Node.PROCESS_MODE_PAUSABLE
	blood_particles.name = "HitIchorBurst"
	blood_particles.position = pos
	blood_particles.emitting = true
	blood_particles.one_shot = true
	blood_particles.explosiveness = 0.92
	blood_particles.lifetime = 0.55
	blood_particles.amount = maxi(6, roundi(float(32 if (weapon_type == "axe" or is_kill) else 18) * p_scale))
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
	bubbles.amount = maxi(6, roundi(float(28 if weapon_type == "axe" else 16) * p_scale))
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
	particles.amount = maxi(8, roundi(22.0 * _particle_budget_scale()))
	particles.lifetime = 1.35
	particles.mesh = _get_clam_bubble_mesh()
	particles.direction = Vector3.UP
	particles.spread = 24.0
	particles.gravity = Vector3(0.0, 4.2, 0.0)
	particles.initial_velocity_min = 1.8
	particles.initial_velocity_max = 3.6
	root_node.add_child(particles)
	_auto_free(particles, 1.6)

static func spawn_status_callout(root_node: Node, pos: Vector3, text: String, color: Color = Color("ffd166")) -> void:
	if not root_node or not root_node.is_inside_tree() or text.is_empty():
		return
	var label := Label3D.new()
	label.process_mode = Node.PROCESS_MODE_PAUSABLE
	label.name = "StatusCallout"
	label.font = COMBAT_FONT
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	var old_font_size := 22
	var old_pixel_size := label.pixel_size
	label.font_size = 28
	label.pixel_size = old_pixel_size * (float(old_font_size) / 28.0)
	label.modulate = color
	label.outline_modulate = Color(ArtDirection.INK, 0.95)
	label.outline_size = roundi(4.0 * 28.0 / float(old_font_size))
	label.text = text
	var offset := Vector3(randf_range(-0.22, 0.22), randf_range(0.24, 0.48), randf_range(-0.22, 0.22))
	label.position = pos + offset
	label.scale = Vector3.ONE * 0.42
	root_node.add_child(label)
	_animate_damage_number(label, 0.95)

static func spawn_parry_flash(root_node: Node, pos: Vector3, normal: Vector3) -> void:
	if not root_node or not root_node.is_inside_tree():
		return
	var root := Node3D.new()
	root.name = "ParryFlash"
	root.process_mode = Node.PROCESS_MODE_PAUSABLE
	root.position = pos
	root_node.add_child(root)

	var dir_n := normal.normalized() if normal.length_squared() > 0.0001 else Vector3.UP
	var orient := _align_y_to(dir_n)
	var gold_col := Color("ffd166")
	var cyan_col := Color("63e0f2")

	var hex_disc := MeshInstance3D.new()
	hex_disc.mesh = _get_hex_disc_mesh()
	hex_disc.quaternion = orient
	hex_disc.scale = Vector3.ONE * 0.35
	var hex_mat := _make_glow_material(gold_col.lerp(ArtDirection.PAPER, 0.32), 0.86, 1.15, true)
	hex_disc.material_override = hex_mat
	root.add_child(hex_disc)
	var hex_tween := hex_disc.create_tween()
	hex_tween.tween_property(hex_disc, "scale", Vector3.ONE * 1.9, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	hex_tween.parallel().tween_property(hex_mat, "albedo_color:a", 0.0, 0.26)

	var inner_ring := MeshInstance3D.new()
	inner_ring.mesh = _get_unit_torus_mesh()
	inner_ring.quaternion = orient
	inner_ring.scale = Vector3.ONE * 0.32
	var inner_mat := _make_glow_material(gold_col, 0.88, 0.95)
	inner_ring.material_override = inner_mat
	root.add_child(inner_ring)
	var inner_tween := inner_ring.create_tween()
	inner_tween.tween_property(inner_ring, "scale", Vector3.ONE * 2.15, 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	inner_tween.parallel().tween_property(inner_mat, "albedo_color:a", 0.0, 0.30)

	var outer_ring := MeshInstance3D.new()
	outer_ring.mesh = _get_thin_torus_mesh()
	outer_ring.quaternion = orient * Quaternion(Vector3.RIGHT, 0.35)
	outer_ring.scale = Vector3.ONE * 0.45
	var outer_mat := _make_glow_material(cyan_col, 0.78, 0.85)
	outer_ring.material_override = outer_mat
	root.add_child(outer_ring)
	var outer_tween := outer_ring.create_tween()
	outer_tween.tween_property(outer_ring, "scale", Vector3.ONE * 2.85, 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	outer_tween.parallel().tween_property(outer_mat, "albedo_color:a", 0.0, 0.34)

	var sparks := CPUParticles3D.new()
	sparks.process_mode = Node.PROCESS_MODE_PAUSABLE
	sparks.emitting = true
	sparks.one_shot = true
	sparks.explosiveness = 0.95
	sparks.lifetime = 0.42
	sparks.amount = maxi(8, roundi(28.0 * _particle_budget_scale()))
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sparks.emission_sphere_radius = 0.16
	sparks.direction = dir_n
	sparks.spread = 88.0
	sparks.initial_velocity_min = 4.2
	sparks.initial_velocity_max = 9.4
	sparks.damping_min = 7.0
	sparks.damping_max = 10.5
	sparks.gravity = Vector3.ZERO
	sparks.mesh = _get_spark_particle_mesh(Color("ffe699"), 0.032)
	root.add_child(sparks)

	var flash_light := OmniLight3D.new()
	flash_light.light_color = gold_col.lerp(cyan_col, 0.25)
	flash_light.light_energy = 2.4
	flash_light.omni_range = 6.2
	root.add_child(flash_light)
	var light_tween := flash_light.create_tween()
	light_tween.tween_property(flash_light, "light_energy", 0.0, 0.26)

	_auto_free(root, 0.50)

static func spawn_dodge_afterimage(root_node: Node, pos: Vector3, forward: Vector3) -> void:
	if not root_node or not root_node.is_inside_tree():
		return
	var root := Node3D.new()
	root.name = "DodgeAfterimage"
	root.process_mode = Node.PROCESS_MODE_PAUSABLE
	root.position = pos
	root_node.add_child(root)

	var fwd := forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD
	var orient := _align_y_to(fwd)
	var ice_col := Color("7be8ff")

	var silhouette := MeshInstance3D.new()
	silhouette.mesh = _get_dodge_silhouette_mesh()
	var sil_mat := _make_glow_material(ice_col, 0.42, 0.65)
	silhouette.material_override = sil_mat
	root.add_child(silhouette)
	var sil_tween := silhouette.create_tween()
	sil_tween.tween_property(silhouette, "position", -fwd * 0.45, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	sil_tween.parallel().tween_property(silhouette, "scale", Vector3(0.75, 1.12, 0.75), 0.34)
	sil_tween.parallel().tween_property(sil_mat, "albedo_color:a", 0.0, 0.34)

	for ring_idx in range(2):
		var vortex := MeshInstance3D.new()
		vortex.mesh = _get_thin_torus_mesh()
		vortex.quaternion = orient
		vortex.position = -fwd * (0.25 + float(ring_idx) * 0.55)
		vortex.scale = Vector3.ONE * (0.48 - float(ring_idx) * 0.1)
		var vortex_mat := _make_glow_material(ice_col.lerp(ArtDirection.PAPER, 0.18 * float(ring_idx)), 0.72 - float(ring_idx) * 0.14, 0.75)
		vortex.material_override = vortex_mat
		root.add_child(vortex)
		var v_tween := vortex.create_tween()
		v_tween.tween_property(vortex, "scale", Vector3.ONE * (1.85 - float(ring_idx) * 0.32), 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		v_tween.parallel().tween_property(vortex, "position", -fwd * (0.85 + float(ring_idx) * 0.8), 0.34)
		v_tween.parallel().tween_property(vortex_mat, "albedo_color:a", 0.0, 0.34)

	var trail := CPUParticles3D.new()
	trail.process_mode = Node.PROCESS_MODE_PAUSABLE
	trail.emitting = true
	trail.one_shot = true
	trail.explosiveness = 0.86
	trail.lifetime = 0.46
	trail.amount = maxi(8, roundi(24.0 * _particle_budget_scale()))
	trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	trail.emission_sphere_radius = 0.38
	trail.direction = -fwd
	trail.spread = 36.0
	trail.initial_velocity_min = 2.0
	trail.initial_velocity_max = 5.2
	trail.damping_min = 5.0
	trail.damping_max = 7.5
	trail.gravity = Vector3(0.0, 0.55, 0.0)
	trail.mesh = _get_spark_particle_mesh(ice_col, 0.03)
	root.add_child(trail)

	var glow_light := OmniLight3D.new()
	glow_light.light_color = ice_col
	glow_light.light_energy = 1.25
	glow_light.omni_range = 4.4
	root.add_child(glow_light)
	var light_tween := glow_light.create_tween()
	light_tween.tween_property(glow_light, "light_energy", 0.0, 0.30)

	_auto_free(root, 0.54)

static func spawn_reaction_burst(root_node: Node, pos: Vector3, reaction_type: String, label_text: String = "") -> void:
	if not root_node or not root_node.is_inside_tree():
		return
	var primary := ArtDirection.CYAN
	var secondary := ArtDirection.AMBER
	match reaction_type:
		"superconduct":
			primary = Color("5ce1ff")
			secondary = Color("d8f7ff")
		"implosion":
			primary = Color("ff6b4a")
			secondary = Color("ffd166")
		"overcharge":
			primary = Color("d94dff")
			secondary = Color("ff4f8b")
		"crystal_freeze":
			primary = Color("68f0e2")
			secondary = Color("c8fff9")

	var root := Node3D.new()
	root.name = "ReactionBurst_" + reaction_type
	root.process_mode = Node.PROCESS_MODE_PAUSABLE
	root.position = pos
	root_node.add_child(root)

	var orb := MeshInstance3D.new()
	orb.mesh = _get_unit_sphere_mesh()
	var orb_mat := _make_glow_material(secondary, 0.85, 1.1, true)
	orb.material_override = orb_mat
	root.add_child(orb)
	var orb_tween := orb.create_tween()
	if reaction_type == "implosion":
		orb.scale = Vector3.ONE * 1.9
		orb_tween.tween_property(orb, "scale", Vector3.ONE * 0.25, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		orb_tween.tween_property(orb, "scale", Vector3.ONE * 2.15, 0.24).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		orb_tween.parallel().tween_property(orb_mat, "albedo_color:a", 0.0, 0.24)
	else:
		orb.scale = Vector3.ONE * 0.32
		orb_tween.tween_property(orb, "scale", Vector3.ONE * 1.65, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		orb_tween.parallel().tween_property(orb_mat, "albedo_color:a", 0.0, 0.34)

	for ring_idx in range(2):
		var ring := MeshInstance3D.new()
		ring.mesh = _get_hex_disc_mesh() if (reaction_type == "crystal_freeze" and ring_idx == 1) else _get_unit_torus_mesh()
		ring.rotation_degrees = Vector3(0.0, 0.0, 0.0) if ring_idx == 0 else Vector3(68.0, 32.0, 0.0)
		var ring_col := primary if ring_idx == 0 else secondary
		var ring_mat := _make_glow_material(ring_col, 0.82 - float(ring_idx) * 0.14, 0.9)
		ring.material_override = ring_mat
		root.add_child(ring)
		var r_tween := ring.create_tween()
		if reaction_type == "implosion" and ring_idx == 0:
			ring.scale = Vector3.ONE * 3.1
			r_tween.tween_property(ring, "scale", Vector3.ONE * 0.45, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			r_tween.tween_property(ring, "scale", Vector3.ONE * 3.7, 0.30).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			r_tween.parallel().tween_property(ring_mat, "albedo_color:a", 0.0, 0.30)
		else:
			ring.scale = Vector3.ONE * (0.35 + float(ring_idx) * 0.15)
			r_tween.tween_property(ring, "scale", Vector3.ONE * (3.4 + float(ring_idx) * 0.55), 0.44).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			r_tween.parallel().tween_property(ring_mat, "albedo_color:a", 0.0, 0.44)

	if reaction_type == "superconduct" or reaction_type == "overcharge":
		var arc_mesh := _get_arc_streak_mesh()
		for arc_idx in range(3):
			var arc := MeshInstance3D.new()
			arc.mesh = arc_mesh
			arc.rotation_degrees = Vector3(float(arc_idx) * 35.0, float(arc_idx) * 60.0, 28.0 - float(arc_idx) * 42.0)
			var arc_mat := _make_glow_material(secondary, 0.92, 1.1, true)
			arc.material_override = arc_mat
			root.add_child(arc)
			var arc_tween := arc.create_tween()
			arc_tween.tween_property(arc, "scale", Vector3(1.55, 0.12, 0.12), 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			arc_tween.parallel().tween_property(arc_mat, "albedo_color:a", 0.0, 0.28)

	var particles := CPUParticles3D.new()
	particles.process_mode = Node.PROCESS_MODE_PAUSABLE
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.92
	particles.lifetime = 0.54
	particles.amount = maxi(10, roundi(30.0 * _particle_budget_scale()))
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.25
	particles.direction = Vector3.UP
	particles.spread = 180.0
	particles.initial_velocity_min = 3.2
	particles.initial_velocity_max = 7.8
	particles.damping_min = 5.5
	particles.damping_max = 8.5
	particles.gravity = Vector3(0.0, 0.35, 0.0)
	particles.mesh = _get_spark_particle_mesh(primary, 0.036)
	root.add_child(particles)

	var burst_light := OmniLight3D.new()
	burst_light.light_color = primary
	burst_light.light_energy = 2.6
	burst_light.omni_range = 7.5
	root.add_child(burst_light)
	var light_tween := burst_light.create_tween()
	light_tween.tween_property(burst_light, "light_energy", 0.0, 0.38)

	if not label_text.is_empty():
		spawn_status_callout(root_node, pos + Vector3(0.0, 0.85, 0.0), label_text, primary.lerp(ArtDirection.PAPER, 0.15))

	_auto_free(root, 0.64)

static func spawn_sonar_cone(root_node: Node, origin: Vector3, dir: Vector3, range_m: float = 22.0, color := Color("63e0f2")) -> void:
	if not root_node or not root_node.is_inside_tree():
		return
	var root := Node3D.new()
	root.name = "SonarCone"
	root.process_mode = Node.PROCESS_MODE_PAUSABLE
	root.position = origin
	root_node.add_child(root)

	var fwd := dir.normalized() if dir.length_squared() > 0.0001 else Vector3.FORWARD
	var travel := maxf(2.0, range_m)
	var orient := _align_y_to(fwd)

	for layer_idx in range(3):
		var ring := MeshInstance3D.new()
		ring.mesh = _get_thin_torus_mesh()
		ring.quaternion = orient
		var start_dist := 0.65 + float(layer_idx) * 0.55
		var end_dist := travel * (0.70 + float(layer_idx) * 0.15)
		var start_scale := 0.38 + float(layer_idx) * 0.16
		var end_scale := 2.4 + float(layer_idx) * 1.15
		ring.position = fwd * start_dist
		ring.scale = Vector3.ONE * start_scale
		var layer_col := color.lerp(ArtDirection.PAPER, 0.16 * float(2 - layer_idx))
		var ring_mat := _make_glow_material(layer_col, 0.82 - float(layer_idx) * 0.12, 0.85, layer_idx == 0)
		ring.material_override = ring_mat
		root.add_child(ring)

		var delay := float(layer_idx) * 0.055
		var seg_dur := 0.36 + float(layer_idx) * 0.05
		var r_tween := ring.create_tween()
		if delay > 0.0:
			r_tween.tween_interval(delay)
		r_tween.tween_property(ring, "position", fwd * end_dist, seg_dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		r_tween.parallel().tween_property(ring, "scale", Vector3.ONE * end_scale, seg_dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		r_tween.parallel().tween_property(ring_mat, "albedo_color:a", 0.0, seg_dur)

	var pulse_light := OmniLight3D.new()
	pulse_light.position = fwd * 0.8
	pulse_light.light_color = color
	pulse_light.light_energy = 1.65
	pulse_light.omni_range = 6.2
	root.add_child(pulse_light)
	var light_tween := pulse_light.create_tween()
	light_tween.tween_property(pulse_light, "light_energy", 0.0, 0.30)

	_auto_free(root, 0.65)

static func spawn_harpoon_line(root_node: Node, from: Vector3, to: Vector3, electrified: bool = true, duration: float = 0.45) -> Node3D:
	if not root_node or not root_node.is_inside_tree():
		return null
	var root := Node3D.new()
	root.name = "HarpoonLine"
	root.process_mode = Node.PROCESS_MODE_PAUSABLE
	root_node.add_child(root)
	root.global_position = from

	var life := maxf(0.08, duration)
	var diff := to - from
	var dist := diff.length()
	if dist < 0.001:
		_auto_free(root, life)
		return root

	var dir_n := diff / dist
	var orient := _align_y_to(dir_n)

	var cable := MeshInstance3D.new()
	var cable_cyl := CylinderMesh.new()
	cable_cyl.top_radius = 0.022
	cable_cyl.bottom_radius = 0.022
	cable_cyl.height = dist
	cable_cyl.radial_segments = 8
	cable.mesh = cable_cyl
	cable.position = diff * 0.5
	cable.quaternion = orient
	var cable_mat := StandardMaterial3D.new()
	cable_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	cable_mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	cable_mat.rim_enabled = false
	cable_mat.metallic = 0.85
	cable_mat.roughness = 0.24
	cable_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cable_mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	cable_mat.disable_fog = true
	cable_mat.albedo_color = Color(0.86, 0.93, 0.98, 0.95)
	cable_mat.emission_enabled = true
	cable_mat.emission = Color("6ce8ff") if electrified else Color("c8d8e4")
	cable_mat.emission_energy_multiplier = 0.65 if electrified else 0.22
	cable.material_override = cable_mat
	root.add_child(cable)
	var cable_tween := cable.create_tween()
	cable_tween.tween_property(cable_mat, "albedo_color:a", 0.0, life * 0.35).set_delay(life * 0.65)

	if electrified:
		var sheath := MeshInstance3D.new()
		var sheath_cyl := CylinderMesh.new()
		sheath_cyl.top_radius = 0.048
		sheath_cyl.bottom_radius = 0.048
		sheath_cyl.height = dist
		sheath_cyl.radial_segments = 8
		sheath.mesh = sheath_cyl
		sheath.position = diff * 0.5
		sheath.quaternion = orient
		var sheath_mat := _make_glow_material(Color("6ce8ff"), 0.50, 0.9, true)
		sheath.material_override = sheath_mat
		root.add_child(sheath)
		var sheath_tween := sheath.create_tween()
		sheath_tween.tween_property(sheath_mat, "albedo_color:a", 0.18, life * 0.45)
		sheath_tween.tween_property(sheath_mat, "albedo_color:a", 0.0, life * 0.55)

		var pulse_count := clampi(int(dist / 3.5) + 2, 3, 5)
		var side_axis := dir_n.cross(Vector3.UP)
		if side_axis.length_squared() < 0.001:
			side_axis = dir_n.cross(Vector3.FORWARD)
		side_axis = side_axis.normalized()
		var up_axis := side_axis.cross(dir_n).normalized()
		for pulse_idx in range(pulse_count):
			var node_orb := MeshInstance3D.new()
			node_orb.mesh = _get_unit_sphere_mesh()
			node_orb.scale = Vector3.ONE * 0.16
			var frac_start := float(pulse_idx) / float(pulse_count)
			var jitter := side_axis * randf_range(-0.08, 0.08) + up_axis * randf_range(-0.08, 0.08)
			node_orb.position = diff * frac_start + jitter
			var orb_mat := _make_glow_material(Color("c4f8ff"), 0.95, 1.2, true)
			node_orb.material_override = orb_mat
			root.add_child(node_orb)
			var travel_dur := maxf(0.06, life * (1.0 - frac_start * 0.55))
			var orb_tween := node_orb.create_tween()
			orb_tween.tween_property(node_orb, "position", diff + jitter * 0.35, travel_dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			orb_tween.parallel().tween_property(orb_mat, "albedo_color:a", 0.0, travel_dur)

		var tip_light := OmniLight3D.new()
		tip_light.position = diff
		tip_light.light_color = Color("6ce8ff")
		tip_light.light_energy = 1.6
		tip_light.omni_range = 4.6
		root.add_child(tip_light)
		var tip_tween := tip_light.create_tween()
		tip_tween.tween_property(tip_light, "light_energy", 0.0, life)

	_auto_free(root, life + 0.04)
	return root

static func spawn_ultimate_field(root_node: Node, center: Vector3, radius: float, duration: float, style: String = "mermaid") -> Node3D:
	if not root_node or not root_node.is_inside_tree():
		return null
	var safe_radius := maxf(1.0, radius)
	var safe_dur := maxf(0.4, duration)
	var fade_dur := minf(0.42, safe_dur * 0.28)
	var hold_dur := maxf(0.0, safe_dur - 0.22 - fade_dur)

	var field := Node3D.new()
	field.name = "UltimateField_" + style
	field.process_mode = Node.PROCESS_MODE_PAUSABLE
	root_node.add_child(field)
	field.global_position = center

	var fade_mats: Array[StandardMaterial3D] = []
	var light_col := Color("5eead4")

	if style == "diver":
		light_col = Color("63e0f2")
		var core_beam := MeshInstance3D.new()
		var core_cyl := CylinderMesh.new()
		core_cyl.top_radius = safe_radius * 0.24
		core_cyl.bottom_radius = safe_radius * 0.24
		core_cyl.height = 24.0
		core_cyl.radial_segments = 18
		core_beam.mesh = core_cyl
		core_beam.position = Vector3(0.0, 10.5, 0.0)
		var core_mat := _make_glow_material(Color("e8fbff"), 0.72, 1.15, true)
		core_beam.material_override = core_mat
		fade_mats.append(core_mat)
		field.add_child(core_beam)

		var outer_beam := MeshInstance3D.new()
		var outer_cyl := CylinderMesh.new()
		outer_cyl.top_radius = safe_radius * 0.62
		outer_cyl.bottom_radius = safe_radius * 0.68
		outer_cyl.height = 22.0
		outer_cyl.radial_segments = 24
		outer_beam.mesh = outer_cyl
		outer_beam.position = Vector3(0.0, 9.5, 0.0)
		var outer_mat := _make_glow_material(Color("63e0f2"), 0.22, 0.75)
		outer_beam.material_override = outer_mat
		fade_mats.append(outer_mat)
		field.add_child(outer_beam)

		var base_ring := MeshInstance3D.new()
		base_ring.mesh = _get_thin_torus_mesh()
		base_ring.scale = Vector3.ONE * safe_radius
		var base_mat := _make_glow_material(Color("ffd166"), 0.78, 0.9)
		base_ring.material_override = base_mat
		fade_mats.append(base_mat)
		field.add_child(base_ring)

		var focus_ring := MeshInstance3D.new()
		focus_ring.mesh = _get_unit_torus_mesh()
		focus_ring.scale = Vector3.ONE * (safe_radius * 0.78)
		focus_ring.position = Vector3(0.0, 7.5, 0.0)
		var focus_mat := _make_glow_material(Color("7be8ff"), 0.72, 0.95)
		focus_ring.material_override = focus_mat
		fade_mats.append(focus_mat)
		field.add_child(focus_ring)
		var focus_tween := focus_ring.create_tween()
		focus_tween.tween_property(focus_ring, "position:y", 0.25, maxf(0.25, safe_dur * 0.65)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	elif style == "sub":
		light_col = Color("ff4444")
		var outer_ring := MeshInstance3D.new()
		outer_ring.mesh = _get_thin_torus_mesh()
		outer_ring.scale = Vector3.ONE * safe_radius
		var outer_mat := _make_glow_material(Color("ff4444"), 0.84, 0.95)
		outer_ring.material_override = outer_mat
		fade_mats.append(outer_mat)
		field.add_child(outer_ring)

		var reticle := Node3D.new()
		field.add_child(reticle)
		var inner_ring := MeshInstance3D.new()
		inner_ring.mesh = _get_thin_torus_mesh()
		inner_ring.scale = Vector3.ONE * (safe_radius * 0.56)
		var inner_mat := _make_glow_material(Color("ffd166"), 0.78, 0.9)
		inner_ring.material_override = inner_mat
		fade_mats.append(inner_mat)
		reticle.add_child(inner_ring)

		var bar_mesh := _get_crosshair_bar_mesh()
		for bar_idx in range(4):
			var angle := float(bar_idx) * (PI * 0.5)
			var bar := MeshInstance3D.new()
			bar.mesh = bar_mesh
			bar.rotation.y = angle
			bar.position = Vector3(sin(angle), 0.05, cos(angle)) * (safe_radius * 0.78)
			bar.scale = Vector3(1.0, 1.0, safe_radius * 0.75)
			var bar_mat := _make_glow_material(Color("ff5e4d"), 0.85, 1.0, true)
			bar.material_override = bar_mat
			fade_mats.append(bar_mat)
			reticle.add_child(bar)
		var rot_tween := reticle.create_tween()
		rot_tween.tween_property(reticle, "rotation:y", TAU * 0.75, safe_dur)
	else:
		light_col = Color("5eead4")
		var ring_scales: Array[float] = [safe_radius, safe_radius * 0.72, safe_radius * 0.44]
		var ring_tilts: Array[Vector3] = [Vector3.ZERO, Vector3(14.0, 22.0, -10.0), Vector3(-18.0, 40.0, 12.0)]
		for ring_idx in range(3):
			var ring := MeshInstance3D.new()
			ring.mesh = _get_thin_torus_mesh() if ring_idx < 2 else _get_unit_torus_mesh()
			ring.scale = Vector3.ONE * ring_scales[ring_idx]
			ring.rotation_degrees = ring_tilts[ring_idx]
			ring.position.y = float(ring_idx) * 0.35
			var ring_col := Color("5eead4") if ring_idx != 1 else Color("ffd166")
			var ring_mat := _make_glow_material(ring_col, 0.76 - float(ring_idx) * 0.08, 0.9)
			ring.material_override = ring_mat
			fade_mats.append(ring_mat)
			field.add_child(ring)
			var spin_dir := 1.0 if ring_idx % 2 == 0 else -1.35
			var spin_tween := ring.create_tween()
			spin_tween.tween_property(ring, "rotation:y", ring.rotation.y + TAU * spin_dir * 1.4, safe_dur)

		var vortex_wall := MeshInstance3D.new()
		var wall_cyl := CylinderMesh.new()
		wall_cyl.top_radius = safe_radius * 0.96
		wall_cyl.bottom_radius = safe_radius * 0.82
		wall_cyl.height = 3.8
		wall_cyl.radial_segments = 28
		vortex_wall.mesh = wall_cyl
		vortex_wall.position = Vector3(0.0, 1.8, 0.0)
		var wall_mat := _make_glow_material(Color("5eead4"), 0.16, 0.55)
		vortex_wall.material_override = wall_mat
		fade_mats.append(wall_mat)
		field.add_child(vortex_wall)

		var motes := CPUParticles3D.new()
		motes.process_mode = Node.PROCESS_MODE_PAUSABLE
		motes.emitting = true
		motes.one_shot = false
		motes.lifetime = minf(1.2, safe_dur)
		motes.amount = maxi(10, roundi(30.0 * _particle_budget_scale()))
		motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		motes.emission_sphere_radius = safe_radius * 0.85
		motes.direction = Vector3.UP
		motes.spread = 28.0
		motes.initial_velocity_min = 1.2
		motes.initial_velocity_max = 3.0
		motes.gravity = Vector3(0.0, 0.8, 0.0)
		motes.mesh = _get_spark_particle_mesh(Color("a8fff0"), 0.045)
		field.add_child(motes)

	var field_light := OmniLight3D.new()
	field_light.position = Vector3(0.0, 1.2, 0.0)
	field_light.light_color = light_col
	field_light.light_energy = 2.2
	field_light.omni_range = safe_radius * 1.85
	field.add_child(field_light)

	field.scale = Vector3.ONE * 0.14
	var main_tween := field.create_tween()
	main_tween.tween_property(field, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if hold_dur > 0.0:
		main_tween.tween_interval(hold_dur)
	main_tween.tween_property(field_light, "light_energy", 0.0, fade_dur)
	for fade_mat in fade_mats:
		main_tween.parallel().tween_property(fade_mat, "albedo_color:a", 0.0, fade_dur)
	main_tween.parallel().tween_property(field, "scale", Vector3.ONE * 1.06, fade_dur)
	main_tween.tween_callback(field.queue_free)
	_auto_free(field, safe_dur + 0.08)
	return field

static func spawn_stagger_burst(root_node: Node, pos: Vector3, radius: float = 4.5) -> void:
	if not root_node or not root_node.is_inside_tree():
		return
	var safe_radius := maxf(1.0, radius)
	var root := Node3D.new()
	root.name = "StaggerBurst"
	root.process_mode = Node.PROCESS_MODE_PAUSABLE
	root.position = pos
	root_node.add_child(root)

	var amber_col := Color("ffd166")
	var hot_amber := Color("ff9e44")

	var main_ring := MeshInstance3D.new()
	main_ring.mesh = _get_unit_torus_mesh()
	main_ring.scale = Vector3.ONE * 0.25
	var main_mat := _make_glow_material(amber_col, 0.88, 1.05)
	main_ring.material_override = main_mat
	root.add_child(main_ring)
	var main_tween := main_ring.create_tween()
	main_tween.tween_property(main_ring, "scale", Vector3.ONE * safe_radius, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	main_tween.parallel().tween_property(main_mat, "albedo_color:a", 0.0, 0.42)

	var tilt_ring := MeshInstance3D.new()
	tilt_ring.mesh = _get_thin_torus_mesh()
	tilt_ring.rotation_degrees = Vector3(58.0, 25.0, 0.0)
	tilt_ring.scale = Vector3.ONE * 0.22
	var tilt_mat := _make_glow_material(hot_amber, 0.78, 0.9)
	tilt_ring.material_override = tilt_mat
	root.add_child(tilt_ring)
	var tilt_tween := tilt_ring.create_tween()
	tilt_tween.tween_property(tilt_ring, "scale", Vector3.ONE * (safe_radius * 0.84), 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tilt_tween.parallel().tween_property(tilt_mat, "albedo_color:a", 0.0, 0.38)

	var shards := CPUParticles3D.new()
	shards.process_mode = Node.PROCESS_MODE_PAUSABLE
	shards.emitting = true
	shards.one_shot = true
	shards.explosiveness = 0.94
	shards.lifetime = 0.52
	shards.amount = maxi(8, roundi(26.0 * _particle_budget_scale()))
	shards.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	shards.emission_sphere_radius = 0.22
	shards.direction = Vector3.UP
	shards.spread = 180.0
	shards.initial_velocity_min = 3.6
	shards.initial_velocity_max = 8.4
	shards.damping_min = 6.0
	shards.damping_max = 9.0
	shards.gravity = Vector3(0.0, 0.3, 0.0)
	shards.mesh = _get_spark_particle_mesh(amber_col, 0.038)
	root.add_child(shards)

	var break_light := OmniLight3D.new()
	break_light.light_color = amber_col
	break_light.light_energy = 2.45
	break_light.omni_range = safe_radius * 2.0
	root.add_child(break_light)
	var light_tween := break_light.create_tween()
	light_tween.tween_property(break_light, "light_energy", 0.0, 0.36)

	spawn_status_callout(root_node, pos + Vector3(0.0, 0.95, 0.0), "破防失衡!", amber_col)
	_auto_free(root, 0.62)

static func spawn_telegraph_ring(root_node: Node, pos: Vector3, radius: float, unblockable: bool = false, duration: float = 0.65) -> void:
	if not root_node or not root_node.is_inside_tree():
		return
	var safe_radius := maxf(0.5, radius)
	var safe_dur := maxf(0.12, duration)
	var col := Color("ff4444") if unblockable else Color("ffd166")

	var root := Node3D.new()
	root.name = "TelegraphRing"
	root.process_mode = Node.PROCESS_MODE_PAUSABLE
	root.position = pos
	root_node.add_child(root)

	var outer_ring := MeshInstance3D.new()
	outer_ring.mesh = _get_thin_torus_mesh()
	outer_ring.scale = Vector3.ONE * safe_radius
	var outer_mat := _make_glow_material(col, 0.82, 0.95, true)
	outer_ring.material_override = outer_mat
	root.add_child(outer_ring)

	var fill_ring := MeshInstance3D.new()
	fill_ring.mesh = _get_thin_torus_mesh()
	fill_ring.scale = Vector3.ONE * (safe_radius * 0.14)
	var fill_mat := _make_glow_material(col.lerp(ArtDirection.PAPER, 0.2), 0.72, 0.85, true)
	fill_ring.material_override = fill_mat
	root.add_child(fill_ring)

	var disc := MeshInstance3D.new()
	var disc_cyl := CylinderMesh.new()
	disc_cyl.top_radius = safe_radius * 0.96
	disc_cyl.bottom_radius = safe_radius * 0.96
	disc_cyl.height = 0.02
	disc_cyl.radial_segments = 24
	disc.mesh = disc_cyl
	var disc_mat := _make_glow_material(col, 0.15, 0.5, true)
	disc.material_override = disc_mat
	root.add_child(disc)

	var warn_mats: Array[StandardMaterial3D] = [outer_mat, fill_mat, disc_mat]
	if unblockable:
		var glint_mesh := _get_arc_streak_mesh()
		for glint_idx in range(2):
			var glint := MeshInstance3D.new()
			glint.mesh = glint_mesh
			glint.position = Vector3(0.0, 0.45, 0.0)
			glint.rotation_degrees = Vector3(0.0, 0.0, 45.0 if glint_idx == 0 else -45.0)
			glint.scale = Vector3(0.45, 1.35, 1.35)
			var glint_mat := _make_glow_material(Color("ff6666"), 0.95, 1.2, true)
			glint.material_override = glint_mat
			warn_mats.append(glint_mat)
			root.add_child(glint)
			var g_tween := glint.create_tween()
			g_tween.tween_property(glint, "scale", Vector3(1.15, 0.6, 0.6), safe_dur * 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	var warn_light := OmniLight3D.new()
	warn_light.position = Vector3(0.0, 0.35, 0.0)
	warn_light.light_color = col
	warn_light.light_energy = 1.65 if unblockable else 1.25
	warn_light.omni_range = safe_radius * 2.0
	root.add_child(warn_light)

	var active_dur := safe_dur * 0.82
	var fade_dur := maxf(0.04, safe_dur - active_dur)
	var main_tween := root.create_tween()
	main_tween.tween_property(fill_ring, "scale", Vector3.ONE * safe_radius, active_dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	main_tween.parallel().tween_property(disc_mat, "albedo_color:a", 0.32, active_dur)
	main_tween.tween_property(warn_light, "light_energy", 0.0, fade_dur)
	for w_mat in warn_mats:
		main_tween.parallel().tween_property(w_mat, "albedo_color:a", 0.0, fade_dur)
	main_tween.tween_callback(root.queue_free)
	_auto_free(root, safe_dur + 0.05)
