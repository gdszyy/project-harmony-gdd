## wave_7-5.gd
## 波次 7-5：最终的交响 (考试波)
##
## 教学目标：Boss战前的终极考验，所有机制大融合。
##
## 触发时机：按顺序触发
## BPM：170.0
## 预计时长：~70.0 秒
extends "res://scripts/data/wave_data.gd"

func _init() -> void:
	wave_name = "最终的交响"
	wave_type = "exam"
	chapter_id = "ch7"
	wave_id = "7-5"
	estimated_duration = 70.0
	success_condition = "kill_all"
	
	events = [
		# 设置 BPM 为 170.0
		{
			"timestamp": 0.0,
			"type": "SET_BPM",
			"params": {"bpm": 170.0},
		},
		# 教学提示
		{
			"timestamp": 0.0,
			"type": "SHOW_HINT",
			"params": {
				"text": "最终的考验：运用你学到的一切",
				"duration": 5.0,
			},
		},
		# 生成蜂群 ch7_glitch_phantom
		{
			"timestamp": 2.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch7_glitch_phantom",
				"count": 5,
				"formation": "SCATTERED",
				"direction": "ALL",
				"speed": 130.0,
				"swarm_enabled": true,
			},
		},
		# 生成敌人 ch7_bitcrusher_worm
		{
			"timestamp": 10.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch7_bitcrusher_worm",
				"position": "NORTH",
				"speed": 70.0,
			},
		},
		# 生成敌人 ch7_bitcrusher_worm
		{
			"timestamp": 12.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch7_bitcrusher_worm",
				"position": "SOUTH",
				"speed": 70.0,
			},
		},
		# 生成敌人 wall
		{
			"timestamp": 20.0,
			"type": "SPAWN",
			"params": {
				"enemy": "wall",
				"position": "EAST",
				"speed": 50.0,
				"hp": 1500.0,
				"shield": 500.0,
			},
		},
		# 生成蜂群 screech
		{
			"timestamp": 30.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "screech",
				"count": 8,
				"formation": "CIRCLE",
				"direction": "CENTER",
				"speed": 140.0,
				"swarm_enabled": true,
			},
		},
		# 生成蜂群 ch7_glitch_phantom
		{
			"timestamp": 40.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch7_glitch_phantom",
				"count": 4,
				"formation": "SCATTERED",
				"direction": "WEST",
				"speed": 135.0,
				"swarm_enabled": true,
			},
		},
	]
