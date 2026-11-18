extends Node3D
class_name SubmarineTorpedo

signal impacted(at: Vector3, normal: Vector3)

const ArtDirection = preload("res://scripts/art_direction.gd")

var direction := Vector3.FORWARD
var speed := 48.0
var damage := 120.0
var explosion_radius := 6.0
var has_shockwave := false
var lifetime := 0.0
var max_lifetime := 9.0
var exploded := false
var excluded: Array[RID] = []
var ocean_ref: Node = null

var is_guided: bool = true
var guiding_camera: Camera3D = null
var turn_rate: float = 7.5

var torpedo_camera: Camera3D = null
var has_camera_focus: bool = false
var mobile_performance_mode: bool = false

var trail_particles: CPUParticles3D
var nose_mesh: MeshInstance3D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	name = "SubmarineTorpedo"
	_build_mesh()
	_build_trail()

func _build_mesh() -> void:
	var body := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.14 if not has_shockwave else 0.30
	cyl.bottom_radius = cyl.top_radius
	cyl.height = 1.6 if not has_shockwave else 2.8
	cyl.radial_segments = 14
	body.mesh = cyl
	body.rotation.x = PI * 0.5
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("436878") if not has_shockwave else Color("b86b49")
	mat.metallic = 0.48
	mat.roughness = 0.36
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	mat.rim_enabled = false
	body.material_override = mat
	add_child(body)

	nose_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = cyl.top_radius
	sphere.height = sphere.radius * 2.2
	nose_mesh.mesh = sphere
	nose_mesh.position = Vector3(0, 0, -cyl.height * 0.5)
	var beacon_col := ArtDirection.CYAN if not has_shockwave else ArtDirection.AMBER.lerp(ArtDirection.DANGER, 0.42)
	var glow_mat := StandardMaterial3D.new()
	glow_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	glow_mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	glow_mat.rim_enabled = false
	glow_mat.roughness = 0.22
	glow_mat.metallic = 0.16
	glow_mat.albedo_color = beacon_col.lightened(0.14)
	glow_mat.emission_enabled = true
	glow_mat.emission = beacon_col
	glow_mat.emission_energy_multiplier = 0.82
	nose_mesh.material_override = glow_mat
	add_child(nose_mesh)

	var glow_light := OmniLight3D.new()
	glow_light.position = nose_mesh.position
	glow_light.light_color = beacon_col
	glow_light.light_energy = 1.35
	glow_light.omni_range = 7.5
	add_child(glow_light)

	# Pitot tube needle on nose
	var needle := MeshInstance3D.new()
	var n_cyl := CylinderMesh.new()
	n_cyl.top_radius = 0.015
	n_cyl.bottom_radius = 0.025
	n_cyl.height = 0.4
	needle.mesh = n_cyl
	needle.position = nose_mesh.position - Vector3(0, 0, 0.25)
	needle.rotation.x = PI * 0.5
	needle.material_override = mat
	add_child(needle)

	# Forward Canard Fins (前掠操舵舵翼)
	for r in [0.0, 90.0]:
		var canard := MeshInstance3D.new()
		var c_mesh := BoxMesh.new()
		c_mesh.size = Vector3(0.018, 0.42, 0.16) if not has_shockwave else Vector3(0.035, 0.82, 0.28)
		canard.mesh = c_mesh
		canard.position = Vector3(0, 0, -cyl.height * 0.28)
		canard.rotation_degrees = Vector3(0, 0, r)
		canard.material_override = mat
		add_child(canard)

	# Tail Stabilizer Rudder Fins (尾部稳定方向舵)
	for r in [45.0, -45.0]:
		var fin := MeshInstance3D.new()
		var b_mesh := BoxMesh.new()
		b_mesh.size = Vector3(0.02, 0.52, 0.22) if not has_shockwave else Vector3(0.04, 0.95, 0.38)
		fin.mesh = b_mesh
		fin.position = Vector3(0, 0, cyl.height * 0.4)
		fin.rotation_degrees = Vector3(0, 0, r)
		fin.material_override = mat
		add_child(fin)

func _build_trail() -> void:
	trail_particles = CPUParticles3D.new()
	trail_particles.name = "BubbleWake"
	trail_particles.position = Vector3(0, 0, 0.9)
	trail_particles.amount = 36
	trail_particles.lifetime = 0.65
	trail_particles.explosiveness = 0.08
	trail_particles.direction = Vector3(0, 0, 1)
	trail_particles.spread = 14.0
	trail_particles.initial_velocity_min = 3.0
	trail_particles.initial_velocity_max = 7.5
	trail_particles.gravity = Vector3(0, 0.6, 0)
	var p_mesh := SphereMesh.new()
	p_mesh.radius = 0.045
	p_mesh.height = 0.09
	p_mesh.radial_segments = 6
	p_mesh.rings = 3
	var p_mat := StandardMaterial3D.new()
	p_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	p_mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	p_mat.rim_enabled = false
	p_mat.roughness = 0.28
	p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p_mat.albedo_color = Color(ArtDirection.PAPER.lerp(ArtDirection.CYAN, 0.36), 0.48)
	p_mesh.material = p_mat
	trail_particles.mesh = p_mesh
	add_child(trail_particles)
	if mobile_performance_mode:
		trail_particles.amount = 16

func set_mobile_performance_mode(enabled: bool) -> void:
	mobile_performance_mode = enabled
	if is_instance_valid(trail_particles):
		trail_particles.amount = 16 if enabled else 36
	if is_instance_valid(torpedo_camera):
		torpedo_camera.far = 165.0 if enabled else 320.0

func _adapted_torpedo_fov(base_vfov_deg: float = 82.0) -> float:
	if not is_inside_tree() or get_viewport() == null:
		return base_vfov_deg
	var sz := get_viewport().get_visible_rect().size
	if sz.x <= 1.0 or sz.y <= 1.0:
		return base_vfov_deg
	var aspect := sz.x / sz.y
	if aspect < 1.58:
		var narrow_scale := minf(1.6 / maxf(aspect, 0.35), 1.45)
		return clampf(rad_to_deg(2.0 * atan(tan(deg_to_rad(base_vfov_deg) * 0.5) * narrow_scale)), base_vfov_deg, 98.0)
	if aspect > 1.85:
		var max_hfov_rad := deg_to_rad(110.0)
		var cur_hfov := 2.0 * atan(tan(deg_to_rad(base_vfov_deg) * 0.5) * aspect)
		if cur_hfov > max_hfov_rad:
			return rad_to_deg(2.0 * atan(tan(max_hfov_rad * 0.5) / aspect))
	return base_vfov_deg

func activate_fpv_camera() -> Camera3D:
	torpedo_camera = Camera3D.new()
	torpedo_camera.name = "TorpedoFPVCamera"
	torpedo_camera.fov = _adapted_torpedo_fov(82.0)
	torpedo_camera.near = 0.05
	torpedo_camera.far = 165.0 if mobile_performance_mode else 320.0
	# Camera mounted just above the nose looking forward, so the nose cone and canards are visible
	torpedo_camera.position = Vector3(0, 0.16, -0.22)
	add_child(torpedo_camera)
	torpedo_camera.make_current()
	has_camera_focus = true
	return torpedo_camera

func handle_mouse_look(relative: Vector2, sensitivity: float = 0.0024) -> void:
	rotate_y(-relative.x * sensitivity)
	rotate_object_local(Vector3.RIGHT, -relative.y * sensitivity)
	direction = -global_basis.z

func disengage_camera() -> void:
	has_camera_focus = false

func _physics_process(delta: float) -> void:
	if exploded:
		return
	if has_camera_focus and is_instance_valid(torpedo_camera):
		torpedo_camera.fov = _adapted_torpedo_fov(82.0)
	lifetime += delta
	if lifetime >= max_lifetime:
		_detonate(global_position, Vector3.UP)
		return

	# Remote guidance: if not in FPV camera, still smoothly track player aim point
	if is_guided and not has_camera_focus and is_instance_valid(guiding_camera):
		var cam_pos: Vector3 = guiding_camera.global_position
		var cam_dir: Vector3 = -guiding_camera.global_basis.z
		var target_point := cam_pos + cam_dir * 180.0
		var desired_dir := (target_point - global_position).normalized()
		direction = direction.slerp(desired_dir, delta * turn_rate).normalized()
		if direction.length_squared() > 0.001:
			look_at(global_position + direction, Vector3.UP if absf(direction.y) < 0.95 else Vector3.FORWARD)

	var step := direction.normalized() * speed * delta
	var finish := global_position + step

	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(global_position, finish, 1 | 2 | 4, excluded)
	query.collide_with_areas = true
	var hit := space.intersect_ray(query)

	if not hit.is_empty():
		_detonate(hit["position"], hit.get("normal", Vector3.UP), hit.get("collider", null))
	else:
		global_position = finish

func manual_detonate() -> void:
	if not exploded:
		_detonate(global_position, Vector3.UP)

func _detonate(at: Vector3, normal: Vector3, collider: Node = null) -> void:
	if exploded:
		return
	exploded = true
	has_camera_focus = false

	var parent := get_parent()
	if is_instance_valid(parent):
		var CombatVFXCls = load("res://scripts/combat_vfx.gd")
		if CombatVFXCls:
			CombatVFXCls.spawn_hit_burst(parent, at, normal, "axe" if has_shockwave else "sonic", true, false)
			if has_shockwave:
				CombatVFXCls.spawn_stasis_burst(parent, at, explosion_radius, 0.85, ArtDirection.DANGER.lerp(ArtDirection.AMBER, 0.45))

		var AudioCls = load("res://scripts/underwater_audio.gd")
		if AudioCls:
			AudioCls.play_sound(get_tree(), "sub_heavy_blast" if has_shockwave else "sub_torpedo_hit", -3.5 if has_shockwave else -5.0, randf_range(0.95, 1.05))

		# Damage creatures within area
		if is_instance_valid(ocean_ref) and ocean_ref.has_method("damage_creature"):
			var direct_creature: Node3D = null
			if is_instance_valid(collider):
				if collider.has_meta("creature"):
					direct_creature = collider.get_meta("creature")
				elif collider is Node3D and bool(collider.get_meta("is_creature", false)):
					direct_creature = collider as Node3D
			var creatures: Array[Node3D] = ocean_ref.get_creatures() if ocean_ref.has_method("get_creatures") else []
			var has_hit_dist_fn: bool = ocean_ref.has_method("get_creature_hit_distance")
			for creature in creatures:
				if not is_instance_valid(creature) or bool(creature.get_meta("dead", false)):
					continue
				var dist: float = 0.0 if creature == direct_creature else (
					float(ocean_ref.get_creature_hit_distance(creature, at))
					if has_hit_dist_fn
					else creature.global_position.distance_to(at)
				)
				if dist <= explosion_radius:
					var falloff: float = 1.0 - (dist / maxf(explosion_radius, 0.001)) * 0.45
					var final_dmg: float = damage * falloff
					var push_dir: Vector3 = (creature.global_position - at).normalized()
					if push_dir.length_squared() < 0.001:
						push_dir = direction
					creature.set_meta("last_hit_weapon", "torpedo")
					ocean_ref.damage_creature(creature, final_dmg, push_dir * (25.0 if has_shockwave else 14.0))

	impacted.emit(at, normal)
	queue_free()

