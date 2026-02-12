## harmonic_avatar_manager.gd
## 谐振调式化身管理器 (Issue #59)
##
## 统一管理玩家角色的程序化化身系统：
##   1. 管理 AbstractSkeleton（指挥家骨架）
##   2. 管理四种调式几何体的创建、切换和销毁
##   3. 将几何体附着到骨骼的 BoneAttachment3D 锚点
##   4. 响应游戏事件（施法、受击、节拍）并分发到当前调式
##   5. 与 CharacterClassManager 和 SpellcraftSystem 集成
##
## 挂载方式：作为玩家节点的子节点（或 SubViewport 中的 3D 场景根节点）
extends Node3D

class_name HarmonicAvatarManager

# ============================================================
# 信号
# ============================================================
signal mode_changed(old_mode_id: int, new_mode_id: int)
signal avatar_ready()
signal spellcast_visual_triggered(gesture_name: String)

# ============================================================
# 配置
# ============================================================
## 当前调式 ID (0=Ionian, 1=Locrian, 2=Lydian, 3=Phrygian)
@export var initial_mode_id: int = 0
## 调式切换过渡时间
@export var mode_transition_duration: float = 0.5
## 是否启用骨骼动画
@export var skeleton_enabled: bool = true
## 是否启用 3D 渲染（false 时仅作为数据管理器）
@export var rendering_enabled: bool = true

# ============================================================
# 调式映射
# ============================================================
const MODE_NAMES: Dictionary = {
	0: "ionian",
	1: "locrian",
	2: "lydian",
	3: "phrygian",
}

# 调式骨骼参数配置
const MODE_SKELETON_CONFIG: Dictionary = {
	0: {  # Ionian
		"bpm_sync_multiplier": 1.0,
		"animation_speed_multiplier": 1.0,
		"motion_amplitude": 1.0,
		"gesture_blend_time": 0.15,
	},
	1: {  # Locrian
		"bpm_sync_multiplier": 1.0,  # 实际在 0.8-1.2 间随机波动
		"animation_speed_multiplier": 1.0,
		"motion_amplitude": 1.0,
		"gesture_blend_time": 0.05,  # 更突兀的过渡
	},
	2: {  # Lydian
		"bpm_sync_multiplier": 1.0,
		"animation_speed_multiplier": 0.8,  # 更缓慢飘逸
		"motion_amplitude": 1.2,  # 更大幅度
		"gesture_blend_time": 0.3,  # 更长的混合时间
	},
	3: {  # Phrygian
		"bpm_sync_multiplier": 1.0,
		"animation_speed_multiplier": 1.5,  # 更快速
		"motion_amplitude": 0.9,
		"gesture_blend_time": 0.08,  # 快速切换
	},
}

# 手势到法术类型的映射
const SPELL_GESTURE_MAP: Dictionary = {
	"projectile": "Point",
	"aoe": "DrawCircle",
	"summon": "Raise",
	"shockwave": "Push",
	"scatter": "Flick",
}

# ============================================================
# 节点引用
# ============================================================
var _skeleton: AbstractSkeleton = null
var _current_mode_node: Node3D = null
var _mode_id: int = 0

# ============================================================
# 状态
# ============================================================
var _is_transitioning: bool = false
var _transition_tween: Tween = null
var _initialized: bool = false

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_mode_id = initial_mode_id
	_setup_skeleton()
	_setup_mode(initial_mode_id)
	_connect_game_signals()
	_initialized = true
	avatar_ready.emit()

func _process(_delta: float) -> void:
	if not _initialized:
		return

	# 洛克里亚式的 BPM 随机偏移
	if _mode_id == 1 and _skeleton:
		_skeleton.bpm_sync_multiplier = randf_range(0.8, 1.2)

# ============================================================
# 骨骼设置
# ============================================================

func _setup_skeleton() -> void:
	if not skeleton_enabled:
		return

	_skeleton = AbstractSkeleton.new()
	_skeleton.name = "AbstractSkeleton"
	add_child(_skeleton)

	# 连接骨骼信号
	_skeleton.gesture_started.connect(_on_gesture_started)
	_skeleton.gesture_finished.connect(_on_gesture_finished)

## 根据调式配置骨骼参数
func _configure_skeleton_for_mode(mode_id: int) -> void:
	if _skeleton == null:
		return

	var config: Dictionary = MODE_SKELETON_CONFIG.get(mode_id, MODE_SKELETON_CONFIG[0])
	_skeleton.bpm_sync_multiplier = config.get("bpm_sync_multiplier", 1.0)
	_skeleton.animation_speed_multiplier = config.get("animation_speed_multiplier", 1.0)
	_skeleton.motion_amplitude = config.get("motion_amplitude", 1.0)
	_skeleton.gesture_blend_time = config.get("gesture_blend_time", 0.15)

	# 洛克里亚式启用毛刺修改器
	if mode_id == 1:
		_skeleton.set_glitch_intensity(0.3)
	else:
		_skeleton.set_glitch_intensity(0.0)

# ============================================================
# 调式设置与切换
# ============================================================

## 设置指定调式的几何体
func _setup_mode(mode_id: int) -> void:
	# 清除旧的调式节点
	if _current_mode_node:
		_current_mode_node.queue_free()
		_current_mode_node = null

	# 创建新的调式节点
	match mode_id:
		0:
			_current_mode_node = IonianMode.new()
		1:
			_current_mode_node = LocrianMode.new()
		2:
			_current_mode_node = LydianMode.new()
		3:
			_current_mode_node = PhrygianMode.new()

	if _current_mode_node:
		_current_mode_node.name = "ModeGeometry_%s" % MODE_NAMES.get(mode_id, "unknown")

		# 将几何体附着到骨骼的 torso 锚点
		if _skeleton:
			var core_attach := _skeleton.get_core_attachment()
			if core_attach:
				core_attach.add_child(_current_mode_node)
			else:
				add_child(_current_mode_node)
		else:
			add_child(_current_mode_node)

	# 配置骨骼参数
	_configure_skeleton_for_mode(mode_id)

## 切换调式（带过渡动画）
func switch_mode(new_mode_id: int) -> void:
	if new_mode_id == _mode_id:
		return
	if _is_transitioning:
		return

	var old_mode_id := _mode_id
	_is_transitioning = true

	# 淡出当前调式
	if _transition_tween:
		_transition_tween.kill()

	_transition_tween = create_tween()
	_transition_tween.set_ease(Tween.EASE_IN_OUT)
	_transition_tween.set_trans(Tween.TRANS_CUBIC)

	# 缩小并淡出
	if _current_mode_node:
		_transition_tween.tween_property(_current_mode_node, "scale",
			Vector3.ZERO, mode_transition_duration * 0.4)

	# 切换
	_transition_tween.tween_callback(func():
		_mode_id = new_mode_id
		_setup_mode(new_mode_id)
	)

	# 放大并淡入
	_transition_tween.tween_callback(func():
		if _current_mode_node:
			_current_mode_node.scale = Vector3.ZERO
	)
	_transition_tween.tween_property(self, "_transition_scale_helper",
		1.0, mode_transition_duration * 0.6).from(0.0)

	_transition_tween.tween_callback(func():
		_is_transitioning = false
		mode_changed.emit(old_mode_id, new_mode_id)
	)

## 过渡缩放辅助属性
var _transition_scale_helper: float = 1.0:
	set(value):
		_transition_scale_helper = value
		if _current_mode_node:
			_current_mode_node.scale = Vector3.ONE * value

# ============================================================
# 游戏事件响应
# ============================================================

## 连接游戏系统信号
func _connect_game_signals() -> void:
	# 连接 GameManager 节拍信号
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_signal("beat_tick"):
		gm.beat_tick.connect(_on_beat_tick)

	# 连接 SpellcraftSystem 施法信号
	var ss = get_node_or_null("/root/SpellcraftSystem")
	if ss:
		if ss.has_signal("spell_cast"):
			ss.spell_cast.connect(_on_spell_cast)
		if ss.has_signal("chord_cast"):
			ss.chord_cast.connect(_on_chord_cast)
		if ss.has_signal("manual_cast"):
			ss.manual_cast.connect(_on_manual_cast)

	# 连接 CharacterClassManager 信号
	var ccm = get_tree().get_first_node_in_group("character_class_manager")
	if ccm and ccm.has_signal("class_applied"):
		ccm.class_applied.connect(_on_class_applied)

## 节拍脉冲（由 RenderBridge3D 转发）
func on_beat_pulse(beat_index: int = 0) -> void:
	_on_beat_tick(beat_index)

## 节拍回调
func _on_beat_tick(_beat_index: int = 0) -> void:
	if _current_mode_node and _current_mode_node.has_method("trigger_beat"):
		_current_mode_node.trigger_beat()
	if _skeleton:
		_skeleton.trigger_beat_pulse()

## 自动施法回调
func _on_spell_cast(spell_data: Dictionary) -> void:
	_trigger_spellcast_visual(spell_data)

## 和弦施法回调
func _on_chord_cast(chord_data: Dictionary) -> void:
	_trigger_spellcast_visual(chord_data)
	# 和弦施法有更强的视觉效果
	if _current_mode_node and _current_mode_node.has_method("trigger_spellcast_ripple"):
		_current_mode_node.trigger_spellcast_ripple()

## 手动施法回调
func _on_manual_cast(_slot: int) -> void:
	if _current_mode_node and _current_mode_node.has_method("trigger_spellcast_ripple"):
		_current_mode_node.trigger_spellcast_ripple()
	# 播放指向手势
	if _skeleton:
		_skeleton.play_gesture("Point")

## 角色职业应用回调
func _on_class_applied(class_id: String, _class_name: String) -> void:
	# 根据职业 ID 映射到调式 ID
	var mode_map: Dictionary = {
		"ionian": 0,
		"dorian": 0,       # 多利亚使用 Ionian 基础外观
		"pentatonic": 2,   # 五声音阶使用 Lydian 外观
		"blues": 1,        # 布鲁斯使用 Locrian 外观
	}
	var target_mode: int = mode_map.get(class_id, 0)
	if target_mode != _mode_id:
		switch_mode(target_mode)

## 触发施法视觉效果
func _trigger_spellcast_visual(spell_data: Dictionary) -> void:
	var spell_type: String = spell_data.get("type", "projectile")
	var gesture_name: String = SPELL_GESTURE_MAP.get(spell_type, "Point")

	# 播放骨骼手势动画
	if _skeleton:
		_skeleton.play_gesture(gesture_name)

	# 触发调式特定效果
	if _current_mode_node and _current_mode_node.has_method("trigger_spellcast_ripple"):
		_current_mode_node.trigger_spellcast_ripple()

	spellcast_visual_triggered.emit(gesture_name)

	# 弗里几亚式的刺击修改器
	if _mode_id == 3 and _skeleton:
		_skeleton.apply_impact(Vector3.FORWARD * 0.5)

## 骨骼手势开始回调
func _on_gesture_started(gesture_name: String) -> void:
	spellcast_visual_triggered.emit(gesture_name)

## 骨骼手势完成回调
func _on_gesture_finished(_gesture_name: String) -> void:
	pass

# ============================================================
# 伤害响应
# ============================================================

## 受击视觉效果
func apply_damage_visual(source_direction: Vector3 = Vector3.BACK) -> void:
	# 骨骼受击修改器
	if _skeleton:
		_skeleton.apply_impact(source_direction)

	# 调式特定受击效果
	match _mode_id:
		1:  # Locrian: 数字衰变
			if _current_mode_node and _current_mode_node.has_method("trigger_damage_decay"):
				_current_mode_node.trigger_damage_decay()
		3:  # Phrygian: 反击刺击
			if _current_mode_node and _current_mode_node.has_method("trigger_stab"):
				_current_mode_node.trigger_stab()

# ============================================================
# 公共查询接口
# ============================================================

## 获取当前调式 ID
func get_current_mode_id() -> int:
	return _mode_id

## 获取当前调式名称
func get_current_mode_name() -> String:
	return MODE_NAMES.get(_mode_id, "unknown")

## 获取当前调式节点
func get_current_mode_node() -> Node3D:
	return _current_mode_node

## 获取骨骼系统
func get_skeleton() -> AbstractSkeleton:
	return _skeleton

## 获取当前调式的着色器材质
func get_current_shader_material() -> ShaderMaterial:
	if _current_mode_node and _current_mode_node.has_method("get_shader_material"):
		return _current_mode_node.get_shader_material()
	return null

## 是否正在过渡
func is_transitioning() -> bool:
	return _is_transitioning

## 强制设置调式（无过渡，用于初始化）
func force_mode(mode_id: int) -> void:
	_mode_id = mode_id
	_setup_mode(mode_id)
