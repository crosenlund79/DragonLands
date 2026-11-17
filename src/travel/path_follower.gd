class_name PathFollower
extends RefCounted
## Moves a point along a polyline at caller-supplied distances (pure logic, no Nodes).

var position := Vector2.ZERO
var _points := PackedVector2Array()
var _next_index := 0


func set_path(points: PackedVector2Array) -> void:
	_points = points
	_next_index = 1
	if points.size() > 0:
		position = points[0]


func stop() -> void:
	_points = PackedVector2Array()
	_next_index = 0


func is_active() -> bool:
	return _next_index > 0 and _next_index < _points.size()


## Advances up to `distance` along the path; returns the distance actually moved.
func advance(distance: float) -> float:
	var moved := 0.0
	while distance > 0.0 and is_active():
		var target := _points[_next_index]
		var gap := position.distance_to(target)
		if gap <= distance:
			position = target
			distance -= gap
			moved += gap
			_next_index += 1
		else:
			position = position.move_toward(target, distance)
			moved += distance
			distance = 0.0
	return moved


## Unit direction toward the next waypoint (ZERO when idle).
func direction() -> Vector2:
	if not is_active():
		return Vector2.ZERO
	return position.direction_to(_points[_next_index])


## Current position followed by the waypoints still ahead.
func remaining_points() -> PackedVector2Array:
	var rest := PackedVector2Array([position])
	if is_active():
		rest.append_array(_points.slice(_next_index))
	return rest


func final_point() -> Vector2:
	return _points[_points.size() - 1] if _points.size() > 0 else position
