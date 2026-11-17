class_name StartingDragons
extends RefCounted
## Ember and Moss, the two adult dragons the adventurer starts with.


static func create_roster() -> DragonRoster:
	var roster := DragonRoster.new()
	roster.add(_make("ember", "Ember", "cinderwing", "dragons/ember", "Bold, restless", "Soot-dark wingtips"))
	roster.add(_make("moss", "Moss", "fernback", "dragons/moss", "Calm, curious", "Teal dapples"))
	return roster


static func _make(id: String, p_name: String, species_id: String, p_art: String, temperament: String,
		markings: String) -> DragonRecord:
	var r := DragonRecord.new()
	r.id = id
	r.name = p_name
	r.species_id = species_id
	r.born_at_minutes = -30.0 * WorldClock.MINUTES_PER_DAY  # Grown long before the story begins.
	r.origin = "Travelled with you from the start"
	r.art = p_art
	r.traits = {"temperament": temperament, "markings": markings}
	return r
