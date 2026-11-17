class_name BreedingRules
extends RefCounted
## When two owned dragons may breed. No sexes in this prototype: any two different adults
## of the same species are compatible, so the player can never hit a compatibility dead end.

const BREEDING_MINUTES := 180.0  ## In-game time spent at camp for one pairing.
const COOLDOWN_MINUTES := 24.0 * 60.0  ## Rest each parent needs before breeding again.
const MAX_CARRIED_EGGS := 4


static func cooldown_left(dragon: DragonRecord, now: float) -> float:
	var left := dragon.last_bred_at + COOLDOWN_MINUTES - now
	return left if left > WorldClock.EPSILON else 0.0


## Why `dragon` cannot breed right now ("" = it can).
static func dragon_problem(dragon: DragonRecord, now: float) -> String:
	var stage := dragon.stage(now)
	if stage != DragonSpecies.Stage.ADULT:
		var left := dragon.species().adult_at_minutes - dragon.age_minutes(now)
		return "%s is still a %s (adult in %s)" % [dragon.name, DragonSpecies.STAGE_NAMES[stage].to_lower(),
			WorldClock.format_duration(left)]
	if cooldown_left(dragon, now) > 0.0:
		return "%s is resting after breeding (%s left)" % [dragon.name, WorldClock.format_duration(cooldown_left(dragon, now))]
	return ""


## Why `a` and `b` cannot be paired right now ("" = they can).
static func pair_problem(a: DragonRecord, b: DragonRecord, now: float) -> String:
	if a == null or b == null:
		return "Choose two dragons"
	if a.id == b.id:
		return "Choose two different dragons"
	if a.species_id != b.species_id:
		return "%s and %s are different species (only same-species pairs for now)" % [a.name, b.name]
	var problem := dragon_problem(a, now)
	return problem if problem != "" else dragon_problem(b, now)
