## wave_7_1.gd
## 波次 7-1：数字虚空初探 (教学波)
##
## 教学目标：引入现代/电子音乐主题，让玩家认识 Bitcrusher Worm（降采样蠕虫）
## 和 Glitch Phantom（故障幻影）敌人。Bitcrusher Worm 会降低周围音频质量，
## Glitch Phantom 具有瞬移能力。玩家需要适应波形战争的混乱环境。
##
## 触发时机：章节开始时立即触发
## BPM：150（现代电子音乐的快速节奏）
## 预计时长：~45 秒
extends "res://scripts/data/wave_data.gd"

func _init() -> void:
	wave_name = "数字虚空初探"
	wave_type = "tutorial"
	chapter_id = "ch7"
	wave_id = "7-1"
	estimated_duration = 45.0
	success_condition = "kill_all"
	
	events = [
		# 设置 BPM 为 150（现代电子快速节奏）
		{
			"timestamp": 0.0,
			"type": "SET_BPM",
			"params": {"bpm": 150.0},
		},
		# 教学提示：介绍现代/电子主题
		{
			"timestamp": 0.0,
			"type": "SHOW_HINT",
			"params": {
				"text": "音乐被彻底解构为频率与波形——一切皆可为音乐，包括噪音本身",
				"duration": 5.0,
			},
		},
		# 解锁合成主脑音色
		{
			"timestamp": 0.5,
			"type": "UNLOCK",
			"params": {
				"type": "feature",
				"feature": "timbre_synthesizer",
				"message": "解锁：合成主脑音色（波形变换攻击）",
			},
		},
		# 第 1 组：2 只 Bitcrusher Worm 从对侧入场
		{
			"timestamp": 3.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch7_bitcrusher_worm",
				"position": "NORTH",
				"speed": 50.0,
			},
		},
		{
			"timestamp": 5.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch7_bitcrusher_worm",
				"position": "SOUTH",
				"speed": 50.0,
			},
		},
		# 教学提示：Bitcrusher Worm 的特性
		{
			"timestamp": 3.5,
			"type": "SHOW_HINT",
			"params": {
				"text": "降采样蠕虫会扭曲周围的音频空间——保持距离攻击",
				"duration": 4.0,
			},
		},
		# 引入 Glitch Phantom
		{
			"timestamp": 10.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch7_glitch_phantom",
				"position": "EAST",
				"speed": 110.0,
			},
		},
		{
			"timestamp": 11.0,
			"type": "SPAWN",
			"params": {
				"enemy": "ch7_glitch_phantom",
				"position": "WEST",
				"speed": 110.0,
			},
		},
		{
			"timestamp": 10.5,
			"type": "SHOW_HINT",
			"params": {
				"text": "故障幻影会瞬移——预判它们的下一个位置",
				"duration": 3.0,
			},
		},
		# 引入 Silence 敌人（寂静）
		{
			"timestamp": 16.0,
			"type": "SPAWN",
			"params": {
				"enemy": "silence",
				"position": "NORTH",
				"speed": 60.0,
			},
		},
		{
			"timestamp": 16.5,
			"type": "SHOW_HINT",
			"params": {
				"text": "寂静敌人会吸收声音——快速击破以恢复音频环境",
				"duration": 3.0,
			},
		},
		# 混合组：Bitcrusher + Glitch + Static
		{
			"timestamp": 22.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch7_bitcrusher_worm",
				"count": 3,
				"formation": "LINE",
				"direction": "SOUTH",
				"speed": 55.0,
				"swarm_enabled": false,
			},
		},
		{
			"timestamp": 24.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "ch7_glitch_phantom",
				"count": 3,
				"formation": "SCATTERED",
				"direction": "NORTH",
				"speed": 115.0,
				"swarm_enabled": false,
			},
		},
		{
			"timestamp": 26.0,
			"type": "SPAWN_SWARM",
			"params": {
				"enemy": "static",
				"count": 4,
				"formation": "CIRCLE",
				"direction": "EAST",
				"speed": 90.0,
				"swarm_enabled": false,
			},
		},
	]
