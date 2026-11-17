extends GutTest
## Genetics engine: determinism, documented probabilities (statistically), colours, markings,
## wild genomes and gradual improvement through selective breeding.

const N := 20000


func _genome(keen: int, extra: Dictionary = {}, pattern: String = "plain") -> Genome:
	var traits := {"keen_sight": keen}
	traits.merge(extra)
	return Genome.create(SpeciesCatalog.get_species("cinderwing").base_colors, pattern, 0.5, traits)


func _colored(h: float) -> Genome:
	return Genome.create({"primary": Vector3(h, 0.7, 0.8), "secondary": Vector3(h, 0.5, 0.9),
		"accent": Vector3(h, 0.6, 0.7)}, "plain", 0.5, {})


func test_breeding_is_deterministic_for_a_seed() -> void:
	var a := _genome(3, {"thick_scales": 2}, "speckled")
	var b := _genome(2, {"short_sight": 1}, "striped")
	assert_true(GeneticsEngine.breed(a, b, 1234).same_as(GeneticsEngine.breed(a, b, 1234)))
	var distinct := {}
	for seed in 40:
		distinct[JSON.stringify(GeneticsEngine.breed(a, b, seed).to_dict())] = true
	assert_gt(distinct.size(), 30, "different seeds give different offspring")


func test_genome_round_trips_through_json() -> void:
	var g := GeneticsEngine.breed(_genome(4, {"weak_wings": 2}, "dappled"), _genome(5), 99)
	var copy := Genome.from_dict(JSON.parse_string(JSON.stringify(g.to_dict())))
	assert_true(copy.same_as(g))
	assert_eq(copy.tier("keen_sight"), g.tier("keen_sight"))
	assert_null(Genome.from_dict({}))
	assert_null(Genome.from_dict({"colors": {"primary": [0, 0, 0]}, "pattern": "plain"}))


func test_tier_distributions_are_valid_probabilities() -> void:
	for a in range(0, 11):
		for b in range(0, 11):
			var total := 0.0
			for t in GeneticsEngine.tier_distribution(a, b):
				assert_between(int(t), 0, 10)
				total += GeneticsEngine.tier_distribution(a, b)[t]
			assert_almost_eq(total, 1.0, 1e-9, "%d x %d" % [a, b])


func test_documented_numbers() -> void:
	assert_almost_eq(GeneticsEngine.matched_up_chance(1), 0.35, 1e-9)
	assert_almost_eq(GeneticsEngine.matched_up_chance(5), 0.23, 1e-9)
	assert_almost_eq(GeneticsEngine.matched_up_chance(10), 0.08, 1e-9)
	var d := GeneticsEngine.tier_distribution(3, 3)
	assert_almost_eq(d[4], 0.29, 1e-9, "matched tier 3: 29% to reach tier 4")
	assert_almost_eq(d[2], 0.10, 1e-9)
	assert_almost_eq(d[3], 0.61, 1e-9)
	assert_almost_eq(GeneticsEngine.tier_distribution(4, 0)[4], 0.5, 1e-9, "one carrier: 50%")
	assert_almost_eq(GeneticsEngine.tier_distribution(0, 0)[1], 0.02, 1e-9, "spontaneous: 2%")
	assert_false(GeneticsEngine.tier_distribution(10, 10).has(11), "capped at tier 10")


func test_sampled_tiers_match_the_documented_distribution() -> void:
	for pair in [[3, 3], [1, 1], [2, 5], [6, 0], [0, 0], [10, 10], [9, 9]]:
		var counts := {}
		var rng := RandomNumberGenerator.new()
		rng.seed = 777 + pair[0] * 31 + pair[1]
		for i in N:
			var t := GeneticsEngine.inherit_tier(pair[0], pair[1], rng)
			counts[t] = counts.get(t, 0) + 1
		var expected := GeneticsEngine.tier_distribution(pair[0], pair[1])
		for t in expected:
			assert_almost_eq(float(counts.get(t, 0)) / N, expected[t], 0.012, "%s -> tier %d" % [str(pair), t])
		for t in counts:
			assert_true(expected.has(t), "%s produced unexpected tier %d" % [str(pair), t])


func test_colour_channels_blend_between_parents_and_inherit_independently() -> void:
	var a := _colored(0.02)
	var b := _colored(0.12)
	var positions := {"primary": [], "secondary": [], "accent": []}
	var shifts := 0
	for seed in 4000:
		var child := GeneticsEngine.breed(a, b, seed)
		for ch in Genome.CHANNELS:
			var p := GeneticsEngine.blend_position(a.colors[ch], b.colors[ch], child.colors[ch])
			if p < 0.0:
				shifts += 1
			else:
				positions[ch].append(p)
	var shift_rate := float(shifts) / (4000 * 3)
	assert_almost_eq(shift_rate, GeneticsEngine.COLOR_SHIFT_CHANCE, 0.012, "documented colour-shift rate")
	for ch in positions:
		var mean := 0.0
		for p in positions[ch]:
			mean += p
		assert_almost_eq(mean / positions[ch].size(), 0.5, 0.03, "%s blends evenly" % ch)
	var n := mini(positions.primary.size(), positions.accent.size())
	assert_lt(absf(_correlation(positions.primary.slice(0, n), positions.accent.slice(0, n))), 0.08,
		"channels are inherited independently")


func test_markings_follow_the_documented_distribution() -> void:
	var a := _genome(0, {}, "speckled")
	var b := _genome(0, {}, "striped")
	var counts := {}
	for seed in N:
		var p := GeneticsEngine.breed(a, b, seed).pattern
		counts[p] = counts.get(p, 0) + 1
	var expected := GeneticsEngine.pattern_distribution(a, b)
	assert_almost_eq(expected["speckled"], 0.4867, 0.0001)
	for p in expected:
		assert_almost_eq(float(counts.get(p, 0)) / N, expected[p], 0.012, p)


func test_wild_genomes_are_deterministic_and_species_typical() -> void:
	var species := SpeciesCatalog.get_species("cinderwing")
	assert_true(GeneticsEngine.wild(species, 5).same_as(GeneticsEngine.wild(species, 5)))
	var with_keen := 0
	for seed in 3000:
		var g := GeneticsEngine.wild(species, seed)
		var base: Vector3 = species.base_colors.primary
		assert_lt(absf(g.colors.primary.y - base.y), species.wild_color_spread.y + 0.001)
		if g.tier("keen_sight") > 0:
			with_keen += 1
			assert_lte(g.tier("keen_sight"), 2)
	assert_almost_eq(with_keen / 3000.0, GeneticsEngine.WILD_POSITIVE, 0.03)


func test_selective_breeding_improves_a_trait_over_generations() -> void:
	# Keep the two best Keen Sight dragons each generation; raise four eggs per generation.
	var best: Array[Genome] = [_genome(2), _genome(2)]
	var seed := 1
	for generation in 12:
		var candidates: Array[Genome] = best.duplicate()
		for i in 4:
			candidates.append(GeneticsEngine.breed(best[0], best[1], seed))
			seed += 1
		candidates.sort_custom(func(x: Genome, y: Genome) -> bool: return x.tier("keen_sight") > y.tier("keen_sight"))
		best = [candidates[0], candidates[1]]
	assert_gte(best[0].tier("keen_sight"), 5, "tier 2 -> 5+ within 12 generations of selection")


func test_notes_explain_the_inheritance() -> void:
	var a := _genome(3, {"thick_scales": 1}, "speckled")
	var b := _genome(3, {}, "speckled")
	var improved: Genome = null
	for seed in 200:
		var child := GeneticsEngine.breed(a, b, seed)
		if child.tier("keen_sight") == 4:
			improved = child
			break
	assert_not_null(improved)
	var notes := "\n".join(GeneticsEngine.describe(a, b, improved, "Ember", "Pip"))
	assert_string_contains(notes, "Keen Sight IV: stronger than both parents!")
	assert_string_contains(notes, "Markings: Speckled, like both parents")
	assert_string_contains(notes, "Body:")


func test_colour_words() -> void:
	assert_eq(ColorWords.describe(Vector3(0.11, 0.6, 0.96)), "bright gold")
	assert_eq(ColorWords.describe(Vector3(0.09, 0.7, 0.8)), "amber")
	assert_eq(ColorWords.describe(Vector3(0.33, 0.5, 0.55)), "deep jade")
	assert_eq(ColorWords.describe(Vector3(0.5, 0.05, 0.9)), "pearl")


func _correlation(xs: Array, ys: Array) -> float:
	var n := xs.size()
	var mx := 0.0
	var my := 0.0
	for i in n:
		mx += xs[i]
		my += ys[i]
	mx /= n
	my /= n
	var sxy := 0.0
	var sxx := 0.0
	var syy := 0.0
	for i in n:
		sxy += (xs[i] - mx) * (ys[i] - my)
		sxx += (xs[i] - mx) * (xs[i] - mx)
		syy += (ys[i] - my) * (ys[i] - my)
	return sxy / sqrt(sxx * syy)
