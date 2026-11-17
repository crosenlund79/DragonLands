class_name SpriteAnchor
extends RefCounted
## Where each sprite touches the ground, as a fraction of its height from the top.
## Overrides should keep the template's proportions so they stand on the same spot.

const GROUND := {
	"landmarks/standing_stones": 0.66,
	"landmarks/camp": 0.875,
	"landmarks/lodge": 0.88,
	"landmarks/dragon_nest": 0.885,
	"actors/adventurer": 0.95,
	"dragons/moss": 0.92,
	"dragons/ember": 0.62,
	"dragons/cinderwing_hatchling": 0.93,
	"decor/bridge": 0.5,
	"decor/bush": 0.86,
	"decor/rocks": 0.86,
}
const DEFAULT_GROUND := 0.91


static func apply(sprite: Sprite2D, art: String) -> void:
	sprite.centered = false
	var size := sprite.texture.get_size() if sprite.texture else Vector2.ZERO
	sprite.offset = Vector2(-size.x * 0.5, -size.y * GROUND.get(art, DEFAULT_GROUND))
