shader_type canvas_item;

// 惩罚效果后处理 Shader（层级六：环境与惩罚层）
// 实现噪音过载的像素化/色块分离 和 不和谐腐蚀的紫色病毒效果

uniform float noise_overload : hint_range(0.0, 1.0) = 0.0;
uniform float dissonance_corrosion : hint_range(0.0, 1.0) = 0.0;
uniform float monotone_silence : hint_range(0.0, 1.0) = 0.0;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// 噪音过载：像素化 + 色块分离
vec4 noise_overload_effect(vec4 color, vec2 uv, float intensity) {
	// 像素化
	float pixel_size = mix(1.0, 8.0, intensity);
	vec2 screen_size = vec2(textureSize(screen_texture, 0));
	vec2 pixelated_uv = floor(uv * screen_size / pixel_size) * pixel_size / screen_size;
	vec4 pixelated = texture(screen_texture, pixelated_uv);
	
	// 色块分离（色差）
	float aberration = intensity * 0.005;
	float r = texture(screen_texture, uv + vec2(aberration, 0.0)).r;
	float g = texture(screen_texture, uv).g;
	float b = texture(screen_texture, uv - vec2(aberration, 0.0)).b;
	vec4 aberrated = vec4(r, g, b, color.a);
	
	return mix(aberrated, pixelated, intensity * 0.5);
}

// 不和谐腐蚀：紫色数字病毒
vec4 dissonance_effect(vec4 color, vec2 uv, float intensity) {
	// 紫色叠加
	vec3 purple_tint = vec3(0.6, 0.0, 0.8);
	
	// 边缘紫光
	vec2 center = uv - 0.5;
	float edge_dist = max(abs(center.x), abs(center.y)) * 2.0;
	float edge_glow = smoothstep(0.7, 1.0, edge_dist) * intensity;
	
	// 脉冲效果
	float pulse = sin(TIME * 4.0) * 0.5 + 0.5;
	edge_glow *= 0.5 + pulse * 0.5;
	
	vec3 result = mix(color.rgb, purple_tint, edge_glow * 0.4);
	return vec4(result, color.a);
}

// 单调寂静：去饱和 + 灰暗
vec4 monotone_effect(vec4 color, vec2 uv, float intensity) {
	float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));
	vec3 desaturated = mix(color.rgb, vec3(gray), intensity * 0.6);
	desaturated *= 1.0 - intensity * 0.3;
	return vec4(desaturated, color.a);
}

void fragment() {
	vec4 color = texture(screen_texture, SCREEN_UV);
	
	if (noise_overload > 0.01) {
		color = noise_overload_effect(color, SCREEN_UV, noise_overload);
	}
	
	if (dissonance_corrosion > 0.01) {
		color = dissonance_effect(color, SCREEN_UV, dissonance_corrosion);
	}
	
	if (monotone_silence > 0.01) {
		color = monotone_effect(color, SCREEN_UV, monotone_silence);
	}
	
	COLOR = color;
}
