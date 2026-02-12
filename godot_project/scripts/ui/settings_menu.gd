## settings_menu.gd
## 设置菜单
extends Control

@onready var _master_slider: HSlider = $Panel/VBoxContainer/MasterVolume/HSlider
@onready var _music_slider: HSlider = $Panel/VBoxContainer/MusicVolume/HSlider
@onready var _sfx_slider: HSlider = $Panel/VBoxContainer/SFXVolume/HSlider

## OPT05: 量化模式选项按钮（如果场景中存在）
@onready var _quantize_option: OptionButton = $Panel/VBoxContainer/QuantizeMode/OptionButton if has_node("Panel/VBoxContainer/QuantizeMode/OptionButton") else null

func _ready() -> void:
	_load_current_settings()

func _load_current_settings() -> void:
	var settings = SaveManager.load_settings()
	_master_slider.value = settings.get("master", 80.0)
	_music_slider.value = settings.get("music", 80.0)
	_sfx_slider.value = settings.get("sfx", 80.0)
	
	_apply_volume("Master", _master_slider.value)
	_apply_volume("Music", _music_slider.value)
	_apply_volume("SFX", _sfx_slider.value)
	
	# OPT05: 加载量化模式设置
	if _quantize_option:
		_quantize_option.clear()
		_quantize_option.add_item("完全量化 (Full)", 0)     # 默认，最佳音乐体验
		_quantize_option.add_item("柔性量化 (Soft)", 1)     # 高手模式
		_quantize_option.add_item("关闭 (Off)", 2)              # 无障碍/竞技模式
		var saved_mode: int = settings.get("quantize_mode", 0)
		_quantize_option.selected = saved_mode
		_apply_quantize_mode(saved_mode)
		if not _quantize_option.item_selected.is_connected(_on_quantize_mode_changed):
			_quantize_option.item_selected.connect(_on_quantize_mode_changed)

func _on_master_value_changed(value: float) -> void:
	_apply_volume("Master", value)

func _on_music_value_changed(value: float) -> void:
	_apply_volume("Music", value)

func _on_sfx_value_changed(value: float) -> void:
	_apply_volume("SFX", value)

func _apply_volume(bus_name: String, value: float) -> void:
	var bus_idx = AudioServer.get_bus_index(bus_name)
	if bus_idx != -1:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value / 100.0))

## OPT05: 量化模式切换回调
func _on_quantize_mode_changed(index: int) -> void:
	_apply_quantize_mode(index)

## OPT05: 应用量化模式
func _apply_quantize_mode(mode_index: int) -> void:
	match mode_index:
		0:
			AudioManager.set_quantize_mode(AudioEventQueue.QuantizeMode.FULL)
		1:
			AudioManager.set_quantize_mode(AudioEventQueue.QuantizeMode.SOFT)
		2:
			AudioManager.set_quantize_mode(AudioEventQueue.QuantizeMode.OFF)

func _on_back_pressed() -> void:
	var settings = {
		"master": _master_slider.value,
		"music": _music_slider.value,
		"sfx": _sfx_slider.value,
		"quantize_mode": _quantize_option.selected if _quantize_option else 0,  # OPT05
	}
	SaveManager.save_settings(settings)
	visible = false
