shader_type canvas_item;

// enemy_static_glitch.gdshader
// 继承自 enemy_glitch.gdshader，并为 Static 敌人添加了 Datamosh 和顶点抖动效果。

// === 基础故障参数 (从 enemy_glitch 继承) ===
uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float hp_ratio : hint_range(0.0, 1.0) = 1.0;
uniform float beat_energy : hint_range(0.0, 1.0) = 0.0;
uniform float is_stunned : hint_range(0.0, 1.0) = 0.0;
uniform vec4 base_tint : source_color = vec4(1.0, 0.2, 0.3, 1.0);
uniform vec4 glitch_color : source_color = vec4(1.0, 0.0, 0.67, 1.0);

// === 基础效果参数 (从 enemy_glitch 继承) ===
uniform float scanline_density : hint_range(10.0, 200.0) = 80.0;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.3;
uniform float chromatic_offset : hint_range(0.0, 10.0) = 2.0;
uniform float noise_speed : hint_range(0.0, 10.0) = 3.0;
uniform float pixel_size : hint_range(1.0, 16.0) = 1.0;

// === Static 专属效果 ===
uniform float datamosh_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float jitter_amplitude : hint_range(0.0, 5.0) = 1.0;

// 伪随机噪声 (从 enemy_glitch 复制)
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

// === 顶点着色器: 实现顶点抖动 ===
void vertex() {
	float time = TIME * noise_speed * 2.0;
	// 结合 glitch_intensity 和 is_stunned 来控制抖动
	float current_jitter = jitter_amplitude * max(glitch_intensity, is_stunned * 2.0);
	
	// 高频、小幅度的抖动
	VERTEX.x += (hash(vec2(time * 10.0, VERTEX.y)) - 0.5) * current_jitter;
	VERTEX.y += (hash(vec2(time * 10.0, VERTEX.x)) - 0.5) * current_jitter;
}


// === 片段着色器: 实现 Datamosh 和其他效果 ===
void fragment() {
    vec2 uv = UV;
    float time = TIME * noise_speed;
    float intensity = glitch_intensity;

    // 眩晕时故障加剧
    intensity = max(intensity, is_stunned * 0.6);

    // === Datamosh (数据花块) ===
	vec2 mosh_uv = uv;
	if (datamosh_intensity > 0.0) {
		float block_size = mix(64.0, 16.0, datamosh_intensity);
		vec2 block_grid = floor(uv * block_size);
		float block_hash = hash(block_grid + floor(time * 5.0));

		// 随机选择一些块进行位移
		if (block_hash > mix(1.0, 0.85, datamosh_intensity)) {
			float shift_hash = hash(block_grid + 10.0);
			vec2 shift_direction = vec2(hash(block_grid.yx) - 0.5, shift_hash - 0.5) * 2.0;
			float shift_amount = hash(block_grid + floor(time * 5.0 + 20.0)) * 0.2 * datamosh_intensity;
			mosh_uv += shift_direction * shift_amount;
		}
	}
	uv = mosh_uv;

    // === 像素化 ===
    float pix = max(1.0, pixel_size);
    if (pix > 1.5) {
        uv = floor(uv * (1.0 / pix) * 64.0) / 64.0 * pix;
    }

    // === 水平撕裂 (Horizontal Tear) ===
    float tear = 0.0;
    if (intensity > 0.3) {
        float tear_line = step(0.95 - intensity * 0.3, hash(vec2(floor(time * 8.0), floor(uv.y * 20.0))));
        tear = tear_line * intensity * 0.05;
    }
    uv.x += tear;

    // === 色差 (Chromatic Aberration) ===
    float ca_offset = chromatic_offset * intensity / 100.0;
    vec4 color_r = texture(TEXTURE, uv + vec2(ca_offset, 0.0));
    vec4 color_g = texture(TEXTURE, uv);
    vec4 color_b = texture(TEXTURE, uv - vec2(ca_offset, 0.0));
    vec4 color = vec4(color_r.r, color_g.g, color_b.b, color_g.a);

    // 如果没有纹理（纯 Polygon2D），使用顶点颜色
    if (color.a < 0.01) {
        color = COLOR;
    }

    // === 扫描线 ===
    float scanline = sin(FRAGCOORD.y * scanline_density * 0.1) * 0.5 + 0.5;
    scanline = mix(1.0, scanline, scanline_strength * intensity);
    color.rgb *= scanline;

    // === 噪点 (Film Grain) ===
    if (intensity > 0.2) {
        float grain = hash(uv * time * 100.0) * intensity * 0.3;
        color.rgb += vec3(grain);
    }

    // === HP 相关效果 ===
    if (hp_ratio < 0.5) {
        float white_blend = (0.5 - hp_ratio) * 1.2;
        color.rgb = mix(color.rgb, vec3(1.0), white_blend * 0.5);
    }

    // === 节拍脉冲 ===
    color.rgb += vec3(beat_energy * 0.15);

    // === 随机闪烁 ===
    if (intensity > 0.6) {
        float flicker = step(0.7, hash(vec2(time * 20.0, 0.0)));
        color.a *= mix(1.0, 0.3, flicker * intensity);
    }

    // === 应用基础色调 ===
    color.rgb *= base_tint.rgb;
    color.rgb = mix(color.rgb, glitch_color.rgb, glitch_intensity * 0.3);

    COLOR = color;
}
