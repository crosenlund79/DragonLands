class_name LocationRegistry
extends RefCounted
## All locations of a region plus their discovered / visited state.

signal discovered(location: Location)

var _locations: Array[Location] = []
var _discovered: Dictionary = {}
var _visited: Dictionary = {}


func add(location: Location) -> void:
	_locations.append(location)


func all() -> Array[Location]:
	return _locations.duplicate()


func get_by_id(id: String) -> Location:
	for location in _locations:
		if location.id == id:
			return location
	return null


func at_cell(cell: Vector2i) -> Location:
	for location in _locations:
		if location.cell == cell:
			return location
	return null


func is_discovered(id: String) -> bool:
	return _discovered.has(id)


func is_visited(id: String) -> bool:
	return _visited.has(id)


func mark_visited(id: String) -> void:
	_visited[id] = true


## Marks every location whose cell is explored as discovered; returns the new ones.
func discover_explored(fog: FogOfWar) -> Array[Location]:
	var found: Array[Location] = []
	for location in _locations:
		if not _discovered.has(location.id) and fog.is_explored(location.cell):
			_discovered[location.id] = true
			found.append(location)
			discovered.emit(location)
	return found


## Closest discovered location within `radius` cells, or null.
func nearest_discovered(cell: Vector2i, radius: float) -> Location:
	var best: Location = null
	var best_distance := radius
	for location in _locations:
		if not _discovered.has(location.id):
			continue
		var distance := Vector2(location.cell - cell).length()
		if distance <= best_distance:
			best = location
			best_distance = distance
	return best
