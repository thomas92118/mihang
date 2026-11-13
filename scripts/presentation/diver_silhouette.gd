extends RefCounted
## Original compact expedition suit. These cached meshes are visual-only and
## remain mounted on Diver's existing gameplay/weapon attachment pivots.

const CONTRACT_VERSION := "expedition-silhouette-1"
const TRIANGLE_BUDGET := 3600
static var _cache: Dictionary = {}

static func torso() -> ArrayMesh:
	return _loft("torso", [
		Vector4(-0.19, 0.074, 0.062, 0.012), Vector4(-0.15, 0.111, 0.075, 0.006),
		Vector4(-0.06, 0.122, 0.078, 0.0), Vector4(0.06, 0.146, 0.088, -0.004),
		Vector4(0.19, 0.184, 0.086, 0.0), Vector4(0.242, 0.162, 0.074, 0.0),
		Vector4(0.285, 0.098, 0.058, 0.0), Vector4(0.31, 0.068, 0.050, 0.0)
	], 16)

static func chest() -> ArrayMesh:
	return _loft("chest", [
		Vector4(-0.045, 0.056, 0.026, -0.064), Vector4(0.035, 0.108, 0.038, -0.063),
		Vector4(0.125, 0.140, 0.044, -0.062), Vector4(0.198, 0.132, 0.038, -0.057),
		Vector4(0.250, 0.084, 0.026, -0.048)
	], 12)

static func helmet() -> ArrayMesh:
	return _loft("helmet", [
		Vector4(-0.102, 0.055, 0.053, 0.004), Vector4(-0.080, 0.089, 0.079, 0.004),
		Vector4(-0.025, 0.109, 0.097, 0.005), Vector4(0.050, 0.105, 0.095, 0.008),
		Vector4(0.104, 0.078, 0.070, 0.012), Vector4(0.133, 0.023, 0.023, 0.012)
	], 16)

static func visor() -> ArrayMesh:
	return _loft("visor", [
		Vector4(-0.052, 0.060, 0.018, -0.074), Vector4(-0.024, 0.095, 0.034, -0.076),
		Vector4(0.010, 0.099, 0.036, -0.077), Vector4(0.040, 0.094, 0.032, -0.076),
		Vector4(0.064, 0.062, 0.016, -0.072)
	], 14)

static func visor_rim() -> ArrayMesh:
	return _loft("visor_rim", [
		Vector4(-0.058, 0.064, 0.016, -0.076), Vector4(-0.048, 0.082, 0.022, -0.081)
	], 12)

static func collar() -> ArrayMesh:
	return _loft("collar", [
		Vector4(-0.018, 0.082, 0.066, -0.002), Vector4(0.000, 0.088, 0.070, -0.003),
		Vector4(0.016, 0.080, 0.064, -0.001)
	], 12)

static func belt() -> ArrayMesh:
	return _loft("belt", [Vector4(-0.128, 0.116, 0.079, 0.0), Vector4(-0.108, 0.120, 0.081, 0.0)], 12)

static func backpack() -> ArrayMesh:
	return _loft("backpack", [
		Vector4(-0.176, 0.054, 0.027, 0.020), Vector4(-0.133, 0.096, 0.043, 0.026),
		Vector4(0.105, 0.103, 0.049, 0.023), Vector4(0.170, 0.076, 0.040, 0.015),
		Vector4(0.192, 0.035, 0.022, 0.008)
	], 12)

static func tank() -> ArrayMesh:
	return _loft("tank", [
		Vector4(-0.161, 0.013, 0.015, 0.0), Vector4(-0.141, 0.034, 0.037, 0.0),
		Vector4(-0.099, 0.039, 0.040, 0.0), Vector4(0.109, 0.036, 0.038, -0.003),
		Vector4(0.148, 0.026, 0.030, -0.004), Vector4(0.165, 0.009, 0.012, -0.004)
	], 12)

static func shoulder() -> ArrayMesh:
	return _loft("shoulder", [
		Vector4(-0.076, 0.032, 0.034, -0.004), Vector4(-0.028, 0.044, 0.044, -0.002),
		Vector4(0.016, 0.043, 0.042, 0.001), Vector4(0.046, 0.021, 0.022, 0.003)
	], 10)

static func upper_arm() -> ArrayMesh:
	return _loft("upper_arm", [
		Vector4(-0.133, 0.029, 0.030, 0.0), Vector4(-0.073, 0.041, 0.039, 0.0),
		Vector4(0.054, 0.047, 0.043, 0.0), Vector4(0.108, 0.033, 0.033, 0.0)
	], 10)

static func forearm() -> ArrayMesh:
	return _loft("forearm", [
		Vector4(-0.125, 0.027, 0.027, 0.0), Vector4(-0.083, 0.034, 0.034, 0.0),
		Vector4(0.042, 0.041, 0.037, 0.0), Vector4(0.109, 0.032, 0.032, 0.0)
	], 10)

static func glove() -> ArrayMesh:
	return _loft("glove", [
		Vector4(-0.043, 0.025, 0.025, -0.004), Vector4(-0.013, 0.038, 0.037, 0.0),
		Vector4(0.024, 0.034, 0.033, 0.003), Vector4(0.043, 0.019, 0.022, 0.006)
	], 10)

static func thigh() -> ArrayMesh:
	return _loft("thigh", [
		Vector4(-0.147, 0.036, 0.039, 0.0), Vector4(-0.079, 0.049, 0.050, 0.0),
		Vector4(0.071, 0.064, 0.061, 0.0), Vector4(0.132, 0.049, 0.051, 0.0)
	], 12)

static func knee() -> ArrayMesh:
	return _loft("knee", [
		Vector4(-0.049, 0.030, 0.030, 0.0), Vector4(-0.014, 0.044, 0.045, -0.005),
		Vector4(0.025, 0.042, 0.042, 0.0), Vector4(0.045, 0.028, 0.030, 0.0)
	], 10)

static func calf() -> ArrayMesh:
	return _loft("calf", [
		Vector4(-0.142, 0.027, 0.031, 0.0), Vector4(-0.060, 0.039, 0.043, 0.0),
		Vector4(0.045, 0.049, 0.046, 0.002), Vector4(0.123, 0.035, 0.035, 0.0)
	], 12)

static func fin() -> ArrayMesh:
	if _cache.has("fin"):
		return _cache["fin"]
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	_append_fin_lobe(vertices, normals, uvs, indices, [
		[0.0, 0.002, -0.016, 0.028, 0.018],
		[0.0, 0.002, 0.035, 0.035, 0.020],
		[0.0, 0.001, 0.125, 0.029, 0.014],
		[0.0, 0.000, 0.230, 0.020, 0.0085],
		[0.0, -0.001, 0.315, 0.008, 0.0045],
	], 8)
	for side in [-1.0, 1.0]:
		_append_fin_lobe(vertices, normals, uvs, indices, [
			[side * 0.016, 0.000, 0.020, 0.018, 0.0120],
			[side * 0.021, -0.001, 0.135, 0.0245, 0.0090],
			[side * 0.025, -0.002, 0.250, 0.0290, 0.0066],
			[side * 0.028, -0.003, 0.352, 0.0285, 0.0050],
			[side * 0.037, -0.0045, 0.436, 0.0165, 0.0035],
			[side * 0.045, -0.006, 0.520, 0.0032, 0.0016],
		], 8)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var blade := ArrayMesh.new()
	blade.resource_name = "fin"
	blade.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_cache["fin"] = blade
	return blade

static func _append_fin_lobe(vertices: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array, indices: PackedInt32Array, rings: Array, segments: int) -> void:
	var base := vertices.size()
	var ring_count := rings.size()
	for ring in range(ring_count):
		var cur: Array = rings[ring]
		var below: Array = rings[maxi(0, ring - 1)]
		var above: Array = rings[mini(ring_count - 1, ring + 1)]
		var cx := float(cur[0])
		var cy := float(cur[1])
		var z := float(cur[2])
		var rx := float(cur[3])
		var ry := float(cur[4])
		var dcx := float(above[0]) - float(below[0])
		var dcy := float(above[1]) - float(below[1])
		var dz := float(above[2]) - float(below[2])
		var drx := float(above[3]) - float(below[3])
		var dry := float(above[4]) - float(below[4])
		for segment in range(segments):
			var angle := TAU * float(segment) / float(segments)
			var c := cos(angle)
			var s := sin(angle)
			vertices.append(Vector3(cx + c * rx, cy + s * ry, z))
			var axial := Vector3(dcx + c * drx, dcy + s * dry, dz)
			var angular := Vector3(-s * rx, c * ry, 0.0)
			normals.append(angular.cross(axial).normalized())
			uvs.append(Vector2(float(segment) / float(segments), float(ring) / float(ring_count - 1)))
			if ring < ring_count - 1:
				var a := base + ring * segments + segment
				var next := base + ring * segments + (segment + 1) % segments
				indices.append_array(PackedInt32Array([a, a + segments, next, next, a + segments, next + segments]))
	for cap in [0, ring_count - 1]:
		var cur: Array = rings[cap]
		var cx := float(cur[0])
		var cy := float(cur[1])
		var z := float(cur[2])
		var rx := float(cur[3])
		var ry := float(cur[4])
		var center := vertices.size()
		var normal := Vector3(0.0, 0.0, -1.0) if cap == 0 else Vector3(0.0, 0.0, 1.0)
		vertices.append(Vector3(cx, cy, z))
		normals.append(normal)
		uvs.append(Vector2(0.5, 0.5))
		for segment in range(segments):
			var angle := TAU * float(segment) / float(segments)
			vertices.append(Vector3(cx + cos(angle) * rx, cy + sin(angle) * ry, z))
			normals.append(normal)
			uvs.append(Vector2(cos(angle), sin(angle)) * 0.5 + Vector2.ONE * 0.5)
		for segment in range(segments):
			var a := center + 1 + segment
			var b := center + 1 + (segment + 1) % segments
			indices.append_array(PackedInt32Array([center, a, b] if cap == 0 else [center, b, a]))

static func _loft(key: String, profile: Array, segments: int) -> ArrayMesh:
	if _cache.has(key):
		return _cache[key]
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for ring in range(profile.size()):
		var shape: Vector4 = profile[ring]
		var below: Vector4 = profile[maxi(0, ring - 1)]
		var above: Vector4 = profile[mini(profile.size() - 1, ring + 1)]
		var span := above - below
		for segment in range(segments):
			var angle := TAU * float(segment) / float(segments)
			var c := cos(angle)
			var s := sin(angle)
			vertices.append(Vector3(c * shape.y, shape.x, s * shape.z + shape.w))
			var vertical := Vector3(c * span.y, span.x, s * span.z + span.w)
			var angular := Vector3(-s * shape.y, 0.0, c * shape.z)
			normals.append(vertical.cross(angular).normalized())
			uvs.append(Vector2(float(segment) / float(segments), float(ring) / float(profile.size() - 1)))
			if ring < profile.size() - 1:
				var a := ring * segments + segment
				var next := ring * segments + (segment + 1) % segments
				indices.append_array(PackedInt32Array([a, next, a + segments, next, next + segments, a + segments]))
	# Flat sealed caps use separate normals; sides keep continuous highlights.
	for cap in [0, profile.size() - 1]:
		var shape: Vector4 = profile[cap]
		var center := vertices.size()
		var normal := Vector3.DOWN if cap == 0 else Vector3.UP
		vertices.append(Vector3(0.0, shape.x, shape.w))
		normals.append(normal)
		uvs.append(Vector2(0.5, 0.5))
		for segment in range(segments):
			var angle := TAU * float(segment) / float(segments)
			vertices.append(Vector3(cos(angle) * shape.y, shape.x, sin(angle) * shape.z + shape.w))
			normals.append(normal)
			uvs.append(Vector2(cos(angle), sin(angle)) * 0.5 + Vector2.ONE * 0.5)
		for segment in range(segments):
			var a := center + 1 + segment
			var b := center + 1 + (segment + 1) % segments
			indices.append_array(PackedInt32Array([center, b, a] if cap == 0 else [center, a, b]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.resource_name = key
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_cache[key] = mesh
	return mesh
