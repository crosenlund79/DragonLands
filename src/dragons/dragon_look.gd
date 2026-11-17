class_name DragonLook
extends RefCounted
## Turns a dragon's genome into a recolour material for its (shared, replaceable) template art.
## Each art needs a matching "<art>_mask" image; without one the art is shown unchanged.

const SHADER := preload("res://src/dragons/dragon_recolor.gdshader")
const PATTERN_IDS := {"plain": 0, "speckled": 1, "striped": 2, "dappled": 3}

static var _reference_cache: Dictionary = {}  # art -> Vector3 average luminance per region


static func mask_name(art: String) -> String:
	return art + "_mask"


## A material showing `genome` on `art`, or null if the art has no mask (or no genome).
static func material_for(genome: Genome, art: String, assets: AssetResolver, seed_text: String = "") -> ShaderMaterial:
	if genome == null or not assets.has_asset(mask_name(art)):
		return null
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("mask_tex", assets.get_texture(mask_name(art)))
	material.set_shader_parameter("reference_luma", reference_luma(art, assets))
	material.set_shader_parameter("primary_color", _rgb(genome.color("primary")))
	material.set_shader_parameter("secondary_color", _rgb(genome.color("secondary")))
	material.set_shader_parameter("accent_color", _rgb(genome.color("accent")))
	material.set_shader_parameter("pattern", PATTERN_IDS.get(genome.pattern, 0))
	material.set_shader_parameter("pattern_strength", genome.pattern_strength * 0.85)
	material.set_shader_parameter("pattern_color", _rgb(genome.color("accent").darkened(0.45)))
	material.set_shader_parameter("pattern_seed", float(hash(seed_text) % 1000))
	return material


## Average luminance of the template's body / belly / wing regions (computed once per art).
static func reference_luma(art: String, assets: AssetResolver) -> Vector3:
	if _reference_cache.has(art):
		return _reference_cache[art]
	var result := Vector3(0.5, 0.5, 0.5)
	var image := assets.get_texture(art).get_image()
	var mask := assets.get_texture(mask_name(art)).get_image()
	if image != null and mask != null:
		image = image.duplicate()
		mask = mask.duplicate()
		for img in [image, mask]:
			if img.is_compressed():
				img.decompress()
			img.clear_mipmaps()
		if mask.get_size() != image.get_size():
			mask.resize(image.get_width(), image.get_height())
		var sums := Vector3.ZERO
		var counts := Vector3.ZERO
		for y in image.get_height():
			for x in image.get_width():
				var m := mask.get_pixel(x, y)
				if m.a < 0.9:
					continue
				var c := image.get_pixel(x, y)
				var luma := c.r * 0.299 + c.g * 0.587 + c.b * 0.114
				for i in 3:
					var w := [m.r, m.g, m.b][i] as float
					if w > 0.9:
						sums[i] += luma
						counts[i] += 1.0
		for i in 3:
			if counts[i] > 0.0:
				result[i] = sums[i] / counts[i]
	_reference_cache[art] = result
	return result


static func _rgb(c: Color) -> Vector3:
	return Vector3(c.r, c.g, c.b)
