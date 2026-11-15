shader_type canvas_item;
render_mode unshaded;

// Screen-space band blur. The sampler stays nearest so the sharp center is the
// same texel the sprites already drew. The blur is the average of neighbors.

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest, repeat_disable;
uniform float band_px = 50.0;
uniform float strength = 0.4;

void fragment() {
	float y_px = SCREEN_UV.y / SCREEN_PIXEL_SIZE.y;
	float view_h = 1.0 / SCREEN_PIXEL_SIZE.y;
	float from_edge = min(y_px, view_h - y_px);
	float t = smoothstep(band_px, 0.0, from_edge) * strength;
	vec2 px = SCREEN_PIXEL_SIZE;
	float reach = mix(0.0, 8.0, clamp(t / max(strength, 0.001), 0.0, 1.0));
	vec4 sharp = texture(screen_texture, SCREEN_UV);
	vec4 blur = sharp;
	blur += texture(screen_texture, SCREEN_UV + vec2(0.0, px.y * reach));
	blur += texture(screen_texture, SCREEN_UV - vec2(0.0, px.y * reach));
	blur += texture(screen_texture, SCREEN_UV + vec2(0.0, px.y * reach * 2.0));
	blur += texture(screen_texture, SCREEN_UV - vec2(0.0, px.y * reach * 2.0));
	blur += texture(screen_texture, SCREEN_UV + vec2(px.x * reach, 0.0));
	blur += texture(screen_texture, SCREEN_UV - vec2(px.x * reach, 0.0));
	blur += texture(screen_texture, SCREEN_UV + vec2(px.x * reach, px.y * reach));
	blur += texture(screen_texture, SCREEN_UV - vec2(px.x * reach, px.y * reach));
	blur /= 9.0;
	COLOR = mix(sharp, blur, t);
}
