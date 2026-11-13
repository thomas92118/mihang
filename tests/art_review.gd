extends SceneTree
## Fixed cameras shared by the before/after art review; requires a real renderer.
const Ocean = preload("res://scripts/ocean.gd")
const Capture = preload("res://tests/art_capture_support.gd")
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

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	assert(DisplayServer.get_name() != "headless", "Use the real Compatibility renderer")
	root.size = Vector2i(1280, 800)
	var args := OS.get_cmdline_user_args()
	var output := args[0] if not args.is_empty() else "res://.tools/abzu-review/after"
	var only_region := args[1] if args.size() > 1 and not args[1].begins_with("--") else ""
	var samples := 80
	var warmup := 60
	var phase := 12.0
	for index in range(args.size()):
		if args[index] == "--samples" and index + 1 < args.size():
			samples = maxi(20, int(args[index + 1]))
		elif args[index] == "--warmup" and index + 1 < args.size():
			warmup = maxi(12, int(args[index + 1]))
		elif args[index] == "--phase" and index + 1 < args.size():
			phase = maxf(0.0, float(args[index + 1]))
	DirAccess.make_dir_recursive_absolute(output)
	var ocean = Ocean.new()
	root.add_child(ocean)
	# Disable inherited child processing too: fixed-camera evidence is explicitly
	# static and cannot substitute for a real-time gameplay performance run.
	ocean.process_mode = Node.PROCESS_MODE_DISABLED
	var camera := Camera3D.new()
	camera.fov = 64.0
	camera.far = 330.0
	root.add_child(camera)
	var ecology = ocean.get_node("SeabedEcology")
	var report: Array = []
	var view_count := 0
	var controlled_materials := 0
	for shot: Array in SHOTS:
		if not only_region.is_empty() and str(shot[0]) != only_region:
			continue
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
			for frame in range(warmup):
				ecology.update_observer(at, 0.016)
				await process_frame
			controlled_materials = maxi(controlled_materials, Capture.apply_review_phase(ocean, phase))
			await process_frame
			await RenderingServer.frame_post_draw
			var picture := root.get_texture().get_image()
			assert(picture.save_png(output.path_join("%s-%s.png" % [shot[0], "arrival" if view == 0 else "detail"])) == OK)
			view_count += 1
			if view == 0:
				var times: Array[float] = []
				var calls := 0.0
				for frame in range(samples):
					var before := Time.get_ticks_usec()
					await process_frame
					await RenderingServer.frame_post_draw
					times.append(float(Time.get_ticks_usec() - before) / 1000.0)
					calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
				times.sort()
				report.append({"region": shot[0], "p50_ms": times[mini(samples - 1, int(samples * 0.5))],
					"p95_ms": times[mini(samples - 1, int(ceil(samples * 0.95)) - 1)], "draw_calls": calls / float(samples),
					"samples": samples, "warmup_frames": warmup, "camera_position": [at.x, at.y, at.z],
					"video_memory": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)})
		print("REVIEW ", shot[0])
	assert(not report.is_empty(), "No region matched review selection: " + only_region)
	Capture.write_json(output.path_join("performance.json"), report)
	var metadata := Capture.environment(root.size, phase, "static_fixed_camera")
	metadata["camera_script"] = "tests/art_review.gd"
	metadata["samples_per_region"] = samples
	metadata["warmup_frames"] = warmup
	metadata["controlled_shader_materials"] = controlled_materials
	metadata["composition_seed"] = 671112
	metadata["ecology_seed"] = 381193
	metadata["views_captured"] = view_count
	Capture.write_json(output.path_join("environment.json"), metadata)
	print("PASS: ", view_count, " fixed-camera region views (static capture): ", output)
	ocean.free()
	camera.free()
	quit()
