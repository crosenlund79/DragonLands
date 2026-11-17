class_name LineageBook
extends RefCounted
## Permanent ancestry: one entry per dragon that ever belonged to the player, keyed by id.
## Entries are never removed, so ancestry stays readable even if a dragon later leaves.

var _entries: Dictionary = {}  # id -> {id, name, species, parents, generation, born_at, color}


## Adds or refreshes the entry for `dragon` (one entry per id; never duplicated).
func record(dragon: DragonRecord) -> void:
	_entries[dragon.id] = {
		"id": dragon.id,
		"name": dragon.name,
		"species": dragon.species_id,
		"parents": Array(dragon.parent_ids),
		"generation": dragon.generation,
		"born_at": dragon.born_at_minutes,
		"color": dragon.genome.color("primary").to_html(false) if dragon.genome != null else "",
	}


func has_entry(id: String) -> bool:
	return _entries.has(id)


func get_entry(id: String) -> Dictionary:
	return _entries.get(id, {})


func size() -> int:
	return _entries.size()


func parents_of(id: String) -> PackedStringArray:
	return PackedStringArray(get_entry(id).get("parents", []))


## Every known ancestor id of `id` (parents, grandparents, ...), each listed once.
func ancestors(id: String) -> PackedStringArray:
	var found := PackedStringArray()
	var queue := Array(parents_of(id))
	while not queue.is_empty():
		var next: String = queue.pop_front()
		if found.has(next):
			continue
		found.append(next)
		queue.append_array(Array(parents_of(next)))
	return found


func to_array() -> Array:
	var ids := _entries.keys()
	ids.sort()
	return ids.map(func(id: String) -> Dictionary: return _entries[id].duplicate(true))


## Replaces all entries from saved data; false (and no change) on malformed or repeated ids.
func load_array(entries: Array) -> bool:
	var loaded := {}
	for entry in entries:
		if not (entry is Dictionary) or not (entry.get("id") is String) or loaded.has(entry.id):
			return false
		var e: Dictionary = (entry as Dictionary).duplicate(true)
		e.generation = int(e.get("generation", 0))
		loaded[entry.id] = e
	_entries = loaded
	return true
