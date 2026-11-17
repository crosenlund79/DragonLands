class_name UiStyle
extends RefCounted
## Shared look for HUD panels and the encounter dialog.

const TEXT := Color(0.97, 0.92, 0.82)
const MUTED := Color(0.8, 0.74, 0.62)
const GOLD := Color(0.88, 0.72, 0.42)


static func panel(alpha: float = 0.84) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.11, 0.09, 0.07, alpha)
	box.border_color = Color(GOLD, 0.85)
	box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	box.shadow_color = Color(0, 0, 0, 0.35)
	box.shadow_size = 6
	box.set_content_margin_all(10)
	return box


static func label(text: String, size: int, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 17)
	var normal := panel(0.95)
	normal.bg_color = Color(0.2, 0.16, 0.11, 0.95)
	normal.set_content_margin_all(8)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.32, 0.24, 0.14, 0.98)
	hover.border_color = Color(1.0, 0.85, 0.5)
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color(1, 0.97, 0.88))
	return b
