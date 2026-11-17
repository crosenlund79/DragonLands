shader_type canvas_item;
// Fog of war: drifting cloud texture masked by the explored-cells map (TEXTURE, red channel).

uniform sampler2D cloud_tex : repeat_enable, filter_linear_mipmap;
uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform vec2 map_px = vec2(3072.0, 2304.0);
uniform vec2 grid = vec2(48.0, 36.0);

void fragment() {
	vec2 world = UV * map_px;
	vec2 warp = vec2(texture(noise_tex, world / 520.0 + vec2(TIME * 0.004, 0.0)).r,
			texture(noise_tex, world / 520.0 + vec2(0.41, 0.77 + TIME * 0.003)).r) - 0.5;
	float explored = texture(TEXTURE, UV + warp * 1.25 / grid).r;
	float fog = 1.0 - smoothstep(0.2, 0.62, explored);
	vec3 cloud = texture(cloud_tex, world / 640.0 + vec2(TIME * 0.006, TIME * 0.0025)).rgb;
	cloud = mix(cloud, texture(cloud_tex, world / 1100.0 - vec2(TIME * 0.004, 0.0)).rgb, 0.45);
	float rim = smoothstep(0.0, 0.45, fog) * (1.0 - smoothstep(0.45, 0.95, fog));
	cloud += rim * vec3(0.16, 0.17, 0.2);
	COLOR = vec4(cloud, fog);
}
