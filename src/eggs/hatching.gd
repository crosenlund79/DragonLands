class_name Hatching
extends RefCounted
## Turns a ready egg into a new DragonRecord. Characteristics come from the egg's
## seed, so the same egg always hatches the same hatchling (also after a reload).

const MAX_NAME_LENGTH := 18


static func hatch(egg: EggRecord, dragon_id: String, chosen_name: String, now: float, origin: String) -> DragonRecord:
	var species := egg.species()
	var rng := _rng(egg)
	var dragon := DragonRecord.new()
	dragon.id = dragon_id
	dragon.species_id = egg.species_id
	dragon.name = sanitize_name(chosen_name, suggest_name(egg, 0))
	dragon.born_at_minutes = now
	dragon.origin = origin
	dragon.traits = {
		"temperament": species.temperaments[rng.randi_range(0, species.temperaments.size() - 1)],
		"markings": species.markings[rng.randi_range(0, species.markings.size() - 1)],
	}
	return dragon


## A species-appropriate name; `attempt` cycles through alternatives.
static func suggest_name(egg: EggRecord, attempt: int) -> String:
	var names := egg.species().hatchling_names
	if names.is_empty():
		return egg.species().short_name
	return names[posmod(egg.seed + attempt, names.size())]


static func sanitize_name(text: String, fallback: String) -> String:
	var clean := " ".join(text.strip_edges().split(" ", false))
	clean = clean.left(MAX_NAME_LENGTH).strip_edges()
	return clean if clean != "" else fallback


static func _rng(egg: EggRecord) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = egg.seed
	return rng
