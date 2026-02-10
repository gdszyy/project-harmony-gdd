## wave_1_2.gd
## 波次 1-2：音符差异 (教学波)
##
## 教学目标：让玩家理解不同音符的速度、射程和伤害差异。
## 远处 3 只慢速 Static（需要 D 音符的远射程）
## 近处 3 只快速 Static（需要 G 音符的高伤害）
##
## 触发时机：第 3 个随机波次结束后
## BPM：100
## 预计时长：~40 秒
extends "res://scripts/data/wave_data.gd"

func _init() -> void:
	wave_name = "音符差异"
	wave_type = "tutorial"
	chapter_id = "ch1"
	wave_id = "1-2"
	estimated_duration = 40.0
	success_condition = "kill_all"
	
	events = [
		# 解锁 D 音符
		{
			"timestamp": 0.0,
			"type": "UNLOCK",
			"params": {
				"type": "note",
				"note": "D",
				"message": "获得 D 音符（极速远程）",
			},
		},
		# 解锁 G 音符
		{
			"timestamp": 0.5,
			"type": "UNLOCK",
			"params": {
				"type": "note",
				"note": "G",
				"message": "获得 G 音符（爆发伤害）",
			},
		},
		# 教学提示
		{
			"timestamp": 1.0,
			"type": "SHOW_HINT",
			"params": {
				"text": "不同音符有不同的速度、射程和伤害",
				"duration": 5.0,
			},
		},
		# 远处慢速 Static 组（需要 D 音符远射程）
		{
			"timestamp": 3.0,
			"type": "SPAWN",
			"params": {
				"enemy": "static",
				"position": "Vector2(0, -800)",
				"speed": 60.0,
			},
		},
		{
			"timestamp": 3.5,
			"type": "SPAWN",
			"params": {
				"enemy": "static",
				"position": "Vector2(100, -800)",
				"speed": 60.0,
			},
		},
		{
			"timestamp": 4.0,
			"type": "SPAWN",
			"params": {
				"enemy": "static",
				"position": "Vector2(-100, -800)",
				"speed": 60.0,
			},
		},
		# 近处快速 Static 组（需要 G 音符高伤害）
		{
			"timestamp": 5.0,
			"type": "SPAWN",
			"params": {
				"enemy": "static",
				"position": "Vector2(0, -300)",
				"speed": 150.0,
			},
		},
		{
			"timestamp": 5.5,
			"type": "SPAWN",
			"params": {
				"enemy": "static",
				"position": "Vector2(80, -300)",
				"speed": 150.0,
			},
		},
		{
			"timestamp": 6.0,
			"type": "SPAWN",
			"params": {
				"enemy": "static",
				"position": "Vector2(-80, -300)",
				"speed": 150.0,
			},
		},
	]
