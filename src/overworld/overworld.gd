extends Node2D
## Prototype 001 entry scene. Builds the region, the session (rules/state) and the
## views, then routes input and signals between them. Holds no game rules itself.

const INVALID_CELL := Vector2i(-1, -1)

var session: OverworldSession
var assets: AssetResolver
var adventurer: Adventurer
var camera: OverworldCamera
var hud: Hud
var encounter_panel: EncounterPanel
var trail := FollowTrail.new()

var _preview: PathPreview
var _daylight: CanvasModulate
var _markers: Dictionary = {}  # location id -> LocationMarker
var _destination := INVALID_CELL  # Cell the current route ends on.
var _requested := INVALID_CELL  # Cell the player clicked (may still be in fog).
var _hover_cell := INVALID_CELL


func _ready() -> void:
	assets = AssetResolver.new(AssetResolver.default_override_root())
	var map := ElderwoodVale.create_map()
	session = OverworldSession.new(map, ElderwoodVale.create_locations(), StartingParty.create(),
		ElderwoodVale.START_CELL, ElderwoodVale.START_MINUTES)
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
	var world := Node2D.new()
	world.name = "World"
	world.y_sort_enabled = true
	add_child(world)

	var keep_clear: Array[Vector2i] = [ElderwoodVale.START_CELL]
	for location in session.locations.all():
		keep_clear.append(location.cell)
		var marker := LocationMarker.new()
		marker.setup(location, assets, map)
		world.add_child(marker)
		_markers[location.id] = marker
	DecorView.populate(DecorPlan.build(map, keep_clear), assets, world, ground)

	adventurer = Adventurer.new()
	adventurer.setup(map, assets, map.cell_to_world(ElderwoodVale.START_CELL))
	world.add_child(adventurer)
	_seed_trail(adventurer.position)
	for dragon in session.party:
		var companion := DragonCompanion.new()
		companion.setup(dragon, assets, trail)
		world.add_child(companion)

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

	session.locations.discovered.connect(_on_location_discovered)
	session.clock.time_changed.connect(_on_time_changed)
	session.cell_changed.connect(_on_cell_changed)
	adventurer.moved.connect(_on_adventurer_moved)
	adventurer.arrived.connect(_on_adventurer_arrived)
	encounter_panel.choice_made.connect(_on_choice_made)

	session.begin()
	fog_view.setup(session.fog, map, assets, noise)
	hud.setup(session, assets)
	_on_time_changed(session.clock.total_minutes)
	hud.show_toast("Click the map to travel. Somewhere in the vale, a wild dragon is nesting.", 6.0)


func _process(_delta: float) -> void:
	trail.record(adventurer.position)
	if adventurer.is_travelling():
		_preview.show_active(adventurer.remaining_route())
	_update_hover()


func _unhandled_input(event: InputEvent) -> void:
	if encounter_panel.is_open():
		return
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
	if encounter_panel.is_open() or adventurer.is_travelling():
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
		encounter_panel.open(location, assets.get_texture(location.art))


func _on_choice_made(location: Location, choice: EncounterChoice) -> void:
	encounter_panel.show_outcome(session.resolve_choice(location, choice))


func _on_location_discovered(location: Location) -> void:
	(_markers[location.id] as LocationMarker).set_discovered(true)


func _on_time_changed(_minutes: float) -> void:
	_daylight.color = Daylight.color_at(session.clock.hour_of_day())


## Lays a short breadcrumb trail along the road behind the start so the dragons begin in line.
func _seed_trail(start: Vector2) -> void:
	trail.reset(start + Vector2(-220, 0))
	for i in range(1, 45):
		trail.record(start + Vector2(-220 + i * 5, 0))
	trail.record(start)


func _make_noise() -> Texture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.012
	noise.fractal_octaves = 4
	noise.seed = 7
	return ImageTexture.create_from_image(noise.get_seamless_image(256, 256))
