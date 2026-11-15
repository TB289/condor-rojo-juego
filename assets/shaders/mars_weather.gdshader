shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float dust_strength : hint_range(0.0, 1.0) = 0.0;
uniform float radiation_strength : hint_range(0.0, 1.0) = 0.0;
uniform vec2 player_screen = vec2(0.5, 0.5);
uniform float seconds = 0.0;

float hash21(vec2 p) {
    p = fract(p * vec2(127.1, 311.7));
    p += dot(p, p + 19.19);
    return fract(p.x * p.y);
}

void fragment() {
    vec3 rgb = texture(screen_texture, SCREEN_UV).rgb;
    vec2 uv = SCREEN_UV;
    if (dust_strength > 0.001) {
        // Strong sand haze outside the area immediately around the astronaut.
        float dist_px = distance((uv - player_screen) * vec2(640.0, 360.0), vec2(0.0));
        float visibility = 1.0 - smoothstep(48.0, mix(320.0, 105.0, dust_strength), dist_px);
        float gust = sin(uv.y * 115.0 - uv.x * 51.0 + seconds * 6.0) * 0.038;
        float noise = hash21(floor(uv * vec2(240.0, 135.0) + vec2(seconds * 27.0, -seconds * 10.0)));
        vec3 sand = vec3(0.76, 0.47, 0.27) + vec3(gust + noise * 0.065);
        float haze = dust_strength * mix(0.67, 0.23, visibility);
        rgb = mix(rgb, sand, clamp(haze, 0.0, 0.85));
    }
    if (radiation_strength > 0.001) {
        // Strong vivid contrasts like the accessibility filter, restricted to the
        // game world (the HUD remains legible). Gentle pulse: no fast flashing.
        float pulse = 0.91 + 0.09 * sin(seconds * 1.8);
        float strength = radiation_strength * pulse;
        vec3 punch = clamp((rgb - vec3(0.5)) * (1.0 + strength * 0.98) + vec3(0.5), vec3(0.0), vec3(1.0));
        float luma = dot(punch, vec3(0.2126, 0.7152, 0.0722));
        punch = clamp(mix(vec3(luma), punch, 1.0 + strength * 0.37), vec3(0.0), vec3(1.0));
        punch += vec3(0.11, -0.015, 0.17) * strength;
        float edge = smoothstep(0.37, 0.70, distance(uv, vec2(0.5)));
        punch = mix(punch, vec3(0.60, 0.14, 0.64), edge * strength * 0.35);
        rgb = mix(rgb, clamp(punch, vec3(0.0), vec3(1.0)), strength);
    }
    COLOR = vec4(rgb, 1.0);
}
