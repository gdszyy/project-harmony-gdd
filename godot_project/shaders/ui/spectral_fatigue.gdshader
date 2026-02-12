// spectral_fatigue.gdshader
// 频谱偏移疲劳条 Shader — 信号干扰与数据损坏效果
// 模拟故障艺术风格的破碎辉光条
// 关联文档：Docs/UI_Design_Module6_ResonanceSlicing.md §5
shader_type canvas_item;

// 疲劳值 (0.0 ~ 1.0)
uniform float sof_value : hint_range(0.0, 1.0) = 0.0;
// 时间
uniform float time : hint_range(0.0, 1000.0) = 0.0;
// 基础颜色（暗紫）
uniform vec4 color_low : source_color = vec4(0.616, 0.435, 1.0, 1.0);
// 高疲劳颜色（品红）
uniform vec4 color_mid : source_color = vec4(1.0, 0.302, 0.416, 1.0);
// 极高疲劳颜色（刺眼品红）
uniform vec4 color_high : source_color = vec4(1.0, 0.0, 0.4, 1.0);
// 条宽度（归一化）
uniform float bar_height : hint_range(0.0, 1.0) = 0.5;

// 伪随机
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 uv = UV;

	// 基础填充遮罩
	float fill = step(uv.x, sof_value);
	float bar_mask = step(abs(uv.y - 0.5), bar_height * 0.5);

	if (fill < 0.01 || bar_mask < 0.01) {
		// 背景（极暗）
		COLOR = vec4(0.04, 0.03, 0.08, 0.3 * bar_mask);
		return;
	}

	// 颜色插值
	vec4 bar_color;
	if (sof_value < 0.3) {
		bar_color = color_low;
	} else if (sof_value < 0.6) {
		float t = (sof_value - 0.3) / 0.3;
		bar_color = mix(color_low, color_mid, t);
	} else {
		float t = (sof_value - 0.6) / 0.4;
		bar_color = mix(color_mid, color_high, t);
	}

	// 透明度随疲劳增加
	float base_alpha = mix(0.3, 1.0, sof_value);

	// 水平位移毛刺（30%以上）
	float glitch_offset = 0.0;
	if (sof_value > 0.3) {
		float glitch_strength = (sof_value - 0.3) / 0.7;
		float glitch_line = step(0.8, hash(vec2(floor(uv.y * 20.0), floor(time * 3.0))));
		glitch_offset = glitch_line * glitch_strength * 0.1 * sin(time * 20.0);
	}

	// 破碎效果（60%以上）
	float fragment_mask = 1.0;
	if (sof_value > 0.6) {
		float break_strength = (sof_value - 0.6) / 0.4;
		float n = noise(vec2(uv.x * 15.0 + time * 2.0, uv.y * 8.0));
		fragment_mask = smoothstep(0.3 * break_strength, 0.5 * break_strength, n);
		// 多段错位
		float segment = hash(vec2(floor(uv.x * 10.0 + time), 0.0));
		float y_offset = (segment - 0.5) * break_strength * 0.3;
		uv.y += y_offset;
	}

	// 噪点纹理（60%以上）
	float noise_overlay = 0.0;
	if (sof_value > 0.6) {
		noise_overlay = noise(uv * 50.0 + time * 5.0) * (sof_value - 0.6) / 0.4 * 0.3;
	}

	// 扫描线（60%以上）
	float scanline = 0.0;
	if (sof_value > 0.6) {
		scanline = step(0.95, sin(uv.y * 100.0 + time * 10.0)) * 0.3;
	}

	// 抖动（30%以上，强度随疲劳增加）
	float jitter = 0.0;
	if (sof_value > 0.3) {
		float jitter_strength = (sof_value - 0.3) / 0.7;
		float jitter_freq = mix(0.5, 5.0, jitter_strength);  // 2秒到0.2秒一次
		jitter = sin(time * jitter_freq * 6.28318530) * jitter_strength * 0.02;
	}

	// 剧烈闪烁（80%以上）
	float flash = 1.0;
	if (sof_value > 0.8) {
		float flash_strength = (sof_value - 0.8) / 0.2;
		flash = 0.5 + 0.5 * sin(time * 15.0 * flash_strength);
	}

	// 最终合成
	vec4 final_color = bar_color;
	final_color.rgb += noise_overlay;
	final_color.rgb += scanline;
	final_color.a = base_alpha * fill * bar_mask * fragment_mask * flash;

	COLOR = final_color;
}
