extends SceneTree
## Same harness works with the frozen original and the refined protagonist.
const Game = preload("res://scripts/game.gd")
const Capture = preload("res://tests/art_capture_support.gd")
const POSES := [
	["idle-back", Vector3.ZERO, 0.0, 0.0, "game"],
	["cruise-back", Vector3(0, 0, -5.2), 0.0, 0.0, "game"],
	["ascent", Vector3(0, 2.2, -3.8), 0.0, 0.18, "game"],
	["descent", Vector3(0, -2.2, -3.8), 0.0, -0.20, "game"],
	["bank-turn", Vector3(2.0, 0, -4.5), 0.22, 0.0, "game"],
	["dash", Vector3(0, 0, -9.0), 0.0, 0.0, "game"],
	["cruise-side", Vector3(0, 0, -5.2), 0.0, 0.0, "side"],
	["idle-front", Vector3.ZERO, 0.0, 0.0, "front"],
	["aim-sonic", Vector3.ZERO, 0.0, 0.0, "game"],
	["shield", Vector3.ZERO, 0.0, 0.0, "game"],
	["booster", Vector3(0, 0, -6.0), 0.0, 0.0, "side"],
	["riding-posture", Vector3.ZERO, 0.0, 0.0, "side"],
]

func _initialize() -> void:
	_run.call_deferred()

func _has_property(object: Object, property: String) -> bool:
	for entry: Dictionary in object.get_property_list():
		if str(entry.name) == property:
			return true
	return false

func _run() -> void:
	assert(DisplayServer.get_name() != "headless", "Character evidence requires a real renderer")
	root.size = Vector2i(1280, 800)
	var args := OS.get_cmdline_user_args()
	var output := args[0] if not args.is_empty() else "res://.tools/abzu-refinement/character"
	var phase := 12.0
	for index in range(args.size()):
		if args[index] == "--phase" and index + 1 < args.size():
			phase = maxf(0.0, float(args[index + 1]))
	DirAccess.make_dir_recursive_absolute(output)
	var game = Game.new()
	root.add_child(game)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.ocean.process_mode = Node.PROCESS_MODE_DISABLED
	game.diver.process_mode = Node.PROCESS_MODE_DISABLED
	game.hud.process_mode = Node.PROCESS_MODE_DISABLED
	game._set_screen("play")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var diver = game.diver
	diver.active = false
	diver.position = Vector3(0, -9.0, 17.0)
	game.ocean.set_depth(9.0)
	if game.ocean.has_method("set_art_observer"):
		game.ocean.set_art_observer(diver.position)
	for frame in range(90):
		game.ocean.seabed_ecology.update_observer(diver.position, 0.016)
		await process_frame
	Capture.apply_review_phase(game.ocean, phase)
	var external := Camera3D.new()
	external.fov = 42.0
	external.far = 280.0
	root.add_child(external)
	for pose: Array in POSES:
		if diver.booster_active:
			diver.toggle_booster()
		if diver.shield_active:
			diver.toggle_shield()
		if diver.in_mount_mode:
			diver.set_mount_mode(false)
		diver.rotation = Vector3.ZERO
		diver.velocity = pose[1]
		diver.swim_clock = phase
		diver.turn_bank = float(pose[2])
		diver.camera.rotation = Vector3(float(pose[3]), 0, 0)
		diver.sprinting = pose[0] == "dash"
		if _has_property(diver, "swim_motion_blend"):
			diver.set("swim_motion_blend", 0.0)
			diver.set("swim_kick_rate", 2.2)
		diver.set_weapon("sonic" if pose[0] == "aim-sonic" else "knife")
		diver.aiming = pose[0] == "aim-sonic"
		diver.scoped = false
		diver.aim_blend = 1.0 if diver.aiming else 0.0
		diver.equip_anim_time = 0.0
		diver.camera.fov = 48.0 if diver.aiming else (84.0 if diver.sprinting else 78.0)
		if pose[0] == "shield":
			diver.toggle_shield()
		elif pose[0] == "booster":
			diver.toggle_booster()
		elif pose[0] == "riding-posture":
			diver.set_mount_mode(true)
		for step in range(120):
			diver._animate_diver_model(1.0 / 60.0)
		diver._update_third_person_camera(1.0)
		game.hud.update_hud({"mode": "explore", "current_weapon": diver.current_weapon,
			"aiming": diver.aiming, "depth": 9.0, "player_pos": diver.position,
			"biome": "阳光浅礁带", "health": 100.0})
		game.hud._detail_time = 0.0
		game.hud.toast_time = 0.0
		game.hud.toast_label.hide()
		game.hud.update_hud({"mode": "explore", "current_weapon": diver.current_weapon,
			"aiming": diver.aiming, "depth": 9.0, "player_pos": diver.position,
			"biome": "阳光浅礁带", "health": 100.0})
		if pose[4] == "game":
			diver.camera.make_current()
			game.hud.root.show()
		else:
			external.position = diver.position + (Vector3(3.2, -0.05, 0) if pose[4] == "side" else Vector3(0, -0.05, -3.2))
			external.look_at(diver.position + Vector3(0, -0.12, 0))
			external.make_current()
			game.hud.root.hide()
		await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png(output.path_join(str(pose[0]) + ".png")) == OK)
		print("CHARACTER REVIEW ", pose[0])
	var metadata := Capture.environment(root.size, phase, "static_protagonist_pose")
	metadata["pose_steps"] = 120
	metadata["pose_delta"] = 1.0 / 60.0
	metadata["views_captured"] = POSES.size()
	metadata["scope_note"] = "Poses are sampled with the production animator; riding is a posture-only view. Movement/control correctness and actual mounts are verified separately."
	Capture.write_json(output.path_join("environment.json"), metadata)
	game.free()
	external.free()
	print("PASS: ", POSES.size(), " protagonist views at ", output)
	quit()
