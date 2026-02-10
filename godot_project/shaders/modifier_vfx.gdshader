shader_type canvas_item;

// 修饰符视觉增强 Shader
// 为弹体附着修饰符特效：穿透刀锋环、追踪准星、分裂电弧、回响残影、散射扇形
// 通过 modifier_type 切换不同的视觉效果

uniform int modifier_type : hint_range(0, 4) = 0;
// 0 = PIERCE (穿透), 1 = HOMING (追踪), 2 = SPLIT (分裂), 3 = ECHO (回响), 4 = SCATTER (散射)

uniform vec4 modifier_color : source_color = vec4(0.0, 1.0, 0.8, 1.0);
uniform float intensity : hint_range(0.0, 2.0) = 1.0;
uniform float time_offset : hint_range(0.0, 100.0) = 0.0;

// 穿透：旋转刀锋光环
vec4 pierce_effect(vec2 uv, float t) {
	vec2 center = uv - 0.5;
	float dist = length(center);
	float angle = atan(center.y, center.x);
	
	// 旋转刀锋
	float blade_count = 4.0;
	float blade = abs(sin(angle * blade_count + t * 5.0));
	blade = smoothstep(0.6, 0.9, blade);
	
	// 外环
	float ring = smoothstep(0.35, 0.38, dist) * smoothstep(0.42, 0.38, dist);
	
	// 锐利指示线
	float line_mask = smoothstep(0.02, 0.0, abs(center.y)) * step(0.0, center.x);
	line_mask *= smoothstep(0.5, 0.3, dist);
	
	float alpha = (ring * blade + line_mask * 0.6) * intensity;
	vec4 col = modifier_color;
	col.rgb *= 1.0 + blade * 0.5;
	col.a = clamp(alpha, 0.0, 1.0);
	return col;
}

// 追踪：动态准星
vec4 homing_effect(vec2 uv, float t) {
	vec2 center = uv - 0.5;
	float dist = length(center);
	float angle = atan(center.y, center.x);
	
	// 旋转准星环
	float ring = smoothstep(0.28, 0.30, dist) * smoothstep(0.34, 0.30, dist);
	
	// 十字准星线
	float cross_h = smoothstep(0.015, 0.0, abs(center.y)) * step(0.15, abs(center.x)) * step(abs(center.x), 0.4);
	float cross_v = smoothstep(0.015, 0.0, abs(center.x)) * step(0.15, abs(center.y)) * step(abs(center.y), 0.4);
	
	// 旋转三角标记
	float tri_angle = angle + t * 3.0;
	float tri_count = 3.0;
	float tri = abs(sin(tri_angle * tri_count));
	tri = smoothstep(0.85, 1.0, tri);
	float tri_ring = smoothstep(0.20, 0.22, dist) * smoothstep(0.26, 0.22, dist);
	
	float alpha = (ring + cross_h + cross_v + tri * tri_ring) * intensity;
	vec4 col = modifier_color;
	col.a = clamp(alpha, 0.0, 1.0);
	return col;
}

// 分裂：三核心电弧
vec4 split_effect(vec2 uv, float t) {
	vec2 center = uv - 0.5;
	
	// 三个不稳定核心
	vec2 core1 = vec2(sin(t * 4.0) * 0.1, cos(t * 3.0) * 0.1);
	vec2 core2 = vec2(sin(t * 4.0 + 2.094) * 0.1, cos(t * 3.0 + 2.094) * 0.1);
	vec2 core3 = vec2(sin(t * 4.0 + 4.189) * 0.1, cos(t * 3.0 + 4.189) * 0.1);
	
	float d1 = length(center - core1);
	float d2 = length(center - core2);
	float d3 = length(center - core3);
	
	float glow1 = 0.02 / (d1 + 0.01);
	float glow2 = 0.02 / (d2 + 0.01);
	float glow3 = 0.02 / (d3 + 0.01);
	
	// 核心间电弧
	float arc12 = smoothstep(0.02, 0.0, abs(d1 - d2)) * step(d1, 0.2) * step(d2, 0.2);
	float arc23 = smoothstep(0.02, 0.0, abs(d2 - d3)) * step(d2, 0.2) * step(d3, 0.2);
	float arc13 = smoothstep(0.02, 0.0, abs(d1 - d3)) * step(d1, 0.2) * step(d3, 0.2);
	
	float alpha = (glow1 + glow2 + glow3 + (arc12 + arc23 + arc13) * 0.3) * intensity;
	vec4 col = modifier_color;
	col.a = clamp(alpha, 0.0, 1.0);
	return col;
}

// 回响：残影延迟效果
vec4 echo_effect(vec2 uv, float t) {
	vec2 center = uv - 0.5;
	float dist = length(center);
	
	// 主体光环
	float main_ring = smoothstep(0.18, 0.20, dist) * smoothstep(0.24, 0.20, dist);
	
	// 残影（向后偏移的淡化副本）
	vec2 echo1_center = center + vec2(0.08, 0.0);
	float echo1_dist = length(echo1_center);
	float echo1 = smoothstep(0.18, 0.20, echo1_dist) * smoothstep(0.24, 0.20, echo1_dist) * 0.5;
	
	vec2 echo2_center = center + vec2(0.16, 0.0);
	float echo2_dist = length(echo2_center);
	float echo2 = smoothstep(0.18, 0.20, echo2_dist) * smoothstep(0.24, 0.20, echo2_dist) * 0.25;
	
	// 拖尾光带
	float trail = smoothstep(0.03, 0.0, abs(center.y)) * step(0.0, center.x) * step(center.x, 0.3);
	trail *= smoothstep(0.3, 0.0, center.x) * 0.4;
	
	float pulse = sin(t * 4.0) * 0.3 + 0.7;
	float alpha = (main_ring * pulse + echo1 + echo2 + trail) * intensity;
	vec4 col = modifier_color;
	col.a = clamp(alpha, 0.0, 1.0);
	return col;
}

// 散射：扇形弹道预示
vec4 scatter_effect(vec2 uv, float t) {
	vec2 center = uv - 0.5;
	float dist = length(center);
	float angle = atan(center.y, center.x);
	
	// 扇形区域（前方 ±30度）
	float fan_angle = 0.524; // 30 degrees
	float fan = step(abs(angle), fan_angle) * step(0.0, center.x);
	float fan_edge = smoothstep(fan_angle + 0.05, fan_angle, abs(angle)) * step(0.0, center.x);
	
	// 扇形内的射线
	float ray_count = 5.0;
	float rays = abs(sin(angle * ray_count));
	rays = smoothstep(0.9, 1.0, rays) * fan;
	
	// 扩散动画
	float expand = fract(t * 0.8);
	float expand_ring = smoothstep(expand * 0.4, expand * 0.4 + 0.02, dist) * 
						smoothstep(expand * 0.4 + 0.04, expand * 0.4 + 0.02, dist);
	expand_ring *= fan_edge;
	
	float alpha = (fan_edge * 0.15 + rays * 0.4 + expand_ring * 0.6) * intensity;
	vec4 col = modifier_color;
	col.a = clamp(alpha, 0.0, 1.0);
	return col;
}

void fragment() {
	float t = TIME + time_offset;
	
	vec4 result;
	if (modifier_type == 0) {
		result = pierce_effect(UV, t);
	} else if (modifier_type == 1) {
		result = homing_effect(UV, t);
	} else if (modifier_type == 2) {
		result = split_effect(UV, t);
	} else if (modifier_type == 3) {
		result = echo_effect(UV, t);
	} else {
		result = scatter_effect(UV, t);
	}
	
	COLOR = result;
}
