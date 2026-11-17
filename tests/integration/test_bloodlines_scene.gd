extends GutTest
## Prototype 003 through the real scene: collection screen, party selection at camp, breeding
## through the UI, recoloured companions, camp residents and loading saves (v2 and Prototype 002).

const SCENE := preload("res://src/overworld/overworld.tscn")
const CAMP := Vector2i(3, 16)
var _path: String


func before_each() -> void:
	_path = "user://test_bloodlines_%d.json" % Time.get_ticks_usec()


func after_each() -> void:
	if FileAccess.file_exists(_path):
		DirAccess.remove_absolute(_path)


func _spawn() -> OverworldScene:
	var scene: OverworldScene = SCENE.instantiate()
	add_child_autofree(scene)
	return scene


func _camp(scene: OverworldScene) -> Location:
	return scene.session.locations.get_by_id("camp")


## Takes the nest egg and hatches it at camp through the panels.
func _hatch_pip(scene: OverworldScene) -> DragonRecord:
	var nest := scene.session.locations.get_by_id("nest")
	scene.session.resolve_choice(nest, nest.encounter.get_choice("egg"))
	scene.session.adventurer_cell = CAMP
	scene.adventurer.position = scene.session.map.cell_to_world(CAMP)
	scene.open_encounter(_camp(scene))
	scene.encounter_panel.choose("warm")
	scene.hatching_panel.skip_animation()
	scene.hatching_panel.submit_name("Pip")
	scene.hatching_panel.close()
	return scene.session.roster.all()[2]


func _companion_ids(scene: OverworldScene) -> Array:
	return scene.companions.map(func(c: DragonCompanion) -> String: return c.record.id)


func test_breed_through_the_collection_screen_and_manage_the_party() -> void:
	var scene := _spawn()
	var pip := _hatch_pip(scene)
	assert_eq(_companion_ids(scene), ["ember", "moss", pip.id])
	for c in scene.companions:
		assert_not_null(c._sprite.material, "%s is drawn with its genome colours" % c.record.name)
	# Rest until Pip is grown, then tend the dragons.
	scene.open_encounter(_camp(scene))
	assert_has(scene.encounter_panel.offered_choice_ids(), "rest_until")
	scene.encounter_panel.choose("rest_until")
	scene.encounter_panel.close()
	assert_true(scene.collection_screen.is_open() == false)
	scene.open_encounter(_camp(scene))
	scene.encounter_panel.choose("tend")
	assert_true(scene.collection_screen.is_open(), "the camp choice opens the collection")
	assert_false(scene.encounter_panel.is_open())
	scene.collection_screen.select(pip.id)
	scene.collection_screen.show_side("compare")
	scene.collection_screen.compare_with("ember")
	scene.collection_screen.show_side("ancestry")
	scene.collection_screen.show_tab("breeding")
	scene.collection_screen.choose_parents("ember", pip.id)
	var egg := scene.collection_screen.pair()
	assert_not_null(egg)
	assert_string_contains(scene.collection_screen.message(), "An egg was laid")
	assert_eq(scene.session.eggs.size(), 1)
	assert_null(scene.collection_screen.pair(), "parents now rest")
	# Leave Moss at camp.
	scene.collection_screen.show_tab("collection")
	scene.collection_screen.set_travelling("moss", false)
	assert_eq(_companion_ids(scene), ["ember", pip.id])
	assert_eq(scene.camp_residents.resident_ids(), PackedStringArray(["moss"]))
	scene.collection_screen.close()
	assert_true(scene.encounter_panel.is_open(), "closing the collection at camp returns to the camp panel")
	# Hatch the bred egg: it joins the party (a slot is free) and shows its ancestry.
	scene.encounter_panel.choose("warm")
	scene.hatching_panel.skip_animation()
	scene.hatching_panel.submit_name("Kindle")
	var kindle := scene.session.roster.get_by_id("dragon-4")
	assert_not_null(kindle)
	assert_eq(kindle.parent_ids, PackedStringArray(["ember", pip.id]))
	assert_true(scene.session.is_travelling(kindle.id))
	scene.hatching_panel.close()
	assert_eq(_companion_ids(scene), ["ember", pip.id, kindle.id])
	assert_false(scene.companions[2].is_flying(), "Kindle is a hatchling")
	await wait_process_frames(2)


func test_party_cannot_change_away_from_camp() -> void:
	var scene := _spawn()
	scene.open_collection()
	scene.collection_screen.set_travelling("moss", false)
	assert_string_contains(scene.collection_screen.message(), "chosen at Wayfarer's Camp")
	assert_eq(_companion_ids(scene), ["ember", "moss"])
	scene.collection_screen.close()
	assert_false(scene.encounter_panel.is_open(), "away from camp nothing else opens")
	await wait_process_frames(2)


func test_save_and_load_restores_party_residents_and_genes() -> void:
	var scene := _spawn()
	var pip := _hatch_pip(scene)
	scene.session.set_travelling("moss", false)
	assert_true(scene.save_game(_path))
	OverworldScene.queue_load(SaveGame.read(_path))
	var loaded := _spawn()
	assert_eq(_companion_ids(loaded), ["ember", pip.id])
	assert_eq(loaded.camp_residents.resident_ids(), PackedStringArray(["moss"]))
	assert_true(loaded.session.roster.get_by_id(pip.id).genome.same_as(pip.genome))
	await wait_process_frames(2)


func test_prototype_002_save_loads_into_the_scene() -> void:
	OverworldScene.queue_load(SaveGame.read("res://tests/fixtures/p002_save_with_pip.json"))
	var scene := _spawn()
	assert_eq(_companion_ids(scene), ["ember", "moss", "dragon-2"])
	assert_eq(scene.camp_residents.resident_ids().size(), 0)
	assert_eq(scene.session.roster.get_by_id("dragon-2").name, "Pip")
	await wait_process_frames(2)


func test_closing_the_hatching_panel_early_is_safe() -> void:
	var scene := _spawn()
	var nest := scene.session.locations.get_by_id("nest")
	scene.session.resolve_choice(nest, nest.encounter.get_choice("egg"))
	var egg := scene.session.eggs.all()[0]
	var species := egg.species()
	scene.hatching_panel.open(egg, scene.assets.get_texture(species.egg_art), null, scene.assets.get_texture(species.hatchling_art))
	scene.hatching_panel.close()
	scene.hatching_panel._stage._process(3.0)  # would have burst and called back into the closed panel
	assert_false(scene.hatching_panel.is_open())
	assert_eq(get_errors().size(), 0)
	await wait_process_frames(2)
