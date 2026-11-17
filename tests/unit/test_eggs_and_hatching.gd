extends GutTest
## Egg records, incubation progress, the egg collection and hatching.

func _egg(id: String = "egg-1", acquired: float = 100.0, seed: int = 42) -> EggRecord:
	return EggRecord.create(id, "cinderwing", "nest", acquired, seed)


func test_new_egg_uses_species_incubation_time() -> void:
	var egg := _egg()
	assert_eq(egg.incubation_minutes, SpeciesCatalog.get_species("cinderwing").incubation_minutes)
	assert_eq(egg.progress(100.0), 0.0)
	assert_false(egg.is_ready(100.0))


func test_incubation_progresses_with_world_time() -> void:
	var egg := _egg()
	var half := 100.0 + egg.incubation_minutes * 0.5
	assert_almost_eq(egg.progress(half), 0.5, 0.0001)
	assert_almost_eq(egg.remaining_minutes(half), egg.incubation_minutes * 0.5, 0.0001)
	assert_true(egg.is_ready(100.0 + egg.incubation_minutes))
	assert_eq(egg.progress(1e9), 1.0, "clamped")
	assert_eq(egg.remaining_minutes(1e9), 0.0)


func test_egg_round_trips() -> void:
	var egg := _egg("egg-7", 321.5, 987654)
	var copy := EggRecord.from_dict(JSON.parse_string(JSON.stringify(egg.to_dict())))
	assert_eq(copy.to_dict(), egg.to_dict())
	assert_null(EggRecord.from_dict({"id": "", "species": "cinderwing"}))


func test_collection_refuses_duplicates_and_finds_soonest() -> void:
	var eggs := EggCollection.new()
	assert_true(eggs.add(_egg("egg-1", 100.0)))
	assert_false(eggs.add(_egg("egg-1", 100.0)))
	assert_true(eggs.add(_egg("egg-2", 50.0)))
	assert_eq(eggs.soonest(200.0).id, "egg-2")
	assert_eq(eggs.remove("egg-2").id, "egg-2")
	assert_null(eggs.remove("egg-2"))
	assert_eq(eggs.size(), 1)


func test_collection_load_replaces_without_duplicates() -> void:
	var eggs := EggCollection.new()
	eggs.add(_egg())
	var saved := eggs.to_array()
	assert_true(eggs.load_array(saved))
	assert_true(eggs.load_array(saved))
	assert_eq(eggs.size(), 1)
	assert_false(eggs.load_array([saved[0], saved[0]]))
	assert_eq(eggs.size(), 1)


func test_hatching_creates_a_named_wild_hatchling() -> void:
	var egg := _egg()
	var now := 100.0 + egg.incubation_minutes
	var dragon := Hatching.hatch(egg, "dragon-3", "  Pip  ", now, "Hatched at camp")
	assert_eq(dragon.id, "dragon-3")
	assert_eq(dragon.name, "Pip")
	assert_eq(dragon.species_id, "cinderwing")
	assert_eq(dragon.born_at_minutes, now)
	assert_eq(dragon.stage(now), DragonSpecies.Stage.HATCHLING)
	assert_eq(dragon.generation, 0)
	assert_true(dragon.parent_ids.is_empty())
	assert_has(egg.species().temperaments, dragon.traits.temperament)
	assert_has(egg.species().markings, dragon.traits.markings)


func test_same_egg_always_hatches_the_same_characteristics() -> void:
	var a := Hatching.hatch(_egg("egg-1", 0.0, 1234), "d1", "A", 900.0, "")
	var b := Hatching.hatch(_egg("egg-1", 0.0, 1234), "d2", "B", 900.0, "")
	assert_eq(a.traits, b.traits)


func test_names_are_sanitised_with_a_fallback() -> void:
	assert_eq(Hatching.sanitize_name("   ", "Cinder"), "Cinder")
	assert_eq(Hatching.sanitize_name("Sir   Flames  a  Lot", "x"), "Sir Flames a Lot")
	assert_eq(Hatching.sanitize_name("A very very long dragon name", "x").length(), Hatching.MAX_NAME_LENGTH)
	var egg := _egg()
	assert_has(egg.species().hatchling_names, Hatching.suggest_name(egg, 0))
	assert_ne(Hatching.suggest_name(egg, 0), Hatching.suggest_name(egg, 1))


func test_advancing_by_the_remaining_time_always_makes_the_egg_ready() -> void:
	# Regression: with a clock built from many full-precision travel increments, the old
	# "progress >= 1.0" check left ~9% of eggs a hair short of ready after "keep warm".
	for i in 500:
		var egg := _egg("egg-%d" % i, 480.0 + i * (100.0 / 7.0) + 1.0 / 3.0)
		var clock := WorldClock.new(egg.acquired_at_minutes)
		for k in (i % 37) + 3:
			clock.advance(0.37 * (15.0 + k / 9.0))  # irregular travel increments
		clock.advance(egg.remaining_minutes(clock.total_minutes))
		assert_true(egg.is_ready(clock.total_minutes), "egg %d" % i)
		assert_eq(egg.progress(clock.total_minutes), 1.0)
