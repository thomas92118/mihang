extends SceneTree

# Run with a real renderer: Godot --path . -s tests/water_visual.gd
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	assert(DisplayServer.get_name() != "headless", "Water checks require a real rendering window")
	var ocean = load("res://scripts/ocean.gd").new()
	root.add_child(ocean)
	ocean.set_process(false)
	var material: ShaderMaterial = ocean.get_node("WaterSurface").material_override
	var normals: NoiseTexture2D = material.get_shader_parameter("ripple_normal")
	if normals.get_image() == null:
		await normals.changed
	assert(not normals.get_image().is_empty(), "Water normal texture must finish generating")
	var seabed: MeshInstance3D = ocean.get_node("Seabed")
	var sediment: NoiseTexture2D = seabed.material_override.get_shader_parameter("sediment_noise")
	if sediment.get_image() == null:
		await sediment.changed
	assert(not sediment.get_image().is_empty(), "Seabed texture must finish generating")
	var camera := Camera3D.new()
	camera.fov = 78.0
	camera.far = 240.0
	root.add_child(camera)
	var lamp := SpotLight3D.new()
	lamp.light_color = Color(0.78, 0.96, 1.0)
	lamp.light_energy = 9.0
	lamp.spot_range = 85.0
	lamp.spot_angle = 55.0
	camera.add_child(lamp)
	var output := "res://.tools/water-review"
	if not OS.get_cmdline_user_args().is_empty():
		output = OS.get_cmdline_user_args()[0]
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	await process_frame
	for shot in [
		["underwater", Vector3(0, -9, 17), Vector3(0, -5, -18)],
		["surface", Vector3(12, 1.2, 18), Vector3(0, -1, -15)],
		["snell-window", Vector3(20, -5, 8), Vector3(18, 6, -2)],
		["deep", Vector3(15, -65, -130), Vector3(15, -48, -170)],
		["sand-close", Vector3(-13, ocean.floor_height(-13, 12) + 1.4, 12), Vector3(-11, ocean.floor_height(-11, 8), 8)],
		["reef-floor", Vector3(-10, ocean.floor_height(-10, 20) + 4.0, 20), Vector3(0, ocean.floor_height(0, 0), 0)],
		["slope-floor", Vector3(26, ocean.floor_height(26, -45) + 2.4, -45), Vector3(30, ocean.floor_height(30, -55), -55)],
		["abyss-floor", Vector3(-30, ocean.floor_height(-30, -140) + 2.0, -140), Vector3(-28, ocean.floor_height(-28, -146), -146)],
	]:
		camera.position = shot[1]
		camera.look_at(shot[2])
		lamp.visible = shot[0] in ["slope-floor", "abyss-floor"]
		ocean.set_depth(maxf(0.0, -camera.position.y))
		await process_frame
		await RenderingServer.frame_post_draw
		var first := root.get_texture().get_image()
		assert(not first.is_empty())
		assert(first.save_png(output.path_join(shot[0] + ".png")) == OK)
		if shot[0] == "underwater":
			await create_timer(0.8).timeout
			await RenderingServer.frame_post_draw
			var second := root.get_texture().get_image()
			# Sample the upper water surface, away from fish and terrain.
			var difference := _difference(first, second, Rect2i(40, 20, first.get_width() - 80, 180))
			assert(difference > 0.5, "Water must animate instead of rendering as a flat or broken material")
			assert(second.save_png(output.path_join("underwater-motion.png")) == OK)
		if shot[0] == "abyss-floor":
			# In the abyss there are no moving caustics: isolate the sediment texture's effect.
			var plain := Image.create(4, 4, false, Image.FORMAT_RGB8)
			plain.fill(Color(0.5, 0.5, 0.5))
			plain.generate_mipmaps()
			seabed.material_override.set_shader_parameter("sediment_noise", ImageTexture.create_from_image(plain))
			await process_frame
			await RenderingServer.frame_post_draw
			var flat := root.get_texture().get_image()
			var floor_area := Rect2i(40, first.get_height() * 2 / 3, first.get_width() - 80, first.get_height() / 3 - 20)
			assert(_difference(first, flat, floor_area) > 0.5, "Sediment detail must affect the rendered seabed")
			seabed.material_override.set_shader_parameter("sediment_noise", sediment)
	print("PASS: animated water and seabed rendered in shallow water, on the slope and in the abyss; screenshots: " + output)
	quit()

func _difference(first: Image, second: Image, area: Rect2i) -> float:
	var difference := 0.0
	for x in range(area.position.x, area.end.x, 20):
		for y in range(area.position.y, area.end.y, 20):
			var a := first.get_pixel(x, y)
			var b := second.get_pixel(x, y)
			difference += absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
	return difference
