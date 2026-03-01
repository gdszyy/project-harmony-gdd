## wave_6-4.gd
## 波次 6-4：十二音序列 (教学波)
##
## 教学目标：强制玩家使用不重复的音符序列。
##
## 触发时机：按顺序触发
## BPM：150.0
## 预计时长：~55.0 秒
extends "res://scripts/data/wave_data.gd"

func _init() -> void:
	wave_name = "十二音序列"
	wave_type = "tutorial"
	chapter_id = "ch6"
	wave_id = "6-4"
	estimated_duration = 55.0
	success_condition = "kill_all"
	
	events = [
		# 设置 BPM 为 150.0
		{
			"timestamp": 0.0,
			"type": "SET_BPM",
			"params": {"bpm": 150.0},
		},
		# 教学提示
		{
			"timestamp": 0.0,
			"type": "SHOW_HINT",
			"params": {
				"text": "使用不重复的十二音序列来最大化伤害",
				"duration": 5.0,
			},
		},
		# 生成敌人 wall
		{
			"timestamp": 2.0,
			"type": "SPAWN",
			"params": {
				"enemy": "wall",
				"position": "CENTER",
				"speed": 30.0,
				"hp": 1000.0,
				"shield": 300.0,
			},
		},
		# 生成蜂群 ch6_serial_drone
		{
			"timestamp": 10.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch6_serial_drone",
				"count": 6,
				"formation": "CIRCLE",
				"direction": "CENTER",
				"speed": 70.0,
				"swarm_enabled": true,
			},
		},
	]
