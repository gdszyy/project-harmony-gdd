## wave_4-3.gd
## 波次 4-3：小七和弦：召唤构造 (教学波)
##
## 教学目标：教学小七和弦召唤物的使用。
##
## 触发时机：按顺序触发
## BPM：110.0
## 预计时长：~45.0 秒
extends "res://scripts/data/wave_data.gd"

func _init() -> void:
	wave_name = "小七和弦：召唤构造"
	wave_type = "tutorial"
	chapter_id = "ch4"
	wave_id = "4-3"
	estimated_duration = 45.0
	success_condition = "kill_all"
	
	events = [
		# 设置 BPM 为 110.0
		{
			"timestamp": 0.0,
			"type": "SET_BPM",
			"params": {"bpm": 110.0},
		},
		# 教学提示
		{
			"timestamp": 0.0,
			"type": "SHOW_HINT",
			"params": {
				"text": "使用小七和弦召唤节拍哨塔协助攻击",
				"duration": 5.0,
			},
		},
		# 生成敌人 wall
		{
			"timestamp": 2.0,
			"type": "SPAWN",
			"params": {
				"enemy": "wall",
				"position": "NORTH",
				"speed": 35.0,
				"hp": 400.0,
				"shield": 100.0,
			},
		},
		# 生成蜂群 static
		{
			"timestamp": 5.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "static",
				"count": 15,
				"formation": "LINE",
				"direction": "NORTH",
				"speed": 85.0,
				"swarm_enabled": true,
			},
		},
	]
