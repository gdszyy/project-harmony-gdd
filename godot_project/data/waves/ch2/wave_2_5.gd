## wave_2-5.gd
## 波次 2-5：复调迷宫 (考试波)
##
## 教学目标：综合考验玩家对Ch2机制的掌握。
##
## 触发时机：按顺序触发
## BPM：105.0
## 预计时长：~60.0 秒
extends "res://scripts/data/wave_data.gd"

func _init() -> void:
	wave_name = "复调迷宫"
	wave_type = "exam"
	chapter_id = "ch2"
	wave_id = "2-5"
	estimated_duration = 60.0
	success_condition = "kill_all"
	
	events = [
		# 设置 BPM 为 105.0
		{
			"timestamp": 0.0,
			"type": "SET_BPM",
			"params": {"bpm": 105.0},
		},
		# 教学提示
		{
			"timestamp": 0.0,
			"type": "SHOW_HINT",
			"params": {
				"text": "综合考验：在复杂的复调中寻找出路",
				"duration": 4.0,
			},
		},
		# 生成蜂群 ch2_choir
		{
			"timestamp": 2.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch2_choir",
				"count": 5,
				"formation": "LINE",
				"direction": "NORTH",
				"speed": 65.0,
				"swarm_enabled": true,
			},
		},
		# 生成蜂群 ch2_choir
		{
			"timestamp": 5.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch2_choir",
				"count": 5,
				"formation": "LINE",
				"direction": "SOUTH",
				"speed": 65.0,
				"swarm_enabled": true,
			},
		},
		# 生成敌人 ch2_scribe
		{
			"timestamp": 10.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch2_scribe",
				"position": "EAST",
				"speed": 60.0,
			},
		},
		# 生成敌人 ch2_scribe
		{
			"timestamp": 12.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch2_scribe",
				"position": "WEST",
				"speed": 60.0,
			},
		},
		# 生成敌人 wall
		{
			"timestamp": 18.0,
			"type": "SPAWN",
			"params": {
				"enemy": "wall",
				"position": "NORTH",
				"speed": 30.0,
				"hp": 250.0,
				"shield": 50.0,
			},
		},
		# 生成蜂群 ch2_choir
		{
			"timestamp": 20.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch2_choir",
				"count": 8,
				"formation": "SCATTERED",
				"direction": "SOUTH",
				"speed": 70.0,
				"swarm_enabled": true,
			},
		},
	]
