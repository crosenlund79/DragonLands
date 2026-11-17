class_name StartingDragons
extends RefCounted
## Ember and Moss, the two adult dragons the adventurer starts with. Their genomes use
## their species' template colours, so recolouring reproduces the original art.


static func create_roster() -> DragonRoster:
	var roster := DragonRoster.new()
	roster.add(_make("ember", "Ember", "cinderwing", "dragons/ember", "Bold, restless"))
	roster.add(_make("moss", "Moss", "fernback", "dragons/moss", "Calm, curious"))
	return roster


## The fixed genome of a starting dragon (also used to upgrade pre-genetics saves); null otherwise.
static func canonical_genome(id: String) -> Genome:
	match id:
		"ember":
			return Genome.create(SpeciesCatalog.get_species("cinderwing").base_colors, "plain", 0.5,
				{"keen_sight": 2, "strong_wings": 1})
		"moss":
			return Genome.create(SpeciesCatalog.get_species("fernback").base_colors, "plain", 0.5,
				{"thick_scales": 2, "steady_heart": 1})
	return null


static func _make(id: String, p_name: String, species_id: String, p_art: String, temperament: String) -> DragonRecord:
	var r := DragonRecord.new()
	r.id = id
	r.name = p_name
	r.species_id = species_id
	r.born_at_minutes = -30.0 * WorldClock.MINUTES_PER_DAY  # Grown long before the story begins.
	r.origin = "Travelled with you from the start"
	r.art = p_art
	r.traits = {"temperament": temperament}
	r.genome = canonical_genome(id)
	return r
