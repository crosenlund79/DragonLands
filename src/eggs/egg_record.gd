class_name EggRecord
extends RefCounted
## One collected egg. It develops with the world clock wherever it is carried.

var id: String
var species_id: String
var origin_location_id: String
var acquired_at_minutes: float
var incubation_minutes: float
var seed: int  ## Fixes the hatchling's characteristics (no re-rolling by reloading).


static func create(p_id: String, p_species_id: String, location_id: String, now: float, p_seed: int) -> EggRecord:
	var egg := EggRecord.new()
	egg.id = p_id
	egg.species_id = p_species_id
	egg.origin_location_id = location_id
	egg.acquired_at_minutes = now
	egg.incubation_minutes = SpeciesCatalog.get_species(p_species_id).incubation_minutes
	egg.seed = p_seed
	return egg


func species() -> DragonSpecies:
	return SpeciesCatalog.get_species(species_id)


## Slack for floating-point clock sums (advancing by remaining_minutes() must make it ready).
const READY_EPSILON := 0.001


func progress(now: float) -> float:
	if incubation_minutes <= 0.0 or is_ready(now):
		return 1.0
	return clampf((now - acquired_at_minutes) / incubation_minutes, 0.0, 1.0)


func remaining_minutes(now: float) -> float:
	return 0.0 if is_ready(now) else acquired_at_minutes + incubation_minutes - now


func is_ready(now: float) -> bool:
	return now >= acquired_at_minutes + incubation_minutes - READY_EPSILON


func to_dict() -> Dictionary:
	return {
		"id": id,
		"species": species_id,
		"origin": origin_location_id,
		"acquired_at": acquired_at_minutes,
		"incubation": incubation_minutes,
		"seed": seed,
	}


static func from_dict(data: Dictionary) -> EggRecord:
	if not (data.get("id") is String) or data.id == "" or not SpeciesCatalog.has_species(str(data.get("species", ""))):
		return null
	var egg := EggRecord.new()
	egg.id = data.id
	egg.species_id = data.species
	egg.origin_location_id = str(data.get("origin", ""))
	egg.acquired_at_minutes = float(data.get("acquired_at", 0.0))
	egg.incubation_minutes = float(data.get("incubation", 0.0))
	egg.seed = int(data.get("seed", 0))
	return egg
