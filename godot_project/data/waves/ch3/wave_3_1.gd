## wave_3_1.gd
## 波次 3-1：复调初探 (教学波)
##
## 教学目标：引入巴洛克对位法主题，让玩家认识 Counterpoint Crawler（对位爬行者）敌人。
## Counterpoint Crawler 以多声部交织的方式移动，路径相互呼应。
## 玩家需要学会追踪多条独立运动轨迹并逐一击破。
##
## 触发时机：章节开始时立即触发
## BPM：110（巴洛克的精密节奏）
## 预计时长：~40 秒
extends "res://scripts/data/wave_data.gd"

func _init() -> void:
	wave_name = "复调初探"
	wave_type = "tutorial"
	chapter_id = "ch3"
	wave_id = "3-1"
	estimated_duration = 40.0
	success_condition = "kill_all"
	
	events = [
		# 设置 BPM 为 110（巴洛克精密节奏）
		{
			"timestamp": 0.0,
			"type": "SET_BPM",
			"params": {"bpm": 110.0},
		},
		# 教学提示：介绍对位法概念
		{
			"timestamp": 0.0,
			"type": "SHOW_HINT",
			"params": {
				"text": "巴赫的对位法——每个声部都是独立的个体，却又和谐共存",
				"duration": 5.0,
			},
		},
		# 解锁羽管键琴音色
		{
			"timestamp": 0.5,
			"type": "UNLOCK",
			"params": {
				"type": "feature",
				"feature": "timbre_harpsichord",
				"message": "解锁：羽管键琴音色（对位交织攻击）",
			},
		},
		# 第 1 组：2 只 Counterpoint Crawler 从对角线入场（模拟对位）
		{
			"timestamp": 3.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch3_counterpoint_crawler",
				"position": "NORTH",
				"speed": 45.0,
			},
		},
		{
			"timestamp": 4.5,
			"type": "SPAWN",
			"params": {
				"enemy": "ch3_counterpoint_crawler",
				"position": "SOUTH",
				"speed": 45.0,
			},
		},
		# 教学提示：对位爬行者的特性
		{
			"timestamp": 3.5,
			"type": "SHOW_HINT",
			"params": {
				"text": "对位爬行者的路径相互呼应——注意它们的交织移动模式",
				"duration": 4.0,
			},
		},
		# 第 2 组：加入 Pulse 敌人形成多声部
		{
			"timestamp": 10.0,
			"type": "SPAWN",
			"params": {
				"enemy": "pulse",
				"position": "EAST",
				"speed": 50.0,
			},
		},
		{
			"timestamp": 11.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch3_counterpoint_crawler",
				"position": "WEST",
				"speed": 50.0,
			},
		},
		# 教学提示：多声部应对
		{
			"timestamp": 10.5,
			"type": "SHOW_HINT",
			"params": {
				"text": "多个声部同时出现时，优先处理最近的威胁",
				"duration": 3.0,
			},
		},
		# 第 3 组：三声部对位（3 只 Crawler 从三个方向）
		{
			"timestamp": 18.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch3_counterpoint_crawler",
				"position": "NORTH",
				"speed": 50.0,
			},
		},
		{
			"timestamp": 19.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch3_counterpoint_crawler",
				"position": "EAST",
				"speed": 50.0,
			},
		},
		{
			"timestamp": 20.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch3_counterpoint_crawler",
				"position": "WEST",
				"speed": 50.0,
			},
		},
		# 旧章敌人作为低声部填充
		{
			"timestamp": 22.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch2_choir",
				"count": 3,
				"formation": "LINE",
				"direction": "SOUTH",
				"speed": 60.0,
				"swarm_enabled": false,
			},
		},
	]
