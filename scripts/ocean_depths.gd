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
	var fog_color := Color(0.032, 0.44, 0.67).lerp(Color(0.032, 0.28, 0.48), shelf)
	fog_color = fog_color.lerp(Color(0.030, 0.17, 0.35), twilight)
	fog_color = fog_color.lerp(Color(0.024, 0.105, 0.245), basin)
	fog_color = fog_color.lerp(Color(0.018, 0.068, 0.18), hadal)
	# A cool, restrained fill keeps deep silhouettes legible. Directional light
	# still supplies the broad shallow-water forms; lamps restore local pigments.
	var ambient_color := Color(0.66, 0.83, 0.89).lerp(Color(0.44, 0.67, 0.79), shelf)
	ambient_color = ambient_color.lerp(Color(0.30, 0.48, 0.69), twilight)
	ambient_color = ambient_color.lerp(Color(0.24, 0.38, 0.58), basin)
	ambient_color = ambient_color.lerp(Color(0.20, 0.33, 0.52), hadal)
	var fog_energy := 0.54 * exp(-water_depth * 0.004) + 0.32
	return {
		"sun_energy": 0.84 * exp(-water_depth * SUNLIGHT_FALLOFF),
		"sun_color": Color(1.0, 0.955, 0.86),
		"ambient_energy": 0.24 * exp(-water_depth * 0.0068) + 0.105,
		"ambient_color": ambient_color,
		"fog_energy": fog_energy,
		"fog_density": 0.0045 + (1.0 - exp(-water_depth * 0.005)) * 0.0058,
		"fog_color": fog_color,
		"background_color": (fog_color.srgb_to_linear() * fog_energy).linear_to_srgb()
	}
