shader_type canvas_item;

// 管弦全奏 (Tutti) 专属特效 Shader
// 核心机制：情感爆发（渐强渐弱的伤害曲线）
// 视觉特征：火焰渐变 + 情感强度驱动 + 混沌能量团

uniform vec4 base_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float intensity : hint_range(0.0, 2.0) = 1.0;
uniform float emotional_intensity : hint_range(0.0, 100.0) = 0.0; // 情感强度 0-100
uniform bool is_climax = false; // 是否处于高潮爆发状态

// ADSR 包络参数
uniform float attack_time = 0.10;
uniform float decay_time = 0.05;
uniform float sustain_level = 0.85;
uniform float release_time = 0.20;
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

// 伪随机噪声
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), f.x),
			   mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 center = UV - 0.5;
	float dist = length(center);
	float t = TIME;
	float env = get_adsr_envelope(time_alive);
	
	// 情感强度归一化
	float emotion_ratio = emotional_intensity / 100.0;
	if (is_climax) emotion_ratio = 1.2; // 高潮时突破上限
	
	// 1. 混沌能量团 (基于噪声)
	// 翻滚速度随情感强度增加
	float speed = 2.0 + emotion_ratio * 8.0;
	vec2 noise_uv = center * (5.0 + emotion_ratio * 5.0) + vec2(t * speed * 0.5, t * speed);
	float n = noise(noise_uv);
	
	// 2. 核心与边缘
	float core = smoothstep(0.4, 0.0, dist);
	float edge = smoothstep(0.4, 0.3, dist) * smoothstep(0.2, 0.3, dist);
	
	// 3. 颜色渐变 (冷蓝 -> 炽红)
	vec4 color_cold = vec4(0.2, 0.5, 1.0, 1.0); // Pianissimo
	vec4 color_hot = vec4(1.0, 0.2, 0.1, 1.0);  // Fortissimo
	vec4 color_climax = vec4(1.0, 0.9, 0.2, 1.0); // 高潮金黄
	
	vec4 current_color = mix(color_cold, color_hot, clamp(emotion_ratio, 0.0, 1.0));
	if (is_climax) {
		// 高潮时闪烁
		float flash = sin(t * 20.0) * 0.5 + 0.5;
		current_color = mix(color_hot, color_climax, flash);
	}
	
	// 综合混合
	float alpha = (n * 0.6 + core * 0.8 + edge * emotion_ratio) * intensity * env;
	
	// 基础颜色混合
	vec4 final_color = current_color * base_color;
	final_color.a = clamp(alpha, 0.0, 1.0);
	
	COLOR = final_color;
}
