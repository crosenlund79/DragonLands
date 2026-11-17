extends GutTest

func test_starts_unexplored() -> void:
	var fog := FogOfWar.new(Vector2i(10, 10))
	assert_eq(fog.explored_count(), 0)
	assert_false(fog.is_explored(Vector2i(3, 3)))


func test_reveal_is_circular_and_clipped_to_map() -> void:
	var fog := FogOfWar.new(Vector2i(10, 10))
	var newly := fog.reveal(Vector2i(0, 0), 2.0)
	assert_true(fog.is_explored(Vector2i(2, 0)))
	assert_true(fog.is_explored(Vector2i(1, 1)))
	assert_false(fog.is_explored(Vector2i(2, 2)), "corner is outside the radius")
	assert_eq(newly.size(), fog.explored_count())


func test_reveal_reports_only_new_cells_and_emits_once() -> void:
	var fog := FogOfWar.new(Vector2i(10, 10))
	watch_signals(fog)
	fog.reveal(Vector2i(5, 5), 1.0)
	assert_eq(fog.reveal(Vector2i(5, 5), 1.0).size(), 0)
	assert_signal_emit_count(fog, "revealed", 1)


func test_out_of_bounds_is_never_explored() -> void:
	var fog := FogOfWar.new(Vector2i(4, 4))
	fog.reveal(Vector2i(2, 2), 10.0)
	assert_false(fog.is_explored(Vector2i(-1, 0)))
	assert_eq(fog.explored_count(), 16)
	assert_eq(fog.to_bytes()[0], 255)
