shader_type canvas_item;
render_mode unshaded;

// Gold at the top, orange at the bottom, a cream edge on the first rows.
// The dark outline is a second label behind this one, so it stays #1A0C14.

uniform vec4 cream : source_color = vec4(1.0, 0.988235, 0.909804, 1.0);
uniform vec4 gold : source_color = vec4(1.0, 0.878431, 0.0, 1.0);
uniform vec4 orange : source_color = vec4(1.0, 0.415686, 0.125490, 1.0);

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float t = clamp(UV.y, 0.0, 1.0);
	vec3 col = mix(gold.rgb, orange.rgb, smoothstep(0.12, 1.0, t));
	float rim = 1.0 - smoothstep(0.0, 0.2, t);
	col = mix(col, cream.rgb, rim);
	COLOR = vec4(col, tex.a);
}
