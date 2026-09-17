class_name RuntimeSchema
extends RefCounted

const REQUIRED := {
	"actor": ["id", "kind", "faction", "pos", "radius", "hp", "max_hp", "action"],
	"action": ["kind", "elapsed", "duration"],
	"projectile": ["kind", "pos", "vel", "radius", "damage", "source_id", "layer", "misdirected"],
	"hazard": ["kind", "pos", "radius", "elapsed", "duration", "source_id", "layer"],
	"barrier": ["pos", "axis", "half_length", "thickness", "hp", "source_id", "layer"],
	"effect": ["kind", "pos", "elapsed", "duration", "layer"],
	"pickup": ["id", "item_id", "pos", "layer"],
}

static func construct(schema: String, values: Dictionary) -> Dictionary:
	var result := values.duplicate(true)
	for error in validate(schema, result): push_error(String(error))
	return result

static func validate(schema: String, value: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()
	if not REQUIRED.has(schema):
		errors.append("Unknown runtime schema: %s" % schema)
		return errors
	for field in Array(REQUIRED[schema]):
		if not value.has(field): errors.append("%s is missing required field %s" % [schema, field])
	if schema == "projectile" and String(value.get("elevation_profile", "flat")) == "arc" and not value.has("arc_span"):
		errors.append("arcing projectile is missing required field arc_span")
	return errors

static func validate_registry() -> PackedStringArray:
	var errors := PackedStringArray()
	for schema in REQUIRED:
		if Array(REQUIRED[schema]).is_empty(): errors.append("Runtime schema %s has no required fields" % schema)
	return errors
