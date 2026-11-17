shader_type canvas_item;
// Gentle wind sway for foliage sprites: the top of the sprite moves, the base stays put.

uniform float strength = 1.6;

void vertex() {
	vec2 world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	float top = 1.0 - UV.y;
	VERTEX.x += sin(TIME * 1.15 + world.x * 0.011 + world.y * 0.017) * strength * top * top;
}
