class_name LocationMarker
extends Node2D
## A location's landmark sprite plus a name banner that appears once discovered.

var location: Location
var _banner := Label.new()


func setup(p_location: Location, assets: AssetResolver, map: RegionMap) -> void:
	location = p_location
	position = map.cell_to_world(location.cell) + Vector2(0, RegionMap.CELL_SIZE * 0.3)
	var sprite := Sprite2D.new()
	sprite.texture = assets.get_texture(location.art)
	SpriteAnchor.apply(sprite, location.art)
	add_child(sprite)
	var settings := LabelSettings.new()
	settings.font_size = 16
	settings.font_color = Color(1.0, 0.95, 0.82)
	settings.outline_size = 6
	settings.outline_color = Color(0.12, 0.09, 0.06, 0.95)
	settings.shadow_size = 3
	settings.shadow_color = Color(0, 0, 0, 0.4)
	_banner.label_settings = settings
	_banner.text = location.name
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.size = Vector2(220, 24)
	_banner.position = Vector2(-110, 14)
	_banner.visible = false
	_banner.z_index = 2
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_banner)


func set_discovered(value: bool) -> void:
	_banner.visible = value
