## wave_3-6.gd
## 波次 3-6：多声部协作 (考试波)
##
## 教学目标：综合考验和弦进行与黑键效果器。
##
## 触发时机：按顺序触发
## BPM：125.0
## 预计时长：~60.0 秒
extends "res://scripts/data/wave_data.gd"

func _init() -> void:
	wave_name = "多声部协作"
	wave_type = "exam"
	chapter_id = "ch3"
	wave_id = "3-6"
	estimated_duration = 60.0
	success_condition = "kill_all"
	
	events = [
		# 设置 BPM 为 125.0
		{
			"timestamp": 0.0,
			"type": "SET_BPM",
			"params": {"bpm": 125.0},
		},
		# 教学提示
		{
			"timestamp": 0.0,
			"type": "SHOW_HINT",
			"params": {
				"text": "综合考验：结合和弦进行与黑键效果器",
				"duration": 4.0,
			},
		},
		# 生成敌人 ch3_counterpoint_crawler
		{
			"timestamp": 2.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch3_counterpoint_crawler",
				"position": "NORTH",
				"speed": 45.0,
			},
		},
		# 生成敌人 pulse
		{
			"timestamp": 5.0,
			"type": "SPAWN",
			"params": {
				"enemy": "pulse",
				"position": "EAST",
				"speed": 55.0,
			},
		},
		# 生成敌人 ch3_counterpoint_crawler
		{
			"timestamp": 15.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch3_counterpoint_crawler",
				"position": "SOUTH",
				"speed": 45.0,
			},
		},
		# 生成敌人 pulse
		{
			"timestamp": 18.0,
			"type": "SPAWN",
			"params": {
				"enemy": "pulse",
				"position": "WEST",
				"speed": 55.0,
			},
		},
		# 生成蜂群 static
		{
			"timestamp": 25.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "static",
				"count": 10,
				"formation": "SCATTERED",
				"direction": "NORTH",
				"speed": 90.0,
				"swarm_enabled": true,
			},
		},
	]
