## wave_1_3.gd
## 波次 1-3：完美卡拍 (练习波)
##
## 教学目标：让玩家练习完美卡拍，体验 1.5 倍伤害和 2.5 倍击退。
## 8 只 Static 蜂群从北方排成一行冲来，启用蜂群加速。
## BPM 提升至 110，增加节奏紧迫感。
##
## 触发时机：第 5 个随机波次结束后
## BPM：110
## 预计时长：~35 秒
extends "res://scripts/data/wave_data.gd"

func _init() -> void:
	wave_name = "完美卡拍"
	wave_type = "practice"
	chapter_id = "ch1"
	wave_id = "1-3"
	estimated_duration = 35.0
	success_condition = "kill_all"
	
	events = [
		# BPM 提升至 110
		{
			"timestamp": 0.0,
			"type": "SET_BPM",
			"params": {"bpm": 110.0},
		},
		# 教学提示：完美卡拍加成
		{
			"timestamp": 0.0,
			"type": "SHOW_HINT",
			"params": {
				"text": "完美卡拍可获得 1.5 倍伤害和 2.5 倍击退",
				"duration": 4.0,
			},
		},
		# 8 只 Static 蜂群从北方排成一行
		{
			"timestamp": 2.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "static",
				"count": 8,
				"formation": "LINE",
				"direction": "NORTH",
				"speed": 100.0,
				"swarm_enabled": true,
			},
		},
	]
