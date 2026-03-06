shader_type canvas_item;

// 萨克斯 (Saxophone) 专属特效 Shader
// 核心机制：摇摆攻击（反拍强化，S型弹道）
// 视觉特征：霓虹流光 + 烟雾扭曲 + 金色音符

uniform vec4 base_color : source_color = vec4(1.0, 0.8, 0.2, 1.0); // 金色
uniform float intensity : hint_range(0.0, 2.0) = 1.0;
uniform bool is_offbeat = false; // 是否为反拍强化状态
uniform bool is_improvising = false; // 是否处于即兴独奏状态

// ADSR 包络参数
uniform float attack_time = 0.06;
uniform float decay_time = 0.10;
uniform float sustain_level = 0.70;
uniform float release_time = 0.12;
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
	float t = TIME;
	float env = get_adsr_envelope(time_alive);
	
	// 1. 烟雾扭曲背景
	vec2 distorted_uv = center + vec2(sin(center.y * 12.0 + t * 4.0), cos(center.x * 12.0 + t * 3.0)) * 0.08;
	float smoke_dist = length(distorted_uv);
	float smoke = smoothstep(0.4, 0.1, smoke_dist);
	
	// 2. 核心金属光泽 (金色音符)
	float core = smoothstep(0.2, 0.0, dist);
	float metal_shine = sin(dist * 20.0 - t * 5.0) * 0.5 + 0.5;
	core *= (0.5 + metal_shine * 0.5);
	
	// 3. 霓虹流光边缘 (反拍强化时出现)
	float neon = 0.0;
	vec4 neon_color = vec4(0.6, 0.2, 1.0, 1.0); // 蓝紫色霓虹
	
	if (is_offbeat || is_improvising) {
		float neon_edge = smoothstep(0.35, 0.25, smoke_dist) * smoothstep(0.15, 0.25, smoke_dist);
		float neon_pulse = sin(t * 10.0) * 0.5 + 0.5;
		neon = neon_edge * (0.5 + neon_pulse * 0.5);
		
		if (is_improvising) {
			// 即兴独奏时，整体偏向高亮蓝紫
			neon *= 1.5;
			core *= 0.5; // 核心变暗，突出霓虹
		}
	}
	
	float alpha = (smoke * 0.3 + core * 0.8 + neon * 1.2) * intensity * env;
	
	// 颜色混合
	vec4 final_color = base_color;
	if (is_offbeat || is_improvising) {
		final_color = mix(base_color, neon_color, neon);
		if (is_improvising) {
			final_color = mix(final_color, vec4(0.8, 0.4, 1.0, 1.0), 0.6);
		}
	}
	
	final_color.a = clamp(alpha, 0.0, 1.0);
	COLOR = final_color;
}
