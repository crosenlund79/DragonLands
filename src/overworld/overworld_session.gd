class_name OverworldSession
extends RefCounted
## Game state and rules of one overworld outing, independent of rendering:
## travel advances the clock and explores fog, visits open encounters, eggs
## develop with the clock and hatch into new dragons at camp.
## Scene nodes call into this object; it never touches Nodes itself.

signal cell_changed(cell: Vector2i)
signal egg_acquired(egg: EggRecord)
signal egg_ready(egg: EggRecord)
signal hatch_requested(egg: EggRecord)  ## UI should run the hatching moment, then call hatch_egg().
signal dragon_hatched(dragon: DragonRecord)

const SIGHT_RADIUS := 5.5
const AREA_NAME_RADIUS := 2.5

var map: RegionMap
var fog: FogOfWar
var clock: WorldClock
var locations: LocationRegistry
var pathfinder: GridPathfinder
var roster: DragonRoster  ## Owned dragons, in party order (all of them travel with you).
var eggs := EggCollection.new()
var adventurer_cell: Vector2i
var next_serial := 1  ## Source of unique ids for new eggs and dragons.
var eggs_taken: Dictionary = {}  ## location id -> true once its egg was collected.
var _ready_announced: Dictionary = {}  ## egg id -> true once egg_ready was emitted.


func _init(p_map: RegionMap, p_locations: LocationRegistry, p_roster: DragonRoster,
		start_cell: Vector2i, start_minutes: float) -> void:
	map = p_map
	locations = p_locations
	roster = p_roster
	adventurer_cell = start_cell
	fog = FogOfWar.new(map.size)
	clock = WorldClock.new(start_minutes)
	pathfinder = GridPathfinder.new(map, true)
	fog.revealed.connect(pathfinder.reveal)
	clock.time_changed.connect(_on_clock_changed)  # A method, not a lambda: avoids a RefCounted cycle.


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


## Description to show for a location right now.
func encounter_text(location: Location) -> String:
	var e := location.encounter
	return e.depleted_text if egg_taken(location.id) and e.depleted_text != "" else e.text


## The choices currently available at a location (egg choices depend on state).
func choices_for(location: Location) -> Array[EncounterChoice]:
	var result: Array[EncounterChoice] = []
	var now := clock.total_minutes
	var next_egg := eggs.soonest(now)
	for choice in location.encounter.choices:
		match choice.action:
			EncounterChoice.ACTION_TAKE_EGG:
				if not egg_taken(location.id):
					result.append(choice)
			EncounterChoice.ACTION_HATCH_EGG:
				if next_egg != null and next_egg.is_ready(now):
					result.append(choice.with_label("Hatch the %s egg" % next_egg.species().short_name))
			EncounterChoice.ACTION_WARM_EGG:
				if next_egg != null and not next_egg.is_ready(now):
					result.append(choice.with_label("%s (%s)" % [choice.label,
						WorldClock.format_duration(next_egg.remaining_minutes(now))]))
			_:
				result.append(choice)
	return result


## Applies a chosen encounter option and returns its outcome text ("" = close the panel).
func resolve_choice(location: Location, choice: EncounterChoice) -> String:
	match choice.action:
		EncounterChoice.ACTION_TAKE_EGG:
			if egg_taken(location.id):
				return ""
			clock.advance(choice.minutes)
			var egg := EggRecord.create(new_id("egg"), choice.species, location.id, clock.total_minutes,
				hash("%s/%s/%d" % [location.id, choice.species, int(clock.total_minutes)]) & 0x7fffffff)
			eggs_taken[location.id] = true
			eggs.add(egg)
			egg_acquired.emit(egg)
			return choice.outcome
		EncounterChoice.ACTION_WARM_EGG, EncounterChoice.ACTION_HATCH_EGG:
			var egg := eggs.soonest(clock.total_minutes)
			if egg == null:
				return ""
			clock.advance(egg.remaining_minutes(clock.total_minutes))
			hatch_requested.emit(egg)
			return ""
	clock.advance(choice.minutes)
	if choice.reveal_radius > 0.0:
		_explore(location.cell, choice.reveal_radius)
	return choice.outcome


func egg_taken(location_id: String) -> bool:
	return eggs_taken.has(location_id)


## Hatches a ready egg into a new owned dragon named `chosen_name`. Returns null if the
## egg is unknown or not ready yet.
func hatch_egg(egg_id: String, chosen_name: String) -> DragonRecord:
	var egg := eggs.get_by_id(egg_id)
	if egg == null or not egg.is_ready(clock.total_minutes):
		return null
	var nest := locations.get_by_id(egg.origin_location_id)
	var here := locations.at_cell(adventurer_cell)
	var origin := "Hatched at %s from an egg found at %s" % [
		here.name if here != null else "the roadside", nest.name if nest != null else "the wild"]
	var dragon := Hatching.hatch(egg, new_id("dragon"), chosen_name, clock.total_minutes, origin)
	eggs.remove(egg_id)
	_ready_announced.erase(egg_id)
	roster.add(dragon)
	dragon_hatched.emit(dragon)
	return dragon


func new_id(prefix: String) -> String:
	var id := "%s-%d" % [prefix, next_serial]
	next_serial += 1
	return id


## Marks eggs that are already ready as announced (used after loading a save).
func mark_ready_eggs_announced() -> void:
	for egg in eggs.all():
		if egg.is_ready(clock.total_minutes):
			_ready_announced[egg.id] = true


func _on_clock_changed(_minutes: float) -> void:
	_announce_ready_eggs()


func _announce_ready_eggs() -> void:
	for egg in eggs.all():
		if not _ready_announced.has(egg.id) and egg.is_ready(clock.total_minutes):
			_ready_announced[egg.id] = true
			egg_ready.emit(egg)


## Short place description for the HUD, e.g. "Old road" or "Emberfall Nest".
func area_name(cell: Vector2i) -> String:
	var nearby := locations.nearest_discovered(cell, AREA_NAME_RADIUS)
	if nearby != null:
		return nearby.name
	return Terrain.display_name(map.get_terrain(cell))


func _explore(center: Vector2i, radius: float) -> void:
	fog.reveal(center, radius)
	locations.discover_explored(fog)
