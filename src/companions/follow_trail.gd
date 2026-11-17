class_name FollowTrail
extends RefCounted
## Breadcrumb trail of a leader's recent positions. Followers aim for a point a
## fixed distance *along the walked path*, so they inherit the leader's
## obstacle-free route instead of cutting across terrain.

var spacing := 6.0
var max_length := 480.0
var _points := PackedVector2Array()  # [0] = leader's current position (newest)


func reset(position: Vector2) -> void:
	_points = PackedVector2Array([position])


func record(position: Vector2) -> void:
	if _points.is_empty():
		reset(position)
		return
	if _points.size() == 1 or _points[1].distance_to(position) >= spacing:
		_points.insert(0, position)
	else:
		_points[0] = position
	_trim()


## Point `distance` behind the leader along the trail (oldest point if the trail is shorter).
func point_behind(distance: float) -> Vector2:
	if _points.is_empty():
		return Vector2.ZERO
	var remaining := distance
	for i in _points.size() - 1:
		var a := _points[i]
		var b := _points[i + 1]
		var segment := a.distance_to(b)
		if segment >= remaining:
			return a.move_toward(b, remaining)
		remaining -= segment
	return _points[_points.size() - 1]


## Walking direction at `distance` behind the leader (ZERO on a degenerate trail).
func heading_at(distance: float) -> Vector2:
	var ahead := point_behind(maxf(0.0, distance - 10.0))
	var behind := point_behind(distance + 10.0)
	return behind.direction_to(ahead) if ahead.distance_squared_to(behind) > 0.01 else Vector2.ZERO


func length() -> float:
	var total := 0.0
	for i in _points.size() - 1:
		total += _points[i].distance_to(_points[i + 1])
	return total


func _trim() -> void:
	var total := 0.0
	for i in _points.size() - 1:
		total += _points[i].distance_to(_points[i + 1])
		if total > max_length:
			_points.resize(i + 2)
			return
