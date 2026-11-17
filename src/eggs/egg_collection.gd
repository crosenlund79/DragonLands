class_name EggCollection
extends RefCounted
## Eggs the adventurer is carrying. Ids are unique: adding a known id is refused.

signal changed

var _eggs: Array[EggRecord] = []


func add(egg: EggRecord) -> bool:
	if egg == null or get_by_id(egg.id) != null:
		return false
	_eggs.append(egg)
	changed.emit()
	return true


func remove(id: String) -> EggRecord:
	for i in _eggs.size():
		if _eggs[i].id == id:
			var egg := _eggs[i]
			_eggs.remove_at(i)
			changed.emit()
			return egg
	return null


func get_by_id(id: String) -> EggRecord:
	for egg in _eggs:
		if egg.id == id:
			return egg
	return null


func all() -> Array[EggRecord]:
	return _eggs.duplicate()


func size() -> int:
	return _eggs.size()


## The egg that will be (or already is) ready first, or null when empty.
func soonest(now: float) -> EggRecord:
	var best: EggRecord = null
	for egg in _eggs:
		if best == null or egg.remaining_minutes(now) < best.remaining_minutes(now):
			best = egg
	return best


func to_array() -> Array:
	return _eggs.map(func(e: EggRecord) -> Dictionary: return e.to_dict())


## Replaces the collection with saved eggs; false (and no change) on invalid or repeated entries.
func load_array(entries: Array) -> bool:
	var loaded: Array[EggRecord] = []
	var seen := {}
	for entry in entries:
		var egg := EggRecord.from_dict(entry) if entry is Dictionary else null
		if egg == null or seen.has(egg.id):
			return false
		seen[egg.id] = true
		loaded.append(egg)
	_eggs = loaded
	changed.emit()
	return true
