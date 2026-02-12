## boss_arena_decorator.gd
## Boss 战专属环境装饰系统 (Issue #114)
##
## 职责：
## 1. 为每个 Boss 战创建独特的视觉环境氛围
## 2. 与 chapter_visual_manager_3d.gd 协作，在 Boss 战期间覆盖章节视觉
## 3. 管理 Boss 战场的粒子特效、色调变化、屏幕后处理
## 4. 响应 Boss 阶段切换，动态调整环境表现
##
## 设计理念：
## 每个 Boss 代表一个音乐史时代，其战场环境应当是该时代精神的视觉化身。
## 从毕达哥拉斯的几何光殿到噪音的数字虚空，环境装饰强化叙事沉浸感。
##
## 使用方式：
##   var decorator = BossArenaDecorator.new()
##   add_child(decorator)
##   decorator.activate_boss_arena("boss_pythagoras")
##   # Boss 击败后
##   decorator.deactivate_boss_arena()
class_name BossArenaDecorator
extends CanvasLayer

# ============================================================
# 信号
# ============================================================
signal arena_activated(boss_key: String)
signal arena_deactivated()
signal arena_phase_changed(phase_index: int)

# ============================================================
# 配置
# ============================================================
## 环境过渡时间
@export var transition_duration: float = 1.5
## 粒子数量倍率
@export var particle_density: float = 1.0

# ============================================================
# 状态
# ============================================================
var _is_active: bool = false
var _current_boss_key: String = ""
var _current_phase: int = 0
var _environment_layer: Control
var _particle_container: Control
var _vignette: ColorRect
var _ambient_overlay: ColorRect
var _screen_tint_overlay: ColorRect
var _active_particles: Array[GPUParticles2D] = []

# ============================================================
# Boss 环境配置数据
# ============================================================
## 每个 Boss 的环境视觉配置
const BOSS_ARENA_CONFIGS: Dictionary = {
	# ================================================================
	# 第一章：毕达哥拉斯 — 纯粹光线构成的圆形殿堂
	# ================================================================
	"boss_pythagoras": {
		"name": "克拉尼圣殿",
		"vignette_color": Color(0.9, 0.85, 0.6, 0.15),
		"ambient_color": Color(0.95, 0.9, 0.7, 0.08),
		"particle_color": Color(1.0, 0.95, 0.7, 0.6),
		"particle_type": "geometric_lines",
		"screen_tint": Color(1.0, 0.98, 0.9, 1.0),
		"pulse_with_beat": true,
		"phase_colors": [
			Color(0.9, 0.85, 0.6),   # 阶段一：温暖金色
			Color(1.0, 0.7, 0.3),    # 阶段二：炽热橙金
		],
		"description": "地面由脉冲网格构成，光线在数学比例中流动",
	},

	# ================================================================
	# 第二章：圭多 — 高耸幽暗的哥特式大教堂
	# ================================================================
	"boss_guido": {
		"name": "圣咏大教堂",
		"vignette_color": Color(0.3, 0.2, 0.5, 0.25),
		"ambient_color": Color(0.2, 0.15, 0.4, 0.12),
		"particle_color": Color(0.6, 0.5, 1.0, 0.4),
		"particle_type": "rising_notes",
		"screen_tint": Color(0.85, 0.8, 1.0, 1.0),
		"pulse_with_beat": true,
		"phase_colors": [
			Color(0.4, 0.3, 0.7),    # 阶段一：幽暗紫蓝
			Color(0.6, 0.3, 0.9),    # 阶段二：深紫
		],
		"description": "哥特式拱顶投下的光柱中，五线谱在地面浮现",
	},

	# ================================================================
	# 第三章：巴赫 — 管风琴管道与精密齿轮的机械宇宙
	# ================================================================
	"boss_bach": {
		"name": "赋格机械殿",
		"vignette_color": Color(0.6, 0.4, 0.2, 0.2),
		"ambient_color": Color(0.4, 0.3, 0.15, 0.1),
		"particle_color": Color(0.8, 0.6, 0.3, 0.5),
		"particle_type": "clockwork_gears",
		"screen_tint": Color(1.0, 0.95, 0.85, 1.0),
		"pulse_with_beat": true,
		"phase_colors": [
			Color(0.7, 0.5, 0.2),    # 阶段一：铜色
			Color(0.9, 0.4, 0.1),    # 阶段二：炽铜
		],
		"description": "巨大的管风琴管道在背景中延伸，齿轮随节拍转动",
	},

	# ================================================================
	# 第四章：莫扎特 — 明亮对称的洛可可风格宫廷舞厅
	# ================================================================
	"boss_mozart": {
		"name": "洛可可舞厅",
		"vignette_color": Color(0.9, 0.7, 1.0, 0.15),
		"ambient_color": Color(0.95, 0.85, 1.0, 0.08),
		"particle_color": Color(1.0, 0.85, 1.0, 0.5),
		"particle_type": "crystal_sparkle",
		"screen_tint": Color(1.0, 0.95, 1.0, 1.0),
		"pulse_with_beat": true,
		"phase_colors": [
			Color(0.9, 0.75, 1.0),   # 呈示部：柔和粉紫
			Color(0.8, 0.5, 0.9),    # 发展部：深紫
			Color(1.0, 0.6, 0.8),    # 再现部：玫瑰金
		],
		"description": "水晶吊灯折射出棱镜光芒，镜面反射无限延伸",
	},

	# ================================================================
	# 第五章：贝多芬 — 风暴肆虐的荒野废墟
	# ================================================================
	"boss_beethoven": {
		"name": "命运荒原",
		"vignette_color": Color(0.2, 0.15, 0.3, 0.3),
		"ambient_color": Color(0.15, 0.1, 0.25, 0.15),
		"particle_color": Color(0.7, 0.5, 1.0, 0.6),
		"particle_type": "storm_lightning",
		"screen_tint": Color(0.85, 0.8, 0.95, 1.0),
		"pulse_with_beat": true,
		"phase_colors": [
			Color(0.3, 0.2, 0.5),    # 月光：深蓝紫
			Color(0.6, 0.2, 0.4),    # 暴风雨：暗红紫
		],
		"description": "闪电撕裂乌云，废墟王座在风暴中心屹立",
	},

	# ================================================================
	# 第六章：艾灵顿 — 烟雾缭绕的爵士俱乐部
	# ================================================================
	"boss_jazz": {
		"name": "午夜爵士俱乐部",
		"vignette_color": Color(0.1, 0.05, 0.2, 0.3),
		"ambient_color": Color(0.05, 0.02, 0.15, 0.15),
		"particle_color": Color(1.0, 0.6, 0.2, 0.4),
		"particle_type": "smoke_neon",
		"screen_tint": Color(0.9, 0.85, 0.95, 1.0),
		"pulse_with_beat": true,
		"phase_colors": [
			Color(0.8, 0.4, 0.1),    # 合奏：温暖琥珀
			Color(0.2, 0.1, 0.6),    # 即兴：深蓝
		],
		"description": "霓虹灯在烟雾中投射出迷幻的光影，舞台聚光灯追随节奏",
	},

	# ================================================================
	# 第七章：噪音 — 抽象的数字空间
	# ================================================================
	"boss_noise": {
		"name": "频谱虚空",
		"vignette_color": Color(0.0, 0.1, 0.05, 0.35),
		"ambient_color": Color(0.0, 0.05, 0.02, 0.2),
		"particle_color": Color(0.0, 1.0, 0.5, 0.5),
		"particle_type": "digital_glitch",
		"screen_tint": Color(0.8, 0.9, 0.85, 1.0),
		"pulse_with_beat": false,
		"phase_colors": [
			Color(0.0, 0.8, 0.4),    # 正弦波：绿
			Color(0.0, 0.4, 1.0),    # 方波：蓝
			Color(1.0, 0.3, 0.0),    # 锯齿波：橙
			Color(1.0, 0.0, 0.3),    # 白噪音：红
		],
		"description": "数据流在虚空中奔涌，示波器波形构成了一切",
	},
}

# ============================================================
# 初始化
# ============================================================

func _ready() -> void:
	layer = 5  # 在游戏层之上，UI 层之下
	_build_environment_layers()
	_hide_all()
	set_process(false)

func _build_environment_layers() -> void:
	# 环境容器
	_environment_layer = Control.new()
	_environment_layer.name = "EnvironmentLayer"
	_environment_layer.anchor_right = 1.0
	_environment_layer.anchor_bottom = 1.0
	_environment_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_environment_layer)

	# 环境色调覆盖层
	_ambient_overlay = ColorRect.new()
	_ambient_overlay.name = "AmbientOverlay"
	_ambient_overlay.anchor_right = 1.0
	_ambient_overlay.anchor_bottom = 1.0
	_ambient_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ambient_overlay.color = Color(0, 0, 0, 0)
	_environment_layer.add_child(_ambient_overlay)

	# 粒子容器
	_particle_container = Control.new()
	_particle_container.name = "ParticleContainer"
	_particle_container.anchor_right = 1.0
	_particle_container.anchor_bottom = 1.0
	_particle_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_environment_layer.add_child(_particle_container)

	# 屏幕色调覆盖层（使用 screen_tint 配置）
	_screen_tint_overlay = ColorRect.new()
	_screen_tint_overlay.name = "ScreenTintOverlay"
	_screen_tint_overlay.anchor_right = 1.0
	_screen_tint_overlay.anchor_bottom = 1.0
	_screen_tint_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen_tint_overlay.color = Color(1, 1, 1, 0)
	_environment_layer.add_child(_screen_tint_overlay)

	# 暗角效果
	_vignette = ColorRect.new()
	_vignette.name = "Vignette"
	_vignette.anchor_right = 1.0
	_vignette.anchor_bottom = 1.0
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.color = Color(0, 0, 0, 0)
	_environment_layer.add_child(_vignette)

# ============================================================
# 公共接口
# ============================================================

## 激活 Boss 战场环境
func activate_boss_arena(boss_key: String) -> void:
	if _is_active:
		deactivate_boss_arena()

	if not BOSS_ARENA_CONFIGS.has(boss_key):
		push_warning("BossArenaDecorator: 未找到 Boss '%s' 的环境配置" % boss_key)
		return

	_current_boss_key = boss_key
	_current_phase = 0
	_is_active = true
	set_process(true)

	var config: Dictionary = BOSS_ARENA_CONFIGS[boss_key]

	# 应用环境配置
	_apply_arena_config(config)

	# 创建粒子效果
	_create_particles(config)

	# 淡入环境
	_fade_in_arena()

	# 通知 chapter_visual_manager_3d（如果存在）
	_notify_visual_manager(boss_key, true)

	arena_activated.emit(boss_key)

## 停用 Boss 战场环境
func deactivate_boss_arena() -> void:
	if not _is_active:
		return

	_fade_out_arena()
	_is_active = false
	set_process(false)

	# 恢复章节视觉
	_notify_visual_manager(_current_boss_key, false)

	_current_boss_key = ""
	arena_deactivated.emit()

## 响应 Boss 阶段切换
func on_boss_phase_changed(phase_index: int) -> void:
	if not _is_active:
		return

	_current_phase = phase_index
	var config: Dictionary = BOSS_ARENA_CONFIGS.get(_current_boss_key, {})
	var phase_colors: Array = config.get("phase_colors", [])

	if phase_index < phase_colors.size():
		var new_color: Color = phase_colors[phase_index]
		_transition_phase_color(new_color)

	arena_phase_changed.emit(phase_index)

## 获取当前 Boss 战场是否激活
func is_arena_active() -> bool:
	return _is_active

# ============================================================
# 环境应用
# ============================================================

func _apply_arena_config(config: Dictionary) -> void:
	# 暗角颜色
	var vignette_color: Color = config.get("vignette_color", Color(0, 0, 0, 0.2))
	_vignette.color = vignette_color
	_vignette.modulate.a = 0.0

	# 环境色调
	var ambient_color: Color = config.get("ambient_color", Color(0, 0, 0, 0.1))
	_ambient_overlay.color = ambient_color
	_ambient_overlay.modulate.a = 0.0

	# 屏幕色调覆盖（微妙的全屏色彩偏移）
	var screen_tint: Color = config.get("screen_tint", Color(1, 1, 1, 1))
	# 将 screen_tint 转换为低透明度覆盖色，避免过度影响画面
	var tint_overlay_color := Color(
		screen_tint.r, screen_tint.g, screen_tint.b,
		(1.0 - screen_tint.a) * 0.08  # 非白色时产生微弱色彩偏移
	)
	_screen_tint_overlay.color = tint_overlay_color
	_screen_tint_overlay.modulate.a = 0.0

func _create_particles(config: Dictionary) -> void:
	# 清除旧粒子
	_clear_particles()

	var particle_type: String = config.get("particle_type", "")
	var particle_color: Color = config.get("particle_color", Color.WHITE)

	match particle_type:
		"geometric_lines":
			_create_geometric_particles(particle_color)
		"rising_notes":
			_create_rising_particles(particle_color)
		"clockwork_gears":
			_create_clockwork_particles(particle_color)
		"crystal_sparkle":
			_create_sparkle_particles(particle_color)
		"storm_lightning":
			_create_storm_particles(particle_color)
		"smoke_neon":
			_create_smoke_particles(particle_color)
		"digital_glitch":
			_create_glitch_particles(particle_color)

func _clear_particles() -> void:
	for p in _active_particles:
		if is_instance_valid(p):
			p.queue_free()
	_active_particles.clear()

# ============================================================
# 粒子效果工厂
# ============================================================

## 毕达哥拉斯：几何光线粒子
func _create_geometric_particles(color: Color) -> void:
	var particles := _create_base_particles()
	var mat := particles.process_material as ParticleProcessMaterial
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(600, 400, 0)
	mat.direction = Vector3(0, -0.3, 0)
	mat.spread = 30.0
	mat.initial_velocity_min = 10.0
	mat.initial_velocity_max = 30.0
	mat.gravity = Vector3(0, 0, 0)
	mat.scale_min = 1.0
	mat.scale_max = 3.0
	mat.color = color
	particles.amount = int(40 * particle_density)
	particles.lifetime = 4.0
	_particle_container.add_child(particles)
	_active_particles.append(particles)

## 圭多：上升的音符粒子
func _create_rising_particles(color: Color) -> void:
	var particles := _create_base_particles()
	var mat := particles.process_material as ParticleProcessMaterial
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(600, 50, 0)
	mat.direction = Vector3(0, -1, 0)
	mat.spread = 15.0
	mat.initial_velocity_min = 20.0
	mat.initial_velocity_max = 50.0
	mat.gravity = Vector3(0, -10, 0)
	mat.scale_min = 0.5
	mat.scale_max = 2.0
	mat.color = color
	particles.amount = int(30 * particle_density)
	particles.lifetime = 5.0
	particles.position = Vector2(600, 700)
	_particle_container.add_child(particles)
	_active_particles.append(particles)

## 巴赫：齿轮旋转粒子
func _create_clockwork_particles(color: Color) -> void:
	var particles := _create_base_particles()
	var mat := particles.process_material as ParticleProcessMaterial
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mat.emission_ring_radius = 300.0
	mat.emission_ring_inner_radius = 100.0
	mat.emission_ring_height = 0.0
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 5.0
	mat.initial_velocity_max = 15.0
	mat.angular_velocity_min = 30.0
	mat.angular_velocity_max = 90.0
	mat.gravity = Vector3(0, 0, 0)
	mat.scale_min = 1.5
	mat.scale_max = 4.0
	mat.color = color
	particles.amount = int(25 * particle_density)
	particles.lifetime = 6.0
	particles.position = Vector2(600, 400)
	_particle_container.add_child(particles)
	_active_particles.append(particles)

## 莫扎特：水晶闪烁粒子
func _create_sparkle_particles(color: Color) -> void:
	var particles := _create_base_particles()
	var mat := particles.process_material as ParticleProcessMaterial
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(600, 400, 0)
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 5.0
	mat.initial_velocity_max = 20.0
	mat.gravity = Vector3(0, 5, 0)
	mat.scale_min = 0.3
	mat.scale_max = 1.5
	mat.color = color
	particles.amount = int(50 * particle_density)
	particles.lifetime = 3.0
	particles.position = Vector2(600, 200)
	_particle_container.add_child(particles)
	_active_particles.append(particles)

## 贝多芬：风暴闪电粒子
func _create_storm_particles(color: Color) -> void:
	# 雨滴层
	var rain := _create_base_particles()
	var rain_mat := rain.process_material as ParticleProcessMaterial
	rain_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	rain_mat.emission_box_extents = Vector3(700, 10, 0)
	rain_mat.direction = Vector3(-0.2, 1, 0)
	rain_mat.spread = 5.0
	rain_mat.initial_velocity_min = 200.0
	rain_mat.initial_velocity_max = 350.0
	rain_mat.gravity = Vector3(0, 100, 0)
	rain_mat.scale_min = 0.5
	rain_mat.scale_max = 1.0
	rain_mat.color = Color(0.5, 0.5, 0.7, 0.3)
	rain.amount = int(80 * particle_density)
	rain.lifetime = 2.0
	rain.position = Vector2(600, -50)
	_particle_container.add_child(rain)
	_active_particles.append(rain)

	# 闪电火花层
	var sparks := _create_base_particles()
	var spark_mat := sparks.process_material as ParticleProcessMaterial
	spark_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	spark_mat.emission_box_extents = Vector3(400, 200, 0)
	spark_mat.direction = Vector3(0, 0, 0)
	spark_mat.spread = 180.0
	spark_mat.initial_velocity_min = 50.0
	spark_mat.initial_velocity_max = 150.0
	spark_mat.gravity = Vector3(0, 50, 0)
	spark_mat.scale_min = 0.5
	spark_mat.scale_max = 2.0
	spark_mat.color = color
	sparks.amount = int(15 * particle_density)
	sparks.lifetime = 0.8
	sparks.position = Vector2(600, 300)
	_particle_container.add_child(sparks)
	_active_particles.append(sparks)

## 艾灵顿：烟雾霓虹粒子
func _create_smoke_particles(color: Color) -> void:
	# 烟雾层
	var smoke := _create_base_particles()
	var smoke_mat := smoke.process_material as ParticleProcessMaterial
	smoke_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	smoke_mat.emission_box_extents = Vector3(600, 100, 0)
	smoke_mat.direction = Vector3(0, -1, 0)
	smoke_mat.spread = 30.0
	smoke_mat.initial_velocity_min = 5.0
	smoke_mat.initial_velocity_max = 15.0
	smoke_mat.gravity = Vector3(0, -3, 0)
	smoke_mat.scale_min = 3.0
	smoke_mat.scale_max = 8.0
	smoke_mat.color = Color(0.3, 0.2, 0.4, 0.15)
	smoke.amount = int(20 * particle_density)
	smoke.lifetime = 8.0
	smoke.position = Vector2(600, 700)
	_particle_container.add_child(smoke)
	_active_particles.append(smoke)

	# 霓虹光点层
	var neon := _create_base_particles()
	var neon_mat := neon.process_material as ParticleProcessMaterial
	neon_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	neon_mat.emission_box_extents = Vector3(500, 300, 0)
	neon_mat.direction = Vector3(0, 0, 0)
	neon_mat.spread = 180.0
	neon_mat.initial_velocity_min = 2.0
	neon_mat.initial_velocity_max = 8.0
	neon_mat.gravity = Vector3(0, 0, 0)
	neon_mat.scale_min = 0.5
	neon_mat.scale_max = 2.0
	neon_mat.color = color
	neon.amount = int(25 * particle_density)
	neon.lifetime = 4.0
	neon.position = Vector2(600, 400)
	_particle_container.add_child(neon)
	_active_particles.append(neon)

## 噪音：数字故障粒子
func _create_glitch_particles(color: Color) -> void:
	var particles := _create_base_particles()
	var mat := particles.process_material as ParticleProcessMaterial
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(600, 400, 0)
	mat.direction = Vector3(0, 0, 0)
	mat.spread = 180.0
	mat.initial_velocity_min = 30.0
	mat.initial_velocity_max = 100.0
	mat.gravity = Vector3(0, 0, 0)
	mat.scale_min = 0.5
	mat.scale_max = 3.0
	mat.color = color
	particles.amount = int(60 * particle_density)
	particles.lifetime = 1.5
	particles.position = Vector2(600, 400)
	# 故障效果：随机性更强
	mat.initial_velocity_min = 50.0
	mat.initial_velocity_max = 200.0
	_particle_container.add_child(particles)
	_active_particles.append(particles)

## 创建基础粒子节点
func _create_base_particles() -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	var mat := ParticleProcessMaterial.new()
	particles.process_material = mat
	particles.emitting = true
	particles.one_shot = false
	return particles

# ============================================================
# 过渡动画
# ============================================================

func _fade_in_arena() -> void:
	_environment_layer.visible = true
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_vignette, "modulate:a", 1.0, transition_duration)
	tween.tween_property(_ambient_overlay, "modulate:a", 1.0, transition_duration)
	tween.tween_property(_screen_tint_overlay, "modulate:a", 1.0, transition_duration)

func _fade_out_arena() -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_vignette, "modulate:a", 0.0, transition_duration)
	tween.tween_property(_ambient_overlay, "modulate:a", 0.0, transition_duration)
	tween.tween_property(_screen_tint_overlay, "modulate:a", 0.0, transition_duration)
	tween.chain()
	tween.tween_callback(func():
		_clear_particles()
		_environment_layer.visible = false
	)

func _transition_phase_color(new_color: Color) -> void:
	var new_vignette := Color(new_color.r, new_color.g, new_color.b, _vignette.color.a)
	var new_ambient := Color(new_color.r * 0.5, new_color.g * 0.5, new_color.b * 0.5, _ambient_overlay.color.a)

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_vignette, "color", new_vignette, 1.0)
	tween.tween_property(_ambient_overlay, "color", new_ambient, 1.0)

	# 更新粒子颜色
	for p in _active_particles:
		if is_instance_valid(p) and p.process_material:
			var mat := p.process_material as ParticleProcessMaterial
			if mat:
				var target_color := Color(new_color.r, new_color.g, new_color.b, mat.color.a)
				tween.tween_property(mat, "color", target_color, 1.0)

func _hide_all() -> void:
	_environment_layer.visible = false

# ============================================================
# 每帧更新
# ============================================================

func _process(delta: float) -> void:
	if not _is_active:
		return

	var config: Dictionary = BOSS_ARENA_CONFIGS.get(_current_boss_key, {})

	# 节拍脉冲效果
	if config.get("pulse_with_beat", false):
		_update_beat_pulse(delta)

	# 噪音 Boss 特殊效果：随机颜色闪烁
	if _current_boss_key == "boss_noise":
		_update_glitch_effect(delta)

func _update_beat_pulse(_delta: float) -> void:
	# 通过 BGMManager 获取节拍相位
	# BGMManager 使用 _current_sixteenth (0-based) 跟踪小节内位置
	var bgm_mgr := get_node_or_null("/root/BGMManager")
	if bgm_mgr == null:
		return

	# 从 _current_sixteenth 计算节拍相位 (0.0 ~ 1.0 每拍)
	# 每拍 = 4 个十六分音符，所以 beat_phase = (sixteenth % 4) / 4.0
	var beat_phase: float = 0.0
	if "_current_sixteenth" in bgm_mgr:
		var sixteenth: int = bgm_mgr._current_sixteenth
		beat_phase = float(sixteenth % 4) / 4.0
	elif bgm_mgr.has_method("get_beat_phase"):
		beat_phase = bgm_mgr.get_beat_phase()

	# 节拍时刻环境闪烁（beat_phase 接近 0 时脉冲最强）
	var pulse := exp(-beat_phase * 4.0) * 0.15
	_ambient_overlay.modulate.a = 1.0 + pulse

var _glitch_timer: float = 0.0

func _update_glitch_effect(_delta: float) -> void:
	_glitch_timer += _delta
	if _glitch_timer > 0.1:
		_glitch_timer = 0.0
		# 随机微调环境颜色模拟故障
		var r := randf_range(-0.05, 0.05)
		var g := randf_range(-0.05, 0.05)
		_ambient_overlay.color.r = clampf(_ambient_overlay.color.r + r, 0.0, 0.3)
		_ambient_overlay.color.g = clampf(_ambient_overlay.color.g + g, 0.0, 0.2)

# ============================================================
# 与 ChapterVisualManager3D 协作
# ============================================================

func _notify_visual_manager(boss_key: String, entering: bool) -> void:
	var visual_mgr := get_tree().get_first_node_in_group("chapter_visual_manager")
	if visual_mgr == null:
		visual_mgr = get_node_or_null("/root/ChapterVisualManager3D")

	if visual_mgr and visual_mgr.has_method("on_boss_arena_state_changed"):
		visual_mgr.on_boss_arena_state_changed(boss_key, entering)
	elif visual_mgr and entering:
		# 后备：直接设置 shader 参数
		if visual_mgr.has_method("set_boss_mode"):
			visual_mgr.set_boss_mode(true)
