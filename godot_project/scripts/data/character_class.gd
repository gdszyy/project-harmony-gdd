## character_class.gd
## 角色/职业系统数据定义 (Issue #28)
##
## 基于 GDD §8.1 和 MetaProgressionSystem_Documentation.md 设计：
##   - 不同"调性"或"音阶"作为不同角色/职业
##   - 每个角色拥有独特的初始序列器配置和被动能力
##   - 与 ModeSystem (mode_system.gd) 深度集成
##
## 角色/职业列表：
##   1. 伊奥尼亚 (Ionian) — 均衡者：全套白键，和谐度高
##   2. 多利亚 (Dorian) — 民谣诗人：小调色彩，自带回响
##   3. 五声音阶 (Pentatonic) — 东方行者：仅 CDEGA，单发伤害 +20%
##   4. 布鲁斯 (Blues) — 爵士乐手：不和谐值转暴击率
extends RefCounted

# ============================================================
# 角色/职业完整定义
# ============================================================

const CLASS_DEFINITIONS: Dictionary = {
	"ionian": {
		"id": "ionian",
		"name": "伊奥尼亚",
		"name_en": "Ionian",
		"title": "均衡者",
		"title_en": "The Balanced",
		"description": "C大调音阶英雄。基础法术和谐悦耳，成长曲线平滑。全套白键可用，适合新手入门。",
		"lore": "在和谐之殿的正中央，伊奥尼亚的旋律如水晶般纯净。她代表着音乐最原始的秩序——每一个音符都恰到好处，每一个和弦都完美无瑕。",
		
		# 调式配置
		"scale_notes": [0, 2, 4, 5, 7, 9, 11],  # C D E F G A B (MIDI pitch class)
		"available_white_keys": ["C", "D", "E", "F", "G", "A", "B"],
		"locked_keys": [],
		
		# 基础属性修正
		"stats": {
			"hp_mult": 1.0,
			"damage_mult": 1.0,
			"speed_mult": 1.0,
			"spell_cooldown_mult": 1.0,
			"xp_gain_mult": 1.0,
		},
		
		# 被动能力
		"passive": {
			"id": "harmony_bonus",
			"name": "和谐共振",
			"name_en": "Harmonic Resonance",
			"description": "和弦法术的和谐度加成 +10%，不和谐度积累速度 -10%",
			"effects": {
				"harmony_bonus": 0.10,
				"dissonance_reduction": 0.10,
			},
		},
		
		# 初始序列器配置
		"initial_sequencer": {
			"auto_notes": [0, 4, 7],  # C E G (C大三和弦)
			"auto_interval": 0.5,     # 每0.5拍自动发射
			"auto_damage_mult": 1.0,
		},
		
		# 视觉配置
		"visual": {
			"primary_color": Color(0.9, 0.9, 1.0),    # 纯白偏蓝
			"secondary_color": Color(0.6, 0.7, 1.0),   # 淡蓝
			"particle_color": Color(0.8, 0.85, 1.0),
			"aura_shader_param": "ionian_glow",
		},
		
		# 解锁条件
		"unlock": {
			"cost": 0,
			"requirement": "default",
			"requirement_desc": "默认解锁",
		},
	},
	
	"dorian": {
		"id": "dorian",
		"name": "多利亚",
		"name_en": "Dorian",
		"title": "民谣诗人",
		"title_en": "The Folk Bard",
		"description": "侧重小调色彩的英雄。初始自带回响修饰符效果，控场能力出众，但单调值累积速度略快。",
		"lore": "多利亚的歌声带着一丝忧郁的美感，如同暮色中的民谣。每一个音符都会在空气中留下回响，编织出层叠的声音之网。",
		
		"scale_notes": [0, 2, 3, 5, 7, 9, 10],  # C D Eb F G A Bb
		"available_white_keys": ["C", "D", "E", "F", "G", "A", "B"],
		"locked_keys": [],
		
		"stats": {
			"hp_mult": 1.0,
			"damage_mult": 1.0,
			"speed_mult": 1.05,   # 略快
			"spell_cooldown_mult": 0.95,  # 施法略快
			"xp_gain_mult": 1.0,
		},
		
		"passive": {
			"id": "auto_echo",
			"name": "回响之歌",
			"name_en": "Song of Echoes",
			"description": "每3次施法自动附加一次回响修饰符效果",
			"effects": {
				"echo_interval": 3,
				"echo_modifier": true,
			},
		},
		
		"initial_sequencer": {
			"auto_notes": [0, 3, 7],  # C Eb G (C小三和弦)
			"auto_interval": 0.5,
			"auto_damage_mult": 0.9,
		},
		
		"visual": {
			"primary_color": Color(0.6, 0.4, 0.8),    # 紫色
			"secondary_color": Color(0.4, 0.3, 0.7),   # 深紫
			"particle_color": Color(0.7, 0.5, 0.9),
			"aura_shader_param": "dorian_echo",
		},
		
		"unlock": {
			"cost": 80,
			"requirement": "complete_chapter_2",
			"requirement_desc": "通关第二章后可解锁",
		},
	},
	
	"pentatonic": {
		"id": "pentatonic",
		"name": "五声音阶",
		"name_en": "Pentatonic",
		"title": "东方行者",
		"title_en": "The Eastern Wanderer",
		"description": "仅使用 CDEGA 五个音符。操作简单但功能性受限，单发伤害极高，极难产生不和谐值。",
		"lore": "五声音阶行者遵循着最古老的音乐法则——少即是多。五个音符足以表达天地间的一切和谐，每一击都蕴含着山河的力量。",
		
		"scale_notes": [0, 2, 4, 7, 9],  # C D E G A
		"available_white_keys": ["C", "D", "E", "G", "A"],
		"locked_keys": ["F", "B"],
		
		"stats": {
			"hp_mult": 1.1,       # 略厚血
			"damage_mult": 1.2,   # 单发伤害 +20%
			"speed_mult": 0.95,   # 略慢
			"spell_cooldown_mult": 1.1,  # 施法略慢
			"xp_gain_mult": 1.1,  # 经验略多
		},
		
		"passive": {
			"id": "harmony_shield",
			"name": "五行护盾",
			"name_en": "Pentatonic Shield",
			"description": "不和谐度积累减半，每30秒自动清除一次不和谐度",
			"effects": {
				"dissonance_multiplier": 0.5,
				"auto_cleanse_interval": 30.0,
			},
		},
		
		"initial_sequencer": {
			"auto_notes": [0, 4, 7, 9],  # C E G A
			"auto_interval": 0.6,
			"auto_damage_mult": 1.2,
		},
		
		"visual": {
			"primary_color": Color(1.0, 0.85, 0.4),    # 金色
			"secondary_color": Color(0.9, 0.6, 0.2),    # 琥珀
			"particle_color": Color(1.0, 0.9, 0.5),
			"aura_shader_param": "pentatonic_jade",
		},
		
		"unlock": {
			"cost": 60,
			"requirement": "complete_chapter_1",
			"requirement_desc": "通关第一章后可解锁",
		},
	},
	
	"blues": {
		"id": "blues",
		"name": "布鲁斯",
		"name_en": "Blues",
		"title": "爵士乐手",
		"title_en": "The Jazz Virtuoso",
		"description": "天生拥有降音，不和谐值可转化为暴击率。极高的爆发潜力，但生存压力大，对疲劳管理技巧要求极高。",
		"lore": "布鲁斯乐手行走在和谐与混沌的边缘。他的每一个音符都带着叛逆的蓝色火焰——不和谐不是弱点，而是力量的源泉。",
		
		"scale_notes": [0, 3, 5, 6, 7, 10],  # C Eb F Gb G Bb
		"available_white_keys": ["C", "D", "E", "F", "G", "A", "B"],
		"locked_keys": [],
		
		"stats": {
			"hp_mult": 0.85,      # 较脆
			"damage_mult": 1.0,
			"speed_mult": 1.1,    # 较快
			"spell_cooldown_mult": 0.85,  # 施法更快
			"xp_gain_mult": 0.9,  # 经验略少
		},
		
		"passive": {
			"id": "dissonance_crit",
			"name": "蓝色火焰",
			"name_en": "Blue Flame",
			"description": "不和谐值转化为暴击率（每点 +3%，上限30%）。暴击伤害 x2.0",
			"effects": {
				"crit_per_dissonance": 0.03,
				"crit_cap": 0.30,
				"crit_damage_mult": 2.0,
			},
		},
		
		"initial_sequencer": {
			"auto_notes": [0, 3, 6, 10],  # C Eb Gb Bb (减七和弦)
			"auto_interval": 0.4,
			"auto_damage_mult": 0.8,
		},
		
		"visual": {
			"primary_color": Color(0.2, 0.4, 0.9),    # 蓝色
			"secondary_color": Color(0.1, 0.2, 0.6),   # 深蓝
			"particle_color": Color(0.3, 0.5, 1.0),
			"aura_shader_param": "blues_flame",
		},
		
		"unlock": {
			"cost": 100,
			"requirement": "complete_chapter_4",
			"requirement_desc": "通关第四章后可解锁",
		},
	},
}

# ============================================================
# 工具方法
# ============================================================

## 获取所有角色/职业 ID 列表
static func get_all_class_ids() -> Array[String]:
	var ids: Array[String] = []
	for key in CLASS_DEFINITIONS:
		ids.append(key)
	return ids

## 获取指定角色/职业的完整定义
static func get_class_definition(class_id: String) -> Dictionary:
	return CLASS_DEFINITIONS.get(class_id, CLASS_DEFINITIONS["ionian"])

## 获取指定角色/职业的被动能力
static func get_passive(class_id: String) -> Dictionary:
	var def: Dictionary = CLASS_DEFINITIONS.get(class_id, {})
	return def.get("passive", {})

## 获取指定角色/职业的属性修正
static func get_stats(class_id: String) -> Dictionary:
	var def: Dictionary = CLASS_DEFINITIONS.get(class_id, {})
	return def.get("stats", {})

## 获取指定角色/职业的初始序列器配置
static func get_initial_sequencer(class_id: String) -> Dictionary:
	var def: Dictionary = CLASS_DEFINITIONS.get(class_id, {})
	return def.get("initial_sequencer", {})

## 获取指定角色/职业的视觉配置
static func get_visual_config(class_id: String) -> Dictionary:
	var def: Dictionary = CLASS_DEFINITIONS.get(class_id, {})
	return def.get("visual", {})

## 获取指定角色/职业的解锁条件
static func get_unlock_info(class_id: String) -> Dictionary:
	var def: Dictionary = CLASS_DEFINITIONS.get(class_id, {})
	return def.get("unlock", {})
