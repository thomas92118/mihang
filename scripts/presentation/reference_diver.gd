extends RefCounted
## Loads the reference-directed character without recoloring its imported PBR.
## Geometry can be shared; every material belongs to one character instance.

const MODEL_PATH := "res://assets/models/reference_diver.glb"
const CONTRACT_VERSION := "reference-directed-diver-1"
const DRIVER_KEYS := ["body", "head", "arm_l", "arm_r", "forearm_l", "forearm_r", "leg_l", "leg_r", "calf_l", "calf_r", "fin_l", "fin_r"]
static var _parts: Array[Dictionary] = []
static var _loaded := false
static var _packed: PackedScene
static var _has_skin := false

static func available() -> bool:
	if not _loaded:
		_load()
	return not _parts.is_empty()

static func _load() -> void:
	_loaded = true
	if not ResourceLoader.exists(MODEL_PATH):
		return
	var packed := load(MODEL_PATH) as PackedScene
	if packed == null:
		return
	_packed = packed
	var source := packed.instantiate()
	var skeletons := source.find_children("*", "Skeleton3D", true, false)
	for part: MeshInstance3D in source.find_children("*", "MeshInstance3D", true, false):
		var tokens := String(part.name).split("__", true, 1)
		if tokens.size() != 2 or tokens[0] not in DRIVER_KEYS or part.mesh == null:
			continue
		_parts.append({"name": String(part.name), "driver": tokens[0], "mesh": part.mesh,
			"transform": part.transform, "materials": _source_materials(part)})
		_has_skin = _has_skin or (part.skin != null and not skeletons.is_empty())
	source.free()

static func _source_materials(part: MeshInstance3D) -> Array[Material]:
	var materials: Array[Material] = []
	for surface in part.mesh.get_surface_count():
		materials.append(part.get_active_material(surface))
	return materials

static func populate(drivers: Dictionary) -> Dictionary:
	if not available():
		return {"parts": 0, "triangles": 0}
	if _has_skin:
		return _populate_skin(drivers)
	var material_copies: Dictionary = {}
	var triangles := 0
	for record: Dictionary in _parts:
		var parent: Node3D = drivers.get(record.driver, null)
		assert(parent != null, "Missing reference character driver: " + str(record.driver))
		var part := MeshInstance3D.new()
		part.name = record.name
		part.mesh = record.mesh
		part.transform = record.transform
		part.set_meta("reference_part", true)
		part.set_meta("reference_driver", record.driver)
		for surface in part.mesh.get_surface_count():
			var original: Material = record.materials[surface]
			if original != null:
				var id := original.get_instance_id()
				if not material_copies.has(id):
					# Keep albedo, glass transparency, roughness, metal and texture
					# bindings exactly as authored. ModelFinish never sees this rig.
					var copy := original.duplicate(false) as Material
					copy.set_meta("reference_material", true)
					material_copies[id] = copy
				part.set_surface_override_material(surface, material_copies[id])
			var arrays := part.mesh.surface_get_arrays(surface)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			triangles += (indices.size() if not indices.is_empty() else vertices.size()) / 3
		parent.add_child(part)
	return {"parts": _parts.size(), "triangles": triangles, "skinned": false, "skeleton_count": 0}

static func _populate_skin(drivers: Dictionary) -> Dictionary:
	var model_root := (drivers.body as Node3D).get_parent() as Node3D
	var scene := _packed.instantiate() as Node3D
	scene.name = "ReferenceSkinnedCharacter"
	model_root.add_child(scene)
	var skeletons := scene.find_children("*", "Skeleton3D", true, false)
	assert(skeletons.size() == 1, "The reference character must use one shared skin skeleton")
	var skeleton := skeletons[0] as Skeleton3D
	var copies: Dictionary = {}
	var triangles := 0
	var parts := 0
	for part: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		var tokens := String(part.name).split("__", true, 1)
		if tokens.size() != 2 or tokens[0] not in DRIVER_KEYS or part.mesh == null:
			continue
		parts += 1
		part.set_meta("reference_part", true)
		part.set_meta("reference_driver", tokens[0])
		for surface in part.mesh.get_surface_count():
			var source := part.get_active_material(surface)
			if source != null:
				var id := source.get_instance_id()
				if not copies.has(id):
					var material := source.duplicate(false) as Material
					material.set_meta("reference_material", true)
					copies[id] = material
				part.set_surface_override_material(surface, copies[id])
			var arrays := part.mesh.surface_get_arrays(surface)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			triangles += (indices.size() if not indices.is_empty() else vertices.size()) / 3
	var rests: Dictionary = {}
	for key: String in DRIVER_KEYS:
		assert(drivers.has(key), "Missing skin controller: " + key)
		rests[key] = _relative_to_model(drivers[key], model_root)
	var pending: Array[int] = []
	var order: Array[int] = []
	for index in skeleton.get_bone_count():
		pending.append(index)
	while not pending.is_empty():
		var progress := false
		for index in pending.duplicate():
			var parent := skeleton.get_bone_parent(index)
			if parent < 0 or parent in order:
				order.append(index)
				pending.erase(index)
				progress = true
		assert(progress, "Invalid cycle in reference skeleton hierarchy")
	model_root.set_meta("reference_skin_state", {"skeleton": skeleton, "driver_rest": rests,
		"order": order, "skeleton_in_model": _relative_to_model(skeleton, model_root)})
	model_root.set_meta("reference_skinned", true)
	sync_skin(model_root, drivers)
	return {"parts": parts, "triangles": triangles, "skinned": true, "skeleton_count": skeletons.size()}

static func _relative_to_model(node: Node3D, model_root: Node3D) -> Transform3D:
	# Compose locals so the initial binding also works before a scene-tree frame
	# and never folds the player's transform or 1.15 visual scale into bone poses.
	var result := node.transform
	var parent := node.get_parent()
	while parent != model_root:
		assert(parent is Node3D, "Skin controller must be below the visual model")
		result = (parent as Node3D).transform * result
		parent = parent.get_parent()
	return result

static func sync_skin(model_root: Node3D, drivers: Dictionary) -> void:
	if not model_root.has_meta("reference_skin_state"):
		return
	var state: Dictionary = model_root.get_meta("reference_skin_state")
	var skeleton: Skeleton3D = state.skeleton
	if not is_instance_valid(skeleton):
		return
	var skel_in_model: Transform3D = state.skeleton_in_model
	var model_in_skel := skel_in_model.affine_inverse()
	var desired_globals: Dictionary = {}
	for index: int in state.order:
		var key := String(skeleton.get_bone_name(index))
		var parent := skeleton.get_bone_parent(index)
		var parent_global: Transform3D = desired_globals[parent] if parent >= 0 else Transform3D.IDENTITY
		var desired: Transform3D
		if drivers.has(key):
			var driver_now := _relative_to_model(drivers[key], model_root)
			var driver_rest: Transform3D = state.driver_rest[key]
			desired = model_in_skel * driver_now * driver_rest.affine_inverse() * skel_in_model * skeleton.get_bone_global_rest(index)
		else:
			desired = parent_global * skeleton.get_bone_rest(index)
		desired_globals[index] = desired
		var desired_local := parent_global.affine_inverse() * desired
		# Godot 4 stores the complete parent-local pose, including rest
		# translation. Removing rest here collapses joints to the origin.
		skeleton.set_bone_pose(index, desired_local)

static func joint(parent: Node3D, label: String, at: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = label
	node.position = at
	parent.add_child(node)
	return node
