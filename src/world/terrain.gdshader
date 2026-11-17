shader_type canvas_item;
// Blends terrain textures from a 1-pixel-per-cell control map.
// Control channels: r = forest floor, g = road, b = water, a = rock; grass fills the rest.
// The control lookup is warped by noise so cell borders read as organic edges.

uniform sampler2D tex_grass : repeat_enable, filter_linear_mipmap;
uniform sampler2D tex_forest : repeat_enable, filter_linear_mipmap;
uniform sampler2D tex_road : repeat_enable, filter_linear_mipmap;
uniform sampler2D tex_water : repeat_enable, filter_linear_mipmap;
uniform sampler2D tex_rock : repeat_enable, filter_linear_mipmap;
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform vec2 map_px = vec2(3072.0, 2304.0);
uniform vec2 grid = vec2(48.0, 36.0);
uniform float tile_px = 256.0;

float band(float w, float center, float softness) {
	return smoothstep(center - softness, center + softness, w);
}

void fragment() {
	vec2 world = UV * map_px;
	vec2 warp = vec2(texture(noise_tex, world / 700.0).r,
			texture(noise_tex, world / 700.0 + vec2(0.37, 0.71)).r) - 0.5;
	vec2 fine = vec2(texture(noise_tex, world / 190.0).r,
			texture(noise_tex, world / 190.0 + vec2(0.53, 0.19)).r) - 0.5;
	vec4 c = texture(TEXTURE, UV + (warp * 0.9 + fine * 0.35) / grid);
	vec4 c_soft = texture(TEXTURE, UV + warp * 0.5 / grid);

	vec2 tuv = world / tile_px;
	float macro = texture(noise_tex, world / 1900.0).r;
	vec3 col = texture(tex_grass, tuv).rgb * mix(0.86, 1.1, macro);

	float forest = band(c.r, 0.42, 0.22);
	col = mix(col, texture(tex_forest, tuv * 1.1).rgb, forest);

	float rock = band(c.a, 0.45, 0.18);
	col = mix(col, texture(tex_rock, tuv * 0.8).rgb * mix(0.9, 1.06, macro), rock);

	// Roads: dark trodden rim, then packed dirt.
	float road = band(c.g, 0.58, 0.06);
	float road_rim = band(c.g, 0.48, 0.07) - road;
	col = mix(col, col * vec3(0.72, 0.68, 0.6), road_rim * 0.8);
	col = mix(col, texture(tex_road, tuv).rgb, road);

	// Water: muddy shore, shallow-to-deep tint, drifting ripples.
	float water = band(c.b, 0.5, 0.05);
	float shore = band(c.b, 0.36, 0.06) - water;
	col = mix(col, vec3(0.58, 0.52, 0.36), shore * 0.85);
	vec2 drift = vec2(TIME * 0.012, TIME * 0.007);
	vec3 wcol = texture(tex_water, tuv + drift + warp * 0.08).rgb;
	wcol = mix(wcol, texture(tex_water, tuv * 1.7 - drift * 1.3).rgb, 0.35);
	float depth = band(c_soft.b, 0.86, 0.12);
	wcol = mix(wcol * vec3(1.1, 1.08, 1.02), wcol * vec3(0.78, 0.86, 0.95), depth);
	float glint = smoothstep(0.78, 0.84, texture(noise_tex, world / 120.0 + vec2(TIME * 0.03, 0.0)).r);
	wcol += glint * 0.12 * (1.0 - depth);
	col = mix(col, wcol, water);

	// Gentle vignette-free contrast lift keeps the painted look readable when zoomed out.
	col = mix(col, col * col * 1.35, 0.12);
	COLOR = vec4(col, 1.0);
}
