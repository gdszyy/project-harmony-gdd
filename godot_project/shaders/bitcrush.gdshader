shader_type canvas_item;

// 比特破碎 (Bitcrush) 效果 Shader
// 用于第七章 "合成主脑·噪音" 的敌人和Boss战
// 模拟降采样、色彩量化和数据损坏的视觉效果

uniform float pixel_size : hint_range(1.0, 32.0) = 1.0;
uniform float color_depth : hint_range(2.0, 256.0) = 256.0;
uniform float corruption : hint_range(0.0, 1.0) = 0.0;
uniform float chromatic_aberration : hint_range(0.0, 0.05) = 0.0;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float noise_amount : hint_range(0.0, 1.0) = 0.0;

float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
    vec2 uv = UV;
    
    // Pixelation (降采样)
    if (pixel_size > 1.0) {
        vec2 pixel_uv = floor(uv * (1.0 / TEXTURE_PIXEL_SIZE) / pixel_size) * pixel_size * TEXTURE_PIXEL_SIZE;
        uv = pixel_uv;
    }
    
    // Corruption: randomly offset UV
    if (corruption > 0.0) {
        float noise = random(floor(uv * 20.0) + vec2(floor(TIME * 5.0)));
        if (noise < corruption * 0.3) {
            uv.x += (random(uv + TIME) - 0.5) * corruption * 0.1;
        }
    }
    
    // Chromatic Aberration (色差)
    float r = texture(TEXTURE, uv + vec2(chromatic_aberration, 0.0)).r;
    float g = texture(TEXTURE, uv).g;
    float b = texture(TEXTURE, uv - vec2(chromatic_aberration, 0.0)).b;
    float a = texture(TEXTURE, uv).a;
    
    vec3 color = vec3(r, g, b);
    
    // Color quantization (色彩量化)
    color = floor(color * color_depth) / color_depth;
    
    // Scanlines
    if (scanline_intensity > 0.0) {
        float scanline = sin(UV.y * 800.0) * 0.5 + 0.5;
        color *= 1.0 - scanline * scanline_intensity;
    }
    
    // Digital noise
    if (noise_amount > 0.0) {
        float noise = random(uv + vec2(TIME * 0.1)) * noise_amount;
        color += vec3(noise) - noise_amount * 0.5;
    }
    
    COLOR = vec4(color, a);
}
