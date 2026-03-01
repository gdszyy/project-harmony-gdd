## wave_5-5.gd
## 波次 5-5：动态BPM生存 (考试波)
##
## 教学目标：在快速变化的BPM中生存。
##
## 触发时机：按顺序触发
## BPM：140.0
## 预计时长：~60.0 秒
extends "res://scripts/data/wave_data.gd"

func _init() -> void:
	wave_name = "动态BPM生存"
	wave_type = "exam"
	chapter_id = "ch5"
	wave_id = "5-5"
	estimated_duration = 60.0
	success_condition = "kill_all"
	
	events = [
		# 设置 BPM 为 140.0
		{
			"timestamp": 0.0,
			"type": "SET_BPM",
			"params": {"bpm": 140.0},
		},
		# 教学提示
		{
			"timestamp": 0.0,
			"type": "SHOW_HINT",
			"params": {
				"text": "注意BPM的变化，随时调整你的施法节奏",
				"duration": 5.0,
			},
		},
		# 生成蜂群 ch5_rubato_stalker
		{
			"timestamp": 2.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch5_rubato_stalker",
				"count": 5,
				"formation": "SCATTERED",
				"direction": "ALL",
				"speed": 85.0,
				"swarm_enabled": true,
			},
		},
		# 设置 BPM 为 160.0
		{
			"timestamp": 10.0,
			"type": "SET_BPM",
			"params": {"bpm": 160.0},
		},
		# 生成蜂群 screech
		{
			"timestamp": 12.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "screech",
				"count": 4,
				"formation": "LINE",
				"direction": "NORTH",
				"speed": 110.0,
				"swarm_enabled": true,
			},
		},
		# 设置 BPM 为 120.0
		{
			"timestamp": 20.0,
			"type": "SET_BPM",
			"params": {"bpm": 120.0},
		},
		# 生成敌人 wall
		{
			"timestamp": 22.0,
			"type": "SPAWN",
			"params": {
				"enemy": "wall",
				"position": "WEST",
				"speed": 45.0,
				"hp": 700.0,
				"shield": 100.0,
			},
		},
		# 设置 BPM 为 150.0
		{
			"timestamp": 30.0,
			"type": "SET_BPM",
			"params": {"bpm": 150.0},
		},
		# 生成蜂群 ch5_rubato_stalker
		{
			"timestamp": 32.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch5_rubato_stalker",
				"count": 4,
				"formation": "SCATTERED",
				"direction": "SOUTH",
				"speed": 90.0,
				"swarm_enabled": true,
			},
		},
	]
