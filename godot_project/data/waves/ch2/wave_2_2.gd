## wave_2_2.gd
## 波次 2-2：圣咏风暴 (Boss前置高潮波)
##
## 设计目标：为 Boss Guido 战做铺垫的高强度波次。
## 大量 Choir 和 Scribe 从多方向涌入，BPM 提升至 108。
## Cantor Commander 精英作为 Boss 的先锋出现，预告 Boss 战的到来。
##
## 触发时机：Boss 战前最后一个剧本波次
## BPM：108
## 预计时长：~55 秒
extends "res://scripts/data/wave_data.gd"

func _init() -> void:
	wave_name = "圣咏风暴"
	wave_type = "exam"
	chapter_id = "ch2"
	wave_id = "2-2"
	estimated_duration = 55.0
	success_condition = "kill_all"
	
	events = [
		# BPM 提升至 108
		{
			"timestamp": 0.0,
			"type": "SET_BPM",
			"params": {"bpm": 108.0},
		},
		# 剧情提示
		{
			"timestamp": 0.0,
			"type": "SHOW_HINT",
			"params": {
				"text": "圭多的记谱法力量正在汇聚——准备迎接圣咏宗师的考验",
				"duration": 4.0,
			},
		},
		# 第一波：Choir 蜂群从北方冲来
		{
			"timestamp": 2.5,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch2_choir",
				"count": 6,
				"formation": "V_SHAPE",
				"direction": "NORTH",
				"speed": 70.0,
				"swarm_enabled": true,
			},
		},
		# 第二波：Scribe 从两侧夹击
		{
			"timestamp": 6.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch2_scribe",
				"position": "EAST",
				"speed": 55.0,
			},
		},
		{
			"timestamp": 6.5,
			"type": "SPAWN",
			"params": {
				"enemy": "ch2_scribe",
				"position": "WEST",
				"speed": 55.0,
			},
		},
		{
			"timestamp": 7.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch2_scribe",
				"position": "EAST",
				"speed": 60.0,
			},
		},
		# 第三波：大规模 Choir 蜂群 + Static 混合
		{
			"timestamp": 12.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch2_choir",
				"count": 8,
				"formation": "CIRCLE",
				"direction": "SOUTH",
				"speed": 75.0,
				"swarm_enabled": true,
			},
		},
		{
			"timestamp": 13.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "static",
				"count": 4,
				"formation": "LINE",
				"direction": "WEST",
				"speed": 90.0,
				"swarm_enabled": false,
			},
		},
		# 第四波：Cantor Commander 精英入场（Boss 先锋）
		{
			"timestamp": 20.0,
			"type": "SHOW_HINT",
			"params": {
				"text": "圣咏指挥官出现了——它是圭多的左膀右臂！",
				"duration": 3.0,
			},
		},
		{
			"timestamp": 21.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch2_cantor_commander",
				"position": "NORTH",
				"speed": 40.0,
				"hp": 150.0,
			},
		},
		# 精英护卫
		{
			"timestamp": 21.5,
			"type": "SPAWN_ESCORT",
			"params": {
				"enemy": "ch2_choir",
				"count": 4,
				"orbit_target": "LAST_SPAWNED",
				"orbit_radius": 70.0,
				"speed": 65.0,
			},
		},
		# 最终冲刺：全方向 Choir 涌入
		{
			"timestamp": 30.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch2_choir",
				"count": 6,
				"formation": "SCATTERED",
				"direction": "NORTH",
				"speed": 80.0,
				"swarm_enabled": true,
			},
		},
		{
			"timestamp": 32.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch2_choir",
				"count": 4,
				"formation": "SCATTERED",
				"direction": "SOUTH",
				"speed": 80.0,
				"swarm_enabled": true,
			},
		},
	]
