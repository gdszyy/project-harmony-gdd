## wave_data.gd
## 剧本波次数据资源类型
## 定义精确编排的剧本波次事件序列，用于教学引导和叙事推进。
## 由 ChapterManager 在特定时间点注入到 EnemySpawner 中执行。
##
## 事件类型：
##   - SPAWN: 在指定位置生成单个敌人
##   - SPAWN_SWARM: 生成一组蜂群敌人（指定阵型）
##   - SPAWN_ESCORT: 生成围绕目标的护卫敌人
##   - SET_BPM: 动态调整全局 BPM
##   - SHOW_HINT: 显示非侵入式教学提示
##   - CONDITIONAL_HINT: 条件触发的教学提示
##   - UNLOCK: 解锁新机制/音符/节奏型
class_name WaveData
extends Resource

# ============================================================
# 波次基础信息
# ============================================================

## 波次名称（用于调试和日志）
@export var wave_name: String = ""

## 波次类型：tutorial（教学波）/ practice（练习波）/ exam（考试波）
@export var wave_type: String = "tutorial"

## 波次所属章节标识
@export var chapter_id: String = "ch1"

## 波次编号（如 "1-1", "1-2"）
@export var wave_id: String = ""

## 预计持续时间（秒），仅供参考，实际以事件完成为准
@export var estimated_duration: float = 30.0

# ============================================================
# 事件序列
# ============================================================

## 事件列表，每个事件是一个 Dictionary，包含：
##   - "timestamp": float — 从波次开始的秒数
##   - "type": String — 事件类型（SPAWN / SPAWN_SWARM / SPAWN_ESCORT /
##                       SET_BPM / SHOW_HINT / CONDITIONAL_HINT / UNLOCK）
##   - "params": Dictionary — 事件参数（因类型而异）
##
## SPAWN 参数：
##   - "enemy": String — 敌人类型名称
##   - "position": Variant — 生成位置（String 如 "NORTH" 或 Vector2）
##   - "speed": float — 移动速度（可选，覆盖默认值）
##   - "hp": float — 生命值（可选）
##   - "shield": float — 护盾值（可选）
##
## SPAWN_SWARM 参数：
##   - "enemy": String — 敌人类型名称
##   - "count": int — 数量
##   - "formation": String — 阵型（LINE / CIRCLE / SCATTERED / V_SHAPE）
##   - "direction": String — 来源方向（NORTH / SOUTH / EAST / WEST）
##   - "speed": float — 移动速度
##   - "swarm_enabled": bool — 是否启用蜂群加速
##
## SPAWN_ESCORT 参数：
##   - "enemy": String — 护卫敌人类型
##   - "count": int — 护卫数量
##   - "orbit_target": String — 环绕目标（"LAST_SPAWNED" 或敌人ID）
##   - "orbit_radius": float — 环绕半径
##   - "speed": float — 移动速度
##
## SET_BPM 参数：
##   - "bpm": float — 目标 BPM
##
## SHOW_HINT 参数：
##   - "text": String — 提示文本
##   - "duration": float — 显示时长（秒）
##   - "highlight_ui": String — 需要高亮的 UI 元素名称（可选）
##
## CONDITIONAL_HINT 参数：
##   - "condition": String — 触发条件标识
##   - "text": String — 提示文本
##   - "highlight_ui": String — 高亮 UI 元素（可选）
##
## UNLOCK 参数：
##   - "type": String — 解锁类型（"note" / "feature" / "rhythm"）
##   - "note": String — 音符名称（type="note" 时）
##   - "feature": String — 功能标识（type="feature" 时）
##   - "rhythm": String — 节奏型标识（type="rhythm" 时）
##   - "message": String — 解锁提示消息
@export var events: Array[Dictionary] = []

# ============================================================
# 成功条件
# ============================================================

## 成功条件类型：
##   - "kill_all": 击杀所有剧本敌人
##   - "survive": 存活指定时间
##   - "custom": 自定义条件
@export var success_condition: String = "kill_all"

## 自定义成功条件参数
@export var success_params: Dictionary = {}

# ============================================================
# 公共接口
# ============================================================

## 获取按时间排序的事件列表
func get_sorted_events() -> Array[Dictionary]:
	var sorted := events.duplicate()
	sorted.sort_custom(func(a, b): return a.get("timestamp", 0.0) < b.get("timestamp", 0.0))
	return sorted

## 获取波次中的总敌人数量（用于进度显示）
func get_total_enemy_count() -> int:
	var count := 0
	for event in events:
		var type: String = event.get("type", "")
		match type:
			"SPAWN":
				count += 1
			"SPAWN_SWARM":
				count += event.get("params", {}).get("count", 0)
			"SPAWN_ESCORT":
				count += event.get("params", {}).get("count", 0)
	return count

## 获取波次的最后一个事件的时间戳
func get_last_event_timestamp() -> float:
	var max_time := 0.0
	for event in events:
		var t: float = event.get("timestamp", 0.0)
		if t > max_time:
			max_time = t
	return max_time

## 验证波次数据完整性
func validate() -> Array[String]:
	var errors: Array[String] = []
	
	if wave_name.is_empty():
		errors.append("wave_name is empty")
	if wave_id.is_empty():
		errors.append("wave_id is empty")
	if events.is_empty():
		errors.append("events array is empty")
	
	for i in range(events.size()):
		var event := events[i]
		if not event.has("timestamp"):
			errors.append("Event %d missing 'timestamp'" % i)
		if not event.has("type"):
			errors.append("Event %d missing 'type'" % i)
		
		var type: String = event.get("type", "")
		var valid_types := ["SPAWN", "SPAWN_SWARM", "SPAWN_ESCORT", "SET_BPM", "SHOW_HINT", "CONDITIONAL_HINT", "UNLOCK"]
		if type not in valid_types:
			errors.append("Event %d has invalid type: '%s'" % [i, type])
	
	return errors
