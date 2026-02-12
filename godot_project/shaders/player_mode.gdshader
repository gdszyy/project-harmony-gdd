shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx, unshaded;

// ============================================================
// 统一玩家调式着色器 (Issue #59)
// 处理四种谐振调式的动态视觉变化
// mode_id: 0=Ionian, 1=Locrian, 2=Lydian, 3=Phrygian
// ============================================================

// === 调式控制 ===
uniform int mode_id : hint_range(0, 3) = 0;

// === 基础颜色 ===
uniform vec3 primary_color : source_color = vec3(0.0, 0.85, 0.75);    // 默认: Resonant Teal
uniform vec3 secondary_color : source_color = vec3(0.9, 0.95, 1.0);   // 默认: Crystal White

// === 时间与节拍 ===
uniform float time_offset : hint_range(0.0, 100.0) = 0.0;
uniform float bpm_phase : hint_range(0.0, 1.0) = 0.0;
uniform float beat_energy : hint_range(0.0, 1.0) = 0.0;

// === 发光控制 ===
uniform float emission_energy : hint_range(0.0, 16.0) = 3.0;
uniform float fresnel_power : hint_range(0.1, 10.0) = 2.5;

// === Ionian 专用 ===
uniform float rotation_speed : hint_range(0.0, 5.0) = 1.0;
uniform float ripple_intensity : hint_range(0.0, 1.0) = 0.0;

// === Locrian 专用 ===
uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float jitter_frequency : hint_range(0.0, 50.0) = 15.0;
uniform float chromatic_aberration : hint_range(0.0, 0.1) = 0.0;

// === Lydian 专用 ===
uniform float nebula_density : hint_range(0.0, 2.0) = 1.0;
uniform float star_brightness : hint_range(0.0, 5.0) = 1.0;

// === Phrygian 专用 ===
uniform float blade_sharpness : hint_range(0.0, 2.0) = 1.0;
uniform float stab_offset : hint_range(0.0, 1.0) = 0.0;
uniform float threat_pulse : hint_range(0.0, 1.0) = 0.0;

// ============================================================
// 工具函数
// ============================================================

// HSV 到 RGB 转换
vec3 hsv_to_rgb(float h, float s, float v) {
    vec3 rgb = clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
    return v * mix(vec3(1.0), rgb, s);
}

// 伪随机数生成
float hash(float n) {
    return fract(sin(n) * 43758.5453123);
}

// 2D 噪声
float noise2d(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float n = i.x + i.y * 57.0;
    return mix(
        mix(hash(n), hash(n + 1.0), f.x),
        mix(hash(n + 57.0), hash(n + 58.0), f.x),
        f.y
    );
}

// ============================================================
// 顶点着色器
// ============================================================

void vertex() {
    float t = TIME + time_offset;

    // --- Locrian: 顶点毛刺位移 ---
    if (mode_id == 1) {
        float glitch_block = step(0.85, hash(floor(VERTEX.y * 10.0 + t * jitter_frequency)));
        float displacement = glitch_block * glitch_intensity * 0.05;
        VERTEX.x += sin(t * jitter_frequency + VERTEX.y * 20.0) * displacement;
        VERTEX.z += cos(t * jitter_frequency * 0.7 + VERTEX.x * 15.0) * displacement;

        // 随机跳帧效果
        float frame_skip = step(0.95, hash(floor(t * 30.0)));
        VERTEX += NORMAL * frame_skip * glitch_intensity * 0.02;
    }

    // --- Phrygian: 刀锋变形 ---
    if (mode_id == 3) {
        // 将圆环变形为锐利的刀锋形状
        float angle = atan(VERTEX.z, VERTEX.x);
        float blade_factor = pow(abs(sin(angle * 2.0)), blade_sharpness);
        VERTEX.y += blade_factor * 0.03;

        // 刺击偏移
        VERTEX.z -= stab_offset * 0.1;
    }

    // --- Ionian: BPM 同步的柔和脉冲 ---
    if (mode_id == 0) {
        float pulse = sin(bpm_phase * TAU) * 0.01 * beat_energy;
        VERTEX += NORMAL * pulse;
    }

    // --- Lydian: 星云飘动 ---
    if (mode_id == 2) {
        float wave = sin(t * 0.5 + VERTEX.x * 3.0) * 0.015 * nebula_density;
        VERTEX.y += wave;
        VERTEX.x += cos(t * 0.3 + VERTEX.z * 2.0) * 0.01 * nebula_density;
    }
}

// ============================================================
// 片段着色器
// ============================================================

void fragment() {
    float t = TIME + time_offset;
    vec3 final_color = primary_color;
    float final_emission = emission_energy;

    // 菲涅尔边缘发光
    float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), fresnel_power);

    // ============================================================
    // Mode 0: Ionian (和谐指挥家)
    // 颜色: Resonant Teal + Crystal White
    // 效果: 平滑 BPM 同步旋转, 柔和涟漪
    // ============================================================
    if (mode_id == 0) {
        // 平滑的颜色混合
        float blend = sin(t * rotation_speed + UV.x * TAU) * 0.5 + 0.5;
        final_color = mix(primary_color, secondary_color, blend * 0.3);

        // BPM 同步脉冲
        float bpm_glow = sin(bpm_phase * TAU) * 0.5 + 0.5;
        final_emission *= (1.0 + bpm_glow * beat_energy * 0.5);

        // 施法涟漪效果
        if (ripple_intensity > 0.01) {
            float ripple = sin(length(UV - 0.5) * 20.0 - t * 8.0) * ripple_intensity;
            final_color += vec3(ripple * 0.2);
            final_emission *= (1.0 + ripple * 0.3);
        }
    }

    // ============================================================
    // Mode 1: Locrian (失谐痉挛者)
    // 颜色: Corrosive Purple + Error Red
    // 效果: 毛刺抖动, 色差, 数字衰变
    // ============================================================
    else if (mode_id == 1) {
        // 基础颜色带毛刺
        float glitch_noise = noise2d(UV * 50.0 + vec2(t * 10.0, 0.0));
        float glitch_block = step(0.7, hash(floor(UV.y * 20.0 + t * 5.0)));

        // 色差效果 (Chromatic Aberration)
        vec3 color_shift = vec3(
            noise2d(UV * 30.0 + vec2(t * 8.0 + chromatic_aberration * 10.0, 0.0)),
            noise2d(UV * 30.0 + vec2(0.0, t * 8.0)),
            noise2d(UV * 30.0 + vec2(-t * 8.0 - chromatic_aberration * 10.0, 0.0))
        );

        final_color = mix(primary_color, secondary_color, glitch_block * glitch_intensity);
        final_color += color_shift * chromatic_aberration * glitch_intensity * 2.0;

        // 数字衰变闪烁
        float decay_flash = step(0.92, hash(floor(t * 20.0))) * glitch_intensity;
        final_emission *= (1.0 + decay_flash * 3.0);

        // 扫描线效果
        float scanline = sin(UV.y * 100.0 + t * 15.0) * 0.5 + 0.5;
        final_color *= (1.0 - scanline * glitch_intensity * 0.2);
    }

    // ============================================================
    // Mode 2: Lydian (星云舞者)
    // 颜色: 程序化彩虹色 (基于 hsv_to_rgb)
    // 效果: 星云流动, 星尘闪烁, 飘逸拖尾
    // ============================================================
    else if (mode_id == 2) {
        // 程序化彩虹色 - 基于 UV 和时间
        float hue = fract(UV.x * 0.5 + UV.y * 0.3 + t * 0.1);
        vec3 rainbow = hsv_to_rgb(hue, 0.7, 1.0);

        // 星云密度噪声
        float nebula = noise2d(UV * 5.0 + vec2(t * 0.2, t * 0.15)) * nebula_density;
        float nebula2 = noise2d(UV * 8.0 + vec2(-t * 0.15, t * 0.1)) * nebula_density;

        final_color = mix(primary_color, rainbow, 0.6);
        final_color += vec3(nebula * 0.2, nebula2 * 0.15, (nebula + nebula2) * 0.1);

        // 星尘闪烁
        float star = step(0.97, hash(floor(UV.x * 50.0) + floor(UV.y * 50.0) + floor(t * 3.0)));
        final_color += vec3(star * star_brightness);

        // 整体柔和发光
        final_emission *= (1.0 + nebula * 0.3);
    }

    // ============================================================
    // Mode 3: Phrygian (利刃刺客)
    // 颜色: Error Red + Neon Pink
    // 效果: 刀锋锐利高光, 威胁性脉动, 刺击闪光
    // ============================================================
    else if (mode_id == 3) {
        // 锐利的颜色过渡
        float sharp_blend = step(0.5, fract(UV.x * 4.0 + t * 0.5));
        final_color = mix(primary_color, secondary_color, sharp_blend * 0.4);

        // 威胁性脉动 - 缓慢的明暗交替
        float threat = sin(t * 1.5) * 0.5 + 0.5;
        final_emission *= (0.7 + threat * threat_pulse * 0.6);

        // 刀锋锐利高光
        float edge_highlight = pow(abs(sin(UV.y * 8.0 + t * 2.0)), 8.0);
        final_color += secondary_color * edge_highlight * 0.3;

        // 刺击闪光
        if (stab_offset > 0.01) {
            float stab_flash = (1.0 - stab_offset) * 2.0;
            final_emission *= (1.0 + stab_flash);
            final_color = mix(final_color, vec3(1.0), stab_offset * 0.3);
        }
    }

    // ============================================================
    // 通用输出
    // ============================================================
    ALBEDO = vec3(0.02);
    EMISSION = final_color * fresnel * final_emission;

    // 节拍能量叠加
    EMISSION += final_color * beat_energy * 0.5;

    // 全息投影质感
    ROUGHNESS = 0.05;
    METALLIC = 0.9;
}
