## wave_6_1.gd
## 波次 6-1：摇摆初夜 (教学波)
##
## 教学目标：引入爵士主题，让玩家认识 Walking Bass（行走低音）和
## Scat Singer（拟声歌手）敌人。Walking Bass 以稳定的反拍节奏行进，
## Scat Singer 以即兴的不规则路径移动。玩家需要适应摇摆节奏的反拍攻击模式。
##
## 触发时机：章节开始时立即触发
## BPM：140（爵士的摇摆节奏）
## 预计时长：~45 秒
extends "res://scripts/data/wave_data.gd"

func _init() -> void:
	wave_name = "摇摆初夜"
	wave_type = "tutorial"
	chapter_id = "ch6"
	wave_id = "6-1"
	estimated_duration = 45.0
	success_condition = "kill_all"
	
	events = [
		# 设置 BPM 为 140（爵士摇摆节奏）
		{
			"timestamp": 0.0,
			"type": "SET_BPM",
			"params": {"bpm": 140.0},
		},
		# 教学提示：介绍爵士主题
		{
			"timestamp": 0.0,
			"type": "SHOW_HINT",
			"params": {
				"text": "爵士乐的摇摆节奏——反拍才是真正的重音所在",
				"duration": 5.0,
			},
		},
		# 解锁萨克斯音色
		{
			"timestamp": 0.5,
			"type": "UNLOCK",
			"params": {
				"type": "feature",
				"feature": "timbre_saxophone",
				"message": "解锁：萨克斯音色（摇摆节奏攻击）",
			},
		},
		# 第 1 组：2 只 Walking Bass 从南方稳步入场
		{
			"timestamp": 3.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch6_walking_bass",
				"position": "SOUTH",
				"speed": 35.0,
			},
		},
		{
			"timestamp": 5.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch6_walking_bass",
				"position": "NORTH",
				"speed": 35.0,
			},
		},
		# 教学提示：Walking Bass 的特性
		{
			"timestamp": 3.5,
			"type": "SHOW_HINT",
			"params": {
				"text": "行走低音以稳定的反拍节奏前进——在反拍攻击可获得额外伤害",
				"duration": 4.0,
			},
		},
		# 引入 Scat Singer
		{
			"timestamp": 10.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch6_scat_singer",
				"position": "EAST",
				"speed": 100.0,
			},
		},
		{
			"timestamp": 11.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch6_scat_singer",
				"position": "WEST",
				"speed": 100.0,
			},
		},
		{
			"timestamp": 10.5,
			"type": "SHOW_HINT",
			"params": {
				"text": "拟声歌手移动路径即兴多变——预判它们的下一步",
				"duration": 3.0,
			},
		},
		# 混合组：Walking Bass + Scat Singer + 旧章敌人
		{
			"timestamp": 18.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch6_walking_bass",
				"count": 3,
				"formation": "LINE",
				"direction": "SOUTH",
				"speed": 38.0,
				"swarm_enabled": false,
			},
		},
		{
			"timestamp": 20.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch6_scat_singer",
				"count": 3,
				"formation": "SCATTERED",
				"direction": "NORTH",
				"speed": 105.0,
				"swarm_enabled": false,
			},
		},
		{
			"timestamp": 22.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch5_crescendo_surge",
				"count": 2,
				"formation": "LINE",
				"direction": "EAST",
				"speed": 60.0,
				"swarm_enabled": false,
			},
		},
	]
