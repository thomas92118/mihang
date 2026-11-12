extends Node3D

signal detonated(at: Vector3, radius: float, duration: float)

const ArtDirection = preload("res://scripts/art_direction.gd")

const SPEED := 4.5
const COLLISION_RADIUS := 0.85
const MAX_LIFETIME := 18.0

var direction := Vector3.FORWARD
var field_radius := 12.0
var freeze_duration := 6.0
var excluded: Array[RID] = []
var lifetime := 0.0
var exploded := false
var collision_shape := SphereShape3D.new()
var shell: MeshInstance3D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	name = "StasisEnergyOrb"
	collision_shape.radius = COLLISION_RADIUS
	var core := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.62
	sphere.height = 1.24
	sphere.radial_segments = 24
	sphere.rings = 12
	core.mesh = sphere
	var material := StandardMaterial3D.new()
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	material.rim_enabled = false
	material.roughness = 0.24
	material.metallic = 0.12
	material.albedo_color = ArtDirection.CYAN.lerp(ArtDirection.PAPER, 0.28)
	material.emission_enabled = true
	material.emission = Color("56a8be")
	material.emission_energy_multiplier = 0.82
	core.material_override = material
	add_child(core)
	shell = MeshInstance3D.new()
	var outer := SphereMesh.new()
	outer.radius = COLLISION_RADIUS
	outer.height = COLLISION_RADIUS * 2.0
	shell.mesh = outer
	var glow := StandardMaterial3D.new()
	glow.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	glow.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	glow.rim_enabled = false
	glow.roughness = 0.18
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	glow.albedo_color = Color(ArtDirection.CYAN, 0.22)
	glow.emission_enabled = true
	glow.emission = ArtDirection.CYAN
	glow.emission_energy_multiplier = 0.32
	shell.material_override = glow
	add_child(shell)
	var ring_mat := StandardMaterial3D.new()
	ring_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	ring_mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	ring_mat.rim_enabled = false
	ring_mat.roughness = 0.30
	ring_mat.metallic = 0.25
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.albedo_color = Color(ArtDirection.PAPER.lerp(ArtDirection.CYAN, 0.45), 0.74)
	ring_mat.emission_enabled = true
	ring_mat.emission = ArtDirection.CYAN
	ring_mat.emission_energy_multiplier = 0.42
	for axis in range(3):
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.77
		torus.outer_radius = 0.805
		torus.rings = 24
		torus.ring_segments = 6
		ring.mesh = torus
		ring.material_override = ring_mat
		ring.rotation = Vector3(PI * 0.5 * axis, 0.7 * axis, 0.3 * axis)
		shell.add_child(ring)
	var light := OmniLight3D.new()
	light.light_color = ArtDirection.CYAN.lerp(Color("4fa3c4"), 0.38)
	light.light_energy = 1.35
	light.omni_range = 7.5
	add_child(light)

func _physics_process(delta: float) -> void:
	if exploded:
		return
	lifetime += delta
	var space := get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collision_shape
	query.transform = Transform3D(Basis.IDENTITY, global_position)
	query.collision_mask = 7
	query.collide_with_areas = true
	query.exclude = excluded
	# cast_motion ignores objects already overlapping the sphere.
	if not space.intersect_shape(query, 1).is_empty():
		_detonate()
		return
	var motion := direction.normalized() * SPEED * delta
	query.motion = motion
	var fractions := space.cast_motion(query)
	if fractions.size() == 2 and fractions[0] < 1.0:
		global_position += motion * fractions[0]
		_detonate()
		return
	global_position += motion
	shell.rotate_y(delta * 1.4)
	shell.rotate_z(delta * 0.8)
	if lifetime >= MAX_LIFETIME:
		queue_free()

func _detonate() -> void:
	if exploded:
		return
	exploded = true
	detonated.emit(global_position, field_radius, freeze_duration)
	queue_free()
