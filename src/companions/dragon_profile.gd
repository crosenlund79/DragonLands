class_name DragonProfile
extends RefCounted
## Identity of one individual dragon travelling with the adventurer.
## Deliberately minimal: future genetics/breeding data attaches to this record.

var id: String
var name: String
var species: String
var element: String
var temperament: String
var art: String  ## Logical asset name for AssetResolver.
var flies: bool
var follow_distance: float  ## Pixels behind the adventurer along the walked trail.
var side_offset: float  ## Pixels to the right (+) / left (-) of the trail, so companions flank rather than stack.
var accent: Color


func _init(p_id: String, p_name: String, p_species: String, p_element: String,
		p_temperament: String, p_art: String, p_flies: bool, p_follow_distance: float,
		p_side_offset: float, p_accent: Color) -> void:
	id = p_id
	name = p_name
	species = p_species
	element = p_element
	temperament = p_temperament
	art = p_art
	flies = p_flies
	follow_distance = p_follow_distance
	side_offset = p_side_offset
	accent = p_accent
