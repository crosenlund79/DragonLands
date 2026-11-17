class_name DragonSpecies
extends RefCounted
## Shared definition of one dragon species. Individuals are DragonRecords that
## point at a species by id; nothing here changes per dragon.

enum Stage { HATCHLING, JUVENILE, ADULT }

const STAGE_NAMES := {Stage.HATCHLING: "Hatchling", Stage.JUVENILE: "Juvenile", Stage.ADULT: "Adult"}

var id: String
var name: String  ## e.g. "Cinderwing drake"
var short_name: String  ## e.g. "Cinderwing"
var element: String
var flies: bool  ## Juveniles and adults of this species fly; hatchlings always walk.
var accent: Color
var incubation_minutes: float
var juvenile_at_minutes: float  ## Age when a hatchling becomes a juvenile.
var adult_at_minutes: float
var egg_art: String
var cracked_egg_art: String
var hatchling_art: String
var adult_art: String
var base_colors: Dictionary  ## channel -> Vector3 HSV typical of the species.
var wild_color_spread: Vector3  ## +/- range of wild-born colours around base_colors.
var temperaments: PackedStringArray
var hatchling_names: PackedStringArray


static func from_dict(p_id: String, data: Dictionary) -> DragonSpecies:
	var s := DragonSpecies.new()
	s.id = p_id
	s.name = data.name
	s.short_name = data.short_name
	s.element = data.element
	s.flies = data.flies
	s.accent = data.accent
	s.incubation_minutes = data.incubation_hours * 60.0
	s.juvenile_at_minutes = data.juvenile_at_days * WorldClock.MINUTES_PER_DAY
	s.adult_at_minutes = data.adult_at_days * WorldClock.MINUTES_PER_DAY
	s.egg_art = data.get("egg_art", "")
	s.cracked_egg_art = data.get("cracked_egg_art", "")
	s.hatchling_art = data.hatchling_art
	s.adult_art = data.adult_art
	s.base_colors = data.colors
	s.wild_color_spread = data.wild_color_spread
	s.temperaments = PackedStringArray(data.temperaments)
	s.hatchling_names = PackedStringArray(data.get("hatchling_names", []))
	return s


func stage_at_age(age_minutes: float) -> Stage:
	if age_minutes < juvenile_at_minutes - WorldClock.EPSILON:
		return Stage.HATCHLING
	if age_minutes < adult_at_minutes - WorldClock.EPSILON:
		return Stage.JUVENILE
	return Stage.ADULT


func art_for(stage: Stage) -> String:
	return hatchling_art if stage == Stage.HATCHLING else adult_art


func flies_at(stage: Stage) -> bool:
	return flies and stage != Stage.HATCHLING
