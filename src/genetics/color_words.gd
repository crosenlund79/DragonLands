class_name ColorWords
extends RefCounted
## Short, readable names for genome colours (e.g. "bright amber", "deep jade").

const HUES := [
	[0.015, "crimson"], [0.045, "scarlet"], [0.075, "flame"], [0.105, "amber"], [0.15, "gold"],
	[0.19, "citrine"], [0.25, "fern"], [0.36, "jade"], [0.47, "teal"], [0.58, "azure"],
	[0.7, "indigo"], [0.8, "violet"], [0.92, "rose"], [1.01, "crimson"],
]


static func describe(hsv: Vector3) -> String:
	var h := hsv.x
	var s := hsv.y
	var v := hsv.z
	var noun := ""
	if s < 0.2:
		noun = "ash" if v < 0.55 else ("pearl" if v > 0.85 else "silver")
	else:
		for entry in HUES:
			if h < entry[0]:
				noun = entry[1]
				break
	var adjective := ""
	if s < 0.2:
		return ("dark " if v < 0.35 else "") + noun
	if v < 0.45:
		adjective = "dark "
	elif v < 0.62:
		adjective = "deep "
	elif s < 0.42 and v > 0.8:
		adjective = "pale "
	elif v > 0.88 and s > 0.55:
		adjective = "bright "
	return adjective + noun
