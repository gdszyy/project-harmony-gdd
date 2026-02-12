// energy_ring.gdshader
// 相位能量环 Shader — 流动光粒效果
// 以自定义 _draw() 绘制的圆弧为基础，叠加粒子流动效果
// 关联文档：Docs/UI_Design_Module6_ResonanceSlicing.md §4
shader_type canvas_item;

// 能量比例 (0.0 ~ 1.0)
uniform float energy_ratio : hint_range(0.0, 1.0) = 1.0;
// 粒子流动速度
uniform float particle_speed : hint_range(0.1, 2.0) = 1.0;
// 粒子颜色
uniform vec4 particle_color : source_color = vec4(0.918, 0.902, 1.0, 1.0);
// 时间
uniform float time : hint_range(0.0, 1000.0) = 0.0;
// 节拍能量
uniform float beat_energy : hint_range(0.0, 2.0) = 0.0;
// 圆环参数
uniform float ring_inner_radius : hint_range(0.0, 0.5) = 0.38;
uniform float ring_outer_radius : hint_range(0.0, 0.5) = 0.44;
// 是否处于危险状态（闪烁）
uniform float danger_flash : hint_range(0.0, 1.0) = 0.0;
// 裂纹强度（能量极低时）
uniform float crack_intensity : hint_range(0.0, 1.0) = 0.0;

// 伪随机
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// 噪声函数
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 uv = UV;
	vec2 center = vec2(0.5, 0.5);
	vec2 d = uv - center;
	float dist = length(d);
	float angle = atan(d.y, d.x);

	// 圆环遮罩
	float ring_mid = (ring_inner_radius + ring_outer_radius) * 0.5;
	float ring_width = (ring_outer_radius - ring_inner_radius) * 0.5;
	float ring_mask = 1.0 - smoothstep(ring_width - 0.003, ring_width + 0.003, abs(dist - ring_mid));

	if (ring_mask < 0.01) {
		COLOR = vec4(0.0);
		return;
	}

	// 能量填充角度范围 (从底部开始，顺时针)
	float fill_angle = energy_ratio * 6.28318530;
	// 将角度映射到 [0, 2PI]，从底部(PI/2)开始
	float mapped_angle = mod(angle - 1.5707963 + 6.28318530, 6.28318530);
	float fill_mask = step(mapped_angle, fill_angle);

	// 流动光粒效果
	float flow_angle = angle + time * particle_speed;
	float particle_pattern = 0.0;

	// 多层粒子
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float freq = 8.0 + fi * 5.0;
		float speed_offset = fi * 0.3;
		float p = sin(flow_angle * freq + time * (particle_speed + speed_offset) * 3.0);
		p *= sin(flow_angle * (freq * 0.7) - time * (particle_speed + speed_offset) * 2.0);
		p = max(0.0, p);
		p *= noise(vec2(flow_angle * 2.0 + fi, time * 0.5));
		particle_pattern += p * (1.0 - fi * 0.25);
	}
	particle_pattern = clamp(particle_pattern, 0.0, 1.0);

	// 密度随能量变化
	float density = mix(0.1, 1.0, energy_ratio);
	particle_pattern *= density;

	// 节拍脉冲
	float pulse = 1.0 + beat_energy * 0.3;

	// 危险闪烁
	float flash = 1.0;
	if (danger_flash > 0.0) {
		flash = 0.5 + 0.5 * sin(time * 10.0) * danger_flash;
	}

	// 裂纹效果
	float crack = 0.0;
	if (crack_intensity > 0.0) {
		float crack_noise = noise(vec2(angle * 10.0, dist * 50.0 + time * 0.5));
		crack = step(0.85 - crack_intensity * 0.3, crack_noise) * crack_intensity;
	}

	// 最终颜色
	vec4 final_color = particle_color;
	float alpha = ring_mask * fill_mask * (0.3 + particle_pattern * 0.7) * pulse * flash;

	// 边缘辉光
	float edge_glow = smoothstep(ring_width, ring_width * 0.5, abs(dist - ring_mid));
	alpha += edge_glow * 0.15 * fill_mask * energy_ratio;

	// 裂纹叠加（深色线条）
	if (crack > 0.0) {
		final_color.rgb = mix(final_color.rgb, vec3(0.1, 0.0, 0.0), crack * 0.8);
	}

	// 刻度标记（25%, 50%, 75%, 100%）
	float tick_alpha = 0.0;
	for (int t = 1; t <= 4; t++) {
		float tick_angle = float(t) * 1.5707963;  // PI/2 increments
		float tick_diff = abs(mod(mapped_angle - tick_angle + 6.28318530, 6.28318530));
		tick_diff = min(tick_diff, 6.28318530 - tick_diff);
		tick_alpha += smoothstep(0.03, 0.01, tick_diff) * 0.3;
	}

	final_color.a = clamp(alpha + tick_alpha * ring_mask, 0.0, 1.0);
	COLOR = final_color;
}
