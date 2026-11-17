class_name TraitCatalog
extends RefCounted
## The heritable gameplay traits. Order matters: the genetics engine rolls them in this order.
## Only "active" traits affect play today; the others are inherited and shown, ready for later systems.

const KEEN_SIGHT := "keen_sight"
const SHORT_SIGHT := "short_sight"
const SIGHT_PER_TIER := 0.15  ## Extra scouting radius (cells) per Keen Sight tier.
const SHORT_SIGHT_PER_TIER := 0.10  ## Scouting radius lost (cells) per Short Sight tier.

const TRAITS := [
	{"id": "keen_sight", "name": "Keen Sight", "positive": true, "active": true,
		"about": "Spots land from further away: the party scouts +0.15 cells per tier."},
	{"id": "strong_wings", "name": "Strong Wings", "positive": true, "active": false,
		"about": "Powerful flight. Not used in play yet (future: longer flights and expeditions)."},
	{"id": "thick_scales", "name": "Thick Scales", "positive": true, "active": false,
		"about": "Tough hide. Not used in play yet (future: resilience)."},
	{"id": "steady_heart", "name": "Steady Heart", "positive": true, "active": false,
		"about": "Calm and loyal. Not used in play yet (future: bonding)."},
	{"id": "short_sight", "name": "Short Sight", "positive": false, "active": true,
		"about": "Poor eyesight: scouts 0.10 cells less per tier."},
	{"id": "brittle_scales", "name": "Brittle Scales", "positive": false, "active": false,
		"about": "Fragile hide. Not used in play yet (future: fragility)."},
	{"id": "weak_wings", "name": "Weak Wings", "positive": false, "active": false,
		"about": "Tires quickly in flight. Not used in play yet (future: shorter flights)."},
]


static func ids() -> Array[String]:
	var result: Array[String] = []
	for t in TRAITS:
		result.append(t.id)
	return result


static func has_trait(id: String) -> bool:
	return ids().has(id)


static func info(id: String) -> Dictionary:
	for t in TRAITS:
		if t.id == id:
			return t
	return {}


static func display_name(id: String) -> String:
	return str(info(id).get("name", id))


static func is_positive(id: String) -> bool:
	return bool(info(id).get("positive", true))


## Net scouting radius change (cells) a single dragon with this genome provides.
static func scouting_of(genome: Genome) -> float:
	if genome == null:
		return 0.0
	return genome.tier(KEEN_SIGHT) * SIGHT_PER_TIER - genome.tier(SHORT_SIGHT) * SHORT_SIGHT_PER_TIER


static func roman(tier: int) -> String:
	const NUMERALS := ["", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]
	return NUMERALS[clampi(tier, 0, 10)]
