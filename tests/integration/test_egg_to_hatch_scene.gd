extends GutTest
## The full egg-to-hatch sequence through the real scene and panels, then save and
## load into a fresh scene instance (headless).

const SCENE := preload("res://src/overworld/overworld.tscn")
var _path: String


func before_each() -> void:
	_path = "user://test_scene_save_%d.json" % Time.get_ticks_usec()


func after_each() -> void:
	if FileAccess.file_exists(_path):
		DirAccess.remove_absolute(_path)


func _spawn() -> OverworldScene:
	var scene: OverworldScene = SCENE.instantiate()
	add_child_autofree(scene)
	return scene


func _simulate(scene: OverworldScene, seconds: float, step: float = 0.05) -> void:
	var t := 0.0
	while t < seconds:
		scene.adventurer._process(step)
		scene._process(step)
		for companion in scene.companions:
			companion._process(step)
		t += step


func _place(scene: OverworldScene, cell: Vector2i, reveal: float) -> void:
	scene.session.fog.reveal(cell, reveal)
	scene.session.locations.discover_explored(scene.session.fog)
	scene.session.adventurer_cell = cell
	scene.adventurer.position = scene.session.map.cell_to_world(cell)


func _walk_to(scene: OverworldScene, cell: Vector2i) -> void:
	assert_true(scene.travel_to(cell))
	_simulate(scene, 14.0)
	assert_eq(scene.session.adventurer_cell, cell)


func test_collect_carry_hatch_name_and_follow() -> void:
	var scene := _spawn()
	# 1. The nest gives one egg.
	_place(scene, Vector2i(38, 12), 7.0)
	_walk_to(scene, Vector2i(42, 6))
	assert_true(scene.encounter_panel.is_open())
	assert_has(scene.encounter_panel.offered_choice_ids(), "egg")
	scene.encounter_panel.choose("egg")
	assert_eq(scene.session.eggs.size(), 1)
	assert_true(scene.hud._eggs_box.visible, "the egg appears in the HUD")
	scene.encounter_panel.close()
	scene.open_encounter(scene.session.locations.get_by_id("nest"))
	assert_does_not_have(scene.encounter_panel.offered_choice_ids(), "egg", "only one egg per nest")
	scene.encounter_panel.close()

	# 2. Back at camp (teleported for speed) the egg is kept warm until it hatches.
	_place(scene, Vector2i(4, 17), 6.0)
	var egg := scene.session.eggs.all()[0]
	assert_false(egg.is_ready(scene.session.clock.total_minutes))
	_walk_to(scene, Vector2i(3, 16))
	assert_true(scene.encounter_panel.is_open())
	assert_has(scene.encounter_panel.offered_choice_ids(), "warm")
	scene.encounter_panel.choose("warm")
	assert_false(scene.encounter_panel.is_open(), "the hatching moment replaces the camp panel")
	assert_true(scene.hatching_panel.is_open())
	assert_true(egg.is_ready(scene.session.clock.total_minutes))

	# 3. The hatching moment, naming and characteristics.
	assert_false(scene.hatching_panel.is_naming(), "naming waits for the egg to hatch")
	scene.hatching_panel.skip_animation()
	assert_true(scene.hatching_panel.is_naming())
	scene.hatching_panel.submit_name("  Pip ")
	assert_eq(scene.session.roster.size(), 3)
	assert_eq(scene.session.eggs.size(), 0)
	assert_false(scene.hud._eggs_box.visible)
	assert_true(scene.hatching_panel.is_open(), "characteristics are shown before closing")
	scene.hatching_panel.close()

	# 4. The hatchling walks with the party; Ember and Moss are unchanged.
	assert_eq(scene.companions.size(), 3)
	var pip := scene.companions[2]
	assert_eq(pip.record.name, "Pip")
	assert_false(pip.is_flying(), "hatchlings walk")
	assert_true(scene.companions[0].is_flying(), "Ember still flies")
	assert_false(scene.companions[1].is_flying(), "Moss still walks")
	_walk_to(scene, Vector2i(9, 17))
	for companion in scene.companions:
		assert_lt(companion.position.distance_to(scene.adventurer.position), 200.0, companion.record.name)
	await wait_process_frames(2)


func test_save_then_load_into_a_new_scene_without_duplicates() -> void:
	var scene := _spawn()
	var nest := scene.session.locations.get_by_id("nest")
	scene.session.resolve_choice(nest, nest.encounter.get_choice("egg"))
	var egg := scene.session.eggs.all()[0]
	scene.session.clock.advance(egg.incubation_minutes)
	scene.session.hatch_egg(egg.id, "Pip")
	scene.session.clock.advance(90.0)
	assert_true(scene.save_game(_path))
	var saved := SaveGame.read(_path)
	for i in 2:
		OverworldScene.queue_load(saved)
		var loaded := _spawn()
		assert_eq(loaded.session.roster.size(), 3, "load #%d" % (i + 1))
		assert_eq(loaded.companions.size(), 3)
		assert_eq(loaded.session.roster.all()[2].name, "Pip")
		assert_eq(loaded.session.eggs.size(), 0)
		assert_true(loaded.session.egg_taken("nest"))
		assert_eq(loaded.session.clock.total_minutes, scene.session.clock.total_minutes)
		assert_eq(loaded.hud._time_label.text, scene.hud._time_label.text)
	var fresh := _spawn()
	assert_eq(fresh.session.roster.size(), 2, "without a queued load the game starts fresh")
	await wait_process_frames(2)
