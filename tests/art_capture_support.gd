extends RefCounted
## Shared capture-only controls. Gameplay continues to use review_time = -1.

static func environment(resolution: Vector2i, phase: float, capture_mode: String) -> Dictionary:
	var method := str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "unknown"))
	if RenderingServer.has_method("get_current_rendering_method"):
		method = str(RenderingServer.call("get_current_rendering_method"))
	var driver := "unknown"
	if RenderingServer.has_method("get_current_rendering_driver_name"):
		driver = str(RenderingServer.call("get_current_rendering_driver_name"))
	return {
		"engine": Engine.get_version_info(),
		"platform": OS.get_name(),
		"renderer": method,
		"rendering_driver": driver,
		"adapter": RenderingServer.get_video_adapter_name(),
		"adapter_vendor": RenderingServer.get_video_adapter_vendor(),
		"display_server": DisplayServer.get_name(),
		"resolution": [resolution.x, resolution.y],
		"vsync_mode": DisplayServer.window_get_vsync_mode(),
		"max_fps": Engine.max_fps,
		"capture_mode": capture_mode,
		"review_phase_seconds": phase,
		"deterministic_scope": "review_time shader uniforms and imported animation poses; static scene processing disabled",
	}

static func write_json(path: String, value: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null, "Cannot write review artifact: " + path)
	file.store_string(JSON.stringify(value, "\t") + "\n")

static func apply_review_phase(world: Node, phase: float) -> int:
	var seen: Dictionary = {}
	var updated := 0
	for part: GeometryInstance3D in world.find_children("*", "GeometryInstance3D", true, false):
		updated += _material_phase(part.material_override, phase, seen)
		if part is MeshInstance3D and part.mesh != null:
			for surface in range(part.mesh.get_surface_count()):
				updated += _material_phase(part.get_active_material(surface), phase, seen)
		elif part is MultiMeshInstance3D and part.multimesh != null and part.multimesh.mesh != null:
			for surface in range(part.multimesh.mesh.get_surface_count()):
				updated += _material_phase(part.multimesh.mesh.surface_get_material(surface), phase, seen)
	for player: AnimationPlayer in world.find_children("*", "AnimationPlayer", true, false):
		var clip := player.assigned_animation
		if not clip.is_empty() and player.has_animation(clip):
			var animation := player.get_animation(clip)
			player.seek(fposmod(phase, maxf(animation.length, 0.001)), true)
			player.pause()
	return updated

static func _material_phase(material: Material, phase: float, seen: Dictionary) -> int:
	if not material is ShaderMaterial or material.shader == null:
		return 0
	var id := material.get_instance_id()
	if seen.has(id):
		return 0
	seen[id] = true
	for uniform: Dictionary in material.shader.get_shader_uniform_list():
		if str(uniform.get("name", "")) == "review_time":
			material.set_shader_parameter("review_time", phase)
			return 1
	return 0
