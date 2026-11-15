extends SceneTree
## End-to-end behavioral and layout tests for GameplayGuide, GuidePanel, HUD onboarding card, and Game screen return stack.

const GameplayGuide = preload("res://scripts/gameplay_guide.gd")
const HUD = preload("res://scripts/hud.gd")
const Game = preload("res://scripts/game.gd")

const TEMP_SAVE := "user://test_onboarding_guide.cfg"

class FakeInputs extends Node:
	signal device_changed(device: String)
	signal settings_changed
	var active_device := "keyboard"
	var settings := {
		"gamepad_sensitivity": 1.0,
		"touch_sensitivity": 1.0,
		"deadzone": 0.2,
		"touch_scale": 1.0,
		"touch_opacity": 0.75,
		"invert_y": false,
		"touch_mode": "auto",
	}
	func hint(action: String) -> String:
		if active_device == "touch":
			return "TOUCH_" + action
		return "PAD_" + action

func _initialize() -> void:
	create_timer(30.0).timeout.connect(func() -> void:
		_cleanup_temp_save()
		printerr("GAMEPLAY_GUIDE_TEST_TIMEOUT")
		quit(1)
	)
	_run.call_deferred()

func _cleanup_temp_save() -> void:
	var abs_path := ProjectSettings.globalize_path(TEMP_SAVE)
	if FileAccess.file_exists(TEMP_SAVE) or FileAccess.file_exists(abs_path):
		DirAccess.remove_absolute(abs_path)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_cleanup_temp_save()
		printerr("ASSERTION_FAILED: ", message)
		quit(1)

func _run() -> void:
	_cleanup_temp_save()
	_test_chapters_and_sequential_survival()
	_test_explore_out_of_order_and_tips()
	_test_persistence_skip_and_restart()
	await _test_hud_guide_and_onboarding_layout()
	await _test_game_return_stack()
	_cleanup_temp_save()
	print("PASS: gameplay guide chapters, dual-mode onboarding, contextual tips, persistence, responsive HUD layout and return stack")
	quit()

func _test_chapters_and_sequential_survival() -> void:
	var chapters := GameplayGuide.get_chapters()
	assert(chapters.size() == 7, "Guide must provide 7 structured chapters")
	var ids := {}
	for ch: Dictionary in chapters:
		var cid := str(ch.get("id", ""))
		assert(not cid.is_empty() and not ids.has(cid), "Chapter IDs must be unique")
		ids[cid] = true
		assert(not str(ch.get("title", "")).is_empty())
		assert(not str(ch.get("summary", "")).is_empty())
		var items: Array = ch.get("items", [])
		assert(items.size() >= 3, "Each chapter should contain structured items")

	var guide := GameplayGuide.new(false)
	guide.start_voyage("survival")
	assert(guide.is_onboarding_visible())
	assert(guide.current_step_index == 0)
	var web_payload := guide.get_hud_payload(false, true)
	assert(str(web_payload["sub_hint"]).contains("点击锁定视角"))

	# Fast travel / teleport deltas (> 18m) must be ignored during step 1.
	var tp_res := guide.record_motion(Vector3(32.0, 5.0, 0.0))
	assert(not bool(tp_res["step_advanced"]) and is_zero_approx(guide.horiz_moved))

	# Normal swimming + vertical diving completes step 1 ("swim").
	guide.record_motion(Vector3(4.5, 0.8, 0.0))
	assert(guide.current_step_index == 0)
	var swim_res := guide.record_motion(Vector3(4.2, -0.9, 0.0))
	assert(bool(swim_res["step_advanced"]) and guide.current_step_index == 1)

	# Step 2: lamp or shield
	var lamp_res := guide.notify_event("lamp_toggled")
	assert(bool(lamp_res["step_advanced"]) and guide.current_step_index == 2)

	# Step 3: sonar ping
	var sonar_res := guide.notify_event("sonar_pinged")
	assert(bool(sonar_res["step_advanced"]) and guide.current_step_index == 3)

	# Step 4: sea chart requires opening then closing
	var premature_close := guide.notify_event("map_closed")
	assert(not bool(premature_close["step_advanced"]) and guide.current_step_index == 3)
	guide.notify_event("map_opened")
	var map_res := guide.notify_event("map_closed")
	assert(bool(map_res["step_advanced"]) and guide.current_step_index == 4)

	# Step 5 in survival mode ignores sonic_fired, requires real gathering/supply action
	var sonic_surv := guide.notify_event("sonic_fired")
	assert(not bool(sonic_surv["step_advanced"]) and guide.current_step_index == 4)
	var gather_res := guide.notify_event("resource_collected")
	assert(bool(gather_res["step_advanced"]) and guide.current_step_index == 5)

	# Step 6: workbench / sushi / guide completes onboarding with temporary banner
	var done_res := guide.notify_event("craft_opened")
	assert(bool(done_res["completed_now"]) and guide.onboarding_completed)
	assert(guide.completion_banner_timer > 0.0 and guide.is_onboarding_visible())
	var banner_payload := guide.get_hud_payload()
	assert(bool(banner_payload["completed_banner"]))
	guide.tick(3.0)
	assert(not guide.is_onboarding_visible())

func _test_explore_out_of_order_and_tips() -> void:
	var guide := GameplayGuide.new(false)
	guide.start_voyage("explore")
	assert(guide.mode == "explore")

	# Pre-complete step 3 (sonar) and step 5 (sonic_fired in explore mode) while still on step 1.
	guide.notify_event("sonar_pinged")
	guide.notify_event("sonic_fired")
	assert(guide.current_step_index == 0)

	# Finish step 1 & step 2 -> must automatically skip step 3 (sonar) and land on step 4 (sea_chart, idx 3).
	guide.record_motion(Vector3(9.0, 2.0, 0.0))
	assert(guide.current_step_index == 1)
	guide.notify_event("shield_toggled")
	assert(guide.current_step_index == 3, "Pre-completed sonar step must be skipped automatically")

	# Finish step 4 -> must automatically skip pre-completed step 5 (gather) and land on step 6 (workbench, idx 5).
	guide.notify_event("map_opened")
	guide.notify_event("map_closed")
	assert(guide.current_step_index == 5, "Pre-completed explore gather step must be skipped automatically")

	# Contextual tips deduplication & cooldown
	var tip1 := guide.notify_event("weapon_equipped", {"weapon": "sonic"})
	assert(str(tip1["tip_id"]) == "tip_sonic_charge" and not str(tip1["tip_text"]).is_empty())

	# Cooldown blocks immediate second tip
	var blocked_tip := guide.notify_event("overweight_entered")
	assert(str(blocked_tip["tip_text"]).is_empty(), "Cooldown must suppress back-to-back contextual tips")

	# After cooldown expires, overweight tip fires once, and sonic tip never repeats
	guide.tick(13.0)
	var tip2 := guide.notify_event("overweight_entered")
	assert(str(tip2["tip_id"]) == "tip_overweight" and not str(tip2["tip_text"]).is_empty())
	guide.tick(13.0)
	var repeat_tip := guide.notify_event("weapon_equipped", {"weapon": "sonic"})
	assert(str(repeat_tip["tip_text"]).is_empty(), "Seen contextual tip must not repeat")

func _test_persistence_skip_and_restart() -> void:
	var writer := GameplayGuide.new(true, TEMP_SAVE)
	writer.restart_onboarding("survival")
	writer.notify_event("weapon_equipped", {"weapon": "sonic"})
	writer.skip_onboarding()
	assert(writer.onboarding_skipped and not writer.is_onboarding_visible())

	var reader := GameplayGuide.new(true, TEMP_SAVE)
	reader.start_voyage("survival")
	assert(reader.onboarding_skipped and not reader.is_onboarding_visible())
	assert(bool(reader.seen_tips.get("tip_sonic_charge", false)))

	reader.restart_onboarding("explore")
	assert(not reader.onboarding_skipped and not reader.onboarding_completed)
	assert(reader.is_onboarding_visible() and reader.current_step_index == 0 and reader.mode == "explore")

	var reader_after_reset := GameplayGuide.new(true, TEMP_SAVE)
	reader_after_reset.start_voyage("explore")
	assert(reader_after_reset.is_onboarding_visible() and reader_after_reset.current_step_index == 0)

func _test_hud_guide_and_onboarding_layout() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	root.add_child(viewport)
	var inputs := FakeInputs.new()
	viewport.add_child(inputs)
	var hud := HUD.new()
	viewport.add_child(hud)
	await process_frame
	hud.configure_input(inputs)
	hud.set_process(false)
	await process_frame

	# Default HUD without onboarding payload keeps OnboardingInstrument hidden.
	hud.set_screen("play")
	var base_data := {
		"mode": "survival",
		"oxygen": 80.0,
		"max_oxygen": 90.0,
		"health": 100.0,
		"depth": 12.0,
		"biome": "阳光浅礁带",
		"current_weapon": "knife",
		"inventory": {"titanium": 1},
	}
	hud.update_hud(base_data)
	assert(not hud.onboarding_panel.visible)

	var guide := GameplayGuide.new(false)
	guide.start_voyage("survival")
	var ob_data := base_data.duplicate(true)
	ob_data["onboarding"] = guide.get_hud_payload()

	# Check zero-overlap across desktop, tablet touch, and compact mobile touch resolutions.
	var cases := [
		{"size": Vector2i(1280, 800), "device": "keyboard", "touch_mode": "auto"},
		{"size": Vector2i(1920, 1080), "device": "keyboard", "touch_mode": "auto"},
		{"size": Vector2i(1280, 800), "device": "touch", "touch_mode": "on"},
		{"size": Vector2i(844, 390), "device": "touch", "touch_mode": "on"},
		{"size": Vector2i(640, 360), "device": "touch", "touch_mode": "on"},
	]
	var life_panel: Control = hud.instruments.get_node("LifeSupportInstrument")
	for c: Dictionary in cases:
		var sz: Vector2i = c["size"]
		viewport.size = sz
		hud.root.size = Vector2(sz)
		inputs.active_device = str(c["device"])
		inputs.settings["touch_mode"] = str(c["touch_mode"])
		inputs.settings_changed.emit()
		inputs.device_changed.emit(inputs.active_device)
		hud.set_screen("play")
		hud.update_hud(ob_data)
		hud.toast("发现新的科考地标 · 已记录海图与航向")
		hud._process(0.1)
		await process_frame
		_expect(hud.onboarding_panel.is_visible_in_tree(), "Onboarding card must be visible at %s" % [sz])
		var ob_rect := hud.onboarding_panel.get_global_rect()
		_expect(Rect2(Vector2.ZERO, Vector2(sz)).encloses(ob_rect.grow(-1.0)), "Onboarding card must stay inside viewport at %s" % [sz])
		_expect(not ob_rect.intersects(life_panel.get_global_rect()), "Onboarding card must not overlap LifeSupportInstrument at %s" % [sz])
		_expect(not ob_rect.intersects(hud.compass_strip.get_global_rect()), "Onboarding card must not overlap compass at %s" % [sz])
		_expect(not ob_rect.intersects(hud.status_value.get_global_rect()), "Onboarding card must not overlap status readout at %s (ob=%s, status=%s)" % [sz, ob_rect, hud.status_value.get_global_rect()])
		_expect(not ob_rect.intersects(hud.toast_label.get_global_rect()), "Onboarding card must not overlap toast at %s (ob=%s, toast=%s)" % [sz, ob_rect, hud.toast_label.get_global_rect()])

	# Yielding to scoped / submarine / boss fight states
	viewport.size = Vector2i(1280, 800)
	hud.root.size = Vector2(1280, 800)
	inputs.active_device = "keyboard"
	inputs.settings["touch_mode"] = "auto"
	inputs.settings_changed.emit()
	for suppression_case: Dictionary in [
		{"current_weapon": "sonic", "scoped": true},
		{"in_submarine": true, "sub_name": "深海斥候号"},
		{"boss": {"active": true, "name": "深渊水龙", "health": 900.0, "max_health": 1800.0}},
	]:
		var state_data := ob_data.duplicate(true)
		state_data.merge(suppression_case, true)
		hud.update_hud(state_data)
		assert(not hud.onboarding_panel.visible, "Onboarding card must yield during high-priority combat/vehicle/scope state")

	# Guide screen chapter switching & dynamic device hint updates
	hud.set_screen("guide")
	await process_frame
	var chapter_btns: Array = hud.guide_view.get("chapter_buttons", [])
	assert(chapter_btns.size() == 7)
	var select_fn: Callable = hud.guide_view["select_chapter"]
	for idx in range(7):
		select_fn.call(idx)
	select_fn.call(0)
	var item_card: Panel = hud.menus["guide"].find_child("ItemCard_0", true, false)
	assert(is_instance_valid(item_card) and item_card.visible)
	inputs.active_device = "gamepad"
	inputs.device_changed.emit("gamepad")
	assert(hud.onboarding_desc.text.contains("PAD_"), "Onboarding description must adapt to gamepad hints")
	var restart_signals := [0]
	var skip_signals := [0]
	hud.onboarding_restart_requested.connect(func() -> void: restart_signals[0] += 1)
	hud.onboarding_skip_requested.connect(func() -> void: skip_signals[0] += 1)
	(hud.guide_view["restart_btn"] as Button).pressed.emit()
	(hud.guide_view["skip_btn"] as Button).pressed.emit()
	assert(restart_signals[0] == 1 and skip_signals[0] == 1)

	viewport.queue_free()
	await process_frame

func _test_game_return_stack() -> void:
	var game := Game.new()
	game.gameplay_guide.persist_enabled = false
	root.add_child(game)
	game.gameplay_guide.persist_enabled = false
	game.set_process(false)
	game.set_physics_process(false)
	game.ocean.process_mode = Node.PROCESS_MODE_DISABLED
	game.diver.set_physics_process(false)
	game.diver.set_process(false)
	await process_frame

	# main -> guide -> close -> main
	assert(game.screen == "main" and not paused)
	game._on_hud_action_requested("gameplay_guide")
	assert(game.screen == "guide" and paused)
	game._close_input_screen()
	assert(game.screen == "main" and not paused)

	# play -> pause -> guide -> controls -> close -> guide -> close -> pause -> close -> play
	game._start("explore")
	assert(game.screen == "play" and not paused)
	game._set_screen("pause")
	assert(game.screen == "pause" and paused)
	game._on_hud_action_requested("gameplay_guide")
	assert(game.screen == "guide" and game.guide_return_screen == "pause")
	game._on_hud_action_requested("controls")
	assert(game.screen == "controls" and game.controls_return_screen == "guide")
	game._close_input_screen()
	assert(game.screen == "guide")
	game._close_input_screen()
	assert(game.screen == "pause")
	game._close_input_screen()
	assert(game.screen == "play" and not paused)

	# pause -> controls -> guide -> close -> pause (no controls<->guide infinite loop)
	game._set_screen("pause")
	game._on_hud_action_requested("controls")
	assert(game.screen == "controls" and game.controls_return_screen == "pause")
	game._on_hud_action_requested("gameplay_guide")
	assert(game.screen == "guide" and game.guide_return_screen == "pause")
	game._close_input_screen()
	assert(game.screen == "pause")

	paused = false
	game.free()
	await process_frame
