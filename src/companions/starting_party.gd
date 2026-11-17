class_name StartingParty
extends RefCounted
## The two original companion dragons of Prototype 001.


static func create() -> Array[DragonProfile]:
	var party: Array[DragonProfile] = [
		DragonProfile.new("ember", "Ember", "Cinderwing drake", "Fire", "Bold, restless",
			"dragons/ember", true, 150.0, -40.0, Color(0.93, 0.45, 0.2)),
		DragonProfile.new("moss", "Moss", "Fernback wyrm", "Grove", "Calm, curious",
			"dragons/moss", false, 56.0, 14.0, Color(0.42, 0.7, 0.42)),
	]
	return party
