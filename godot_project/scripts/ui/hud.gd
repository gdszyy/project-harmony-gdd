## hud.gd
## 游戏 HUD 界面
## 包含：谐振完整度(血条)、疲劳度仪表、BPM显示、
## 手动施法槽、伤害数字、恢复建议
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
# 状态
# ============================================================
var _current_hp_ratio: float = 1.0
var _current_fatigue: float = 0.0
var _suggestion_timer: float = 0.0
var _damage_numbers: Array[Dictionary] = []

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

	_setup_fatigue_filter()

func _process(delta: float) -> void:
	_update_info_labels()
	_update_damage_numbers(delta)
	
	# 从 FatigueManager 读取最新 AFI
	_current_fatigue = FatigueManager.current_afi
	_update_fatigue_filter()

	# 建议文字淡出
	if _suggestion_timer > 0:
		_suggestion_timer -= delta
		if _suggestion_timer <= 0 and _suggestion_label:
			_suggestion_label.text = ""

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
