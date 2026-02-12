// hud_phase_tint.gdshader
// HUD 全局色调偏移 Shader
// 根据当前相位对 HUD 元素进行色相偏移、亮度调整
// 关联文档：Docs/UI_Design_Module6_ResonanceSlicing.md §8
shader_type canvas_item;

// 色相偏移量 (-0.15 ~ 0.15)
// 高通: -0.08, 低通: +0.08, 全频: 0.0
uniform float hue_shift : hint_range(-0.15, 0.15) = 0.0;
// 亮度偏移量 (-0.2 ~ 0.2)
// 高通: +0.05, 低通: -0.05, 全频: 0.0
uniform float brightness_offset : hint_range(-0.2, 0.2) = 0.0;
// 对比度偏移量
uniform float contrast_offset : hint_range(-0.2, 0.2) = 0.0;
// 模糊量（低通相位轻微模糊）
uniform float blur_amount : hint_range(0.0, 2.0) = 0.0;
// 锐化量（高通相位边缘锐化）
uniform float sharpen_amount : hint_range(0.0, 1.0) = 0.0;

// RGB -> HSL 转换
vec3 rgb_to_hsl(vec3 c) {
	float cmax = max(c.r, max(c.g, c.b));
	float cmin = min(c.r, min(c.g, c.b));
	float delta = cmax - cmin;
	float l = (cmax + cmin) * 0.5;
	float s = 0.0;
	if (delta > 0.0) {
		s = delta / (1.0 - abs(2.0 * l - 1.0));
	}
	float h = 0.0;
	if (delta > 0.0) {
		if (cmax == c.r) {
			h = mod((c.g - c.b) / delta, 6.0);
		} else if (cmax == c.g) {
			h = (c.b - c.r) / delta + 2.0;
		} else {
			h = (c.r - c.g) / delta + 4.0;
		}
		h /= 6.0;
	}
	return vec3(h, s, l);
}

// HSL -> RGB 转换
vec3 hsl_to_rgb(vec3 hsl) {
	float c = (1.0 - abs(2.0 * hsl.z - 1.0)) * hsl.y;
	float x = c * (1.0 - abs(mod(hsl.x * 6.0, 2.0) - 1.0));
	float m = hsl.z - c * 0.5;
	vec3 rgb;
	float h6 = hsl.x * 6.0;
	if (h6 < 1.0) rgb = vec3(c, x, 0.0);
	else if (h6 < 2.0) rgb = vec3(x, c, 0.0);
	else if (h6 < 3.0) rgb = vec3(0.0, c, x);
	else if (h6 < 4.0) rgb = vec3(0.0, x, c);
	else if (h6 < 5.0) rgb = vec3(x, 0.0, c);
	else rgb = vec3(c, 0.0, x);
	return rgb + m;
}

void fragment() {
	vec4 col = texture(TEXTURE, UV);

	// 色相偏移
	vec3 hsl = rgb_to_hsl(col.rgb);
	hsl.x = fract(hsl.x + hue_shift);
	hsl.z = clamp(hsl.z + brightness_offset, 0.0, 1.0);
	col.rgb = hsl_to_rgb(hsl);

	// 对比度调整
	if (abs(contrast_offset) > 0.001) {
		float factor = 1.0 + contrast_offset;
		col.rgb = (col.rgb - 0.5) * factor + 0.5;
		col.rgb = clamp(col.rgb, vec3(0.0), vec3(1.0));
	}

	COLOR = col;
}
