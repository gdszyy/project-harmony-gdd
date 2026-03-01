## wave_2-4.gd
## 波次 2-4：神圣几何 (练习波)
##
## 教学目标：引入更复杂的阵型，要求玩家利用和弦进行面杀伤。
##
## 触发时机：按顺序触发
## BPM：100.0
## 预计时长：~45.0 秒
extends "res://scripts/data/wave_data.gd"

func _init() -> void:
	wave_name = "神圣几何"
	wave_type = "practice"
	chapter_id = "ch2"
	wave_id = "2-4"
	estimated_duration = 45.0
	success_condition = "kill_all"
	
	events = [
		# 设置 BPM 为 100.0
		{
			"timestamp": 0.0,
			"type": "SET_BPM",
			"params": {"bpm": 100.0},
		},
		# 教学提示
		{
			"timestamp": 0.0,
			"type": "SHOW_HINT",
			"params": {
				"text": "使用管风琴音色进行范围打击",
				"duration": 4.0,
			},
		},
		# 生成蜂群 ch2_choir
		{
			"timestamp": 2.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch2_choir",
				"count": 6,
				"formation": "CIRCLE",
				"direction": "CENTER",
				"speed": 50.0,
				"swarm_enabled": true,
			},
		},
		# 生成敌人 ch2_scribe
		{
			"timestamp": 8.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch2_scribe",
				"position": "NORTH",
				"speed": 55.0,
			},
		},
		# 生成敌人 ch2_scribe
		{
			"timestamp": 8.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch2_scribe",
				"position": "SOUTH",
				"speed": 55.0,
			},
		},
		# 生成蜂群 ch2_choir
		{
			"timestamp": 15.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch2_choir",
				"count": 5,
				"formation": "V_SHAPE",
				"direction": "EAST",
				"speed": 60.0,
				"swarm_enabled": true,
			},
		},
	]
