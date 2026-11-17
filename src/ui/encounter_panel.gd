class_name EncounterPanel
extends Control
## Modal panel for a visited location: art, description and choices, then the outcome.

signal choice_made(location: Location, choice: EncounterChoice)
signal closed

var _location: Location
var _offered: Array[EncounterChoice] = []
var _title: Label
var _art: TextureRect
var _body: Label
var _choices: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.05, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := PanelContainer.new()
	var style := UiStyle.panel(0.95)
	style.set_content_margin_all(20)
	box.add_theme_stylebox_override("panel", style)
	center.add_child(box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.custom_minimum_size = Vector2(620, 0)
	box.add_child(col)
	_title = UiStyle.label("", 28, Color(1.0, 0.88, 0.6))
	col.add_child(_title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	col.add_child(row)
	_art = TextureRect.new()
	_art.custom_minimum_size = Vector2(200, 180)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_art)
	_body = UiStyle.label("", 17)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(380, 0)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_body)
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 8)
	col.add_child(_choices)


## Shows `location` with its current description and choices (both supplied by the session).
func open(location: Location, art: Texture2D, text: String, choices: Array[EncounterChoice]) -> void:
	_location = location
	_offered = choices
	_title.text = location.encounter.title
	_body.text = text
	_art.texture = art
	_clear_choices()
	for choice in choices:
		var button := UiStyle.button(choice.label)
		button.pressed.connect(_on_choice.bind(choice))
		_choices.add_child(button)
	visible = true


func is_open() -> bool:
	return visible


func offered_choice_ids() -> Array:
	return _offered.map(func(c: EncounterChoice) -> String: return c.id)


## Picks an offered choice by id (as a click would); ignored if not offered.
func choose(choice_id: String) -> void:
	for choice in _offered:
		if choice.id == choice_id:
			_on_choice(choice)
			return


func _on_choice(choice: EncounterChoice) -> void:
	choice_made.emit(_location, choice)


## Shows the result of a choice; an empty outcome closes the panel.
func show_outcome(text: String) -> void:
	if text == "":
		close()
		return
	_body.text = text
	_offered = []
	_clear_choices()
	var button := UiStyle.button("Continue")
	button.pressed.connect(close)
	_choices.add_child(button)


func close() -> void:
	if not visible:
		return
	visible = false
	_location = null
	_offered = []
	closed.emit()


func _clear_choices() -> void:
	for child in _choices.get_children():
		_choices.remove_child(child)
		child.queue_free()
