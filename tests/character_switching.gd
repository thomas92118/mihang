extends SceneTree
## End-to-end verification for multi-character switching and additional mermaid variants.

const Diver = preload("res://scripts/diver.gd")
const Game = preload("res://scripts/game.gd")
const CharacterRoster = preload("res://scripts/presentation/character_roster.gd")
const ReferenceDiver = preload("res://scripts/presentation/reference_diver.gd")

func _initialize() -> void:
	create_timer(45.0).timeout.connect(func() -> void:
		CharacterRoster.save_character(CharacterRoster.DEFAULT_CHARACTER)
		printerr("CHARACTER_SWITCHING_TIMEOUT")
		quit(1)
	)
	_run.call_deferred()

func _find_role_material(model_root: Node3D, role: String) -> StandardMaterial3D:
	for part: MeshInstance3D in model_root.find_children("*", "MeshInstance3D", true, false):
		if not bool(part.get_meta("reference_part", false)) or part.mesh == null:
			continue
		for s_idx in part.mesh.get_surface_count():
			var mat := part.get_active_material(s_idx) as StandardMaterial3D
			if mat != null and String(mat.get_meta("reference_role", "")) == role:
				return mat
	return null

func _run() -> void:
	assert(ReferenceDiver.available(), "reference_diver.glb must be imported")
	for required_id: String in ["coral_mermaid", "moonlight_mermaid", "abyss_mermaid", "golden_siren", "sakura_mermaid", "expedition_diver"]:
		assert(required_id in CharacterRoster.CHARACTER_ORDER, "Missing character: " + required_id)

	# 1. Standalone Diver live switching, distinct mermaid textures/ornaments, and state preservation
	var diver := Diver.new()
	root.add_child(diver)
	diver.set_process(false)
	diver.set_physics_process(false)
	assert(diver.current_character == "coral_mermaid" and diver.reference_model_active)
	var coral_scales := _find_role_material(diver.diver_model, "scales")
	assert(coral_scales != null and coral_scales.albedo_texture != null, "Default mermaid scales material missing")
	var coral_scale_tex_id := coral_scales.albedo_texture.get_instance_id()
	assert(diver.head_pivot.get_node_or_null("CharacterOrnament") == null, "Default coral mermaid must keep pure authored silhouette")

	var seen_scale_tex_ids: Dictionary = {coral_scale_tex_id: "coral_mermaid"}
	for cid: String in CharacterRoster.CHARACTER_ORDER:
		var profile := diver.set_character(cid)
		assert(diver.current_character == cid and String(profile.get("id", "")) == cid)
		assert(String(diver.diver_model.get_meta("character_id", "")) == cid)
		var is_mermaid := bool(profile.get("is_mermaid", true))
		assert(diver.reference_model_active == is_mermaid, "Wrong rig mode for " + cid)
		if is_mermaid:
			var scales_mat := _find_role_material(diver.diver_model, "scales")
			var hair_mat := _find_role_material(diver.diver_model, "hair")
			var iris_mat := _find_role_material(diver.diver_model, "iris")
			assert(scales_mat != null and hair_mat != null and iris_mat != null, "Missing tagged mermaid materials on " + cid)
			if cid != "coral_mermaid":
				var tex_id := scales_mat.albedo_texture.get_instance_id()
				assert(not seen_scale_tex_ids.has(tex_id), "Mermaid variant must have distinct procedural scale texture: " + cid)
				seen_scale_tex_ids[tex_id] = cid
				var ornament := diver.head_pivot.get_node_or_null("CharacterOrnament")
				assert(ornament != null and ornament.get_child_count() > 0, "Mermaid variant missing 3D head ornament: " + cid)
			if cid == "abyss_mermaid":
				assert(scales_mat.emission_enabled and scales_mat.emission_energy_multiplier > 0.4, "Abyss mermaid must have bioluminescent scales")
			if cid == "moonlight_mermaid":
				assert(scales_mat.emission_enabled and hair_mat.albedo_texture != null, "Moonlight mermaid must have starry scale glow and silver hair texture")
		else:
			assert(diver.booster_node.position.is_equal_approx(Vector3(0.0, -0.14, -0.46)))

		for motion: Vector3 in [Vector3.ZERO, Vector3(0, 0, -5.0), Vector3(0, 2.5, -4.0)]:
			diver.velocity = motion
			for _f in 20:
				diver._animate_diver_model(1.0 / 60.0)
				assert(diver.body_pivot.transform.is_finite() and diver.head_pivot.transform.is_finite(), "Non-finite pose on " + cid)

	# State preservation across character switch (weapon, shield, submarine, scope)
	diver.set_weapon("sonic")
	diver.aiming = true
	diver.shield_active = true
	diver.set_character("moonlight_mermaid")
	diver._animate_diver_model(1.0 / 60.0)
	var gun: Node3D = diver.weapon_nodes.sonic
	diver._sync_reference_gun_to_hand(gun, "sonic", Vector3.ZERO, Vector3.ZERO)
	assert(gun.to_global(Vector3(0, -0.10, 0.16)).distance_to(diver.right_hand_socket.global_position) < 0.002, "Gun detached after switching to moonlight_mermaid")
	diver.set_submarine_mode(true, "scout")
	diver.set_character("abyss_mermaid")
	assert(not diver.diver_model.visible and not diver.breath_bubbles.emitting, "Submarine visibility leaked across character switch")
	diver.set_submarine_mode(false)
	diver.scoped = true
	diver.set_character("sakura_mermaid")
	assert(not diver.diver_model.visible, "Scoped visibility leaked across character switch")
	diver.scoped = false

	# Material isolation between two concurrent mermaids with different styles
	var second := Diver.new()
	root.add_child(second)
	second.set_process(false)
	second.set_physics_process(false)
	diver.set_character("coral_mermaid")
	second.set_character("abyss_mermaid")
	var c_mat := _find_role_material(diver.diver_model, "scales")
	var a_mat := _find_role_material(second.diver_model, "scales")
	assert(c_mat.get_instance_id() != a_mat.get_instance_id() and not c_mat.emission_enabled and a_mat.emission_enabled, "Concurrent mermaid instances leaked material state")
	diver.free()
	second.free()

	# 2. Full Game + Title Showcase + HUD Selector + Hotkey P Integration
	CharacterRoster.save_character("coral_mermaid")
	var game := Game.new()
	root.add_child(game)
	await process_frame
	await process_frame
	assert(game.screen == "main" and is_instance_valid(game.title_showcase_diver) and game.title_showcase_diver.visible, "Title showcase diver must be visible on main screen")
	assert(game.diver.current_character == "coral_mermaid" and game.title_showcase_diver.current_character == "coral_mermaid")

	# Select moonlight_mermaid via Title Screen HUD button
	var moon_btn: Button = game.hud.main_char_buttons.get("moonlight_mermaid", null)
	assert(is_instance_valid(moon_btn), "Title character button missing for moonlight_mermaid")
	moon_btn.pressed.emit()
	await process_frame
	assert(game.diver.current_character == "moonlight_mermaid" and game.title_showcase_diver.current_character == "moonlight_mermaid")
	assert(CharacterRoster.load_saved_character() == "moonlight_mermaid")
	assert(game.hud.main_char_title.text.contains("月光银发人鱼"))

	# Enter play mode and press P (character_switch) -> should advance to abyss_mermaid
	game.hud.start_requested.emit("explore")
	await process_frame
	assert(game.screen == "play" and not game.title_showcase_diver.visible)
	var ev := InputEventAction.new()
	ev.action = "character_switch"
	ev.pressed = true
	game._handle_action_event(ev)
	await process_frame
	assert(game.diver.current_character == "abyss_mermaid", "Hotkey character_switch did not advance to abyss_mermaid")
	assert(game.hud.pause_char_btn.text.contains("深海幽光人鱼"))

	# Pause menu cycle button -> golden_siren
	game._set_screen("pause")
	await process_frame
	game.hud.pause_char_btn.pressed.emit()
	await process_frame
	assert(game.diver.current_character == "golden_siren", "Pause menu character button did not cycle to golden_siren")

	get_tree_or_self_cleanup(game)
	CharacterRoster.save_character(CharacterRoster.DEFAULT_CHARACTER)
	print("PASS: character_switching verified across all 6 characters, bespoke ornaments, isolated PBR textures, HUD selector, title showcase, pause menu & P hotkey")
	quit(0)

func get_tree_or_self_cleanup(game: Node) -> void:
	paused = false
	if is_instance_valid(game):
		game.free()
