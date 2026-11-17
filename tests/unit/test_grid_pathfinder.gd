extends GutTest

func _map(rows: Array[String]) -> RegionMap:
	return RegionMap.from_rows("Test", rows)


func test_straight_path_includes_both_ends() -> void:
	var finder := GridPathfinder.new(_map([".....",]))
	var path := finder.find_path(Vector2i(0, 0), Vector2i(4, 0))
	assert_eq(path.size(), 5)
	assert_eq(path[0], Vector2i(0, 0))
	assert_eq(path[4], Vector2i(4, 0))


func test_routes_around_obstacles() -> void:
	var finder := GridPathfinder.new(_map([
		".....",
		".TTT.",
		".....",
	]))
	var path := finder.find_path(Vector2i(0, 1), Vector2i(4, 1))
	assert_gt(path.size(), 0)
	for cell in path:
		assert_ne(cell, Vector2i(2, 1))
		assert_ne(cell, Vector2i(1, 1))


func test_never_cuts_obstacle_corners_diagonally() -> void:
	var finder := GridPathfinder.new(_map([
		".T",
		"..",
	]))
	var path := finder.find_path(Vector2i(0, 0), Vector2i(1, 1))
	assert_eq(path, [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)] as Array[Vector2i])


func test_unreachable_or_blocked_targets_return_empty() -> void:
	var finder := GridPathfinder.new(_map([
		"..~..",
		"..~..",
	]))
	assert_eq(finder.find_path(Vector2i(0, 0), Vector2i(4, 0)).size(), 0, "river splits the map")
	assert_eq(finder.find_path(Vector2i(0, 0), Vector2i(2, 0)).size(), 0, "target is water")


func test_prefers_road_when_it_is_quicker() -> void:
	var finder := GridPathfinder.new(_map([
		"tttttt",
		"======",
	]))
	var path := finder.find_path(Vector2i(0, 0), Vector2i(5, 0))
	var on_road := 0
	for cell in path:
		if cell.y == 1:
			on_road += 1
	assert_gt(on_road, 2, "detours over the road instead of crossing woodland")


func test_estimate_minutes_uses_terrain() -> void:
	var finder := GridPathfinder.new(_map(["===", "..."]))
	var road: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	var meadow: Array[Vector2i] = [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)]
	assert_almost_eq(finder.estimate_minutes(road), 20.0, 0.001)
	assert_almost_eq(finder.estimate_minutes(meadow), 30.0, 0.001)


func test_world_points_start_at_walker_and_end_at_target_center() -> void:
	var map := _map(["....", "....", "...."])
	var finder := GridPathfinder.new(map)
	var path := finder.find_path(Vector2i(0, 0), Vector2i(3, 2))
	var start := Vector2(40, 20)
	var points := finder.to_world_points(path, start)
	assert_eq(points[0], start)
	assert_eq(points[points.size() - 1], map.cell_to_world(Vector2i(3, 2)))
	for p in points:
		assert_true(map.is_passable(map.world_to_cell(p)))


func test_smoothing_keeps_endpoints_and_rounds_corners() -> void:
	var raw := PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10)])
	var smooth := GridPathfinder.smooth(raw, 1)
	assert_eq(smooth[0], raw[0])
	assert_eq(smooth[smooth.size() - 1], raw[2])
	assert_false(smooth.has(Vector2(10, 0)), "the sharp corner is cut")


func test_known_only_mode_routes_through_explored_cells_only() -> void:
	var finder := GridPathfinder.new(_map(["....."]), true)
	assert_eq(finder.find_path(Vector2i(0, 0), Vector2i(4, 0)).size(), 0, "nothing explored yet")
	var seen: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	finder.reveal(seen)
	assert_eq(finder.find_path(Vector2i(0, 0), Vector2i(2, 0)).size(), 3)
	assert_eq(finder.find_path(Vector2i(0, 0), Vector2i(4, 0)).size(), 0, "target still unexplored")


func test_reveal_never_opens_obstacles() -> void:
	var finder := GridPathfinder.new(_map([".T."]), true)
	var all: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)]
	finder.reveal(all)
	assert_false(finder.is_routable(Vector2i(1, 0)))
	assert_eq(finder.find_path(Vector2i(0, 0), Vector2i(2, 0)).size(), 0)
