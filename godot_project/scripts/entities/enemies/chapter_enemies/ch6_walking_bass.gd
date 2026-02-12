## ch6_walking_bass.gd
## 第六章特色敌人：行走贝斯 (Walking Bass)
## 沿着爵士行走贝斯线的音阶路径移动的敌人。
## 音乐隐喻：爵士乐中行走贝斯的稳定律动，四分音符逐级进行。
##
## 程序化视觉实现 (Issue #69):
## - 低音提琴轮廓由霓虹灯管 (Line2D) 构成
## - 流动色彩效果：颜色沿轮廓随布鲁斯音阶流动
## - 音符符号轨迹VFX：行走路径留下发光音符
## - 低频脉冲波纹视觉增强
##
## 机制：
## - 沿预设的音阶路径移动（非直线追踪）
## - 每到达一个"音符节点"时释放低频脉冲
## - 路径上留下持续伤害的"贝斯线"轨迹（音符符号）
## - 多个行走贝斯会形成和声路径网络
## - 在反拍（2、4拍）时移动速度加倍（摇摆感）
extends "res://scripts/entities/enemy_base.gd"

# ============================================================
# Walking Bass 专属配置
# ============================================================

## 路径节点间距
@export var path_step_distance: float = 60.0
## 低频脉冲伤害
@export var pulse_damage: float = 8.0
## 低频脉冲范围
@export var pulse_radius: float = 80.0
## 轨迹持续时间
@export var trail_duration: float = 5.0
## 轨迹伤害/秒
@export var trail_dps: float = 5.0
## 反拍速度倍率
@export var offbeat_speed_mult: float = 2.0
## 音阶模式（蓝调音阶度数）
@export var scale_degrees: Array[int] = [0, 2, 3, 5, 7, 9, 10, 12]

## === 程序化视觉配置 (Issue #69) ===
## 霓虹灯管宽度
@export var neon_tube_width: float = 3.0
## 霓虹灯管辉光宽度
@export var neon_glow_width: float = 8.0
## 霓虹色彩循环速度
@export var color_flow_speed: float = 2.0
## 霓虹基础色（深棕 + 霓虹轮廓）
@export var neon_base_color: Color = Color(0.3, 0.15, 0.1)
## 霓虹色彩调色板（布鲁斯音阶对应的颜色）
var _neon_palette: Array[Color] = [
	Color(0.0, 0.8, 1.0),   # 电蓝 — 根音
	Color(0.9, 0.2, 0.8),   # 霓虹粉 — 小三度
	Color(1.0, 0.6, 0.0),   # 琥珀 — 四度
	Color(0.2, 1.0, 0.4),   # 霓虹绿 — 五度
	Color(1.0, 0.1, 0.3),   # 霓虹红 — 小七度
	Color(0.6, 0.3, 1.0),   # 霓虹紫 — 蓝调音
]

# ============================================================
# 内部状态
# ============================================================

## 路径系统
var _path_nodes: Array[Vector2] = []
var _current_path_index: int = 0
var _path_direction: int = 1  # 1=正向, -1=反向
var _base_move_speed: float = 0.0

## 轨迹系统
var _trail_segments: Array[Dictionary] = []  # {node, position, timer}

## 脉冲冷却
var _pulse_cooldown: float = 0.0

## 节拍状态
var _is_offbeat: bool = false
var _beat_counter: int = 0

## === 程序化视觉节点 (Issue #69) ===
var _bass_visual: Node2D = null           # 低音提琴视觉容器
var _neon_outline: Line2D = null          # 霓虹灯管轮廓
var _neon_glow: Line2D = null             # 霓虹辉光层
var _neon_fill: Polygon2D = null          # 内部填充
var _strings: Array[Line2D] = []          # 琴弦
var _f_holes: Array[Polygon2D] = []       # f孔
var _color_flow_phase: float = 0.0        # 色彩流动相位
var _sway_phase: float = 0.0             # 摇摆相位
var _note_trail_nodes: Array[Dictionary] = []  # 音符轨迹 {node, timer}

# ============================================================
# 初始化
# ============================================================

func _on_enemy_ready() -> void:
	enemy_type = EnemyType.PULSE
	quantized_fps = 12.0
	_quantize_interval = 1.0 / quantized_fps
	knockback_resistance = 0.3
	move_on_offbeat = true  # 反拍移动
	
	base_color = neon_base_color
	base_glitch_intensity = 0.05
	max_glitch_intensity = 0.6
	
	_base_move_speed = move_speed
	
	# 生成程序化视觉
	_build_bass_visual()
	
	# 生成初始路径
	_generate_bass_path()
	
	# 将程序化视觉节点注册为 enemy_base 的 _sprite
	# 使基类的 _update_visual 能正确操作程序化视觉
	_sprite = _bass_visual

# ============================================================
# 程序化低音提琴霓虹灯管轮廓 (Issue #69)
# ============================================================

## 生成低音提琴的程序化霓虹灯管轮廓
func _build_bass_visual() -> void:
	_bass_visual = Node2D.new()
	_bass_visual.name = "BassVisual"
	
	# 低音提琴轮廓点（简化的提琴形状）
	var outline_points := _generate_bass_outline()
	
	# --- 1. 内部填充（暗色半透明） ---
	_neon_fill = Polygon2D.new()
	_neon_fill.polygon = outline_points
	_neon_fill.color = Color(neon_base_color.r, neon_base_color.g, neon_base_color.b, 0.3)
	_bass_visual.add_child(_neon_fill)
	
	# --- 2. 霓虹辉光层（宽、低透明度） ---
	_neon_glow = Line2D.new()
	_neon_glow.name = "NeonGlow"
	_neon_glow.width = neon_glow_width
	_neon_glow.default_color = Color(0.0, 0.8, 1.0, 0.2)
	_neon_glow.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_neon_glow.end_cap_mode = Line2D.LINE_CAP_ROUND
	_neon_glow.closed = true
	for p in outline_points:
		_neon_glow.add_point(p)
	_bass_visual.add_child(_neon_glow)
	
	# --- 3. 霓虹灯管轮廓（窄、高亮度） ---
	_neon_outline = Line2D.new()
	_neon_outline.name = "NeonOutline"
	_neon_outline.width = neon_tube_width
	_neon_outline.default_color = Color(0.0, 0.8, 1.0, 0.9)
	_neon_outline.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_neon_outline.end_cap_mode = Line2D.LINE_CAP_ROUND
	_neon_outline.closed = true
	for p in outline_points:
		_neon_outline.add_point(p)
	_bass_visual.add_child(_neon_outline)
	
	# --- 4. 琴弦 ---
	_build_strings()
	
	# --- 5. f孔 ---
	_build_f_holes()
	
	add_child(_bass_visual)

## 生成低音提琴轮廓点
func _generate_bass_outline() -> PackedVector2Array:
	var points := PackedVector2Array()
	
	# 低音提琴形状：上窄下宽，中间有腰线
	# 使用参数化曲线生成
	var segments := 32
	for i in range(segments):
		var t := float(i) / float(segments)
		var angle := t * TAU
		
		# 基础椭圆
		var rx: float
		var ry: float
		
		# 提琴形状的宽度调制
		var y_norm := sin(angle)  # -1 到 1
		
		if y_norm > 0.3:
			# 上半部（琴头方向）— 较窄
			var st := (y_norm - 0.3) / 0.7
			rx = lerpf(8.0, 5.0, st)
		elif y_norm > -0.1:
			# 腰线 — 最窄
			var st := (y_norm + 0.1) / 0.4
			rx = lerpf(6.0, 8.0, abs(st - 0.5) * 2.0)
		else:
			# 下半部（琴身方向）— 较宽
			var st := (-y_norm - 0.1) / 0.9
			rx = lerpf(8.0, 11.0, st)
		
		ry = 18.0  # 纵向高度
		
		var x := cos(angle) * rx
		var y := sin(angle) * ry
		
		points.append(Vector2(x, y))
	
	return points

## 生成琴弦
func _build_strings() -> void:
	var string_count := 4
	var string_spacing := 3.0
	var start_x := -string_spacing * (string_count - 1) * 0.5
	
	for i in range(string_count):
		var string_line := Line2D.new()
		string_line.width = 1.0
		var x := start_x + i * string_spacing
		string_line.add_point(Vector2(x, -14.0))
		string_line.add_point(Vector2(x, 14.0))
		string_line.default_color = Color(0.8, 0.7, 0.5, 0.5)
		_bass_visual.add_child(string_line)
		_strings.append(string_line)

## 生成 f 孔
func _build_f_holes() -> void:
	for side in [-1.0, 1.0]:
		var f_hole := Polygon2D.new()
		var points := PackedVector2Array()
		
		# 简化的 f 形状
		var segments := 8
		for i in range(segments + 1):
			var t := float(i) / float(segments)
			var x := sin(t * PI * 1.5) * 2.0 * side + side * 4.0
			var y := lerpf(-5.0, 5.0, t)
			points.append(Vector2(x, y))
		
		# 回程
		for i in range(segments, -1, -1):
			var t := float(i) / float(segments)
			var x := sin(t * PI * 1.5) * 1.0 * side + side * 4.0
			var y := lerpf(-5.0, 5.0, t)
			points.append(Vector2(x, y))
		
		f_hole.polygon = points
		f_hole.color = Color(0.0, 0.6, 0.8, 0.4)
		_bass_visual.add_child(f_hole)
		_f_holes.append(f_hole)

# ============================================================
# 流动色彩效果 (Issue #69)
# ============================================================

## 更新霓虹灯管的流动色彩
func _update_color_flow(delta: float) -> void:
	_color_flow_phase += delta * color_flow_speed
	
	if _neon_outline == null or _neon_glow == null:
		return
	
	# 使用 Gradient 模拟流动色彩
	var point_count := _neon_outline.get_point_count()
	if point_count == 0:
		return
	
	# 为每个线段点设置不同颜色（模拟色彩流动）
	# Line2D 使用 gradient 属性来实现
	var gradient := Gradient.new()
	var color_count := _neon_palette.size()
	
	for i in range(color_count):
		var offset := fmod(float(i) / float(color_count) + _color_flow_phase * 0.1, 1.0)
		gradient.add_point(offset, _neon_palette[i])
	
	# 排序 gradient 点
	# 由于 Godot Gradient 自动排序，直接设置即可
	_neon_outline.gradient = gradient
	
	# 辉光层使用相同渐变但降低透明度
	var glow_gradient := gradient.duplicate()
	for i in range(glow_gradient.get_point_count()):
		var c := glow_gradient.get_color(i)
		c.a = 0.25
		glow_gradient.set_color(i, c)
	_neon_glow.gradient = glow_gradient

## 更新琴弦振动效果
func _update_string_vibration(delta: float) -> void:
	for i in range(_strings.size()):
		var string_line := _strings[i]
		if not is_instance_valid(string_line):
			continue
		
		# 琴弦振动（不同频率）
		var freq := 3.0 + i * 1.5
		var amp := 1.0 + sin(_sway_phase * 0.5) * 0.5
		
		# 更新中间点（添加振动偏移）
		if string_line.get_point_count() == 2:
			# 添加中间点以实现弯曲
			string_line.clear_points()
			string_line.add_point(Vector2(string_line.get_meta("start_x", 0), -14.0))
			for j in range(1, 5):
				var t := float(j) / 5.0
				var y := lerpf(-14.0, 14.0, t)
				var vibration := sin(_sway_phase * freq + t * PI) * amp
				string_line.add_point(Vector2(vibration, y))
			string_line.add_point(Vector2(0, 14.0))
		else:
			for j in range(1, string_line.get_point_count() - 1):
				var t := float(j) / float(string_line.get_point_count() - 1)
				var vibration := sin(_sway_phase * freq + t * PI) * amp
				string_line.set_point_position(j, Vector2(vibration + string_line.get_point_position(j).x * 0.1, string_line.get_point_position(j).y))

# ============================================================
# 音符符号轨迹 VFX (Issue #69)
# ============================================================

## 生成音符符号轨迹
func _spawn_note_trail() -> void:
	var note_node := Node2D.new()
	note_node.global_position = global_position
	
	# 随机选择音符类型
	var note_type := randi() % 3
	
	match note_type:
		0:
			_draw_quarter_note(note_node)
		1:
			_draw_eighth_note(note_node)
		2:
			_draw_bass_clef(note_node)
	
	# 使用当前流动色彩
	var color_index := randi() % _neon_palette.size()
	var note_color := _neon_palette[color_index]
	note_node.modulate = note_color
	
	get_parent().add_child(note_node)
	
	# 音符上浮动画
	var tween := note_node.create_tween()
	tween.set_parallel(true)
	tween.tween_property(note_node, "position:y", note_node.position.y - 20.0, trail_duration).as_relative()
	tween.tween_property(note_node, "modulate:a", 0.0, trail_duration)
	tween.tween_property(note_node, "rotation", randf_range(-0.3, 0.3), trail_duration)
	tween.chain()
	tween.tween_callback(note_node.queue_free)
	
	_note_trail_nodes.append({
		"node": note_node,
		"timer": trail_duration,
		"position": global_position,
	})

## 绘制四分音符
func _draw_quarter_note(parent: Node2D) -> void:
	# 音符头（实心椭圆）
	var head := Polygon2D.new()
	var points := PackedVector2Array()
	for i in range(12):
		var angle := (TAU / 12.0) * i
		points.append(Vector2(cos(angle) * 3.5, sin(angle) * 2.5 + 4.0))
	head.polygon = points
	head.color = Color.WHITE
	parent.add_child(head)
	
	# 符杆
	var stem := Line2D.new()
	stem.width = 1.5
	stem.default_color = Color.WHITE
	stem.add_point(Vector2(3.0, 4.0))
	stem.add_point(Vector2(3.0, -8.0))
	parent.add_child(stem)

## 绘制八分音符
func _draw_eighth_note(parent: Node2D) -> void:
	# 音符头
	var head := Polygon2D.new()
	var points := PackedVector2Array()
	for i in range(12):
		var angle := (TAU / 12.0) * i
		points.append(Vector2(cos(angle) * 3.5, sin(angle) * 2.5 + 4.0))
	head.polygon = points
	head.color = Color.WHITE
	parent.add_child(head)
	
	# 符杆
	var stem := Line2D.new()
	stem.width = 1.5
	stem.default_color = Color.WHITE
	stem.add_point(Vector2(3.0, 4.0))
	stem.add_point(Vector2(3.0, -8.0))
	parent.add_child(stem)
	
	# 符尾（旗帜）
	var flag := Line2D.new()
	flag.width = 1.5
	flag.default_color = Color.WHITE
	flag.add_point(Vector2(3.0, -8.0))
	flag.add_point(Vector2(6.0, -4.0))
	flag.add_point(Vector2(5.0, -2.0))
	parent.add_child(flag)

## 绘制低音谱号（简化）
func _draw_bass_clef(parent: Node2D) -> void:
	# 简化的低音谱号
	var clef := Line2D.new()
	clef.width = 2.0
	clef.default_color = Color.WHITE
	clef.begin_cap_mode = Line2D.LINE_CAP_ROUND
	clef.end_cap_mode = Line2D.LINE_CAP_ROUND
	
	# C形曲线
	for i in range(12):
		var t := float(i) / 11.0
		var angle := t * PI * 1.2 + PI * 0.4
		var r := 5.0 - t * 2.0
		clef.add_point(Vector2(cos(angle) * r, sin(angle) * r))
	parent.add_child(clef)
	
	# 两个点
	for dy in [-2.0, 2.0]:
		var dot := Polygon2D.new()
		var points := PackedVector2Array()
		for i in range(6):
			var angle := (TAU / 6.0) * i
			points.append(Vector2(cos(angle) * 1.2 + 4.0, sin(angle) * 1.2 + dy))
		dot.polygon = points
		dot.color = Color.WHITE
		parent.add_child(dot)

# ============================================================
# 路径系统
# ============================================================

func _generate_bass_path() -> void:
	_path_nodes.clear()
	
	# 以当前位置为起点，沿音阶度数生成路径
	var start_pos := global_position
	var base_angle := randf() * TAU
	
	for i in range(scale_degrees.size()):
		var degree := scale_degrees[i]
		# 每个音阶度数对应一个方向偏移
		var angle := base_angle + degree * deg_to_rad(12.0)
		var pos := start_pos + Vector2.from_angle(angle) * path_step_distance * (i + 1)
		_path_nodes.append(pos)
	
	_current_path_index = 0

# ============================================================
# 每帧逻辑
# ============================================================

func _on_enemy_process(delta: float) -> void:
	_sway_phase += delta * 3.0
	
	# 更新程序化视觉
	_update_color_flow(delta)
	_update_bass_sway(delta)
	_update_note_trails(delta)
	
	# 更新轨迹
	_update_trails(delta)
	
	# 脉冲冷却
	if _pulse_cooldown > 0.0:
		_pulse_cooldown -= delta
	
	# 速度调整（反拍加速）
	if _is_offbeat:
		move_speed = _base_move_speed * offbeat_speed_mult
	else:
		move_speed = _base_move_speed

## 更新低音提琴的摇摆动画
func _update_bass_sway(delta: float) -> void:
	if _bass_visual == null:
		return
	
	# 爵士摇摆：三连音律动的摇摆惯性
	var swing := sin(_sway_phase) * 4.0
	var swing_tilt := sin(_sway_phase * 0.7) * 0.1
	
	_bass_visual.position.x = swing
	_bass_visual.rotation = swing_tilt
	
	# 反拍时的弹跳
	if _is_offbeat:
		var bounce := abs(sin(_sway_phase * 4.0)) * 3.0
		_bass_visual.position.y = -bounce

## 更新音符轨迹
func _update_note_trails(delta: float) -> void:
	var expired: Array[int] = []
	for i in range(_note_trail_nodes.size()):
		var note := _note_trail_nodes[i]
		note["timer"] -= delta
		if note["timer"] <= 0.0:
			expired.append(i)
		else:
			# 轨迹伤害
			if _target and is_instance_valid(_target):
				var dist := _target.global_position.distance_to(note["position"])
				if dist < 20.0:
					if _target.has_method("take_damage"):
						_target.take_damage(trail_dps * delta)
	
	for i in range(expired.size() - 1, -1, -1):
		_note_trail_nodes.remove_at(expired[i])

func _update_trails(delta: float) -> void:
	var expired: Array[int] = []
	for i in range(_trail_segments.size()):
		var seg := _trail_segments[i]
		seg["timer"] -= delta
		if seg["timer"] <= 0.0:
			expired.append(i)
			if is_instance_valid(seg["node"]):
				seg["node"].queue_free()
		else:
			# 轨迹伤害
			if _target and is_instance_valid(_target):
				var dist := _target.global_position.distance_to(seg["position"])
				if dist < 20.0:
					if _target.has_method("take_damage"):
						_target.take_damage(trail_dps * delta)
			# 淡出
			if is_instance_valid(seg["node"]):
				seg["node"].modulate.a = seg["timer"] / trail_duration
	
	# 移除过期轨迹
	for i in range(expired.size() - 1, -1, -1):
		_trail_segments.remove_at(expired[i])

# ============================================================
# 移动逻辑
# ============================================================

func _calculate_movement_direction() -> Vector2:
	if _path_nodes.is_empty():
		_generate_bass_path()
		return Vector2.ZERO
	
	var target_pos := _path_nodes[_current_path_index]
	var dir := (target_pos - global_position)
	var dist := dir.length()
	
	if dist < 15.0:
		# 到达节点：释放脉冲 + 留下音符轨迹
		_on_reach_path_node()
		
		# 移动到下一个节点
		_current_path_index += _path_direction
		if _current_path_index >= _path_nodes.size():
			_path_direction = -1
			_current_path_index = _path_nodes.size() - 2
		elif _current_path_index < 0:
			_path_direction = 1
			_current_path_index = 1
			# 重新生成路径（朝向玩家）
			if _target and is_instance_valid(_target):
				_regenerate_path_toward_player()
	
	return dir.normalized()

func _regenerate_path_toward_player() -> void:
	_path_nodes.clear()
	var start_pos := global_position
	var base_angle := (global_position.direction_to(_target.global_position)).angle()
	
	for i in range(scale_degrees.size()):
		var degree := scale_degrees[i]
		var angle := base_angle + degree * deg_to_rad(8.0) - deg_to_rad(40.0)
		var pos := start_pos + Vector2.from_angle(angle) * path_step_distance * (i + 1)
		_path_nodes.append(pos)
	
	_current_path_index = 0
	_path_direction = 1

# ============================================================
# 路径节点到达事件
# ============================================================

func _on_reach_path_node() -> void:
	# 释放低频脉冲
	if _pulse_cooldown <= 0.0:
		_pulse_cooldown = 1.0
		_fire_bass_pulse()
	
	# 留下音符轨迹 (Issue #69)
	_spawn_note_trail()
	
	# 留下伤害轨迹
	_spawn_trail_segment()

func _fire_bass_pulse() -> void:
	# 视觉：霓虹色低频脉冲波 (Issue #69 增强)
	# OPT03: 攻击时触发音高层
	if _audio_controller:
		_audio_controller.play_behavior_pitch("attack")
	var ring_container := Node2D.new()
	ring_container.global_position = global_position
	get_parent().add_child(ring_container)
	
	# 多层脉冲环（霓虹色）
	for layer in range(3):
		var ring := Polygon2D.new()
		var points := PackedVector2Array()
		var inner_r := 4.0 + layer * 2.0
		var outer_r := inner_r + 2.0
		
		# 环形多边形
		var seg_count := 24
		for i in range(seg_count):
			var angle := (TAU / seg_count) * i
			points.append(Vector2(cos(angle) * outer_r, sin(angle) * outer_r))
		for i in range(seg_count - 1, -1, -1):
			var angle := (TAU / seg_count) * i
			points.append(Vector2(cos(angle) * inner_r, sin(angle) * inner_r))
		
		ring.polygon = points
		var color_idx := (layer + int(_color_flow_phase * 2.0)) % _neon_palette.size()
		ring.color = _neon_palette[color_idx]
		ring.color.a = 0.6 - layer * 0.15
		ring_container.add_child(ring)
	
	var tween := ring_container.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring_container, "scale", Vector2(pulse_radius / 5.0, pulse_radius / 5.0), 0.4)
	tween.tween_property(ring_container, "modulate:a", 0.0, 0.5)
	tween.chain()
	tween.tween_callback(ring_container.queue_free)
	
	# 伤害
	if _target and is_instance_valid(_target):
		if global_position.distance_to(_target.global_position) < pulse_radius:
			if _target.has_method("take_damage"):
				_target.take_damage(pulse_damage)

func _spawn_trail_segment() -> void:
	# 发光的贝斯线轨迹段 (Issue #69 增强)
	var trail := Line2D.new()
	trail.width = 3.0
	var color_idx := int(_color_flow_phase * 3.0) % _neon_palette.size()
	trail.default_color = _neon_palette[color_idx]
	trail.default_color.a = 0.6
	trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	
	# 短波浪线段
	for i in range(5):
		var t := float(i) / 4.0
		var x := lerpf(-8.0, 8.0, t)
		var y := sin(t * PI * 2.0) * 3.0
		trail.add_point(Vector2(x, y))
	
	trail.global_position = global_position
	get_parent().add_child(trail)
	
	_trail_segments.append({
		"node": trail,
		"position": global_position,
		"timer": trail_duration,
	})

# ============================================================
# 节拍回调
# ============================================================

func _on_beat(_beat_index: int) -> void:
	_beat_counter += 1
	_is_offbeat = false
	
	# 强拍：霓虹脉冲 (Issue #69)
	if _bass_visual:
		var tween := create_tween()
		tween.tween_property(_bass_visual, "scale", Vector2(1.3, 0.8), 0.05)
		tween.tween_property(_bass_visual, "scale", Vector2(1.0, 1.0), 0.1)
	
	# 琴弦闪亮
	for string_line in _strings:
		if is_instance_valid(string_line):
			string_line.default_color = Color(1.0, 1.0, 1.0, 0.9)
			var tween2 := create_tween()
			tween2.tween_property(string_line, "default_color", Color(0.8, 0.7, 0.5, 0.5), 0.2)

func _on_half_beat(_half_beat_index: int) -> void:
	_is_offbeat = true
	
	# 反拍：加速脉冲 + 霓虹闪烁 (Issue #69)
	if _bass_visual:
		var tween := create_tween()
		tween.tween_property(_bass_visual, "scale", Vector2(0.8, 1.2), 0.03)
		tween.tween_property(_bass_visual, "scale", Vector2(1.0, 1.0), 0.08)
	
	# 霓虹轮廓闪亮
	if _neon_outline:
		_neon_outline.width = neon_tube_width * 2.0
		var tween2 := create_tween()
		tween2.tween_property(_neon_outline, "width", neon_tube_width, 0.15)

# ============================================================
# 死亡效果
# ============================================================

func _on_death_effect() -> void:
	# 死亡时释放最终低频脉冲
	_fire_bass_pulse()
	
	# 霓虹灯管碎裂效果 (Issue #69)
	_spawn_neon_shatter()
	
	# 清理所有轨迹
	for seg in _trail_segments:
		if is_instance_valid(seg["node"]):
			seg["node"].queue_free()
	_trail_segments.clear()

## 霓虹灯管碎裂效果
func _spawn_neon_shatter() -> void:
	var shard_count := 12
	for i in range(shard_count):
		var shard := Line2D.new()
		shard.width = neon_tube_width
		var color_idx := i % _neon_palette.size()
		shard.default_color = _neon_palette[color_idx]
		
		# 短线段碎片
		var length := randf_range(5.0, 12.0)
		var angle := randf() * TAU
		shard.add_point(Vector2.ZERO)
		shard.add_point(Vector2.from_angle(angle) * length)
		
		shard.global_position = global_position
		get_parent().add_child(shard)
		
		var dir := Vector2.from_angle(angle)
		var speed := randf_range(60.0, 150.0)
		var target_pos := shard.global_position + dir * speed
		
		var tween := shard.create_tween()
		tween.set_parallel(true)
		tween.tween_property(shard, "global_position", target_pos, 0.5)
		tween.tween_property(shard, "modulate:a", 0.0, 0.6)
		tween.tween_property(shard, "rotation", randf_range(-PI, PI), 0.5)
		tween.chain()
		tween.tween_callback(shard.queue_free)

func _get_type_name() -> String:
	return "ch6_walking_bass"
