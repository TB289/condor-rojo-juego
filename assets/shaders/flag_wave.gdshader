shader_type canvas_item;

uniform float pole_u = 0.05;

// The pole is the left 2 px. Only the cloth, and mostly the top, moves. pole_u = 2 / width.

void vertex() {
	float cloth = smoothstep(pole_u, min(pole_u + 0.35, 0.98), UV.x);
	float tip = clamp(1.0 - UV.y, 0.0, 1.0);
	float wave = sin(TIME * 5.5 + UV.y * 10.0);
	VERTEX.x += wave * 2.6 * cloth * tip;
}

void fragment() {
	COLOR = texture(TEXTURE, UV);
}
