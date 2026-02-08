shader_type canvas_item;

// 玩家受击反馈 Shader — 屏幕抖动 + 边缘红色渐变
// 应用于全屏 ColorRect (CanvasLayer)
//
// 效果：
// 1. 受击瞬间的屏幕色差偏移（模拟抖动）
// 2. 边缘红色渐变暗角（受击严重度越高越明显）
// 3. 低血量时持续的红色脉冲边缘
// 4. 受击瞬间的白色闪光

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

// === 受击参数 ===
uniform float hit_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float hit_direction_x : hint_range(-1.0, 1.0) = 0.0;
uniform float hit_direction_y : hint_range(-1.0, 1.0) = 0.0;

// === 低血量参数 ===
uniform float low_hp_intensity : hint_range(0.0, 1.0) = 0.0;

// === 颜色 ===
uniform vec4 hit_vignette_color : source_color = vec4(0.8, 0.05, 0.05, 0.7);
uniform vec4 low_hp_vignette_color : source_color = vec4(0.6, 0.0, 0.0, 0.5);
uniform float flash_intensity : hint_range(0.0, 1.0) = 0.0;

// === 抖动参数 ===
uniform float shake_offset_x : hint_range(-0.02, 0.02) = 0.0;
uniform float shake_offset_y : hint_range(-0.02, 0.02) = 0.0;

void fragment() {
    // === 1. 屏幕抖动 (UV 偏移) ===
    vec2 uv = SCREEN_UV;
    uv += vec2(shake_offset_x, shake_offset_y);

    // === 2. 色差偏移 (受击方向性) ===
    float aberration = hit_intensity * 0.01;
    vec2 hit_dir = normalize(vec2(hit_direction_x, hit_direction_y) + vec2(0.001));

    vec4 r_col = texture(screen_texture, uv + hit_dir * aberration);
    vec4 g_col = texture(screen_texture, uv);
    vec4 b_col = texture(screen_texture, uv - hit_dir * aberration);

    vec3 final_color = vec3(r_col.r, g_col.g, b_col.b);

    // === 3. 受击红色暗角 ===
    if (hit_intensity > 0.01) {
        float edge_dist = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));

        // 暗角范围随受击强度增大
        float vignette_range = mix(0.15, 0.4, hit_intensity);
        float vignette = smoothstep(0.0, vignette_range, edge_dist);

        // 方向性暗角（受击方向更强）
        vec2 dir_offset = vec2(hit_direction_x, hit_direction_y) * 0.1;
        vec2 shifted_uv = uv - 0.5 + dir_offset;
        float dir_dist = length(shifted_uv);
        float dir_vignette = smoothstep(0.3, 0.8, dir_dist);

        float combined_vignette = max(1.0 - vignette, dir_vignette * 0.5);
        combined_vignette *= hit_intensity;

        final_color = mix(final_color, hit_vignette_color.rgb, combined_vignette * hit_vignette_color.a);
    }

    // === 4. 低血量持续红色脉冲边缘 ===
    if (low_hp_intensity > 0.01) {
        float edge_dist = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));

        // 脉冲呼吸
        float pulse = sin(TIME * 3.0) * 0.5 + 0.5;
        float pulse_strength = mix(0.3, 0.7, pulse);

        float vignette_range = mix(0.1, 0.25, low_hp_intensity);
        float vignette = smoothstep(0.0, vignette_range, edge_dist);

        float low_hp_vignette = (1.0 - vignette) * low_hp_intensity * pulse_strength;

        final_color = mix(final_color, low_hp_vignette_color.rgb, low_hp_vignette * low_hp_vignette_color.a);

        // 心跳效果 — 周期性的微弱全屏红色闪烁
        float heartbeat = pow(max(0.0, sin(TIME * 2.5)), 8.0);
        final_color += low_hp_vignette_color.rgb * heartbeat * low_hp_intensity * 0.1;
    }

    // === 5. 受击白色闪光 ===
    final_color = mix(final_color, vec3(1.0), flash_intensity * 0.4);

    COLOR = vec4(final_color, 1.0);
}
