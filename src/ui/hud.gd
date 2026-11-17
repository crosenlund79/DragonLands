class_name Hud
extends Control
## Minimal HUD: world time, current place, travelling dragons, controls hint and toasts.

var _session: OverworldSession
var _time_label: Label
var _phase_label: Label
var _region_label: Label
var _area_label: Label
var _toast: PanelContainer
var _toast_label: Label
var _toast_tween: Tween


func setup(session: OverworldSession, assets: AssetResolver) -> void:
	_session = session
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

	# Dragons (bottom-left)
	var party_col := VBoxContainer.new()
	party_col.add_child(UiStyle.label("TRAVELLING DRAGONS", 13, UiStyle.GOLD))
	for dragon in session.party:
		party_col.add_child(_dragon_row(dragon, assets))
	_panel(party_col, Control.PRESET_BOTTOM_LEFT, Vector2(16, -16))

	# Controls hint (bottom-right)
	_panel(UiStyle.label("Left-click: travel   ·   Right-drag / WASD: pan\nWheel: zoom   ·   Space: follow adventurer",
		13, UiStyle.MUTED), Control.PRESET_BOTTOM_RIGHT, Vector2(-16, -16), 0.6)

	# Toast (below the location panel)
	_toast_label = UiStyle.label("", 18, Color(1.0, 0.9, 0.6))
	_toast = _panel(_toast_label, Control.PRESET_CENTER_TOP, Vector2(0, 100))
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.modulate.a = 0.0

	session.clock.time_changed.connect(func(_m: float) -> void: _refresh_time())
	session.cell_changed.connect(func(_c: Vector2i) -> void: _refresh_area())
	session.locations.discovered.connect(_on_discovered)
	_refresh_time()
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


func _refresh_time() -> void:
	var clock := _session.clock
	_time_label.text = "Day %d  ·  %s" % [clock.day(), clock.clock_text()]
	_phase_label.text = clock.phase_name()


func _refresh_area() -> void:
	_area_label.text = _session.area_name(_session.adventurer_cell)


func _on_discovered(location: Location) -> void:
	_refresh_area()
	show_toast("Discovered: %s" % location.name)


func _dragon_row(dragon: DragonProfile, assets: AssetResolver) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var frame := PanelContainer.new()
	var frame_style := UiStyle.panel(0.9)
	frame_style.bg_color = dragon.accent.darkened(0.65)
	frame_style.border_color = dragon.accent
	frame_style.set_content_margin_all(2)
	frame.add_theme_stylebox_override("panel", frame_style)
	var portrait := TextureRect.new()
	portrait.texture = assets.get_texture(dragon.art)
	portrait.custom_minimum_size = Vector2(64, 52)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.add_child(portrait)
	row.add_child(frame)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", -2)
	text.add_child(UiStyle.label(dragon.name, 19))
	text.add_child(UiStyle.label("%s · %s" % [dragon.species, dragon.element], 13, UiStyle.MUTED))
	text.add_child(UiStyle.label(dragon.temperament, 13, UiStyle.MUTED))
	row.add_child(text)
	return row


## Wraps `content` in a styled panel anchored to a screen corner/edge (grows inward).
func _panel(content: Control, preset: int, offset: Vector2, alpha: float = 0.84) -> PanelContainer:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UiStyle.panel(alpha))
	box.mouse_filter = Control.MOUSE_FILTER_STOP  # Clicks on HUD panels never send the party walking.
	box.add_child(content)
	add_child(box)
	box.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH if preset == Control.PRESET_CENTER_TOP \
		else (Control.GROW_DIRECTION_BEGIN if preset == Control.PRESET_BOTTOM_RIGHT else Control.GROW_DIRECTION_END)
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN if preset in [Control.PRESET_BOTTOM_LEFT, Control.PRESET_BOTTOM_RIGHT] \
		else Control.GROW_DIRECTION_END
	box.position += offset
	return box
