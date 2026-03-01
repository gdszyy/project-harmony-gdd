shader_type canvas_item;

// waveform.gdshader
// 主菜单背景 — 谐振波形动效
// 参考设计文档: UI_Design_Module1_MainMenu.md

uniform float time_scale : hint_range(0.1, 5.0) = 1.0;
uniform float amplitude : hint_range(0.0, 0.5) = 0.15;
uniform float frequency : hint_range(1.0, 20.0) = 6.0;
uniform int wave_count : hint_range(1, 8) = 4;
uniform float line_thickness : hint_range(0.001, 0.02) = 0.005;
uniform vec4 wave_color_1 : source_color = vec4(0.4, 0.6, 1.0, 0.6);
uniform vec4 wave_color_2 : source_color = vec4(0.8, 0.4, 1.0, 0.4);
uniform vec4 background_color : source_color = vec4(0.05, 0.02, 0.1, 1.0);
uniform float phase_offset : hint_range(0.0, 6.28) = 0.5;

void fragment() {
	vec2 uv = UV;
	float t = TIME * time_scale;
	vec4 col = background_color;

	for (int i = 0; i < wave_count; i++) {
		float fi = float(i);
		float freq_mod = frequency + fi * 1.5;
		float amp_mod = amplitude * (1.0 - fi * 0.1);
		float phase = fi * phase_offset + t * (0.8 + fi * 0.2);

		// 正弦波叠加
		float wave_y = 0.5 + amp_mod * sin(uv.x * freq_mod + phase);
		// 添加谐波
		wave_y += amp_mod * 0.3 * sin(uv.x * freq_mod * 2.0 + phase * 1.5);

		float dist = abs(uv.y - wave_y);
		float line = smoothstep(line_thickness, 0.0, dist);

		// 颜色插值
		float color_mix = fi / float(wave_count - 1);
		vec4 wave_col = mix(wave_color_1, wave_color_2, color_mix);
		wave_col.a *= line;

		// 发光效果
		float glow = smoothstep(line_thickness * 8.0, 0.0, dist) * 0.15;
		wave_col.a += glow * wave_col.a;

		col = mix(col, wave_col, wave_col.a);
	}

	COLOR = col;
}
