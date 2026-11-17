extends GutTest
## The handcrafted region is well-formed and every location can be reached from the start.

func test_layout_is_rectangular_and_parses_cleanly() -> void:
	var map := ElderwoodVale.create_map()
	assert_eq(map.size, Vector2i(48, 36))
	for row in ElderwoodVale.ROWS:
		assert_eq(row.length(), 48)


func test_start_and_locations_stand_on_passable_cells() -> void:
	var map := ElderwoodVale.create_map()
	assert_true(map.is_passable(ElderwoodVale.START_CELL))
	for location in ElderwoodVale.create_locations().all():
		assert_true(map.is_passable(location.cell), location.name)


func test_every_location_is_reachable_from_the_start() -> void:
	var map := ElderwoodVale.create_map()
	var finder := GridPathfinder.new(map)
	for location in ElderwoodVale.create_locations().all():
		assert_gt(finder.find_path(ElderwoodVale.START_CELL, location.cell).size(), 1, location.name)


func test_contains_the_required_features() -> void:
	var map := ElderwoodVale.create_map()
	var counts := {}
	for y in map.size.y:
		for x in map.size.x:
			var t := map.get_terrain(Vector2i(x, y))
			counts[t] = counts.get(t, 0) + 1
	for t in [Terrain.Type.ROAD, Terrain.Type.WATER, Terrain.Type.BRIDGE, Terrain.Type.MOUNTAIN, Terrain.Type.FOREST]:
		assert_gt(counts.get(t, 0), 0, Terrain.display_name(t))
	var kinds := ElderwoodVale.create_locations().all().map(func(l: Location) -> int: return l.kind)
	assert_has(kinds, Location.Kind.DRAGON_NEST)
	assert_gte(kinds.size(), 4, "a few discoverable locations")
