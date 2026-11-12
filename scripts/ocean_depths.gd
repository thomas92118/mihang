extends RefCounted

const ArtDirection := preload("res://scripts/art_direction.gd")

static func region_palette_texture() -> ImageTexture:
	# One tiny shared atlas supplies terrain pigments, including boundary blends.
	# This remains ordinary texture sampling on the Compatibility/Web renderer.
	var image := Image.create(9, 2, false, Image.FORMAT_RGBA8)
	var ids := ["core", "atoll", "kelp", "ridge", "citadel", "wreck", "bones", "caldera", "hadal"]
	for index in range(ids.size()):
		var profile := ArtDirection.region_profile(ids[index])
		image.set_pixel(index, 0, profile["sand"])
		image.set_pixel(index, 1, profile["rock"])
	return ImageTexture.create_from_image(image)

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
	# A luminous turquoise horizon separates the sunlit colonies from their
	# background. The same continuous curve reaches a nearly black blue trench.
	var fog_color := Color(0.025, 0.40, 0.62).lerp(Color(0.025, 0.23, 0.42), shelf)
	fog_color = fog_color.lerp(Color(0.025, 0.13, 0.29), twilight)
	fog_color = fog_color.lerp(Color(0.018, 0.075, 0.18), basin)
	fog_color = fog_color.lerp(Color(0.012, 0.045, 0.13), hadal)
	var ambient_color := Color(0.60, 0.80, 0.86).lerp(Color(0.36, 0.60, 0.72), shelf)
	ambient_color = ambient_color.lerp(Color(0.22, 0.39, 0.60), twilight)
	ambient_color = ambient_color.lerp(Color(0.16, 0.26, 0.43), basin)
	var fog_energy := 0.56 * exp(-water_depth * 0.004) + 0.30
	return {
		"sun_energy": 0.76 * exp(-water_depth * SUNLIGHT_FALLOFF),
		"sun_color": Color(1.0, 0.955, 0.86),
		"ambient_energy": 0.23 * exp(-water_depth * 0.007) + 0.08,
		"ambient_color": ambient_color,
		"fog_energy": fog_energy,
		"fog_density": 0.0046 + (1.0 - exp(-water_depth * 0.005)) * 0.006,
		"fog_color": fog_color,
		"background_color": (fog_color.srgb_to_linear() * fog_energy).linear_to_srgb()
	}
