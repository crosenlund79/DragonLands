extends GutTest
## Lineage book and breeding rules in isolation.

func _dragon(id: String, parents: Array = [], generation: int = 0, born: float = -10000.0) -> DragonRecord:
	var d := DragonRecord.new()
	d.id = id
	d.name = id.capitalize()
	d.species_id = "cinderwing"
	d.born_at_minutes = born
	d.parent_ids = PackedStringArray(parents)
	d.generation = generation
	d.genome = StartingDragons.canonical_genome("ember")
	return d


func test_lineage_records_once_and_walks_ancestors() -> void:
	var book := LineageBook.new()
	for d in [_dragon("a"), _dragon("b"), _dragon("c", ["a", "b"], 1), _dragon("d", ["c", "a"], 2)]:
		book.record(d)
		book.record(d)
	assert_eq(book.size(), 4)
	assert_eq(book.parents_of("d"), PackedStringArray(["c", "a"]))
	assert_eq(book.ancestors("d"), PackedStringArray(["c", "a", "b"]), "each ancestor listed once")
	var copy := LineageBook.new()
	assert_true(copy.load_array(JSON.parse_string(JSON.stringify(book.to_array()))))
	assert_eq(copy.to_array(), book.to_array())
	assert_false(copy.load_array([{"id": "x"}, {"id": "x"}]))
	assert_eq(copy.size(), 4, "a rejected load changes nothing")


func test_pair_rules() -> void:
	var now := 0.0
	var a := _dragon("a")
	var b := _dragon("b")
	assert_eq(BreedingRules.pair_problem(a, b, now), "")
	var young := _dragon("young", [], 0, now - 60.0)
	assert_string_contains(BreedingRules.pair_problem(a, young, now), "still a hatchling")
	var juvenile := _dragon("juv", [], 0, now - 2.0 * WorldClock.MINUTES_PER_DAY)
	assert_string_contains(BreedingRules.pair_problem(a, juvenile, now), "still a juvenile")
	a.last_bred_at = now - 60.0
	assert_string_contains(BreedingRules.pair_problem(a, b, now), "resting after breeding")
	assert_almost_eq(BreedingRules.cooldown_left(a, now), BreedingRules.COOLDOWN_MINUTES - 60.0, 0.001)
	var fern := _dragon("fern")
	fern.species_id = "fernback"
	assert_string_contains(BreedingRules.pair_problem(b, fern, now), "different species")


func test_thresholds_reached_by_float_sums_count_as_reached() -> void:
	# Regression: an age a hair below "adult" showed "still a juvenile (adult in 0m)" forever,
	# because the rest milestone ignored the sliver. Same for breeding cooldowns.
	for i in 300:
		var born := 437.0 + i * (100.0 / 7.0) + 1.0 / 3.0
		var dragon := _dragon("d%d" % i, [], 0, born)
		var clock := WorldClock.new(born)
		for k in (i % 23) + 2:
			clock.advance(0.37 * (15.0 + k / 9.0))
		clock.advance(dragon.species().adult_at_minutes - dragon.age_minutes(clock.total_minutes))
		assert_eq(dragon.stage(clock.total_minutes), DragonSpecies.Stage.ADULT, "dragon %d" % i)
		dragon.last_bred_at = clock.total_minutes
		clock.advance(BreedingRules.cooldown_left(dragon, clock.total_minutes))
		assert_eq(BreedingRules.dragon_problem(dragon, clock.total_minutes), "", "cooldown %d" % i)
