extends RefCounted
## Shared art vocabulary. Colours are material pigments, never depth-baked light.

const INK := Color("102735")
const PAPER := Color("ede7d8")
const CYAN := Color("80c6c4")
const AMBER := Color("dfb46d")
const DANGER := Color("d76e62")
const PANEL := Color(0.035, 0.085, 0.12, 0.94)
const MUTED := Color("91a9ab")
const REGIONS := {
	"core": {"water": "166b78", "sand": "d8c49e", "rock": "7e8b85", "flora": "839f69", "accent": "d8856a", "shadow": "254753"},
	"atoll": {"water": "187e89", "sand": "e4d7b4", "rock": "a1ad9b", "flora": "8eaa74", "accent": "e5b75f", "shadow": "325964"},
	"kelp": {"water": "163f45", "sand": "b8b591", "rock": "657c70", "flora": "7c9752", "accent": "c9b56c", "shadow": "233e44"},
	"ridge": {"water": "203f5a", "sand": "a6b1ae", "rock": "819cac", "flora": "8a94a2", "accent": "91ccc8", "shadow": "273d54"},
	"citadel": {"water": "173b4b", "sand": "a3aa9a", "rock": "86958b", "flora": "8c8b94", "accent": "78bdb6", "shadow": "243e4a"},
	"wreck": {"water": "152e3d", "sand": "8f8b7d", "rock": "6b7778", "flora": "909ba0", "accent": "d99558", "shadow": "273c46"},
	"bones": {"water": "203b43", "sand": "9e9986", "rock": "6f6759", "flora": "a5a88a", "accent": "cec7ae", "shadow": "2f454b"},
	"caldera": {"water": "121f28", "sand": "756a5e", "rock": "524a43", "flora": "b29b85", "accent": "c96f36", "shadow": "28343e"},
	"hadal": {"water": "111b35", "sand": "777d88", "rock": "6d7b9b", "flora": "9ca6b1", "accent": "92bdd2", "shadow": "1b2d44"}
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
		"pod", "shipwreck", "diver", "submarine", "weapon":
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
