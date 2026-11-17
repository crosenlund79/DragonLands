extends GutTest
## Contracts between travel, clock, fog, pathfinding, locations and encounters.

var session: OverworldSession


func before_each() -> void:
	session = OverworldSession.new(ElderwoodVale.create_map(), ElderwoodVale.create_locations(),
		StartingParty.create(), ElderwoodVale.START_CELL, ElderwoodVale.START_MINUTES)
	session.begin()


func _walk(path: Array[Vector2i]) -> void:
	var follower := PathFollower.new()
	follower.set_path(session.pathfinder.to_world_points(path, session.map.cell_to_world(path[0])))
	while follower.is_active():
		var moved := follower.advance(8.0)
		session.travel(moved, follower.position)


func test_begin_explores_the_start_and_discovers_the_camp() -> void:
	assert_true(session.fog.is_explored(ElderwoodVale.START_CELL))
	assert_true(session.locations.is_discovered("camp"))
	assert_false(session.locations.is_discovered("nest"))
	assert_eq(session.area_name(session.adventurer_cell), "Wayfarer's Camp")


func test_travel_advances_clock_by_terrain() -> void:
	var start := session.clock.total_minutes
	var pos := session.map.cell_to_world(ElderwoodVale.START_CELL)  # road
	session.travel(RegionMap.CELL_SIZE, pos)
	assert_almost_eq(session.clock.total_minutes - start, 10.0, 0.001, "one road cell = 10 min")
	session.travel(RegionMap.CELL_SIZE, session.map.cell_to_world(Vector2i(4, 18)))  # meadow
	assert_almost_eq(session.clock.total_minutes - start, 25.0, 0.001, "plus one meadow cell = 15 min")


func test_no_time_passes_without_travel() -> void:
	var start := session.clock.total_minutes
	session.travel(0.0, session.map.cell_to_world(ElderwoodVale.START_CELL))
	assert_eq(session.clock.total_minutes, start)


func test_routes_only_through_explored_land_and_open_up_as_fog_clears() -> void:
	var far := Vector2i(30, 17)
	assert_eq(session.plan_route(far).size(), 0, "unexplored")
	var near := session.resolve_target(far)
	assert_ne(near, Vector2i(-1, -1))
	assert_true(session.fog.is_explored(near), "clicking into fog targets the explored edge")
	_walk(session.plan_route(near))
	assert_eq(session.adventurer_cell, near)
	assert_gt(session.resolve_target(far).x, near.x, "the frontier moved east as we walked")


func test_known_obstacles_and_off_map_clicks_are_refused() -> void:
	assert_true(session.fog.is_explored(Vector2i(8, 19)))
	assert_eq(session.resolve_target(Vector2i(8, 19)), Vector2i(-1, -1), "explored deep forest")
	assert_eq(session.resolve_target(Vector2i(-5, -5)), Vector2i(-1, -1), "outside the map")


func test_unexplored_obstacles_still_lead_toward_them() -> void:
	var toward := session.resolve_target(Vector2i(0, 0))  # fogged mountains to the north-west
	assert_ne(toward, Vector2i(-1, -1))
	assert_lt(toward.y, ElderwoodVale.START_CELL.y, "heads north")


func test_route_estimate_matches_time_spent_walking() -> void:
	session.fog.reveal(Vector2i(6, 18), 6.0)
	var target := Vector2i(6, 21)
	var path := session.plan_route(target)
	assert_gt(path.size(), 2)
	var estimate := session.pathfinder.estimate_minutes(path)
	var start := session.clock.total_minutes
	_walk(path)
	assert_almost_eq(session.clock.total_minutes - start, estimate, estimate * 0.2)


func test_entering_cells_discovers_nearby_locations() -> void:
	watch_signals(session.locations)
	session.fog.reveal(Vector2i(31, 14), 2.0)  # make the road north routable
	session.adventurer_cell = Vector2i(31, 14)
	session.travel(RegionMap.CELL_SIZE, session.map.cell_to_world(Vector2i(31, 13)))
	assert_true(session.locations.is_discovered("watchtower"))
	assert_signal_emitted_with_parameters(session.locations, "discovered", [session.locations.get_by_id("watchtower")])


func test_arriving_at_the_nest_opens_its_encounter_and_choices_cost_time() -> void:
	var nest := session.arrive(Vector2i(42, 6))
	assert_not_null(nest)
	assert_eq(nest.kind, Location.Kind.DRAGON_NEST)
	assert_true(session.locations.is_visited("nest"))
	var start := session.clock.total_minutes
	var text := session.resolve_choice(nest, nest.encounter.get_choice("approach"))
	assert_ne(text, "")
	assert_almost_eq(session.clock.total_minutes - start, 30.0, 0.001)
	assert_eq(session.resolve_choice(nest, nest.encounter.get_choice("leave")), "", "leaving closes immediately")


func test_climbing_the_watchtower_reveals_the_distant_nest() -> void:
	var tower := session.arrive(Vector2i(32, 9))
	assert_eq(tower.kind, Location.Kind.LOOKOUT)
	assert_false(session.locations.is_discovered("nest"))
	session.resolve_choice(tower, tower.encounter.get_choice("climb"))
	assert_true(session.locations.is_discovered("nest"))
	assert_true(session.pathfinder.is_routable(Vector2i(42, 6)), "revealed land becomes routable")


func test_arriving_elsewhere_returns_no_location() -> void:
	assert_null(session.arrive(Vector2i(10, 17)))
