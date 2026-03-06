shader_type spatial;
render_mode unshaded, blend_add, depth_test_disabled, cull_disabled;

// ============================================================
// 统一的法术材质 Shader (SpellMaterial3D)
// 职责：通过 INSTANCE_CUSTOM_DATA 支持批量渲染，实现多层特效叠加
// ============================================================

// === 全局参数 ===
global uniform float global_time;
global uniform float beat_phase;
global uniform vec3 chapter_color;

// === 材质参数 ===
uniform sampler2D timbre_textures[5]; // 0=无, 1=弹拨, 2=拉弦, 3=吹奏, 4=打击
uniform sampler2D noise_texture;

// === 实例自定义数据 (INSTANCE_CUSTOM_DATA) 解析 ===
// instance_custom.x = base_color_index (音符颜色索引，暂时未使用，颜色通过 COLOR 传递)
// instance_custom.y = emission_multiplier (发光强度/伤害倍率)
// instance_custom.z = timbre_texture_mask (音色遮罩索引 0-4)
// instance_custom.w = distortion_glitch (惩罚扭曲程度 0.0-1.0)

// 伪随机函数
float random(vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

void fragment() {
    // 1. 解析实例数据
    float emission_mult = INSTANCE_CUSTOM.y;
    int timbre_idx = int(round(INSTANCE_CUSTOM.z));
    float glitch_amount = INSTANCE_CUSTOM.w;
    
    // 基础颜色由顶点颜色提供
    vec4 base_color = COLOR;
    
    // 2. 基础形态计算 (中心亮，边缘暗)
    vec2 center_uv = UV - vec2(0.5);
    float dist = length(center_uv) * 2.0;
    
    // 3. 惩罚扭曲 (P0 机制阻断层)
    vec2 distorted_uv = UV;
    if (glitch_amount > 0.0) {
        // 噪音采样
        float noise_val = texture(noise_texture, UV * 5.0 + vec2(global_time)).r;
        // 像素化/撕裂效果
        float block_size = 10.0 * glitch_amount;
        vec2 block_uv = floor(UV * block_size) / block_size;
        float glitch_offset = (random(block_uv + vec2(global_time)) - 0.5) * 0.2 * glitch_amount;
        
        distorted_uv.x += glitch_offset;
        
        // 降低发光，变灰
        emission_mult *= (1.0 - glitch_amount);
        base_color.rgb = mix(base_color.rgb, vec3(dot(base_color.rgb, vec3(0.299, 0.587, 0.114))), glitch_amount);
    }
    
    // 4. 音色纹理叠加 (P4 质感基础层)
    float timbre_alpha = 1.0;
    vec3 timbre_rgb = vec3(1.0);
    
    // 简化版音色纹理采样 (实际项目中应使用 texture 数组或 3D 纹理)
    // 这里用程序化生成模拟不同音色的质感
    if (timbre_idx == 1) {
        // 弹拨：水墨波纹
        float ripple = sin(dist * 20.0 - global_time * 5.0) * 0.5 + 0.5;
        timbre_alpha = smoothstep(0.4, 0.2, dist) * ripple;
    } else if (timbre_idx == 2) {
        // 拉弦：丝线
        float angle = atan(center_uv.y, center_uv.x);
        float strand = sin(angle * 3.0 + dist * 10.0 + global_time * 2.0);
        timbre_alpha = smoothstep(0.8, 1.0, abs(strand)) * smoothstep(0.5, 0.1, dist);
    } else if (timbre_idx == 3) {
        // 吹奏：气流
        float flow = sin(distorted_uv.x * 10.0 + global_time * 3.0) * 0.5 + 0.5;
        timbre_alpha = flow * smoothstep(0.5, 0.0, dist);
    } else if (timbre_idx == 4) {
        // 打击：坚实方块
        vec2 abs_uv = abs(center_uv);
        float box = max(abs_uv.x, abs_uv.y);
        timbre_alpha = smoothstep(0.25, 0.2, box);
    } else {
        // 默认：柔和圆球
        timbre_alpha = smoothstep(0.5, 0.1, dist);
    }
    
    // 5. 核心与辉光计算
    float core = smoothstep(0.2, 0.0, dist);
    float glow = exp(-dist * 3.0) * 0.5;
    
    // 结合章节色调
    vec3 final_rgb = mix(base_color.rgb, chapter_color, 0.1);
    
    // 6. 最终输出
    // 颜色 = 基础色 * (核心 + 音色纹理) + 辉光
    vec3 out_color = final_rgb * (core + timbre_alpha * 0.5) + final_rgb * glow;
    
    ALBEDO = out_color;
    // 发光强度受 emission_mult 和节拍相位影响
    EMISSION = out_color * emission_mult * (1.0 + beat_phase * 0.5);
    
    // 透明度
    ALPHA = clamp((core + timbre_alpha + glow) * base_color.a, 0.0, 1.0);
    
    // 故障时的额外闪烁
    if (glitch_amount > 0.0 && random(vec2(global_time, dist)) > 0.9) {
        ALPHA = 0.0;
    }
}
