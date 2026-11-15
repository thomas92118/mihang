extends SceneTree

const SafeArea = preload("res://scripts/presentation/safe_area.gd")
const TouchControls = preload("res://scripts/touch_controls.gd")
const InputController = preload("res://scripts/input_controller.gd")
const GameplayGuide = preload("res://scripts/gameplay_guide.gd")
const HUD = preload("res://scripts/hud.gd")
const Survival = preload("res://scripts/survival.gd")
const Ocean = preload("res://scripts/ocean.gd")

const PORTRAIT_VIEWS := [
	Vector2i(360, 740),
	Vector2i(375, 667),
	Vector2i(390, 844),
	Vector2i(430, 932),
]

const LANDSCAPE_VIEWS := [
	Vector2i(640, 360),
	Vector2i(667, 375),
	Vector2i(844, 390),
	Vector2i(932, 430),
]

const ALL_SCREENS := [
	"main", "pause", "craft", "sushi", "mount_board",
	"map", "win", "quick", "controls", "guide",
]

func _initialize() -> void:
	create_timer(45.0).timeout.connect(func() -> void:
		SafeArea.clear_mock_insets()
		printerr("FAIL: mobile_adaptation test timed out")
		quit(1)
	)
	_run.call_deferred()

func _control_rect_in_viewport(ctrl: Control) -> Rect2:
	return ctrl.get_global_rect()

func _check(cond: bool, msg: String) -> void:
	if not cond:
		SafeArea.clear_mock_insets()
		printerr("MOBILE_ADAPTATION_FAIL: " + msg)
		quit(1)

func _run() -> void:
	await _verify_touch_and_hud_matrix()
	await _verify_menus_responsive_matrix()
	await _verify_voyage_autosave_and_continue()
	SafeArea.clear_mock_insets()
	print("MOBILE_ADAPTATION_OK: portrait/landscape safe areas, >=44px touch targets, HUD anti-overlap, 10 responsive menus, and voyage save/resume")
	quit(0)

func _verify_touch_and_hud_matrix() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(844, 390)
	root.add_child(viewport)

	var inputs := InputController.new()
	viewport.add_child(inputs)
	var hud := HUD.new()
	viewport.add_child(hud)
	var layer := CanvasLayer.new()
	viewport.add_child(layer)
	var touch := TouchControls.new()
	layer.add_child(touch)

	await process_frame
	inputs.apply_settings({"touch_mode": "on", "graphics_quality": "performance"}, false)
	inputs.notify_device("touch")
	hud.configure_input(inputs)
	hud.set_screen("play")
	touch.set_gameplay_enabled(true)
	await process_frame

	# Verify touch onboarding payload never prompts pointer lock.
	var guide := GameplayGuide.new()
	var payload: Dictionary = guide.get_hud_payload(false, true, true)
	for v in payload.values():
		_check(not str(v).contains("点击锁定视角"), "Touch HUD payload must never ask to click for pointer lock: %s" % str(v))

	# Verify direct combat/exploration quick-slots exist.
	for qs: String in ["weapon_cycle", "toggle_shield", "sonar_ping", "lamp"]:
		_check(TouchControls.LABELS.has(qs), "Missing direct touch quick-slot: %s" % qs)

	var cases: Array[Dictionary] = []
	for res: Vector2i in PORTRAIT_VIEWS:
		cases.append({"res": res, "insets": [0.0, 0.0, 0.0, 0.0]})
		cases.append({"res": res, "insets": [59.0, 0.0, 34.0, 0.0]})
	for res: Vector2i in LANDSCAPE_VIEWS:
		cases.append({"res": res, "insets": [0.0, 0.0, 0.0, 0.0]})
		cases.append({"res": res, "insets": [0.0, 59.0, 21.0, 59.0]})

	for case_info: Dictionary in cases:
		var res: Vector2i = case_info["res"]
		var ins: Array = case_info["insets"]
		if ins[0] == 0.0 and ins[1] == 0.0 and ins[2] == 0.0 and ins[3] == 0.0:
			SafeArea.clear_mock_insets()
		else:
			SafeArea.set_mock_insets(ins[0], ins[1], ins[2], ins[3])

		viewport.size = res
		hud.root.size = Vector2(res)
		touch.size = Vector2(res)
		hud._apply_layout()
		touch._rebuild_layout()
		await process_frame

		var hud_safe: Rect2 = hud.get_layout_safe_rect()
		var life: Control = hud.instruments.get_node("LifeSupportInstrument")
		var life_rect := _control_rect_in_viewport(life)
		_check(hud_safe.grow(2.0).encloses(life_rect), "LifeSupportInstrument outside safe rect at %s insets=%s: %s vs %s" % [res, ins, life_rect, hud_safe])

		for scale: float in [0.75, 1.0, 1.5]:
			touch.configure({"touch_scale": scale, "touch_opacity": 0.78})
			var t_safe: Rect2 = touch.get_safe_rect()
			var joy_rect: Rect2 = touch.get_joystick_rect()
			_check(t_safe.grow(1.0).encloses(joy_rect), "Joystick outside safe rect at %s scale %.2f" % [res, scale])

			var actions: Array = TouchControls.LABELS.keys()
			for i in range(actions.size()):
				var act_a := str(actions[i])
				var rect_a: Rect2 = touch.get_control_rect(act_a)
				_check(t_safe.grow(1.0).encloses(rect_a), "%s outside safe rect at %s scale %.2f: %s vs %s" % [act_a, res, scale, rect_a, t_safe])
				if scale >= 1.0:
					_check(rect_a.size.x >= 43.5 and rect_a.size.y >= 43.5, "%s hitbox < 44px at %s scale %.2f: %s" % [act_a, res, scale, rect_a.size])
				_check(not rect_a.intersects(joy_rect), "%s overlaps joystick at %s scale %.2f" % [act_a, res, scale])
				for j in range(i + 1, actions.size()):
					var act_b := str(actions[j])
					var rect_b: Rect2 = touch.get_control_rect(act_b)
					_check(not rect_a.intersects(rect_b), "%s overlaps %s at %s scale %.2f" % [act_a, act_b, res, scale])

			# Check HUD LifeSupportInstrument does not collide with joystick, sprint, or quick slots at default scale 1.0.
			if is_equal_approx(scale, 1.0):
				_check(not life_rect.intersects(joy_rect), "LifeSupport overlaps joystick at %s insets=%s: %s vs %s" % [res, ins, life_rect, joy_rect])
				for check_act: String in ["sprint", "weapon_cycle", "toggle_shield", "sonar_ping", "lamp", "attack", "interact"]:
					var b_rect: Rect2 = touch.get_control_rect(check_act)
					_check(not life_rect.intersects(b_rect), "LifeSupport overlaps %s at %s insets=%s: %s vs %s" % [check_act, res, ins, life_rect, b_rect])
				var radar_rect := _control_rect_in_viewport(hud.minimap_radar)
				_check(not radar_rect.intersects(touch.get_control_rect("pause_game")), "Radar overlaps pause_game at %s" % [res])

	# Check scope exit button behavior.
	SafeArea.clear_mock_insets()
	viewport.size = Vector2i(844, 390)
	hud.root.size = Vector2(844, 390)
	hud._apply_layout()
	var emitted_actions: Array[String] = []
	hud.action_requested.connect(func(a: String) -> void: emitted_actions.append(a))
	hud.scope_exit_btn.show()
	_check(hud.scope_exit_btn.size.y >= 44.0, "Scope exit button height must be >= 44px")
	hud.scope_exit_btn.pressed.emit()
	_check(emitted_actions.has("scope"), "Scope exit button must emit scope toggle action")

	viewport.queue_free()
	await process_frame

func _verify_menus_responsive_matrix() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(390, 844)
	root.add_child(viewport)
	var inputs := InputController.new()
	viewport.add_child(inputs)
	inputs.apply_settings({"touch_mode": "on"}, false)
	inputs.notify_device("touch")
	var hud := HUD.new()
	viewport.add_child(hud)
	await process_frame
	hud.configure_input(inputs)
	hud.set_can_continue_voyage(true, "深度 128m · 金币 360")
	await process_frame

	var menu_views := [
		{"res": Vector2i(360, 740), "insets": [59.0, 0.0, 34.0, 0.0]},
		{"res": Vector2i(390, 844), "insets": [59.0, 0.0, 34.0, 0.0]},
		{"res": Vector2i(640, 360), "insets": [0.0, 44.0, 21.0, 44.0]},
		{"res": Vector2i(844, 390), "insets": [0.0, 59.0, 21.0, 59.0]},
	]

	for mv: Dictionary in menu_views:
		var res: Vector2i = mv["res"]
		var ins: Array = mv["insets"]
		SafeArea.set_mock_insets(ins[0], ins[1], ins[2], ins[3])
		viewport.size = res
		hud.root.size = Vector2(res)
		hud._apply_layout()
		await process_frame

		for screen: String in ALL_SCREENS:
			hud.set_screen(screen)
			hud._apply_layout()
			await process_frame
			var scroll: ScrollContainer = hud.menu_scrolls[screen]
			var content: Control = hud.menu_contents[screen]
			_check(scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "%s must disable horizontal scrolling" % screen)
			_check(content.size.x <= scroll.size.x + 1.5, "%s content width %.1f overflows scroll width %.1f at %s" % [screen, content.size.x, scroll.size.x, res])
			if screen in ["main", "map", "guide"]:
				_check(scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "%s should use single-screen responsive layout without outer vertical scroll" % screen)

	# Verify graphics_quality control and continue_voyage_btn signal.
	_check(hud.settings_controls.has("graphics_quality"), "Controls menu must expose graphics_quality selector")
	var gfx_changes: Array[Dictionary] = []
	hud.input_settings_requested.connect(func(v: Dictionary) -> void: gfx_changes.append(v))
	(hud.settings_controls["graphics_quality"] as OptionButton).item_selected.emit(1)
	_check(not gfx_changes.is_empty() and str(gfx_changes.back().get("graphics_quality", "")) == "performance", "graphics_quality selector must emit performance")

	var cont_box := {"count": 0}
	hud.continue_requested.connect(func() -> void: cont_box["count"] = int(cont_box["count"]) + 1)
	hud.set_screen("main")
	await process_frame
	_check(hud.continue_voyage_btn.visible, "Continue voyage button must be visible when save is available")
	_check(hud.continue_voyage_btn.size.y >= 44.0, "Continue voyage button must be >= 44px tall")
	hud.continue_voyage_btn.pressed.emit()
	_check(int(cont_box["count"]) == 1, "Continue voyage button must emit continue_requested")

	SafeArea.clear_mock_insets()
	viewport.queue_free()
	await process_frame

func _verify_voyage_autosave_and_continue() -> void:
	# Unit check Survival round-trip first.
	var s1 := Survival.new()
	s1.gold = 777
	s1.reinforced_suit = true
	s1.discover_landmark("sunken_observatory")
	s1.unlock_outpost("reef_outpost", "浅礁前哨")
	s1.set_custom_waypoint(Vector3(42.0, -35.0, -88.0))
	s1.reveal_world_area(Vector3(10.0, -12.0, 20.0), 40.0)
	var dumped: Dictionary = s1.to_save_dict()
	var s2 := Survival.new()
	s2.load_save_dict(dumped)
	_check(s2.gold == s1.gold and s2.gold >= 777 and s2.reinforced_suit == true, "Survival gold & reinforced_suit round-trip failed")
	_check(s2.landmarks_discovered.has("sunken_observatory"), "Survival landmarks_discovered round-trip failed")
	_check(s2.unlocked_outposts.has("reef_outpost"), "Survival unlocked_outposts round-trip failed")
	_check(s2.has_custom_waypoint and s2.custom_waypoint.distance_to(Vector3(42.0, -35.0, -88.0)) < 0.05, "Survival custom_waypoint round-trip failed")
	_check(s2.get_survey_ratio() > 0.0, "Survival surveyed_cells round-trip failed")

	# Integration check on scenes/main.tscn with isolated save path.
	var temp_save := "user://test_mobile_adaptation_voyage.json"
	if FileAccess.file_exists(temp_save):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_save))

	var packed := load("res://scenes/main.tscn") as PackedScene
	var game := packed.instantiate()
	game.voyage_save_path = temp_save
	root.add_child(game)
	await process_frame
	await process_frame

	_check(not game.has_voyage_save(), "Clean temp save path should start empty")
	game._start("survival")
	await process_frame
	var target_y := maxf(-12.0, Ocean.terrain_height(18.0, -32.0) + 3.0)
	var target_pos := Vector3(18.0, target_y, -32.0)
	game.diver.global_position = target_pos
	await process_frame
	game.state.gold = 520
	game.state.inventory["copper"] = 6
	game.state.discover_landmark("kelp_arch")
	if not game.state.weapons.has("sonic"):
		game.state.weapons.append("sonic")
	game._switch_weapon("sonic")
	_check(game.save_voyage(), "save_voyage() must succeed during active voyage")
	_check(game.has_voyage_save(), "has_voyage_save() must detect saved file")

	# Simulate mobile browser reload with a fresh Game instance reading persisted voyage save.
	game.queue_free()
	await process_frame
	await process_frame

	var game2 := packed.instantiate()
	game2.voyage_save_path = temp_save
	root.add_child(game2)
	await process_frame
	await process_frame
	_check(game2.hud.continue_voyage_btn.visible, "Fresh boot main menu must show Continue Voyage button when save exists")

	game2.hud.continue_requested.emit()
	await process_frame
	_check(game2.screen == "play", "Continue Voyage must enter play screen")
	_check(game2.state.gold == 520 and int(game2.state.inventory.get("copper", 0)) == 6, "Saved gold & inventory must restore")
	_check(game2.state.landmarks_discovered.has("kelp_arch"), "Saved landmarks must restore")
	_check(game2.diver.global_position.distance_to(target_pos) < 0.5, "Saved diver position must restore")
	_check(game2.diver.current_weapon == "sonic", "Saved weapon must restore")

	if FileAccess.file_exists(temp_save):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_save))
	game2.queue_free()
	await process_frame
