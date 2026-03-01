## wave_7-3.gd
## 波次 7-3：相位失调 (教学波)
##
## 教学目标：教学频谱相位系统，低通、高通、全频的切换。
##
## 触发时机：按顺序触发
## BPM：160.0
## 预计时长：~50.0 秒
extends "res://scripts/data/wave_data.gd"

func _init() -> void:
	wave_name = "相位失调"
	wave_type = "tutorial"
	chapter_id = "ch7"
	wave_id = "7-3"
	estimated_duration = 50.0
	success_condition = "kill_all"
	
	events = [
		# 设置 BPM 为 160.0
		{
			"timestamp": 0.0,
			"type": "SET_BPM",
			"params": {"bpm": 160.0},
		},
		# 教学提示
		{
			"timestamp": 0.0,
			"type": "SHOW_HINT",
			"params": {
				"text": "切换不同的频谱相位来应对不同类型的弹幕",
				"duration": 5.0,
			},
		},
		# 生成蜂群 ch7_glitch_phantom
		{
			"timestamp": 2.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch7_glitch_phantom",
				"count": 4,
				"formation": "SCATTERED",
				"direction": "ALL",
				"speed": 120.0,
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
				"speed": 60.0,
			},
		},
		# 生成敌人 ch7_bitcrusher_worm
		{
			"timestamp": 15.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch7_bitcrusher_worm",
				"position": "SOUTH",
				"speed": 60.0,
			},
		},
	]
