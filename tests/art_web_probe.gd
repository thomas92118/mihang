extends Node
## Export-only fixed-camera Web benchmark. build_art_web_probe.mjs copies this
## into an isolated project's scripts/ and never changes the game's main scene.

const Ocean = preload("res://scripts/ocean.gd")
const SHOTS := [
	["core", Vector2(0, -8), Vector2(20, 34), 5.0],
	["atoll", Vector2(40, 340), Vector2(25, 38), 5.0],
	["kelp", Vector2(-260, 280), Vector2(25, 40), 9.0],
	["ridge", Vector2(380, 290), Vector2(30, 45), 9.0],
	["citadel", Vector2(460, -60), Vector2(27, 45), 8.0],
	["wreck", Vector2(420, -380), Vector2(30, 40), 7.0],
	["bones", Vector2(-480, -90), Vector2(35, 56), 13.0],
	["caldera", Vector2(-440, -420), Vector2(32, 48), 10.0],
	["hadal", Vector2(60, -640), Vector2(32, 48), 12.0],
]

var _report: Array = []
var _environment: Dictionary = {}

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	assert(OS.has_feature("web"), "This probe is for exported Web builds")
	var options: Dictionary = JSON.parse_string(str(JavaScriptBridge.eval("JSON.stringify(Object.fromEntries(new URLSearchParams(window.location.search)))", true)))
	var samples := maxi(20, int(options.get("samples", "80")))
	var warmup := maxi(12, int(options.get("warmup", "60")))
	var phase := maxf(0.0, float(options.get("phase", "12.0")))
	var resolution := Vector2i(int(options.get("width", "1280")), int(options.get("height", "800")))
	get_window().size = resolution
	_environment = {
		"engine": Engine.get_version_info(), "platform": OS.get_name(),
		"renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "unknown")),
		"adapter": RenderingServer.get_video_adapter_name(), "adapter_vendor": RenderingServer.get_video_adapter_vendor(),
		"display_server": DisplayServer.get_name(), "resolution": [resolution.x, resolution.y],
		"vsync_mode": DisplayServer.window_get_vsync_mode(), "max_fps": Engine.max_fps,
		"capture_mode": "web_static_fixed_camera", "samples_per_region": samples,
		"warmup_frames": warmup, "review_phase_seconds": phase, "world_seed": 671112,
		"camera_fov": 64.0, "camera_far": 330.0,
		"metric_scope": "Browser-paced Godot process_frame plus frame_post_draw intervals; static scene; not GPU timer queries or gameplay throughput",
		"deterministic_scope": "Imported animation poses and available review_time uniforms; legacy shaders without that uniform still use TIME",
	}
	_publish("building")
	await get_tree().process_frame
	var ocean = Ocean.new()
	add_child(ocean)
	ocean.process_mode = Node.PROCESS_MODE_DISABLED
	var ecology = ocean.get_node("SeabedEcology")
	var camera := Camera3D.new()
	camera.fov = 64.0
	camera.far = 330.0
	camera.current = true
	add_child(camera)
	var controls := 0
	for shot: Array in SHOTS:
		var center: Vector2 = shot[1]
		var floor_y: float = ecology.sample_floor_height(center.x, center.y)
		for view in range(2):
			var offset: Vector2 = shot[2] * (1.0 if view == 0 else 0.48)
			var at := Vector3(center.x + offset.x, floor_y + float(shot[3]) + (6.0 if view == 0 else 2.0), center.y + offset.y)
			at.y = maxf(at.y, ecology.sample_floor_height(at.x, at.z) + 3.5)
			at.y = minf(at.y, -2.0)
			camera.position = at
			camera.look_at(Vector3(center.x, floor_y + float(shot[3]) * 0.5, center.y))
			ocean.set_depth(-at.y)
			if ocean.has_method("set_art_observer"):
				ocean.call("set_art_observer", at)
			_publish("warming", {"region": shot[0], "view": view})
			for frame in range(warmup):
				ecology.update_observer(at, 1.0 / 60.0)
				await get_tree().process_frame
			controls = maxi(controls, _apply_phase(ocean, phase))
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			if view == 0:
				_publish("measuring", {"region": shot[0], "view": view})
				var times: Array[float] = []
				var calls := 0.0
				for frame in range(samples):
					var before := Time.get_ticks_usec()
					await get_tree().process_frame
					await RenderingServer.frame_post_draw
					times.append(float(Time.get_ticks_usec() - before) / 1000.0)
					calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
				times.sort()
				var memory := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
				_report.append({
					"region": shot[0], "p50_ms": times[mini(samples - 1, int(samples * 0.5))],
					"p95_ms": times[mini(samples - 1, int(ceil(samples * 0.95)) - 1)],
					"draw_calls": calls / float(samples), "video_memory": memory if memory > 0.0 else null,
					"samples": samples, "warmup_frames": warmup, "camera_position": [at.x, at.y, at.z],
					"floor_y": floor_y,
				})
			var capture := "%s-%s" % [shot[0], "arrival" if view == 0 else "detail"]
			_publish("capture_ready", {"region": shot[0], "view": view, "capture": capture})
			# The browser takes the screenshot and explicitly acknowledges the pose.
			# That work is outside the measured interval.
			var deadline := Time.get_ticks_msec() + 45000
			while str(JavaScriptBridge.eval("window.artReviewAck || ''", true)) != capture:
				if Time.get_ticks_msec() > deadline:
					_publish("error", {"message": "Screenshot acknowledgement timed out: " + capture})
					return
				await get_tree().process_frame
	_environment["controlled_shader_materials"] = controls
	_publish("done", {"views_captured": SHOTS.size() * 2})
	print("PASS: Web art probe, nine regions, eighteen camera views")

func _publish(status: String, progress: Dictionary = {}) -> void:
	var state := {"status": status, "environment": _environment, "regions": _report}
	state.merge(progress)
	JavaScriptBridge.eval("window.artReview = " + JSON.stringify(state) + ";", true)

func _apply_phase(world: Node, phase: float) -> int:
	var seen: Dictionary = {}
	var count := 0
	for part: GeometryInstance3D in world.find_children("*", "GeometryInstance3D", true, false):
		count += _material_phase(part.material_override, phase, seen)
		if part is MeshInstance3D and part.mesh != null:
			for surface in range(part.mesh.get_surface_count()):
				count += _material_phase(part.get_active_material(surface), phase, seen)
		elif part is MultiMeshInstance3D and part.multimesh != null and part.multimesh.mesh != null:
			for surface in range(part.multimesh.mesh.get_surface_count()):
				count += _material_phase(part.multimesh.mesh.surface_get_material(surface), phase, seen)
	for player: AnimationPlayer in world.find_children("*", "AnimationPlayer", true, false):
		var clip := player.assigned_animation
		if not clip.is_empty() and player.has_animation(clip):
			var animation := player.get_animation(clip)
			player.seek(fposmod(phase, maxf(animation.length, 0.001)), true)
			player.pause()
	return count

func _material_phase(material: Material, phase: float, seen: Dictionary) -> int:
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
