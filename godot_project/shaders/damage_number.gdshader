shader_type canvas_item;

// ============================================================
// 伤害数字着色器
// 支持暴击故障效果、不和谐流淌效果、治疗辉光
// ============================================================

uniform int damage_type : hint_range(0, 4) = 0;
// 0 = NORMAL, 1 = CRITICAL, 2 = DISSONANCE, 3 = HEAL, 4 = PERFECT
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float time_sec : hint_range(0.0, 9999.0) = 0.0;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
    // 暴击/完美：故障顶点偏移
    if (damage_type == 1 || damage_type == 4) {
        float glitch = hash(vec2(floor(VERTEX.y * 0.1), floor(time_sec * 20.0)));
        if (glitch > 0.9) {
            VERTEX.x += (glitch - 0.9) * 40.0 * (1.0 - progress);
        }
    }

    // 不和谐：向下拉伸
    if (damage_type == 2) {
        VERTEX.y += VERTEX.y * progress * 0.3;
    }
}

void fragment() {
    vec2 uv = UV;
    vec4 tex = texture(TEXTURE, uv);

    vec4 final_color = tex;

    if (damage_type == 1 || damage_type == 4) {
        // 暴击/完美：色彩通道分离
        float ca_offset = (1.0 - progress) * 0.015;
        float r = texture(TEXTURE, uv + vec2(ca_offset, 0.0)).r;
        float b = texture(TEXTURE, uv - vec2(ca_offset, 0.0)).b;
        final_color.r = r;
        final_color.b = b;

        // 像素化边缘
        float pixel_size = mix(1.0, 3.0, (1.0 - progress) * 0.5);
        vec2 pixelated_uv = floor(uv * (128.0 / pixel_size)) * (pixel_size / 128.0);
        float pixel_blend = (1.0 - progress) * 0.3;
        vec4 pixelated = texture(TEXTURE, pixelated_uv);
        final_color = mix(final_color, pixelated, pixel_blend);
    }

    if (damage_type == 2) {
        // 不和谐：液体下滴效果
        float drip = sin(uv.x * 20.0 + time_sec * 5.0) * 0.02 * progress;
        vec4 drip_tex = texture(TEXTURE, uv + vec2(0.0, drip));
        final_color = mix(final_color, drip_tex, progress * 0.5);
        // 紫色色调加深
        final_color.rgb = mix(final_color.rgb, final_color.rgb * vec3(0.7, 0.3, 1.0), progress * 0.3);
    }

    if (damage_type == 3) {
        // 治疗：柔和辉光
        float glow = smoothstep(0.5, 0.0, length(uv - vec2(0.5))) * (1.0 - progress) * 0.3;
        final_color.rgb += vec3(0.4, 1.0, 0.7) * glow;
    }

    // 淡出
    final_color.a *= tex.a * (1.0 - progress);

    COLOR = final_color;
}
