extends SceneTree
## Fixed cameras shared by the before/after art review; requires a real renderer.
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

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	assert(DisplayServer.get_name() != "headless", "Use the real Compatibility renderer")
	root.size = Vector2i(1280, 800)
	var args := OS.get_cmdline_user_args()
	var output := args[0] if not args.is_empty() else "res://.tools/abzu-review/after"
	DirAccess.make_dir_recursive_absolute(output)
	var ocean = Ocean.new()
	root.add_child(ocean)
	ocean.set_process(false)
	var camera := Camera3D.new()
	camera.fov = 64.0
	camera.far = 330.0
	root.add_child(camera)
	var ecology = ocean.get_node("SeabedEcology")
	var report: Array = []
	for shot: Array in SHOTS:
		if args.size() > 1 and str(shot[0]) != args[1]:
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
			for frame in range(60):
				ecology.update_observer(at, 0.016)
				await process_frame
			await RenderingServer.frame_post_draw
			var picture := root.get_texture().get_image()
			assert(picture.save_png(output.path_join("%s-%s.png" % [shot[0], "arrival" if view == 0 else "detail"])) == OK)
			if view == 0:
				var times: Array[float] = []
				var calls := 0.0
				for frame in range(80):
					var before := Time.get_ticks_usec()
					await process_frame
					await RenderingServer.frame_post_draw
					times.append(float(Time.get_ticks_usec() - before) / 1000.0)
					calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
				times.sort()
				report.append({"region": shot[0], "p50_ms": times[40], "p95_ms": times[76], "draw_calls": calls / 80.0,
					"video_memory": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)})
		print("REVIEW ", shot[0])
	var file := FileAccess.open(output.path_join("performance.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("PASS: 18 fixed-camera region views: ", output)
	ocean.free()
	camera.free()
	quit()
