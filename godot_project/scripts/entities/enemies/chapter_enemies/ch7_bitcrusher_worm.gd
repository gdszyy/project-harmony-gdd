## ch7_bitcrusher_worm.gd
## 第七章特色敌人：比特破碎虫 (Bit-Crushing Worm)
## Issue #70: 使用纯程序化技术实现的蠕虫状敌人
##
## 设计概要：
## - 蠕虫由多个像素块段组成，各段分辨率不同
## - 经过的地面会被"降采样腐蚀"
## - 身体段数随时间增长
## - 头部发射"量化噪音"弹幕
## - 被击中时身体段会断裂
##
## 技术实现 (Issue #70 Checklist):
## 1. 分段身体运动 — MeshInstance3D 链式跟随 (2D 模式下使用 Polygon2D 链)
## 2. 多分辨率块着色器 — bitcrush_worm_body.gdshader
## 3. 地面腐蚀交互 — 通过 RenderingServer 全局着色器参数
extends "res://scripts/entities/enemy_base.gd"

# ============================================================
# Bit-Crushing Worm 专属配置
# ============================================================

## 身体段数
@export var initial_segments: int = 4
## 最大身体段数
@export var max_segments: int = 10
## 段生长间隔
@export var growth_interval: float = 6.0
## 降采样区域半径
@export var bitcrush_radius: float = 40.0
## 降采样区域持续时间
@export var bitcrush_duration: float = 4.0
## 降采样伤害减免比例
@export var bitcrush_damage_reduction: float = 0.4
## 量化噪音弹幕伤害
@export var noise_damage: float = 10.0
## 量化噪音弹幕速度
@export var noise_speed: float = 140.0
## 弹幕间隔
@export var fire_interval: float = 2.0

# ============================================================
# 内部状态
# ============================================================

## 身体段数据: {node: Polygon2D, position: Vector2, color: Color, resolution: float}
var _segments: Array[Dictionary] = []
var _segment_spacing: float = 20.0

## 生长计时
var _growth_timer: float = 0.0

## 降采样区域
var _bitcrush_zones: Array[Dictionary] = []  # {node, position, timer}

## 弹幕计时
var _fire_timer: float = 0.0

## 移动历史（用于身体跟随）
var _position_history: Array[Vector2] = []
var _history_interval: float = 0.05
var _history_timer: float = 0.0

## 蛇形移动
var _wander_angle: float = 0.0
var _wander_timer: float = 0.0

## 地面腐蚀计时
var _corruption_spawn_timer: float = 0.0
var _corruption_spawn_interval: float = 0.8

## 身体段着色器资源缓存
var _body_shader: Shader = null

# ============================================================
# 初始化
# ============================================================

func _on_enemy_ready() -> void:
	enemy_type = EnemyType.PULSE
	# 注意：这些值会被 enemy_spawner._apply_difficulty_scaling() 用
	# CHAPTER_ENEMY_STATS 中的值覆盖，此处设置为默认回退值
	max_hp = 100.0
	current_hp = 100.0
	move_speed = 50.0
	contact_damage = 14.0
	xp_value = 13

	quantized_fps = 8.0
	_quantize_interval = 1.0 / quantized_fps
	knockback_resistance = 0.5
	move_on_offbeat = false

	base_color = Color(0.0, 0.8, 0.5)
	base_glitch_intensity = 0.1
	max_glitch_intensity = 0.8
	collision_radius = 14.0

	# 隐藏 spawner 创建的默认 EnemyVisual（我们使用自己的程序化视觉体系）
	# _sprite 由 enemy_base.gd 的 @onready 引用 $EnemyVisual
	if _sprite:
		_sprite.visible = false

	# 预加载身体段着色器
	_body_shader = load("res://shaders/bitcrush_worm_body.gdshader")

	# 注册全局着色器参数（地面腐蚀交互）
	_register_global_shader_params()

	# 创建初始身体段
	_create_segments(initial_segments)

	# 初始化位置历史
	for i in range(max_segments * 5):
		_position_history.append(global_position)

## 注册全局着色器参数，供地面着色器读取蠕虫位置
func _register_global_shader_params() -> void:
	# 设置初始全局参数值
	# 地面着色器通过这些参数实现腐蚀效果
	RenderingServer.global_shader_parameter_set(
		"worm_position", Vector3(global_position.x, global_position.y, 0.0)
	)
	RenderingServer.global_shader_parameter_set(
		"worm_corruption_radius", bitcrush_radius
	)
	RenderingServer.global_shader_parameter_set(
		"worm_corruption_fade", 0.0
	)

# ============================================================
# 1. 分段身体运动 (Issue #70 Checklist Item 1)
# ============================================================

func _create_segments(count: int) -> void:
	for i in range(count):
		_add_segment()

func _add_segment() -> void:
	if _segments.size() >= max_segments:
		return

	var seg_visual := Polygon2D.new()

	# 像素化的方形段 — 越靠后越小（模拟蠕虫锥形身体）
	var size := 10.0 - _segments.size() * 0.5
	size = max(size, 5.0)
	seg_visual.polygon = PackedVector2Array([
		Vector2(-size, -size), Vector2(size, -size),
		Vector2(size, size), Vector2(-size, size)
	])

	# 颜色渐变：头部亮绿 → 尾部暗绿
	var t := float(_segments.size()) / max_segments
	var seg_color := base_color.lerp(Color(0.0, 0.3, 0.2), t)
	seg_visual.color = seg_color

	# 2. 多分辨率块着色器 (Issue #70 Checklist Item 2)
	# 每个段使用不同的 resolution 参数，尾部更像素化
	if _body_shader:
		var mat := ShaderMaterial.new()
		mat.shader = _body_shader
		# 头部高分辨率(细腻) → 尾部低分辨率(粗糙像素化)
		mat.set_shader_parameter("resolution", 16.0 - t * 12.0)
		mat.set_shader_parameter("corruption", t * 0.5)
		mat.set_shader_parameter("base_color", seg_color)
		mat.set_shader_parameter("corrupt_color", Color(1.0, 0.0, 0.5))
		mat.set_shader_parameter("scanline_intensity", 0.2 + t * 0.3)
		mat.set_shader_parameter("glitch_intensity", t * 0.2)
		mat.set_shader_parameter("beat_energy", 0.0)
		mat.set_shader_parameter("time_scale", 1.0 + t * 0.5)
		seg_visual.material = mat
	else:
		# 回退：使用旧的 bitcrush.gdshader
		var fallback_shader := load("res://shaders/bitcrush.gdshader")
		if fallback_shader:
			var mat := ShaderMaterial.new()
			mat.shader = fallback_shader
			mat.set_shader_parameter("pixel_size", 4.0 + t * 8.0)
			mat.set_shader_parameter("color_depth", 16.0 - t * 8.0)
			mat.set_shader_parameter("corruption", t * 0.3)
			mat.set_shader_parameter("scanline_intensity", 0.3)
			seg_visual.material = mat

	var pos := global_position
	if _segments.size() > 0:
		pos = _segments[-1]["position"]

	seg_visual.global_position = pos
	get_parent().add_child(seg_visual)

	_segments.append({
		"node": seg_visual,
		"position": pos,
		"color": seg_color,
		"resolution": 16.0 - t * 12.0,  # 记录分辨率用于动态调整
	})

# ============================================================
# 每帧逻辑
# ============================================================

func _on_enemy_process(delta: float) -> void:
	# 记录位置历史
	_history_timer += delta
	if _history_timer >= _history_interval:
		_history_timer = 0.0
		_position_history.push_front(global_position)
		if _position_history.size() > max_segments * 10:
			_position_history.pop_back()

	# 更新身体段位置（分段跟随运动）
	_update_segments()

	# 生长
	_growth_timer += delta
	if _growth_timer >= growth_interval:
		_growth_timer = 0.0
		_add_segment()

	# 降采样区域管理
	_update_bitcrush_zones(delta)

	# 弹幕
	_fire_timer += delta
	if _fire_timer >= fire_interval:
		_fire_timer = 0.0
		_fire_noise_burst()

	# 3. 地面腐蚀交互 (Issue #70 Checklist Item 3)
	# 持续更新全局着色器参数，传递蠕虫位置给地面着色器
	_update_ground_corruption(delta)

## 更新身体段位置 — 经典蛇/蠕虫式跟随运动
func _update_segments() -> void:
	for i in range(_segments.size()):
		var seg := _segments[i]
		if not is_instance_valid(seg["node"]):
			continue

		# 每个段跟随位置历史中的对应位置
		var history_index := (i + 1) * 4
		if history_index < _position_history.size():
			seg["position"] = _position_history[history_index]
			seg["node"].global_position = seg["position"]

		# 像素化抖动 — 模拟数据损坏的不稳定感
		if randf() < 0.1:
			seg["node"].position += Vector2(
				randf_range(-2, 2), randf_range(-2, 2)
			)

		# 动态更新着色器的 beat_energy（衰减）
		if seg["node"].material is ShaderMaterial:
			var mat := seg["node"].material as ShaderMaterial
			var current_beat := mat.get_shader_parameter("beat_energy")
			if current_beat is float and current_beat > 0.0:
				mat.set_shader_parameter("beat_energy", maxf(current_beat - 0.05, 0.0))

# ============================================================
# 3. 地面腐蚀交互 (Issue #70 Checklist Item 3)
# ============================================================

## 更新全局着色器参数，使地面着色器能读取蠕虫位置并绘制腐蚀效果
func _update_ground_corruption(delta: float) -> void:
	# 持续更新蠕虫位置到全局着色器参数
	RenderingServer.global_shader_parameter_set(
		"worm_position", Vector3(global_position.x, global_position.y, 0.0)
	)

	# 定期在蠕虫位置生成可见的腐蚀区域标记
	_corruption_spawn_timer += delta
	if _corruption_spawn_timer >= _corruption_spawn_interval:
		_corruption_spawn_timer = 0.0
		_spawn_bitcrush_zone()

func _update_bitcrush_zones(delta: float) -> void:
	var expired: Array[int] = []

	for i in range(_bitcrush_zones.size()):
		var zone := _bitcrush_zones[i]
		zone["timer"] -= delta
		if zone["timer"] <= 0.0:
			expired.append(i)
			if is_instance_valid(zone["node"]):
				zone["node"].queue_free()
		else:
			# 淡出效果
			if is_instance_valid(zone["node"]):
				var fade_ratio := zone["timer"] / bitcrush_duration
				zone["node"].modulate.a = fade_ratio * 0.3

				# 更新腐蚀区域着色器的衰减参数
				if zone["node"].material is ShaderMaterial:
					var mat := zone["node"].material as ShaderMaterial
					mat.set_shader_parameter("fade_progress", 1.0 - fade_ratio)

	for i in range(expired.size() - 1, -1, -1):
		_bitcrush_zones.remove_at(expired[i])

# ============================================================
# 降采样区域
# ============================================================

func _spawn_bitcrush_zone() -> void:
	var zone := Polygon2D.new()
	# 像素化方形腐蚀区域
	zone.polygon = PackedVector2Array([
		Vector2(-bitcrush_radius, -bitcrush_radius),
		Vector2(bitcrush_radius, -bitcrush_radius),
		Vector2(bitcrush_radius, bitcrush_radius),
		Vector2(-bitcrush_radius, bitcrush_radius),
	])
	zone.color = Color(0.0, 0.6, 0.3, 0.15)

	# 为腐蚀区域应用像素化着色器
	var bitcrush_shader := load("res://shaders/bitcrush.gdshader")
	if bitcrush_shader:
		var mat := ShaderMaterial.new()
		mat.shader = bitcrush_shader
		mat.set_shader_parameter("pixel_size", 8.0)
		mat.set_shader_parameter("color_depth", 8.0)
		mat.set_shader_parameter("corruption", 0.3)
		mat.set_shader_parameter("scanline_intensity", 0.2)
		zone.material = mat

	zone.global_position = global_position
	get_parent().add_child(zone)

	_bitcrush_zones.append({
		"node": zone,
		"position": global_position,
		"timer": bitcrush_duration,
	})

## 检查位置是否在降采样区域内
func is_position_bitcrushed(pos: Vector2) -> bool:
	for zone in _bitcrush_zones:
		if pos.distance_to(zone["position"]) < bitcrush_radius:
			return true
	return false

# ============================================================
# 量化噪音弹幕
# ============================================================

func _fire_noise_burst() -> void:
	if _is_dead or not _target or not is_instance_valid(_target):
		return

	var dir := (global_position.direction_to(_target.global_position)).angle()

	# 量化噪音：不规则方向的弹幕，数量与身体段数挂钩
	var count := 3 + _segments.size() / 2
	for i in range(count):
		var angle := dir + randf_range(-0.5, 0.5)
		var speed := noise_speed * randf_range(0.7, 1.3)

		var proj := Area2D.new()
		proj.add_to_group("enemy_projectiles")

		var col := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 4.0
		col.shape = shape
		proj.add_child(col)

		# 像素化方形弹幕
		var visual := Polygon2D.new()
		var s := randf_range(3.0, 6.0)
		visual.polygon = PackedVector2Array([
			Vector2(-s, -s), Vector2(s, -s), Vector2(s, s), Vector2(-s, s)
		])
		visual.color = Color(0.0, 1.0, 0.5, 0.8)

		# 弹幕也使用像素化着色器
		if _body_shader:
			var proj_mat := ShaderMaterial.new()
			proj_mat.shader = _body_shader
			proj_mat.set_shader_parameter("resolution", randf_range(4.0, 12.0))
			proj_mat.set_shader_parameter("corruption", randf_range(0.2, 0.6))
			proj_mat.set_shader_parameter("base_color", Color(0.0, 1.0, 0.5, 0.8))
			proj_mat.set_shader_parameter("corrupt_color", Color(1.0, 0.0, 0.5))
			proj_mat.set_shader_parameter("scanline_intensity", 0.2)
			visual.material = proj_mat

		proj.add_child(visual)

		proj.global_position = global_position
		get_parent().add_child(proj)

		var vel := Vector2.from_angle(angle) * speed
		var tween := proj.create_tween()
		tween.tween_property(proj, "global_position",
			proj.global_position + vel * 3.0, 3.0)
		tween.tween_callback(proj.queue_free)

		proj.body_entered.connect(func(body: Node2D):
			if body.is_in_group("player") and body.has_method("take_damage"):
				body.take_damage(noise_damage)
				proj.queue_free()
		)

# ============================================================
# 受击断裂
# ============================================================

func take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO, is_perfect_beat: bool = false) -> void:
	super.take_damage(amount, knockback_dir, is_perfect_beat)

	# 受到大量伤害时断裂尾部段
	if amount >= max_hp * 0.15 and _segments.size() > 1 and not _is_dead:
		_break_tail_segment()

func _break_tail_segment() -> void:
	if _segments.is_empty():
		return

	var tail = _segments.pop_back()
	if not is_instance_valid(tail["node"]):
		return

	var tail_pos: Vector2 = tail["position"]

	# 断裂视觉：闪白 → 像素化溶解
	var tween = tail["node"].create_tween()
	tween.tween_property(tail["node"], "modulate", Color.WHITE, 0.1)
	tween.tween_property(tail["node"], "modulate:a", 0.0, 0.3)
	tween.tween_callback(tail["node"].queue_free)

	# 断裂处释放噪音弹幕碎片
	for i in range(4):
		var angle := (TAU / 4) * i + randf() * 0.5
		var proj := Area2D.new()
		proj.add_to_group("enemy_projectiles")

		var col := CollisionShape2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 3.0
		col.shape = shape
		proj.add_child(col)

		var visual := Polygon2D.new()
		visual.polygon = PackedVector2Array([
			Vector2(-3, -3), Vector2(3, -3), Vector2(3, 3), Vector2(-3, 3)
		])
		visual.color = Color(0.0, 1.0, 0.5, 0.7)
		proj.add_child(visual)

		proj.global_position = tail_pos
		get_parent().add_child(proj)

		var vel := Vector2.from_angle(angle) * noise_speed * 0.5
		var proj_tween := proj.create_tween()
		proj_tween.tween_property(proj, "global_position",
			proj.global_position + vel * 2.0, 2.0)
		proj_tween.tween_callback(proj.queue_free)

	# 断裂处也留下一个小型腐蚀区域
	_spawn_bitcrush_zone_at(tail_pos, bitcrush_radius * 0.5)

## 在指定位置生成腐蚀区域
func _spawn_bitcrush_zone_at(pos: Vector2, radius: float) -> void:
	var zone := Polygon2D.new()
	zone.polygon = PackedVector2Array([
		Vector2(-radius, -radius), Vector2(radius, -radius),
		Vector2(radius, radius), Vector2(-radius, radius),
	])
	zone.color = Color(0.0, 0.6, 0.3, 0.15)
	zone.global_position = pos
	get_parent().add_child(zone)

	_bitcrush_zones.append({
		"node": zone,
		"position": pos,
		"timer": bitcrush_duration * 0.5,
	})

# ============================================================
# 移动逻辑
# ============================================================

func _calculate_movement_direction() -> Vector2:
	if _target == null:
		return Vector2.ZERO

	# 蛇形移动：朝玩家方向蜿蜒前进
	var to_player := (_target.global_position - global_position).normalized()

	_wander_timer += _quantize_interval
	_wander_angle += sin(_wander_timer * 2.0) * 0.8

	var wander_dir := Vector2.from_angle(to_player.angle() + sin(_wander_timer * 1.5) * 0.8)

	return wander_dir

# ============================================================
# 节拍回调
# ============================================================

func _on_beat(_beat_index: int) -> void:
	# 节拍时所有段闪烁 + 着色器 beat_energy 脉冲
	for seg in _segments:
		if is_instance_valid(seg["node"]):
			# 视觉闪烁
			var tween = seg["node"].create_tween()
			tween.tween_property(seg["node"], "modulate", Color.WHITE, 0.05)
			tween.tween_property(seg["node"], "modulate", seg["color"], 0.1)

			# 着色器节拍能量
			if seg["node"].material is ShaderMaterial:
				var mat := seg["node"].material as ShaderMaterial
				mat.set_shader_parameter("beat_energy", 1.0)

# ============================================================
# 死亡效果
# ============================================================

func _on_death_effect() -> void:
	# 清除全局着色器参数（停止地面腐蚀）
	RenderingServer.global_shader_parameter_set(
		"worm_corruption_fade", 1.0
	)

	# 死亡时所有段爆炸
	for seg in _segments:
		if is_instance_valid(seg["node"]):
			# 爆炸弹幕
			for i in range(3):
				var angle := randf() * TAU
				var proj := Area2D.new()
				proj.add_to_group("enemy_projectiles")
				var col := CollisionShape2D.new()
				var shape := CircleShape2D.new()
				shape.radius = 3.0
				col.shape = shape
				proj.add_child(col)
				var visual := Polygon2D.new()
				visual.polygon = PackedVector2Array([
					Vector2(-3, -3), Vector2(3, -3), Vector2(3, 3), Vector2(-3, 3)
				])
				visual.color = Color(0.0, 1.0, 0.5, 0.7)
				proj.add_child(visual)
				proj.global_position = seg["position"]
				get_parent().add_child(proj)
				var vel := Vector2.from_angle(angle) * noise_speed * 0.4
				var tween := proj.create_tween()
				tween.tween_property(proj, "global_position",
					proj.global_position + vel * 2.0, 2.0)
				tween.tween_callback(proj.queue_free)

			# 段消失
			seg["node"].queue_free()
	_segments.clear()

	# 清理降采样区域
	for zone in _bitcrush_zones:
		if is_instance_valid(zone["node"]):
			zone["node"].queue_free()
	_bitcrush_zones.clear()

func _get_type_name() -> String:
	return "ch7_bitcrusher_worm"
