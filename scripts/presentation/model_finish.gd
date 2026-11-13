extends RefCounted
## Finishes code-built models without touching their gameplay pivots or colliders.
## Materials keep their identity so existing rage/stasis animations still own them.

const ArtDirection = preload("res://scripts/art_direction.gd")
static var _mesh_cache: Dictionary = {}

static func apply(root: Node3D, category: String) -> void:
	if bool(root.get_meta("art_finished", false)):
		return
	var seen: Dictionary = {}
	_finish_node(root, root, category, seen)
	root.set_meta("art_finished", true)

static func _finish_node(node: Node, root: Node3D, category: String, seen: Dictionary) -> void:
	if node != root and bool(node.get_meta("art_finished", false)):
		return
	if node is MeshInstance3D:
		var part := node as MeshInstance3D
		var label := String(part.name).to_lower()
		if category in ["school_fish", "sea_spider"] or label.contains("eye") or label.contains("spot") or label.contains("scale") or label.contains("sucker"):
			part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if part.mesh != null:
			if category != "environment":
				_finish_geometry(part, label, category)
			if part.material_override is StandardMaterial3D:
				_finish_material(part.material_override, label, category, seen)
			for index in range(part.mesh.get_surface_count()):
				var material: Material = part.get_surface_override_material(index)
				if material == null:
					material = part.mesh.surface_get_material(index)
				if material is StandardMaterial3D:
					_finish_material(material, label, category, seen)
	# Light placement/range belongs to the controller; tighten decorative emission only.
	for child in node.get_children():
		_finish_node(child, root, category, seen)

static func _finish_material(material: StandardMaterial3D, label: String, category: String, seen: Dictionary) -> void:
	var key := material.get_instance_id()
	if seen.has(key):
		return
	seen[key] = true
	if material.has_meta("painterly_finished"):
		return
	material.set_meta("painterly_finished", true)
	var original := material.albedo_color
	var skin_kind := category
	if category in ["scout", "titan", "mini", "vehicle"]:
		skin_kind = "submarine"
	if category in ["knife", "axe", "sonic", "marker", "booster", "shield"]:
		skin_kind = "weapon"
	var profile := ArtDirection.material_profile(skin_kind)
	var warm := original.r > original.b * 1.35 and original.r > original.g * 1.10
	var is_glass := material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
	var luminous := material.emission_enabled
	var color: Color = profile.base
	if category == "environment":
		# Keep regional pigments and the distinction between hot vents and cool beacons.
		color = original
		color.s = minf(color.s * 1.08, 0.82)
		color = color.lerp(ArtDirection.CYAN, 0.025)
		material.roughness = maxf(material.roughness, 0.63)
	elif skin_kind == "diver" and material.has_meta("diver_pigment"):
		# The expedition suit has authored navy/teal/gold roles. Preserve those
		# pigments rather than mapping every pale shell to the same light cyan.
		color = original
		material.metallic = minf(material.metallic, 0.22)
		material.roughness = maxf(material.roughness, 0.58 if not label.contains("visor") else 0.28)
	elif is_glass:
		color = Color("527d8c")
		color.a = original.a
		material.roughness = 0.19
	elif label.contains("belly") or label.contains("plastron") or label.contains("pale") or label.contains("tooth") or label.contains("fang") or label.contains("horn"):
		color = profile.tip
		material.roughness = 0.68
	elif original.get_luminance() < 0.12 or label.contains("rubber") or label.contains("seam") or label.contains("grip"):
		color = ArtDirection.INK.lightened(0.08)
		material.roughness = 0.73
	elif skin_kind == "diver":
		if warm:
			color = Color("edc969")
			material.roughness = 0.52
			material.metallic = 0.14
		elif original.get_luminance() < 0.35:
			color = Color("103951")
			material.roughness = 0.72
			material.metallic = 0.06
		elif original.get_luminance() < 0.58:
			color = Color("629eaa")
			material.roughness = 0.46
			material.metallic = 0.24
		else:
			color = Color("7ca8b1")
			material.roughness = 0.56
			material.metallic = 0.12
	elif skin_kind in ["submarine", "weapon", "diver"]:
		if warm:
			color = ArtDirection.AMBER.darkened(0.08)
		elif original.get_luminance() < 0.4:
			color = Color("24617f")
		else:
			color = Color("bfd8d4")
		material.roughness = float(profile.roughness)
		material.metallic = minf(material.metallic, 0.52)
	else:
		# Alternate existing skin/fin pigments while preserving material boundaries.
		color = profile.base.lerp(profile.tip, clampf(original.get_luminance() * 0.55, 0.0, 0.48))
		if warm:
			color = color.lerp(Color("b99872"), 0.35)
		material.roughness = float(profile.roughness)
		material.metallic = minf(material.metallic, 0.08)
	color.a = original.a
	material.albedo_color = color
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	material.rim_enabled = false
	if not is_glass:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	if luminous:
		if skin_kind == "diver" and material.has_meta("diver_pigment"):
			material.emission_energy_multiplier = minf(material.emission_energy_multiplier, 0.12)
			return
		var is_heat := category == "environment" and warm
		material.emission = ArtDirection.AMBER if is_heat else ArtDirection.CYAN
		material.emission_energy_multiplier = 0.7 if is_heat else 0.22
		if label.contains("eye") or label.contains("beacon") or label.contains("indicator"):
			material.emission_energy_multiplier = 0.4
		if label.contains("wing") or label.contains("belly") or label.contains("fin"):
			material.emission_energy_multiplier = 0.10

static func _finish_geometry(part: MeshInstance3D, label: String, category: String) -> void:
	var source := part.mesh
	if not source is SphereMesh:
		return
	var fin := label.contains("fin") or label.contains("flipper") or label.contains("paddle") or label.contains("wing")
	var body := label.contains("body") or label.contains("mantle") or label.contains("head") or label.contains("snout") or label.contains("fuselage") or label.contains("carapace")
	if not fin and not body:
		return
	var sphere := source as SphereMesh
	var shape_key := "%s:%s:%s:%s:%s" % [sphere.radius, sphere.height, sphere.radial_segments, sphere.rings, "fin" if fin else "body"]
	if _mesh_cache.has(shape_key):
		part.mesh = _mesh_cache[shape_key]
		return
	var arrays := sphere.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var radius := maxf(sphere.radius, 0.001)
	for index in range(vertices.size()):
		var point := vertices[index]
		var t := clampf(point.z / radius, -1.0, 1.0)
		if fin:
			point.x *= 0.84 - t * 0.14
			point.y += sin(t * PI) * radius * 0.045
		else:
			point.x *= 0.97 + 0.03 * cos(t * PI)
			point.y += sin(t * PI) * radius * 0.025
		vertices[index] = point
		# Smooth analytic normals remain stable across a small, low-frequency sculpt.
		normals[index] = Vector3(normals[index].x, normals[index].y, normals[index].z).normalized()
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh_cache[shape_key] = mesh
	part.mesh = mesh
