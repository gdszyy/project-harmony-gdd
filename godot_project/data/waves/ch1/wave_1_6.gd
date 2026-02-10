## wave_1_6.gd
## 波次 1-6：综合运用 (考试波)
##
## 教学目标：综合考验玩家对所有已学机制的掌握。
## 10 只 Static 蜂群 + 2 只 Pulse + 1 只 Wall，从三个方向分批入场。
## BPM 提升至 120，增加最终考验的紧迫感。
##
## 触发时机：第 9 个随机波次结束后
## BPM：120
## 预计时长：~60 秒
extends "res://scripts/data/wave_data.gd"

func _init() -> void:
	wave_name = "综合运用"
	wave_type = "exam"
	chapter_id = "ch1"
	wave_id = "1-6"
	estimated_duration = 60.0
	success_condition = "kill_all"
	
	events = [
		# BPM 提升至 120
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
				"text": "综合运用所有技巧",
				"duration": 3.0,
			},
		},
		# 10 只 Static 蜂群从北方散开冲来
		{
			"timestamp": 2.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "static",
				"count": 10,
				"formation": "SCATTERED",
				"direction": "NORTH",
				"speed": 110.0,
				"swarm_enabled": true,
			},
		},
		# 第 1 只 Pulse 从东方入场（4 拍周期弹幕）
		{
			"timestamp": 8.0,
			"type": "SPAWN",
			"params": {
				"enemy": "pulse",
				"position": "EAST",
				"speed": 50.0,
			},
		},
		# Wall 从南方入场
		{
			"timestamp": 12.0,
			"type": "SPAWN",
			"params": {
				"enemy": "wall",
				"position": "SOUTH",
				"speed": 30.0,
				"hp": 200.0,
				"shield": 50.0,
			},
		},
		# 第 2 只 Pulse 从西方入场
		{
			"timestamp": 18.0,
			"type": "SPAWN",
			"params": {
				"enemy": "pulse",
				"position": "WEST",
				"speed": 50.0,
			},
		},
	]
