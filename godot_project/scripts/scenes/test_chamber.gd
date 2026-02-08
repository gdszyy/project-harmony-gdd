## test_chamber.gd
## 回响试炼场 (The Echoing Chamber) — 测试场主逻辑
##
## 功能概述：
##   1. 自由生成任意敌人（类型、数量、等级可调）
##   2. 自由配置玩家属性（HP、伤害倍率、移速等）
##   3. 自由测试法术系统（音符、和弦、修饰符、音色）
##   4. 实时 DPS 统计与伤害日志
##   5. 无限生命 / 无限法力 / 时间暂停等调试开关
##   6. 快速切换调式和章节环境
##   7. 一键解锁全部图鉴条目
##
## 场景结构：
##   TestChamber (Node2D)
##     ├── Ground (背景)
##     ├── Player (玩家)
##     ├── EnemyContainer (敌人容器)
##     ├── ProjectileManager (弹体管理)
##     ├── HUD (游戏 HUD)
##     ├── DebugPanel (调试面板 — 左侧可折叠)
##     └── DPSOverlay (DPS 统计覆盖层)
extends Node2D

# ============================================================
# 信号
# ============================================================
signal debug_message(text: String)

# ============================================================
# 常量
# ============================================================
const ARENA_SIZE := Vector2(3000, 3000)
const ARENA_CENTER := ARENA_SIZE / 2.0
const GRID_SIZE := 100.0
const GRID_COLOR := Color(0.08, 0.06, 0.14, 0.5)
const GRID_ACCENT := Color(0.15, 0.10, 0.25, 0.6)
const BORDER_COLOR := Color(0.6, 0.3, 1.0, 0.8)

# 敌人场景路径
const ENEMY_SCENES: Dictionary = {
	"static":  "res://scenes/enemies/enemy_static.tscn",
	"silence": "res://scenes/enemies/enemy_silence.tscn",
	"screech": "res://scenes/enemies/enemy_screech.tscn",
	"pulse":   "res://scenes/enemies/enemy_pulse.tscn",
	"wall":    "res://scenes/enemies/enemy_wall.tscn",
}

# ============================================================
# 节点引用
# ============================================================
@onready var _player: CharacterBody2D = $Player
@onready var _enemy_container: Node2D = $EnemyContainer
@onready var _projectile_manager: Node2D = $ProjectileManager
@onready var _hud: CanvasLayer = $HUD

# ============================================================
# 调试状态
# ============================================================
var god_mode: bool = false          ## 无敌模式
var infinite_fatigue: bool = false   ## 无限疲劳（不增长）
var freeze_enemies: bool = false     ## 冻结敌人
var show_hitboxes: bool = false      ## 显示碰撞箱
var auto_fire: bool = false          ## 自动施法
var time_scale: float = 1.0         ## 时间缩放

# DPS 统计
var _dps_tracker: Dictionary = {
	"total_damage": 0.0,
	"session_start": 0.0,
	"damage_log": [],       # [{time, damage, source}]
	"window_damage": 0.0,   # 5秒窗口伤害
	"window_start": 0.0,
	"current_dps": 0.0,
	"peak_dps": 0.0,
}

# 生成的敌人计数
var _spawned_count: int = 0
var _killed_count: int = 0

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_dps_tracker["session_start"] = Time.get_ticks_msec() / 1000.0
	_dps_tracker["window_start"] = _dps_tracker["session_start"]

	# 将玩家放在场地中心
	if _player:
		_player.position = ARENA_CENTER

	# 设置 GameManager 为测试模式
	if GameManager:
		GameManager.is_test_mode = true

	_log("回响试炼场已启动。使用左侧调试面板控制测试环境。")

func _process(delta: float) -> void:
	# 应用时间缩放
	Engine.time_scale = time_scale

	# God mode
	if god_mode and _player and _player.has_method("set_hp"):
		_player.set_hp(_player.max_hp)

	# 冻结敌人
	if freeze_enemies:
		for enemy in _enemy_container.get_children():
			if enemy.has_method("set_frozen"):
				enemy.set_frozen(true)

	# 无限疲劳
	if infinite_fatigue and GameManager:
		GameManager.fatigue = 0.0

	# 更新 DPS 窗口
	_update_dps_window()

	# 绘制调试信息
	if show_hitboxes:
		queue_redraw()

func _draw() -> void:
	# 绘制竞技场网格
	_draw_arena_grid()

	# 绘制竞技场边界
	_draw_arena_border()

	# 绘制碰撞箱
	if show_hitboxes:
		_draw_hitboxes()

func _unhandled_input(event: InputEvent) -> void:
	# 快捷键
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F1:
				god_mode = !god_mode
				_log("无敌模式: %s" % ("开启" if god_mode else "关闭"))
			KEY_F2:
				infinite_fatigue = !infinite_fatigue
				_log("无限疲劳: %s" % ("开启" if infinite_fatigue else "关闭"))
			KEY_F3:
				freeze_enemies = !freeze_enemies
				_log("冻结敌人: %s" % ("开启" if freeze_enemies else "关闭"))
			KEY_F4:
				show_hitboxes = !show_hitboxes
				queue_redraw()
				_log("碰撞箱显示: %s" % ("开启" if show_hitboxes else "关闭"))
			KEY_F5:
				_clear_all_enemies()
			KEY_F6:
				_reset_dps()
			KEY_F7:
				time_scale = 0.5 if time_scale == 1.0 else 1.0
				_log("时间缩放: %.1fx" % time_scale)
			KEY_F8:
				_spawn_wave_preset("mixed_basic")
			KEY_F9:
				if CodexManager:
					CodexManager.unlock_all()
					_log("已解锁全部图鉴条目")

# ============================================================
# 敌人生成
# ============================================================

## 生成指定类型的敌人
func spawn_enemy(enemy_type: String, count: int = 1, position_mode: String = "random") -> void:
	if not ENEMY_SCENES.has(enemy_type):
		_log("未知敌人类型: %s" % enemy_type)
		return

	var scene: PackedScene = load(ENEMY_SCENES[enemy_type])
	if not scene:
		_log("无法加载敌人场景: %s" % enemy_type)
		return

	for i in range(count):
		var enemy := scene.instantiate()
		var spawn_pos := _get_spawn_position(position_mode, i, count)
		enemy.position = spawn_pos

		# 连接死亡信号
		if enemy.has_signal("enemy_died"):
			enemy.enemy_died.connect(_on_enemy_died)

		_enemy_container.add_child(enemy)
		_spawned_count += 1

	_log("已生成 %d 个 [%s]，位置模式: %s" % [count, enemy_type, position_mode])

## 获取生成位置
func _get_spawn_position(mode: String, index: int, total: int) -> Vector2:
	match mode:
		"random":
			return Vector2(
				randf_range(200, ARENA_SIZE.x - 200),
				randf_range(200, ARENA_SIZE.y - 200)
			)
		"circle":
			var angle := (TAU / total) * index
			var radius := 400.0
			return ARENA_CENTER + Vector2(cos(angle), sin(angle)) * radius
		"line":
			var start_x := ARENA_CENTER.x - (total * 60) / 2.0
			return Vector2(start_x + index * 60, ARENA_CENTER.y - 300)
		"grid":
			var cols := ceili(sqrt(total))
			var row := index / cols
			var col := index % cols
			var start := ARENA_CENTER - Vector2(cols * 60, (total / cols) * 60) / 2.0
			return start + Vector2(col * 60, row * 60)
		"player_front":
			if _player:
				var offset := Vector2(randf_range(-100, 100), -200 - randf_range(0, 200))
				return _player.position + offset
			return ARENA_CENTER
		_:
			return ARENA_CENTER + Vector2(randf_range(-300, 300), randf_range(-300, 300))

## 预设波次
func spawn_wave_preset(preset_name: String) -> void:
	_spawn_wave_preset(preset_name)

func _spawn_wave_preset(preset_name: String) -> void:
	match preset_name:
		"mixed_basic":
			spawn_enemy("static", 10, "circle")
			spawn_enemy("silence", 2, "random")
			spawn_enemy("screech", 3, "random")
			_log("预设波次: 基础混合")
		"static_swarm":
			spawn_enemy("static", 30, "circle")
			_log("预设波次: 底噪蜂群 (30)")
		"elite_test":
			spawn_enemy("pulse", 3, "line")
			spawn_enemy("wall", 1, "player_front")
			_log("预设波次: 精英测试")
		"stress_test":
			spawn_enemy("static", 50, "random")
			spawn_enemy("screech", 10, "random")
			spawn_enemy("pulse", 5, "random")
			spawn_enemy("wall", 3, "random")
			spawn_enemy("silence", 5, "random")
			_log("预设波次: 压力测试 (73 敌人)")
		"dps_dummy":
			# 生成一个高HP的音墙作为DPS木桩
			spawn_enemy("wall", 1, "player_front")
			_log("预设波次: DPS 木桩")
		_:
			_log("未知预设: %s" % preset_name)

## 清除所有敌人
func _clear_all_enemies() -> void:
	var count := _enemy_container.get_child_count()
	for child in _enemy_container.get_children():
		child.queue_free()
	_log("已清除 %d 个敌人" % count)

## 获取当前敌人数量
func get_enemy_count() -> int:
	return _enemy_container.get_child_count()

# ============================================================
# DPS 统计
# ============================================================

## 记录伤害（由弹体系统调用）
func record_damage(damage: float, source: String = "spell") -> void:
	var now := Time.get_ticks_msec() / 1000.0
	_dps_tracker["total_damage"] += damage
	_dps_tracker["damage_log"].append({
		"time": now,
		"damage": damage,
		"source": source,
	})
	_dps_tracker["window_damage"] += damage

## 更新 DPS 滑动窗口（5秒）
func _update_dps_window() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var window := 5.0

	# 移除超出窗口的记录
	var log: Array = _dps_tracker["damage_log"]
	while not log.is_empty() and log[0]["time"] < now - window:
		_dps_tracker["window_damage"] -= log[0]["damage"]
		log.pop_front()

	# 计算当前 DPS
	var elapsed = now - _dps_tracker.get("window_start", now)
	if elapsed > 0.1:
		_dps_tracker["current_dps"] = _dps_tracker["window_damage"] / min(elapsed, window)
	else:
		_dps_tracker["current_dps"] = 0.0

	# 更新峰值
	if _dps_tracker["current_dps"] > _dps_tracker["peak_dps"]:
		_dps_tracker["peak_dps"] = _dps_tracker["current_dps"]

## 获取 DPS 统计
func get_dps_stats() -> Dictionary:
	var now := Time.get_ticks_msec() / 1000.0
	var session_time = now - _dps_tracker["session_start"]
	var avg_dps = _dps_tracker["total_damage"] / max(session_time, 0.1)
	return {
		"current_dps": _dps_tracker["current_dps"],
		"peak_dps": _dps_tracker["peak_dps"],
		"average_dps": avg_dps,
		"total_damage": _dps_tracker["total_damage"],
		"session_time": session_time,
	}

## 重置 DPS 统计
func _reset_dps() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	_dps_tracker = {
		"total_damage": 0.0,
		"session_start": now,
		"damage_log": [],
		"window_damage": 0.0,
		"window_start": now,
		"current_dps": 0.0,
		"peak_dps": 0.0,
	}
	_killed_count = 0
	_log("DPS 统计已重置")

# ============================================================
# 玩家属性调整
# ============================================================

## 设置玩家属性（由调试面板调用）
func set_player_stat(stat: String, value: float) -> void:
	if not _player:
		return

	match stat:
		"max_hp":
			if _player.has_method("set_max_hp"):
				_player.set_max_hp(value)
			elif "max_hp" in _player:
				_player.max_hp = value
			_log("玩家最大 HP: %.0f" % value)
		"move_speed":
			if "move_speed" in _player:
				_player.move_speed = value
			_log("玩家移速: %.0f" % value)
		"damage_multiplier":
			if GameManager and "damage_multiplier" in GameManager:
				GameManager.damage_multiplier = value
			_log("伤害倍率: %.2fx" % value)
		"pickup_range":
			if "pickup_range" in _player:
				_player.pickup_range = value
			_log("拾取范围: %.0f" % value)

## 设置 BPM
func set_bpm(bpm: float) -> void:
	if GameManager:
		GameManager.bpm = bpm
		_log("BPM: %.0f" % bpm)

## 设置调式
func set_mode(mode_id: String) -> void:
	if ModeSystem and ModeSystem.has_method("select_mode"):
		ModeSystem.select_mode(mode_id)
		_log("调式: %s" % mode_id)

## 设置玩家等级
func set_player_level(level: int) -> void:
	if GameManager:
		GameManager.player_level = level
		_log("玩家等级: %d" % level)

# ============================================================
# 绘制辅助
# ============================================================

func _draw_arena_grid() -> void:
	# 网格线
	for x in range(0, int(ARENA_SIZE.x), int(GRID_SIZE)):
		var color := GRID_ACCENT if x % (int(GRID_SIZE) * 5) == 0 else GRID_COLOR
		draw_line(Vector2(x, 0), Vector2(x, ARENA_SIZE.y), color, 1.0)
	for y in range(0, int(ARENA_SIZE.y), int(GRID_SIZE)):
		var color := GRID_ACCENT if y % (int(GRID_SIZE) * 5) == 0 else GRID_COLOR
		draw_line(Vector2(0, y), Vector2(ARENA_SIZE.x, y), color, 1.0)

	# 中心十字
	draw_line(ARENA_CENTER - Vector2(50, 0), ARENA_CENTER + Vector2(50, 0), BORDER_COLOR * 0.5, 2.0)
	draw_line(ARENA_CENTER - Vector2(0, 50), ARENA_CENTER + Vector2(0, 50), BORDER_COLOR * 0.5, 2.0)

func _draw_arena_border() -> void:
	var rect := Rect2(Vector2.ZERO, ARENA_SIZE)
	draw_rect(rect, BORDER_COLOR, false, 3.0)

	# 角落装饰
	var corner_size := 30.0
	var corners := [
		Vector2.ZERO, Vector2(ARENA_SIZE.x, 0),
		Vector2(0, ARENA_SIZE.y), ARENA_SIZE
	]
	for c in corners:
		draw_circle(c, corner_size * 0.3, BORDER_COLOR * 0.6)

func _draw_hitboxes() -> void:
	# 绘制玩家碰撞箱
	if _player:
		draw_circle(_player.position, 12.0, Color(0.0, 1.0, 0.5, 0.3))

	# 绘制敌人碰撞箱
	for enemy in _enemy_container.get_children():
		if "collision_radius" in enemy:
			draw_circle(enemy.position, enemy.collision_radius, Color(1.0, 0.3, 0.3, 0.3))
		else:
			draw_circle(enemy.position, 16.0, Color(1.0, 0.3, 0.3, 0.3))

# ============================================================
# 信号回调
# ============================================================

func _on_enemy_died(pos: Vector2, xp_value: int, enemy_type: String) -> void:
	_killed_count += 1
	if CodexManager:
		CodexManager.on_enemy_died(pos, xp_value, enemy_type)

# ============================================================
# 日志
# ============================================================

func _log(text: String) -> void:
	var timestamp := Time.get_time_string_from_system()
	var msg := "[%s] %s" % [timestamp, text]
	debug_message.emit(msg)
	print("[TestChamber] %s" % msg)

## 获取统计摘要
func get_stats_summary() -> Dictionary:
	var dps := get_dps_stats()
	return {
		"enemies_alive": get_enemy_count(),
		"enemies_spawned": _spawned_count,
		"enemies_killed": _killed_count,
		"current_dps": dps["current_dps"],
		"peak_dps": dps["peak_dps"],
		"total_damage": dps["total_damage"],
		"session_time": dps["session_time"],
		"god_mode": god_mode,
		"time_scale": time_scale,
	}
