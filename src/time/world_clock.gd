class_name WorldClock
extends RefCounted
## Continuous in-game time, measured in minutes since Day 1 00:00.
## Time only moves when something advances it (travel, encounters) - there are no turns.

signal time_changed(total_minutes: float)

const MINUTES_PER_DAY := 1440.0

var total_minutes: float


func _init(start_minutes: float = 8.0 * 60.0) -> void:
	total_minutes = start_minutes


func advance(minutes: float) -> void:
	if minutes <= 0.0:
		return
	total_minutes += minutes
	time_changed.emit(total_minutes)


## Jumps to an absolute time (used when loading a save).
func set_time(minutes: float) -> void:
	total_minutes = maxf(0.0, minutes)
	time_changed.emit(total_minutes)


func day() -> int:
	return int(floor(total_minutes / MINUTES_PER_DAY)) + 1


## Hours since midnight as a fraction (e.g. 13.5 = 13:30).
func hour_of_day() -> float:
	return fmod(total_minutes, MINUTES_PER_DAY) / 60.0


func clock_text() -> String:
	var minutes_today := int(floor(fmod(total_minutes, MINUTES_PER_DAY)))
	return "%02d:%02d" % [floori(minutes_today / 60.0), minutes_today % 60]


func phase_name() -> String:
	var h := hour_of_day()
	if h < 5.0:
		return "Night"
	if h < 7.0:
		return "Dawn"
	if h < 12.0:
		return "Morning"
	if h < 17.0:
		return "Afternoon"
	if h < 20.0:
		return "Dusk"
	if h < 22.0:
		return "Evening"
	return "Night"


static func format_duration(minutes: float) -> String:
	var total := int(round(minutes))
	if total < 60:
		return "%dm" % total
	if total % 60 == 0:
		return "%dh" % floori(total / 60.0)
	return "%dh %02dm" % [floori(total / 60.0), total % 60]
