extends GutTest
## Headless smoke test of the assembled scene: travel, companions, HUD and the nest panel.

const SCENE := preload("res://src/overworld/overworld.tscn")
var scene


func before_each() -> void:
	scene = SCENE.instantiate()
	add_child_autofree(scene)


func _simulate(seconds: float, step: float = 0.05) -> void:
	var t := 0.0
	while t < seconds:
		scene.adventurer._process(step)
		scene._process(step)
		for child in scene.get_node("World").get_children():
			if child is DragonCompanion:
				child._process(step)
		t += step


func _companions() -> Array:
	return scene.get_node("World").get_children().filter(func(n: Node) -> bool: return n is DragonCompanion)


func test_scene_builds_with_two_companions_and_hud() -> void:
	assert_eq(_companions().size(), 2)
	assert_not_null(scene.hud)
	assert_false(scene.encounter_panel.is_open())
	assert_eq(scene.hud._area_label.text, "Wayfarer's Camp")


func test_click_travel_moves_adventurer_advances_time_and_companions_follow() -> void:
	var start_minutes: float = scene.session.clock.total_minutes
	assert_true(scene.travel_to(Vector2i(8, 17)))
	_simulate(6.0)
	assert_false(scene.adventurer.is_travelling())
	assert_eq(scene.session.adventurer_cell, Vector2i(8, 17))
	assert_gt(scene.session.clock.total_minutes, start_minutes)
	for dragon in _companions():
		assert_lt(dragon.position.distance_to(scene.adventurer.position), 190.0, dragon.record.name)
		assert_lt(dragon.position.x, scene.adventurer.position.x, "%s trails behind" % dragon.record.name)
	assert_string_contains(scene.hud._time_label.text, "Day 1")


func test_clicking_blocked_terrain_does_not_move() -> void:
	assert_false(scene.travel_to(Vector2i(8, 19)), "explored deep forest")
	assert_false(scene.adventurer.is_travelling())


func test_walking_into_fog_reaches_the_clicked_location_once_revealed() -> void:
	# Pretend the watchtower view was taken: the nest is known, the pass is not walked yet.
	scene.session.fog.reveal(Vector2i(37, 15), 9.0)
	scene.session.adventurer_cell = Vector2i(37, 15)
	scene.adventurer.position = scene.session.map.cell_to_world(Vector2i(37, 15))
	assert_false(scene.session.fog.is_explored(Vector2i(42, 6)))
	assert_true(scene.travel_to(Vector2i(42, 6)))
	_simulate(12.0)
	assert_eq(scene.session.adventurer_cell, Vector2i(42, 6))
	assert_true(scene.encounter_panel.is_open(), "the nest encounter panel opens on arrival")
	var before: float = scene.session.clock.total_minutes
	scene.encounter_panel.choose("approach")
	assert_almost_eq(scene.session.clock.total_minutes - before, 30.0, 0.001)
	assert_true(scene.encounter_panel.is_open(), "outcome is shown before closing")
	scene.encounter_panel.close()
	assert_false(scene.encounter_panel.is_open())
	await wait_process_frames(2)  # let the panel's queue_free'd buttons go before the orphan check
