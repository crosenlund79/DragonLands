class_name FogView
extends Sprite2D
## Draws FogOfWar as drifting clouds. Newly explored cells fade out over ~0.5 s.

const SHADER := preload("res://src/exploration/fog.gdshader")
const FADE_PER_SECOND := 2.2

var _fog: FogOfWar
var _image: Image
var _texture: ImageTexture
var _shown := PackedFloat32Array()
var _fading := false


func setup(fog: FogOfWar, map: RegionMap, assets: AssetResolver, noise: Texture2D) -> void:
	_fog = fog
	_shown.resize(fog.size.x * fog.size.y)
	_image = Image.create(fog.size.x, fog.size.y, false, Image.FORMAT_L8)
	_texture = ImageTexture.create_from_image(_image)
	texture = _texture
	centered = false
	scale = Vector2.ONE * RegionMap.CELL_SIZE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var shader_material := ShaderMaterial.new()
	shader_material.shader = SHADER
	shader_material.set_shader_parameter("cloud_tex", assets.get_texture("fog/clouds"))
	shader_material.set_shader_parameter("noise_tex", noise)
	shader_material.set_shader_parameter("map_px", map.pixel_size())
	shader_material.set_shader_parameter("grid", Vector2(map.size))
	material = shader_material
	fog.revealed.connect(func(_cells: Array[Vector2i]) -> void: _fading = true)
	# Already-explored cells (e.g. the start area) appear without a fade.
	for y in fog.size.y:
		for x in fog.size.x:
			if fog.is_explored(Vector2i(x, y)):
				_shown[y * fog.size.x + x] = 1.0
	_push()


func _process(delta: float) -> void:
	if not _fading or _fog == null:
		return
	var still_fading := false
	var step := delta * FADE_PER_SECOND
	for y in _fog.size.y:
		for x in _fog.size.x:
			var i := y * _fog.size.x + x
			if _shown[i] < 1.0 and _fog.is_explored(Vector2i(x, y)):
				_shown[i] = minf(1.0, _shown[i] + step)
				still_fading = still_fading or _shown[i] < 1.0
	_fading = still_fading
	_push()


func _push() -> void:
	var bytes := PackedByteArray()
	bytes.resize(_shown.size())
	for i in _shown.size():
		bytes[i] = int(_shown[i] * 255.0)
	_image.set_data(_fog.size.x, _fog.size.y, false, Image.FORMAT_L8, bytes)
	_texture.update(_image)
