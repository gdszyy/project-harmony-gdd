## wave_5_2.gd
## 波次 5-2：英雄交响 (Boss前置高潮波)
##
## 设计目标：为 Boss Beethoven 战做铺垫的高强度波次。
## 模拟交响曲的四个乐章压缩：快板→慢板→谐谑曲→终曲。
## Symphony Commander 精英作为 Boss 先锋出现，BPM 提升至 138。
##
## 触发时机：Boss 战前最后一个剧本波次
## BPM：138
## 预计时长：~65 秒
extends "res://scripts/data/wave_data.gd"

func _init() -> void:
	wave_name = "英雄交响"
	wave_type = "exam"
	chapter_id = "ch5"
	wave_id = "5-2"
	estimated_duration = 65.0
	success_condition = "kill_all"
	
	events = [
		# BPM 提升至 138
		{
			"timestamp": 0.0,
			"type": "SET_BPM",
			"params": {"bpm": 138.0},
		},
		# 剧情提示
		{
			"timestamp": 0.0,
			"type": "SHOW_HINT",
			"params": {
				"text": "命运交响曲的终章——狂想者贝多芬即将以全部意志降临",
				"duration": 4.0,
			},
		},
		# 第一乐章（快板）：Fate Knocker 快速涌入
		{
			"timestamp": 2.5,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch5_fate_knocker",
				"count": 4,
				"formation": "V_SHAPE",
				"direction": "NORTH",
				"speed": 45.0,
				"swarm_enabled": true,
			},
		},
		{
			"timestamp": 5.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch5_crescendo_surge",
				"count": 4,
				"formation": "LINE",
				"direction": "SOUTH",
				"speed": 65.0,
				"swarm_enabled": false,
			},
		},
		# 第二乐章（慢板）：Wall 坦克 + 护卫
		{
			"timestamp": 10.0,
			"type": "SPAWN",
			"params": {
				"enemy": "wall",
				"position": "NORTH",
				"speed": 25.0,
				"hp": 250.0,
				"shield": 80.0,
			},
		},
		{
			"timestamp": 10.5,
			"type": "SPAWN_ESCORT",
			"params": {
				"enemy": "ch5_crescendo_surge",
				"count": 4,
				"orbit_target": "LAST_SPAWNED",
				"orbit_radius": 80.0,
				"speed": 60.0,
			},
		},
		# 第三乐章（谐谑曲）：高速 Fury Spirit 突袭
		{
			"timestamp": 18.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch5_fury_spirit",
				"position": "EAST",
				"speed": 90.0,
			},
		},
		{
			"timestamp": 19.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch5_fury_spirit",
				"position": "WEST",
				"speed": 90.0,
			},
		},
		{
			"timestamp": 20.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch4_minuet_dancer",
				"count": 5,
				"formation": "SCATTERED",
				"direction": "SOUTH",
				"speed": 100.0,
				"swarm_enabled": true,
			},
		},
		# Symphony Commander 精英入场（Boss 先锋）
		{
			"timestamp": 26.0,
			"type": "SHOW_HINT",
			"params": {
				"text": "交响指挥官出现——贝多芬的意志化身！",
				"duration": 3.0,
			},
		},
		{
			"timestamp": 27.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch5_symphony_commander",
				"position": "NORTH",
				"speed": 30.0,
				"hp": 300.0,
			},
		},
		{
			"timestamp": 27.5,
			"type": "SPAWN_ESCORT",
			"params": {
				"enemy": "ch5_fate_knocker",
				"count": 3,
				"orbit_target": "LAST_SPAWNED",
				"orbit_radius": 90.0,
				"speed": 42.0,
			},
		},
		# 第四乐章（终曲）：全方向高密度涌入
		{
			"timestamp": 36.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch5_fate_knocker",
				"count": 6,
				"formation": "CIRCLE",
				"direction": "NORTH",
				"speed": 48.0,
				"swarm_enabled": true,
			},
		},
		{
			"timestamp": 38.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch5_crescendo_surge",
				"count": 6,
				"formation": "SCATTERED",
				"direction": "SOUTH",
				"speed": 70.0,
				"swarm_enabled": true,
			},
		},
		{
			"timestamp": 40.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch5_fury_spirit",
				"position": "EAST",
				"speed": 95.0,
			},
		},
		{
			"timestamp": 41.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch5_fury_spirit",
				"position": "WEST",
				"speed": 95.0,
			},
		},
	]
