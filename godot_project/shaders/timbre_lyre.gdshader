shader_type canvas_item;

// 里拉琴 (Lyre) 专属特效 Shader
// 核心机制：泛音共鸣（基于数学比例的伤害加成）
// 视觉特征：水墨扩散 + 金色光点 + 弦振波形

uniform vec4 base_color : source_color = vec4(1.0, 0.84, 0.0, 1.0); // 圣光金
uniform float intensity : hint_range(0.0, 2.0) = 1.0;
uniform float resonance_ratio : hint_range(0.0, 1.0) = 0.0; // 接近简单整数比时的共鸣强度

// ADSR 包络参数
uniform float attack_time = 0.08;
uniform float decay_time = 0.20;
uniform float sustain_level = 0.60;
uniform float release_time = 0.15;
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

void fragment() {
	vec2 center = UV - 0.5;
	float dist = length(center);
	float angle = atan(center.y, center.x);
	float t = TIME;
	float env = get_adsr_envelope(time_alive);
	
	// 1. 弦振波形 (正弦波环绕)
	float wave_freq = 6.0;
	float wave_amp = 0.05 + resonance_ratio * 0.1; // 共鸣时振幅增大
	float wave = sin(angle * wave_freq + t * 5.0) * wave_amp;
	float wave_ring = smoothstep(0.02, 0.0, abs(dist - (0.3 + wave)));
	
	// 2. 水墨扩散波纹
	float ripple = sin(dist * 40.0 - t * 10.0) * 0.5 + 0.5;
	ripple *= smoothstep(0.4, 0.1, dist);
	
	// 3. 金色光珠核心
	float core = 0.02 / (dist + 0.01);
	core = min(core, 1.5);
	
	// 综合混合
	float alpha = (wave_ring * 0.8 + ripple * 0.3 + core * 0.6) * intensity * env;
	
	// 共鸣时亮度激增
	vec4 final_color = base_color * (1.0 + resonance_ratio * 1.5);
	final_color.a = clamp(alpha, 0.0, 1.0);
	
	COLOR = final_color;
}
