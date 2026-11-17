class_name Encounter
extends RefCounted
## Content of an encounter panel: title, art, description and choices.

var title: String
var text: String
var art: String  ## Logical asset name for AssetResolver.
var choices: Array[EncounterChoice] = []


func _init(p_title: String, p_text: String, p_art: String, p_choices: Array[EncounterChoice]) -> void:
	title = p_title
	text = p_text
	art = p_art
	choices = p_choices


func get_choice(choice_id: String) -> EncounterChoice:
	for choice in choices:
		if choice.id == choice_id:
			return choice
	return null
