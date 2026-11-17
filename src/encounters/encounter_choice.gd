class_name EncounterChoice
extends RefCounted
## One option in an encounter panel and its (deliberately simple) consequences.

## Special effects a choice can trigger; most choices have none.
const ACTION_NONE := ""
const ACTION_TAKE_EGG := "take_egg"  ## Gain one egg of `species` (once per location).
const ACTION_WARM_EGG := "warm_egg"  ## Wait until the soonest egg is ready, then hatch it.
const ACTION_HATCH_EGG := "hatch_egg"  ## Hatch a ready egg.

var id: String
var label: String
var outcome: String  ## Text shown after choosing; "" closes the panel immediately.
var minutes: float  ## In-game time the choice takes.
var reveal_radius: float  ## > 0 explores fog around the location.
var action: String
var species: String  ## Species id for ACTION_TAKE_EGG.


func _init(p_id: String, p_label: String, p_outcome: String = "", p_minutes: float = 0.0,
		p_reveal_radius: float = 0.0, p_action: String = ACTION_NONE, p_species: String = "") -> void:
	id = p_id
	label = p_label
	outcome = p_outcome
	minutes = p_minutes
	reveal_radius = p_reveal_radius
	action = p_action
	species = p_species


func with_label(new_label: String) -> EncounterChoice:
	return EncounterChoice.new(id, new_label, outcome, minutes, reveal_radius, action, species)
