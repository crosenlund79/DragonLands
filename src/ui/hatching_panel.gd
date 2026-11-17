class_name HatchingPanel
extends Control
## Modal hatching moment: animation, naming the hatchling, then its characteristics.

signal name_confirmed(egg_id: String, chosen_name: String)
signal finished

var _egg: EggRecord
var _name_attempt := 0
var _naming := false
var _title: Label
var _stage: HatchStage
var _name_row: HBoxContainer
var _name_edit: LineEdit
var _confirm: Button
var _details: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.05, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := PanelContainer.new()
	var style := UiStyle.panel(0.96)
	style.set_content_margin_all(22)
	box.add_theme_stylebox_override("panel", style)
	center.add_child(box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.custom_minimum_size = Vector2(560, 0)
	box.add_child(col)
	_title = UiStyle.label("", 28, Color(1.0, 0.88, 0.6))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_title)
	_stage = HatchStage.new()
	_stage.custom_minimum_size = Vector2(560, 290)
	_stage.hatched.connect(_on_hatched)
	col.add_child(_stage)

	_name_row = HBoxContainer.new()
	_name_row.add_theme_constant_override("separation", 8)
	_name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_name_row.add_child(UiStyle.label("Name:", 18))
	_name_edit = LineEdit.new()
	_name_edit.max_length = Hatching.MAX_NAME_LENGTH
	_name_edit.custom_minimum_size = Vector2(220, 0)
	_name_edit.add_theme_font_size_override("font_size", 18)
	var field := UiStyle.panel(1.0)
	field.bg_color = Color(0.2, 0.16, 0.11)
	field.set_content_margin_all(6)
	_name_edit.add_theme_stylebox_override("normal", field)
	_name_edit.add_theme_stylebox_override("focus", field)
	_name_edit.add_theme_stylebox_override("read_only", field)
	_name_edit.add_theme_color_override("font_color", UiStyle.TEXT)
	_name_edit.add_theme_color_override("selection_color", Color(0.75, 0.45, 0.2, 0.6))
	_name_edit.text_changed.connect(func(_t: String) -> void: _update_confirm())
	_name_edit.text_submitted.connect(func(_t: String) -> void: _confirm_name())
	_name_row.add_child(_name_edit)
	var another := UiStyle.button("Another name")
	another.pressed.connect(_suggest_another)
	_name_row.add_child(another)
	col.add_child(_name_row)
	_confirm = UiStyle.button("")
	_confirm.pressed.connect(_confirm_name)
	col.add_child(_confirm)

	_details = VBoxContainer.new()
	_details.add_theme_constant_override("separation", 6)
	col.add_child(_details)


func open(egg: EggRecord, egg_tex: Texture2D, cracked_tex: Texture2D, hatchling_tex: Texture2D) -> void:
	_egg = egg
	_name_attempt = 0
	_title.text = "Something stirs inside the egg..."
	_naming = false
	# Keep the naming controls in the layout (invisible) so the panel does not jump.
	for c in [_name_row, _confirm]:
		c.visible = true
		c.modulate.a = 0.0
	_name_edit.editable = false
	_clear(_details)
	_details.visible = false
	_name_edit.text = Hatching.suggest_name(egg, 0)
	_update_confirm()  # Real text now, so the reserved row has its final height.
	_stage.play(egg_tex, cracked_tex, hatchling_tex)
	visible = true


func is_open() -> bool:
	return visible


func is_naming() -> bool:
	return visible and _naming


## Skips the animation (tests / impatient players).
func skip_animation() -> void:
	_stage.finish()


## Sets the name field and confirms it, as a player would.
func submit_name(text: String) -> void:
	_name_edit.text = text
	_confirm_name()


func _on_hatched() -> void:
	_title.text = "A %s hatchling!" % _egg.species().short_name
	_naming = true
	_name_edit.editable = true
	var fade := create_tween().set_parallel()
	for c in [_name_row, _confirm]:
		fade.tween_property(c, "modulate:a", 1.0, 0.4).set_delay(0.3)
	_update_confirm()
	_name_edit.grab_focus.call_deferred()
	_name_edit.select_all.call_deferred()


func _suggest_another() -> void:
	_name_attempt += 1
	_name_edit.text = Hatching.suggest_name(_egg, _name_attempt)
	_update_confirm()


func _update_confirm() -> void:
	_confirm.text = "Welcome, %s!" % Hatching.sanitize_name(_name_edit.text, Hatching.suggest_name(_egg, _name_attempt))


func _confirm_name() -> void:
	if not is_naming():
		return
	name_confirmed.emit(_egg.id, Hatching.sanitize_name(_name_edit.text, Hatching.suggest_name(_egg, _name_attempt)))


## Shows the new dragon's characteristics after the session created it.
func show_dragon(dragon: DragonRecord, now: float) -> void:
	var species := dragon.species()
	_title.text = dragon.name
	_naming = false
	_name_row.visible = false
	_confirm.visible = false
	_clear(_details)
	_details.visible = true
	var lines := [
		["Species", species.name],
		["Element", species.element],
		["Temperament", str(dragon.traits.get("temperament", "-"))],
		["Markings", str(dragon.traits.get("markings", "-"))],
		["Growth", "%s (hatched %s)" % [DragonSpecies.STAGE_NAMES[dragon.stage(now)], _when(dragon.born_at_minutes)]],
		["Origin", dragon.origin],
	]
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 4)
	for line in lines:
		grid.add_child(UiStyle.label(line[0], 15, UiStyle.GOLD))
		var value := UiStyle.label(line[1], 16)
		value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		value.custom_minimum_size = Vector2(400, 0)
		grid.add_child(value)
	_details.add_child(grid)
	var done := UiStyle.button("%s joins your travelling dragons" % dragon.name)
	done.pressed.connect(close)
	_details.add_child(done)


func close() -> void:
	if not visible:
		return
	visible = false
	_egg = null
	finished.emit()


func _when(minutes: float) -> String:
	var clock := WorldClock.new(minutes)
	return "Day %d, %s" % [clock.day(), clock.clock_text()]


func _clear(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
