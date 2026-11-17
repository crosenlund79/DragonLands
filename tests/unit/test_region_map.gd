extends GutTest

const ROWS: Array[String] = ["..T", "=B~", "Mrt"]


func test_parses_rows_into_terrain_types() -> void:
	var map := RegionMap.from_rows("Test", ROWS)
	assert_eq(map.size, Vector2i(3, 3))
	assert_eq(map.get_terrain(Vector2i(2, 0)), Terrain.Type.FOREST)
	assert_eq(map.get_terrain(Vector2i(1, 1)), Terrain.Type.BRIDGE)
	assert_eq(map.get_terrain(Vector2i(1, 2)), Terrain.Type.ROCKY)


func test_passability_and_bounds() -> void:
	var map := RegionMap.from_rows("Test", ROWS)
	assert_true(map.is_passable(Vector2i(0, 0)))
	assert_false(map.is_passable(Vector2i(2, 1)), "water blocks")
	assert_false(map.is_passable(Vector2i(0, 2)), "mountains block")
	assert_false(map.is_passable(Vector2i(-1, 0)), "outside the map blocks")
	assert_eq(map.get_terrain(Vector2i(5, 5)), -1)


func test_cell_world_round_trip() -> void:
	var map := RegionMap.from_rows("Test", ROWS)
	var center := map.cell_to_world(Vector2i(2, 1))
	assert_eq(center, Vector2(2.5, 1.5) * RegionMap.CELL_SIZE)
	assert_eq(map.world_to_cell(center), Vector2i(2, 1))
	assert_eq(map.world_to_cell(Vector2(-1, 10)), Vector2i(-1, 0))


func test_road_is_fastest_and_woods_slower_than_meadow() -> void:
	assert_lt(Terrain.minutes_per_cell(Terrain.Type.ROAD), Terrain.minutes_per_cell(Terrain.Type.MEADOW))
	assert_gt(Terrain.minutes_per_cell(Terrain.Type.WOODS), Terrain.minutes_per_cell(Terrain.Type.MEADOW))


func test_unknown_symbol_reports_error_and_defaults_to_meadow() -> void:
	var rows: Array[String] = [".?"]
	var map := RegionMap.from_rows("Bad", rows)
	assert_eq(map.get_terrain(Vector2i(1, 0)), Terrain.Type.MEADOW)
	assert_push_error("unknown symbol")
