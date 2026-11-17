class_name EncounterChoice
extends RefCounted
## One option in an encounter panel and its (deliberately simple) consequences.

var id: String
var label: String
var outcome: String  ## Text shown after choosing; "" closes the panel immediately.
var minutes: float  ## In-game time the choice takes.
var reveal_radius: float  ## > 0 explores fog around the location.


func _init(p_id: String, p_label: String, p_outcome: String = "", p_minutes: float = 0.0,
		p_reveal_radius: float = 0.0) -> void:
	id = p_id
	label = p_label
	outcome = p_outcome
	minutes = p_minutes
	reveal_radius = p_reveal_radius
