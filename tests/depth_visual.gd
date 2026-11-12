extends SceneTree

# Real-renderer review of depth, lamp illumination and formerly empty frontiers.
# Godot --path . --log-file .tools/depth-visual.log -s tests/depth_visual.gd
const Ocean = preload("res://scripts/ocean.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	assert(DisplayServer.get_name() != "headless", "Depth review requires a real renderer")
	var finished := [false]
	create_timer(90.0).timeout.connect(func() -> void:
		if not finished[0]:
			printerr("FAIL: Depth visual review timed out")
			quit(1)
	)
	var ocean = Ocean.new()
	root.add_child(ocean)
	ocean.set_process(false)
	var camera := Camera3D.new()
	camera.fov = 78.0
	camera.far = 280.0
	root.add_child(camera)
	var lamp := SpotLight3D.new()
	lamp.light_color = Color(1.0, 0.95, 0.85)
	lamp.light_energy = 7.0
	lamp.spot_range = 55.0
	lamp.spot_angle = 52.0
	camera.add_child(lamp)
	var output := "res://.tools/depth-review"
	if not OS.get_cmdline_user_args().is_empty():
		output = OS.get_cmdline_user_args()[0]
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	var shots := [
		{"name": "01-home-reef", "xz": Vector2(-10, 20), "look": Vector2(0, 0), "height": 4.5, "lamp": false},
		{"name": "02-northern-atoll", "xz": Vector2(90, 390), "look": Vector2(83, 370), "height": 4.5, "lamp": false},
		{"name": "03-kelp-strait", "xz": Vector2(-315, 325), "look": Vector2(-302, 306), "height": 5.5, "lamp": false},
		{"name": "04-outer-east", "xz": Vector2(625, -80), "look": Vector2(607, -101), "height": 4.0, "lamp": true},
		{"name": "05-continental-slope", "xz": Vector2(26, -45), "look": Vector2(31, -57), "height": 4.5, "lamp": true},
		{"name": "06-caldera", "xz": Vector2(-460, -440), "look": Vector2(-441, -454), "height": 5.0, "lamp": true},
		{"name": "07-hadal-ambient", "xz": Vector2(90, -700), "look": Vector2(104, -715), "height": 4.0, "lamp": false},
		{"name": "08-hadal-lamp", "xz": Vector2(90, -700), "look": Vector2(104, -715), "height": 4.0, "lamp": true},
		{"name": "09-far-northeast", "xz": Vector2(780, 760), "look": Vector2(765, 742), "height": 4.0, "lamp": false},
		{"name": "10-far-southwest", "xz": Vector2(-790, -720), "look": Vector2(-774, -738), "height": 4.0, "lamp": true},
		{"name": "11-shelf-ridge", "xz": Vector2(390, 300), "look": Vector2(405, 285), "height": 4.5, "lamp": true},
		{"name": "12-bathyal-bonefield", "xz": Vector2(-490, -90), "look": Vector2(-475, -105), "height": 5.0, "lamp": true},
	]
	var ecology = ocean.get_node("SeabedEcology")
	var abyss_ambient: Image
	for shot: Dictionary in shots:
		var xz: Vector2 = shot["xz"]
		var look_xz: Vector2 = shot["look"]
		var at := Vector3(xz.x, ecology.sample_floor_height(xz.x, xz.y) + float(shot["height"]), xz.y)
		var target := Vector3(look_xz.x, ecology.sample_floor_height(look_xz.x, look_xz.y) + 0.9, look_xz.y)
		camera.position = at
		camera.look_at(target)
		lamp.visible = bool(shot["lamp"])
		ocean.set_depth(maxf(0.0, -at.y))
		for frame in range(32):
			ecology.update_observer(at, 0.1)
			await process_frame
		assert(ecology.get_ecology_snapshot()["pending_chunks"] == 0)
		# Allow asynchronous noise generation and shader compilation to settle.
		for frame in range(4):
			await process_frame
			await RenderingServer.frame_post_draw
		var rendered := root.get_texture().get_image()
		assert(not rendered.is_empty())
		assert(rendered.save_png(output.path_join(str(shot["name"]) + ".png")) == OK)
		if str(shot["name"]) == "07-hadal-ambient":
			abyss_ambient = rendered
		if str(shot["name"]) == "08-hadal-lamp":
			assert(-at.y >= 460.0, "The hadal visual review must reach the expanded 500m depth range")
			assert(_mean_luminance(rendered) > _mean_luminance(abyss_ambient) + 0.003, "A white lamp must reveal the otherwise dark abyssal seabed")
		print("RENDER: " + str(shot["name"]) + " depth=" + str(snappedf(-at.y, 0.1)) + " luminance=" + str(snappedf(_mean_luminance(rendered), 0.0001)))
	finished[0] = true
	print("PASS: natural depth/frontier visual review; screenshots: " + output)
	ocean.queue_free()
	camera.queue_free()
	await process_frame
	quit()

func _mean_luminance(rendered: Image) -> float:
	var total := 0.0
	var samples := 0
	for y in range(rendered.get_height() / 3, rendered.get_height() - 20, 24):
		for x in range(40, rendered.get_width() - 40, 24):
			var color := rendered.get_pixel(x, y)
			total += color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
			samples += 1
	return total / float(maxi(samples, 1))
