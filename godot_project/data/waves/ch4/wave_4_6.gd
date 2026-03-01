## wave_4-6.gd
## 波次 4-6：结构之美 (考试波)
##
## 教学目标：综合考验七和弦、和弦进行完整度和疲劳管理。
##
## 触发时机：按顺序触发
## BPM：120.0
## 预计时长：~65.0 秒
extends "res://scripts/data/wave_data.gd"

func _init() -> void:
	wave_name = "结构之美"
	wave_type = "exam"
	chapter_id = "ch4"
	wave_id = "4-6"
	estimated_duration = 65.0
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
				"text": "综合考验：合理运用七和弦并保持施法的呼吸感",
				"duration": 5.0,
			},
		},
		# 生成蜂群 ch4_minuet_dancer
		{
			"timestamp": 2.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch4_minuet_dancer",
				"count": 4,
				"formation": "MIRROR",
				"direction": "EAST_WEST",
				"speed": 60.0,
				"swarm_enabled": true,
			},
		},
		# 生成敌人 wall
		{
			"timestamp": 10.0,
			"type": "SPAWN",
			"params": {
				"enemy": "wall",
				"position": "NORTH",
				"speed": 35.0,
				"hp": 500.0,
				"shield": 100.0,
			},
		},
		# 生成蜂群 screech
		{
			"timestamp": 15.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "screech",
				"count": 3,
				"formation": "SCATTERED",
				"direction": "SOUTH",
				"speed": 90.0,
				"swarm_enabled": true,
			},
		},
		# 生成敌人 wall
		{
			"timestamp": 25.0,
			"type": "SPAWN",
			"params": {
				"enemy": "wall",
				"position": "SOUTH",
				"speed": 35.0,
				"hp": 500.0,
				"shield": 100.0,
			},
		},
		# 生成蜂群 ch4_minuet_dancer
		{
			"timestamp": 30.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch4_minuet_dancer",
				"count": 4,
				"formation": "MIRROR",
				"direction": "NORTH_SOUTH",
				"speed": 60.0,
				"swarm_enabled": true,
			},
		},
	]
