extends GutTest
## AssetResolver: override precedence, fallbacks, supported format, root selection.

const LOGICAL := "terrain/grass"
var _root: String


func before_each() -> void:
	_root = OS.get_user_data_dir().path_join("test_overrides_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(_root.path_join("graphics/terrain"))


func after_each() -> void:
	_remove_tree(_root)


func test_uses_packaged_template_when_no_override() -> void:
	var resolver := AssetResolver.new(_root)
	assert_not_null(resolver.get_texture(LOGICAL))
	assert_eq(resolver.get_source(LOGICAL), "res://assets/graphics/terrain/template_grass.png")


func test_fallback_path_maps_logical_name_to_template_file() -> void:
	assert_eq(AssetResolver.fallback_path("dragons/ember"), "res://assets/graphics/dragons/template_ember.png")
	assert_eq(AssetResolver.fallback_path("icon"), "res://assets/graphics/template_icon.png")


func test_png_override_takes_precedence() -> void:
	var image := Image.create(4, 3, false, Image.FORMAT_RGBA8)
	image.fill(Color.RED)
	var path := _root.path_join("graphics/terrain/grass.png")
	image.save_png(path)
	var resolver := AssetResolver.new(_root)
	var texture := resolver.get_texture(LOGICAL)
	assert_eq(resolver.get_source(LOGICAL), path)
	assert_eq(texture.get_size(), Vector2(4, 3))


func test_invalid_override_falls_back_with_warning() -> void:
	var file := FileAccess.open(_root.path_join("graphics/terrain/grass.png"), FileAccess.WRITE)
	file.store_string("definitely not a png")
	file.close()
	var resolver := AssetResolver.new(_root)
	assert_not_null(resolver.get_texture(LOGICAL))
	assert_eq(resolver.get_source(LOGICAL), "res://assets/graphics/terrain/template_grass.png")
	assert_push_warning("invalid override")
	for error in get_errors():
		error.handled = true  # The engine's own image-decoding error is expected here.


func test_unsupported_extension_is_ignored() -> void:
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.save_jpg(_root.path_join("graphics/terrain/grass.jpg"))
	var resolver := AssetResolver.new(_root)
	assert_eq(resolver.get_source(LOGICAL), "res://assets/graphics/terrain/template_grass.png")


func test_missing_asset_returns_placeholder_without_crashing() -> void:
	var resolver := AssetResolver.new(_root)
	assert_not_null(resolver.get_texture("nothing/here"))
	assert_eq(resolver.get_source("nothing/here"), "")
	assert_push_error("no override or fallback")


func test_results_are_cached_for_the_session() -> void:
	var resolver := AssetResolver.new(_root)
	var first := resolver.get_texture(LOGICAL)
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.save_png(_root.path_join("graphics/terrain/grass.png"))
	assert_same(resolver.get_texture(LOGICAL), first, "overrides apply after restart, not live")


func test_override_root_is_project_custom_folder_in_development() -> void:
	assert_eq(AssetResolver.select_override_root(false, "/proj/custom", "/opt/godot/godot"), "/proj/custom")


func test_override_root_is_next_to_executable_when_exported() -> void:
	assert_eq(AssetResolver.select_override_root(true, "/proj/custom", "/games/dl/DragonLands.x86_64"),
		"/games/dl/custom")


func _remove_tree(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_remove_tree(path.path_join(sub))
	for file in dir.get_files():
		dir.remove(file)
	DirAccess.remove_absolute(path)
