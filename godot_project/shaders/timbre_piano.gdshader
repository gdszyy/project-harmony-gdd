shader_type canvas_item;

// 钢琴 (Fortepiano) 专属特效 Shader
// 核心机制：力度动态（强弱拍伤害差异化）
// 视觉特征：水晶折射 + 黑白键闪烁

uniform vec4 base_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float intensity : hint_range(0.0, 2.0) = 1.0;
uniform int velocity_state : hint_range(0, 2) = 1; // 0=piano(弱), 1=mezzo(中), 2=forte(强)

// ADSR 包络参数
uniform float attack_time = 0.02;
uniform float decay_time = 0.10;
uniform float sustain_level = 0.80;
uniform float release_time = 0.08;
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
	
	// 1. 黑白琴键交替 (径向条纹)
	float key_count = 12.0;
	float keys = step(0.0, sin(angle * key_count + t * 2.0));
	
	// 2. 晶体光球 (多边形切割感)
	float facet = abs(sin(angle * 6.0) * cos(dist * 15.0));
	float crystal = smoothstep(0.4, 0.0, dist);
	
	float alpha = 0.0;
	vec4 final_color = base_color;
	
	// 根据力度状态调整视觉
	if (velocity_state == 2) {
		// Forte (强)：高亮、星芒、冲击波
		float star = pow(abs(cos(angle * 4.0)), 10.0) * smoothstep(0.5, 0.0, dist);
		float shockwave = sin(dist * 30.0 - t * 15.0) * 0.5 + 0.5;
		shockwave *= smoothstep(0.4, 0.2, dist);
		
		alpha = (crystal * 0.8 + facet * 0.5 + keys * 0.3 + star * 1.5 + shockwave * 0.6) * intensity * env;
		final_color = mix(base_color, vec4(1.0, 0.9, 0.5, 1.0), 0.5); // 偏金黄色
	} else if (velocity_state == 0) {
		// Piano (弱)：半透明、柔和、气泡感
		float bubble = smoothstep(0.3, 0.25, dist) * smoothstep(0.2, 0.25, dist);
		alpha = (bubble * 0.8 + crystal * 0.3 + keys * 0.1) * intensity * env * 0.6;
		final_color = mix(base_color, vec4(0.6, 0.8, 1.0, 1.0), 0.5); // 偏冷蓝色
	} else {
		// Mezzo (中)：标准状态
		alpha = (crystal * 0.6 + facet * 0.4 + keys * 0.2) * intensity * env;
	}
	
	// 黑白交替颜色混合
	vec4 key_color = mix(vec4(1.0), vec4(0.1, 0.1, 0.1, 1.0), keys * 0.6);
	final_color *= key_color;
	
	final_color.a = clamp(alpha, 0.0, 1.0);
	COLOR = final_color;
}
