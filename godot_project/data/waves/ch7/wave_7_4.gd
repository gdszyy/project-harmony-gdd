## wave_7-4.gd
## 波次 7-4：音色增益 (练习波)
##
## 教学目标：练习在不同音色和相位间快速切换。
##
## 触发时机：按顺序触发
## BPM：165.0
## 预计时长：~55.0 秒
extends "res://scripts/data/wave_data.gd"

func _init() -> void:
	wave_name = "音色增益"
	wave_type = "practice"
	chapter_id = "ch7"
	wave_id = "7-4"
	estimated_duration = 55.0
	success_condition = "kill_all"
	
	events = [
		# 设置 BPM 为 165.0
		{
			"timestamp": 0.0,
			"type": "SET_BPM",
			"params": {"bpm": 165.0},
		},
		# 教学提示
		{
			"timestamp": 0.0,
			"type": "SHOW_HINT",
			"params": {
				"text": "不断切换音色以防止敌人产生抗性",
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
				"speed": 45.0,
				"hp": 1200.0,
				"shield": 400.0,
			},
		},
		# 生成蜂群 ch7_glitch_phantom
		{
			"timestamp": 8.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch7_glitch_phantom",
				"count": 3,
				"formation": "SCATTERED",
				"direction": "SOUTH",
				"speed": 125.0,
				"swarm_enabled": true,
			},
		},
		# 生成敌人 ch7_bitcrusher_worm
		{
			"timestamp": 20.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch7_bitcrusher_worm",
				"position": "EAST",
				"speed": 65.0,
			},
		},
	]
