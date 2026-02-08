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

	for i in range(min(_silence_indicators.size(), 7)):
		var white_key: int = i  # WhiteKey 枚举 0-6 对应 C-B
		if white_key in silenced:
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
		var beat_pulse := max(0.0, 1.0 - beat_progress * 3.0)
		mat.set_shader_parameter("beat_pulse", beat_pulse * 0.3)

		# 不和谐度视觉效果
		var fatigue_data := FatigueManager.query_fatigue()
		var dissonance_visual: float = 0.0
		var silenced := fatigue_data.get("silenced_notes", [])
		if not silenced.is_empty():
			dissonance_visual = min(float(silenced.size()) * 0.2, 1.0)
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
			var prev_fatigue := mat.get_shader_parameter("fatigue_level")
			mat.set_shader_parameter("fatigue_level", max(0.0, prev_fatigue - 0.1))
			var tween2 := create_tween()
			tween2.tween_interval(0.3)
			tween2.tween_callback(func():
				if mat:
					mat.set_shader_parameter("fatigue_level", _current_fatigue)
			)
