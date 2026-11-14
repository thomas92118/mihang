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

static func _infer_material_role(mat: Material, part_name: String) -> String:
	if mat != null:
		var res_name := String(mat.resource_name)
		if res_name.begins_with("Reference_"):
			return res_name.trim_prefix("Reference_")
	var low := part_name.to_lower()
	if low.contains("scales"):
		return "scales"
	if low.contains("pearlescentmermaidfin"):
		return "fin_pearl"
	if low.contains("scallopshell"):
		return "shell_pearl"
	if low.contains("lustrousseapearls"):
		return "pearl"
	if low.contains("hair_highlight"):
		return "hair_highlight"
	if low.contains("hair"):
		return "hair"
	if low.contains("iris"):
		return "iris"
	if low.contains("lips") or low.ends_with("__lip"):
		return "lip"
	if low.contains("eyewhite"):
		return "eye_white"
	if low.contains("pupil"):
		return "pupil"
	if low.contains("lashes"):
		return "lash"
	if low.contains("skin_shadow"):
		return "skin_shadow"
	if low.contains("faceskin"):
		return "skin"
	if low.contains("skin"):
		return "body_skin"
	if low.contains("glass") or low.contains("visor"):
		return "glass"
	if low.contains("specimen_gold"):
		return "specimen_gold"
	if low.contains("gold_light"):
		return "gold_light"
	if low.contains("gold"):
		return "gold"
	return ""

static func _is_face_skin_part(part_name: String) -> bool:
	return part_name.to_lower().contains("faceskin")

static func _should_disable_part_shadow(driver: String, role: String) -> bool:
	if role in ["eye_white", "iris", "pupil", "lash", "skin_shadow", "lip"]:
		return true
	return driver == "head" and role in ["gold", "gold_light", "pearl", "glass", "fin_pearl"]

static func configure_mermaid_materials(model_root: Node3D) -> void:
	if not is_instance_valid(model_root):
		return
	var seen: Dictionary = {}
	var lit_entries: Array[Dictionary] = []
	for part: MeshInstance3D in model_root.find_children("*", "MeshInstance3D", true, false):
		if not bool(part.get_meta("reference_part", false)) or part.mesh == null:
			continue
		var driver := String(part.get_meta("reference_driver", ""))
		for surface in part.mesh.get_surface_count():
			var mat := part.get_surface_override_material(surface) as StandardMaterial3D
			if mat == null:
				continue
			var role := String(mat.get_meta("reference_role", ""))
			if _should_disable_part_shadow(driver, role):
				part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var id := mat.get_instance_id()
			if seen.has(id):
				continue
			seen[id] = true
			if role in ["skin", "body_skin", "skin_shadow", "eye_white", "iris", "pupil", "lip", "lash", "shell_pearl", "hair", "hair_highlight", "pearl"]:
				mat.disable_receive_shadows = true
			var is_face := bool(mat.get_meta("is_face_skin", false))
			match role:
				"skin":
					mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
					mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
					mat.roughness = 0.95 if is_face else 0.88
					mat.metallic = 0.0
					mat.backlight_enabled = true
					mat.backlight = Color(0.56, 0.52, 0.54) if is_face else Color(0.54, 0.50, 0.52)
					var w_skin := 0.15 if is_face else 0.22
					var e_skin := 0.69 if is_face else 0.62
					mat.albedo_color = Color(w_skin, w_skin, w_skin, 1.0)
					mat.emission_enabled = true
					mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
					mat.emission_texture = mat.albedo_texture
					mat.emission = Color.WHITE
					mat.emission_energy_multiplier = e_skin
					lit_entries.append({"mat": mat, "base_color": Color.WHITE, "albedo_weight": w_skin, "emission_energy": e_skin, "textured": true})
				"body_skin":
					mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
					mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
					mat.roughness = 0.88
					mat.metallic = 0.0
					mat.backlight_enabled = true
					mat.backlight = Color(0.54, 0.50, 0.52)
					var w_body := 0.22
					var e_body := 0.62
					mat.albedo_color = Color(w_body, w_body, w_body, 1.0)
					mat.emission_enabled = true
					mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
					mat.emission_texture = mat.albedo_texture
					mat.emission = Color.WHITE
					mat.emission_energy_multiplier = e_body
					lit_entries.append({"mat": mat, "base_color": Color.WHITE, "albedo_weight": w_body, "emission_energy": e_body, "textured": true})
				"skin_shadow":
					var raw_creases: Color = mat.get_meta("authored_base_color", mat.albedo_color)
					if not mat.has_meta("authored_base_color"):
						mat.set_meta("authored_base_color", raw_creases)
					var styled_creases: Color = mat.get_meta("styled_crease_color", raw_creases.lerp(Color(0.96, 0.84, 0.82), 0.42))
					mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
					mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
					mat.roughness = 0.92
					mat.metallic = 0.0
					mat.backlight_enabled = true
					mat.backlight = Color(0.56, 0.52, 0.54)
					var w_crease := 0.16
					var e_crease := 0.66
					mat.albedo_color = Color(styled_creases.r * w_crease, styled_creases.g * w_crease, styled_creases.b * w_crease, 1.0)
					mat.emission_enabled = true
					mat.emission_operator = BaseMaterial3D.EMISSION_OP_ADD
					mat.emission_texture = null
					mat.emission = styled_creases
					mat.emission_energy_multiplier = e_crease
					lit_entries.append({"mat": mat, "base_color": styled_creases, "albedo_weight": w_crease, "emission_energy": e_crease, "textured": false})
				"eye_white":
					var raw_sclera: Color = mat.get_meta("authored_base_color", mat.albedo_color)
					if not mat.has_meta("authored_base_color"):
						mat.set_meta("authored_base_color", raw_sclera)
					mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
					mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
					mat.roughness = 0.90
					mat.metallic = 0.0
					mat.backlight_enabled = true
					mat.backlight = Color(0.60, 0.60, 0.62)
					var w_eye := 0.14
					var e_eye := 0.74
					mat.albedo_color = Color(raw_sclera.r * w_eye, raw_sclera.g * w_eye, raw_sclera.b * w_eye, 1.0)
					mat.emission_enabled = true
					mat.emission_operator = BaseMaterial3D.EMISSION_OP_ADD
					mat.emission_texture = null
					mat.emission = raw_sclera
					mat.emission_energy_multiplier = e_eye
					lit_entries.append({"mat": mat, "base_color": raw_sclera, "albedo_weight": w_eye, "emission_energy": e_eye, "textured": false})
				"lip":
					mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
					mat.roughness = 0.22
					mat.metallic = 0.0
					mat.backlight_enabled = true
					mat.backlight = Color(0.54, 0.46, 0.50)
					var w_lip := 0.20
					var e_lip := 0.64
					mat.albedo_color = Color(w_lip, w_lip, w_lip, 1.0)
					mat.emission_enabled = true
					mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
					mat.emission_texture = mat.albedo_texture
					mat.emission = Color.WHITE
					mat.emission_energy_multiplier = e_lip
					lit_entries.append({"mat": mat, "base_color": Color.WHITE, "albedo_weight": w_lip, "emission_energy": e_lip, "textured": true})
				"iris":
					var boost_iris := float(mat.get_meta("variant_iris_emission", 0.0))
					mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
					mat.backlight_enabled = true
					mat.backlight = Color(0.55, 0.55, 0.58)
					var w_iris := 0.24
					var e_iris := clampf(0.58 + boost_iris * 0.45, 0.58, 0.82)
					mat.albedo_color = Color(w_iris, w_iris, w_iris, 1.0)
					mat.emission_enabled = true
					mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
					mat.emission_texture = mat.albedo_texture
					mat.emission = Color.WHITE
					mat.emission_energy_multiplier = e_iris
					lit_entries.append({"mat": mat, "base_color": Color.WHITE, "albedo_weight": w_iris, "emission_energy": e_iris, "textured": true, "min_deep_scale": 0.62})
	model_root.set_meta("mermaid_lit_entries", lit_entries)
	model_root.set_meta("mermaid_lit_depth", -999.0)
	update_mermaid_depth_lighting(model_root, 8.0, true)

static func update_mermaid_depth_lighting(model_root: Node3D, depth: float, force: bool = false) -> void:
	if not is_instance_valid(model_root) or not model_root.has_meta("mermaid_lit_entries"):
		return
	var clamped_depth := maxf(depth, 0.0)
	var last_depth := float(model_root.get_meta("mermaid_lit_depth", -999.0))
	if not force and absf(clamped_depth - last_depth) < 0.35:
		return
	model_root.set_meta("mermaid_lit_depth", clamped_depth)
	var deep_t := smoothstep(18.0, 260.0, clamped_depth)
	var tint := Color.WHITE.lerp(Color(0.84, 0.93, 1.0), deep_t * 0.52)
	var entries: Array = model_root.get_meta("mermaid_lit_entries")
	for entry: Dictionary in entries:
		var mat: StandardMaterial3D = entry.get("mat", null)
		if not is_instance_valid(mat):
			continue
		var min_scale := float(entry.get("min_deep_scale", 0.35))
		var scale := lerpf(1.0, min_scale, deep_t)
		var base_col: Color = entry["base_color"]
		mat.emission = Color(base_col.r * tint.r, base_col.g * tint.g, base_col.b * tint.b, 1.0)
		mat.emission_energy_multiplier = float(entry["emission_energy"]) * scale

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
				var is_face := _is_face_skin_part(String(record.name))
				var copy_key := "%d:face" % id if is_face else str(id)
				if not material_copies.has(copy_key):
					# Keep albedo, glass transparency, roughness, metal and texture
					# bindings exactly as authored. ModelFinish never sees this rig.
					var copy := original.duplicate(false) as Material
					copy.set_meta("reference_material", true)
					copy.set_meta("reference_role", _infer_material_role(original, String(record.name)))
					copy.set_meta("is_face_skin", is_face)
					material_copies[copy_key] = copy
				part.set_surface_override_material(surface, material_copies[copy_key])
			var arrays := part.mesh.surface_get_arrays(surface)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			triangles += (indices.size() if not indices.is_empty() else vertices.size()) / 3
		parent.add_child(part)
	var root_node := (drivers.body as Node3D).get_parent() as Node3D
	if is_instance_valid(root_node):
		configure_mermaid_materials(root_node)
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
				var is_face := _is_face_skin_part(String(part.name))
				var copy_key := "%d:face" % id if is_face else str(id)
				if not copies.has(copy_key):
					var material := source.duplicate(false) as Material
					material.set_meta("reference_material", true)
					material.set_meta("reference_role", _infer_material_role(source, String(part.name)))
					material.set_meta("is_face_skin", is_face)
					copies[copy_key] = material
				part.set_surface_override_material(surface, copies[copy_key])
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
	configure_mermaid_materials(model_root)
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
