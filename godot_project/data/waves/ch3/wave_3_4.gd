## wave_3-4.gd
## 波次 3-4：和弦进行：T->D蓄力 (练习波)
##
## 教学目标：练习主到属的蓄力效果。
##
## 触发时机：按顺序触发
## BPM：115.0
## 预计时长：~45.0 秒
extends "res://scripts/data/wave_data.gd"

func _init() -> void:
	wave_name = "和弦进行：T->D蓄力"
	wave_type = "practice"
	chapter_id = "ch3"
	wave_id = "3-4"
	estimated_duration = 45.0
	success_condition = "kill_all"
	
	events = [
		# 设置 BPM 为 115.0
		{
			"timestamp": 0.0,
			"type": "SET_BPM",
			"params": {"bpm": 115.0},
		},
		# 教学提示
		{
			"timestamp": 0.0,
			"type": "SHOW_HINT",
			"params": {
				"text": "连续释放大三(T)到增三(D)进行蓄力，下一个法术伤害翻倍",
				"duration": 5.0,
			},
		},
		# 生成敌人 pulse
		{
			"timestamp": 2.0,
			"type": "SPAWN",
			"params": {
				"enemy": "pulse",
				"position": "EAST",
				"speed": 50.0,
			},
		},
		# 生成敌人 pulse
		{
			"timestamp": 4.0,
			"type": "SPAWN",
			"params": {
				"enemy": "pulse",
				"position": "WEST",
				"speed": 50.0,
			},
		},
		# 生成敌人 pulse
		{
			"timestamp": 6.0,
			"type": "SPAWN",
			"params": {
				"enemy": "pulse",
				"position": "NORTH",
				"speed": 50.0,
			},
		},
	]
