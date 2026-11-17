class_name CampResidents
extends Node2D
## Dragons that are not travelling rest around Wayfarer's Camp, so the collection is
## visible in the world. Purely presentation: rebuilt whenever the party or roster changes.

const SPOTS: Array[Vector2] = [Vector2(-86, 54), Vector2(70, 66), Vector2(-24, 92), Vector2(124, 30),
	Vector2(-140, 18), Vector2(20, 128), Vector2(-96, 126), Vector2(150, 104)]

var _session: OverworldSession
var _assets: AssetResolver
var _world: Node2D
var _sprites: Array[Sprite2D] = []
var _time := 0.0


func setup(session: OverworldSession, assets: AssetResolver, world: Node2D, camp_center: Vector2) -> void:
	_session = session
	_assets = assets
	_world = world
	position = camp_center
	rebuild()


func rebuild() -> void:
	for sprite in _sprites:
		sprite.queue_free()
	_sprites.clear()
	var now := _session.clock.total_minutes
	var i := 0
	for dragon in _session.roster.all():
		if _session.is_travelling(dragon.id) or i >= SPOTS.size():
			continue
		var art := dragon.art_at(now)
		var sprite := Sprite2D.new()
		sprite.texture = _assets.get_texture(art)
		SpriteAnchor.apply(sprite, art)
		sprite.material = DragonLook.material_for(dragon.genome, art, _assets, dragon.id)
		sprite.position = position + SPOTS[i]
		sprite.flip_h = SPOTS[i].x > 0.0
		sprite.scale = Vector2.ONE * (DragonCompanion.JUVENILE_SCALE if dragon.stage(now) == DragonSpecies.Stage.JUVENILE else 1.0)
		if art == "dragons/ember" or dragon.species().flies_at(dragon.stage(now)):
			sprite.offset.y += sprite.texture.get_height() * 0.18  # Flyers rest on the ground at camp.
		sprite.set_meta("dragon_id", dragon.id)
		_world.add_child(sprite)
		_sprites.append(sprite)
		i += 1


func resident_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for sprite in _sprites:
		ids.append(str(sprite.get_meta("dragon_id")))
	return ids


func _process(delta: float) -> void:
	_time += delta
	for i in _sprites.size():
		_sprites[i].rotation = sin(_time * 1.3 + i) * 0.015
