shader_type canvas_item;

// 频谱相位全局后处理 Shader（层级七：频谱相位层）
// 根据当前频谱相位切换全局视觉风格
// phase: 0=全频(Fundamental), 1=高通(Overtone), 2=低通(Sub-Bass)

uniform int phase : hint_range(0, 2) = 0;
uniform float transition_progress : hint_range(0.0, 1.0) = 0.0;
uniform float phase_intensity : hint_range(0.0, 1.0) = 1.0;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// 高通相位：明亮、冷色调、线框化、锐化
vec4 overtone_filter(vec4 color, vec2 uv) {
	// 冷色调偏移
	vec3 cold = vec3(
		color.r * 0.85,
		color.g * 0.95,
		color.b * 1.15
	);
	
	// 亮度提升
	cold = cold * 1.15 + vec3(0.05);
	
	// 边缘锐化（Sobel-like）
	vec2 pixel = vec2(1.0) / vec2(textureSize(screen_texture, 0));
	vec4 left = texture(screen_texture, uv + vec2(-pixel.x, 0.0));
	vec4 right = texture(screen_texture, uv + vec2(pixel.x, 0.0));
	vec4 up = texture(screen_texture, uv + vec2(0.0, -pixel.y));
	vec4 down = texture(screen_texture, uv + vec2(0.0, pixel.y));
	
	float edge = length(right.rgb - left.rgb) + length(down.rgb - up.rgb);
	cold += vec3(edge * 0.3);
	
	return vec4(cold, color.a);
}

// 低通相位：暗沉、暖色调、液态化、模糊
vec4 sub_bass_filter(vec4 color, vec2 uv) {
	// 暖色调偏移
	vec3 warm = vec3(
		color.r * 1.15,
		color.g * 0.9,
		color.b * 0.75
	);
	
	// 亮度降低
	warm = warm * 0.85;
	
	// 轻微模糊（液态化）
	vec2 pixel = vec2(1.0) / vec2(textureSize(screen_texture, 0));
	vec4 blur = vec4(0.0);
	blur += texture(screen_texture, uv + vec2(-pixel.x, -pixel.y)) * 0.0625;
	blur += texture(screen_texture, uv + vec2(0.0, -pixel.y)) * 0.125;
	blur += texture(screen_texture, uv + vec2(pixel.x, -pixel.y)) * 0.0625;
	blur += texture(screen_texture, uv + vec2(-pixel.x, 0.0)) * 0.125;
	blur += texture(screen_texture, uv) * 0.25;
	blur += texture(screen_texture, uv + vec2(pixel.x, 0.0)) * 0.125;
	blur += texture(screen_texture, uv + vec2(-pixel.x, pixel.y)) * 0.0625;
	blur += texture(screen_texture, uv + vec2(0.0, pixel.y)) * 0.125;
	blur += texture(screen_texture, uv + vec2(pixel.x, pixel.y)) * 0.0625;
	
	warm = mix(warm, blur.rgb * vec3(1.15, 0.9, 0.75) * 0.85, 0.3);
	
	return vec4(warm, color.a);
}

void fragment() {
	vec4 color = texture(screen_texture, SCREEN_UV);
	
	if (phase == 0 || phase_intensity < 0.01) {
		// 全频：无滤镜
		COLOR = color;
	} else if (phase == 1) {
		// 高通
		vec4 filtered = overtone_filter(color, SCREEN_UV);
		COLOR = mix(color, filtered, phase_intensity * transition_progress);
	} else if (phase == 2) {
		// 低通
		vec4 filtered = sub_bass_filter(color, SCREEN_UV);
		COLOR = mix(color, filtered, phase_intensity * transition_progress);
	}
}
