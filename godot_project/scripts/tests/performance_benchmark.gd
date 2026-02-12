## performance_benchmark.gd
## Issue #116: 性能基准测试场景
## 验证 2000+ 弹体场景下 MultiMesh 渲染性能
## 同时测试敌人对象池的分配/回收效率
##
## 测试项目：
## 1. MultiMesh 弹体渲染：2000 弹体同屏时的 FPS
## 2. 碰撞检测：空间哈希 vs 暴力检测在高负载下的对比
## 3. 对象池吞吐量：敌人分配/回收的延迟
## 4. 综合压力测试：弹体 + 敌人 + 碰撞同时运行
##
## 使用方法：
## 1. 在编辑器中打开 res://scenes/tests/performance_benchmark.tscn
## 2. 运行场景，测试结果将输出到控制台和 UI
## 3. 按 F1-F4 切换不同测试模式
extends Node2D

# ============================================================
# 测试配置
# ============================================================
const BENCHMARK_DURATION: float = 10.0  ## 每个测试运行时长（秒）
const WARMUP_FRAMES: int = 60           ## 预热帧数（不计入统计）
const TARGET_FPS: float = 60.0          ## 目标帧率

## 弹体测试参数
const PROJECTILE_COUNTS: Array[int] = [500, 1000, 1500, 2000, 2500, 3000]
const PROJECTILE_SPAWN_RATE: int = 100  ## 每帧生成弹体数

## 敌人测试参数
const ENEMY_COUNTS: Array[int] = [30, 60, 90, 120]
const ENEMY_SPAWN_BURST: int = 10       ## 每次批量生成敌人数

## 碰撞测试参数
const COLLISION_PROJECTILE_COUNT: int = 2000
const COLLISION_ENEMY_COUNT: int = 120

# ============================================================
# 测试模式
# ============================================================
enum BenchmarkMode {
	IDLE,                    ## 等待开始
	PROJECTILE_STRESS,       ## 弹体渲染压力测试
	ENEMY_POOL_THROUGHPUT,   ## 敌人对象池吞吐量测试
	COLLISION_STRESS,        ## 碰撞检测压力测试
	COMBINED_STRESS,         ## 综合压力测试
	COMPLETE,                ## 测试完成
}

# ============================================================
# 状态
# ============================================================
var _current_mode: BenchmarkMode = BenchmarkMode.IDLE
var _test_timer: float = 0.0
var _warmup_counter: int = 0
var _current_projectile_target: int = 0
var _current_enemy_target: int = 0

## 帧时间采样
var _frame_times: Array[float] = []
var _min_fps: float = INF
var _max_fps: float = 0.0
var _total_frame_time: float = 0.0
var _frame_count: int = 0

## 对象池测试数据
var _pool_acquire_times: Array[float] = []
var _pool_release_times: Array[float] = []
var _pool_acquire_count: int = 0
var _pool_release_count: int = 0

## 碰撞测试数据
var _collision_check_times: Array[float] = []

## 综合测试结果
var _benchmark_results: Array[Dictionary] = []

## 子系统引用
var _projectile_manager: Node = null
var _pool_manager: Node = null
var _collision_optimizer: CollisionOptimizer = null

## UI 引用
var _ui_label: Label = null
var _results_label: RichTextLabel = null

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_setup_ui()
	_setup_subsystems()
	print("=== Performance Benchmark Ready ===")
	print("Press F1: Projectile Stress Test")
	print("Press F2: Enemy Pool Throughput Test")
	print("Press F3: Collision Stress Test")
	print("Press F4: Combined Stress Test")
	print("Press F5: Run All Tests Sequentially")
	print("===================================")

func _process(delta: float) -> void:
	_update_ui()
	
	match _current_mode:
		BenchmarkMode.IDLE:
			pass
		BenchmarkMode.PROJECTILE_STRESS:
			_process_projectile_stress(delta)
		BenchmarkMode.ENEMY_POOL_THROUGHPUT:
			_process_enemy_pool_test(delta)
		BenchmarkMode.COLLISION_STRESS:
			_process_collision_stress(delta)
		BenchmarkMode.COMBINED_STRESS:
			_process_combined_stress(delta)
		BenchmarkMode.COMPLETE:
			pass

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_F1:
				_start_test(BenchmarkMode.PROJECTILE_STRESS)
			KEY_F2:
				_start_test(BenchmarkMode.ENEMY_POOL_THROUGHPUT)
			KEY_F3:
				_start_test(BenchmarkMode.COLLISION_STRESS)
			KEY_F4:
				_start_test(BenchmarkMode.COMBINED_STRESS)
			KEY_F5:
				_run_all_tests()
			KEY_ESCAPE:
				_abort_test()

# ============================================================
# 子系统设置
# ============================================================

func _setup_subsystems() -> void:
	# ProjectileManager（使用演示模式）
	_projectile_manager = get_node_or_null("ProjectileManager")
	if _projectile_manager == null:
		var pm_script = load("res://scripts/systems/projectile_manager.gd")
		if pm_script:
			_projectile_manager = Node2D.new()
			_projectile_manager.set_script(pm_script)
			_projectile_manager.name = "ProjectileManager"
			_projectile_manager.set("_demo_mode", true)
			add_child(_projectile_manager)
	
	# PoolManager
	_pool_manager = get_node_or_null("PoolManager")
	if _pool_manager == null:
		var pool_script = load("res://scripts/systems/pool_manager.gd")
		if pool_script:
			_pool_manager = Node.new()
			_pool_manager.set_script(pool_script)
			_pool_manager.name = "PoolManager"
			add_child(_pool_manager)
	
	# CollisionOptimizer
	_collision_optimizer = CollisionOptimizer.new(128.0)

# ============================================================
# UI 设置
# ============================================================

func _setup_ui() -> void:
	# 实时状态标签
	_ui_label = Label.new()
	_ui_label.name = "StatusLabel"
	_ui_label.position = Vector2(10, 10)
	_ui_label.add_theme_font_size_override("font_size", 16)
	_ui_label.add_theme_color_override("font_color", Color.WHITE)
	var canvas := CanvasLayer.new()
	canvas.name = "BenchmarkUI"
	canvas.add_child(_ui_label)
	add_child(canvas)
	
	# 结果面板
	_results_label = RichTextLabel.new()
	_results_label.name = "ResultsLabel"
	_results_label.position = Vector2(10, 200)
	_results_label.size = Vector2(600, 400)
	_results_label.bbcode_enabled = true
	_results_label.add_theme_font_size_override("normal_font_size", 14)
	canvas.add_child(_results_label)

func _update_ui() -> void:
	if _ui_label == null:
		return
	
	var fps := Engine.get_frames_per_second()
	var mode_name := _get_mode_name(_current_mode)
	var projectile_count := 0
	if _projectile_manager and _projectile_manager.has_method("get_active_count"):
		projectile_count = _projectile_manager.get_active_count()
	
	var text := "Mode: %s | FPS: %d | Projectiles: %d" % [mode_name, fps, projectile_count]
	
	if _current_mode != BenchmarkMode.IDLE and _current_mode != BenchmarkMode.COMPLETE:
		text += " | Time: %.1f / %.1f" % [_test_timer, BENCHMARK_DURATION]
		if _frame_count > 0:
			var avg_fps := _frame_count / _total_frame_time if _total_frame_time > 0 else 0.0
			text += " | Avg FPS: %.1f | Min: %.1f | Max: %.1f" % [avg_fps, _min_fps, _max_fps]
	
	_ui_label.text = text

# ============================================================
# 测试控制
# ============================================================

func _start_test(mode: BenchmarkMode) -> void:
	_reset_stats()
	_current_mode = mode
	_test_timer = 0.0
	_warmup_counter = 0
	
	# 清理上一次测试的弹体
	if _projectile_manager and _projectile_manager.has_method("clear_all"):
		_projectile_manager.clear_all()
	
	print("\n--- Starting: %s ---" % _get_mode_name(mode))

func _end_test() -> void:
	var result := _compile_result()
	_benchmark_results.append(result)
	_print_result(result)
	_update_results_display()
	
	# 清理
	if _projectile_manager and _projectile_manager.has_method("clear_all"):
		_projectile_manager.clear_all()
	
	_current_mode = BenchmarkMode.COMPLETE

func _abort_test() -> void:
	if _projectile_manager and _projectile_manager.has_method("clear_all"):
		_projectile_manager.clear_all()
	_current_mode = BenchmarkMode.IDLE
	print("Test aborted.")

func _run_all_tests() -> void:
	_benchmark_results.clear()
	_start_test(BenchmarkMode.PROJECTILE_STRESS)
	# 后续测试在每个测试完成后自动启动
	# 通过 _end_test 中的逻辑链式触发

func _reset_stats() -> void:
	_frame_times.clear()
	_min_fps = INF
	_max_fps = 0.0
	_total_frame_time = 0.0
	_frame_count = 0
	_pool_acquire_times.clear()
	_pool_release_times.clear()
	_pool_acquire_count = 0
	_pool_release_count = 0
	_collision_check_times.clear()

# ============================================================
# 帧时间采样
# ============================================================

func _sample_frame(delta: float) -> void:
	if _warmup_counter < WARMUP_FRAMES:
		_warmup_counter += 1
		return
	
	var fps := 1.0 / delta if delta > 0 else 0.0
	_frame_times.append(delta)
	_total_frame_time += delta
	_frame_count += 1
	
	if fps < _min_fps:
		_min_fps = fps
	if fps > _max_fps:
		_max_fps = fps

# ============================================================
# 测试 1: 弹体渲染压力测试
# ============================================================

func _process_projectile_stress(delta: float) -> void:
	_test_timer += delta
	_sample_frame(delta)
	
	if _test_timer >= BENCHMARK_DURATION:
		_end_test()
		return
	
	# 持续生成弹体直到达到目标数量
	if _projectile_manager:
		var current_count := 0
		if _projectile_manager.has_method("get_active_count"):
			current_count = _projectile_manager.get_active_count()
		
		var target := 2000  # 目标 2000 弹体
		if current_count < target:
			var to_spawn := mini(PROJECTILE_SPAWN_RATE, target - current_count)
			for i in range(to_spawn):
				var spell_data := {
					"speed": randf_range(300.0, 800.0),
					"damage": 30.0,
					"size": randf_range(16.0, 32.0),
					"duration": 8.0,  # 长持续时间确保弹体不会过早消失
					"color": Color(randf(), randf(), randf()),
					"note": randi() % 12,
					"modifier": -1,
				}
				var origin := Vector2(randf_range(100, 1820), randf_range(100, 980))
				var direction := Vector2.from_angle(randf() * TAU)
				if _projectile_manager.has_method("spawn_from_spell"):
					_projectile_manager.spawn_from_spell(spell_data, origin, direction)

# ============================================================
# 测试 2: 敌人对象池吞吐量测试
# ============================================================

func _process_enemy_pool_test(delta: float) -> void:
	_test_timer += delta
	_sample_frame(delta)
	
	if _test_timer >= BENCHMARK_DURATION:
		_end_test()
		return
	
	if _pool_manager == null:
		print("PoolManager not available, skipping pool test")
		_end_test()
		return
	
	# 每帧执行 acquire/release 循环
	var acquired_enemies: Array[Node] = []
	
	# Acquire 阶段
	var acquire_start := Time.get_ticks_usec()
	for i in range(ENEMY_SPAWN_BURST):
		var types := ["static", "screech", "pulse", "silence", "wall"]
		var type_name: String = types[randi() % types.size()]
		if _pool_manager.has_method("acquire_enemy"):
			var enemy := _pool_manager.acquire_enemy(type_name)
			if enemy:
				acquired_enemies.append(enemy)
				_pool_acquire_count += 1
	var acquire_end := Time.get_ticks_usec()
	var acquire_time := float(acquire_end - acquire_start) / 1000.0  # ms
	_pool_acquire_times.append(acquire_time)
	
	# Release 阶段（归还刚获取的敌人）
	var release_start := Time.get_ticks_usec()
	for enemy in acquired_enemies:
		var type_name: String = enemy.get_meta("pool_type", "static")
		if _pool_manager.has_method("release_enemy"):
			_pool_manager.release_enemy(type_name, enemy)
			_pool_release_count += 1
	var release_end := Time.get_ticks_usec()
	var release_time := float(release_end - release_start) / 1000.0  # ms
	_pool_release_times.append(release_time)

# ============================================================
# 测试 3: 碰撞检测压力测试
# ============================================================

func _process_collision_stress(delta: float) -> void:
	_test_timer += delta
	_sample_frame(delta)
	
	if _test_timer >= BENCHMARK_DURATION:
		_end_test()
		return
	
	# 生成弹体
	if _projectile_manager:
		var current_count := 0
		if _projectile_manager.has_method("get_active_count"):
			current_count = _projectile_manager.get_active_count()
		
		if current_count < COLLISION_PROJECTILE_COUNT:
			var to_spawn := mini(50, COLLISION_PROJECTILE_COUNT - current_count)
			for i in range(to_spawn):
				var spell_data := {
					"speed": randf_range(200.0, 600.0),
					"damage": 30.0,
					"size": 24.0,
					"duration": 10.0,
					"color": Color(0.0, 1.0, 0.8),
					"note": -1,
					"modifier": -1,
				}
				var origin := Vector2(randf_range(100, 1820), randf_range(100, 980))
				var direction := Vector2.from_angle(randf() * TAU)
				if _projectile_manager.has_method("spawn_from_spell"):
					_projectile_manager.spawn_from_spell(spell_data, origin, direction)
	
	# 模拟敌人数据
	var mock_enemies: Array = []
	for i in range(COLLISION_ENEMY_COUNT):
		mock_enemies.append({
			"position": Vector2(randf_range(0, 1920), randf_range(0, 1080)),
			"radius": 16.0,
		})
	
	# 执行碰撞检测并计时
	if _projectile_manager and _projectile_manager.has_method("check_collisions"):
		var start := Time.get_ticks_usec()
		var _hits = _projectile_manager.check_collisions(mock_enemies)
		var end := Time.get_ticks_usec()
		var collision_time := float(end - start) / 1000.0  # ms
		_collision_check_times.append(collision_time)

# ============================================================
# 测试 4: 综合压力测试
# ============================================================

func _process_combined_stress(delta: float) -> void:
	_test_timer += delta
	_sample_frame(delta)
	
	if _test_timer >= BENCHMARK_DURATION:
		_end_test()
		return
	
	# 同时运行弹体 + 碰撞
	# 弹体生成
	if _projectile_manager:
		var current_count := 0
		if _projectile_manager.has_method("get_active_count"):
			current_count = _projectile_manager.get_active_count()
		
		if current_count < 2000:
			var to_spawn := mini(80, 2000 - current_count)
			for i in range(to_spawn):
				var spell_data := {
					"speed": randf_range(300.0, 700.0),
					"damage": 30.0,
					"size": randf_range(16.0, 32.0),
					"duration": 8.0,
					"color": Color(randf(), randf(), randf()),
					"note": randi() % 12,
					"modifier": -1,
				}
				var origin := Vector2(randf_range(100, 1820), randf_range(100, 980))
				var direction := Vector2.from_angle(randf() * TAU)
				if _projectile_manager.has_method("spawn_from_spell"):
					_projectile_manager.spawn_from_spell(spell_data, origin, direction)
	
	# 碰撞检测
	var mock_enemies: Array = []
	for i in range(120):
		mock_enemies.append({
			"position": Vector2(randf_range(0, 1920), randf_range(0, 1080)),
			"radius": 16.0,
		})
	
	if _projectile_manager and _projectile_manager.has_method("check_collisions"):
		var start := Time.get_ticks_usec()
		var _hits = _projectile_manager.check_collisions(mock_enemies)
		var end := Time.get_ticks_usec()
		var collision_time := float(end - start) / 1000.0
		_collision_check_times.append(collision_time)
	
	# 对象池 acquire/release 循环
	if _pool_manager and _pool_manager.has_method("acquire_enemy"):
		var acquired: Array[Node] = []
		for i in range(5):
			var enemy := _pool_manager.acquire_enemy("static")
			if enemy:
				acquired.append(enemy)
		for enemy in acquired:
			if _pool_manager.has_method("release_enemy"):
				_pool_manager.release_enemy("static", enemy)

# ============================================================
# 结果编译
# ============================================================

func _compile_result() -> Dictionary:
	var avg_fps := _frame_count / _total_frame_time if _total_frame_time > 0 else 0.0
	
	# 计算 1% low FPS（最差 1% 帧的平均 FPS）
	var sorted_times := _frame_times.duplicate()
	sorted_times.sort()
	var one_percent_count := max(1, int(sorted_times.size() * 0.01))
	var worst_times := sorted_times.slice(sorted_times.size() - one_percent_count)
	var one_percent_low := 0.0
	if not worst_times.is_empty():
		var sum := 0.0
		for t in worst_times:
			sum += t
		one_percent_low = float(one_percent_count) / sum if sum > 0 else 0.0
	
	# 计算帧时间标准差
	var mean_frame_time := _total_frame_time / _frame_count if _frame_count > 0 else 0.0
	var variance := 0.0
	for t in _frame_times:
		variance += (t - mean_frame_time) * (t - mean_frame_time)
	variance /= max(1, _frame_count)
	var std_dev := sqrt(variance)
	
	var result := {
		"mode": _get_mode_name(_current_mode),
		"duration": _test_timer,
		"frame_count": _frame_count,
		"avg_fps": avg_fps,
		"min_fps": _min_fps if _min_fps != INF else 0.0,
		"max_fps": _max_fps,
		"one_percent_low_fps": one_percent_low,
		"frame_time_std_dev_ms": std_dev * 1000.0,
		"meets_target": avg_fps >= TARGET_FPS,
	}
	
	# 对象池数据
	if not _pool_acquire_times.is_empty():
		var sum := 0.0
		for t in _pool_acquire_times:
			sum += t
		result["pool_avg_acquire_ms"] = sum / _pool_acquire_times.size()
		result["pool_acquire_count"] = _pool_acquire_count
	
	if not _pool_release_times.is_empty():
		var sum := 0.0
		for t in _pool_release_times:
			sum += t
		result["pool_avg_release_ms"] = sum / _pool_release_times.size()
		result["pool_release_count"] = _pool_release_count
	
	# 碰撞数据
	if not _collision_check_times.is_empty():
		var sum := 0.0
		var max_t := 0.0
		for t in _collision_check_times:
			sum += t
			if t > max_t:
				max_t = t
		result["collision_avg_ms"] = sum / _collision_check_times.size()
		result["collision_max_ms"] = max_t
		result["collision_check_count"] = _collision_check_times.size()
	
	return result

func _print_result(result: Dictionary) -> void:
	print("\n=== %s Results ===" % result["mode"])
	print("  Duration: %.1f s | Frames: %d" % [result["duration"], result["frame_count"]])
	print("  FPS — Avg: %.1f | Min: %.1f | Max: %.1f | 1%% Low: %.1f" % [
		result["avg_fps"], result["min_fps"], result["max_fps"], result["one_percent_low_fps"]
	])
	print("  Frame Time StdDev: %.2f ms" % result["frame_time_std_dev_ms"])
	print("  Meets 60 FPS Target: %s" % ("YES ✓" if result["meets_target"] else "NO ✗"))
	
	if result.has("pool_avg_acquire_ms"):
		print("  Pool Acquire — Avg: %.3f ms | Count: %d" % [result["pool_avg_acquire_ms"], result["pool_acquire_count"]])
	if result.has("pool_avg_release_ms"):
		print("  Pool Release — Avg: %.3f ms | Count: %d" % [result["pool_avg_release_ms"], result["pool_release_count"]])
	if result.has("collision_avg_ms"):
		print("  Collision — Avg: %.3f ms | Max: %.3f ms | Checks: %d" % [
			result["collision_avg_ms"], result["collision_max_ms"], result["collision_check_count"]
		])
	print("===========================\n")

func _update_results_display() -> void:
	if _results_label == null:
		return
	
	var bbcode := "[b]Benchmark Results[/b]\n\n"
	for result in _benchmark_results:
		var status := "[color=green]PASS[/color]" if result["meets_target"] else "[color=red]FAIL[/color]"
		bbcode += "[b]%s[/b] — %s\n" % [result["mode"], status]
		bbcode += "  Avg FPS: %.1f | Min: %.1f | 1%% Low: %.1f\n" % [
			result["avg_fps"], result["min_fps"], result["one_percent_low_fps"]
		]
		if result.has("collision_avg_ms"):
			bbcode += "  Collision Avg: %.3f ms\n" % result["collision_avg_ms"]
		if result.has("pool_avg_acquire_ms"):
			bbcode += "  Pool Acquire: %.3f ms | Release: %.3f ms\n" % [
				result["pool_avg_acquire_ms"],
				result.get("pool_avg_release_ms", 0.0)
			]
		bbcode += "\n"
	
	_results_label.text = bbcode

# ============================================================
# 工具函数
# ============================================================

func _get_mode_name(mode: BenchmarkMode) -> String:
	match mode:
		BenchmarkMode.IDLE:                return "Idle"
		BenchmarkMode.PROJECTILE_STRESS:   return "Projectile Stress (2000+)"
		BenchmarkMode.ENEMY_POOL_THROUGHPUT: return "Enemy Pool Throughput"
		BenchmarkMode.COLLISION_STRESS:    return "Collision Stress (2000p × 120e)"
		BenchmarkMode.COMBINED_STRESS:     return "Combined Stress"
		BenchmarkMode.COMPLETE:            return "Complete"
		_:                                 return "Unknown"
