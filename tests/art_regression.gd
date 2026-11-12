extends SceneTree
## Headless art refactor regression suite:
## 1. Frozen landmark collisions (ruins & shipwreck) + Ocean attachment
## 2. Visual builders, art_finished metadata, sockets/pivots & headlight shadow budget
## 3. Creature material instance isolation & GLB AnimationPlayer pause when frozen
## 4. Dual-resolution (1280x800 & 1920x1080) UI bounds & sibling button non-overlap

const Ocean = preload("res://scripts/ocean.gd")
const Diver = preload("res://scripts/diver.gd")
const Submarine = preload("res://scripts/submarine.gd")
const MarineCreature = preload("res://scripts/marine_creature.gd")
const HUD = preload("res://scripts/hud.gd")

const UI_TOLERANCE_PX := 2.0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var ocean := _verify_landmark_collisions()
	_verify_visual_builders()
	await _verify_animation_and_material_isolation(ocean)
	if is_instance_valid(ocean):
		ocean.free()
	await process_frame
	await _verify_hud_dual_resolution()
	print("PASS: art regression (landmark collisions, visual builders & pivots, material/animation isolation, 1280x800 & 1920x1080 UI)")
	quit(0)

func _count_valid_concave_faces(node: Node) -> int:
	var total_faces := 0
	var bodies := node.find_children("*", "StaticBody3D", true, false)
	if node is StaticBody3D:
		bodies.push_front(node)
	for body_node in bodies:
		var body := body_node as StaticBody3D
		var shapes := body.find_children("*", "CollisionShape3D", true, false)
		for shape_node in shapes:
			var col := shape_node as CollisionShape3D
			if col.shape is ConcavePolygonShape3D:
				var faces: PackedVector3Array = (col.shape as ConcavePolygonShape3D).get_faces()
				assert(faces.size() >= 3 and faces.size() % 3 == 0, "Invalid ConcavePolygonShape3D face array")
				total_faces += faces.size() / 3
	return total_faces

func _verify_landmark_collisions() -> Node3D:
	for asset_id: String in ["ruins", "shipwreck"]:
		var path := "res://assets/collision/" + asset_id + ".tscn"
		var packed: PackedScene = load(path)
		assert(packed != null, path + ": failed to load frozen collision scene")
		var coll_root: Node3D = packed.instantiate()
		assert(coll_root != null, path + ": failed to instantiate frozen collision scene")
		var bodies := coll_root.find_children("*", "StaticBody3D", true, false)
		assert(not bodies.is_empty(), path + ": missing StaticBody3D nodes")
		var face_count := _count_valid_concave_faces(coll_root)
		assert(face_count > 0, path + ": missing valid ConcavePolygonShape3D faces")
		coll_root.free()

	var ocean: Node3D = Ocean.new()
	root.add_child(ocean)
	ocean.set_process(false)

	var ruins_attached := 0
	var shipwreck_attached := 0
	var core_ruins_found := false
	var core_wreck_found := false
	for child in ocean.get_children():
		if not (child is Node3D):
			continue
		var n3 := child as Node3D
		var visual_asset := String(n3.get_meta("visual_asset", ""))
		if visual_asset == "ruins":
			var faces := _count_valid_concave_faces(n3)
			if faces > 0:
				ruins_attached += 1
				if Vector2(n3.position.x, n3.position.z).distance_to(Vector2(2.0, -25.0)) < 6.0:
					core_ruins_found = true
		elif visual_asset == "shipwreck":
			var faces := _count_valid_concave_faces(n3)
			if faces > 0:
				shipwreck_attached += 1
				if Vector2(n3.position.x, n3.position.z).distance_to(Vector2(45.0, -55.0)) < 6.0:
					core_wreck_found = true

	assert(ruins_attached >= 3 and core_ruins_found, "Ocean must attach frozen ruins.tscn collisions onto landmark ruins")
	assert(shipwreck_attached >= 1 and core_wreck_found, "Ocean must attach frozen shipwreck.tscn collision onto landmark shipwreck")
	return ocean

func _verify_visual_builders() -> void:
	# 1. Diver visual rig, weapons, sockets, booster, shield, and lamp
	var diver: CharacterBody3D = Diver.new()
	root.add_child(diver)
	diver.set_process(false)
	diver.set_physics_process(false)

	assert(is_instance_valid(diver.diver_model), "Diver third-person model missing")
	assert(is_instance_valid(diver.equipment_rig), "Diver equipment rig missing")
	var diver_finished: bool = bool(diver.get_meta("art_finished", false)) or (
		bool(diver.diver_model.get_meta("art_finished", false)) and bool(diver.equipment_rig.get_meta("art_finished", false))
	)
	assert(diver_finished, "Diver visual roots must have art_finished == true")

	assert(is_instance_valid(diver.weapon_mount), "Diver weapon_mount missing")
	for weapon_id: String in ["knife", "axe", "sonic", "marker_gun"]:
		assert(diver.weapon_nodes.has(weapon_id) and is_instance_valid(diver.weapon_nodes[weapon_id]), "Diver weapon node missing: " + weapon_id)
	assert(is_instance_valid(diver.gun_muzzle), "Diver sonic gun_muzzle missing")

	for socket_or_pivot in [
		diver.body_pivot,
		diver.head_pivot,
		diver.left_arm_pivot,
		diver.right_arm_pivot,
		diver.left_forearm_pivot,
		diver.right_forearm_pivot,
		diver.left_hand_socket,
		diver.right_hand_socket,
		diver.left_leg_pivot,
		diver.right_leg_pivot,
	]:
		assert(is_instance_valid(socket_or_pivot), "Diver limb pivot or hand socket missing")

	assert(is_instance_valid(diver.booster_node), "Diver handheld booster missing")
	assert(is_instance_valid(diver.shield_mount) and is_instance_valid(diver.shield_node), "Diver energy shield missing")
	assert(is_instance_valid(diver.lamp) and diver.lamp is SpotLight3D and diver.lamp.shadow_enabled, "Diver shadowed SpotLight3D lamp missing")
	assert(is_instance_valid(diver.lamp_fill), "Diver fill light missing")
	diver.lamp.visible = true
	diver.lamp_fill.visible = true
	diver.set_submarine_mode(true, "scout")
	assert(not diver.lamp.visible and not diver.lamp_fill.visible, "Diver lamp must turn off while piloting a submarine to preserve <= 1 shadow light")
	diver.set_submarine_mode(false)
	assert(diver.lamp.visible and diver.lamp_fill.visible, "Diver lamp must restore previous state upon disembarking submarine")
	diver.free()

	# 2. Submarines ("scout", "titan", "mini")
	for sub_type: String in ["scout", "titan", "mini"]:
		var sub: CharacterBody3D = Submarine.new()
		root.add_child(sub)
		sub.configure(sub_type)
		sub.set_process(false)
		sub.set_physics_process(false)

		assert(bool(sub.get_meta("art_finished", false)) == true, sub_type + ": submarine art_finished must be true")
		assert(not sub.headlights.is_empty(), sub_type + ": submarine headlights missing")
		var shadow_headlights := 0
		for light: Light3D in sub.headlights:
			assert(is_instance_valid(light), sub_type + ": invalid headlight reference")
			if light.shadow_enabled:
				shadow_headlights += 1
		assert(shadow_headlights <= 1, sub_type + ": submarine must have at most 1 shadow-casting headlight")
		assert(is_instance_valid(sub.cockpit_seat), sub_type + ": cockpit_seat missing")
		assert(not sub.propellers.is_empty(), sub_type + ": propellers missing")
		assert(not sub.muzzles.is_empty(), sub_type + ": weapon muzzles missing")
		sub.free()

	# 3. Procedural MarineCreature species
	var species_list := [
		"water_dragon",
		"flying_fish",
		"kraken",
		"colossus_turtle",
		"sea_wolf",
		"seal",
		"sea_spider",
		"school_fish",
	]
	for kind: String in species_list:
		var creature: Node3D = MarineCreature.new()
		creature.configure(kind)
		root.add_child(creature)
		assert(bool(creature.get_meta("art_finished", false)) == true, kind + ": creature art_finished must be true")
		assert(not creature.limbs.is_empty(), kind + ": creature fin/tentacle/leg pivots missing")
		for limb in creature.limbs:
			assert(is_instance_valid(limb), kind + ": invalid limb pivot")
		if kind in ["kraken", "sea_spider"]:
			assert(creature.limbs.size() == 8, kind + ": expected 8 articulated tentacle/leg pivots")
		else:
			assert(not creature.tail.is_empty(), kind + ": swimming creature tail pivots missing")
			for seg in creature.tail:
				assert(is_instance_valid(seg), kind + ": invalid tail pivot")
		creature.animate(0.16)
		creature.free()

func _collect_standard_materials(node: Node) -> Array[StandardMaterial3D]:
	var materials: Array[StandardMaterial3D] = []
	var seen: Dictionary = {}
	var meshes := node.find_children("*", "MeshInstance3D", true, false)
	for m in meshes:
		var mi := m as MeshInstance3D
		if mi.material_override is StandardMaterial3D:
			var mat := mi.material_override as StandardMaterial3D
			if not seen.has(mat.get_instance_id()):
				seen[mat.get_instance_id()] = true
				materials.append(mat)
		if mi.mesh != null:
			for s_idx in range(mi.mesh.get_surface_count()):
				var s_mat := mi.get_surface_override_material(s_idx)
				if s_mat == null:
					s_mat = mi.mesh.surface_get_material(s_idx)
				if s_mat is StandardMaterial3D:
					var std := s_mat as StandardMaterial3D
					if not seen.has(std.get_instance_id()):
						seen[std.get_instance_id()] = true
						materials.append(std)
	return materials

func _verify_animation_and_material_isolation(ocean: Node3D) -> void:
	# 1. Material isolation across separate MarineCreature instances
	for kind: String in ["water_dragon", "sea_wolf"]:
		var inst_a: Node3D = MarineCreature.new()
		inst_a.configure(kind)
		root.add_child(inst_a)

		var inst_b: Node3D = MarineCreature.new()
		inst_b.configure(kind)
		root.add_child(inst_b)

		var mats_a := _collect_standard_materials(inst_a)
		var mats_b := _collect_standard_materials(inst_b)
		assert(not mats_a.is_empty() and not mats_b.is_empty(), kind + ": missing StandardMaterial3D instances")

		var ids_a: Dictionary = {}
		for mat_a in mats_a:
			ids_a[mat_a.get_instance_id()] = true
		for mat_b in mats_b:
			assert(not ids_a.has(mat_b.get_instance_id()), kind + ": StandardMaterial3D shared across separate creature instances")

		var b_initial_albedo: Color = mats_b[0].albedo_color
		inst_a.set_meta("enraged", false)
		inst_b.set_meta("enraged", false)
		inst_a.animate(0.1)
		inst_b.animate(0.1)
		var b_calm_emission: Color = inst_b.glow_material.emission

		# Simulate rage + stasis tint on instance A only
		inst_a.set_meta("enraged", true)
		inst_a.animate(0.1)
		inst_b.animate(0.1)
		mats_a[0].albedo_color = Color(0.12, 0.45, 0.98)

		assert(not inst_a.glow_material.emission.is_equal_approx(inst_b.glow_material.emission), kind + ": rage emission did not isolate to instance A")
		assert(inst_b.glow_material.emission.is_equal_approx(b_calm_emission), kind + ": instance B emission mutated when instance A enraged")
		assert(mats_b[0].albedo_color.is_equal_approx(b_initial_albedo), kind + ": instance B albedo mutated when instance A tinted")

		inst_a.free()
		inst_b.free()

	# 2. GLB creature AnimationPlayer speed_scale = 0.0 clean freeze check
	var glb_packed: PackedScene = load("res://assets/models/fish_predator.glb")
	assert(glb_packed != null, "Failed to load fish_predator.glb")
	var glb_creature: Node3D = glb_packed.instantiate()
	root.add_child(glb_creature)
	var players := glb_creature.find_children("*", "AnimationPlayer", true, false)
	var skeletons := glb_creature.find_children("*", "Skeleton3D", true, false)
	assert(players.size() == 1 and skeletons.size() == 1, "GLB creature must contain AnimationPlayer and Skeleton3D")
	var player := players[0] as AnimationPlayer
	var skeleton := skeletons[0] as Skeleton3D
	assert(player.has_animation("swim"), "fish_predator.glb missing swim animation")
	player.get_animation("swim").loop_mode = Animation.LOOP_LINEAR
	player.speed_scale = 1.0
	player.play("swim")
	player.advance(0.18)
	await process_frame

	# Freeze via speed_scale = 0.0
	player.speed_scale = 0.0
	var frozen_pos: float = player.current_animation_position
	var frozen_poses: Array[Transform3D] = []
	for bone_idx in range(skeleton.get_bone_count()):
		frozen_poses.append(skeleton.get_bone_pose(bone_idx))

	for _step in range(5):
		await process_frame

	assert(player.is_playing(), "AnimationPlayer with speed_scale = 0.0 should stay in clean paused playback state")
	assert(is_equal_approx(player.current_animation_position, frozen_pos), "AnimationPlayer advanced while speed_scale == 0.0")
	for bone_idx in range(skeleton.get_bone_count()):
		assert(skeleton.get_bone_pose(bone_idx).is_equal_approx(frozen_poses[bone_idx]), "Skeleton bone pose drifted while speed_scale == 0.0")

	# Verify clean resume after unfreezing
	player.speed_scale = 1.0
	player.advance(0.15)
	var resumed_moved := false
	for bone_idx in range(skeleton.get_bone_count()):
		if not skeleton.get_bone_pose(bone_idx).is_equal_approx(frozen_poses[bone_idx]):
			resumed_moved = true
			break
	assert(resumed_moved, "GLB creature skeleton failed to resume deformation after speed_scale restored to 1.0")
	glb_creature.free()

	# Also verify Ocean stasis freeze pauses live GLB predator AnimationPlayer
	if is_instance_valid(ocean) and not ocean.predators.is_empty():
		var pred: Node3D = ocean.predators[0]
		ocean.last_diver_pos = pred.global_position
		ocean._update_creature_animation(pred)
		var pred_player: AnimationPlayer = pred.get_meta("animation_player", null)
		if is_instance_valid(pred_player):
			assert(pred_player.is_playing(), "Predator AnimationPlayer should play within observer range")
			var frozen_cnt: int = ocean.freeze_creatures(pred.global_position, 8.0, 3.0)
			assert(frozen_cnt >= 1, "Ocean.freeze_creatures should freeze target predator")
			assert(not pred_player.is_playing(), "Ocean.freeze_creatures should pause predator AnimationPlayer")

func _is_top_level_panel(panel: Panel, hud_root: Control) -> bool:
	var cur := panel.get_parent()
	while cur != null and cur != hud_root:
		if cur is Panel:
			return false
		cur = cur.get_parent()
	return true

func _assert_within_viewport(ctrl: Control, vp_size: Vector2, context: String) -> void:
	var rect := ctrl.get_global_rect()
	assert(rect.size.x > 0.0 and rect.size.y > 0.0, "%s: zero-sized control %s (%s)" % [context, ctrl.name, rect])
	assert(
		rect.position.x >= -UI_TOLERANCE_PX
		and rect.position.y >= -UI_TOLERANCE_PX
		and rect.end.x <= vp_size.x + UI_TOLERANCE_PX
		and rect.end.y <= vp_size.y + UI_TOLERANCE_PX,
		"%s: control '%s' (%s) exceeds viewport %s" % [context, ctrl.name, rect, vp_size]
	)

func _verify_hud_dual_resolution() -> void:
	var vp := SubViewport.new()
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.size = Vector2i(1280, 800)
	root.add_child(vp)

	var hud := HUD.new()
	vp.add_child(hud)
	await process_frame

	hud.update_hud({
		"mode": "survival",
		"oxygen": 82.0,
		"max_oxygen": 150.0,
		"health": 95.0,
		"depth": 48.0,
		"biome": "阳光浅礁带",
		"distance_home": 36.0,
		"exploration_progress": 0.42,
		"explorer_rank": "深海勘测员",
		"landmarks_count": 10,
		"landmarks_total": 24,
		"outposts_unlocked_count": 3,
		"outposts_total": 6,
		"relics_collected_count": 5,
		"relics_total": 12,
		"inventory": {"titanium": 4, "copper": 2, "quartz": 2, "kelp": 3, "fish_small": 2},
		"weapons": ["knife", "axe", "sonic"],
		"current_weapon": "sonic",
		"tamed_beasts": [
			{"name": "斑纹礁海豹", "health": 420.0, "deployed": true},
			{"name": "幽影海狼", "health": 560.0, "deployed": false},
		],
		"deployed_beast_count": 1,
	})

	var resolutions := [Vector2i(1280, 800), Vector2i(1920, 1080)]
	var screens := ["main", "hud", "play", "pause", "craft", "sushi", "mount_board", "map", "win"]

	for res: Vector2i in resolutions:
		vp.size = res
		hud.root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		hud.root.size = Vector2(res)
		await process_frame
		await process_frame

		var vp_size := Vector2(res)
		assert(hud.root.size.is_equal_approx(vp_size), "HUD root size %s did not match %s" % [hud.root.size, vp_size])

		for screen: String in screens:
			hud.set_screen(screen)
			# HUD uses "play" internally for live flight instruments; alias "hud" to also verify FlightInstruments
			if screen == "hud" and not hud.menus.has("hud") and not hud.instruments.visible:
				hud.set_screen("play")
			await process_frame

			var ctx := "%dx%d [%s]" % [res.x, res.y, screen]
			var panels := hud.root.find_children("*", "Panel", true, false)
			var visible_panels := 0
			for p_node in panels:
				var panel := p_node as Panel
				if not panel.is_visible_in_tree():
					continue
				if _is_top_level_panel(panel, hud.root):
					visible_panels += 1
					_assert_within_viewport(panel, vp_size, ctx)

			var buttons := hud.root.find_children("*", "Button", true, false)
			var buttons_by_parent: Dictionary = {}
			var visible_buttons: Array[Button] = []
			for b_node in buttons:
				var btn := b_node as Button
				if not btn.is_visible_in_tree():
					continue
				_assert_within_viewport(btn, vp_size, ctx)
				visible_buttons.append(btn)
				var parent_id := btn.get_parent().get_instance_id()
				if not buttons_by_parent.has(parent_id):
					buttons_by_parent[parent_id] = []
				buttons_by_parent[parent_id].append(btn)

			if screen != "hud" and screen != "play":
				assert(not visible_buttons.is_empty(), ctx + ": expected visible interactive buttons on menu screen")
			else:
				assert(visible_panels > 0, ctx + ": expected visible HUD instrument panels")

			for parent_id in buttons_by_parent:
				var siblings: Array = buttons_by_parent[parent_id]
				for i in range(siblings.size()):
					var btn_a: Button = siblings[i]
					var rect_a := btn_a.get_global_rect().grow(-0.5)
					for j in range(i + 1, siblings.size()):
						var btn_b: Button = siblings[j]
						var rect_b := btn_b.get_global_rect().grow(-0.5)
						assert(
							not rect_a.intersects(rect_b),
							"%s: sibling buttons overlap: '%s' (%s) vs '%s' (%s)" % [
								ctx, btn_a.text, btn_a.get_global_rect(), btn_b.text, btn_b.get_global_rect()
							]
						)

	vp.free()
	await process_frame
