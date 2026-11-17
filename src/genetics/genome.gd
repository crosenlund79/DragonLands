class_name Genome
extends RefCounted
## A dragon's complete heritable makeup, fixed when its egg is created and never re-rolled.
## Cosmetic genes (three colour channels, markings) are kept apart from gameplay traits.

const CHANNELS: Array[String] = ["primary", "secondary", "accent"]  ## Body, belly, wings/fronds.
const CHANNEL_NAMES := {"primary": "Body", "secondary": "Belly", "accent": "Wings & crest"}
const PATTERNS: Array[String] = ["plain", "speckled", "striped", "dappled"]
const FORMAT := 1

var colors: Dictionary = {}  ## channel -> Vector3(hue, saturation, value), each 0..1.
var pattern := "plain"
var pattern_strength := 0.5  ## 0..1, how bold the markings are.
var traits: Dictionary = {}  ## trait id -> tier 1..10 (absent = 0).


static func create(p_colors: Dictionary, p_pattern: String, p_strength: float, p_traits: Dictionary) -> Genome:
	var g := Genome.new()
	for ch in CHANNELS:
		g.colors[ch] = p_colors[ch]
	g.pattern = p_pattern
	g.pattern_strength = p_strength
	for id in p_traits:
		if int(p_traits[id]) > 0:
			g.traits[id] = clampi(int(p_traits[id]), 1, GeneticsEngine.MAX_TIER)
	return g


func color(channel: String) -> Color:
	var c: Vector3 = colors[channel]
	return Color.from_hsv(c.x, c.y, c.z)


func tier(trait_id: String) -> int:
	return int(traits.get(trait_id, 0))


func to_dict() -> Dictionary:
	var c := {}
	for ch in CHANNELS:
		var v: Vector3 = colors[ch]
		c[ch] = [snappedf(v.x, 0.0001), snappedf(v.y, 0.0001), snappedf(v.z, 0.0001)]
	var t := {}
	for id in TraitCatalog.ids():
		if tier(id) > 0:
			t[id] = tier(id)
	return {"format": FORMAT, "colors": c, "pattern": pattern, "pattern_strength": snappedf(pattern_strength, 0.0001),
		"traits": t}


## Rebuilds a genome from to_dict() output; null if anything is missing or malformed.
static func from_dict(data: Dictionary) -> Genome:
	if not data.has("colors") or not (data.colors is Dictionary) or not PATTERNS.has(str(data.get("pattern", ""))):
		return null
	var g := Genome.new()
	for ch in CHANNELS:
		var v: Variant = data.colors.get(ch)
		if not (v is Array) or v.size() != 3:
			return null
		g.colors[ch] = Vector3(clampf(float(v[0]), 0.0, 1.0), clampf(float(v[1]), 0.0, 1.0), clampf(float(v[2]), 0.0, 1.0))
	g.pattern = str(data.pattern)
	g.pattern_strength = clampf(float(data.get("pattern_strength", 0.5)), 0.0, 1.0)
	var t: Variant = data.get("traits", {})
	if not (t is Dictionary):
		return null
	for id in t:
		if TraitCatalog.has_trait(str(id)) and int(t[id]) > 0:
			g.traits[str(id)] = clampi(int(t[id]), 1, GeneticsEngine.MAX_TIER)
	return g


func same_as(other: Genome) -> bool:
	return other != null and to_dict() == other.to_dict()
