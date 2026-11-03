extends Node3D

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

func animate(delta: float) -> void:
	animation_clock += delta
	match species:
		"sea_spider":
			for i in range(limbs.size()):
				limbs[i].rotation.y = sin(animation_clock * 5.0 + i * PI * 0.8) * 0.2
				limbs[i].rotation.z = sin(animation_clock * 5.0 + i * PI) * 0.13
		"seal":
			for i in range(limbs.size()):
				limbs[i].rotation.z = sin(animation_clock * 2.8 + i * PI) * 0.32
			for part in tail:
				part.rotation.x = sin(animation_clock * 2.8) * 0.2
		"water_dragon":
			for i in range(tail.size()):
				var rest: Vector3 = tail[i].get_meta("rest")
				tail[i].position = rest + Vector3(sin(animation_clock * 2.0 - i * 0.5) * (0.1 + i * 0.1), cos(animation_clock * 1.3 - i * 0.3) * 0.12, 0)
				tail[i].rotation.y = cos(animation_clock * 2.0 - i * 0.5) * 0.18
			for i in range(limbs.size()):
				limbs[i].rotation.z = sin(animation_clock * 1.8 + i * PI) * 0.22
			glow_material.emission = Color(1.0, 0.25, 0.12) if bool(get_meta("enraged", false)) else Color(0.08, 0.55, 1.0)
		"flying_fish":
			for i in range(limbs.size()):
				limbs[i].rotation.z = sin(animation_clock * 7.5 + i * PI) * 0.42
				limbs[i].rotation.y = cos(animation_clock * 4.0) * 0.18
			for part in tail:
				part.rotation.y = sin(animation_clock * 8.5) * 0.35
			if glow_material:
				glow_material.emission = Color(1.0, 0.35, 0.1) if bool(get_meta("enraged", false)) else Color(0.18, 0.95, 1.0)
		"kraken":
			for i in range(limbs.size()):
				var t: float = animation_clock * 2.8 + i * 0.75
				limbs[i].rotation.x = sin(t) * 0.35
				limbs[i].rotation.z = cos(t * 0.7) * 0.28
			if glow_material:
				glow_material.emission = Color(1.0, 0.2, 0.1) if bool(get_meta("enraged", false)) else Color(0.85, 0.35, 1.0)
		"colossus_turtle":
			for i in range(limbs.size()):
				limbs[i].rotation.z = sin(animation_clock * 1.8 + i * PI * 0.5) * 0.32
			for part in tail:
				part.rotation.y = sin(animation_clock * 1.5) * 0.18
			if glow_material:
				glow_material.emission = Color(1.0, 0.3, 0.1) if bool(get_meta("enraged", false)) else Color(0.2, 1.0, 0.65)
		"sea_wolf":
			for i in range(limbs.size()):
				limbs[i].rotation.z = sin(animation_clock * 4.2 + i * PI * 0.7) * 0.28
				limbs[i].rotation.x = cos(animation_clock * 4.2 + i * PI * 0.5) * 0.16
			for part in tail:
				part.rotation.y = sin(animation_clock * 5.5) * 0.32
			if glow_material:
				glow_material.emission = Color(1.0, 0.45, 0.1) if bool(get_meta("enraged", false)) else Color(0.15, 0.85, 0.95)
		"school_fish":
			for part in tail:
				part.rotation.y = sin(animation_clock * 11.0) * 0.45
			for i in range(limbs.size()):
				limbs[i].rotation.z = sin(animation_clock * 8.0 + i * PI) * 0.35

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
	var shell := _material(Color(0.27, 0.13, 0.16), 0.35)
	var joints := _material(Color(0.7, 0.33, 0.17), 0.55)
	var eyes := _material(Color(0.15, 0.85, 1.0), 0.2, true)
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
	var skin := _material(Color(0.39, 0.46, 0.5), 0.08)
	var belly := _material(Color(0.69, 0.75, 0.73))
	var dark := _material(Color(0.04, 0.08, 0.1))
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
	var scales := _material(Color(0.025, 0.14, 0.24), 0.45)
	var pale := _material(Color(0.16, 0.4, 0.52), 0.35)
	var horns := _material(Color(0.85, 0.62, 0.3), 0.6)
	glow_material = _material(Color(0.12, 0.65, 1.0), 0.2, true)
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
	var scales := _material(Color(0.08, 0.25, 0.42), 0.5)
	var wings := _material(Color(0.15, 0.85, 0.95), 0.35, true)
	var belly := _material(Color(0.85, 0.92, 0.98), 0.15)
	var fins_mat := _material(Color(0.04, 0.15, 0.28), 0.6)
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
	var skin := _material(Color(0.28, 0.10, 0.22), 0.25)
	var dark_skin := _material(Color(0.14, 0.05, 0.12), 0.45)
	var sucker_mat := _material(Color(0.95, 0.35, 0.85), 0.2, true)
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
		var seg_count := 4
		var parent_node: Node3D = tentacle_root
		for s in range(seg_count):
			var seg_len: float = length / seg_count
			var start_p := Vector3(0, -s * seg_len * 0.7, -s * seg_len * 0.7)
			var end_p := Vector3(0, -(s + 1) * seg_len * 0.7, -(s + 1) * seg_len * 0.7)
			_tube(start_p, end_p, 0.45 - s * 0.08, skin, parent_node)
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
	var shell_mat := _material(Color(0.12, 0.22, 0.16), 0.65)
	var plate_mat := _material(Color(0.24, 0.38, 0.28), 0.45)
	var crystal_mat := _material(Color(0.25, 0.95, 0.65), 0.25, true)
	var skin := _material(Color(0.18, 0.28, 0.22), 0.3)
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
	material.metallic = metallic
	material.roughness = 0.6
	if luminous:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.8
	return material

func _ellipsoid(label: String, at: Vector3, size: Vector3, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = label
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 16
	sphere.rings = 8
	part.mesh = sphere
	part.position = at
	part.scale = size
	part.material_override = material
	(parent if parent != null else self).add_child(part)
	return part

func _tube(start: Vector3, finish: Vector3, radius: float, material: Material, parent: Node3D = null) -> void:
	var part := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius * 0.8
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
	var pelt := _material(Color(0.12, 0.18, 0.26), 0.45)
	var belly := _material(Color(0.35, 0.48, 0.58), 0.25)
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
	var scales := _material(Color(0.15, 0.65, 0.85), 0.25)
	var belly := _material(Color(0.85, 0.96, 1.0), 0.15, true)
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
