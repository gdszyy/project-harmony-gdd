## wave_4_2.gd
## 波次 4-2：奏鸣曲式终章 (Boss前置高潮波)
##
## 设计目标：为 Boss Mozart 战做铺垫的高强度波次。
## 模拟奏鸣曲式结构：呈示部→发展部→再现部。
## Court Kapellmeister 精英作为 Boss 先锋出现，BPM 提升至 126。
##
## 触发时机：Boss 战前最后一个剧本波次
## BPM：126
## 预计时长：~60 秒
extends "res://scripts/data/wave_data.gd"

func _init() -> void:
	wave_name = "奏鸣曲式终章"
	wave_type = "exam"
	chapter_id = "ch4"
	wave_id = "4-2"
	estimated_duration = 60.0
	success_condition = "kill_all"
	
	events = [
		# BPM 提升至 126
		{
			"timestamp": 0.0,
			"type": "SET_BPM",
			"params": {"bpm": 126.0},
		},
		# 剧情提示
		{
			"timestamp": 0.0,
			"type": "SHOW_HINT",
			"params": {
				"text": "奏鸣曲式的终章——古典完形莫扎特即将降临",
				"duration": 4.0,
			},
		},
		# 呈示部（Exposition）：主题 Dancer + 副题 Crawler
		{
			"timestamp": 2.5,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch4_minuet_dancer",
				"count": 4,
				"formation": "LINE",
				"direction": "NORTH",
				"speed": 100.0,
				"swarm_enabled": false,
			},
		},
		{
			"timestamp": 5.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch3_counterpoint_crawler",
				"count": 3,
				"formation": "LINE",
				"direction": "SOUTH",
				"speed": 50.0,
				"swarm_enabled": false,
			},
		},
		# 发展部（Development）：高密度混合
		{
			"timestamp": 10.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch4_minuet_dancer",
				"count": 6,
				"formation": "SCATTERED",
				"direction": "EAST",
				"speed": 105.0,
				"swarm_enabled": true,
			},
		},
		{
			"timestamp": 12.0,
			"type": "SPAWN",
			"params": {
				"enemy": "pulse",
				"position": "WEST",
				"speed": 50.0,
			},
		},
		{
			"timestamp": 14.0,
			"type": "SPAWN",
			"params": {
				"enemy": "pulse",
				"position": "EAST",
				"speed": 50.0,
			},
		},
		{
			"timestamp": 15.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch2_choir",
				"count": 4,
				"formation": "SCATTERED",
				"direction": "SOUTH",
				"speed": 70.0,
				"swarm_enabled": false,
			},
		},
		# Court Kapellmeister 精英入场（Boss 先锋）
		{
			"timestamp": 22.0,
			"type": "SHOW_HINT",
			"params": {
				"text": "宫廷乐长出现——莫扎特的忠实仆从！",
				"duration": 3.0,
			},
		},
		{
			"timestamp": 23.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch4_court_kapellmeister",
				"position": "NORTH",
				"speed": 35.0,
				"hp": 250.0,
			},
		},
		# 精英护卫
		{
			"timestamp": 23.5,
			"type": "SPAWN_ESCORT",
			"params": {
				"enemy": "ch4_minuet_dancer",
				"count": 4,
				"orbit_target": "LAST_SPAWNED",
				"orbit_radius": 90.0,
				"speed": 95.0,
			},
		},
		# 再现部（Recapitulation）：全方向高密度涌入
		{
			"timestamp": 32.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch4_minuet_dancer",
				"count": 8,
				"formation": "V_SHAPE",
				"direction": "NORTH",
				"speed": 110.0,
				"swarm_enabled": true,
			},
		},
		{
			"timestamp": 35.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch4_minuet_dancer",
				"count": 5,
				"formation": "CIRCLE",
				"direction": "SOUTH",
				"speed": 110.0,
				"swarm_enabled": true,
			},
		},
		{
			"timestamp": 38.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch3_counterpoint_crawler",
				"position": "WEST",
				"speed": 55.0,
			},
		},
	]
