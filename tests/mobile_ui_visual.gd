extends SceneTree
## Renders mobile portrait (390x844) and landscape (844x390) gameplay UI screenshots
## with the circular GPT-generated touch icon buttons for visual QA.

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func() -> void:
		printerr("MOBILE_UI_VISUAL_TIMEOUT")
		quit(1)
	)
	_run.call_deferred()

func _run() -> void:
	assert(DisplayServer.get_name() != "headless", "mobile_ui_visual requires a real renderer")
	var out_dir := ProjectSettings.globalize_path("res://.tools/mobile-ui-review")
	if not OS.get_cmdline_user_args().is_empty():
		out_dir = ProjectSettings.globalize_path(OS.get_cmdline_user_args()[0])
	DirAccess.make_dir_recursive_absolute(out_dir)

	var vp := SubViewport.new()
	vp.size = Vector2i(844, 390)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.gui_embed_subwindows = true
	root.add_child(vp)

	var packed := load("res://scenes/main.tscn") as PackedScene
	var game := packed.instantiate()
	game.voyage_save_path = "user://temp_mobile_ui_visual.json"
	game.gameplay_guide.persist_enabled = false
	vp.add_child(game)
	await process_frame
	await process_frame

	game.input_controller.apply_settings({"touch_mode": "on", "touch_scale": 1.0, "touch_opacity": 0.88}, false)
	game.input_controller.notify_device("touch")
	game._start("survival")
	game.diver.global_position = Vector3(13.5, game.ocean.floor_height(13.5, 21.0) + 2.6, 21.0)
	if not game.state.weapons.has("sonic"):
		game.state.weapons.append("sonic")
	await create_timer(0.45).timeout

	# 1. Landscape gameplay (844x390, onboarding dismissed)
	game.gameplay_guide.skip_onboarding()
	game.hud.toast_time = 0.0
	game.hud.toast_label.hide()
	await _capture_view(vp, game, Vector2i(844, 390), out_dir.path_join("landscape_844x390.png"))

	# 2. Portrait gameplay (390x844, onboarding dismissed)
	game.hud.toast_time = 0.0
	game.hud.toast_label.hide()
	await _capture_view(vp, game, Vector2i(390, 844), out_dir.path_join("portrait_390x844.png"))

	# 3. Portrait gameplay with compact onboarding card & icon skip button (390x844)
	game.gameplay_guide.restart_onboarding("survival")
	game.hud.toast("【发现新海域地标】逃生舱浅礁 · 浅海珊瑚林 (+35G)")
	await _capture_view(vp, game, Vector2i(390, 844), out_dir.path_join("portrait_onboarding_390x844.png"))

	# 4. Landscape scoped 8x mode showing circular scope_exit image button (844x390)
	game.gameplay_guide.skip_onboarding()
	game._switch_weapon("sonic")
	game.hud._weapon_flash_time = 0.0
	game.hud.toast_time = 0.0
	game.hud.toast_label.hide()
	game.diver.scoped = true
	await _capture_view(vp, game, Vector2i(844, 390), out_dir.path_join("landscape_scoped_844x390.png"))

	var save_abs := ProjectSettings.globalize_path("user://temp_mobile_ui_visual.json")
	if FileAccess.file_exists(save_abs):
		DirAccess.remove_absolute(save_abs)
	print("MOBILE_UI_VISUAL_OK: ", out_dir)
	quit(0)

func _capture_view(vp: SubViewport, game: Node, target_size: Vector2i, file_path: String) -> void:
	vp.size = target_size
	game.hud.root.size = Vector2(target_size)
	game.touch_controls.size = Vector2(target_size)
	game.touch_controls._rebuild_layout()
	game._sync_touch_context_and_margins(true)
	for _i in range(5):
		await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	assert(not img.is_empty(), "Rendered mobile viewport image must not be empty")
	assert(img.save_png(file_path) == OK, "Failed saving screenshot: " + file_path)
