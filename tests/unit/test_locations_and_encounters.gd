extends GutTest

func _registry() -> LocationRegistry:
	var registry := LocationRegistry.new()
	var choices: Array[EncounterChoice] = [EncounterChoice.new("look", "Look", "You look.", 10.0)]
	registry.add(Location.new("a", "Alpha", Vector2i(1, 1), Location.Kind.LANDMARK, "x",
		Encounter.new("Alpha", "Text", "x", choices)))
	registry.add(Location.new("b", "Beta", Vector2i(8, 8), Location.Kind.DRAGON_NEST, "y",
		Encounter.new("Beta", "Text", "y", choices)))
	return registry


func test_discovered_when_cell_is_explored() -> void:
	var registry := _registry()
	var fog := FogOfWar.new(Vector2i(10, 10))
	watch_signals(registry)
	fog.reveal(Vector2i(0, 0), 2.0)
	var found := registry.discover_explored(fog)
	assert_eq(found.size(), 1)
	assert_eq(found[0].id, "a")
	assert_true(registry.is_discovered("a"))
	assert_false(registry.is_discovered("b"))
	assert_eq(registry.discover_explored(fog).size(), 0, "discovery happens once")
	assert_signal_emit_count(registry, "discovered", 1)


func test_lookup_by_cell_and_id() -> void:
	var registry := _registry()
	assert_eq(registry.at_cell(Vector2i(8, 8)).id, "b")
	assert_null(registry.at_cell(Vector2i(0, 0)))
	assert_eq(registry.get_by_id("a").name, "Alpha")


func test_nearest_discovered_ignores_undiscovered() -> void:
	var registry := _registry()
	assert_null(registry.nearest_discovered(Vector2i(1, 2), 3.0))
	var fog := FogOfWar.new(Vector2i(10, 10))
	fog.reveal(Vector2i(1, 1), 1.0)
	registry.discover_explored(fog)
	assert_eq(registry.nearest_discovered(Vector2i(1, 2), 3.0).id, "a")
	assert_null(registry.nearest_discovered(Vector2i(6, 6), 3.0))


func test_encounter_choice_lookup() -> void:
	var encounter := _registry().get_by_id("b").encounter
	assert_eq(encounter.get_choice("look").minutes, 10.0)
	assert_null(encounter.get_choice("missing"))
