class_name DragonRecord
extends RefCounted
## One individual dragon: a persistent identity that outlives scenes and saves.
## Its Genome (colours, markings, traits) comes from its egg and never changes.

var id: String  ## Unique within a save, never reused.
var name: String
var species_id: String
var born_at_minutes: float  ## World time of hatching (negative = before the story began).
var origin: String  ## Human-readable provenance.
var art: String = ""  ## Optional individual art; "" = species art for the growth stage.
const NEVER := -1.0e9

var traits: Dictionary = {}  ## Personality, e.g. {"temperament": "Bold"} (not inherited).
var genome: Genome  ## Heritable makeup; null only while migrating an old save.
var parent_ids: PackedStringArray = PackedStringArray()  ## Empty for wild-born dragons.
var generation: int = 0  ## 0 = wild stock; offspring = highest parent generation + 1.
var mutations: PackedStringArray = PackedStringArray()  ## Reserved: always empty for now.
var last_bred_at: float = NEVER  ## World time this dragon last bred (for its cooldown).
var inheritance_notes: PackedStringArray = PackedStringArray()  ## How its genes were inherited.


func species() -> DragonSpecies:
	return SpeciesCatalog.get_species(species_id)


func age_minutes(now: float) -> float:
	return maxf(0.0, now - born_at_minutes)


func stage(now: float) -> DragonSpecies.Stage:
	return species().stage_at_age(age_minutes(now))


## Logical asset name for this dragon at its current growth stage.
func art_at(now: float) -> String:
	return art if art != "" else species().art_for(stage(now))


func to_dict() -> Dictionary:
	return {
		"id": id,
		"name": name,
		"species": species_id,
		"born_at": born_at_minutes,
		"origin": origin,
		"art": art,
		"traits": traits.duplicate(true),
		"genome": genome.to_dict() if genome != null else {},
		"parents": Array(parent_ids),
		"generation": generation,
		"mutations": Array(mutations),
		"bred_at": last_bred_at,
		"notes": Array(inheritance_notes),
	}


## Rebuilds a record from to_dict() output; null if required data is missing or unknown.
static func from_dict(data: Dictionary) -> DragonRecord:
	if not (data.get("id") is String) or data.id == "" or not SpeciesCatalog.has_species(str(data.get("species", ""))):
		return null
	var r := DragonRecord.new()
	r.id = data.id
	r.name = str(data.get("name", "Unnamed"))
	r.species_id = data.species
	r.born_at_minutes = float(data.get("born_at", 0.0))
	r.origin = str(data.get("origin", ""))
	r.art = str(data.get("art", ""))
	r.traits = (data.get("traits", {}) as Dictionary).duplicate(true)
	var genome_data: Variant = data.get("genome", {})
	r.genome = Genome.from_dict(genome_data) if genome_data is Dictionary else null
	r.parent_ids = PackedStringArray(data.get("parents", []))
	r.generation = int(data.get("generation", 0))
	r.mutations = PackedStringArray(data.get("mutations", []))
	r.last_bred_at = float(data.get("bred_at", NEVER))
	r.inheritance_notes = PackedStringArray(data.get("notes", []))
	return r
