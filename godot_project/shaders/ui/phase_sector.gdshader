// phase_sector.gdshader
// 相位扇区渲染 Shader — 辉光、色差、畸变效果
// 用于三相位指示器的每个扇区 (TextureRect + ShaderMaterial)
// 关联文档：Docs/UI_Design_Module6_ResonanceSlicing.md §3
shader_type canvas_item;

// 相位类型：0=Fundamental, 1=Overtone, 2=SubBass
uniform int phase_type : hint_range(0, 2) = 0;
// 激活进度：0.0（未激活）到 1.0（完全激活）
uniform float active_progress : hint_range(0.0, 1.0) = 0.0;
// 主辉光颜色
uniform vec4 glow_color : source_color = vec4(0.616, 0.435, 1.0, 1.0);
// 节拍能量（驱动脉动）
uniform float beat_energy : hint_range(0.0, 2.0) = 0.0;
// 时间变量（驱动内部动画）
uniform float time : hint_range(0.0, 1000.0) = 0.0;

// 扇区基础形状参数
uniform float sector_angle_start : hint_range(-3.15, 3.15) = -0.5236;
uniform float sector_angle_end : hint_range(-3.15, 6.3) = 0.5236;
uniform float inner_radius : hint_range(0.0, 0.5) = 0.25;
uniform float outer_radius : hint_range(0.0, 0.5) = 0.45;

// 辅助函数：角度归一化到 [-PI, PI]
float normalize_angle(float a) {
	float result = mod(a + 3.14159265, 6.28318530) - 3.14159265;
	return result;
}

// 扇区 SDF（有符号距离场）
float sector_sdf(vec2 uv) {
	vec2 center = vec2(0.5, 0.5);
	vec2 d = uv - center;
	float dist = length(d);
	float angle = atan(d.y, d.x);

	// 径向距离
	float radial = max(inner_radius - dist, dist - outer_radius);

	// 角度距离
	float mid_angle = (sector_angle_start + sector_angle_end) * 0.5;
	float half_span = (sector_angle_end - sector_angle_start) * 0.5;
	float angle_diff = abs(normalize_angle(angle - mid_angle));
	float angular = angle_diff - half_span;

	// 将角度距离转换为像素级距离
	angular *= dist;

	return max(radial, angular);
}

// 高通相位内部动画：线框闪烁
float overtone_anim(vec2 uv, float t) {
	float line1 = abs(sin(uv.y * 30.0 + t * 8.0));
	float line2 = abs(sin(uv.x * 25.0 + t * 6.0));
	float grid = min(line1, line2);
	float flicker = step(0.92, grid) * (0.5 + 0.5 * sin(t * 15.0));
	return flicker;
}

// 全频相位内部动画：正弦波流动
float fundamental_anim(vec2 uv, float t) {
	float wave = sin(uv.x * 12.0 + t * 3.0) * 0.5 + 0.5;
	float mask = smoothstep(0.45, 0.5, wave) * smoothstep(0.55, 0.5, wave);
	return mask * 0.6;
}

// 低通相位内部动画：液态涌动
float subbass_anim(vec2 uv, float t) {
	float blob1 = sin(uv.x * 5.0 + t * 1.5) * sin(uv.y * 4.0 + t * 1.2);
	float blob2 = sin(uv.x * 3.0 - t * 0.8) * sin(uv.y * 6.0 + t * 2.0);
	float liquid = (blob1 + blob2) * 0.5 + 0.5;
	return smoothstep(0.3, 0.7, liquid) * 0.5;
}

void fragment() {
	vec2 uv = UV;
	float sdf = sector_sdf(uv);

	// 基础形状遮罩（带抗锯齿）
	float shape_mask = 1.0 - smoothstep(-0.005, 0.002, sdf);

	if (shape_mask < 0.01) {
		COLOR = vec4(0.0);
		return;
	}

	// 基础颜色（未激活态为暗色轮廓）
	float brightness = mix(0.15, 1.0, active_progress);
	vec4 base_color = glow_color * brightness;

	// 内部动画
	float anim = 0.0;
	if (phase_type == 1) {
		anim = overtone_anim(uv, time);
	} else if (phase_type == 0) {
		anim = fundamental_anim(uv, time);
	} else {
		anim = subbass_anim(uv, time);
	}
	anim *= active_progress;

	// 辉光效果
	float glow_dist = -sdf;
	float glow_mask = smoothstep(0.0, 0.03, glow_dist) * active_progress;
	float edge_glow = smoothstep(0.005, 0.0, abs(sdf)) * active_progress * 0.8;

	// 节拍脉动
	float pulse = beat_energy * 0.3 * active_progress;
	float pulse_glow = pulse * smoothstep(0.02, 0.0, abs(sdf));

	// 色差效果（仅高通相位）
	float chromatic = 0.0;
	if (phase_type == 1 && active_progress > 0.5) {
		chromatic = sin(time * 10.0 + uv.y * 20.0) * 0.02 * active_progress;
	}

	// 动态模糊效果（仅低通相位）
	float blur_offset = 0.0;
	if (phase_type == 2 && active_progress > 0.5) {
		blur_offset = sin(time * 2.0) * 0.005 * active_progress;
	}

	// 最终颜色合成
	vec4 final_color = base_color;
	final_color.rgb += glow_color.rgb * (edge_glow + pulse_glow);
	final_color.rgb += glow_color.rgb * anim * 0.3;
	final_color.rgb += vec3(chromatic, 0.0, -chromatic);  // 色差
	final_color.a = shape_mask * mix(0.3, 1.0, active_progress);

	// 放射状光晕（激活态）
	if (active_progress > 0.8) {
		float halo = smoothstep(outer_radius + 0.05, outer_radius, length(uv - vec2(0.5)));
		halo *= (active_progress - 0.8) * 5.0;
		final_color.rgb += glow_color.rgb * halo * 0.2;
	}

	COLOR = final_color;
}
