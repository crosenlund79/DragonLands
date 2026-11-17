extends GutTest
## Pure helpers used by the views: decor placement, terrain control map, daylight, camera.

func _map() -> RegionMap:
	return ElderwoodVale.create_map()


func test_decor_plan_is_deterministic() -> void:
	var keep: Array[Vector2i] = []
	assert_eq(DecorPlan.build(_map(), keep, 5), DecorPlan.build(_map(), keep, 5))


func test_decor_never_lands_on_roads_or_water_and_bridges_are_ground_level() -> void:
	var map := _map()
	var keep: Array[Vector2i] = []
	var bridges := 0
	for entry in DecorPlan.build(map, keep):
		var cell := map.world_to_cell(entry.position)
		var terrain := map.get_terrain(cell)
		if entry.art == "decor/bridge":
			bridges += 1
			assert_true(entry.ground)
			continue
		assert_false(entry.ground)
		assert_ne(terrain, Terrain.Type.ROAD, "%s at %s" % [entry.art, cell])
		assert_ne(terrain, Terrain.Type.WATER, "%s at %s" % [entry.art, cell])
	assert_eq(bridges, 1)


func test_decor_keeps_location_surroundings_clear() -> void:
	var map := _map()
	var keep: Array[Vector2i] = [Vector2i(28, 26)]
	for entry in DecorPlan.build(map, keep):
		if entry.art.begins_with("decor/mountain"):
			continue
		var cell := map.world_to_cell(entry.position)
		assert_false(absi(cell.x - 28) <= 1 and absi(cell.y - 26) <= 1, "%s at %s" % [entry.art, cell])


func test_terrain_control_map_encodes_each_cell() -> void:
	var map := _map()
	var image := TerrainView.build_control_image(map)
	assert_eq(image.get_size(), map.size)
	assert_almost_eq(image.get_pixel(0, 17).g, 1.0, 0.01, "road")
	assert_almost_eq(image.get_pixel(0, 0).a, 1.0, 0.01, "mountain")
	assert_almost_eq(image.get_pixel(10, 28).b, 1.0, 0.01, "lake")


func test_daylight_is_bright_at_noon_and_dim_but_readable_at_night() -> void:
	var noon := Daylight.color_at(12.0)
	var night := Daylight.color_at(1.0)
	assert_gt(noon.v, night.v)
	assert_gt(night.v, 0.5)
	assert_eq(Daylight.color_at(0.0), Daylight.color_at(24.0))


func test_camera_clamps_view_inside_map() -> void:
	var bounds := Rect2(0, 0, 3000, 2000)
	assert_eq(OverworldCamera.clamp_center(Vector2(0, 0), Vector2(1000, 600), bounds), Vector2(500, 300))
	assert_eq(OverworldCamera.clamp_center(Vector2(1500, 1000), Vector2(1000, 600), bounds), Vector2(1500, 1000))
	assert_eq(OverworldCamera.clamp_center(Vector2(10, 10), Vector2(4000, 600), bounds), Vector2(1500, 300))
	assert_almost_eq(OverworldCamera.fit_zoom(Vector2(1600, 900), Vector2(3072, 2304)), 0.5208, 0.001)


func test_sprite_anchor_puts_ground_point_at_node_origin() -> void:
	var sprite := Sprite2D.new()
	var image := Image.create(100, 200, false, Image.FORMAT_RGBA8)
	sprite.texture = ImageTexture.create_from_image(image)
	SpriteAnchor.apply(sprite, "decor/tree_oak")
	assert_eq(sprite.offset, Vector2(-50, -182))
	sprite.free()
