shader_type particles;

// ============================================================
// Lydian 星云粒子着色器 (Issue #59)
// 程序化生成彩虹色粒子，无需纹理
// 用于 GPUParticles3D 的自定义粒子处理
// ============================================================

// === 控制参数 ===
uniform float swirl_speed : hint_range(0.0, 5.0) = 1.0;
uniform float ring_radius : hint_range(0.1, 2.0) = 0.4;
uniform float ring_thickness : hint_range(0.01, 0.5) = 0.08;
uniform float hue_speed : hint_range(0.0, 2.0) = 0.3;
uniform float sparkle_intensity : hint_range(0.0, 2.0) = 1.0;
uniform float burst_energy : hint_range(0.0, 1.0) = 0.0;

// HSV 到 RGB 转换
vec3 hsv_to_rgb(float h, float s, float v) {
    vec3 rgb = clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
    return v * mix(vec3(1.0), rgb, s);
}

// 伪随机
float hash(float n) {
    return fract(sin(n) * 43758.5453123);
}

void start() {
    // 环形分布
    float angle = hash(float(INDEX) * 1.234) * TAU;
    float r = ring_radius + (hash(float(INDEX) * 5.678) - 0.5) * ring_thickness;
    
    TRANSFORM[3].x = cos(angle) * r;
    TRANSFORM[3].y = (hash(float(INDEX) * 9.012) - 0.5) * ring_thickness;
    TRANSFORM[3].z = sin(angle) * r;
    
    // 初始速度 - 切线方向 + 微小径向速度
    float tangent_speed = 0.02 + hash(float(INDEX) * 3.456) * 0.04;
    VELOCITY.x = -sin(angle) * tangent_speed;
    VELOCITY.y = (hash(float(INDEX) * 7.89) - 0.5) * 0.02;
    VELOCITY.z = cos(angle) * tangent_speed;
    
    // 爆发时增加径向速度
    if (burst_energy > 0.01) {
        VELOCITY.x += cos(angle) * burst_energy * 0.3;
        VELOCITY.z += sin(angle) * burst_energy * 0.3;
    }
}

void process() {
    float t = LIFETIME;  // 0.0 到 1.0
    
    // 旋转漩涡运动
    float swirl_angle = TIME * swirl_speed + float(INDEX) * 0.1;
    float current_r = length(vec2(TRANSFORM[3].x, TRANSFORM[3].z));
    
    // 缓慢的螺旋运动
    VELOCITY.x += -sin(swirl_angle) * 0.001;
    VELOCITY.z += cos(swirl_angle) * 0.001;
    
    // 阻尼
    VELOCITY *= 0.995;
    
    // 程序化彩虹色 - 基于粒子生命周期和索引
    float hue = fract(t * 0.5 + float(INDEX) * 0.0618 + TIME * hue_speed);
    float saturation = 0.7 + sin(t * PI) * 0.3;
    float value = sin(t * PI);  // 淡入淡出
    
    // 星尘闪烁
    float sparkle = step(0.95, hash(float(INDEX) + floor(TIME * 8.0))) * sparkle_intensity;
    value = min(value + sparkle, 1.0);
    
    COLOR.rgb = hsv_to_rgb(hue, saturation, value);
    COLOR.a = sin(t * PI) * 0.8;  // 淡入淡出透明度
    
    // 爆发时更亮
    if (burst_energy > 0.01) {
        COLOR.rgb += vec3(burst_energy * 0.5);
        COLOR.a = min(COLOR.a + burst_energy * 0.3, 1.0);
    }
}
