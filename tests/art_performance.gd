extends SceneTree
## Reproducible real-renderer comparison. The same script runs in the frozen baseline.
const Ocean = preload("res://scripts/ocean.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	assert(DisplayServer.get_name() != "headless")
	root.size = Vector2i(1280, 800)
	var ocean = Ocean.new()
	root.add_child(ocean)
	ocean.set_process(false)
	var camera := Camera3D.new()
	camera.fov = 78.0
	camera.far = 240.0
	root.add_child(camera)
	var ecology = ocean.get_node("SeabedEcology")
	var report: Array = []
	for xz: Vector2 in [Vector2(-10, 20), Vector2(-315, 325), Vector2(26, -45), Vector2(-490, -90)]:
		var at := Vector3(xz.x, ecology.sample_floor_height(xz.x, xz.y) + 4.5, xz.y)
		camera.position = at
		camera.look_at(at + Vector3(10, -3, -20))
		ocean.set_depth(maxf(0, -at.y))
		for frame in range(80):
			ecology.update_observer(at, 0.016)
			await process_frame
		var times: Array[float] = []
		var calls := 0.0
		var triangles := 0.0
		for frame in range(100):
			var before := Time.get_ticks_usec()
			await process_frame
			await RenderingServer.frame_post_draw
			times.append(float(Time.get_ticks_usec() - before) / 1000.0)
			calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			triangles += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		times.sort()
		report.append({"xz": [xz.x, xz.y], "p50_ms": times[50], "p95_ms": times[95], "draw_calls": calls / 100.0, "triangles": triangles / 100.0,
			"video_memory": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED), "ecology": ecology.get_ecology_snapshot()})
	var output := "res://.tools/art-performance.json"
	if not OS.get_cmdline_user_args().is_empty():
		output = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("PASS art performance: ", JSON.stringify(report))
	ocean.queue_free()
	camera.queue_free()
	await process_frame
	quit()
