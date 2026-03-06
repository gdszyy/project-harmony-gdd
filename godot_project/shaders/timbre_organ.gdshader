shader_type canvas_item;

// 管风琴 (Organ) 专属特效 Shader
// 核心机制：和声层叠（多声部叠加攻击）
// 视觉特征：圣光柱 + 彩色玻璃折射 + 多层光环

uniform vec4 base_color : source_color = vec4(0.8, 0.2, 0.3, 1.0); // 基础音符色
uniform float intensity : hint_range(0.0, 2.0) = 1.0;
uniform int voice_layers : hint_range(0, 4) = 0; // 当前声部层数

// ADSR 包络参数
uniform float attack_time = 0.15;
uniform float decay_time = 0.0;
uniform float sustain_level = 0.90;
uniform float release_time = 0.40;
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
	
	float alpha = 0.0;
	vec4 final_color = base_color;
	
	// 基础核心
	float core = smoothstep(0.15, 0.0, dist);
	alpha += core * 0.5;
	
	// 根据声部层数叠加光环
	if (voice_layers >= 1) {
		float ring1 = smoothstep(0.25, 0.2, dist) * smoothstep(0.15, 0.2, dist);
		float gothic1 = sin(angle * 6.0 + t) * 0.5 + 0.5;
		alpha += ring1 * (0.5 + gothic1 * 0.5);
	}
	
	if (voice_layers >= 2) {
		float ring2 = smoothstep(0.35, 0.3, dist) * smoothstep(0.25, 0.3, dist);
		float gothic2 = sin(angle * 12.0 - t * 1.5) * 0.5 + 0.5;
		alpha += ring2 * (0.4 + gothic2 * 0.6);
		final_color = mix(final_color, vec4(1.0, 0.5, 0.0, 1.0), 0.3); // 叠加琥珀色
	}
	
	if (voice_layers >= 3) {
		float ring3 = smoothstep(0.45, 0.4, dist) * smoothstep(0.35, 0.4, dist);
		float gothic3 = sin(angle * 18.0 + t * 2.0) * 0.5 + 0.5;
		alpha += ring3 * (0.3 + gothic3 * 0.7);
		final_color = mix(final_color, vec4(1.0, 0.2, 0.0, 1.0), 0.5); // 叠加深红色
	}
	
	if (voice_layers >= 4) {
		// 满层：圣咏之火
		float fire = sin(dist * 20.0 - t * 10.0 + angle * 4.0) * 0.5 + 0.5;
		fire *= smoothstep(0.2, 0.0, dist);
		alpha += fire * 0.8;
		final_color = mix(final_color, vec4(1.0, 0.9, 0.5, 1.0), fire); // 中心圣光
	}
	
	// 彩色玻璃折射效果 (微小的色差)
	float glass = sin(center.x * 30.0) * cos(center.y * 30.0) * 0.1;
	
	alpha = (alpha + glass) * intensity * env;
	final_color.a = clamp(alpha, 0.0, 1.0);
	
	COLOR = final_color;
}
