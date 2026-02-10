## wave_1_1.gd
## 波次 1-1：初识节拍 (教学波)
## 
## 教学目标：让玩家感受节拍节奏，学会跟随地面脉冲进行攻击。
## 4 只 Static 从四个方向依次出现，间隔 2.4 秒（约 4 拍@BPM=100）。
## 
## 触发时机：章节开始时立即触发
## BPM：100
## 预计时长：~30 秒
extends "res://scripts/data/wave_data.gd"

func _init() -> void:
	wave_name = "初识节拍"
	wave_type = "tutorial"
	chapter_id = "ch1"
	wave_id = "1-1"
	estimated_duration = 30.0
	success_condition = "kill_all"
	
	events = [
		# 设置 BPM 为 100（章节起始节奏）
		{
			"timestamp": 0.0,
			"type": "SET_BPM",
			"params": {"bpm": 100.0},
		},
		# 教学提示：跟随节拍
		{
			"timestamp": 0.0,
			"type": "SHOW_HINT",
			"params": {
				"text": "跟随地面的脉冲节奏进行攻击",
				"duration": 4.0,
			},
		},
		# 第 1 只 Static：北方
		{
			"timestamp": 2.4,
			"type": "SPAWN",
			"params": {
				"enemy": "static",
				"position": "NORTH",
				"speed": 80.0,
			},
		},
		# 第 2 只 Static：东方
		{
			"timestamp": 4.8,
			"type": "SPAWN",
			"params": {
				"enemy": "static",
				"position": "EAST",
				"speed": 80.0,
			},
		},
		# 第 3 只 Static：南方
		{
			"timestamp": 7.2,
			"type": "SPAWN",
			"params": {
				"enemy": "static",
				"position": "SOUTH",
				"speed": 80.0,
			},
		},
		# 第 4 只 Static：西方
		{
			"timestamp": 9.6,
			"type": "SPAWN",
			"params": {
				"enemy": "static",
				"position": "WEST",
				"speed": 80.0,
			},
		},
	]
