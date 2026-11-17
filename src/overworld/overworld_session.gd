class_name OverworldSession
extends RefCounted
## Game state and rules of one overworld outing, independent of rendering:
## travel advances the clock and explores fog, visits open encounters.
## Scene nodes call into this object; it never touches Nodes itself.

signal cell_changed(cell: Vector2i)

const SIGHT_RADIUS := 5.5
const AREA_NAME_RADIUS := 2.5

var map: RegionMap
var fog: FogOfWar
var clock: WorldClock
var locations: LocationRegistry
var pathfinder: GridPathfinder
var party: Array[DragonProfile]
var adventurer_cell: Vector2i


func _init(p_map: RegionMap, p_locations: LocationRegistry, p_party: Array[DragonProfile],
		start_cell: Vector2i, start_minutes: float) -> void:
	map = p_map
	locations = p_locations
	party = p_party
	adventurer_cell = start_cell
	fog = FogOfWar.new(map.size)
	clock = WorldClock.new(start_minutes)
	pathfinder = GridPathfinder.new(map, true)
	fog.revealed.connect(pathfinder.reveal)


## Reveals the surroundings of the starting cell. Call once after signals are connected.
func begin() -> void:
	_explore(adventurer_cell, SIGHT_RADIUS)


func plan_route(target: Vector2i) -> Array[Vector2i]:
	return pathfinder.find_path(adventurer_cell, target)


## The cell to head for when the player points at `target`: the target itself if it is
## explored and walkable, otherwise the last such cell on the line from the adventurer
## toward it ("walk to the edge of what you can see"). Returns (-1, -1) if none.
func resolve_target(target: Vector2i) -> Vector2i:
	if pathfinder.is_routable(target):
		return target
	if fog.is_explored(target) or not map.is_inside(target):
		return Vector2i(-1, -1)  # A known obstacle: refuse rather than guess.
	var from := Vector2(adventurer_cell)
	var to := Vector2(target)
	var steps := int(ceil(from.distance_to(to) * 2.0))
	for i in range(steps, 0, -1):
		var cell := Vector2i(from.lerp(to, float(i) / steps).round())
		if cell != adventurer_cell and pathfinder.is_routable(cell):
			return cell
	return Vector2i(-1, -1)


## Reports that the adventurer walked `distance_px` and is now at `position`.
## Advances the clock by the terrain under the adventurer and explores on entering new cells.
func travel(distance_px: float, position: Vector2) -> void:
	var cell := map.world_to_cell(position)
	if map.is_passable(cell) and cell != adventurer_cell:
		adventurer_cell = cell
		_explore(cell, SIGHT_RADIUS)
		cell_changed.emit(cell)
	var terrain := map.get_terrain(adventurer_cell)
	clock.advance(distance_px / RegionMap.CELL_SIZE * Terrain.minutes_per_cell(terrain))


## Called when the adventurer stops on `cell` as the route destination.
## Returns the location visited there, or null.
func arrive(cell: Vector2i) -> Location:
	var location := locations.at_cell(cell)
	if location != null:
		locations.mark_visited(location.id)
	return location


## Applies a chosen encounter option and returns its outcome text.
func resolve_choice(location: Location, choice: EncounterChoice) -> String:
	clock.advance(choice.minutes)
	if choice.reveal_radius > 0.0:
		_explore(location.cell, choice.reveal_radius)
	return choice.outcome


## Short place description for the HUD, e.g. "Old road" or "Emberfall Nest".
func area_name(cell: Vector2i) -> String:
	var nearby := locations.nearest_discovered(cell, AREA_NAME_RADIUS)
	if nearby != null:
		return nearby.name
	return Terrain.display_name(map.get_terrain(cell))


func _explore(center: Vector2i, radius: float) -> void:
	fog.reveal(center, radius)
	locations.discover_explored(fog)
