class_name Hatching
extends RefCounted
## Turns a ready egg into a new DragonRecord. Genes come from the egg (decided when it was
## laid or found); personality comes from the egg's seed. Nothing is re-rolled on reload.

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
	dragon.traits = {"temperament": species.temperaments[rng.randi_range(0, species.temperaments.size() - 1)]}
	dragon.genome = Genome.from_dict(egg.genome.to_dict())
	dragon.parent_ids = egg.parent_ids.duplicate()
	dragon.generation = egg.generation
	dragon.inheritance_notes = egg.notes.duplicate()
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
