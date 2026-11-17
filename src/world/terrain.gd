class_name Terrain
extends RefCounted
## Terrain types of the overworld grid and their travel rules.
## minutes = in-game travel time to cross one cell; speed = on-screen walking pace factor.

enum Type { MEADOW, WOODS, FOREST, ROAD, WATER, BRIDGE, MOUNTAIN, ROCKY }

const SYMBOLS := {
	".": Type.MEADOW,
	"t": Type.WOODS,
	"T": Type.FOREST,
	"=": Type.ROAD,
	"~": Type.WATER,
	"B": Type.BRIDGE,
	"M": Type.MOUNTAIN,
	"r": Type.ROCKY,
}

const _INFO := {
	Type.MEADOW: {"name": "Meadow", "passable": true, "minutes": 15.0, "speed": 1.0},
	Type.WOODS: {"name": "Woodland", "passable": true, "minutes": 24.0, "speed": 0.8},
	Type.FOREST: {"name": "Deep forest", "passable": false, "minutes": 24.0, "speed": 0.8},
	Type.ROAD: {"name": "Old road", "passable": true, "minutes": 10.0, "speed": 1.25},
	Type.WATER: {"name": "River", "passable": false, "minutes": 15.0, "speed": 1.0},
	Type.BRIDGE: {"name": "Stone bridge", "passable": true, "minutes": 10.0, "speed": 1.15},
	Type.MOUNTAIN: {"name": "Mountains", "passable": false, "minutes": 30.0, "speed": 0.7},
	Type.ROCKY: {"name": "Rocky hills", "passable": true, "minutes": 22.0, "speed": 0.8},
}


static func from_symbol(symbol: String) -> int:
	return SYMBOLS.get(symbol, -1)


static func is_passable(type: int) -> bool:
	return _INFO.has(type) and _INFO[type]["passable"]


static func minutes_per_cell(type: int) -> float:
	return _INFO[type]["minutes"] if _INFO.has(type) else 15.0


static func speed_factor(type: int) -> float:
	return _INFO[type]["speed"] if _INFO.has(type) else 1.0


static func display_name(type: int) -> String:
	return _INFO[type]["name"] if _INFO.has(type) else "Unknown"
