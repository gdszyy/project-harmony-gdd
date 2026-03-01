## wave_4-5.gd
## 波次 4-5：密度疲劳与留白 (教学波)
##
## 教学目标：教学疲劳系统，要求玩家有节奏地施法。
##
## 触发时机：按顺序触发
## BPM：120.0
## 预计时长：~55.0 秒
extends "res://scripts/data/wave_data.gd"

func _init() -> void:
	wave_name = "密度疲劳与留白"
	wave_type = "tutorial"
	chapter_id = "ch4"
	wave_id = "4-5"
	estimated_duration = 55.0
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
				"text": "注意施法节奏，过度密集的攻击会导致疲劳削弱伤害",
				"duration": 5.0,
			},
		},
		# 生成蜂群 static
		{
			"timestamp": 2.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "static",
				"count": 30,
				"formation": "SCATTERED",
				"direction": "ALL",
				"speed": 70.0,
				"swarm_enabled": true,
			},
		},
	]
