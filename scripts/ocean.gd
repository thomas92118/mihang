extends Node3D

const HOME := Vector3(0, -3.5, 8)
const RESOURCE_NAMES := {
	"titanium": "钛矿",
	"copper": "铜矿",
	"quartz": "石英",
	"kelp": "海藻样本",
	"fish_small": "发光小金鱼 (食用)",
	"shark_fragment": "巨鲨齿骨碎片 (强化)",
	"abyss_fragment": "深渊巨兽晶核 (强化)",
	"black_box": "失事潜艇黑匣子 (科考日志)"
}

const FRAGMENT_NAMES := {
	"shark_fragment": "巨鲨齿骨碎片",
	"abyss_fragment": "深渊巨兽晶核"
}

var environment: Environment
var sun: DirectionalLight3D
var resources: Array[Node3D] = []
var fragments: Array[Node3D] = []
var fish: Array[Node3D] = []
var small_fish: Array[Node3D] = []
var predators: Array[Node3D] = []
var rng := RandomNumberGenerator.new()
var clock: float = 0.0
var cache: Dictionary = {}
var vent_lights: Array[OmniLight3D] = []
var jellies: Array[Node3D] = []

static func floor_height(x: float, z: float) -> float:
	var base_hills: float = sin(x * 0.045) * 3.5 + cos(z * 0.05) * 3.0 + sin((x + z) * 0.07) * 1.8
	var micro_detail: float = sin(x * 0.15 + cos(z * 0.1)) * 0.8 + cos(z * 0.18) * 0.6
	var depth_tier: float = 0.0
	if z < -15.0:
		var slope_t: float = clampf((-z - 15.0) / 70.0, 0.0, 1.0)
		var drop: float = slope_t * slope_t * (3.0 - 2.0 * slope_t)
		depth_tier -= drop * 66.0
		var trench_dist: float = absf(z - (-162.0))
		if trench_dist < 42.0:
			var trench_shape: float = 1.0 - trench_dist / 42.0
			depth_tier -= trench_shape * trench_shape * 17.0

	var x_dist: float = absf(x)
	if x_dist > 85.0:
		var x_slope: float = clampf((x_dist - 85.0) / 85.0, 0.0, 1.0)
		depth_tier -= x_slope * x_slope * 45.0

	return -16.0 + depth_tier + base_hills + micro_detail

func _ready() -> void:
	rng.seed = 240913
	_create_environment()
	_create_terrain()
	_populate()

func _create_environment() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.035, 0.29, 0.36)
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.16, 0.34, 0.6)
	sky_material.sky_horizon_color = Color(0.69, 0.82, 0.88)
	sky_material.ground_bottom_color = Color(0.025, 0.13, 0.16)
	sky_material.ground_horizon_color = Color(0.18, 0.38, 0.43)
	environment.sky = Sky.new()
	environment.sky.sky_material = sky_material
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.38, 0.72, 0.76)
	environment.ambient_light_energy = 0.65
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.075, 0.43, 0.47)
	environment.fog_light_energy = 0.8
	environment.fog_density = 0.012
	environment.fog_sky_affect = 1.0
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-68, -28, 0)
	sun.light_color = Color(0.72, 0.94, 0.84)
	sun.light_energy = 1.35
	add_child(sun)

	var surface := MeshInstance3D.new()
	surface.name = "WaterSurface"
	var plane := PlaneMesh.new()
	plane.size = Vector2(540, 460)
	plane.subdivide_width = 180
	plane.subdivide_depth = 152
	surface.mesh = plane
	surface.position = Vector3(0, 0, -80)
	var water := ShaderMaterial.new()
	water.shader = load("res://shaders/water.gdshader")
	var noise := FastNoiseLite.new()
	noise.seed = 240913
	noise.frequency = 0.035
	noise.fractal_octaves = 4
	var ripples := NoiseTexture2D.new()
	ripples.width = 512
	ripples.height = 512
	ripples.seamless = true
	ripples.as_normal_map = true
	ripples.bump_strength = 2.0
	ripples.noise = noise
	water.set_shader_parameter("ripple_normal", ripples)
	water.set_shader_parameter("sun_direction", sun.transform.basis.z)
	surface.material_override = water
	surface.extra_cull_margin = 0.6
	add_child(surface)

	var shaft_material := ShaderMaterial.new()
	shaft_material.shader = load("res://shaders/shaft.gdshader")
	for i in range(16):
		var shaft := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(rng.randf_range(2.5, 6.0), 32)
		shaft.mesh = quad
		shaft.material_override = shaft_material
		shaft.position = Vector3(rng.randf_range(-60, 60), -17, rng.randf_range(-45, 25))
		shaft.rotation_degrees = Vector3(0, -20, -18)
		add_child(shaft)

func _create_terrain() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(-250, 250, 4):
		for z in range(-280, 120, 4):
			var points := [Vector2(x, z), Vector2(x + 4, z), Vector2(x, z + 4), Vector2(x + 4, z + 4)]
			for index in [0, 1, 2, 1, 3, 2]:
				var p: Vector2 = points[index]
				st.add_vertex(Vector3(p.x, floor_height(p.x, p.y), p.y))
	st.generate_normals()
	var terrain := MeshInstance3D.new()
	terrain.name = "Seabed"
	terrain.mesh = st.commit()
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/sand.gdshader")
	var noise := FastNoiseLite.new()
	noise.seed = 240914
	noise.frequency = 0.065
	noise.fractal_octaves = 4
	var sediment := NoiseTexture2D.new()
	sediment.width = 512
	sediment.height = 512
	sediment.seamless = true
	sediment.noise = noise
	material.set_shader_parameter("sediment_noise", sediment)
	terrain.material_override = material
	add_child(terrain)
	terrain.create_trimesh_collision()

func model(asset: String, at: Vector3, size: float = 1.0) -> Node3D:
	if not cache.has(asset):
		cache[asset] = load("res://assets/models/" + asset + ".glb")
	var instance: Node3D = cache[asset].instantiate()
	add_child(instance)
	instance.position = at
	instance.scale = Vector3.ONE * size
	return instance

func _populate() -> void:
	# 1. 逃生舱 (Lifepod at HOME)
	var pod := model("pod", HOME)
	pod.name = "Lifepod"
	var pod_body := StaticBody3D.new()
	var pod_collision := CollisionShape3D.new()
	var pod_shape := SphereShape3D.new()
	pod_shape.radius = 2.2
	pod_collision.shape = pod_shape
	pod_body.add_child(pod_collision)
	pod_body.position.y = 2.0
	pod.add_child(pod_body)
	var beacon_light := OmniLight3D.new()
	beacon_light.position = HOME + Vector3(0, 3, 0)
	beacon_light.light_color = Color(0.2, 1.0, 0.85)
	beacon_light.light_energy = 3.2
	beacon_light.omni_range = 14
	add_child(beacon_light)
	var marker := Label3D.new()
	marker.text = "◇  LIFEPOD  /  逃生舱"
	marker.position = HOME + Vector3(0, 6.5, 0)
	marker.font_size = 48
	marker.pixel_size = 0.009
	marker.modulate = Color(0.65, 1.0, 0.9)
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.no_depth_test = true
	add_child(marker)

	# 2. 浅海与海沟古代遗迹拱门
	var arch := model("ruins", Vector3(2, floor_height(2, -25), -25), 1.4)
	arch.rotation.y = 0.15
	for child in arch.find_children("*", "MeshInstance3D"):
		child.create_trimesh_collision()
	var arch_marker := _create_marker("◈  ANCIENT RUINS  /  古代海沟遗迹", Vector3(2, floor_height(2, -25) + 6.0, -25), Color(0.4, 0.9, 0.8))
	add_child(arch_marker)

	# 3. 深渊古代巨石祭坛
	var altar_pos := Vector3(-50, floor_height(-50, -170), -170)
	var altar := model("ruins", altar_pos, 1.8)
	altar.rotation.y = 0.45
	for child in altar.find_children("*", "MeshInstance3D"):
		child.create_trimesh_collision()
	var altar_light := OmniLight3D.new()
	altar_light.position = altar_pos + Vector3(0, 5, 0)
	altar_light.light_color = Color(0.18, 0.92, 1.0)
	altar_light.light_energy = 4.8
	altar_light.omni_range = 26.0
	add_child(altar_light)
	var altar_marker := _create_marker("◈  ABYSSAL ALTAR  /  深渊史前祭坛", altar_pos + Vector3(0, 9.0, 0), Color(0.3, 0.95, 1.0))
	add_child(altar_marker)

	# 4. 深海地热喷口群
	var vent_positions := [
		Vector3(15, floor_height(15, -165), -165),
		Vector3(-15, floor_height(-15, -180), -180),
		Vector3(32, floor_height(32, -152), -152),
		Vector3(-2, floor_height(-2, -195), -195),
	]
	for p in vent_positions:
		_create_hydrothermal_vent(p)
	var vent_marker := _create_marker("♨  HYDROTHERMAL VENTS  /  深海地热喷口", Vector3(15, floor_height(15, -165) + 12.0, -165), Color(1.0, 0.6, 0.2))
	add_child(vent_marker)

	# 5. 失事科考潜艇遗址
	var wreck_pos := Vector3(45, floor_height(45, -55) + 0.9, -55)
	var wreck := model("shipwreck", wreck_pos, 1.35)
	wreck.rotation = Vector3(0.08, 0.45, -0.15)
	for child in wreck.find_children("*", "MeshInstance3D"):
		child.create_trimesh_collision()
	var wreck_beacon := OmniLight3D.new()
	wreck_beacon.position = wreck_pos + Vector3(0, 6.2, 0)
	wreck_beacon.light_color = Color(0.2, 0.95, 1.0)
	wreck_beacon.light_energy = 4.2
	wreck_beacon.omni_range = 24.0
	add_child(wreck_beacon)
	var wreck_interior := OmniLight3D.new()
	wreck_interior.position = wreck_pos + Vector3(0, 1.8, 1.0)
	wreck_interior.light_color = Color(1.0, 0.52, 0.16)
	wreck_interior.light_energy = 2.8
	wreck_interior.omni_range = 15.0
	add_child(wreck_interior)
	var wreck_marker := _create_marker("⚓  RESEARCH SHIPWRECK  /  失事科考潜艇", wreck_pos + Vector3(0, 8.5, 0), Color(1.0, 0.8, 0.4))
	add_child(wreck_marker)

	# 5.1 失事潜艇黑匣子交互终端 (Black Box Data Terminal)
	var black_box := StaticBody3D.new()
	black_box.name = "BlackBoxTerminal"
	black_box.position = wreck_pos + Vector3(1.2, 1.4, 1.8)
	black_box.collision_layer = 2
	black_box.set_meta("kind", "black_box")
	black_box.set_meta("name", "失事科考潜艇黑匣子")
	var bb_box := CollisionShape3D.new()
	var bb_shape := BoxShape3D.new()
	bb_shape.size = Vector3(1.1, 0.9, 1.1)
	bb_box.shape = bb_shape
	black_box.add_child(bb_box)
	var bb_light := OmniLight3D.new()
	bb_light.light_color = Color(0.25, 0.95, 1.0)
	bb_light.light_energy = 3.6
	bb_light.omni_range = 8.0
	black_box.add_child(bb_light)
	var bb_label := Label3D.new()
	bb_label.text = "◈  BLACK BOX  /  失事科考日志"
	bb_label.position = Vector3(0, 0.85, 0)
	bb_label.font_size = 32
	bb_label.pixel_size = 0.007
	bb_label.modulate = Color(0.35, 0.95, 1.0)
	bb_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bb_label.no_depth_test = true
	black_box.add_child(bb_label)
	add_child(black_box)

	# 6. 暮光断崖与深渊导航光标浮标
	_create_nav_buoy(Vector3(0, -22, -35), "▼  CONTINENTAL DROP-OFF  /  暮光大断崖")
	_create_nav_buoy(Vector3(0, -65, -105), "▼  ABYSSAL ENTRANCE  /  深渊裂谷入口")

	# 7. 岩石分布 (覆盖浅海、斜坡与深海)
	for i in range(110):
		var x: float = rng.randf_range(-190, 190)
		var z: float = rng.randf_range(-240, 80)
		if absf(x) < 8 and z > -30 and z < 15:
			continue
		var rock := model("rock", Vector3(x, floor_height(x, z) - 0.3, z), rng.randf_range(0.8, 3.2))
		rock.rotation.y = rng.randf_range(0, TAU)
		for child in rock.find_children("*", "MeshInstance3D"):
			child.create_trimesh_collision()

	# 8. 植被分布 (浅海珊瑚、海藻林、深海发光管珊瑚)
	for i in range(160):
		var x: float = rng.randf_range(-160, 160)
		var z: float = rng.randf_range(-230, 80)
		var depth_at_pos: float = -floor_height(x, z)
		var asset: String
		if depth_at_pos > 50.0:
			asset = "tube_coral"
		elif depth_at_pos > 25.0:
			asset = "tube_coral" if (i % 2 == 0) else "coral"
		else:
			asset = ["coral", "tube_coral", "kelp"][i % 3]
		var plant := model(asset, Vector3(x, floor_height(x, z), z), rng.randf_range(0.8, 2.0))
		plant.rotation.y = rng.randf_range(0, TAU)

	for p in [Vector3(-7, 0, 2), Vector3(8, 0, -5), Vector3(-9, 0, -16)]:
		model("coral", Vector3(p.x, floor_height(p.x, p.z), p.z), 1.5)

	# 9. 巨型发光海葵群落
	for i in range(32):
		var x: float
		var z: float
		if i < 20:
			x = rng.randf_range(-65, 65)
			z = rng.randf_range(-45, 25)
		else:
			x = rng.randf_range(-75, 75)
			z = rng.randf_range(-80, -45)
		var anemone := model("anemone", Vector3(x, floor_height(x, z), z), rng.randf_range(0.85, 1.6))
		anemone.rotation.y = rng.randf_range(0, TAU)

	# 10. 深渊地热结晶石柱柱群
	for i in range(18):
		var x: float = rng.randf_range(-80, 80)
		var z: float = rng.randf_range(-210, -115)
		var spire_pos := Vector3(x, floor_height(x, z) - 0.2, z)
		var spire := model("crystal_spire", spire_pos, rng.randf_range(0.95, 1.8))
		spire.rotation.y = rng.randf_range(0, TAU)
		for child in spire.find_children("*", "MeshInstance3D"):
			child.create_trimesh_collision()
		if i % 3 == 0:
			var crystal_light := OmniLight3D.new()
			crystal_light.position = spire_pos + Vector3(0, 3.8, 0)
			crystal_light.light_color = Color(0.2, 0.88, 1.0) if (i % 2 == 0) else Color(0.72, 0.38, 1.0)
			crystal_light.light_energy = 3.2
			crystal_light.omni_range = 20.0
			add_child(crystal_light)

	# 11. 资源生成 (共 100 处采集点：56 处浅海，20 处斜坡，24 处深渊裂谷与热泉)
	var trail := [Vector2(-3, 3), Vector2(2, 0), Vector2(6, -5), Vector2(-5, -9), Vector2(3, -13), Vector2(-2, -18), Vector2(7, -20), Vector2(-6, -24)]
	var kinds := ["titanium", "kelp", "copper", "quartz"]
	for i in range(56):
		var p: Vector2 = trail[i] if i < trail.size() else Vector2(rng.randf_range(-55, 55), rng.randf_range(-55, 45))
		_spawn_resource(kinds[i % 4], Vector3(p.x, floor_height(p.x, p.y) + 0.5, p.y))
	for i in range(20):
		var x: float = rng.randf_range(-80, 80)
		var z: float = rng.randf_range(-85, -35)
		var kind: String = "copper" if (i % 2 == 0) else "titanium"
		_spawn_resource(kind, Vector3(x, floor_height(x, z) + 0.5, z))
	for i in range(24):
		var x: float = rng.randf_range(-70, 60)
		var z: float = rng.randf_range(-210, -120)
		var kind: String = "quartz" if (i % 2 == 0) else "titanium"
		_spawn_resource(kind, Vector3(x, floor_height(x, z) + 0.5, z))

	# 12. 多元生态鱼类群落 (共 134 条鱼：54 条可食用小鱼，48 条中型珊瑚游鱼，18 条巡猎巨鲨，14 条深渊巨兽)
	# 12.1 可食用发光小鱼 (54 条：30 浅海，14 斜坡，10 深渊)
	for i in range(30):
		var center := Vector3(rng.randf_range(-48, 48), rng.randf_range(-17, -4), rng.randf_range(-48, 28))
		_spawn_small_fish(center, rng.randf_range(0.8, 1.25))
	for i in range(14):
		var center := Vector3(rng.randf_range(-68, 68), rng.randf_range(-52, -26), rng.randf_range(-88, -38))
		_spawn_small_fish(center, rng.randf_range(0.9, 1.3))
	for i in range(10):
		var center := Vector3(rng.randf_range(-65, 65), rng.randf_range(-92, -66), rng.randf_range(-198, -118))
		_spawn_small_fish(center, rng.randf_range(0.95, 1.35))

	# 12.2 中型漫游温和鱼群 (48 条：28 浅海，12 斜坡，8 深渊)
	for i in range(28):
		var center := Vector3(rng.randf_range(-42, 42), rng.randf_range(-18, -6), rng.randf_range(-45, 25))
		_spawn_neutral_fish(center, rng.randf_range(0.7, 1.3))
	for i in range(12):
		var center := Vector3(rng.randf_range(-65, 65), rng.randf_range(-50, -25), rng.randf_range(-85, -40))
		_spawn_neutral_fish(center, rng.randf_range(0.9, 1.5))
	for i in range(8):
		var center := Vector3(rng.randf_range(-60, 60), rng.randf_range(-90, -65), rng.randf_range(-195, -120))
		_spawn_neutral_fish(center, rng.randf_range(0.85, 1.6))

	# 12.3 凶猛攻击性捕食者：深海巡猎巨鲨 (18 条：8 浅海边缘，10 暮光斜坡断崖)
	for i in range(8):
		var center := Vector3(rng.randf_range(-60, 60), rng.randf_range(-22, -10), rng.randf_range(-48, -10))
		_spawn_predator("predator", center, rng.randf_range(0.95, 1.35))
	for i in range(10):
		var center := Vector3(rng.randf_range(-75, 75), rng.randf_range(-56, -26), rng.randf_range(-90, -42))
		_spawn_predator("predator", center, rng.randf_range(1.0, 1.45))

	# 12.4 凶猛深渊巨兽：深渊鮟鱇怪兽 (14 条：深海大裂谷与地热喷口区)
	for i in range(14):
		var center := Vector3(rng.randf_range(-72, 72), rng.randf_range(-96, -65), rng.randf_range(-205, -115))
		_spawn_predator("abyss", center, rng.randf_range(0.9, 1.4))

	# 13. 深海发光水母群 (18 只水母漂浮脉动)
	for i in range(18):
		var center: Vector3
		if i < 6:
			center = Vector3(rng.randf_range(-55, 55), rng.randf_range(-48, -26), rng.randf_range(-85, -35))
		else:
			center = Vector3(rng.randf_range(-75, 75), rng.randf_range(-95, -65), rng.randf_range(-200, -115))
		var jelly := model("jellyfish", center, rng.randf_range(0.85, 1.5))
		jelly.set_meta("kind", "jellyfish")
		jelly.set_meta("name", "发光水母")
		jelly.set_meta("center", center)
		jelly.set_meta("phase", rng.randf_range(0, TAU))
		jelly.set_meta("drift_speed", rng.randf_range(0.12, 0.24))
		jelly.set_meta("stun_timer", 0.0)
		jelly.set_meta("dead", false)
		jellies.append(jelly)
	_create_particles()

func _create_marker(text: String, at: Vector3, color: Color) -> Label3D:
	var marker := Label3D.new()
	marker.text = text
	marker.position = at
	marker.font_size = 40
	marker.pixel_size = 0.0085
	marker.modulate = color
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.no_depth_test = true
	return marker

func _create_nav_buoy(at: Vector3, label_text: String) -> void:
	var buoy := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.6
	sphere.height = 1.2
	buoy.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.9, 0.95)
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.9, 0.95)
	mat.emission_energy_multiplier = 2.0
	buoy.material_override = mat
	buoy.position = at
	add_child(buoy)

	var light := OmniLight3D.new()
	light.position = at
	light.light_color = Color(0.25, 0.95, 0.9)
	light.light_energy = 3.5
	light.omni_range = 18.0
	add_child(light)

	var marker := _create_marker(label_text, at + Vector3(0, 2.5, 0), Color(0.6, 1.0, 0.9))
	add_child(marker)

func _create_hydrothermal_vent(at: Vector3) -> void:
	var vent_root := Node3D.new()
	vent_root.position = at
	add_child(vent_root)

	var chimney_height: float = 8.5
	var chimney := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.bottom_radius = 2.4
	cyl.top_radius = 1.1
	cyl.height = chimney_height
	chimney.mesh = cyl
	var basalt := StandardMaterial3D.new()
	basalt.albedo_color = Color(0.12, 0.13, 0.15)
	basalt.roughness = 0.95
	chimney.material_override = basalt
	chimney.position.y = chimney_height * 0.5
	vent_root.add_child(chimney)

	var crater := MeshInstance3D.new()
	var crater_mesh := CylinderMesh.new()
	crater_mesh.bottom_radius = 1.05
	crater_mesh.top_radius = 0.8
	crater_mesh.height = 0.6
	crater.mesh = crater_mesh
	var magma := StandardMaterial3D.new()
	magma.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	magma.albedo_color = Color(1.0, 0.45, 0.08)
	crater.material_override = magma
	crater.position.y = chimney_height + 0.15
	vent_root.add_child(crater)

	var light := OmniLight3D.new()
	light.position = at + Vector3(0, chimney_height + 1.2, 0)
	light.light_color = Color(1.0, 0.52, 0.16)
	light.light_energy = 5.2
	light.omni_range = 36.0
	light.omni_attenuation = 1.15
	add_child(light)
	vent_lights.append(light)

	var plume := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var bubble := SphereMesh.new()
	bubble.radius = 0.08
	bubble.height = 0.16
	var bubble_mat := StandardMaterial3D.new()
	bubble_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bubble_mat.albedo_color = Color(1.0, 0.65, 0.25)
	bubble.material = bubble_mat
	mm.mesh = bubble
	mm.instance_count = 32
	for i in range(mm.instance_count):
		var offset := Vector3(rng.randf_range(-0.5, 0.5), chimney_height + float(i) * 0.45, rng.randf_range(-0.5, 0.5))
		mm.set_instance_transform(i, Transform3D(Basis(), offset))
	plume.multimesh = mm
	vent_root.add_child(plume)

func _spawn_small_fish(center: Vector3, size: float) -> void:
	var body := StaticBody3D.new()
	body.name = "FishSmall"
	body.position = center
	body.collision_layer = 2
	body.set_meta("kind", "fish_small")
	body.set_meta("name", "发光小金鱼")
	body.set_meta("center", center)
	body.set_meta("phase", rng.randf_range(0, TAU))
	body.set_meta("swim_speed", rng.randf_range(0.9, 1.45))
	body.set_meta("radius", rng.randf_range(3.8, 7.2))
	body.set_meta("stun_timer", 0.0)
	body.set_meta("dead", false)
	add_child(body)

	var creature := model("fish_small", Vector3.ZERO, size)
	creature.reparent(body, false)

	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.85
	collision.shape = sphere
	body.add_child(collision)

	fish.append(body)
	small_fish.append(body)

func _spawn_neutral_fish(center: Vector3, size: float) -> void:
	var creature := model("fish", center, size)
	creature.set_meta("kind", "fish")
	creature.set_meta("name", "珊瑚游鱼")
	creature.set_meta("center", center)
	creature.set_meta("phase", rng.randf_range(0, TAU))
	creature.set_meta("swim_speed", rng.randf_range(0.8, 1.3))
	creature.set_meta("radius", rng.randf_range(5.0, 9.0))
	creature.set_meta("stun_timer", 0.0)
	creature.set_meta("dead", false)
	fish.append(creature)

func _spawn_predator(kind: String, center: Vector3, size: float) -> void:
	var is_shark: bool = kind == "predator"
	var model_name: String = "fish_predator" if is_shark else "fish_abyss"
	var creature := model(model_name, center, size)
	creature.set_meta("kind", kind)
	creature.set_meta("name", "深海巨鲨" if is_shark else "深渊巨兽")
	creature.set_meta("center", center)
	creature.set_meta("phase", rng.randf_range(0, TAU))
	creature.set_meta("health", 120.0 if is_shark else 170.0)
	creature.set_meta("max_health", 120.0 if is_shark else 170.0)
	creature.set_meta("damage", 22.0 if is_shark else 35.0)
	creature.set_meta("detect_radius", 32.0 if is_shark else 25.0)
	creature.set_meta("attack_radius", 3.2 if is_shark else 3.8)
	creature.set_meta("speed", 6.6 if is_shark else 5.4)
	creature.set_meta("patrol_speed", 2.2 if is_shark else 1.8)
	creature.set_meta("bite_cooldown", 0.0)
	creature.set_meta("stun_timer", 0.0)
	creature.set_meta("dead", false)
	creature.set_meta("state", "patrol")
	creature.set_meta("flee_timer", 0.0)
	fish.append(creature)
	predators.append(creature)

func remove_small_fish(body: Node3D) -> void:
	if small_fish.has(body):
		small_fish.erase(body)
	if fish.has(body):
		fish.erase(body)
	body.queue_free()

func tick_predators(diver_pos: Vector3, delta: float, flashlight_on: bool = false) -> Array[Dictionary]:
	var bites: Array[Dictionary] = []
	for p: Node3D in predators:
		if not is_instance_valid(p):
			continue
		if bool(p.get_meta("dead", false)) or float(p.get_meta("stun_timer", 0.0)) > 0.0:
			continue

		var bite_cd: float = float(p.get_meta("bite_cooldown", 0.0))
		if bite_cd > 0.0:
			p.set_meta("bite_cooldown", maxf(0.0, bite_cd - delta))

		var flee_t: float = float(p.get_meta("flee_timer", 0.0))
		var dist: float = p.global_position.distance_to(diver_pos)
		var detect_r: float = float(p.get_meta("detect_radius"))
		var attack_r: float = float(p.get_meta("attack_radius"))
		var speed: float = float(p.get_meta("speed"))
		var center: Vector3 = p.get_meta("center")

		# Tactical flee state when struck by diver weapons
		if flee_t > 0.0:
			p.set_meta("flee_timer", maxf(0.0, flee_t - delta))
			p.set_meta("state", "flee")
			var away := (p.global_position - diver_pos).normalized()
			p.position += away * (speed * 1.3) * delta
			if away.length_squared() > 0.001:
				var up := Vector3.UP if absf(away.y) < 0.95 else Vector3.FORWARD
				p.look_at(p.global_position + away, up, true)
			continue

		if dist < detect_r:
			# Three-stage AI: Warning circle (11~24m without flashlight) vs Active Hunt Strike
			if dist > 11.0 and not flashlight_on:
				p.set_meta("state", "warn")
				var phase_val: float = float(p.get_meta("phase", 0.0))
				var orbit_t: float = clock * 1.4 + phase_val
				var orbit_target := diver_pos + Vector3(sin(orbit_t) * 14.5, sin(orbit_t * 1.6) * 2.2, cos(orbit_t) * 14.5)
				p.position = p.position.move_toward(orbit_target, speed * 0.9 * delta)
				var to_d := (diver_pos - p.global_position).normalized()
				if to_d.length_squared() > 0.001:
					var up_w := Vector3.UP if absf(to_d.y) < 0.95 else Vector3.FORWARD
					p.look_at(p.global_position + to_d, up_w, true)
			else:
				p.set_meta("state", "hunt")
				var to_diver := (diver_pos - p.global_position).normalized()
				p.position += to_diver * (speed * 1.15) * delta
				if to_diver.length_squared() > 0.001:
					var up := Vector3.UP if absf(to_diver.y) < 0.95 else Vector3.FORWARD
					p.look_at(p.global_position + to_diver, up, true)
				if dist < attack_r and bite_cd <= 0.0:
					p.set_meta("bite_cooldown", 2.8)
					p.set_meta("flee_timer", 1.8) # Brief tactical disengagement after bite
					bites.append({
						"name": str(p.get_meta("name")),
						"damage": float(p.get_meta("damage")),
						"pos": p.global_position
					})
		else:
			p.set_meta("state", "patrol")
			var phase: float = float(p.get_meta("phase"))
			var patrol_spd: float = float(p.get_meta("patrol_speed"))
			var t: float = clock * patrol_spd * 0.2 + phase
			var orbit_r: float = 14.0 if str(p.get_meta("kind")) == "predator" else 10.0
			var target_pos := center + Vector3(sin(t) * orbit_r, sin(t * 1.8) * 2.5, cos(t) * (orbit_r * 0.75))
			var move_dir := (target_pos - p.position).normalized()
			p.position = p.position.move_toward(target_pos, patrol_spd * delta * 4.0)
			if move_dir.length_squared() > 0.001:
				var up := Vector3.UP if absf(move_dir.y) < 0.95 else Vector3.FORWARD
				p.look_at(p.position + move_dir, up, true)

	return bites

func _tick_status(n: Node3D, delta: float) -> bool:
	if not is_instance_valid(n):
		return true
	if bool(n.get_meta("dead", false)):
		n.position.y = minf(0.0, n.position.y + 6.0 * delta)
		n.rotation.z = move_toward(n.rotation.z, PI, delta * 2.2)
		return true
	var stun: float = float(n.get_meta("stun_timer", 0.0))
	if stun > 0.0:
		n.set_meta("stun_timer", maxf(0.0, stun - delta))
		n.rotation.z += sin(clock * 25.0) * 0.03
		return true
	return false

func strike_predator(from: Vector3, dir: Vector3, max_range: float, damage: float, knockback: float, is_sonic: bool, max_targets: int = 99, cleave_angle: float = -1.0) -> Dictionary:
	var angle_threshold: float = cleave_angle
	if angle_threshold < 0.0:
		angle_threshold = 0.35 if is_sonic else 0.76

	var candidates: Array[Dictionary] = []
	var living: Array[Node3D] = []
	living.append_array(fish)
	living.append_array(jellies)
	for p: Node3D in living:
		if not is_instance_valid(p) or bool(p.get_meta("dead", false)):
			continue
		var to_p := p.global_position - from
		var dist := to_p.length()
		if dist > max_range:
			continue
		var norm_to_p := to_p / maxf(dist, 0.001)
		var angle_dot := dir.dot(norm_to_p)
		if angle_dot >= angle_threshold:
			candidates.append({"target": p, "dist": dist, "dir": norm_to_p})

	if candidates.is_empty():
		return {}

	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["dist"] < b["dist"])

	var hit_count: int = 0
	var killed_names: Array[String] = []
	var hit_names: Array[String] = []
	var primary_target_info: Dictionary = {}
	var dropped_items: Array[Dictionary] = []

	var targets_to_process: int = mini(candidates.size(), max_targets)
	for i in range(targets_to_process):
		var item: Dictionary = candidates[i]
		var p: Node3D = item["target"]
		if not is_instance_valid(p):
			continue

		var p_name: String = str(p.get_meta("name", "海洋生物"))
		var p_kind: String = str(p.get_meta("kind", ""))
		var knock_dir := dir.normalized()
		p.position += knock_dir * knockback
		p.position.y = clampf(p.position.y, floor_height(p.position.x, p.position.z) + 1.2, 0.0)

		hit_count += 1
		hit_names.append(p_name)

		var killed := false
		if is_sonic:
			p.set_meta("stun_timer", 3.2)
			p.set_meta("flee_timer", 4.2)
		else:
			killed = true
			p.set_meta("flee_timer", 3.2)
			killed_names.append(p_name)
			if p_kind == "predator" or p_kind == "abyss":
				var frag_kind := "shark_fragment" if p_kind == "predator" else "abyss_fragment"
				var drop_node := _spawn_fragment(frag_kind, p.global_position)
				dropped_items.append({
					"kind": frag_kind,
					"name": FRAGMENT_NAMES.get(frag_kind, "身体碎片"),
					"node": drop_node,
					"pos": p.global_position
				})
				predators.erase(p)
				fish.erase(p)
				p.queue_free()
			else:
				p.set_meta("dead", true)
				p.set_meta("health", 0.0)

		if i == 0:
			primary_target_info = {
				"hit": true,
				"name": p_name,
				"damage": damage,
				"killed": killed,
				"health_left": maxf(0.0, float(p.get_meta("health", 0.0))) if is_instance_valid(p) else 0.0,
				"is_sonic": is_sonic
			}

	primary_target_info["hit_count"] = hit_count
	primary_target_info["hit_names"] = hit_names
	primary_target_info["killed_names"] = killed_names
	primary_target_info["dropped_items"] = dropped_items
	return primary_target_info
func _spawn_fragment(kind: String, at: Vector3) -> Node3D:
	var body := StaticBody3D.new()
	body.name = "Fragment_" + kind
	body.position = at
	body.collision_layer = 2
	body.set_meta("kind", kind)
	body.set_meta("initial_y", at.y)
	body.set_meta("bob_phase", rng.randf_range(0.0, TAU))
	add_child(body)

	# Visual representation: distinct glowing geometry
	var mesh_inst := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	if kind == "shark_fragment":
		# Shark tooth shard: sharp triangular prism with azure bio-luminescence
		var prism := PrismMesh.new()
		prism.size = Vector3(0.55, 0.75, 0.35)
		mesh_inst.mesh = prism
		mat.albedo_color = Color(0.2, 0.9, 1.0, 0.95)
	else:
		# Abyssal bio-crystal: prismatic octahedron / cylinder crystal with violet radiance
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.15
		cyl.bottom_radius = 0.42
		cyl.height = 0.85
		cyl.radial_segments = 6
		mesh_inst.mesh = cyl
		mat.albedo_color = Color(0.85, 0.35, 1.0, 0.95)

	mesh_inst.material_override = mat
	body.add_child(mesh_inst)

	# Radiant beacon light to ensure high visibility in deep water
	var light := OmniLight3D.new()
	light.light_color = Color(0.3, 0.85, 1.0) if kind == "shark_fragment" else Color(0.85, 0.4, 1.0)
	light.light_energy = 4.0
	light.omni_range = 14.0
	light.omni_attenuation = 0.75
	body.add_child(light)

	# Interaction collision volume for diver targeting (E key)
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.3
	collision.shape = sphere
	body.add_child(collision)

	fragments.append(body)
	resources.append(body) # Also register in resources so raycast finds it
	return body

func remove_fragment(body: Node3D) -> void:
	if fragments.has(body):
		fragments.erase(body)
	if resources.has(body):
		resources.erase(body)
	if is_instance_valid(body):
		body.queue_free()

func _spawn_resource(kind: String, at: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "Resource_" + kind
	body.position = at
	body.collision_layer = 2
	body.set_meta("kind", kind)
	add_child(body)
	var asset := model("resource_" + kind, Vector3.ZERO)
	asset.reparent(body, false)
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.8
	collision.shape = sphere
	collision.position.y = 0.4
	body.add_child(collision)
	resources.append(body)

func _create_particles() -> void:
	var particles := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var sphere := SphereMesh.new()
	sphere.radius = 0.03
	sphere.height = 0.06
	sphere.radial_segments = 4
	sphere.rings = 2
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.36, 0.72, 0.68)
	sphere.material = mat
	mm.mesh = sphere
	mm.instance_count = 450
	for i in range(mm.instance_count):
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(rng.randf_range(-180, 180), rng.randf_range(-95, 0), rng.randf_range(-230, 80))))
	particles.multimesh = mm
	add_child(particles)

func _process(delta: float) -> void:
	clock += delta

	for creature in fish:
		_tick_status(creature, delta)
	for jelly in jellies:
		_tick_status(jelly, delta)

	# 1. Neutral fish swimming
	for creature in fish:
		if not is_instance_valid(creature) or creature in small_fish or creature in predators:
			continue
		if bool(creature.get_meta("dead", false)) or float(creature.get_meta("stun_timer", 0.0)) > 0.0:
			continue
		var center: Vector3 = creature.get_meta("center")
		var t: float = clock * 0.24 + float(creature.get_meta("phase"))
		var rad: float = float(creature.get_meta("radius", 6.0))
		var next := center + Vector3(sin(t) * rad, sin(t * 2.0) * 0.8, cos(t) * (rad * 0.66))
		var direction := next - creature.position
		if direction.length_squared() > 0.00001:
			var up := Vector3.UP if absf(direction.normalized().y) < 0.95 else Vector3.FORWARD
			creature.look_at(creature.position + direction, up, true)
		creature.position = next

	# 2. Small edible fish swimming
	for sfish in small_fish:
		if not is_instance_valid(sfish):
			continue
		if bool(sfish.get_meta("dead", false)) or float(sfish.get_meta("stun_timer", 0.0)) > 0.0:
			continue
		var center: Vector3 = sfish.get_meta("center")
		var phase: float = float(sfish.get_meta("phase"))
		var spd: float = float(sfish.get_meta("swim_speed"))
		var rad: float = float(sfish.get_meta("radius"))
		var t: float = clock * spd * 0.4 + phase
		var next := center + Vector3(sin(t) * rad, sin(t * 2.2) * 0.8, cos(t) * (rad * 0.7))
		var dir := next - sfish.position
		if dir.length_squared() > 0.0001:
			var up := Vector3.UP if absf(dir.normalized().y) < 0.95 else Vector3.FORWARD
			sfish.look_at(sfish.position + dir, up, true)
		sfish.position = next

	# 3. Vent light subtle geothermal flicker
	for light in vent_lights:
		light.light_energy = 5.2 + sin(clock * 4.5 + light.position.x) * 0.55

	# 4. Deep-sea jellyfish biological pulsating drift
	for jelly in jellies:
		if not is_instance_valid(jelly) or bool(jelly.get_meta("dead", false)) or float(jelly.get_meta("stun_timer", 0.0)) > 0.0:
			continue
		var center: Vector3 = jelly.get_meta("center")
		var phase: float = float(jelly.get_meta("phase"))
		var drift_speed: float = float(jelly.get_meta("drift_speed"))
		var t: float = clock * drift_speed + phase
		var pulse_t: float = clock * 2.2 + phase * 1.8
		var next := center + Vector3(sin(t) * 5.0, sin(pulse_t) * 1.1, cos(t * 0.75) * 4.5)
		jelly.position = next
		var contraction: float = sin(pulse_t)
		jelly.scale = Vector3(1.0 + contraction * 0.08, 1.0 - contraction * 0.12, 1.0 + contraction * 0.08)

	# 5. Dropped biological fragments rise to the surface, then bob
	for frag in fragments:
		if not is_instance_valid(frag):
			continue
		var bphase: float = float(frag.get_meta("bob_phase", 0.0))
		if frag.position.y < -0.2:
			frag.position.y = minf(-0.05, frag.position.y + 6.0 * delta)
		else:
			frag.position.y = sin(clock * 1.8 + bphase) * 0.15
		frag.rotate_y(delta * 1.5)
func set_depth(depth: float) -> void:
	var depth_ratio := clampf(depth / 90.0, 0.0, 1.0)
	environment.fog_density = lerpf(0.010, 0.026, depth_ratio)
	environment.background_mode = Environment.BG_SKY if depth < 0.05 else Environment.BG_COLOR
	environment.fog_sky_affect = 0.0 if depth < 0.05 else 1.0

	var shallow_fog := Color(0.075, 0.43, 0.47)
	var mid_fog := Color(0.022, 0.16, 0.26)
	var deep_fog := Color(0.005, 0.018, 0.034)
	if depth < 32.0:
		environment.fog_light_color = shallow_fog.lerp(mid_fog, depth / 32.0)
	else:
		environment.fog_light_color = mid_fog.lerp(deep_fog, clampf((depth - 32.0) / 50.0, 0.0, 1.0))

	var shallow_bg := Color(0.035, 0.29, 0.36)
	var deep_bg := Color(0.003, 0.014, 0.025)
	environment.background_color = shallow_bg.lerp(deep_bg, depth_ratio)
	environment.ambient_light_energy = lerpf(0.65, 0.07, depth_ratio)

	if is_instance_valid(sun):
		sun.light_energy = lerpf(1.35, 0.0, clampf(depth / 42.0, 0.0, 1.0))
