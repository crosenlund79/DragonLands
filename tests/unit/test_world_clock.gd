extends GutTest

func test_starts_at_given_time() -> void:
	var clock := WorldClock.new(8 * 60)
	assert_eq(clock.day(), 1)
	assert_eq(clock.clock_text(), "08:00")
	assert_eq(clock.phase_name(), "Morning")


func test_advance_rolls_over_days() -> void:
	var clock := WorldClock.new(23 * 60 + 30)
	clock.advance(45.0)
	assert_eq(clock.day(), 2)
	assert_eq(clock.clock_text(), "00:15")
	assert_eq(clock.phase_name(), "Night")


func test_advance_emits_and_ignores_non_positive() -> void:
	var clock := WorldClock.new(0)
	watch_signals(clock)
	clock.advance(0.0)
	clock.advance(-5.0)
	assert_signal_not_emitted(clock, "time_changed")
	clock.advance(1.5)
	assert_signal_emitted_with_parameters(clock, "time_changed", [1.5])


func test_phases_through_the_day() -> void:
	var expected := {6: "Dawn", 13: "Afternoon", 18: "Dusk", 21: "Evening", 23: "Night"}
	for hour in expected:
		assert_eq(WorldClock.new(hour * 60.0).phase_name(), expected[hour])


func test_format_duration() -> void:
	assert_eq(WorldClock.format_duration(45.0), "45m")
	assert_eq(WorldClock.format_duration(120.0), "2h")
	assert_eq(WorldClock.format_duration(85.4), "1h 25m")
