shader_type canvas_item;
// 狂怒精魂 — 闪电云体 Shader (Issue #68)
// 用于不定形粒子云和核心球体的程序化视觉
// 实现：闪电效果、音乐强度驱动、蓄力白光、电弧辉光

// === 控制参数 ===
uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float hp_ratio : hint_range(0.0, 1.0) = 1.0;
uniform float beat_energy : hint_range(0.0, 1.0) = 0.0;
uniform float music_intensity : hint_range(0.0, 1.0) = 0.5;
uniform float charge_progress : hint_range(0.0, 1.0) = 0.0;
uniform vec4 base_tint : source_color = vec4(0.7, 0.8, 1.0, 1.0);

// === 闪电视觉参数 ===
uniform float lightning_frequency : hint_range(0.0, 20.0) = 8.0;
uniform float lightning_brightness : hint_range(0.0, 3.0) = 1.5;
uniform float arc_glow_intensity : hint_range(0.0, 2.0) = 1.0;
uniform float core_pulse_speed : hint_range(0.0, 10.0) = 3.0;
uniform float noise_scale : hint_range(1.0, 50.0) = 15.0;

// 伪随机噪声
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

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

// 分形布朗运动
float fbm(vec2 p) {
    float value = 0.0;
    float amplitude = 0.5;
    for (int i = 0; i < 4; i++) {
        value += amplitude * noise(p);
        p *= 2.0;
        amplitude *= 0.5;
    }
    return value;
}

void fragment() {
    vec2 uv = UV;
    float time = TIME;
    vec4 color = COLOR;

    // === 不定形云体效果 ===
    // 使用 FBM 噪声创建不定形的云状纹理
    float cloud = fbm(uv * noise_scale + vec2(time * 0.5, time * 0.3));
    cloud = smoothstep(0.3, 0.7, cloud);

    // 音乐强度影响云的密度和活跃度
    float active_cloud = fbm(uv * noise_scale * 1.5 + vec2(time * music_intensity * 2.0, time * 1.5));
    cloud = mix(cloud, active_cloud, music_intensity);

    // 云体颜色：白/蓝渐变
    vec3 cloud_color = mix(
        vec3(0.4, 0.6, 1.0),  // 电弧蓝
        vec3(0.9, 0.95, 1.0), // 闪电白
        cloud
    );

    // === 闪电效果 ===
    // 随机闪电闪烁
    float lightning_flash = step(0.97 - music_intensity * 0.05,
        hash(vec2(floor(time * lightning_frequency), floor(uv.y * 10.0))));
    cloud_color += vec3(lightning_flash * lightning_brightness);

    // 闪电分支（程序化分形）
    float branch = abs(sin(uv.y * 30.0 + time * 5.0 + noise(uv * 20.0) * 10.0));
    branch = smoothstep(0.95, 1.0, branch);
    cloud_color += vec3(0.8, 0.9, 1.0) * branch * music_intensity;

    // === 核心脉动辉光 ===
    float core_dist = distance(uv, vec2(0.5, 0.5));
    float core_pulse = sin(time * core_pulse_speed) * 0.15 + 0.85;
    float core_glow = smoothstep(0.3 * core_pulse, 0.0, core_dist) * arc_glow_intensity;

    // 双脉冲心跳
    float double_beat = max(sin(time * core_pulse_speed * 2.0) * 0.1, 0.0);
    core_glow *= (1.0 + double_beat);

    cloud_color += vec3(1.0, 0.95, 0.9) * core_glow;

    // === 蓄力效果 ===
    if (charge_progress > 0.0) {
        // 粒子向核心收缩的视觉
        float charge_pull = smoothstep(0.5 - charge_progress * 0.3, 0.0, core_dist);
        cloud_color = mix(cloud_color, vec3(1.0), charge_progress * charge_pull);

        // 全身白光
        cloud_color += vec3(charge_progress * 0.5);

        // 能量涟漪
        float ripple = sin(core_dist * 40.0 - time * 10.0) * 0.5 + 0.5;
        cloud_color += vec3(ripple * charge_progress * 0.3);
    }

    // === 节拍脉冲 ===
    cloud_color += vec3(beat_energy * 0.3);
    // 节拍时核心爆发
    core_glow += beat_energy * 0.5;
    cloud_color += vec3(1.0, 0.95, 0.9) * beat_energy * 0.3 * smoothstep(0.2, 0.0, core_dist);

    // === 音乐强度驱动的整体效果 ===
    // 高强度时更亮、更活跃
    cloud_color *= mix(0.6, 1.2, music_intensity);
    // 高强度时边缘更锐利
    float edge_sharpness = mix(0.3, 0.8, music_intensity);
    color.a *= smoothstep(1.0 - edge_sharpness, edge_sharpness, cloud);

    // === 故障效果 ===
    if (glitch_intensity > 0.3) {
        // 电子干扰
        float interference = sin(FRAGCOORD.y * 100.0 + time * 20.0) * glitch_intensity * 0.2;
        cloud_color.r += interference;
        cloud_color.b -= interference;
        // 随机断裂
        if (hash(vec2(floor(time * 15.0), floor(uv.y * 30.0))) > 0.9 - glitch_intensity * 0.2) {
            cloud_color = vec3(1.0);
        }
    }

    // === HP 相关效果 ===
    if (hp_ratio < 0.4) {
        float damage_factor = (0.4 - hp_ratio) / 0.4;
        // 低 HP 时闪电变得不稳定
        cloud_color += vec3(sin(time * 20.0) * damage_factor * 0.3);
        // 颜色偏红
        cloud_color = mix(cloud_color, vec3(1.0, 0.3, 0.2), damage_factor * 0.3);
    }

    color.rgb = cloud_color * base_tint.rgb;
    COLOR = color;
}
