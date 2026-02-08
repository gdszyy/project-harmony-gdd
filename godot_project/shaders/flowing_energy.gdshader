shader_type canvas_item;

uniform vec4 base_color : source_color = vec4(0.8, 0.2, 0.3, 1.0);
uniform vec4 highlight_color : source_color = vec4(1.0, 0.5, 0.6, 1.0);

uniform float speed = 0.4;
uniform float noise_scale = 5.0;
uniform float highlight_width = 0.1;

// 2D Noise function
float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
    // Base color of the bar
    vec4 color = base_color;
    
    // Create moving bands of light
    float time_factor = TIME * speed;
    float band_1 = smoothstep(0.0, highlight_width, fract(UV.x * 2.0 + time_factor));
    band_1 *= smoothstep(highlight_width + 0.1, highlight_width, fract(UV.x * 2.0 + time_factor));

    float band_2 = smoothstep(0.0, highlight_width, fract(UV.x * 1.5 - time_factor * 0.7));
    band_2 *= smoothstep(highlight_width + 0.15, highlight_width, fract(UV.x * 1.5 - time_factor * 0.7));

    // Add subtle noise to the bands to make them less uniform
    float noise = random(UV * noise_scale + vec2(TIME * 0.1, 0.0)) * 0.3;
    
    // Combine bands and apply to the highlight color
    vec3 highlight = highlight_color.rgb * (band_1 + band_2 + noise);
    
    // Mix with the base color
    color.rgb = mix(color.rgb, highlight, highlight_color.a * (band_1 + band_2 + noise));
    
    COLOR = color;
}
