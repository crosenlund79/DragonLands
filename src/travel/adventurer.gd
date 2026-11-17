class_name Adventurer
extends Node2D
## The player's walker: follows a world-space route at a terrain-dependent pace.

signal moved(distance: float, position: Vector2)
signal arrived(position: Vector2)

const BASE_SPEED := 150.0  ## Pixels per second on meadow.

var _map: RegionMap
var _follower := PathFollower.new()
var _sprite := Sprite2D.new()
var _step_phase := 0.0


func setup(map: RegionMap, assets: AssetResolver, start: Vector2) -> void:
	_map = map
	position = start
	_sprite.texture = assets.get_texture("actors/adventurer")
	SpriteAnchor.apply(_sprite, "actors/adventurer")
	add_child(_sprite)


func travel_along(points: PackedVector2Array) -> void:
	_follower.set_path(points)


func stop() -> void:
	_follower.stop()


func is_travelling() -> bool:
	return _follower.is_active()


func remaining_route() -> PackedVector2Array:
	return _follower.remaining_points()


func _process(delta: float) -> void:
	if _follower.is_active():
		var terrain := _map.get_terrain(_map.world_to_cell(position))
		var moved_by := _follower.advance(BASE_SPEED * Terrain.speed_factor(terrain) * delta)
		var direction := _follower.direction()
		if absf(direction.x) > 0.2:
			_sprite.flip_h = direction.x < 0.0
		position = _follower.position
		_step_phase += moved_by * 0.11
		moved.emit(moved_by, position)
		if not _follower.is_active():
			arrived.emit(position)
	else:
		_step_phase = lerpf(_step_phase, roundf(_step_phase / PI) * PI, minf(1.0, delta * 10.0))
	_sprite.position.y = -absf(sin(_step_phase)) * 3.0
	_sprite.rotation = sin(_step_phase) * 0.04
	queue_redraw()


func _draw() -> void:
	_draw_shadow(self, Vector2(1, 0), Vector2(17, 6), 0.32)


static func _draw_shadow(item: CanvasItem, center: Vector2, radii: Vector2, alpha: float) -> void:
	var points := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	item.draw_colored_polygon(points, Color(0.08, 0.1, 0.04, alpha))
