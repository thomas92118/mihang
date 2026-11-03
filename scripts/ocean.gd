extends Node3D

signal boss_encounter_started
signal boss_defeated
signal all_bosses_conquered
signal mother_tree_spawned

const MarineCreature = preload("res://scripts/marine_creature.gd")
const Submarine = preload("res://scripts/submarine.gd")
const BOSS_ARENA_CENTER := Vector3(-50, -76, -170)
const BOSS_TRIGGER_RADIUS := 36.0
const BOSS_MAX_HEALTH := 1800.0

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
var neutral_fish: Array[Node3D] = []
var predators: Array[Node3D] = []
var rng := RandomNumberGenerator.new()
var clock: float = 0.0
var cache: Dictionary = {}
var plant_materials: Dictionary = {}
var vent_lights: Array[OmniLight3D] = []
var jellies: Array[Node3D] = []

# New marine life and environment systems
var rays: Array[Node3D] = []
var turtles: Array[Node3D] = []
var squids: Array[Node3D] = []
var crabs: Array[Node3D] = []
var tubeworm_colonies: Array[Node3D] = []
var sea_fans: Array[Node3D] = []
var starfish: Array[Node3D] = []
var dynamic_plants: Array[Node3D] = []
var last_diver_pos: Vector3 = Vector3(0, -9, 17)
var sea_spiders: Array[Node3D] = []
var seals: Array[Node3D] = []
var submarines: Array[Node3D] = []
var water_dragon: Node3D
var flying_fish_boss: Node3D
var kraken_boss: Node3D
var turtle_boss: Node3D
var boss_nodes: Dictionary = {}
var boss_arena_centers: Dictionary = {}
var active_boss_id: String = "water_dragon"
var active_boss_node: Node3D = null
var boss_active := false
var boss_slain := false
var boss_action := "circle"
var boss_action_timer := 3.0
var boss_cycle := 0
var boss_charge_direction := Vector3.FORWARD
var boss_warning := ""
var scope_view_enabled := false
var scope_meshes: Array[MeshInstance3D] = []
var conquered_bosses: Dictionary = {}
var mother_tree: Node3D = null
var mother_tree_spawned_flag := false
var mother_tree_items: Array[Node3D] = []
var sea_wolves: Array[Node3D] = []
var schooling_fish: Array[Node3D] = []
var fish_schools: Array[Dictionary] = []
var escape_console: Node3D = null

var plant_shader: Shader = preload("res://shaders/plant_sway.gdshader")

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
	if z < -240.0:
		var deep_trench: float = clampf((-z - 240.0) / 90.0, 0.0, 1.0)
		depth_tier -= deep_trench * 32.0

	var x_dist: float = absf(x)
	if x_dist > 85.0:
		var x_slope: float = clampf((x_dist - 85.0) / 85.0, 0.0, 1.0)
		depth_tier -= x_slope * x_slope * 45.0

	return -16.0 + depth_tier + base_hills + micro_detail

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
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
	plane.subdivide_width = 80
	plane.subdivide_depth = 68
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
	for x in range(-280, 280, 6):
		for z in range(-380, 140, 6):
			var points := [Vector2(x, z), Vector2(x + 6, z), Vector2(x, z + 6), Vector2(x + 6, z + 6)]
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

func model(asset: String, at: Vector3, size: float = 1.0, visibility_range: float = 48.0) -> Node3D:
	if not cache.has(asset):
		cache[asset] = load("res://assets/models/" + asset + ".glb")
	var instance: Node3D = cache[asset].instantiate()
	add_child(instance)
	instance.position = at
	instance.scale = Vector3.ONE * size
	if visibility_range > 0.0:
		for child in instance.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = child
			mi.visibility_range_end = visibility_range
			mi.set_meta("base_visibility_range", visibility_range)
			scope_meshes.append(mi)
			mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	var players := instance.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		var player: AnimationPlayer = players[0]
		var base_clip := "pulse" if asset == "jellyfish" else ("walk" if asset == "crab" else "swim")
		for clip in player.get_animation_list():
			if clip in ["swim", "pulse", "walk", "defend"]:
				player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		instance.set_meta("animation_player", player)
		instance.set_meta("base_animation", base_clip)
		player.play(base_clip)
		player.seek(rng.randf() * player.get_animation(base_clip).length, true)
	return instance

func apply_plant_shader(node: Node3D, sway_str: float = 0.35, sway_freq: float = 1.25, asset_key: String = "") -> void:
	for child in node.find_children("*", "MeshInstance3D"):
		var mesh_inst: MeshInstance3D = child
		if not mesh_inst.mesh:
			continue
		for s in range(mesh_inst.mesh.get_surface_count()):
			var cache_key := "%s_%d_%.2f_%.2f" % [asset_key, s, sway_str, sway_freq]
			var sm: ShaderMaterial = plant_materials.get(cache_key, null)
			if sm == null or asset_key == "":
				var orig_mat = mesh_inst.mesh.surface_get_material(s)
				sm = ShaderMaterial.new()
				sm.shader = plant_shader
				if orig_mat is BaseMaterial3D:
					sm.set_shader_parameter("albedo", orig_mat.albedo_color)
					sm.set_shader_parameter("roughness", orig_mat.roughness)
					sm.set_shader_parameter("metallic", orig_mat.metallic)
					sm.set_shader_parameter("albedo_texture", orig_mat.albedo_texture)
					sm.set_shader_parameter("normal_texture", orig_mat.normal_texture)
					sm.set_shader_parameter("normal_scale", orig_mat.normal_scale)
					sm.set_shader_parameter("orm_texture", orig_mat.roughness_texture)
					sm.set_shader_parameter("uv_scale", orig_mat.uv1_scale)
					sm.set_shader_parameter("uv_offset", orig_mat.uv1_offset)
					if orig_mat.emission_enabled:
						sm.set_shader_parameter("emission", orig_mat.emission)
						sm.set_shader_parameter("emission_energy", orig_mat.emission_energy_multiplier)
						sm.set_shader_parameter("emission_texture", orig_mat.emission_texture)
				sm.set_shader_parameter("sway_strength", sway_str)
				sm.set_shader_parameter("sway_frequency", sway_freq)
				if asset_key != "":
					plant_materials[cache_key] = sm
			mesh_inst.set_surface_override_material(s, sm)

func _update_creature_animation(node: Node3D) -> void:
	if not node.has_meta("animation_player"):
		return
	var player: AnimationPlayer = node.get_meta("animation_player", null)
	if not is_instance_valid(player):
		return
	if _is_immobile(node):
		if player.is_playing():
			player.pause()
		return

	# Distance-based animation LOD: pause bone matrix evaluations outside diver visual range (>30m)
	var dist_sq: float = node.global_position.distance_squared_to(last_diver_pos)
	var animation_distance := 160.0 if scope_view_enabled else 30.0
	if dist_sq > animation_distance * animation_distance:
		if player.is_playing():
			player.pause()
		return

	if player.assigned_animation == "bite" and player.is_playing():
		return
	var clip: String = node.get_meta("base_animation", "swim")
	if clip == "walk" and bool(node.get_meta("defensive", false)):
		clip = "defend"
	if player.assigned_animation != clip or not player.is_playing():
		player.play(clip, 0.15)
	var state: String = node.get_meta("state", "patrol")
	player.speed_scale = 1.5 if state in ["hunt", "flee"] else 1.0
	if float(node.get_meta("fright_timer", 0.0)) > 0.0:
		player.speed_scale = 2.2

func _populate() -> void:
	# 1. 逃生舱 (Lifepod at HOME)
	var pod := model("pod", HOME, 1.0, 95.0)
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
	marker.font = preload("res://assets/fonts/NotoSansSC-Subset.otf")
	marker.text = "◇  LIFEPOD  /  逃生舱"
	marker.position = HOME + Vector3(0, 6.5, 0)
	marker.font_size = 48
	marker.pixel_size = 0.009
	marker.modulate = Color(0.65, 1.0, 0.9)
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.no_depth_test = true
	add_child(marker)

	# Central Escape Console at Lifepod (中央逃生控制台)
	escape_console = Node3D.new()
	escape_console.name = "EscapeConsole"
	escape_console.position = HOME + Vector3(2.2, 0.4, 1.4)
	escape_console.set_meta("kind", "escape_console")
	escape_console.set_meta("name", "中央逃生控制台")
	var console_body := StaticBody3D.new()
	var console_col := CollisionShape3D.new()
	var col_box := BoxShape3D.new()
	col_box.size = Vector3(1.4, 1.6, 1.2)
	console_col.shape = col_box
	console_body.add_child(console_col)
	escape_console.add_child(console_body)
	var c_base := MeshInstance3D.new()
	var b_box := BoxMesh.new()
	b_box.size = Vector3(1.2, 1.2, 0.9)
	c_base.mesh = b_box
	var c_mat := StandardMaterial3D.new()
	c_mat.albedo_color = Color(0.12, 0.16, 0.22)
	c_mat.metallic = 0.8
	c_mat.roughness = 0.3
	c_base.material_override = c_mat
	escape_console.add_child(c_base)
	var screen_mesh := MeshInstance3D.new()
	var s_quad := QuadMesh.new()
	s_quad.size = Vector2(0.9, 0.6)
	screen_mesh.mesh = s_quad
	screen_mesh.position = Vector3(0, 0.65, 0.3)
	screen_mesh.rotation_degrees = Vector3(-35, 0, 0)
	var s_mat := StandardMaterial3D.new()
	s_mat.albedo_color = Color(0.08, 0.45, 0.85)
	s_mat.emission_enabled = true
	s_mat.emission = Color(0.15, 0.85, 1.0)
	s_mat.emission_energy_multiplier = 2.4
	screen_mesh.material_override = s_mat
	escape_console.add_child(screen_mesh)
	var c_light := OmniLight3D.new()
	c_light.position = Vector3(0, 1.0, 0.4)
	c_light.light_color = Color(0.2, 0.9, 1.0)
	c_light.light_energy = 2.5
	c_light.omni_range = 8.0
	escape_console.add_child(c_light)
	var c_label := Label3D.new()
	c_label.font = preload("res://assets/fonts/NotoSansSC-Subset.otf")
	c_label.text = "⬡  ESCAPE CONSOLE  /  逃生控制台"
	c_label.position = Vector3(0, 1.6, 0)
	c_label.font_size = 32
	c_label.pixel_size = 0.007
	c_label.modulate = Color(0.3, 0.95, 1.0)
	c_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	c_label.no_depth_test = true
	escape_console.add_child(c_label)
	add_child(escape_console)

	# 2. 浅海与海沟古代遗迹拱门
	var arch := model("ruins", Vector3(2, floor_height(2, -25), -25), 1.4, 95.0)
	arch.rotation.y = 0.15
	for child in arch.find_children("*", "MeshInstance3D"):
		child.create_trimesh_collision()
	var arch_marker := _create_marker("◈  ANCIENT RUINS  /  古代海沟遗迹", Vector3(2, floor_height(2, -25) + 6.0, -25), Color(0.4, 0.9, 0.8))
	add_child(arch_marker)

	# 3. 深渊古代巨石祭坛
	var altar_pos := Vector3(-50, floor_height(-50, -170), -170)
	var altar := model("ruins", altar_pos, 1.8, 95.0)
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
	var wreck := model("shipwreck", wreck_pos, 1.35, 95.0)
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
	bb_label.font = preload("res://assets/fonts/NotoSansSC-Subset.otf")
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

	# 6.0 潜水艇海面上方浮泊部署 (根据指令全部调整至海面上方停泊)
	# 深海斥候号 (海面浅礁船坞)
	var scout_sub := Submarine.new()
	scout_sub.configure("scout")
	scout_sub.position = Vector3(25, 0.45, 18)
	scout_sub.rotation.y = -PI * 0.4
	add_child(scout_sub)
	submarines.append(scout_sub)
	_create_nav_buoy(Vector3(25, 0.2, 18), "⚓  SCOUT SUB DOCK  /  深海斥候号海面停泊处")

	# 泰坦远征号 (海面系泊浮标)
	var titan_sub := Submarine.new()
	titan_sub.configure("titan")
	titan_sub.position = Vector3(-60, 0.65, -95)
	titan_sub.rotation.y = PI * 0.25
	add_child(titan_sub)
	submarines.append(titan_sub)
	_create_nav_buoy(Vector3(-60, 0.2, -95), "⚓  TITAN MOORING  /  泰坦巨型核潜艇海面系泊区")

	# 微型脉冲潜艇 (竖椭圆机体，逃生舱近邻海面停泊)
	var mini_sub := Submarine.new()
	mini_sub.configure("mini")
	mini_sub.position = Vector3(-14, 0.35, 12)
	mini_sub.rotation.y = PI * 0.15
	add_child(mini_sub)
	submarines.append(mini_sub)
	_create_nav_buoy(Vector3(-14, 0.2, 12), "⚓  MINI EMP SUB  /  微型脉冲潜艇海面停泊处")

	# 6.1 新增区域 1：碧蓝晶簇海盆
	var basin_center := Vector3(95, floor_height(95, -30), -30)
	for i in range(8):
		var angle: float = float(i) * TAU / 8.0
		var cx: float = 95.0 + cos(angle) * 16.0
		var cz: float = -30.0 + sin(angle) * 16.0
		var spire := model("crystal_spire", Vector3(cx, floor_height(cx, cz) - 0.2, cz), rng.randf_range(1.5, 2.4), 65.0)
		spire.rotation.y = angle
	var basin_light := OmniLight3D.new()
	basin_light.position = basin_center + Vector3(0, 4.5, 0)
	basin_light.light_color = Color(0.15, 0.85, 1.0)
	basin_light.light_energy = 5.0
	basin_light.omni_range = 28.0
	add_child(basin_light)
	var basin_marker := _create_marker("◈  CRYSTAL BASIN  /  碧蓝晶簇海盆", basin_center + Vector3(0, 8.5, 0), Color(0.25, 0.9, 1.0))
	add_child(basin_marker)

	# 6.2 新增区域 2：深渊重装造船厂
	var yard_center := Vector3(-110, floor_height(-110, -185), -185)
	var dock_arch := model("ruins", yard_center, 2.4, 95.0)
	dock_arch.rotation.y = PI * 0.25
	for child in dock_arch.find_children("*", "MeshInstance3D"):
		child.create_trimesh_collision()
	_create_hydrothermal_vent(yard_center + Vector3(-16, 0, 10))
	_create_hydrothermal_vent(yard_center + Vector3(18, 0, -12))
	var yard_beacon := OmniLight3D.new()
	yard_beacon.position = yard_center + Vector3(0, 14.0, 0)
	yard_beacon.light_color = Color(1.0, 0.55, 0.15)
	yard_beacon.light_energy = 6.5
	yard_beacon.omni_range = 45.0
	add_child(yard_beacon)
	var yard_marker := _create_marker("⚓  ABYSSAL SHIPYARD  /  深渊重装造船厂", yard_center + Vector3(0, 18.0, 0), Color(1.0, 0.65, 0.25))
	add_child(yard_marker)

	# 6.3 新增区域 3：海妖磷光珊瑚林 (幽绿珊瑚海谷，密布巨型发光海葵与鬼蝠鲼群)
	var grove_center := Vector3(-85, floor_height(-85, -50), -50)
	for i in range(14):
		var gx: float = rng.randf_range(-102, -68)
		var gz: float = rng.randf_range(-64, -36)
		var gy: float = floor_height(gx, gz)
		model("anemone", Vector3(gx, gy, gz), rng.randf_range(1.6, 2.8), 45.0)
		if i % 2 == 0:
			model("sea_fan", Vector3(gx + 1.5, gy, gz - 1.2), rng.randf_range(1.3, 2.2), 45.0)
		if i % 3 == 0:
			model("tube_coral", Vector3(gx + 2.0, gy, gz), rng.randf_range(1.2, 1.8), 45.0)
	var grove_light := OmniLight3D.new()
	grove_light.position = grove_center + Vector3(0, 5.0, 0)
	grove_light.light_color = Color(0.2, 1.0, 0.65)
	grove_light.light_energy = 4.2
	grove_light.omni_range = 30.0
	add_child(grove_light)
	var grove_marker := _create_marker("❊  PHOSPHOR GROVES  /  海妖磷光珊瑚林", grove_center + Vector3(0, 8.5, 0), Color(0.35, 1.0, 0.7))
	add_child(grove_marker)

	# 6.4 极境生态隔离边界 (外圈隔离浮标，边界之外即为真正的外面世界)
	for i in range(16):
		var ang: float = float(i) * TAU / 16.0
		var bx: float = cos(ang) * 218.0
		var bz: float = sin(ang) * 220.0
		var pylon := _create_marker("⚠️  生态隔离屏障  /  边界之外为深蓝外洋", Vector3(bx, 1.5, bz), Color(1.0, 0.35, 0.2))
		add_child(pylon)
		var p_light := OmniLight3D.new()
		p_light.position = Vector3(bx, 0.5, bz)
		p_light.light_color = Color(1.0, 0.28, 0.15) if (i % 2 == 0) else Color(0.25, 0.85, 1.0)
		p_light.light_energy = 3.5
		p_light.omni_range = 22.0
		add_child(p_light)

	# 7. 岩石分布 (覆盖浅海、斜坡与深海，采用轻量化球体碰撞体消除 37 万个凹网格碰撞面)
	for i in range(110):
		var x: float = rng.randf_range(-190, 190)
		var z: float = rng.randf_range(-240, 80)
		if absf(x) < 8 and z > -30 and z < 15:
			continue
		var r_scale: float = rng.randf_range(0.8, 3.2)
		var rock := model("rock", Vector3(x, floor_height(x, z) - 0.3, z), r_scale, 48.0)
		rock.rotation.y = rng.randf_range(0, TAU)
		var sb := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = r_scale * 1.5
		col.shape = sphere
		col.position.y = r_scale * 0.7
		sb.add_child(col)
		rock.add_child(sb)

	# 8. 植被与珊瑚分布 (带 GPU 顶点海流摆荡 Shader)
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
		var plant := model(asset, Vector3(x, floor_height(x, z), z), rng.randf_range(0.8, 2.0), 36.0)
		plant.rotation.y = rng.randf_range(0, TAU)
		apply_plant_shader(plant, 0.36, 1.25, asset)
		dynamic_plants.append(plant)

	for p in [Vector3(-7, 0, 2), Vector3(8, 0, -5), Vector3(-9, 0, -16)]:
		var c := model("coral", Vector3(p.x, floor_height(p.x, p.z), p.z), 1.5, 36.0)
		apply_plant_shader(c, 0.28, 1.3, "coral")
		dynamic_plants.append(c)

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
		var anemone := model("anemone", Vector3(x, floor_height(x, z), z), rng.randf_range(0.85, 1.6), 32.0)
		anemone.rotation.y = rng.randf_range(0, TAU)
		apply_plant_shader(anemone, 0.26, 1.45, "anemone")
		dynamic_plants.append(anemone)

	# 10. 深渊地热结晶石柱群 (轻量圆柱碰撞体替代凹网格碰撞体)
	for i in range(18):
		var x: float = rng.randf_range(-80, 80)
		var z: float = rng.randf_range(-210, -115)
		var spire_pos := Vector3(x, floor_height(x, z) - 0.2, z)
		var s_scale: float = rng.randf_range(0.95, 1.8)
		var spire := model("crystal_spire", spire_pos, s_scale, 65.0)
		spire.rotation.y = rng.randf_range(0, TAU)
		var sb := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.height = s_scale * 4.8
		cyl.radius = s_scale * 0.9
		col.shape = cyl
		col.position.y = s_scale * 2.4
		sb.add_child(col)
		spire.add_child(sb)
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

	# 14. 新增生态物种与海底环境群落
	_spawn_manta_rays()
	_spawn_sea_turtles()
	_spawn_squids()
	_spawn_crabs()
	_spawn_tubeworm_colonies()
	_spawn_sea_fans()
	_spawn_starfish_urchins()
	_spawn_extra_creatures()
	_spawn_sea_wolves()
	_spawn_schooling_fish()
	for creature in get_creatures():
		_register_creature_hitbox(creature)

	_create_particles()

func _spawn_manta_rays() -> void:
	# 4 只巡弋浅海与暮光大断崖上方的巨型蝠鲼
	var ray_centers := [
		Vector3(35, -12, 12),
		Vector3(-42, -15, -12),
		Vector3(12, -22, -45),
		Vector3(-28, -26, -58)
	]
	for idx in range(ray_centers.size()):
		var center: Vector3 = ray_centers[idx]
		var ray := model("manta_ray", center, rng.randf_range(1.1, 1.45))
		ray.set_meta("kind", "manta_ray")
		ray.set_meta("name", "巨型鬼蝠鲼")
		ray.set_meta("center", center)
		ray.set_meta("phase", rng.randf_range(0, TAU))
		ray.set_meta("radius", rng.randf_range(20.0, 32.0))
		ray.set_meta("speed", rng.randf_range(0.25, 0.40))
		ray.set_meta("stun_timer", 0.0)
		ray.set_meta("dead", false)
		rays.append(ray)

func _spawn_sea_turtles() -> void:
	# 6 只在浅海珊瑚与海藻林间温和巡游的海龟
	var turtle_centers := [
		Vector3(-18, -8, 14),
		Vector3(22, -10, -8),
		Vector3(-8, -14, -22),
		Vector3(16, -11, 22),
		Vector3(-32, -16, 8),
		Vector3(28, -15, -18)
	]
	for idx in range(turtle_centers.size()):
		var center: Vector3 = turtle_centers[idx]
		var turtle := model("sea_turtle", center, rng.randf_range(0.9, 1.3))
		turtle.set_meta("kind", "sea_turtle")
		turtle.set_meta("name", "深海绿海龟")
		turtle.set_meta("center", center)
		turtle.set_meta("phase", rng.randf_range(0, TAU))
		turtle.set_meta("radius", rng.randf_range(7.5, 14.0))
		turtle.set_meta("speed", rng.randf_range(0.35, 0.65))
		turtle.set_meta("stun_timer", 0.0)
		turtle.set_meta("dead", false)
		turtles.append(turtle)

func _spawn_squids() -> void:
	# 12 只发光巨乌贼：5 只在暮光大陆坡，7 只在深渊海沟与热泉裂谷
	for i in range(12):
		var center: Vector3
		if i < 5:
			center = Vector3(rng.randf_range(-65, 65), rng.randf_range(-48, -28), rng.randf_range(-85, -42))
		else:
			center = Vector3(rng.randf_range(-70, 70), rng.randf_range(-94, -68), rng.randf_range(-200, -118))
		var squid := model("squid", center, rng.randf_range(0.95, 1.4))
		squid.set_meta("kind", "squid")
		squid.set_meta("name", "深渊发光巨乌贼")
		squid.set_meta("center", center)
		squid.set_meta("phase", rng.randf_range(0, TAU))
		squid.set_meta("radius", rng.randf_range(6.0, 11.0))
		squid.set_meta("speed", rng.randf_range(0.5, 0.85))
		squid.set_meta("stun_timer", 0.0)
		squid.set_meta("dead", false)
		squids.append(squid)

func _spawn_crabs() -> void:
	# 18 只底栖巨蟹贴附于海床岩面与沉船残骸
	for i in range(18):
		var x: float
		var z: float
		if i < 8:
			x = rng.randf_range(-55, 55)
			z = rng.randf_range(-45, 25)
		elif i < 12:
			# 聚集在失事科考潜艇周围
			x = 45.0 + rng.randf_range(-14.0, 14.0)
			z = -55.0 + rng.randf_range(-14.0, 14.0)
		else:
			x = rng.randf_range(-65, 65)
			z = rng.randf_range(-195, -125)
		var y: float = floor_height(x, z)
		var crab := model("crab", Vector3(x, y, z), rng.randf_range(0.75, 1.25))
		crab.rotation.y = rng.randf_range(0, TAU)
		crab.set_meta("kind", "crab")
		crab.set_meta("name", "深海巨螯蟹")
		crab.set_meta("origin_x", x)
		crab.set_meta("origin_z", z)
		crab.set_meta("phase", rng.randf_range(0, TAU))
		crab.set_meta("patrol_radius", rng.randf_range(2.5, 5.5))
		crab.set_meta("defensive", false)
		crab.set_meta("stun_timer", 0.0)
		crab.set_meta("dead", false)
		crabs.append(crab)

func _spawn_tubeworm_colonies() -> void:
	# 14 簇巨型管虫丛密集扎根在 4 座深海地热黑烟囱热泉周围
	var vent_spots := [
		Vector3(15, -165, 0),
		Vector3(-15, -180, 0),
		Vector3(32, -152, 0),
		Vector3(-2, -195, 0)
	]
	for i in range(14):
		var base_spot: Vector3 = vent_spots[i % vent_spots.size()]
		var ox: float = base_spot.x + rng.randf_range(-7.5, 7.5)
		var oz: float = base_spot.y + rng.randf_range(-7.5, 7.5)
		var oy: float = floor_height(ox, oz)
		var colony := model("tubeworms", Vector3(ox, oy, oz), rng.randf_range(0.85, 1.45), 50.0)
		colony.rotation.y = rng.randf_range(0, TAU)
		colony.set_meta("retract_progress", 0.0)
		colony.set_meta("last_retract_applied", -1.0)
		apply_plant_shader(colony, 0.28, 1.45)
		var mats: Array[ShaderMaterial] = []
		for child in colony.find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = child
			for s in range(mi.mesh.get_surface_count()):
				var sm = mi.get_surface_override_material(s)
				if sm is ShaderMaterial:
					mats.append(sm)
		colony.set_meta("shader_materials", mats)
		tubeworm_colonies.append(colony)

func _spawn_sea_fans() -> void:
	# 22 簇扇形海柳珊瑚生长在大陆坡断崖陡壁与浅海交界岩壁
	for i in range(22):
		var x: float = rng.randf_range(-85, 85)
		var z: float = rng.randf_range(-90, -18)
		var y: float = floor_height(x, z)
		var fan := model("sea_fan", Vector3(x, y, z), rng.randf_range(0.85, 1.5), 36.0)
		fan.rotation.y = rng.randf_range(0, TAU)
		apply_plant_shader(fan, 0.38, 1.15, "sea_fan")
		sea_fans.append(fan)

func _spawn_starfish_urchins() -> void:
	# 24 处底栖海星与发光海胆群落附着于浅海与斜坡海床
	for i in range(24):
		var x: float = rng.randf_range(-120, 120)
		var z: float = rng.randf_range(-150, 45)
		var y: float = floor_height(x, z) - 0.05
		var star := model("starfish_urchin", Vector3(x, y, z), rng.randf_range(0.85, 1.35), 30.0)
		star.rotation.y = rng.randf_range(0, TAU)
		starfish.append(star)

func _create_marker(text: String, at: Vector3, color: Color) -> Label3D:
	var marker := Label3D.new()
	marker.font = preload("res://assets/fonts/NotoSansSC-Subset.otf")
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
	body.set_meta("fright_timer", 0.0)
	add_child(body)

	var creature := model("fish_small", Vector3.ZERO, size, 35.0)
	creature.reparent(body, false)
	if creature.has_meta("animation_player"):
		body.set_meta("animation_player", creature.get_meta("animation_player"))
		body.set_meta("base_animation", creature.get_meta("base_animation"))

	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.85
	collision.shape = sphere
	body.add_child(collision)

	fish.append(body)
	small_fish.append(body)

func _spawn_neutral_fish(center: Vector3, size: float) -> void:
	var creature := model("fish", center, size, 42.0)
	creature.set_meta("kind", "fish")
	creature.set_meta("name", "珊瑚游鱼")
	creature.set_meta("center", center)
	creature.set_meta("phase", rng.randf_range(0, TAU))
	creature.set_meta("swim_speed", rng.randf_range(0.8, 1.3))
	creature.set_meta("radius", rng.randf_range(5.0, 9.0))
	creature.set_meta("stun_timer", 0.0)
	creature.set_meta("dead", false)
	creature.set_meta("fright_timer", 0.0)
	fish.append(creature)
	neutral_fish.append(creature)

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
	# 10% 食肉攻击性生物，警戒攻击半径特别小（约5米），避开即安全
	creature.set_meta("detect_radius", 5.2 if is_shark else 5.8)
	creature.set_meta("attack_radius", 2.2 if is_shark else 2.6)
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
	last_diver_pos = diver_pos
	var bites: Array[Dictionary] = []
	for p: Node3D in predators:
		if not is_instance_valid(p):
			continue
		if bool(p.get_meta("tamed", false)):
			continue
		if _is_immobile(p):
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
			if dist > 11.0 and not flashlight_on:
				p.set_meta("state", "warn")
				var phase_val: float = float(p.get_meta("phase", 0.0))
				var orbit_t: float = float(p.get_meta("motion_clock", clock)) * 1.4 + phase_val
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
					p.set_meta("flee_timer", 1.8)
					var player: AnimationPlayer = p.get_meta("animation_player", null)
					if is_instance_valid(player):
						player.speed_scale = 1.0
						player.play("bite", 0.08)
					bites.append({
						"name": str(p.get_meta("name")),
						"damage": float(p.get_meta("damage")),
						"pos": p.global_position
					})
		else:
			p.set_meta("state", "patrol")
			var phase: float = float(p.get_meta("phase"))
			var patrol_spd: float = float(p.get_meta("patrol_speed"))
			var t: float = float(p.get_meta("motion_clock", clock)) * patrol_spd * 0.2 + phase
			var orbit_r: float = 14.0 if str(p.get_meta("kind")) == "predator" else 10.0
			var target_pos := center + Vector3(sin(t) * orbit_r, sin(t * 1.8) * 2.5, cos(t) * (orbit_r * 0.75))
			var move_dir := (target_pos - p.position).normalized()
			p.position = p.position.move_toward(target_pos, patrol_spd * delta * 4.0)
			if move_dir.length_squared() > 0.001:
				var up := Vector3.UP if absf(move_dir.y) < 0.95 else Vector3.FORWARD
				p.look_at(p.position + move_dir, up, true)

	bites.append_array(_tick_sea_spiders(diver_pos, delta))
	bites.append_array(_tick_sea_wolves(diver_pos, delta))
	_tick_seals_vs_sharks(delta)
	check_boss_encounter(diver_pos)
	bites.append_array(_tick_boss(diver_pos, delta))
	return bites

func _tick_status(n: Node3D, delta: float) -> bool:
	if not is_instance_valid(n):
		return true
	_update_creature_animation(n)
	var frozen: float = float(n.get_meta("freeze_timer", 0.0))
	if frozen > 0.0:
		n.set_meta("freeze_timer", maxf(0.0, frozen - delta))
		if frozen <= delta:
			var aura := n.get_node_or_null("StasisAura")
			if is_instance_valid(aura):
				aura.queue_free()
		return true
	if bool(n.get_meta("dead", false)):
		# 击杀后尸体软趴趴沉在海底，便于搜刮
		var seabed := floor_height(n.position.x, n.position.z) + 0.16
		if n.position.y > seabed:
			n.position.y = maxf(seabed, n.position.y - 4.5 * delta)
			n.rotation.z = move_toward(n.rotation.z, 1.15, delta * 1.8)
		return true
	n.set_meta("motion_clock", float(n.get_meta("motion_clock", clock - delta)) + delta)
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
	var living: Array[Node3D] = get_creatures()

	for p: Node3D in living:
		if not is_instance_valid(p) or bool(p.get_meta("dead", false)):
			continue
		if bool(p.get_meta("tamed", false)):
			continue
		if p == water_dragon and not boss_active:
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
	var hit_positions: Array[Vector3] = []
	var hit_kinds: Array[String] = []
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
		hit_positions.append(p.global_position)
		hit_kinds.append(p_kind)
		var knock_dir := dir.normalized()

		hit_count += 1
		hit_names.append(p_name)

		var killed := false
		if is_sonic:
			if float(p.get_meta("freeze_timer", 0.0)) <= 0.0:
				p.position += knock_dir * knockback
			p.set_meta("stun_timer", 3.2)
			p.set_meta("flee_timer", 4.2)
		else:
			var instant_kill := p_kind not in ["water_dragon", "sea_spider", "seal"]
			var result := damage_creature(p, damage, knock_dir * knockback, instant_kill)
			if result.is_empty():
				continue
			killed = bool(result.get("killed", false))
			if killed:
				killed_names.append(p_name)
				dropped_items.append_array(result.get("dropped_items", []))

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
	primary_target_info["hit_positions"] = hit_positions
	primary_target_info["hit_kinds"] = hit_kinds
	return primary_target_info

func get_creatures() -> Array[Node3D]:
	var creatures: Array[Node3D] = []
	for population in [fish, jellies, squids, rays, turtles, crabs, sea_spiders, seals, sea_wolves, schooling_fish]:
		creatures.append_array(population)
	for b_id in boss_nodes:
		if is_instance_valid(boss_nodes[b_id]):
			creatures.append(boss_nodes[b_id])
	return creatures

func get_submarines() -> Array[Node3D]:
	return submarines

func find_nearby_submarine(pos: Vector3, max_dist: float = 7.0) -> Node3D:
	for sub in submarines:
		if not is_instance_valid(sub):
			continue
		var dist: float = pos.distance_to(sub.global_position)
		var threshold: float = float(sub.interact_radius) if ("interact_radius" in sub) else max_dist
		if dist <= threshold:
			return sub
	return null

func _is_immobile(creature: Node3D) -> bool:
	return bool(creature.get_meta("dead", false)) or float(creature.get_meta("stun_timer", 0.0)) > 0.0 or float(creature.get_meta("freeze_timer", 0.0)) > 0.0

func _register_creature_hitbox(creature: Node3D) -> void:
	creature.set_meta("freeze_timer", 0.0)
	creature.set_meta("motion_clock", 0.0)
	if creature is CollisionObject3D:
		return
	var kind: String = str(creature.get_meta("kind", "fish"))
	var area := Area3D.new()
	area.name = "CreatureHitbox"
	area.collision_layer = 4
	area.collision_mask = 0
	area.monitoring = false
	area.set_meta("creature", creature)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	var sizes := {
		"fish": Vector2(0.45, 2.2), "predator": Vector2(0.8, 5.0),
		"abyss": Vector2(1.0, 4.4), "jellyfish": Vector2(0.8, 2.8),
		"squid": Vector2(0.85, 5.0), "manta_ray": Vector2(1.0, 3.2),
		"sea_turtle": Vector2(0.7, 2.4), "crab": Vector2(0.8, 1.8),
		"sea_spider": Vector2(1.0, 2.0), "seal": Vector2(0.72, 4.4),
		"water_dragon": Vector2(1.65, 17.0)
	}
	var size: Vector2 = sizes.get(kind, Vector2(0.7, 2.0))
	capsule.radius = size.x
	capsule.height = maxf(size.y, size.x * 2.0)
	collision.shape = capsule
	collision.rotation.x = PI * 0.5
	if kind == "water_dragon":
		collision.position.z = -1.4
	elif kind == "sea_spider":
		collision.position.y = 0.85
	area.add_child(collision)
	creature.add_child(area)

func trace_laser(from: Vector3, direction: Vector3, max_range: float, excluded: Array[RID] = []) -> Dictionary:
	var finish := from + direction.normalized() * max_range
	var query := PhysicsRayQueryParameters3D.create(from, finish, 7, excluded)
	query.collide_with_areas = true
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return {"position": finish, "creature": null}
	var collider: Node = result["collider"]
	var creature: Node3D = collider.get_meta("creature") if collider.has_meta("creature") else null
	if creature == null and collider.has_meta("kind") and get_creatures().has(collider):
		creature = collider as Node3D
	return {"position": result["position"], "creature": creature, "collider": collider}

func damage_creature(creature: Node3D, damage: float, impulse := Vector3.ZERO, instant_kill := false) -> Dictionary:
	if not is_instance_valid(creature) or bool(creature.get_meta("dead", false)):
		return {}
	# 自己契约的坐骑战兽无法被攻击造成伤害
	if bool(creature.get_meta("tamed", false)):
		return {}
	var kind: String = str(creature.get_meta("kind", ""))
	if kind == "water_dragon" and not boss_active and not instant_kill:
		return {}
	var health: float = float(creature.get_meta("health", 60.0))
	health = 0.0 if instant_kill else maxf(0.0, health - damage)
	creature.set_meta("health", health)
	if kind != "water_dragon" and float(creature.get_meta("freeze_timer", 0.0)) <= 0.0:
		creature.position += impulse
		creature.position.y = clampf(creature.position.y, floor_height(creature.position.x, creature.position.z) + 0.25, -0.05)
	var at := creature.global_position
	var creature_name: String = str(creature.get_meta("name", "海洋生物"))
	var drops: Array[Dictionary] = []
	var killed := health <= 0.0
	if killed:
		creature.set_meta("dead", true)
		creature.set_meta("can_loot", true)
		creature.set_meta("looted", false)
		if creature.has_method("set_limp_corpse"):
			creature.set_limp_corpse()
		if kind in ["predator", "abyss"]:
			var fragment_kind := "shark_fragment" if kind == "predator" else "abyss_fragment"
			var fragment := _spawn_fragment(fragment_kind, at)
			drops.append({"kind": fragment_kind, "name": FRAGMENT_NAMES[fragment_kind], "node": fragment, "pos": at})
			predators.erase(creature)
		for b_id in boss_nodes:
			if creature == boss_nodes[b_id]:
				conquered_bosses[b_id] = true
				boss_slain = conquered_bosses.size() >= 4
				boss_active = false
				boss_warning = ""
				boss_defeated.emit()
				if conquered_bosses.size() >= 4 and not mother_tree_spawned_flag:
					mother_tree_spawned_flag = true
					spawn_mother_tree()
					all_bosses_conquered.emit()
	return {
		"hit": true, "name": creature_name, "damage": damage, "killed": killed,
		"health_left": health, "is_sonic": false, "hit_count": 1,
		"hit_names": [creature_name], "killed_names": [creature_name] if killed else [],
		"dropped_items": drops, "hit_positions": [at], "hit_kinds": [kind]
	}

func freeze_creatures(at: Vector3, radius: float, duration: float) -> int:
	var count := 0
	for creature in get_creatures():
		if not is_instance_valid(creature) or bool(creature.get_meta("dead", false)):
			continue
		if creature.global_position.distance_squared_to(at) > radius * radius:
			continue
		creature.set_meta("freeze_timer", maxf(float(creature.get_meta("freeze_timer", 0.0)), duration))
		_update_creature_animation(creature)
		if not creature.has_node("StasisAura"):
			var aura := MeshInstance3D.new()
			aura.name = "StasisAura"
			var sphere := SphereMesh.new()
			sphere.radius = 6.0 if creature == water_dragon else 1.2
			sphere.height = sphere.radius * 2.0
			sphere.radial_segments = 16
			sphere.rings = 8
			aura.mesh = sphere
			var material := StandardMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			material.albedo_color = Color(0.08, 0.4, 1.0, 0.14)
			aura.material_override = material
			creature.add_child(aura)
		count += 1
	return count

func _spawn_extra_creatures() -> void:
	for i in range(12):
		var x: float = -18.0 + i * 4.6 if i < 4 else rng.randf_range(-65, 55)
		var z: float = -8.0 - i * 6.0 if i < 4 else rng.randf_range(-150, -40)
		var spider := MarineCreature.new()
		spider.configure("sea_spider")
		add_child(spider)
		spider.position = Vector3(x, floor_height(x, z) + 0.15, z)
		spider.set_meta("center", spider.position)
		spider.set_meta("phase", rng.randf_range(0, TAU))
		spider.set_meta("health", 90.0)
		spider.set_meta("bite_cooldown", 0.0)
		sea_spiders.append(spider)
	for i in range(6):
		var seal := MarineCreature.new()
		seal.configure("seal")
		add_child(seal)
		seal.position = Vector3(12.0 + i * 7.0, -7.0 - i * 1.8, 6.0 - i * 9.0)
		seal.set_meta("center", seal.position)
		seal.set_meta("phase", rng.randf_range(0, TAU))
		seal.set_meta("health", 160.0)
		seals.append(seal)
	water_dragon = MarineCreature.new()
	water_dragon.configure("water_dragon")
	add_child(water_dragon)
	water_dragon.position = BOSS_ARENA_CENTER + Vector3(0, 3, -6)
	water_dragon.set_meta("health", BOSS_MAX_HEALTH)
	water_dragon.set_meta("max_health", BOSS_MAX_HEALTH)
	water_dragon.set_meta("bite_cooldown", 0.0)
	boss_nodes["water_dragon"] = water_dragon
	boss_arena_centers["water_dragon"] = BOSS_ARENA_CENTER
	active_boss_node = water_dragon
	var marker := _create_marker("终章  /  深渊水龙领域\n进入 36 米范围开启 Boss 战", BOSS_ARENA_CENTER + Vector3(0, 8, 0), Color(0.25, 0.65, 1.0))
	add_child(marker)

	# Boss 2: Storm Flying Fish (风暴飞鱼·空棘龙皇)
	flying_fish_boss = MarineCreature.new()
	flying_fish_boss.configure("flying_fish")
	add_child(flying_fish_boss)
	flying_fish_boss.position = Vector3(145, -16, -40)
	flying_fish_boss.set_meta("health", 1400.0)
	flying_fish_boss.set_meta("max_health", 1400.0)
	flying_fish_boss.set_meta("name", "风暴飞鱼 · 空棘龙皇")
	flying_fish_boss.set_meta("kind", "boss_flying_fish")
	boss_nodes["flying_fish"] = flying_fish_boss
	boss_arena_centers["flying_fish"] = Vector3(145, -16, -40)
	add_child(_create_marker("风暴海脊  /  风暴飞鱼领地", Vector3(145, -10, -40), Color(0.2, 0.85, 1.0)))

	# Boss 3: Abyssal Kraken (深渊巨章·克拉肯领主)
	kraken_boss = MarineCreature.new()
	kraken_boss.configure("kraken")
	add_child(kraken_boss)
	kraken_boss.position = Vector3(-105, -75, -85)
	kraken_boss.set_meta("health", 2200.0)
	kraken_boss.set_meta("max_health", 2200.0)
	kraken_boss.set_meta("name", "深渊巨章 · 克拉肯领主")
	kraken_boss.set_meta("kind", "boss_kraken")
	boss_nodes["kraken"] = kraken_boss
	boss_arena_centers["kraken"] = Vector3(-105, -75, -85)
	add_child(_create_marker("克拉肯海沟  /  深渊巨章巢穴", Vector3(-105, -68, -85), Color(0.85, 0.35, 1.0)))

	# Boss 4: Ancient Colossus Turtle (远古灵龟·巨岩神鳌)
	turtle_boss = MarineCreature.new()
	turtle_boss.configure("colossus_turtle")
	add_child(turtle_boss)
	turtle_boss.position = Vector3(-140, -92, -145)
	turtle_boss.set_meta("health", 2600.0)
	turtle_boss.set_meta("max_health", 2600.0)
	turtle_boss.set_meta("name", "远古灵龟 · 巨岩神鳌")
	turtle_boss.set_meta("kind", "boss_turtle")
	boss_nodes["colossus_turtle"] = turtle_boss
	boss_arena_centers["colossus_turtle"] = Vector3(-140, -92, -145)
	add_child(_create_marker("巨鳌盆地  /  远古灵龟领地", Vector3(-140, -84, -145), Color(0.2, 1.0, 0.65)))

func _tick_sea_spiders(diver_pos: Vector3, delta: float) -> Array[Dictionary]:
	var attacks: Array[Dictionary] = []
	for spider in sea_spiders:
		if not is_instance_valid(spider) or _is_immobile(spider):
			continue
		if bool(spider.get_meta("tamed", false)):
			continue
		var cooldown: float = maxf(0.0, float(spider.get_meta("bite_cooldown", 0.0)) - delta)
		spider.set_meta("bite_cooldown", cooldown)
		var distance: float = spider.global_position.distance_to(diver_pos)
		var target_pos: Vector3
		if distance < 10.0 and diver_pos.y < floor_height(diver_pos.x, diver_pos.z) + 4.5:
			target_pos = diver_pos
		else:
			var center: Vector3 = spider.get_meta("center")
			var t: float = float(spider.get_meta("motion_clock", clock)) * 0.35 + float(spider.get_meta("phase"))
			target_pos = center + Vector3(sin(t) * 4.0, 0, cos(t) * 3.0)
		var next: Vector3 = spider.position.move_toward(target_pos, delta * 2.6)
		next.y = floor_height(next.x, next.z) + 0.15
		var forward := Vector3(next.x - spider.position.x, 0, next.z - spider.position.z)
		if forward.length_squared() > 0.0001:
			spider.look_at(spider.position + forward, Vector3.UP, true)
		spider.position = next
		if distance < 2.6 and cooldown <= 0.0:
			spider.set_meta("bite_cooldown", 2.0)
			attacks.append({"name": "海蜘蛛足刺", "damage": 12.0, "pos": spider.global_position})
	return attacks

func _tick_seals_vs_sharks(delta: float) -> void:
	for seal in seals:
		if not is_instance_valid(seal) or _is_immobile(seal):
			continue
		for shark in predators:
			if not is_instance_valid(shark) or _is_immobile(shark):
				continue
			var dist: float = seal.global_position.distance_to(shark.global_position)
			if dist < 14.0:
				seal.position = seal.position.move_toward(shark.global_position, delta * 3.5)
				shark.position = shark.position.move_toward(seal.global_position, delta * 3.2)
				if dist < 3.2:
					var s_hp: float = float(shark.get_meta("health", 90.0)) - delta * 28.0
					var seal_hp: float = float(seal.get_meta("health", 160.0)) - delta * 20.0
					shark.set_meta("health", s_hp)
					seal.set_meta("health", seal_hp)
					if s_hp <= 0.0:
						damage_creature(shark, 999.0)
					if seal_hp <= 0.0:
						damage_creature(seal, 999.0)
				break

func check_boss_encounter(diver_pos: Vector3) -> void:
	if conquered_bosses.size() >= 4:
		return
	for b_id in boss_nodes:
		if conquered_bosses.has(b_id):
			continue
		var b_node: Node3D = boss_nodes[b_id]
		if not is_instance_valid(b_node) or bool(b_node.get_meta("dead", false)) or bool(b_node.get_meta("tamed", false)):
			continue
		var center_pos: Vector3 = boss_arena_centers.get(b_id, b_node.global_position)
		var d: float = diver_pos.distance_to(center_pos)
		if not boss_active and d <= BOSS_TRIGGER_RADIUS:
			active_boss_id = b_id
			active_boss_node = b_node
			boss_active = true
			boss_action = "circle"
			boss_action_timer = 2.5
			boss_warning = "%s 苏醒！进入领地决战" % str(b_node.get_meta("name", "巨兽"))
			boss_encounter_started.emit()
			return
		elif boss_active and active_boss_id == b_id and d > 85.0:
			reset_boss_encounter()

func reset_boss_encounter() -> void:
	boss_active = false
	boss_action = "circle"
	boss_action_timer = 3.0
	boss_cycle = 0
	boss_warning = ""
	if is_instance_valid(active_boss_node):
		var max_h: float = float(active_boss_node.get_meta("max_health", BOSS_MAX_HEALTH))
		active_boss_node.set_meta("health", max_h)
		active_boss_node.set_meta("enraged", false)
		active_boss_node.set_meta("freeze_timer", 0.0)

func get_boss_status() -> Dictionary:
	var b: Node3D = active_boss_node if is_instance_valid(active_boss_node) else water_dragon
	return {
		"active": boss_active, "defeated": conquered_bosses.has("water_dragon") or (conquered_bosses.size() >= 4),
		"all_cleared": conquered_bosses.size() >= 4,
		"conquered_count": conquered_bosses.size(),
		"conquered_ids": conquered_bosses.keys(),
		"health": float(b.get_meta("health", 0.0)) if is_instance_valid(b) else 0.0,
		"max_health": float(b.get_meta("max_health", BOSS_MAX_HEALTH)) if is_instance_valid(b) else BOSS_MAX_HEALTH,
		"name": str(b.get_meta("name", "深渊水龙 · 潮汐君主")) if is_instance_valid(b) else "深渊水龙 · 潮汐君主",
		"warning": boss_warning,
		"frozen": float(b.get_meta("freeze_timer", 0.0)) if is_instance_valid(b) else 0.0
	}

func _tick_boss(diver_pos: Vector3, delta: float) -> Array[Dictionary]:
	var attacks: Array[Dictionary] = []
	var b: Node3D = active_boss_node if is_instance_valid(active_boss_node) else water_dragon
	if not boss_active or not is_instance_valid(b) or _is_immobile(b) or bool(b.get_meta("tamed", false)):
		return attacks
	var b_max: float = float(b.get_meta("max_health", BOSS_MAX_HEALTH))
	var enraged: bool = float(b.get_meta("health")) <= b_max * 0.5
	b.set_meta("enraged", enraged)
	var cooldown: float = maxf(0.0, float(b.get_meta("bite_cooldown", 0.0)) - delta)
	b.set_meta("bite_cooldown", cooldown)
	boss_action_timer -= delta
	var to_diver: Vector3 = diver_pos - b.global_position
	if boss_action == "circle":
		var t: float = float(b.get_meta("motion_clock", clock)) * 0.4
		var destination := diver_pos + Vector3(sin(t) * 18.0, 2.0 + sin(t * 1.3) * 3.0, cos(t) * 18.0)
		b.position = b.position.move_toward(destination, delta * (8.0 if enraged else 5.5))
		boss_warning = "狂暴阶段 · 冲刺速度提升" if enraged else "%s 正在盘旋 · 蓄力球可冻结它" % str(b.get_meta("name", "巨兽"))
		if boss_action_timer <= 0.0:
			boss_cycle += 1
			boss_action = "pulse_windup" if boss_cycle % 3 == 0 else "charge_windup"
			boss_action_timer = 1.2
	elif boss_action == "charge_windup":
		boss_warning = "巨兽冲刺蓄势！向侧面闪避 / Q 冲刺"
		if boss_action_timer <= 0.0:
			boss_charge_direction = to_diver.normalized()
			boss_action = "charge"
			boss_action_timer = 1.35
	elif boss_action == "charge":
		boss_warning = "巨兽猛烈冲刺！"
		b.position += boss_charge_direction * delta * (25.0 if enraged else 18.0)
		if to_diver.length() < 6.0 and cooldown <= 0.0:
			b.set_meta("bite_cooldown", 1.0)
			attacks.append({"name": "%s 猛撞" % str(b.get_meta("name", "巨兽")), "damage": 38.0 if enraged else 26.0, "pos": b.global_position})
		if boss_action_timer <= 0.0:
			boss_action = "circle"
			boss_action_timer = 2.4
	elif boss_action == "pulse_windup":
		boss_warning = "高能震荡波蓄势！远离巨兽 18 米"
		if boss_action_timer <= 0.0:
			if to_diver.length() < 18.0:
				attacks.append({"name": "巨兽震荡狂涛", "damage": 32.0 if enraged else 22.0, "pos": b.global_position})
			var vfx = load("res://scripts/combat_vfx.gd")
			vfx.spawn_stasis_burst(self, b.global_position, 18.0, 0.7, Color(1.0, 0.3, 0.12))
			boss_action = "circle"
			boss_action_timer = 3.0
	if to_diver.length_squared() > 0.001:
		var forward: Vector3 = boss_charge_direction if boss_action == "charge" else to_diver.normalized()
		b.look_at(b.position + forward, Vector3.UP if absf(forward.y) < 0.95 else Vector3.FORWARD, true)
	b.position.y = clampf(b.position.y, floor_height(b.position.x, b.position.z) + 3.0, -2.0)
	return attacks

func _spawn_fragment(kind: String, at: Vector3) -> Node3D:
	var body := StaticBody3D.new()
	body.name = "Fragment_" + kind
	body.position = at
	body.collision_layer = 2
	body.set_meta("kind", kind)
	body.set_meta("initial_y", at.y)
	body.set_meta("bob_phase", rng.randf_range(0.0, TAU))
	add_child(body)

	var mesh_inst := MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	if kind == "shark_fragment":
		var prism := PrismMesh.new()
		prism.size = Vector3(0.55, 0.75, 0.35)
		mesh_inst.mesh = prism
		mat.albedo_color = Color(0.2, 0.9, 1.0, 0.95)
	else:
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.15
		cyl.bottom_radius = 0.42
		cyl.height = 0.85
		cyl.radial_segments = 6
		mesh_inst.mesh = cyl
		mat.albedo_color = Color(0.85, 0.35, 1.0, 0.95)

	mesh_inst.material_override = mat
	body.add_child(mesh_inst)

	var light := OmniLight3D.new()
	light.light_color = Color(0.3, 0.85, 1.0) if kind == "shark_fragment" else Color(0.85, 0.4, 1.0)
	light.light_energy = 4.0
	light.omni_range = 14.0
	light.omni_attenuation = 0.75
	body.add_child(light)

	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.3
	collision.shape = sphere
	body.add_child(collision)

	fragments.append(body)
	resources.append(body)
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
	var asset := model("resource_" + kind, Vector3.ZERO, 1.0, 36.0)
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
	for ray in rays:
		_tick_status(ray, delta)
	for turtle in turtles:
		_tick_status(turtle, delta)
	for squid in squids:
		_tick_status(squid, delta)
	for crab in crabs:
		_tick_status(crab, delta)
	for spider in sea_spiders:
		if not _tick_status(spider, delta):
			spider.animate(delta)
	for seal in seals:
		if _tick_status(seal, delta):
			continue
		seal.animate(delta)
		var center: Vector3 = seal.get_meta("center")
		var t: float = float(seal.get_meta("motion_clock")) * 0.35 + float(seal.get_meta("phase"))
		var next := center + Vector3(sin(t) * 9.0, sin(t * 1.6) * 1.5, cos(t) * 7.0)
		var direction := next - seal.position
		if direction.length_squared() > 0.0001:
			seal.look_at(seal.position + direction, Vector3.UP, true)
		seal.position = next
	if is_instance_valid(water_dragon) and not _tick_status(water_dragon, delta):
		water_dragon.animate(delta)
		if not boss_active:
			var t: float = float(water_dragon.get_meta("motion_clock"))
			water_dragon.position = BOSS_ARENA_CENTER + Vector3(0, 3.0 + sin(t * 0.5), -6)

	# 1. 中型温和鱼群巡游与惊扰避障 (遍历独立 neutral_fish 数组，消除每帧过万次数组线性比对)
	for creature in neutral_fish:
		if not is_instance_valid(creature):
			continue
		if _is_immobile(creature):
			continue
		var center: Vector3 = creature.get_meta("center")
		var t: float = float(creature.get_meta("motion_clock", clock)) * 0.24 + float(creature.get_meta("phase"))
		var rad: float = float(creature.get_meta("radius", 6.0))
		var next := center + Vector3(sin(t) * rad, sin(t * 2.0) * 0.8, cos(t) * (rad * 0.66))

		# 潜水员近身惊扰避让
		var dist_diver: float = creature.global_position.distance_to(last_diver_pos)
		if dist_diver < 4.5:
			var away := (creature.global_position - last_diver_pos).normalized()
			next += away * (4.5 - dist_diver) * 1.5

		# 视距外（50m 外浓雾不可见）跳过朝向和横滚矩阵运算，节约 CPU
		if dist_diver <= 50.0:
			var direction := next - creature.position
			if direction.length_squared() > 0.00001:
				var up := Vector3.UP if absf(direction.normalized().y) < 0.95 else Vector3.FORWARD
				creature.look_at(creature.position + direction, up, true)
				# 转弯横滚倾角 (Banking)
				var turn_yaw: float = sin(t) * 0.22
				creature.rotate_object_local(Vector3.FORWARD, -turn_yaw)
		creature.position = next

	# 2. 可食用发光小金鱼快速群游与机敏避险
	for sfish in small_fish:
		if not is_instance_valid(sfish):
			continue
		if _is_immobile(sfish):
			continue
		var center: Vector3 = sfish.get_meta("center")
		var phase: float = float(sfish.get_meta("phase"))
		var spd: float = float(sfish.get_meta("swim_speed"))
		var rad: float = float(sfish.get_meta("radius"))

		# 惊扰加速响应
		var fright_t: float = float(sfish.get_meta("fright_timer", 0.0))
		var dist_d: float = sfish.global_position.distance_to(last_diver_pos)
		if dist_d < 3.8:
			fright_t = 1.6
			sfish.set_meta("fright_timer", fright_t)

		if fright_t > 0.0:
			sfish.set_meta("fright_timer", maxf(0.0, fright_t - delta))
			spd *= 2.2

		var t: float = float(sfish.get_meta("motion_clock", clock)) * spd * 0.45 + phase
		var next := center + Vector3(sin(t) * rad, sin(t * 2.2) * 0.8, cos(t) * (rad * 0.7))
		if dist_d < 3.8:
			var flee_vec := (sfish.global_position - last_diver_pos).normalized()
			next += flee_vec * 2.4

		var dir := next - sfish.position
		if dir.length_squared() > 0.0001:
			var up := Vector3.UP if absf(dir.normalized().y) < 0.95 else Vector3.FORWARD
			sfish.look_at(sfish.position + dir, up, true)
			sfish.rotate_object_local(Vector3.FORWARD, -sin(t * 1.5) * 0.28)
		sfish.position = next

	# 3. 巨型鬼蝠鲼：大范围开阔海域巡游与翼展倾角
	for ray in rays:
		if not is_instance_valid(ray) or _is_immobile(ray):
			continue
		var center: Vector3 = ray.get_meta("center")
		var phase: float = float(ray.get_meta("phase"))
		var spd: float = float(ray.get_meta("speed"))
		var rad: float = float(ray.get_meta("radius"))
		var t: float = float(ray.get_meta("motion_clock", clock)) * spd * 0.18 + phase
		# 双纽线/大椭圆滑翔轨迹
		var next := center + Vector3(sin(t) * rad, sin(t * 1.8) * 1.8, cos(t * 0.8) * (rad * 0.75))
		var dir := next - ray.position
		if dir.length_squared() > 0.0001:
			var up := Vector3.UP if absf(dir.normalized().y) < 0.95 else Vector3.FORWARD
			ray.look_at(ray.position + dir, up, true)
			# 优雅大翼倾斜
			ray.rotate_object_local(Vector3.FORWARD, -sin(t * 0.8) * 0.38)
		ray.position = next

	# 4. 深海绿海龟：浅海珊瑚礁漫游与起伏换气游姿
	for turtle in turtles:
		if not is_instance_valid(turtle) or _is_immobile(turtle):
			continue
		var center: Vector3 = turtle.get_meta("center")
		var phase: float = float(turtle.get_meta("phase"))
		var spd: float = float(turtle.get_meta("speed"))
		var rad: float = float(turtle.get_meta("radius"))
		var t: float = float(turtle.get_meta("motion_clock", clock)) * spd * 0.22 + phase
		var next := center + Vector3(sin(t) * rad, sin(t * 1.4) * 1.6, cos(t) * (rad * 0.8))
		var dir := next - turtle.position
		if dir.length_squared() > 0.0001:
			var up := Vector3.UP if absf(dir.normalized().y) < 0.95 else Vector3.FORWARD
			turtle.look_at(turtle.position + dir, up, true)
			turtle.rotate_object_local(Vector3.FORWARD, -sin(t) * 0.18)
		turtle.position = next

	# 5. 深渊发光巨乌贼：脉冲喷射加速与拖曳滑翔
	for squid in squids:
		if not is_instance_valid(squid) or _is_immobile(squid):
			continue
		var center: Vector3 = squid.get_meta("center")
		var phase: float = float(squid.get_meta("phase"))
		var spd: float = float(squid.get_meta("speed"))
		var rad: float = float(squid.get_meta("radius"))
		var t: float = float(squid.get_meta("motion_clock", clock)) * spd * 0.18 + phase
		var next := center + Vector3(sin(t) * rad, sin(t * 1.6) * 2.2, cos(t) * rad)
		var dir := next - squid.position
		if dir.length_squared() > 0.0001:
			var up := Vector3.UP if absf(dir.normalized().y) < 0.95 else Vector3.FORWARD
			squid.look_at(squid.position + dir, up, true)
		squid.position = next

	# 6. 底栖巨螯蟹：海床爬行与潜水员接近时的举螯防卫姿态
	for crab in crabs:
		if not is_instance_valid(crab) or _is_immobile(crab):
			continue
		var ox: float = float(crab.get_meta("origin_x"))
		var oz: float = float(crab.get_meta("origin_z"))
		var phase: float = float(crab.get_meta("phase"))
		var patrol_r: float = float(crab.get_meta("patrol_radius"))

		var dist_diver: float = crab.global_position.distance_to(last_diver_pos)
		if dist_diver < 4.8:
			# 潜水员近身防御警戒状态：转向玩家，微幅抬起前身
			crab.set_meta("defensive", true)
			var to_diver := (last_diver_pos - crab.global_position)
			to_diver.y = 0
			if to_diver.length_squared() > 0.001:
				crab.look_at(crab.global_position + to_diver.normalized(), Vector3.UP, true)
		else:
			crab.set_meta("defensive", false)
			# 沿海床自然爬行
			var t: float = float(crab.get_meta("motion_clock", clock)) * 0.35 + phase
			var cx: float = ox + sin(t) * patrol_r
			var cz: float = oz + cos(t * 0.8) * (patrol_r * 0.75)
			var cy: float = floor_height(cx, cz)
			var move_dir := Vector3(cx, cy, cz) - crab.position
			if move_dir.length_squared() > 0.0001:
				var flat_dir := Vector3(move_dir.x, 0, move_dir.z).normalized()
				if flat_dir.length_squared() > 0.001:
					crab.look_at(crab.position + flat_dir, Vector3.UP, true)
			crab.position = Vector3(cx, cy, cz)

	# 7. 热泉巨管虫群落受惊收缩与触碰交互 (使用缓存材质引用，避免逐帧 find_children 搜索)
	for colony in tubeworm_colonies:
		if not is_instance_valid(colony):
			continue
		var dist_to_d: float = colony.global_position.distance_to(last_diver_pos)
		var cur_retract: float = float(colony.get_meta("retract_progress", 0.0))
		var target_retract: float = 1.0 if dist_to_d < 3.8 else 0.0
		cur_retract = move_toward(cur_retract, target_retract, delta * (3.5 if target_retract > 0.5 else 0.8))
		colony.set_meta("retract_progress", cur_retract)
		var last_applied: float = float(colony.get_meta("last_retract_applied", -1.0))
		if absf(cur_retract - last_applied) > 0.005:
			colony.set_meta("last_retract_applied", cur_retract)
			var mats: Array = colony.get_meta("shader_materials", [])
			for mat in mats:
				if mat is ShaderMaterial:
					mat.set_shader_parameter("retract_progress", cur_retract)

	# 8. 地热喷口发光呼吸微光
	for light in vent_lights:
		light.light_energy = 5.2 + sin(clock * 4.5 + light.position.x) * 0.55

	# 9. 水母生物节律脉动
	for jelly in jellies:
		if not is_instance_valid(jelly) or _is_immobile(jelly):
			continue
		var center: Vector3 = jelly.get_meta("center")
		var phase: float = float(jelly.get_meta("phase"))
		var drift_speed: float = float(jelly.get_meta("drift_speed"))
		var local_clock: float = float(jelly.get_meta("motion_clock", clock))
		var t: float = local_clock * drift_speed + phase
		var pulse_t: float = local_clock * 2.2 + phase * 1.8
		var next := center + Vector3(sin(t) * 5.0, sin(pulse_t) * 1.1, cos(t * 0.75) * 4.5)
		jelly.position = next

	# 10. 掉落碎片浮动
	for frag in fragments:
		if not is_instance_valid(frag):
			continue
		var bphase: float = float(frag.get_meta("bob_phase", 0.0))
		if frag.position.y < -0.2:
			frag.position.y = minf(-0.05, frag.position.y + 6.0 * delta)
		else:
			frag.position.y = sin(clock * 1.8 + bphase) * 0.15
		frag.rotate_y(delta * 1.5)
	_tick_sea_wolves(last_diver_pos, delta)
	_tick_schooling_fish(last_diver_pos, delta)

func get_laser_color() -> Color:
	var background := environment.fog_light_color
	var luminance: float = background.r * 0.2126 + background.g * 0.7152 + background.b * 0.0722
	var illumination: float = luminance + environment.ambient_light_energy * 0.12 + sun.light_energy * 0.18
	var darkness: float = 1.0 - clampf(illumination / 0.6, 0.0, 1.0)
	return Color(0.015, 0.08, 0.7).lerp(Color(0.08, 0.5, 1.0), darkness)

func set_depth(depth: float, scoped: bool = false) -> void:
	if scoped != scope_view_enabled:
		scope_view_enabled = scoped
		for mesh in scope_meshes:
			if is_instance_valid(mesh):
				mesh.visibility_range_end = 300.0 if scoped else float(mesh.get_meta("base_visibility_range"))
	var depth_ratio := clampf(depth / 90.0, 0.0, 1.0)
	environment.fog_density = lerpf(0.010, 0.026, depth_ratio)
	if scoped:
		environment.fog_density *= 0.16
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

func mark_boss_tamed(b_id: String) -> void:
	conquered_bosses[b_id] = true
	if active_boss_id == b_id:
		boss_active = false
		boss_warning = ""
		active_boss_node = null
	if conquered_bosses.size() >= 4 and not mother_tree_spawned_flag:
		mother_tree_spawned_flag = true
		spawn_mother_tree()
		all_bosses_conquered.emit()
	boss_defeated.emit()

func _spawn_sea_wolves() -> void:
	var pack_spawns := [
		{"pos": Vector3(75, -65, -120), "pack": 1, "count": 3},
		{"pos": Vector3(-80, -78, -165), "pack": 2, "count": 3}
	]
	for spawn in pack_spawns:
		var p_center: Vector3 = spawn["pos"]
		var p_id: int = int(spawn["pack"])
		var cnt: int = int(spawn["count"])
		for i in range(cnt):
			var wolf := MarineCreature.new()
			wolf.configure("sea_wolf")
			add_child(wolf)
			var offset := Vector3(cos(i * TAU / cnt) * 6.0, (i - 1) * 1.5, sin(i * TAU / cnt) * 6.0)
			wolf.position = p_center + offset
			wolf.set_meta("center", p_center)
			wolf.set_meta("health", 650.0)
			wolf.set_meta("max_health", 650.0)
			wolf.set_meta("damage", 22.0)
			wolf.set_meta("speed", 13.5)
			wolf.set_meta("detect_radius", 26.0)
			wolf.set_meta("attack_radius", 4.2)
			wolf.set_meta("pack_id", p_id)
			wolf.set_meta("pack_index", i)
			wolf.set_meta("bite_cooldown", 0.0)
			wolf.set_meta("motion_clock", rng.randf_range(0, 100))
			wolf.set_meta("phase", i * 1.8)
			wolf.set_meta("tamed", false)
			wolf.set_meta("dead", false)
			sea_wolves.append(wolf)

func _tick_sea_wolves(diver_pos: Vector3, delta: float) -> Array[Dictionary]:
	var bites: Array[Dictionary] = []
	for wolf in sea_wolves:
		if not is_instance_valid(wolf):
			continue
		if _tick_status(wolf, delta):
			continue
		wolf.animate(delta)
		if bool(wolf.get_meta("tamed", false)):
			continue
		var center: Vector3 = wolf.get_meta("center")
		var spd: float = float(wolf.get_meta("speed", 13.5))
		var cd: float = maxf(0.0, float(wolf.get_meta("bite_cooldown", 0.0)) - delta)
		wolf.set_meta("bite_cooldown", cd)
		var dist: float = wolf.global_position.distance_to(diver_pos)
		var target_pos := center
		var clock_val: float = float(wolf.get_meta("motion_clock", clock)) + delta
		wolf.set_meta("motion_clock", clock_val)
		var phase: float = float(wolf.get_meta("phase", 0.0))
		if dist < float(wolf.get_meta("detect_radius", 26.0)):
			var pack_idx: int = int(wolf.get_meta("pack_index", 0))
			var angle: float = clock_val * 1.2 + pack_idx * (TAU / 3.0)
			var orbit_dist: float = 10.0 if (pack_idx != 0 or cd > 0.0) else 2.5
			target_pos = diver_pos + Vector3(cos(angle) * orbit_dist, sin(clock_val * 2.0) * 1.5, sin(angle) * orbit_dist)
			if dist < float(wolf.get_meta("attack_radius", 4.2)) and cd <= 0.0:
				wolf.set_meta("bite_cooldown", 2.2)
				bites.append({"name": "海狼撕咬", "damage": float(wolf.get_meta("damage", 22.0)), "pos": wolf.global_position})
		else:
			target_pos = center + Vector3(cos(clock_val * 0.4 + phase) * 18.0, sin(clock_val * 0.3) * 3.5, sin(clock_val * 0.4 + phase) * 18.0)
		var next_pos: Vector3 = wolf.position.move_toward(target_pos, delta * spd)
		var move_dir := next_pos - wolf.position
		if move_dir.length_squared() > 0.001:
			var up_dir := Vector3.UP if absf(move_dir.normalized().y) < 0.95 else Vector3.FORWARD
			wolf.look_at(wolf.position + move_dir, up_dir, true)
		wolf.position = next_pos
	return bites

func _spawn_schooling_fish() -> void:
	fish_schools.clear()
	var school_defs := [
		{"center": Vector3(25, -14, 10), "count": 18, "radius": 7.0, "speed": 6.8},
		{"center": Vector3(-45, -55, -95), "count": 18, "radius": 9.0, "speed": 8.5}
	]
	for s_idx in range(school_defs.size()):
		var def: Dictionary = school_defs[s_idx]
		var s_center: Vector3 = def["center"]
		var cnt: int = int(def["count"])
		var s_fish_list: Array[Node3D] = []
		for i in range(cnt):
			var sfish := MarineCreature.new()
			sfish.configure("school_fish")
			add_child(sfish)
			var offset := Vector3(rng.randf_range(-4, 4), rng.randf_range(-2, 2), rng.randf_range(-4, 4))
			sfish.position = s_center + offset
			sfish.set_meta("school_id", s_idx)
			sfish.set_meta("velocity", Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized() * float(def["speed"]))
			sfish.set_meta("scatter_timer", 0.0)
			sfish.set_meta("dead", false)
			schooling_fish.append(sfish)
			s_fish_list.append(sfish)
		fish_schools.append({
			"center": s_center,
			"current_pos": s_center,
			"fish": s_fish_list,
			"speed": float(def["speed"]),
			"orbit_angle": rng.randf_range(0, TAU)
		})

func _tick_schooling_fish(diver_pos: Vector3, delta: float) -> void:
	for s_idx in range(fish_schools.size()):
		var school: Dictionary = fish_schools[s_idx]
		var s_center: Vector3 = school["center"]
		var ang: float = float(school["orbit_angle"]) + delta * 0.35
		school["orbit_angle"] = ang
		var school_lead: Vector3 = s_center + Vector3(sin(ang) * 22.0, sin(ang * 1.8) * 3.5, cos(ang) * 18.0)
		school["current_pos"] = school_lead
		var fish_list: Array = school["fish"]
		var center_of_mass := Vector3.ZERO
		var valid_count := 0
		for f in fish_list:
			if is_instance_valid(f):
				center_of_mass += f.position
				valid_count += 1
		if valid_count > 0:
			center_of_mass /= float(valid_count)

		for f: Node3D in fish_list:
			if not is_instance_valid(f):
				continue
			if _tick_status(f, delta):
				continue
			f.animate(delta)

			var vel: Vector3 = f.get_meta("velocity", Vector3.FORWARD)
			var scatter_t: float = maxf(0.0, float(f.get_meta("scatter_timer", 0.0)) - delta)
			f.set_meta("scatter_timer", scatter_t)

			var d_dist: float = f.global_position.distance_to(diver_pos)
			if d_dist < 6.0:
				var away: Vector3 = (f.global_position - diver_pos).normalized()
				vel += away * 16.0
				f.set_meta("scatter_timer", 1.8)

			if scatter_t <= 0.0:
				var to_com := (center_of_mass - f.position) * 0.8
				var to_lead := (school_lead - f.position) * 0.6
				var separation := Vector3.ZERO
				for other: Node3D in fish_list:
					if other != f and is_instance_valid(other):
						var diff := f.position - other.position
						var d_sq := diff.length_squared()
						if d_sq < 3.2 and d_sq > 0.0001:
							separation += diff.normalized() * (3.2 - sqrt(d_sq)) * 2.2
				vel += (to_com + to_lead + separation) * delta * 4.0
			var target_spd: float = float(school["speed"]) * (2.2 if scatter_t > 0.0 else 1.0)
			vel = vel.limit_length(target_spd)
			f.set_meta("velocity", vel)
			f.position += vel * delta

			if vel.length_squared() > 0.01:
				var up_v := Vector3.UP if absf(vel.normalized().y) < 0.95 else Vector3.FORWARD
				f.look_at(f.position + vel, up_v, true)

func spawn_mother_tree() -> Node3D:
	if is_instance_valid(mother_tree):
		return mother_tree
	mother_tree = Node3D.new()
	mother_tree.name = "AncientMotherTree"
	var tree_root_pos := Vector3(0, floor_height(0, -340) - 2.0, -340)
	mother_tree.position = tree_root_pos
	add_child(mother_tree)
	mother_tree_spawned_flag = true

	var mat_bark := StandardMaterial3D.new()
	mat_bark.albedo_color = Color(0.06, 0.22, 0.16)
	mat_bark.roughness = 0.85
	mat_bark.emission_enabled = true
	mat_bark.emission = Color(0.12, 0.75, 0.55)
	mat_bark.emission_energy_multiplier = 0.8

	var mat_canopy := StandardMaterial3D.new()
	mat_canopy.albedo_color = Color(0.15, 0.85, 0.72)
	mat_canopy.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_canopy.albedo_color.a = 0.75
	mat_canopy.emission_enabled = true
	mat_canopy.emission = Color(0.2, 0.95, 0.85)
	mat_canopy.emission_energy_multiplier = 2.4

	# 1. Colossal Ancient Trunk (Rising from seabed up 70 meters)
	var trunk := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.bottom_radius = 8.5
	cyl.top_radius = 4.2
	cyl.height = 70.0
	cyl.radial_segments = 24
	trunk.mesh = cyl
	trunk.position = Vector3(0, 35.0, 0)
	trunk.material_override = mat_bark
	mother_tree.add_child(trunk)

	# 8 Twisted Massive Roots
	for i in range(8):
		var ang: float = i * TAU / 8.0
		var r_end := Vector3(cos(ang) * 36.0, 0.5, sin(ang) * 36.0)
		var root_cyl := MeshInstance3D.new()
		var r_mesh := CylinderMesh.new()
		r_mesh.bottom_radius = 3.6
		r_mesh.top_radius = 1.2
		r_mesh.height = 38.0
		root_cyl.mesh = r_mesh
		root_cyl.position = (Vector3(0, 4.0, 0) + r_end) * 0.5
		root_cyl.material_override = mat_bark
		mother_tree.add_child(root_cyl)
		root_cyl.look_at(mother_tree.global_position + r_end, Vector3.UP)
		root_cyl.rotate_object_local(Vector3.RIGHT, PI * 0.5)

	# 2. Glowing Bioluminescent Canopy Foliage Clusters
	for i in range(12):
		var c_ang: float = i * TAU / 12.0
		var foliage := MeshInstance3D.new()
		var s_mesh := SphereMesh.new()
		s_mesh.radius = 8.5 + (i % 3) * 2.5
		s_mesh.height = s_mesh.radius * 1.8
		foliage.mesh = s_mesh
		foliage.position = Vector3(cos(c_ang) * 24.0, 68.0 + (i % 4) * 3.0, sin(c_ang) * 24.0)
		foliage.material_override = mat_canopy
		mother_tree.add_child(foliage)

	# 3. Skyward Ascending Luminous Beacon Light Pillar
	var beacon := OmniLight3D.new()
	beacon.position = Vector3(0, 50.0, 0)
	beacon.light_color = Color(0.2, 0.95, 0.85)
	beacon.light_energy = 8.5
	beacon.omni_range = 95.0
	mother_tree.add_child(beacon)

	# 4. Spore Particle Emitter
	var particles := CPUParticles3D.new()
	particles.amount = 48
	particles.lifetime = 6.0
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 28.0
	particles.gravity = Vector3(0, 0.8, 0)
	var p_mesh := SphereMesh.new()
	p_mesh.radius = 0.22
	p_mesh.height = 0.44
	particles.mesh = p_mesh
	var p_mat := StandardMaterial3D.new()
	p_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p_mat.albedo_color = Color(0.3, 1.0, 0.8, 0.85)
	particles.material_override = p_mat
	particles.position = Vector3(0, 45.0, 0)
	mother_tree.add_child(particles)

	# 5. Sanctuary Entrance Marker & 3 Sacred Collectable Items
	var arch_marker := _create_marker("◈ 远古深海母树 · 圣所\n游入内部收集生命核心", tree_root_pos + Vector3(0, 16.0, 12.0), Color(0.3, 1.0, 0.8))
	add_child(arch_marker)

	var s_pos := tree_root_pos + Vector3(0, 12.0, 0)
	_spawn_mother_item("mother_tree_essence", "母树生命精华", s_pos + Vector3(-3.2, 0.5, 0), Color(0.2, 1.0, 0.5))
	_spawn_mother_item("ancient_star_core", "远古星核源石", s_pos + Vector3(0, 0.8, -3.2), Color(0.2, 0.8, 1.0))
	_spawn_mother_item("tree_seed", "深海启迪之种", s_pos + Vector3(3.2, 0.5, 0), Color(0.85, 0.4, 1.0))

	mother_tree_spawned.emit()
	return mother_tree

func _spawn_mother_item(kind: String, item_name: String, at: Vector3, color: Color) -> Node3D:
	var item := Node3D.new()
	item.name = kind
	item.position = at
	item.set_meta("kind", kind)
	item.set_meta("name", item_name)
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.4
	col.shape = sph
	body.add_child(col)
	item.add_child(body)
	var mesh_inst := MeshInstance3D.new()
	var m: Mesh
	if kind == "ancient_star_core":
		var prism := PrismMesh.new()
		prism.size = Vector3(1.2, 1.6, 1.2)
		m = prism
	elif kind == "mother_tree_essence":
		var s := SphereMesh.new()
		s.radius = 0.65
		s.height = 1.3
		m = s
	else:
		var caps := CapsuleMesh.new()
		caps.radius = 0.5
		caps.height = 1.2
		m = caps
	mesh_inst.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.2
	mesh_inst.material_override = mat
	item.add_child(mesh_inst)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 3.5
	light.omni_range = 8.0
	item.add_child(light)
	var lbl := Label3D.new()
	lbl.font = preload("res://assets/fonts/NotoSansSC-Subset.otf")
	lbl.text = "✦  [E] 采摘 " + item_name
	lbl.position = Vector3(0, 1.4, 0)
	lbl.font_size = 28
	lbl.pixel_size = 0.007
	lbl.modulate = color
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	item.add_child(lbl)
	add_child(item)
	mother_tree_items.append(item)
	return item
