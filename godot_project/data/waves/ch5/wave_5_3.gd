## wave_5-3.gd
## 波次 5-3：不和谐度的力量 (练习波)
##
## 教学目标：练习利用减七和弦的高不和谐度进行爆发。
##
## 触发时机：按顺序触发
## BPM：130.0
## 预计时长：~45.0 秒
extends "res://scripts/data/wave_data.gd"

func _init() -> void:
	wave_name = "不和谐度的力量"
	wave_type = "practice"
	chapter_id = "ch5"
	wave_id = "5-3"
	estimated_duration = 45.0
	success_condition = "kill_all"
	
	events = [
		# 设置 BPM 为 130.0
		{
			"timestamp": 0.0,
			"type": "SET_BPM",
			"params": {"bpm": 130.0},
		},
		# 教学提示
		{
			"timestamp": 0.0,
			"type": "SHOW_HINT",
			"params": {
				"text": "减七和弦能快速积攒不和谐度，触发强大的毁灭打击",
				"duration": 5.0,
			},
		},
		# 生成蜂群 ch5_rubato_stalker
		{
			"timestamp": 2.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch5_rubato_stalker",
				"count": 4,
				"formation": "SCATTERED",
				"direction": "NORTH",
				"speed": 75.0,
				"swarm_enabled": true,
			},
		},
		# 生成敌人 wall
		{
			"timestamp": 10.0,
			"type": "SPAWN",
			"params": {
				"enemy": "wall",
				"position": "SOUTH",
				"speed": 40.0,
				"hp": 600.0,
				"shield": 150.0,
			},
		},
	]
