## wave_2_1.gd
## 波次 2-1：记谱之光 (教学波)
##
## 教学目标：引入中世纪记谱法主题，让玩家认识 Choir（唱诗班）和 Scribe（抄谱员）敌人。
## Choir 敌人以群体齐唱方式攻击，Scribe 敌人会在地面留下音符标记。
## 玩家需要学会区分两种敌人的攻击模式并合理应对。
##
## 触发时机：章节开始时立即触发
## BPM：90（中世纪圣咏的庄严节奏）
## 预计时长：~35 秒
extends "res://scripts/data/wave_data.gd"

func _init() -> void:
	wave_name = "记谱之光"
	wave_type = "tutorial"
	chapter_id = "ch2"
	wave_id = "2-1"
	estimated_duration = 35.0
	success_condition = "kill_all"
	
	events = [
		# 设置 BPM 为 90（中世纪圣咏节奏）
		{
			"timestamp": 0.0,
			"type": "SET_BPM",
			"params": {"bpm": 90.0},
		},
		# 教学提示：介绍新敌人
		{
			"timestamp": 0.0,
			"type": "SHOW_HINT",
			"params": {
				"text": "圭多的记谱法赋予了声音形体——注意唱诗班和抄谱员的不同攻击方式",
				"duration": 5.0,
			},
		},
		# 解锁管风琴音色
		{
			"timestamp": 0.5,
			"type": "UNLOCK",
			"params": {
				"type": "feature",
				"feature": "timbre_organ",
				"message": "解锁：管风琴音色（和声层叠攻击）",
			},
		},
		# 第 1 组：3 只 Choir 从北方齐步入场
		{
			"timestamp": 3.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch2_choir",
				"count": 3,
				"formation": "LINE",
				"direction": "NORTH",
				"speed": 60.0,
				"swarm_enabled": false,
			},
		},
		# 教学提示：Choir 的特性
		{
			"timestamp": 3.5,
			"type": "SHOW_HINT",
			"params": {
				"text": "唱诗班敌人会齐声攻击——集中火力快速击破",
				"duration": 3.0,
			},
		},
		# 第 2 组：2 只 Scribe 从东方入场
		{
			"timestamp": 8.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch2_scribe",
				"position": "EAST",
				"speed": 50.0,
			},
		},
		{
			"timestamp": 10.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch2_scribe",
				"position": "WEST",
				"speed": 50.0,
			},
		},
		# 教学提示：Scribe 的特性
		{
			"timestamp": 8.5,
			"type": "SHOW_HINT",
			"params": {
				"text": "抄谱员会在地面留下音符标记——避开标记区域",
				"duration": 3.0,
			},
		},
		# 混合组：Choir + Scribe 同时出现
		{
			"timestamp": 15.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch2_choir",
				"count": 4,
				"formation": "SCATTERED",
				"direction": "SOUTH",
				"speed": 65.0,
				"swarm_enabled": false,
			},
		},
		{
			"timestamp": 16.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch2_scribe",
				"position": "NORTH",
				"speed": 55.0,
			},
		},
	]
