extends GutTest
## Dragon records, species definitions and the roster.

func _record(id: String = "dragon-1") -> DragonRecord:
	var r := DragonRecord.new()
	r.id = id
	r.name = "Cinder"
	r.species_id = "cinderwing"
	r.born_at_minutes = 600.0
	r.origin = "Hatched at Wayfarer's Camp"
	r.traits = {"temperament": "Bold", "markings": "Gold-rimmed scales"}
	return r


func test_species_catalog_defines_the_two_existing_species_only() -> void:
	var cinder := SpeciesCatalog.get_species("cinderwing")
	var fern := SpeciesCatalog.get_species("fernback")
	assert_eq(cinder.element, "Fire")
	assert_true(cinder.flies)
	assert_false(fern.flies)
	assert_gt(cinder.incubation_minutes, 0.0)
	assert_eq(cinder.egg_art, "eggs/cinderwing")
	assert_null(SpeciesCatalog.get_species("unknown"))
	assert_eq(SpeciesCatalog.DATA.size(), 2, "no new species in Prototype 002")


func test_growth_stage_follows_age() -> void:
	var r := _record()
	var s := r.species()
	assert_eq(r.stage(600.0), DragonSpecies.Stage.HATCHLING)
	assert_eq(r.stage(600.0 + s.juvenile_at_minutes), DragonSpecies.Stage.JUVENILE)
	assert_eq(r.stage(600.0 + s.adult_at_minutes), DragonSpecies.Stage.ADULT)
	assert_eq(r.age_minutes(500.0), 0.0, "never negative")


func test_art_and_flight_follow_growth_stage() -> void:
	var r := _record()
	var s := r.species()
	assert_eq(r.art_at(600.0), "dragons/cinderwing_hatchling")
	assert_false(s.flies_at(r.stage(600.0)), "hatchlings walk")
	assert_eq(r.art_at(600.0 + s.adult_at_minutes), s.adult_art)
	assert_true(s.flies_at(r.stage(600.0 + s.adult_at_minutes)))
	r.art = "dragons/ember"
	assert_eq(r.art_at(600.0), "dragons/ember", "individual art wins")


func test_record_round_trips_including_reserved_genetics_fields() -> void:
	var r := _record()
	r.genome = {"future": {"locus": ["a", "b"], "weight": 0.5}}  # JSON numbers come back as floats
	r.parent_ids = PackedStringArray(["dragon-a", "dragon-b"])
	r.generation = 2
	var copy := DragonRecord.from_dict(JSON.parse_string(JSON.stringify(r.to_dict())))
	assert_eq(copy.to_dict(), r.to_dict())
	assert_eq(copy.generation, 2)
	assert_eq(copy.parent_ids, PackedStringArray(["dragon-a", "dragon-b"]))


func test_new_records_start_as_wild_stock_with_empty_genetics() -> void:
	var r := DragonRecord.new()
	assert_eq(r.generation, 0)
	assert_true(r.parent_ids.is_empty())
	assert_true(r.genome.is_empty())
	assert_true(r.mutations.is_empty())


func test_invalid_records_are_rejected() -> void:
	assert_null(DragonRecord.from_dict({"name": "No id", "species": "cinderwing"}))
	assert_null(DragonRecord.from_dict({"id": "x", "species": "griffin"}))


func test_roster_refuses_duplicate_ids_and_keeps_order() -> void:
	var roster := StartingDragons.create_roster()
	assert_eq(roster.size(), 2)
	assert_false(roster.add(_record("ember")), "id already owned")
	assert_true(roster.add(_record("dragon-1")))
	assert_eq(roster.index_of("dragon-1"), 2)
	assert_eq(roster.all().map(func(d: DragonRecord) -> String: return d.name), ["Ember", "Moss", "Cinder"])


func test_roster_load_replaces_and_rejects_duplicates() -> void:
	var roster := StartingDragons.create_roster()
	var saved := roster.to_array()
	assert_true(roster.load_array(saved))
	assert_true(roster.load_array(saved))
	assert_eq(roster.size(), 2, "loading twice never duplicates")
	assert_false(roster.load_array([saved[0], saved[0]]))
	assert_eq(roster.size(), 2, "a rejected load changes nothing")


func test_ember_and_moss_keep_their_identity() -> void:
	var roster := StartingDragons.create_roster()
	var ember := roster.get_by_id("ember")
	var moss := roster.get_by_id("moss")
	assert_eq(ember.species().short_name, "Cinderwing")
	assert_eq(moss.species().short_name, "Fernback")
	assert_eq(ember.art_at(0.0), "dragons/ember")
	assert_eq(moss.art_at(0.0), "dragons/moss")
	assert_eq(ember.stage(0.0), DragonSpecies.Stage.ADULT)
	assert_true(ember.species().flies_at(ember.stage(0.0)))
	assert_false(moss.species().flies_at(moss.stage(0.0)))
