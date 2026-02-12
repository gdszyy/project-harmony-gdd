## hud.gd — 战斗 HUD 主控制器 (v4.0 — Module 2 重写)
## 管理所有 HUD 子组件的生命周期、布局和全局状态
##
## 层级结构：
##   Layer 5  — 游戏世界内 UI（序列器、弹药环、节拍指示器）
##   Layer 6  — 伤害数字
##   Layer 10 — 屏幕空间 HUD（血条、疲劳、Boss 血条、施法槽、信息面板、召唤物）
##   Layer 11 — 最高层级提示（密度过载、和弦进行等）
##   Layer 19 — DPS 覆盖层（仅测试场）
##
## 保留功能：经验条、疲劳滤镜、调式信息、留白奖励
extends CanvasLayer

# ============================================================
# 信号
# ============================================================
signal hud_ready()
signal hud_visibility_changed(is_visible: bool)

# ============================================================
# 配置
# ============================================================
const BASE_RESOLUTION := Vector2(1920, 1080)

# ============================================================
# 模块化子组件引用 (Layer 10 — 屏幕空间 HUD)
# ============================================================
var _hp_bar: Control = null
var _fatigue_meter: Control = null
var _boss_hp_bar: Control = null
var _manual_cast_slots: Control = null
var _info_panel: Control = null
var _summon_hud: Control = null

# Layer 6 — 伤害数字
var _damage_number_layer: CanvasLayer = null
var _damage_number_pool: Node2D = null

# Layer 11 — 通知管理器
var _notification_manager: CanvasLayer = null

# Layer 5 — 游戏世界内 UI（由场景管理，此处仅引用）
var _rhythm_indicator: Control = null
var _ammo_ring: Node2D = null

# Layer 19 — DPS 覆盖层
var _dps_overlay: CanvasLayer = null

# ============================================================
# 保留的旧版 UI 元素（兼容现有系统）
# ============================================================
## 疲劳滤镜（全屏后处理）
var _fatigue_filter: ColorRect = null
## 建议文字标签
var _suggestion_label: Label = null
## 单音寂静指示器
var _silence_indicators: Array[Label] = []
## 密度过载警告标签（旧版，新版由 NotificationManager 处理）
var _overload_warning: Label = null
## 和弦进行提示标签（旧版，新版由 NotificationManager 处理）
var _progression_label: Label = null
## 调式信息标签
var _mode_label: Label = null
## 暴击率标签
var _crit_label: Label = null
## 经验条
var _xp_bar_container: Control = null
var _xp_bar_bg: ColorRect = null
var _xp_bar_fill: ColorRect = null
var _xp_bar_label: Label = null
var _xp_flash_timer: float = 0.0
var _xp_display_ratio: float = 0.0
var _levelup_flash_timer: float = 0.0

# ============================================================
# 全局状态
# ============================================================
var _is_boss_fight: bool = false
var _hud_visible: bool = true
var _current_hp_ratio: float = 1.0
var _current_fatigue: float = 0.0
var _suggestion_timer: float = 0.0
var _progression_timer: float = 0.0
var _overload_flash_timer: float = 0.0

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	layer = 10
	name = "BattleHUD"

	_build_modular_hud()
	_setup_legacy_ui()
	_setup_fatigue_filter()
	_connect_global_signals()

	hud_ready.emit()

func _process(delta: float) -> void:
	# 更新世界空间 UI 引用
	if _rhythm_indicator == null:
		_rhythm_indicator = get_tree().get_first_node_in_group("rhythm_indicator")
	if _ammo_ring == null:
		_ammo_ring = get_tree().get_first_node_in_group("ammo_ring")

	# 疲劳滤镜更新
	_current_fatigue = FatigueManager.current_afi if FatigueManager.get("current_afi") != null else _current_fatigue
	_update_fatigue_filter()

	# 建议文字淡出
	_update_suggestion(delta)
	# 和弦进行提示淡出
	_update_progression_label(delta)
	# 密度过载闪烁
	_update_overload_warning(delta)
	# 单音寂静指示器
	_update_silence_indicators()
	# 经验条
	_update_xp_bar(delta)

# ============================================================
# 模块化 HUD 构建
# ============================================================

func _build_modular_hud() -> void:
	# === 1. 谐振完整度 (血条) — Bottom-Wide, 800x150 ===
	_hp_bar = _load_script_node("res://scripts/ui/hp_bar.gd", "HPBar")
	_hp_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hp_bar.offset_left = -400
	_hp_bar.offset_right = 400
	_hp_bar.offset_top = -150
	_hp_bar.offset_bottom = 0
	add_child(_hp_bar)

	# === 2. 听感疲劳指示器 — Center-Right, 80x440 ===
	_fatigue_meter = _load_script_node("res://scripts/ui/fatigue_meter.gd", "FatigueMeter")
	_fatigue_meter.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_fatigue_meter.offset_left = -80
	_fatigue_meter.offset_right = 0
	_fatigue_meter.offset_top = -220
	_fatigue_meter.offset_bottom = 220
	add_child(_fatigue_meter)

	# === 3. Boss 血条 — Top-Wide, 1000x120 ===
	_boss_hp_bar = _load_script_node("res://scripts/ui/boss_hp_bar_ui.gd", "BossHPBar")
	_boss_hp_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_boss_hp_bar.offset_left = -500
	_boss_hp_bar.offset_right = 500
	_boss_hp_bar.offset_top = 0
	_boss_hp_bar.offset_bottom = 120
	_boss_hp_bar.visible = false  # 默认隐藏，Boss 战时显示
	add_child(_boss_hp_bar)

	# === 4. 手动施法槽 — Bottom-Left, 240x80 ===
	_manual_cast_slots = _load_script_node("res://scripts/ui/manual_cast_slot.gd", "ManualCastSlots")
	_manual_cast_slots.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_manual_cast_slots.offset_left = 20
	_manual_cast_slots.offset_right = 280
	_manual_cast_slots.offset_top = -100
	_manual_cast_slots.offset_bottom = -10
	add_child(_manual_cast_slots)

	# === 5. 信息面板 — Top-Left, 200x100 ===
	_info_panel = _load_script_node("res://scripts/ui/info_panel.gd", "InfoPanel")
	_info_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_info_panel.offset_left = 10
	_info_panel.offset_right = 210
	_info_panel.offset_top = 10
	_info_panel.offset_bottom = 110
	add_child(_info_panel)

	# === 6. 召唤物 HUD — Top-Right, 180x300 ===
	_summon_hud = _load_script_node("res://scripts/ui/summon_hud.gd", "SummonHUD")
	_summon_hud.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_summon_hud.offset_left = -200
	_summon_hud.offset_right = 0
	_summon_hud.offset_top = 10
	_summon_hud.offset_bottom = 340
	add_child(_summon_hud)

	# === 7. 伤害数字层 — Layer 6 ===
	_damage_number_layer = CanvasLayer.new()
	_damage_number_layer.name = "DamageNumberLayer"
	_damage_number_layer.layer = 6
	add_child(_damage_number_layer)

	var pool_script := load("res://scripts/ui/damage_number_pool.gd")
	if pool_script:
		_damage_number_pool = Node2D.new()
		_damage_number_pool.set_script(pool_script)
		_damage_number_pool.name = "DamageNumberPool"
		_damage_number_layer.add_child(_damage_number_pool)

	# === 8. 通知管理器 — Layer 11 ===
	var notif_script := load("res://scripts/ui/notification_manager.gd")
	if notif_script:
		_notification_manager = CanvasLayer.new()
		_notification_manager.set_script(notif_script)
		_notification_manager.name = "NotificationManager"
		add_child(_notification_manager)

## 加载脚本并创建 Control 节点
func _load_script_node(script_path: String, node_name: String) -> Control:
	var script := load(script_path)
	var node := Control.new()
	if script:
		node.set_script(script)
	else:
		push_warning("HUD: Failed to load script: %s" % script_path)
	node.name = node_name
	return node

# ============================================================
# 保留的旧版 UI 初始化
# ============================================================

func _setup_legacy_ui() -> void:
	_setup_suggestion_label()
	_setup_silence_indicators()
	_setup_overload_warning()
	_setup_progression_label()
	_setup_mode_label()
	_setup_crit_label()
	_setup_xp_bar()

func _setup_suggestion_label() -> void:
	_suggestion_label = Label.new()
	_suggestion_label.name = "SuggestionLabel"
	_suggestion_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_suggestion_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_suggestion_label.offset_top = -180
	_suggestion_label.offset_bottom = -160
	_suggestion_label.offset_left = -300
	_suggestion_label.offset_right = 300
	_suggestion_label.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	_suggestion_label.add_theme_font_size_override("font_size", 14)
	_suggestion_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_suggestion_label)

func _setup_silence_indicators() -> void:
	var note_names := ["C", "D", "E", "F", "G", "A", "B"]
	for i in range(7):
		var indicator := Label.new()
		indicator.name = "SilenceIndicator_%s" % note_names[i]
		indicator.text = note_names[i]
		indicator.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.3))
		indicator.add_theme_font_size_override("font_size", 14)
		indicator.visible = false
		indicator.position = Vector2(10 + i * 30, 0)
		indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(indicator)
		_silence_indicators.append(indicator)

func _setup_overload_warning() -> void:
	_overload_warning = Label.new()
	_overload_warning.name = "OverloadWarning"
	_overload_warning.text = "⚠ DENSITY OVERLOAD"
	_overload_warning.add_theme_color_override("font_color", Color(1.0, 0.3, 0.1))
	_overload_warning.add_theme_font_size_override("font_size", 18)
	_overload_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overload_warning.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_overload_warning.offset_top = 80
	_overload_warning.offset_left = -200
	_overload_warning.offset_right = 200
	_overload_warning.visible = false
	_overload_warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overload_warning)

func _setup_progression_label() -> void:
	_progression_label = Label.new()
	_progression_label.name = "ProgressionLabel"
	_progression_label.text = ""
	_progression_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.6))
	_progression_label.add_theme_font_size_override("font_size", 22)
	_progression_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progression_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_progression_label.offset_top = 110
	_progression_label.offset_left = -300
	_progression_label.offset_right = 300
	_progression_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_progression_label)

func _setup_mode_label() -> void:
	_mode_label = Label.new()
	_mode_label.name = "ModeLabel"
	_mode_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9, 0.8))
	_mode_label.add_theme_font_size_override("font_size", 12)
	_mode_label.position = Vector2(10, 5)
	_mode_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_mode_display()
	add_child(_mode_label)

func _setup_crit_label() -> void:
	_crit_label = Label.new()
	_crit_label.name = "CritLabel"
	_crit_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2, 0.9))
	_crit_label.add_theme_font_size_override("font_size", 14)
	_crit_label.position = Vector2(10, 22)
	_crit_label.visible = false
	_crit_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_crit_label)

# ============================================================
# 全局信号连接
# ============================================================

func _connect_global_signals() -> void:
	# 核心信号
	if GameManager.has_signal("player_hp_changed"):
		GameManager.player_hp_changed.connect(_on_hp_changed)
	if GameManager.has_signal("beat_tick"):
		GameManager.beat_tick.connect(_on_beat_tick)
	if GameManager.has_signal("xp_gained"):
		GameManager.xp_gained.connect(_on_xp_gained)
	if GameManager.has_signal("level_up"):
		GameManager.level_up.connect(_on_level_up)

	# 疲劳系统
	if FatigueManager.has_signal("fatigue_updated"):
		FatigueManager.fatigue_updated.connect(_on_fatigue_updated)
	if FatigueManager.has_signal("recovery_suggestion"):
		FatigueManager.recovery_suggestion.connect(_on_recovery_suggestion)
	if FatigueManager.has_signal("rest_cleanse_triggered"):
		FatigueManager.rest_cleanse_triggered.connect(_on_rest_cleanse)

	# Boss 战
	if GameManager.has_signal("boss_fight_started"):
		GameManager.boss_fight_started.connect(_on_boss_fight_started)
	if GameManager.has_signal("boss_fight_ended"):
		GameManager.boss_fight_ended.connect(_on_boss_fight_ended)

	# 伤害事件
	if GameManager.has_signal("damage_dealt"):
		GameManager.damage_dealt.connect(_on_damage_dealt)
	if GameManager.has_signal("player_healed"):
		GameManager.player_healed.connect(_on_player_healed)

	# SpellcraftSystem
	if SpellcraftSystem.has_signal("spell_blocked_by_silence"):
		SpellcraftSystem.spell_blocked_by_silence.connect(_on_spell_blocked)
	if SpellcraftSystem.has_signal("accuracy_penalized"):
		SpellcraftSystem.accuracy_penalized.connect(_on_accuracy_penalized)
	if SpellcraftSystem.has_signal("progression_resolved"):
		SpellcraftSystem.progression_resolved.connect(_on_progression_resolved)

	# 调式系统
	if ModeSystem.has_signal("mode_changed"):
		ModeSystem.mode_changed.connect(_on_mode_changed)
	if ModeSystem.has_signal("crit_from_dissonance"):
		ModeSystem.crit_from_dissonance.connect(_on_crit_updated)

	# 密度过载 / 和弦进行 / 单音寂静（新版通知系统）
	if GameManager.has_signal("density_overload"):
		GameManager.density_overload.connect(_on_density_overload_signal)
	if GameManager.has_signal("chord_progression_triggered"):
		GameManager.chord_progression_triggered.connect(_on_chord_progression_signal)
	if GameManager.has_signal("note_silenced"):
		GameManager.note_silenced.connect(_on_note_silenced_signal)

# ============================================================
# 血条回调
# ============================================================

func _on_hp_changed(current_hp: float, max_hp: float) -> void:
	_current_hp_ratio = current_hp / max(max_hp, 0.001)

# ============================================================
# 疲劳度回调
# ============================================================

func _on_fatigue_updated(result: Dictionary) -> void:
	_current_fatigue = result.get("afi", 0.0)

func _on_recovery_suggestion(message: String) -> void:
	if _suggestion_label:
		_suggestion_label.text = message
		_suggestion_timer = 5.0

		var suggestion_color: Color
		if _current_fatigue >= 0.8:
			suggestion_color = Color(1.0, 0.3, 0.2)
		elif _current_fatigue >= 0.5:
			suggestion_color = Color(1.0, 0.8, 0.2)
		else:
			suggestion_color = Color(0.6, 0.9, 1.0)
		_suggestion_label.add_theme_color_override("font_color", suggestion_color)

		_suggestion_label.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(_suggestion_label, "modulate:a", 1.0, 0.3)

func _update_suggestion(delta: float) -> void:
	if _suggestion_timer > 0:
		_suggestion_timer -= delta
		if _suggestion_label:
			if _suggestion_timer <= 1.0 and _suggestion_timer > 0:
				_suggestion_label.modulate.a = _suggestion_timer
			if _suggestion_timer <= 0:
				_suggestion_label.text = ""
				_suggestion_label.modulate.a = 1.0

# ============================================================
# Boss 战回调
# ============================================================

func _on_boss_fight_started(boss_node: Node) -> void:
	_is_boss_fight = true
	if _boss_hp_bar:
		_boss_hp_bar.visible = true
		if _boss_hp_bar.has_method("show_boss_bar"):
			_boss_hp_bar.show_boss_bar(boss_node)

func _on_boss_fight_ended() -> void:
	_is_boss_fight = false
	if _boss_hp_bar:
		if _boss_hp_bar.has_method("hide_boss_bar"):
			_boss_hp_bar.hide_boss_bar()
		_boss_hp_bar.visible = false

# ============================================================
# 伤害事件回调
# ============================================================

func _on_damage_dealt(data: Dictionary) -> void:
	if _damage_number_pool == null:
		return
	var damage: float = data.get("damage", 0.0)
	var pos: Vector2 = data.get("position", Vector2.ZERO)
	var is_crit: bool = data.get("is_critical", false)
	var is_perfect: bool = data.get("is_perfect_beat", false)
	var is_dissonance: bool = data.get("is_dissonance", false)

	if is_perfect:
		_damage_number_pool.spawn_perfect(damage, pos)
	elif is_crit:
		_damage_number_pool.spawn_critical(damage, pos)
	elif is_dissonance:
		_damage_number_pool.spawn_dissonance(damage, pos)
	else:
		_damage_number_pool.spawn_normal(damage, pos)

func _on_player_healed(data: Dictionary) -> void:
	if _damage_number_pool == null:
		return
	var amount: float = data.get("amount", 0.0)
	var pos: Vector2 = data.get("position", Vector2.ZERO)
	_damage_number_pool.spawn_heal(amount, pos)

## 兼容旧版接口
func show_damage_number(position: Vector2, damage: float, is_crit: bool = false, is_self_damage: bool = false) -> void:
	if _damage_number_pool:
		if is_self_damage:
			_damage_number_pool.spawn_dissonance(damage, position)
		elif is_crit:
			_damage_number_pool.spawn_critical(damage, position)
		else:
			_damage_number_pool.spawn_normal(damage, position)

# ============================================================
# 通知系统回调
# ============================================================

func _on_density_overload_signal() -> void:
	if _notification_manager and _notification_manager.has_method("show_warning"):
		_notification_manager.show_warning("DENSITY OVERLOAD",
			StatusNotification.NotificationType.DENSITY_OVERLOAD, 2.5)
	# 旧版兼容
	_overload_flash_timer = 2.0
	if _overload_warning:
		_overload_warning.visible = true

func _on_chord_progression_signal(chord_name: String) -> void:
	if _notification_manager and _notification_manager.has_method("show_info"):
		_notification_manager.show_info("CHORD PROGRESSION: %s" % chord_name,
			StatusNotification.NotificationType.CHORD_PROGRESSION, 2.0)

func _on_note_silenced_signal(note_name: String) -> void:
	if _notification_manager and _notification_manager.has_method("show_info"):
		_notification_manager.show_info("NOTE SILENCED: %s" % note_name,
			StatusNotification.NotificationType.NOTE_SILENCED, 1.5)

# ============================================================
# 密度过载 / 精准度惩罚
# ============================================================

func _on_accuracy_penalized(_penalty: float) -> void:
	_overload_flash_timer = 2.0
	if _overload_warning:
		_overload_warning.visible = true
	# 新版通知
	if _notification_manager and _notification_manager.has_method("show_warning"):
		_notification_manager.show_warning("DENSITY OVERLOAD",
			StatusNotification.NotificationType.DENSITY_OVERLOAD, 2.0)

func _update_overload_warning(delta: float) -> void:
	if _overload_flash_timer > 0:
		_overload_flash_timer -= delta
		if _overload_warning:
			_overload_warning.visible = fmod(_overload_flash_timer, 0.4) > 0.2
			if _overload_flash_timer <= 0:
				_overload_warning.visible = false

# ============================================================
# 和弦进行提示
# ============================================================

func _on_progression_resolved(progression: Dictionary) -> void:
	if _progression_label == null:
		return

	var transition: String = progression.get("transition", "")
	var effect: Dictionary = progression.get("effect", {})
	var completeness: int = progression.get("completeness", 0)

	var text := ""
	match transition:
		"D_to_T":
			text = "D -> T  %s" % effect.get("desc", "")
		"T_to_D":
			text = "T -> D  %s" % effect.get("desc", "")
		"PD_to_D":
			text = "PD -> D  %s" % effect.get("desc", "")

	if completeness >= 3:
		text += "  [%d-chain]" % completeness

	_progression_label.text = text
	_progression_label.modulate.a = 1.0
	_progression_timer = 3.0

	var tween := create_tween()
	tween.tween_property(_progression_label, "modulate", Color(1.0, 1.0, 0.5), 0.1)
	tween.tween_property(_progression_label, "modulate", Color(0.2, 1.0, 0.6), 0.3)

	# 同步到新版通知系统
	if _notification_manager and _notification_manager.has_method("show_info"):
		_notification_manager.show_info(text,
			StatusNotification.NotificationType.CHORD_PROGRESSION, 2.0)

func _update_progression_label(delta: float) -> void:
	if _progression_timer > 0:
		_progression_timer -= delta
		if _progression_label:
			_progression_label.modulate.a = clamp(_progression_timer / 1.0, 0.0, 1.0)
			if _progression_timer <= 0:
				_progression_label.text = ""
				_progression_label.modulate.a = 1.0

# ============================================================
# 单音寂静
# ============================================================

func _on_spell_blocked(_note: int) -> void:
	if _fatigue_filter and _fatigue_filter.material:
		var mat: ShaderMaterial = _fatigue_filter.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("dissonance_level", 0.5)
			var tween := create_tween()
			tween.tween_interval(0.15)
			tween.tween_callback(func():
				if mat:
					mat.set_shader_parameter("dissonance_level", 0.0)
			)

func _update_silence_indicators() -> void:
	if not FatigueManager.has_method("query_fatigue"):
		return
	var fatigue_data := FatigueManager.query_fatigue()
	var silenced: Array = fatigue_data.get("silenced_notes", [])

	var silenced_keys: Array[int] = []
	for entry in silenced:
		if entry is Dictionary:
			silenced_keys.append(int(entry.get("note", -1)))

	var game_time: float = GameManager.game_time if GameManager.get("game_time") != null else 0.0

	for i in range(min(_silence_indicators.size(), 7)):
		var white_key: int = i
		if white_key in silenced_keys:
			_silence_indicators[i].visible = true
			var alpha := 0.3 + sin(game_time * 4.0) * 0.2
			_silence_indicators[i].add_theme_color_override(
				"font_color", Color(1.0, 0.2, 0.2, alpha)
			)
			var note_name: String = ""
			if MusicData.get("WHITE_KEY_STATS") != null:
				note_name = MusicData.WHITE_KEY_STATS.get(white_key, {}).get("name", "?")
			else:
				note_name = ["C", "D", "E", "F", "G", "A", "B"][i]
			_silence_indicators[i].text = "%s [X]" % note_name
		else:
			_silence_indicators[i].visible = false

# ============================================================
# 调式信息
# ============================================================

func _on_mode_changed(_mode_id: String) -> void:
	_update_mode_display()

func _update_mode_display() -> void:
	if _mode_label == null:
		return
	if not ModeSystem.has_method("get_current_mode_info"):
		return
	var info := ModeSystem.get_current_mode_info()
	var key_names := ModeSystem.get_available_key_names()
	_mode_label.text = "%s [%s]  %s" % [
		info.get("name", ""),
		info.get("subtitle", ""),
		" ".join(key_names),
	]

	if _crit_label:
		_crit_label.visible = (ModeSystem.get("current_mode_id") == "blues")

func _on_crit_updated(crit_chance: float) -> void:
	if _crit_label:
		_crit_label.text = "Crit: %.0f%%" % (crit_chance * 100.0)

# ============================================================
# 疲劳滤镜
# ============================================================

func _setup_fatigue_filter() -> void:
	_fatigue_filter = ColorRect.new()
	_fatigue_filter.name = "FatigueFilter"
	_fatigue_filter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fatigue_filter.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fatigue_filter)

	var shader := load("res://shaders/fatigue_filter.gdshader")
	if shader:
		var material := ShaderMaterial.new()
		material.shader = shader
		_fatigue_filter.material = material

func _update_fatigue_filter() -> void:
	if _fatigue_filter == null or _fatigue_filter.material == null:
		return

	var mat: ShaderMaterial = _fatigue_filter.material as ShaderMaterial
	if mat == null:
		return

	mat.set_shader_parameter("fatigue_level", _current_fatigue)

	var tier: int = 0
	if _current_fatigue >= 0.8:
		tier = 3
	elif _current_fatigue >= 0.5:
		tier = 2
	elif _current_fatigue >= 0.3:
		tier = 1
	mat.set_shader_parameter("fatigue_tier", tier)

	# 节拍脉冲
	if GameManager.has_method("get_beat_progress"):
		var beat_progress := GameManager.get_beat_progress()
		var beat_pulse := max(0.0, 1.0 - beat_progress * 3.0)
		mat.set_shader_parameter("beat_pulse", beat_pulse * 0.3)

	# 不和谐度
	if FatigueManager.has_method("query_fatigue"):
		var fatigue_data := FatigueManager.query_fatigue()
		var dissonance_visual: float = 0.0
		var silenced_list: Array = fatigue_data.get("silenced_notes", [])
		if not silenced_list.is_empty():
			dissonance_visual = min(float(silenced_list.size()) * 0.2, 1.0)
		mat.set_shader_parameter("dissonance_level", dissonance_visual)

	# 密度过载
	var density_overload: float = 0.0
	if FatigueManager.get("is_density_overloaded") and FatigueManager.is_density_overloaded:
		density_overload = 1.0 - FatigueManager.current_density_damage_multiplier
	mat.set_shader_parameter("density_overload", density_overload)

# ============================================================
# 节拍响应
# ============================================================

func _on_beat_tick(_beat_index: int) -> void:
	pass  # 节拍响应由各子组件自行处理

# ============================================================
# 留白奖励
# ============================================================

func _on_rest_cleanse(rest_count: int) -> void:
	if _progression_label:
		_progression_label.text = "~ 留白清洗 x%d ~" % rest_count
		_progression_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
		_progression_label.modulate.a = 1.0
		_progression_timer = 2.0

		var tween := create_tween()
		tween.tween_property(_progression_label, "modulate", Color(0.4, 0.9, 1.0), 0.15)
		tween.tween_property(_progression_label, "modulate", Color(0.2, 1.0, 0.6), 0.4)
		tween.tween_callback(func():
			if _progression_label:
				_progression_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.6))
		)

	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_rest_cleanse_sfx"):
		audio_mgr.play_rest_cleanse_sfx()

	if _fatigue_filter and _fatigue_filter.material:
		var mat: ShaderMaterial = _fatigue_filter.material as ShaderMaterial
		if mat:
			var prev_fatigue = mat.get_shader_parameter("fatigue_level")
			mat.set_shader_parameter("fatigue_level", max(0.0, prev_fatigue - 0.1))
			var tween2 := create_tween()
			tween2.tween_interval(0.3)
			tween2.tween_callback(func():
				if mat:
					mat.set_shader_parameter("fatigue_level", _current_fatigue)
			)

# ============================================================
# 经验条 UI
# ============================================================

func _setup_xp_bar() -> void:
	_xp_bar_container = Control.new()
	_xp_bar_container.name = "XPBarContainer"
	_xp_bar_container.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_xp_bar_container.offset_top = -28.0
	_xp_bar_container.offset_bottom = 0.0
	_xp_bar_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_xp_bar_container)

	_xp_bar_bg = ColorRect.new()
	_xp_bar_bg.name = "XPBarBG"
	_xp_bar_bg.color = Color(0.05, 0.05, 0.1, 0.7)
	_xp_bar_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_xp_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_xp_bar_container.add_child(_xp_bar_bg)

	_xp_bar_fill = ColorRect.new()
	_xp_bar_fill.name = "XPBarFill"
	_xp_bar_fill.color = Color(0.0, 0.9, 0.8, 0.85)
	_xp_bar_fill.anchor_top = 0.0
	_xp_bar_fill.anchor_bottom = 1.0
	_xp_bar_fill.anchor_left = 0.0
	_xp_bar_fill.anchor_right = 0.0
	_xp_bar_fill.offset_top = 2.0
	_xp_bar_fill.offset_bottom = -2.0
	_xp_bar_fill.offset_left = 2.0
	_xp_bar_fill.offset_right = 0.0
	_xp_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_xp_bar_container.add_child(_xp_bar_fill)

	_xp_bar_label = Label.new()
	_xp_bar_label.name = "XPBarLabel"
	_xp_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_xp_bar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_xp_bar_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_xp_bar_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))
	_xp_bar_label.add_theme_font_size_override("font_size", 13)
	_xp_bar_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	_xp_bar_label.add_theme_constant_override("shadow_offset_x", 1)
	_xp_bar_label.add_theme_constant_override("shadow_offset_y", 1)
	_xp_bar_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_xp_bar_container.add_child(_xp_bar_label)

	_xp_display_ratio = 0.0
	_update_xp_bar_text()

func _update_xp_bar(delta: float) -> void:
	if _xp_bar_fill == null or _xp_bar_container == null:
		return

	var target_ratio: float = 0.0
	var xp_to_next: int = GameManager.xp_to_next_level if GameManager.get("xp_to_next_level") != null else 100
	var player_xp: int = GameManager.player_xp if GameManager.get("player_xp") != null else 0
	if xp_to_next > 0:
		target_ratio = float(player_xp) / float(xp_to_next)
	target_ratio = clamp(target_ratio, 0.0, 1.0)

	_xp_display_ratio = lerp(_xp_display_ratio, target_ratio, delta * 10.0)
	_xp_bar_fill.anchor_right = _xp_display_ratio
	_xp_bar_fill.offset_right = -2.0

	var player_level: int = GameManager.player_level if GameManager.get("player_level") != null else 1
	var level_color_t: float = clamp(float(player_level - 1) / 20.0, 0.0, 1.0)
	var base_color := Color(0.0, 0.9, 0.8).lerp(Color(1.0, 0.85, 0.2), level_color_t)

	if _xp_flash_timer > 0.0:
		_xp_flash_timer -= delta
		var flash_intensity: float = clamp(_xp_flash_timer / 0.3, 0.0, 1.0)
		base_color = base_color.lerp(Color.WHITE, flash_intensity * 0.5)

	if _levelup_flash_timer > 0.0:
		_levelup_flash_timer -= delta
		var flash_intensity: float = clamp(_levelup_flash_timer / 0.5, 0.0, 1.0)
		base_color = base_color.lerp(Color(1.0, 1.0, 0.5), flash_intensity * 0.8)
		if _xp_bar_bg:
			_xp_bar_bg.color = Color(0.05, 0.05, 0.1, 0.7).lerp(
				Color(0.2, 0.2, 0.1, 0.9), flash_intensity * 0.5
			)
	else:
		if _xp_bar_bg:
			_xp_bar_bg.color = Color(0.05, 0.05, 0.1, 0.7)

	_xp_bar_fill.color = base_color
	_update_xp_bar_text()

func _update_xp_bar_text() -> void:
	if _xp_bar_label == null:
		return
	var player_level: int = GameManager.player_level if GameManager.get("player_level") != null else 1
	var player_xp: int = GameManager.player_xp if GameManager.get("player_xp") != null else 0
	var xp_to_next: int = GameManager.xp_to_next_level if GameManager.get("xp_to_next_level") != null else 100
	_xp_bar_label.text = "Lv.%d   %d / %d XP" % [player_level, player_xp, xp_to_next]

func _on_xp_gained(_amount: int) -> void:
	_xp_flash_timer = 0.3

func _on_level_up(_new_level: int) -> void:
	_levelup_flash_timer = 0.5
	_xp_display_ratio = 0.0

# ============================================================
# 公共接口
# ============================================================

func get_hp_bar() -> Control:
	return _hp_bar

func get_fatigue_meter() -> Control:
	return _fatigue_meter

func get_boss_hp_bar() -> Control:
	return _boss_hp_bar

func get_manual_cast_slots() -> Control:
	return _manual_cast_slots

func get_info_panel() -> Control:
	return _info_panel

func get_summon_hud() -> Control:
	return _summon_hud

func get_damage_number_pool() -> Node2D:
	return _damage_number_pool

func get_notification_manager() -> CanvasLayer:
	return _notification_manager

func get_rhythm_indicator() -> Control:
	return _rhythm_indicator

func get_ammo_ring() -> Node2D:
	return _ammo_ring

## 显示/隐藏整个 HUD
func set_hud_visible(is_visible: bool) -> void:
	_hud_visible = is_visible
	visible = is_visible
	if _damage_number_layer:
		_damage_number_layer.visible = is_visible
	if _notification_manager:
		_notification_manager.visible = is_visible
	hud_visibility_changed.emit(is_visible)

## 启用 DPS 覆盖层（仅测试场）
func enable_dps_overlay() -> void:
	if _dps_overlay != null:
		return
	var script := load("res://scripts/ui/dps_overlay.gd")
	if script:
		_dps_overlay = CanvasLayer.new()
		_dps_overlay.set_script(script)
		_dps_overlay.name = "DPSOverlay"
		add_child(_dps_overlay)

## 禁用 DPS 覆盖层
func disable_dps_overlay() -> void:
	if _dps_overlay:
		_dps_overlay.queue_free()
		_dps_overlay = null

## 快捷方法：生成伤害数字
func spawn_damage_number_v2(damage: float, pos: Vector2, type: int = 0) -> void:
	if _damage_number_pool and _damage_number_pool.has_method("spawn_damage"):
		_damage_number_pool.spawn_damage(damage, pos, type as DamageNumber.DamageType)

## 快捷方法：显示通知
func show_notification(text: String, type: int = 4, duration: float = 2.0) -> void:
	if _notification_manager and _notification_manager.has_method("show_info"):
		_notification_manager.show_info(text, type as StatusNotification.NotificationType, duration)
