## wave_1_4.gd
## 波次 1-4：休止符的力量 (教学波)
##
## 教学目标：让玩家学会在序列器中使用休止符来增强攻击效率。
## 2 只 Wall（高 HP + 护盾），不使用休止符时击破困难。
## 使用"G - 休止 - G - 休止"序列后效率显著提升。
##
## 触发时机：第 7 个随机波次结束后
## BPM：110
## 预计时长：~50 秒
extends "res://scripts/data/wave_data.gd"

func _init() -> void:
	wave_name = "休止符的力量"
	wave_type = "tutorial"
	chapter_id = "ch1"
	wave_id = "1-4"
	estimated_duration = 50.0
	success_condition = "kill_all"
	
	events = [
		# 解锁休止符功能
		{
			"timestamp": 0.0,
			"type": "UNLOCK",
			"params": {
				"type": "feature",
				"feature": "REST_NOTE",
				"message": "解锁：休止符",
			},
		},
		# 教学提示
		{
			"timestamp": 0.5,
			"type": "SHOW_HINT",
			"params": {
				"text": "在序列器中编入休止符可增强其他音符",
				"duration": 5.0,
				"highlight_ui": "REST_BUTTON",
			},
		},
		# 第 1 只 Wall：正前方
		{
			"timestamp": 3.0,
			"type": "SPAWN",
			"params": {
				"enemy": "wall",
				"position": "Vector2(0, -400)",
				"speed": 25.0,
				"hp": 200.0,
				"shield": 50.0,
			},
		},
		# 条件提示：如果 15 秒内未使用休止符，给出提醒
		{
			"timestamp": 18.0,
			"type": "CONDITIONAL_HINT",
			"params": {
				"condition": "NO_REST_USED_FOR_15s",
				"text": "尝试在序列器中使用休止符",
				"highlight_ui": "REST_BUTTON",
			},
		},
		# 第 2 只 Wall：右前方
		{
			"timestamp": 25.0,
			"type": "SPAWN",
			"params": {
				"enemy": "wall",
				"position": "Vector2(200, -400)",
				"speed": 25.0,
				"hp": 200.0,
				"shield": 50.0,
			},
		},
	]
