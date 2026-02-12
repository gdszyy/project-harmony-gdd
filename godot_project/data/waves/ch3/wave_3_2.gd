## wave_3_2.gd
## 波次 3-2：赋格风暴 (Boss前置高潮波)
##
## 设计目标：为 Boss Bach 战做铺垫的高强度波次。
## 大量 Counterpoint Crawler 以赋格形式（主题-应答-对题）分批入场。
## Fugue Weaver 精英作为 Boss 先锋出现，BPM 提升至 116。
##
## 触发时机：Boss 战前最后一个剧本波次
## BPM：116
## 预计时长：~60 秒
extends "res://scripts/data/wave_data.gd"

func _init() -> void:
	wave_name = "赋格风暴"
	wave_type = "exam"
	chapter_id = "ch3"
	wave_id = "3-2"
	estimated_duration = 60.0
	success_condition = "kill_all"
	
	events = [
		# BPM 提升至 116
		{
			"timestamp": 0.0,
			"type": "SET_BPM",
			"params": {"bpm": 116.0},
		},
		# 剧情提示
		{
			"timestamp": 0.0,
			"type": "SHOW_HINT",
			"params": {
				"text": "赋格的主题正在展开——大构建师巴赫即将现身",
				"duration": 4.0,
			},
		},
		# 赋格主题（Exposition）：Crawler 从北方依次入场
		{
			"timestamp": 2.5,
			"type": "SPAWN",
			"params": {
				"enemy": "ch3_counterpoint_crawler",
				"position": "NORTH",
				"speed": 50.0,
			},
		},
		{
			"timestamp": 4.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch3_counterpoint_crawler",
				"position": "EAST",
				"speed": 50.0,
			},
		},
		{
			"timestamp": 5.5,
			"type": "SPAWN",
			"params": {
				"enemy": "ch3_counterpoint_crawler",
				"position": "SOUTH",
				"speed": 50.0,
			},
		},
		{
			"timestamp": 7.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch3_counterpoint_crawler",
				"position": "WEST",
				"speed": 50.0,
			},
		},
		# 赋格发展（Development）：蜂群 + Pulse 混合
		{
			"timestamp": 10.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch3_counterpoint_crawler",
				"count": 6,
				"formation": "CIRCLE",
				"direction": "NORTH",
				"speed": 55.0,
				"swarm_enabled": true,
			},
		},
		{
			"timestamp": 12.0,
			"type": "SPAWN",
			"params": {
				"enemy": "pulse",
				"position": "EAST",
				"speed": 45.0,
			},
		},
		{
			"timestamp": 13.0,
			"type": "SPAWN",
			"params": {
				"enemy": "pulse",
				"position": "WEST",
				"speed": 45.0,
			},
		},
		# 旧章敌人作为填充声部
		{
			"timestamp": 15.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch2_choir",
				"count": 5,
				"formation": "SCATTERED",
				"direction": "SOUTH",
				"speed": 65.0,
				"swarm_enabled": false,
			},
		},
		# Fugue Weaver 精英入场（Boss 先锋）
		{
			"timestamp": 22.0,
			"type": "SHOW_HINT",
			"params": {
				"text": "赋格编织者出现——它能同时操控多条声部线！",
				"duration": 3.0,
			},
		},
		{
			"timestamp": 23.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch3_fugue_weaver",
				"position": "NORTH",
				"speed": 35.0,
				"hp": 200.0,
			},
		},
		# 精英护卫
		{
			"timestamp": 23.5,
			"type": "SPAWN_ESCORT",
			"params": {
				"enemy": "ch3_counterpoint_crawler",
				"count": 4,
				"orbit_target": "LAST_SPAWNED",
				"orbit_radius": 80.0,
				"speed": 50.0,
			},
		},
		# 赋格再现（Recapitulation）：全方向高密度涌入
		{
			"timestamp": 32.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch3_counterpoint_crawler",
				"count": 8,
				"formation": "V_SHAPE",
				"direction": "NORTH",
				"speed": 60.0,
				"swarm_enabled": true,
			},
		},
		{
			"timestamp": 35.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch3_counterpoint_crawler",
				"count": 5,
				"formation": "LINE",
				"direction": "SOUTH",
				"speed": 60.0,
				"swarm_enabled": true,
			},
		},
		{
			"timestamp": 37.0,
			"type": "SPAWN",
			"params": {
				"enemy": "pulse",
				"position": "EAST",
				"speed": 50.0,
			},
		},
	]
