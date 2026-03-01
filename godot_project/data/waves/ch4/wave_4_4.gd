## wave_4-4.gd
## 波次 4-4：和弦进行完整度 (教学波)
##
## 教学目标：教学4和弦进行的2.0倍率奖励。
##
## 触发时机：按顺序触发
## BPM：115.0
## 预计时长：~50.0 秒
extends "res://scripts/data/wave_data.gd"

func _init() -> void:
	wave_name = "和弦进行完整度"
	wave_type = "tutorial"
	chapter_id = "ch4"
	wave_id = "4-4"
	estimated_duration = 50.0
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
				"text": "连续释放4个和弦构成完整进行，获得2.0倍伤害奖励",
				"duration": 5.0,
			},
		},
		# 生成敌人 wall
		{
			"timestamp": 2.0,
			"type": "SPAWN",
			"params": {
				"enemy": "wall",
				"position": "CENTER",
				"speed": 25.0,
				"hp": 800.0,
				"shield": 200.0,
			},
		},
	]
