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
				"enemy_types": ["ch5_fate_knocker", "ch5_crescendo_surge", "ch4_minuet_dancer", "wall"],
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
				"enemy_types": ["ch5_fate_knocker", "ch5_crescendo_surge", "ch4_minuet_dancer", "wall"],
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
