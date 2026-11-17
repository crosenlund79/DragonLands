class_name DragonSheet
extends RefCounted
## Builders for readable dragon information blocks, shared by the collection screen,
## the breeding view and the hatching card.

const POSITIVE := Color(0.55, 0.85, 0.5)
const NEGATIVE := Color(0.95, 0.5, 0.42)


## A recoloured portrait of `dragon` at its current growth stage.
static func portrait(dragon: DragonRecord, now: float, assets: AssetResolver, box: Vector2) -> TextureRect:
	var art := dragon.art_at(now)
	var rect := TextureRect.new()
	rect.texture = assets.get_texture(art)
	rect.material = DragonLook.material_for(dragon.genome, art, assets, dragon.id)
	rect.custom_minimum_size = box
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## "Adult · 6d 4h old" style summary.
static func growth_text(dragon: DragonRecord, now: float) -> String:
	return "%s · %s old" % [DragonSpecies.STAGE_NAMES[dragon.stage(now)],
		WorldClock.format_duration(dragon.age_minutes(now)) if dragon.age_minutes(now) < 60.0 * 24.0 * 20.0 else "many days"]


static func parents_text(dragon: DragonRecord, lineage: LineageBook) -> String:
	if dragon.parent_ids.size() < 2:
		return "Generation %d · wild-born, parents unknown" % dragon.generation
	return "Generation %d · %s × %s" % [dragon.generation, _name(dragon.parent_ids[0], lineage),
		_name(dragon.parent_ids[1], lineage)]


## Header: portrait, name, species, growth, generation/parents, temperament.
static func header(dragon: DragonRecord, now: float, assets: AssetResolver, lineage: LineageBook,
		portrait_size: Vector2 = Vector2(150, 118)) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.add_child(portrait(dragon, now, assets, portrait_size))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.add_child(UiStyle.label(dragon.name, 26, Color(1.0, 0.9, 0.65)))
	var species := dragon.species()
	col.add_child(UiStyle.label("%s · %s element" % [species.name, species.element], 15, UiStyle.TEXT))
	col.add_child(UiStyle.label(growth_text(dragon, now), 15, UiStyle.MUTED))
	col.add_child(UiStyle.label(parents_text(dragon, lineage), 15, UiStyle.MUTED))
	col.add_child(UiStyle.label("Temperament: %s" % str(dragon.traits.get("temperament", "-")), 15, UiStyle.MUTED))
	row.add_child(col)
	return row


static func section(title: String) -> Label:
	var l := UiStyle.label(title, 13, UiStyle.GOLD)
	l.add_theme_constant_override("line_spacing", 0)
	return l


static func swatch(color: Color, size: Vector2 = Vector2(28, 16)) -> PanelContainer:
	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color(0.1, 0.08, 0.05)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	box.add_theme_stylebox_override("panel", style)
	box.custom_minimum_size = size
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return box


## Colour channels and markings: the cosmetic genes.
static func appearance(genome: Genome) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.add_child(section("APPEARANCE (cosmetic)"))
	for ch in Genome.CHANNELS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(swatch(genome.color(ch)))
		row.add_child(UiStyle.label("%s: %s" % [Genome.CHANNEL_NAMES[ch], ColorWords.describe(genome.colors[ch])], 15))
		col.add_child(row)
	var marks := "Markings: plain" if genome.pattern == "plain" else \
		"Markings: %s (%d%% bold)" % [genome.pattern, roundi(genome.pattern_strength * 100.0)]
	col.add_child(UiStyle.label(marks, 15))
	return col


## Gameplay traits with tier bars; active traits are marked.
static func traits(genome: Genome) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.add_child(section("GENETIC TRAITS (tier 1-10)"))
	var any := false
	for id in TraitCatalog.ids():
		var tier := genome.tier(id)
		if tier <= 0:
			continue
		any = true
		col.add_child(trait_row(id, tier))
	if not any:
		col.add_child(UiStyle.label("No notable traits", 15, UiStyle.MUTED))
	return col


static func trait_row(id: String, tier: int) -> Control:
	var info := TraitCatalog.info(id)
	var color := POSITIVE if info.positive else NEGATIVE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.tooltip_text = info.about
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	var name := UiStyle.label("%s %s" % [info.name, TraitCatalog.roman(tier)], 15, color)
	name.custom_minimum_size = Vector2(150, 0)
	row.add_child(name)
	row.add_child(tier_bar(tier, color))
	var note := UiStyle.label("active" if info.active else "future", 12, Color(1.0, 0.85, 0.45) if info.active else UiStyle.MUTED)
	row.add_child(note)
	return row


static func tier_bar(tier: int, color: Color) -> HBoxContainer:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 2)
	for i in GeneticsEngine.MAX_TIER:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(9, 12)
		pip.color = color if i < tier else Color(0.3, 0.26, 0.2)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(pip)
	return bar


static func notes(lines: PackedStringArray, title: String = "INHERITANCE") -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 1)
	col.add_child(section(title))
	for line in lines:
		var l := UiStyle.label("• " + line, 14, UiStyle.TEXT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(l)
	return col


static func _name(id: String, lineage: LineageBook) -> String:
	return str(lineage.get_entry(id).get("name", "?"))
