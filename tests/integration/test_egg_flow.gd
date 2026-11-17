extends GutTest
## Egg acquisition at the nest, incubation on the world clock and hatching at camp.

var session: OverworldSession


func before_each() -> void:
	session = OverworldSession.new(ElderwoodVale.create_map(), ElderwoodVale.create_locations(),
		StartingDragons.create_roster(), ElderwoodVale.START_CELL, ElderwoodVale.START_MINUTES)
	session.begin()


func _nest() -> Location:
	return session.locations.get_by_id("nest")


func _camp() -> Location:
	return session.locations.get_by_id("camp")


func _ids(choices: Array[EncounterChoice]) -> Array:
	return choices.map(func(c: EncounterChoice) -> String: return c.id)


func _take_egg() -> EggRecord:
	var choice := _nest().encounter.get_choice("egg")
	session.resolve_choice(_nest(), choice)
	return session.eggs.all()[0] if session.eggs.size() > 0 else null


func test_nest_offers_an_egg_and_grants_exactly_one() -> void:
	assert_has(_ids(session.choices_for(_nest())), "egg")
	watch_signals(session)
	var start := session.clock.total_minutes
	var egg := _take_egg()
	assert_not_null(egg)
	assert_eq(egg.species_id, "cinderwing")
	assert_eq(egg.origin_location_id, "nest")
	assert_almost_eq(session.clock.total_minutes - start, 45.0, 0.001, "asking takes time")
	assert_signal_emitted(session, "egg_acquired")
	assert_true(session.egg_taken("nest"))


func test_the_same_nest_cannot_give_a_second_egg() -> void:
	_take_egg()
	assert_does_not_have(_ids(session.choices_for(_nest())), "egg", "choice disappears")
	assert_eq(session.resolve_choice(_nest(), _nest().encounter.get_choice("egg")), "", "forcing it does nothing")
	assert_eq(session.eggs.size(), 1)
	assert_string_contains(session.encounter_text(_nest()), "Two speckled eggs")


func test_egg_develops_while_travelling_and_announces_readiness_once() -> void:
	var egg := _take_egg()
	watch_signals(session)
	var road := session.map.cell_to_world(ElderwoodVale.START_CELL)
	var cells_needed := egg.incubation_minutes / Terrain.minutes_per_cell(Terrain.Type.ROAD)
	session.travel(RegionMap.CELL_SIZE * cells_needed * 0.5, road)
	assert_almost_eq(egg.progress(session.clock.total_minutes), 0.5, 0.01)
	assert_signal_not_emitted(session, "egg_ready")
	session.travel(RegionMap.CELL_SIZE * cells_needed * 0.6, road)
	assert_true(egg.is_ready(session.clock.total_minutes))
	session.travel(RegionMap.CELL_SIZE, road)
	assert_signal_emit_count(session, "egg_ready", 1)


func test_no_time_no_development() -> void:
	var egg := _take_egg()
	var p := egg.progress(session.clock.total_minutes)
	session.arrive(Vector2i(10, 17))
	assert_eq(egg.progress(session.clock.total_minutes), p)


func test_camp_offers_warming_until_ready_then_hatching() -> void:
	assert_does_not_have(_ids(session.choices_for(_camp())), "warm", "no egg, no egg choices")
	assert_does_not_have(_ids(session.choices_for(_camp())), "hatch")
	var egg := _take_egg()
	var warm := session.choices_for(_camp()).filter(func(c: EncounterChoice) -> bool: return c.id == "warm")
	assert_eq(warm.size(), 1)
	assert_string_contains(warm[0].label, "12h", "shows the time still needed")
	watch_signals(session)
	assert_eq(session.resolve_choice(_camp(), warm[0]), "", "closes the panel for the hatching moment")
	assert_true(egg.is_ready(session.clock.total_minutes), "waiting advanced the clock to readiness")
	assert_signal_emitted_with_parameters(session, "hatch_requested", [egg])
	assert_has(_ids(session.choices_for(_camp())), "hatch")
	assert_does_not_have(_ids(session.choices_for(_camp())), "warm")


func test_hatching_adds_a_new_dragon_and_consumes_the_egg() -> void:
	var egg := _take_egg()
	session.adventurer_cell = _camp().cell
	assert_null(session.hatch_egg(egg.id, "Pip"), "not ready yet")
	session.clock.advance(egg.incubation_minutes)
	watch_signals(session)
	var dragon := session.hatch_egg(egg.id, "Pip")
	assert_not_null(dragon)
	assert_eq(dragon.name, "Pip")
	assert_eq(session.roster.size(), 3)
	assert_eq(session.roster.all()[2].id, dragon.id)
	assert_eq(session.eggs.size(), 0)
	assert_string_contains(dragon.origin, "Wayfarer's Camp")
	assert_string_contains(dragon.origin, "Emberfall Nest")
	assert_signal_emitted_with_parameters(session, "dragon_hatched", [dragon])
	assert_null(session.hatch_egg(egg.id, "Again"), "an egg hatches once")
	assert_eq(session.roster.size(), 3)
	assert_true(session.egg_taken("nest"), "the nest stays emptied after hatching")


func test_ids_are_unique_across_eggs_and_dragons() -> void:
	var egg := _take_egg()
	session.clock.advance(egg.incubation_minutes)
	var dragon := session.hatch_egg(egg.id, "Pip")
	var ids := {}
	for d in session.roster.all():
		ids[d.id] = true
	ids[egg.id] = true
	assert_eq(ids.size(), session.roster.size() + 1)
	assert_ne(dragon.id, egg.id)
