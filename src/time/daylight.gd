class_name Daylight
extends RefCounted
## World tint for the time of day. Nights stay readable rather than dark.

const KEYS := [
	[0.0, Color(0.56, 0.6, 0.82)],
	[4.5, Color(0.58, 0.62, 0.84)],
	[6.5, Color(1.0, 0.84, 0.76)],
	[9.0, Color(1.0, 1.0, 0.98)],
	[16.5, Color(1.0, 0.98, 0.94)],
	[19.0, Color(1.0, 0.78, 0.64)],
	[21.0, Color(0.66, 0.66, 0.86)],
	[24.0, Color(0.56, 0.6, 0.82)],
]


static func color_at(hour: float) -> Color:
	var h := fposmod(hour, 24.0)
	for i in KEYS.size() - 1:
		var a: Array = KEYS[i]
		var b: Array = KEYS[i + 1]
		if h >= a[0] and h <= b[0]:
			return (a[1] as Color).lerp(b[1], (h - a[0]) / (b[0] - a[0]))
	return KEYS[0][1]
