class_name SpeciesCatalog
extends RefCounted
## The species that exist in the game so far. Prototype 002 adds no new species:
## the Cinderwing egg belongs to Ember's species.

const DATA := {
	"cinderwing": {
		"name": "Cinderwing drake",
		"short_name": "Cinderwing",
		"element": "Fire",
		"flies": true,
		"accent": Color(0.93, 0.45, 0.2),
		"incubation_hours": 12.0,
		"juvenile_at_days": 1.0,
		"adult_at_days": 4.0,
		"egg_art": "eggs/cinderwing",
		"cracked_egg_art": "eggs/cinderwing_cracked",
		"hatchling_art": "dragons/cinderwing_hatchling",
		"adult_art": "dragons/ember",
		"temperaments": ["Bold", "Curious", "Playful", "Watchful", "Stubborn", "Gentle"],
		"markings": ["Ash-speckled back", "Gold-rimmed scales", "Soot-dark wingtips", "Bright ember belly", "Flame-tipped tail"],
		"hatchling_names": ["Cinder", "Flicker", "Kindle", "Pyra", "Smoulder", "Tinder", "Sparrow", "Ashby", "Fennel", "Blaze"],
	},
	"fernback": {
		"name": "Fernback wyrm",
		"short_name": "Fernback",
		"element": "Grove",
		"flies": false,
		"accent": Color(0.42, 0.7, 0.42),
		"incubation_hours": 16.0,
		"juvenile_at_days": 1.5,
		"adult_at_days": 5.0,
		"hatchling_art": "dragons/moss",
		"adult_art": "dragons/moss",
		"temperaments": ["Calm", "Curious", "Shy", "Patient", "Cheerful"],
		"markings": ["Teal dapples", "Curled frond crest", "Mossy flanks", "Bark-brown horns"],
	},
}

static var _cache: Dictionary = {}


static func get_species(id: String) -> DragonSpecies:
	if not DATA.has(id):
		return null
	if not _cache.has(id):
		_cache[id] = DragonSpecies.from_dict(id, DATA[id])
	return _cache[id]


static func has_species(id: String) -> bool:
	return DATA.has(id)
