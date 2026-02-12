## character_class_manager.gd
## 角色/职业管理器 (Issue #28)
##
## 负责在游戏开始时根据玩家选择的调式/职业：
##   1. 应用角色属性修正到 GameManager
##   2. 配置初始序列器
##   3. 激活被动能力
##   4. 设置角色视觉风格
##
## 与 ModeSystem (mode_system.gd) 协同工作：
##   - ModeSystem 负责音符可用性和调式被动
##   - CharacterClassManager 负责属性修正、序列器配置和视觉风格
##
## 挂载方式：作为 main_game.tscn 的子节点
extends Node

const CharacterClass = preload("res://scripts/data/character_class.gd")

# ============================================================
# 信号
# ============================================================
signal class_applied(class_id: String, class_name: String)
signal passive_triggered(passive_id: String, effect: Dictionary)
signal auto_cleanse_triggered()

# ============================================================
# 状态
# ============================================================
## 当前角色/职业 ID
var current_class_id: String = "ionian"
## 当前角色/职业定义
var _class_def: Dictionary = {}
## 被动能力状态
var _passive_timer: float = 0.0
## 自动清除计时器（五声音阶专用）
var _auto_cleanse_timer: float = 0.0
## 是否已应用
var _applied: bool = false

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	add_to_group("character_class_manager")

func _process(delta: float) -> void:
	if not _applied:
		return
	if GameManager.current_state != GameManager.GameState.PLAYING:
		return
	
	_update_passive(delta)

# ============================================================
# 应用角色/职业
# ============================================================

## 在游戏开始时调用，应用选中的角色/职业
func apply_class(class_id: String = "") -> void:
	if class_id.is_empty():
		class_id = SaveManager.get_selected_mode()
	
	current_class_id = class_id
	_class_def = CharacterClass.get_class_definition(class_id)
	
	# 1. 应用属性修正
	_apply_stats()
	
	# 2. 配置初始序列器
	_setup_initial_sequencer()
	
	# 3. 应用视觉风格
	_apply_visual_style()
	
	# 4. 初始化被动能力
	_init_passive()
	
	_applied = true
	class_applied.emit(class_id, _class_def.get("name", "未知"))

## 重置
func reset() -> void:
	_applied = false
	_passive_timer = 0.0
	_auto_cleanse_timer = 0.0
	current_class_id = "ionian"
	_class_def = {}

# ============================================================
# 属性修正
# ============================================================

func _apply_stats() -> void:
	var stats: Dictionary = _class_def.get("stats", {})
	
	# HP 修正
	var hp_mult: float = stats.get("hp_mult", 1.0)
	if hp_mult != 1.0:
		GameManager.player_max_hp *= hp_mult
		GameManager.player_current_hp = GameManager.player_max_hp
	
	# 移速修正（通过玩家节点）
	var speed_mult: float = stats.get("speed_mult", 1.0)
	if speed_mult != 1.0:
		var player := get_tree().get_first_node_in_group("player")
		if player and "move_speed" in player:
			player.move_speed *= speed_mult

## 获取当前角色的伤害倍率（供 SpellcraftSystem 使用）
func get_damage_multiplier() -> float:
	var stats: Dictionary = _class_def.get("stats", {})
	return stats.get("damage_mult", 1.0)

## 获取当前角色的施法冷却倍率
func get_cooldown_multiplier() -> float:
	var stats: Dictionary = _class_def.get("stats", {})
	return stats.get("spell_cooldown_mult", 1.0)

## 获取当前角色的经验倍率
func get_xp_multiplier() -> float:
	var stats: Dictionary = _class_def.get("stats", {})
	return stats.get("xp_gain_mult", 1.0)

# ============================================================
# 初始序列器配置
# ============================================================

func _setup_initial_sequencer() -> void:
	var seq_config: Dictionary = _class_def.get("initial_sequencer", {})
	if seq_config.is_empty():
		return
	
	# 通知 SpellcraftSystem 设置初始自动序列
	if SpellcraftSystem.has_method("set_auto_sequence"):
		SpellcraftSystem.set_auto_sequence(
			seq_config.get("auto_notes", [0, 4, 7]),
			seq_config.get("auto_interval", 0.5),
			seq_config.get("auto_damage_mult", 1.0)
		)

# ============================================================
# 视觉风格
# ============================================================

func _apply_visual_style() -> void:
	var visual_config: Dictionary = _class_def.get("visual", {})
	if visual_config.is_empty():
		return
	
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	
	# --- 2D 视觉增强器（旧系统，保持向后兼容） ---
	var visual_enhancer = player.get_node_or_null("PlayerVisualEnhanced")
	if visual_enhancer == null:
		visual_enhancer = player.get_node_or_null("PlayerVisual")
	
	if visual_enhancer and visual_enhancer.has_method("set_class_colors"):
		visual_enhancer.set_class_colors(
			visual_config.get("primary_color", Color.WHITE),
			visual_config.get("secondary_color", Color.GRAY),
			visual_config.get("particle_color", Color.WHITE)
		)
	
	# --- 3D 谐振调式化身 (Issue #59) ---
	# HarmonicAvatarManager 会自动监听 class_applied 信号并切换调式。
	# 但如果玩家已有 HarmonicAvatarManager 引用，也可以直接通知。
	if player.has_method("get_harmonic_avatar"):
		var avatar: HarmonicAvatarManager = player.get_harmonic_avatar()
		if avatar:
			# 根据职业 ID 映射到调式 ID
			var mode_map: Dictionary = {
				"ionian": 0,
				"dorian": 0,
				"pentatonic": 2,
				"blues": 1,
			}
			var target_mode: int = mode_map.get(current_class_id, 0)
			avatar.switch_mode(target_mode)

# ============================================================
# 被动能力
# ============================================================

func _init_passive() -> void:
	var passive: Dictionary = _class_def.get("passive", {})
	var passive_id: String = passive.get("id", "")
	
	match passive_id:
		"harmony_bonus":
			# 伊奥尼亚：和谐度加成已在 ModeSystem 中处理
			pass
		"auto_echo":
			# 多利亚：回响效果已在 ModeSystem.on_spell_cast 中处理
			pass
		"harmony_shield":
			# 五声音阶：不和谐度减半已在 ModeSystem 中处理
			# 初始化自动清除计时器
			var effects: Dictionary = passive.get("effects", {})
			_auto_cleanse_timer = effects.get("auto_cleanse_interval", 30.0)
		"dissonance_crit":
			# 布鲁斯：暴击率已在 ModeSystem 中处理
			pass

func _update_passive(delta: float) -> void:
	var passive: Dictionary = _class_def.get("passive", {})
	var passive_id: String = passive.get("id", "")
	
	match passive_id:
		"harmony_shield":
			# 五声音阶：自动清除不和谐度
			_auto_cleanse_timer -= delta
			if _auto_cleanse_timer <= 0:
				var effects: Dictionary = passive.get("effects", {})
				_auto_cleanse_timer = effects.get("auto_cleanse_interval", 30.0)
				# 清除不和谐度
				if GameManager.has_method("reduce_dissonance"):
					GameManager.reduce_dissonance(5.0)
				auto_cleanse_triggered.emit()
				passive_triggered.emit("harmony_shield", {"cleansed": 5.0})

# ============================================================
# 查询接口
# ============================================================

## 获取当前角色/职业的完整信息
func get_current_class_info() -> Dictionary:
	return _class_def

## 获取当前角色/职业的名称
func get_current_class_name() -> String:
	return _class_def.get("name", "伊奥尼亚")

## 获取当前角色/职业的标题
func get_current_class_title() -> String:
	return _class_def.get("title", "均衡者")

## 获取当前角色/职业的描述
func get_current_class_description() -> String:
	return _class_def.get("description", "")

## 获取当前角色/职业的被动能力描述
func get_passive_description() -> String:
	var passive: Dictionary = _class_def.get("passive", {})
	return passive.get("description", "无被动能力")

## 获取当前角色/职业的背景故事
func get_lore() -> String:
	return _class_def.get("lore", "")

## 获取所有可用角色/职业的摘要信息（供 UI 使用）
func get_all_classes_summary() -> Array[Dictionary]:
	var summaries: Array[Dictionary] = []
	for class_id in CharacterClass.get_all_class_ids():
		var def: Dictionary = CharacterClass.get_class_definition(class_id)
		var unlock: Dictionary = def.get("unlock", {})
		summaries.append({
			"id": class_id,
			"name": def.get("name", ""),
			"name_en": def.get("name_en", ""),
			"title": def.get("title", ""),
			"description": def.get("description", ""),
			"cost": unlock.get("cost", 0),
			"unlocked": SaveManager.is_mode_unlocked(class_id),
			"selected": class_id == current_class_id,
			"visual": def.get("visual", {}),
		})
	return summaries
