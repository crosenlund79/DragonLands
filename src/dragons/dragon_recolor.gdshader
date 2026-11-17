shader_type canvas_item;
// Shows a dragon's genome on shared template art.
// mask_tex: red = body (primary), green = belly (secondary), blue = wings/crest (accent),
// black = keep the original pixel (outline, eyes, horns, flame).
// Each region keeps the art's shading: new colour x (pixel luminance / region's average luminance).
// Markings are drawn procedurally on the body region, so no per-pattern images are needed.

uniform sampler2D mask_tex : filter_linear_mipmap;
uniform vec3 primary_color = vec3(1.0);
uniform vec3 secondary_color = vec3(1.0);
uniform vec3 accent_color = vec3(1.0);
uniform vec3 reference_luma = vec3(0.5);  // average luminance of each region in the template
uniform int pattern = 0;  // 0 plain, 1 speckled, 2 striped, 3 dappled
uniform float pattern_strength = 0.0;
uniform vec3 pattern_color = vec3(0.2);
uniform float pattern_seed = 0.0;

varying vec4 tint;

void vertex() {
	tint = COLOR;
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float spots(vec2 px, float cell, float radius, float softness) {
	vec2 c = floor(px / cell);
	float m = 0.0;
	for (int i = -1; i <= 1; i++) {
		for (int j = -1; j <= 1; j++) {
			vec2 n = c + vec2(float(i), float(j));
			vec2 jitter = vec2(hash12(n + pattern_seed), hash12(n + pattern_seed + 17.0));
			vec2 center = (n + 0.2 + 0.6 * jitter) * cell;
			float r = radius * (0.65 + 0.6 * hash12(n + pattern_seed + 31.0));
			m = max(m, 1.0 - smoothstep(r - softness, r + softness, length(px - center)));
		}
	}
	return m;
}

float marking(vec2 px) {
	if (pattern == 1) {
		return spots(px, 6.0, 1.5, 0.6);
	} else if (pattern == 2) {
		float s = sin((px.x * 0.9 + px.y * 0.35) * 0.42 + pattern_seed);
		return smoothstep(0.25, 0.7, s);
	} else if (pattern == 3) {
		return spots(px, 13.0, 3.6, 1.6);
	}
	return 0.0;
}

void fragment() {
	vec4 base = texture(TEXTURE, UV);
	vec4 m = texture(mask_tex, UV);
	float luma = dot(base.rgb, vec3(0.299, 0.587, 0.114));
	vec3 shade = vec3(luma) / max(reference_luma, vec3(0.05));
	vec3 col = base.rgb;
	col = mix(col, primary_color * shade.x, m.r);
	col = mix(col, secondary_color * shade.y, m.g);
	col = mix(col, accent_color * shade.z, m.b);
	vec2 px = UV / TEXTURE_PIXEL_SIZE;
	col = mix(col, pattern_color * shade.x, marking(px) * pattern_strength * m.r);
	COLOR = vec4(clamp(col, 0.0, 1.0), base.a) * tint;
}
