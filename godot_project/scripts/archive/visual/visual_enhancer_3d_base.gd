## visual_enhancer_3d_base.gd
## 3D 视觉增强器基类
##
## 职责：
## 1. 自动处理 2D 实体在 3D 空间的同步 (通过 Sprite3D)
## 2. 提供 3D 空间的节拍响应和 Shader 接口
class_name VisualEnhancer3DBase
extends Node3D

# ============================================================
# 配置
# ============================================================
@export var sync_with_2d_parent: bool = true
@export var beat_pulse_scale: float = 0.1

# ============================================================
# 状态
# ============================================================
var _parent_2d: Node2D
var _sprite_3d: Sprite3D
var _base_scale: Vector3

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	if sync_with_2d_parent:
		_parent_2d = get_parent() as Node2D
	
	_setup_sprite_3d()
	_connect_signals()

func _process(delta: float) -> void:
	if sync_with_2d_parent and _parent_2d:
		# 同步位置：将 2D 坐标映射到 3D Y=0 平面
		var gve = get_node_or_null("/root/GlobalVisualEnvironment3D")
		if gve:
			global_position = gve.to_3d(_parent_2d.global_position)
		
		# 同步旋转
		rotation.y = -_parent_2d.global_rotation
	
	_update_visual(delta)

func _setup_sprite_3d() -> void:
	# 查找或创建 Sprite3D
	_sprite_3d = get_node_or_null("Sprite3D")
	if not _sprite_3d:
		_sprite_3d = Sprite3D.new()
		_sprite_3d.shaded = true
		_sprite_3d.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		add_child(_sprite_3d)
	
	_base_scale = scale

func _connect_signals() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm and gm.has_signal("beat_tick"):
		gm.beat_tick.connect(_on_beat)

# ============================================================
# 视觉逻辑
# ============================================================

func _on_beat(_count: int) -> void:
	# 节拍缩放脉冲
	var tween = create_tween()
	tween.tween_property(self, "scale", _base_scale * (1.0 + beat_pulse_scale), 0.05)
	tween.tween_property(self, "scale", _base_scale, 0.2)

func _update_visual(_delta: float) -> void:
	pass

# ============================================================
# 公共接口
# ============================================================

func set_texture(tex: Texture2D) -> void:
	if _sprite_3d:
		_sprite_3d.texture = tex
