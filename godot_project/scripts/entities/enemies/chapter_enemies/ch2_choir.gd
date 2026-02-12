## ch2_choir.gd
## 第二章特色敌人：唱诗班 (Choir)
## 3-5个 Static 组成同步移动的编队，模拟中世纪齐唱。
## 音乐隐喻：圭多的"齐唱"理念 — 多个声音汇成一体。
## 机制：
## - 编队内所有成员同步移动（跟随队长）
## - 编队完整时获得"齐唱护盾"加成
## - 击杀队长后编队散开，成员变为普通 Static
## - 编队释放同步直线弹幕（圣咏音墙）
extends "res://scripts/entities/enemy_base.gd"

# ============================================================
# Choir 专属配置
# ============================================================
## 是否为编队队长
@export var is_choir_leader: bool = false
## 编队成员引用
var choir_members: Array[Node2D] = []
## 队长引用
var choir_leader: Node2D = null
## 编队内位置偏移
var formation_offset: Vector2 = Vector2.ZERO
## 齐唱护盾加成（编队完整时）
@export var unison_shield_bonus: float = 0.4
## 同步弹幕间隔（拍数）
@export var chant_attack_beats: int = 6
## 弹幕速度
@export var chant_projectile_speed: float = 160.0
## 弹幕伤害
@export var chant_projectile_damage: float = 8.0
## 编队间距
@export var formation_spacing: float = 40.0

# ============================================================
# 内部状态
# ============================================================
var _choir_beat_counter: int = 0
var _formation_intact: bool = true
var _scattered: bool = false
## 齐唱视觉连线
var _choir_lines: Array[Line2D] = []
## 圣咏吟唱视觉相位
var _chant_phase: float = 0.0
## 能量链 Shader Material（Issue #65 增强）
var _energy_link_shader: ShaderMaterial = null
## 领袖脉冲光环节点（Issue #65 增强）
var _leader_pulse_ring: Polygon2D = null
## 领袖脉冲光环相位
var _leader_pulse_phase: float = 0.0

# ============================================================
# 初始化
# ============================================================

func _on_enemy_ready() -> void:
	enemy_type = EnemyType.STATIC
	quantized_fps = 8.0
	_quantize_interval = 1.0 / quantized_fps
	knockback_resistance = 0.15
	move_on_offbeat = false
	
	# 暗金色调（中世纪教堂感）
	base_color = Color(0.8, 0.65, 0.3)
	base_glitch_intensity = 0.05
	max_glitch_intensity = 0.5
	
	# 队长 HP 更高
	if is_choir_leader:
		max_hp *= 1.5
		current_hp = max_hp
		base_color = Color(1.0, 0.8, 0.3)
	
	# Issue #65: 初始化能量链 Shader
	_setup_energy_link_shader()
	
	# Issue #65: 领袖视觉区分
	if is_choir_leader:
		_setup_leader_visuals()

## Issue #65: 初始化能量链 Shader Material
func _setup_energy_link_shader() -> void:
	var shader_res = load("res://shaders/choir_energy_link.gdshader")
	if shader_res:
		_energy_link_shader = ShaderMaterial.new()
		_energy_link_shader.shader = shader_res
		_energy_link_shader.set_shader_parameter("flow_speed", 2.0)
		_energy_link_shader.set_shader_parameter("link_intensity", 1.5)
		_energy_link_shader.set_shader_parameter("beat_energy", 0.0)

## Issue #65: 领袖视觉区分 — 增大 scale、增强 emission、添加脉冲光环
func _setup_leader_visuals() -> void:
	# 领袖 scale 增大 1.3 倍
	scale = Vector2(1.3, 1.3)
	
	# 领袖 shader emission 更强
	if _sprite and _sprite.material is ShaderMaterial:
		_sprite.material.set_shader_parameter("base_tint", Color(1.0, 0.85, 0.35, 1.0))
	
	# 领袖独特的脉冲光环效果（半透明圆环）
	_leader_pulse_ring = Polygon2D.new()
	_leader_pulse_ring.name = "LeaderPulseRing"
	_leader_pulse_ring.z_index = -1
	var ring_points := PackedVector2Array()
	var ring_segments := 24
	var ring_radius := 22.0
	for i in range(ring_segments):
		var angle := float(i) / ring_segments * TAU
		ring_points.append(Vector2(cos(angle), sin(angle)) * ring_radius)
	_leader_pulse_ring.polygon = ring_points
	_leader_pulse_ring.color = Color(1.0, 0.8, 0.3, 0.3)
	add_child(_leader_pulse_ring)

# ============================================================
# 编队管理
# ============================================================

## 设置为编队队长
func setup_as_leader(members: Array[Node2D]) -> void:
	is_choir_leader = true
	choir_members = members
	max_hp *= 1.5
	current_hp = max_hp
	base_color = Color(1.0, 0.8, 0.3)
	
	# Issue #65: 应用领袖视觉
	_setup_leader_visuals()
	
	# 为成员分配编队位置
	var count := members.size()
	for i in range(count):
		var member := members[i]
		if member == self:
			continue
		if member.has_method("set_choir_leader"):
			# V字编队
			var row := (i + 1) / 2
			var side := 1 if i % 2 == 0 else -1
			var offset := Vector2(
				-row * formation_spacing * 0.7,
				side * row * formation_spacing * 0.5
			)
			member.set_choir_leader(self, offset)

## 设置队长引用
func set_choir_leader(leader: Node2D, offset: Vector2) -> void:
	choir_leader = leader
	formation_offset = offset
	is_choir_leader = false

## 检查编队完整性
func _check_formation() -> void:
	if not is_choir_leader:
		return
	
	var alive_count := 0
	for member in choir_members:
		if is_instance_valid(member) and not member.get("_is_dead"):
			alive_count += 1
	
	_formation_intact = alive_count >= 2  # 至少2人才算编队

# ============================================================
# 每帧逻辑
# ============================================================

func _on_enemy_process(delta: float) -> void:
	# 圣咏吟唱视觉
	_chant_phase += delta * 2.0
	if _sprite:
		var chant_glow := sin(_chant_phase) * 0.1
		if _formation_intact and not _scattered:
			# 编队完整时发光更强
			_sprite.modulate = base_color.lerp(Color(1.0, 0.9, 0.5), 0.2 + chant_glow)
		else:
			_sprite.modulate = base_color
	
	# 队长更新编队状态
	if is_choir_leader:
		_check_formation()
		_update_choir_lines()
		
		# Issue #65: 更新领袖脉冲光环
		_update_leader_pulse(delta)
		
		# Issue #65: 更新能量链 shader uniform
		if _energy_link_shader:
			var beat_e := (sin(_chant_phase * 3.0) + 1.0) * 0.5
			_energy_link_shader.set_shader_parameter("beat_energy", beat_e)

## Issue #65: 更新领袖脉冲光环效果
func _update_leader_pulse(delta: float) -> void:
	if not _leader_pulse_ring:
		return
	_leader_pulse_phase += delta * 3.0
	var pulse := (sin(_leader_pulse_phase) + 1.0) * 0.5
	var ring_scale := 1.0 + pulse * 0.3
	_leader_pulse_ring.scale = Vector2(ring_scale, ring_scale)
	_leader_pulse_ring.color.a = 0.15 + pulse * 0.25

func _update_choir_lines() -> void:
	# 清理旧连线
	for line in _choir_lines:
		if is_instance_valid(line):
			line.queue_free()
	_choir_lines.clear()
	
	if not is_choir_leader or _scattered:
		return
	
	# Issue #65: 绘制编队连线（使用能量链 shader）
	for member in choir_members:
		if not is_instance_valid(member) or member == self or member.get("_is_dead"):
			continue
		var line := Line2D.new()
		line.width = 6.0  # Issue #65: 增加线条宽度
		line.default_color = Color(0.6, 0.1, 0.1, 0.8)  # 暗红色基调
		# Issue #65: 应用能量链 shader
		if _energy_link_shader:
			line.material = _energy_link_shader
		line.add_point(global_position)
		line.add_point(member.global_position)
		get_parent().add_child(line)
		_choir_lines.append(line)

# ============================================================
# 移动逻辑
# ============================================================

func _calculate_movement_direction() -> Vector2:
	# 散开后变为普通 Static 行为
	if _scattered:
		if _target:
			return (_target.global_position - global_position).normalized()
		return Vector2.ZERO
	
	# 队长：朝向玩家移动
	if is_choir_leader:
		if _target:
			return (_target.global_position - global_position).normalized()
		return Vector2.ZERO
	
	# 成员：跟随队长编队位置
	if choir_leader and is_instance_valid(choir_leader) and not choir_leader.get("_is_dead"):
		var target_pos := choir_leader.global_position + formation_offset
		var to_target := target_pos - global_position
		if to_target.length() > 5.0:
			return to_target.normalized()
		return Vector2.ZERO
	else:
		# 队长死亡，散开
		_scatter()
		if _target:
			return (_target.global_position - global_position).normalized()
		return Vector2.ZERO

## Issue #65: 增强版编队散开 — 能量链断裂动画 + 闪光效果
func _scatter() -> void:
	if _scattered:
		return
	_scattered = true
	choir_leader = null
	
	# 散开时短暂加速
	move_speed *= 1.5
	
	# Issue #65: 能量链断裂动画（线条快速收缩并消失）
	for line in _choir_lines:
		if is_instance_valid(line):
			var line_tween := line.create_tween()
			line_tween.tween_property(line, "width", 0.0, 0.15).set_trans(Tween.TRANS_EXPO)
			line_tween.tween_callback(line.queue_free)
	_choir_lines.clear()
	
	# Issue #65: 散开时的闪光效果
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "modulate", Color(1.0, 0.9, 0.5, 1.0), 0.05)
		tween.tween_property(_sprite, "modulate", Color.WHITE, 0.1)
		tween.tween_property(_sprite, "modulate", base_color, 0.3)

## Issue #65: 提供获取 sprite 的方法（供管理器使用）
func get_sprite() -> Node2D:
	return _sprite

## Issue #65: 播放闪光效果（供外部调用）
func play_flash_effect() -> void:
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "modulate", Color.WHITE, 0.08)
		tween.tween_property(_sprite, "modulate", base_color, 0.25)

# ============================================================
# 伤害处理：齐唱护盾
# ============================================================

func take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO, is_perfect_beat: bool = false) -> void:
	var final_amount := amount
	
	# 编队完整时获得齐唱护盾（减伤）
	if _formation_intact and not _scattered:
		final_amount *= (1.0 - unison_shield_bonus)
	
	super.take_damage(final_amount, knockback_dir, is_perfect_beat)

# ============================================================
# 节拍响应：同步圣咏弹幕
# ============================================================

func _on_beat(_beat_index: int) -> void:
	_choir_beat_counter += 1
	
	# 节拍脉冲
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "scale", Vector2(1.15, 1.15), 0.05)
		tween.tween_property(_sprite, "scale", Vector2(1.0, 1.0), 0.1)
	
	# 队长在指定拍数时指挥全体发射弹幕
	if is_choir_leader and _choir_beat_counter % chant_attack_beats == 0:
		_fire_choir_chant()

## 编队齐射：所有成员同时向玩家发射直线弹幕
func _fire_choir_chant() -> void:
	if _target == null:
		return
	
	# 自己发射
	_fire_chant_projectile()
	
	# 指挥成员发射
	for member in choir_members:
		if is_instance_valid(member) and member != self and not member.get("_is_dead"):
			if member.has_method("_fire_chant_projectile"):
				member._fire_chant_projectile()

## 发射圣咏弹幕
func _fire_chant_projectile() -> void:
	if _target == null:
		return
	
	var angle := (global_position.direction_to(_target.global_position)).angle()
	
	var proj := Area2D.new()
	proj.add_to_group("enemy_projectiles")
	
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20, 6)
	col.shape = shape
	col.rotation = angle
	proj.add_child(col)
	
	# 视觉：横向音符条（圣咏音墙）
	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(-10, -3), Vector2(10, -3), Vector2(10, 3), Vector2(-10, 3)
	])
	visual.color = Color(0.9, 0.75, 0.3, 0.8)
	visual.rotation = angle
	proj.add_child(visual)
	
	proj.global_position = global_position
	get_parent().add_child(proj)
	
	var vel := Vector2.from_angle(angle) * chant_projectile_speed
	var tween := proj.create_tween()
	tween.tween_property(proj, "global_position",
		proj.global_position + vel * 3.0, 3.0)
	tween.tween_callback(proj.queue_free)
	
	proj.body_entered.connect(func(body: Node2D):
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(chant_projectile_damage)
			proj.queue_free()
	)

# ============================================================
# 死亡效果
# ============================================================

func _on_death_effect() -> void:
	# 队长死亡时散开所有成员
	if is_choir_leader:
		for member in choir_members:
			if is_instance_valid(member) and member != self and not member.get("_is_dead"):
				if member.has_method("_scatter"):
					member._scatter()
	
	# Issue #65: 领袖脉冲光环消失动画
	if _leader_pulse_ring:
		var pulse_tween := create_tween()
		pulse_tween.tween_property(_leader_pulse_ring, "modulate:a", 0.0, 0.2)
		pulse_tween.tween_callback(_leader_pulse_ring.queue_free)
	
	# 清理连线
	for line in _choir_lines:
		if is_instance_valid(line):
			line.queue_free()
	_choir_lines.clear()
