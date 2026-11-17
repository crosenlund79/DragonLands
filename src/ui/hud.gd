class_name Hud
extends Control
## Minimal HUD: world time, current place, carried eggs, travelling dragons,
## save/load buttons, controls hint and toasts.

signal save_requested
signal load_requested
signal collection_requested

var _session: OverworldSession
var _assets: AssetResolver
var _time_label: Label
var _phase_label: Label
var _region_label: Label
var _area_label: Label
var _party_col: VBoxContainer
var _eggs_box: PanelContainer
var _eggs_col: VBoxContainer
var _egg_rows: Dictionary = {}  # egg id -> {bar: ProgressBar, status: Label}
var _party_stages: Dictionary = {}  # dragon id -> stage shown
var _toast: PanelContainer
var _toast_label: Label
var _toast_tween: Tween


func setup(session: OverworldSession, assets: AssetResolver) -> void:
	_session = session
	_assets = assets
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# Time (top-left)
	var time_col := VBoxContainer.new()
	time_col.add_theme_constant_override("separation", 0)
	_time_label = UiStyle.label("", 26)
	_phase_label = UiStyle.label("", 15, UiStyle.MUTED)
	time_col.add_child(_time_label)
	time_col.add_child(_phase_label)
	_panel(time_col, Control.PRESET_TOP_LEFT, Vector2(16, 16))

	# Eggs (top-left, below the time; only while carrying eggs)
	_eggs_col = VBoxContainer.new()
	_eggs_col.add_theme_constant_override("separation", 6)
	_eggs_box = _panel(_eggs_col, Control.PRESET_TOP_LEFT, Vector2(16, 104))

	# Location (top-centre)
	var place_col := VBoxContainer.new()
	place_col.add_theme_constant_override("separation", 0)
	_region_label = UiStyle.label(session.map.region_name.to_upper(), 13, UiStyle.GOLD)
	_area_label = UiStyle.label("", 22)
	_region_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_area_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	place_col.add_child(_region_label)
	place_col.add_child(_area_label)
	place_col.custom_minimum_size = Vector2(260, 0)
	_panel(place_col, Control.PRESET_CENTER_TOP, Vector2(0, 16))

	# Save / load (top-right)
	var file_row := HBoxContainer.new()
	file_row.add_theme_constant_override("separation", 8)
	var dragons_button := UiStyle.button("Dragons  (Tab)")
	var save_button := UiStyle.button("Save  (F5)")
	var load_button := UiStyle.button("Load  (F9)")
	dragons_button.pressed.connect(func() -> void: collection_requested.emit())
	for b in [dragons_button, save_button, load_button]:
		b.add_theme_font_size_override("font_size", 14)
		b.focus_mode = Control.FOCUS_NONE
		file_row.add_child(b)
	save_button.pressed.connect(func() -> void: save_requested.emit())
	load_button.pressed.connect(func() -> void: load_requested.emit())
	_panel(file_row, Control.PRESET_TOP_RIGHT, Vector2(-16, 16), 0.6)

	# Dragons (bottom-left)
	_party_col = VBoxContainer.new()
	_panel(_party_col, Control.PRESET_BOTTOM_LEFT, Vector2(16, -16))

	# Controls hint (bottom-right)
	_panel(UiStyle.label("Left-click: travel   ·   Right-drag / WASD: pan\nWheel: zoom   ·   Space: follow adventurer",
		13, UiStyle.MUTED), Control.PRESET_BOTTOM_RIGHT, Vector2(-16, -16), 0.6)

	# Toast (below the location panel)
	_toast_label = UiStyle.label("", 18, Color(1.0, 0.9, 0.6))
	_toast = _panel(_toast_label, Control.PRESET_CENTER_TOP, Vector2(0, 100))
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.modulate.a = 0.0

	session.clock.time_changed.connect(func(_m: float) -> void: _on_time_changed())
	session.cell_changed.connect(func(_c: Vector2i) -> void: _refresh_area())
	session.locations.discovered.connect(_on_discovered)
	session.roster.changed.connect(_rebuild_party)
	session.party_changed.connect(_rebuild_party)
	session.eggs.changed.connect(_rebuild_eggs)
	_rebuild_party()
	_rebuild_eggs()
	_on_time_changed()
	_refresh_area()


func show_toast(text: String, seconds: float = 3.5) -> void:
	_toast_label.text = text
	if _toast_tween:
		_toast_tween.kill()
	_toast.reset_size()
	_toast.position.x = (size.x - _toast.size.x) * 0.5
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.25)
	_toast_tween.tween_interval(seconds)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.6)


func _on_time_changed() -> void:
	var clock := _session.clock
	_time_label.text = "Day %d  ·  %s" % [clock.day(), clock.clock_text()]
	_phase_label.text = clock.phase_name()
	_refresh_eggs()
	for dragon in _session.roster.all():
		if _party_stages.get(dragon.id, -1) != dragon.stage(clock.total_minutes):
			_rebuild_party()
			return


func _refresh_area() -> void:
	_area_label.text = _session.area_name(_session.adventurer_cell)


func _on_discovered(location: Location) -> void:
	_refresh_area()
	show_toast("Discovered: %s" % location.name)


# --- Dragons -------------------------------------------------------------------

func _rebuild_party() -> void:
	_clear(_party_col)
	_party_stages.clear()
	var bonus := _session.scouting_bonus()
	var header := "TRAVELLING DRAGONS"
	if absf(bonus) > 0.001:
		header += "  ·  scouting %+.2f" % bonus
	_party_col.add_child(UiStyle.label(header, 13, UiStyle.GOLD))
	var now := _session.clock.total_minutes
	for dragon in _session.party():
		_party_col.add_child(_dragon_row(dragon, now))
	for dragon in _session.roster.all():
		_party_stages[dragon.id] = dragon.stage(now)
	var resting := _session.roster.size() - _session.party_ids.size()
	if resting > 0:
		_party_col.add_child(UiStyle.label("+%d resting at Wayfarer's Camp" % resting, 13, UiStyle.MUTED))
	elif _session.party_ids.is_empty():
		_party_col.add_child(UiStyle.label("No dragons travelling", 13, UiStyle.MUTED))


func _dragon_row(dragon: DragonRecord, now: float) -> Control:
	var species := dragon.species()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var frame := PanelContainer.new()
	var frame_style := UiStyle.panel(0.9)
	frame_style.bg_color = species.accent.darkened(0.65)
	frame_style.border_color = species.accent
	frame_style.set_content_margin_all(2)
	frame.add_theme_stylebox_override("panel", frame_style)
	frame.add_child(DragonSheet.portrait(dragon, now, _assets, Vector2(64, 52)))
	row.add_child(frame)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", -2)
	text.add_child(UiStyle.label(dragon.name, 19))
	text.add_child(UiStyle.label("%s · %s" % [species.name, species.element], 13, UiStyle.MUTED))
	var detail := str(dragon.traits.get("temperament", ""))
	var stage := dragon.stage(now)
	if stage != DragonSpecies.Stage.ADULT:
		detail = "%s · %s" % [DragonSpecies.STAGE_NAMES[stage], detail]
	text.add_child(UiStyle.label(detail, 13, UiStyle.MUTED))
	row.add_child(text)
	return row


# --- Eggs ----------------------------------------------------------------------

func _rebuild_eggs() -> void:
	_clear(_eggs_col)
	_egg_rows.clear()
	_eggs_box.visible = _session.eggs.size() > 0
	if not _eggs_box.visible:
		return
	_eggs_col.add_child(UiStyle.label("EGGS", 13, UiStyle.GOLD))
	for egg in _session.eggs.all():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var icon := TextureRect.new()
		icon.texture = _assets.get_texture(egg.species().egg_art)
		icon.custom_minimum_size = Vector2(30, 38)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		col.add_child(UiStyle.label("%s egg" % egg.species().short_name, 16))
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(190, 9)
		bar.max_value = 1.0
		bar.step = 0.0
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.25, 0.2, 0.15)
		bg.set_corner_radius_all(4)
		var fill := StyleBoxFlat.new()
		fill.bg_color = egg.species().accent
		fill.set_corner_radius_all(4)
		bar.add_theme_stylebox_override("background", bg)
		bar.add_theme_stylebox_override("fill", fill)
		col.add_child(bar)
		var status := UiStyle.label("", 13, UiStyle.MUTED)
		col.add_child(status)
		row.add_child(col)
		_eggs_col.add_child(row)
		_egg_rows[egg.id] = {"bar": bar, "status": status}
	_refresh_eggs()


func _refresh_eggs() -> void:
	var now := _session.clock.total_minutes
	for egg in _session.eggs.all():
		if not _egg_rows.has(egg.id):
			continue
		var row: Dictionary = _egg_rows[egg.id]
		(row.bar as ProgressBar).value = egg.progress(now)
		var status := row.status as Label
		if egg.is_ready(now):
			status.text = "Ready! Hatch it at Wayfarer's Camp"
			status.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
		else:
			status.text = "Warm · hatches in %s" % WorldClock.format_duration(egg.remaining_minutes(now))
			status.add_theme_color_override("font_color", UiStyle.MUTED)


# --- Helpers -------------------------------------------------------------------

func _clear(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


## Wraps `content` in a styled panel anchored to a screen corner/edge (grows inward).
func _panel(content: Control, preset: int, offset: Vector2, alpha: float = 0.84) -> PanelContainer:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UiStyle.panel(alpha))
	box.mouse_filter = Control.MOUSE_FILTER_STOP  # Clicks on HUD panels never send the party walking.
	box.add_child(content)
	add_child(box)
	box.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH if preset == Control.PRESET_CENTER_TOP \
		else (Control.GROW_DIRECTION_BEGIN if preset in [Control.PRESET_BOTTOM_RIGHT, Control.PRESET_TOP_RIGHT] \
		else Control.GROW_DIRECTION_END)
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN if preset in [Control.PRESET_BOTTOM_LEFT, Control.PRESET_BOTTOM_RIGHT] \
		else Control.GROW_DIRECTION_END
	box.position += offset
	return box
