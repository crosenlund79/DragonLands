class_name DecorPlan
extends RefCounted
## Deterministic placement of scenery (trees, mountains, rocks, bridges) from the terrain grid.
## Pure data: DecorView turns the entries into sprites.

## Entry: {art: String, position: Vector2, scale: float, flip: bool, tint: Color, ground: bool}
static func build(map: RegionMap, keep_clear: Array[Vector2i], seed: int = 1337) -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var entries: Array[Dictionary] = []
	var size := float(RegionMap.CELL_SIZE)
	for y in map.size.y:
		for x in map.size.x:
			var cell := Vector2i(x, y)
			var terrain := map.get_terrain(cell)
			var origin := Vector2(cell) * size
			if terrain == Terrain.Type.BRIDGE:
				entries.append(_entry("decor/bridge", map.cell_to_world(cell), 1.0, false, Color.WHITE, true))
				continue
			if terrain == Terrain.Type.MOUNTAIN:
				var art := "decor/mountain_a" if rng.randf() < 0.55 else "decor/mountain_b"
				var pos := origin + Vector2(size * 0.5 + rng.randf_range(-10, 10), size * 0.85 + rng.randf_range(-6, 6))
				# Peaks beside walkable land shrink to foothills so passes stay readable.
				var scale := rng.randf_range(0.4, 0.5) if _borders_walkable(map, cell) else rng.randf_range(0.52, 0.72)
				entries.append(_entry(art, pos, scale, rng.randf() < 0.5, _tint(rng, 0.06), false))
				continue
			if _near(cell, keep_clear):
				continue
			match terrain:
				Terrain.Type.FOREST:
					for i in 3:
						var p := origin + Vector2((i % 2) * 0.5 * size + rng.randf_range(10, 26), (i / 2) * 0.45 * size + rng.randf_range(22, 40))
						entries.append(_tree(rng, p, y < 14))
				Terrain.Type.WOODS:
					if rng.randf() < 0.75:
						entries.append(_tree(rng, origin + Vector2(rng.randf_range(14, 50), rng.randf_range(26, 56)), y < 14))
					if rng.randf() < 0.4:
						entries.append(_entry("decor/bush", origin + Vector2(rng.randf_range(10, 54), rng.randf_range(30, 60)),
							rng.randf_range(0.8, 1.1), rng.randf() < 0.5, _tint(rng, 0.08), false))
				Terrain.Type.MEADOW:
					var roll := rng.randf()
					if roll < 0.05:
						entries.append(_entry("decor/bush", origin + Vector2(rng.randf_range(12, 52), rng.randf_range(24, 58)),
							rng.randf_range(0.75, 1.0), rng.randf() < 0.5, _tint(rng, 0.08), false))
					elif roll < 0.075:
						entries.append(_entry("decor/rocks", origin + Vector2(rng.randf_range(12, 52), rng.randf_range(24, 58)),
							rng.randf_range(0.6, 0.85), rng.randf() < 0.5, _tint(rng, 0.05), false))
				Terrain.Type.ROCKY:
					var roll := rng.randf()
					if roll < 0.3:
						entries.append(_entry("decor/rocks", origin + Vector2(rng.randf_range(12, 52), rng.randf_range(24, 58)),
							rng.randf_range(0.7, 1.05), rng.randf() < 0.5, _tint(rng, 0.05), false))
					elif roll < 0.4:
						entries.append(_entry("decor/tree_pine", origin + Vector2(rng.randf_range(14, 50), rng.randf_range(30, 56)),
							rng.randf_range(0.6, 0.8), rng.randf() < 0.5, _tint(rng, 0.08), false))
	return entries


static func _tree(rng: RandomNumberGenerator, position: Vector2, highland: bool) -> Dictionary:
	var pine_chance := 0.6 if highland else 0.28
	var art := "decor/tree_pine" if rng.randf() < pine_chance else "decor/tree_oak"
	return _entry(art, position, rng.randf_range(0.82, 1.08), rng.randf() < 0.5, _tint(rng, 0.1), false)


static func _tint(rng: RandomNumberGenerator, amount: float) -> Color:
	var v := 1.0 - rng.randf() * amount
	return Color(v * rng.randf_range(0.97, 1.0), v, v * rng.randf_range(0.94, 1.0))


static func _borders_walkable(map: RegionMap, cell: Vector2i) -> bool:
	for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		if map.is_passable(cell + offset):
			return true
	return false


static func _near(cell: Vector2i, cells: Array[Vector2i]) -> bool:
	for other in cells:
		if absi(other.x - cell.x) <= 1 and absi(other.y - cell.y) <= 1:
			return true
	return false


static func _entry(art: String, position: Vector2, scale: float, flip: bool, tint: Color, ground: bool) -> Dictionary:
	return {"art": art, "position": position, "scale": scale, "flip": flip, "tint": tint, "ground": ground}
