class_name DragonRecord
extends RefCounted
## One individual dragon: a persistent identity that outlives scenes and saves.
## Fields marked "reserved" give future genetics/breeding a home without
## implementing any inheritance now.

var id: String  ## Unique within a save, never reused.
var name: String
var species_id: String
var born_at_minutes: float  ## World time of hatching (negative = before the story began).
var origin: String  ## Human-readable provenance.
var art: String = ""  ## Optional individual art; "" = species art for the growth stage.
var traits: Dictionary = {}  ## Expressed characteristics, e.g. {"temperament": "Bold"}.
var genome: Dictionary = {}  ## Reserved: heritable data, empty until genetics exist (saved as JSON: numbers load as floats).
var parent_ids: PackedStringArray = PackedStringArray()  ## Reserved: empty for wild-born dragons.
var generation: int = 0  ## Reserved: 0 = wild stock.
var mutations: PackedStringArray = PackedStringArray()  ## Reserved: always empty for now.


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
		"genome": genome.duplicate(true),
		"parents": Array(parent_ids),
		"generation": generation,
		"mutations": Array(mutations),
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
	r.genome = (data.get("genome", {}) as Dictionary).duplicate(true)
	r.parent_ids = PackedStringArray(data.get("parents", []))
	r.generation = int(data.get("generation", 0))
	r.mutations = PackedStringArray(data.get("mutations", []))
	return r
