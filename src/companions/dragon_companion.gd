class_name DragonCompanion
extends Node2D
## A companion dragon that trails the adventurer along the walked path.
## Flyers hover above the scenery with a ground shadow; walkers pad along behind.

const FLY_ALTITUDE := 42.0
const CATCH_UP := 4.5  ## Higher = tighter following.

var profile: DragonProfile
var _trail: FollowTrail
var _sprite := Sprite2D.new()
var _time := 0.0
var _last_position := Vector2.ZERO
var _speed := 0.0
var _step_phase := 0.0


func setup(p_profile: DragonProfile, assets: AssetResolver, trail: FollowTrail) -> void:
	profile = p_profile
	_trail = trail
	_sprite.texture = assets.get_texture(profile.art)
	SpriteAnchor.apply(_sprite, profile.art)
	add_child(_sprite)
	position = trail.point_behind(profile.follow_distance)
	_last_position = position
	_time = randf() * TAU
	if profile.flies:
		z_index = 1  # Above trees and landmarks.


func _process(delta: float) -> void:
	_time += delta
	var heading := _trail.heading_at(profile.follow_distance)
	var side := Vector2(-heading.y, heading.x) * profile.side_offset
	var target := _trail.point_behind(profile.follow_distance) + side
	if profile.flies:
		target += Vector2(cos(_time * 0.7) * 18.0, sin(_time * 0.9) * 8.0)
	position = position.lerp(target, 1.0 - exp(-CATCH_UP * delta))
	var velocity := (position - _last_position) / maxf(delta, 0.0001)
	_last_position = position
	_speed = lerpf(_speed, velocity.length(), minf(1.0, delta * 8.0))
	if absf(velocity.x) > 12.0:
		_sprite.flip_h = velocity.x < 0.0
	if profile.flies:
		var flap := sin(_time * 6.5)
		_sprite.position.y = -FLY_ALTITUDE + sin(_time * 2.1) * 5.0
		_sprite.scale = Vector2(1.0, 1.0 + flap * 0.05)
	else:
		_step_phase += _speed * delta * 0.16
		var bob := absf(sin(_step_phase)) * minf(1.0, _speed / 40.0)
		_sprite.position.y = -bob * 3.0
		_sprite.scale = Vector2(1.0, 1.0 + sin(_time * 2.4) * 0.015)
	queue_redraw()


func _draw() -> void:
	if profile == null:
		return
	if profile.flies:
		var shrink := 0.85 + sin(_time * 2.1) * 0.05
		Adventurer._draw_shadow(self, Vector2(0, 2), Vector2(30, 9) * shrink, 0.22)
	else:
		Adventurer._draw_shadow(self, Vector2(2, -1), Vector2(30, 7), 0.3)
