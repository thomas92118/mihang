extends Node3D

signal boss_encounter_started
signal boss_defeated
signal all_bosses_conquered
signal mother_tree_spawned

const MarineCreature = preload("res://scripts/marine_creature.gd")
const Submarine = preload("res://scripts/submarine.gd")
const SeabedEcology = preload("res://scripts/seabed_ecology.gd")
const OceanDepths = preload("res://scripts/ocean_depths.gd")
const ArtDirection = preload("res://scripts/art_direction.gd")
const OceanComposition = preload("res://scripts/presentation/ocean_composition.gd")
const ModelFinish = preload("res://scripts/presentation/model_finish.gd")
const LABEL_FONT = preload("res://assets/fonts/NotoSansSC-Subset.otf")
const LABEL_FONT_SIZE := 40
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

const WORLD_HALF_EXTENT := 900.0
const SEABED_INNER_X0 := -288
const SEABED_INNER_X1 := 288
const SEABED_INNER_Z0 := -384
const SEABED_INNER_Z1 := 144
const SEABED_INNER_STEP := 6
const SEABED_OUTER_STEP := 12

const OUTPOST_SPECS := [
	{"id": "outpost_atoll", "name": "北境环礁科考站", "region": "北境晴空珊瑚环礁", "xz": Vector2(40, 340)},
	{"id": "outpost_kelp", "name": "翡翠海峡前哨站", "region": "翡翠巨藻迷宫海峡", "xz": Vector2(-260, 280)},
	{"id": "outpost_east", "name": "东海星象前哨站", "region": "东海沉没星象古都", "xz": Vector2(460, -60)},
	{"id": "outpost_west", "name": "龙骨荒原前哨站", "region": "西洋巨兽龙骨荒原", "xz": Vector2(-480, -90)},
	{"id": "outpost_caldera", "name": "黑曜火山科考站", "region": "黑曜石海底火山口", "xz": Vector2(-440, -420)},
	{"id": "outpost_hadal", "name": "极渊星辉前哨站", "region": "南极渊星辉圣域", "xz": Vector2(60, -640)}
]

const RELIC_SPECS := [
	{"id": "relic_reef_pearl", "name": "远古潮汐海螺星盘", "xz": Vector2(68, 42)},
	{"id": "relic_slope_astrolabe", "name": "失落深潜航海仪", "xz": Vector2(-62, -72)},
	{"id": "relic_atoll_crown", "name": "晴空珊瑚王冠结晶", "xz": Vector2(85, 385)},
	{"id": "relic_atoll_tablet", "name": "环礁先民潮汐石刻", "xz": Vector2(-45, 420)},
	{"id": "relic_kelp_amber", "name": "翡翠万年海珀核心", "xz": Vector2(-315, 325)},
	{"id": "relic_aurora_prism", "name": "极光海岭共鸣棱镜", "xz": Vector2(395, 305)},
	{"id": "relic_citadel_orb", "name": "沉没古都星象天球", "xz": Vector2(515, -75)},
	{"id": "relic_citadel_codex", "name": "星象神殿深海铭文", "xz": Vector2(430, -155)},
	{"id": "relic_ghost_compass", "name": "幽灵舰队核能罗盘", "xz": Vector2(435, -395)},
	{"id": "relic_leviathan_fang", "name": "远古利维坦晶化龙牙", "xz": Vector2(-525, -110)},
	{"id": "relic_caldera_heart", "name": "黑曜地心熔岩星核", "xz": Vector2(-455, -455)},
	{"id": "relic_hadal_chalice", "name": "极渊星辉永恒圣杯", "xz": Vector2(95, -675)}
]

var environment: Environment
var air_sky: Sky
var water_sky: Sky
var water_atmosphere: ShaderMaterial
var _atmosphere_color := Color(-1, -1, -1)
var _atmosphere_energy := -1.0
var _atmosphere_sunlit := -1.0
var art_depth := 0.0
var sun: DirectionalLight3D
var water_surface: MeshInstance3D = null
var water_surface_mat: ShaderMaterial = null
var water_underwater_mat: ShaderMaterial = null
var resources: Array[Node3D] = []
var fragments: Array[Node3D] = []
var fish: Array[Node3D] = []
var small_fish: Array[Node3D] = []
var neutral_fish: Array[Node3D] = []
var predators: Array[Node3D] = []
var rng := RandomNumberGenerator.new()
var clock: float = 0.0
static var cache: Dictionary = {}
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
var brain_corals: Array[Node3D] = []
var staghorn_corals: Array[Node3D] = []
var table_corals: Array[Node3D] = []
var barrel_sponges: Array[Node3D] = []
var giant_clams: Array[Node3D] = []
var sea_lilies: Array[Node3D] = []
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
var scope_meshes: Array[GeometryInstance3D] = []
var conquered_bosses: Dictionary = {}
var mother_tree: Node3D = null
var mother_tree_spawned_flag := false
var mother_tree_items: Array[Node3D] = []
var sea_wolves: Array[Node3D] = []
var schooling_fish: Array[Node3D] = []
var fish_schools: Array[Dictionary] = []
var escape_console: Node3D = null
var outposts: Array[Node3D] = []
var explorer_relics: Array[Node3D] = []
var outer_seabed_chunks: Array[MeshInstance3D] = []
var mother_tree_marker: Label3D = null
var seabed_ecology: Node3D
var marine_snow: MultiMeshInstance3D
var frontier_wildlife: Array[Node3D] = []
var _all_creatures: Array[Node3D] = []
var _creatures_dirty: bool = true
var _stasis_aura_mat: StandardMaterial3D = null
var _stasis_sphere_small: SphereMesh = null
var _stasis_sphere_boss: SphereMesh = null

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

	var core_h: float = -16.0 + depth_tier + base_hills + micro_detail

	# Seamless blend into Open-World Ocean Frontiers outside core basin ([-210, 210] x [-360, 120])
	var dx_out: float = maxf(0.0, absf(x) - 210.0)
	var dz_out: float = maxf(maxf(0.0, z - 120.0), maxf(0.0, -360.0 - z))
	var dist_out: float = sqrt(dx_out * dx_out + dz_out * dz_out)
	if dist_out <= 0.001:
		return core_h

	var t_out: float = clampf(dist_out / 95.0, 0.0, 1.0)
	var blend: float = t_out * t_out * (3.0 - 2.0 * t_out)

	# The outer ocean descends through a continental shelf into a true deep
	# basin. Broad ridges and canyons add relief at a different scale from dunes.
	var macro_wave: float = sin(x * 0.012) * 10.5 + cos(z * 0.013) * 8.5
	var south_basin := smoothstep(0.0, 760.0, -z)
	var north_shelf := smoothstep(160.0, 420.0, z)
	var frontier_h: float = -62.0 - south_basin * 175.0 + north_shelf * 30.0
	frontier_h += base_hills * 1.45 + micro_detail + macro_wave

	# A shallow lagoon and its reef rim remain the northern surface habitat.
	var d_atoll: float = Vector2(x - 40.0, z - 340.0).length()
	if d_atoll < 280.0:
		var w_a := 1.0 - smoothstep(90.0, 280.0, d_atoll)
		var reef_rim := exp(-pow((d_atoll - 85.0) / 34.0, 2.0)) * 4.5
		frontier_h = lerpf(frontier_h, -18.0 + base_hills * 0.55 + micro_detail + reef_rim, w_a)

	# Kelp occupies the sunlit strait, not the abyss beyond the shelf edge.
	var d_kelp: float = Vector2(x - (-260.0), z - 280.0).length()
	if d_kelp < 210.0:
		var w_k := 1.0 - smoothstep(65.0, 210.0, d_kelp)
		frontier_h = lerpf(frontier_h, -36.0 + base_hills * 0.70 + sin(x * 0.024) * 2.5, w_k)

	# The northern ridge is a submerged rocky shelf, with 20m relief.
	var d_aurora: float = Vector2(x - 380.0, z - 290.0).length()
	if d_aurora < 220.0:
		var w_r := 1.0 - smoothstep(75.0, 220.0, d_aurora)
		var ridge := sin((x - 380.0) * 0.043 + (z - 290.0) * 0.018) * 17.0
		frontier_h = lerpf(frontier_h, -82.0 + ridge + base_hills * 0.65, w_r)

	# The citadel sits on a twilight terrace above a continental drop-off.
	var d_east: float = Vector2(x - 460.0, z + 60.0).length()
	if d_east < 245.0:
		var w_e := 1.0 - smoothstep(85.0, 245.0, d_east)
		var terrace := sin(d_east * 0.065) * 5.5
		frontier_h = lerpf(frontier_h, -135.0 + terrace + base_hills * 0.65 + micro_detail, w_e)

	# The ghost fleet rests below the shelf, with gullies between the wrecks.
	var d_ghost: float = Vector2(x - 420.0, z + 380.0).length()
	if d_ghost < 235.0:
		var w_g := 1.0 - smoothstep(65.0, 235.0, d_ghost)
		var gully := sin((x + z) * 0.022) * 8.0
		frontier_h = lerpf(frontier_h, -182.0 + base_hills * 0.8 + gully, w_g)

	# A winding fossil canyon has a deep channel and high opposing shoulders.
	var d_lev: float = Vector2(x + 480.0, z + 90.0).length()
	if d_lev < 250.0:
		var w_l := 1.0 - smoothstep(80.0, 250.0, d_lev)
		var canyon_axis := absf(x + 480.0 + sin(z * 0.025) * 13.0)
		var canyon_cut := (1.0 - smoothstep(12.0, 70.0, canyon_axis)) * 24.0
		frontier_h = lerpf(frontier_h, -218.0 - canyon_cut + base_hills * 0.9, w_l)

	# A nearly 100m caldera wall encloses the bathyal hydrothermal field.
	var d_caldera: float = Vector2(x + 440.0, z + 420.0).length()
	if d_caldera < 245.0:
		var w_c := 1.0 - smoothstep(145.0, 245.0, d_caldera)
		var crater_profile := -352.0 + smoothstep(60.0, 142.0, d_caldera) * 96.0
		frontier_h = lerpf(frontier_h, crater_profile + micro_detail + base_hills * 0.45, w_c)

	# The south trench is reached by descending a broad V-shaped continental
	# escarpment. Its narrow axis reaches 600m rather than a deeper flat plane.
	if z < -375.0:
		var trench_axis := 40.0 + sin((z + 640.0) * 0.012) * 28.0
		var cross_trench := absf(x - trench_axis)
		var s_drop := smoothstep(375.0, 610.0, -z)
		var trench_wall := 1.0 - smoothstep(85.0, 360.0, cross_trench)
		var axial_pit := exp(-pow((z + 775.0) / 100.0, 2.0)) * exp(-pow(cross_trench / 75.0, 2.0)) * 18.0
		var trench_floor := -520.0 - smoothstep(600.0, 800.0, -z) * 64.0
		trench_floor += base_hills * 0.5 + sin(z * 0.018) * 4.0 - axial_pit
		frontier_h = lerpf(frontier_h, trench_floor, s_drop * trench_wall)

	frontier_h = clampf(frontier_h, -OceanDepths.MAX_SEAFLOOR_DEPTH, -6.5)
	return lerpf(core_h, frontier_h, blend)

static func terrain_height(x: float, z: float) -> float:
	# Contact height on the actual rendered/collidable triangle. Analytic
	# heights alone leave objects floating above steep outer escarpments.
	var ix0 := float(SEABED_INNER_X0)
	var ix1 := float(SEABED_INNER_X1)
	var iz0 := float(SEABED_INNER_Z0)
	var iz1 := float(SEABED_INNER_Z1)
	var step := float(SEABED_INNER_STEP)
	var half := float(SEABED_OUTER_STEP) * 0.5
	var origin := Vector2(ix0, iz0)
	var region := 0
	if z >= iz1:
		step = float(SEABED_OUTER_STEP)
		origin = Vector2(-960.0, iz1)
		region = 1
	elif z < iz0:
		step = float(SEABED_OUTER_STEP)
		origin = Vector2(-960.0, -960.0)
		region = 2
	elif x < ix0:
		step = float(SEABED_OUTER_STEP)
		origin = Vector2(-960.0, iz0)
		region = 3
	elif x >= ix1:
		step = float(SEABED_OUTER_STEP)
		origin = Vector2(ix1, iz0)
		region = 4
	var x0: float = floor((x - origin.x) / step) * step + origin.x
	var z0: float = floor((z - origin.y) / step) * step + origin.y
	if region == 2 and z0 > iz0 - step:
		z0 = iz0 - step
	elif region == 3 and x0 > ix0 - step:
		x0 = ix0 - step
	if region == 1 and is_equal_approx(z0, iz1) and x0 >= ix0 and x0 < ix1:
		return _bary_stitched(
			(x - x0) / step, (z - iz1) / step,
			floor_height(x0, iz1), floor_height(x0 + half, iz1), floor_height(x0 + step, iz1),
			floor_height(x0, iz1 + step), floor_height(x0 + step, iz1 + step)
		)
	if region == 2 and is_equal_approx(z0, iz0 - step) and x0 >= ix0 and x0 < ix1:
		return _bary_stitched(
			(x - x0) / step, (iz0 - z) / step,
			floor_height(x0, iz0), floor_height(x0 + half, iz0), floor_height(x0 + step, iz0),
			floor_height(x0, z0), floor_height(x0 + step, z0)
		)
	if region == 3 and is_equal_approx(x0, ix0 - step) and z0 >= iz0 and z0 < iz1:
		return _bary_stitched(
			(z - z0) / step, (ix0 - x) / step,
			floor_height(ix0, z0), floor_height(ix0, z0 + half), floor_height(ix0, z0 + step),
			floor_height(x0, z0), floor_height(x0, z0 + step)
		)
	if region == 4 and is_equal_approx(x0, ix1) and z0 >= iz0 and z0 < iz1:
		return _bary_stitched(
			(z - z0) / step, (x - ix1) / step,
			floor_height(ix1, z0), floor_height(ix1, z0 + half), floor_height(ix1, z0 + step),
			floor_height(ix1 + step, z0), floor_height(ix1 + step, z0 + step)
		)
	var tx := (x - x0) / step
	var tz := (z - z0) / step
	var a := floor_height(x0, z0)
	var b := floor_height(x0 + step, z0)
	var c := floor_height(x0, z0 + step)
	if tx + tz <= 1.0:
		return a + (b - a) * tx + (c - a) * tz
	var d := floor_height(x0 + step, z0 + step)
	return d + (c - d) * (1.0 - tx) + (b - d) * (1.0 - tz)

static func _bary_stitched(u: float, v: float, h_b0: float, h_bm: float, h_b1: float, h_t0: float, h_t1: float) -> float:
	if 2.0 * u + v <= 1.0:
		return h_b0 + (h_bm - h_b0) * (2.0 * u) + (h_t0 - h_b0) * v
	if 2.0 * (1.0 - u) + v <= 1.0:
		return h_b1 + (h_bm - h_b1) * (2.0 * (1.0 - u)) + (h_t1 - h_b1) * v
	return h_bm * (1.0 - v) + h_t0 * (0.5 * (1.0 + v) - u) + h_t1 * (u - 0.5 * (1.0 - v))

static func _floor_normal_fast(x: float, z: float, h_center: float = NAN) -> Vector3:
	const EPS := 1.5
	var h0: float = floor_height(x, z) if is_nan(h_center) else h_center
	var hx: float = floor_height(x + EPS, z)
	var hz: float = floor_height(x, z + EPS)
	return Vector3(h0 - hx, EPS, h0 - hz).normalized()

static func _build_seabed_grid_mesh(x0: int, x1: int, z0: int, z1: int, step: int, stitch_side: String = "") -> ArrayMesh:
	var nx: int = (x1 - x0) / step
	var nz: int = (z1 - z0) / step
	var vx_count: int = nx + 1
	var vz_count: int = nz + 1
	var vert_count: int = vx_count * vz_count
	var half: float = float(step) * 0.5
	var stitch_count: int = 0
	if stitch_side == "min_z" or stitch_side == "max_z":
		stitch_count = (SEABED_INNER_X1 - SEABED_INNER_X0) / step
	elif stitch_side == "min_x" or stitch_side == "max_x":
		stitch_count = (SEABED_INNER_Z1 - SEABED_INNER_Z0) / step
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	vertices.resize(vert_count + stitch_count)
	normals.resize(vert_count + stitch_count)
	uvs.resize(vert_count + stitch_count)
	var inv_step: float = 1.0 / float(step)
	var v_idx: int = 0
	for ix in range(vx_count):
		var fx: float = float(x0 + ix * step)
		var u: float = fx * inv_step
		for iz in range(vz_count):
			var fz: float = float(z0 + iz * step)
			var h: float = floor_height(fx, fz)
			vertices[v_idx] = Vector3(fx, h, fz)
			normals[v_idx] = _floor_normal_fast(fx, fz, h)
			uvs[v_idx] = Vector2(u, fz * inv_step)
			v_idx += 1

	var indices := PackedInt32Array()
	indices.resize(nx * nz * 6 + stitch_count * 3)
	var i_idx: int = 0
	for ix in range(nx):
		var cell_x: int = x0 + ix * step
		var row0: int = ix * vz_count
		var row1: int = (ix + 1) * vz_count
		for iz in range(nz):
			var cell_z: int = z0 + iz * step
			var i0: int = row0 + iz
			var i1: int = row1 + iz
			var i2: int = row0 + iz + 1
			var i3: int = row1 + iz + 1
			if stitch_side == "min_z" and iz == 0 and cell_x >= SEABED_INNER_X0 and cell_x < SEABED_INNER_X1:
				var mx: float = float(cell_x) + half
				var mz: float = float(z0)
				var mh: float = floor_height(mx, mz)
				var im: int = v_idx
				vertices[im] = Vector3(mx, mh, mz)
				normals[im] = _floor_normal_fast(mx, mz, mh)
				uvs[im] = Vector2(mx * inv_step, mz * inv_step)
				v_idx += 1
				indices[i_idx] = i0; indices[i_idx + 1] = im; indices[i_idx + 2] = i2
				indices[i_idx + 3] = im; indices[i_idx + 4] = i3; indices[i_idx + 5] = i2
				indices[i_idx + 6] = im; indices[i_idx + 7] = i1; indices[i_idx + 8] = i3
				i_idx += 9
				continue
			if stitch_side == "max_z" and iz == nz - 1 and cell_x >= SEABED_INNER_X0 and cell_x < SEABED_INNER_X1:
				var mx: float = float(cell_x) + half
				var mz: float = float(z1)
				var mh: float = floor_height(mx, mz)
				var im: int = v_idx
				vertices[im] = Vector3(mx, mh, mz)
				normals[im] = _floor_normal_fast(mx, mz, mh)
				uvs[im] = Vector2(mx * inv_step, mz * inv_step)
				v_idx += 1
				indices[i_idx] = i0; indices[i_idx + 1] = im; indices[i_idx + 2] = i2
				indices[i_idx + 3] = i0; indices[i_idx + 4] = i1; indices[i_idx + 5] = im
				indices[i_idx + 6] = i1; indices[i_idx + 7] = i3; indices[i_idx + 8] = im
				i_idx += 9
				continue
			if stitch_side == "max_x" and ix == nx - 1 and cell_z >= SEABED_INNER_Z0 and cell_z < SEABED_INNER_Z1:
				var mx: float = float(x1)
				var mz: float = float(cell_z) + half
				var mh: float = floor_height(mx, mz)
				var im: int = v_idx
				vertices[im] = Vector3(mx, mh, mz)
				normals[im] = _floor_normal_fast(mx, mz, mh)
				uvs[im] = Vector2(mx * inv_step, mz * inv_step)
				v_idx += 1
				indices[i_idx] = i0; indices[i_idx + 1] = i1; indices[i_idx + 2] = im
				indices[i_idx + 3] = i0; indices[i_idx + 4] = im; indices[i_idx + 5] = i2
				indices[i_idx + 6] = im; indices[i_idx + 7] = i3; indices[i_idx + 8] = i2
				i_idx += 9
				continue
			if stitch_side == "min_x" and ix == 0 and cell_z >= SEABED_INNER_Z0 and cell_z < SEABED_INNER_Z1:
				var mx: float = float(x0)
				var mz: float = float(cell_z) + half
				var mh: float = floor_height(mx, mz)
				var im: int = v_idx
				vertices[im] = Vector3(mx, mh, mz)
				normals[im] = _floor_normal_fast(mx, mz, mh)
				uvs[im] = Vector2(mx * inv_step, mz * inv_step)
				v_idx += 1
				indices[i_idx] = i0; indices[i_idx + 1] = i1; indices[i_idx + 2] = im
				indices[i_idx + 3] = im; indices[i_idx + 4] = i1; indices[i_idx + 5] = i3
				indices[i_idx + 6] = im; indices[i_idx + 7] = i3; indices[i_idx + 8] = i2
				i_idx += 9
				continue
			indices[i_idx] = i0
			indices[i_idx + 1] = i1
			indices[i_idx + 2] = i2
			indices[i_idx + 3] = i1
			indices[i_idx + 4] = i3
			indices[i_idx + 5] = i2
			i_idx += 6

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	rng.seed = 240913
	_create_environment()
	_create_terrain()
	_populate()
	_naturalize_scene_materials()
	seabed_ecology = SeabedEcology.new()
	seabed_ecology.name = "SeabedEcology"
	add_child(seabed_ecology)
	seabed_ecology.configure(self)
	set_depth(maxf(0.0, -last_diver_pos.y))
	_sync_animation_lod(last_diver_pos)

func _create_environment() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.065, 0.22, 0.26)
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.24, 0.42, 0.61)
	sky_material.sky_horizon_color = Color(0.70, 0.78, 0.80)
	sky_material.ground_bottom_color = Color(0.025, 0.09, 0.12)
	sky_material.ground_horizon_color = Color(0.16, 0.28, 0.31)
	environment.sky = Sky.new()
	environment.sky.sky_material = sky_material
	air_sky = environment.sky
	water_atmosphere = ShaderMaterial.new()
	water_atmosphere.shader = load("res://shaders/ocean_atmosphere.gdshader")
	water_sky = Sky.new()
	water_sky.radiance_size = Sky.RADIANCE_SIZE_32
	water_sky.process_mode = Sky.PROCESS_MODE_QUALITY
	water_sky.sky_material = water_atmosphere
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_sky_contribution = 0.0
	environment.ambient_light_color = Color(0.68, 0.80, 0.81)
	environment.ambient_light_energy = 0.405
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.10, 0.29, 0.32)
	environment.fog_light_energy = 0.78
	environment.fog_density = 0.009
	environment.fog_sun_scatter = 0.04
	environment.fog_sky_affect = 1.0
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-68, -28, 0)
	sun.light_color = Color(1.0, 0.97, 0.89)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 50.0
	add_child(sun)

	var surface := MeshInstance3D.new()
	surface.name = "WaterSurface"
	water_surface = surface
	# Blender-authored radial topology resolves nearby wave crests while spending
	# fewer vertices on the distant horizon. Its shader remains world anchored.
	var ocean_patch: Node3D = load("res://assets/models/ocean_surface.glb").instantiate()
	var ocean_meshes := ocean_patch.find_children("*", "MeshInstance3D", true, false)
	assert(ocean_meshes.size() == 1, "Authored ocean patch must contain one mesh")
	surface.mesh = (ocean_meshes[0] as MeshInstance3D).mesh
	ocean_patch.free()
	surface.set_meta("authored_model", "ocean-surface-3")
	surface.position = Vector3.ZERO
	water_surface_mat = ShaderMaterial.new()
	water_surface_mat.shader = load("res://shaders/water.gdshader")
	water_underwater_mat = ShaderMaterial.new()
	water_underwater_mat.shader = load("res://shaders/water_underwater.gdshader")
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
	var sun_dir := sun.transform.basis.z
	water_surface_mat.set_shader_parameter("ripple_normal", ripples)
	water_surface_mat.set_shader_parameter("sun_direction", sun_dir)
	water_underwater_mat.set_shader_parameter("ripple_normal", ripples)
	water_underwater_mat.set_shader_parameter("sun_direction", sun_dir)
	surface.material_override = water_surface_mat
	surface.extra_cull_margin = 1.2
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

	# Broad curtains alternate with thin shafts; their shared shader fades gently
	# at the surface and at depth instead of filling the whole sea with glow.
	var beam_specs := [
		{"pos": Vector3(-11, -19.5, 2), "size": Vector2(5.2, 26.0), "rot": Vector3(0, -18, -18)},
		{"pos": Vector3(10, -19.0, 0), "size": Vector2(5.8, 26.0), "rot": Vector3(0, -22, -17)},
		{"pos": Vector3(-4, -21.0, -12), "size": Vector2(6.5, 28.0), "rot": Vector3(0, -15, -19)},
		{"pos": Vector3(16, -20.0, -10), "size": Vector2(6.2, 28.0), "rot": Vector3(0, -24, -18)},
		{"pos": Vector3(-18, -22.0, -18), "size": Vector2(7.0, 30.0), "rot": Vector3(0, -16, -18)},
		{"pos": Vector3(6, -24.0, -26), "size": Vector2(7.5, 32.0), "rot": Vector3(0, -20, -18)},
		{"pos": Vector3(24, -22.5, 6), "size": Vector2(5.5, 26.0), "rot": Vector3(0, -20, -17)},
		{"pos": Vector3(-24, -21.5, 8), "size": Vector2(5.4, 26.0), "rot": Vector3(0, -18, -19)},
		{"pos": Vector3(28, -32.0, -42), "size": Vector2(8.0, 36.0), "rot": Vector3(0, -22, -16)},
		{"pos": Vector3(-26, -30.0, -38), "size": Vector2(7.5, 34.0), "rot": Vector3(0, -18, -17)},
	]
	for spec in beam_specs:
		var beam := MeshInstance3D.new()
		var b_quad := QuadMesh.new()
		b_quad.size = spec["size"]
		beam.mesh = b_quad
		beam.material_override = shaft_material
		beam.position = spec["pos"]
		beam.rotation_degrees = spec["rot"]
		add_child(beam)

func _create_terrain() -> void:
	var ix0 := SEABED_INNER_X0
	var ix1 := SEABED_INNER_X1
	var iz0 := SEABED_INNER_Z0
	var iz1 := SEABED_INNER_Z1
	var terrain := MeshInstance3D.new()
	terrain.name = "Seabed"
	terrain.mesh = _build_seabed_grid_mesh(ix0, ix1, iz0, iz1, SEABED_INNER_STEP)
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
	material.set_shader_parameter("region_palette", OceanDepths.region_palette_texture())
	material.set_shader_parameter("use_region_palette", true)
	terrain.material_override = material
	terrain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(terrain)
	terrain.create_trimesh_collision()

	# Conforming Outer Open-World Seabed Chunks (12m grid with 6m midpoint seam stitching)
	var chunk_defs := [
		{"name": "OuterSeabed_North", "x0": -960, "x1": 960, "z0": iz1, "z1": 960, "stitch": "min_z"},
		{"name": "OuterSeabed_South", "x0": -960, "x1": 960, "z0": -960, "z1": iz0, "stitch": "max_z"},
		{"name": "OuterSeabed_West", "x0": -960, "x1": ix0, "z0": iz0, "z1": iz1, "stitch": "max_x"},
		{"name": "OuterSeabed_East", "x0": ix1, "x1": 960, "z0": iz0, "z1": iz1, "stitch": "min_x"}
	]
	for cdef in chunk_defs:
		var cx0: int = int(cdef["x0"])
		var cx1: int = int(cdef["x1"])
		var cz0: int = int(cdef["z0"])
		var cz1: int = int(cdef["z1"])
		var chunk := MeshInstance3D.new()
		chunk.name = str(cdef["name"])
		chunk.mesh = _build_seabed_grid_mesh(cx0, cx1, cz0, cz1, SEABED_OUTER_STEP, str(cdef["stitch"]))
		chunk.material_override = material
		chunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(chunk)
		chunk.create_trimesh_collision()
		outer_seabed_chunks.append(chunk)

func model(asset: String, at: Vector3, size: float = 1.0, visibility_range: float = 48.0) -> Node3D:
	if not cache.has(asset):
		cache[asset] = load("res://assets/models/" + asset + ".glb")
	var instance: Node3D = cache[asset].instantiate()
	add_child(instance)
	instance.position = at
	instance.scale = Vector3.ONE * size
	instance.set_meta("visual_asset", asset)
	# Rigid models share the same natural, depth-aware lighting as vegetation.
	# Surface overrides leave the imported PBR resources and animations intact.
	apply_plant_shader(instance, 0.0, 0.0, asset)
	var casts_landmark_shadow := asset in ["pod", "ruins", "shipwreck", "manta_ray", "sea_turtle", "fish_predator", "fish_abyss"]
	if visibility_range > 0.0:
		for child in instance.find_children("*", "GeometryInstance3D", true, false):
			var gi: GeometryInstance3D = child
			if not casts_landmark_shadow:
				gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			gi.visibility_range_end = visibility_range
			gi.set_meta("base_visibility_range", visibility_range)
			scope_meshes.append(gi)
			gi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
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

func _asset_emission_scale(asset_key: String) -> float:
	# Keep living lights and artificial beacons legible without making every
	# rock, leaf and coral emit daylight in the abyss.
	match asset_key:
		"jellyfish":
			return 0.32
		"fish_abyss", "crystal_spire":
			return 0.12
		"pod", "shipwreck", "ruins", "resource_quartz":
			return 0.06
		"giant_clam", "tubeworms", "anemone":
			return 0.035
		_:
			return 0.012

func configure_natural_palette(material: ShaderMaterial, asset_key: String, region_id: String = "core") -> void:
	# Texture pigments remain intact. Depth absorption belongs to incident light.
	var profile := ArtDirection.material_profile(asset_key, "", region_id)
	material.set_shader_parameter("natural_palette", false)
	material.set_shader_parameter("palette_strength", 0.0)
	material.set_shader_parameter("palette_dark", profile.shadow)
	material.set_shader_parameter("palette_light", profile.tip)
	material.set_shader_parameter("roughness", profile.roughness)
	material.set_shader_parameter("metallic", profile.metallic)

func _attach_landmark_collision(instance: Node3D, asset_key: String) -> void:
	# The original collision geometry is independent of the replacement artwork.
	var frozen: PackedScene = load("res://assets/collision/" + asset_key + ".tscn")
	instance.add_child(frozen.instantiate())

func _naturalize_scene_materials() -> void:
	ModelFinish.apply(self, "environment")
	# Decorative lights support local composition, never blanket illumination.
	for light_node in find_children("*", "OmniLight3D", true, false):
		var omni := light_node as OmniLight3D
		var is_authored: bool = bool(omni.get_meta("authored_light", false))
		var is_vent: bool = omni in vent_lights
		omni.light_cull_mask = 2
		omni.distance_fade_enabled = true
		omni.distance_fade_begin = 135.0 if is_authored else (40.0 if is_vent else 28.0)
		omni.distance_fade_length = 24.0 if is_authored else 12.0
		if omni.global_position.y < -4.0 and not is_authored and not is_vent:
			omni.light_energy *= 0.22
			omni.omni_range = minf(omni.omni_range * 0.72, 16.0)

func apply_plant_shader(node: Node3D, sway_str: float = 0.35, sway_freq: float = 1.25, asset_key: String = "") -> void:
	var palette_key := asset_key if asset_key != "" else str(node.get_meta("visual_asset", ""))
	var share_material := palette_key != "" and palette_key != "giant_clam"
	var world_pos := node.global_position if node.is_inside_tree() else node.position
	if not node.is_inside_tree():
		var parent_node := node.get_parent()
		while parent_node is Node3D and parent_node != self:
			world_pos = (parent_node as Node3D).transform * world_pos
			parent_node = parent_node.get_parent()
	var region_id := ArtDirection.region_id_at(world_pos.x, world_pos.z)
	for child in node.find_children("*", "MeshInstance3D"):
		var mesh_inst: MeshInstance3D = child
		if not mesh_inst.mesh:
			continue
		for s in range(mesh_inst.mesh.get_surface_count()):
			var orig_mat = mesh_inst.mesh.surface_get_material(s)
			if orig_mat is BaseMaterial3D and orig_mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				var glass_key := "glass_%s_%d_%d" % [palette_key, orig_mat.get_instance_id(), s]
				var gmat: StandardMaterial3D = plant_materials.get(glass_key, null)
				if gmat == null or not share_material:
					gmat = orig_mat.duplicate() as StandardMaterial3D
					if gmat != null:
						gmat.cull_mode = BaseMaterial3D.CULL_DISABLED
						if gmat.emission_enabled:
							gmat.emission_energy_multiplier *= _asset_emission_scale(palette_key)
						if share_material:
							plant_materials[glass_key] = gmat
				if gmat != null:
					mesh_inst.set_surface_override_material(s, gmat)
				continue
			var material_id: int = orig_mat.get_instance_id() if orig_mat != null else 0
			var cache_key := "%s_%s_%d_%d_%.2f_%.2f" % [palette_key, region_id, material_id, s, sway_str, sway_freq]
			var sm: ShaderMaterial = plant_materials.get(cache_key, null)
			if sm == null or not share_material:
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
						var em_col: Color = orig_mat.emission
						if em_col.r + em_col.g + em_col.b < 0.01 and orig_mat.emission_texture != null:
							em_col = Color.WHITE
						sm.set_shader_parameter("emission", em_col)
						sm.set_shader_parameter("emission_energy", orig_mat.emission_energy_multiplier * _asset_emission_scale(palette_key))
						sm.set_shader_parameter("emission_texture", orig_mat.emission_texture)
				sm.set_shader_parameter("sway_strength", sway_str)
				sm.set_shader_parameter("sway_frequency", sway_freq)
				configure_natural_palette(sm, palette_key, region_id)
				if share_material:
					plant_materials[cache_key] = sm
			mesh_inst.set_surface_override_material(s, sm)
		mesh_inst.extra_cull_margin = maxf(mesh_inst.extra_cull_margin, sway_str * 3.0)

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
	marker.text = "◇  LIFEPOD  /  逃生舱"
	marker.position = HOME + Vector3(0, 3.35, 0)
	marker.modulate = Color(0.65, 1.0, 0.9)
	_configure_label_3d(marker, 48, 0.009)
	marker.visibility_range_end = 13.5
	marker.visibility_range_end_margin = 2.0
	marker.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
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
	var b_box := CylinderMesh.new()
	b_box.bottom_radius = 0.42
	b_box.top_radius = 0.30
	b_box.height = 1.04
	b_box.radial_segments = 24
	c_base.mesh = b_box
	var c_mat := StandardMaterial3D.new()
	c_mat.albedo_color = Color("ebe3d0")
	c_mat.metallic = 0.12
	c_mat.roughness = 0.34
	c_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	c_mat.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	c_base.material_override = c_mat
	escape_console.add_child(c_base)
	var c_brass_mat := StandardMaterial3D.new()
	c_brass_mat.albedo_color = Color("cba052")
	c_brass_mat.metallic = 0.76
	c_brass_mat.roughness = 0.28
	for foot_i in range(3):
		var fa := float(foot_i) * TAU / 3.0 + 0.4
		var foot_strut := MeshInstance3D.new()
		foot_strut.mesh = _make_organic_limb_mesh([
			Vector3(cos(fa) * 0.34, -0.15, sin(fa) * 0.34),
			Vector3(cos(fa) * 0.58, -0.38, sin(fa) * 0.58),
			Vector3(cos(fa) * 0.66, -0.54, sin(fa) * 0.66)
		], [0.06, 0.05, 0.075], 8, 4, 0.02, 0.0)
		foot_strut.material_override = c_brass_mat
		escape_console.add_child(foot_strut)
	for ring_h: float in [-0.28, 0.28, 0.50]:
		var c_ring := MeshInstance3D.new()
		var ct := TorusMesh.new()
		var rr := lerpf(0.42, 0.32, (ring_h + 0.28) / 0.8)
		ct.inner_radius = rr - 0.028
		ct.outer_radius = rr + 0.028
		ct.rings = 24
		ct.ring_segments = 8
		c_ring.mesh = ct
		c_ring.position.y = ring_h
		c_ring.material_override = c_brass_mat
		escape_console.add_child(c_ring)
	var c_collar := MeshInstance3D.new()
	var collar_box := BoxMesh.new()
	collar_box.size = Vector3(0.88, 0.16, 0.64)
	c_collar.mesh = collar_box
	c_collar.position = Vector3(0, 0.54, 0.10)
	c_collar.rotation_degrees = Vector3(-24, 0, 0)
	c_collar.material_override = c_brass_mat
	escape_console.add_child(c_collar)
	var screen_mesh := MeshInstance3D.new()
	var s_quad := QuadMesh.new()
	s_quad.size = Vector2(0.76, 0.46)
	screen_mesh.mesh = s_quad
	screen_mesh.position = Vector3(0, 0.64, 0.14)
	screen_mesh.rotation_degrees = Vector3(-24, 0, 0)
	var s_mat := StandardMaterial3D.new()
	s_mat.albedo_color = ArtDirection.INK
	s_mat.emission_enabled = true
	s_mat.emission = ArtDirection.CYAN
	s_mat.emission_energy_multiplier = 0.42
	screen_mesh.material_override = s_mat
	escape_console.add_child(screen_mesh)
	var c_light := OmniLight3D.new()
	c_light.position = Vector3(0, 1.0, 0.4)
	c_light.light_color = Color(0.2, 0.9, 1.0)
	c_light.light_energy = 2.5
	c_light.omni_range = 8.0
	escape_console.add_child(c_light)
	var c_label := Label3D.new()
	c_label.text = "⬡  ESCAPE CONSOLE  /  逃生控制台"
	c_label.position = Vector3(0, 1.6, 0)
	c_label.modulate = Color(0.3, 0.95, 1.0)
	_configure_label_3d(c_label, 32, 0.007)
	c_label.visibility_range_end = 9.5
	escape_console.add_child(c_label)
	add_child(escape_console)

	# 2. 浅海与海沟古代遗迹拱门
	var arch := model("ruins", Vector3(2, floor_height(2, -25), -25), 1.4, 95.0)
	arch.rotation.y = 0.15
	_attach_landmark_collision(arch, "ruins")
	var arch_marker := _create_marker("◈  ANCIENT RUINS  /  古代海沟遗迹", Vector3(2, floor_height(2, -25) + 6.0, -25), Color(0.4, 0.9, 0.8))
	add_child(arch_marker)

	# 3. 深渊古代巨石祭坛
	var altar_pos := Vector3(-50, floor_height(-50, -170), -170)
	var altar := model("ruins", altar_pos, 1.8, 95.0)
	altar.rotation.y = 0.45
	_attach_landmark_collision(altar, "ruins")
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
	_attach_landmark_collision(wreck, "shipwreck")
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
	var wreck_marker := _create_marker("⚓  RESEARCH SHIPWRECK  /  失事科考潜艇", wreck_pos + Vector3(0, 6.4, 0), Color(1.0, 0.8, 0.4))
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
	bb_label.modulate = Color(0.35, 0.95, 1.0)
	_configure_label_3d(bb_label, 32, 0.007)
	bb_label.visibility_range_end = 9.5
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
	_attach_landmark_collision(dock_arch, "ruins")
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

	# 6.4 开放海域四大远洋航道导航浮标（移除封闭屏障，指引无缝外海疆域）
	_create_nav_buoy(Vector3(12, -8, 135), "▲  北境远洋航道  ·  晴空珊瑚环礁 / 翡翠巨藻海峡")
	_create_nav_buoy(Vector3(210, -24, -45), "▶  东海远洋航道  ·  沉没星象古都 / 极光海岭")
	_create_nav_buoy(Vector3(-210, -28, -75), "◀  西洋远洋航道  ·  巨兽龙骨荒原 / 黑曜石火山口")
	_create_nav_buoy(Vector3(0, -45, -235), "▼  南极渊远洋航道  ·  远古深海母树 / 极渊星辉圣域")

	# Decorative colonies are now streamed and authored by OceanComposition.

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
	_spawn_coral_reef_colonies()
	_spawn_extra_creatures()
	_spawn_sea_wolves()
	_spawn_schooling_fish()
	_creatures_dirty = true
	for creature in get_creatures():
		_register_creature_hitbox(creature)

	_create_particles()
	_populate_open_world_frontiers()

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

func _spawn_coral_reef_colonies() -> void:
	# 6.5 琉璃珊瑚礁花园地标群落 (浅海救生舱周边的多层高保真珊瑚礁生态区)
	var garden_center := Vector3(18, floor_height(18, -8), -8)
	var garden_marker := _create_marker("✿  CORAL SANCTUARY  /  琉璃珊瑚礁花园", garden_center + Vector3(0, 7.2, 0), Color(0.35, 1.0, 0.88))
	add_child(garden_marker)
	var garden_light := OmniLight3D.new()
	garden_light.position = garden_center + Vector3(0, 3.8, 0)
	garden_light.light_color = Color(0.25, 0.95, 0.88)
	garden_light.light_energy = 1.4
	garden_light.omni_range = 12.0
	add_child(garden_light)

	# 在潜水员出生点视野前方与琉璃珊瑚礁花园精心布置代表性高保真珊瑚礁组合
	var showcase_spots := [
		{"asset": "brain_coral", "pos": Vector2(-4.2, 6.5), "scale": 1.35, "yaw": 0.4},
		{"asset": "staghorn_coral", "pos": Vector2(4.6, 5.8), "scale": 1.45, "yaw": 1.2},
		{"asset": "table_coral", "pos": Vector2(-2.4, 2.2), "scale": 1.40, "yaw": 0.8},
		{"asset": "giant_clam", "pos": Vector2(2.6, 3.2), "scale": 1.28, "yaw": -0.6},
		{"asset": "barrel_sponge", "pos": Vector2(-6.8, 3.8), "scale": 1.32, "yaw": 2.1},
		{"asset": "sea_lily", "pos": Vector2(6.4, 2.0), "scale": 1.35, "yaw": -1.1},
		{"asset": "table_coral", "pos": Vector2(15.5, -6.5), "scale": 1.65, "yaw": 0.3},
		{"asset": "brain_coral", "pos": Vector2(19.2, -9.8), "scale": 1.50, "yaw": 1.7},
		{"asset": "staghorn_coral", "pos": Vector2(21.0, -5.5), "scale": 1.55, "yaw": 2.4},
		{"asset": "giant_clam", "pos": Vector2(17.2, -7.2), "scale": 1.40, "yaw": -0.4},
		{"asset": "barrel_sponge", "pos": Vector2(14.0, -11.0), "scale": 1.50, "yaw": 0.9},
		{"asset": "sea_lily", "pos": Vector2(20.5, -12.0), "scale": 1.45, "yaw": 1.5},
	]
	for item in showcase_spots:
		var p2: Vector2 = item["pos"]
		var kind_id: String = item["asset"]
		var node := _place_reef_element(kind_id, Vector3(p2.x, floor_height(p2.x, p2.y), p2.y), float(item["scale"]), float(item["yaw"]), 55.0)
		if kind_id == "giant_clam":
			var pearl_light := OmniLight3D.new()
			pearl_light.position = node.position + Vector3(0, 1.2, 0)
			pearl_light.light_color = Color(0.28, 0.92, 1.0)
			pearl_light.light_energy = 2.4
			pearl_light.omni_range = 10.0
			add_child(pearl_light)

	# 5. 深海发光巨砗磲 (18 处：浅海珊瑚花园、古代遗迹与深渊晶簇海盆)
	for i in range(18):
		var x: float = rng.randf_range(-95, 105)
		var z: float = rng.randf_range(-165, 25)
		_place_reef_element("giant_clam", Vector3(x, floor_height(x, z), z), rng.randf_range(0.9, 1.5), rng.randf_range(0, TAU), 45.0)


func _place_reef_element(asset: String, at: Vector3, scale_val: float, yaw: float, vis_range: float) -> Node3D:
	var node := model(asset, at, scale_val, vis_range)
	node.rotation.y = yaw
	node.set_meta("kind", asset)
	match asset:
		"brain_coral":
			node.set_meta("name", "迷宫脑珊瑚")
			apply_plant_shader(node, 0.05, 1.15, asset)
			brain_corals.append(node)
		"staghorn_coral":
			node.set_meta("name", "鹿角珊瑚丛")
			apply_plant_shader(node, 0.18, 1.25, asset)
			staghorn_corals.append(node)
		"table_coral":
			node.set_meta("name", "层叠桌形珊瑚")
			apply_plant_shader(node, 0.08, 1.10, asset)
			table_corals.append(node)
		"barrel_sponge":
			node.set_meta("name", "巨型褶皱桶状海绵")
			apply_plant_shader(node, 0.10, 1.05, asset)
			barrel_sponges.append(node)
		"giant_clam":
			node.set_meta("kind", "giant_clam")
			node.set_meta("name", "深海发光巨砗磲")
			node.set_meta("retract_progress", 0.0)
			node.set_meta("last_retract_applied", -1.0)
			node.set_meta("clam_cooldown", 0.0)
			apply_plant_shader(node, 0.06, 1.20)
			var mats: Array[ShaderMaterial] = []
			for child in node.find_children("*", "MeshInstance3D", true, false):
				var mi: MeshInstance3D = child
				for s in range(mi.mesh.get_surface_count()):
					var sm = mi.get_surface_override_material(s)
					if sm is ShaderMaterial:
						mats.append(sm)
			node.set_meta("shader_materials", mats)
			giant_clams.append(node)
		"sea_lily":
			node.set_meta("name", "深海羽状海百合")
			apply_plant_shader(node, 0.40, 1.35, asset)
			sea_lilies.append(node)
	dynamic_plants.append(node)
	return node

func _configure_label_3d(lbl: Label3D, orig_font_size: int, orig_pixel_size: float) -> void:
	if "/" in lbl.text and not "\n" in lbl.text:
		lbl.text = lbl.text.get_slice("/", 1).strip_edges()
	lbl.font = LABEL_FONT
	lbl.font_size = LABEL_FONT_SIZE
	lbl.pixel_size = orig_pixel_size * float(orig_font_size) / float(LABEL_FONT_SIZE)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = false
	lbl.visibility_range_end = 10.5 if "[E]" in lbl.text else 28.0
	var is_warm := lbl.modulate.r > lbl.modulate.b * 1.2
	lbl.modulate = ArtDirection.AMBER if is_warm else ArtDirection.PAPER.lerp(ArtDirection.CYAN, 0.42)
	lbl.outline_modulate = Color(ArtDirection.INK.r, ArtDirection.INK.g, ArtDirection.INK.b, 0.88)
	lbl.outline_size = 4

func _create_marker(text: String, at: Vector3, color: Color) -> Label3D:
	var marker := Label3D.new()
	# Long bilingual labels stay in the chart; world labels show the short name.
	marker.text = text.get_slice("/", 1).strip_edges() if "/" in text else text
	marker.position = at
	marker.modulate = color
	_configure_label_3d(marker, 40, 0.0085)
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
	var seabed_node := get_node_or_null("Seabed") as MeshInstance3D
	var basalt_mat: Material = seabed_node.material_override if seabed_node != null else null
	if basalt_mat == null:
		var fallback_basalt := StandardMaterial3D.new()
		fallback_basalt.albedo_color = Color("2d2825")
		fallback_basalt.roughness = 0.94
		fallback_basalt.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
		basalt_mat = fallback_basalt
	var spire_specs := [
		{"offset": Vector3.ZERO, "h": chimney_height, "r0": 2.25, "r1": 0.84, "tilt": Vector3(2.5, 14.0, -1.8), "seed": 1.1},
		{"offset": Vector3(1.75, 0.0, 0.80), "h": 4.9, "r0": 1.25, "r1": 0.46, "tilt": Vector3(-5.0, 38.0, 6.0), "seed": 2.7},
		{"offset": Vector3(-1.45, 0.0, -1.05), "h": 3.5, "r0": 1.05, "r1": 0.38, "tilt": Vector3(4.5, -24.0, -5.0), "seed": 4.3},
	]
	for spec in spire_specs:
		var chimney := MeshInstance3D.new()
		chimney.mesh = _build_faceted_basalt_spire_mesh(float(spec["h"]), float(spec["r0"]), float(spec["r1"]), float(spec["seed"]))
		chimney.material_override = basalt_mat
		chimney.position = spec["offset"] + Vector3(0, -0.35, 0)
		chimney.rotation_degrees = spec["tilt"]
		chimney.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		chimney.layers = 3
		vent_root.add_child(chimney)

	var crater := MeshInstance3D.new()
	var crater_mesh := CylinderMesh.new()
	crater_mesh.bottom_radius = 0.62
	crater_mesh.top_radius = 0.48
	crater_mesh.height = 0.26
	crater_mesh.radial_segments = 7
	crater.mesh = crater_mesh
	var magma := StandardMaterial3D.new()
	magma.set_meta("painterly_finished", true)
	magma.albedo_color = Color("cf642c")
	magma.roughness = 0.55
	magma.emission_enabled = true
	magma.emission = Color("e07838")
	magma.emission_energy_multiplier = 1.15
	crater.material_override = magma
	crater.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	crater.position.y = chimney_height - 0.48
	vent_root.add_child(crater)

	var light := OmniLight3D.new()
	light.position = at + Vector3(0, chimney_height + 1.2, 0)
	light.light_color = Color(1.0, 0.52, 0.16)
	light.light_energy = 4.8
	light.omni_range = 24.0
	light.omni_attenuation = 1.22
	light.distance_fade_enabled = true
	light.distance_fade_begin = 90.0
	light.distance_fade_length = 24.0
	add_child(light)
	vent_lights.append(light)

	var plume := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var bubble := SphereMesh.new()
	bubble.radius = 0.08
	bubble.height = 0.16
	bubble.radial_segments = 6
	bubble.rings = 3
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
	var phase: float = rng.randf_range(0, TAU)
	var swim_speed: float = rng.randf_range(0.9, 1.45)
	var rad: float = rng.randf_range(3.8, 7.2)
	body.position = center + Vector3(sin(phase) * rad, sin(phase * 2.2) * 0.8, cos(phase) * (rad * 0.7))
	body.collision_layer = 2
	body.set_meta("kind", "fish_small")
	body.set_meta("name", "发光小金鱼")
	body.set_meta("center", center)
	body.set_meta("phase", phase)
	body.set_meta("swim_speed", swim_speed)
	body.set_meta("radius", rad)
	body.set_meta("fish_scale", size)
	body.set_meta("stun_timer", 0.0)
	body.set_meta("dead", false)
	body.set_meta("fright_timer", 0.0)
	add_child(body)

	var creature := model("fish_small", Vector3.ZERO, size, 35.0)
	creature.reparent(body, false)
	var init_tangent := Vector3(cos(phase) * rad, cos(phase * 2.2) * 1.76, -sin(phase) * (rad * 0.7))
	if init_tangent.length_squared() > 0.0001:
		var dir_norm := init_tangent.normalized()
		var up := Vector3.UP if absf(dir_norm.y) < 0.95 else Vector3.FORWARD
		creature.basis = (Basis.looking_at(-dir_norm, up) * Basis(Vector3.FORWARD, -sin(phase * 1.5) * 0.28)).scaled(Vector3.ONE * size)
	body.set_meta("fish_model", creature)
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
	_creatures_dirty = true

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
	_creatures_dirty = true

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
	_creatures_dirty = true

func remove_small_fish(body: Node3D) -> void:
	body.set_meta("is_creature", false)
	if small_fish.has(body):
		small_fish.erase(body)
	if fish.has(body):
		fish.erase(body)
	_creatures_dirty = true
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
		var dist_sq: float = p.global_position.distance_squared_to(diver_pos)
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

		if dist_sq < detect_r * detect_r:
			if dist_sq > 11.0 * 11.0 and not flashlight_on:
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
				if dist_sq < attack_r * attack_r and bite_cd <= 0.0:
					p.set_meta("bite_cooldown", 2.8)
					p.set_meta("flee_timer", 1.8)
					p.set_meta("has_attacked_player", true)
					var player: AnimationPlayer = p.get_meta("animation_player", null)
					if is_instance_valid(player):
						player.speed_scale = 1.0
						player.play("bite", 0.08)
					bites.append({
						"name": str(p.get_meta("name")),
						"damage": float(p.get_meta("damage")),
						"pos": p.global_position,
						"attacker": p
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
			n.set_meta("has_stasis_aura", false)
			var aura := n.get_node_or_null("StasisAura")
			if is_instance_valid(aura):
				aura.queue_free()
		return true
	if bool(n.get_meta("dead", false)):
		# 击杀后尸体软趴趴沉在海底，便于搜刮
		var seabed := floor_height(n.position.x, n.position.z) + 0.16
		if n.position.y > seabed:
			n.position.y = maxf(seabed, n.position.y - 4.5 * delta)
			var corpse_vis: Node3D = n.get_meta("fish_model", null) if n.has_meta("fish_model") else n
			if is_instance_valid(corpse_vis):
				corpse_vis.rotation.z = move_toward(corpse_vis.rotation.z, 1.15, delta * 1.8)
		return true
	n.set_meta("motion_clock", float(n.get_meta("motion_clock", clock - delta)) + delta)
	var stun: float = float(n.get_meta("stun_timer", 0.0))
	if stun > 0.0:
		n.set_meta("stun_timer", maxf(0.0, stun - delta))
		var stun_vis: Node3D = n.get_meta("fish_model", null) if n.has_meta("fish_model") else n
		if is_instance_valid(stun_vis):
			stun_vis.rotation.z += sin(clock * 25.0) * 0.03
		return true
	return false

func strike_predator(from: Vector3, dir: Vector3, max_range: float, damage: float, knockback: float, is_sonic: bool, max_targets: int = 99, cleave_angle: float = -1.0) -> Dictionary:
	var angle_threshold: float = cleave_angle
	if angle_threshold < 0.0:
		angle_threshold = 0.35 if is_sonic else 0.76

	var candidates: Array[Dictionary] = []
	var living: Array[Node3D] = get_creatures()
	var max_range_sq: float = max_range * max_range

	for p: Node3D in living:
		if not is_instance_valid(p) or bool(p.get_meta("dead", false)):
			continue
		if bool(p.get_meta("tamed", false)):
			continue
		if p == water_dragon and not boss_active:
			continue
		var to_p := p.global_position - from
		var dist_sq := to_p.length_squared()
		if dist_sq > max_range_sq:
			continue
		var dist := sqrt(dist_sq)
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
		var hit_stars: int = 2
		if is_sonic:
			if float(p.get_meta("freeze_timer", 0.0)) <= 0.0:
				p.position += knock_dir * knockback
			p.set_meta("stun_timer", 3.2)
			p.set_meta("flee_timer", 4.2)
		else:
			var inferred_weapon := "axe" if (cleave_angle > 0.0 and cleave_angle < 0.25) else "knife"
			p.set_meta("last_hit_weapon", inferred_weapon)
			var instant_kill := p_kind not in ["water_dragon", "sea_spider", "seal"]
			var result := damage_creature(p, damage, knock_dir * knockback, instant_kill)
			if result.is_empty():
				continue
			killed = bool(result.get("killed", false))
			hit_stars = int(result.get("catch_stars", 2))
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
				"is_sonic": is_sonic,
				"catch_stars": hit_stars
			}

	primary_target_info["hit_count"] = hit_count
	primary_target_info["hit_names"] = hit_names
	primary_target_info["killed_names"] = killed_names
	primary_target_info["dropped_items"] = dropped_items
	primary_target_info["hit_positions"] = hit_positions
	primary_target_info["hit_kinds"] = hit_kinds
	return primary_target_info

func get_creatures() -> Array[Node3D]:
	var valid_bosses: int = 0
	for b_id in boss_nodes:
		if is_instance_valid(boss_nodes[b_id]):
			valid_bosses += 1
	var expected_total: int = fish.size() + jellies.size() + squids.size() + rays.size() + turtles.size() + crabs.size() + sea_spiders.size() + seals.size() + sea_wolves.size() + schooling_fish.size() + valid_bosses
	if _creatures_dirty or _all_creatures.size() != expected_total:
		_all_creatures.clear()
		_all_creatures.append_array(fish)
		_all_creatures.append_array(jellies)
		_all_creatures.append_array(squids)
		_all_creatures.append_array(rays)
		_all_creatures.append_array(turtles)
		_all_creatures.append_array(crabs)
		_all_creatures.append_array(sea_spiders)
		_all_creatures.append_array(seals)
		_all_creatures.append_array(sea_wolves)
		_all_creatures.append_array(schooling_fish)
		for b_id in boss_nodes:
			var b_node: Node3D = boss_nodes[b_id]
			if is_instance_valid(b_node):
				_all_creatures.append(b_node)
		_creatures_dirty = false
	return _all_creatures

func get_submarines() -> Array[Node3D]:
	return submarines

func find_nearby_submarine(pos: Vector3, max_dist: float = 7.0) -> Node3D:
	for sub in submarines:
		if not is_instance_valid(sub):
			continue
		var threshold: float = float(sub.interact_radius) if ("interact_radius" in sub) else max_dist
		if pos.distance_squared_to(sub.global_position) <= threshold * threshold:
			return sub
	return null

func _is_immobile(creature: Node3D) -> bool:
	return bool(creature.get_meta("dead", false)) or float(creature.get_meta("stun_timer", 0.0)) > 0.0 or float(creature.get_meta("freeze_timer", 0.0)) > 0.0

func _register_creature_hitbox(creature: Node3D) -> void:
	creature.set_meta("freeze_timer", 0.0)
	creature.set_meta("motion_clock", 0.0)
	creature.set_meta("is_creature", true)
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
	if creature == null and collider is Node3D and (bool(collider.get_meta("is_creature", false)) or (collider.has_meta("kind") and get_creatures().has(collider))):
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
	var catch_stars: int = int(creature.get_meta("catch_stars", 2))
	var was_controlled: bool = float(creature.get_meta("freeze_timer", 0.0)) > 0.0 or creature.has_node("StasisAura") or float(creature.get_meta("stun_timer", 0.0)) > 0.0
	var hit_weapon: String = str(creature.get_meta("last_hit_weapon", ""))
	if was_controlled:
		catch_stars = 3
	elif hit_weapon == "knife":
		catch_stars = 2
	elif hit_weapon in ["axe", "sonic", "torpedo"]:
		catch_stars = 1
	if killed:
		creature.set_meta("dead", true)
		creature.set_meta("can_loot", true)
		creature.set_meta("looted", false)
		creature.set_meta("catch_stars", catch_stars)
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
		"dropped_items": drops, "hit_positions": [at], "hit_kinds": [kind],
		"catch_stars": catch_stars
	}

func find_nearby_oxygen_clam(pos: Vector3, max_dist: float = 4.8) -> Node3D:
	var best: Node3D = null
	var best_d_sq: float = max_dist * max_dist
	for clam in giant_clams:
		if not is_instance_valid(clam):
			continue
		if float(clam.get_meta("clam_cooldown", 0.0)) > 0.0:
			continue
		var clam_pos: Vector3 = clam.global_position if clam.is_inside_tree() else clam.position
		var d_sq: float = pos.distance_squared_to(clam_pos)
		if d_sq <= best_d_sq:
			best_d_sq = d_sq
			best = clam
	return best

func salvage_creature_with_drone(creature: Node3D) -> Dictionary:
	if not is_instance_valid(creature):
		return {}
	var kind: String = str(creature.get_meta("kind", "fish"))
	var c_name: String = str(creature.get_meta("name", "海洋生物"))
	var at: Vector3 = creature.global_position if creature.is_inside_tree() else creature.position
	var was_dead: bool = bool(creature.get_meta("dead", false))
	var drops: Array[Dictionary] = []
	if not was_dead and kind in ["predator", "abyss"]:
		var fragment_kind := "shark_fragment" if kind == "predator" else "abyss_fragment"
		var fragment := _spawn_fragment(fragment_kind, at)
		drops.append({"kind": fragment_kind, "name": FRAGMENT_NAMES[fragment_kind], "node": fragment, "pos": at})
	creature.set_meta("dead", true)
	creature.set_meta("can_loot", false)
	creature.set_meta("looted", true)
	creature.set_meta("is_creature", false)
	creature.set_meta("catch_stars", 3)
	predators.erase(creature)
	small_fish.erase(creature)
	neutral_fish.erase(creature)
	fish.erase(creature)
	jellies.erase(creature)
	squids.erase(creature)
	rays.erase(creature)
	turtles.erase(creature)
	crabs.erase(creature)
	sea_spiders.erase(creature)
	seals.erase(creature)
	sea_wolves.erase(creature)
	schooling_fish.erase(creature)
	_creatures_dirty = true
	var tree := creature.get_tree()
	if tree:
		var tw := creature.create_tween()
		tw.tween_property(creature, "position:y", creature.position.y + 16.0, 1.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(creature, "scale", Vector3.ZERO, 0.45).set_delay(0.9)
		tw.tween_callback(creature.queue_free)
	else:
		creature.queue_free()
	return {
		"kind": kind,
		"name": c_name,
		"pos": at,
		"stars": 3,
		"dropped_items": drops
	}

func freeze_creatures(at: Vector3, radius: float, duration: float) -> int:
	var count := 0
	var radius_sq: float = radius * radius
	for creature in get_creatures():
		if not is_instance_valid(creature) or bool(creature.get_meta("dead", false)):
			continue
		if creature.global_position.distance_squared_to(at) > radius_sq:
			continue
		var prev_freeze: float = float(creature.get_meta("freeze_timer", 0.0))
		if duration > prev_freeze:
			creature.set_meta("freeze_timer", duration)
		if prev_freeze <= 0.0:
			_update_creature_animation(creature)
		if not bool(creature.get_meta("has_stasis_aura", false)) and not creature.has_node("StasisAura"):
			if _stasis_aura_mat == null:
				_stasis_aura_mat = StandardMaterial3D.new()
				_stasis_aura_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				_stasis_aura_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				_stasis_aura_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
				_stasis_aura_mat.albedo_color = Color(0.08, 0.4, 1.0, 0.14)
				_stasis_sphere_small = SphereMesh.new()
				_stasis_sphere_small.radius = 1.2
				_stasis_sphere_small.height = 2.4
				_stasis_sphere_small.radial_segments = 16
				_stasis_sphere_small.rings = 8
				_stasis_sphere_boss = SphereMesh.new()
				_stasis_sphere_boss.radius = 6.0
				_stasis_sphere_boss.height = 12.0
				_stasis_sphere_boss.radial_segments = 16
				_stasis_sphere_boss.rings = 8
			var aura := MeshInstance3D.new()
			aura.name = "StasisAura"
			aura.mesh = _stasis_sphere_boss if creature == water_dragon else _stasis_sphere_small
			aura.material_override = _stasis_aura_mat
			creature.add_child(aura)
			creature.set_meta("has_stasis_aura", true)
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
	_creatures_dirty = true

func _tick_sea_spiders(diver_pos: Vector3, delta: float) -> Array[Dictionary]:
	var attacks: Array[Dictionary] = []
	for spider in sea_spiders:
		if not is_instance_valid(spider) or _is_immobile(spider):
			continue
		if bool(spider.get_meta("tamed", false)):
			continue
		var cooldown: float = maxf(0.0, float(spider.get_meta("bite_cooldown", 0.0)) - delta)
		spider.set_meta("bite_cooldown", cooldown)
		var dist_sq: float = spider.global_position.distance_squared_to(diver_pos)
		var target_pos: Vector3
		if dist_sq < 10.0 * 10.0 and diver_pos.y < floor_height(diver_pos.x, diver_pos.z) + 4.5:
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
		if dist_sq < 2.6 * 2.6 and cooldown <= 0.0:
			spider.set_meta("bite_cooldown", 2.0)
			spider.set_meta("has_attacked_player", true)
			attacks.append({"name": "海蜘蛛足刺", "damage": 12.0, "pos": spider.global_position, "attacker": spider})
	return attacks

func _tick_seals_vs_sharks(delta: float) -> void:
	for seal in seals:
		if not is_instance_valid(seal) or _is_immobile(seal):
			continue
		for shark in predators:
			if not is_instance_valid(shark) or _is_immobile(shark):
				continue
			var dist_sq: float = seal.global_position.distance_squared_to(shark.global_position)
			if dist_sq < 14.0 * 14.0:
				seal.position = seal.position.move_toward(shark.global_position, delta * 3.5)
				shark.position = shark.position.move_toward(seal.global_position, delta * 3.2)
				if dist_sq < 3.2 * 3.2:
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
			b.set_meta("has_attacked_player", true)
			attacks.append({"name": "%s 猛撞" % str(b.get_meta("name", "巨兽")), "damage": 38.0 if enraged else 26.0, "pos": b.global_position, "attacker": b})
		if boss_action_timer <= 0.0:
			boss_action = "circle"
			boss_action_timer = 2.4
	elif boss_action == "pulse_windup":
		boss_warning = "高能震荡波蓄势！远离巨兽 18 米"
		if boss_action_timer <= 0.0:
			if to_diver.length() < 18.0:
				b.set_meta("has_attacked_player", true)
				attacks.append({"name": "巨兽震荡狂涛", "damage": 32.0 if enraged else 22.0, "pos": b.global_position, "attacker": b})
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
	# Sparse, lit marine snow follows the explored water column in coarse cells.
	# It replaces the fixed neon particle layers which only covered the old map.
	marine_snow = MultiMeshInstance3D.new()
	marine_snow.name = "MarineSnow"
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var sphere := SphereMesh.new()
	sphere.radius = 0.018
	sphere.height = 0.036
	sphere.radial_segments = 4
	sphere.rings = 2
	mm.mesh = sphere
	mm.instance_count = 320
	var snow_rng := RandomNumberGenerator.new()
	snow_rng.seed = 20261112
	for i in range(mm.instance_count):
		var at := Vector3(snow_rng.randf_range(-42.0, 42.0), snow_rng.randf_range(-42.0, 42.0), snow_rng.randf_range(-42.0, 42.0))
		var size_scale := snow_rng.randf_range(0.5, 1.4)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * size_scale), at))
	marine_snow.multimesh = mm
	var snow_material := ShaderMaterial.new()
	snow_material.shader = load("res://shaders/marine_snow.gdshader")
	marine_snow.material_override = snow_material
	marine_snow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marine_snow.extra_cull_margin = 1.0
	add_child(marine_snow)

func _spawn_decor_model(asset: String, at: Vector3, scale_vec: Vector3, rot_vec: Vector3 = Vector3.ZERO, vis_range: float = 110.0, sway: float = 0.0, sway_freq: float = 1.25) -> Node3D:
	var node := model(asset, at, 1.0, vis_range)
	node.scale = scale_vec
	node.rotation = rot_vec
	if sway > 0.0:
		apply_plant_shader(node, sway, sway_freq, asset)
	return node

func _process(delta: float) -> void:
	clock += delta
	_update_water_surface_state(scope_view_enabled)
	if is_instance_valid(seabed_ecology):
		seabed_ecology.update_observer(last_diver_pos, delta)
	if is_instance_valid(marine_snow):
		marine_snow.position = (last_diver_pos / 32.0).floor() * 32.0

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
		var dist_sq_diver: float = creature.global_position.distance_squared_to(last_diver_pos)
		if dist_sq_diver < 4.5 * 4.5:
			var dist_diver: float = sqrt(dist_sq_diver)
			var away := (creature.global_position - last_diver_pos).normalized()
			next += away * (4.5 - dist_diver) * 1.5

		# 视距外（50m 外浓雾不可见）跳过朝向和横滚矩阵运算，节约 CPU
		if dist_sq_diver <= 50.0 * 50.0:
			var direction := next - creature.position
			if direction.length_squared() > 0.00001:
				var up := Vector3.UP if absf(direction.normalized().y) < 0.95 else Vector3.FORWARD
				creature.look_at(creature.position + direction, up, true)
				# 转弯横滚倾角 (Banking)
				var turn_yaw: float = sin(t) * 0.22
				creature.rotate_object_local(Vector3.FORWARD, -turn_yaw)
		creature.position = next

	# 2. 可食用发光小金鱼快速群游与机敏避险
	var sfish_active_r: float = 305.0 if scope_view_enabled else 42.0
	var sfish_active_sq: float = sfish_active_r * sfish_active_r
	for sfish in small_fish:
		if not is_instance_valid(sfish):
			continue
		if _is_immobile(sfish):
			continue
		var center: Vector3 = sfish.get_meta("center")
		if last_diver_pos != Vector3.ZERO and center.distance_squared_to(last_diver_pos) > sfish_active_sq and sfish.position.distance_squared_to(last_diver_pos) > sfish_active_sq:
			continue
		var phase: float = float(sfish.get_meta("phase"))
		var spd: float = float(sfish.get_meta("swim_speed"))
		var rad: float = float(sfish.get_meta("radius"))

		# 惊扰加速响应
		var fright_t: float = float(sfish.get_meta("fright_timer", 0.0))
		var dist_sq_d: float = sfish.global_position.distance_squared_to(last_diver_pos)
		if dist_sq_d < 3.8 * 3.8:
			fright_t = 1.6
			sfish.set_meta("fright_timer", fright_t)

		if fright_t > 0.0:
			sfish.set_meta("fright_timer", maxf(0.0, fright_t - delta))
			spd *= 2.2

		var t: float = float(sfish.get_meta("motion_clock", clock)) * spd * 0.45 + phase
		var next := center + Vector3(sin(t) * rad, sin(t * 2.2) * 0.8, cos(t) * (rad * 0.7))
		if dist_sq_d < 3.8 * 3.8:
			var flee_vec := (sfish.global_position - last_diver_pos).normalized()
			next += flee_vec * 2.4

		var dir := next - sfish.position
		var fish_vis: Node3D = sfish.get_meta("fish_model", null)
		if is_instance_valid(fish_vis) and dir.length_squared() > 0.0001:
			var dir_norm := dir.normalized()
			var up := Vector3.UP if absf(dir_norm.y) < 0.95 else Vector3.FORWARD
			var fish_scale: float = float(sfish.get_meta("fish_scale", 1.0))
			fish_vis.basis = (Basis.looking_at(-dir_norm, up) * Basis(Vector3.FORWARD, -sin(t * 1.5) * 0.28)).scaled(Vector3.ONE * fish_scale)
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

		var dist_sq_diver: float = crab.global_position.distance_squared_to(last_diver_pos)
		if dist_sq_diver < 4.8 * 4.8:
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
			var cy: float = terrain_height(cx, cz)
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
		var dist_sq_d: float = colony.global_position.distance_squared_to(last_diver_pos)
		var cur_retract: float = float(colony.get_meta("retract_progress", 0.0))
		var target_retract: float = 1.0 if dist_sq_d < 3.8 * 3.8 else 0.0
		cur_retract = move_toward(cur_retract, target_retract, delta * (3.5 if target_retract > 0.5 else 0.8))
		colony.set_meta("retract_progress", cur_retract)
		var last_applied: float = float(colony.get_meta("last_retract_applied", -1.0))
		if absf(cur_retract - last_applied) > 0.005:
			colony.set_meta("last_retract_applied", cur_retract)
			var mats: Array = colony.get_meta("shader_materials", [])
			for mat in mats:
				if mat is ShaderMaterial:
					mat.set_shader_parameter("retract_progress", cur_retract)

	# 7.1 深海发光巨砗磲近身感应微闭交互
	for clam in giant_clams:
		if not is_instance_valid(clam):
			continue
		var clam_cd: float = float(clam.get_meta("clam_cooldown", 0.0))
		if clam_cd > 0.0:
			clam.set_meta("clam_cooldown", maxf(0.0, clam_cd - delta))
		var dist_sq_c: float = clam.global_position.distance_squared_to(last_diver_pos)
		var cur_c: float = float(clam.get_meta("retract_progress", 0.0))
		var target_c: float = 0.65 if dist_sq_c < 4.2 * 4.2 else 0.0
		cur_c = move_toward(cur_c, target_c, delta * (2.8 if target_c > 0.1 else 0.7))
		clam.set_meta("retract_progress", cur_c)
		var last_c: float = float(clam.get_meta("last_retract_applied", -1.0))
		if absf(cur_c - last_c) > 0.005:
			clam.set_meta("last_retract_applied", cur_c)
			var c_mats: Array = clam.get_meta("shader_materials", [])
			for mat in c_mats:
				if mat is ShaderMaterial:
					mat.set_shader_parameter("retract_progress", cur_c)

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
	_tick_schooling_fish(last_diver_pos, delta)
	for relic in explorer_relics:
		if is_instance_valid(relic) and relic.visible and relic.has_node("RelicCore"):
			var core_node: Node3D = relic.get_node("RelicCore")
			core_node.rotate_y(delta * 1.4)
			core_node.position.y = 1.55 + sin(clock * 2.2 + relic.position.x * 0.1) * 0.18

func get_laser_color() -> Color:
	var background := environment.fog_light_color
	var luminance: float = background.r * 0.2126 + background.g * 0.7152 + background.b * 0.0722
	var illumination: float = luminance + environment.ambient_light_energy * 0.12 + sun.light_energy * 0.18
	var darkness: float = maxf(smoothstep(0.0, 100.0, art_depth), (1.0 - clampf(illumination / 0.6, 0.0, 1.0)) * 0.2)
	return Color(0.015, 0.08, 0.7).lerp(Color(0.08, 0.5, 1.0), darkness)

static func sample_depth_profile(depth: float) -> Dictionary:
	return OceanDepths.light_profile(depth)

func _update_water_surface_state(is_scoped: bool) -> void:
	if not is_instance_valid(water_surface):
		return
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam != null:
		# Move topology only; world-space phases and normals remain continuous.
		water_surface.position.x = snappedf(cam.global_position.x, 4.0)
		water_surface.position.z = snappedf(cam.global_position.z, 4.0)
	var use_underwater: bool = cam != null and cam.global_position.y < -0.75
	var target_mat: ShaderMaterial = water_underwater_mat if use_underwater else water_surface_mat
	if target_mat != null and water_surface.material_override != target_mat:
		water_surface.material_override = target_mat
	var looking_up: bool = cam != null and (-cam.global_transform.basis.z.y > 0.32)
	water_surface.visible = is_scoped or cam == null or cam.global_position.y >= -64.0 or (cam.global_position.y >= -180.0 and looking_up)

func set_depth(depth: float, scoped: bool = false) -> void:
	art_depth = maxf(depth, 0.0)
	if scoped != scope_view_enabled:
		scope_view_enabled = scoped
		for mesh in scope_meshes:
			if is_instance_valid(mesh):
				mesh.visibility_range_end = 300.0 if scoped else float(mesh.get_meta("base_visibility_range", mesh.visibility_range_end))
	_update_water_surface_state(scoped)
	var profile := sample_depth_profile(depth)
	environment.fog_density = float(profile["fog_density"])
	if scoped:
		environment.fog_density *= 0.16
	environment.background_mode = Environment.BG_SKY
	var target_sky: Sky = air_sky if depth < 0.05 else water_sky
	if environment.sky != target_sky:
		environment.sky = target_sky
	environment.fog_sky_affect = 0.0 if depth < 0.05 else 0.58

	environment.fog_light_color = profile["fog_color"]
	environment.fog_light_energy = float(profile["fog_energy"])
	environment.background_color = profile["background_color"]
	environment.ambient_light_color = profile["ambient_color"]
	environment.ambient_light_energy = float(profile["ambient_energy"])

	if is_instance_valid(sun):
		sun.light_color = profile["sun_color"]
		sun.light_energy = float(profile["sun_energy"])
		sun.shadow_enabled = depth < 58.0
		sun.visible = depth < 210.0
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		set_art_observer(camera.global_position, depth)
	else:
		_update_water_atmosphere(profile.fog_color, float(profile.fog_energy), depth)

func set_world_labels_visible(show_labels: bool) -> void:
	for node in find_children("*", "Label3D", true, false):
		var lbl := node as Label3D
		if not show_labels:
			if lbl.visible:
				lbl.set_meta("_pre_title_vis", true)
				lbl.visible = false
		elif bool(lbl.get_meta("_pre_title_vis", false)):
			lbl.remove_meta("_pre_title_vis")
			lbl.visible = true

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
	_creatures_dirty = true

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
		var dist_sq: float = wolf.global_position.distance_squared_to(diver_pos)
		var detect_r: float = float(wolf.get_meta("detect_radius", 26.0))
		var target_pos := center
		var clock_val: float = float(wolf.get_meta("motion_clock", clock))
		var phase: float = float(wolf.get_meta("phase", 0.0))
		if dist_sq < detect_r * detect_r:
			var pack_idx: int = int(wolf.get_meta("pack_index", 0))
			var angle: float = clock_val * 1.2 + pack_idx * (TAU / 3.0)
			var orbit_dist: float = 10.0 if (pack_idx != 0 or cd > 0.0) else 2.5
			target_pos = diver_pos + Vector3(cos(angle) * orbit_dist, sin(clock_val * 2.0) * 1.5, sin(angle) * orbit_dist)
			var attack_r: float = float(wolf.get_meta("attack_radius", 4.2))
			if dist_sq < attack_r * attack_r and cd <= 0.0:
				wolf.set_meta("bite_cooldown", 2.2)
				wolf.set_meta("has_attacked_player", true)
				bites.append({"name": "海狼撕咬", "damage": float(wolf.get_meta("damage", 22.0)), "pos": wolf.global_position, "attacker": wolf})
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
	_creatures_dirty = true

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

			var d_dist_sq: float = f.global_position.distance_squared_to(diver_pos)
			if d_dist_sq < 6.0 * 6.0:
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
	if is_instance_valid(mother_tree) and bool(mother_tree.get_meta("awakened", false)):
		return mother_tree
	if is_instance_valid(mother_tree):
		mother_tree_spawned_flag = true
		mother_tree.set_meta("awakened", true)
		var canopy_mat := mother_tree.get_meta("canopy_material", null) as StandardMaterial3D
		if canopy_mat != null:
			canopy_mat.emission_energy_multiplier = 0.72
		var vein_mat := mother_tree.get_meta("vein_material", null) as StandardMaterial3D
		if vein_mat != null:
			vein_mat.emission_energy_multiplier = 1.15
		if is_instance_valid(mother_tree_marker):
			mother_tree_marker.text = "◈ 远古深海母树 · 觉醒圣所\n游入内部收集三大生命核心"
			mother_tree_marker.modulate = Color(0.35, 1.0, 0.85)
		var root_pos := mother_tree.position
		if mother_tree_items.is_empty():
			var awaken_pos := root_pos + Vector3(0, 12.0, 0)
			_spawn_mother_item("mother_tree_essence", "母树生命精华", awaken_pos + Vector3(-3.2, 0.5, 0), Color(0.2, 1.0, 0.5))
			_spawn_mother_item("ancient_star_core", "远古星核源石", awaken_pos + Vector3(0, 0.8, -3.2), Color(0.2, 0.8, 1.0))
			_spawn_mother_item("tree_seed", "深海启迪之种", awaken_pos + Vector3(3.2, 0.5, 0), Color(0.85, 0.4, 1.0))
		mother_tree_spawned.emit()
		return mother_tree
	_build_mother_tree_structure(true)
	mother_tree_spawned.emit()
	return mother_tree

func _make_organic_limb_mesh(points: Array[Vector3], radii: Array[float], radial_segs: int = 16, flute_count: int = 7, flute_amp: float = 0.14, twist: float = 1.4) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var rings: Array[PackedVector3Array] = []
	var count := points.size()
	for i in range(count):
		var p := points[i]
		var dir := (points[mini(i + 1, count - 1)] - points[maxi(i - 1, 0)]).normalized()
		var ref := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.92 else Vector3.RIGHT
		var tangent := dir.cross(ref).normalized()
		var bitangent := tangent.cross(dir).normalized()
		var t := float(i) / float(maxi(1, count - 1))
		var r_base := radii[i]
		var ring := PackedVector3Array()
		for j in range(radial_segs):
			var ang := float(j) / float(radial_segs) * TAU
			var flute := 1.0 + flute_amp * cos(ang * float(flute_count) + t * twist * TAU)
			var rad := r_base * flute
			ring.append(p + (tangent * cos(ang) + bitangent * sin(ang)) * rad)
		rings.append(ring)
	for i in range(count - 1):
		for j in range(radial_segs):
			var jn := (j + 1) % radial_segs
			var a: Vector3 = rings[i][j]
			var b: Vector3 = rings[i][jn]
			var c: Vector3 = rings[i + 1][j]
			var d: Vector3 = rings[i + 1][jn]
			st.add_vertex(a); st.add_vertex(b); st.add_vertex(c)
			st.add_vertex(b); st.add_vertex(d); st.add_vertex(c)
	var tip_c := points[-1]
	for j in range(radial_segs):
		var jn := (j + 1) % radial_segs
		st.add_vertex(rings[-1][j]); st.add_vertex(rings[-1][jn]); st.add_vertex(tip_c)
	st.generate_normals()
	return st.commit()

func _make_scalloped_canopy_dome(radius: float, height: float, lobes: int = 12) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var segs := 36
	var r_steps := 7
	for side in [0, 1]:
		var rings: Array[PackedVector3Array] = []
		for ri in range(r_steps + 1):
			var u := float(ri) / float(r_steps)
			var ring := PackedVector3Array()
			for si in range(segs):
				var ang := float(si) / float(segs) * TAU
				var scallop := 1.0 + 0.11 * cos(ang * float(lobes)) * u
				var r := radius * u * scallop
				var dome_y := height * (1.0 - pow(u, 1.75)) + 0.08 * height * cos(ang * float(lobes)) * u * (1.0 - u * 0.4)
				if side == 1:
					dome_y -= height * (0.14 * (1.0 - u * 0.72) + 0.05 * maxf(0.0, cos(ang * float(lobes) * 2.0)))
				ring.append(Vector3(cos(ang) * r, dome_y, sin(ang) * r))
			rings.append(ring)
		for ri in range(r_steps):
			for si in range(segs):
				var sn := (si + 1) % segs
				var a: Vector3 = rings[ri][si]
				var b: Vector3 = rings[ri][sn]
				var c: Vector3 = rings[ri + 1][si]
				var d: Vector3 = rings[ri + 1][sn]
				if side == 0:
					st.add_vertex(a); st.add_vertex(c); st.add_vertex(b)
					st.add_vertex(b); st.add_vertex(c); st.add_vertex(d)
				else:
					st.add_vertex(a); st.add_vertex(b); st.add_vertex(c)
					st.add_vertex(b); st.add_vertex(d); st.add_vertex(c)
	st.generate_normals()
	return st.commit()

func _build_mother_tree_structure(awakened: bool) -> Node3D:
	mother_tree = Node3D.new()
	mother_tree.name = "AncientMotherTree"
	mother_tree.set_meta("awakened", awakened)
	var tree_root_pos := Vector3(0, floor_height(0, -340) - 2.0, -340)
	mother_tree.position = tree_root_pos
	add_child(mother_tree)
	mother_tree_spawned_flag = awakened

	var mat_bark := StandardMaterial3D.new()
	mat_bark.albedo_color = Color("3c5163")
	mat_bark.roughness = 0.82
	mat_bark.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	mat_bark.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	mat_bark.rim_enabled = false
	mat_bark.emission_enabled = true
	mat_bark.emission = Color("64a8be")
	mat_bark.emission_energy_multiplier = 0.12

	var mat_canopy := StandardMaterial3D.new()
	mat_canopy.albedo_color = Color("76d4cd")
	mat_canopy.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_canopy.albedo_color.a = 0.62
	mat_canopy.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat_canopy.roughness = 0.36
	mat_canopy.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	mat_canopy.emission_enabled = true
	mat_canopy.emission = Color("8cf0e4")
	mat_canopy.emission_energy_multiplier = 0.68 if awakened else 0.42
	mother_tree.set_meta("canopy_material", mat_canopy)

	var mat_vein := StandardMaterial3D.new()
	mat_vein.albedo_color = Color("b8f6ec")
	mat_vein.roughness = 0.28
	mat_vein.emission_enabled = true
	mat_vein.emission = Color("74ebd9")
	mat_vein.emission_energy_multiplier = 1.05 if awakened else 0.55
	mother_tree.set_meta("vein_material", mat_vein)

	# 1. Colossal Twisting Fluted Ancient Trunk (Rising organically up 68 meters)
	var trunk_pts: Array[Vector3] = []
	var trunk_radii: Array[float] = []
	for step in range(15):
		var t := float(step) / 14.0
		var sway_x := sin(t * PI * 1.65) * 3.4 * t
		var sway_z := cos(t * PI * 1.35 + 0.6) * 2.8 * t
		var flare := pow(maxf(0.0, 1.0 - t * 2.6), 2.0) * 4.8
		trunk_pts.append(Vector3(sway_x, t * 67.0, sway_z))
		trunk_radii.append(lerpf(8.2, 3.4, pow(t, 0.75)) + flare)
	var trunk := MeshInstance3D.new()
	trunk.mesh = _make_organic_limb_mesh(trunk_pts, trunk_radii, 24, 9, 0.16, 1.25)
	trunk.material_override = mat_bark
	mother_tree.add_child(trunk)

	# Helical bioluminescent sap veins climbing the fluted trunk
	for v_idx in range(4):
		var v_pts: Array[Vector3] = []
		var v_rad: Array[float] = []
		var base_a := float(v_idx) * TAU / 4.0
		for step in range(18):
			var t := float(step) / 17.0
			var center := Vector3(sin(t * PI * 1.65) * 3.4 * t, t * 65.0 + 1.5, cos(t * PI * 1.35 + 0.6) * 2.8 * t)
			var r_trunk := lerpf(8.2, 3.4, pow(t, 0.75)) + pow(maxf(0.0, 1.0 - t * 2.6), 2.0) * 4.8
			var ang := base_a + t * TAU * 1.15
			v_pts.append(center + Vector3(cos(ang) * (r_trunk * 0.96), 0.0, sin(ang) * (r_trunk * 0.96)))
			v_rad.append(lerpf(0.55, 0.22, t))
		var vein := MeshInstance3D.new()
		vein.mesh = _make_organic_limb_mesh(v_pts, v_rad, 8, 3, 0.05, 0.5)
		vein.material_override = mat_vein
		mother_tree.add_child(vein)

	# 10 Cathedral Buttress Roots arching out into the seabed
	for i in range(10):
		var ang: float = float(i) * TAU / 10.0 + sin(float(i) * 1.7) * 0.14
		var reach := 36.0 + float(i % 3) * 5.5
		var r_pts: Array[Vector3] = []
		var r_rad: Array[float] = []
		for s in range(9):
			var t := float(s) / 8.0
			var curve_ang := ang + sin(t * PI) * (0.22 if i % 2 == 0 else -0.18)
			var dist := lerpf(5.8, reach, pow(t, 0.86))
			var arch_h := lerpf(19.5, -1.2, pow(t, 0.72)) + sin(t * PI) * 5.8
			r_pts.append(Vector3(cos(curve_ang) * dist, arch_h, sin(curve_ang) * dist))
			r_rad.append(lerpf(3.4, 0.65, pow(t, 0.82)))
		var root_limb := MeshInstance3D.new()
		root_limb.mesh = _make_organic_limb_mesh(r_pts, r_rad, 12, 5, 0.14, 0.8)
		root_limb.material_override = mat_bark
		mother_tree.add_child(root_limb)

	# 2. Sweeping Primary & Crown Boughs + Multi-Tiered Scalloped Bioluminescent Sea-Canopy Domes
	var top_center := trunk_pts[-1]
	var crown_dome := MeshInstance3D.new()
	crown_dome.mesh = _make_scalloped_canopy_dome(22.0, 9.5, 16)
	crown_dome.position = top_center + Vector3(0, 3.5, 0)
	crown_dome.material_override = mat_canopy
	mother_tree.add_child(crown_dome)

	for i in range(12):
		var c_ang: float = float(i) * TAU / 12.0 + (0.18 if i % 2 == 1 else 0.0)
		var upper_tier := (i % 3) == 0
		var start_t := 0.78 if upper_tier else (0.62 + float(i % 2) * 0.08)
		var trunk_anchor := Vector3(sin(start_t * PI * 1.65) * 3.4 * start_t, start_t * 67.0, cos(start_t * PI * 1.35 + 0.6) * 2.8 * start_t)
		var out_reach := (20.0 if upper_tier else 31.0) + float(i % 4) * 3.2
		var end_y := (73.0 if upper_tier else 63.0) + float(i % 3) * 3.2
		var b_pts: Array[Vector3] = []
		var b_rad: Array[float] = []
		for s in range(8):
			var t := float(s) / 7.0
			var b_ang := c_ang + sin(t * PI) * 0.16
			var dist := out_reach * pow(t, 0.88)
			var y := lerpf(trunk_anchor.y, end_y, pow(t, 0.76)) + sin(t * PI) * 3.6
			b_pts.append(Vector3(trunk_anchor.x * (1.0 - t) + cos(b_ang) * dist, y, trunk_anchor.z * (1.0 - t) + sin(b_ang) * dist))
			b_rad.append(lerpf(2.3, 0.58, t))
		var bough := MeshInstance3D.new()
		bough.mesh = _make_organic_limb_mesh(b_pts, b_rad, 10, 5, 0.11, 0.6)
		bough.material_override = mat_bark
		mother_tree.add_child(bough)

		var foliage := MeshInstance3D.new()
		var dome_r := (12.5 if upper_tier else 15.0) + float(i % 3) * 2.2
		foliage.mesh = _make_scalloped_canopy_dome(dome_r, dome_r * 0.42, 12)
		foliage.position = b_pts[-1] + Vector3(0, 0.6, 0)
		foliage.rotation = Vector3(sin(c_ang) * 0.08, c_ang, -cos(c_ang) * 0.08)
		foliage.material_override = mat_canopy
		mother_tree.add_child(foliage)

		# Hanging luminous curtain tendrils under each canopy bell
		for tendril_k in range(2):
			var t_ang := c_ang + (float(tendril_k) - 0.5) * 0.45
			var t_origin := b_pts[-1] + Vector3(cos(t_ang) * (dome_r * 0.48), -0.4, sin(t_ang) * (dome_r * 0.48))
			var t_pts: Array[Vector3] = []
			var t_rad: Array[float] = []
			var drop_len := 11.0 + float((i + tendril_k) % 3) * 3.5
			for ts in range(6):
				var u := float(ts) / 5.0
				t_pts.append(t_origin + Vector3(sin(u * PI * 1.5 + float(i)) * 1.1 * u, -u * drop_len, cos(u * PI * 1.3 + float(tendril_k)) * 1.1 * u))
				t_rad.append(lerpf(0.24, 0.04, u))
			var tendril := MeshInstance3D.new()
			tendril.mesh = _make_organic_limb_mesh(t_pts, t_rad, 6, 3, 0.04, 0.4)
			tendril.material_override = mat_vein
			mother_tree.add_child(tendril)

	# 3. Skyward Ascending Luminous Beacon Light Pillar
	var beacon := OmniLight3D.new()
	beacon.position = Vector3(0, 50.0, 0)
	beacon.light_color = Color("92bdd2")
	beacon.light_energy = 3.2
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
	p_mesh.radial_segments = 6
	p_mesh.rings = 3
	particles.mesh = p_mesh
	var p_mat := StandardMaterial3D.new()
	p_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p_mat.albedo_color = Color(0.62, 0.84, 0.88, 0.65)
	particles.material_override = p_mat
	particles.position = Vector3(0, 45.0, 0)
	mother_tree.add_child(particles)

	# 5. Sanctuary Entrance Marker & 3 Sacred Collectable Items
	var m_text := "◈ 远古深海母树 · 觉醒圣所\n游入内部收集生命核心" if awakened else "◈ 远古深海母树 · 沉眠圣所\n平息四大深海领主可唤醒圣物"
	mother_tree_marker = _create_marker(m_text, tree_root_pos + Vector3(0, 16.0, 12.0), Color(0.3, 1.0, 0.8))
	add_child(mother_tree_marker)

	if awakened:
		var s_pos := tree_root_pos + Vector3(0, 12.0, 0)
		_spawn_mother_item("mother_tree_essence", "母树生命精华", s_pos + Vector3(-3.2, 0.5, 0), Color(0.2, 1.0, 0.5))
		_spawn_mother_item("ancient_star_core", "远古星核源石", s_pos + Vector3(0, 0.8, -3.2), Color(0.2, 0.8, 1.0))
		_spawn_mother_item("tree_seed", "深海启迪之种", s_pos + Vector3(3.2, 0.5, 0), Color(0.85, 0.4, 1.0))

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
	lbl.text = "✦  [E] 采摘 " + item_name
	lbl.position = Vector3(0, 1.4, 0)
	lbl.modulate = color
	_configure_label_3d(lbl, 28, 0.007)
	item.add_child(lbl)
	add_child(item)
	mother_tree_items.append(item)
	return item

func _populate_open_world_frontiers() -> void:
	var frng := RandomNumberGenerator.new()
	frng.seed = 20261112

	# Pre-place Dormant Ancient Mother Tree Sanctuary so open-world explorers see it from afar
	if not is_instance_valid(mother_tree):
		_build_mother_tree_structure(false)

	# 1. Spawn 6 Open-World Research Outpost Relays & Sonar Towers
	for spec in OUTPOST_SPECS:
		_spawn_research_outpost(spec)

	# 2. Spawn 12 Sunken Ancient Relics / Exploration Caches
	for rspec in RELIC_SPECS:
		_spawn_explorer_relic(rspec)

	# 3. Deploy Extra Expedition Scout Submarine in Northern Sunlit Atoll Lagoon
	var atoll_sub := Submarine.new()
	atoll_sub.configure("scout")
	atoll_sub.sub_name = "远洋开拓号巡航艇"
	atoll_sub.position = Vector3(55, 0.45, 348)
	atoll_sub.rotation.y = PI * 0.75
	add_child(atoll_sub)
	submarines.append(atoll_sub)
	_create_nav_buoy(Vector3(55, 0.2, 348), "⚓  EXPEDITION SUB  /  远洋开拓号环礁停泊港")

	var composition := OceanComposition.new()
	add_child(composition)
	composition.configure(self)

	# 12. Distribute Open-World Mineral Resources & Frontier Marine Wildlife
	var res_kinds := ["titanium", "copper", "quartz", "kelp"]
	var region_hubs := [
		Vector2(40, 340), Vector2(-260, 280), Vector2(380, 290),
		Vector2(460, -60), Vector2(420, -380), Vector2(-480, -90),
		Vector2(-440, -420), Vector2(60, -640)
	]
	for h_idx in range(region_hubs.size()):
		var hub: Vector2 = region_hubs[h_idx]
		for j in range(6):
			var rx := hub.x + frng.randf_range(-58.0, 58.0)
			var rz := hub.y + frng.randf_range(-58.0, 58.0)
			var rk: String = res_kinds[(h_idx + j) % res_kinds.size()]
			var resource_y := terrain_height(rx, rz)
			if rk == "kelp" and -resource_y > OceanDepths.KELP_LIMIT:
				rk = "quartz"
			_spawn_resource(rk, Vector3(rx, resource_y + 0.5, rz))
		_spawn_frontier_wildlife(hub, frng)

	# Appending to separate species arrays changes their concatenated indices.
	# Register by identity instead of skipping the old combined array length.
	_creatures_dirty = true
	for creature in get_creatures():
		if not creature.has_meta("motion_clock"):
			_register_creature_hitbox(creature)

func _spawn_frontier_wildlife(hub: Vector2, life_rng: RandomNumberGenerator) -> void:
	var depth := maxf(0.0, -terrain_height(hub.x, hub.y))
	var zone := OceanDepths.zone_id(depth)
	var species: Array[String] = []
	match zone:
		"sunlit_reef":
			species.assign(["fish_small", "fish_small", "fish", "sea_turtle", "manta_ray", "predator"])
		"shelf_garden":
			species.assign(["fish_small", "fish", "fish", "manta_ray", "squid", "predator"])
		"twilight_slope":
			species.assign(["fish", "squid", "squid", "jellyfish", "jellyfish", "predator"])
		"bathyal_basin":
			species.assign(["squid", "squid", "jellyfish", "jellyfish", "crab", "crab", "abyss"])
		_:
			species.assign(["jellyfish", "jellyfish", "jellyfish", "crab", "crab", "abyss"])
	for kind in species:
		var x := hub.x + life_rng.randf_range(-34.0, 34.0)
		var z := hub.y + life_rng.randf_range(-34.0, 34.0)
		var ground := terrain_height(x, z)
		var patrol_floor := ground
		for offset: Vector2 in [Vector2(-10, 0), Vector2(10, 0), Vector2(0, -10), Vector2(0, 10)]:
			patrol_floor = maxf(patrol_floor, terrain_height(x + offset.x, z + offset.y))
		var center := Vector3(x, minf(-3.0, patrol_floor + life_rng.randf_range(7.0, 14.0)), z)
		var creature: Node3D
		if kind == "fish_small":
			_spawn_small_fish(center, 1.0)
			creature = small_fish[-1]
		elif kind == "fish":
			_spawn_neutral_fish(center, 1.0)
			creature = neutral_fish[-1]
			creature.set_meta("name", "冷水银鳞鱼" if depth >= 90.0 else "大陆架礁鱼")
		elif kind in ["predator", "abyss"]:
			_spawn_predator(kind, center, 1.3 if kind == "abyss" else 1.15)
			creature = predators[-1]
		else:
			if kind == "crab":
				center.y = ground
			creature = model(kind, center, 1.3 if kind == "manta_ray" else 1.05, 90.0)
			creature.set_meta("kind", kind)
			creature.set_meta("center", center)
			creature.set_meta("phase", life_rng.randf_range(0.0, TAU))
			creature.set_meta("radius", life_rng.randf_range(5.0, 9.0))
			creature.set_meta("speed", life_rng.randf_range(0.35, 0.65))
			creature.set_meta("stun_timer", 0.0)
			creature.set_meta("dead", false)
			match kind:
				"sea_turtle":
					creature.set_meta("name", "浅礁绿海龟")
					turtles.append(creature)
				"manta_ray":
					creature.set_meta("name", "大陆架鬼蝠鲼")
					rays.append(creature)
				"squid":
					creature.set_meta("name", "深海玻璃鱿鱼" if depth >= 200.0 else "暮光远洋乌贼")
					squids.append(creature)
				"jellyfish":
					creature.set_meta("name", "极渊帷幕水母" if depth >= 360.0 else "暮光栉水母")
					creature.set_meta("drift_speed", life_rng.randf_range(0.12, 0.20))
					jellies.append(creature)
				"crab":
					creature.set_meta("name", "极深盲眼蟹" if depth >= 360.0 else "深海岩穴蟹")
					creature.set_meta("origin_x", x)
					creature.set_meta("origin_z", z)
					creature.set_meta("patrol_radius", 3.0)
					creature.set_meta("defensive", false)
					crabs.append(creature)
		creature.set_meta("depth_zone", zone)
		creature.set_meta("habitat_depth", depth)
		frontier_wildlife.append(creature)
	_creatures_dirty = true

func _spawn_research_outpost(spec: Dictionary) -> Node3D:
	var xz: Vector2 = spec["xz"]
	var base_y := terrain_height(xz.x, xz.y)
	var pos := Vector3(xz.x, base_y, xz.y)
	var root_node := StaticBody3D.new()
	root_node.name = "Outpost_" + str(spec["id"])
	root_node.position = pos
	root_node.collision_layer = 3
	root_node.set_meta("kind", "outpost_tower")
	root_node.set_meta("outpost_id", str(spec["id"]))
	root_node.set_meta("name", str(spec["name"]))
	root_node.set_meta("region", str(spec["region"]))
	root_node.set_meta("activated", false)
	add_child(root_node)

	var col := CollisionShape3D.new()
	var cyl_shape := CylinderShape3D.new()
	cyl_shape.radius = 2.6
	cyl_shape.height = 7.5
	col.shape = cyl_shape
	col.position.y = 3.75
	root_node.add_child(col)

	var pod_inst := model("pod", Vector3.ZERO, 1.15, 160.0)
	pod_inst.reparent(root_node, false)
	pod_inst.position = Vector3(0, 0.2, 0)

	# Sculpted Ivory-Ceramic & Antique-Brass Sonar Relay Mast Assembly
	var m_mat := StandardMaterial3D.new()
	m_mat.albedo_color = Color("e8dfd0")
	m_mat.metallic = 0.15
	m_mat.roughness = 0.36
	m_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY

	var brass_mat := StandardMaterial3D.new()
	brass_mat.albedo_color = Color("cba052")
	brass_mat.metallic = 0.76
	brass_mat.roughness = 0.28
	brass_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY

	var mast := MeshInstance3D.new()
	var mcyl := CylinderMesh.new()
	mcyl.bottom_radius = 0.24
	mcyl.top_radius = 0.11
	mcyl.height = 6.6
	mcyl.radial_segments = 16
	mast.mesh = mcyl
	mast.position = Vector3(0, 7.1, 0)
	mast.material_override = m_mat
	root_node.add_child(mast)

	for ring_y: float in [4.6, 6.8, 9.0, 10.1]:
		var collar := MeshInstance3D.new()
		var torus := TorusMesh.new()
		var r_ring := lerpf(0.68, 0.42, (ring_y - 4.6) / 5.6)
		torus.inner_radius = r_ring - 0.055
		torus.outer_radius = r_ring + 0.055
		torus.rings = 24
		torus.ring_segments = 10
		collar.mesh = torus
		collar.position = Vector3(0, ring_y, 0)
		collar.material_override = brass_mat
		root_node.add_child(collar)

	for leg_i in range(3):
		var la := float(leg_i) * TAU / 3.0
		var strut := MeshInstance3D.new()
		strut.mesh = _make_organic_limb_mesh([
			Vector3(cos(la) * 0.92, 3.85, sin(la) * 0.92),
			Vector3(cos(la) * 0.56, 6.6, sin(la) * 0.56),
			Vector3(cos(la) * 0.34, 9.9, sin(la) * 0.34)
		], [0.065, 0.05, 0.038], 8, 4, 0.02, 0.0)
		strut.material_override = brass_mat
		root_node.add_child(strut)

	for dish_side: float in [-1.0, 1.0]:
		var dish := MeshInstance3D.new()
		dish.mesh = _make_scalloped_canopy_dome(0.62, 0.22, 8)
		dish.position = Vector3(dish_side * 0.52, 8.2, 0.0)
		dish.rotation = Vector3(0.0, 0.0, -dish_side * PI * 0.42)
		dish.material_override = m_mat
		root_node.add_child(dish)

	var core := MeshInstance3D.new()
	core.name = "BeaconCore"
	var sph := SphereMesh.new()
	sph.radius = 0.56
	sph.height = 1.24
	sph.radial_segments = 24
	sph.rings = 12
	core.mesh = sph
	core.position = Vector3(0, 10.6, 0)
	var b_mat := StandardMaterial3D.new()
	b_mat.albedo_color = ArtDirection.AMBER
	b_mat.roughness = 0.35
	b_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	b_mat.emission_enabled = true
	b_mat.emission = ArtDirection.AMBER
	b_mat.emission_energy_multiplier = 0.58
	core.material_override = b_mat
	root_node.add_child(core)

	var light := OmniLight3D.new()
	light.name = "OutpostLight"
	light.position = Vector3(0, 7.5, 0)
	light.light_color = ArtDirection.AMBER
	light.light_energy = 1.8
	light.omni_range = 24.0
	root_node.add_child(light)

	var lbl := Label3D.new()
	lbl.name = "OutpostLabel"
	lbl.text = "⬡  %s\n[E 激活声呐塔与跃迁网 · 补氧制造]" % str(spec["name"])
	lbl.position = Vector3(0, 12.6, 0)
	lbl.modulate = Color(1.0, 0.84, 0.36)
	_configure_label_3d(lbl, 38, 0.009)
	root_node.add_child(lbl)

	outposts.append(root_node)
	return root_node

func set_outpost_activated_visual(outpost: Node3D) -> void:
	if not is_instance_valid(outpost):
		return
	outpost.set_meta("activated", true)
	if outpost.has_node("BeaconCore"):
		var core: MeshInstance3D = outpost.get_node("BeaconCore")
		var mat := core.material_override as StandardMaterial3D
		if mat:
			mat.albedo_color = ArtDirection.CYAN
			mat.emission = ArtDirection.CYAN
			mat.emission_energy_multiplier = 0.65
	if outpost.has_node("OutpostLight"):
		var lgt: OmniLight3D = outpost.get_node("OutpostLight")
		lgt.light_color = ArtDirection.CYAN
		lgt.light_energy = 2.2
	if outpost.has_node("OutpostLabel"):
		var lbl: Label3D = outpost.get_node("OutpostLabel")
		lbl.text = "⬡  %s  [已联网]\n[E 打开海图跃迁 · Tab 制造 · 自动补氧]" % str(outpost.get_meta("name", "科考前哨站"))
		lbl.modulate = ArtDirection.CYAN

func find_nearby_outpost(pos: Vector3, max_dist: float = 9.5) -> Node3D:
	var best: Node3D = null
	var best_d_sq: float = max_dist * max_dist
	for out in outposts:
		if is_instance_valid(out):
			var d_sq := pos.distance_squared_to(out.global_position + Vector3(0, 2.0, 0))
			if d_sq <= best_d_sq:
				best_d_sq = d_sq
				best = out
	return best

func _spawn_explorer_relic(spec: Dictionary) -> Node3D:
	var xz: Vector2 = spec["xz"]
	var pos := Vector3(xz.x, terrain_height(xz.x, xz.y), xz.y)
	var body := StaticBody3D.new()
	body.name = "Relic_" + str(spec["id"])
	body.position = pos
	body.collision_layer = 2
	body.set_meta("kind", "explorer_relic")
	body.set_meta("relic_id", str(spec["id"]))
	body.set_meta("name", str(spec["name"]))
	body.set_meta("collected", false)
	add_child(body)

	var col := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.5
	col.shape = sph
	col.position.y = 1.2
	body.add_child(col)

	var ped := MeshInstance3D.new()
	var pcyl := CylinderMesh.new()
	pcyl.bottom_radius = 1.08
	pcyl.top_radius = 0.78
	pcyl.height = 0.52
	pcyl.radial_segments = 16
	ped.mesh = pcyl
	ped.position.y = 0.26
	var p_mat := StandardMaterial3D.new()
	p_mat.albedo_color = Color("d4cbb4")
	p_mat.roughness = 0.82
	p_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	ped.material_override = p_mat
	body.add_child(ped)

	var ped_upper := MeshInstance3D.new()
	var ucyl := CylinderMesh.new()
	ucyl.bottom_radius = 0.72
	ucyl.top_radius = 0.54
	ucyl.height = 0.42
	ucyl.radial_segments = 16
	ped_upper.mesh = ucyl
	ped_upper.position.y = 0.72
	ped_upper.material_override = p_mat
	body.add_child(ped_upper)

	var relic_brass := StandardMaterial3D.new()
	relic_brass.albedo_color = Color("cfa24e")
	relic_brass.metallic = 0.78
	relic_brass.roughness = 0.28
	for ring_tilt: Vector3 in [Vector3(0.45, 0.2, 0.0), Vector3(-0.45, 1.2, 0.55)]:
		var astro_ring := MeshInstance3D.new()
		var atorus := TorusMesh.new()
		atorus.inner_radius = 0.60
		atorus.outer_radius = 0.66
		atorus.rings = 28
		atorus.ring_segments = 10
		astro_ring.mesh = atorus
		astro_ring.position.y = 1.55
		astro_ring.rotation = ring_tilt
		astro_ring.material_override = relic_brass
		body.add_child(astro_ring)

	var core := MeshInstance3D.new()
	core.name = "RelicCore"
	var oct_st := SurfaceTool.new()
	oct_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top_v := Vector3(0, 0.56, 0)
	var bot_v := Vector3(0, -0.56, 0)
	for f_i in range(6):
		var a0 := float(f_i) / 6.0 * TAU
		var a1 := float(f_i + 1) / 6.0 * TAU
		var m0 := Vector3(cos(a0) * 0.36, 0.0, sin(a0) * 0.36)
		var m1 := Vector3(cos(a1) * 0.36, 0.0, sin(a1) * 0.36)
		oct_st.add_vertex(top_v); oct_st.add_vertex(m1); oct_st.add_vertex(m0)
		oct_st.add_vertex(bot_v); oct_st.add_vertex(m0); oct_st.add_vertex(m1)
	oct_st.generate_normals()
	core.mesh = oct_st.commit()
	core.position.y = 1.55
	var c_mat := StandardMaterial3D.new()
	c_mat.albedo_color = ArtDirection.AMBER.lerp(ArtDirection.PAPER, 0.28)
	c_mat.roughness = 0.34
	c_mat.metallic = 0.25
	c_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	c_mat.emission_enabled = true
	c_mat.emission = ArtDirection.AMBER
	c_mat.emission_energy_multiplier = 0.48
	core.material_override = c_mat
	body.add_child(core)

	var lbl := Label3D.new()
	lbl.text = "◆  [E] 收集遗珍：" + str(spec["name"])
	lbl.position = Vector3(0, 2.65, 0)
	lbl.modulate = ArtDirection.AMBER
	_configure_label_3d(lbl, 30, 0.008)
	body.add_child(lbl)

	explorer_relics.append(body)
	return body

func find_nearby_relic(pos: Vector3, max_dist: float = 4.6) -> Node3D:
	var best: Node3D = null
	var best_d_sq: float = max_dist * max_dist
	for rel in explorer_relics:
		if is_instance_valid(rel) and not bool(rel.get_meta("collected", false)):
			var d_sq := pos.distance_squared_to(rel.global_position + Vector3(0, 1.2, 0))
			if d_sq <= best_d_sq:
				best_d_sq = d_sq
				best = rel
	return best

func get_map_outpost_snapshots() -> Array[Dictionary]:
	var arr: Array[Dictionary] = []
	for out in outposts:
		if is_instance_valid(out):
			arr.append({
				"id": str(out.get_meta("outpost_id", "")),
				"name": str(out.get_meta("name", "科考前哨站")),
				"region": str(out.get_meta("region", "")),
				"pos": out.global_position
			})
	return arr

func get_map_relic_snapshots() -> Array[Dictionary]:
	var arr: Array[Dictionary] = []
	for rel in explorer_relics:
		if is_instance_valid(rel):
			arr.append({
				"id": str(rel.get_meta("relic_id", "")),
				"name": str(rel.get_meta("name", "远古遗珍")),
				"pos": rel.global_position,
				"collected": bool(rel.get_meta("collected", false))
			})
	return arr

func get_map_submarine_snapshots() -> Array[Dictionary]:
	var arr: Array[Dictionary] = []
	for sub in submarines:
		if is_instance_valid(sub):
			arr.append({
				"name": str(sub.sub_name if "sub_name" in sub else "深海潜艇"),
				"pos": sub.global_position
			})
	return arr

func _build_faceted_basalt_spire_mesh(height: float, r_bottom: float, r_top: float, seed_val: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 7
	var rings := 5
	var ring_pts: Array = []
	for r in range(rings + 1):
		var t := float(r) / float(rings)
		var y := t * height
		var step_ledge := 1.0 + 0.08 * sin(t * PI * 3.0 + seed_val)
		var base_r := lerpf(r_bottom, r_top, pow(t, 0.82)) * step_ledge
		var pts: Array[Vector3] = []
		for s in range(sides):
			var ang := float(s) * TAU / float(sides) + t * 0.18
			var flute := 1.0 + 0.16 * sin(ang * 3.0 + seed_val) + 0.09 * cos(ang * 2.0 - t * 4.0)
			var jag_y := y + (0.22 * sin(ang * 2.0 + seed_val * 1.7) if r == rings else 0.0)
			pts.append(Vector3(cos(ang) * base_r * flute, jag_y, sin(ang) * base_r * flute))
		ring_pts.append(pts)
	for r in range(rings):
		var row0: Array = ring_pts[r]
		var row1: Array = ring_pts[r + 1]
		for s in range(sides):
			var s_next := (s + 1) % sides
			var p00: Vector3 = row0[s]
			var p10: Vector3 = row0[s_next]
			var p01: Vector3 = row1[s]
			var p11: Vector3 = row1[s_next]
			st.add_vertex(p00); st.add_vertex(p10); st.add_vertex(p01)
			st.add_vertex(p10); st.add_vertex(p11); st.add_vertex(p01)
	# Sloped inward crater rim instead of a flat top disc
	var top_row: Array = ring_pts[rings]
	var throat_center := Vector3(0.0, height - 0.55, 0.0)
	for s in range(sides):
		var s_next := (s + 1) % sides
		st.add_vertex(top_row[s])
		st.add_vertex(top_row[s_next])
		st.add_vertex(throat_center)
	st.generate_normals()
	return st.commit()

func _build_leviathan_rib_mesh(side: float, broken: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 7
	var segments := 5 if broken else 8
	var max_t := 0.58 if broken else 1.0
	var rings: Array = []
	for i in range(segments + 1):
		var u := (float(i) / float(segments)) * max_t
		# Bow slightly outward near base, then arch smoothly inward over the spine
		var x := side * (sin(u * PI) * 2.2 - pow(u, 1.35) * 12.2)
		var y := sin(u * PI * 0.56) * 19.5
		var center := Vector3(x, y, 0.0)
		var du := 0.02
		var u2 := minf(u + du, 1.0)
		var next_c := Vector3(side * (sin(u2 * PI) * 2.2 - pow(u2, 1.35) * 12.2), sin(u2 * PI * 0.56) * 19.5, 0.0)
		var tangent := (next_c - center).normalized()
		if tangent.length_squared() < 0.01:
			tangent = Vector3(-side * 0.7, 0.7, 0.0).normalized()
		var normal_z := Vector3.FORWARD
		var binormal := tangent.cross(normal_z).normalized()
		var radius := lerpf(1.06, 0.30, pow(u, 0.85))
		var pts: Array[Vector3] = []
		for s in range(sides):
			var ang := float(s) * TAU / float(sides)
			var ridge := 1.0 + 0.10 * cos(ang * 2.0)
			var local := binormal * (cos(ang) * radius * ridge) + normal_z * (sin(ang) * radius * 0.66)
			pts.append(center + local)
		rings.append(pts)
	for i in range(segments):
		var r0: Array = rings[i]
		var r1: Array = rings[i + 1]
		for s in range(sides):
			var sn := (s + 1) % sides
			st.add_vertex(r0[s]); st.add_vertex(r0[sn]); st.add_vertex(r1[s])
			st.add_vertex(r0[sn]); st.add_vertex(r1[sn]); st.add_vertex(r1[s])
	var tip_ring: Array = rings[segments]
	var tip_center := Vector3.ZERO
	for p: Vector3 in tip_ring:
		tip_center += p
	tip_center = tip_center / float(sides) + Vector3(-side * 0.35, 0.25 if broken else 0.45, 0.0)
	for s in range(sides):
		var sn := (s + 1) % sides
		st.add_vertex(tip_ring[s]); st.add_vertex(tip_ring[sn]); st.add_vertex(tip_center)
	st.generate_normals()
	return st.commit()

func set_art_observer(at: Vector3, depth_override: float = -1.0) -> void:
	if not is_processing() and at.distance_squared_to(last_diver_pos) > 4.0:
		_sync_animation_lod(at)
	# Water hue follows region weights smoothly, without modifying the shared
	# depth/energy contract used by visibility and navigation.
	var weights := ArtDirection.region_weights(Vector2(at.x, at.z))
	var water := Color(0, 0, 0, 1)
	for region: String in weights:
		var color: Color = ArtDirection.region_profile(region).water
		var weight: float = weights[region]
		water.r += color.r * weight
		water.g += color.g * weight
		water.b += color.b * weight
	var depth := depth_override if depth_override >= 0.0 else maxf(0.0, -at.y)
	var profile := sample_depth_profile(depth)
	var amount := 0.48 * (1.0 - smoothstep(150.0, 600.0, depth)) + 0.15
	var fog: Color = profile.fog_color.lerp(water, amount)
	environment.fog_light_color = fog
	environment.background_color = (fog.srgb_to_linear() * float(profile.fog_energy)).linear_to_srgb()
	_update_water_atmosphere(fog, float(profile.fog_energy), depth)

func _update_water_atmosphere(water: Color, energy: float, depth: float) -> void:
	if water_atmosphere == null:
		return
	var sunlit := 1.0 - smoothstep(40.0, 190.0, depth)
	# Avoid invalidating reflection cubemaps when an observer is stationary or
	# crosses a tiny fraction of a regional blend; the visible fog stays smooth.
	if Vector3(water.r, water.g, water.b).distance_squared_to(Vector3(_atmosphere_color.r, _atmosphere_color.g, _atmosphere_color.b)) > 0.000009:
		water_atmosphere.set_shader_parameter("water_color", water)
		_atmosphere_color = water
	if absf(energy - _atmosphere_energy) > 0.003:
		water_atmosphere.set_shader_parameter("water_energy", energy)
		_atmosphere_energy = energy
	if absf(sunlit - _atmosphere_sunlit) > 0.01:
		water_atmosphere.set_shader_parameter("sunlit_amount", sunlit)
		_atmosphere_sunlit = sunlit

func _sync_animation_lod(observer: Vector3) -> void:
	var prev := last_diver_pos
	last_diver_pos = observer
	for creature in get_creatures():
		if is_instance_valid(creature):
			_update_creature_animation(creature)
	if is_processing():
		last_diver_pos = prev
