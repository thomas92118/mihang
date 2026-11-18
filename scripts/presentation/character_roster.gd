extends RefCounted
## Playable character roster, procedural mermaid PBR textures & bespoke 3D ornaments.

const ReferenceDiver = preload("res://scripts/presentation/reference_diver.gd")
const SafeArea = preload("res://scripts/presentation/safe_area.gd")
const DEFAULT_CHARACTER := "coral_mermaid"
const SAVE_PATH := "user://character_profile.cfg"

const CHARACTER_ORDER: Array[String] = [
	"coral_mermaid",
	"moonlight_mermaid",
	"abyss_mermaid",
	"golden_siren",
	"sakura_mermaid",
	"expedition_diver",
]

const PROFILES := {
	"coral_mermaid": {
		"id": "coral_mermaid",
		"name": "珊瑚晨曦人鱼",
		"short_name": "珊瑚人鱼",
		"subtitle": "绯莓长发 · 珠母贝衣 · 碧海粉绡尾",
		"badge_color": Color(0.96, 0.56, 0.68),
		"ring_color": Color(0.45, 0.96, 0.92),
		"is_mermaid": true,
	},
	"moonlight_mermaid": {
		"id": "moonlight_mermaid",
		"name": "月光银发人鱼",
		"short_name": "月光银发",
		"subtitle": "月华银发 · 紫晶星眸 · 蓝紫星纱尾",
		"badge_color": Color(0.76, 0.70, 1.0),
		"ring_color": Color(0.68, 0.56, 1.0),
		"is_mermaid": true,
	},
	"abyss_mermaid": {
		"id": "abyss_mermaid",
		"name": "深海幽光人鱼",
		"short_name": "深海美人鱼",
		"subtitle": "溟海墨蓝发 · 幽冥电青鳞 · 生物荧光尾",
		"badge_color": Color(0.22, 0.94, 0.96),
		"ring_color": Color(0.14, 0.95, 0.88),
		"is_mermaid": true,
	},
	"golden_siren": {
		"id": "golden_siren",
		"name": "曦光金鳞人鱼",
		"short_name": "曦光金鳞",
		"subtitle": "香槟金发 · 翡翠碧眸 · 流金珊瑚尾",
		"badge_color": Color(1.0, 0.82, 0.42),
		"ring_color": Color(1.0, 0.78, 0.32),
		"is_mermaid": true,
	},
	"sakura_mermaid": {
		"id": "sakura_mermaid",
		"name": "幻樱星汐人鱼",
		"short_name": "幻樱星汐",
		"subtitle": "樱粉长发 · 晴空星眸 · 樱霞极光尾",
		"badge_color": Color(0.98, 0.72, 0.88),
		"ring_color": Color(0.98, 0.68, 0.86),
		"is_mermaid": true,
	},
	"expedition_diver": {
		"id": "expedition_diver",
		"name": "深潜科考员",
		"short_name": "深潜科考",
		"subtitle": "抗压潜航装甲 · 全景面罩 · 双气瓶推进",
		"badge_color": Color(0.52, 0.82, 0.90),
		"ring_color": Color(0.38, 0.86, 0.96),
		"is_mermaid": false,
	},
}

const MERMAID_STYLES := {
	"moonlight_mermaid": {
		"skin_base": Vector3(0.985, 0.945, 0.975),
		"skin_blush": Vector3(0.89, 0.64, 0.84),
		"skin_shadow_makeup": Vector3(0.90, 0.82, 0.96),
		"skin_shadow_mat": Color(0.88, 0.79, 0.90),
		"body_warmth": Vector3(0.92, 0.76, 0.92),
		"body_shimmer": Vector3(0.78, 0.82, 1.0),
		"lip_deep": Vector3(0.68, 0.24, 0.52),
		"lip_soft": Vector3(0.92, 0.58, 0.78),
		"lash": Color(0.18, 0.16, 0.28),
		"iris_limbal": Vector3(0.08, 0.06, 0.28),
		"iris_deep": Vector3(0.22, 0.14, 0.56),
		"iris_mid": Vector3(0.46, 0.34, 0.94),
		"iris_glow": Vector3(0.74, 0.78, 1.0),
		"iris_ring": Vector3(0.92, 0.94, 1.0),
		"iris_emission": 0.16,
		"hair_root": Vector3(0.46, 0.50, 0.66),
		"hair_tip": Vector3(0.93, 0.95, 1.0),
		"hair_hi_root": Vector3(0.62, 0.66, 0.82),
		"hair_hi_tip": Vector3(0.98, 0.98, 1.0),
		"hair_halo": Vector3(0.88, 0.84, 1.0),
		"hair_rough": 0.23,
		"hair_metal": 0.14,
		"shell_ivory": Vector3(0.93, 0.95, 1.0),
		"shell_blush": Vector3(0.76, 0.68, 0.98),
		"shell_irid": Vector3(0.68, 0.88, 1.0),
		"pearl": Color(0.94, 0.95, 1.0),
		"gold": Color(0.78, 0.82, 0.93),
		"gold_light": Color(0.91, 0.94, 1.0),
		"gold_metal": 0.88,
		"gold_rough": 0.18,
		"specimen_gold": Color(0.82, 0.78, 1.0),
		"glass": Color(0.70, 0.68, 1.0, 0.41),
		"glass_emission": Color(0.62, 0.58, 1.0),
		"glass_emission_energy": 0.14,
		"scale_dorsal": Vector3(0.11, 0.20, 0.66),
		"scale_lateral": Vector3(0.38, 0.26, 0.88),
		"scale_ventral": Vector3(0.64, 0.68, 0.98),
		"scale_irid": Vector3(0.74, 0.48, 0.98),
		"scale_rim": Vector3(0.88, 0.84, 1.0),
		"scale_peduncle": Vector3(0.54, 0.46, 0.94),
		"scale_emission_col": Vector3(0.52, 0.44, 1.0),
		"scale_emission_energy": 0.22,
		"fin_root": Vector3(0.24, 0.22, 0.82),
		"fin_mid": Vector3(0.52, 0.36, 0.96),
		"fin_tip": Vector3(0.74, 0.88, 1.0),
		"fin_emission_col": Vector3(0.56, 0.48, 1.0),
		"fin_emission_energy": 0.18,
		"bubble_color": Color(0.84, 0.80, 1.0, 0.34),
	},
	"abyss_mermaid": {
		"skin_base": Vector3(0.92, 0.95, 0.98),
		"skin_blush": Vector3(0.66, 0.72, 0.88),
		"skin_shadow_makeup": Vector3(0.74, 0.88, 0.96),
		"skin_shadow_mat": Color(0.76, 0.84, 0.92),
		"body_warmth": Vector3(0.74, 0.84, 0.94),
		"body_shimmer": Vector3(0.32, 0.94, 0.92),
		"lip_deep": Vector3(0.54, 0.14, 0.34),
		"lip_soft": Vector3(0.78, 0.38, 0.58),
		"lash": Color(0.05, 0.10, 0.18),
		"iris_limbal": Vector3(0.02, 0.10, 0.18),
		"iris_deep": Vector3(0.04, 0.32, 0.44),
		"iris_mid": Vector3(0.08, 0.86, 0.82),
		"iris_glow": Vector3(0.42, 1.0, 0.92),
		"iris_ring": Vector3(1.0, 0.84, 0.34),
		"iris_emission": 0.36,
		"hair_root": Vector3(0.04, 0.08, 0.20),
		"hair_tip": Vector3(0.08, 0.66, 0.82),
		"hair_hi_root": Vector3(0.07, 0.18, 0.36),
		"hair_hi_tip": Vector3(0.28, 0.95, 0.98),
		"hair_halo": Vector3(0.22, 0.92, 0.98),
		"hair_rough": 0.25,
		"hair_metal": 0.10,
		"shell_ivory": Vector3(0.16, 0.24, 0.34),
		"shell_blush": Vector3(0.24, 0.18, 0.44),
		"shell_irid": Vector3(0.14, 0.84, 0.78),
		"pearl": Color(0.72, 0.96, 0.98),
		"gold": Color(0.30, 0.56, 0.66),
		"gold_light": Color(0.52, 0.88, 0.94),
		"gold_metal": 0.84,
		"gold_rough": 0.22,
		"specimen_gold": Color(0.22, 0.96, 0.92),
		"glass": Color(0.18, 0.95, 0.96, 0.42),
		"glass_emission": Color(0.12, 0.96, 0.92),
		"glass_emission_energy": 0.32,
		"scale_dorsal": Vector3(0.03, 0.09, 0.22),
		"scale_lateral": Vector3(0.06, 0.24, 0.42),
		"scale_ventral": Vector3(0.12, 0.56, 0.66),
		"scale_irid": Vector3(0.10, 0.88, 0.84),
		"scale_rim": Vector3(0.18, 0.98, 0.96),
		"scale_peduncle": Vector3(0.08, 0.68, 0.74),
		"scale_emission_col": Vector3(0.14, 0.98, 0.92),
		"scale_emission_energy": 0.58,
		"fin_root": Vector3(0.04, 0.18, 0.34),
		"fin_mid": Vector3(0.08, 0.74, 0.88),
		"fin_tip": Vector3(0.32, 1.0, 0.84),
		"fin_emission_col": Vector3(0.14, 0.96, 0.90),
		"fin_emission_energy": 0.44,
		"bubble_color": Color(0.32, 1.0, 0.94, 0.38),
	},
	"golden_siren": {
		"skin_base": Vector3(0.99, 0.89, 0.82),
		"skin_blush": Vector3(0.98, 0.58, 0.52),
		"skin_shadow_makeup": Vector3(0.96, 0.76, 0.64),
		"skin_shadow_mat": Color(0.90, 0.72, 0.65),
		"body_warmth": Vector3(0.98, 0.68, 0.56),
		"body_shimmer": Vector3(1.0, 0.90, 0.64),
		"lip_deep": Vector3(0.88, 0.28, 0.26),
		"lip_soft": Vector3(0.98, 0.58, 0.50),
		"lash": Color(0.24, 0.14, 0.08),
		"iris_limbal": Vector3(0.04, 0.20, 0.16),
		"iris_deep": Vector3(0.06, 0.44, 0.34),
		"iris_mid": Vector3(0.12, 0.78, 0.58),
		"iris_glow": Vector3(0.54, 0.98, 0.78),
		"iris_ring": Vector3(1.0, 0.86, 0.42),
		"iris_emission": 0.12,
		"hair_root": Vector3(0.62, 0.40, 0.16),
		"hair_tip": Vector3(0.98, 0.88, 0.58),
		"hair_hi_root": Vector3(0.76, 0.54, 0.24),
		"hair_hi_tip": Vector3(1.0, 0.95, 0.76),
		"hair_halo": Vector3(1.0, 0.95, 0.78),
		"hair_rough": 0.24,
		"hair_metal": 0.12,
		"shell_ivory": Vector3(1.0, 0.96, 0.88),
		"shell_blush": Vector3(0.98, 0.78, 0.56),
		"shell_irid": Vector3(0.72, 0.96, 0.88),
		"pearl": Color(1.0, 0.96, 0.84),
		"gold": Color(0.90, 0.70, 0.28),
		"gold_light": Color(0.98, 0.88, 0.56),
		"gold_metal": 0.88,
		"gold_rough": 0.19,
		"specimen_gold": Color(1.0, 0.84, 0.36),
		"glass": Color(1.0, 0.86, 0.58, 0.41),
		"glass_emission": Color(1.0, 0.82, 0.44),
		"glass_emission_energy": 0.12,
		"scale_dorsal": Vector3(0.88, 0.46, 0.24),
		"scale_lateral": Vector3(0.96, 0.74, 0.28),
		"scale_ventral": Vector3(1.0, 0.92, 0.66),
		"scale_irid": Vector3(0.28, 0.86, 0.78),
		"scale_rim": Vector3(1.0, 0.94, 0.68),
		"scale_peduncle": Vector3(0.98, 0.64, 0.46),
		"scale_emission_col": Vector3(1.0, 0.80, 0.38),
		"scale_emission_energy": 0.14,
		"fin_root": Vector3(0.96, 0.68, 0.32),
		"fin_mid": Vector3(0.98, 0.54, 0.44),
		"fin_tip": Vector3(1.0, 0.92, 0.64),
		"fin_emission_col": Vector3(1.0, 0.82, 0.44),
		"fin_emission_energy": 0.12,
		"bubble_color": Color(1.0, 0.92, 0.70, 0.32),
	},
	"sakura_mermaid": {
		"skin_base": Vector3(0.995, 0.94, 0.96),
		"skin_blush": Vector3(0.98, 0.62, 0.74),
		"skin_shadow_makeup": Vector3(0.98, 0.78, 0.88),
		"skin_shadow_mat": Color(0.91, 0.75, 0.83),
		"body_warmth": Vector3(0.98, 0.74, 0.84),
		"body_shimmer": Vector3(0.84, 0.96, 0.98),
		"lip_deep": Vector3(0.88, 0.32, 0.52),
		"lip_soft": Vector3(0.98, 0.66, 0.78),
		"lash": Color(0.28, 0.14, 0.20),
		"iris_limbal": Vector3(0.12, 0.14, 0.34),
		"iris_deep": Vector3(0.22, 0.38, 0.68),
		"iris_mid": Vector3(0.36, 0.74, 0.98),
		"iris_glow": Vector3(0.98, 0.72, 0.90),
		"iris_ring": Vector3(1.0, 0.88, 0.94),
		"iris_emission": 0.14,
		"hair_root": Vector3(0.68, 0.34, 0.50),
		"hair_tip": Vector3(1.0, 0.82, 0.90),
		"hair_hi_root": Vector3(0.82, 0.48, 0.64),
		"hair_hi_tip": Vector3(1.0, 0.92, 0.96),
		"hair_halo": Vector3(1.0, 0.94, 0.98),
		"hair_rough": 0.24,
		"hair_metal": 0.08,
		"shell_ivory": Vector3(1.0, 0.95, 0.97),
		"shell_blush": Vector3(0.98, 0.72, 0.84),
		"shell_irid": Vector3(0.76, 0.96, 0.98),
		"pearl": Color(1.0, 0.95, 0.98),
		"gold": Color(0.90, 0.68, 0.72),
		"gold_light": Color(0.98, 0.86, 0.88),
		"gold_metal": 0.84,
		"gold_rough": 0.20,
		"specimen_gold": Color(0.98, 0.76, 0.86),
		"glass": Color(0.98, 0.78, 0.92, 0.41),
		"glass_emission": Color(0.96, 0.72, 0.90),
		"glass_emission_energy": 0.14,
		"scale_dorsal": Vector3(0.94, 0.52, 0.72),
		"scale_lateral": Vector3(0.98, 0.72, 0.86),
		"scale_ventral": Vector3(0.88, 0.96, 0.98),
		"scale_irid": Vector3(0.56, 0.94, 0.92),
		"scale_rim": Vector3(1.0, 0.92, 0.96),
		"scale_peduncle": Vector3(0.74, 0.92, 0.96),
		"scale_emission_col": Vector3(0.98, 0.72, 0.88),
		"scale_emission_energy": 0.16,
		"fin_root": Vector3(0.64, 0.92, 0.94),
		"fin_mid": Vector3(0.98, 0.68, 0.84),
		"fin_tip": Vector3(1.0, 0.92, 0.96),
		"fin_emission_col": Vector3(0.96, 0.74, 0.90),
		"fin_emission_energy": 0.14,
		"bubble_color": Color(1.0, 0.84, 0.94, 0.34),
	},
}

static var _texture_cache: Dictionary = {}
static var _scale_cell_ready := false
static var _scale_dome: PackedFloat32Array
static var _scale_rim: PackedFloat32Array
static var _scale_groove: PackedFloat32Array
static var _scale_striat: PackedFloat32Array

static func normalize_id(character_id: String) -> String:
	return character_id if PROFILES.has(character_id) else DEFAULT_CHARACTER

static func get_profile(character_id: String) -> Dictionary:
	return PROFILES[normalize_id(character_id)]

static func next_id(current_id: String, step: int = 1) -> String:
	var idx := CHARACTER_ORDER.find(normalize_id(current_id))
	if idx < 0:
		idx = 0
	return CHARACTER_ORDER[posmod(idx + step, CHARACTER_ORDER.size())]

static func load_saved_character() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return DEFAULT_CHARACTER
	return normalize_id(str(cfg.get_value("character", "selected", DEFAULT_CHARACTER)))

static func save_character(character_id: String) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("character", "selected", normalize_id(character_id))
	cfg.save(SAVE_PATH)

static func apply_mermaid_style(
	model_root: Node3D,
	drivers: Dictionary,
	breath_bubbles: CPUParticles3D,
	thruster_bubbles: CPUParticles3D,
	character_id: String
) -> void:
	var cid := normalize_id(character_id)
	if cid == DEFAULT_CHARACTER or not MERMAID_STYLES.has(cid):
		return
	var style: Dictionary = MERMAID_STYLES[cid]
	var tex_set := _get_textures(cid, style)
	var seen_mats: Dictionary = {}
	for part: MeshInstance3D in model_root.find_children("*", "MeshInstance3D", true, false):
		if not bool(part.get_meta("reference_part", false)) or part.mesh == null:
			continue
		for s_idx in part.mesh.get_surface_count():
			var mat := part.get_surface_override_material(s_idx) as StandardMaterial3D
			if mat == null or seen_mats.has(mat.get_instance_id()):
				continue
			seen_mats[mat.get_instance_id()] = true
			var role := String(mat.get_meta("reference_role", ""))
			_apply_role_material(mat, role, style, tex_set)
	var head_node: Node3D = drivers.get("head", null)
	if is_instance_valid(head_node):
		_attach_head_ornament(head_node, cid)
	ReferenceDiver.configure_mermaid_materials(model_root)
	var bubble_col: Color = style.get("bubble_color", Color(0.86, 0.98, 1.0, 0.32))
	for emitter: CPUParticles3D in [breath_bubbles, thruster_bubbles]:
		if is_instance_valid(emitter) and emitter.mesh is PrimitiveMesh:
			var p_mesh := (emitter.mesh as PrimitiveMesh).duplicate() as PrimitiveMesh
			var b_mat := StandardMaterial3D.new()
			b_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			b_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			b_mat.albedo_color = bubble_col
			p_mesh.material = b_mat
			emitter.mesh = p_mesh

static func _apply_role_material(mat: StandardMaterial3D, role: String, style: Dictionary, tex_set: Dictionary) -> void:
	match role:
		"scales":
			mat.albedo_color = Color.WHITE
			mat.albedo_texture = tex_set["scales"]
			mat.roughness = 0.18
			mat.metallic = 0.24
			var em_energy: float = float(style.get("scale_emission_energy", 0.0))
			if em_energy > 0.01 and tex_set.has("scales_emission"):
				mat.emission_enabled = true
				mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
				mat.emission = Color.WHITE
				mat.emission_texture = tex_set["scales_emission"]
				mat.emission_energy_multiplier = em_energy
		"fin_pearl":
			mat.albedo_color = Color.WHITE
			mat.albedo_texture = tex_set["fin_pearl"]
			mat.roughness = 0.20
			mat.metallic = 0.16
			var fin_em: float = float(style.get("fin_emission_energy", 0.0))
			if fin_em > 0.01 and tex_set.has("fin_emission"):
				mat.emission_enabled = true
				mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
				mat.emission = Color.WHITE
				mat.emission_texture = tex_set["fin_emission"]
				mat.emission_energy_multiplier = fin_em
		"shell_pearl":
			mat.albedo_color = Color.WHITE
			mat.albedo_texture = tex_set["shell_pearl"]
			mat.roughness = 0.19
			mat.metallic = 0.18
		"skin":
			mat.albedo_color = Color.WHITE
			mat.albedo_texture = tex_set["skin"]
		"body_skin":
			mat.albedo_color = Color.WHITE
			mat.albedo_texture = tex_set["body_skin"]
		"skin_shadow":
			mat.set_meta("styled_crease_color", style["skin_shadow_mat"])
			mat.albedo_color = style["skin_shadow_mat"]
		"lip":
			mat.albedo_color = Color.WHITE
			mat.albedo_texture = tex_set["lip"]
			mat.roughness = 0.15
		"lash":
			mat.albedo_color = style["lash"]
		"iris":
			mat.albedo_color = Color.WHITE
			mat.albedo_texture = tex_set["iris"]
			var iris_em: float = float(style.get("iris_emission", 0.0))
			mat.set_meta("variant_iris_emission", iris_em)
			if iris_em > 0.01:
				mat.emission_enabled = true
				mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
				mat.emission = Color.WHITE
				mat.emission_texture = tex_set["iris"]
				mat.emission_energy_multiplier = iris_em
		"hair":
			mat.albedo_color = Color.WHITE
			mat.albedo_texture = tex_set["hair"]
			mat.roughness = float(style.get("hair_rough", 0.25))
			mat.metallic = float(style.get("hair_metal", 0.08))
		"hair_highlight":
			mat.albedo_color = Color.WHITE
			mat.albedo_texture = tex_set["hair_highlight"]
			mat.roughness = maxf(0.18, float(style.get("hair_rough", 0.25)) - 0.03)
			mat.metallic = float(style.get("hair_metal", 0.08)) + 0.04
		"pearl":
			mat.albedo_color = style["pearl"]
			mat.roughness = 0.13
			mat.metallic = 0.16
		"gold":
			mat.albedo_color = style["gold"]
			mat.metallic = float(style.get("gold_metal", 0.85))
			mat.roughness = float(style.get("gold_rough", 0.20))
		"gold_light":
			mat.albedo_color = style["gold_light"]
			mat.metallic = maxf(0.68, float(style.get("gold_metal", 0.85)) - 0.10)
			mat.roughness = float(style.get("gold_rough", 0.20)) + 0.02
		"specimen_gold":
			mat.albedo_color = style["specimen_gold"]
			mat.emission_enabled = true
			mat.emission = style["specimen_gold"]
			mat.emission_energy_multiplier = 0.16
		"glass":
			mat.albedo_color = style["glass"]
			mat.emission_enabled = true
			mat.emission = style["glass_emission"]
			mat.emission_energy_multiplier = float(style.get("glass_emission_energy", 0.10))

static func _ensure_scale_cell_lut() -> void:
	if _scale_cell_ready:
		return
	_scale_cell_ready = true
	# Exact 20x12 staggered 2-row scale tile matching 34x54 UV grid (340x324 image)
	_scale_dome.resize(20 * 12)
	_scale_rim.resize(20 * 12)
	_scale_groove.resize(20 * 12)
	_scale_striat.resize(20 * 12)
	for ry in range(12):
		var row_parity := 0.5 if ry >= 6 else 0.0
		var fy := (float(ry % 6) + 0.5) / 6.0
		for rx in range(20):
			var gx := (float(rx) + 0.5) / 10.0 + row_parity
			var fx := (gx - floorf(gx)) - 0.5
			var dist_rim := sqrt(pow(fx * 1.12, 2.0) + pow((fy - 0.42) * 1.05, 2.0))
			var dome := clampf(1.0 - pow(dist_rim, 1.85), 0.0, 1.0)
			var rim := exp(-pow((dist_rim - 0.82) / 0.085, 2.0)) * (1.0 if fy > 0.18 else 0.0)
			var groove := exp(-pow((dist_rim - 0.93) / 0.055, 2.0))
			var striat := sin(fx * PI * 16.0) * 0.015 * dome
			var k := ry * 20 + rx
			_scale_dome[k] = dome
			_scale_rim[k] = rim
			_scale_groove[k] = groove
			_scale_striat[k] = striat

static func _to_tex(w: int, h: int, bytes: PackedByteArray) -> ImageTexture:
	var img := Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, bytes)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

static func _write_rgb(bytes: PackedByteArray, offset: int, col: Vector3) -> void:
	bytes[offset] = clampi(roundi(col.x * 255.0), 0, 255)
	bytes[offset + 1] = clampi(roundi(col.y * 255.0), 0, 255)
	bytes[offset + 2] = clampi(roundi(col.z * 255.0), 0, 255)
	bytes[offset + 3] = 255

static func _get_textures(cid: String, style: Dictionary) -> Dictionary:
	if _texture_cache.has(cid):
		return _texture_cache[cid]
	_ensure_scale_cell_lut()
	var out: Dictionary = {}
	var res_div := 2 if (SafeArea.is_default_touch_platform() or OS.has_feature("web")) else 1

	# 1. Imbricated Mermaid Scales (340x324 — exact 10px/col x 6px/row period for 34x54 UV grid)
	var sw := 340 / res_div
	var sh := 324 / res_div
	var s_bytes := PackedByteArray()
	s_bytes.resize(sw * sh * 4)
	var se_bytes := PackedByteArray()
	se_bytes.resize(sw * sh * 4)
	var c_dorsal: Vector3 = style["scale_dorsal"]
	var c_lat: Vector3 = style["scale_lateral"]
	var c_vent: Vector3 = style["scale_ventral"]
	var c_irid: Vector3 = style["scale_irid"]
	var c_rim: Vector3 = style["scale_rim"]
	var c_ped: Vector3 = style["scale_peduncle"]
	var c_skin: Vector3 = style["skin_base"]
	var c_em: Vector3 = style["scale_emission_col"]
	var u_vent := PackedFloat32Array()
	var u_lat := PackedFloat32Array()
	u_vent.resize(sw)
	u_lat.resize(sw)
	for x in range(sw):
		var uu := (float(x) + 0.5) / float(sw)
		u_vent[x] = cos(uu * TAU) * 0.5 + 0.5
		var s_u := sin(uu * PI)
		u_lat[x] = s_u * s_u
	var idx := 0
	for y in range(sh):
		# glTF top row y=0 corresponds to Blender vv=1 (waist)
		var vv := 1.0 - (float(y) + 0.5) / float(sh)
		var waist_b := pow(clampf((vv - 0.85) / 0.15, 0.0, 1.0), 1.35) * 0.84
		var ped_b := pow(clampf((0.16 - vv) / 0.16, 0.0, 1.0), 1.4) * 0.55
		var ry := posmod((sh - 1 - y) * res_div, 12)
		var row_off := ry * 20
		for x in range(sw):
			var uu := (float(x) + 0.5) / float(sw)
			var vent := u_vent[x]
			var lat := u_lat[x]
			var k := row_off + ((x * res_div) % 20)
			var dome := _scale_dome[k]
			var rim := _scale_rim[k]
			var groove := _scale_groove[k]
			var striat := _scale_striat[k]
			var body_c := c_dorsal * ((1.0 - vent) * 0.65) + c_lat * (0.55 + 0.35 * lat) + c_vent * (vent * 0.42)
			body_c = body_c.clamp(Vector3.ZERO, Vector3.ONE)
			var irid := (0.5 + 0.5 * sin(vv * 15.0 + uu * TAU * 2.0)) * 0.28 * lat
			body_c = body_c * (1.0 - irid) + c_irid * irid
			var col := body_c * (0.72 + 0.34 * dome + striat)
			col = col * (1.0 - 0.56 * rim) + c_rim * (0.56 * rim)
			col *= (1.0 - 0.32 * groove)
			col = col * (1.0 - ped_b) + c_ped * ped_b
			col = col * (1.0 - waist_b) + c_skin * waist_b
			_write_rgb(s_bytes, idx, col)
			var em_mask := clampf(rim * 0.92 + dome * lat * 0.16, 0.0, 1.0) * (1.0 - waist_b)
			_write_rgb(se_bytes, idx, c_em * em_mask)
			idx += 4
	out["scales"] = _to_tex(sw, sh, s_bytes)
	out["scales_emission"] = _to_tex(sw, sh, se_bytes)

	# 2. Gossamer Caudal & Lateral Fin Pearl (192x256)
	var fw := 192 / res_div
	var fh := 256 / res_div
	var f_bytes := PackedByteArray()
	f_bytes.resize(fw * fh * 4)
	var fe_bytes := PackedByteArray()
	fe_bytes.resize(fw * fh * 4)
	var f_root: Vector3 = style["fin_root"]
	var f_mid: Vector3 = style["fin_mid"]
	var f_tip: Vector3 = style["fin_tip"]
	var f_em_col: Vector3 = style["fin_emission_col"]
	idx = 0
	for y in range(fh):
		var vv := 1.0 - (float(y) + 0.5) / float(fh)
		var w_mid := exp(-pow((vv - 0.54) / 0.30, 2.0))
		var w_tip := pow(clampf((vv - 0.45) / 0.55, 0.0, 1.0), 1.5)
		var w_root := clampf(1.0 - vv * 1.5, 0.0, 1.0)
		var tot := maxf(0.0001, w_root + w_mid + w_tip)
		var row_base := (f_root * w_root + f_mid * w_mid + f_tip * w_tip) / tot
		for x in range(fw):
			var uu := (float(x) + 0.5) / float(fw)
			var ray_wave := sin(uu * PI * 38.0)
			var rays := ray_wave * 0.042 * (1.0 - 0.25 * vv)
			var shimmer := 0.045 * cos(uu * PI * 12.0 - vv * 6.0)
			_write_rgb(f_bytes, idx, row_base * (1.0 + rays + shimmer))
			var vein := clampf(maxf(0.0, ray_wave) * 0.65 + w_tip * 0.45, 0.0, 1.0)
			_write_rgb(fe_bytes, idx, f_em_col * vein)
			idx += 4
	out["fin_pearl"] = _to_tex(fw, fh, f_bytes)
	out["fin_emission"] = _to_tex(fw, fh, fe_bytes)

	# 3. Flowing Silk Hair & Highlights (192x256)
	for is_hi in [false, true]:
		var hw := 192 / res_div
		var hh := 256 / res_div
		var h_bytes := PackedByteArray()
		h_bytes.resize(hw * hh * 4)
		var h_root: Vector3 = style["hair_hi_root"] if is_hi else style["hair_root"]
		var h_tip: Vector3 = style["hair_hi_tip"] if is_hi else style["hair_tip"]
		var h_halo: Vector3 = style["hair_halo"]
		idx = 0
		for y in range(hh):
			var vv := 1.0 - (float(y) + 0.5) / float(hh)
			var ombre := pow(clampf((vv - 0.22) / 0.78, 0.0, 1.0), 1.2)
			var halo_v := exp(-pow((vv - 0.28) / 0.085, 2.0)) * 0.18
			var base_h := h_root * (1.0 - ombre) + h_tip * ombre
			for x in range(hw):
				var uu := (float(x) + 0.5) / float(hw)
				var strands := sin(uu * TAU * 38.0) * 0.042 + sin(uu * TAU * 14.0) * 0.028
				var halo := halo_v * (0.5 + 0.5 * cos(uu * TAU * 2.0))
				_write_rgb(h_bytes, idx, base_h * (1.0 + strands) + h_halo * halo)
				idx += 4
		out["hair_highlight" if is_hi else "hair"] = _to_tex(hw, hh, h_bytes)

	# 4. Starry Ocean-Gem Iris (128x128)
	var isz := 128 / res_div
	var i_bytes := PackedByteArray()
	i_bytes.resize(isz * isz * 4)
	var c_lim: Vector3 = style["iris_limbal"]
	var c_ideep: Vector3 = style["iris_deep"]
	var c_imid: Vector3 = style["iris_mid"]
	var c_iglow: Vector3 = style["iris_glow"]
	var c_iring: Vector3 = style["iris_ring"]
	idx = 0
	for y in range(isz):
		var yy := 1.0 - (float(y) + 0.5) / float(isz) * 2.0
		var upper_sh := pow(clampf((yy + 0.10) / 0.95, 0.0, 1.0), 1.35) * 0.78
		for x in range(isz):
			var xx := (float(x) + 0.5) / float(isz) * 2.0 - 1.0
			var rr := sqrt(xx * xx + yy * yy)
			var ang := atan2(yy, xx)
			var limbal := pow(clampf((rr - 0.66) / 0.30, 0.0, 1.0), 1.25) * 0.90
			var lower_glow := exp(-pow((rr - 0.54) / 0.18, 2.0)) * clampf(-yy + 0.15, 0.0, 1.0) * 0.56
			var ring := exp(-pow((rr - 0.35) / 0.11, 2.0)) * 0.52
			var fibers := 0.5 + 0.5 * sin(ang * 36.0 + sin(rr * 8.0) * 1.1)
			var mid := c_imid * (1.0 - 0.34 * fibers) + c_iglow * (0.34 * fibers)
			var col := mid * (1.0 - upper_sh) + c_ideep * upper_sh
			col = col * (1.0 - ring) + c_iring * ring
			col += c_iglow * lower_glow
			col = col * (1.0 - limbal) + c_lim * limbal
			_write_rgb(i_bytes, idx, col)
			idx += 4
	out["iris"] = _to_tex(isz, isz, i_bytes)

	# 5. Scallop Shell Nacre, Face Skin, Body Skin & Glossy Lips (128x128)
	var bsz := 128 / res_div
	var sh_bytes := PackedByteArray()
	var sk_bytes := PackedByteArray()
	var bd_bytes := PackedByteArray()
	var lp_bytes := PackedByteArray()
	sh_bytes.resize(bsz * bsz * 4)
	sk_bytes.resize(bsz * bsz * 4)
	bd_bytes.resize(bsz * bsz * 4)
	lp_bytes.resize(bsz * bsz * 4)
	var sh_ivory: Vector3 = style["shell_ivory"]
	var sh_blush: Vector3 = style["shell_blush"]
	var sh_irid: Vector3 = style["shell_irid"]
	var sk_blush: Vector3 = style["skin_blush"]
	var sk_shadow: Vector3 = style["skin_shadow_makeup"]
	var bd_warmth: Vector3 = style["body_warmth"]
	var bd_shimmer: Vector3 = style["body_shimmer"]
	var lp_deep: Vector3 = style["lip_deep"]
	var lp_soft: Vector3 = style["lip_soft"]
	idx = 0
	for y in range(bsz):
		var vv := 1.0 - (float(y) + 0.5) / float(bsz)
		var s_blush := clampf(1.0 - vv * 1.3, 0.0, 1.0) * 0.48
		var bd_shim := pow(clampf((0.18 - vv) / 0.18, 0.0, 1.0), 1.5) * 0.24
		var bd_warm := exp(-pow((vv - 0.74) / 0.18, 2.0)) * 0.12
		var bd_col := c_skin * (1.0 - bd_warm) + bd_warmth * bd_warm
		bd_col = bd_col * (1.0 - bd_shim) + bd_shimmer * bd_shim
		var lp_inner := clampf(1.0 - vv * 1.15, 0.0, 1.0)
		for x in range(bsz):
			var uu := (float(x) + 0.5) / float(bsz)
			# Shell
			var flute := sin(uu * PI * 18.0) * 0.032
			var irid_w := clampf(vv - 0.35, 0.0, 1.0) * 0.36 * (0.5 + 0.5 * cos(uu * TAU * 2.0))
			var scol := sh_ivory * (1.0 - s_blush - irid_w) + sh_blush * s_blush + sh_irid * irid_w
			_write_rgb(sh_bytes, idx, scol * (1.0 + flute))
			# Face skin
			var cheek := exp(-pow((absf(uu - 0.5) - 0.090) / 0.068, 2.0) - pow((vv - 0.44) / 0.080, 2.0))
			var nose := exp(-pow((uu - 0.5) / 0.030, 2.0) - pow((vv - 0.38) / 0.036, 2.0))
			var chin := exp(-pow((uu - 0.5) / 0.050, 2.0) - pow((vv - 0.14) / 0.055, 2.0))
			var eyesh := exp(-pow((absf(uu - 0.5) - 0.070) / 0.050, 2.0) - pow((vv - 0.545) / 0.038, 2.0))
			var bridge := exp(-pow((uu - 0.5) / 0.015, 2.0) - pow((vv - 0.46) / 0.075, 2.0))
			var wb := 0.30 * cheek + 0.18 * nose + 0.12 * chin
			var fcol := c_skin * (1.0 - wb) + sk_blush * wb
			fcol = fcol * (1.0 - 0.12 * eyesh) + sk_shadow * (0.12 * eyesh)
			fcol = fcol * (1.0 - 0.16 * bridge) + Vector3.ONE * (0.16 * bridge)
			_write_rgb(sk_bytes, idx, fcol)
			# Body skin
			_write_rgb(bd_bytes, idx, bd_col)
			# Lips
			var center := exp(-pow((uu - 0.5) / 0.32, 2.0))
			var gloss := exp(-pow((uu - 0.48) / 0.14, 2.0) - pow((vv - 0.42) / 0.12, 2.0)) * 0.24
			var lw := clampf(lp_inner * 0.74 * center + 0.20, 0.0, 1.0)
			var lcol := lp_deep * lw + lp_soft * (1.0 - lw) + Vector3(1.0, 0.94, 0.96) * (gloss * 0.35)
			_write_rgb(lp_bytes, idx, lcol)
			idx += 4
	out["shell_pearl"] = _to_tex(bsz, bsz, sh_bytes)
	out["skin"] = _to_tex(bsz, bsz, sk_bytes)
	out["body_skin"] = _to_tex(bsz, bsz, bd_bytes)
	out["lip"] = _to_tex(bsz, bsz, lp_bytes)

	_texture_cache.clear()
	_texture_cache[cid] = out
	return out

static func _ornament_mat(albedo: Color, metallic: float, roughness: float, emission_col := Color.BLACK, emission_energy := 0.0, alpha := 1.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(albedo.r, albedo.g, albedo.b, alpha)
	mat.metallic = metallic
	mat.roughness = roughness
	mat.rim_enabled = false
	mat.disable_receive_shadows = true
	if alpha < 0.99:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission_energy > 0.001:
		mat.emission_enabled = true
		mat.emission = emission_col
		mat.emission_energy_multiplier = emission_energy
	return mat

static func _attach_head_ornament(head_node: Node3D, cid: String) -> void:
	var old := head_node.get_node_or_null("CharacterOrnament")
	if is_instance_valid(old):
		head_node.remove_child(old)
		old.free()
	var root := Node3D.new()
	root.name = "CharacterOrnament"
	head_node.add_child(root)

	match cid:
		"moonlight_mermaid":
			# Floating Platinum Crescent Halo & Starlight Pearls above tiara
			var silver_mat := _ornament_mat(Color(0.92, 0.95, 1.0), 0.90, 0.16, Color(0.68, 0.64, 1.0), 0.28)
			var star_mat := _ornament_mat(Color(0.86, 0.82, 1.0), 0.25, 0.12, Color(0.76, 0.68, 1.0), 0.55)
			var halo := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = 0.022
			torus.outer_radius = 0.026
			torus.rings = 28
			torus.ring_segments = 12
			halo.mesh = torus
			halo.position = Vector3(0.0, 0.184, -0.056)
			halo.rotation_degrees = Vector3(78.0, 0.0, 0.0)
			halo.scale = Vector3(1.15, 1.0, 0.88)
			halo.material_override = silver_mat
			root.add_child(halo)
			for pt: Array in [[Vector3(0.0, 0.184, -0.056), 0.0058], [Vector3(-0.036, 0.170, -0.052), 0.0038], [Vector3(0.036, 0.170, -0.052), 0.0038]]:
				var orb := MeshInstance3D.new()
				var sph := SphereMesh.new()
				sph.radius = pt[1]
				sph.height = pt[1] * 2.0
				orb.mesh = sph
				orb.position = pt[0]
				orb.material_override = star_mat
				root.add_child(orb)
			var moon_light := OmniLight3D.new()
			moon_light.position = Vector3(0.0, 0.06, -0.34)
			moon_light.light_color = Color(0.76, 0.72, 1.0)
			moon_light.light_energy = 0.14
			moon_light.omni_range = 1.9
			root.add_child(moon_light)

		"abyss_mermaid":
			# Bioluminescent Abyssal Siren Filaments & Glowing Lure Pearls
			var stalk_mat := _ornament_mat(Color(0.14, 0.68, 0.82), 0.55, 0.22, Color(0.08, 0.85, 0.92), 0.38)
			var lure_mat := _ornament_mat(Color(0.45, 1.0, 0.94), 0.10, 0.10, Color(0.18, 1.0, 0.90), 1.15, 0.92)
			for side in [-1.0, 1.0]:
				for seg in range(5):
					var t := float(seg) / 4.0
					var node := MeshInstance3D.new()
					var cyl := CylinderMesh.new()
					var r0 := lerpf(0.0028, 0.0009, t)
					cyl.bottom_radius = r0
					cyl.top_radius = r0 * 0.78
					cyl.height = 0.020
					node.mesh = cyl
					node.position = Vector3(side * lerpf(0.022, 0.058, t), lerpf(0.148, 0.206, sin(t * PI * 0.5)), lerpf(-0.062, -0.044, t * t))
					node.rotation_degrees = Vector3(-18.0 + t * 28.0, 0.0, -side * (24.0 + t * 22.0))
					node.material_override = stalk_mat
					root.add_child(node)
				var lure := MeshInstance3D.new()
				var sph := SphereMesh.new()
				sph.radius = 0.0056
				sph.height = 0.0112
				lure.mesh = sph
				lure.position = Vector3(side * 0.062, 0.208, -0.042)
				lure.material_override = lure_mat
				root.add_child(lure)
			var center_lure := MeshInstance3D.new()
			var csph := SphereMesh.new()
			csph.radius = 0.0064
			csph.height = 0.0128
			center_lure.mesh = csph
			center_lure.position = Vector3(0.0, 0.178, -0.068)
			center_lure.material_override = lure_mat
			root.add_child(center_lure)
			var bio_light := OmniLight3D.new()
			bio_light.position = Vector3(0.0, 0.08, -0.34)
			bio_light.light_color = Color(0.16, 0.96, 0.92)
			bio_light.light_energy = 0.14
			bio_light.omni_range = 2.4
			root.add_child(bio_light)

		"golden_siren":
			# Radiant 7-Ray Sunburst Aureole Crown
			var sun_mat := _ornament_mat(Color(0.98, 0.84, 0.42), 0.90, 0.17, Color(1.0, 0.82, 0.34), 0.26)
			for i in range(-3, 4):
				var ang_deg := float(i) * 16.0
				var ray := MeshInstance3D.new()
				var cyl := CylinderMesh.new()
				cyl.bottom_radius = 0.0022
				cyl.top_radius = 0.0004
				var h := 0.034 - absf(float(i)) * 0.005
				cyl.height = h
				ray.mesh = cyl
				var rad := deg_to_rad(ang_deg)
				ray.position = Vector3(sin(rad) * 0.044, 0.154 + cos(rad) * 0.018, -0.056 + absf(float(i)) * 0.004)
				ray.rotation_degrees = Vector3(-10.0, 0.0, -ang_deg)
				ray.material_override = sun_mat
				root.add_child(ray)

		"sakura_mermaid":
			# Rose-Quartz Petal Diadem & Floating Sakura Pearls
			var petal_mat := _ornament_mat(Color(1.0, 0.76, 0.88), 0.18, 0.14, Color(1.0, 0.72, 0.88), 0.24, 0.72)
			var pearl_mat := _ornament_mat(Color(1.0, 0.94, 0.97), 0.22, 0.12, Color(1.0, 0.82, 0.92), 0.20)
			for side in [-1.0, 1.0]:
				var wing := MeshInstance3D.new()
				var prism := PrismMesh.new()
				prism.size = Vector3(0.026, 0.036, 0.004)
				wing.mesh = prism
				wing.position = Vector3(side * 0.040, 0.162, -0.054)
				wing.rotation_degrees = Vector3(-12.0, side * 18.0, -side * 32.0)
				wing.material_override = petal_mat
				root.add_child(wing)
				var p := MeshInstance3D.new()
				var sph := SphereMesh.new()
				sph.radius = 0.0044
				sph.height = 0.0088
				p.mesh = sph
				p.position = Vector3(side * 0.022, 0.168, -0.062)
				p.material_override = pearl_mat
				root.add_child(p)

	for mesh_child: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		mesh_child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
