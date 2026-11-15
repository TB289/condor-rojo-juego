shader_type canvas_item;
render_mode unshaded;

// One pass for the outdoor world: a little 3/4 perspective and curvature on the
// frame. The wide center is a 1:1 nearest blit. Tilt-shift sampling is skipped
// when tilt_strength is 0 (the default); the uniform stays so it can be re-enabled.
// Warping there (perspective 0.1 scales x by about 1.045 at uv.y = 0.5) makes
// neighboring pixels share or skip a texel after the snap, which reads as blur.
// use_screen = true when this draws a BackBufferCopy (MarsMap opened alone).
// use_screen = false when TEXTURE is the world SubViewport.

uniform sampler2D world_tex : filter_nearest, repeat_disable;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;
uniform bool use_screen = false;
uniform vec2 view_size = vec2(640.0, 360.0);
uniform float perspective = 0.0;
uniform float curvature = 0.0;
uniform float band_px = 20.0;
uniform float tilt_strength = 0.0;

vec2 warp(vec2 uv) {
	float y = uv.y + perspective * uv.y * (1.0 - uv.y);
	float x_scale = 1.0 + perspective * (1.0 - uv.y) * 0.9;
	float x = (uv.x - 0.5) * x_scale + 0.5;
	float edge = (uv.x - 0.5) * 2.0;
	y -= curvature * edge * edge;
	vec2 c = vec2(x, y) - 0.5;
	c *= 1.0 + curvature * 0.55 * dot(c, c);
	return c + 0.5;
}

vec2 snap_texel(vec2 uv) {
	return (floor(uv * view_size) + 0.5) / view_size;
}

// 0 across the play area, rising only in the outer frame.
// Vertical ramp is the top and bottom ~32 px. Horizontal ramp is the side frame (~62 px).
float frame_amount(vec2 uv) {
	vec2 px = abs(uv - vec2(0.5)) * view_size;
	vec2 half_size = view_size * 0.5;
	float ax = smoothstep(half_size.x - 62.0, half_size.x - 2.0, px.x);
	float ay = smoothstep(half_size.y - 32.0, half_size.y - 2.0, px.y);
	return max(ax, ay);
}

vec4 fetch(vec2 uv) {
	if (use_screen) {
		return texture(screen_tex, uv);
	}
	return texture(world_tex, uv);
}

vec4 sample_world(vec2 uv) {
	float edge = 0.0;
	if (perspective > 0.001 || curvature > 0.001) {
		edge = frame_amount(uv);
	}
	// Identity in the center: no warp, no snap, nearest texel of this pixel.
	if (edge <= 0.001) {
		return fetch(uv);
	}
	vec2 warped = mix(uv, warp(uv), edge);
	vec2 limit = vec2(1.0) - vec2(1.0) / view_size;
	return fetch(snap_texel(clamp(warped, vec2(0.0), limit)));
}

void fragment() {
	vec2 uv = use_screen ? SCREEN_UV : UV;
	vec4 sharp = sample_world(uv);
	float t = 0.0;
	if (tilt_strength > 0.001 && band_px > 0.5) {
		float y_px = uv.y * view_size.y;
		float from_edge = min(y_px, view_size.y - y_px);
		t = smoothstep(band_px, 0.0, from_edge) * tilt_strength;
	}
	vec4 color = sharp;
	if (t >= 0.001) {
		float reach = mix(0.0, 8.0, clamp(t / max(tilt_strength, 0.001), 0.0, 1.0));
		vec2 px = vec2(1.0) / view_size;
		vec4 blur = sharp;
		blur += sample_world(uv + vec2(0.0, px.y * reach));
		blur += sample_world(uv - vec2(0.0, px.y * reach));
		blur += sample_world(uv + vec2(0.0, px.y * reach * 2.0));
		blur += sample_world(uv - vec2(0.0, px.y * reach * 2.0));
		blur += sample_world(uv + vec2(px.x * reach, 0.0));
		blur += sample_world(uv - vec2(px.x * reach, 0.0));
		blur += sample_world(uv + vec2(px.x * reach, px.y * reach));
		blur += sample_world(uv - vec2(px.x * reach, px.y * reach));
		blur /= 9.0;
		color = mix(sharp, blur, t);
	}
	COLOR = color;
}
