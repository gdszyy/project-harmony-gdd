## wave_3-5.gd
## 波次 3-5：黑键效果器 (教学波)
##
## 教学目标：教学穿透和追踪效果器。
##
## 触发时机：按顺序触发
## BPM：120.0
## 预计时长：~45.0 秒
extends "res://scripts/data/wave_data.gd"

func _init() -> void:
	wave_name = "黑键效果器"
	wave_type = "tutorial"
	chapter_id = "ch3"
	wave_id = "3-5"
	estimated_duration = 45.0
	success_condition = "kill_all"
	
	events = [
		# 设置 BPM 为 120.0
		{
			"timestamp": 0.0,
			"type": "SET_BPM",
			"params": {"bpm": 120.0},
		},
		# 教学提示
		{
			"timestamp": 0.0,
			"type": "SHOW_HINT",
			"params": {
				"text": "使用C#穿透效果器处理对位爬虫的主体和炮塔",
				"duration": 5.0,
			},
		},
		# 生成敌人 ch3_counterpoint_crawler
		{
			"timestamp": 2.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch3_counterpoint_crawler",
				"position": "NORTH",
				"speed": 40.0,
			},
		},
		# 生成敌人 ch3_counterpoint_crawler
		{
			"timestamp": 15.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch3_counterpoint_crawler",
				"position": "SOUTH",
				"speed": 40.0,
			},
		},
	]
