## wave_6-3.gd
## 波次 6-3：无调性迷宫 (练习波)
##
## 教学目标：处理大量Atonal Amalgam敌人。
##
## 触发时机：按顺序触发
## BPM：145.0
## 预计时长：~50.0 秒
extends "res://scripts/data/wave_data.gd"

func _init() -> void:
	wave_name = "无调性迷宫"
	wave_type = "practice"
	chapter_id = "ch6"
	wave_id = "6-3"
	estimated_duration = 50.0
	success_condition = "kill_all"
	
	events = [
		# 设置 BPM 为 145.0
		{
			"timestamp": 0.0,
			"type": "SET_BPM",
			"params": {"bpm": 145.0},
		},
		# 教学提示
		{
			"timestamp": 0.0,
			"type": "SHOW_HINT",
			"params": {
				"text": "无调性融合体会分裂，准备好范围攻击",
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
				"speed": 50.0,
			},
		},
		# 生成敌人 ch6_atonal_amalgam
		{
			"timestamp": 5.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch6_atonal_amalgam",
				"position": "SOUTH",
				"speed": 50.0,
			},
		},
		# 生成敌人 ch6_atonal_amalgam
		{
			"timestamp": 15.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch6_atonal_amalgam",
				"position": "EAST",
				"speed": 50.0,
			},
		},
		# 生成敌人 ch6_atonal_amalgam
		{
			"timestamp": 18.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch6_atonal_amalgam",
				"position": "WEST",
				"speed": 50.0,
			},
		},
	]
