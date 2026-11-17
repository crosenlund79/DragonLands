class_name ElderwoodVale
extends RefCounted
## Handcrafted data for the first region: terrain layout, start and locations.
## Legend:  . meadow   t woodland   T deep forest   = road   B bridge
##          ~ river/lake   M mountains   r rocky hills
## Locations stand on passable cells; walking onto one (as the route's destination) opens its panel.

const REGION_NAME := "Elderwood Vale"
const START_CELL := Vector2i(4, 17)
const START_MINUTES := 8.0 * 60.0

const ROWS: Array[String] = [
	"MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM",  # 0
	"MMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMMM",  # 1
	"TTTTMMMMMMMMMMMMMMrrrMMMMMMrrrMMMMMMMMMMMMMMMMMM",  # 2
	"TTTTTTTTTTMMMMtt.....rr~rr..MMMMMMMMMMMMMMMMMMMM",  # 3
	"TTTTTTTTTTTTttt.....t..~.t.trrrMMMMMMMMrrrrMMMMM",  # 4
	"TTTTTTTTTTTTTtt....t...~t.ttrMMMMMMMMMrrrrrrrMMM",  # 5
	"TTTTTTTTTTTTTTTtttt....~.....rrrrrMMMrrrrrrrrMMM",  # 6
	"TTTTTTTTTTTTTTttt......~....rrrrrrMMMrrrrrrrrrMM",  # 7
	"TTTTTTTTTTTTTTttt.....~~tTTtrrrrrrMMMMrrrrrrrMMM",  # 8
	"TTTTTTTTTTTTTttttt....~.TTTTrrrrrrMMMMrrrrrrrMMM",  # 9
	"TTTTTTTTTTTTttt....t..~.TTTTt.rrrrMMMMrrMMMMMMMM",  # 10
	"TTTTTTTTTTttt.........~tTTTTt...=.MMMMrMMMMMMMMM",  # 11
	"TTTTTTTTttt..........~~tTTTTt...=.MMMMrMMMMMMMMM",  # 12
	"tttt.t.........tt....~.tTTTTt..==.MMMrrMMMMMMMrM",  # 13
	".t..............t....~..ttttt..=..MrrMrrMMMrrrrr",  # 14
	".........t...t.......~.........=......r.rrrrrrrr",  # 15
	"...........========..~.........=......r.........",  # 16
	"============......===B==========================",  # 17
	".....................~.....=......t......tt.....",  # 18
	"........TTTTT...t....~.....=........t........t..",  # 19
	"..t....tTTTTTt.......~.....=....tttttttttttttttt",  # 20
	"...t....TTTTT.......~~.....=..ttTTTTTTTTTTTTTTTT",  # 21
	".......ttttttt.t....~......==...TTTTTTTTTTTTTTTT",  # 22
	"...................~~.......=...TTTTTTTTTTTTTTTT",  # 23
	"..t...............~~........=...TTTTTTTTTTTTTTTT",  # 24
	"....t....~~~~~...~~.ttttttt.=tttTTTTTTTTT.TTTTTT",  # 25
	"...t...~~~~~~~~~~~...TTTTT...tttttttTTTt...tTTTT",  # 26
	"......~~~~~~~~~~.t...TTTTT...tt.TTTtttt.....TTTT",  # 27
	".....~~~~~~~~~~~t....TTTTT......TTTTTT.......TTT",  # 28
	".....~~~~~~~~~~......TTTTT......TTTTTTT.....TTTT",  # 29
	"..t...~~~~~~~~.....ttttt.tttttttTTTTTTTt...tTTTT",  # 30
	"ttttttt.~~~~TTTTTTTTTTTTTTTTTTTTTTTTTTTTT.TTTTTT",  # 31
	"TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",  # 32
	"TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",  # 33
	"TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",  # 34
	"TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT",  # 35
]


static func create_map() -> RegionMap:
	return RegionMap.from_rows(REGION_NAME, ROWS)


static func create_locations() -> LocationRegistry:
	var registry := LocationRegistry.new()
	registry.add(Location.new("camp", "Wayfarer's Camp", Vector2i(3, 16), Location.Kind.CAMP,
		"landmarks/camp", Encounter.new("Wayfarer's Camp",
			"Your camp at the western edge of the Elderwood. Ember dozes beside last night's fire while Moss noses through the packs for dried apples.",
			"landmarks/camp", [
				EncounterChoice.new("hatch", "Hatch the egg", "", 0.0, 0.0, EncounterChoice.ACTION_HATCH_EGG),
				EncounterChoice.new("warm", "Keep the egg warm until it hatches", "", 0.0, 0.0,
					EncounterChoice.ACTION_WARM_EGG),
				EncounterChoice.new("rest", "Rest by the fire (1h)",
					"You rest a while. Moss curls around your boots; Ember keeps one golden eye on the road.", 60.0),
				EncounterChoice.new("leave", "Set out"),
			])))
	registry.add(Location.new("watchtower", "Old Watchtower", Vector2i(32, 9), Location.Kind.LOOKOUT,
		"landmarks/watchtower", Encounter.new("Old Watchtower",
			"A broken tower of grey stone leans over the rocky spur. Its stair still climbs most of the way up.",
			"landmarks/watchtower", [
				EncounterChoice.new("climb", "Climb to the top (30m)",
					"From the top you see the whole vale: the river glinting south toward the lake, smoke above a lodge - and far to the north-east, a thin plume rising between the peaks.",
					30.0, 11.0),
				EncounterChoice.new("leave", "Move on"),
			])))
	registry.add(Location.new("lodge", "Woodcutter's Lodge", Vector2i(28, 26), Location.Kind.LANDMARK,
		"landmarks/lodge", Encounter.new("Woodcutter's Lodge",
			"A low timber lodge with moss on its roof. Fresh chips lie around the chopping block, but the woodcutter is away. A carved sign points east: \"Stones - mind the trail.\"",
			"landmarks/lodge", [
				EncounterChoice.new("rest", "Rest by the woodpile (2h)",
					"You doze in the sun. When you wake, Moss has stacked three logs - badly - and looks very proud.", 120.0),
				EncounterChoice.new("leave", "Move on"),
			])))
	registry.add(Location.new("stones", "Whisperstones", Vector2i(41, 28), Location.Kind.LANDMARK,
		"landmarks/standing_stones", Encounter.new("Whisperstones",
			"Seven mossy standing stones ring a quiet clearing. When the wind passes between them, they hum. Moss presses close to the tallest stone and hums back.",
			"landmarks/standing_stones", [
				EncounterChoice.new("listen", "Listen (20m)",
					"The humming rises and falls like breath. Ember lands beside you, unusually still. Whatever the stones remember, the dragons seem to know it too.", 20.0),
				EncounterChoice.new("leave", "Leave quietly"),
			])))
	registry.add(Location.new("nest", "Emberfall Nest", Vector2i(42, 6), Location.Kind.DRAGON_NEST,
		"landmarks/dragon_nest", Encounter.new("Emberfall Nest",
			"In a hollow of warm black rock lies a nest of charred branches and moss. Three speckled eggs glow faintly in the ash. Above, a wild Cinderwing circles - watching you, and watching Ember.",
			"landmarks/dragon_nest", [
				EncounterChoice.new("approach", "Approach slowly (30m)",
					"You kneel at the rim, hands open. The wild dragon lands on a crag and rumbles; Ember answers with a soft chirr. At last it settles over its eggs and lets you stay. You sketch the nest and its three eggs.", 30.0),
				EncounterChoice.new("ember", "Let Ember greet it (15m)",
					"Ember glides up to the crag. The two drakes trade curls of smoke and low clicks. When Ember returns it smells of warm ash - and looks very pleased with itself.", 15.0),
				EncounterChoice.new("egg", "Ask, through Ember, for an egg (45m)",
					"Ember lands beside the wild Cinderwing. For a long while they trade smoke and low clicks. At last the wild dragon noses one speckled egg to the rim of the nest and steps back. You wrap it in your cloak. It is warm, and something inside shifts.\n\nKeep it with you; return to Wayfarer's Camp when it is ready to hatch.",
					45.0, 0.0, EncounterChoice.ACTION_TAKE_EGG, "cinderwing"),
				EncounterChoice.new("leave", "Withdraw quietly"),
			], "Two speckled eggs glow in the ash where three once lay. The wild Cinderwing watches from its crag, calm now - it knows you, and it knows Ember.")))
	return registry
