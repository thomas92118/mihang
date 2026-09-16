extends SceneTree

# Run headless for contracts, or with --visual for rendered material/animation proof.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var staging := "--staging" in args
	var visual := "--visual" in args
	var manifest_path := "res://.tools/alien-staging/asset-manifest.json" if staging else "res://assets/source/asset-manifest.json"
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(manifest_path))
	assert(not manifest.is_empty())
	if not staging:
		assert(manifest.size() == 28)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 0.001
	root.add_child(camera)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -30, 0)
	sun.light_energy = 1.6
	root.add_child(sun)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.07, 0.10, 0.12)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(0.6, 0.7, 0.8)
	world.environment.ambient_light_energy = 0.5
	root.add_child(world)
	if visual:
		assert(DisplayServer.get_name() != "headless")
		DirAccess.make_dir_recursive_absolute("res://assets/source/alien-ocean-v2/godot-previews")
	for id: String in manifest:
		var entry: Dictionary = manifest[id]
		var scene: Node3D
		if staging:
			var document := GLTFDocument.new()
			var state := GLTFState.new()
			assert(document.append_from_file("res://.tools/alien-staging/models/" + id + ".glb", state) == OK)
			scene = document.generate_scene(state)
		else:
			scene = load("res://" + entry.file).instantiate()
		root.add_child(scene)
		assert(scene.find_child("Cube", true, false) == null)
		var meshes := scene.find_children("*", "MeshInstance3D", true, false)
		assert(not meshes.is_empty(), id + ": missing mesh")
		var bounds := AABB()
		var first := true
		for child: MeshInstance3D in meshes:
			var box: AABB = child.global_transform * child.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
			for surface in child.mesh.get_surface_count():
				var mat: BaseMaterial3D = child.mesh.surface_get_material(surface)
				assert(mat != null and mat.albedo_texture != null, id + ": albedo missing")
				assert(mat.normal_enabled and mat.normal_texture != null, id + ": normal missing")
				assert(mat.roughness_texture != null and mat.metallic_texture != null, id + ": ORM missing")
				assert(mat.emission_enabled and mat.emission_texture != null, id + ": emission missing")
		var dimensions: Array = entry.dimensions_godot_xyz
		for axis in 3:
			assert(absf(bounds.size[axis] - dimensions[axis]) < maxf(0.005, dimensions[axis] * 0.1), id + ": size contract changed")
		var players := scene.find_children("*", "AnimationPlayer", true, false)
		if int(entry.bones) > 0:
			var skeletons := scene.find_children("*", "Skeleton3D", true, false)
			assert(skeletons.size() == 1 and skeletons[0].get_bone_count() <= 64)
			assert(players.size() == 1, id + ": animation player missing")
			var player: AnimationPlayer = players[0]
			var skeleton: Skeleton3D = skeletons[0]
			for clip: String in entry.animations:
				assert(player.has_animation(clip), id + ": missing clip " + clip)
				player.play(clip)
				player.advance(0.0)
				var initial: Array[Transform3D] = []
				for index in skeleton.get_bone_count():
					initial.append(skeleton.get_bone_pose(index))
				player.advance(player.get_animation(clip).length * 0.25)
				var moved := false
				for index in skeleton.get_bone_count():
					moved = moved or not initial[index].is_equal_approx(skeleton.get_bone_pose(index))
				assert(moved, id + ": animation does not deform joints: " + clip)
			player.stop()
		if visual:
			var center := bounds.get_center()
			var span: float = maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
			camera.size = span * 1.25
			camera.position = center + Vector3(1.2, 0.7, 1.8) * span
			camera.look_at(center)
			await process_frame
			await RenderingServer.frame_post_draw
			var picture := root.get_texture().get_image()
			assert(not picture.is_empty())
			assert(picture.save_png("res://assets/source/alien-ocean-v2/godot-previews/" + id + ".png") == OK)
		print("PASS asset ", id, ": PBR, scale, ", entry.animations)
		scene.free()
	world.free()
	camera.free()
	sun.free()
	await process_frame
	print("PASS: ", manifest.size(), " asset contracts")
	quit()
