class_name DragonCompanion
extends Node2D
## A dragon travelling with the adventurer, trailing along the walked path.
## Its look follows its growth stage: flyers hover above the scenery with a ground
## shadow; walkers (including every hatchling) pad along behind.

const FLY_ALTITUDE := 42.0
const CATCH_UP := 4.5  ## Higher = tighter following.
const JUVENILE_SCALE := 0.8
## Per party slot: x = distance behind along the trail (px), y = side offset (+ = right of the path).
const SLOTS: Array[Vector2] = [Vector2(150, -40), Vector2(56, 14), Vector2(102, 30), Vector2(126, -8)]

var record: DragonRecord
var _assets: AssetResolver
var _trail: FollowTrail
var _slot := Vector2.ZERO
var _flies := false
var _art := ""
var _base_scale := 1.0
var _sprite := Sprite2D.new()
var _time := 0.0
var _last_position := Vector2.ZERO
var _speed := 0.0
var _step_phase := 0.0


func setup(p_record: DragonRecord, assets: AssetResolver, trail: FollowTrail, slot_index: int, now: float) -> void:
	record = p_record
	_assets = assets
	_trail = trail
	set_slot(slot_index)
	add_child(_sprite)
	update_growth(now)
	position = trail.point_behind(_slot.x)
	_last_position = position
	_time = randf() * TAU


## Where in the party line this dragon walks (distance behind / side offset).
func set_slot(slot_index: int) -> void:
	_slot = SLOTS[slot_index % SLOTS.size()]


## Refreshes art, scale and flight for the dragon's growth stage at world time `now`.
func update_growth(now: float) -> void:
	var stage := record.stage(now)
	_flies = record.species().flies_at(stage)
	z_index = 1 if _flies else 0  # Flyers pass above trees and landmarks.
	_base_scale = JUVENILE_SCALE if stage == DragonSpecies.Stage.JUVENILE else 1.0
	var art := record.art_at(now)
	if art != _art:
		_art = art
		_sprite.texture = _assets.get_texture(art)
		SpriteAnchor.apply(_sprite, art)
		_sprite.material = DragonLook.material_for(record.genome, art, _assets, record.id)  # Inherited colours.


func is_flying() -> bool:
	return _flies


func _process(delta: float) -> void:
	_time += delta
	var heading := _trail.heading_at(_slot.x)
	var side := Vector2(-heading.y, heading.x) * _slot.y
	var target := _trail.point_behind(_slot.x) + side
	if _flies:
		target += Vector2(cos(_time * 0.7) * 18.0, sin(_time * 0.9) * 8.0)
	position = position.lerp(target, 1.0 - exp(-CATCH_UP * delta))
	var velocity := (position - _last_position) / maxf(delta, 0.0001)
	_last_position = position
	_speed = lerpf(_speed, velocity.length(), minf(1.0, delta * 8.0))
	if absf(velocity.x) > 12.0:
		_sprite.flip_h = velocity.x < 0.0
	if _flies:
		var flap := sin(_time * 6.5)
		_sprite.position.y = -FLY_ALTITUDE * _base_scale + sin(_time * 2.1) * 5.0
		_sprite.scale = Vector2(1.0, 1.0 + flap * 0.05) * _base_scale
	else:
		_step_phase += _speed * delta * 0.16
		var bob := absf(sin(_step_phase)) * minf(1.0, _speed / 40.0)
		_sprite.position.y = -bob * 3.0
		_sprite.scale = Vector2(1.0, 1.0 + sin(_time * 2.4) * 0.015) * _base_scale
	queue_redraw()


func _draw() -> void:
	if record == null:
		return
	if _flies:
		var shrink := (0.85 + sin(_time * 2.1) * 0.05) * _base_scale
		Adventurer._draw_shadow(self, Vector2(0, 2), Vector2(30, 9) * shrink, 0.22)
	else:
		var width := _sprite.texture.get_width() * 0.3 * _base_scale if _sprite.texture else 30.0
		Adventurer._draw_shadow(self, Vector2(2, -1), Vector2(width, width * 0.24), 0.3)
