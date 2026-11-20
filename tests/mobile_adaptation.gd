extends SceneTree

const SafeArea = preload("res://scripts/presentation/safe_area.gd")
const CharacterRoster = preload("res://scripts/presentation/character_roster.gd")
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

const TABLET_FOLD_VIEWS := [
	Vector2i(900, 800),
	Vector2i(1024, 768),
	Vector2i(900, 600),
]

const ALL_SCREENS := [
	"main", "pause", "craft", "sushi", "mount_board",
	"map", "win", "quick", "controls", "guide",
]

var _saved_character_before_test := ""

func _cleanup_global_test_state() -> void:
	SafeArea.clear_mock_insets()
	if not _saved_character_before_test.is_empty():
		CharacterRoster.save_character(_saved_character_before_test)
		_saved_character_before_test = ""

func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		_cleanup_global_test_state()
		printerr("FAIL: mobile_adaptation test timed out")
		quit(1)
	)
	_run.call_deferred()

func _control_rect_in_viewport(ctrl: Control) -> Rect2:
	return ctrl.get_global_rect()

func _check(cond: bool, msg: String) -> void:
	if not cond:
		_cleanup_global_test_state()
		printerr("MOBILE_ADAPTATION_FAIL: " + msg)
		quit(1)

func _run() -> void:
	await _verify_touch_and_hud_matrix()
	await _verify_menus_responsive_matrix()
	await _test_mobile_title_showcase_alignment()
	await _verify_loading_screen_safe_area()
	await _verify_voyage_autosave_and_continue()
	_cleanup_global_test_state()
	print("MOBILE_ADAPTATION_OK: phone/tablet/foldable safe areas, scale 1.0/1.5 HUD anti-overlap, menu scroll hold, mobile title showcase alignment, loading safe area, touch prompts, and voyage save/resume")
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

	# Verify touch onboarding & contextual tips never leak [E] or pointer-lock copy.
	var guide := GameplayGuide.new(false)
	for g_mode: String in ["survival", "explore"]:
		guide.start_voyage(g_mode)
		for step_idx in range(GameplayGuide.ONBOARDING_STEPS.size()):
			guide.current_step_index = step_idx
			var payload: Dictionary = guide.get_hud_payload(false, true, true)
			for v in payload.values():
				var raw_str := str(v)
				_check(not raw_str.contains("点击锁定视角") and not raw_str.contains("[E]"), "Touch GameplayGuide payload leaked desktop copy: %s" % raw_str)
			for txt_key: String in ["instruction", "sub_hint"]:
				var formatted := hud.format_input_text(str(payload.get(txt_key, "")))
				_check(not formatted.contains("点击锁定视角") and not formatted.contains("[E]"), "Touch formatted onboarding text leaked desktop copy: %s" % formatted)
	for tip_val in GameplayGuide.CONTEXTUAL_TIPS.values():
		var fmt_tip := hud.format_input_text(str(tip_val))
		_check(not fmt_tip.contains("点击锁定视角") and not fmt_tip.contains("[E]"), "Touch contextual tip leaked desktop copy: %s" % fmt_tip)

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
	for res: Vector2i in TABLET_FOLD_VIEWS:
		cases.append({"res": res, "insets": [0.0, 0.0, 0.0, 0.0]})
		cases.append({"res": res, "insets": [0.0, 24.0, 20.0, 24.0]})

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
		touch._rebuild_layout()
		hud.set_touch_margins(touch.get_hud_safe_margins())
		await process_frame

		var life: Control = hud.instruments.get_node("LifeSupportInstrument")

		for scale: float in [0.75, 1.0, 1.5]:
			inputs.settings["touch_scale"] = scale
			touch.configure({"touch_scale": scale, "touch_opacity": 0.78})
			hud.set_touch_margins(touch.get_hud_safe_margins())
			hud.update_hud({"current_weapon": "knife", "scoped": false, "in_submarine": false, "details": true})
			var hud_safe: Rect2 = hud.get_layout_safe_rect()
			var life_rect := _control_rect_in_viewport(life)
			_check(hud_safe.grow(2.0).encloses(life_rect), "LifeSupportInstrument outside safe rect at %s scale %.2f insets=%s: %s vs %s" % [res, scale, ins, life_rect, hud_safe])

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

			# Check HUD anti-overlap at both default (1.0) and enlarged (1.5) touch_scale.
			if is_equal_approx(scale, 1.0) or is_equal_approx(scale, 1.5):
				_check(not life_rect.intersects(joy_rect), "LifeSupport overlaps joystick at %s scale %.2f insets=%s: %s vs %s" % [res, scale, ins, life_rect, joy_rect])
				for check_act: String in ["sprint", "weapon_cycle", "toggle_shield", "sonar_ping", "lamp", "attack", "interact"]:
					var b_rect: Rect2 = touch.get_control_rect(check_act)
					_check(not life_rect.intersects(b_rect), "LifeSupport overlaps %s at %s scale %.2f insets=%s: %s vs %s" % [check_act, res, scale, ins, life_rect, b_rect])
				_check(not hud.equipment_value.visible, "equipment_value must stay hidden in touch layout (including tablet/foldable) at %s scale %.2f" % [res, scale])
				var radar_rect := _control_rect_in_viewport(hud.minimap_radar)
				_check(not radar_rect.intersects(touch.get_control_rect("pause_game")), "Radar overlaps pause_game at %s scale %.2f" % [res, scale])

				hud.update_hud({"current_weapon": "sonic", "scoped": true, "scope_distance": 1200.0})
				var scope_rect := _control_rect_in_viewport(hud.scope_exit_btn)
				_check(hud.scope_exit_btn.visible, "scope_exit_btn must be visible when scoped")
				_check(hud_safe.grow(2.0).encloses(scope_rect), "scope_exit_btn outside safe rect at %s scale %.2f: %s vs %s" % [res, scale, scope_rect, hud_safe])
				_check(not scope_rect.intersects(touch.get_control_rect("ascend")), "scope_exit_btn overlaps ascend at %s scale %.2f: %s vs %s" % [res, scale, scope_rect, touch.get_control_rect("ascend")])
				_check(not scope_rect.intersects(touch.get_control_rect("pause_game")), "scope_exit_btn overlaps pause_game at %s scale %.2f: %s vs %s" % [res, scale, scope_rect, touch.get_control_rect("pause_game")])
				hud.update_hud({"current_weapon": "knife", "scoped": false})

	# Check scope exit button behavior.
	inputs.settings["touch_scale"] = 1.0
	touch.configure({"touch_scale": 1.0, "touch_opacity": 0.78})
	SafeArea.clear_mock_insets()
	viewport.size = Vector2i(844, 390)
	hud.root.size = Vector2(844, 390)
	touch.size = Vector2(844, 390)
	touch._rebuild_layout()
	hud.set_touch_margins(touch.get_hud_safe_margins())
	var emitted_actions: Array[String] = []
	hud.action_requested.connect(func(a: String) -> void: emitted_actions.append(a))
	hud.scope_exit_btn.show()
	_check(hud.scope_exit_btn.size.y >= 44.0, "Scope exit button height must be >= 44px")
	_check(hud.scope_exit_btn.icon != null and hud.scope_exit_btn.text.is_empty(), "Touch scope_exit_btn must use pure image icon without text")
	hud.scope_exit_btn.pressed.emit()
	_check(emitted_actions.has("scope"), "Scope exit button must emit scope toggle action")
	var skip_box := {"count": 0}
	hud.onboarding_skip_requested.connect(func() -> void: skip_box["count"] = int(skip_box["count"]) + 1)
	_check(is_instance_valid(hud.onboarding_close_btn) and hud.onboarding_close_btn.icon != null and hud.onboarding_close_btn.text.is_empty(), "Onboarding skip button must use image icon in touch mode")
	hud.onboarding_close_btn.pressed.emit()
	_check(int(skip_box["count"]) == 1, "Onboarding close icon button must emit onboarding_skip_requested")

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

	# Verify modal scroll preservation on touch (craft menu at 844x390 across 0.25s navigation refresh).
	SafeArea.set_mock_insets(0.0, 59.0, 21.0, 59.0)
	viewport.size = Vector2i(844, 390)
	hud.root.size = Vector2(844, 390)
	hud.set_screen("craft")
	hud._apply_layout()
	await process_frame
	await process_frame
	var craft_scroll: ScrollContainer = hud.menu_scrolls["craft"]
	_check(not craft_scroll.follow_focus, "Touch mode craft menu must disable follow_focus")
	craft_scroll.scroll_vertical = 120
	await process_frame
	hud._process(0.25)
	await process_frame
	_check(craft_scroll.scroll_vertical >= 100, "Touch mode craft scroll_vertical must not snap back to 0 after 0.25s navigation refresh (got %d)" % craft_scroll.scroll_vertical)

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

func _test_mobile_title_showcase_alignment() -> void:
	_saved_character_before_test = CharacterRoster.load_saved_character()
	var temp_save := "user://test_mobile_title_showcase_unused.json"
	if FileAccess.file_exists(temp_save):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_save))

	var viewport := SubViewport.new()
	viewport.size = Vector2i(390, 844)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var packed := load("res://scenes/main.tscn") as PackedScene
	_check(packed != null, "scenes/main.tscn must load cleanly for title showcase test")
	var game := packed.instantiate()
	game.voyage_save_path = temp_save
	game.gameplay_guide.persist_enabled = false
	viewport.add_child(game)
	await process_frame
	await process_frame

	game.input_controller.apply_settings({"touch_mode": "on"}, false)
	game.input_controller.notify_device("touch")
	game._set_screen("main")
	await process_frame

	var view_cases: Array[Dictionary] = [
		{"name": "portrait_390x844_dynamic_island", "res": Vector2i(390, 844), "insets": [59.0, 0.0, 34.0, 0.0]},
		{"name": "portrait_360x740_zero_insets", "res": Vector2i(360, 740), "insets": [0.0, 0.0, 0.0, 0.0]},
		{"name": "landscape_844x390_safe_insets", "res": Vector2i(844, 390), "insets": [0.0, 59.0, 21.0, 59.0]},
		{"name": "landscape_640x360_zero_insets", "res": Vector2i(640, 360), "insets": [0.0, 0.0, 0.0, 0.0]},
	]
	var char_ids: Array[String] = ["coral_mermaid", "expedition_diver"]

	for case_info: Dictionary in view_cases:
		var case_name: String = str(case_info["name"])
		var res: Vector2i = case_info["res"]
		var ins: Array = case_info["insets"]
		if ins[0] == 0.0 and ins[1] == 0.0 and ins[2] == 0.0 and ins[3] == 0.0:
			SafeArea.clear_mock_insets()
		else:
			SafeArea.set_mock_insets(ins[0], ins[1], ins[2], ins[3])

		viewport.size = res
		game.hud.root.size = Vector2(res)
		game.touch_controls.size = Vector2(res)
		game.touch_controls._rebuild_layout()
		game._sync_touch_context_and_margins(true)
		game.hud._apply_layout()
		await process_frame

		for cid: String in char_ids:
			var label := "%s [%s]" % [case_name, cid]
			game._select_character(cid, false)
			game.reset_title_showcase_angles()
			_check(game.screen == "main", "Title showcase test must stay on main screen (%s)" % label)
			_check(is_instance_valid(game.title_showcase_diver) and game.title_showcase_diver.visible, "Title showcase diver must be visible on main screen (%s)" % label)
			_check(game.title_showcase_diver.current_character == cid, "Title showcase character mismatch (%s): got %s" % [label, game.title_showcase_diver.current_character])

			for _step in range(60):
				game._update_title_camera(0.016)
			await process_frame

			var showcase: CharacterBody3D = game.title_showcase_diver
			var cam: Camera3D = game.title_camera
			_check(is_instance_valid(cam), "title_camera must be valid (%s)" % label)
			_check(is_instance_valid(showcase.body_pivot) and is_instance_valid(showcase.diver_model), "Showcase body_pivot/diver_model must be valid (%s)" % label)
			_check(is_instance_valid(showcase.head_pivot) and is_instance_valid(showcase.left_fin_pivot) and is_instance_valid(showcase.right_fin_pivot), "Showcase head/fin pivots must be valid (%s)" % label)

			var body_rot: Vector3 = showcase.body_pivot.rotation
			_check(absf(body_rot.x) < 0.03 and absf(body_rot.z) < 0.03, "Showcase body_pivot must stay upright (%s): rot=%s" % [label, body_rot])
			var model_z: float = showcase.diver_model.position.z
			_check(absf(model_z) < 0.01, "Showcase diver_model.position.z must stay centered on spin axis (%s): z=%.4f" % [label, model_z])

			var head_world: Vector3 = showcase.head_pivot.global_position
			var body_world: Vector3 = showcase.body_pivot.global_position
			var fin_world: Vector3 = (showcase.left_fin_pivot.global_position + showcase.right_fin_pivot.global_position) * 0.5
			_check(not cam.is_position_behind(head_world) and not cam.is_position_behind(body_world) and not cam.is_position_behind(fin_world), "Showcase pivots must be in front of title_camera (%s)" % label)

			var hp: Vector2 = cam.unproject_position(head_world)
			var bp: Vector2 = cam.unproject_position(body_world)
			var fp: Vector2 = cam.unproject_position(fin_world)
			var tilt_hb: float = rad_to_deg(atan2(bp.x - hp.x, maxf(1.0, bp.y - hp.y)))
			var tilt_hf: float = rad_to_deg(atan2(fp.x - hp.x, maxf(1.0, fp.y - hp.y)))
			_check(absf(tilt_hb) < 1.5, "Showcase head-to-body tilt %.2f deg exceeds 1.5 deg (%s): hp=%s bp=%s" % [tilt_hb, label, hp, bp])
			_check(absf(tilt_hf) < 1.5, "Showcase head-to-fin tilt %.2f deg exceeds 1.5 deg (%s): hp=%s fp=%s" % [tilt_hf, label, hp, fp])

			var vp_w := float(res.x)
			_check(absf(hp.x - vp_w * 0.5) <= vp_w * 0.035, "Showcase head not horizontally centered (%s): hp.x=%.1f vs %.1f (tol=%.1f)" % [label, hp.x, vp_w * 0.5, vp_w * 0.035])
			_check(absf(fp.x - vp_w * 0.5) <= vp_w * 0.035, "Showcase fin midpoint not horizontally centered (%s): fp.x=%.1f vs %.1f (tol=%.1f)" % [label, fp.x, vp_w * 0.5, vp_w * 0.035])

			if res.x < res.y:
				var title_en_ctrl: Control = game.hud._main_ui["en_lbl"]
				var char_card_ctrl: Control = game.hud._main_ui["char_card"]
				var title_en_rect := _control_rect_in_viewport(title_en_ctrl)
				var char_card_rect := _control_rect_in_viewport(char_card_ctrl)
				_check(hp.y > title_en_rect.end.y, "Portrait showcase head overlaps title (%s): hp.y=%.1f <= title_en.end.y=%.1f" % [label, hp.y, title_en_rect.end.y])
				_check(fp.y < char_card_rect.position.y, "Portrait showcase fin pivot overlaps bottom character card (%s): fp.y=%.1f >= char_card.y=%.1f" % [label, fp.y, char_card_rect.position.y])

			if res == Vector2i(390, 844):
				game.rotate_title_showcase(PI * 0.5)
				game._update_title_camera(0.016)
				await process_frame
				var hp_rot: Vector2 = cam.unproject_position(showcase.head_pivot.global_position)
				var bp_rot: Vector2 = cam.unproject_position(showcase.body_pivot.global_position)
				var fp_rot: Vector2 = cam.unproject_position((showcase.left_fin_pivot.global_position + showcase.right_fin_pivot.global_position) * 0.5)
				var tilt_hb_rot: float = rad_to_deg(atan2(bp_rot.x - hp_rot.x, maxf(1.0, bp_rot.y - hp_rot.y)))
				var tilt_hf_rot: float = rad_to_deg(atan2(fp_rot.x - hp_rot.x, maxf(1.0, fp_rot.y - hp_rot.y)))
				_check(absf(hp_rot.x - vp_w * 0.5) <= vp_w * 0.035, "Showcase rotated 90 deg drifted off center (%s): hp.x=%.1f vs %.1f" % [label, hp_rot.x, vp_w * 0.5])
				_check(absf(bp_rot.x - vp_w * 0.5) <= vp_w * 0.035, "Showcase rotated 90 deg torso drifted off center (%s): bp.x=%.1f vs %.1f" % [label, bp_rot.x, vp_w * 0.5])
				_check(absf(tilt_hb_rot) < 1.5, "Showcase rotated 90 deg spine tilted %.2f deg (%s): hp=%s bp=%s" % [tilt_hb_rot, label, hp_rot, bp_rot])
				if cid != "expedition_diver":
					_check(absf(tilt_hf_rot) < 1.5, "Showcase rotated 90 deg tilted %.2f deg (%s): hp=%s fp=%s" % [tilt_hf_rot, label, hp_rot, fp_rot])
				game.reset_title_showcase_angles()
				await process_frame

	_cleanup_global_test_state()
	if FileAccess.file_exists(temp_save):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_save))
	viewport.queue_free()
	await process_frame

func _verify_loading_screen_safe_area() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(390, 844)
	root.add_child(viewport)
	SafeArea.set_mock_insets(59.0, 0.0, 34.0, 0.0)

	var loading_packed := load("res://scenes/loading.tscn") as PackedScene
	_check(loading_packed != null, "scenes/loading.tscn must load cleanly")
	var loading := loading_packed.instantiate()
	viewport.add_child(loading)
	loading.set_process(false)
	await process_frame
	loading._layout_ui()
	await process_frame

	var raw_safe := SafeArea.get_safe_rect(viewport)
	var title_rect := Rect2(loading._title_label.position, loading._title_label.size)
	var astro_c: Vector2 = loading._plate._astro_center
	var astro_outer_r: float = float(loading._plate._astro_radius) * 1.11
	var astro_rect := Rect2(astro_c - Vector2(astro_outer_r, astro_outer_r), Vector2(astro_outer_r * 2.0, astro_outer_r * 2.0))
	var header_rect := Rect2(loading._header_label.position, loading._header_label.size)
	var bar_rect: Rect2 = loading._plate._bar_rect

	_check(raw_safe.grow(1.5).encloses(title_rect), "LoadingScreen title exceeds Dynamic Island safe area at 390x844: %s vs %s" % [title_rect, raw_safe])
	_check(raw_safe.grow(1.5).encloses(astro_rect), "LoadingScreen astrolabe exceeds Dynamic Island safe area at 390x844: %s vs %s" % [astro_rect, raw_safe])
	_check(raw_safe.grow(1.5).encloses(header_rect), "LoadingScreen header exceeds Dynamic Island safe area at 390x844: %s vs %s" % [header_rect, raw_safe])
	_check(raw_safe.grow(1.5).encloses(bar_rect), "LoadingScreen progress bar exceeds Dynamic Island safe area at 390x844: %s vs %s" % [bar_rect, raw_safe])
	_check(not title_rect.intersects(astro_rect), "LoadingScreen title overlaps astrolabe at 390x844: %s vs %s" % [title_rect, astro_rect])

	var tap_ev := InputEventScreenTouch.new()
	tap_ev.index = 0
	tap_ev.pressed = true
	tap_ev.position = Vector2(195.0, 420.0)
	loading._input(tap_ev)
	_check(bool(loading._skip_min_wait), "ScreenTouch on LoadingScreen must set _skip_min_wait")

	if not String(loading._active_path).is_empty():
		ResourceLoader.load_threaded_get(String(loading._active_path))
	loading._held_resources.clear()
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

	# Verify 3D interaction Label3D prompts cleanly switch away from [E] in touch mode.
	game.ocean.refresh_interaction_prompts(true)
	var label_3d_nodes: Array = game.ocean.find_children("*", "Label3D", true, false)
	_check(not label_3d_nodes.is_empty(), "Ocean must contain 3D Label3D prompts")
	for node in label_3d_nodes:
		var lbl := node as Label3D
		_check(not lbl.text.contains("[E]") and not lbl.text.contains("点击锁定视角"), "Touch Ocean Label3D leaked desktop prompt (%s): %s" % [lbl.name, lbl.text])
	for helper_txt: String in [
		game.ocean._format_mother_item_label("生命核心", true),
		game.ocean._format_outpost_label("浅礁前哨", false, true),
		game.ocean._format_outpost_label("浅礁前哨", true, true),
		game.ocean._format_relic_label("星盘残片", true),
	]:
		_check(not helper_txt.contains("[E]") and helper_txt.contains("点击交互"), "Touch Ocean prompt helper must replace [E] with 点击交互: %s" % helper_txt)

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
