class_name HatchStage
extends Control
## The animated part of the hatching moment: the egg glows and wobbles, cracks,
## bursts into shell fragments and sparkles, and the hatchling pops out.
## Pure presentation; all textures come from the AssetResolver.

signal hatched

const WOBBLE_END := 1.5
const CRACK_END := 2.4
const POP_TIME := 0.6
const EGG_SCALE := 2.0
const HATCHLING_SCALE := 2.4

var _egg: Texture2D
var _cracked: Texture2D
var _hatchling: Texture2D
var _time := -1.0
var _did_burst := false
var _particles: Array[Dictionary] = []
var _hatchling_rect := TextureRect.new()  ## Separate node so it can carry the recolour material.
var _fx := Control.new()  ## Draws shell fragments and sparkles above the hatchling.


func _ready() -> void:
	_hatchling_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hatchling_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hatchling_rect.visible = false
	add_child(_hatchling_rect)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx.draw.connect(_draw_particles)
	add_child(_fx)


func play(egg: Texture2D, cracked: Texture2D, hatchling: Texture2D, hatchling_material: Material = null) -> void:
	_egg = egg
	_cracked = cracked
	_hatchling = hatchling
	_hatchling_rect.texture = hatchling
	_hatchling_rect.material = hatchling_material
	_hatchling_rect.visible = false
	_time = 0.0
	_did_burst = false
	_particles.clear()
	queue_redraw()


## Jumps straight to the hatched state (used by tests and when skipping).
func finish() -> void:
	if _time < CRACK_END:
		_time = CRACK_END
		_burst()
		_place_hatchling()


## Stops the animation (used when the panel closes early).
func stop() -> void:
	_time = -1.0
	_particles.clear()
	_hatchling_rect.visible = false
	queue_redraw()


func has_hatched() -> bool:
	return _did_burst


func _process(delta: float) -> void:
	if _time < 0.0:
		return
	_time += delta
	if not _did_burst and _time >= CRACK_END:
		_burst()
	for p in _particles:
		p.pos += p.vel * delta
		p.vel.y += p.gravity * delta
		p.rot += p.spin * delta
		p.life -= delta
	_particles = _particles.filter(func(p: Dictionary) -> bool: return p.life > 0.0)
	_place_hatchling()
	queue_redraw()
	_fx.size = size
	_fx.queue_redraw()


func _burst() -> void:
	_did_burst = true
	var center := _egg_center()
	for i in 12:
		var a := randf_range(-PI * 0.95, -PI * 0.05)
		_particles.append({"pos": center, "vel": Vector2(cos(a), sin(a)) * randf_range(160, 320), "gravity": 520.0,
			"rot": randf() * TAU, "spin": randf_range(-8, 8), "life": randf_range(0.9, 1.4), "kind": "shell",
			"size": randf_range(7, 13)})
	for i in 26:
		var a := randf() * TAU
		_particles.append({"pos": center, "vel": Vector2(cos(a), sin(a)) * randf_range(60, 230), "gravity": -20.0,
			"rot": 0.0, "spin": 0.0, "life": randf_range(0.8, 1.8), "kind": "spark", "size": randf_range(2.5, 5.5)})
	hatched.emit()


func _egg_center() -> Vector2:
	return Vector2(size.x * 0.5, size.y * 0.55)


func _draw() -> void:
	if _time < 0.0 or _egg == null:
		return
	var center := _egg_center()
	var ground := Vector2(center.x, center.y + _egg.get_height() * EGG_SCALE * 0.42)
	# Warm glow that swells as hatching nears, flashes on the burst, then settles.
	var glow := clampf(_time / CRACK_END, 0.0, 1.0)
	if _did_burst:
		glow = 1.0 + maxf(0.0, 0.5 - (_time - CRACK_END)) * 2.0
	for i in 6:
		var r := size.y * (0.12 + i * 0.05) * (0.75 + glow * 0.25)  # Largest ring stays inside the stage.
		draw_circle(center, r, Color(1.0, 0.7, 0.3, 0.07 * minf(glow, 1.4)))
	draw_set_transform(ground + Vector2(0, 4), 0.0, Vector2(1.0, 0.28))
	draw_circle(Vector2.ZERO, 70.0, Color(0.05, 0.04, 0.03, 0.35))
	draw_set_transform_matrix(Transform2D.IDENTITY)

	if not _did_burst:
		var cracked := _time >= WOBBLE_END
		var strength := _time / WOBBLE_END if not cracked else 1.6
		var angle := sin(_time * (14.0 if not cracked else 26.0)) * 0.07 * strength
		var hop := absf(sin(_time * 13.0)) * 6.0 if cracked else 0.0
		var tex := _cracked if cracked and _cracked else _egg
		var size_px := tex.get_size() * EGG_SCALE
		draw_set_transform(ground - Vector2(0, hop), angle, Vector2.ONE)
		draw_texture_rect(tex, Rect2(Vector2(-size_px.x * 0.5, -size_px.y * 0.93), size_px), false)
		draw_set_transform_matrix(Transform2D.IDENTITY)


func _place_hatchling() -> void:
	if not _did_burst or _hatchling == null:
		return
	var ground := Vector2(size.x * 0.5, _egg_center().y + _egg.get_height() * EGG_SCALE * 0.42)
	var t := clampf((_time - CRACK_END) / POP_TIME, 0.0, 1.0)
	var pop := maxf(0.01, _elastic(t))
	var bob := sin(_time * 3.2) * 3.0 if t >= 1.0 else 0.0
	var size_px := _hatchling.get_size() * HATCHLING_SCALE
	_hatchling_rect.visible = true
	_hatchling_rect.size = size_px
	_hatchling_rect.pivot_offset = Vector2(size_px.x * 0.5, size_px.y * 0.93)
	_hatchling_rect.position = ground - _hatchling_rect.pivot_offset + Vector2(0, bob)
	_hatchling_rect.scale = Vector2(pop, pop)


func _draw_particles() -> void:
	for p in _particles:
		var alpha := clampf(p.life, 0.0, 1.0)
		if p.kind == "shell":
			_fx.draw_set_transform(p.pos, p.rot, Vector2.ONE)
			var s: float = p.size
			var shard := PackedVector2Array([Vector2(-s, -s * 0.4), Vector2(s * 0.6, -s * 0.7), Vector2(s, s * 0.5), Vector2(-s * 0.3, s * 0.6)])
			_fx.draw_colored_polygon(shard, Color(0.97, 0.9, 0.76, alpha))
			_fx.draw_polyline(shard + PackedVector2Array([shard[0]]), Color(0.16, 0.13, 0.09, alpha), 1.5, true)
			_fx.draw_set_transform_matrix(Transform2D.IDENTITY)
		else:
			var s: float = p.size
			var c := Color(1.0, 0.86, 0.45, alpha)
			_fx.draw_line(p.pos - Vector2(s, 0), p.pos + Vector2(s, 0), c, 2.0, true)
			_fx.draw_line(p.pos - Vector2(0, s), p.pos + Vector2(0, s), c, 2.0, true)


static func _elastic(t: float) -> float:
	if t <= 0.0:
		return 0.0
	if t >= 1.0:
		return 1.0
	return pow(2.0, -10.0 * t) * sin((t * 10.0 - 0.75) * (TAU / 3.0)) + 1.0
