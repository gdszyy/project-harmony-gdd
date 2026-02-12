// glitch_transition.gdshader
// 数字故障转场效果 — 用于全屏菜单之间的切换
// 模拟在不同"数据空间"之间传送的体验
// 由 UITransitionManager 通过 Tween 控制 progress uniform
shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform vec4 accent_color : source_color = vec4(0.616, 0.435, 1.0, 1.0);

// 伪随机数生成
float random(vec2 uv) {
	return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	float block_height = 0.04;
	float displacement = 0.25;

	// 在动画中段效果最强（钟形曲线）
	float effect_strength = 1.0 - abs(progress - 0.5) * 2.0;
	effect_strength = smoothstep(0.0, 1.0, effect_strength);

	vec2 uv = SCREEN_UV;

	// 水平像素条错位
	float block_seed = floor(uv.y / block_height);
	float offset = (random(vec2(block_seed, progress * 10.0)) - 0.5) * displacement * effect_strength;
	uv.x += offset;

	// 色差 (Chromatic Aberration)
	float ca_strength = 0.015 * effect_strength;
	vec4 color;
	color.r = texture(SCREEN_TEXTURE, uv + vec2(ca_strength, 0.0)).r;
	color.g = texture(SCREEN_TEXTURE, uv).g;
	color.b = texture(SCREEN_TEXTURE, uv - vec2(ca_strength, 0.0)).b;
	color.a = 1.0;

	// 扫描线效果
	float scanline = sin(uv.y * 800.0) * 0.04 * effect_strength;
	color.rgb -= scanline;

	// 随机噪点
	float noise = (random(uv + vec2(progress)) - 0.5) * 0.1 * effect_strength;
	color.rgb += noise;

	// 暗角效果
	float vignette = 1.0 - length(uv - 0.5) * 0.6 * effect_strength;
	color.rgb *= vignette;

	// 在 progress 接近 0.5 时叠加强调色闪烁
	float flash = smoothstep(0.4, 0.5, effect_strength) * smoothstep(0.6, 0.5, effect_strength);
	color.rgb = mix(color.rgb, accent_color.rgb, flash * 0.15);

	// 在 progress > 0.5 时逐渐变暗（为新场景做准备）
	float fade = smoothstep(0.45, 0.55, progress);
	color.rgb *= mix(1.0, 0.0, fade * effect_strength);

	COLOR = color;
}
