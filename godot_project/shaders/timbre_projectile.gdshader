shader_type canvas_item;

// 音色系别弹体质感 Shader（层级三：攻击质感层）
// 为弹体叠加音色系别的独特视觉修饰
// timbre_type: 0=无, 1=里拉琴, 2=管风琴, 3=羽管键琴, 4=钢琴, 5=管弦全奏, 6=萨克斯, 7=合成主脑

uniform int timbre_type : hint_range(0, 7) = 0;
uniform vec4 timbre_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float intensity : hint_range(0.0, 2.0) = 1.0;
uniform float beat_phase : hint_range(0.0, 1.0) = 0.0;

// ADSR 包络参数
uniform float attack_time = 0.1;
uniform float decay_time = 0.1;
uniform float sustain_level = 0.8;
uniform float release_time = 0.2;
uniform float time_alive = 0.0; // 弹体存活时间

// 计算 ADSR 包络值
float get_adsr_envelope(float t) {
	if (t < attack_time) {
		return t / attack_time;
	} else if (t < attack_time + decay_time) {
		return mix(1.0, sustain_level, (t - attack_time) / decay_time);
	} else {
		return sustain_level;
	}
}

// 1. 里拉琴 (Lyre)：水墨扩散 + 金色光点 (泛音共鸣)
vec4 lyre_effect(vec2 uv, float t, float env) {
	vec2 center = uv - 0.5;
	float dist = length(center);
	
	// 同心圆波纹（泛音波纹）
	float ripple1 = sin(dist * 30.0 - t * 8.0) * 0.5 + 0.5;
	ripple1 *= smoothstep(0.4, 0.2, dist);
	
	float ripple2 = sin(dist * 20.0 - t * 6.0 + 1.0) * 0.5 + 0.5;
	ripple2 *= smoothstep(0.35, 0.15, dist);
	
	// 金色光珠核心
	float core_glow = 0.03 / (dist + 0.02);
	core_glow = min(core_glow, 2.0);
	
	float alpha = (ripple1 * 0.3 + ripple2 * 0.2 + core_glow * 0.4) * intensity * env;
	vec4 col = timbre_color;
	col.a = clamp(alpha, 0.0, 1.0);
	return col;
}

// 2. 管风琴 (Organ)：圣光柱 + 彩色玻璃折射 (和声层叠)
vec4 organ_effect(vec2 uv, float t, float env) {
	vec2 center = uv - 0.5;
	float dist = length(center);
	
	// 多层叠加的厚重光环
	float ring1 = smoothstep(0.3, 0.25, dist) * smoothstep(0.2, 0.25, dist);
	float ring2 = smoothstep(0.2, 0.15, dist) * smoothstep(0.1, 0.15, dist);
	float ring3 = smoothstep(0.1, 0.05, dist) * smoothstep(0.0, 0.05, dist);
	
	// 哥特式花纹模拟 (径向波浪)
	float angle = atan(center.y, center.x);
	float gothic = sin(angle * 8.0 + t * 2.0) * 0.5 + 0.5;
	
	float alpha = (ring1 * 0.5 + ring2 * 0.7 + ring3 + gothic * 0.3 * ring1) * intensity * env;
	vec4 col = mix(timbre_color, vec4(1.0, 0.8, 0.2, 1.0), ring3); // 中心偏琥珀色
	col.a = clamp(alpha, 0.0, 1.0);
	return col;
}

// 3. 羽管键琴 (Harpsichord)：金属光泽 + 装饰音符粒子 (对位交织)
vec4 harpsichord_effect(vec2 uv, float t, float env) {
	vec2 center = uv - 0.5;
	float dist = length(center);
	float angle = atan(center.y, center.x);
	
	// 机械齿轮旋转
	float gear = sin(angle * 12.0 - t * 5.0) * 0.5 + 0.5;
	float gear_edge = smoothstep(0.35, 0.3, dist) * smoothstep(0.25, 0.3, dist);
	
	// 内部发条
	float spring = sin(dist * 40.0 + angle * 2.0 - t * 3.0) * 0.5 + 0.5;
	spring *= smoothstep(0.25, 0.0, dist);
	
	float alpha = (gear * gear_edge * 0.8 + spring * 0.5) * intensity * env;
	vec4 col = mix(timbre_color, vec4(0.8, 0.7, 0.3, 1.0), gear_edge); // 黄铜色
	col.a = clamp(alpha, 0.0, 1.0);
	return col;
}

// 4. 钢琴 (Fortepiano)：水晶折射 + 黑白键闪烁 (力度动态)
vec4 fortepiano_effect(vec2 uv, float t, float env) {
	vec2 center = uv - 0.5;
	float dist = length(center);
	float angle = atan(center.y, center.x);
	
	// 黑白键交替 (径向条纹)
	float keys = step(0.0, sin(angle * 10.0 + t));
	
	// 晶体光球
	float crystal = smoothstep(0.4, 0.0, dist);
	float facet = abs(sin(angle * 4.0) * cos(dist * 10.0));
	
	// 强弱拍脉冲
	float beat_pulse = sin(beat_phase * 6.28318) * 0.5 + 0.5;
	
	float alpha = (crystal * 0.5 + facet * 0.3 + keys * 0.2 * crystal) * (1.0 + beat_pulse * 0.5) * intensity * env;
	vec4 col = mix(vec4(1.0), vec4(0.1, 0.1, 0.1, 1.0), keys * 0.5); // 黑白交替
	col *= timbre_color;
	col.a = clamp(alpha, 0.0, 1.0);
	return col;
}

// 5. 管弦全奏 (Tutti)：火焰渐变 + 情感强度驱动 (情感爆发)
vec4 tutti_effect(vec2 uv, float t, float env) {
	vec2 center = uv - 0.5;
	float dist = length(center);
	
	// 混沌能量团 (噪声模拟)
	float noise1 = sin(center.x * 15.0 + t * 4.0) * cos(center.y * 15.0 - t * 3.0);
	float noise2 = sin(center.x * 25.0 - t * 5.0) * cos(center.y * 25.0 + t * 6.0);
	float chaos = (noise1 + noise2) * 0.25 + 0.5;
	
	// 核心高亮
	float core = smoothstep(0.3, 0.0, dist);
	
	float alpha = (chaos * 0.6 + core * 0.8) * intensity * env;
	
	// 颜色随时间/强度渐变 (冷蓝到炽红)
	vec4 color_cold = vec4(0.2, 0.5, 1.0, 1.0);
	vec4 color_hot = vec4(1.0, 0.2, 0.1, 1.0);
	float heat = sin(t * 2.0) * 0.5 + 0.5; // 简化版，实际应由外部传入情感强度
	
	vec4 col = mix(color_cold, color_hot, heat) * timbre_color;
	col.a = clamp(alpha, 0.0, 1.0);
	return col;
}

// 6. 萨克斯 (Saxophone)：霓虹流光 + 烟雾扭曲 (摇摆攻击)
vec4 saxophone_effect(vec2 uv, float t, float env) {
	vec2 center = uv - 0.5;
	float dist = length(center);
	
	// 烟雾扭曲
	vec2 distorted_uv = center + vec2(sin(center.y * 10.0 + t * 3.0), cos(center.x * 10.0 + t * 2.0)) * 0.05;
	float smoke_dist = length(distorted_uv);
	float smoke = smoothstep(0.4, 0.1, smoke_dist);
	
	// 霓虹流光边缘
	float neon_edge = smoothstep(0.35, 0.3, smoke_dist) * smoothstep(0.25, 0.3, smoke_dist);
	
	float alpha = (smoke * 0.4 + neon_edge * 0.8) * intensity * env;
	vec4 col = mix(timbre_color, vec4(0.6, 0.2, 1.0, 1.0), neon_edge); // 蓝紫色霓虹
	col.a = clamp(alpha, 0.0, 1.0);
	return col;
}

// 7. 合成主脑 (Synthesizer)：故障像素 + 波形可视化 (波形变换)
vec4 synthesizer_effect(vec2 uv, float t, float env) {
	vec2 center = uv - 0.5;
	
	// 像素化/故障效果
	float pixel_size = 0.05;
	vec2 pixel_uv = floor(center / pixel_size) * pixel_size;
	float dist = length(pixel_uv);
	
	// 扫描线
	float scanline = sin(uv.y * 50.0 - t * 10.0) * 0.5 + 0.5;
	
	// 基础几何体 (方块)
	vec2 abs_center = abs(pixel_uv);
	float box = max(abs_center.x, abs_center.y);
	float shape = step(box, 0.3);
	
	// 随机故障块
	float glitch = step(0.9, fract(sin(dot(pixel_uv, vec2(12.9898, 78.233)) + t) * 43758.5453));
	
	float alpha = (shape * 0.6 + glitch * 0.4) * (0.8 + scanline * 0.2) * intensity * env;
	vec4 col = timbre_color;
	// RGB 分离
	if (glitch > 0.0) {
		col.r *= 1.5;
		col.b *= 0.5;
	}
	col.a = clamp(alpha, 0.0, 1.0);
	return col;
}

void fragment() {
	float t = TIME;
	float env = get_adsr_envelope(time_alive);
	
	vec4 result = vec4(0.0);
	if (timbre_type == 1) {
		result = lyre_effect(UV, t, env);
	} else if (timbre_type == 2) {
		result = organ_effect(UV, t, env);
	} else if (timbre_type == 3) {
		result = harpsichord_effect(UV, t, env);
	} else if (timbre_type == 4) {
		result = fortepiano_effect(UV, t, env);
	} else if (timbre_type == 5) {
		result = tutti_effect(UV, t, env);
	} else if (timbre_type == 6) {
		result = saxophone_effect(UV, t, env);
	} else if (timbre_type == 7) {
		result = synthesizer_effect(UV, t, env);
	}
	
	COLOR = result;
}
