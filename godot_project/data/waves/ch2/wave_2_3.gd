## wave_2-3.gd
## 波次 2-3：多声部协同 (练习波)
##
## 教学目标：让玩家练习处理多个声部的敌人，Choir和Scribe交替出现。
##
## 触发时机：按顺序触发
## BPM：95.0
## 预计时长：~40.0 秒
extends "res://scripts/data/wave_data.gd"

func _init() -> void:
	wave_name = "多声部协同"
	wave_type = "practice"
	chapter_id = "ch2"
	wave_id = "2-3"
	estimated_duration = 40.0
	success_condition = "kill_all"
	
	events = [
		# 设置 BPM 为 95.0
		{
			"timestamp": 0.0,
			"type": "SET_BPM",
			"params": {"bpm": 95.0},
		},
		# 教学提示
		{
			"timestamp": 0.0,
			"type": "SHOW_HINT",
			"params": {
				"text": "注意躲避抄谱员的标记，同时击破唱诗班",
				"duration": 4.0,
			},
		},
		# 生成蜂群 ch2_choir
		{
			"timestamp": 2.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch2_choir",
				"count": 4,
				"formation": "LINE",
				"direction": "NORTH",
				"speed": 60.0,
				"swarm_enabled": true,
			},
		},
		# 生成敌人 ch2_scribe
		{
			"timestamp": 5.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch2_scribe",
				"position": "EAST",
				"speed": 50.0,
			},
		},
		# 生成蜂群 ch2_choir
		{
			"timestamp": 10.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch2_choir",
				"count": 3,
				"formation": "SCATTERED",
				"direction": "SOUTH",
				"speed": 65.0,
				"swarm_enabled": true,
			},
		},
		# 生成敌人 ch2_scribe
		{
			"timestamp": 12.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch2_scribe",
				"position": "WEST",
				"speed": 50.0,
			},
		},
	]
