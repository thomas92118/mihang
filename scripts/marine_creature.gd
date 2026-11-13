extends Node3D

const ModelFinish = preload("res://scripts/presentation/model_finish.gd")
const BlenderArt = preload("res://scripts/presentation/blender_art.gd")

var species := ""
var animation_clock := 0.0
var limbs: Array[Node3D] = []
var tail: Array[Node3D] = []
var glow_material: StandardMaterial3D

func configure(kind: String) -> void:
	species = kind
	set_meta("kind", kind)
	match kind:
		"sea_spider":
			_build_spider()
		"seal":
			_build_seal()
		"water_dragon":
			_build_dragon()
		"flying_fish":
			_build_flying_fish()
		"kraken":
			_build_kraken()
		"colossus_turtle":
			_build_colossus_turtle()
		"sea_wolf":
			_build_sea_wolf()
		"school_fish":
			_build_school_fish()
	ModelFinish.apply(self, kind)

func animate(delta: float) -> void:
	animation_clock += delta
	var enraged := bool(get_meta("enraged", false))
	match species:
		"sea_spider":
			for i in range(limbs.size()):
				var base_yaw: float = float(limbs[i].get_meta("base_yaw", 0.0))
				limbs[i].rotation.y = base_yaw + sin(animation_clock * 5.0 + i * PI * 0.8) * 0.18
				limbs[i].rotation.z = sin(animation_clock * 5.0 + i * PI) * 0.12
			if glow_material:
				glow_material.emission = Color(1.0, 0.22, 0.08) if enraged else Color(0.85, 0.48, 0.16)
		"seal":
			for i in range(limbs.size()):
				limbs[i].rotation.z = sin(animation_clock * 2.8 + i * PI) * 0.28
			for part in tail:
				part.rotation.y = sin(animation_clock * 3.1) * 0.22
				part.rotation.x = cos(animation_clock * 2.8) * 0.12
			if glow_material:
				glow_material.emission = Color(1.0, 0.30, 0.12) if enraged else Color(0.75, 0.88, 0.96)
		"water_dragon":
			for i in range(tail.size()):
				var rest: Vector3 = tail[i].get_meta("rest")
				tail[i].position = rest + Vector3(sin(animation_clock * 2.0 - i * 0.5) * (0.1 + i * 0.1), cos(animation_clock * 1.3 - i * 0.3) * 0.12, 0)
				tail[i].rotation.y = cos(animation_clock * 2.0 - i * 0.5) * 0.18
			for i in range(limbs.size()):
				limbs[i].rotation.z = sin(animation_clock * 1.8 + i * PI * 0.5) * 0.22
			if glow_material:
				glow_material.emission = Color(1.0, 0.25, 0.12) if enraged else Color(0.92, 0.72, 0.24)
		"flying_fish":
			for i in range(limbs.size()):
				limbs[i].rotation.z = sin(animation_clock * 7.5 + i * PI) * 0.34
				limbs[i].rotation.y = cos(animation_clock * 4.0) * 0.14
			for part in tail:
				part.rotation.y = sin(animation_clock * 8.5) * 0.35
			if glow_material:
				glow_material.emission = Color(1.0, 0.35, 0.1) if enraged else Color(0.32, 0.82, 1.0)
		"kraken":
			for i in range(limbs.size()):
				var t: float = animation_clock * 2.8 + i * 0.75
				var base_yaw: float = float(limbs[i].get_meta("base_yaw", 0.0))
				limbs[i].rotation.y = base_yaw + cos(t * 0.6) * 0.14
				limbs[i].rotation.x = sin(t) * 0.28
				limbs[i].rotation.z = cos(t * 0.7) * 0.20
			if glow_material:
				glow_material.emission = Color(1.0, 0.2, 0.08) if enraged else Color(0.95, 0.68, 0.18)
		"colossus_turtle":
			for i in range(limbs.size()):
				limbs[i].rotation.z = sin(animation_clock * 1.8 + i * PI * 0.5) * 0.28
			for part in tail:
				part.rotation.y = sin(animation_clock * 1.5) * 0.18
			if glow_material:
				glow_material.emission = Color(1.0, 0.3, 0.1) if enraged else Color(0.38, 0.92, 0.62)
		"sea_wolf":
			for i in range(limbs.size()):
				limbs[i].rotation.z = sin(animation_clock * 4.2 + i * PI * 0.7) * 0.28
				limbs[i].rotation.x = cos(animation_clock * 4.2 + i * PI * 0.5) * 0.16
			for part in tail:
				part.rotation.x = sin(animation_clock * 5.5) * 0.28
				part.rotation.y = cos(animation_clock * 2.75) * 0.10
			if glow_material:
				glow_material.emission = Color(1.0, 0.38, 0.08) if enraged else Color(0.94, 0.70, 0.20)
		"school_fish":
			for part in tail:
				part.rotation.y = sin(animation_clock * 11.0) * 0.45
			for i in range(limbs.size()):
				limbs[i].rotation.z = sin(animation_clock * 8.0 + i * PI) * 0.35
			if glow_material:
				glow_material.emission = Color(1.0, 0.45, 0.15) if enraged else Color(0.92, 0.76, 0.34)

func set_limp_corpse() -> void:
	set_meta("dead", true)
	set_meta("can_loot", true)
	set_meta("looted", false)
	rotation.z = lerpf(0.7, 1.15, (randi() % 2) * 2 - 1)
	rotation.x = randf_range(-0.25, 0.25)
	for limb in limbs:
		if is_instance_valid(limb):
			limb.rotation.z = clampf(limb.rotation.z + 0.45, -1.2, 1.2)

func set_tamed(is_tamed: bool = true) -> void:
	set_meta("tamed", is_tamed)
	if has_node("StasisAura"):
		get_node("StasisAura").queue_free()
	var crest := get_node_or_null("TameCrest")
	if is_tamed:
		if crest == null:
			var ring := MeshInstance3D.new()
			ring.name = "TameCrest"
			var tor := TorusMesh.new()
			tor.inner_radius = 1.1
			tor.outer_radius = 1.25
			ring.mesh = tor
			ring.material_override = _material(Color(0.2, 0.95, 1.0), 0.15, true)
			ring.position = Vector3(0, 1.6, 0)
			ring.rotation.x = PI * 0.5
			add_child(ring)
	else:
		if crest != null:
			crest.queue_free()

func _build_spider() -> void:
	name = "SeaSpider"
	set_meta("name", "深海长足海蜘蛛")
	if BlenderArt.mesh("creature_sea_spider_shell") != null:
		var mats := BlenderArt.create_creature_materials(Color(0.85, 0.48, 0.16), Color(0.68, 0.25, 0.18))
		glow_material = mats["glow"]
		BlenderArt.attach_part(self, "SpinyCarapace", "creature_sea_spider_shell", mats)
		for side: float in [-1.0, 1.0]:
			var leg_key := "creature_sea_spider_leg_r" if side > 0.0 else "creature_sea_spider_leg_l"
			for row: int in range(4):
				var pivot := Node3D.new()
				pivot.name = "SpiderLeg_%s_%d" % ["R" if side > 0.0 else "L", row]
				pivot.position = Vector3(side * 0.52, 0.88, -0.48 + row * 0.32)
				var yaw: float = -side * (-0.54 + row * 0.36)
				pivot.rotation.y = yaw
				pivot.set_meta("base_yaw", yaw)
				add_child(pivot)
				BlenderArt.attach_part(pivot, "BandedLeg", leg_key, mats)
				limbs.append(pivot)
		return
	var shell := _material(Color(0.76, 0.20, 0.36), 0.25)
	var joints := _material(Color(1.0, 0.56, 0.18), 0.35)
	var eyes := _material(Color(0.22, 0.96, 1.0), 0.15, true)
	_ellipsoid("Armored abdomen", Vector3(0, 0.95, -0.15), Vector3(1.15, 0.7, 1.45), shell)
	_ellipsoid("Head", Vector3(0, 0.86, 0.75), Vector3(0.6, 0.48, 0.65), joints)
	for side in [-1.0, 1.0]:
		for row in range(4):
			var pivot := Node3D.new()
			pivot.position = Vector3(side * 0.42, 0.85, -0.72 + row * 0.42)
			add_child(pivot)
			var knee := Vector3(side * 1.2, 0.38, (row - 1.5) * 0.35)
			var foot := Vector3(side * 1.8, -0.8, (row - 1.5) * 0.65)
			_tube(Vector3.ZERO, knee, 0.075, shell, pivot)
			_tube(knee, foot, 0.045, joints, pivot)
			_ellipsoid("Leg joint", knee, Vector3.ONE * 0.18, joints, pivot)
			limbs.append(pivot)
		_ellipsoid("Blue eye", Vector3(side * 0.17, 1.04, 1.01), Vector3.ONE * 0.11, eyes)
		_tube(Vector3(side * 0.13, 0.85, 0.95), Vector3(side * 0.3, 0.72, 1.25), 0.06, joints)

func _build_seal() -> void:
	name = "ReefSeal"
	set_meta("name", "斑纹礁海豹")
	if BlenderArt.mesh("creature_seal_head") != null and BlenderArt.mesh("creature_seal_flipper_r") != null:
		var mats := BlenderArt.create_creature_materials(Color(0.75, 0.88, 0.96), Color(0.45, 0.53, 0.60))
		glow_material = mats["glow"]
		BlenderArt.attach_part(self, "DappledBody", "creature_seal_body", mats)
		BlenderArt.attach_part(self, "SealHead", "creature_seal_head", mats, Vector3(0.0, 0.22, 1.42))
		for side in [-1.0, 1.0]:
			var flipper := Node3D.new()
			flipper.name = "ForeFlipper_" + ("R" if side > 0.0 else "L")
			flipper.position = Vector3(side * 0.56, -0.24, 0.54)
			add_child(flipper)
			var f_key := "creature_seal_flipper_r" if side > 0.0 else "creature_seal_flipper_l"
			BlenderArt.attach_part(flipper, "ForePaddle", f_key, mats)
			limbs.append(flipper)
			var hind := Node3D.new()
			hind.name = "HindFlipper_" + ("R" if side > 0.0 else "L")
			hind.position = Vector3(side * 0.16, -0.06, -1.66)
			add_child(hind)
			var h_key := "creature_seal_hind_r" if side > 0.0 else "creature_seal_hind_l"
			BlenderArt.attach_part(hind, "WebbedHind", h_key, mats)
			tail.append(hind)
		return
	var skin := _material(Color(0.34, 0.64, 0.86), 0.08)
	var belly := _material(Color(0.92, 0.97, 1.0))
	var dark := _material(Color(0.08, 0.14, 0.24))
	_ellipsoid("Streamlined body", Vector3.ZERO, Vector3(1.6, 1.35, 3.5), skin)
	_ellipsoid("Pale belly", Vector3(0, -0.3, 0.3), Vector3(1.25, 0.9, 2.65), belly)
	_ellipsoid("Rounded head", Vector3(0, 0.2, 1.7), Vector3(1.08, 1.08, 1.2), skin)
	_ellipsoid("Muzzle", Vector3(0, 0.01, 2.2), Vector3(0.72, 0.46, 0.5), belly)
	_ellipsoid("Nose", Vector3(0, 0.14, 2.44), Vector3(0.2, 0.13, 0.14), dark)
	for side in [-1.0, 1.0]:
		_ellipsoid("Eye", Vector3(side * 0.39, 0.42, 2.07), Vector3.ONE * 0.15, dark)
		var flipper := Node3D.new()
		flipper.position = Vector3(side * 0.56, -0.25, 0.52)
		add_child(flipper)
		var paddle := _ellipsoid("Front flipper", Vector3(side * 0.6, 0, -0.26), Vector3(1.6, 0.18, 0.75), skin, flipper)
		paddle.rotation.y = side * 0.45
		limbs.append(flipper)
		var fin := _ellipsoid("Tail flipper", Vector3(side * 0.38, -0.08, -1.8), Vector3(0.9, 0.18, 0.95), skin)
		tail.append(fin)
		for whisker in range(3):
			_tube(Vector3(side * 0.22, -0.03, 2.37), Vector3(side * 0.75, 0.1 - whisker * 0.13, 2.54), 0.012, belly)
		for spot in range(7):
			_ellipsoid("Coat spot", Vector3(side * 0.66, 0.37, -1.15 + spot * 0.35), Vector3(0.17, 0.1, 0.22), dark)

func _build_dragon() -> void:
	name = "AbyssalWaterDragon"
	set_meta("name", "深渊水龙 · 潮汐君主")
	if BlenderArt.mesh("creature_water_dragon_pectoral_r") != null:
		var mats := BlenderArt.create_creature_materials(Color(0.92, 0.72, 0.24), Color(0.18, 0.38, 0.72))
		glow_material = mats["glow"]
		for i in range(14):
			var segment := Node3D.new()
			segment.name = "DragonSegment_%d" % i
			segment.position = Vector3(0.0, 0.0, 3.3 - i * 0.95)
			segment.set_meta("rest", segment.position)
			add_child(segment)
			var taper := maxf(0.28, 1.24 - i * 0.072)
			BlenderArt.attach_part(segment, "ScaledSpineSegment", "creature_water_dragon_segment", mats, Vector3.ZERO, Vector3.ZERO, Vector3(taper, taper, 0.88))
			if i == 13:
				BlenderArt.attach_part(segment, "RibbonCaudalFin", "creature_water_dragon_caudal", mats, Vector3(0.0, 0.0, -0.52))
			tail.append(segment)
		BlenderArt.attach_part(self, "HornedDragonHead", "creature_water_dragon_head", mats, Vector3(0.0, 0.20, 4.35))
		for side in [-1.0, 1.0]:
			var pec_root := Node3D.new()
			pec_root.name = "PectoralWing_" + ("R" if side > 0.0 else "L")
			pec_root.position = Vector3(side * 0.95, -0.14, 2.05)
			add_child(pec_root)
			var pec_key := "creature_water_dragon_pectoral_r" if side > 0.0 else "creature_water_dragon_pectoral_l"
			BlenderArt.attach_part(pec_root, "PleatedPectoralFin", pec_key, mats)
			limbs.append(pec_root)
			var pel_root := Node3D.new()
			pel_root.name = "PelvicWing_" + ("R" if side > 0.0 else "L")
			pel_root.position = Vector3(side * 0.62, -0.18, -1.65)
			add_child(pel_root)
			var pel_key := "creature_water_dragon_pelvic_r" if side > 0.0 else "creature_water_dragon_pelvic_l"
			BlenderArt.attach_part(pel_root, "PleatedPelvicFin", pel_key, mats)
			limbs.append(pel_root)
		var d_light := OmniLight3D.new()
		d_light.position = Vector3(0.0, 1.2, 3.0)
		d_light.light_color = Color(0.28, 0.64, 1.0)
		d_light.light_energy = 3.2
		d_light.omni_range = 18.0
		add_child(d_light)
		return
	var scales := _material(Color(0.10, 0.42, 0.78), 0.35)
	var pale := _material(Color(0.45, 0.88, 0.98), 0.25)
	var horns := _material(Color(1.0, 0.78, 0.24), 0.45)
	glow_material = _material(Color(0.22, 0.92, 1.0), 0.15, true)
	for i in range(14):
		var segment := Node3D.new()
		segment.position = Vector3(0, 0, 3.3 - i * 0.95)
		segment.set_meta("rest", segment.position)
		add_child(segment)
		var thickness := maxf(0.28, 2.45 - i * 0.15)
		_ellipsoid("Overlapping scale segment", Vector3.ZERO, Vector3(thickness, thickness * 0.74, 1.65), scales, segment)
		_ellipsoid("Luminous belly scales", Vector3(0, -thickness * 0.23, 0.04), Vector3(thickness * 0.76, thickness * 0.35, 1.6), pale, segment)
		_spike(Vector3(0, thickness * 0.38, -0.1), 0.16, 0.7 + thickness * 0.18, horns, segment)
		for side in [-1.0, 1.0]:
			_ellipsoid("Bioluminescent scale", Vector3(side * thickness * 0.46, 0.12, 0.15), Vector3(0.13, 0.18, 0.7), glow_material, segment)
		tail.append(segment)
	_ellipsoid("Dragon head", Vector3(0, 0.25, 4.55), Vector3(2.5, 1.8, 2.8), scales)
	_ellipsoid("Long armored snout", Vector3(0, -0.02, 6.04), Vector3(1.6, 0.8, 1.7), pale)
	_ellipsoid("Lower jaw", Vector3(0, -0.47, 5.72), Vector3(1.5, 0.3, 2.1), scales)
	for side in [-1.0, 1.0]:
		_ellipsoid("Dragon eye", Vector3(side * 1.04, 0.58, 5.22), Vector3(0.25, 0.25, 0.48), glow_material)
		var horn := _spike(Vector3(side * 0.78, 1.25, 4.05), 0.28, 2.0, horns)
		horn.rotation.z = -side * 0.4
		horn.rotation.x = -0.65
		for tooth in range(5):
			var fang := _spike(Vector3(side * 0.65, -0.26, 5.25 + tooth * 0.32), 0.08, 0.32, horns)
			fang.rotation.z = PI
		var fin_root := Node3D.new()
		fin_root.position = Vector3(side * 1.0, -0.1, 2.0)
		add_child(fin_root)
		var fin := _ellipsoid("Sweeping dragon fin", Vector3(side * 1.7, 0, -1), Vector3(4.7, 0.2, 2.0), pale, fin_root)
		fin.rotation.y = side * 0.4
		_tube(Vector3.ZERO, Vector3(side * 3.6, 0, -1.7), 0.08, glow_material, fin_root)
		limbs.append(fin_root)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 1, 3)
	light.light_color = Color(0.08, 0.5, 1.0)
	light.light_energy = 4.5
	light.omni_range = 18.0
	add_child(light)

func _build_flying_fish() -> void:
	name = "StormFlyingFish"
	set_meta("name", "风暴飞鱼 · 空棘龙皇")
	if BlenderArt.mesh("creature_flying_fish_wing_r") != null:
		var mats := BlenderArt.create_creature_materials(Color(0.32, 0.82, 1.0), Color(0.24, 0.52, 0.84))
		glow_material = mats["glow"]
		BlenderArt.attach_part(self, "PelagicFuselage", "creature_flying_fish_body", mats)
		for side in [-1.0, 1.0]:
			var wing_root := Node3D.new()
			wing_root.name = "GlidingWing_" + ("R" if side > 0.0 else "L")
			wing_root.position = Vector3(side * 0.96, 0.24, 1.35)
			add_child(wing_root)
			var w_key := "creature_flying_fish_wing_r" if side > 0.0 else "creature_flying_fish_wing_l"
			BlenderArt.attach_part(wing_root, "RayedPectoralWing", w_key, mats)
			limbs.append(wing_root)
			var pel_root := Node3D.new()
			pel_root.name = "PelvicWing_" + ("R" if side > 0.0 else "L")
			pel_root.position = Vector3(side * 0.62, -0.46, -1.15)
			add_child(pel_root)
			var p_key := "creature_flying_fish_pelvic_r" if side > 0.0 else "creature_flying_fish_pelvic_l"
			BlenderArt.attach_part(pel_root, "RayedPelvicFin", p_key, mats)
			limbs.append(pel_root)
		var tail_pivot := Node3D.new()
		tail_pivot.name = "HypocercalTailPivot"
		tail_pivot.position = Vector3(0.0, 0.0, -4.35)
		add_child(tail_pivot)
		BlenderArt.attach_part(tail_pivot, "HypocercalCaudal", "creature_flying_fish_caudal", mats)
		tail.append(tail_pivot)
		var ff_light := OmniLight3D.new()
		ff_light.position = Vector3(0.0, 0.6, 1.0)
		ff_light.light_color = Color(0.38, 0.82, 1.0)
		ff_light.light_energy = 3.4
		ff_light.omni_range = 24.0
		add_child(ff_light)
		return
	var scales := _material(Color(0.14, 0.54, 0.92), 0.35)
	var wings := _material(Color(0.24, 0.95, 1.0), 0.25, true)
	var belly := _material(Color(0.95, 0.98, 1.0), 0.12)
	var fins_mat := _material(Color(1.0, 0.62, 0.18), 0.35)
	glow_material = wings

	# Streamlined Hydrodynamic Body
	_ellipsoid("FishFuselage", Vector3.ZERO, Vector3(2.4, 2.0, 8.5), scales)
	_ellipsoid("FishBelly", Vector3(0, -0.4, 0.2), Vector3(1.8, 1.1, 7.2), belly)
	_ellipsoid("StreamlinedHead", Vector3(0, 0.1, 4.6), Vector3(2.1, 1.8, 2.8), scales)
	_spike(Vector3(0, 0.05, 6.2), 0.35, 1.6, fins_mat)

	# Massive Iridescent Wing Gliding Fins (左右巨大飞跃滑翔翼鳍)
	for side in [-1.0, 1.0]:
		var wing_root := Node3D.new()
		wing_root.position = Vector3(side * 1.1, 0.3, 1.2)
		add_child(wing_root)
		var wing := _ellipsoid("WingFin", Vector3(side * 3.5, 0, -0.5), Vector3(6.5, 0.15, 2.8), wings, wing_root)
		wing.rotation.y = -side * 0.25
		_tube(Vector3.ZERO, Vector3(side * 5.8, 0, -1.2), 0.11, glow_material, wing_root)
		limbs.append(wing_root)

		# Eye
		_ellipsoid("Eye", Vector3(side * 0.92, 0.45, 4.8), Vector3.ONE * 0.28, glow_material)

	# Dorsal Spines & Caudal Tail
	for i in range(5):
		var spine := _spike(Vector3(0, 1.1 + i * 0.08, 2.2 - i * 0.9), 0.15, 1.4 - i * 0.15, glow_material)
		spine.rotation.x = -0.4

	var tail_fin := _ellipsoid("CaudalFin", Vector3(0, 0, -4.6), Vector3(0.18, 3.4, 2.2), wings)
	tail.append(tail_fin)

	var light := OmniLight3D.new()
	light.position = Vector3(0, 0.5, 1.0)
	light.light_color = Color(0.15, 0.85, 1.0)
	light.light_energy = 5.0
	light.omni_range = 25.0
	add_child(light)

func _build_kraken() -> void:
	name = "AbyssalKraken"
	set_meta("name", "深渊巨章 · 克拉肯领主")
	if BlenderArt.mesh("creature_kraken_arm") != null:
		var mats := BlenderArt.create_creature_materials(Color(0.95, 0.68, 0.18), Color(0.64, 0.24, 0.18))
		glow_material = mats["glow"]
		BlenderArt.attach_part(self, "TuberculatedMantle", "creature_kraken_mantle", mats)
		BlenderArt.attach_part(self, "BrowCollar", "creature_kraken_head", mats)
		for i in range(8):
			var angle: float = i * TAU / 8.0 + PI * 0.125
			var arm_root := Node3D.new()
			arm_root.name = "KrakenArm_%d" % i
			arm_root.position = Vector3(sin(angle) * 1.65, -0.25, cos(angle) * 1.65)
			arm_root.rotation.y = angle
			arm_root.set_meta("base_yaw", angle)
			add_child(arm_root)
			BlenderArt.attach_part(arm_root, "SuckerTentacle", "creature_kraken_arm", mats)
			limbs.append(arm_root)
		var k_light := OmniLight3D.new()
		k_light.position = Vector3(0.0, 1.6, 1.2)
		k_light.light_color = Color(1.0, 0.58, 0.32)
		k_light.light_energy = 3.6
		k_light.omni_range = 28.0
		add_child(k_light)
		return
	var skin := _material(Color(0.72, 0.18, 0.56), 0.22)
	var dark_skin := _material(Color(0.42, 0.12, 0.48), 0.32)
	var sucker_mat := _material(Color(1.0, 0.42, 0.92), 0.15, true)
	glow_material = sucker_mat

	# Massive Cephalopod Mantle Dome (百米深海巨型章鱼头部/外套膜)
	_ellipsoid("MantleDome", Vector3(0, 3.2, 2.5), Vector3(5.6, 6.2, 7.8), skin)
	_ellipsoid("LowerHead", Vector3(0, 0.6, 0.5), Vector3(4.8, 3.8, 4.5), dark_skin)

	# Glowing Giant Eyes
	for side in [-1.0, 1.0]:
		_ellipsoid("KrakenEye", Vector3(side * 2.2, 0.8, 1.6), Vector3(0.55, 0.55, 0.8), sucker_mat)

	# 8 Colossal Jointed Tentacles (八条多节挥舞巨触)
	for i in range(8):
		var angle: float = i * TAU / 8.0
		var tentacle_root := Node3D.new()
		tentacle_root.position = Vector3(cos(angle) * 2.5, -0.4, sin(angle) * 2.5)
		add_child(tentacle_root)
		var length := 14.0
		var seg_count := 8
		var parent_node: Node3D = tentacle_root
		for s in range(seg_count):
			var seg_len: float = length / seg_count
			var t0 := float(s) / seg_count
			var t1 := float(s + 1) / seg_count
			var start_p := Vector3(sin(t0 * PI * 1.3) * 1.3, -t0 * length * 0.7, -t0 * length * 0.7)
			var end_p := Vector3(sin(t1 * PI * 1.3) * 1.3, -t1 * length * 0.7, -t1 * length * 0.7)
			_tube(start_p, end_p, lerpf(0.46, 0.055, t0), skin, parent_node)
			_ellipsoid("SuckerGlow", (start_p + end_p) * 0.5 + Vector3(0, -0.15, 0), Vector3.ONE * 0.35, sucker_mat, parent_node)
		limbs.append(tentacle_root)

	var light := OmniLight3D.new()
	light.position = Vector3(0, 1.5, 0)
	light.light_color = Color(0.85, 0.25, 1.0)
	light.light_energy = 5.5
	light.omni_range = 30.0
	add_child(light)

func _build_colossus_turtle() -> void:
	name = "ColossusAncientTurtle"
	set_meta("name", "远古灵龟 · 巨岩神鳌")
	if BlenderArt.mesh("creature_colossus_turtle_flipper_f_r") != null:
		var mats := BlenderArt.create_creature_materials(Color(0.38, 0.92, 0.62), Color(0.36, 0.52, 0.38))
		glow_material = mats["glow"]
		BlenderArt.attach_part(self, "ScuteCarapace", "creature_colossus_turtle_shell", mats)
		BlenderArt.attach_part(self, "BeakedHead", "creature_colossus_turtle_head", mats, Vector3(0.0, 0.52, 5.15))
		for side in [-1.0, 1.0]:
			var ff_root := Node3D.new()
			ff_root.name = "FrontFlipper_" + ("R" if side > 0.0 else "L")
			ff_root.position = Vector3(side * 3.75, 0.18, 2.65)
			add_child(ff_root)
			var ff_key := "creature_colossus_turtle_flipper_f_r" if side > 0.0 else "creature_colossus_turtle_flipper_f_l"
			BlenderArt.attach_part(ff_root, "ReticulatedFrontFlipper", ff_key, mats)
			limbs.append(ff_root)
			var rf_root := Node3D.new()
			rf_root.name = "RearFlipper_" + ("R" if side > 0.0 else "L")
			rf_root.position = Vector3(side * 2.95, 0.02, -4.25)
			add_child(rf_root)
			var rf_key := "creature_colossus_turtle_flipper_r_r" if side > 0.0 else "creature_colossus_turtle_flipper_r_l"
			BlenderArt.attach_part(rf_root, "ReticulatedRearPaddle", rf_key, mats)
			limbs.append(rf_root)
		var t_tail := Node3D.new()
		t_tail.name = "TurtleTailPivot"
		t_tail.position = Vector3(0.0, 0.12, -5.25)
		add_child(t_tail)
		BlenderArt.attach_part(t_tail, "ScalyTail", "creature_colossus_turtle_tail", mats)
		tail.append(t_tail)
		var t_light := OmniLight3D.new()
		t_light.position = Vector3(0.0, 2.6, 0.0)
		t_light.light_color = Color(0.45, 0.95, 0.65)
		t_light.light_energy = 3.5
		t_light.omni_range = 30.0
		add_child(t_light)
		return
	var shell_mat := _material(Color(0.16, 0.62, 0.44), 0.35)
	var plate_mat := _material(Color(0.95, 0.82, 0.48), 0.28)
	var crystal_mat := _material(Color(0.28, 1.0, 0.76), 0.18, true)
	var skin := _material(Color(0.24, 0.76, 0.56), 0.24)
	glow_material = crystal_mat

	# Colossal Rugged Shell Carapace (巨型坚甲神鳌重装甲壳)
	_ellipsoid("Carapace", Vector3(0, 1.4, 0), Vector3(8.5, 4.4, 11.0), shell_mat)
	_ellipsoid("PlastronBelly", Vector3(0, -0.9, 0), Vector3(7.2, 2.2, 9.8), plate_mat)

	# Glowing Crystal Spires encrusted on shell
	for i in range(6):
		var angle: float = i * TAU / 6.0
		var p := Vector3(cos(angle) * 2.8, 3.2 + (i % 2) * 0.4, sin(angle) * 3.4)
		_spike(p, 0.4, 1.8 + (i % 2) * 0.8, crystal_mat)

	# Armored Head & Horns
	_ellipsoid("TurtleHead", Vector3(0, 0.5, 6.2), Vector3(2.6, 2.2, 3.2), skin)
	for side in [-1.0, 1.0]:
		_spike(Vector3(side * 0.95, 1.4, 5.8), 0.25, 1.5, plate_mat)
		_ellipsoid("Eye", Vector3(side * 1.15, 0.7, 6.5), Vector3.ONE * 0.3, crystal_mat)

	# 4 Massive Sweeping Armored Flippers (四只巨大前划巨鳍)
	for side in [-1.0, 1.0]:
		# Front Massive Flippers
		var flipper_f := Node3D.new()
		flipper_f.position = Vector3(side * 4.0, 0.1, 2.8)
		add_child(flipper_f)
		var f_pad := _ellipsoid("FrontFlipper", Vector3(side * 2.8, 0, -0.6), Vector3(5.8, 0.32, 2.6), skin, flipper_f)
		f_pad.rotation.y = side * 0.35
		limbs.append(flipper_f)

		# Rear Steering Paddles
		var flipper_r := Node3D.new()
		flipper_r.position = Vector3(side * 3.5, -0.2, -4.2)
		add_child(flipper_r)
		var r_pad := _ellipsoid("RearPaddle", Vector3(side * 1.8, 0, -0.8), Vector3(3.6, 0.25, 1.8), skin, flipper_r)
		r_pad.rotation.y = -side * 0.3
		limbs.append(flipper_r)

	var tail_fin := _ellipsoid("TurtleTail", Vector3(0, -0.3, -6.2), Vector3(0.9, 0.8, 2.4), skin)
	tail.append(tail_fin)

	var light := OmniLight3D.new()
	light.position = Vector3(0, 2.5, 0)
	light.light_color = Color(0.2, 1.0, 0.6)
	light.light_energy = 5.2
	light.omni_range = 32.0
	add_child(light)

func _material(color: Color, metallic: float = 0.0, luminous: bool = false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic * 0.65
	material.roughness = 0.65
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	material.rim_enabled = false
	material.rim = 0.56
	material.rim_tint = 0.32
	if luminous:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 0.26
	return material

func _ellipsoid(label: String, at: Vector3, size: Vector3, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = label
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 16
	sphere.rings = 8
	if species in ["water_dragon", "seal", "sea_wolf", "flying_fish"] and size.z > size.x:
		sphere.radial_segments = 20
		sphere.rings = 10
	part.mesh = sphere
	var authored := BlenderArt.creature_mesh(species, label)
	if authored != null:
		part.mesh = authored
		part.set_meta("blender_surface", true)
		BlenderArt.bind_detail(material, authored)
	part.position = at
	part.scale = size
	part.material_override = material
	(parent if parent != null else self).add_child(part)
	return part

func _tube(start: Vector3, finish: Vector3, radius: float, material: Material, parent: Node3D = null) -> void:
	var part := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius * 0.72
	cylinder.bottom_radius = radius
	cylinder.height = start.distance_to(finish)
	cylinder.radial_segments = 8
	part.mesh = cylinder
	part.position = (start + finish) * 0.5
	part.quaternion = Quaternion(Vector3.UP, (finish - start).normalized())
	part.material_override = material
	(parent if parent != null else self).add_child(part)

func _spike(at: Vector3, radius: float, height: float, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = radius
	cone.height = height
	cone.radial_segments = 8
	part.mesh = cone
	part.position = at
	part.material_override = material
	(parent if parent != null else self).add_child(part)
	return part

func _build_sea_wolf() -> void:
	name = "AbyssalSeaWolf"
	set_meta("name", "幽影海狼 · 深渊猎手")
	if BlenderArt.mesh("creature_sea_wolf_pectoral_r") != null:
		var mats := BlenderArt.create_creature_materials(Color(0.94, 0.70, 0.20), Color(0.32, 0.42, 0.52))
		glow_material = mats["glow"]
		BlenderArt.attach_part(self, "LupineTorso", "creature_sea_wolf_body", mats)
		BlenderArt.attach_part(self, "LupineHead", "creature_sea_wolf_head", mats, Vector3(0.0, 0.20, 1.92))
		for side in [-1.0, 1.0]:
			var pec := Node3D.new()
			pec.name = "PectoralFlipper_" + ("R" if side > 0.0 else "L")
			pec.position = Vector3(side * 0.68, -0.22, 0.78)
			add_child(pec)
			var pec_key := "creature_sea_wolf_pectoral_r" if side > 0.0 else "creature_sea_wolf_pectoral_l"
			BlenderArt.attach_part(pec, "PectoralBlade", pec_key, mats)
			limbs.append(pec)
			var pel := Node3D.new()
			pel.name = "PelvicFlipper_" + ("R" if side > 0.0 else "L")
			pel.position = Vector3(side * 0.48, -0.18, -1.18)
			add_child(pel)
			var pel_key := "creature_sea_wolf_pelvic_r" if side > 0.0 else "creature_sea_wolf_pelvic_l"
			BlenderArt.attach_part(pel, "PelvicBlade", pel_key, mats)
			limbs.append(pel)
		var fluke_pivot := Node3D.new()
		fluke_pivot.name = "FlukePivot"
		fluke_pivot.position = Vector3(0.0, -0.04, -2.36)
		add_child(fluke_pivot)
		BlenderArt.attach_part(fluke_pivot, "HorizontalFluke", "creature_sea_wolf_fluke", mats)
		tail.append(fluke_pivot)
		var w_light := OmniLight3D.new()
		w_light.position = Vector3(0.0, 0.4, 2.0)
		w_light.light_color = Color(0.95, 0.78, 0.42)
		w_light.light_energy = 1.6
		w_light.omni_range = 12.0
		add_child(w_light)
		return
	var pelt := _material(Color(0.22, 0.42, 0.68), 0.28)
	var belly := _material(Color(0.76, 0.90, 0.98), 0.18)
	var fangs := _material(Color(0.95, 0.96, 0.98), 0.15)
	var eyes_glow := _material(Color(0.2, 0.95, 1.0), 0.1, true)
	glow_material = eyes_glow

	_ellipsoid("WolfBody", Vector3(0, 0, 0), Vector3(1.7, 1.45, 4.2), pelt)
	_ellipsoid("WolfBelly", Vector3(0, -0.28, 0.2), Vector3(1.3, 0.85, 3.2), belly)
	_ellipsoid("WolfHead", Vector3(0, 0.22, 2.3), Vector3(1.2, 1.1, 1.6), pelt)
	_ellipsoid("Snout", Vector3(0, 0.05, 3.1), Vector3(0.75, 0.55, 1.2), pelt)
	_ellipsoid("LowerJaw", Vector3(0, -0.28, 2.9), Vector3(0.65, 0.32, 1.1), belly)

	for side in [-1.0, 1.0]:
		_spike(Vector3(side * 0.28, -0.08, 3.2), 0.05, 0.25, fangs)
		_spike(Vector3(side * 0.25, -0.22, 3.1), 0.04, 0.22, fangs)
		_ellipsoid("Eye", Vector3(side * 0.48, 0.38, 2.65), Vector3.ONE * 0.16, eyes_glow)
		var flipper := Node3D.new()
		flipper.position = Vector3(side * 0.72, -0.25, 0.85)
		add_child(flipper)
		var paddle := _ellipsoid("PectoralPaddle", Vector3(side * 0.65, 0, -0.35), Vector3(1.5, 0.16, 0.85), pelt, flipper)
		paddle.rotation.y = side * 0.35
		limbs.append(flipper)
		var flipper_rear := Node3D.new()
		flipper_rear.position = Vector3(side * 0.55, -0.2, -1.2)
		add_child(flipper_rear)
		var r_pad := _ellipsoid("RearPaddle", Vector3(side * 0.45, 0, -0.25), Vector3(1.0, 0.12, 0.65), pelt, flipper_rear)
		r_pad.rotation.y = -side * 0.25
		limbs.append(flipper_rear)

	for i in range(5):
		var spk := _spike(Vector3(0, 0.85 - i * 0.05, 1.2 - i * 0.65), 0.08, 0.55 - i * 0.06, eyes_glow)
		spk.rotation.x = -0.3

	var tail_fin := _ellipsoid("WolfCaudalFin", Vector3(0, 0, -2.6), Vector3(0.12, 1.45, 1.3), eyes_glow)
	tail.append(tail_fin)

	var light := OmniLight3D.new()
	light.position = Vector3(0, 0.4, 2.0)
	light.light_color = Color(0.2, 0.95, 1.0)
	light.light_energy = 2.4
	light.omni_range = 14.0
	add_child(light)

func _build_school_fish() -> void:
	name = "SchoolingFish"
	set_meta("name", "荧光幻梭鱼")
	if BlenderArt.mesh("creature_school_fish_fin_r") != null:
		var mats := BlenderArt.create_creature_materials(Color(0.92, 0.76, 0.34), Color(0.76, 0.82, 0.88))
		glow_material = mats["glow"]
		BlenderArt.attach_part(self, "SilverOchreBody", "creature_school_fish_body", mats)
		for side in [-1.0, 1.0]:
			var fin := Node3D.new()
			fin.name = "PectoralFin_" + ("R" if side > 0.0 else "L")
			fin.position = Vector3(side * 0.10, -0.04, 0.16)
			add_child(fin)
			var f_key := "creature_school_fish_fin_r" if side > 0.0 else "creature_school_fish_fin_l"
			BlenderArt.attach_part(fin, "SideFin", f_key, mats)
			limbs.append(fin)
		var caudal_pivot := Node3D.new()
		caudal_pivot.name = "TailFinPivot"
		caudal_pivot.position = Vector3(0.0, 0.0, -0.52)
		add_child(caudal_pivot)
		BlenderArt.attach_part(caudal_pivot, "TailFin", "creature_school_fish_caudal", mats)
		tail.append(caudal_pivot)
		return
	var scales := _material(Color(0.18, 0.78, 0.98), 0.18)
	var belly := _material(Color(0.92, 0.98, 1.0), 0.12, true)
	glow_material = belly
	_ellipsoid("Body", Vector3.ZERO, Vector3(0.22, 0.32, 1.15), scales)
	_ellipsoid("BellyGlow", Vector3(0, -0.06, 0.05), Vector3(0.18, 0.18, 0.9), belly)
	for side in [-1.0, 1.0]:
		_ellipsoid("Eye", Vector3(side * 0.11, 0.06, 0.42), Vector3.ONE * 0.045, belly)
		var fin := Node3D.new()
		fin.position = Vector3(side * 0.12, -0.04, 0.15)
		add_child(fin)
		_ellipsoid("SideFin", Vector3(side * 0.14, 0, -0.08), Vector3(0.25, 0.03, 0.18), belly, fin)
		limbs.append(fin)
	var caudal := _ellipsoid("TailFin", Vector3(0, 0, -0.65), Vector3(0.03, 0.42, 0.32), belly)
	tail.append(caudal)
