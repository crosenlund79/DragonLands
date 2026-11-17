extends GutTest

func test_advances_along_segments() -> void:
	var f := PathFollower.new()
	f.set_path(PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(10, 10)]))
	assert_true(f.is_active())
	assert_eq(f.advance(15.0), 15.0)
	assert_eq(f.position, Vector2(10, 5))
	assert_eq(f.direction(), Vector2(0, 1))


func test_stops_at_end_and_reports_partial_distance() -> void:
	var f := PathFollower.new()
	f.set_path(PackedVector2Array([Vector2(0, 0), Vector2(10, 0)]))
	assert_eq(f.advance(25.0), 10.0)
	assert_false(f.is_active())
	assert_eq(f.position, Vector2(10, 0))
	assert_eq(f.advance(5.0), 0.0)


func test_remaining_points_start_at_current_position() -> void:
	var f := PathFollower.new()
	f.set_path(PackedVector2Array([Vector2(0, 0), Vector2(10, 0), Vector2(20, 0)]))
	f.advance(5.0)
	assert_eq(f.remaining_points(), PackedVector2Array([Vector2(5, 0), Vector2(10, 0), Vector2(20, 0)]))
	f.stop()
	assert_false(f.is_active())
