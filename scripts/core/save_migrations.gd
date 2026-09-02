class_name SaveMigrations
extends RefCounted

const SUPPORTED_START_VERSIONS := [21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 33, 34, 35]

static func normalize(source: Dictionary, current_version: int) -> Dictionary:
	var payload := source.duplicate(true)
	var version := int(payload.get("save_version", 0))
	if version not in SUPPORTED_START_VERSIONS or version > current_version: return {}
	while version < current_version:
		payload = _migrate_one(payload, version)
		if payload.is_empty(): return {}
		version += 1
		payload["save_version"] = version
	return payload

static func _migrate_one(payload: Dictionary, from_version: int) -> Dictionary:
	match from_version:
		21: return _v21_to_v22(payload)
		22: return _v22_to_v23(payload)
		23: return _v23_to_v24(payload)
		24: return _v24_to_v25(payload)
		25: return _v25_to_v26(payload)
		26: return _v26_to_v27(payload)
		27: return _v27_to_v28(payload)
		28: return _v28_to_v29(payload)
		29: return _v29_to_v30(payload)
		30: return _v30_to_v31(payload)
		31: return _v31_to_v32(payload)
		32: return _v32_to_v33(payload)
		33: return _v33_to_v34(payload)
		34: return _v34_to_v35(payload)
		_: return {}

# Historical semantic migrations still run during hydration because they need the
# generated world and loadout. These explicit steps own schema normalization only.
static func _copy(payload: Dictionary) -> Dictionary: return payload.duplicate(true)
static func _v21_to_v22(payload: Dictionary) -> Dictionary: return _copy(payload)
static func _v22_to_v23(payload: Dictionary) -> Dictionary: return _copy(payload)
static func _v23_to_v24(payload: Dictionary) -> Dictionary: return _copy(payload)
static func _v24_to_v25(payload: Dictionary) -> Dictionary: return _copy(payload)
static func _v25_to_v26(payload: Dictionary) -> Dictionary: return _copy(payload)
static func _v26_to_v27(payload: Dictionary) -> Dictionary: return _copy(payload)
static func _v27_to_v28(payload: Dictionary) -> Dictionary: return _copy(payload)
static func _v28_to_v29(payload: Dictionary) -> Dictionary: return _copy(payload)
static func _v29_to_v30(payload: Dictionary) -> Dictionary: return _copy(payload)
static func _v30_to_v31(payload: Dictionary) -> Dictionary: return _copy(payload)
static func _v31_to_v32(payload: Dictionary) -> Dictionary: return _copy(payload)
static func _v32_to_v33(payload: Dictionary) -> Dictionary: return _copy(payload)

static func _v33_to_v34(payload: Dictionary) -> Dictionary:
	var result := _copy(payload)
	if not result.has("cooldowns"):
		result["cooldowns"] = {
			"dodge":{"remaining":float(result.get("dodge_cooldown", 0.0)), "maximum":4.0},
			"block":{"remaining":float(result.get("block_cooldown", 0.0)), "maximum":3.5},
			"endure":{"remaining":float(result.get("endure_cooldown", 0.0)), "maximum":4.5},
			"skill":{"remaining":float(result.get("skill_cooldown", 0.0)), "maximum":float(result.get("skill_cooldown_max", 6.5))},
			"rally":{"remaining":float(result.get("rally_cooldown", 0.0)), "maximum":12.0},
			"advance":{"remaining":float(result.get("advance_cooldown", 0.0)), "maximum":float(result.get("advance_cooldown_max", 6.0))},
			"main_ability":{"remaining":float(result.get("main_ability_cooldown", 0.0)), "maximum":float(result.get("main_ability_cooldown_max", 12.0))},
			"subclass_ability":{"remaining":float(result.get("subclass_ability_cooldown", 0.0)), "maximum":float(result.get("subclass_ability_cooldown_max", 8.0))},
			"weapon_sequence":{"remaining":float(result.get("weapon_sequence_cooldown", 0.0)), "maximum":0.0001},
			"spell":{"remaining":float(result.get("spell_cooldown", 0.0)), "maximum":float(result.get("spell_cooldown_max", 8.0))},
		}
	return result

static func _v34_to_v35(payload: Dictionary) -> Dictionary:
	var result := _copy(payload)
	var migrated_projectiles: Array = []
	for value in Array(result.get("projectiles", [])):
		var projectile := Dictionary(value).duplicate(true)
		if not projectile.has("misdirected"): projectile["misdirected"] = false
		migrated_projectiles.append(projectile)
	result["projectiles"] = migrated_projectiles
	return result

static func validate_current(payload: Dictionary, current_version: int) -> PackedStringArray:
	var errors := PackedStringArray()
	if int(payload.get("save_version", -1)) != current_version: errors.append("Save version is not current")
	for key in ["run_seed", "mode_id", "player_pos", "enemies", "projectiles", "hazards", "barriers", "effects", "cooldowns", "rng_state"]:
		if not payload.has(key): errors.append("Current save is missing %s" % key)
	for key in ["enemies", "projectiles", "hazards", "barriers", "effects"]:
		if payload.has(key) and not payload[key] is Array: errors.append("Save field %s must be an Array" % key)
	if payload.has("cooldowns") and not payload["cooldowns"] is Dictionary: errors.append("Save cooldowns must be a Dictionary")
	return errors
