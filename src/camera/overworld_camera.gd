class_name OverworldCamera
extends Camera2D
## Map camera: wheel zoom toward the cursor, right/middle-drag or WASD/arrow-key pan,
## optional follow of a target, always clamped to the map bounds.

const MAX_ZOOM := 1.8
const PAN_SPEED := 900.0
const ZOOM_STEP := 1.12

var bounds := Rect2()
var follow_target: Node2D
var following := true
var _dragging := false


func _ready() -> void:
	position_smoothing_enabled = false


func _process(delta: float) -> void:
	var pan := Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))
			- float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))
			- float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	if pan != Vector2.ZERO:
		following = false
		position += pan.normalized() * PAN_SPEED * delta / zoom.x
	elif following and follow_target != null:
		position = position.lerp(follow_target.position, 1.0 - exp(-3.5 * delta))
	_clamp()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_WHEEL_UP and button.pressed:
			_zoom_at(ZOOM_STEP, button.position)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN and button.pressed:
			_zoom_at(1.0 / ZOOM_STEP, button.position)
		elif button.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_dragging = button.pressed
	elif event is InputEventMouseMotion and _dragging:
		following = false
		position -= (event as InputEventMouseMotion).relative / zoom.x
		_clamp()
	elif event is InputEventKey and event.pressed and (event as InputEventKey).physical_keycode in [KEY_SPACE, KEY_C]:
		following = true


func min_zoom() -> float:
	return fit_zoom(get_viewport_rect().size, bounds.size)


func _zoom_at(factor: float, screen_point: Vector2) -> void:
	var before := get_canvas_transform().affine_inverse() * screen_point
	var z := clampf(zoom.x * factor, min_zoom(), MAX_ZOOM)
	zoom = Vector2(z, z)
	_clamp()
	force_update_scroll()
	var after := get_canvas_transform().affine_inverse() * screen_point
	position += before - after
	_clamp()


func _clamp() -> void:
	var z := maxf(zoom.x, min_zoom())
	if z != zoom.x:
		zoom = Vector2(z, z)
	position = clamp_center(position, get_viewport_rect().size / zoom.x, bounds)


## Smallest zoom at which the view still fits inside the map.
static func fit_zoom(view_size: Vector2, map_size: Vector2) -> float:
	if map_size.x <= 0.0 or map_size.y <= 0.0:
		return 1.0
	return maxf(view_size.x / map_size.x, view_size.y / map_size.y)


## Camera centre clamped so a view of `view_size` (world units) stays within `rect`.
static func clamp_center(center: Vector2, view_size: Vector2, rect: Rect2) -> Vector2:
	var half := view_size * 0.5
	var lo := rect.position + half
	var hi := rect.end - half
	return Vector2(
		rect.get_center().x if lo.x > hi.x else clampf(center.x, lo.x, hi.x),
		rect.get_center().y if lo.y > hi.y else clampf(center.y, lo.y, hi.y))
