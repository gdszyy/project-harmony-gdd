## ch4_minuet_dancer.gd
## 第四章特色敌人：小步舞曲舞者 (Minuet Dancer)
## 永远成对出现，移动轨迹保持完美的镜像对称。
## 音乐隐喻：古典主义的对称之美，莫扎特宫廷舞会的优雅。
##
## 程序化视觉实现 (Issue #67):
## - 洛可可风格烛台几何体 (Polygon2D 程序化生成)
## - 镜像对称移动AI (领舞/跟舞 manager 模式)
## - 旋风光粒子VFX (旋转攻击时隐藏几何体，激活粒子旋风)
##
## 机制：
## - 成对镜像对称移动
## - 攻击严格遵循3/4拍
## - 每小节第一拍进行旋转（短暂无敌帧 + 光粒子旋风）
## - 击杀一个后另一个狂暴
extends "res://scripts/entities/enemy_base.gd"

# ============================================================
# Minuet Dancer 专属配置
# ============================================================

## 舞伴引用
var dance_partner: Node2D = null
## 是否为"领舞"（另一个为"跟舞"，镜像移动）
@export var is_lead: bool = true
## 镜像轴（垂直于此轴镜像）
var mirror_axis: Vector2 = Vector2.UP
## 镜像中心点
var mirror_center: Vector2 = Vector2.ZERO

## 旋转无敌帧持续时间
@export var spin_invincibility_duration: float = 0.4
## 3/4拍攻击伤害
@export var waltz_attack_damage: float = 10.0
## 弹幕速度
@export var waltz_projectile_speed: float = 180.0
## 狂暴速度倍率
@export var rage_speed_multiplier: float = 2.0
## 狂暴伤害倍率
@export var rage_damage_multiplier: float = 1.8

## === 程序化视觉配置 (Issue #67) ===
## 烛台几何体缩放
@export var candlestick_scale: float = 1.0
## 旋风粒子数量
@export var vortex_particle_count: int = 24
## 旋风粒子最大半径
@export var vortex_max_radius: float = 40.0
## 旋风粒子颜色
@export var vortex_color: Color = Color(1.0, 0.92, 0.6, 0.9)  # 金色光屑

# ============================================================
# 内部状态
# ============================================================

var _waltz_beat_counter: int = 0  # 3/4拍计数 (0,1,2)
var _is_spinning: bool = false
var _spin_timer: float = 0.0
var _is_invincible: bool = false
var _partner_dead: bool = false
var _is_enraged: bool = false

## 舞步相位
var _dance_phase: float = 0.0
## 旋转角度
var _spin_angle: float = 0.0

## === 程序化视觉节点 (Issue #67) ===
var _candlestick_visual: Node2D = null      # 烛台几何体容器
var _candlestick_body: Polygon2D = null     # 烛台主体
var _candlestick_flame: Polygon2D = null    # 烛台火焰
var _candlestick_ornaments: Array[Polygon2D] = []  # 装饰卷曲
var _vortex_particles: Array[Node2D] = []   # 旋风粒子节点
var _vortex_container: Node2D = null        # 旋风容器
var _is_vortex_active: bool = false         # 旋风是否激活
var _vortex_phase: float = 0.0             # 旋风旋转相位
var _flame_phase: float = 0.0             # 火焰动画相位
var _connection_line: Line2D = null        # 舞伴连接线

# ============================================================
# 初始化
# ============================================================

func _on_enemy_ready() -> void:
	enemy_type = EnemyType.STATIC
	quantized_fps = 12.0
	_quantize_interval = 1.0 / quantized_fps
	knockback_resistance = 0.2
	move_on_offbeat = false
	
	# 洛可可粉白色调 — 领舞银白，跟舞淡金
	base_color = Color(0.95, 0.88, 0.92) if is_lead else Color(0.92, 0.88, 0.78)
	base_glitch_intensity = 0.03
	max_glitch_intensity = 0.4
	
	# 生成程序化烛台几何体
	_build_candlestick_geometry()
	# 创建旋风粒子系统
	_build_vortex_particles()
	# 创建舞伴连接线
	_build_connection_line()

# ============================================================
# 程序化洛可可烛台几何体 (Issue #67)
# ============================================================

## 生成洛可可风格烛台的程序化几何体
## 烛台由底座、柱身、装饰卷曲、火焰四部分组成
func _build_candlestick_geometry() -> void:
	_candlestick_visual = Node2D.new()
	_candlestick_visual.name = "CandlestickVisual"
	
	# --- 1. 底座 (宽椭圆形) ---
	var base_poly := Polygon2D.new()
	var base_points := PackedVector2Array()
	for i in range(16):
		var angle := (TAU / 16.0) * i
		var rx := 10.0 * candlestick_scale
		var ry := 4.0 * candlestick_scale
		base_points.append(Vector2(cos(angle) * rx, sin(angle) * ry + 14.0 * candlestick_scale))
	base_poly.polygon = base_points
	base_poly.color = base_color.darkened(0.2)
	_candlestick_visual.add_child(base_poly)
	
	# --- 2. 柱身 (优雅的收腰曲线) ---
	_candlestick_body = Polygon2D.new()
	var body_points := PackedVector2Array()
	# 右侧轮廓 (从底到顶)
	var right_profile: Array[Vector2] = []
	var left_profile: Array[Vector2] = []
	var steps := 20
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var y := lerpf(14.0, -16.0, t) * candlestick_scale
		# 洛可可曲线：底部宽，中间收腰，顶部略宽（杯形）
		var width: float
		if t < 0.15:
			# 底座过渡
			width = lerpf(8.0, 4.0, t / 0.15)
		elif t < 0.5:
			# 收腰
			var st := (t - 0.15) / 0.35
			width = lerpf(4.0, 2.5, st) + sin(st * PI) * 1.5
		elif t < 0.8:
			# 展开（杯形）
			var st := (t - 0.5) / 0.3
			width = lerpf(2.5, 5.0, st)
		else:
			# 顶部收口
			var st := (t - 0.8) / 0.2
			width = lerpf(5.0, 3.0, st)
		width *= candlestick_scale
		right_profile.append(Vector2(width, y))
		left_profile.append(Vector2(-width, y))
	
	# 组合轮廓
	for p in right_profile:
		body_points.append(p)
	left_profile.reverse()
	for p in left_profile:
		body_points.append(p)
	
	_candlestick_body.polygon = body_points
	_candlestick_body.color = base_color
	_candlestick_visual.add_child(_candlestick_body)
	
	# --- 3. 装饰卷曲 (Rococo Scrollwork) ---
	_build_rococo_ornaments()
	
	# --- 4. 火焰 (顶部的发光火焰) ---
	_candlestick_flame = Polygon2D.new()
	var flame_points := PackedVector2Array()
	flame_points.append(Vector2(0, -24.0 * candlestick_scale))  # 顶点
	flame_points.append(Vector2(-3.0 * candlestick_scale, -16.0 * candlestick_scale))
	flame_points.append(Vector2(-1.5 * candlestick_scale, -18.0 * candlestick_scale))
	flame_points.append(Vector2(0, -14.0 * candlestick_scale))
	flame_points.append(Vector2(1.5 * candlestick_scale, -18.0 * candlestick_scale))
	flame_points.append(Vector2(3.0 * candlestick_scale, -16.0 * candlestick_scale))
	_candlestick_flame.polygon = flame_points
	_candlestick_flame.color = Color(1.0, 0.92, 0.5, 0.95)  # 金色火焰
	_candlestick_visual.add_child(_candlestick_flame)
	
	# 火焰光晕
	var glow := Polygon2D.new()
	var glow_points := PackedVector2Array()
	for i in range(12):
		var angle := (TAU / 12.0) * i
		glow_points.append(Vector2(cos(angle) * 6.0, sin(angle) * 6.0 - 19.0) * candlestick_scale)
	glow.polygon = glow_points
	glow.color = Color(1.0, 0.95, 0.7, 0.25)
	_candlestick_visual.add_child(glow)
	
	add_child(_candlestick_visual)

## 生成洛可可风格的装饰卷曲
func _build_rococo_ornaments() -> void:
	_candlestick_ornaments.clear()
	
	# 左右对称的C形卷曲装饰
	for side in [-1.0, 1.0]:
		var ornament := Polygon2D.new()
		var points := PackedVector2Array()
		
		# C形卷曲曲线
		var segments := 12
		for i in range(segments + 1):
			var t := float(i) / float(segments)
			var angle := t * PI * 1.2 - PI * 0.1
			var r := (3.0 + sin(t * PI) * 2.0) * candlestick_scale
			var x := cos(angle) * r * side + side * 4.0 * candlestick_scale
			var y := sin(angle) * r * 0.6 + 2.0 * candlestick_scale
			points.append(Vector2(x, y))
		
		# 回程（内侧，更窄）
		for i in range(segments, -1, -1):
			var t := float(i) / float(segments)
			var angle := t * PI * 1.2 - PI * 0.1
			var r := (1.5 + sin(t * PI) * 1.0) * candlestick_scale
			var x := cos(angle) * r * side + side * 4.0 * candlestick_scale
			var y := sin(angle) * r * 0.6 + 2.0 * candlestick_scale
			points.append(Vector2(x, y))
		
		ornament.polygon = points
		ornament.color = base_color.lightened(0.15)
		_candlestick_visual.add_child(ornament)
		_candlestick_ornaments.append(ornament)
	
	# 顶部小花饰
	var top_ornament := Polygon2D.new()
	var top_points := PackedVector2Array()
	for i in range(6):
		var angle := (TAU / 6.0) * i
		var r := 2.0 * candlestick_scale
		if i % 2 == 0:
			r = 3.5 * candlestick_scale
		top_points.append(Vector2(cos(angle) * r, sin(angle) * r - 14.5 * candlestick_scale))
	top_ornament.polygon = top_points
	top_ornament.color = base_color.lightened(0.25)
	_candlestick_visual.add_child(top_ornament)
	_candlestick_ornaments.append(top_ornament)

# ============================================================
# 旋风光粒子系统 (Issue #67)
# ============================================================

## 创建旋风粒子系统
## 旋转攻击时，隐藏烛台几何体，激活金色光屑旋风
func _build_vortex_particles() -> void:
	_vortex_container = Node2D.new()
	_vortex_container.name = "VortexContainer"
	_vortex_container.visible = false
	
	for i in range(vortex_particle_count):
		var particle := Polygon2D.new()
		# 小型菱形光粒子
		var size := randf_range(1.5, 3.5)
		particle.polygon = PackedVector2Array([
			Vector2(0, -size), Vector2(size * 0.6, 0),
			Vector2(0, size), Vector2(-size * 0.6, 0)
		])
		# 金色光屑，带随机亮度变化
		var brightness := randf_range(0.7, 1.0)
		particle.color = Color(
			vortex_color.r * brightness,
			vortex_color.g * brightness,
			vortex_color.b * brightness,
			vortex_color.a * randf_range(0.5, 1.0)
		)
		# 随机初始位置（极坐标）
		particle.set_meta("orbit_radius", randf_range(5.0, vortex_max_radius))
		particle.set_meta("orbit_speed", randf_range(8.0, 16.0))
		particle.set_meta("orbit_offset", randf() * TAU)
		particle.set_meta("vertical_speed", randf_range(-30.0, 30.0))
		particle.set_meta("base_alpha", particle.color.a)
		
		_vortex_container.add_child(particle)
		_vortex_particles.append(particle)
	
	add_child(_vortex_container)

## 更新旋风粒子动画
func _update_vortex_particles(delta: float) -> void:
	if not _is_vortex_active:
		return
	
	_vortex_phase += delta
	
	for particle in _vortex_particles:
		if not is_instance_valid(particle):
			continue
		
		var orbit_r: float = particle.get_meta("orbit_radius")
		var orbit_spd: float = particle.get_meta("orbit_speed")
		var orbit_off: float = particle.get_meta("orbit_offset")
		var vert_spd: float = particle.get_meta("vertical_speed")
		var base_a: float = particle.get_meta("base_alpha")
		
		# 螺旋运动：半径随时间收缩再展开
		var time_factor := sin(_vortex_phase * 3.0) * 0.3 + 0.7
		var current_r := orbit_r * time_factor
		var angle := _vortex_phase * orbit_spd + orbit_off
		
		particle.position = Vector2(
			cos(angle) * current_r,
			sin(angle) * current_r * 0.6 + sin(_vortex_phase * vert_spd * 0.1) * 8.0
		)
		
		# 旋转粒子自身
		particle.rotation = angle + PI * 0.25
		
		# 闪烁效果
		var flicker := sin(_vortex_phase * 12.0 + orbit_off * 5.0) * 0.3 + 0.7
		particle.color.a = base_a * flicker
		
		# 缩放脉冲
		var pulse := 1.0 + sin(_vortex_phase * 6.0 + orbit_off) * 0.3
		particle.scale = Vector2(pulse, pulse)

## 激活旋风效果
func _activate_vortex() -> void:
	_is_vortex_active = true
	_vortex_phase = 0.0
	
	# 隐藏烛台几何体
	if _candlestick_visual:
		_candlestick_visual.visible = false
	
	# 显示旋风粒子
	if _vortex_container:
		_vortex_container.visible = true

## 停用旋风效果
func _deactivate_vortex() -> void:
	_is_vortex_active = false
	
	# 显示烛台几何体
	if _candlestick_visual:
		_candlestick_visual.visible = true
	
	# 隐藏旋风粒子
	if _vortex_container:
		_vortex_container.visible = false

# ============================================================
# 舞伴连接线 (Issue #67)
# ============================================================

## 创建舞伴之间的优雅连接线
func _build_connection_line() -> void:
	_connection_line = Line2D.new()
	_connection_line.name = "ConnectionLine"
	_connection_line.width = 1.5
	_connection_line.default_color = Color(1.0, 0.95, 0.8, 0.3)
	_connection_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_connection_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	# 仅领舞绘制连接线
	if is_lead:
		add_child(_connection_line)

## 更新舞伴连接线
func _update_connection_line() -> void:
	if not is_lead or _connection_line == null:
		return
	if not dance_partner or not is_instance_valid(dance_partner):
		_connection_line.visible = false
		return
	
	_connection_line.visible = true
	_connection_line.clear_points()
	
	# 优雅的贝塞尔曲线连接
	var start := Vector2.ZERO  # 自身位置（局部坐标）
	var end := dance_partner.global_position - global_position
	var mid := (start + end) * 0.5 + Vector2(0, -20.0 - sin(_dance_phase) * 10.0)
	
	var segments := 16
	for i in range(segments + 1):
		var t := float(i) / float(segments)
		# 二次贝塞尔曲线
		var p := (1.0 - t) * (1.0 - t) * start + 2.0 * (1.0 - t) * t * mid + t * t * end
		_connection_line.add_point(p)
	
	# 连接线随舞步脉动
	var pulse := sin(_dance_phase * 2.0) * 0.15 + 0.85
	_connection_line.default_color.a = 0.3 * pulse

# ============================================================
# 舞伴设置
# ============================================================

func setup_partner(partner: Node2D, lead: bool) -> void:
	dance_partner = partner
	is_lead = lead
	base_color = Color(0.95, 0.88, 0.92) if is_lead else Color(0.92, 0.88, 0.78)
	# 更新烛台颜色
	if _candlestick_body:
		_candlestick_body.color = base_color

# ============================================================
# 每帧逻辑
# ============================================================

func _on_enemy_process(delta: float) -> void:
	_dance_phase += delta * 2.5
	_flame_phase += delta * 4.0
	
	# 旋转无敌帧 + 旋风
	if _is_spinning:
		_spin_timer -= delta
		_spin_angle += delta * 15.0
		
		# 旋风粒子更新
		_update_vortex_particles(delta)
		
		if _spin_timer <= 0.0:
			_is_spinning = false
			_is_invincible = false
			_spin_angle = 0.0
			_deactivate_vortex()
	
	# 烛台视觉动画
	if _candlestick_visual and _candlestick_visual.visible:
		# 优雅的摇摆
		var sway := sin(_dance_phase) * 3.0
		_candlestick_visual.position.x = sway
		_candlestick_visual.rotation = sin(_dance_phase * 0.7) * 0.08
		
		# 火焰动画
		_update_flame_animation(delta)
		
		# 装饰卷曲微动
		_update_ornament_animation(delta)
		
		# 狂暴视觉
		if _is_enraged:
			var rage_flash := sin(Time.get_ticks_msec() * 0.01) * 0.3
			var rage_color := base_color.lerp(Color(1.0, 0.2, 0.2), 0.3 + rage_flash)
			if _candlestick_body:
				_candlestick_body.color = rage_color
	
	# 更新舞伴连接线
	_update_connection_line()
	
	# 检查舞伴状态
	if dance_partner and not is_instance_valid(dance_partner):
		if not _partner_dead:
			_on_partner_death()

## 更新火焰动画
func _update_flame_animation(delta: float) -> void:
	if _candlestick_flame == null:
		return
	
	# 火焰闪烁与形变
	var flicker := sin(_flame_phase) * 0.15 + sin(_flame_phase * 2.3) * 0.1
	_candlestick_flame.scale = Vector2(1.0 + flicker, 1.0 + flicker * 1.5)
	_candlestick_flame.position.x = sin(_flame_phase * 1.7) * 1.0
	
	# 火焰颜色脉动
	var color_pulse := sin(_flame_phase * 0.8) * 0.5 + 0.5
	_candlestick_flame.color = Color(
		1.0,
		lerpf(0.85, 0.95, color_pulse),
		lerpf(0.3, 0.6, color_pulse),
		0.95
	)

## 更新装饰卷曲微动
func _update_ornament_animation(_delta: float) -> void:
	for i in range(_candlestick_ornaments.size()):
		var ornament := _candlestick_ornaments[i]
		if not is_instance_valid(ornament):
			continue
		# 每个装饰以不同相位轻微摇摆
		var phase_offset := float(i) * 1.5
		ornament.rotation = sin(_dance_phase * 1.2 + phase_offset) * 0.05

# ============================================================
# 移动逻辑：镜像对称 (Issue #67 增强)
# ============================================================

func _calculate_movement_direction() -> Vector2:
	if _target == null:
		return Vector2.ZERO
	
	if is_lead or _partner_dead:
		# 领舞/失伴：追踪玩家，加入优雅的华尔兹弧线
		var dir := (_target.global_position - global_position).normalized()
		# 3/4拍的圆弧运动
		var waltz_curve := sin(_dance_phase * 0.7) * 0.35
		# 加入轻微的螺旋趋近
		var spiral := cos(_dance_phase * 0.3) * 0.15
		return dir.rotated(waltz_curve + spiral)
	else:
		# 跟舞：精确镜像领舞的位置
		if dance_partner and is_instance_valid(dance_partner):
			# 计算以玩家为中心的镜像
			if _target:
				var center := _target.global_position
				var partner_offset := dance_partner.global_position - center
				# 关于中心点的水平镜像
				var mirrored_pos := center + Vector2(-partner_offset.x, partner_offset.y)
				var dir := (mirrored_pos - global_position).normalized()
				return dir
		
		return (_target.global_position - global_position).normalized()

# ============================================================
# 伤害处理：旋转时无敌
# ============================================================

func take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO, is_perfect_beat: bool = false) -> void:
	if _is_invincible:
		# 旋转无敌帧 — 旋风粒子闪烁提示
		if _vortex_container and _vortex_container.visible:
			for particle in _vortex_particles:
				if is_instance_valid(particle):
					particle.color = Color.WHITE
			# 短暂闪白后恢复
			var tween := create_tween()
			tween.tween_interval(0.05)
			tween.tween_callback(_restore_vortex_colors)
		return
	
	super.take_damage(amount, knockback_dir, is_perfect_beat)

## 恢复旋风粒子颜色
func _restore_vortex_colors() -> void:
	for particle in _vortex_particles:
		if is_instance_valid(particle):
			var base_a: float = particle.get_meta("base_alpha")
			particle.color = Color(
				vortex_color.r, vortex_color.g, vortex_color.b, base_a
			)

# ============================================================
# 节拍响应：3/4拍攻击
# ============================================================

func _on_beat(_beat_index: int) -> void:
	_waltz_beat_counter = (_waltz_beat_counter + 1) % 3
	
	match _waltz_beat_counter:
		0:
			# 第一拍（强拍）：旋转 + 无敌帧 + 旋风VFX
			_start_spin()
		1:
			# 第二拍：发射弹幕
			_waltz_attack()
		2:
			# 第三拍：轻拍脉冲 — 烛台火焰闪耀
			if _candlestick_flame:
				var tween := create_tween()
				tween.tween_property(_candlestick_flame, "scale", Vector2(1.5, 2.0), 0.05)
				tween.tween_property(_candlestick_flame, "scale", Vector2(1.0, 1.0), 0.1)

func _start_spin() -> void:
	_is_spinning = true
	_is_invincible = true
	_spin_timer = spin_invincibility_duration
	_spin_angle = 0.0
	
	# 激活旋风光粒子VFX
	_activate_vortex()
	
	# 旋风展开动画
	if _vortex_container:
		_vortex_container.scale = Vector2(0.3, 0.3)
		var tween := create_tween()
		tween.tween_property(_vortex_container, "scale", Vector2(1.0, 1.0), 0.15)

func _waltz_attack() -> void:
	if _target == null:
		return
	
	var angle := (global_position.direction_to(_target.global_position)).angle()
	var damage := waltz_attack_damage
	if _is_enraged:
		damage *= rage_damage_multiplier
	
	# 发射优雅的弧线弹幕（金色光屑风格）
	for i in range(3):
		var offset_angle := angle + (i - 1) * 0.25
		_spawn_waltz_projectile(offset_angle, damage)

func _spawn_waltz_projectile(angle: float, damage: float) -> void:
	var proj := Area2D.new()
	proj.add_to_group("enemy_projectiles")
	
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 4.0
	col.shape = shape
	proj.add_child(col)
	
	# 优雅的菱形弹体（与旋风粒子风格一致）
	var visual := Polygon2D.new()
	var points := PackedVector2Array([
		Vector2(0, -5), Vector2(3, 0), Vector2(0, 5), Vector2(-3, 0)
	])
	visual.polygon = points
	visual.color = vortex_color.lerp(Color.WHITE, 0.3)
	proj.add_child(visual)
	
	# 弹体拖尾
	var trail := Line2D.new()
	trail.width = 2.0
	trail.default_color = Color(vortex_color.r, vortex_color.g, vortex_color.b, 0.4)
	trail.add_point(Vector2.ZERO)
	trail.add_point(Vector2.ZERO)
	proj.add_child(trail)
	
	proj.global_position = global_position
	get_parent().add_child(proj)
	
	var vel := Vector2.from_angle(angle) * waltz_projectile_speed
	var start_pos := proj.global_position
	var tween := proj.create_tween()
	tween.tween_property(proj, "global_position",
		proj.global_position + vel * 2.5, 2.5)
	tween.tween_callback(proj.queue_free)
	
	# 弹体旋转
	var rot_tween := proj.create_tween()
	rot_tween.set_loops()
	rot_tween.tween_property(visual, "rotation", TAU, 0.5).as_relative()
	
	proj.body_entered.connect(func(body: Node2D):
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(damage)
			proj.queue_free()
	)

# ============================================================
# 舞伴死亡：狂暴
# ============================================================

func _on_partner_death() -> void:
	_partner_dead = true
	_is_enraged = true
	
	# 狂暴效果
	move_speed *= rage_speed_multiplier
	contact_damage *= rage_damage_multiplier
	
	base_color = Color(1.0, 0.3, 0.3)
	
	# 狂暴视觉爆发
	if _candlestick_visual:
		var tween := create_tween()
		tween.tween_property(_candlestick_visual, "modulate", Color.WHITE, 0.15)
		tween.tween_property(_candlestick_visual, "scale", Vector2(1.5, 1.5), 0.15)
		tween.tween_property(_candlestick_visual, "modulate", Color(1.0, 0.5, 0.5), 0.3)
		tween.tween_property(_candlestick_visual, "scale", Vector2(1.0, 1.0), 0.3)
	
	# 火焰变为红色
	if _candlestick_flame:
		_candlestick_flame.color = Color(1.0, 0.3, 0.1, 0.95)
	
	# 旋风粒子变为红色
	vortex_color = Color(1.0, 0.3, 0.2, 0.9)

# ============================================================
# 死亡效果
# ============================================================

func _on_death_effect() -> void:
	# 通知舞伴
	if dance_partner and is_instance_valid(dance_partner):
		if dance_partner.has_method("_on_partner_death"):
			dance_partner._on_partner_death()
	
	# 死亡时释放一圈金色光屑
	_spawn_death_particles()

## 死亡时的金色光屑爆散效果
func _spawn_death_particles() -> void:
	var particle_count := 16
	for i in range(particle_count):
		var particle := Polygon2D.new()
		var size := randf_range(1.5, 3.0)
		particle.polygon = PackedVector2Array([
			Vector2(0, -size), Vector2(size * 0.6, 0),
			Vector2(0, size), Vector2(-size * 0.6, 0)
		])
		particle.color = vortex_color
		particle.global_position = global_position
		get_parent().add_child(particle)
		
		var angle := (TAU / particle_count) * i + randf_range(-0.2, 0.2)
		var speed := randf_range(60.0, 120.0)
		var target_pos := particle.global_position + Vector2.from_angle(angle) * speed
		
		var tween := particle.create_tween()
		tween.set_parallel(true)
		tween.tween_property(particle, "global_position", target_pos, 0.6)
		tween.tween_property(particle, "modulate:a", 0.0, 0.6)
		tween.tween_property(particle, "rotation", randf_range(-TAU, TAU), 0.6)
		tween.chain()
		tween.tween_callback(particle.queue_free)

func _get_type_name() -> String:
	return "ch4_minuet_dancer"
