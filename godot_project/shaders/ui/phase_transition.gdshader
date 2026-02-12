// phase_transition.gdshader
// 全屏频谱扫描过渡效果 Shader
// 在相位切换时产生扫描线 + 色差 + 噪点的过渡效果
// 关联文档：Docs/UI_Design_Module6_ResonanceSlicing.md §7
shader_type canvas_item;

// 过渡进度 (0.0 ~ 1.0)
uniform float progress : hint_range(0.0, 1.0) = 0.0;
// 扫描方向：0=从下往上(Overtone), 1=从上往下(SubBass), 2=从中心向外(Fundamental)
uniform int direction = 0;
// 目标相位颜色
uniform vec4 target_color : source_color = vec4(0.3, 1.0, 0.95, 1.0);
// 扫描线宽度
uniform float scan_width : hint_range(0.01, 0.2) = 0.1;
// 色差强度
uniform float chromatic_strength : hint_range(0.0, 0.05) = 0.015;
// 噪点强度
uniform float noise_strength : hint_range(0.0, 1.0) = 0.3;
// 余波数量
uniform int ripple_count : hint_range(0, 5) = 3;

// 伪随机
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// 简单噪声
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
	vec2 uv = SCREEN_UV;
	vec4 screen_color = textureLod(TEXTURE, UV, 0.0);

	// 计算扫描线位置
	float scan_pos;
	if (direction == 0) {
		// 从下往上 (Overtone)
		scan_pos = 1.0 - progress;
	} else if (direction == 1) {
		// 从上往下 (SubBass)
		scan_pos = progress;
	} else {
		// 从中心向外 (Fundamental)
		scan_pos = abs(uv.y - 0.5) * 2.0;
	}

	// 扫描线遮罩
	float dist;
	if (direction == 2) {
		// 中心扩散模式：使用径向距离
		float center_dist = length(uv - vec2(0.5, 0.5)) * 2.0;
		dist = abs(center_dist - progress);
	} else {
		dist = abs(uv.y - scan_pos);
	}

	float scan_mask = smoothstep(scan_width, 0.0, dist);

	// 余波效果
	float ripple_mask = 0.0;
	for (int i = 1; i <= ripple_count; i++) {
		float ripple_offset = float(i) * scan_width * 1.5;
		float ripple_pos;
		if (direction == 0) {
			ripple_pos = scan_pos + ripple_offset;
		} else if (direction == 1) {
			ripple_pos = scan_pos - ripple_offset;
		} else {
			ripple_pos = progress - ripple_offset;
		}
		float ripple_dist;
		if (direction == 2) {
			float rd = length(uv - vec2(0.5, 0.5)) * 2.0;
			ripple_dist = abs(rd - ripple_pos);
		} else {
			ripple_dist = abs(uv.y - ripple_pos);
		}
		float ripple_strength = 1.0 / float(i + 1);
		ripple_mask += smoothstep(scan_width * 0.5, 0.0, ripple_dist) * ripple_strength;
	}

	float total_mask = scan_mask + ripple_mask * 0.5;

	// 色差效果
	float chromatic_offset = total_mask * chromatic_strength;
	vec4 color_r = textureLod(TEXTURE, UV + vec2(chromatic_offset, 0.0), 0.0);
	vec4 color_g = textureLod(TEXTURE, UV, 0.0);
	vec4 color_b = textureLod(TEXTURE, UV - vec2(chromatic_offset, 0.0), 0.0);
	vec4 chromatic = vec4(color_r.r, color_g.g, color_b.b, 1.0);

	// 噪点
	float n = noise(uv * 4.0 + vec2(progress * 10.0, 0.0));
	float noise_mask = scan_mask * n * noise_strength;

	// 扫描线核心光带
	float core_line = smoothstep(scan_width * 0.3, 0.0, dist);

	// 混合
	vec4 result = mix(screen_color, chromatic, total_mask * 0.5);
	result = mix(result, target_color, scan_mask * 0.3 + noise_mask);
	result.rgb += target_color.rgb * core_line * 0.5;

	// 整体透明度由 progress 控制淡入淡出
	float fade = sin(progress * 3.14159265);  // 在 0 和 1 时为 0，在 0.5 时最大
	result = mix(screen_color, result, fade);

	COLOR = result;
}
