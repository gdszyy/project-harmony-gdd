## ch3_counterpoint_crawler.gd
## 第三章特色敌人：对位爬虫 (Counterpoint Crawler)
## Issue #66: 使用程序化技术实现的机械蜘蛛敌人
##
## 设计概要：
## - 机械蜘蛛，羽管键琴状身体 + 管风琴炮塔
## - 双声部敌人：主体(低音声部)缓慢移动，炮塔(高音声部)独立瞄准射击
## - 巴赫对位法中两个独立声部的具象化
##
## 技术实现 (Issue #66 Checklist):
## 1. 程序化骨骼创建 — 模拟 Skeleton3D 的骨骼层级 (2D 模式下用节点层级)
## 2. 程序化几何体附着 — 身体/腿/炮塔均为程序化生成的 Polygon2D
## 3. 程序化行走与 IK — 简化的 2D IK 行走算法
## 4. 细节着色器 — counterpoint_crawler_body/metal.gdshader
extends "res://scripts/entities/enemy_base.gd"

# ============================================================
# Counterpoint Crawler 专属配置
# ============================================================

## 炮塔射击间隔（秒）
@export var turret_fire_interval: float = 2.0
## 炮塔弹幕速度
@export var turret_projectile_speed: float = 200.0
## 炮塔弹幕伤害
@export var turret_projectile_damage: float = 10.0
## 炮塔旋转速度
@export var turret_rotation_speed: float = 1.5
## 炮塔HP（独立于主体）
@export var turret_hp: float = 40.0
## 炮塔弹幕数
@export var turret_projectile_count: int = 3
## 炮塔弹幕扇形角度
@export var turret_spread: float = 0.4  # ~23度

## 腿部配置
@export var leg_count: int = 6  # 每侧3条腿
@export var leg_length: float = 18.0  # 腿总长度
@export var step_distance: float = 12.0  # 触发迈步的距离阈值
@export var step_height: float = 6.0  # 迈步抬腿高度
@export var step_speed: float = 8.0  # 迈步速度

# ============================================================
# 内部状态
# ============================================================

var _turret_alive: bool = true
var _turret_current_hp: float = 0.0
var _turret_fire_timer: float = 0.0
var _turret_angle: float = 0.0

## 对位节奏相位（主体和炮塔不同步）
var _body_phase: float = 0.0
var _turret_phase: float = 0.0

## 程序化骨骼节点层级 (Issue #66 Checklist Item 1)
## 模拟 Skeleton3D 的骨骼层级结构
var _skeleton_root: Node2D = null       # body 骨骼
var _turret_bone: Node2D = null         # turret 骨骼
var _leg_bones: Array[Dictionary] = []  # 每条腿的骨骼链: {coxa, femur, tibia, foot_target, foot_current, is_stepping}

## 程序化几何体 (Issue #66 Checklist Item 2)
var _body_visual: Polygon2D = null      # 羽管键琴身体
var _turret_visual: Node2D = null       # 管风琴炮塔
var _leg_visuals: Array[Array] = []     # 每条腿的视觉段

## 着色器缓存
var _body_shader: Shader = null
var _metal_shader: Shader = null

# ============================================================
# 初始化
# ============================================================

func _on_enemy_ready() -> void:
	enemy_type = EnemyType.PULSE
	# 注意：这些值会被 enemy_spawner._apply_difficulty_scaling() 用
	# CHAPTER_ENEMY_STATS 中的值覆盖，此处设置为默认回退值
	max_hp = 70.0
	current_hp = 70.0
	move_speed = 45.0
	contact_damage = 10.0
	xp_value = 9
	collision_radius = 14.0
	quantized_fps = 8.0
	_quantize_interval = 1.0 / quantized_fps
	knockback_resistance = 0.4
	move_on_offbeat = false

	# 铜管色调（巴洛克机械感）
	base_color = Color(0.7, 0.5, 0.2)
	base_glitch_intensity = 0.08
	max_glitch_intensity = 0.6

	# 隐藏 spawner 创建的默认 EnemyVisual（我们使用自己的程序化视觉体系）
	if _sprite:
		_sprite.visible = false

	# 初始化炮塔HP
	_turret_current_hp = turret_hp

	# 预加载着色器
	_body_shader = load("res://shaders/counterpoint_crawler_body.gdshader")
	_metal_shader = load("res://shaders/counterpoint_crawler_metal.gdshader")

	# 1. 创建程序化骨骼层级
	_create_skeleton_hierarchy()

	# 2. 创建程序化几何体并附着到骨骼
	_create_procedural_geometry()

	# 3. 初始化 IK 行走系统
	_initialize_ik_walking()

# ============================================================
# 1. 程序化骨骼创建 (Issue #66 Checklist Item 1)
# ============================================================
## 创建模拟 Skeleton3D 的节点层级
## 骨骼结构: body → turret_joint
##                → leg_l1_coxa → leg_l1_femur → leg_l1_tibia
##                → leg_r1_coxa → leg_r1_femur → leg_r1_tibia
##                → ... (共 leg_count 条腿)

func _create_skeleton_hierarchy() -> void:
	# 根骨骼 (body)
	_skeleton_root = Node2D.new()
	_skeleton_root.name = "SkeletonRoot_Body"
	add_child(_skeleton_root)

	# 炮塔骨骼 (turret) — body 的子节点
	_turret_bone = Node2D.new()
	_turret_bone.name = "Bone_Turret"
	_turret_bone.position = Vector2(0, -14)  # 炮塔在身体上方
	_skeleton_root.add_child(_turret_bone)

	# 腿部骨骼链 — body 的子节点
	var legs_per_side := leg_count / 2
	for i in range(leg_count):
		var side := -1.0 if i < legs_per_side else 1.0  # 左侧 / 右侧
		var leg_index := i % legs_per_side
		var leg_prefix := "L" if side < 0 else "R"

		# 腿根位置：沿身体两侧均匀分布
		var body_half_width := 12.0
		var body_half_height := 8.0
		var leg_y_offset := -body_half_height + (float(leg_index) / float(max(1, legs_per_side - 1))) * body_half_height * 2.0
		var coxa_pos := Vector2(side * body_half_width, leg_y_offset)

		# Coxa (基节) — 连接身体
		var coxa := Node2D.new()
		coxa.name = "Bone_%s%d_Coxa" % [leg_prefix, leg_index]
		coxa.position = coxa_pos
		_skeleton_root.add_child(coxa)

		# Femur (股节) — coxa 的子节点
		var femur := Node2D.new()
		femur.name = "Bone_%s%d_Femur" % [leg_prefix, leg_index]
		femur.position = Vector2(side * leg_length * 0.4, 0)
		coxa.add_child(femur)

		# Tibia (胫节) — femur 的子节点
		var tibia := Node2D.new()
		tibia.name = "Bone_%s%d_Tibia" % [leg_prefix, leg_index]
		tibia.position = Vector2(side * leg_length * 0.6, 0)
		femur.add_child(tibia)

		# 脚部目标位置（IK 目标）
		var rest_foot_pos := global_position + coxa_pos + Vector2(side * leg_length, leg_y_offset * 0.3)

		_leg_bones.append({
			"coxa": coxa,
			"femur": femur,
			"tibia": tibia,
			"side": side,
			"index": leg_index,
			"foot_target": rest_foot_pos,       # IK 目标位置
			"foot_current": rest_foot_pos,       # 当前脚位置
			"foot_rest": rest_foot_pos,          # 静止位置
			"is_stepping": false,                # 是否正在迈步
			"step_progress": 0.0,                # 迈步进度 [0, 1]
			"step_start": rest_foot_pos,         # 迈步起始位置
			"step_end": rest_foot_pos,           # 迈步目标位置
			"coxa_rest_pos": coxa_pos,           # coxa 静止位置
		})

# ============================================================
# 2. 程序化几何体和附着 (Issue #66 Checklist Item 2)
# ============================================================

func _create_procedural_geometry() -> void:
	# 身体 — 羽管键琴形状的 BoxMesh (2D: 矩形 Polygon2D)
	_body_visual = Polygon2D.new()
	_body_visual.polygon = PackedVector2Array([
		Vector2(-14, -8), Vector2(14, -8),
		Vector2(12, 8), Vector2(-12, 8)  # 略微梯形，模拟键琴形状
	])
	_body_visual.color = Color(0.7, 0.5, 0.2)

	# 应用身体着色器
	if _body_shader:
		var body_mat := ShaderMaterial.new()
		body_mat.shader = _body_shader
		body_mat.set_shader_parameter("brass_color", Color(0.7, 0.5, 0.2))
		body_mat.set_shader_parameter("dark_color", Color(0.3, 0.2, 0.1))
		body_mat.set_shader_parameter("accent_color", Color(1.0, 0.8, 0.3))
		body_mat.set_shader_parameter("gear_scale", 6.0)
		body_mat.set_shader_parameter("rotation_speed", 0.5)
		body_mat.set_shader_parameter("key_count", 8.0)
		body_mat.set_shader_parameter("beat_energy", 0.0)
		body_mat.set_shader_parameter("damage_ratio", 0.0)
		_body_visual.material = body_mat

	# 附着到 body 骨骼
	_skeleton_root.add_child(_body_visual)

	# 炮塔 — 管风琴管簇 (多个矩形组成)
	_turret_visual = Node2D.new()
	_turret_visual.name = "TurretVisual"

	# 管风琴管 — 3根不同高度的管
	var pipe_widths := [3.0, 4.0, 3.0]
	var pipe_heights := [10.0, 14.0, 8.0]
	var pipe_offsets := [-4.0, 0.0, 4.0]

	for i in range(pipe_widths.size()):
		var pipe := Polygon2D.new()
		var w := pipe_widths[i]
		var h := pipe_heights[i]
		pipe.polygon = PackedVector2Array([
			Vector2(-w, 0), Vector2(w, 0),
			Vector2(w, -h), Vector2(-w, -h)
		])
		pipe.position = Vector2(pipe_offsets[i], 0)
		pipe.color = Color(0.6, 0.45, 0.2)

		# 应用金属着色器
		if _metal_shader:
			var pipe_mat := ShaderMaterial.new()
			pipe_mat.shader = _metal_shader
			pipe_mat.set_shader_parameter("metal_color", Color(0.6, 0.45, 0.2))
			pipe_mat.set_shader_parameter("highlight_color", Color(1.0, 0.9, 0.6))
			pipe_mat.set_shader_parameter("shininess", 0.6)
			pipe_mat.set_shader_parameter("beat_energy", 0.0)
			pipe_mat.set_shader_parameter("wear", 0.1 * i)
			pipe.material = pipe_mat

		_turret_visual.add_child(pipe)

	# 炮口指示器
	var muzzle := Polygon2D.new()
	muzzle.polygon = PackedVector2Array([
		Vector2(-3, -2), Vector2(8, 0), Vector2(-3, 2)
	])
	muzzle.color = Color(0.9, 0.7, 0.3)
	muzzle.position = Vector2(0, -14)
	_turret_visual.add_child(muzzle)

	# 附着到 turret 骨骼
	_turret_bone.add_child(_turret_visual)

	# 腿部几何体 — 每条腿由 2 段圆柱(矩形)组成
	for i in range(_leg_bones.size()):
		var leg_data := _leg_bones[i]
		var leg_segments: Array = []

		# 上腿段 (coxa → femur)
		var upper_leg := Polygon2D.new()
		upper_leg.polygon = PackedVector2Array([
			Vector2(-1.5, -1.5), Vector2(1.5, -1.5),
			Vector2(1.5, 1.5), Vector2(-1.5, 1.5)
		])
		upper_leg.color = Color(0.55, 0.4, 0.2)

		if _metal_shader:
			var ul_mat := ShaderMaterial.new()
			ul_mat.shader = _metal_shader
			ul_mat.set_shader_parameter("metal_color", Color(0.55, 0.4, 0.2))
			ul_mat.set_shader_parameter("highlight_color", Color(0.9, 0.8, 0.5))
			ul_mat.set_shader_parameter("shininess", 0.5)
			ul_mat.set_shader_parameter("beat_energy", 0.0)
			ul_mat.set_shader_parameter("wear", 0.2)
			upper_leg.material = ul_mat

		leg_data["coxa"].add_child(upper_leg)
		leg_segments.append(upper_leg)

		# 下腿段 (femur → tibia)
		var lower_leg := Polygon2D.new()
		lower_leg.polygon = PackedVector2Array([
			Vector2(-1.0, -1.0), Vector2(1.0, -1.0),
			Vector2(1.0, 1.0), Vector2(-1.0, 1.0)
		])
		lower_leg.color = Color(0.5, 0.35, 0.18)

		if _metal_shader:
			var ll_mat := ShaderMaterial.new()
			ll_mat.shader = _metal_shader
			ll_mat.set_shader_parameter("metal_color", Color(0.5, 0.35, 0.18))
			ll_mat.set_shader_parameter("highlight_color", Color(0.85, 0.75, 0.45))
			ll_mat.set_shader_parameter("shininess", 0.4)
			ll_mat.set_shader_parameter("beat_energy", 0.0)
			ll_mat.set_shader_parameter("wear", 0.3)
			lower_leg.material = ll_mat

		leg_data["femur"].add_child(lower_leg)
		leg_segments.append(lower_leg)

		_leg_visuals.append(leg_segments)

# ============================================================
# 3. 程序化行走与 IK (Issue #66 Checklist Item 3)
# ============================================================

func _initialize_ik_walking() -> void:
	# 初始化每条腿的静止位置
	for i in range(_leg_bones.size()):
		var leg := _leg_bones[i]
		var rest_pos := global_position + leg["coxa_rest_pos"] + Vector2(leg["side"] * leg_length, 0)
		leg["foot_rest"] = rest_pos
		leg["foot_target"] = rest_pos
		leg["foot_current"] = rest_pos

## 程序化行走算法
## 1. 计算每条腿的理想落脚点
## 2. 当脚与理想位置距离超过阈值时触发迈步
## 3. 使用交替三脚架步态协调腿部运动
func _update_procedural_walking(delta: float) -> void:
	# 更新每条腿的理想落脚点
	for i in range(_leg_bones.size()):
		var leg := _leg_bones[i]

		# 理想落脚点 = 身体位置 + 腿根偏移 + 腿伸展方向
		var ideal_foot_pos := global_position + leg["coxa_rest_pos"] + Vector2(
			leg["side"] * leg_length,
			leg["coxa_rest_pos"].y * 0.3
		)

		# 加入移动方向预测
		if _movement_direction != Vector2.ZERO:
			ideal_foot_pos += _movement_direction * step_distance * 0.3

		leg["foot_target"] = ideal_foot_pos

		# 检查是否需要迈步
		var dist_to_target := leg["foot_current"].distance_to(leg["foot_target"])

		if not leg["is_stepping"] and dist_to_target > step_distance:
			# 检查步态协调：交替三脚架步态
			# 偶数索引的腿和奇数索引的腿交替迈步
			if _can_leg_step(i):
				_start_step(i)

		# 更新迈步动画
		if leg["is_stepping"]:
			leg["step_progress"] += delta * step_speed
			if leg["step_progress"] >= 1.0:
				# 迈步完成
				leg["step_progress"] = 1.0
				leg["is_stepping"] = false
				leg["foot_current"] = leg["step_end"]
			else:
				# 插值脚位置 + 抬腿弧线
				var t_val: float = leg["step_progress"]
				var lerped := leg["step_start"].lerp(leg["step_end"], t_val)
				# Y 轴弧线：sin 曲线模拟抬腿
				var lift := sin(t_val * PI) * step_height
				lerped.y -= lift
				leg["foot_current"] = lerped

		# 简化 IK：根据脚位置反算骨骼旋转
		_solve_leg_ik(i)

## 检查某条腿是否可以迈步（步态协调）
## 使用交替三脚架步态：同一组的腿不能同时迈步
func _can_leg_step(leg_index: int) -> bool:
	# 三脚架步态：腿分为两组 (0,2,4) 和 (1,3,5)
	var group := leg_index % 2
	for i in range(_leg_bones.size()):
		if i == leg_index:
			continue
		if i % 2 == group and _leg_bones[i]["is_stepping"]:
			return false  # 同组有腿正在迈步，等待
	return true

## 开始迈步
func _start_step(leg_index: int) -> void:
	var leg := _leg_bones[leg_index]
	leg["is_stepping"] = true
	leg["step_progress"] = 0.0
	leg["step_start"] = leg["foot_current"]
	leg["step_end"] = leg["foot_target"]

## 简化 2D IK 求解器
## 根据脚部位置反算 coxa 和 femur 的旋转角度
func _solve_leg_ik(leg_index: int) -> void:
	var leg := _leg_bones[leg_index]
	var coxa: Node2D = leg["coxa"]
	var femur: Node2D = leg["femur"]
	var tibia: Node2D = leg["tibia"]

	# 计算从 coxa 全局位置到脚位置的方向
	var coxa_global := coxa.global_position
	var foot_pos: Vector2 = leg["foot_current"]
	var to_foot := foot_pos - coxa_global

	# coxa 旋转：指向脚的方向
	var target_angle := to_foot.angle()
	coxa.global_rotation = target_angle

	# femur 位置由 coxa 子节点自动跟随
	# 计算 femur 到脚的剩余距离
	var femur_global := femur.global_position
	var to_foot_from_femur := foot_pos - femur_global

	# femur 旋转：指向脚的方向（简化 IK，不做精确的双骨骼求解）
	var femur_angle := to_foot_from_femur.angle()
	femur.global_rotation = femur_angle

	# tibia 跟随 femur
	tibia.global_position = foot_pos

# ============================================================
# 每帧逻辑
# ============================================================

func _on_enemy_process(delta: float) -> void:
	# 主体节奏相位
	_body_phase += delta * 2.0

	# 3. 程序化行走 (Issue #66 Checklist Item 3)
	_update_procedural_walking(delta)

	# 炮塔逻辑
	if _turret_alive:
		_turret_phase += delta * 3.0

		# 炮塔独立追踪玩家（对位法：独立声部）
		if _target and is_instance_valid(_target):
			var target_angle := (global_position.direction_to(_target.global_position)).angle()
			_turret_angle = lerp_angle(_turret_angle, target_angle, turret_rotation_speed * delta)

		# 更新炮塔骨骼旋转
		if _turret_bone:
			_turret_bone.rotation = _turret_angle

		# 炮塔视觉脉冲
		if _turret_visual:
			var turret_pulse := sin(_turret_phase) * 0.05
			_turret_visual.scale = Vector2(1.0 + turret_pulse, 1.0 + turret_pulse)

		# 炮塔射击
		_turret_fire_timer += delta
		if _turret_fire_timer >= turret_fire_interval:
			_turret_fire_timer = 0.0
			_turret_fire()

	# 主体视觉 — 呼吸脉冲
	if _body_visual:
		var body_pulse := sin(_body_phase) * 0.03
		_body_visual.scale = Vector2(1.0 + body_pulse, 1.0 + body_pulse)

	# 更新身体着色器参数
	_update_shader_params()

## 更新着色器参数
func _update_shader_params() -> void:
	# 身体着色器 — 受伤比例
	if _body_visual and _body_visual.material is ShaderMaterial:
		var mat := _body_visual.material as ShaderMaterial
		var damage_ratio := 1.0 - (current_hp / max_hp)
		mat.set_shader_parameter("damage_ratio", damage_ratio)

		# beat_energy 衰减
		var current_beat: Variant = mat.get_shader_parameter("beat_energy")
		if current_beat is float and current_beat > 0.0:
			mat.set_shader_parameter("beat_energy", maxf(current_beat - 0.05, 0.0))

# ============================================================
# 炮塔射击
# ============================================================

func _turret_fire() -> void:
	if not _turret_alive or _target == null:
		return

	for i in range(turret_projectile_count):
		var t := float(i) / float(max(1, turret_projectile_count - 1))
		var angle := _turret_angle - turret_spread / 2.0 + turret_spread * t
		if turret_projectile_count == 1:
			angle = _turret_angle
		_spawn_turret_projectile(angle)

	# 射击反馈 — 炮塔后坐力
	if _turret_visual:
		var tween := _turret_visual.create_tween()
		tween.tween_property(_turret_visual, "scale", Vector2(1.3, 0.7), 0.05)
		tween.tween_property(_turret_visual, "scale", Vector2(1.0, 1.0), 0.1)

func _spawn_turret_projectile(angle: float) -> void:
	var proj := Area2D.new()
	proj.add_to_group("enemy_projectiles")

	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 4.0
	col.shape = shape
	proj.add_child(col)

	# 弹幕视觉 — 三角形音符
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-3, -2), Vector2(5, 0), Vector2(-3, 2)
	])
	visual.color = Color(0.9, 0.7, 0.3, 0.8)
	visual.rotation = angle

	# 应用金属着色器
	if _metal_shader:
		var proj_mat := ShaderMaterial.new()
		proj_mat.shader = _metal_shader
		proj_mat.set_shader_parameter("metal_color", Color(0.9, 0.7, 0.3, 0.8))
		proj_mat.set_shader_parameter("highlight_color", Color(1.0, 0.95, 0.7))
		proj_mat.set_shader_parameter("shininess", 0.8)
		visual.material = proj_mat

	proj.add_child(visual)

	proj.global_position = global_position + Vector2(0, -14)
	get_parent().add_child(proj)

	var vel := Vector2.from_angle(angle) * turret_projectile_speed
	var tween := proj.create_tween()
	tween.tween_property(proj, "global_position",
		proj.global_position + vel * 3.0, 3.0)
	tween.tween_callback(proj.queue_free)

	proj.body_entered.connect(func(body: Node2D):
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(turret_projectile_damage)
			proj.queue_free()
	)

# ============================================================
# 伤害处理：炮塔可独立受伤
# ============================================================

func take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO, is_perfect_beat: bool = false) -> void:
	# 30% 概率伤害命中炮塔
	if _turret_alive and randf() < 0.3:
		_turret_current_hp -= amount
		if _turret_current_hp <= 0.0:
			_destroy_turret()
		# 炮塔受击闪烁
		if _turret_visual:
			var tween := _turret_visual.create_tween()
			tween.tween_property(_turret_visual, "modulate", Color.WHITE, 0.05)
			tween.tween_property(_turret_visual, "modulate", Color(0.9, 0.7, 0.3), 0.1)
	else:
		super.take_damage(amount, knockback_dir, is_perfect_beat)

func _destroy_turret() -> void:
	_turret_alive = false
	if _turret_visual:
		var tween := _turret_visual.create_tween()
		tween.tween_property(_turret_visual, "modulate:a", 0.0, 0.3)
		tween.tween_property(_turret_visual, "scale", Vector2(0.0, 0.0), 0.3)
		tween.tween_callback(_turret_visual.queue_free)

	# 主体加速（失去炮塔后更具攻击性）
	move_speed *= 1.5
	contact_damage *= 1.3

	# 加速行走步态
	step_speed *= 1.3

# ============================================================
# 移动逻辑：缓慢追踪
# ============================================================

func _calculate_movement_direction() -> Vector2:
	if _target == null:
		return Vector2.ZERO
	return (_target.global_position - global_position).normalized()

# ============================================================
# 节拍响应
# ============================================================

func _on_beat(_beat_index: int) -> void:
	# 主体节拍脉冲
	if _body_visual:
		var tween := create_tween()
		tween.tween_property(_body_visual, "scale", Vector2(1.12, 1.12), 0.05)
		tween.tween_property(_body_visual, "scale", Vector2(1.0, 1.0), 0.1)

		# 着色器 beat_energy
		if _body_visual.material is ShaderMaterial:
			var mat := _body_visual.material as ShaderMaterial
			mat.set_shader_parameter("beat_energy", 1.0)

	# 腿部金属着色器节拍能量
	for leg_segs in _leg_visuals:
		for seg in leg_segs:
			if seg is Polygon2D and seg.material is ShaderMaterial:
				var mat := seg.material as ShaderMaterial
				mat.set_shader_parameter("beat_energy", 0.8)

	# 炮塔着色器节拍能量
	if _turret_visual:
		for child in _turret_visual.get_children():
			if child is Polygon2D and child.material is ShaderMaterial:
				var mat := child.material as ShaderMaterial
				mat.set_shader_parameter("beat_energy", 0.8)

# ============================================================
# 死亡效果
# ============================================================

func _on_death_effect() -> void:
	# 炮塔销毁
	if _turret_visual and is_instance_valid(_turret_visual):
		_turret_visual.queue_free()

	# 腿部散落效果
	for i in range(_leg_bones.size()):
		var leg := _leg_bones[i]
		if is_instance_valid(leg["coxa"]):
			# 腿部飞散
			var scatter_dir := Vector2(leg["side"], randf_range(-1, 1)).normalized()
			var tween := leg["coxa"].create_tween()
			tween.set_parallel(true)
			tween.tween_property(leg["coxa"], "global_position",
				leg["coxa"].global_position + scatter_dir * 30.0, 0.4)
			tween.tween_property(leg["coxa"], "modulate:a", 0.0, 0.4)
			tween.tween_property(leg["coxa"], "rotation",
				leg["coxa"].rotation + randf_range(-2.0, 2.0), 0.4)
			tween.chain()
			tween.tween_callback(leg["coxa"].queue_free)

	# 身体碎裂
	if _body_visual and is_instance_valid(_body_visual):
		var tween := _body_visual.create_tween()
		tween.set_parallel(true)
		tween.tween_property(_body_visual, "scale", Vector2(0.0, 0.0), 0.3)
		tween.tween_property(_body_visual, "modulate:a", 0.0, 0.3)
		tween.chain()
		tween.tween_callback(_body_visual.queue_free)

	# 骨骼根节点清理
	if _skeleton_root and is_instance_valid(_skeleton_root):
		# 延迟清理，等待动画完成
		get_tree().create_timer(0.5).timeout.connect(func():
			if is_instance_valid(_skeleton_root):
				_skeleton_root.queue_free()
		)

func _get_type_name() -> String:
	return "ch3_counterpoint_crawler"
