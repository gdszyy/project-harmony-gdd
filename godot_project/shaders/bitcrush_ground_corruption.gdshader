shader_type canvas_item;

// 比特破碎虫 地面腐蚀效果着色器
// Issue #70: 地面腐蚀 VFX
// 在蠕虫经过的地面上绘制临时的像素化"腐蚀"斑块
// 通过全局着色器参数接收蠕虫位置

global uniform float global_time;
global uniform vec3 worm_position;       // 蠕虫当前世界位置 (x, y, 0)
global uniform float worm_corruption_radius;  // 腐蚀半径
global uniform float worm_corruption_fade;    // 腐蚀衰减进度 [0, 1]

uniform vec4 corruption_color : source_color = vec4(0.0, 1.0, 0.3, 0.25);
uniform float pixel_size : hint_range(2.0, 32.0) = 8.0;
uniform float distortion_strength : hint_range(0.0, 0.1) = 0.02;

// 伪随机
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
    vec2 uv = UV;
    float t = global_time;

    // 计算片段到蠕虫位置的距离（在屏幕空间中近似）
    vec2 frag_world = (FRAGCOORD.xy - vec2(0.5)) * SCREEN_PIXEL_SIZE;
    float dist = length(frag_world - worm_position.xy);

    // 腐蚀区域判定
    float corruption_mask = 1.0 - smoothstep(
        worm_corruption_radius * 0.5,
        worm_corruption_radius,
        dist
    );
    corruption_mask *= (1.0 - worm_corruption_fade);

    if (corruption_mask <= 0.01) {
        // 不在腐蚀范围内，保持原样
        COLOR = texture(TEXTURE, uv);
        return;
    }

    // 像素化效果
    vec2 pixelated_uv = floor(uv * pixel_size) / pixel_size;

    // 随机块颜色
    vec2 block_id = floor(uv * pixel_size);
    float block_val = hash(block_id + vec2(floor(t * 3.0)));

    // 原始颜色
    vec4 original = texture(TEXTURE, uv);

    // 腐蚀后的颜色：像素化 + 绿色调
    vec4 corrupted = texture(TEXTURE, pixelated_uv);
    corrupted.rgb = mix(corrupted.rgb, corruption_color.rgb * block_val, 0.6);

    // 扫描线叠加
    float scanline = sin(uv.y * pixel_size * 6.28) * 0.5 + 0.5;
    corrupted.rgb *= 1.0 - scanline * 0.15;

    // 混合
    COLOR = mix(original, corrupted, corruption_mask * corruption_color.a);
}
