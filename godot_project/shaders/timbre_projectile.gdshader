shader_type canvas_item;

// 音色系别弹体质感 Shader（层级三：攻击质感层）
// 为弹体叠加音色系别的独特视觉修饰
// timbre_type: 0=无, 1=弹拨(水墨/金珠), 2=拉弦(缠绕丝线), 3=吹奏(气流), 4=打击(坚实)

uniform int timbre_type : hint_range(0, 4) = 0;
uniform vec4 timbre_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float intensity : hint_range(0.0, 2.0) = 1.0;
uniform float beat_phase : hint_range(0.0, 1.0) = 0.0;

// 弹拨系：水墨波纹
vec4 plucked_effect(vec2 uv, float t) {
	vec2 center = uv - 0.5;
	float dist = length(center);
	
	// 同心圆波纹（墨滴在水中扩散）
	float ripple1 = sin(dist * 30.0 - t * 8.0) * 0.5 + 0.5;
	ripple1 *= smoothstep(0.4, 0.2, dist);
	
	float ripple2 = sin(dist * 20.0 - t * 6.0 + 1.0) * 0.5 + 0.5;
	ripple2 *= smoothstep(0.35, 0.15, dist);
	
	// 金色光珠核心
	float core_glow = 0.03 / (dist + 0.02);
	core_glow = min(core_glow, 2.0);
	
	float alpha = (ripple1 * 0.3 + ripple2 * 0.2 + core_glow * 0.4) * intensity;
	vec4 col = timbre_color;
	col.a = clamp(alpha, 0.0, 1.0);
	return col;
}

// 拉弦系：缠绕能量丝线
vec4 bowed_effect(vec2 uv, float t) {
	vec2 center = uv - 0.5;
	float dist = length(center);
	float angle = atan(center.y, center.x);
	
	// 两股缠绕丝线
	float strand1 = sin(angle * 2.0 + dist * 15.0 + t * 3.0);
	strand1 = smoothstep(0.7, 1.0, abs(strand1));
	strand1 *= smoothstep(0.4, 0.1, dist);
	
	float strand2 = sin(angle * 2.0 + dist * 15.0 + t * 3.0 + 3.14159);
	strand2 = smoothstep(0.7, 1.0, abs(strand2));
	strand2 *= smoothstep(0.4, 0.1, dist);
	
	// 共振标记光晕
	float glow = smoothstep(0.25, 0.15, dist) * 0.3;
	
	float alpha = (strand1 + strand2 + glow) * intensity;
	vec4 col = timbre_color;
	col.a = clamp(alpha, 0.0, 1.0);
	return col;
}

// 吹奏系：半透明气流
vec4 wind_effect(vec2 uv, float t) {
	vec2 center = uv - 0.5;
	float dist = length(center);
	
	// 气流方向（从左到右）
	float flow = sin(center.x * 10.0 + t * 5.0 + center.y * 3.0) * 0.5 + 0.5;
	flow *= smoothstep(0.4, 0.0, dist);
	
	// 前端聚焦（右侧更亮）
	float focus = smoothstep(-0.2, 0.3, center.x) * smoothstep(0.4, 0.1, dist);
	
	// 逐渐变细的尾部
	float tail = smoothstep(0.15, 0.0, abs(center.y) - (0.15 - center.x * 0.2));
	tail *= step(-0.3, center.x);
	
	float alpha = (flow * 0.3 + focus * 0.4 + tail * 0.2) * intensity;
	vec4 col = timbre_color;
	col.a = clamp(alpha, 0.0, 1.0);
	return col;
}

// 打击系：坚实规整
vec4 percussive_effect(vec2 uv, float t) {
	vec2 center = uv - 0.5;
	float dist = length(center);
	
	// 完美方形边框
	vec2 abs_center = abs(center);
	float box = max(abs_center.x, abs_center.y);
	float box_edge = smoothstep(0.22, 0.20, box) * smoothstep(0.18, 0.20, box);
	
	// 强拍脉冲
	float beat_pulse = sin(beat_phase * 6.28318) * 0.5 + 0.5;
	float fill = smoothstep(0.20, 0.0, box) * beat_pulse * 0.3;
	
	// 坚实核心
	float core = smoothstep(0.08, 0.0, dist) * 0.5;
	
	float alpha = (box_edge * 0.6 + fill + core) * intensity;
	vec4 col = timbre_color;
	col.a = clamp(alpha, 0.0, 1.0);
	return col;
}

void fragment() {
	float t = TIME;
	
	vec4 result = vec4(0.0);
	if (timbre_type == 1) {
		result = plucked_effect(UV, t);
	} else if (timbre_type == 2) {
		result = bowed_effect(UV, t);
	} else if (timbre_type == 3) {
		result = wind_effect(UV, t);
	} else if (timbre_type == 4) {
		result = percussive_effect(UV, t);
	}
	
	COLOR = result;
}
