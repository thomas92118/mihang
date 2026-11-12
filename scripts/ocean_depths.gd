extends RefCounted

# Shared physical limits and ecological layers for terrain, movement and charts.
const MAX_SEAFLOOR_DEPTH := 600.0
const MAX_DIVE_DEPTH := 660.0
const SUNLIGHT_FALLOFF := 0.012
const SUNLIT_LIMIT := 35.0
const SHELF_LIMIT := 90.0
const TWILIGHT_LIMIT := 200.0
const BATHYAL_LIMIT := 360.0
const KELP_LIMIT := 55.0

static func zone_id(depth: float) -> String:
	if depth < SUNLIT_LIMIT:
		return "sunlit_reef"
	if depth < SHELF_LIMIT:
		return "shelf_garden"
	if depth < TWILIGHT_LIMIT:
		return "twilight_slope"
	if depth < BATHYAL_LIMIT:
		return "bathyal_basin"
	return "hadal_trench"

static func zone_label(depth: float) -> String:
	match zone_id(depth):
		"sunlit_reef":
			return "阳光浅礁带"
		"shelf_garden":
			return "大陆架海藻与海扇带"
		"twilight_slope":
			return "暮光陆坡冷水珊瑚带"
		"bathyal_basin":
			return "深海盆地海绵与海百合带"
		_:
			return "极深海沟黏土与结核带"

static func light_profile(depth: float) -> Dictionary:
	var water_depth := maxf(depth, 0.0)
	var shelf := smoothstep(0.0, 95.0, water_depth)
	var twilight := smoothstep(75.0, 220.0, water_depth)
	var basin := smoothstep(180.0, 390.0, water_depth)
	var hadal := smoothstep(340.0, MAX_SEAFLOOR_DEPTH, water_depth)
	var fog_color := Color(0.10, 0.29, 0.32).lerp(Color(0.030, 0.15, 0.20), shelf)
	fog_color = fog_color.lerp(Color(0.012, 0.055, 0.10), twilight)
	fog_color = fog_color.lerp(Color(0.004, 0.017, 0.038), basin)
	fog_color = fog_color.lerp(Color(0.0015, 0.006, 0.014), hadal)
	var ambient_color := Color(0.68, 0.80, 0.81).lerp(Color(0.38, 0.59, 0.68), shelf)
	ambient_color = ambient_color.lerp(Color(0.22, 0.39, 0.56), twilight)
	ambient_color = ambient_color.lerp(Color(0.14, 0.24, 0.37), basin)
	var fog_energy := 0.64 * exp(-water_depth * 0.006) + 0.08
	return {
		"sun_energy": 1.25 * exp(-water_depth * SUNLIGHT_FALLOFF),
		"sun_color": Color(1.0, 0.97, 0.89),
		"ambient_energy": 0.38 * exp(-water_depth * 0.009) + 0.008,
		"ambient_color": ambient_color,
		"fog_energy": fog_energy,
		"fog_density": 0.0065 + (1.0 - exp(-water_depth * 0.005)) * 0.009,
		"fog_color": fog_color,
		"background_color": Color(fog_color.r * fog_energy, fog_color.g * fog_energy, fog_color.b * fog_energy)
	}
