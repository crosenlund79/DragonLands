class_name TerrainView
extends Sprite2D
## Paints the ground of a region with terrain.gdshader. The sprite's texture is a
## 1-pixel-per-cell control map, scaled up so one texel covers one cell.

const SHADER := preload("res://src/world/terrain.gdshader")
const TEXTURES := {
	"tex_grass": "terrain/grass",
	"tex_forest": "terrain/forest_floor",
	"tex_road": "terrain/road",
	"tex_water": "terrain/water",
	"tex_rock": "terrain/rock",
}


func setup(map: RegionMap, assets: AssetResolver, noise: Texture2D) -> void:
	texture = ImageTexture.create_from_image(build_control_image(map))
	centered = false
	scale = Vector2.ONE * RegionMap.CELL_SIZE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var shader_material := ShaderMaterial.new()
	shader_material.shader = SHADER
	for uniform_name in TEXTURES:
		shader_material.set_shader_parameter(uniform_name, assets.get_texture(TEXTURES[uniform_name]))
	shader_material.set_shader_parameter("noise_tex", noise)
	shader_material.set_shader_parameter("map_px", map.pixel_size())
	shader_material.set_shader_parameter("grid", Vector2(map.size))
	material = shader_material


static func build_control_image(map: RegionMap) -> Image:
	var image := Image.create(map.size.x, map.size.y, false, Image.FORMAT_RGBA8)
	for y in map.size.y:
		for x in map.size.x:
			image.set_pixel(x, y, control_color(map.get_terrain(Vector2i(x, y))))
	return image


static func control_color(terrain: int) -> Color:
	match terrain:
		Terrain.Type.FOREST:
			return Color(1, 0, 0, 0)
		Terrain.Type.WOODS:
			return Color(0.62, 0, 0, 0)
		Terrain.Type.ROAD:
			return Color(0, 1, 0, 0)
		Terrain.Type.WATER, Terrain.Type.BRIDGE:
			return Color(0, 0, 1, 0)
		Terrain.Type.MOUNTAIN:
			return Color(0, 0, 0, 1)
		Terrain.Type.ROCKY:
			return Color(0.15, 0, 0, 0.78)
	return Color(0, 0, 0, 0)
