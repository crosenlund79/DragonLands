class_name SaveGame
extends RefCounted
## Minimal save/load of an OverworldSession as JSON: world clock, adventurer cell,
## explored map, discoveries, collected eggs (with incubation progress), owned
## dragons and id counter. Restoring replaces state, so nothing is duplicated.

const VERSION := 1
const DEFAULT_PATH := "user://savegame.json"


static func capture(session: OverworldSession) -> Dictionary:
	return {
		"version": VERSION,
		"region": session.map.region_name,
		"clock_minutes": session.clock.total_minutes,
		"adventurer_cell": [session.adventurer_cell.x, session.adventurer_cell.y],
		"explored": Marshalls.raw_to_base64(session.fog.to_bytes()),
		"discovered": Array(session.locations.discovered_ids()),
		"visited": Array(session.locations.visited_ids()),
		"eggs_taken": session.eggs_taken.keys(),
		"eggs": session.eggs.to_array(),
		"dragons": session.roster.to_array(),
		"next_serial": session.next_serial,
	}


## Applies saved data to `session`. Everything is validated first; on any problem
## the session is left untouched and false is returned.
static func restore(session: OverworldSession, data: Dictionary) -> bool:
	if int(data.get("version", -1)) != VERSION or data.get("region") != session.map.region_name:
		return _reject("unsupported version or different region")
	var explored := Marshalls.base64_to_raw(str(data.get("explored", "")))
	var cell_data: Array = data.get("adventurer_cell", [])
	if explored.size() != session.map.size.x * session.map.size.y or cell_data.size() != 2:
		return _reject("explored map or position is malformed")
	var cell := Vector2i(int(cell_data[0]), int(cell_data[1]))
	if not session.map.is_passable(cell):
		return _reject("adventurer position is not walkable")
	var eggs := EggCollection.new()
	var roster := DragonRoster.new()
	if not eggs.load_array(data.get("eggs", [])) or not roster.load_array(data.get("dragons", [])):
		return _reject("eggs or dragons are malformed")

	session.pathfinder.forget_explored()
	session.fog.load_bytes(explored)
	session.locations.restore_state(data.get("discovered", []), data.get("visited", []))
	session.eggs_taken.clear()
	for id in data.get("eggs_taken", []):
		session.eggs_taken[str(id)] = true
	session.eggs.load_array(data.get("eggs", []))
	session.roster.load_array(data.get("dragons", []))
	session.next_serial = maxi(int(data.get("next_serial", 1)), 1)
	session.adventurer_cell = cell
	session.clock.total_minutes = maxf(0.0, float(data.get("clock_minutes", session.clock.total_minutes)))
	session.mark_ready_eggs_announced()  # Eggs that were ready before saving are not "new" news.
	session.clock.set_time(session.clock.total_minutes)
	return true


static func write(data: Dictionary, path: String = DEFAULT_PATH) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return OK


## Parsed save data, or an empty Dictionary if the file is missing or unreadable.
static func read(path: String = DEFAULT_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		push_warning("SaveGame: '%s' is not a valid save file." % path)
		return {}
	return parsed


static func exists(path: String = DEFAULT_PATH) -> bool:
	return FileAccess.file_exists(path)


static func _reject(reason: String) -> bool:
	push_warning("SaveGame: cannot load save (%s)." % reason)
	return false
