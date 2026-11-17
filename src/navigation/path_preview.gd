class_name PathPreview
extends Node2D
## Draws the hovered route (faint) and the active route (bright) as footstep dots,
## a destination ring with the estimated travel time, or a cross for blocked targets.

const DOT_SPACING := 17.0
const ACTIVE_COLOR := Color(1.0, 0.86, 0.45)
const HOVER_COLOR := Color(1.0, 0.95, 0.8, 0.75)
const BLOCKED_COLOR := Color(0.95, 0.35, 0.3)

var _hover := PackedVector2Array()
var _hover_label := ""
var _active := PackedVector2Array()
var _blocked_at := Vector2.INF
var _blocked_time := 0.0
var _time := 0.0


func show_hover(points: PackedVector2Array, label: String) -> void:
	_hover = points
	_hover_label = label
	queue_redraw()


func clear_hover() -> void:
	if _hover.is_empty() and _blocked_at == Vector2.INF:
		return
	_hover = PackedVector2Array()
	queue_redraw()


func show_active(points: PackedVector2Array) -> void:
	_active = points
	queue_redraw()


func flash_blocked(at: Vector2) -> void:
	_blocked_at = at
	_blocked_time = 0.8
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if _blocked_time > 0.0:
		_blocked_time -= delta
		if _blocked_time <= 0.0:
			_blocked_at = Vector2.INF
	if not _active.is_empty() or not _hover.is_empty() or _blocked_at != Vector2.INF:
		queue_redraw()


func _draw() -> void:
	if not _hover.is_empty():
		_draw_route(_hover, HOVER_COLOR, 3.2, 0.0)
		_draw_destination(_hover[_hover.size() - 1], HOVER_COLOR)
		if _hover_label != "":
			_draw_label(_hover[_hover.size() - 1] + Vector2(0, -22), _hover_label)
	if _active.size() > 1:
		_draw_route(_active, ACTIVE_COLOR, 3.8, _time * 26.0)
		_draw_destination(_active[_active.size() - 1], ACTIVE_COLOR)
	if _blocked_at != Vector2.INF:
		var r := 11.0
		var c := Color(BLOCKED_COLOR, clampf(_blocked_time * 2.0, 0.0, 1.0))
		draw_line(_blocked_at + Vector2(-r, -r), _blocked_at + Vector2(r, r), c, 4.0, true)
		draw_line(_blocked_at + Vector2(-r, r), _blocked_at + Vector2(r, -r), c, 4.0, true)


func _draw_route(points: PackedVector2Array, color: Color, radius: float, scroll: float) -> void:
	var carry := fposmod(-scroll, DOT_SPACING) + 14.0
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var length := a.distance_to(b)
		var t := carry
		while t < length:
			var p := a.lerp(b, t / length)
			draw_circle(p + Vector2(1, 1.5), radius, Color(0.1, 0.08, 0.05, 0.35 * color.a))
			draw_circle(p, radius, color)
			t += DOT_SPACING
		carry = t - length


func _draw_destination(at: Vector2, color: Color) -> void:
	var pulse := 1.0 + sin(_time * 4.0) * 0.08
	draw_arc(at + Vector2(1, 2), 15.0 * pulse, 0.0, TAU, 32, Color(0.1, 0.08, 0.05, 0.35), 4.0, true)
	draw_arc(at, 15.0 * pulse, 0.0, TAU, 32, color, 3.0, true)
	draw_circle(at, 4.0, color)


func _draw_label(at: Vector2, text: String) -> void:
	var font := ThemeDB.fallback_font
	var size := 15
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var box := Rect2(at - Vector2(width * 0.5 + 8, 17), Vector2(width + 16, 23))
	draw_rect(box, Color(0.1, 0.08, 0.06, 0.78))
	draw_rect(box, Color(0.85, 0.7, 0.42, 0.9), false, 1.5)
	draw_string(font, Vector2(box.position.x + 8, box.position.y + 17), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
		Color(1, 0.95, 0.85))
