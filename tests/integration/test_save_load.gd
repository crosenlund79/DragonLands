extends GutTest
## Save/load round-trips the session without duplicating eggs or dragons.

var _path: String


func before_each() -> void:
	_path = "user://test_save_%d.json" % Time.get_ticks_usec()


func after_each() -> void:
	if FileAccess.file_exists(_path):
		DirAccess.remove_absolute(_path)


func _new_session() -> OverworldSession:
	return OverworldSession.new(ElderwoodVale.create_map(), ElderwoodVale.create_locations(),
		StartingDragons.create_roster(), ElderwoodVale.START_CELL, ElderwoodVale.START_MINUTES)


## A session that has explored, visited, taken the egg, hatched it, and holds nothing else.
func _played_session(hatch: bool) -> OverworldSession:
	var s := _new_session()
	s.begin()
	s.fog.reveal(Vector2i(31, 14), 3.0)
	s.locations.discover_explored(s.fog)
	var tower := s.arrive(Vector2i(32, 9))
	s.resolve_choice(tower, tower.encounter.get_choice("climb"))
	var nest := s.locations.get_by_id("nest")
	s.resolve_choice(nest, nest.encounter.get_choice("egg"))
	s.adventurer_cell = Vector2i(32, 10)
	s.clock.advance(200.0)
	if hatch:
		var egg := s.eggs.all()[0]
		s.clock.advance(egg.incubation_minutes)
		s.hatch_egg(egg.id, "Pip")
	return s


func _round_trip(source: OverworldSession) -> OverworldSession:
	assert_eq(SaveGame.write(SaveGame.capture(source), _path), OK)
	var loaded := _new_session()
	assert_true(SaveGame.restore(loaded, SaveGame.read(_path)))
	return loaded


func test_round_trip_restores_clock_map_discoveries_and_position() -> void:
	var source := _played_session(false)
	var loaded := _round_trip(source)
	assert_eq(loaded.clock.total_minutes, source.clock.total_minutes)
	assert_eq(loaded.adventurer_cell, Vector2i(32, 10))
	assert_eq(loaded.fog.to_bytes(), source.fog.to_bytes())
	assert_true(loaded.locations.is_discovered("nest"))
	assert_true(loaded.locations.is_visited("watchtower"))
	assert_false(loaded.locations.is_visited("nest"))
	assert_true(loaded.pathfinder.is_routable(Vector2i(42, 6)), "explored land is routable again")
	assert_false(loaded.pathfinder.is_routable(Vector2i(10, 30)), "unexplored land stays closed")


func test_round_trip_keeps_egg_and_its_incubation_progress() -> void:
	var source := _played_session(false)
	var loaded := _round_trip(source)
	assert_eq(loaded.eggs.size(), 1)
	var a := source.eggs.all()[0]
	var b := loaded.eggs.all()[0]
	assert_eq(b.to_dict(), a.to_dict())
	assert_almost_eq(b.progress(loaded.clock.total_minutes), a.progress(source.clock.total_minutes), 0.0001)
	assert_true(loaded.egg_taken("nest"))
	var nest := loaded.locations.get_by_id("nest")
	assert_eq(loaded.resolve_choice(nest, nest.encounter.get_choice("egg")), "", "no second egg after loading")
	assert_eq(loaded.eggs.size(), 1)


func test_clock_keeps_advancing_incubation_after_load() -> void:
	var loaded := _round_trip(_played_session(false))
	var egg := loaded.eggs.all()[0]
	watch_signals(loaded)
	loaded.clock.advance(egg.remaining_minutes(loaded.clock.total_minutes))
	assert_true(egg.is_ready(loaded.clock.total_minutes))
	assert_signal_emit_count(loaded, "egg_ready", 1)


func test_round_trip_keeps_owned_dragons_without_duplicates() -> void:
	var source := _played_session(true)
	var loaded := _round_trip(source)
	assert_eq(loaded.roster.to_array(), source.roster.to_array())
	assert_eq(loaded.roster.size(), 3)
	assert_eq(loaded.roster.all()[2].name, "Pip")
	assert_eq(loaded.eggs.size(), 0)
	assert_true(SaveGame.restore(loaded, SaveGame.read(_path)), "loading the same save again")
	assert_eq(loaded.roster.size(), 3, "...still three dragons")
	assert_eq(loaded.eggs.size(), 0)


func test_new_ids_after_load_never_collide() -> void:
	var loaded := _round_trip(_played_session(true))
	var fresh := loaded.new_id("dragon")
	assert_null(loaded.roster.get_by_id(fresh))


func test_saving_a_loaded_game_is_stable() -> void:
	var source := _played_session(true)
	var loaded := _round_trip(source)
	assert_eq(SaveGame.capture(loaded), SaveGame.capture(source))


func test_missing_or_corrupt_saves_leave_the_session_untouched() -> void:
	var s := _new_session()
	s.begin()
	var before := SaveGame.capture(s)
	assert_eq(SaveGame.read(_path), {}, "missing file")
	var file := FileAccess.open(_path, FileAccess.WRITE)
	file.store_string("{ not json")
	file.close()
	assert_eq(SaveGame.read(_path), {})
	assert_push_warning("not a valid save file")
	for e in get_errors():
		e.handled = true  # JSON parser's own error
	assert_false(SaveGame.restore(s, {"version": 99}))
	assert_push_warning("cannot load save")
	var bad := before.duplicate(true)
	bad.dragons = [bad.dragons[0], bad.dragons[0]]
	assert_false(SaveGame.restore(s, bad), "duplicate dragon ids are rejected")
	assert_push_warning("cannot load save")
	assert_eq(SaveGame.capture(s), before)
