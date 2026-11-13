extends SceneTree
## Integration checks for the reference-directed model. These do not certify
## visual likeness: front/profile/back and swimming captures still need review.
const Diver = preload("res://scripts/diver.gd")
const ReferenceDiver = preload("res://scripts/presentation/reference_diver.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	assert(ReferenceDiver.available(), "Import assets/models/reference_diver.glb first")
	var first := Diver.new()
	root.add_child(first)
	first.set_process(false)
	first.set_physics_process(false)
	assert(first.reference_model_active, "Player did not use the reference-directed model")
	assert(first.diver_model.get_meta("mesh_contract", "") == ReferenceDiver.CONTRACT_VERSION)
	assert(first.diver_model.get_meta("reference_parts", 0) >= 24, "Reference model contains too few semantic parts")
	assert(first.left_arm_pivot.position.is_equal_approx(Vector3(-0.18, 0.19, 0)))
	assert(first.left_forearm_pivot.position.is_equal_approx(Vector3(0, -0.235, 0)))
	assert(first.left_knee_pivot.position.is_equal_approx(Vector3(0, -0.265, 0)))
	assert(first.left_fin_pivot.position.is_equal_approx(Vector3(0, -0.26, 0)))
	assert(first.diver_model.find_child("StreamlinedHelmet", true, false) == null, "Old opaque helmet survived replacement")
	var skeletons := first.diver_model.find_children("*", "Skeleton3D", true, false)
	assert(skeletons.size() == 1 and first.diver_model.get_meta("reference_skinned", false), "Reference character must retain its complete shared skin skeleton")
	var skeleton := skeletons[0] as Skeleton3D
	for driver: String in ReferenceDiver.DRIVER_KEYS:
		assert(skeleton.find_bone(driver) >= 0, "Imported skin is missing driver bone: " + driver)
	for fin: String in ["fin_l", "fin_r"]:
		var bone := skeleton.find_bone(fin)
		assert(skeleton.get_bone_pose(bone).is_equal_approx(skeleton.get_bone_rest(bone)), "Fin binding must preserve the complete parent-local rest pose")
	var labels := ""
	var skin_materials: Dictionary = {}
	var first_materials: Dictionary = {}
	var face_found := false
	var hair_found := false
	var transparent_glass := false
	var authored_meshes := 0
	var triangles := 0
	var blended_vertices := 0
	for part: MeshInstance3D in first.diver_model.find_children("*", "MeshInstance3D", true, false):
		if not bool(part.get_meta("reference_part", false)):
			continue
		authored_meshes += 1
		assert(part.skin != null and not part.skeleton.is_empty(), "Skinned mesh was detached from its skeleton")
		var label := String(part.name).to_lower()
		labels += " " + label
		face_found = face_found or label.contains("face")
		hair_found = hair_found or label.contains("hair")
		assert(part.material_override == null, "A generic whole-mesh override hid the imported material design")
		assert(String(part.get_meta("reference_driver", "")) in ReferenceDiver.DRIVER_KEYS)
		for surface in part.mesh.get_surface_count():
			var material := part.get_active_material(surface) as BaseMaterial3D
			assert(material != null and material.get_meta("reference_material", false), "Authored PBR material missing")
			first_materials[material.get_instance_id()] = true
			if label.contains("face") or label.contains("skin"):
				skin_materials[material.get_instance_id()] = material.albedo_color
			if label.contains("glass") or label.contains("visor"):
				transparent_glass = transparent_glass or (material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED and material.albedo_color.a < 0.6)
			var arrays := part.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			triangles += (indices.size() if not indices.is_empty() else vertices.size()) / 3
			var influences := 8 if (part.mesh.surface_get_format(surface) & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS) != 0 else 4
			for vertex in vertices.size():
				var positive := 0
				var total := 0.0
				for influence in influences:
					var weight := weights[vertex * influences + influence]
					total += weight
					if weight > 0.001:
						positive += 1
				assert(absf(total - 1.0) < 0.01, "Skin weights must be normalized")
				if positive > 1:
					blended_vertices += 1
			for point: Vector3 in vertices:
				assert(point.is_finite(), "Character geometry contains invalid positions")
	assert(authored_meshes >= 24 and triangles > 12000, "Simplified v3 geometry was substituted for the detailed reference model")
	assert(face_found and not skin_materials.is_empty(), "Human face/skin was omitted")
	assert(hair_found, "Reference hair and tied bun were omitted")
	assert(transparent_glass, "Opaque visor hides the face instead of preserving the glass material")
	assert(blended_vertices > 0, "Pelvis/leg connection remains rigid instead of using blended skin weights")
	for detail: String in ["eye", "iris", "lip", "brow"]:
		assert(labels.contains(detail), "Reference facial feature omitted: " + detail)
	for finger: String in ["thumb", "index", "middle", "ring", "little"]:
		assert(labels.contains(finger), "The hand must have five modeled digits: " + finger)
	var second := Diver.new()
	root.add_child(second)
	second.set_process(false)
	second.set_physics_process(false)
	for part: MeshInstance3D in second.diver_model.find_children("*", "MeshInstance3D", true, false):
		if not bool(part.get_meta("reference_part", false)):
			continue
		for surface in part.mesh.get_surface_count():
			assert(not first_materials.has(part.get_active_material(surface).get_instance_id()), "Separate divers share mutable material instances")
	var start_position := first.position
	for motion: Vector3 in [Vector3.ZERO, Vector3(0, 0, -5.2), Vector3(0, 3, -4), Vector3(0, -3, -4)]:
		first.velocity = motion
		for frame in 90:
			first._animate_diver_model(1.0 / 60.0)
			for joint: Node3D in [first.body_pivot, first.head_pivot, first.left_arm_pivot, first.right_arm_pivot, first.left_forearm_pivot, first.right_forearm_pivot, first.left_knee_pivot, first.right_knee_pivot, first.left_fin_pivot, first.right_fin_pivot]:
				assert(joint.transform.is_finite(), "Character animation produced an invalid transform")
		assert(first.position.is_equal_approx(start_position) and first.velocity.is_equal_approx(motion), "Visual animation changed movement physics")
	var left_leg_bone := skeleton.find_bone("leg_l")
	var before := skeleton.get_bone_global_pose(left_leg_bone)
	first.left_leg_pivot.rotation.x += 0.35
	ReferenceDiver.sync_skin(first.diver_model, first._reference_drivers)
	var after := skeleton.get_bone_global_pose(left_leg_bone)
	assert(not before.is_equal_approx(after), "Procedural leg motion did not reach the imported skin bones")
	var state: Dictionary = first.diver_model.get_meta("reference_skin_state")
	var skeleton_in_model: Transform3D = state.skeleton_in_model
	var current_leg := ReferenceDiver._relative_to_model(first.left_leg_pivot, first.diver_model)
	var leg_rest: Transform3D = state.driver_rest.leg_l
	var expected := skeleton_in_model.affine_inverse() * current_leg * leg_rest.affine_inverse() * skeleton_in_model * skeleton.get_bone_global_rest(left_leg_bone)
	assert(after.is_equal_approx(expected), "Imported bone pose does not follow the actual gameplay controller")
	first.set_weapon("sonic")
	first.aiming = true
	first._animate_diver_model(1.0 / 60.0)
	var gun: Node3D = first.weapon_nodes.sonic
	first._sync_reference_gun_to_hand(gun, "sonic", Vector3.ZERO, Vector3.ZERO)
	assert(gun.to_global(Vector3(0, -0.10, 0.16)).distance_to(first.right_hand_socket.global_position) < 0.001, "Third-person gun grip is detached from the modeled hand")
	first.in_mount_mode = true
	first._animate_diver_model(0.1)
	assert(is_equal_approx(first.left_leg_pivot.rotation.z, 0.0) and is_equal_approx(first.left_leg_pivot.rotation.x, first.right_leg_pivot.rotation.x), "Mermaid tail must curve symmetrically without splitting laterally")
	first.in_mount_mode = false
	first.set_submarine_mode(true, "scout")
	first._update_third_person_camera(0)
	assert(not first.diver_model.visible)
	first.set_submarine_mode(false)
	first.scoped = true
	first._update_third_person_camera(0)
	assert(not first.diver_model.visible and first.camera.position.is_zero_approx())
	first.free()
	second.free()
	print("PASS: reference-directed model, ", authored_meshes, " authored parts, ", triangles, " triangles; ", blended_vertices, " blended vertices, real bone deformation, semantic face/hair/five digits, transparent glass, isolated preserved materials and finite poses")
	quit(0)
