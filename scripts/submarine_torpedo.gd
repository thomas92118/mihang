extends Node3D
class_name SubmarineTorpedo

signal impacted(at: Vector3, normal: Vector3)

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
	mat.albedo_color = Color(0.12, 0.18, 0.24) if not has_shockwave else Color(0.16, 0.09, 0.05)
	mat.metallic = 0.8
	mat.roughness = 0.3
	body.material_override = mat
	add_child(body)

	nose_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = cyl.top_radius
	sphere.height = sphere.radius * 2.2
	nose_mesh.mesh = sphere
	nose_mesh.position = Vector3(0, 0, -cyl.height * 0.5)
	var glow_mat := StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.albedo_color = Color(0.2, 0.9, 1.0) if not has_shockwave else Color(1.0, 0.45, 0.12)
	nose_mesh.material_override = glow_mat
	add_child(nose_mesh)

	var glow_light := OmniLight3D.new()
	glow_light.position = nose_mesh.position
	glow_light.light_color = glow_mat.albedo_color
	glow_light.light_energy = 4.2
	glow_light.omni_range = 10.0
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
	var p_mat := StandardMaterial3D.new()
	p_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p_mat.albedo_color = Color(0.8, 0.96, 1.0, 0.65)
	trail_particles.mesh = p_mesh
	add_child(trail_particles)

func activate_fpv_camera() -> Camera3D:
	torpedo_camera = Camera3D.new()
	torpedo_camera.name = "TorpedoFPVCamera"
	torpedo_camera.fov = 82.0
	torpedo_camera.near = 0.05
	torpedo_camera.far = 320.0
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
				CombatVFXCls.spawn_stasis_burst(parent, at, explosion_radius, 0.85, Color(1.0, 0.45, 0.15))

		var AudioCls = load("res://scripts/underwater_audio.gd")
		if AudioCls:
			AudioCls.play_sound(get_tree(), "sub_heavy_blast" if has_shockwave else "sub_torpedo_hit", -3.5 if has_shockwave else -5.0, randf_range(0.95, 1.05))

		# Damage creatures within area
		if is_instance_valid(ocean_ref) and ocean_ref.has_method("damage_creature"):
			var creatures: Array[Node3D] = ocean_ref.get_creatures() if ocean_ref.has_method("get_creatures") else []
			for creature in creatures:
				if not is_instance_valid(creature) or bool(creature.get_meta("dead", false)):
					continue
				var dist: float = creature.global_position.distance_to(at)
				if dist <= explosion_radius:
					var falloff: float = 1.0 - (dist / explosion_radius) * 0.45
					var final_dmg: float = damage * falloff
					var push_dir: Vector3 = (creature.global_position - at).normalized()
					if push_dir.length_squared() < 0.001:
						push_dir = direction
					ocean_ref.damage_creature(creature, final_dmg, push_dir * (25.0 if has_shockwave else 14.0))

	impacted.emit(at, normal)
	queue_free()

