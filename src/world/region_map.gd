class_name RegionMap
extends RefCounted
## Terrain grid of one overworld region plus cell <-> world conversions.

const CELL_SIZE := 64

var region_name: String
var size: Vector2i
var _cells: PackedInt32Array


static func from_rows(p_region_name: String, rows: Array[String]) -> RegionMap:
	var map := RegionMap.new()
	map.region_name = p_region_name
	var width := rows[0].length() if rows.size() > 0 else 0
	map.size = Vector2i(width, rows.size())
	map._cells.resize(width * rows.size())
	for y in rows.size():
		var row := rows[y]
		if row.length() != width:
			push_error("RegionMap: row %d has width %d, expected %d." % [y, row.length(), width])
		for x in width:
			var type := Terrain.from_symbol(row[x]) if x < row.length() else -1
			if type < 0:
				push_error("RegionMap: unknown symbol at (%d, %d)." % [x, y])
				type = Terrain.Type.MEADOW
			map._cells[y * width + x] = type
	return map


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


## Terrain type at cell, or -1 outside the map.
func get_terrain(cell: Vector2i) -> int:
	return _cells[cell.y * size.x + cell.x] if is_inside(cell) else -1


func is_passable(cell: Vector2i) -> bool:
	return Terrain.is_passable(get_terrain(cell))


func cell_to_world(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * CELL_SIZE


func world_to_cell(position: Vector2) -> Vector2i:
	return Vector2i((position / CELL_SIZE).floor())


func pixel_size() -> Vector2:
	return Vector2(size * CELL_SIZE)
