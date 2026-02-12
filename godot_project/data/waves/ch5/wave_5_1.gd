## wave_5_1.gd
## 波次 5-1：命运叩门 (教学波)
##
## 教学目标：引入浪漫主义主题，让玩家认识 Fate Knocker（命运叩门者）和
## Crescendo Surge（渐强浪潮）敌人。Fate Knocker 以强力单次攻击为主，
## Crescendo Surge 的攻击力随时间递增。玩家需要学会情感爆发式攻击节奏。
##
## 触发时机：章节开始时立即触发
## BPM：130（浪漫主义的激情节奏）
## 预计时长：~45 秒
extends "res://scripts/data/wave_data.gd"

func _init() -> void:
	wave_name = "命运叩门"
	wave_type = "tutorial"
	chapter_id = "ch5"
	wave_id = "5-1"
	estimated_duration = 45.0
	success_condition = "kill_all"
	
	events = [
		# 设置 BPM 为 130（浪漫主义激情节奏）
		{
			"timestamp": 0.0,
			"type": "SET_BPM",
			"params": {"bpm": 130.0},
		},
		# 教学提示：介绍浪漫主义主题
		{
			"timestamp": 0.0,
			"type": "SHOW_HINT",
			"params": {
				"text": "贝多芬打破了古典的框架——以个人意志和情感力量重塑音乐",
				"duration": 5.0,
			},
		},
		# 解锁管弦全奏音色
		{
			"timestamp": 0.5,
			"type": "UNLOCK",
			"params": {
				"type": "feature",
				"feature": "timbre_tutti",
				"message": "解锁：管弦全奏音色（情感爆发式攻击）",
			},
		},
		# 命运动机：4 只 Fate Knocker 模拟"命运叩门"节奏（短短短长）
		{
			"timestamp": 3.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch5_fate_knocker",
				"position": "NORTH",
				"speed": 40.0,
			},
		},
		{
			"timestamp": 3.5,
			"type": "SPAWN",
			"params": {
				"enemy": "ch5_fate_knocker",
				"position": "EAST",
				"speed": 40.0,
			},
		},
		{
			"timestamp": 4.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch5_fate_knocker",
				"position": "SOUTH",
				"speed": 40.0,
			},
		},
		# 教学提示：Fate Knocker 的特性
		{
			"timestamp": 3.5,
			"type": "SHOW_HINT",
			"params": {
				"text": "命运叩门者——高血量但移动缓慢，需要持续输出",
				"duration": 4.0,
			},
		},
		# 引入 Crescendo Surge
		{
			"timestamp": 12.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch5_crescendo_surge",
				"position": "WEST",
				"speed": 60.0,
			},
		},
		{
			"timestamp": 13.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch5_crescendo_surge",
				"position": "EAST",
				"speed": 60.0,
			},
		},
		{
			"timestamp": 12.5,
			"type": "SHOW_HINT",
			"params": {
				"text": "渐强浪潮的攻击力随时间递增——尽快击破！",
				"duration": 3.0,
			},
		},
		# 混合组：Fate Knocker + Crescendo Surge + 旧章敌人
		{
			"timestamp": 20.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch5_fate_knocker",
				"position": "NORTH",
				"speed": 42.0,
			},
		},
		{
			"timestamp": 21.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch5_crescendo_surge",
				"count": 3,
				"formation": "LINE",
				"direction": "SOUTH",
				"speed": 65.0,
				"swarm_enabled": false,
			},
		},
		{
			"timestamp": 23.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch4_minuet_dancer",
				"count": 3,
				"formation": "SCATTERED",
				"direction": "EAST",
				"speed": 90.0,
				"swarm_enabled": false,
			},
		},
	]
