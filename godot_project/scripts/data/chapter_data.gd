## chapter_data.gd
## 章节数据配置 (Autoload / 静态数据)
## 定义每个章节的完整敌人生态体系：
##   - 章节基础信息（名称、BPM、时代主题）
##   - 普通敌人池（含章节特色敌人）
##   - 精英/小Boss池
##   - 最终Boss
##   - 波次模板（每章的波次编排）
##   - 章节过渡条件
##
## 生存者游戏流程：
##   每章 = 多个波次阶段 → 精英出现 → 更多波次 → 最终Boss
##   章节间有短暂过渡（主题切换 + 奖励结算）
class_name ChapterData
extends Node

# ============================================================
# 章节枚举
# ============================================================
enum Chapter {
	CH1_PYTHAGORAS,   ## 古希腊 · 律动尊者
	CH2_GUIDO,        ## 中世纪 · 圣咏宗师
	CH3_BACH,         ## 巴洛克 · 大构建师
	CH4_MOZART,       ## 古典主义 · 古典完形
	CH5_BEETHOVEN,    ## 浪漫主义 · 狂想者
	CH6_JAZZ,         ## 爵士 · 切分行者
	CH7_NOISE,        ## 现代 · 合成主脑
}

# ============================================================
# 章节配置数据
# ============================================================
const CHAPTERS: Dictionary = {
	Chapter.CH1_PYTHAGORAS: {
		"name": "第一章：数之和谐",
		"subtitle": "The Harmony of Numbers",
		"era": "古希腊",
		"bpm": 100,
		"beats_per_measure": 4,
		"color_theme": Color(0.3, 0.5, 0.8),
		"description": "毕达哥拉斯发现了音程与数学比例的关系，一切从数字开始。",
		
		# 章节持续时间（秒），达到后触发Boss
		"duration": 180.0,
		# Boss触发前的最小波次数
		"min_waves_before_boss": 8,
		
		# ---- 普通敌人池 ----
		"enemy_pool": {
			"static":            { "weight": 3.0, "min_wave": 1 },
			"screech":           { "weight": 1.5, "min_wave": 2 },
			"ch1_grid_static":   { "weight": 2.0, "min_wave": 3 },
			"ch1_metronome_pulse": { "weight": 2.0, "min_wave": 4 },
		},
		
		# ---- 精英/小Boss池 ----
		"elite_pool": {
			"ch1_harmony_guardian":   { "weight": 2.0, "min_wave": 5 },
			"ch1_frequency_sentinel": { "weight": 2.0, "min_wave": 6 },
		},
		
		# ---- 最终Boss ----
		"boss": {
			"key": "boss_pythagoras",
			"script_path": "res://scripts/entities/enemies/bosses/boss_pythagoras.gd",
		},
		
		# ---- 剧本波次调度表 ----
		"scripted_waves": [
			{
				"trigger": "chapter_start",
				"wave_data": "res://data/waves/ch1/wave_1_1.gd",
			},
			{
				"trigger": "after_random_wave",
				"trigger_wave": 3,
				"wave_data": "res://data/waves/ch1/wave_1_2.gd",
			},
			{
				"trigger": "after_random_wave",
				"trigger_wave": 5,
				"wave_data": "res://data/waves/ch1/wave_1_3.gd",
			},
			{
				"trigger": "after_random_wave",
				"trigger_wave": 7,
				"wave_data": "res://data/waves/ch1/wave_1_4.gd",
			},
			{
				"trigger": "after_random_wave",
				"trigger_wave": 8,
				"wave_data": "res://data/waves/ch1/wave_1_5.gd",
			},
			{
				"trigger": "after_random_wave",
				"trigger_wave": 9,
				"wave_data": "res://data/waves/ch1/wave_1_6.gd",
			},
		],
		
		# ---- 波次模板 ----
		"wave_templates": [
			{
				"waves": [1, 3],
				"type": "normal",
				"enemy_count_base": 6,
				"enemy_types": ["static"],
				"spawn_interval": 2.0,
			},
			{
				"waves": [4, 5],
				"type": "chapter_intro",
				"enemy_count_base": 8,
				"enemy_types": ["static", "ch1_grid_static", "screech"],
				"spawn_interval": 1.8,
			},
			{
				"waves": [6, 6],
				"type": "elite",
				"enemy_count_base": 4,
				"enemy_types": ["ch1_grid_static", "ch1_metronome_pulse"],
				"elite_type": "ch1_harmony_guardian",
				"spawn_interval": 1.5,
			},
			{
				"waves": [7, 8],
				"type": "swarm",
				"enemy_count_base": 15,
				"enemy_types": ["static", "ch1_grid_static", "ch1_metronome_pulse", "screech"],
				"spawn_interval": 1.2,
			},
			{
				"waves": [9, 9],
				"type": "elite",
				"enemy_count_base": 6,
				"enemy_types": ["ch1_grid_static", "ch1_metronome_pulse"],
				"elite_type": "ch1_frequency_sentinel",
				"spawn_interval": 1.5,
			},
			{
				"waves": [10, 10],
				"type": "pre_boss",
				"enemy_count_base": 12,
				"enemy_types": ["ch1_grid_static", "ch1_metronome_pulse", "screech"],
				"spawn_interval": 1.0,
			},
		],
		
		"completion_rewards": {
			"resonance_fragments": 30,
			"xp_bonus": 100,
			"unlock": "ch2_access",
		},
	},
	
	Chapter.CH2_GUIDO: {
		"name": "第二章：记谱之光",
		"subtitle": "Light of Notation",
		"era": "中世纪",
		"bpm": 90,
		"beats_per_measure": 4,
		"color_theme": Color(0.8, 0.65, 0.3),
		"description": "圭多发明了四线谱，将无形的声音固定为有形的符号。",
		
		"duration": 200.0,
		"min_waves_before_boss": 9,
		
		"enemy_pool": {
			"static":            { "weight": 2.0, "min_wave": 1 },
			"ch1_grid_static":   { "weight": 1.5, "min_wave": 1 },
			"ch2_choir":         { "weight": 3.0, "min_wave": 2 },
			"ch2_scribe":        { "weight": 2.5, "min_wave": 3 },
			"screech":           { "weight": 1.0, "min_wave": 2 },
		},
		
		"elite_pool": {
			"ch2_cantor_commander": { "weight": 3.0, "min_wave": 5 },
			"ch1_harmony_guardian": { "weight": 1.0, "min_wave": 7 },
		},
		
		"boss": {
			"key": "boss_guido",
			"script_path": "res://scripts/entities/enemies/bosses/boss_guido.gd",
		},
		
		"wave_templates": [
			{
				"waves": [1, 3],
				"type": "normal",
				"enemy_count_base": 8,
				"enemy_types": ["static", "ch1_grid_static", "screech"],
				"spawn_interval": 2.0,
			},
			{
				"waves": [4, 5],
				"type": "chapter_intro",
				"enemy_count_base": 10,
				"enemy_types": ["ch2_choir", "ch2_scribe", "static"],
				"spawn_interval": 1.8,
			},
			{
				"waves": [6, 6],
				"type": "elite",
				"enemy_count_base": 5,
				"enemy_types": ["ch2_choir", "ch2_scribe"],
				"elite_type": "ch2_cantor_commander",
				"spawn_interval": 1.5,
			},
			{
				"waves": [7, 9],
				"type": "swarm",
				"enemy_count_base": 18,
				"enemy_types": ["ch2_choir", "ch2_scribe", "static", "screech"],
				"spawn_interval": 1.2,
			},
			{
				"waves": [10, 10],
				"type": "elite",
				"enemy_count_base": 8,
				"enemy_types": ["ch2_choir", "ch2_scribe"],
				"elite_type": "ch2_cantor_commander",
				"spawn_interval": 1.3,
			},
			{
				"waves": [11, 11],
				"type": "pre_boss",
				"enemy_count_base": 14,
				"enemy_types": ["ch2_choir", "ch2_scribe", "ch1_grid_static"],
				"spawn_interval": 1.0,
			},
		],
		
		"completion_rewards": {
			"resonance_fragments": 40,
			"xp_bonus": 150,
			"unlock": "ch3_access",
		},
	},
	
	Chapter.CH3_BACH: {
		"name": "第三章：复调迷宫",
		"subtitle": "The Polyphonic Labyrinth",
		"era": "巴洛克",
		"bpm": 110,
		"beats_per_measure": 4,
		"color_theme": Color(0.6, 0.4, 0.15),
		"description": "巴赫将对位法推向极致，每个声部都是独立而又和谐的个体。",
		
		"duration": 220.0,
		"min_waves_before_boss": 10,
		
		"enemy_pool": {
			"static":                    { "weight": 1.5, "min_wave": 1 },
			"ch1_grid_static":           { "weight": 1.0, "min_wave": 1 },
			"ch2_choir":                 { "weight": 1.5, "min_wave": 2 },
			"ch3_counterpoint_crawler":  { "weight": 3.0, "min_wave": 2 },
			"pulse":                     { "weight": 2.0, "min_wave": 3 },
			"screech":                   { "weight": 1.0, "min_wave": 1 },
		},
		
		"elite_pool": {
			"ch3_fugue_weaver":        { "weight": 3.0, "min_wave": 5 },
			"ch2_cantor_commander":    { "weight": 1.5, "min_wave": 7 },
		},
		
		"boss": {
			"key": "boss_bach",
			"script_path": "res://scripts/entities/enemies/bosses/boss_bach.gd",
		},
		
		"wave_templates": [
			{
				"waves": [1, 3],
				"type": "normal",
				"enemy_count_base": 10,
				"enemy_types": ["static", "ch1_grid_static", "ch2_choir", "screech"],
				"spawn_interval": 1.8,
			},
			{
				"waves": [4, 5],
				"type": "chapter_intro",
				"enemy_count_base": 12,
				"enemy_types": ["ch3_counterpoint_crawler", "pulse", "ch2_choir"],
				"spawn_interval": 1.6,
			},
			{
				"waves": [6, 6],
				"type": "elite",
				"enemy_count_base": 6,
				"enemy_types": ["ch3_counterpoint_crawler", "pulse"],
				"elite_type": "ch3_fugue_weaver",
				"spawn_interval": 1.4,
			},
			{
				"waves": [7, 9],
				"type": "swarm",
				"enemy_count_base": 20,
				"enemy_types": ["ch3_counterpoint_crawler", "pulse", "ch2_choir", "static"],
				"spawn_interval": 1.1,
			},
			{
				"waves": [10, 10],
				"type": "elite",
				"enemy_count_base": 8,
				"enemy_types": ["ch3_counterpoint_crawler", "pulse"],
				"elite_type": "ch3_fugue_weaver",
				"spawn_interval": 1.2,
			},
			{
				"waves": [11, 12],
				"type": "pre_boss",
				"enemy_count_base": 16,
				"enemy_types": ["ch3_counterpoint_crawler", "pulse", "ch2_choir"],
				"spawn_interval": 0.9,
			},
		],
		
		"completion_rewards": {
			"resonance_fragments": 50,
			"xp_bonus": 200,
			"unlock": "ch4_access",
		},
	},
	
	Chapter.CH4_MOZART: {
		"name": "第四章：完美形式",
		"subtitle": "The Perfect Form",
		"era": "古典主义",
		"bpm": 120,
		"beats_per_measure": 3,  # 3/4拍（华尔兹）
		"color_theme": Color(0.95, 0.9, 0.7),
		"description": "莫扎特以完美的形式和优雅的对称性，将古典主义推向巅峰。",
		
		"duration": 240.0,
		"min_waves_before_boss": 10,
		
		"enemy_pool": {
			"static":                    { "weight": 1.0, "min_wave": 1 },
			"ch3_counterpoint_crawler":  { "weight": 1.5, "min_wave": 1 },
			"ch4_minuet_dancer":         { "weight": 3.0, "min_wave": 2 },
			"pulse":                     { "weight": 1.5, "min_wave": 2 },
			"screech":                   { "weight": 1.0, "min_wave": 1 },
			"ch2_choir":                 { "weight": 1.0, "min_wave": 3 },
		},
		
		"elite_pool": {
			"ch4_court_kapellmeister":  { "weight": 3.0, "min_wave": 5 },
			"ch3_fugue_weaver":         { "weight": 1.5, "min_wave": 8 },
		},
		
		"boss": {
			"key": "boss_mozart",
			"script_path": "res://scripts/entities/enemies/bosses/boss_mozart.gd",
		},
		
		"wave_templates": [
			{
				"waves": [1, 3],
				"type": "normal",
				"enemy_count_base": 10,
				"enemy_types": ["static", "ch3_counterpoint_crawler", "screech"],
				"spawn_interval": 1.8,
			},
			{
				"waves": [4, 5],
				"type": "chapter_intro",
				"enemy_count_base": 12,
				"enemy_types": ["ch4_minuet_dancer", "pulse", "ch3_counterpoint_crawler"],
				"spawn_interval": 1.5,
			},
			{
				"waves": [6, 6],
				"type": "elite",
				"enemy_count_base": 6,
				"enemy_types": ["ch4_minuet_dancer", "pulse"],
				"elite_type": "ch4_court_kapellmeister",
				"spawn_interval": 1.3,
			},
			{
				"waves": [7, 9],
				"type": "swarm",
				"enemy_count_base": 22,
				"enemy_types": ["ch4_minuet_dancer", "pulse", "ch3_counterpoint_crawler", "ch2_choir"],
				"spawn_interval": 1.0,
			},
			{
				"waves": [10, 10],
				"type": "elite",
				"enemy_count_base": 8,
				"enemy_types": ["ch4_minuet_dancer", "pulse"],
				"elite_type": "ch4_court_kapellmeister",
				"spawn_interval": 1.1,
			},
			{
				"waves": [11, 12],
				"type": "pre_boss",
				"enemy_count_base": 18,
				"enemy_types": ["ch4_minuet_dancer", "pulse", "ch3_counterpoint_crawler"],
				"spawn_interval": 0.8,
			},
		],
		
		"completion_rewards": {
			"resonance_fragments": 60,
			"xp_bonus": 250,
			"unlock": "ch5_access",
		},
	},
	
	Chapter.CH5_BEETHOVEN: {
		"name": "第五章：命运之力",
		"subtitle": "The Force of Destiny",
		"era": "浪漫主义",
		"bpm": 130,
		"beats_per_measure": 4,
		"color_theme": Color(0.7, 0.15, 0.15),
		"description": "贝多芬打破了古典主义的框架，以个人意志和情感力量重塑音乐。",
		
		"duration": 260.0,
		"min_waves_before_boss": 11,
		
		"enemy_pool": {
			"static":                    { "weight": 0.8, "min_wave": 1 },
			"ch4_minuet_dancer":         { "weight": 1.5, "min_wave": 1 },
			"ch5_fate_knocker":          { "weight": 3.0, "min_wave": 2 },
			"ch5_crescendo_surge":       { "weight": 2.5, "min_wave": 3 },
			"ch5_fury_spirit":           { "weight": 2.0, "min_wave": 4 },
			"pulse":                     { "weight": 1.5, "min_wave": 1 },
			"ch3_counterpoint_crawler":  { "weight": 1.0, "min_wave": 2 },
			"wall":                      { "weight": 1.5, "min_wave": 5 },
		},
		
		"elite_pool": {
			"ch5_symphony_commander":   { "weight": 3.0, "min_wave": 5 },
			"ch4_court_kapellmeister":  { "weight": 1.5, "min_wave": 8 },
		},
		
		"boss": {
			"key": "boss_beethoven",
			"script_path": "res://scripts/entities/enemies/bosses/boss_beethoven.gd",
		},
		
		"wave_templates": [
			{
				"waves": [1, 3],
				"type": "normal",
				"enemy_count_base": 12,
				"enemy_types": ["static", "ch4_minuet_dancer", "pulse"],
				"spawn_interval": 1.6,
			},
			{
				"waves": [4, 5],
				"type": "chapter_intro",
				"enemy_count_base": 14,
				"enemy_types": ["ch5_fate_knocker", "ch5_crescendo_surge", "pulse"],
				"spawn_interval": 1.4,
			},
			{
				"waves": [6, 6],
				"type": "elite",
				"enemy_count_base": 6,
				"enemy_types": ["ch5_fate_knocker", "ch5_crescendo_surge"],
				"elite_type": "ch5_symphony_commander",
				"spawn_interval": 1.2,
			},
			{
				"waves": [7, 9],
				"type": "swarm",
				"enemy_count_base": 25,
				"enemy_types": ["ch5_fate_knocker", "ch5_crescendo_surge", "ch5_fury_spirit", "ch4_minuet_dancer", "wall"],
				"spawn_interval": 0.9,
			},
			{
				"waves": [10, 10],
				"type": "elite",
				"enemy_count_base": 10,
				"enemy_types": ["ch5_fate_knocker", "ch5_crescendo_surge", "wall"],
				"elite_type": "ch5_symphony_commander",
				"spawn_interval": 1.0,
			},
			{
				"waves": [11, 13],
				"type": "pre_boss",
				"enemy_count_base": 20,
				"enemy_types": ["ch5_fate_knocker", "ch5_crescendo_surge", "ch5_fury_spirit", "ch4_minuet_dancer", "wall"],
				"spawn_interval": 0.7,
			},
		],
		
		"completion_rewards": {
			"resonance_fragments": 80,
			"xp_bonus": 350,
			"unlock": "ch6_access",
		},
	},
	
	# ================================================================
	# 第六章：切分行者 · 爵士 (The Syncopated Shadow)
	# ================================================================
	Chapter.CH6_JAZZ: {
		"name": "第六章：切分行者",
		"subtitle": "The Syncopated Shadow",
		"era": "爵士",
		"bpm": 140,
		"beats_per_measure": 4,
		"color_theme": Color(0.6, 0.3, 0.7),
		"description": "爵士乐的摇摆节奏与即兴色彩，打破了功能和声的稳定预期。",
		
		"duration": 280.0,
		"min_waves_before_boss": 12,
		
		## 特殊机制：摇摆力场 — 所有敌人攻击偏向反拍
		"special_mechanics": {
			"swing_grid": true,           ## 启用摇摆力场
			"offbeat_attack_ratio": 0.7,  ## 70%的攻击落在反拍上
			"spotlight_safe_zones": true,  ## 聚光灯安全区
		},
		
		"enemy_pool": {
			"ch5_crescendo_surge":       { "weight": 1.0, "min_wave": 1 },
			"ch5_fate_knocker":          { "weight": 1.0, "min_wave": 1 },
			"ch5_fury_spirit":           { "weight": 0.8, "min_wave": 3 },
			"ch6_walking_bass":          { "weight": 3.0, "min_wave": 2 },
			"ch6_scat_singer":           { "weight": 2.5, "min_wave": 3 },
			"pulse":                     { "weight": 1.5, "min_wave": 1 },
			"screech":                   { "weight": 1.0, "min_wave": 2 },
			"wall":                      { "weight": 1.0, "min_wave": 5 },
		},
		
		"elite_pool": {
			"ch6_bebop_virtuoso":       { "weight": 3.0, "min_wave": 5 },
			"ch5_symphony_commander":   { "weight": 1.5, "min_wave": 8 },
		},
		
		"boss": {
			"key": "boss_jazz",
			"script_path": "res://scripts/entities/enemies/bosses/boss_jazz.gd",
		},
		
		"wave_templates": [
			# 阶段1：入门 — 引入摇摆节奏感
			{
				"waves": [1, 3],
				"type": "normal",
				"enemy_count_base": 12,
				"enemy_types": ["ch5_crescendo_surge", "ch5_fate_knocker", "pulse"],
				"spawn_interval": 1.5,
			},
			# 阶段2：引入爵士特色敌人
			{
				"waves": [4, 5],
				"type": "chapter_intro",
				"enemy_count_base": 14,
				"enemy_types": ["ch6_walking_bass", "ch6_scat_singer", "pulse"],
				"spawn_interval": 1.3,
			},
			# 阶段3：首次精英
			{
				"waves": [6, 6],
				"type": "elite",
				"enemy_count_base": 6,
				"enemy_types": ["ch6_walking_bass", "ch6_scat_singer"],
				"elite_type": "ch6_bebop_virtuoso",
				"spawn_interval": 1.1,
			},
			# 阶段4：蜂群
			{
				"waves": [7, 9],
				"type": "swarm",
				"enemy_count_base": 28,
				"enemy_types": ["ch6_walking_bass", "ch6_scat_singer", "ch5_crescendo_surge", "screech"],
				"spawn_interval": 0.8,
			},
			# 阶段5：第二精英
			{
				"waves": [10, 10],
				"type": "elite",
				"enemy_count_base": 10,
				"enemy_types": ["ch6_walking_bass", "ch6_scat_singer", "wall"],
				"elite_type": "ch6_bebop_virtuoso",
				"spawn_interval": 0.9,
			},
			# 阶段6：脉冲风暴
			{
				"waves": [11, 12],
				"type": "pulse_storm",
				"enemy_count_base": 15,
				"enemy_types": ["ch6_walking_bass", "ch6_scat_singer", "pulse"],
				"spawn_interval": 0.7,
			},
			# 阶段7：Boss前冲刺
			{
				"waves": [13, 14],
				"type": "pre_boss",
				"enemy_count_base": 22,
				"enemy_types": ["ch6_walking_bass", "ch6_scat_singer", "ch5_fate_knocker", "wall"],
				"spawn_interval": 0.6,
			},
		],
		
		"completion_rewards": {
			"resonance_fragments": 100,
			"xp_bonus": 450,
			"unlock": "ch7_access",
		},
	},
	
	# ================================================================
	# 第七章：合成主脑 · 噪音 (The Digital Void)
	# ================================================================
	Chapter.CH7_NOISE: {
		"name": "第七章：数字虚空",
		"subtitle": "The Digital Void",
		"era": "现代/电子",
		"bpm": 150,
		"beats_per_measure": 4,
		"color_theme": Color(0.1, 0.9, 0.6),
		"description": "音乐被彻底解构为频率与波形，一切皆可为音乐，包括噪音本身。",
		
		"duration": 300.0,
		"min_waves_before_boss": 13,
		
		## 特殊机制：波形战争 — 敌人具有故障着色器效果
		"special_mechanics": {
			"waveform_warfare": true,     ## 启用波形战争
			"glitch_shader": true,        ## 敌人故障着色器
			"bitcrush_zones": true,       ## 降采样区域
			"frequency_shift": true,      ## 频率偏移（改变弹体属性）
		},
		
		"enemy_pool": {
			"ch6_walking_bass":          { "weight": 1.0, "min_wave": 1 },
			"ch6_scat_singer":           { "weight": 1.0, "min_wave": 1 },
			"ch7_bitcrusher_worm":       { "weight": 3.0, "min_wave": 2 },
			"ch7_glitch_phantom":        { "weight": 2.5, "min_wave": 3 },
			"static":                    { "weight": 2.0, "min_wave": 1 },
			"silence":                   { "weight": 2.0, "min_wave": 3 },
			"wall":                      { "weight": 1.5, "min_wave": 5 },
		},
		
		"elite_pool": {
			"ch7_frequency_overlord":   { "weight": 3.0, "min_wave": 5 },
			"ch6_bebop_virtuoso":       { "weight": 1.5, "min_wave": 8 },
		},
		
		"boss": {
			"key": "boss_noise",
			"script_path": "res://scripts/entities/enemies/bosses/boss_noise.gd",
		},
		
		"wave_templates": [
			# 阶段1：入门 — 数字虚空初探
			{
				"waves": [1, 3],
				"type": "normal",
				"enemy_count_base": 14,
				"enemy_types": ["static", "ch6_walking_bass", "ch6_scat_singer"],
				"spawn_interval": 1.4,
			},
			# 阶段2：引入终章特色敌人
			{
				"waves": [4, 5],
				"type": "chapter_intro",
				"enemy_count_base": 16,
				"enemy_types": ["ch7_bitcrusher_worm", "ch7_glitch_phantom", "static"],
				"spawn_interval": 1.2,
			},
			# 阶段3：首次精英
			{
				"waves": [6, 6],
				"type": "elite",
				"enemy_count_base": 8,
				"enemy_types": ["ch7_bitcrusher_worm", "ch7_glitch_phantom"],
				"elite_type": "ch7_frequency_overlord",
				"spawn_interval": 1.0,
			},
			# 阶段4：寂静潮
			{
				"waves": [7, 8],
				"type": "silence_tide",
				"enemy_count_base": 20,
				"enemy_types": ["ch7_bitcrusher_worm", "silence", "static"],
				"spawn_interval": 0.9,
			},
			# 阶段5：蜂群
			{
				"waves": [9, 11],
				"type": "swarm",
				"enemy_count_base": 30,
				"enemy_types": ["ch7_bitcrusher_worm", "ch7_glitch_phantom", "static", "silence"],
				"spawn_interval": 0.7,
			},
			# 阶段6：第二精英
			{
				"waves": [12, 12],
				"type": "elite",
				"enemy_count_base": 12,
				"enemy_types": ["ch7_bitcrusher_worm", "ch7_glitch_phantom", "wall"],
				"elite_type": "ch7_frequency_overlord",
				"spawn_interval": 0.8,
			},
			# 阶段7：Boss前冲刺
			{
				"waves": [13, 15],
				"type": "pre_boss",
				"enemy_count_base": 25,
				"enemy_types": ["ch7_bitcrusher_worm", "ch7_glitch_phantom", "silence", "wall"],
				"spawn_interval": 0.5,
			},
		],
		
		"completion_rewards": {
			"resonance_fragments": 150,
			"xp_bonus": 600,
			"unlock": "game_complete",
		},
	},
}

# ============================================================
# 敌人脚本路径映射（章节特色敌人 + 精英）
# ============================================================
const ENEMY_SCRIPT_PATHS: Dictionary = {
	# 基础敌人（已有场景）
	"static":  "",
	"silence": "",
	"screech": "",
	"pulse":   "",
	"wall":    "",
	
	# 第一章特色
	"ch1_grid_static":       "res://scripts/entities/enemies/chapter_enemies/ch1_grid_static.gd",
	"ch1_metronome_pulse":   "res://scripts/entities/enemies/chapter_enemies/ch1_metronome_pulse.gd",
	
	# 第二章特色
	"ch2_choir":             "res://scripts/entities/enemies/chapter_enemies/ch2_choir.gd",
	"ch2_scribe":            "res://scripts/entities/enemies/chapter_enemies/ch2_scribe.gd",
	
	# 第三章特色
	"ch3_counterpoint_crawler": "res://scripts/entities/enemies/chapter_enemies/ch3_counterpoint_crawler.gd",
	
	# 第四章特色
	"ch4_minuet_dancer":     "res://scripts/entities/enemies/chapter_enemies/ch4_minuet_dancer.gd",
	
	# 第五章特色
	"ch5_fate_knocker":      "res://scripts/entities/enemies/chapter_enemies/ch5_fate_knocker.gd",
	"ch5_crescendo_surge":   "res://scripts/entities/enemies/chapter_enemies/ch5_crescendo_surge.gd",
	"ch5_fury_spirit":       "res://scripts/entities/enemies/chapter_enemies/ch5_fury_spirit.gd",
	
	# 第六章特色
	"ch6_walking_bass":      "res://scripts/entities/enemies/chapter_enemies/ch6_walking_bass.gd",
	"ch6_scat_singer":       "res://scripts/entities/enemies/chapter_enemies/ch6_scat_singer.gd",
	
	# 第七章特色
	"ch7_bitcrusher_worm":   "res://scripts/entities/enemies/chapter_enemies/ch7_bitcrusher_worm.gd",
	"ch7_glitch_phantom":    "res://scripts/entities/enemies/chapter_enemies/ch7_glitch_phantom.gd",
}

const ELITE_SCRIPT_PATHS: Dictionary = {
	# 第一章精英
	"ch1_harmony_guardian":   "res://scripts/entities/enemies/elites/ch1_harmony_guardian.gd",
	"ch1_frequency_sentinel": "res://scripts/entities/enemies/elites/ch1_frequency_sentinel.gd",
	
	# 第二章精英
	"ch2_cantor_commander":   "res://scripts/entities/enemies/elites/ch2_cantor_commander.gd",
	
	# 第三章精英
	"ch3_fugue_weaver":       "res://scripts/entities/enemies/elites/ch3_fugue_weaver.gd",
	
	# 第四章精英
	"ch4_court_kapellmeister": "res://scripts/entities/enemies/elites/ch4_court_kapellmeister.gd",
	
	# 第五章精英
	"ch5_symphony_commander": "res://scripts/entities/enemies/elites/ch5_symphony_commander.gd",
	
	# 第六章精英
	"ch6_bebop_virtuoso":     "res://scripts/entities/enemies/elites/ch6_bebop_virtuoso.gd",
	
	# 第七章精英
	"ch7_frequency_overlord": "res://scripts/entities/enemies/elites/ch7_frequency_overlord.gd",
}

# ============================================================
# 章节敌人基础数值（用于难度缩放）
# ============================================================
const CHAPTER_ENEMY_STATS: Dictionary = {
	"ch1_grid_static": {
		"hp": 35.0, "speed": 70.0, "damage": 9.0, "xp": 4,
	},
	"ch1_metronome_pulse": {
		"hp": 50.0, "speed": 55.0, "damage": 14.0, "xp": 7,
	},
	"ch2_choir": {
		"hp": 25.0, "speed": 60.0, "damage": 7.0, "xp": 5,
	},
	"ch2_scribe": {
		"hp": 40.0, "speed": 50.0, "damage": 6.0, "xp": 6,
	},
	"ch3_counterpoint_crawler": {
		"hp": 70.0, "speed": 45.0, "damage": 10.0, "xp": 9,
	},
	"ch4_minuet_dancer": {
		"hp": 35.0, "speed": 90.0, "damage": 10.0, "xp": 6,
	},
	"ch5_fate_knocker": {
		"hp": 90.0, "speed": 40.0, "damage": 15.0, "xp": 10,
	},
	"ch5_crescendo_surge": {
		"hp": 50.0, "speed": 60.0, "damage": 8.0, "xp": 8,
	},
	"ch5_fury_spirit": {
		"hp": 120.0, "speed": 90.0, "damage": 12.0, "xp": 18,
	},
	# 第六章
	"ch6_walking_bass": {
		"hp": 80.0, "speed": 35.0, "damage": 12.0, "xp": 11,
	},
	"ch6_scat_singer": {
		"hp": 40.0, "speed": 100.0, "damage": 9.0, "xp": 9,
	},
	# 第七章
	"ch7_bitcrusher_worm": {
		"hp": 100.0, "speed": 50.0, "damage": 14.0, "xp": 13,
	},
	"ch7_glitch_phantom": {
		"hp": 60.0, "speed": 110.0, "damage": 11.0, "xp": 12,
	},
}

# ============================================================
# 章节专属音色武器配置 (v2.0 — Issue #38)
# 每个章节拥有一种专属音色武器，与章节主题深度绑定
# ============================================================
const CHAPTER_TIMBRES: Dictionary = {
	Chapter.CH1_PYTHAGORAS: {
		"timbre": MusicData.ChapterTimbre.LYRE,
		"name": "里拉琴",
		"name_en": "Lyre",
		"electronic_variant": MusicData.ElectronicVariant.SINE_WAVE_SYNTH,
		"electronic_name": "Sine Wave Synth",
		"electronic_name_cn": "正弦波合成",
		"core_mechanic": "harmonic_resonance",
		"chord_interaction": MusicData.ChordType.DOMINANT_7,
		"desc": "纯净的泛音共鸣，基于数学比例的伤害加成",
	},
	Chapter.CH2_GUIDO: {
		"timbre": MusicData.ChapterTimbre.ORGAN,
		"name": "管风琴",
		"name_en": "Organ",
		"electronic_variant": MusicData.ElectronicVariant.DRONE_SYNTH,
		"electronic_name": "Drone Synth",
		"electronic_name_cn": "无人机音合成",
		"core_mechanic": "harmonic_stacking",
		"chord_interaction": MusicData.ChordType.MINOR,
		"desc": "持续的和声层叠，多声部叠加攻击",
	},
	Chapter.CH3_BACH: {
		"timbre": MusicData.ChapterTimbre.HARPSICHORD,
		"name": "羽管键琴",
		"name_en": "Harpsichord",
		"electronic_variant": MusicData.ElectronicVariant.ARPEGGIATOR_SYNTH,
		"electronic_name": "Arpeggiator Synth",
		"electronic_name_cn": "琶音器合成",
		"core_mechanic": "counterpoint_weave",
		"chord_interaction": MusicData.ChordType.AUGMENTED,
		"desc": "精密的对位攻击，多弹道交织",
	},
	Chapter.CH4_MOZART: {
		"timbre": MusicData.ChapterTimbre.FORTEPIANO,
		"name": "钢琴",
		"name_en": "Fortepiano",
		"electronic_variant": MusicData.ElectronicVariant.VELOCITY_PAD,
		"electronic_name": "Velocity Pad",
		"electronic_name_cn": "力度感应垫",
		"core_mechanic": "velocity_dynamics",
		"chord_interaction": MusicData.ChordType.MINOR_7,
		"desc": "力度动态控制，强弱拍伤害差异化",
	},
	Chapter.CH5_BEETHOVEN: {
		"timbre": MusicData.ChapterTimbre.TUTTI,
		"name": "管弦全奏",
		"name_en": "Tutti",
		"electronic_variant": MusicData.ElectronicVariant.SUPERSAW_SYNTH,
		"electronic_name": "Supersaw Synth",
		"electronic_name_cn": "超级锯齿波",
		"core_mechanic": "emotional_crescendo",
		"chord_interaction": MusicData.ChordType.DIMINISHED,
		"desc": "情感爆发式攻击，渐强渐弱的伤害曲线",
	},
	Chapter.CH6_JAZZ: {
		"timbre": MusicData.ChapterTimbre.SAXOPHONE,
		"name": "萨克斯",
		"name_en": "Saxophone",
		"electronic_variant": MusicData.ElectronicVariant.FM_SYNTH,
		"electronic_name": "FM Synth",
		"electronic_name_cn": "FM合成器",
		"core_mechanic": "swing_attack",
		"chord_interaction": MusicData.ChordType.MAJOR_7,
		"desc": "摇摆节奏攻击，反拍强化",
	},
	Chapter.CH7_NOISE: {
		"timbre": MusicData.ChapterTimbre.SYNTHESIZER,
		"name": "合成主脑",
		"name_en": "Synthesizer",
		"electronic_variant": MusicData.ElectronicVariant.GLITCH_ENGINE,
		"electronic_name": "Glitch Engine",
		"electronic_name_cn": "故障引擎",
		"core_mechanic": "waveform_morph",
		"chord_interaction": MusicData.ChordType.DIMINISHED_7,
		"desc": "波形变换攻击，频率操控",
	},
}

# ============================================================
# 章节专属词条配置 (v2.0 — Issue #38)
# 每个章节有 3 个专属词条（普通/稀有/史诗各 1 个）
# 词条与章节音色武器有协同效果
# ============================================================
const CHAPTER_INSCRIPTIONS: Dictionary = {
	# ---- Ch1 数之和谐 · 毕达哥拉斯词条 ----
	Chapter.CH1_PYTHAGORAS: [
		{
			"id": "ch1_golden_ratio",
			"name": "黄金比例",
			"rarity": MusicData.InscriptionRarity.COMMON,
			"desc": "弹体飞行距离为黄金比例（约 1.618 倍基础距离）时，伤害 +25%",
			"synergy_desc": "里拉琴弹体自动调整飞行距离至黄金比例",
			"params": {
				"distance_ratio": 1.618,
				"distance_tolerance": 0.1,
				"damage_bonus": 0.25,
			},
		},
		{
			"id": "ch1_pythagorean_interval",
			"name": "毕达哥拉斯音程",
			"rarity": MusicData.InscriptionRarity.RARE,
			"desc": "同时存在的弹体数量为 2 的幂次时（2/4/8），全体弹体伤害 +15%",
			"synergy_desc": "里拉琴的泛音共鸣自动生成 2^n 个衍生弹体",
			"params": {
				"power_of_two_targets": [2, 4, 8],
				"damage_bonus": 0.15,
			},
		},
		{
			"id": "ch1_music_of_spheres",
			"name": "天球之乐",
			"rarity": MusicData.InscriptionRarity.EPIC,
			"desc": "每 30 秒触发一次'天球共鸣'，对全屏敌人造成当前 DPS 50% 的伤害",
			"synergy_desc": "里拉琴使用期间天球共鸣冷却时间 -10s",
			"params": {
				"cooldown": 30.0,
				"synergy_cooldown_reduction": 10.0,
				"dps_ratio": 0.50,
			},
		},
	],
	
	# ---- Ch2 记谱之光 · 圭多词条 ----
	Chapter.CH2_GUIDO: [
		{
			"id": "ch2_four_line_staff",
			"name": "四线谱",
			"rarity": MusicData.InscriptionRarity.COMMON,
			"desc": "弹体飞行轨迹上留下持续 1s 的'谱线'，敌人经过时受到 10% 额外伤害",
			"synergy_desc": "管风琴的持续音自动生成四条平行谱线",
			"params": {
				"trail_duration": 1.0,
				"trail_damage_bonus": 0.10,
				"synergy_parallel_count": 4,
			},
		},
		{
			"id": "ch2_solmization",
			"name": "唱名法",
			"rarity": MusicData.InscriptionRarity.RARE,
			"desc": "连续使用不同音符施法（Do-Re-Mi...），每个不同音符 +8% 伤害（最多 +56%）",
			"synergy_desc": "管风琴的多声部自动计入不同音符数",
			"params": {
				"damage_per_unique_note": 0.08,
				"max_unique_notes": 7,
				"max_damage_bonus": 0.56,
			},
		},
		{
			"id": "ch2_chant_echo",
			"name": "圣咏回响",
			"rarity": MusicData.InscriptionRarity.EPIC,
			"desc": "法术命中敌人后，在命中位置生成持续 3s 的'圣咏区域'，区域内敌人受到的所有伤害 +20%",
			"synergy_desc": "管风琴的持续音延长圣咏区域至 5s",
			"params": {
				"zone_duration": 3.0,
				"synergy_zone_duration": 5.0,
				"damage_amplify": 0.20,
				"zone_radius": 80.0,
			},
		},
	],
	
	# ---- Ch3 复调迷宫 · 巴赫词条 ----
	Chapter.CH3_BACH: [
		{
			"id": "ch3_canon",
			"name": "卡农",
			"rarity": MusicData.InscriptionRarity.COMMON,
			"desc": "每发弹体在 0.3s 后生成一个延迟复制体，沿相同轨迹飞行，伤害为 60%",
			"synergy_desc": "羽管键琴的对位弹体也会触发卡农",
			"params": {
				"copy_delay": 0.3,
				"copy_damage_ratio": 0.60,
			},
		},
		{
			"id": "ch3_fugue_subject",
			"name": "赋格主题",
			"rarity": MusicData.InscriptionRarity.RARE,
			"desc": "标记第一个命中的敌人为'主题'，后续弹体命中其他敌人时，'主题'敌人也受到 30% 传导伤害",
			"synergy_desc": "羽管键琴的多弹道使'主题'传导更频繁",
			"params": {
				"conduct_damage_ratio": 0.30,
				"subject_mark_duration": 10.0,
			},
		},
		{
			"id": "ch3_goldberg_variations",
			"name": "哥德堡变奏",
			"rarity": MusicData.InscriptionRarity.EPIC,
			"desc": "每 30 次施法后，下一次施法的效果翻倍（伤害、范围、持续时间均 x2）",
			"synergy_desc": "羽管键琴的快速施法加速触发变奏",
			"params": {
				"cast_threshold": 30,
				"double_multiplier": 2.0,
			},
		},
	],
	
	# ---- Ch4 完美形式 · 莫扎特词条 ----
	Chapter.CH4_MOZART: [
		{
			"id": "ch4_sonata_form",
			"name": "奏鸣曲式",
			"rarity": MusicData.InscriptionRarity.COMMON,
			"desc": "战斗分为'呈示-展开-再现'三阶段，每阶段切换时获得 3s 全属性 +15%",
			"synergy_desc": "钢琴的力度控制在阶段切换时自动最大化",
			"params": {
				"phase_count": 3,
				"transition_buff_duration": 3.0,
				"all_stats_bonus": 0.15,
			},
		},
		{
			"id": "ch4_perfect_cadence",
			"name": "完美终止",
			"rarity": MusicData.InscriptionRarity.RARE,
			"desc": "击杀敌人时，若使用的是 V-I（属-主）和弦进行，额外获得 2 倍经验",
			"synergy_desc": "钢琴自动将终止式的力度提升至 fortissimo",
			"params": {
				"xp_multiplier": 2.0,
				"required_progression": "D_to_T",
			},
		},
		{
			"id": "ch4_mozart_effect",
			"name": "莫扎特效应",
			"rarity": MusicData.InscriptionRarity.EPIC,
			"desc": "保持 15s 不受伤，获得'灵感'状态：施法速度 +30%，持续 10s",
			"synergy_desc": "钢琴在'灵感'状态下解锁隐藏的装饰音弹体",
			"params": {
				"no_damage_threshold": 15.0,
				"inspiration_duration": 10.0,
				"cast_speed_bonus": 0.30,
			},
		},
	],
	
	# ---- Ch5 命运之力 · 贝多芬词条 ----
	Chapter.CH5_BEETHOVEN: [
		{
			"id": "ch5_fate_motif",
			"name": "命运动机",
			"rarity": MusicData.InscriptionRarity.COMMON,
			"desc": "每 4 次攻击的第 4 次（da-da-da-DUM）伤害 +40%",
			"synergy_desc": "管弦全奏的第 4 拍自动触发全体乐器齐奏",
			"params": {
				"attack_cycle": 4,
				"fourth_hit_bonus": 0.40,
			},
		},
		{
			"id": "ch5_heroic_symphony",
			"name": "英雄交响",
			"rarity": MusicData.InscriptionRarity.RARE,
			"desc": "生命值低于 30% 时，攻击力 +50%，移动速度 +20%",
			"synergy_desc": "管弦全奏在低血量时自动切换为'暴风雨'模式",
			"params": {
				"hp_threshold": 0.30,
				"attack_bonus": 0.50,
				"speed_bonus": 0.20,
			},
		},
		{
			"id": "ch5_ode_to_joy",
			"name": "欢乐颂",
			"rarity": MusicData.InscriptionRarity.EPIC,
			"desc": "击杀 100 个敌人后触发'欢乐颂'：15s 内所有法术无消耗、无疲劳",
			"synergy_desc": "管弦全奏在欢乐颂期间解锁'合唱终章'超级弹幕",
			"params": {
				"kill_threshold": 100,
				"ode_duration": 15.0,
				"no_cost": true,
				"no_fatigue": true,
			},
		},
	],
	
	# ---- Ch6 切分行者 · 爵士词条 ----
	Chapter.CH6_JAZZ: [
		{
			"id": "ch6_blue_scale",
			"name": "蓝调音阶",
			"rarity": MusicData.InscriptionRarity.COMMON,
			"desc": "使用降音（b3, b5, b7）时，弹体获得'忧郁穿透'：无视 20% 护甲",
			"synergy_desc": "萨克斯的摇摆攻击自动附带蓝调音阶效果",
			"params": {
				"armor_penetration": 0.20,
				"blue_notes": ["b3", "b5", "b7"],
			},
		},
		{
			"id": "ch6_improvisation",
			"name": "即兴独奏",
			"rarity": MusicData.InscriptionRarity.RARE,
			"desc": "连续 5s 不重复使用同一音符，触发'即兴独奏'：下一次施法伤害 x3",
			"synergy_desc": "萨克斯在即兴独奏期间攻击速度翻倍",
			"params": {
				"no_repeat_duration": 5.0,
				"next_cast_multiplier": 3.0,
				"synergy_attack_speed_mult": 2.0,
			},
		},
		{
			"id": "ch6_syncopation_counter",
			"name": "切分反击",
			"rarity": MusicData.InscriptionRarity.EPIC,
			"desc": "在敌人攻击的反拍（弱拍）施法，该法术伤害 +100% 且附带 1s 眩晕",
			"synergy_desc": "萨克斯自动将施法时机偏移至最近的反拍",
			"params": {
				"offbeat_damage_bonus": 1.00,
				"stun_duration": 1.0,
			},
		},
	],
	
	# ---- Ch7 数字虚空 · 电子词条 ----
	Chapter.CH7_NOISE: [
		{
			"id": "ch7_bitcrush",
			"name": "降采样",
			"name_en": "Bitcrush",
			"rarity": MusicData.InscriptionRarity.COMMON,
			"desc": "弹体命中敌人后，敌人的移动变为'低帧率'（每 0.2s 才更新一次位置），持续 2s",
			"synergy_desc": "合成主脑的 Bitcrusher 模式使降采样效果范围扩大至 AOE",
			"params": {
				"frame_interval": 0.2,
				"effect_duration": 2.0,
				"synergy_aoe_radius": 80.0,
			},
		},
		{
			"id": "ch7_fm_modulation",
			"name": "频率调制",
			"name_en": "FM",
			"rarity": MusicData.InscriptionRarity.RARE,
			"desc": "弹体的伤害随飞行时间呈正弦波动（±30%），波峰时命中可触发额外的谐波爆炸",
			"synergy_desc": "合成主脑可调节 FM 的调制频率和深度",
			"params": {
				"damage_oscillation": 0.30,
				"oscillation_frequency": 2.0,
				"harmonic_explosion_radius": 60.0,
				"harmonic_explosion_damage": 0.50,
			},
		},
		{
			"id": "ch7_glitch_overflow",
			"name": "故障溢出",
			"name_en": "Glitch Overflow",
			"rarity": MusicData.InscriptionRarity.EPIC,
			"desc": "每次击杀敌人有 10% 几率触发'故障溢出'：敌人死亡动画变为数据崩溃效果，对周围敌人造成 200% 伤害",
			"synergy_desc": "合成主脑使故障溢出几率提升至 25%",
			"params": {
				"base_chance": 0.10,
				"synergy_chance": 0.25,
				"explosion_damage_ratio": 2.00,
				"explosion_radius": 100.0,
			},
		},
	],
}

# ============================================================
# 跨章节词条组合 · 音乐史彩蛋 (v2.0 — Issue #38)
# ============================================================
const INSCRIPTION_EASTER_EGGS: Array = [
	{
		"id": "ancient_modern_symphony",
		"name": "古今交响",
		"required_inscriptions": ["ch1_music_of_spheres", "ch5_ode_to_joy"],
		"desc": "天球共鸣和欢乐颂可同时触发",
		"effect": "simultaneous_trigger",
	},
	{
		"id": "counterpoint_and_improv",
		"name": "对位与即兴",
		"required_inscriptions": ["ch3_fugue_subject", "ch6_improvisation"],
		"desc": "赋格主题的传导伤害可触发即兴独奏",
		"effect": "conduct_triggers_improv",
	},
	{
		"id": "digital_pythagoras",
		"name": "数字毕达哥拉斯",
		"required_inscriptions": ["ch1_golden_ratio", "ch7_bitcrush"],
		"desc": "黄金比例的距离判定精度放宽 20%",
		"effect": "golden_ratio_tolerance_up",
		"params": { "tolerance_bonus": 0.20 },
	},
	{
		"id": "notation_to_glitch",
		"name": "从记谱到故障",
		"required_inscriptions": ["ch2_four_line_staff", "ch7_glitch_overflow"],
		"desc": "四线谱的谱线变为故障数据流，伤害 +15%",
		"effect": "glitch_staff_lines",
		"params": { "trail_damage_bonus_extra": 0.15 },
	},
	{
		"id": "fate_and_form",
		"name": "命运与形式",
		"required_inscriptions": ["ch4_sonata_form", "ch5_fate_motif"],
		"desc": "奏鸣曲式的阶段切换自动触发命运动机的第 4 击效果",
		"effect": "phase_triggers_fate",
	},
]

# ============================================================
# 公共接口
# ============================================================

## 获取章节配置
static func get_chapter_config(chapter: int) -> Dictionary:
	return CHAPTERS.get(chapter, {})

## 获取章节的波次模板
static func get_wave_template(chapter: int, wave_number: int) -> Dictionary:
	var config := get_chapter_config(chapter)
	var templates: Array = config.get("wave_templates", [])
	
	for template in templates:
		var range_start: int = template["waves"][0]
		var range_end: int = template["waves"][1]
		if wave_number >= range_start and wave_number <= range_end:
			return template
	
	# 超出模板范围，返回最后一个模板（循环高难度波次）
	if not templates.is_empty():
		return templates[-1]
	return {}

## 获取章节可用的敌人类型（基于当前波次）
static func get_available_enemies(chapter: int, wave_number: int) -> Array[String]:
	var config := get_chapter_config(chapter)
	var pool: Dictionary = config.get("enemy_pool", {})
	var available: Array[String] = []
	
	for enemy_type in pool:
		var data: Dictionary = pool[enemy_type]
		if wave_number >= data.get("min_wave", 1):
			available.append(enemy_type)
	
	return available

## 加权随机选择敌人类型
static func weighted_select_enemy(chapter: int, wave_number: int) -> String:
	var config := get_chapter_config(chapter)
	var pool: Dictionary = config.get("enemy_pool", {})
	
	var available: Array[Dictionary] = []
	var total_weight := 0.0
	
	for enemy_type in pool:
		var data: Dictionary = pool[enemy_type]
		if wave_number >= data.get("min_wave", 1):
			available.append({"name": enemy_type, "weight": data["weight"]})
			total_weight += data["weight"]
	
	if available.is_empty():
		return "static"
	
	var roll := randf() * total_weight
	var cumulative := 0.0
	for entry in available:
		cumulative += entry["weight"]
		if roll <= cumulative:
			return entry["name"]
	
	return available[-1]["name"]

## 选择精英类型
static func select_elite(chapter: int, wave_number: int) -> String:
	var config := get_chapter_config(chapter)
	var pool: Dictionary = config.get("elite_pool", {})
	
	var available: Array[Dictionary] = []
	var total_weight := 0.0
	
	for elite_type in pool:
		var data: Dictionary = pool[elite_type]
		if wave_number >= data.get("min_wave", 1):
			available.append({"name": elite_type, "weight": data["weight"]})
			total_weight += data["weight"]
	
	if available.is_empty():
		return ""
	
	var roll := randf() * total_weight
	var cumulative := 0.0
	for entry in available:
		cumulative += entry["weight"]
		if roll <= cumulative:
			return entry["name"]
	
	return available[-1]["name"]

## 获取敌人基础数值
static func get_enemy_base_stats(enemy_type: String) -> Dictionary:
	return CHAPTER_ENEMY_STATS.get(enemy_type, {
		"hp": 30.0, "speed": 80.0, "damage": 8.0, "xp": 3,
	})

## 判断是否为章节特色敌人（需要脚本实例化）
static func is_chapter_enemy(enemy_type: String) -> bool:
	return ENEMY_SCRIPT_PATHS.has(enemy_type) and ENEMY_SCRIPT_PATHS[enemy_type] != ""

## 判断是否为精英敌人
static func is_elite_enemy(enemy_type: String) -> bool:
	return ELITE_SCRIPT_PATHS.has(enemy_type)

## 获取章节总数
static func get_chapter_count() -> int:
	return CHAPTERS.size()

## 获取下一章
static func get_next_chapter(current: int) -> int:
	var idx := current as int
	if idx + 1 < Chapter.size():
		return idx + 1
	return current  # 已是最后一章

## 获取章节特殊机制
static func get_special_mechanics(chapter: int) -> Dictionary:
	var config := get_chapter_config(chapter)
	return config.get("special_mechanics", {})

## 获取章节专属音色武器配置
static func get_chapter_timbre(chapter: int) -> Dictionary:
	return CHAPTER_TIMBRES.get(chapter, {})

## 获取章节专属词条池
static func get_chapter_inscriptions(chapter: int) -> Array[Dictionary]:
	var raw: Array = CHAPTER_INSCRIPTIONS.get(chapter, [])
	var result: Array[Dictionary] = []
	for item in raw:
		result.append(item)
	return result

## 根据词条 ID 获取词条数据
static func get_inscription_by_id(inscription_id: String) -> Dictionary:
	for chapter in CHAPTER_INSCRIPTIONS:
		for inscription in CHAPTER_INSCRIPTIONS[chapter]:
			if inscription["id"] == inscription_id:
				return inscription
	return {}

## 检查是否触发了音乐史彩蛋
static func check_easter_eggs(owned_inscription_ids: Array[String]) -> Array[Dictionary]:
	var triggered: Array[Dictionary] = []
	for egg in INSCRIPTION_EASTER_EGGS:
		var all_met := true
		for req_id in egg["required_inscriptions"]:
			if req_id not in owned_inscription_ids:
				all_met = false
				break
		if all_met:
			triggered.append(egg)
	return triggered

## 获取章节音色武器的电子乐变体信息
static func get_electronic_variant(chapter: int) -> Dictionary:
	var timbre_config := get_chapter_timbre(chapter)
	if timbre_config.is_empty():
		return {}
	var variant_enum = timbre_config.get("electronic_variant", MusicData.ElectronicVariant.NONE)
	return MusicData.ELECTRONIC_VARIANT_DATA.get(variant_enum, {})
