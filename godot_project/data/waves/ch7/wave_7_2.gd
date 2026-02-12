## wave_7_2.gd
## 波次 7-2：频谱崩解 (Boss前置高潮波)
##
## 设计目标：为 Boss Noise 战做铺垫的高强度波次。
## 大量 Bitcrusher Worm、Glitch Phantom 和 Silence 以混乱方式涌入。
## Frequency Overlord 精英作为 Boss 先锋出现，BPM 提升至 168。
## 这是游戏最终章节的最后考验。
##
## 触发时机：Boss 战前最后一个剧本波次
## BPM：168
## 预计时长：~70 秒
extends "res://scripts/data/wave_data.gd"

func _init() -> void:
	wave_name = "频谱崩解"
	wave_type = "exam"
	chapter_id = "ch7"
	wave_id = "7-2"
	estimated_duration = 70.0
	success_condition = "kill_all"
	
	events = [
		# BPM 提升至 168
		{
			"timestamp": 0.0,
			"type": "SET_BPM",
			"params": {"bpm": 168.0},
		},
		# 剧情提示
		{
			"timestamp": 0.0,
			"type": "SHOW_HINT",
			"params": {
				"text": "频谱正在崩解——合成主脑即将以纯粹的波形降临",
				"duration": 4.0,
			},
		},
		# 第一波：Bitcrusher Worm 降采样攻势
		{
			"timestamp": 2.5,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch7_bitcrusher_worm",
				"count": 5,
				"formation": "V_SHAPE",
				"direction": "NORTH",
				"speed": 55.0,
				"swarm_enabled": true,
			},
		},
		{
			"timestamp": 5.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch7_bitcrusher_worm",
				"count": 4,
				"formation": "LINE",
				"direction": "SOUTH",
				"speed": 55.0,
				"swarm_enabled": true,
			},
		},
		# 第二波：Glitch Phantom 故障风暴
		{
			"timestamp": 8.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch7_glitch_phantom",
				"count": 6,
				"formation": "SCATTERED",
				"direction": "EAST",
				"speed": 120.0,
				"swarm_enabled": true,
			},
		},
		{
			"timestamp": 10.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch7_glitch_phantom",
				"count": 5,
				"formation": "SCATTERED",
				"direction": "WEST",
				"speed": 120.0,
				"swarm_enabled": true,
			},
		},
		# 第三波：Silence 寂静潮
		{
			"timestamp": 14.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "silence",
				"count": 6,
				"formation": "CIRCLE",
				"direction": "NORTH",
				"speed": 65.0,
				"swarm_enabled": false,
			},
		},
		{
			"timestamp": 16.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "static",
				"count": 8,
				"formation": "SCATTERED",
				"direction": "SOUTH",
				"speed": 100.0,
				"swarm_enabled": true,
			},
		},
		# 第四波：Wall 坦克 + 混合护卫
		{
			"timestamp": 20.0,
			"type": "SPAWN",
			"params": {
				"enemy": "wall",
				"position": "NORTH",
				"speed": 25.0,
				"hp": 300.0,
				"shield": 100.0,
			},
		},
		{
			"timestamp": 20.5,
			"type": "SPAWN_ESCORT",
			"params": {
				"enemy": "ch7_glitch_phantom",
				"count": 4,
				"orbit_target": "LAST_SPAWNED",
				"orbit_radius": 90.0,
				"speed": 110.0,
			},
		},
		# Frequency Overlord 精英入场（Boss 先锋）
		{
			"timestamp": 28.0,
			"type": "SHOW_HINT",
			"params": {
				"text": "频率霸主出现——它掌控着所有波形的生杀大权！",
				"duration": 3.0,
			},
		},
		{
			"timestamp": 29.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch7_frequency_overlord",
				"position": "NORTH",
				"speed": 25.0,
				"hp": 400.0,
			},
		},
		# 精英护卫
		{
			"timestamp": 29.5,
			"type": "SPAWN_ESCORT",
			"params": {
				"enemy": "ch7_bitcrusher_worm",
				"count": 5,
				"orbit_target": "LAST_SPAWNED",
				"orbit_radius": 100.0,
				"speed": 52.0,
			},
		},
		# 最终冲刺：全方向极限密度涌入
		{
			"timestamp": 38.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch7_bitcrusher_worm",
				"count": 8,
				"formation": "CIRCLE",
				"direction": "NORTH",
				"speed": 60.0,
				"swarm_enabled": true,
			},
		},
		{
			"timestamp": 40.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch7_glitch_phantom",
				"count": 10,
				"formation": "SCATTERED",
				"direction": "SOUTH",
				"speed": 125.0,
				"swarm_enabled": true,
			},
		},
		{
			"timestamp": 42.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "silence",
				"count": 6,
				"formation": "SCATTERED",
				"direction": "EAST",
				"speed": 70.0,
				"swarm_enabled": false,
			},
		},
		{
			"timestamp": 44.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "static",
				"count": 8,
				"formation": "SCATTERED",
				"direction": "WEST",
				"speed": 105.0,
				"swarm_enabled": true,
			},
		},
		{
			"timestamp": 46.0,
			"type": "SPAWN",
			"params": {
				"enemy": "wall",
				"position": "SOUTH",
				"speed": 30.0,
				"hp": 250.0,
			},
		},
	]
