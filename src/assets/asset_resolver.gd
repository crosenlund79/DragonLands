class_name AssetResolver
extends RefCounted
## Single entry point for replaceable graphics (contract: assets/README.md).
##
## A logical name such as "terrain/grass" resolves, in order, to:
##   1. <override_root>/graphics/terrain/grass.png   (user override, runtime-loaded)
##   2. res://assets/graphics/terrain/template_grass.png   (packaged fallback)
## Missing or undecodable overrides fall back with a warning. Results are cached
## for the session; override changes apply after a game restart (no hot-reload).

const FALLBACK_ROOT := "res://assets/graphics"
const OVERRIDE_EXTENSIONS: PackedStringArray = ["png"]

var override_root: String
var _cache: Dictionary = {}
var _sources: Dictionary = {}


func _init(p_override_root: String) -> void:
	override_root = p_override_root


## The override root for this run: next to the executable in exported builds,
## the project's custom/ folder otherwise (editor / development).
static func default_override_root() -> String:
	return select_override_root(
		OS.has_feature("template"),
		ProjectSettings.globalize_path("res://custom"),
		OS.get_executable_path())


static func select_override_root(is_exported: bool, project_custom_dir: String, executable_path: String) -> String:
	if is_exported:
		return executable_path.get_base_dir().path_join("custom")
	return project_custom_dir


static func fallback_path(logical_name: String) -> String:
	var folder := logical_name.get_base_dir()
	var file := "template_%s.png" % logical_name.get_file()
	return FALLBACK_ROOT.path_join(folder).path_join(file) if folder != "" else FALLBACK_ROOT.path_join(file)


func get_texture(logical_name: String) -> Texture2D:
	if _cache.has(logical_name):
		return _cache[logical_name]
	var texture := _load_override(logical_name)
	if texture == null:
		texture = _load_fallback(logical_name)
	_cache[logical_name] = texture
	return texture


## Path the texture was loaded from ("" for the built-in placeholder). For tests/debugging.
func get_source(logical_name: String) -> String:
	get_texture(logical_name)
	return _sources.get(logical_name, "")


func _load_override(logical_name: String) -> Texture2D:
	if override_root == "":
		return null
	var base := override_root.path_join("graphics").path_join(logical_name)
	for ext in OVERRIDE_EXTENSIONS:
		var path := "%s.%s" % [base, ext]
		if not FileAccess.file_exists(path):
			continue
		var image := Image.new()
		if image.load(path) != OK or image.is_empty():
			push_warning("AssetResolver: invalid override '%s'; using fallback." % path)
			continue
		image.generate_mipmaps()
		_sources[logical_name] = path
		return ImageTexture.create_from_image(image)
	return null


func _load_fallback(logical_name: String) -> Texture2D:
	var path := fallback_path(logical_name)
	if ResourceLoader.exists(path):
		var texture := load(path) as Texture2D
		if texture != null:
			_sources[logical_name] = path
			return texture
	push_error("AssetResolver: no override or fallback for '%s'." % logical_name)
	_sources[logical_name] = ""
	var placeholder := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	placeholder.fill(Color.MAGENTA)
	return ImageTexture.create_from_image(placeholder)
