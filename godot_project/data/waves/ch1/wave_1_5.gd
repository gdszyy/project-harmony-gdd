## wave_1_5.gd
## 波次 1-5：附点节奏 (练习波)
##
## 教学目标：让玩家学会使用附点节奏的击退效果来推开敌人。
## 1 只 Wall 被 6 只 Static 护卫环绕。
## 附点节奏的击退可以推开 Static 护卫，为弹体打开通路。
##
## 触发时机：第 8 个随机波次结束后
## BPM：110
## 预计时长：~45 秒
extends "res://scripts/data/wave_data.gd"

func _init() -> void:
	wave_name = "附点节奏"
	wave_type = "practice"
	chapter_id = "ch1"
	wave_id = "1-5"
	estimated_duration = 45.0
	success_condition = "kill_all"
	
	events = [
		# 解锁附点节奏
		{
			"timestamp": 0.0,
			"type": "UNLOCK",
			"params": {
				"type": "rhythm",
				"rhythm": "DOTTED",
				"message": "解锁：附点节奏（伤害+1，击退+1）",
			},
		},
		# 教学提示
		{
			"timestamp": 0.5,
			"type": "SHOW_HINT",
			"params": {
				"text": "附点节奏的击退效果可以推开敌人",
				"duration": 4.0,
			},
		},
		# Wall 核心：正前方
		{
			"timestamp": 3.0,
			"type": "SPAWN",
			"params": {
				"enemy": "wall",
				"position": "Vector2(0, -400)",
				"speed": 30.0,
				"hp": 200.0,
				"shield": 50.0,
			},
		},
		# 6 只 Static 护卫环绕 Wall
		{
			"timestamp": 3.5,
			"type": "SPAWN_ESCORT",
			"params": {
				"enemy": "static",
				"count": 6,
				"orbit_target": "LAST_SPAWNED",
				"orbit_radius": 80.0,
				"speed": 100.0,
			},
		},
	]
