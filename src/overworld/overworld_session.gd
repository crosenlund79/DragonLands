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
signal egg_laid(egg: EggRecord)  ## A bred egg (parents known) was added to the pack.
signal party_changed
signal collection_requested  ## The player chose to tend their dragons at camp.

const SIGHT_RADIUS := 5.5
const AREA_NAME_RADIUS := 2.5
const MAX_PARTY := 3
const MAX_SCOUTING_BONUS := 2.0

var map: RegionMap
var fog: FogOfWar
var clock: WorldClock
var locations: LocationRegistry
var pathfinder: GridPathfinder
var roster: DragonRoster  ## Every owned dragon, travelling or resting at camp.
var party_ids := PackedStringArray()  ## Up to MAX_PARTY travelling dragons, in follow order.
var lineage := LineageBook.new()
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
	for dragon in roster.all():
		lineage.record(dragon)
		if party_ids.size() < MAX_PARTY:
			party_ids.append(dragon.id)
	adventurer_cell = start_cell
	fog = FogOfWar.new(map.size)
	clock = WorldClock.new(start_minutes)
	pathfinder = GridPathfinder.new(map, true)
	fog.revealed.connect(pathfinder.reveal)
	clock.time_changed.connect(_on_clock_changed)  # A method, not a lambda: avoids a RefCounted cycle.


## Reveals the surroundings of the starting cell. Call once after signals are connected.
func begin() -> void:
	_explore(adventurer_cell, sight_radius())


## Exploration radius: base sight plus the best scout among the travelling dragons.
func sight_radius() -> float:
	return SIGHT_RADIUS + scouting_bonus()


func scouting_bonus() -> float:
	var best := -INF
	for dragon in party():
		best = maxf(best, TraitCatalog.scouting_of(dragon.genome))
	return 0.0 if best == -INF else clampf(best, -1.0, MAX_SCOUTING_BONUS)


# --- Party -----------------------------------------------------------------------

func party() -> Array[DragonRecord]:
	var result: Array[DragonRecord] = []
	for id in party_ids:
		var dragon := roster.get_by_id(id)
		if dragon != null:
			result.append(dragon)
	return result


func is_travelling(id: String) -> bool:
	return party_ids.has(id)


func at_camp() -> bool:
	var here := locations.at_cell(adventurer_cell)
	return here != null and here.kind == Location.Kind.CAMP


## Adds or removes a dragon from the travelling party. Returns "" on success, else the reason.
func set_travelling(id: String, travelling: bool) -> String:
	if roster.get_by_id(id) == null:
		return "Unknown dragon"
	if not at_camp():
		return "The party is chosen at Wayfarer's Camp"
	if travelling == is_travelling(id):
		return ""
	if travelling:
		if party_ids.size() >= MAX_PARTY:
			return "At most %d dragons can travel with you" % MAX_PARTY
		party_ids.append(id)
	else:
		party_ids.remove_at(party_ids.find(id))
	party_changed.emit()
	return ""


# --- Breeding --------------------------------------------------------------------

## Why `a_id` x `b_id` cannot breed now ("" = they can).
func breeding_problem(a_id: String, b_id: String) -> String:
	if not at_camp():
		return "Breeding happens at Wayfarer's Camp"
	if eggs.size() >= BreedingRules.MAX_CARRIED_EGGS:
		return "Your pack already holds %d eggs - hatch one first" % BreedingRules.MAX_CARRIED_EGGS
	return BreedingRules.pair_problem(roster.get_by_id(a_id), roster.get_by_id(b_id), clock.total_minutes)


## Pairs two dragons: spends breeding time, starts both cooldowns and lays an egg whose genes
## are decided now. Returns the egg, or null if the pair cannot breed.
func breed(a_id: String, b_id: String) -> EggRecord:
	if breeding_problem(a_id, b_id) != "":
		return null
	var a := roster.get_by_id(a_id)
	var b := roster.get_by_id(b_id)
	clock.advance(BreedingRules.BREEDING_MINUTES)
	var now := clock.total_minutes
	a.last_bred_at = now
	b.last_bred_at = now
	var seed := hash("%s|%s|%d|%d" % [a.id, b.id, next_serial, int(now)]) & 0x7fffffff
	var genome := GeneticsEngine.breed(a.genome, b.genome, seed)
	var egg := EggRecord.create(new_id("egg"), a.species_id, locations.at_cell(adventurer_cell).id, now, seed, genome,
		PackedStringArray([a.id, b.id]), maxi(a.generation, b.generation) + 1,
		GeneticsEngine.describe(a.genome, b.genome, genome, a.name, b.name))
	eggs.add(egg)
	egg_laid.emit(egg)
	return egg


# --- Resting ---------------------------------------------------------------------

## The next thing worth waiting for: {minutes, text}; empty if nothing is pending.
func next_rest_milestone() -> Dictionary:
	var now := clock.total_minutes
	var best := {}
	for dragon in roster.all():  # Eggs have their own "keep warm until it hatches" choice.
		if dragon.stage(now) != DragonSpecies.Stage.ADULT:
			_consider(best, dragon.species().adult_at_minutes - dragon.age_minutes(now), "%s is fully grown" % dragon.name)
		_consider(best, BreedingRules.cooldown_left(dragon, now), "%s is ready to breed again" % dragon.name)
	return best


func _consider(best: Dictionary, minutes: float, text: String) -> void:
	if minutes > WorldClock.EPSILON and (best.is_empty() or minutes < best.minutes):
		best.minutes = ceilf(minutes)
		best.text = text



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
		_explore(cell, sight_radius())
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
			EncounterChoice.ACTION_REST_UNTIL:
				var milestone := next_rest_milestone()
				if not milestone.is_empty():
					result.append(choice.with_label("Rest until %s (%s)" % [milestone.text,
						WorldClock.format_duration(milestone.minutes)]))
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
		EncounterChoice.ACTION_OPEN_COLLECTION:
			collection_requested.emit()
			return ""
		EncounterChoice.ACTION_REST_UNTIL:
			var milestone := next_rest_milestone()
			if milestone.is_empty():
				return "There is nothing to wait for right now."
			clock.advance(milestone.minutes)
			return "You rest at camp for %s. Now %s." % [WorldClock.format_duration(milestone.minutes), milestone.text]
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
	var here := locations.at_cell(adventurer_cell)
	var place: String = here.name if here != null else "the roadside"
	var origin := ""
	if egg.parent_ids.size() == 2:
		origin = "Hatched at %s; bred from %s and %s" % [place, _name_of(egg.parent_ids[0]), _name_of(egg.parent_ids[1])]
	else:
		var nest := locations.get_by_id(egg.origin_location_id)
		origin = "Hatched at %s from an egg found at %s" % [place, nest.name if nest != null else "the wild"]
	var dragon := Hatching.hatch(egg, new_id("dragon"), chosen_name, clock.total_minutes, origin)
	eggs.remove(egg_id)
	_ready_announced.erase(egg_id)
	roster.add(dragon)
	lineage.record(dragon)
	if party_ids.size() < MAX_PARTY:
		party_ids.append(dragon.id)
		party_changed.emit()
	dragon_hatched.emit(dragon)
	return dragon


func _name_of(id: String) -> String:
	var entry := lineage.get_entry(id)
	return str(entry.get("name", "an unknown dragon"))


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
