class_name GeneticsEngine
extends RefCounted
## Original, transparent inheritance rules (documented in docs/GENETICS.md; these are our own
## numbers, not any other game's odds). Every roll comes from one RNG seeded per egg, in a
## fixed order, so the same parents and seed always produce the same offspring.

const MAX_TIER := 10
## Trait carried by both parents at the SAME tier t: chance the child gains a tier.
## 35% at tier 1, 3 points less per tier, never below 8% (tier 10 cannot go higher).
const UP_MATCHED_BASE := 0.35
const UP_MATCHED_STEP := 0.03
const UP_MATCHED_MIN := 0.08
const UP_UNMATCHED := 0.10  ## Both parents carry it at different tiers: chance of +1.
const DOWN := 0.10  ## Both parents carry it: chance of -1 (never below tier 1).
const SINGLE_PARENT := 0.5  ## Only one parent carries it: chance it is passed on, at that tier.
const SPONTANEOUS := 0.02  ## Neither parent carries it: chance it appears at tier 1.
const COLOR_DRIFT := Vector3(0.01, 0.03, 0.03)  ## Always-on tiny hue / saturation / value wobble.
const COLOR_SHIFT_CHANCE := 0.05  ## Per colour channel: a clearly new shade.
const COLOR_SHIFT_HUE := 0.10
const COLOR_SHIFT_VALUE := 0.12
const PATTERN_VARIATION := 0.04  ## Chance the inherited markings pattern changes to one of the other three.
const STRENGTH_DRIFT := 0.05
const WILD_POSITIVE := 0.30  ## Wild-born dragons: chance of each positive trait (tier 1, or 2 one time in three).
const WILD_NEGATIVE := 0.12  ## Wild-born dragons: chance of each negative trait (tier 1).


## Offspring genome of `a` x `b`. Pure function of its inputs.
static func breed(a: Genome, b: Genome, seed: int) -> Genome:
	var rng := _rng(seed)
	var child := Genome.new()
	for ch in Genome.CHANNELS:
		child.colors[ch] = _inherit_color(a.colors[ch], b.colors[ch], rng)
	child.pattern = a.pattern if rng.randf() < 0.5 else b.pattern
	if rng.randf() < PATTERN_VARIATION:
		var others := Genome.PATTERNS.filter(func(p: String) -> bool: return p != child.pattern)
		child.pattern = others[rng.randi_range(0, others.size() - 1)]
	child.pattern_strength = clampf(lerpf(a.pattern_strength, b.pattern_strength, rng.randf())
		+ rng.randf_range(-STRENGTH_DRIFT, STRENGTH_DRIFT), 0.15, 1.0)
	for id in TraitCatalog.ids():
		var t := inherit_tier(a.tier(id), b.tier(id), rng)
		if t > 0:
			child.traits[id] = t
	return child


static func matched_up_chance(tier: int) -> float:
	return maxf(UP_MATCHED_MIN, UP_MATCHED_BASE - UP_MATCHED_STEP * (tier - 1))


## One trait's inherited tier (0 = absent) from parent tiers `a` and `b`.
static func inherit_tier(a: int, b: int, rng: RandomNumberGenerator) -> int:
	if a > 0 and b > 0:
		var base := a if rng.randf() < 0.5 else b
		var up := matched_up_chance(a) if a == b else UP_UNMATCHED
		var roll := rng.randf()
		if roll < up:
			return mini(base + 1, MAX_TIER)
		if roll < up + DOWN:
			return maxi(base - 1, 1)
		return base
	if a > 0 or b > 0:
		return maxi(a, b) if rng.randf() < SINGLE_PARENT else 0
	return 1 if rng.randf() < SPONTANEOUS else 0


## Exact outcome probabilities of inherit_tier(): {tier: probability}, 0 = absent.
static func tier_distribution(a: int, b: int) -> Dictionary:
	var d := {}
	if a > 0 and b > 0:
		var up := matched_up_chance(a) if a == b else UP_UNMATCHED
		for base in [a, b]:
			_add(d, mini(base + 1, MAX_TIER), 0.5 * up)
			_add(d, maxi(base - 1, 1), 0.5 * DOWN)
			_add(d, base, 0.5 * (1.0 - up - DOWN))
	elif a > 0 or b > 0:
		_add(d, maxi(a, b), SINGLE_PARENT)
		_add(d, 0, 1.0 - SINGLE_PARENT)
	else:
		_add(d, 1, SPONTANEOUS)
		_add(d, 0, 1.0 - SPONTANEOUS)
	return d


## Exact markings-pattern probabilities for a pairing: {pattern: probability}.
static func pattern_distribution(a: Genome, b: Genome) -> Dictionary:
	var d := {}
	for chosen in [a.pattern, b.pattern]:
		for p in Genome.PATTERNS:
			_add(d, p, 0.5 * ((1.0 - PATTERN_VARIATION) if p == chosen else PATTERN_VARIATION / 3.0))
	return d


## Genome of a wild-born dragon (unknown parents), e.g. an egg found in a nest.
static func wild(species: DragonSpecies, seed: int) -> Genome:
	var rng := _rng(seed)
	var g := Genome.new()
	for ch in Genome.CHANNELS:
		var base: Vector3 = species.base_colors[ch]
		var spread := species.wild_color_spread
		g.colors[ch] = Vector3(
			fposmod(base.x + rng.randf_range(-spread.x, spread.x), 1.0),
			clampf(base.y + rng.randf_range(-spread.y, spread.y), 0.1, 1.0),
			clampf(base.z + rng.randf_range(-spread.z, spread.z), 0.2, 1.0))
	g.pattern = Genome.PATTERNS[rng.randi_range(0, Genome.PATTERNS.size() - 1)]
	g.pattern_strength = rng.randf_range(0.3, 0.8)
	for id in TraitCatalog.ids():
		if TraitCatalog.is_positive(id):
			if rng.randf() < WILD_POSITIVE:
				g.traits[id] = 2 if rng.randf() < 1.0 / 3.0 else 1
		elif rng.randf() < WILD_NEGATIVE:
			g.traits[id] = 1
	return g


## Plain-language inheritance notes for an offspring, derived by comparing genomes.
static func describe(a: Genome, b: Genome, child: Genome, a_name: String, b_name: String) -> PackedStringArray:
	var notes := PackedStringArray()
	for ch in Genome.CHANNELS:
		var label: String = Genome.CHANNEL_NAMES[ch]
		var word := ColorWords.describe(child.colors[ch])
		var pos := blend_position(a.colors[ch], b.colors[ch], child.colors[ch])
		if pos < -0.5:
			notes.append("%s: %s - a colour shift, a new shade!" % [label, word])
		elif a.colors[ch].distance_to(b.colors[ch]) < 0.02:
			notes.append("%s: %s, like both parents" % [label, word])
		elif pos < 0.35:
			notes.append("%s: %s, close to %s" % [label, word, a_name])
		elif pos > 0.65:
			notes.append("%s: %s, close to %s" % [label, word, b_name])
		else:
			notes.append("%s: %s, a blend of both parents" % [label, word])
	var pattern := child.pattern.capitalize()
	if child.pattern == a.pattern and child.pattern == b.pattern:
		notes.append("Markings: %s, like both parents" % pattern)
	elif child.pattern == a.pattern:
		notes.append("Markings: %s, from %s" % [pattern, a_name])
	elif child.pattern == b.pattern:
		notes.append("Markings: %s, from %s" % [pattern, b_name])
	else:
		notes.append("Markings: %s - a new variation!" % pattern)
	for id in TraitCatalog.ids():
		var ta := a.tier(id)
		var tb := b.tier(id)
		var tc := child.tier(id)
		if ta == 0 and tb == 0 and tc == 0:
			continue
		var name := "%s %s" % [TraitCatalog.display_name(id), TraitCatalog.roman(tc)]
		if tc == 0:
			notes.append("%s: not passed on" % TraitCatalog.display_name(id))
		elif ta == 0 and tb == 0:
			notes.append("%s: appeared on its own - a rare variation" % name)
		elif tc > maxi(ta, tb):
			notes.append("%s: stronger than both parents!" % name)
		elif ta > 0 and tb > 0 and tc < mini(ta, tb):
			notes.append("%s: weaker than both parents" % name)
		elif ta > 0 and tb > 0:
			notes.append("%s: carried by both parents" % name)
		else:
			notes.append("%s: from %s" % [name, a_name if ta > 0 else b_name])
	return notes


## Where `c` lies between parent colours `a` (0) and `b` (1); -1 if it is clearly off the blend line.
static func blend_position(a: Vector3, b: Vector3, c: Vector3) -> float:
	var pa := _hsv_space(a)
	var pb := _hsv_space(b, a)
	var pc := _hsv_space(c, a)
	var seg := pb - pa
	var t := 0.5 if seg.length_squared() < 0.0004 else clampf((pc - pa).dot(seg) / seg.length_squared(), 0.0, 1.0)
	return -1.0 if (pa + seg * t).distance_to(pc) > 0.07 else t


static func hsv_lerp(a: Vector3, b: Vector3, t: float) -> Vector3:
	var dh := fposmod(b.x - a.x + 0.5, 1.0) - 0.5
	return Vector3(fposmod(a.x + dh * t, 1.0), lerpf(a.y, b.y, t), lerpf(a.z, b.z, t))


static func _inherit_color(ca: Vector3, cb: Vector3, rng: RandomNumberGenerator) -> Vector3:
	var c := hsv_lerp(ca, cb, rng.randf())
	c += Vector3(rng.randf_range(-COLOR_DRIFT.x, COLOR_DRIFT.x), rng.randf_range(-COLOR_DRIFT.y, COLOR_DRIFT.y),
		rng.randf_range(-COLOR_DRIFT.z, COLOR_DRIFT.z))
	if rng.randf() < COLOR_SHIFT_CHANCE:
		c.x += COLOR_SHIFT_HUE * (1.0 if rng.randf() < 0.5 else -1.0)
		c.z += rng.randf_range(-COLOR_SHIFT_VALUE, COLOR_SHIFT_VALUE)
	return Vector3(fposmod(c.x, 1.0), clampf(c.y, 0.1, 1.0), clampf(c.z, 0.2, 1.0))


## Hue unwrapped next to `near` and weighted x2 so hue differences count like s/v differences.
static func _hsv_space(c: Vector3, near: Vector3 = Vector3(-1, 0, 0)) -> Vector3:
	var h := c.x
	if near.x >= 0.0:
		h = near.x + (fposmod(c.x - near.x + 0.5, 1.0) - 0.5)
	return Vector3(h * 2.0, c.y, c.z)


static func _add(d: Dictionary, key: Variant, p: float) -> void:
	d[key] = d.get(key, 0.0) + p


static func _rng(seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return rng
