shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform int vision_mode = 1;

void fragment() {
    vec3 rgb = texture(screen_texture, SCREEN_UV).rgb;
    float luma = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
    if (vision_mode == 1) {
        // Stronger light/dark distinction and slightly reduced muddy midtones.
        rgb = clamp((rgb - vec3(0.5)) * 1.36 + vec3(0.5), vec3(0.0), vec3(1.0));
        rgb = mix(vec3(luma), rgb, 1.12);
    } else if (vision_mode == 2) {
        // Separate warm highlights from dark blue/cyan, avoiding red/green cues.
        float warm = clamp(rgb.r * 0.80 + rgb.g * 0.35 - rgb.b * 0.50, 0.0, 1.0);
        float cool = clamp(rgb.b * 0.85 + rgb.g * 0.30 - rgb.r * 0.35, 0.0, 1.0);
        rgb = mix(vec3(luma), vec3(warm + 0.08 * luma,
                                  warm * 0.82 + cool * 0.60,
                                  cool + 0.14 * luma), 0.84);
        rgb = clamp((rgb - vec3(0.5)) * 1.17 + vec3(0.5), vec3(0.0), vec3(1.0));
    } else if (vision_mode == 3) {
        rgb = vec3(clamp((luma - 0.5) * 1.30 + 0.5, 0.0, 1.0));
    }
    COLOR = vec4(clamp(rgb, vec3(0.0), vec3(1.0)), 1.0);
}
