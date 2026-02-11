## hud.gd
## 游戏 HUD 界面 (v3.0)
## 包含：谐振完整度(血条)、疲劳度仪表、BPM显示、
## 手动施法槽(含冷却UI)、伤害数字、恢复建议、
## 单音寂静灰化指示、密度过载警告、和弦进行提示、调式信息
extends CanvasLayer

# ============================================================
# 节点引用
# ============================================================
@onready var _hp_bar: Control = $HPBar
@onready var _fatigue_bar: Control = $FatigueBar
@onready var _bpm_label: Label = $InfoPanel/BPMLabel
@onready var _time_label: Label = $InfoPanel/TimeLabel
@onready var _level_label: Label = $InfoPanel/LevelLabel
@onready var _enemy_count_label: Label = $InfoPanel/EnemyCountLabel
@onready var _suggestion_label: Label = $SuggestionPanel/SuggestionLabel
@onready var _sequencer_ui: Control = $SequencerPanel
@onready var _manual_slots: Control = $ManualSlots
@onready var _fatigue_filter: ColorRect = $FatigueFilter

# ============================================================
# 动态创建的 UI 元素
# ============================================================
## 手动施法槽冷却覆盖层
var _slot_cooldown_overlays: Array[ColorRect] = []
## 单音寂静指示器（7个白键对应的灰化标记）
var _silence_indicators: Array[Label] = []
## 密度过载警告标签
var _overload_warning: Label = null
## 和弦进行提示标签
var _progression_label: Label = null
## 调式信息标签
var _mode_label: Label = null
## 暴击率标签（布鲁斯调式）
var _crit_label: Label = null
## 经验条容器
var _xp_bar_container: Control = null
## 经验条背景
var _xp_bar_bg: ColorRect = null
## 经验条填充
var _xp_bar_fill: ColorRect = null
## 经验条文字
var _xp_bar_label: Label = null
## 经验条闪光效果
var _xp_flash_timer: float = 0.0
## 经验条当前显示比例（用于平滑动画）
var _xp_display_ratio: float = 0.0
## 升级闪光计时器
var _levelup_flash_timer: float = 0.0

# ============================================================
# 状态
# ============================================================
var _current_hp_ratio: float = 1.0
var _current_fatigue: float = 0.0
var _suggestion_timer: float = 0.0
var _damage_numbers: Array[Dictionary] = []
var _progression_timer: float = 0.0
var _overload_flash_timer: float = 0.0

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	layer = 10  # 确保在最上层

	# 连接信号
	GameManager.player_hp_changed.connect(_on_hp_changed)
	GameManager.beat_tick.connect(_on_beat_tick)
	GameManager.xp_gained.connect(_on_xp_gained)
	GameManager.level_up.connect(_on_level_up)
	FatigueManager.fatigue_updated.connect(_on_fatigue_updated)
	FatigueManager.recovery_suggestion.connect(_on_recovery_suggestion)

	# 连接 SpellcraftSystem 信号
	if SpellcraftSystem.has_signal("spell_blocked_by_silence"):
		SpellcraftSystem.spell_blocked_by_silence.connect(_on_spell_blocked)
	if SpellcraftSystem.has_signal("accuracy_penalized"):
		SpellcraftSystem.accuracy_penalized.connect(_on_accuracy_penalized)
	if SpellcraftSystem.has_signal("progression_resolved"):
		SpellcraftSystem.progression_resolved.connect(_on_progression_resolved)

	# 连接调式系统信号
	if ModeSystem.has_signal("mode_changed"):
		ModeSystem.mode_changed.connect(_on_mode_changed)
	if ModeSystem.has_signal("crit_from_dissonance"):
		ModeSystem.crit_from_dissonance.connect(_on_crit_updated)

	# 连接留白奖励信号
	if FatigueManager.has_signal("rest_cleanse_triggered"):
		FatigueManager.rest_cleanse_triggered.connect(_on_rest_cleanse)

	_setup_fatigue_filter()
	_setup_dynamic_ui()

func _process(delta: float) -> void:
	_update_info_labels()
	_update_damage_numbers(delta)
	_update_manual_slot_cooldowns()
	_update_silence_indicators()
	_update_xp_bar(delta)

	# 从 FatigueManager 读取最新 AFI
	_current_fatigue = FatigueManager.current_afi
	_update_fatigue_filter()

	# 建议文字淡出
	if _suggestion_timer > 0:
		_suggestion_timer -= delta
		if _suggestion_timer <= 0 and _suggestion_label:
			_suggestion_label.text = ""

	# 和弦进行提示淡出
	if _progression_timer > 0:
		_progression_timer -= delta
		if _progression_label:
			_progression_label.modulate.a = clamp(_progression_timer / 1.0, 0.0, 1.0)
			if _progression_timer <= 0:
				_progression_label.text = ""
				_progression_label.modulate.a = 1.0

	# 密度过载闪烁
	if _overload_flash_timer > 0:
		_overload_flash_timer -= delta
		if _overload_warning:
			_overload_warning.visible = fmod(_overload_flash_timer, 0.4) > 0.2
			if _overload_flash_timer <= 0:
				_overload_warning.visible = false

# ============================================================
# 动态 UI 初始化
# ============================================================

func _setup_dynamic_ui() -> void:
	_setup_slot_cooldown_overlays()
	_setup_silence_indicators()
	_setup_overload_warning()
	_setup_progression_label()
	_setup_mode_label()
	_setup_crit_label()
	_setup_xp_bar()

## 手动施法槽冷却覆盖层
func _setup_slot_cooldown_overlays() -> void:
	if _manual_slots == null:
		return
	for i in range(SpellcraftSystem.MAX_MANUAL_SLOTS):
		var overlay := ColorRect.new()
		overlay.name = "CooldownOverlay_%d" % i
		overlay.color = Color(0.1, 0.1, 0.1, 0.6)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.visible = false
		# 尺寸将在 _update_manual_slot_cooldowns 中动态设置
		overlay.custom_minimum_size = Vector2(60, 60)
		overlay.size = Vector2(60, 60)
		_manual_slots.add_child(overlay)
		_slot_cooldown_overlays.append(overlay)

## 单音寂静指示器（显示在序列器旁边）
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
		add_child(indicator)
		_silence_indicators.append(indicator)

## 密度过载警告
func _setup_overload_warning() -> void:
	_overload_warning = Label.new()
	_overload_warning.name = "OverloadWarning"
	_overload_warning.text = "⚠ 密度过载 — 精准度下降"
	_overload_warning.add_theme_color_override("font_color", Color(1.0, 0.3, 0.1))
	_overload_warning.add_theme_font_size_override("font_size", 18)
	_overload_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overload_warning.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_overload_warning.position.y = 80
	_overload_warning.visible = false
	add_child(_overload_warning)

## 和弦进行提示
func _setup_progression_label() -> void:
	_progression_label = Label.new()
	_progression_label.name = "ProgressionLabel"
	_progression_label.text = ""
	_progression_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.6))
	_progression_label.add_theme_font_size_override("font_size", 22)
	_progression_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progression_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_progression_label.position.y = 110
	add_child(_progression_label)

## 调式信息标签
func _setup_mode_label() -> void:
	_mode_label = Label.new()
	_mode_label.name = "ModeLabel"
	_mode_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9, 0.8))
	_mode_label.add_theme_font_size_override("font_size", 12)
	_mode_label.position = Vector2(10, 5)
	_update_mode_display()
	add_child(_mode_label)

## 暴击率标签（布鲁斯调式专用）
func _setup_crit_label() -> void:
	_crit_label = Label.new()
	_crit_label.name = "CritLabel"
	_crit_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2, 0.9))
	_crit_label.add_theme_font_size_override("font_size", 14)
	_crit_label.position = Vector2(10, 22)
	_crit_label.visible = false
	add_child(_crit_label)

# ============================================================
# 血条 (谐振完整度)
# ============================================================

func _on_hp_changed(current_hp: float, max_hp: float) -> void:
	_current_hp_ratio = current_hp / max_hp

func _draw_hp_bar() -> void:
	if _hp_bar == null:
		return
	# 血条由 HPBar 子节点的 _draw 处理
	_hp_bar.queue_redraw()

# ============================================================
# 疲劳度
# ============================================================

func _on_fatigue_updated(result: Dictionary) -> void:
	_current_fatigue = result.get("afi", 0.0)

func _on_recovery_suggestion(message: String) -> void:
	if _suggestion_label:
		_suggestion_label.text = message
		_suggestion_timer = 4.0

# ============================================================
# 信息面板
# ============================================================

func _update_info_labels() -> void:
	if _bpm_label:
		_bpm_label.text = "BPM: %d" % int(GameManager.current_bpm)

	if _time_label:
		var minutes := int(GameManager.game_time) / 60
		var seconds := int(GameManager.game_time) % 60
		_time_label.text = "%02d:%02d" % [minutes, seconds]

	if _level_label:
		_level_label.text = "Lv.%d" % GameManager.player_level

# ============================================================
# 手动施法槽冷却 UI
# ============================================================

func _update_manual_slot_cooldowns() -> void:
	for i in range(min(_slot_cooldown_overlays.size(), SpellcraftSystem.MAX_MANUAL_SLOTS)):
		var progress := SpellcraftSystem.get_manual_slot_cooldown_progress(i)
		var overlay := _slot_cooldown_overlays[i]
		if progress > 0.01:
			overlay.visible = true
			# 从上到下缩小覆盖层，表示冷却进度
			overlay.size.y = 60.0 * progress
		else:
			overlay.visible = false

# ============================================================
# 单音寂静灰化指示
# ============================================================

func _update_silence_indicators() -> void:
	var fatigue_data := FatigueManager.query_fatigue()
	var silenced: Array = fatigue_data.get("silenced_notes", [])

	# 提取被寂静的音符 key 列表（silenced 是 [{"note": key, "remaining": float}] 结构）
	var silenced_keys: Array[int] = []
	for entry in silenced:
		if entry is Dictionary:
			silenced_keys.append(int(entry.get("note", -1)))

	for i in range(min(_silence_indicators.size(), 7)):
		var white_key: int = i  # WhiteKey 枚举 0-6 对应 C-B
		if white_key in silenced_keys:
			_silence_indicators[i].visible = true
			# 闪烁效果
			var alpha := 0.3 + sin(GameManager.game_time * 4.0) * 0.2
			_silence_indicators[i].add_theme_color_override(
				"font_color", Color(1.0, 0.2, 0.2, alpha)
			)
			_silence_indicators[i].text = MusicData.WHITE_KEY_STATS.get(white_key, {}).get("name", "?") + " [X]"
		else:
			_silence_indicators[i].visible = false

# ============================================================
# 密度过载警告
# ============================================================

func _on_accuracy_penalized(_penalty: float) -> void:
	_overload_flash_timer = 2.0
	if _overload_warning:
		_overload_warning.visible = true

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

	# 闪烁动画
	var tween := create_tween()
	tween.tween_property(_progression_label, "modulate", Color(1.0, 1.0, 0.5), 0.1)
	tween.tween_property(_progression_label, "modulate", Color(0.2, 1.0, 0.6), 0.3)

# ============================================================
# 单音寂静阻止反馈
# ============================================================

func _on_spell_blocked(_note: int) -> void:
	# 屏幕微震 + 红色闪烁
	if _fatigue_filter and _fatigue_filter.material:
		var mat: ShaderMaterial = _fatigue_filter.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("dissonance_level", 0.5)
			# 短暂恢复
			var tween := create_tween()
			tween.tween_interval(0.15)
			tween.tween_callback(func():
				if mat:
					mat.set_shader_parameter("dissonance_level", 0.0)
			)

# ============================================================
# 调式信息显示
# ============================================================

func _on_mode_changed(_mode_id: String) -> void:
	_update_mode_display()

func _update_mode_display() -> void:
	if _mode_label == null:
		return
	var info := ModeSystem.get_current_mode_info()
	var key_names := ModeSystem.get_available_key_names()
	_mode_label.text = "%s [%s]  %s" % [
		info.get("name", ""),
		info.get("subtitle", ""),
		" ".join(key_names),
	]

	# 布鲁斯调式显示暴击率
	if _crit_label:
		_crit_label.visible = (ModeSystem.current_mode_id == "blues")

func _on_crit_updated(crit_chance: float) -> void:
	if _crit_label:
		_crit_label.text = "Crit: %.0f%%" % (crit_chance * 100.0)

# ============================================================
# 疲劳滤镜
# ============================================================

func _setup_fatigue_filter() -> void:
	if _fatigue_filter == null:
		_fatigue_filter = ColorRect.new()
		_fatigue_filter.name = "FatigueFilter"
		_fatigue_filter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_fatigue_filter)

	# 设置全屏
	_fatigue_filter.set_anchors_preset(Control.PRESET_FULL_RECT)

	# 加载疲劳滤镜 Shader
	var shader := load("res://shaders/fatigue_filter.gdshader")
	if shader:
		var material := ShaderMaterial.new()
		material.shader = shader
		_fatigue_filter.material = material

func _update_fatigue_filter() -> void:
	if _fatigue_filter == null or _fatigue_filter.material == null:
		return

	var mat: ShaderMaterial = _fatigue_filter.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("fatigue_level", _current_fatigue)

		# 节拍脉冲
		var beat_progress := GameManager.get_beat_progress()
		var beat_pulse = max(0.0, 1.0 - beat_progress * 3.0)
		mat.set_shader_parameter("beat_pulse", beat_pulse * 0.3)

		# 不和谐度视觉效果
		var fatigue_data := FatigueManager.query_fatigue()
		var dissonance_visual: float = 0.0
		var silenced_list: Array = fatigue_data.get("silenced_notes", [])
		if not silenced_list.is_empty():
			dissonance_visual = min(float(silenced_list.size()) * 0.2, 1.0)
		mat.set_shader_parameter("dissonance_level", dissonance_visual)

# ============================================================
# 节拍响应
# ============================================================

func _on_beat_tick(_beat_index: int) -> void:
	# BPM标签闪烁
	if _bpm_label:
		var tween := create_tween()
		tween.tween_property(_bpm_label, "modulate", Color(0.0, 1.0, 0.8), 0.05)
		tween.tween_property(_bpm_label, "modulate", Color.WHITE, 0.2)

# ============================================================
# 伤害数字
# ============================================================

func show_damage_number(position: Vector2, damage: float, is_crit: bool = false, is_self_damage: bool = false) -> void:
	_damage_numbers.append({
		"position": position,
		"damage": damage,
		"is_crit": is_crit,
		"is_self_damage": is_self_damage,
		"time": 0.0,
		"duration": 0.8,
	})

func _update_damage_numbers(delta: float) -> void:
	var to_remove: Array[int] = []

	for i in range(_damage_numbers.size()):
		var dn := _damage_numbers[i]
		dn["time"] += delta
		dn["position"].y -= 40.0 * delta  # 上浮

		if dn["time"] >= dn["duration"]:
			to_remove.append(i)

	# 从后向前移除
	for i in range(to_remove.size() - 1, -1, -1):
		_damage_numbers.remove_at(to_remove[i])

# ============================================================
# 留白奖励视觉反馈
# ============================================================

func _on_rest_cleanse(rest_count: int) -> void:
	# 显示清洗提示
	if _progression_label:
		_progression_label.text = "~ 留白清洗 x%d ~" % rest_count
		_progression_label.add_theme_color_override("font_color", Color(0.4, 0.9, 1.0))
		_progression_label.modulate.a = 1.0
		_progression_timer = 2.0

		# 动画：柔和的脉冲
		var tween := create_tween()
		tween.tween_property(_progression_label, "modulate", Color(0.4, 0.9, 1.0), 0.15)
		tween.tween_property(_progression_label, "modulate", Color(0.2, 1.0, 0.6), 0.4)
		# 恢复默认颜色
		tween.tween_callback(func():
			if _progression_label:
				_progression_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.6))
		)

	# 播放清洗音效
	var audio_mgr := get_node_or_null("/root/AudioManager")
	if audio_mgr and audio_mgr.has_method("play_rest_cleanse_sfx"):
		audio_mgr.play_rest_cleanse_sfx()

	# 疲劳滤镜短暂变亮（表示恢复）
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
# 经验条 UI (Issue #37)
# ============================================================

## 初始化经验条 UI 组件
func _setup_xp_bar() -> void:
	# 容器：屏幕底部中央
	_xp_bar_container = Control.new()
	_xp_bar_container.name = "XPBarContainer"
	_xp_bar_container.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_xp_bar_container.offset_top = -28.0
	_xp_bar_container.offset_bottom = 0.0
	_xp_bar_container.offset_left = 0.0
	_xp_bar_container.offset_right = 0.0
	_xp_bar_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_xp_bar_container)

	# 背景条：深色半透明
	_xp_bar_bg = ColorRect.new()
	_xp_bar_bg.name = "XPBarBG"
	_xp_bar_bg.color = Color(0.05, 0.05, 0.1, 0.7)
	_xp_bar_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_xp_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_xp_bar_container.add_child(_xp_bar_bg)

	# 填充条：青色渐变
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

	# 经验值文字标签
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

	# 初始化显示
	_xp_display_ratio = 0.0
	_update_xp_bar_text()

## 每帧更新经验条
func _update_xp_bar(delta: float) -> void:
	if _xp_bar_fill == null or _xp_bar_container == null:
		return

	# 计算目标比例
	var target_ratio: float = 0.0
	if GameManager.xp_to_next_level > 0:
		target_ratio = float(GameManager.player_xp) / float(GameManager.xp_to_next_level)
	target_ratio = clamp(target_ratio, 0.0, 1.0)

	# 平滑插值
	_xp_display_ratio = lerp(_xp_display_ratio, target_ratio, delta * 10.0)

	# 更新填充条宽度（使用 anchor_right 控制比例）
	_xp_bar_fill.anchor_right = _xp_display_ratio
	_xp_bar_fill.offset_right = -2.0

	# 经验条颜色随等级渐变：青色 → 金色
	var level_color_t: float = clamp(float(GameManager.player_level - 1) / 20.0, 0.0, 1.0)
	var base_color := Color(0.0, 0.9, 0.8).lerp(Color(1.0, 0.85, 0.2), level_color_t)

	# 获取经验闪光效果
	if _xp_flash_timer > 0.0:
		_xp_flash_timer -= delta
		var flash_intensity := clamp(_xp_flash_timer / 0.3, 0.0, 1.0)
		base_color = base_color.lerp(Color.WHITE, flash_intensity * 0.5)

	# 升级闪光效果
	if _levelup_flash_timer > 0.0:
		_levelup_flash_timer -= delta
		var flash_intensity := clamp(_levelup_flash_timer / 0.5, 0.0, 1.0)
		base_color = base_color.lerp(Color(1.0, 1.0, 0.5), flash_intensity * 0.8)
		# 背景也闪光
		if _xp_bar_bg:
			_xp_bar_bg.color = Color(0.05, 0.05, 0.1, 0.7).lerp(
				Color(0.2, 0.2, 0.1, 0.9), flash_intensity * 0.5
			)
	else:
		if _xp_bar_bg:
			_xp_bar_bg.color = Color(0.05, 0.05, 0.1, 0.7)

	_xp_bar_fill.color = base_color

	# 更新文字
	_update_xp_bar_text()

## 更新经验条文字
func _update_xp_bar_text() -> void:
	if _xp_bar_label == null:
		return
	_xp_bar_label.text = "Lv.%d   %d / %d XP" % [
		GameManager.player_level,
		GameManager.player_xp,
		GameManager.xp_to_next_level,
	]

## 经验获取回调
func _on_xp_gained(_amount: int) -> void:
	_xp_flash_timer = 0.3

## 升级回调
func _on_level_up(_new_level: int) -> void:
	_levelup_flash_timer = 0.5
	# 重置经验条显示比例（升级后经验重置）
	_xp_display_ratio = 0.0
	# 更新等级标签
	if _level_label:
		_level_label.text = "Lv.%d" % _new_level
		# 等级数字跳动效果
		var tween := create_tween()
		tween.tween_property(_level_label, "scale", Vector2(1.3, 1.3), 0.1)
		tween.tween_property(_level_label, "scale", Vector2(1.0, 1.0), 0.2)
