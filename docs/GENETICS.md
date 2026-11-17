# DragonLands genetics (Prototype 003)

All rules and numbers below are **original to DragonLands**. They were designed for this game and are not taken from Dragon Adventures or any other game. Code: `src/genetics/` (`GeneticsEngine`, `Genome`, `TraitCatalog`); tests: `tests/unit/test_genetics.gd`.

## Principles

- **Genes are fixed when the egg is created.** Breeding or finding an egg decides the full genome right away and stores it in the egg. Hatching copies it, and saving or loading can never re-roll it.
- **Deterministic and seedable.** Each egg has its own seed, and one random generator draws every roll in a fixed order. The same parents with the same seed always give the same offspring.
- **Cosmetic and gameplay genes are separate.** Colours and markings only change appearance; traits are the gameplay genes.

## Cosmetic genes

| Gene | Values | Inheritance |
| --- | --- | --- |
| Body colour (primary) | HSV colour | Independent random point between the parents' colours (hue along the shorter way round) |
| Belly colour (secondary) | HSV colour | Same, rolled independently |
| Wings & crest colour (accent) | HSV colour | Same, rolled independently |
| Markings pattern | plain, speckled, striped, dappled | Either parent's pattern (50/50). Then a **4%** chance it changes to one of the other three (1/3 each) |
| Markings strength | 0.15–1.0 | A random point between the parents' strengths, ±0.05 |

On top of the blend, every colour channel gets:
- a tiny drift every time: hue ±0.01, saturation ±0.03, value ±0.03;
- a **5% chance of a colour shift**, a clearly new shade: hue moves ±0.10 and value ±0.12.

Colours are drawn on the shared template art with a mask: red marks the body, green the belly, blue the wings and crest. Each region keeps the art's shading. Markings are drawn procedurally on the body. Fernback dapples, eyes, horns and flame tips keep their original colours.

## Gameplay traits (tiers 1–10)

| Trait | Kind | Effect today |
| --- | --- | --- |
| Keen Sight | positive | **Active:** the party scouts +0.15 cells per tier |
| Strong Wings | positive | Future (flight / expeditions) |
| Thick Scales | positive | Future (resilience) |
| Steady Heart | positive | Future (bonding) |
| Short Sight | negative | **Active:** scouts 0.10 cells less per tier |
| Brittle Scales | negative | Future (fragility) |
| Weak Wings | negative | Future (flight) |

**Party scouting.** The party's scouting bonus comes from its best travelling dragon: Keen Sight tier × 0.15, minus Short Sight tier × 0.10. The bonus is clamped to −1…+2 cells and added to the base sight of 5.5 cells. It only takes effect while that dragon is in the travelling party.

### Tier inheritance, per trait

| Parents | Result |
| --- | --- |
| Both carry it, **same tier t** | Child gets tier t, then +1 with the *matched chance* (table below), else −1 with 10% (minimum I), else stays t |
| Both carry it, different tiers | Child takes one parent's tier (50/50), then +1 with 10%, else −1 with 10% |
| Only one parent carries it (tier t) | 50%: passed on at tier t; 50%: not inherited |
| Neither parent carries it | 2%: appears at tier I (spontaneous variation) |

The **matched chance** to gain a tier is 35% at tier I and drops 3 points per tier, down to a minimum of 8%. Tier X is the cap.

| Parent tier | I | II | III | IV | V | VI | VII | VIII | IX | X |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Chance of +1 | 35% | 32% | 29% | 26% | 23% | 20% | 17% | 14% | 11% | 8% (stays X) |

Example: two Keen Sight III parents give IV 29%, III 61%, II 10%.

Negative traits follow the same rules, so pairing two carriers tends to make the problem worse. Selective breeding means pairing the best matched dragons and keeping the offspring that improved. In tests, keeping the two best dragons of each generation raises a trait from II to V or more within 12 generations.

The breeding screen shows these exact odds for the chosen pair. The engine computes them with `GeneticsEngine.tier_distribution` and `pattern_distribution`, and the tests check them against 20,000 sampled outcomes per case.

## Wild-born dragons

Eggs found in the wild have unknown parents and are generation 0.
- **Colours:** the species colours, ±0.06 hue, ±0.15 saturation, ±0.12 value.
- **Markings:** any pattern with equal chance, strength 0.3–0.8.
- **Positive traits:** each has a 30% chance, at tier I (or tier II one time in three).
- **Negative traits:** each has a 12% chance, at tier I.

The starting dragons are fixed:
- **Ember:** Keen Sight II, Strong Wings I.
- **Moss:** Thick Scales II, Steady Heart I.

Both have plain markings and the species template colours, so they look exactly like their original art.

## Breeding rules

- **Who can pair:** any two different adults of the same species. There are no sexes in this prototype, so a fresh game can always pair Ember with the nest hatchling once it is grown. Hybrids are not possible yet, and pairing relatives has no penalty yet.
- **Time:** pairing takes 3 in-game hours at Wayfarer's Camp. Each parent then rests 24 in-game hours.
- **Eggs:** you can carry at most 4. A Cinderwing egg incubates for 12 hours.
- **Growth:** a hatchling becomes a juvenile at 1 day and an adult at 4 days.
- **Lineage:** offspring generation = the higher parent generation + 1. Parent ids are stored on every dragon, and the lineage book keeps an entry for every dragon ever owned.
- **Waiting:** resting at camp ("Rest until…", "Rest for a day") moves the world clock. Nothing depends on real-world time.

## Saves

Save format version 2 stores every genome, parent ids, generation, inheritance notes, breeding cooldowns, the travelling party and the lineage book.

Version 1 saves from Prototype 002 load with genomes added:
- Ember and Moss get their fixed genomes.
- Other dragons get a wild genome seeded by their id.
- A carried egg gets a wild genome from its own stored seed.

The same save therefore upgrades the same way every time.
