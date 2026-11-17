class_name GridPathfinder
extends RefCounted
## Obstacle-aware, terrain-weighted A* over a RegionMap.
## Diagonal steps are allowed only when they do not cut an obstacle corner.
## With `known_only`, cells stay blocked until reveal() marks them explored, so
## routes never lead through (or leak the layout of) unexplored land.

var _map: RegionMap
var _astar := AStarGrid2D.new()


func _init(map: RegionMap, known_only: bool = false) -> void:
	_map = map
	_astar.region = Rect2i(Vector2i.ZERO, map.size)
	_astar.cell_size = Vector2.ONE
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_astar.update()
	for y in map.size.y:
		for x in map.size.x:
			var cell := Vector2i(x, y)
			var terrain := map.get_terrain(cell)
			# Weight = travel minutes relative to the fastest terrain (road), so the
			# shortest weighted path is also the quickest in world time.
			_astar.set_point_weight_scale(cell, Terrain.minutes_per_cell(terrain) / 10.0)
			_astar.set_point_solid(cell, known_only or not Terrain.is_passable(terrain))


## Opens explored passable cells for routing (used with `known_only`).
func reveal(cells: Array[Vector2i]) -> void:
	for cell in cells:
		if _map.is_passable(cell):
			_astar.set_point_solid(cell, false)


func is_routable(cell: Vector2i) -> bool:
	return _map.is_inside(cell) and not _astar.is_point_solid(cell)


## Cells from `from` to `to` inclusive; empty when either end is blocked or unreachable.
func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not is_routable(from) or not is_routable(to):
		return result
	result.assign(_astar.get_id_path(from, to))
	return result


## Estimated in-game minutes to walk the given cell path (matches OverworldSession travel).
func estimate_minutes(path: Array[Vector2i]) -> float:
	var total := 0.0
	for i in range(1, path.size()):
		var a := path[i - 1]
		var b := path[i]
		var step := Vector2(b - a).length()
		var minutes_a := Terrain.minutes_per_cell(_map.get_terrain(a))
		var minutes_b := Terrain.minutes_per_cell(_map.get_terrain(b))
		total += step * 0.5 * (minutes_a + minutes_b)
	return total


## World-space waypoints for a cell path. The first point is replaced by `start`
## (the walker's exact position) and corners are rounded with Chaikin smoothing.
func to_world_points(path: Array[Vector2i], start: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for cell in path:
		points.append(_map.cell_to_world(cell))
	if points.size() > 0:
		points[0] = start
	return smooth(points, 2)


static func smooth(points: PackedVector2Array, iterations: int) -> PackedVector2Array:
	var current := points
	for _i in iterations:
		if current.size() < 3:
			return current
		var next := PackedVector2Array([current[0]])
		for i in current.size() - 1:
			var a := current[i]
			var b := current[i + 1]
			next.append(a.lerp(b, 0.25))
			next.append(a.lerp(b, 0.75))
		next.append(current[current.size() - 1])
		current = next
	return current
