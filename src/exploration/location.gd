class_name Location
extends RefCounted
## A discoverable place on the overworld. Visiting its cell opens its encounter.

enum Kind { CAMP, LANDMARK, LOOKOUT, DRAGON_NEST }

var id: String
var name: String
var cell: Vector2i
var kind: Kind
var art: String  ## Logical asset name of the map landmark sprite.
var encounter: Encounter


func _init(p_id: String, p_name: String, p_cell: Vector2i, p_kind: Kind, p_art: String,
		p_encounter: Encounter) -> void:
	id = p_id
	name = p_name
	cell = p_cell
	kind = p_kind
	art = p_art
	encounter = p_encounter
