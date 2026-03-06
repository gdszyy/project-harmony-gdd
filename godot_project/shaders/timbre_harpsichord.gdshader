shader_type canvas_item;

// 羽管键琴 (Harpsichord) 专属特效 Shader
// 核心机制：对位交织（镜像位置生成对位弹体）
// 视觉特征：金属光泽 + 装饰音符粒子 + 机械齿轮

uniform vec4 base_color : source_color = vec4(0.8, 0.7, 0.3, 1.0); // 黄铜色
uniform float intensity : hint_range(0.0, 2.0) = 1.0;
uniform bool is_counterpoint = false; // 是否为对位（镜像）弹体

// ADSR 包络参数
uniform float attack_time = 0.03;
uniform float decay_time = 0.15;
uniform float sustain_level = 0.45;
uniform float release_time = 0.0;
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
	
	// 对位弹体旋转方向相反
	float rot_dir = is_counterpoint ? -1.0 : 1.0;
	
	// 1. 外部大齿轮
	float gear_teeth = 12.0;
	float gear_outer = sin(angle * gear_teeth + t * 3.0 * rot_dir) * 0.05 + 0.4;
	float gear_inner = 0.3;
	float gear_mask = smoothstep(gear_outer + 0.02, gear_outer, dist) * smoothstep(gear_inner - 0.02, gear_inner, dist);
	
	// 2. 内部小齿轮
	float small_teeth = 8.0;
	float small_outer = sin(angle * small_teeth - t * 5.0 * rot_dir) * 0.03 + 0.2;
	float small_inner = 0.1;
	float small_mask = smoothstep(small_outer + 0.02, small_outer, dist) * smoothstep(small_inner - 0.02, small_inner, dist);
	
	// 3. 核心轴承
	float core = smoothstep(0.05, 0.0, dist);
	
	// 4. 金属反光 (高光)
	float highlight = sin(angle * 2.0 + t * 2.0) * 0.5 + 0.5;
	highlight *= smoothstep(0.4, 0.0, dist);
	
	float alpha = (gear_mask * 0.8 + small_mask * 0.9 + core + highlight * 0.5) * intensity * env;
	
	vec4 final_color = base_color;
	
	// 对位弹体视觉差异：半透明、幽灵化、偏冷银色
	if (is_counterpoint) {
		final_color = mix(base_color, vec4(0.7, 0.8, 0.9, 1.0), 0.6); // 冷银色
		alpha *= 0.4; // 半透明
	}
	
	final_color.a = clamp(alpha, 0.0, 1.0);
	COLOR = final_color;
}
