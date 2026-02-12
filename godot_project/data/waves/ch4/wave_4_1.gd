## wave_4_1.gd
## 波次 4-1：完美形式 (教学波)
##
## 教学目标：引入古典主义和声学主题，让玩家认识 Minuet Dancer（小步舞曲舞者）敌人。
## Minuet Dancer 以优雅的 3/4 拍节奏移动，具有高速闪避能力。
## 玩家需要学会利用力度动态（强弱拍）来应对高机动性敌人。
##
## 触发时机：章节开始时立即触发
## BPM：120（古典主义的优雅节奏，3/4拍华尔兹）
## 预计时长：~40 秒
extends "res://scripts/data/wave_data.gd"

func _init() -> void:
	wave_name = "完美形式"
	wave_type = "tutorial"
	chapter_id = "ch4"
	wave_id = "4-1"
	estimated_duration = 40.0
	success_condition = "kill_all"
	
	events = [
		# 设置 BPM 为 120（古典主义优雅节奏）
		{
			"timestamp": 0.0,
			"type": "SET_BPM",
			"params": {"bpm": 120.0},
		},
		# 教学提示：介绍古典主义主题
		{
			"timestamp": 0.0,
			"type": "SHOW_HINT",
			"params": {
				"text": "莫扎特的完美形式——优雅的对称与精确的力度控制",
				"duration": 5.0,
			},
		},
		# 解锁钢琴音色
		{
			"timestamp": 0.5,
			"type": "UNLOCK",
			"params": {
				"type": "feature",
				"feature": "timbre_fortepiano",
				"message": "解锁：钢琴音色（力度动态控制）",
			},
		},
		# 第 1 组：2 只 Minuet Dancer 从对称位置入场
		{
			"timestamp": 3.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch4_minuet_dancer",
				"position": "NORTH",
				"speed": 90.0,
			},
		},
		{
			"timestamp": 4.5,
			"type": "SPAWN",
			"params": {
				"enemy": "ch4_minuet_dancer",
				"position": "SOUTH",
				"speed": 90.0,
			},
		},
		# 教学提示：Minuet Dancer 的特性
		{
			"timestamp": 3.5,
			"type": "SHOW_HINT",
			"params": {
				"text": "小步舞曲舞者移动迅速——在强拍时攻击可造成更高伤害",
				"duration": 4.0,
			},
		},
		# 第 2 组：加入旧章敌人形成对比
		{
			"timestamp": 10.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch3_counterpoint_crawler",
				"position": "EAST",
				"speed": 45.0,
			},
		},
		{
			"timestamp": 11.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch4_minuet_dancer",
				"position": "WEST",
				"speed": 95.0,
			},
		},
		{
			"timestamp": 12.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch4_minuet_dancer",
				"position": "EAST",
				"speed": 95.0,
			},
		},
		# 第 3 组：华尔兹阵型（3 只 Dancer 以三角形入场）
		{
			"timestamp": 18.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch4_minuet_dancer",
				"count": 3,
				"formation": "CIRCLE",
				"direction": "NORTH",
				"speed": 100.0,
				"swarm_enabled": false,
			},
		},
		# Pulse 作为节奏锚点
		{
			"timestamp": 20.0,
			"type": "SPAWN",
			"params": {
				"enemy": "pulse",
				"position": "SOUTH",
				"speed": 50.0,
			},
		},
	]
