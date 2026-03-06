## summon_vfx_controller.gd
## 召唤系统特效控制器 — "幻影声部"视觉表现
## 基于 Docs/Summoning_VFX_Design.md 设计
##
## 负责管理构造体的五阶段特效链：召唤/待机/强拍/弱拍/消散
## 监听 MusicTheoryEngine 的 beat_signal 实现节拍同步
## 实现色彩编码系统：律动塔=谐振青, 共鸣器=圣光金, 干扰场=深邃紫
extends Node3D
class_name SummonVFXController

# ============================================================
# 节点引用
# ============================================================
@onready var main_mesh: MeshInstance3D = $MeshInstance3D
@onready var idle_particles: GPUParticles3D = $IdleParticles
@onready var action_particles: GPUParticles3D = $ActionParticles
@onready var point_light: OmniLight3D = $OmniLight3D

# ============================================================
# 内部状态
# ============================================================
var beat_tween: Tween
var shader_material: ShaderMaterial
var root_note: int = 0
var category: int = 0 # 0: RHYTHM, 1: RESONANCE, 2: MODULATION
var base_color: Color = Color.WHITE
var aux_color: Color = Color.WHITE

# ============================================================
# 色彩编码系统
# ============================================================
const COLOR_PALETTE = {
0: {"main": Color("#00FFFF"), "aux": Color("#FFFFFF")}, # 律动塔：谐振青
1: {"main": Color("#FFD700"), "aux": Color("#FFBF00")}, # 共鸣器：圣光金
2: {"main": Color("#8A2BE2"), "aux": Color("#FF10F0")}, # 干扰场：深邃紫
}

# ============================================================
# 生命周期
# ============================================================
func _ready() -> void:
if main_mesh and main_mesh.get_surface_override_material(0):
shader_material = main_mesh.get_surface_override_material(0)

# 预热粒子系统
if idle_particles:
idle_particles.preprocess = 1.0
if action_particles:
action_particles.preprocess = 1.0

# 连接节拍信号
if GameManager.has_signal("beat_tick"):
if not GameManager.beat_tick.is_connected(_on_beat):
GameManager.beat_tick.connect(_on_beat)

# 连接相位切换信号
var phase_manager = get_tree().current_scene.get_node_or_null("PhaseManager")
if phase_manager and phase_manager.has_signal("phase_changed"):
phase_manager.connect("phase_changed", _on_phase_changed)

# ============================================================
# 初始化配置
# ============================================================
func setup(p_root_note: int, p_category: int) -> void:
root_note = p_root_note
category = p_category

# 应用色彩编码
var palette = COLOR_PALETTE.get(category, COLOR_PALETTE[0])
base_color = palette["main"]
aux_color = palette["aux"]

if shader_material:
shader_material.set_shader_parameter("base_color", base_color)

if point_light:
point_light.light_color = base_color

# 播放召唤动画
_play_spawn_animation()

# ============================================================
# 节拍同步
# ============================================================
func _on_beat(beat_index: int) -> void:
var is_strong_beat: bool = (beat_index % 2 == 0)

# 待机呼吸动画（每拍触发）
_animate_idle_pulse(is_strong_beat)

func _animate_idle_pulse(is_strong: bool) -> void:
if not main_mesh:
return

if beat_tween:
beat_tween.kill()
beat_tween = create_tween()

var target_scale = Vector3(1.1, 1.1, 1.1) if is_strong else Vector3(0.95, 0.95, 0.95)
var target_emission = 2.0 if is_strong else 1.0

beat_tween.tween_property(main_mesh, "scale", target_scale, 0.05)\
.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
beat_tween.tween_property(main_mesh, "scale", Vector3.ONE, 0.15)\
.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

if shader_material:
beat_tween.parallel().tween_property(shader_material,
"shader_parameter/emission_energy", target_emission, 0.05)
beat_tween.tween_property(shader_material,
"shader_parameter/emission_energy", 1.0, 0.2)

# ============================================================
# 动作触发 (由 SummonConstruct 调用)
# ============================================================
func trigger_action(is_strong: bool, is_excited: bool = false) -> void:
if is_strong or is_excited:
_on_strong_beat(is_excited)
else:
_on_weak_beat()

func _on_strong_beat(is_excited: bool = false) -> void:
if not main_mesh:
return

# 强拍100%亮度+辅助色调爆发
var burst_color = aux_color if is_excited else base_color.lightened(0.5)
var burst_emission = 3.0 if is_excited else 2.5

var tween = create_tween()
tween.tween_property(main_mesh, "scale", Vector3(0.7, 0.7, 0.7), 0.05)
tween.tween_property(main_mesh, "scale", Vector3(1.3, 1.3, 1.3), 0.1)
tween.tween_property(main_mesh, "scale", Vector3.ONE, 0.2)

if shader_material:
tween.parallel().tween_property(shader_material, "shader_parameter/emission_energy", burst_emission, 0.05)
tween.parallel().tween_property(shader_material, "shader_parameter/base_color", burst_color, 0.05)
tween.tween_property(shader_material, "shader_parameter/emission_energy", 1.0, 0.3)
tween.parallel().tween_property(shader_material, "shader_parameter/base_color", base_color, 0.3)

if action_particles:
action_particles.restart()
action_particles.emitting = true

func _on_weak_beat() -> void:
if not main_mesh:
return

# 弱拍60%亮度+主色调收缩
var tween = create_tween()
tween.tween_property(main_mesh, "scale", Vector3(0.9, 0.9, 0.9), 0.05)
tween.tween_property(main_mesh, "scale", Vector3(1.1, 1.1, 1.1), 0.1)
tween.tween_property(main_mesh, "scale", Vector3.ONE, 0.15)

if shader_material:
tween.parallel().tween_property(shader_material, "shader_parameter/emission_energy", 0.6, 0.05)
tween.tween_property(shader_material, "shader_parameter/emission_energy", 1.0, 0.2)

# ============================================================
# 相位切换
# ============================================================
func _on_phase_changed(new_phase: int) -> void:
if not shader_material:
return

# 0=全频, 1=高通, 2=低通
# 映射到 shader 的 phase_blend: -1.0(低通) ~ 0.0(全频) ~ 1.0(高通)
var target_blend = 0.0
if new_phase == 1:
target_blend = 1.0
elif new_phase == 2:
target_blend = -1.0

var phase_tween = create_tween()
phase_tween.tween_property(shader_material,
"shader_parameter/phase_blend", target_blend, 0.3)\
.set_trans(Tween.TRANS_SINE)

# ============================================================
# 召唤与消散动画
# ============================================================
func _play_spawn_animation() -> void:
if not main_mesh:
return

main_mesh.scale = Vector3.ZERO
var tween = create_tween()
tween.tween_property(main_mesh, "scale", Vector3.ONE, 0.5)\
.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

if shader_material:
shader_material.set_shader_parameter("emission_energy", 5.0)
tween.parallel().tween_property(shader_material, "shader_parameter/emission_energy", 1.0, 0.5)

func play_fade_out_animation() -> void:
if not main_mesh:
return

var tween = create_tween()
tween.tween_property(main_mesh, "scale", Vector3(1.2, 1.2, 1.2), 0.1)
tween.tween_property(main_mesh, "scale", Vector3.ZERO, 0.4)\
.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

if shader_material:
tween.parallel().tween_property(shader_material, "shader_parameter/emission_energy", 0.0, 0.5)

if idle_particles:
idle_particles.emitting = false
