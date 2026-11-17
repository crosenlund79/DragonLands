class_name CollectionScreen
extends Control
## Dragon management screen: every owned dragon, its genes and ancestry, comparison of two
## dragons, the travelling party (changed at camp) and breeding (at camp) with exact odds.

signal closed

const LIST_WIDTH := 300.0
const SHEET_WIDTH := 540.0
const SIDE_WIDTH := 560.0

var _session: OverworldSession
var _assets: AssetResolver
var _tab := "collection"
var _side := "ancestry"
var _selected := ""
var _compare := ""
var _parent_a := ""
var _parent_b := ""
var _message := ""

var _subtitle: Label
var _tab_buttons: Dictionary = {}
var _body: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.05, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := PanelContainer.new()
	var style := UiStyle.panel(0.97)
	style.set_content_margin_all(18)
	box.add_theme_stylebox_override("panel", style)
	center.add_child(box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size = Vector2(LIST_WIDTH + SHEET_WIDTH + SIDE_WIDTH + 40, 780)
	box.add_child(col)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", -2)
	titles.add_child(UiStyle.label("Dragon Collection", 26, Color(1.0, 0.88, 0.6)))
	_subtitle = UiStyle.label("", 14, UiStyle.MUTED)
	titles.add_child(_subtitle)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	for tab in ["collection", "breeding"]:
		var b := UiStyle.button(tab.capitalize())
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(show_tab.bind(tab))
		header.add_child(b)
		_tab_buttons[tab] = b
	var close_button := UiStyle.button("Close (Esc)")
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(close)
	header.add_child(close_button)
	col.add_child(header)

	_body = MarginContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_body)


func open(session: OverworldSession, assets: AssetResolver, tab: String = "collection") -> void:
	_session = session
	_assets = assets
	_tab = tab
	_message = ""
	if _session.roster.get_by_id(_selected) == null:
		_selected = _session.roster.all()[0].id if _session.roster.size() > 0 else ""
	visible = true
	refresh()


func is_open() -> bool:
	return visible


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


# --- Actions (also used by tests) ----------------------------------------------

func show_tab(tab: String) -> void:
	_tab = tab
	_message = ""
	refresh()


func select(id: String) -> void:
	_selected = id
	refresh()


func show_side(mode: String) -> void:
	_side = mode
	refresh()


func compare_with(id: String) -> void:
	_compare = id
	_side = "compare"
	refresh()


func choose_parents(a_id: String, b_id: String) -> void:
	_parent_a = a_id
	_parent_b = b_id
	_message = ""
	refresh()


func set_travelling(id: String, travelling: bool) -> void:
	_message = _session.set_travelling(id, travelling)
	refresh()


## Pairs the chosen parents. Returns the new egg or null.
func pair() -> EggRecord:
	var egg := _session.breed(_parent_a, _parent_b)
	if egg != null:
		_message = "An egg was laid! It hatches in %s - keep it warm at camp." % \
			WorldClock.format_duration(egg.remaining_minutes(_session.clock.total_minutes))
	refresh()
	return egg


func message() -> String:
	return _message


# --- Building ------------------------------------------------------------------

func refresh() -> void:
	if _session == null:
		return
	var now := _session.clock.total_minutes
	var at_camp := _session.at_camp()
	_subtitle.text = "%d dragons · %d travelling · %d eggs carried · %s" % [_session.roster.size(),
		_session.party_ids.size(), _session.eggs.size(),
		"at Wayfarer's Camp" if at_camp else "away from camp (party and breeding are managed at Wayfarer's Camp)"]
	for tab in _tab_buttons:
		(_tab_buttons[tab] as Button).modulate = Color.WHITE if tab == _tab else Color(1, 1, 1, 0.55)
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	_body.add_child(_build_collection(now, at_camp) if _tab == "collection" else _build_breeding(now, at_camp))


func _build_collection(now: float, at_camp: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.add_child(_build_list(now))
	row.add_child(_scroll(_build_sheet(_session.roster.get_by_id(_selected), now, at_camp), SHEET_WIDTH))
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 8)
	side.custom_minimum_size = Vector2(SIDE_WIDTH, 0)
	var modes := HBoxContainer.new()
	modes.add_theme_constant_override("separation", 6)
	for mode in ["ancestry", "compare"]:
		var b := UiStyle.button(mode.capitalize())
		b.focus_mode = Control.FOCUS_NONE
		b.modulate = Color.WHITE if mode == _side else Color(1, 1, 1, 0.55)
		b.pressed.connect(show_side.bind(mode))
		modes.add_child(b)
	side.add_child(modes)
	var content := _build_ancestry(_selected, now) if _side == "ancestry" else _build_compare(now)
	side.add_child(_scroll(content, SIDE_WIDTH))
	row.add_child(side)
	return row


func _build_list(now: float) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	var groups := [["TRAVELLING", _session.party()], ["RESTING AT CAMP", _resting()]]
	for group in groups:
		col.add_child(DragonSheet.section("%s (%d)" % [group[0], group[1].size()]))
		for dragon in group[1]:
			col.add_child(_card(dragon, now))
	return _scroll(col, LIST_WIDTH)


func _card(dragon: DragonRecord, now: float) -> Control:
	var card := PanelContainer.new()
	var style := UiStyle.panel(0.9)
	style.set_content_margin_all(6)
	if dragon.id == _selected:
		style.bg_color = Color(0.32, 0.24, 0.14, 0.98)
		style.border_color = Color(1.0, 0.85, 0.5)
	card.add_theme_stylebox_override("panel", style)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			select(dragon.id))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(DragonSheet.portrait(dragon, now, _assets, Vector2(58, 46)))
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", -3)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(UiStyle.label(dragon.name, 17))
	text.add_child(UiStyle.label("%s · %s · Gen %d" % [dragon.species().short_name,
		DragonSpecies.STAGE_NAMES[dragon.stage(now)], dragon.generation], 13, UiStyle.MUTED))
	var best := _best_trait(dragon)
	if best != "":
		text.add_child(UiStyle.label(best, 13, DragonSheet.POSITIVE))
	row.add_child(text)
	card.add_child(row)
	return card


func _build_sheet(dragon: DragonRecord, now: float, at_camp: bool) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	if dragon == null:
		col.add_child(UiStyle.label("No dragon selected", 16, UiStyle.MUTED))
		return col
	col.add_child(DragonSheet.header(dragon, now, _assets, _session.lineage))
	var origin := UiStyle.label(dragon.origin, 14, UiStyle.MUTED)
	origin.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(origin)
	var travel := CheckBox.new()
	travel.text = "Travels with you (max %d)" % OverworldSession.MAX_PARTY
	travel.button_pressed = _session.is_travelling(dragon.id)
	travel.disabled = not at_camp or (not travel.button_pressed and _session.party_ids.size() >= OverworldSession.MAX_PARTY)
	travel.add_theme_font_size_override("font_size", 15)
	travel.add_theme_color_override("font_color", UiStyle.TEXT)
	travel.add_theme_color_override("font_disabled_color", UiStyle.MUTED)
	travel.focus_mode = Control.FOCUS_NONE
	travel.toggled.connect(func(on: bool) -> void: set_travelling(dragon.id, on))
	col.add_child(travel)
	if _message != "" and _tab == "collection":
		col.add_child(UiStyle.label(_message, 14, Color(1.0, 0.75, 0.5)))
	col.add_child(DragonSheet.appearance(dragon.genome))
	col.add_child(DragonSheet.traits(dragon.genome))
	var scouting := TraitCatalog.scouting_of(dragon.genome)
	if scouting != 0.0:
		col.add_child(UiStyle.label("Scouting while travelling: %+.2f cells" % scouting, 14,
			DragonSheet.POSITIVE if scouting > 0.0 else DragonSheet.NEGATIVE))
	col.add_child(DragonSheet.section("BREEDING"))
	var problem := BreedingRules.dragon_problem(dragon, now)
	col.add_child(UiStyle.label("Ready to breed" if problem == "" else problem, 15,
		DragonSheet.POSITIVE if problem == "" else UiStyle.MUTED))
	if not dragon.inheritance_notes.is_empty():
		col.add_child(DragonSheet.notes(dragon.inheritance_notes))
	return col


func _build_ancestry(id: String, now: float) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.add_child(DragonSheet.section("ANCESTRY (parents and grandparents)"))
	if id == "":
		return col
	col.add_child(_ancestor_row(id, 0, ""))
	for parent in _session.lineage.parents_of(id):
		col.add_child(_ancestor_row(parent, 1, "Parent"))
		for grandparent in _session.lineage.parents_of(parent):
			col.add_child(_ancestor_row(grandparent, 2, "Grandparent"))
		if _session.lineage.parents_of(parent).is_empty():
			col.add_child(_unknown_row(2))
	if _session.lineage.parents_of(id).is_empty():
		col.add_child(_unknown_row(1))
	var ancestors := _session.lineage.ancestors(id)
	col.add_child(UiStyle.label("%d known ancestors in total." % ancestors.size(), 14, UiStyle.MUTED))
	var children := _session.roster.all().filter(func(d: DragonRecord) -> bool: return d.parent_ids.has(id))
	if not children.is_empty():
		col.add_child(DragonSheet.section("OFFSPRING"))
		col.add_child(UiStyle.label(", ".join(children.map(func(d: DragonRecord) -> String:
			return "%s (Gen %d)" % [d.name, d.generation])), 15))
	return col


func _ancestor_row(id: String, depth: int, role: String) -> Control:
	var entry := _session.lineage.get_entry(id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var indent := Control.new()
	indent.custom_minimum_size = Vector2(depth * 34, 0)
	row.add_child(indent)
	var color_hex := str(entry.get("color", ""))
	row.add_child(DragonSheet.swatch(Color.html(color_hex) if color_hex != "" else Color.GRAY, Vector2(18, 18)))
	var text := "%s%s · Gen %d · %s" % ["%s: " % role if role != "" else "", entry.get("name", "?"),
		int(entry.get("generation", 0)), SpeciesCatalog.get_species(str(entry.get("species", "cinderwing"))).short_name]
	if (entry.get("parents", []) as Array).is_empty():
		text += " (wild-born)"
	row.add_child(UiStyle.label(text, 16 if depth == 0 else 15, Color(1.0, 0.9, 0.65) if depth == 0 else UiStyle.TEXT))
	return row


func _unknown_row(depth: int) -> Control:
	var row := HBoxContainer.new()
	var indent := Control.new()
	indent.custom_minimum_size = Vector2(depth * 34, 0)
	row.add_child(indent)
	row.add_child(UiStyle.label("Parents unknown (wild)", 14, UiStyle.MUTED))
	return row


func _build_compare(now: float) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	var a := _session.roster.get_by_id(_selected)
	var picker := _dragon_picker(_compare, _selected, func(id: String) -> void: compare_with(id))
	col.add_child(DragonSheet.section("COMPARE %s WITH" % (a.name.to_upper() if a else "")))
	col.add_child(picker)
	var b := _session.roster.get_by_id(_compare)
	if a == null or b == null or a == b:
		col.add_child(UiStyle.label("Pick a second dragon to compare.", 15, UiStyle.MUTED))
		return col
	var heads := HBoxContainer.new()
	heads.add_theme_constant_override("separation", 10)
	for d in [a, b]:
		var c := VBoxContainer.new()
		c.custom_minimum_size = Vector2(250, 0)
		c.add_child(DragonSheet.portrait(d, now, _assets, Vector2(130, 96)))
		var n := UiStyle.label(d.name, 18, Color(1.0, 0.9, 0.65))
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		c.add_child(n)
		heads.add_child(c)
	col.add_child(heads)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 4)
	_compare_row(grid, "Growth", DragonSpecies.STAGE_NAMES[a.stage(now)], DragonSpecies.STAGE_NAMES[b.stage(now)])
	_compare_row(grid, "Generation", str(a.generation), str(b.generation))
	for ch in Genome.CHANNELS:
		grid.add_child(UiStyle.label(Genome.CHANNEL_NAMES[ch], 14, UiStyle.GOLD))
		for d in [a, b]:
			var cell := HBoxContainer.new()
			cell.add_theme_constant_override("separation", 6)
			cell.add_child(DragonSheet.swatch(d.genome.color(ch), Vector2(20, 14)))
			cell.add_child(UiStyle.label(ColorWords.describe(d.genome.colors[ch]), 14))
			grid.add_child(cell)
	_compare_row(grid, "Markings", a.genome.pattern, b.genome.pattern)
	for id in TraitCatalog.ids():
		var ta := a.genome.tier(id)
		var tb := b.genome.tier(id)
		if ta == 0 and tb == 0:
			continue
		var better_a := (ta > tb) == TraitCatalog.is_positive(id)
		grid.add_child(UiStyle.label(TraitCatalog.display_name(id), 14, UiStyle.GOLD))
		for entry in [[ta, better_a and ta != tb], [tb, not better_a and ta != tb]]:
			var text := TraitCatalog.roman(entry[0]) if entry[0] > 0 else "-"
			grid.add_child(UiStyle.label(text + ("  ▲" if entry[1] else ""), 15, DragonSheet.POSITIVE if entry[1] else UiStyle.TEXT))
	_compare_row(grid, "Scouting", "%+.2f" % TraitCatalog.scouting_of(a.genome), "%+.2f" % TraitCatalog.scouting_of(b.genome))
	col.add_child(grid)
	col.add_child(UiStyle.label("▲ = the better of the two for that trait", 13, UiStyle.MUTED))
	return col


func _compare_row(grid: GridContainer, label: String, a_text: String, b_text: String) -> void:
	grid.add_child(UiStyle.label(label, 14, UiStyle.GOLD))
	grid.add_child(UiStyle.label(a_text, 14))
	grid.add_child(UiStyle.label(b_text, 14))


# --- Breeding tab --------------------------------------------------------------

func _build_breeding(now: float, at_camp: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.add_child(_parent_column("PARENT A", _parent_a, _parent_b, func(id: String) -> void: choose_parents(id, _parent_b), now))
	row.add_child(_scroll(_odds_column(now, at_camp), 520))
	row.add_child(_parent_column("PARENT B", _parent_b, _parent_a, func(id: String) -> void: choose_parents(_parent_a, id), now))
	return row


func _parent_column(title: String, id: String, other: String, on_pick: Callable, now: float) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.add_child(DragonSheet.section(title))
	col.add_child(_dragon_picker(id, other, on_pick))
	var dragon := _session.roster.get_by_id(id)
	if dragon != null:
		col.add_child(DragonSheet.header(dragon, now, _assets, _session.lineage, Vector2(110, 86)))
		var problem := BreedingRules.dragon_problem(dragon, now)
		col.add_child(UiStyle.label("Ready to breed" if problem == "" else problem, 14,
			DragonSheet.POSITIVE if problem == "" else Color(1.0, 0.75, 0.5)))
		col.add_child(DragonSheet.appearance(dragon.genome))
		col.add_child(DragonSheet.traits(dragon.genome))
	return _scroll(col, 420)


func _odds_column(now: float, at_camp: bool) -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	col.add_child(UiStyle.label("Expected offspring", 22, Color(1.0, 0.88, 0.6)))
	var a := _session.roster.get_by_id(_parent_a)
	var b := _session.roster.get_by_id(_parent_b)
	var problem := _session.breeding_problem(_parent_a, _parent_b)
	var pair_button := UiStyle.button("Pair them  (%s at camp, then both rest %s)" % [
		WorldClock.format_duration(BreedingRules.BREEDING_MINUTES), WorldClock.format_duration(BreedingRules.COOLDOWN_MINUTES)])
	pair_button.disabled = problem != ""
	pair_button.focus_mode = Control.FOCUS_NONE
	pair_button.pressed.connect(func() -> void: pair())
	var status := UiStyle.label("Compatible: same species, both adults and rested." if problem == "" else problem, 15,
		DragonSheet.POSITIVE if problem == "" else Color(1.0, 0.75, 0.5))
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(status)
	col.add_child(pair_button)
	if _message != "":
		var msg := UiStyle.label(_message, 15, Color(1.0, 0.85, 0.45))
		msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(msg)
	if not at_camp:
		col.add_child(UiStyle.label("Travel to Wayfarer's Camp to breed.", 15, UiStyle.MUTED))
	if a == null or b == null or a.species_id != b.species_id:
		col.add_child(UiStyle.label("Choose two dragons of the same species to see the odds.", 15, UiStyle.MUTED))
		return col
	col.add_child(DragonSheet.section("COLOURS (each part blends between the parents; %d%% chance of a new shade)" % \
		roundi(GeneticsEngine.COLOR_SHIFT_CHANCE * 100.0)))
	for ch in Genome.CHANNELS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var label := UiStyle.label(Genome.CHANNEL_NAMES[ch], 14)
		label.custom_minimum_size = Vector2(110, 0)
		row.add_child(label)
		row.add_child(_gradient(a.genome.colors[ch], b.genome.colors[ch]))
		col.add_child(row)
	col.add_child(DragonSheet.section("MARKINGS"))
	col.add_child(UiStyle.label(_odds_text(GeneticsEngine.pattern_distribution(a.genome, b.genome), func(k: Variant) -> String:
		return str(k).capitalize()), 14))
	col.add_child(DragonSheet.section("TRAITS"))
	var listed := false
	for id in TraitCatalog.ids():
		var ta := a.genome.tier(id)
		var tb := b.genome.tier(id)
		if ta == 0 and tb == 0:
			continue
		listed = true
		var name := UiStyle.label(TraitCatalog.display_name(id), 15,
			DragonSheet.POSITIVE if TraitCatalog.is_positive(id) else DragonSheet.NEGATIVE)
		col.add_child(name)
		var odds := UiStyle.label(_odds_text(GeneticsEngine.tier_distribution(ta, tb), func(k: Variant) -> String:
			return "none" if int(k) == 0 else TraitCatalog.roman(int(k))), 14)
		odds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(odds)
	if not listed:
		col.add_child(UiStyle.label("Neither parent carries a trait.", 14, UiStyle.MUTED))
	col.add_child(UiStyle.label("Any trait neither parent carries: %d%% chance to appear at tier I." % \
		roundi(GeneticsEngine.SPONTANEOUS * 100.0), 13, UiStyle.MUTED))
	col.add_child(UiStyle.label("Genes are fixed when the egg is laid.", 13, UiStyle.MUTED))
	return col


func _odds_text(distribution: Dictionary, name_of: Callable) -> String:
	var keys := distribution.keys()
	keys.sort_custom(func(x: Variant, y: Variant) -> bool: return distribution[x] > distribution[y])
	var parts := PackedStringArray()
	for k in keys:
		if distribution[k] >= 0.0005:
			parts.append("%s %s" % [name_of.call(k), _percent(distribution[k])])
	return "  ·  ".join(parts)


func _percent(p: float) -> String:
	return "%d%%" % roundi(p * 100.0) if p >= 0.1 else "%.1f%%" % (p * 100.0)


func _gradient(a: Vector3, b: Vector3) -> Control:
	var gradient := Gradient.new()
	gradient.set_color(0, Color.from_hsv(a.x, a.y, a.z))
	gradient.set_color(1, Color.from_hsv(b.x, b.y, b.z))
	for i in range(1, 4):
		var c := GeneticsEngine.hsv_lerp(a, b, i / 4.0)
		gradient.add_point(i / 4.0, Color.from_hsv(c.x, c.y, c.z))
	var tex := GradientTexture1D.new()
	tex.gradient = gradient
	var rect := TextureRect.new()
	rect.texture = tex
	rect.custom_minimum_size = Vector2(300, 16)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	return rect


# --- Helpers -------------------------------------------------------------------

func _dragon_picker(selected: String, exclude: String, on_pick: Callable) -> OptionButton:
	var picker := OptionButton.new()
	picker.add_theme_font_size_override("font_size", 15)
	picker.focus_mode = Control.FOCUS_NONE
	picker.add_item("- choose a dragon -")
	picker.set_item_metadata(0, "")
	var now := _session.clock.total_minutes
	for dragon in _session.roster.all():
		if dragon.id == exclude:
			continue
		var problem := BreedingRules.dragon_problem(dragon, now)
		picker.add_item("%s (%s, %s%s)" % [dragon.name, dragon.species().short_name,
			DragonSpecies.STAGE_NAMES[dragon.stage(now)], "" if problem == "" or _tab != "breeding" else ", not ready"])
		picker.set_item_metadata(picker.item_count - 1, dragon.id)
		if dragon.id == selected:
			picker.select(picker.item_count - 1)
	picker.item_selected.connect(func(index: int) -> void: on_pick.call(str(picker.get_item_metadata(index))))
	return picker


func _resting() -> Array[DragonRecord]:
	var result: Array[DragonRecord] = []
	for dragon in _session.roster.all():
		if not _session.is_travelling(dragon.id):
			result.append(dragon)
	return result


func _best_trait(dragon: DragonRecord) -> String:
	var best_id := ""
	for id in TraitCatalog.ids():
		if TraitCatalog.is_positive(id) and dragon.genome.tier(id) > (dragon.genome.tier(best_id) if best_id != "" else 0):
			best_id = id
	return "" if best_id == "" else "%s %s" % [TraitCatalog.display_name(best_id), TraitCatalog.roman(dragon.genome.tier(best_id))]


func _scroll(content: Control, width: float) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(width, 690)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	return scroll
