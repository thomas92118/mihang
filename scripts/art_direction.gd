extends RefCounted
## Luminous ocean pigments, shared by the world, the asset generator and the UI.

const INK := Color("082b42")
const PAPER := Color("f4f0dc")
const CYAN := Color("83ded9")
const AMBER := Color("edce7a")
const DANGER := Color("f28c77")
const PANEL := Color(0.025, 0.10, 0.15, 0.82)
const MUTED := Color("abc9ce")
const REGIONS := {
	"core": {"water": "0982b0", "sand": "f1d9a7", "rock": "3e7486", "flora": "469c79", "accent": "f09674", "shadow": "0f355d"},
	"atoll": {"water": "12b3c4", "sand": "f4e3bc", "rock": "4e8a8d", "flora": "6fa874", "accent": "efd07a", "shadow": "125975"},
	"kelp": {"water": "15727c", "sand": "d4ca9f", "rock": "3d7276", "flora": "4fa276", "accent": "d0dc7e", "shadow": "104453"},
	"ridge": {"water": "1f639e", "sand": "b8cfd4", "rock": "437494", "flora": "7ea9b5", "accent": "9ce8ee", "shadow": "153668"},
	"citadel": {"water": "165d88", "sand": "cfcfb6", "rock": "5c8284", "flora": "4f9682", "accent": "e6c875", "shadow": "153354"},
	"wreck": {"water": "1b4f73", "sand": "aeb9ad", "rock": "436b78", "flora": "6e9ca0", "accent": "e09e63", "shadow": "15324a"},
	"bones": {"water": "235979", "sand": "b8bca9", "rock": "4c7082", "flora": "8eae9e", "accent": "f0e7c8", "shadow": "16375a"},
	"caldera": {"water": "16354f", "sand": "748589", "rock": "273b4f", "flora": "a88e72", "accent": "f4a64c", "shadow": "11233b"},
	"hadal": {"water": "183e74", "sand": "98b2c6", "rock": "3d628c", "flora": "84adc0", "accent": "bceef0", "shadow": "10264b"}
}
const REGION_ANCHORS := {
	"atoll": Vector3(40, 340, 255), "kelp": Vector3(-260, 280, 200),
	"ridge": Vector3(380, 290, 220), "citadel": Vector3(460, -60, 245),
	"wreck": Vector3(420, -380, 235), "bones": Vector3(-480, -90, 250),
	"caldera": Vector3(-440, -420, 240), "hadal": Vector3(60, -640, 300)
}

static func region_weights(world_xz: Vector2) -> Dictionary:
	var result: Dictionary = {}
	var total := 0.0
	for key: String in REGION_ANCHORS:
		var anchor: Vector3 = REGION_ANCHORS[key]
		var weight := 1.0 - smoothstep(anchor.z * 0.30, anchor.z, world_xz.distance_to(Vector2(anchor.x, anchor.y)))
		if weight > 0.0:
			result[key] = weight
			total += weight
	result["core"] = maxf(0.0, 1.0 - total)
	total = maxf(total, 1.0)
	for key: String in result:
		result[key] /= total
	return result

static func region_id_at(x: float, z: float) -> String:
	var weights := region_weights(Vector2(x, z))
	var best := "core"
	var strongest := -1.0
	for key: String in weights:
		if float(weights[key]) > strongest:
			strongest = weights[key]
			best = key
	return best

static func region_profile(region_id: String) -> Dictionary:
	var source: Dictionary = REGIONS.get(region_id, REGIONS.core)
	var result: Dictionary = {}
	for key: String in source:
		result[key] = Color(source[key])
	return result

static func material_profile(asset_key: String, material_role: String = "", region_id: String = "core") -> Dictionary:
	var region := region_profile(region_id)
	var base: Color = PAPER
	var tip: Color = PAPER
	var roughness := 0.72
	var metal := 0.0
	var emission := Color.BLACK
	var energy := 0.0
	var tint := 0.08
	match asset_key:
		"rock":
			base = region.rock; tip = base.lightened(0.24); roughness = 0.91; tint = 0.22
		"kelp", "resource_kelp", "sea_lily":
			base = region.flora; tip = Color("c8bd7c"); roughness = 0.79; tint = 0.13
		"coral", "staghorn_coral":
			base = Color("cf826d"); tip = Color("efd6ad"); roughness = 0.86
		"table_coral":
			base = Color("c7837d"); tip = Color("e2baa0"); roughness = 0.87
		"brain_coral":
			base = Color("c4ac70"); tip = Color("e4ce98"); roughness = 0.88
		"barrel_sponge", "tube_coral":
			base = Color("9b86a3"); tip = Color("d0b0bc"); roughness = 0.86
		"sea_fan", "anemone":
			base = Color("b76e78"); tip = Color("e1b096"); roughness = 0.8
		"giant_clam":
			base = Color("a59a94"); tip = Color("c2c5d2"); roughness = 0.64
		"tubeworms", "starfish_urchin":
			base = Color("c17b63"); tip = Color("e0c9ad"); roughness = 0.8
		"crystal_spire", "resource_quartz":
			base = Color("83b4b5"); tip = Color("d3e3d8"); roughness = 0.35; emission = CYAN; energy = 0.06
		"ruins":
			base = Color("9ba695"); tip = Color("c5c3a6"); roughness = 0.92
		"school_fish":
			base = Color("3c8294"); tip = Color("e8b95c"); roughness = 0.56; tint = 0.0
		"fish_small":
			base = Color("d5a457"); tip = Color("efe0b6"); roughness = 0.6; tint = 0.0
		"fish", "manta_ray", "fish_predator", "sea_wolf", "seal":
			base = Color("547e8a"); tip = Color("d1d6c5"); roughness = 0.57; tint = 0.0
		"sea_turtle", "colossus_turtle":
			base = Color("688675"); tip = Color("c7c4a2"); roughness = 0.74; tint = 0.0
		"squid", "crab", "sea_spider", "kraken":
			base = Color("a96e76"); tip = Color("d7c3b4"); roughness = 0.66; tint = 0.0
		"jellyfish", "fish_abyss", "water_dragon", "flying_fish":
			base = Color("58768e"); tip = Color("a7c8cc"); roughness = 0.61; emission = CYAN; energy = 0.22; tint = 0.0
		"diver":
			base = Color("17354b"); tip = Color("b9cdc9"); roughness = 0.66; metal = 0.10; tint = 0.0
		"shipwreck":
			base = Color("9da6a2"); tip = Color("d8cdb8"); roughness = 0.68; metal = 0.22; tint = 0.0
		"pod", "submarine", "weapon":
			base = Color("d4d6c9"); tip = Color("e7dfc9"); roughness = 0.46; metal = 0.3; tint = 0.0
		"resource_copper":
			base = Color("a67953"); tip = Color("d4b38b"); roughness = 0.65; metal = 0.35
		"resource_titanium":
			base = Color("7b9397"); tip = Color("c1c6b9"); roughness = 0.48; metal = 0.5
	if material_role == "glass":
		base = Color("466e80"); tip = CYAN; roughness = 0.18; metal = 0.1
	elif material_role == "metal":
		base = Color("516675"); tip = Color("a7b4b4"); roughness = 0.4; metal = 0.65
	elif material_role == "light":
		base = CYAN; tip = PAPER; emission = CYAN; energy = 0.35
	return {"base": base, "shadow": base.darkened(0.55).lerp(region.shadow, 0.15), "tip": tip,
		"roughness": roughness, "metallic": metal, "emission": emission, "emission_energy": energy, "tint_strength": tint}
