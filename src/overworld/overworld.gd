class_name OverworldScene
extends Node2D
## Entry scene. Builds the region, the session (rules/state) and the views, then
## routes input and signals between them. Holds no game rules itself.

const INVALID_CELL := Vector2i(-1, -1)

## Save data to apply when the scene next starts (set by load_game before reloading).
static var _pending_load: Dictionary = {}

var session: OverworldSession
var assets: AssetResolver
var adventurer: Adventurer
var camera: OverworldCamera
var hud: Hud
var encounter_panel: EncounterPanel
var hatching_panel: HatchingPanel
var trail := FollowTrail.new()
var companions: Array[DragonCompanion] = []

var _world: Node2D
var _preview: PathPreview
var _daylight: CanvasModulate
var _markers: Dictionary = {}  # location id -> LocationMarker
var _destination := INVALID_CELL  # Cell the current route ends on.
var _requested := INVALID_CELL  # Cell the player clicked (may still be in fog).
var _hover_cell := INVALID_CELL


## Makes the next instance of this scene start from `data` (a SaveGame.capture()).
static func queue_load(data: Dictionary) -> void:
	_pending_load = data


func _ready() -> void:
	assets = AssetResolver.new(AssetResolver.default_override_root())
	var map := ElderwoodVale.create_map()
	session = OverworldSession.new(map, ElderwoodVale.create_locations(), StartingDragons.create_roster(),
		ElderwoodVale.START_CELL, ElderwoodVale.START_MINUTES)
	var loaded := not _pending_load.is_empty() and SaveGame.restore(session, _pending_load)
	_pending_load = {}
	if not loaded:
		session.begin()
	RenderingServer.set_default_clear_color(Color(0.07, 0.09, 0.12))
	var noise := _make_noise()

	_daylight = CanvasModulate.new()
	add_child(_daylight)
	var terrain := TerrainView.new()
	terrain.setup(map, assets, noise)
	add_child(terrain)
	var ground := Node2D.new()
	ground.name = "GroundDecor"
	add_child(ground)
	_preview = PathPreview.new()
	add_child(_preview)
	_world = Node2D.new()
	_world.name = "World"
	_world.y_sort_enabled = true
	add_child(_world)

	var keep_clear: Array[Vector2i] = [ElderwoodVale.START_CELL]
	for location in session.locations.all():
		keep_clear.append(location.cell)
		var marker := LocationMarker.new()
		marker.setup(location, assets, map)
		marker.set_discovered(session.locations.is_discovered(location.id))
		_world.add_child(marker)
		_markers[location.id] = marker
	DecorView.populate(DecorPlan.build(map, keep_clear), assets, _world, ground)

	adventurer = Adventurer.new()
	adventurer.setup(map, assets, map.cell_to_world(session.adventurer_cell))
	_world.add_child(adventurer)
	_seed_trail(adventurer.position)
	for dragon in session.roster.all():
		_add_companion(dragon)

	var fog_view := FogView.new()
	fog_view.z_index = 3
	add_child(fog_view)

	camera = OverworldCamera.new()
	camera.bounds = Rect2(Vector2.ZERO, map.pixel_size())
	camera.follow_target = adventurer
	camera.position = adventurer.position
	add_child(camera)
	camera.make_current()

	var ui := CanvasLayer.new()
	add_child(ui)
	hud = Hud.new()
	ui.add_child(hud)
	encounter_panel = EncounterPanel.new()
	ui.add_child(encounter_panel)
	hatching_panel = HatchingPanel.new()
	ui.add_child(hatching_panel)

	session.locations.discovered.connect(_on_location_discovered)
	session.clock.time_changed.connect(_on_time_changed)
	session.cell_changed.connect(_on_cell_changed)
	session.egg_acquired.connect(_on_egg_acquired)
	session.egg_ready.connect(_on_egg_ready)
	session.hatch_requested.connect(_on_hatch_requested)
	session.dragon_hatched.connect(_on_dragon_hatched)
	adventurer.moved.connect(_on_adventurer_moved)
	adventurer.arrived.connect(_on_adventurer_arrived)
	encounter_panel.choice_made.connect(_on_choice_made)
	hatching_panel.name_confirmed.connect(_on_name_confirmed)
	hud.save_requested.connect(save_game)
	hud.load_requested.connect(load_game)

	fog_view.setup(session.fog, map, assets, noise)
	hud.setup(session, assets)
	_on_time_changed(session.clock.total_minutes)
	if loaded:
		hud.show_toast("Game loaded  ·  Day %d, %s" % [session.clock.day(), session.clock.clock_text()])
	else:
		hud.show_toast("Click the map to travel. Somewhere in the vale, a wild dragon is nesting.", 6.0)


func is_modal_open() -> bool:
	return encounter_panel.is_open() or hatching_panel.is_open()


## Writes the current session to `path`. Returns true on success.
func save_game(path: String = SaveGame.DEFAULT_PATH) -> bool:
	var ok := SaveGame.write(SaveGame.capture(session), path) == OK
	hud.show_toast("Game saved  ·  Day %d, %s" % [session.clock.day(), session.clock.clock_text()] if ok
		else "The game could not be saved.")
	return ok


## Reloads the scene from the save at `path`, after checking that it can be applied.
func load_game(path: String = SaveGame.DEFAULT_PATH) -> bool:
	var data := SaveGame.read(path)
	var probe := OverworldSession.new(ElderwoodVale.create_map(), ElderwoodVale.create_locations(),
		StartingDragons.create_roster(), ElderwoodVale.START_CELL, ElderwoodVale.START_MINUTES)
	if data.is_empty() or not SaveGame.restore(probe, data):
		hud.show_toast("No saved game to load." if data.is_empty() else "The saved game could not be loaded.")
		return false
	queue_load(data)
	get_tree().reload_current_scene()
	return true


func _process(_delta: float) -> void:
	trail.record(adventurer.position)
	if adventurer.is_travelling():
		_preview.show_active(adventurer.remaining_route())
	_update_hover()


func _unhandled_input(event: InputEvent) -> void:
	if is_modal_open():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_F5:
				save_game()
			KEY_F9:
				load_game()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		travel_to(session.map.world_to_cell(get_global_mouse_position()))


## Plans and starts a trip toward `cell` (also used by tests). Returns true if travel began.
func travel_to(cell: Vector2i) -> bool:
	var target := session.resolve_target(cell)
	var path := session.plan_route(target) if target != INVALID_CELL else ([] as Array[Vector2i])
	if path.is_empty():
		_preview.flash_blocked(session.map.cell_to_world(cell))
		return false
	_hover_cell = INVALID_CELL
	_preview.clear_hover()
	camera.following = true
	_requested = cell
	_destination = target
	if path.size() == 1:
		_on_adventurer_arrived(adventurer.position)
		return true
	adventurer.travel_along(session.pathfinder.to_world_points(path, adventurer.position))
	return true


func _update_hover() -> void:
	if is_modal_open() or adventurer.is_travelling():
		_hover_cell = INVALID_CELL
		_preview.clear_hover()
		return
	var cell := session.map.world_to_cell(get_global_mouse_position())
	if cell == _hover_cell:
		return
	_hover_cell = cell
	var target := session.resolve_target(cell)
	var path := session.plan_route(target) if target != INVALID_CELL and target != session.adventurer_cell \
		else ([] as Array[Vector2i])
	if path.size() < 2:
		_preview.clear_hover()
		return
	var label := "~" + WorldClock.format_duration(session.pathfinder.estimate_minutes(path))
	var location := session.locations.at_cell(target)
	if location != null and session.locations.is_discovered(location.id):
		label = "%s  ·  %s" % [location.name, label]
	_preview.show_hover(session.pathfinder.to_world_points(path, adventurer.position), label)


func _on_adventurer_moved(distance: float, at: Vector2) -> void:
	session.travel(distance, at)


## While walking toward a fogged target, keep extending the route as the fog clears.
func _on_cell_changed(_cell: Vector2i) -> void:
	if not adventurer.is_travelling() or _requested == _destination:
		return
	var target := session.resolve_target(_requested)
	if target == INVALID_CELL or target == _destination:
		return
	var path := session.plan_route(target)
	if path.size() > 1:
		_destination = target
		adventurer.travel_along(session.pathfinder.to_world_points(path, adventurer.position))


func _on_adventurer_arrived(_at: Vector2) -> void:
	_preview.show_active(PackedVector2Array())
	var location := session.arrive(_destination) if session.adventurer_cell == _destination else null
	_destination = INVALID_CELL
	_requested = INVALID_CELL
	if location != null:
		open_encounter(location)


func open_encounter(location: Location) -> void:
	encounter_panel.open(location, assets.get_texture(location.art), session.encounter_text(location),
		session.choices_for(location))


func _on_choice_made(location: Location, choice: EncounterChoice) -> void:
	var outcome := session.resolve_choice(location, choice)
	if hatching_panel.is_open():
		return  # The choice started the hatching moment, which replaced the encounter panel.
	encounter_panel.show_outcome(outcome)


func _on_egg_acquired(egg: EggRecord) -> void:
	hud.show_toast("You carry a %s egg. It hatches in about %s." % [egg.species().short_name,
		WorldClock.format_duration(egg.remaining_minutes(session.clock.total_minutes))], 5.0)


func _on_egg_ready(egg: EggRecord) -> void:
	var here := session.locations.at_cell(session.adventurer_cell)
	var at_camp := here != null and here.kind == Location.Kind.CAMP
	hud.show_toast("Your %s egg is ready to hatch!%s" % [egg.species().short_name,
		"" if at_camp else " Bring it to Wayfarer's Camp."], 5.0)


func _on_hatch_requested(egg: EggRecord) -> void:
	encounter_panel.close()
	var species := egg.species()
	hatching_panel.open(egg, assets.get_texture(species.egg_art), assets.get_texture(species.cracked_egg_art),
		assets.get_texture(species.hatchling_art))


func _on_name_confirmed(egg_id: String, chosen_name: String) -> void:
	var dragon := session.hatch_egg(egg_id, chosen_name)
	if dragon != null:
		hatching_panel.show_dragon(dragon, session.clock.total_minutes)
	else:
		push_warning("Hatching refused for egg '%s'." % egg_id)
		hatching_panel.close()
		hud.show_toast("The egg is not ready to hatch yet.")


func _on_dragon_hatched(dragon: DragonRecord) -> void:
	var companion := _add_companion(dragon)
	companion.position = adventurer.position + Vector2(18, 6)
	hud.show_toast("%s the %s joins your travelling dragons!" % [dragon.name, dragon.species().short_name], 4.0)


func _add_companion(dragon: DragonRecord) -> DragonCompanion:
	var companion := DragonCompanion.new()
	companion.setup(dragon, assets, trail, session.roster.index_of(dragon.id), session.clock.total_minutes)
	_world.add_child(companion)
	companions.append(companion)
	return companion


func _on_location_discovered(location: Location) -> void:
	(_markers[location.id] as LocationMarker).set_discovered(true)


func _on_time_changed(_minutes: float) -> void:
	_daylight.color = Daylight.color_at(session.clock.hour_of_day())
	for companion in companions:
		companion.update_growth(session.clock.total_minutes)


## Lays a short breadcrumb trail behind the adventurer so the dragons start in line:
## along the walkable route toward the start (after loading), or along the road at the start.
func _seed_trail(start: Vector2) -> void:
	var back := session.pathfinder.find_path(session.adventurer_cell, ElderwoodVale.START_CELL)
	var points := PackedVector2Array()
	if back.size() >= 3:
		for cell in back.slice(0, 5):
			points.append(session.map.cell_to_world(cell))
		points[0] = start
	else:
		points = PackedVector2Array([start, start + Vector2(-220, 0)])
	trail.reset(points[points.size() - 1])
	for i in range(points.size() - 1, 0, -1):
		var a := points[i]
		var b := points[i - 1]
		var steps := maxi(1, int(a.distance_to(b) / 5.0))
		for j in range(1, steps + 1):
			trail.record(a.lerp(b, float(j) / steps))


func _make_noise() -> Texture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.012
	noise.fractal_octaves = 4
	noise.seed = 7
	return ImageTexture.create_from_image(noise.get_seamless_image(256, 256))
