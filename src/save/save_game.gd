class_name SaveGame
extends RefCounted
## Save/load of an OverworldSession as JSON: world clock, adventurer cell, explored map,
## discoveries, taken eggs, eggs (with genes and incubation), owned dragons (identity, genes,
## parentage), the travelling party, the lineage book and the id counter.
## Restoring validates everything first and replaces state, so nothing is ever duplicated.
## Version 1 saves (Prototype 002, before genetics) are upgraded on load.

const VERSION := 2
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
		"party": Array(session.party_ids),
		"lineage": session.lineage.to_array(),
		"next_serial": session.next_serial,
	}


## Applies saved data to `session`. Everything is validated (and old saves upgraded) first;
## on any problem the session is left untouched and false is returned.
static func restore(session: OverworldSession, data: Dictionary) -> bool:
	var version := int(data.get("version", -1))
	if (version != 1 and version != VERSION) or data.get("region") != session.map.region_name:
		return _reject("unsupported version or different region")
	var explored := Marshalls.base64_to_raw(str(data.get("explored", "")))
	var cell_data: Array = data.get("adventurer_cell", [])
	if explored.size() != session.map.size.x * session.map.size.y or cell_data.size() != 2:
		return _reject("explored map or position is malformed")
	var cell := Vector2i(int(cell_data[0]), int(cell_data[1]))
	if not session.map.is_passable(cell):
		return _reject("adventurer position is not walkable")

	var egg_list := EggCollection.new()
	var dragon_list := DragonRoster.new()
	if not egg_list.load_array(data.get("eggs", [])) or not dragon_list.load_array(data.get("dragons", [])):
		return _reject("eggs or dragons are malformed")
	var eggs := egg_list.all()
	var dragons := dragon_list.all()
	for egg in eggs:
		if egg.genome == null:
			if version != 1:
				return _reject("egg %s has no genome" % egg.id)
			egg.genome = GeneticsEngine.wild(egg.species(), egg.seed)  # The egg's own seed: stable.
	for dragon in dragons:
		if dragon.genome == null:
			if version != 1:
				return _reject("dragon %s has no genome" % dragon.id)
			dragon.genome = legacy_genome(dragon)

	var party := PackedStringArray()
	if version == 1:
		for dragon in dragons.slice(0, OverworldSession.MAX_PARTY):
			party.append(dragon.id)
	else:
		for id in data.get("party", []):
			if dragon_list.get_by_id(str(id)) == null or party.has(str(id)):
				return _reject("party lists an unknown or repeated dragon")
			party.append(str(id))
		if party.size() > OverworldSession.MAX_PARTY:
			return _reject("party is too large")
	var lineage := LineageBook.new()
	if version != 1 and not lineage.load_array(data.get("lineage", [])):
		return _reject("lineage is malformed")
	for dragon in dragons:
		if not lineage.has_entry(dragon.id):
			lineage.record(dragon)

	session.pathfinder.forget_explored()
	session.fog.load_bytes(explored)
	session.locations.restore_state(data.get("discovered", []), data.get("visited", []))
	session.eggs_taken.clear()
	for id in data.get("eggs_taken", []):
		session.eggs_taken[str(id)] = true
	session.eggs.set_all(eggs)
	session.roster.set_all(dragons)
	session.party_ids = party
	session.lineage = lineage
	session.next_serial = maxi(int(data.get("next_serial", 1)), 1)
	session.adventurer_cell = cell
	session.clock.total_minutes = maxf(0.0, float(data.get("clock_minutes", session.clock.total_minutes)))
	session.mark_ready_eggs_announced()  # Eggs that were ready before saving are not "new" news.
	session.clock.set_time(session.clock.total_minutes)
	session.party_changed.emit()
	return true


## Genome for a dragon from a pre-genetics save: the canonical one for Ember and Moss,
## otherwise a wild genome seeded by its id (the same every time the save is loaded).
static func legacy_genome(dragon: DragonRecord) -> Genome:
	var canonical := StartingDragons.canonical_genome(dragon.id)
	if canonical != null:
		return canonical
	return GeneticsEngine.wild(dragon.species(), hash("legacy/" + dragon.id) & 0x7fffffff)


static func write(data: Dictionary, path: String = DEFAULT_PATH) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t", true, true))  # full precision: floats round-trip exactly
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
