extends GutTest
## Save v2 round trips and compatibility with genuine Prototype 002 (version 1) saves.

const P002_WITH_PIP := "res://tests/fixtures/p002_save_with_pip.json"
const P002_WITH_EGG := "res://tests/fixtures/p002_save_with_egg.json"
var _path: String


func before_each() -> void:
	_path = "user://test_compat_%d.json" % Time.get_ticks_usec()


func after_each() -> void:
	if FileAccess.file_exists(_path):
		DirAccess.remove_absolute(_path)


func _new_session() -> OverworldSession:
	return OverworldSession.new(ElderwoodVale.create_map(), ElderwoodVale.create_locations(),
		StartingDragons.create_roster(), ElderwoodVale.START_CELL, ElderwoodVale.START_MINUTES)


func _load(path: String) -> OverworldSession:
	var s := _new_session()
	assert_true(SaveGame.restore(s, SaveGame.read(path)), path)
	return s


func test_prototype_002_save_with_a_hatched_dragon_loads() -> void:
	var raw := SaveGame.read(P002_WITH_PIP)
	assert_eq(int(raw.version), 1)
	var s := _load(P002_WITH_PIP)
	assert_eq(s.roster.all().map(func(d: DragonRecord) -> String: return d.name), ["Ember", "Moss", "Pip"])
	assert_eq(s.party_ids, PackedStringArray(["ember", "moss", "dragon-2"]))
	assert_eq(s.lineage.size(), 3)
	assert_true(s.roster.get_by_id("ember").genome.same_as(StartingDragons.canonical_genome("ember")))
	var pip := s.roster.get_by_id("dragon-2")
	assert_not_null(pip.genome)
	assert_true(pip.genome.same_as(SaveGame.legacy_genome(pip)))
	assert_eq(pip.traits.temperament, "Stubborn", "identity preserved")
	assert_eq(s.clock.total_minutes, float(raw.clock_minutes))
	assert_true(s.egg_taken("nest"))


func test_upgraded_genes_are_stable_across_loads() -> void:
	var first := _load(P002_WITH_PIP)
	var second := _load(P002_WITH_PIP)
	assert_eq(SaveGame.capture(first), SaveGame.capture(second))


func test_prototype_002_egg_gets_genes_from_its_own_seed() -> void:
	var s := _load(P002_WITH_EGG)
	assert_eq(s.eggs.size(), 1)
	var egg := s.eggs.all()[0]
	assert_true(egg.genome.same_as(GeneticsEngine.wild(egg.species(), egg.seed)))
	assert_true(_load(P002_WITH_EGG).eggs.all()[0].genome.same_as(egg.genome))


func test_upgraded_save_round_trips_as_version_2() -> void:
	var s := _load(P002_WITH_PIP)
	SaveGame.write(SaveGame.capture(s), _path)
	assert_eq(int(SaveGame.read(_path).version), 2)
	assert_eq(SaveGame.capture(_load(_path)), SaveGame.capture(s))


func test_version_2_preserves_breeding_state_without_duplicates() -> void:
	var s := _load(P002_WITH_PIP)
	s.adventurer_cell = Vector2i(3, 16)
	var pip := s.roster.get_by_id("dragon-2")
	s.clock.advance(5 * WorldClock.MINUTES_PER_DAY)
	var egg := s.breed("ember", pip.id)
	s.clock.advance(egg.incubation_minutes)
	var child := s.hatch_egg(egg.id, "Kindle")
	s.set_travelling("moss", false)
	s.set_travelling(child.id, true)
	var egg2_problem := s.breeding_problem("ember", pip.id)
	assert_string_contains(egg2_problem, "resting")
	SaveGame.write(SaveGame.capture(s), _path)
	var loaded := _load(_path)
	assert_eq(SaveGame.capture(loaded), SaveGame.capture(s))
	var kindle := loaded.roster.get_by_id(child.id)
	assert_true(kindle.genome.same_as(child.genome))
	assert_eq(kindle.parent_ids, PackedStringArray(["ember", "dragon-2"]))
	assert_eq(kindle.generation, 1)
	assert_eq(kindle.inheritance_notes, child.inheritance_notes)
	assert_eq(loaded.party_ids, PackedStringArray(["ember", "dragon-2", child.id]))
	assert_eq(loaded.breeding_problem("ember", pip.id), egg2_problem, "cooldowns survive loading")
	assert_true(SaveGame.restore(loaded, SaveGame.read(_path)), "load again")
	assert_eq(loaded.roster.size(), 4)
	assert_eq(loaded.lineage.size(), 4)


func test_invalid_version_2_data_is_rejected_untouched() -> void:
	var s := _load(P002_WITH_PIP)
	var good := SaveGame.capture(s)
	var bad := good.duplicate(true)
	bad.party = ["ember", "ember"]
	assert_false(SaveGame.restore(s, bad))
	assert_push_warning("cannot load save")
	bad = good.duplicate(true)
	bad.dragons[0].genome = {}
	assert_false(SaveGame.restore(s, bad), "version 2 dragons must have genes")
	assert_push_warning("cannot load save")
	assert_eq(SaveGame.capture(s), good)
