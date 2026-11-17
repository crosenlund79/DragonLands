extends GutTest
## Breeding at camp: eligibility, cooldowns, eggs with fixed genes, hatching, party, scouting, resting.

const CAMP := Vector2i(3, 16)
var session: OverworldSession


func before_each() -> void:
	session = _new_session()


func _new_session() -> OverworldSession:
	var s := OverworldSession.new(ElderwoodVale.create_map(), ElderwoodVale.create_locations(),
		StartingDragons.create_roster(), ElderwoodVale.START_CELL, ElderwoodVale.START_MINUTES)
	s.begin()
	return s


## Fresh game -> nest egg -> hatched "Pip" at camp (party: Ember, Moss, Pip).
func _hatch_pip(s: OverworldSession) -> DragonRecord:
	var nest := s.locations.get_by_id("nest")
	s.resolve_choice(nest, nest.encounter.get_choice("egg"))
	s.adventurer_cell = CAMP
	var camp := s.locations.get_by_id("camp")
	s.resolve_choice(camp, camp.encounter.get_choice("warm"))
	return s.hatch_egg(s.eggs.all()[0].id, "Pip")


func _rest_until(s: OverworldSession) -> String:
	var camp := s.locations.get_by_id("camp")
	var choice: EncounterChoice = s.choices_for(camp).filter(func(c: EncounterChoice) -> bool: return c.id == "rest_until")[0]
	return s.resolve_choice(camp, choice)


func test_first_breeding_is_reachable_from_a_fresh_game() -> void:
	var pip := _hatch_pip(session)
	assert_eq(session.party_ids, PackedStringArray(["ember", "moss", pip.id]))
	assert_string_contains(session.breeding_problem("ember", pip.id), "still a hatchling")
	var labels := session.choices_for(session.locations.get_by_id("camp")).map(func(c: EncounterChoice) -> String: return c.label)
	assert_true(labels.any(func(l: String) -> bool: return l.begins_with("Rest until Pip is fully grown")), str(labels))
	assert_string_contains(_rest_until(session), "Pip is fully grown")
	assert_eq(pip.stage(session.clock.total_minutes), DragonSpecies.Stage.ADULT)
	assert_eq(session.breeding_problem("ember", pip.id), "", "Ember x Pip: no dead end")


func test_breeding_lays_an_egg_with_genes_parents_and_generation() -> void:
	var pip := _hatch_pip(session)
	_rest_until(session)
	var start := session.clock.total_minutes
	watch_signals(session)
	var egg := session.breed("ember", pip.id)
	assert_not_null(egg)
	assert_almost_eq(session.clock.total_minutes - start, BreedingRules.BREEDING_MINUTES, 0.001)
	assert_eq(egg.parent_ids, PackedStringArray(["ember", pip.id]))
	assert_eq(egg.generation, 1)
	assert_not_null(egg.genome)
	assert_gt(egg.notes.size(), 3, "inheritance is explained")
	assert_signal_emitted_with_parameters(session, "egg_laid", [egg])
	assert_string_contains(session.breeding_problem("ember", pip.id), "resting after breeding")


func test_cooldown_ends_after_resting() -> void:
	var pip := _hatch_pip(session)
	_rest_until(session)
	session.breed("ember", pip.id)
	assert_string_contains(_rest_until(session), "ready to breed again")
	assert_eq(session.breeding_problem("ember", pip.id), "")


func test_eligibility_rules() -> void:
	var pip := _hatch_pip(session)
	_rest_until(session)
	assert_string_contains(session.breeding_problem("ember", "moss"), "different species")
	assert_eq(session.breeding_problem("ember", "ember"), "Choose two different dragons")
	assert_eq(session.breeding_problem("ember", "nobody"), "Choose two dragons")
	session.adventurer_cell = Vector2i(10, 17)
	assert_eq(session.breeding_problem("ember", pip.id), "Breeding happens at Wayfarer's Camp")
	assert_null(session.breed("ember", pip.id))


func test_pack_holds_at_most_four_eggs() -> void:
	var pip := _hatch_pip(session)
	for i in BreedingRules.MAX_CARRIED_EGGS:
		_rest_until(session)
		while session.breeding_problem("ember", pip.id) != "":
			_rest_until(session)
		assert_not_null(session.breed("ember", pip.id), "egg %d" % (i + 1))
	_rest_until(session)
	assert_string_contains(session.breeding_problem("ember", pip.id), "already holds 4 eggs")


func test_hatched_offspring_keeps_the_eggs_genes_and_ancestry() -> void:
	var pip := _hatch_pip(session)
	_rest_until(session)
	var egg := session.breed("ember", pip.id)
	var camp := session.locations.get_by_id("camp")
	session.resolve_choice(camp, camp.encounter.get_choice("warm"))
	var child := session.hatch_egg(egg.id, "Kindle")
	assert_true(child.genome.same_as(egg.genome))
	assert_eq(child.parent_ids, PackedStringArray(["ember", pip.id]))
	assert_eq(child.generation, 1)
	assert_string_contains(child.origin, "bred from Ember and Pip")
	assert_eq(child.inheritance_notes, egg.notes)
	assert_true(session.lineage.has_entry(child.id))
	assert_eq(session.lineage.ancestors(child.id), PackedStringArray(["ember", pip.id]))
	assert_false(session.is_travelling(child.id), "the party is full: Kindle rests at camp")
	assert_eq(session.roster.size(), 4)


func test_party_is_chosen_at_camp_and_capped_at_three() -> void:
	var pip := _hatch_pip(session)
	session.adventurer_cell = Vector2i(10, 17)
	assert_eq(session.set_travelling("moss", false), "The party is chosen at Wayfarer's Camp")
	session.adventurer_cell = CAMP
	watch_signals(session)
	assert_eq(session.set_travelling("moss", false), "")
	assert_false(session.is_travelling("moss"))
	assert_signal_emitted(session, "party_changed")
	assert_eq(session.set_travelling("moss", true), "")
	assert_eq(session.party_ids.size(), 3)
	_rest_until(session)
	var egg := session.breed("ember", pip.id)
	session.resolve_choice(session.locations.get_by_id("camp"), session.locations.get_by_id("camp").encounter.get_choice("warm"))
	var child := session.hatch_egg(egg.id, "Kindle")
	assert_eq(session.set_travelling(child.id, true), "At most 3 dragons can travel with you")
	session.set_travelling("moss", false)
	assert_eq(session.set_travelling(child.id, true), "")
	assert_eq(session.party_ids, PackedStringArray(["ember", pip.id, child.id]))


func test_keen_sight_in_the_party_widens_scouting() -> void:
	assert_almost_eq(session.scouting_bonus(), 2 * TraitCatalog.SIGHT_PER_TIER, 0.0001, "Ember's Keen Sight II")
	assert_almost_eq(session.sight_radius(), OverworldSession.SIGHT_RADIUS + 0.3, 0.0001)
	var keen := _new_session()
	keen.roster.get_by_id("ember").genome.traits["keen_sight"] = 8
	var dull := _new_session()
	dull.adventurer_cell = CAMP
	dull.set_travelling("ember", false)
	dull.adventurer_cell = ElderwoodVale.START_CELL
	for s in [keen, dull]:
		s.travel(RegionMap.CELL_SIZE, s.map.cell_to_world(Vector2i(5, 17)))
		s.travel(RegionMap.CELL_SIZE, s.map.cell_to_world(Vector2i(6, 17)))
	assert_almost_eq(keen.sight_radius(), OverworldSession.SIGHT_RADIUS + 1.2, 0.0001)
	assert_eq(dull.scouting_bonus(), 0.0, "Moss alone has no Keen Sight")
	assert_gt(keen.fog.explored_count(), dull.fog.explored_count() + 15, "a keen-eyed party reveals more land")


func test_short_sight_narrows_scouting_only_without_a_better_scout() -> void:
	session.roster.get_by_id("moss").genome.traits["short_sight"] = 3
	assert_almost_eq(session.scouting_bonus(), 0.3, 0.0001, "Ember is still the best scout")
	session.adventurer_cell = CAMP
	session.set_travelling("ember", false)
	assert_almost_eq(session.scouting_bonus(), -0.3, 0.0001)


func test_same_actions_give_the_same_offspring() -> void:
	var a := _new_session()
	var b := _new_session()
	var genomes := []
	for s in [a, b]:
		var pip := _hatch_pip(s)
		_rest_until(s)
		genomes.append(s.breed("ember", pip.id).genome.to_dict())
	assert_eq(genomes[0], genomes[1])
