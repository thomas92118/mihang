extends RefCounted
## Blender-authored visual parts share one library. Gameplay pivots, lights and
## per-instance pigments remain owned by their existing controllers.

const LIBRARY_PATH := "res://assets/models/expedition_library.glb"
static var _meshes: Dictionary = {}
static var _details: Dictionary = {}
static var _surface_materials: Dictionary = {}
static var _named_materials: Dictionary = {}
static var _creature_material_cache: Dictionary = {}
static var _loaded := false

static func mesh(key: String) -> ArrayMesh:
	if not _loaded:
		_load_library()
	return _meshes.get(key, null) as ArrayMesh

static func available() -> bool:
	return mesh("diver_torso") != null

static func _load_library() -> void:
	_loaded = true
	if not ResourceLoader.exists(LIBRARY_PATH):
		return
	var packed := load(LIBRARY_PATH) as PackedScene
	if packed == null:
		return
	var instance := packed.instantiate()
	for child: MeshInstance3D in instance.find_children("*", "MeshInstance3D", true, false):
		if child.mesh is ArrayMesh:
			var key := String(child.name)
			_details[key] = child.mesh.surface_get_material(0)
			var surf_mats: Array[Material] = []
			for s_idx in child.mesh.get_surface_count():
				var smat := child.mesh.surface_get_material(s_idx)
				surf_mats.append(smat)
				if smat != null and smat.resource_name != "":
					_named_materials[smat.resource_name] = smat
			_surface_materials[key] = surf_mats
			var geometry := child.mesh.duplicate(false) as ArrayMesh
			geometry.resource_name = key
			# Shared geometry must not carry a mutable surface material into
			# ModelFinish or rage/stasis controllers on separate creatures.
			for surface in geometry.get_surface_count():
				geometry.surface_set_material(surface, null)
			_meshes[key] = geometry
	instance.free()

static func _clone_pbr_material(source_name: String, role: String, fallback_color: Color) -> StandardMaterial3D:
	if not _loaded:
		_load_library()
	var mat := StandardMaterial3D.new()
	mat.resource_name = source_name + "_instance"
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.set_meta("authored_pbr", true)
	mat.set_meta("painterly_finished", true)
	var src := _named_materials.get(source_name, null) as BaseMaterial3D
	if src != null:
		mat.albedo_color = src.albedo_color
		mat.albedo_texture = src.albedo_texture
		mat.normal_enabled = src.normal_enabled
		mat.normal_texture = src.normal_texture
		mat.normal_scale = src.normal_scale if src.normal_enabled else 0.65
		mat.roughness = src.roughness
		mat.roughness_texture = src.roughness_texture
		mat.roughness_texture_channel = src.roughness_texture_channel
		mat.metallic = src.metallic
		mat.metallic_specular = src.metallic_specular
		mat.metallic_texture = src.metallic_texture
		mat.metallic_texture_channel = src.metallic_texture_channel
		mat.ao_enabled = src.ao_enabled
		mat.ao_texture = src.ao_texture
		mat.ao_texture_channel = src.ao_texture_channel
		mat.emission_enabled = src.emission_enabled
		mat.emission = src.emission
		mat.emission_energy_multiplier = src.emission_energy_multiplier
		mat.emission_operator = src.emission_operator
		mat.emission_texture = src.emission_texture
	else:
		mat.albedo_color = fallback_color
		mat.roughness = 0.44
	if role == "fauna":
		if mat.emission_texture != null:
			mat.emission_enabled = true
			mat.emission = Color.WHITE
			mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
			mat.emission_energy_multiplier = 0.55
	elif role == "fauna_glow":
		mat.emission_enabled = true
		mat.emission_texture = null
		mat.emission_operator = BaseMaterial3D.EMISSION_OP_ADD
		mat.emission = fallback_color
		mat.emission_energy_multiplier = 0.42
	elif role == "sub_hull":
		if mat.emission_texture != null:
			mat.emission_enabled = true
			mat.emission = Color.WHITE
			mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
			mat.emission_energy_multiplier = 1.05
	elif role == "sub_glass":
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_BACK
		mat.albedo_color = Color(0.42, 0.76, 0.82, 0.30)
		mat.albedo_texture = null
		mat.emission_enabled = false
		mat.roughness = 0.09
		mat.metallic = 0.08
		mat.metallic_specular = 0.85
	return mat

static func create_creature_materials(calm_glow: Color, fallback_albedo := Color(0.75, 0.78, 0.82), share_calm: bool = true) -> Dictionary:
	if not share_calm:
		return {
			"fauna": _clone_pbr_material("HeroFaunaAtlas", "fauna", fallback_albedo),
			"glow": _clone_pbr_material("HeroFaunaGlow", "fauna_glow", calm_glow),
		}
	var cache_key := "%s|%s" % [calm_glow.to_html(true), fallback_albedo.to_html(true)]
	if not _creature_material_cache.has(cache_key):
		_creature_material_cache[cache_key] = {
			"fauna": _clone_pbr_material("HeroFaunaAtlas", "fauna", fallback_albedo),
			"glow": _clone_pbr_material("HeroFaunaGlow", "fauna_glow", calm_glow),
		}
	var shared: Dictionary = _creature_material_cache[cache_key]
	return {
		"fauna": shared["fauna"],
		"glow": shared["glow"],
	}

static func create_submarine_materials() -> Dictionary:
	return {
		"hull": _clone_pbr_material("HeroSubmarineAtlas", "sub_hull", Color(0.91, 0.87, 0.80)),
		"glass": _clone_pbr_material("HeroSubmarineGlass", "sub_glass", Color(0.42, 0.76, 0.82, 0.30)),
	}

static func attach_part(parent: Node3D, node_name: String, mesh_key: String, instance_mats: Dictionary, pos := Vector3.ZERO, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var authored := mesh(mesh_key)
	if authored == null:
		return null
	var part := MeshInstance3D.new()
	part.name = node_name
	part.mesh = authored
	part.position = pos
	part.rotation = rot
	part.scale = scl
	part.set_meta("blender_surface", true)
	part.set_meta("art_finished", true)
	var surf_mats: Array = _surface_materials.get(mesh_key, [])
	var default_mat: StandardMaterial3D = instance_mats.get("fauna", instance_mats.get("hull", null))
	for s_idx in authored.get_surface_count():
		var orig: Material = surf_mats[s_idx] if s_idx < surf_mats.size() else null
		var rname := orig.resource_name if orig != null else ""
		var chosen: StandardMaterial3D = default_mat
		if rname.contains("Glass") and instance_mats.has("glass"):
			chosen = instance_mats["glass"]
		elif rname.contains("Glow") and instance_mats.has("glow"):
			chosen = instance_mats["glow"]
		if chosen != null:
			part.set_surface_override_material(s_idx, chosen)
	parent.add_child(part)
	return part

static func bind_detail(material: Material, source_mesh: Mesh) -> void:
	if not material is StandardMaterial3D or source_mesh == null or source_mesh.get_surface_count() == 0:
		return
	var target := material as StandardMaterial3D
	if bool(target.get_meta("blender_detail", false)):
		return
	var source := _details.get(String(source_mesh.resource_name), null) as BaseMaterial3D
	if source == null or source.albedo_texture == null:
		return
	target.albedo_texture = source.albedo_texture
	target.normal_enabled = source.normal_enabled
	target.normal_texture = source.normal_texture
	target.normal_scale = 0.35
	target.roughness_texture = source.roughness_texture
	target.roughness_texture_channel = source.roughness_texture_channel
	target.set_meta("blender_detail", true)

static func finish_diver(root: Node3D) -> void:
	if not available():
		return
	for part: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if part.mesh != null and String(part.mesh.resource_name).begins_with("diver_"):
			bind_detail(part.material_override, part.mesh)
	root.set_meta("blender_library", LIBRARY_PATH)

static func creature_mesh(species: String, label: String) -> ArrayMesh:
	var lower := label.to_lower().replace(" ", "")
	var key := ""
	if lower in ["body", "streamlinedbody", "fishfuselage", "wolfbody"]:
		key = "creature_" + species + "_body"
	elif lower in ["roundedhead", "dragonhead", "streamlinedhead", "wolfhead", "turtlehead", "head"]:
		key = "creature_" + species + "_head"
	elif lower in ["carapace", "armoredabdomen"]:
		key = "creature_" + species + "_shell"
	elif lower == "overlappingscalesegment":
		key = "creature_water_dragon_segment"
	elif lower == "mantledome":
		key = "creature_kraken_mantle"
	elif lower == "lowerhead":
		key = "creature_kraken_head"
	elif lower.contains("jaw") or lower in ["longarmoredsnout", "snout", "muzzle"]:
		key = "creature_snout"
	elif lower.contains("belly") or lower.contains("plastron"):
		key = "creature_belly"
	elif lower.contains("caudal") or lower == "tailfin":
		key = "creature_caudal"
	elif lower == "turtletail":
		key = "creature_tail"
	elif lower.contains("flipper") or lower.contains("paddle") or lower.contains("wing") or lower in ["sidefin", "sweepingdragonfin"]:
		key = "creature_swept_fin"
	return mesh(key) if key != "" else null

static func vehicle_mesh(kind: String, label: String) -> ArrayMesh:
	var key := ""
	if label in ["MainOvalHull", "TitanOvalHull", "VerticalOvalHull"]:
		key = "vehicle_" + kind + "_hull"
	elif label in ["CockpitCanopy", "BridgeDome", "FrontGlassDome", "PodWindow"]:
		key = "vehicle_canopy"
	elif label in ["VentralKeel", "TitanKeelPod", "PodBody", "PodTrim"]:
		key = "vehicle_keel"
	elif label.begins_with("Fin") or label == "SailFin":
		key = "vehicle_fin"
	return mesh(key) if key != "" else null
