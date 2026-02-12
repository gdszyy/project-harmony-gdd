## ch5_fury_spirit.gd
## 第五章特色敌人：狂怒精魂 (Fury Spirit)
## 不定形的闪电元素生物，核心是一个跳动的心脏状闪电球。
## 音乐隐喻：贝多芬的狂暴激情，情感的极端爆发。
##
## 程序化视觉实现 (Issue #68):
## - 不定形粒子云体 (程序化噪声驱动的粒子群)
## - 脉动心脏核心 (SphereMesh 模拟，sin(TIME) 驱动)
## - 音乐强度驱动 (music_intensity uniform 控制视觉激烈程度)
## - 闪电效果 (随机高亮粒子模拟闪电)
##
## 机制：
## - 不定形的闪电元素，形态随 BGM 强度变化
## - 核心心脏脉动，发出闪电触须
## - 蓄力时全身发出耀眼白光
## - 冲刺留下电弧轨迹
extends "res://scripts/entities/enemy_base.gd"

# ============================================================
# Fury Spirit 专属配置
# ============================================================

## 闪电触须伤害
@export var lightning_damage: float = 12.0
## 闪电触须范围
@export var lightning_range: float = 100.0
## 蓄力时间
@export var charge_duration: float = 2.0
## 冲刺速度倍率
@export var dash_speed_multiplier: float = 4.0
## 冲刺持续时间
@export var dash_duration: float = 0.3
## 电弧轨迹持续时间
@export var arc_trail_duration: float = 1.5
## 电弧轨迹伤害/秒
@export var arc_trail_dps: float = 6.0

## === 程序化视觉配置 (Issue #68) ===
## 粒子云数量
@export var cloud_particle_count: int = 40
## 粒子云最大半径
@export var cloud_max_radius: float = 30.0
## 核心脉动速度
@export var core_pulse_speed: float = 3.0
## 核心基础大小
@export var core_base_size: float = 8.0
## 闪电颜色
@export var lightning_color: Color = Color(0.8, 0.9, 1.0, 0.95)  # 闪电白
## 电弧颜色
@export var arc_color: Color = Color(0.4, 0.6, 1.0, 0.8)  # 电弧蓝
## 音乐强度（由外部 AudioManager 设置）
var music_intensity: float = 0.5

# ============================================================
# 内部状态
# ============================================================

## 行为状态
enum FuryState { IDLE, CHARGING, DASHING, RECOVERING }
var _fury_state: FuryState = FuryState.IDLE

## 蓄力计时
var _charge_timer: float = 0.0
## 冲刺计时
var _dash_timer: float = 0.0
## 冲刺方向
var _dash_direction: Vector2 = Vector2.ZERO
## 恢复计时
var _recovery_timer: float = 0.0
## 攻击节拍计数
var _attack_beat_counter: int = 0
## 闪电触须冷却
var _lightning_cooldown: float = 0.0

## === 程序化视觉节点 (Issue #68) ===
var _cloud_container: Node2D = null        # 粒子云容器
var _cloud_particles: Array[Polygon2D] = []  # 云粒子
var _core_visual: Node2D = null            # 核心容器
var _core_sphere: Polygon2D = null         # 核心球体
var _core_glow: Polygon2D = null           # 核心光晕
var _lightning_tendrils: Array[Line2D] = []  # 闪电触须
var _arc_trails: Array[Dictionary] = []     # 电弧轨迹 {node, timer}
var _cloud_phase: float = 0.0             # 云动画相位
var _core_phase: float = 0.0              # 核心脉动相位
var _lightning_timer: float = 0.0          # 闪电刷新计时
var _noise_seeds: Array[float] = []        # 粒子噪声种子

# ============================================================
# 初始化
# ============================================================

func _on_enemy_ready() -> void:
	enemy_type = EnemyType.SCREECH  # 快速、危险的类型
	quantized_fps = 14.0
	_quantize_interval = 1.0 / quantized_fps
	knockback_resistance = 0.3
	move_on_offbeat = true
	
	# 闪电白/电弧蓝色调
	base_color = Color(0.7, 0.8, 1.0)
	base_glitch_intensity = 0.08
	max_glitch_intensity = 0.7
	
	# 生成程序化视觉
	_build_cloud_particles()
	_build_core_visual()
	_build_lightning_tendrils()
	
	# 初始化噪声种子
	for i in range(cloud_particle_count):
		_noise_seeds.append(randf() * 1000.0)
	
	# 将程序化视觉核心节点注册为 enemy_base 的 _sprite
	# 使基类的 _update_visual 能正确操作程序化视觉
	_sprite = _core_visual

# ============================================================
# 程序化不定形粒子云体 (Issue #68)
# ============================================================

## 生成不定形的粒子云
func _build_cloud_particles() -> void:
	_cloud_container = Node2D.new()
	_cloud_container.name = "CloudContainer"
	
	for i in range(cloud_particle_count):
		var particle := Polygon2D.new()
		
		# 不规则的小型多边形（模拟闪电碎片）
		var vert_count := randi_range(3, 6)
		var points := PackedVector2Array()
		var size := randf_range(2.0, 5.0)
		for v in range(vert_count):
			var angle := (TAU / float(vert_count)) * v + randf_range(-0.3, 0.3)
			var r := size * randf_range(0.5, 1.0)
			points.append(Vector2(cos(angle) * r, sin(angle) * r))
		particle.polygon = points
		
		# 闪电白/蓝色，带随机透明度
		var t := randf()
		particle.color = lightning_color.lerp(arc_color, t)
		particle.color.a = randf_range(0.3, 0.8)
		
		# 存储粒子属性
		particle.set_meta("base_radius", randf_range(8.0, cloud_max_radius))
		particle.set_meta("angle_offset", randf() * TAU)
		particle.set_meta("speed", randf_range(1.0, 3.0))
		particle.set_meta("noise_freq", randf_range(0.5, 2.0))
		particle.set_meta("base_alpha", particle.color.a)
		particle.set_meta("base_size", size)
		
		_cloud_container.add_child(particle)
		_cloud_particles.append(particle)
	
	add_child(_cloud_container)

## 更新粒子云动画（噪声驱动）
func _update_cloud_particles(delta: float) -> void:
	_cloud_phase += delta
	
	# 音乐强度影响粒子行为
	var intensity_factor := lerpf(0.3, 1.5, music_intensity)
	var radius_factor := lerpf(0.6, 1.3, music_intensity)
	
	for i in range(_cloud_particles.size()):
		var particle := _cloud_particles[i]
		if not is_instance_valid(particle):
			continue
		
		var base_r: float = particle.get_meta("base_radius")
		var angle_off: float = particle.get_meta("angle_offset")
		var spd: float = particle.get_meta("speed")
		var noise_f: float = particle.get_meta("noise_freq")
		var base_a: float = particle.get_meta("base_alpha")
		var seed_val: float = _noise_seeds[i] if i < _noise_seeds.size() else 0.0
		
		# 伪噪声位移
		var time := _cloud_phase * spd * intensity_factor
		var noise_x := sin(time * noise_f + seed_val) * cos(time * 0.7 + seed_val * 0.5)
		var noise_y := cos(time * noise_f * 0.8 + seed_val * 1.3) * sin(time * 0.5 + seed_val)
		
		var r := base_r * radius_factor
		var angle := angle_off + time * 0.5
		
		particle.position = Vector2(
			cos(angle) * r + noise_x * r * 0.5,
			sin(angle) * r * 0.8 + noise_y * r * 0.4
		)
		
		# 闪电效果：随机让少量粒子极度明亮
		var flash_chance := 0.005 * intensity_factor
		if randf() < flash_chance:
			particle.color = Color(1.0, 1.0, 1.0, 1.0)
			particle.scale = Vector2(2.0, 2.0)
		else:
			# 正常状态
			var alpha_pulse := sin(time * 3.0 + seed_val) * 0.2 + 0.8
			particle.color.a = base_a * alpha_pulse
			particle.scale = Vector2(1.0, 1.0)
		
		# 蓄力时粒子向核心收缩
		if _fury_state == FuryState.CHARGING:
			var charge_t := _charge_timer / charge_duration
			particle.position *= lerpf(1.0, 0.3, charge_t)
			particle.color = particle.color.lerp(Color.WHITE, charge_t * 0.5)

# ============================================================
# 程序化脉动心脏核心 (Issue #68)
# ============================================================

## 生成脉动心脏核心
func _build_core_visual() -> void:
	_core_visual = Node2D.new()
	_core_visual.name = "CoreVisual"
	
	# 核心光晕（外层）
	_core_glow = Polygon2D.new()
	var glow_points := PackedVector2Array()
	for i in range(24):
		var angle := (TAU / 24.0) * i
		glow_points.append(Vector2(cos(angle), sin(angle)) * core_base_size * 2.0)
	_core_glow.polygon = glow_points
	_core_glow.color = Color(0.6, 0.7, 1.0, 0.15)
	_core_visual.add_child(_core_glow)
	
	# 核心球体
	_core_sphere = Polygon2D.new()
	var sphere_points := PackedVector2Array()
	for i in range(16):
		var angle := (TAU / 16.0) * i
		sphere_points.append(Vector2(cos(angle), sin(angle)) * core_base_size)
	_core_sphere.polygon = sphere_points
	_core_sphere.color = lightning_color
	_core_visual.add_child(_core_sphere)
	
	# 内核亮点
	var inner := Polygon2D.new()
	var inner_points := PackedVector2Array()
	for i in range(8):
		var angle := (TAU / 8.0) * i
		inner_points.append(Vector2(cos(angle), sin(angle)) * core_base_size * 0.4)
	inner.polygon = inner_points
	inner.color = Color(1.0, 1.0, 1.0, 0.9)
	_core_visual.add_child(inner)
	
	add_child(_core_visual)

## 更新核心脉动动画
func _update_core_visual(delta: float) -> void:
	_core_phase += delta * core_pulse_speed * lerpf(0.8, 2.0, music_intensity)
	
	if _core_visual == null:
		return
	
	# 心跳脉动：sin 驱动的缩放
	var heartbeat := sin(_core_phase) * 0.2 + 1.0
	# 双脉冲心跳效果
	var double_beat := max(sin(_core_phase * 2.0) * 0.15, 0.0)
	var total_pulse := heartbeat + double_beat
	
	_core_visual.scale = Vector2(total_pulse, total_pulse)
	
	# 核心颜色随音乐强度变化
	if _core_sphere:
		var intensity_color := lightning_color.lerp(Color(1.0, 0.8, 0.4), music_intensity * 0.5)
		_core_sphere.color = intensity_color
		# 发光强度
		_core_sphere.color.a = lerpf(0.7, 1.0, sin(_core_phase) * 0.5 + 0.5)
	
	# 光晕脉动
	if _core_glow:
		var glow_scale := lerpf(1.0, 1.8, music_intensity)
		_core_glow.scale = Vector2(glow_scale, glow_scale) * (1.0 + sin(_core_phase * 0.5) * 0.1)
		_core_glow.color.a = lerpf(0.1, 0.3, music_intensity)
	
	# 蓄力时核心极度明亮
	if _fury_state == FuryState.CHARGING:
		var charge_t := _charge_timer / charge_duration
		_core_visual.scale *= lerpf(1.0, 1.8, charge_t)
		if _core_sphere:
			_core_sphere.color = _core_sphere.color.lerp(Color.WHITE, charge_t)

# ============================================================
# 程序化闪电触须 (Issue #68)
# ============================================================

## 生成闪电触须
func _build_lightning_tendrils() -> void:
	# 创建 4-6 条闪电触须
	var tendril_count := randi_range(4, 6)
	for i in range(tendril_count):
		var tendril := Line2D.new()
		tendril.name = "LightningTendril_%d" % i
		tendril.width = 2.0
		tendril.default_color = Color(0.7, 0.85, 1.0, 0.7)
		tendril.begin_cap_mode = Line2D.LINE_CAP_ROUND
		tendril.end_cap_mode = Line2D.LINE_CAP_ROUND
		
		# 初始化空点
		for _j in range(8):
			tendril.add_point(Vector2.ZERO)
		
		tendril.set_meta("base_angle", (TAU / tendril_count) * i)
		tendril.set_meta("length", randf_range(20.0, lightning_range * 0.6))
		
		add_child(tendril)
		_lightning_tendrils.append(tendril)

## 更新闪电触须（程序化分形闪电）
func _update_lightning_tendrils(delta: float) -> void:
	_lightning_timer += delta
	
	# 闪电刷新频率随音乐强度增加
	var refresh_interval := lerpf(0.15, 0.04, music_intensity)
	
	if _lightning_timer < refresh_interval:
		return
	_lightning_timer = 0.0
	
	for tendril in _lightning_tendrils:
		if not is_instance_valid(tendril):
			continue
		
		var base_angle: float = tendril.get_meta("base_angle")
		var length: float = tendril.get_meta("length")
		
		# 音乐强度影响触须长度和活跃度
		var active_length := length * lerpf(0.3, 1.2, music_intensity)
		
		# 低强度时触须可能消失
		if music_intensity < 0.3 and randf() > music_intensity * 3.0:
			tendril.visible = false
			continue
		tendril.visible = true
		
		# 生成分形闪电路径
		var point_count := tendril.get_point_count()
		var current_angle := base_angle + randf_range(-0.5, 0.5) * music_intensity
		
		for j in range(point_count):
			var t := float(j) / float(point_count - 1)
			var segment_length := active_length * t
			
			# 闪电的锯齿偏移
			var jitter := randf_range(-8.0, 8.0) * music_intensity * (1.0 - t * 0.5)
			var perpendicular := Vector2(-sin(current_angle), cos(current_angle))
			
			var point := Vector2.from_angle(current_angle) * segment_length + perpendicular * jitter
			tendril.set_point_position(j, point)
		
		# 触须颜色随强度变化
		var alpha := lerpf(0.3, 0.9, music_intensity)
		tendril.default_color = Color(0.7, 0.85, 1.0, alpha)
		tendril.width = lerpf(1.0, 3.0, music_intensity)
		
		# 蓄力时触须收缩并变亮
		if _fury_state == FuryState.CHARGING:
			var charge_t := _charge_timer / charge_duration
			tendril.default_color = Color(1.0, 1.0, 1.0, alpha * (1.0 + charge_t))
			tendril.width = lerpf(1.0, 4.0, charge_t)

# ============================================================
# 音乐强度集成 (Issue #68)
# ============================================================

## 从 AudioManager 获取音乐强度
func _update_music_intensity() -> void:
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("get_music_intensity"):
		music_intensity = audio_mgr.get_music_intensity()
	elif audio_mgr and "music_intensity" in audio_mgr:
		music_intensity = audio_mgr.music_intensity
	# 如果没有 AudioManager，使用基于时间的模拟
	else:
		music_intensity = sin(Time.get_ticks_msec() * 0.001 * 0.5) * 0.3 + 0.5

# ============================================================
# 每帧逻辑
# ============================================================

func _on_enemy_process(delta: float) -> void:
	# 更新音乐强度
	_update_music_intensity()
	
	# 更新程序化视觉
	_update_cloud_particles(delta)
	_update_core_visual(delta)
	_update_lightning_tendrils(delta)
	_update_arc_trails(delta)
	
	# 闪电触须冷却
	if _lightning_cooldown > 0.0:
		_lightning_cooldown -= delta
	
	# 状态机
	match _fury_state:
		FuryState.IDLE:
			pass  # 正常移动
		
		FuryState.CHARGING:
			_charge_timer += delta
			if _charge_timer >= charge_duration:
				_start_dash()
		
		FuryState.DASHING:
			_dash_timer -= delta
			if _dash_timer <= 0.0:
				_end_dash()
		
		FuryState.RECOVERING:
			_recovery_timer -= delta
			if _recovery_timer <= 0.0:
				_fury_state = FuryState.IDLE

# ============================================================
# 移动逻辑
# ============================================================

func _calculate_movement_direction() -> Vector2:
	if _target == null:
		return Vector2.ZERO
	
	match _fury_state:
		FuryState.IDLE:
			# 不规则的追踪，带有噪声偏移
			var dir := (_target.global_position - global_position).normalized()
			var noise_offset := Vector2(
				sin(Time.get_ticks_msec() * 0.003) * 0.4,
				cos(Time.get_ticks_msec() * 0.004) * 0.4
			) * music_intensity
			return (dir + noise_offset).normalized()
		
		FuryState.CHARGING:
			return Vector2.ZERO  # 蓄力时不移动
		
		FuryState.DASHING:
			# 冲刺方向
			velocity = _dash_direction * move_speed * dash_speed_multiplier
			move_and_slide()
			_spawn_arc_trail()
			return Vector2.ZERO
		
		FuryState.RECOVERING:
			return Vector2.ZERO
	
	return Vector2.ZERO

# ============================================================
# 攻击系统
# ============================================================

## 开始蓄力
func _start_charge() -> void:
	_fury_state = FuryState.CHARGING
	_charge_timer = 0.0
	
	# 蓄力视觉：粒子收缩，核心变亮
	if _cloud_container:
		var tween := create_tween()
		tween.tween_property(_cloud_container, "modulate", Color(1.5, 1.5, 2.0), charge_duration)

## 开始冲刺
func _start_dash() -> void:
	# OPT03: 攻击时触发音高层
	if _audio_controller:
		_audio_controller.play_behavior_pitch("attack")
	_fury_state = FuryState.DASHING
	_dash_timer = dash_duration
	
	if _target:
		_dash_direction = (global_position.direction_to(_target.global_position))
	else:
		_dash_direction = Vector2.RIGHT
	
	# 冲刺视觉：全身闪白
	if _cloud_container:
		_cloud_container.modulate = Color.WHITE
	
	# 释放闪电伤害
	_fire_lightning_burst()

## 结束冲刺
func _end_dash() -> void:
	_fury_state = FuryState.RECOVERING
	_recovery_timer = 1.0
	
	# 恢复视觉
	if _cloud_container:
		var tween := create_tween()
		tween.tween_property(_cloud_container, "modulate", Color.WHITE, 0.5)

## 释放闪电爆发
func _fire_lightning_burst() -> void:
	if _target == null:
		return
	
	# OPT03: 攻击时触发音高层
	if _audio_controller:
		_audio_controller.play_behavior_pitch("attack")
	var dist := global_position.distance_to(_target.global_position)
	if dist < lightning_range:
		if _target.has_method("take_damage"):
			_target.take_damage(lightning_damage)
	
	# 闪电爆发视觉
	var burst := Polygon2D.new()
	var points := PackedVector2Array()
	for i in range(16):
		var angle := (TAU / 16.0) * i
		var r := 5.0 + randf_range(0, 15.0)
		points.append(Vector2(cos(angle) * r, sin(angle) * r))
	burst.polygon = points
	burst.color = Color(1.0, 1.0, 1.0, 0.9)
	burst.global_position = global_position
	get_parent().add_child(burst)
	
	var tween := burst.create_tween()
	tween.set_parallel(true)
	tween.tween_property(burst, "scale", Vector2(4.0, 4.0), 0.2)
	tween.tween_property(burst, "modulate:a", 0.0, 0.3)
	tween.chain()
	tween.tween_callback(burst.queue_free)

# ============================================================
# 电弧轨迹系统 (Issue #68)
# ============================================================

## 生成电弧轨迹段
func _spawn_arc_trail() -> void:
	var trail := Line2D.new()
	trail.width = 3.0
	trail.default_color = arc_color
	
	# 生成短闪电段
	var seg_count := 6
	for i in range(seg_count):
		var t := float(i) / float(seg_count - 1)
		var jitter := Vector2(randf_range(-6, 6), randf_range(-6, 6))
		trail.add_point(jitter)
	
	trail.global_position = global_position
	get_parent().add_child(trail)
	
	_arc_trails.append({
		"node": trail,
		"timer": arc_trail_duration,
		"position": global_position,
	})

## 更新电弧轨迹
func _update_arc_trails(delta: float) -> void:
	var expired: Array[int] = []
	
	for i in range(_arc_trails.size()):
		var trail := _arc_trails[i]
		trail["timer"] -= delta
		
		if trail["timer"] <= 0.0:
			expired.append(i)
			if is_instance_valid(trail["node"]):
				trail["node"].queue_free()
		else:
			# 轨迹伤害
			if _target and is_instance_valid(_target):
				var dist := _target.global_position.distance_to(trail["position"])
				if dist < 25.0:
					if _target.has_method("take_damage"):
						_target.take_damage(arc_trail_dps * delta)
			
			# 淡出 + 闪烁
			if is_instance_valid(trail["node"]):
				var fade := trail["timer"] / arc_trail_duration
				trail["node"].modulate.a = fade * (0.7 + randf() * 0.3)
				# 随机重新生成闪电形状
				if randf() < 0.1:
					_refresh_arc_trail_shape(trail["node"])
	
	# 移除过期轨迹
	for i in range(expired.size() - 1, -1, -1):
		_arc_trails.remove_at(expired[i])

## 刷新电弧轨迹的闪电形状
func _refresh_arc_trail_shape(trail: Line2D) -> void:
	for i in range(trail.get_point_count()):
		var jitter := Vector2(randf_range(-8, 8), randf_range(-8, 8))
		trail.set_point_position(i, jitter)

# ============================================================
# 节拍响应
# ============================================================

func _on_beat(_beat_index: int) -> void:
	_attack_beat_counter += 1
	
	# 每 4 拍发起一次蓄力-冲刺攻击
	if _attack_beat_counter % 4 == 0 and _fury_state == FuryState.IDLE:
		_start_charge()
	
	# 节拍时闪电触须闪烁
	for tendril in _lightning_tendrils:
		if is_instance_valid(tendril):
			tendril.default_color = Color(1.0, 1.0, 1.0, 0.95)
	
	# 核心强脉冲
	if _core_visual:
		var tween := create_tween()
		tween.tween_property(_core_visual, "scale", Vector2(1.5, 1.5), 0.05)
		tween.tween_property(_core_visual, "scale", Vector2(1.0, 1.0), 0.15)

# ============================================================
# 伤害处理
# ============================================================

func take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO, is_perfect_beat: bool = false) -> void:
	super.take_damage(amount, knockback_dir, is_perfect_beat)
	
	# 受击时闪电爆发
	if _cloud_container:
		_cloud_container.modulate = Color(2.0, 2.0, 2.0)
		var tween := create_tween()
		tween.tween_property(_cloud_container, "modulate", Color.WHITE, 0.2)

# ============================================================
# 死亡效果
# ============================================================

func _on_death_effect() -> void:
	# 死亡时释放大范围闪电爆发
	_fire_lightning_burst()
	
	# 粒子四散
	for particle in _cloud_particles:
		if is_instance_valid(particle):
			var dir := Vector2.from_angle(randf() * TAU)
			var speed := randf_range(80.0, 200.0)
			var target_pos := particle.global_position + dir * speed
			
			# 重新设置为全局坐标
			var global_pos := particle.global_position
			particle.get_parent().remove_child(particle)
			get_parent().add_child(particle)
			particle.global_position = global_pos
			
			var tween := particle.create_tween()
			tween.set_parallel(true)
			tween.tween_property(particle, "global_position", target_pos, 0.5)
			tween.tween_property(particle, "modulate:a", 0.0, 0.5)
			tween.chain()
			tween.tween_callback(particle.queue_free)
	_cloud_particles.clear()
	
	# 清理电弧轨迹
	for trail in _arc_trails:
		if is_instance_valid(trail["node"]):
			trail["node"].queue_free()
	_arc_trails.clear()

func _get_type_name() -> String:
	return "ch5_fury_spirit"
