extends SceneTree
## Real rendered UI states, with actual game controls and a stable 3D background.
const Game = preload("res://scripts/game.gd")
const Capture = preload("res://tests/art_capture_support.gd")
const STATES := ["main", "play", "quiet", "discovery", "low-oxygen", "boss", "alert-stack", "timeout",
	"submarine", "mount", "craft", "map", "sushi", "mount_board", "pause", "win", "quick", "controls"]

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	assert(DisplayServer.get_name() != "headless")
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	game.ocean.process_mode = Node.PROCESS_MODE_DISABLED
	game.diver.set_physics_process(false)
	game.diver.set_process(false)
	var hud = game.hud
	hud.set_process(false)
	var args := OS.get_cmdline_user_args()
	var output := args[0] if not args.is_empty() else "res://.tools/ui-review"
	var phase := 12.0
	for index in range(args.size()):
		if args[index] == "--phase" and index + 1 < args.size():
			phase = maxf(0.0, float(args[index + 1]))
	DirAccess.make_dir_recursive_absolute(output)
	var base := {
		"mode": "survival", "oxygen": 80.0, "max_oxygen": 90.0, "health": 100.0, "depth": 9.0,
		"biome": "阳光浅礁带", "player_pos": Vector3(0, -9, 17), "player_forward": Vector3.FORWARD,
		"exploration_progress": 0.24, "current_weapon": "knife", "inventory": {"titanium": 4, "copper": 2, "quartz": 3, "kelp": 5},
		"landmarks_dict": game.LANDMARKS, "map_outposts": game.ocean.get_map_outpost_snapshots(),
		"marinca_species": game.state.MARINCA_SPECIES if "MARINCA_SPECIES" in game.state else {},
		"tamed_beasts": [{"name": "斑纹礁海豹", "health": 420.0, "deployed": true}], "deployed_beast_count": 1,
	}
	for resolution: Vector2i in [Vector2i(1280, 800), Vector2i(1920, 1080)]:
		root.size = resolution
		var directory := output.path_join("%dx%d" % [resolution.x, resolution.y])
		DirAccess.make_dir_recursive_absolute(directory)
		for state: String in STATES:
			var data := base.duplicate(true)
			var screen := "play" if state in ["quiet", "discovery", "low-oxygen", "boss", "alert-stack", "timeout", "submarine", "mount"] else state
			if state in ["low-oxygen", "alert-stack"]:
				data["oxygen"] = 8.0
				data["health"] = 15.0
			if state in ["boss", "alert-stack"]:
				data["boss"] = {"active": true, "name": "深渊水龙", "health": 650.0, "max_health": 1800.0, "warning": "蓄力静滞，靠近可缔结契约"}
			if state == "submarine":
				data["in_submarine"] = true
				data["sub_name"] = "泰坦远征号"
			if state == "mount":
				data["active_mount_idx"] = 0
			game._set_screen(screen)
			game.diver.active = false
			hud.toast_time = 0.0
			hud.toast_label.hide()
			hud.update_hud(data)
			if state in ["quiet", "discovery", "timeout"]:
				hud._detail_time = 0.0
				hud.update_hud(data)
			else:
				hud._detail_time = 4.0
			if state in ["discovery", "alert-stack", "timeout"]:
				hud.toast("发现新的科考地标 · 已记录海图与航向")
				hud._process(4.0 if state == "timeout" else 0.2)
				hud.update_hud(data)
				if state == "timeout":
					assert(not hud.toast_label.visible, "Timed feedback must expire")
				elif state == "alert-stack":
					assert(not hud.toast_label.get_global_rect().intersects(hud.boss_panel.get_global_rect()))
			for frame in range(12):
				game.ocean.seabed_ecology.update_observer(game.diver.position, 0.016)
				await process_frame
			Capture.apply_review_phase(game.ocean, phase)
			await process_frame
			await RenderingServer.frame_post_draw
			var picture := root.get_texture().get_image()
			assert(picture.save_png(directory.path_join(state + ".png")) == OK)
		print("UI REVIEW ", resolution)
	var metadata := Capture.environment(root.size, phase, "static_ui_states")
	metadata["resolutions"] = [[1280, 800], [1920, 1080]]
	metadata["states"] = STATES
	metadata["views_captured"] = STATES.size() * 2
	Capture.write_json(output.path_join("environment.json"), metadata)
	print("PASS: ", STATES.size() * 2, " rendered UI states at two resolutions")
	paused = false
	game.free()
	quit()
