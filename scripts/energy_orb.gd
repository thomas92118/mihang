extends Node3D

signal detonated(at: Vector3, radius: float, duration: float)

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
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.08, 0.35, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.03, 0.22, 0.8)
	material.disable_fog = true
	core.material_override = material
	add_child(core)
	shell = MeshInstance3D.new()
	var outer := SphereMesh.new()
	outer.radius = COLLISION_RADIUS
	outer.height = COLLISION_RADIUS * 2.0
	shell.mesh = outer
	var glow := material.duplicate() as StandardMaterial3D
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.emission_enabled = false
	glow.albedo_color = Color(0.04, 0.25, 1.0, 0.16)
	shell.material_override = glow
	add_child(shell)
	for axis in range(3):
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.76
		torus.outer_radius = 0.81
		torus.rings = 24
		torus.ring_segments = 6
		ring.mesh = torus
		ring.material_override = material
		ring.rotation = Vector3(PI * 0.5 * axis, 0.7 * axis, 0.3 * axis)
		shell.add_child(ring)
	var light := OmniLight3D.new()
	light.light_color = Color(0.12, 0.5, 1.0)
	light.light_energy = 4.0
	light.omni_range = 9.0
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
