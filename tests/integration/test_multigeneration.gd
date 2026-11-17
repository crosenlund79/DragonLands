extends GutTest
## A scripted multi-generation breeding run from a fresh game, using only session actions.
## Each generation pairs the two best Keen Sight dragons, hatches the egg and grows it up.

const CAMP := Vector2i(3, 16)


func _camp_choice(s: OverworldSession, id: String) -> String:
	var camp := s.locations.get_by_id("camp")
	for c in s.choices_for(camp):
		if c.id == id:
			return s.resolve_choice(camp, c)
	return "<not offered>"


## The newest adult (deepest generation) paired with the best remaining scout.
func _best_pair(s: OverworldSession) -> Array[DragonRecord]:
	var adults: Array[DragonRecord] = []
	for d in s.roster.all():
		if d.species_id == "cinderwing" and d.stage(s.clock.total_minutes) == DragonSpecies.Stage.ADULT:
			adults.append(d)
	if adults.size() < 2:
		return adults
	adults.sort_custom(func(x: DragonRecord, y: DragonRecord) -> bool: return x.generation > y.generation)
	var newest: DragonRecord = adults.pop_front()
	adults.sort_custom(func(x: DragonRecord, y: DragonRecord) -> bool:
		return TraitCatalog.scouting_of(x.genome) > TraitCatalog.scouting_of(y.genome))
	return [newest, adults[0]]


func test_four_generations_from_a_fresh_game() -> void:
	var s := OverworldSession.new(ElderwoodVale.create_map(), ElderwoodVale.create_locations(),
		StartingDragons.create_roster(), ElderwoodVale.START_CELL, ElderwoodVale.START_MINUTES)
	s.begin()
	var nest := s.locations.get_by_id("nest")
	s.resolve_choice(nest, nest.encounter.get_choice("egg"))
	s.adventurer_cell = CAMP
	_camp_choice(s, "warm")
	s.hatch_egg(s.eggs.all()[0].id, "Pip")
	var latest: DragonRecord = s.roster.all()[2]  # Pip
	for generation in range(1, 5):
		var pair := _best_pair(s)
		while latest.stage(s.clock.total_minutes) != DragonSpecies.Stage.ADULT \
				or s.breeding_problem(pair[0].id, pair[1].id) != "":
			assert_ne(_camp_choice(s, "rest_until"), "<not offered>", "always something to wait for")
			pair = _best_pair(s)
		var egg := s.breed(pair[0].id, pair[1].id)
		assert_not_null(egg)
		_camp_choice(s, "warm")
		var child := s.hatch_egg(egg.id, "Gen%d" % generation)
		assert_not_null(child)
		latest = child
		assert_eq(child.generation, maxi(pair[0].generation, pair[1].generation) + 1)
	var deepest: DragonRecord = s.roster.all().reduce(func(m: DragonRecord, d: DragonRecord) -> DragonRecord:
		return d if d.generation > m.generation else m)
	assert_eq(deepest.generation, 4, "four generations deep")
	assert_has(s.lineage.ancestors(deepest.id), "ember", "Ember is in every bloodline")
	var ids := {}
	for d in s.roster.all():
		assert_false(ids.has(d.id), "unique id %s" % d.id)
		ids[d.id] = true
		assert_not_null(d.genome)
	assert_eq(s.roster.size(), 7, "Ember, Moss, Pip + four offspring")
	assert_eq(s.lineage.size(), 7)
	var path := "user://test_multigen_%d.json" % Time.get_ticks_usec()
	SaveGame.write(SaveGame.capture(s), path)
	var loaded := OverworldSession.new(ElderwoodVale.create_map(), ElderwoodVale.create_locations(),
		StartingDragons.create_roster(), ElderwoodVale.START_CELL, ElderwoodVale.START_MINUTES)
	assert_true(SaveGame.restore(loaded, SaveGame.read(path)))
	assert_eq(SaveGame.capture(loaded), SaveGame.capture(s))
	DirAccess.remove_absolute(path)
