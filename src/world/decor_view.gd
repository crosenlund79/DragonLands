class_name DecorView
extends RefCounted
## Instantiates DecorPlan entries as sprites: upright scenery joins the y-sorted world,
## flat pieces (bridges) go to the ground layer beneath walkers.

const SWAY_SHADER := preload("res://src/world/sway.gdshader")


static func populate(entries: Array[Dictionary], assets: AssetResolver, world: Node2D, ground: Node2D) -> void:
	var sway := ShaderMaterial.new()
	sway.shader = SWAY_SHADER
	for entry in entries:
		var sprite := Sprite2D.new()
		sprite.texture = assets.get_texture(entry.art)
		SpriteAnchor.apply(sprite, entry.art)
		sprite.position = entry.position
		sprite.scale = Vector2.ONE * entry.scale
		sprite.flip_h = entry.flip
		sprite.self_modulate = entry.tint
		if entry.art.begins_with("decor/tree") or entry.art == "decor/bush":
			sprite.material = sway
		(ground if entry.ground else world).add_child(sprite)
