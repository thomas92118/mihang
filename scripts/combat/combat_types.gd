extends RefCounted

const STATUS_ELECTRO := "electro"
const STATUS_RUPTURE := "rupture"
const STATUS_STASIS := "stasis"
const STATUS_RESONANCE := "resonance"

const ALL_STATUSES: Array[String] = [
	STATUS_ELECTRO,
	STATUS_RUPTURE,
	STATUS_STASIS,
	STATUS_RESONANCE,
]

const REACTION_SUPERCONDUCT := "superconduct"
const REACTION_IMPLOSION := "implosion"
const REACTION_OVERCHARGE := "overcharge"
const REACTION_CRYSTAL_FREEZE := "crystal_freeze"

const ALL_REACTIONS: Array[String] = [
	REACTION_SUPERCONDUCT,
	REACTION_IMPLOSION,
	REACTION_OVERCHARGE,
	REACTION_CRYSTAL_FREEZE,
]

const STATUS_NAMES := {
	STATUS_ELECTRO: "感电",
	STATUS_RUPTURE: "裂伤",
	STATUS_STASIS: "静滞",
	STATUS_RESONANCE: "声波",
}

const REACTION_NAMES := {
	REACTION_SUPERCONDUCT: "超导裂解",
	REACTION_IMPLOSION: "深压内爆",
	REACTION_OVERCHARGE: "高压电灼",
	REACTION_CRYSTAL_FREEZE: "晶振冻结",
}

const STATUS_COLORS := {
	STATUS_ELECTRO: Color(0.24, 0.86, 1.0),
	STATUS_RUPTURE: Color(0.96, 0.28, 0.34),
	STATUS_STASIS: Color(0.56, 0.84, 1.0),
	STATUS_RESONANCE: Color(1.0, 0.80, 0.28),
}

const REACTION_COLORS := {
	REACTION_SUPERCONDUCT: Color(0.70, 0.58, 1.0),
	REACTION_IMPLOSION: Color(1.0, 0.42, 0.22),
	REACTION_OVERCHARGE: Color(1.0, 0.90, 0.34),
	REACTION_CRYSTAL_FREEZE: Color(0.42, 0.98, 0.96),
}

const PET_ROLE_STRIKER := "striker"
const PET_ROLE_CONTROL := "control"
const PET_ROLE_TANK := "tank"
const PET_ROLE_SUPPORT := "support"

const PET_ROLE_NAMES := {
	PET_ROLE_STRIKER: "突袭",
	PET_ROLE_CONTROL: "控场",
	PET_ROLE_TANK: "承伤",
	PET_ROLE_SUPPORT: "支援",
}

const VALID_ATTACK_KINDS: Array[String] = [
	"light",
	"heavy",
	"weapon_art",
	"tactical",
	"ultimate",
	"pet",
	"torpedo",
	"execute",
]


static func is_valid_status(status_type: String) -> bool:
	return STATUS_NAMES.has(status_type)


static func get_status_name(status_type: String) -> String:
	return String(STATUS_NAMES.get(status_type, status_type))


static func get_reaction_name(reaction_id: String) -> String:
	return String(REACTION_NAMES.get(reaction_id, reaction_id))


static func get_status_color(status_type: String) -> Color:
	return STATUS_COLORS.get(status_type, Color.WHITE)


static func get_reaction_color(reaction_id: String) -> Color:
	return REACTION_COLORS.get(reaction_id, Color.WHITE)


static func get_pet_role(species_kind: String) -> String:
	var key := species_kind.strip_edges().to_lower()
	match key:
		"predator", "fish_predator", "shark", "sea_wolf":
			return PET_ROLE_STRIKER
		"abyss", "fish_abyss", "angler", "squid", "sea_spider", "water_dragon", "boss_water_dragon", "kraken", "boss_kraken", "boss":
			return PET_ROLE_CONTROL
		"sea_turtle", "crab", "colossus_turtle", "boss_colossus_turtle":
			return PET_ROLE_TANK
		"seal", "manta_ray", "flying_fish", "boss_flying_fish":
			return PET_ROLE_SUPPORT
	if key.contains("shark") or key.contains("wolf") or key.contains("predator"):
		return PET_ROLE_STRIKER
	if key.contains("turtle") or key.contains("crab"):
		return PET_ROLE_TANK
	if key.contains("seal") or key.contains("manta") or key.contains("ray") or key.contains("flying"):
		return PET_ROLE_SUPPORT
	if key.contains("angler") or key.contains("squid") or key.contains("spider") or key.contains("dragon") or key.contains("kraken") or key.contains("abyss"):
		return PET_ROLE_CONTROL
	return PET_ROLE_STRIKER


static func make_damage_packet(params: Dictionary = {}) -> Dictionary:
	var raw_kind := String(params.get("attack_kind", "light"))
	var attack_kind := raw_kind if VALID_ATTACK_KINDS.has(raw_kind) else "light"
	var raw_status := String(params.get("status_type", ""))
	var status_type := raw_status if is_valid_status(raw_status) else ""
	var raw_impulse: Variant = params.get("impulse", Vector3.ZERO)
	var impulse: Vector3 = raw_impulse if raw_impulse is Vector3 else Vector3.ZERO
	var raw_pos: Variant = params.get("world_pos", Vector3.ZERO)
	var world_pos: Vector3 = raw_pos if raw_pos is Vector3 else Vector3.ZERO
	var crit_chance := clampf(float(params.get("crit_chance", 0.08)), 0.0, 1.0)
	if bool(params.get("guaranteed_crit", false)):
		crit_chance = 1.0
	return {
		"source_weapon": String(params.get("source_weapon", "knife")),
		"attack_kind": attack_kind,
		"base_damage": maxf(0.0, float(params.get("base_damage", 0.0))),
		"poise_damage": maxf(0.0, float(params.get("poise_damage", 0.0))),
		"status_type": status_type,
		"status_amount": maxf(0.0, float(params.get("status_amount", 0.0))) if status_type != "" else 0.0,
		"crit_chance": crit_chance,
		"crit_mult": maxf(1.0, float(params.get("crit_mult", 1.5))),
		"weakpoint_hit": bool(params.get("weakpoint_hit", false)),
		"armor_pierce": clampf(float(params.get("armor_pierce", 0.0)), 0.0, 1.0),
		"non_lethal_stun": bool(params.get("non_lethal_stun", false)),
		"star_bias": clampi(int(params.get("star_bias", 2)), 1, 3),
		"impulse": impulse,
		"world_pos": world_pos,
	}
