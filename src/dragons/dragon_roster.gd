class_name DragonRoster
extends RefCounted
## The dragons the player owns, in party order. Ids are unique: adding a known id is refused.

signal changed

var _dragons: Array[DragonRecord] = []


func add(dragon: DragonRecord) -> bool:
	if dragon == null or get_by_id(dragon.id) != null:
		return false
	_dragons.append(dragon)
	changed.emit()
	return true


func get_by_id(id: String) -> DragonRecord:
	for dragon in _dragons:
		if dragon.id == id:
			return dragon
	return null


func all() -> Array[DragonRecord]:
	return _dragons.duplicate()


func size() -> int:
	return _dragons.size()


func index_of(id: String) -> int:
	for i in _dragons.size():
		if _dragons[i].id == id:
			return i
	return -1


func to_array() -> Array:
	return _dragons.map(func(d: DragonRecord) -> Dictionary: return d.to_dict())


## Replaces the roster with saved records. Returns false (and changes nothing)
## if any entry is invalid or an id repeats.
func load_array(entries: Array) -> bool:
	var loaded: Array[DragonRecord] = []
	var seen := {}
	for entry in entries:
		var dragon := DragonRecord.from_dict(entry) if entry is Dictionary else null
		if dragon == null or seen.has(dragon.id):
			return false
		seen[dragon.id] = true
		loaded.append(dragon)
	_dragons = loaded
	changed.emit()
	return true


## Replaces the whole collection (used after a save was validated and migrated).
func set_all(items: Array[DragonRecord]) -> void:
	_dragons = items.duplicate()
	changed.emit()
