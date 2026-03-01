## wave_6-5.gd
## 波次 6-5：表现主义噩梦 (考试波)
##
## 教学目标：综合考验第六章的机制。
##
## 触发时机：按顺序触发
## BPM：155.0
## 预计时长：~65.0 秒
extends "res://scripts/data/wave_data.gd"

func _init() -> void:
	wave_name = "表现主义噩梦"
	wave_type = "exam"
	chapter_id = "ch6"
	wave_id = "6-5"
	estimated_duration = 65.0
	success_condition = "kill_all"
	
	events = [
		# 设置 BPM 为 155.0
		{
			"timestamp": 0.0,
			"type": "SET_BPM",
			"params": {"bpm": 155.0},
		},
		# 教学提示
		{
			"timestamp": 0.0,
			"type": "SHOW_HINT",
			"params": {
				"text": "综合考验：在无调性的混乱中保持理智",
				"duration": 5.0,
			},
		},
		# 生成敌人 ch6_atonal_amalgam
		{
			"timestamp": 2.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch6_atonal_amalgam",
				"position": "NORTH",
				"speed": 55.0,
			},
		},
		# 生成蜂群 ch6_serial_drone
		{
			"timestamp": 5.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch6_serial_drone",
				"count": 4,
				"formation": "SCATTERED",
				"direction": "SOUTH",
				"speed": 75.0,
				"swarm_enabled": true,
			},
		},
		# 生成敌人 wall
		{
			"timestamp": 15.0,
			"type": "SPAWN",
			"params": {
				"enemy": "wall",
				"position": "EAST",
				"speed": 40.0,
				"hp": 800.0,
				"shield": 200.0,
			},
		},
		# 生成敌人 ch6_atonal_amalgam
		{
			"timestamp": 20.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch6_atonal_amalgam",
				"position": "WEST",
				"speed": 55.0,
			},
		},
		# 生成蜂群 screech
		{
			"timestamp": 30.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "screech",
				"count": 5,
				"formation": "LINE",
				"direction": "NORTH",
				"speed": 120.0,
				"swarm_enabled": true,
			},
		},
	]
