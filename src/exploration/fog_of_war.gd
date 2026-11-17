class_name FogOfWar
extends RefCounted
## Which cells the player has explored. Exploration is permanent (no re-fogging).

signal revealed(cells: Array[Vector2i])

var size: Vector2i
var _explored := PackedByteArray()


func _init(p_size: Vector2i) -> void:
	size = p_size
	_explored.resize(size.x * size.y)


func is_explored(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= size.x or cell.y >= size.y:
		return false
	return _explored[cell.y * size.x + cell.x] != 0


## Explores every cell within `radius` cells of `center`; returns newly explored cells.
func reveal(center: Vector2i, radius: float) -> Array[Vector2i]:
	var newly: Array[Vector2i] = []
	var r := int(ceil(radius))
	var r2 := radius * radius
	for y in range(max(0, center.y - r), min(size.y, center.y + r + 1)):
		for x in range(max(0, center.x - r), min(size.x, center.x + r + 1)):
			var d := Vector2(x - center.x, y - center.y)
			var index := y * size.x + x
			if d.length_squared() <= r2 and _explored[index] == 0:
				_explored[index] = 1
				newly.append(Vector2i(x, y))
	if not newly.is_empty():
		revealed.emit(newly)
	return newly


func explored_count() -> int:
	return _explored.count(1)


## One byte per cell (255 = explored) for rendering.
func to_bytes() -> PackedByteArray:
	var bytes := _explored.duplicate()
	for i in bytes.size():
		bytes[i] = 255 if bytes[i] != 0 else 0
	return bytes
