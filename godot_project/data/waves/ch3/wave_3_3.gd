## wave_3-3.gd
## 波次 3-3：和弦进行：D->T爆发 (教学波)
##
## 教学目标：教学和弦进行机制，特别是属到主的爆发效果。
##
## 触发时机：按顺序触发
## BPM：110.0
## 预计时长：~40.0 秒
extends "res://scripts/data/wave_data.gd"

func _init() -> void:
	wave_name = "和弦进行：D->T爆发"
	wave_type = "tutorial"
	chapter_id = "ch3"
	wave_id = "3-3"
	estimated_duration = 40.0
	success_condition = "kill_all"
	
	events = [
		# 设置 BPM 为 110.0
		{
			"timestamp": 0.0,
			"type": "SET_BPM",
			"params": {"bpm": 110.0},
		},
		# 教学提示
		{
			"timestamp": 0.0,
			"type": "SHOW_HINT",
			"params": {
				"text": "连续释放减三(D)到大三(T)触发爆发效果",
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
				"speed": 40.0,
				"hp": 400.0,
				"shield": 100.0,
			},
		},
		# 生成蜂群 static
		{
			"timestamp": 10.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "static",
				"count": 6,
				"formation": "SCATTERED",
				"direction": "SOUTH",
				"speed": 80.0,
				"swarm_enabled": true,
			},
		},
	]
