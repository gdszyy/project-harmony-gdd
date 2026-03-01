## wave_5-4.gd
## 波次 5-4：切分节奏适应 (练习波)
##
## 教学目标：练习切分节奏带来的微小位移。
##
## 触发时机：按顺序触发
## BPM：135.0
## 预计时长：~45.0 秒
extends "res://scripts/data/wave_data.gd"

func _init() -> void:
	wave_name = "切分节奏适应"
	wave_type = "practice"
	chapter_id = "ch5"
	wave_id = "5-4"
	estimated_duration = 45.0
	success_condition = "kill_all"
	
	events = [
		# 设置 BPM 为 135.0
		{
			"timestamp": 0.0,
			"type": "SET_BPM",
			"params": {"bpm": 135.0},
		},
		# 教学提示
		{
			"timestamp": 0.0,
			"type": "SHOW_HINT",
			"params": {
				"text": "利用切分节奏施法时的后退位移来躲避攻击",
				"duration": 5.0,
			},
		},
		# 生成蜂群 screech
		{
			"timestamp": 2.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "screech",
				"count": 6,
				"formation": "CIRCLE",
				"direction": "CENTER",
				"speed": 95.0,
				"swarm_enabled": true,
			},
		},
		# 生成蜂群 ch5_rubato_stalker
		{
			"timestamp": 12.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch5_rubato_stalker",
				"count": 3,
				"formation": "LINE",
				"direction": "EAST",
				"speed": 80.0,
				"swarm_enabled": true,
			},
		},
	]
