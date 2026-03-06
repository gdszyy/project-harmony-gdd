shader_type canvas_item;

// 合成主脑 (Synthesizer) 专属特效 Shader
// 核心机制：波形变换（四种基础波形切换）
// 视觉特征：故障像素 + 波形可视化 + 几何形态

uniform vec4 base_color : source_color = vec4(0.0, 1.0, 0.8, 1.0);
uniform float intensity : hint_range(0.0, 2.0) = 1.0;
uniform int waveform_type : hint_range(0, 3) = 0; // 0=Sine, 1=Square, 2=Sawtooth, 3=Triangle
uniform bool is_morphing = false; // 是否处于波形过渡期

// ADSR 包络参数
uniform float attack_time = 0.01;
uniform float decay_time = 0.05;
uniform float sustain_level = 0.75;
uniform float release_time = 0.03;
uniform float time_alive = 0.0;

float get_adsr_envelope(float t) {
	if (t < attack_time) {
		return t / attack_time;
	} else if (t < attack_time + decay_time) {
		return mix(1.0, sustain_level, (t - attack_time) / decay_time);
	} else {
		return sustain_level;
	}
}

// 伪随机
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 center = UV - 0.5;
	float t = TIME;
	float env = get_adsr_envelope(time_alive);
	
	// 1. 像素化网格
	float pixel_size = 0.02;
	vec2 pixel_uv = floor(center / pixel_size) * pixel_size;
	float dist = length(pixel_uv);
	vec2 abs_center = abs(pixel_uv);
	
	// 2. 基础几何形态
	float shape = 0.0;
	vec4 shape_color = base_color;
	
	// 故障过渡期：随机切换波形
	int current_wave = waveform_type;
	if (is_morphing) {
		float glitch_time = floor(t * 20.0);
		current_wave = int(hash(vec2(glitch_time, 0.0)) * 4.0);
	}
	
	if (current_wave == 0) {
		// Sine: 圆润光球 (青色)
		shape = smoothstep(0.3, 0.25, dist);
		shape_color = vec4(0.0, 1.0, 0.8, 1.0);
	} else if (current_wave == 1) {
		// Square: 棱角方块 (洋红)
		float box = max(abs_center.x, abs_center.y);
		shape = step(box, 0.25);
		shape_color = vec4(1.0, 0.0, 1.0, 1.0);
	} else if (current_wave == 2) {
		// Sawtooth: 锐利三角形 (橙色)
		float tri = max(abs_center.x * 0.866025 + pixel_uv.y * 0.5, -pixel_uv.y);
		shape = step(tri, 0.2);
		shape_color = vec4(1.0, 0.5, 0.0, 1.0);
	} else if (current_wave == 3) {
		// Triangle: 细长菱形 (黄色)
		float rhombus = abs_center.x + abs_center.y;
		shape = step(rhombus, 0.3);
		shape_color = vec4(1.0, 1.0, 0.0, 1.0);
	}
	
	// 3. 故障效果 (Glitch)
	float glitch = 0.0;
	if (is_morphing || hash(vec2(t, pixel_uv.y)) > 0.95) {
		glitch = step(0.8, hash(pixel_uv + t));
		// 错位
		shape *= step(0.5, hash(pixel_uv * 10.0 - t));
	}
	
	// 4. 扫描线
	float scanline = sin(UV.y * 100.0 - t * 20.0) * 0.5 + 0.5;
	
	float alpha = (shape * 0.8 + glitch * 0.5) * (0.7 + scanline * 0.3) * intensity * env;
	
	// RGB 分离 (色差)
	vec4 final_color = shape_color;
	if (glitch > 0.0) {
		final_color.r = shape_color.g;
		final_color.g = shape_color.b;
		final_color.b = shape_color.r;
	}
	
	final_color.a = clamp(alpha, 0.0, 1.0);
	COLOR = final_color;
}
