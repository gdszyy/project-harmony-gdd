## wave_6_2.gd
## 波次 6-2：比波普狂潮 (Boss前置高潮波)
##
## 设计目标：为 Boss Jazz 战做铺垫的高强度波次。
## 大量 Walking Bass 和 Scat Singer 以即兴方式涌入，摇摆节奏达到极致。
## Bebop Virtuoso 精英作为 Boss 先锋出现，BPM 提升至 152。
##
## 触发时机：Boss 战前最后一个剧本波次
## BPM：152
## 预计时长：~60 秒
extends "res://scripts/data/wave_data.gd"

func _init() -> void:
	wave_name = "比波普狂潮"
	wave_type = "exam"
	chapter_id = "ch6"
	wave_id = "6-2"
	estimated_duration = 60.0
	success_condition = "kill_all"
	
	events = [
		# BPM 提升至 152
		{
			"timestamp": 0.0,
			"type": "SET_BPM",
			"params": {"bpm": 152.0},
		},
		# 剧情提示
		{
			"timestamp": 0.0,
			"type": "SHOW_HINT",
			"params": {
				"text": "比波普的即兴狂潮——切分行者即将以最纯粹的自由降临",
				"duration": 4.0,
			},
		},
		# 第一波：Walking Bass 稳定低音线
		{
			"timestamp": 2.5,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch6_walking_bass",
				"count": 4,
				"formation": "LINE",
				"direction": "SOUTH",
				"speed": 40.0,
				"swarm_enabled": false,
			},
		},
		# 第二波：Scat Singer 即兴爆发
		{
			"timestamp": 5.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch6_scat_singer",
				"count": 6,
				"formation": "SCATTERED",
				"direction": "NORTH",
				"speed": 110.0,
				"swarm_enabled": true,
			},
		},
		{
			"timestamp": 7.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch6_scat_singer",
				"count": 4,
				"formation": "SCATTERED",
				"direction": "EAST",
				"speed": 115.0,
				"swarm_enabled": true,
			},
		},
		# 第三波：混合旧章敌人
		{
			"timestamp": 12.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch5_crescendo_surge",
				"count": 4,
				"formation": "V_SHAPE",
				"direction": "WEST",
				"speed": 70.0,
				"swarm_enabled": false,
			},
		},
		{
			"timestamp": 14.0,
			"type": "SPAWN",
			"params": {
				"enemy": "pulse",
				"position": "NORTH",
				"speed": 50.0,
			},
		},
		{
			"timestamp": 15.0,
			"type": "SPAWN",
			"params": {
				"enemy": "pulse",
				"position": "SOUTH",
				"speed": 50.0,
			},
		},
		# Bebop Virtuoso 精英入场（Boss 先锋）
		{
			"timestamp": 22.0,
			"type": "SHOW_HINT",
			"params": {
				"text": "比波普大师出现——即兴的极致化身！",
				"duration": 3.0,
			},
		},
		{
			"timestamp": 23.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch6_bebop_virtuoso",
				"position": "NORTH",
				"speed": 30.0,
				"hp": 350.0,
			},
		},
		# 精英护卫
		{
			"timestamp": 23.5,
			"type": "SPAWN_ESCORT",
			"params": {
				"enemy": "ch6_scat_singer",
				"count": 5,
				"orbit_target": "LAST_SPAWNED",
				"orbit_radius": 100.0,
				"speed": 105.0,
			},
		},
		# 最终冲刺：全方向高密度涌入
		{
			"timestamp": 32.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch6_walking_bass",
				"count": 6,
				"formation": "CIRCLE",
				"direction": "SOUTH",
				"speed": 42.0,
				"swarm_enabled": true,
			},
		},
		{
			"timestamp": 34.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch6_scat_singer",
				"count": 8,
				"formation": "SCATTERED",
				"direction": "NORTH",
				"speed": 120.0,
				"swarm_enabled": true,
			},
		},
		{
			"timestamp": 36.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch6_scat_singer",
				"count": 6,
				"formation": "SCATTERED",
				"direction": "EAST",
				"speed": 120.0,
				"swarm_enabled": true,
			},
		},
		{
			"timestamp": 38.0,
			"type": "SPAWN",
			"params": {
				"enemy": "screech",
				"position": "WEST",
				"speed": 80.0,
			},
		},
		{
			"timestamp": 39.0,
			"type": "SPAWN",
			"params": {
				"enemy": "wall",
				"position": "SOUTH",
				"speed": 30.0,
				"hp": 200.0,
			},
		},
	]
