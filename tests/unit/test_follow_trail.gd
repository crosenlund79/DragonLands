extends GutTest

func _walk(trail: FollowTrail, from: Vector2, to: Vector2, steps: int) -> void:
	for i in range(1, steps + 1):
		trail.record(from.lerp(to, float(i) / steps))


func test_point_behind_follows_the_walked_route_not_a_straight_line() -> void:
	var trail := FollowTrail.new()
	trail.reset(Vector2(0, 0))
	_walk(trail, Vector2(0, 0), Vector2(100, 0), 50)
	_walk(trail, Vector2(100, 0), Vector2(100, 100), 50)
	var p := trail.point_behind(150.0)
	assert_almost_eq(p.y, 0.0, 0.01, "150px back along an L-shaped path is on the first leg")
	assert_almost_eq(p.x, 50.0, 3.0)


func test_short_trail_returns_oldest_point() -> void:
	var trail := FollowTrail.new()
	trail.reset(Vector2(5, 5))
	trail.record(Vector2(15, 5))
	assert_eq(trail.point_behind(500.0), Vector2(5, 5))
	assert_eq(trail.point_behind(0.0), Vector2(15, 5))


func test_trail_length_is_capped() -> void:
	var trail := FollowTrail.new()
	trail.max_length = 100.0
	trail.reset(Vector2.ZERO)
	_walk(trail, Vector2.ZERO, Vector2(1000, 0), 200)
	assert_lt(trail.length(), 110.0)


func test_heading_points_in_walking_direction() -> void:
	var trail := FollowTrail.new()
	trail.reset(Vector2.ZERO)
	_walk(trail, Vector2.ZERO, Vector2(200, 0), 40)
	assert_almost_eq(trail.heading_at(50.0), Vector2(1, 0), Vector2(0.01, 0.01))
	var fresh := FollowTrail.new()
	fresh.reset(Vector2(3, 3))
	assert_eq(fresh.heading_at(10.0), Vector2.ZERO)
