shader_type canvas_item;
render_mode unshaded;

// Night mask for the world viewport only. The hole and the beam are a smoothstep
// on this rect's alpha. Sprites underneath stay nearest; this pass does not blur them.
uniform vec2 player_px = vec2(320.0, 180.0);
uniform vec2 beam_px = vec2(320.0, 180.0);
uniform vec2 view_size = vec2(640.0, 360.0);
uniform float radius_px = 44.0;
uniform float softness_px = 11.0;
uniform vec2 beam_dir = vec2(0.0, 1.0);
uniform float beam_on = 0.0;
uniform float beam_length_px = 160.0;
uniform float beam_width_px = 31.0;
uniform float amount = 0.0;
uniform vec4 dark : source_color = vec4(0.05098, 0.07059, 0.10980, 0.96);

void fragment() {
	vec2 px = UV * view_size;
	vec2 d = px - player_px;
	float dist = length(d);
	float edge = max(softness_px, 1.0);
	float circle = 1.0 - smoothstep(radius_px - edge, radius_px, dist);
	float beam = 0.0;
	if (beam_on > 0.5) {
		vec2 from = px - beam_px;
		vec2 dir = beam_dir;
		if (dot(dir, dir) < 0.001) {
			dir = vec2(0.0, 1.0);
		}
		float along = dot(from, dir);
		float side = abs(from.x * dir.y - from.y * dir.x);
		float reach = clamp(along / max(beam_length_px, 1.0), 0.0, 1.0);
		float widen = mix(8.0, beam_width_px, reach);
		float along_m = 1.0 - smoothstep(beam_length_px - edge, beam_length_px + 6.0, along);
		float side_m = 1.0 - smoothstep(widen - 4.0, widen + 2.0, side);
		beam = along_m * side_m * step(0.0, along);
	}
	float vis = max(circle, beam);
	float shade = (1.0 - vis) * clamp(amount, 0.0, 1.0);
	COLOR = vec4(dark.rgb, dark.a * shade);
}
