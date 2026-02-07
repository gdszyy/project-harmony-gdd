## obstacle.gd
## 障碍物脚本
## 静态碰撞体，具有受击反馈和频谱响应视觉效果
extends StaticBody2D

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("obstacles")
	_setup_visual()

func _setup_visual() -> void:
	if _sprite and _sprite.material is ShaderMaterial:
		var mat := _sprite.material as ShaderMaterial
		mat.set_shader_parameter("base_color", Color(0.4, 0.4, 0.5))

func _process(_delta: float) -> void:
	# 响应频谱能量
	if _sprite and _sprite.material is ShaderMaterial:
		var energy = GlobalMusicManager.get_beat_energy()
		_sprite.material.set_shader_parameter("beat_energy", energy)

func take_damage(_amount: float, _knockback: Vector2 = Vector2.ZERO) -> void:
	# 受击反馈：闪烁
	_flash()
	# 播放音效
	GlobalMusicManager.play_ui_sound("click")

func _flash() -> void:
	if _sprite:
		var tween := create_tween()
		tween.tween_property(_sprite, "modulate", Color(2.0, 2.0, 2.0), 0.05)
		tween.tween_property(_sprite, "modulate", Color.WHITE, 0.2)
