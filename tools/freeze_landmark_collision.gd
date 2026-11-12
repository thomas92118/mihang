extends SceneTree
## Run once against the original kit, before promoting replacement visual GLBs.
## The resulting local-space shapes preserve every original mesh transform.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/collision")
	for asset: String in ["ruins", "shipwreck"]:
		var target := "res://assets/collision/" + asset + ".tscn"
		assert(not FileAccess.file_exists(target), "Frozen collisions already exist; never regenerate from new visuals")
		var scene: Node3D = load("res://assets/models/" + asset + ".glb").instantiate()
		root.add_child(scene)
		var collision_root := Node3D.new()
		collision_root.name = "CollisionRoot"
		var count := 0
		for mesh: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
			var body := StaticBody3D.new()
			body.name = "OriginalSurface%d" % count
			collision_root.add_child(body)
			body.owner = collision_root
			body.transform = scene.global_transform.affine_inverse() * mesh.global_transform
			var shape := CollisionShape3D.new()
			shape.shape = mesh.mesh.create_trimesh_shape()
			body.add_child(shape)
			shape.owner = collision_root
			count += 1
		var packed := PackedScene.new()
		assert(packed.pack(collision_root) == OK)
		assert(ResourceSaver.save(packed, target) == OK)
		print("FROZEN ", asset, ": ", count, " original collision surfaces")
		collision_root.free()
		scene.free()
	quit()
