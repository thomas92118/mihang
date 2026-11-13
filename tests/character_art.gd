extends SceneTree
## Visual mesh/rig regression. Uses the actual player builder and animator;
## gameplay movement, hand attachment and scoped/vehicle contracts stay intact.

const Diver = preload("res://scripts/diver.gd")
const Silhouette = preload("res://scripts/presentation/diver_silhouette.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	create_timer(12.0).timeout.connect(func():
		printerr("FAIL: character art regression timed out")
		quit(1)
	)
	var diver = Diver.new()
	root.add_child(diver)
	diver.set_process(false)
	diver.set_physics_process(false)
	assert(diver.diver_model.get_meta("mesh_contract") == Silhouette.CONTRACT_VERSION)
	assert(diver.body_pivot.position.is_equal_approx(Vector3.ZERO))
	assert(diver.left_arm_pivot.position.is_equal_approx(Vector3(-0.20, 0.21, -0.01)))
	assert(diver.right_arm_pivot.position.is_equal_approx(Vector3(0.20, 0.21, -0.01)))
	assert(diver.right_hand_socket.position.is_equal_approx(Vector3(-0.01, -0.08, -0.21)))
	assert(diver.left_hand_socket.position.is_equal_approx(Vector3(0.01, -0.08, -0.21)))
	assert(diver.left_knee_pivot.get_parent() == diver.left_leg_pivot)
	assert(diver.left_fin_pivot.get_parent() == diver.left_knee_pivot)
	assert(diver.right_fin_pivot.get_parent() == diver.right_knee_pivot)
	assert(Silhouette.torso() == Silhouette.torso(), "Procedural suit meshes must be cached")
	assert(Silhouette.helmet().get_aabb().size.x < 0.23, "Helmet must preserve the slimmer silhouette")
	assert(Silhouette.fin().get_aabb().size.z > 0.49, "The fin needs a long tapered trailing edge")
	var triangles := 0
	var checked: Dictionary = {}
	for part: MeshInstance3D in diver.diver_model.find_children("*", "MeshInstance3D", true, false):
		for surface in range(part.mesh.get_surface_count()):
			var arrays := part.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			triangles += (indices.size() if not indices.is_empty() else vertices.size()) / 3
		if part.mesh is ArrayMesh and not checked.has(part.mesh.get_instance_id()):
			_checked_mesh(part.mesh)
			checked[part.mesh.get_instance_id()] = true
		var material: StandardMaterial3D = part.material_override
		assert(material != null and not material.rim_enabled)
		if material.emission_enabled:
			assert(material.emission_energy_multiplier <= 0.12, "Suit detail must not become a white/cyan glow mass")
	assert(triangles <= Silhouette.TRIANGLE_BUDGET, "Suit exceeded authored triangle budget: %d" % triangles)
	var suit: MeshInstance3D = diver.body_pivot.get_node("ExpeditionTorso")
	assert(suit.material_override.albedo_color.is_equal_approx(Color("17354b")), "Authored navy pigment must survive ModelFinish")
	var start_position: Vector3 = diver.position
	var fin_samples: Array[float] = []
	for motion: Vector3 in [Vector3.ZERO, Vector3(0, 0, -5.2), Vector3(0, 4, -3), Vector3(0, -4, -3)]:
		diver.velocity = motion
		for frame in range(90):
			diver._animate_diver_model(1.0 / 60.0)
			for joint: Node3D in [diver.body_pivot, diver.head_pivot, diver.left_arm_pivot, diver.right_arm_pivot, diver.left_leg_pivot, diver.right_leg_pivot, diver.left_knee_pivot, diver.right_knee_pivot, diver.left_fin_pivot, diver.right_fin_pivot]:
				assert(joint.transform.is_finite(), "Pose must stay finite")
			if motion.z < -5.0:
				fin_samples.append(diver.left_fin_pivot.rotation.x)
		assert(diver.velocity.is_equal_approx(motion), "Visual animation must not change physics velocity")
		assert(diver.position.is_equal_approx(start_position), "Visual animation must not move the gameplay body")
	assert(fin_samples.max() - fin_samples.min() > 0.08, "Ankle must articulate after the kick, independently of the hip")
	diver.in_mount_mode = true
	diver._animate_diver_model(0.1)
	assert(is_equal_approx(diver.left_leg_pivot.rotation.z, 0.22))
	diver.in_mount_mode = false
	diver.scoped = true
	diver._update_third_person_camera(0.0)
	assert(diver.camera.position.is_zero_approx() and not diver.diver_model.visible)
	diver.scoped = false
	diver.set_submarine_mode(true, "scout")
	diver._update_third_person_camera(0.0)
	assert(not diver.diver_model.visible)
	diver.set_submarine_mode(false)
	diver._update_third_person_camera(0.0)
	assert(diver.diver_model.visible)
	print("PASS: original expedition silhouette, %d triangles, preserved sockets, articulated fin lag, finite poses and scope/vehicle framing" % triangles)
	diver.free()
	quit()

func _checked_mesh(mesh: ArrayMesh) -> void:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	assert(vertices.size() == normals.size())
	for index in range(vertices.size()):
		assert(vertices[index].is_finite() and normals[index].is_finite())
		assert(absf(normals[index].length() - 1.0) < 0.001)
	for triangle in range(0, indices.size(), 3):
		var a := indices[triangle]
		var b := indices[triangle + 1]
		var c := indices[triangle + 2]
		var face := (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a])
		assert(face.length_squared() > 0.000000000001, "Suit triangles must have nonzero area")
		assert(face.dot(normals[a] + normals[b] + normals[c]) < 0.0, "Godot front faces must use clockwise winding")
