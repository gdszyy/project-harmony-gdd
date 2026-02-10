shader_type canvas_item;

// 和弦进行全屏特效 Shader（层级五：组合效果层）
// D→T: 金色冲击波 + 暖色调染色
// T→D: 琥珀色边框收缩 + 鱼眼畸变
// PD→D: 紫色加速线条

uniform int progression_type : hint_range(0, 2) = 0;
// 0 = D→T (终止解决), 1 = T→D (增幅蓄力), 2 = PD→D (加速)

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 effect_color : source_color = vec4(1.0, 0.85, 0.2, 1.0);
uniform float effect_intensity : hint_range(0.0, 2.0) = 1.0;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// D→T: 金色冲击波
vec4 d_to_t_effect(vec2 uv, float prog) {
	vec2 center = uv - 0.5;
	float dist = length(center);
	
	// 扩散冲击波环
	float wave_radius = prog * 1.2;
	float wave = smoothstep(wave_radius - 0.05, wave_radius, dist) *
				 smoothstep(wave_radius + 0.05, wave_radius, dist);
	
	// 暖色调染色（随冲击波扩散）
	float warm_mask = smoothstep(wave_radius + 0.1, wave_radius - 0.1, dist);
	warm_mask *= (1.0 - prog);  // 随时间消退
	
	vec4 screen = texture(screen_texture, uv);
	vec3 warm_tint = mix(screen.rgb, screen.rgb * vec3(1.2, 1.05, 0.8), warm_mask * 0.3);
	
	// 冲击波光环
	vec3 wave_color = effect_color.rgb * wave * 2.0 * effect_intensity;
	
	return vec4(warm_tint + wave_color, screen.a);
}

// T→D: 边框收缩 + 鱼眼畸变
vec4 t_to_d_effect(vec2 uv, float prog) {
	vec2 center = uv - 0.5;
	float dist = length(center);
	
	// 鱼眼畸变
	float distortion = prog * 0.05 * effect_intensity;
	vec2 distorted_uv = uv + center * dist * distortion;
	vec4 screen = texture(screen_texture, distorted_uv);
	
	// 琥珀色边框
	float border_width = 0.08 * prog;
	float edge = max(abs(center.x), abs(center.y)) * 2.0;
	float border = smoothstep(1.0 - border_width, 1.0, edge);
	
	vec3 border_color = effect_color.rgb * border * effect_intensity;
	
	return vec4(screen.rgb + border_color, screen.a);
}

// PD→D: 加速线条
vec4 pd_to_d_effect(vec2 uv, float prog) {
	vec4 screen = texture(screen_texture, uv);
	vec2 center = uv - 0.5;
	float angle = atan(center.y, center.x);
	float dist = length(center);
	
	// 径向线条（从中心向外）
	float lines = abs(sin(angle * 20.0 + prog * 10.0));
	lines = smoothstep(0.95, 1.0, lines);
	lines *= smoothstep(0.1, 0.5, dist);  // 中心无线条
	lines *= (1.0 - prog);  // 随时间消退
	
	vec3 line_color = effect_color.rgb * lines * 0.5 * effect_intensity;
	
	return vec4(screen.rgb + line_color, screen.a);
}

void fragment() {
	if (progress < 0.01 || effect_intensity < 0.01) {
		COLOR = texture(screen_texture, SCREEN_UV);
	} else if (progression_type == 0) {
		COLOR = d_to_t_effect(SCREEN_UV, progress);
	} else if (progression_type == 1) {
		COLOR = t_to_d_effect(SCREEN_UV, progress);
	} else {
		COLOR = pd_to_d_effect(SCREEN_UV, progress);
	}
}
