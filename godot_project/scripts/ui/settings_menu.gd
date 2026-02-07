## settings_menu.gd
## 设置菜单
extends Control

@onready var _master_slider: HSlider = $Panel/VBoxContainer/MasterVolume/HSlider
@onready var _music_slider: HSlider = $Panel/VBoxContainer/MusicVolume/HSlider
@onready var _sfx_slider: HSlider = $Panel/VBoxContainer/SFXVolume/HSlider

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

func _on_back_pressed() -> void:
	var settings = {
		"master": _master_slider.value,
		"music": _music_slider.value,
		"sfx": _sfx_slider.value
	}
	SaveManager.save_settings(settings)
	visible = false
