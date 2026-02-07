## pause_menu.gd
## 暂停菜单
extends Control

@onready var _stats_label: Label = $Panel/VBoxContainer/StatsLabel
@onready var _settings_menu: Control = $SettingsMenu

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	GameManager.game_state_changed.connect(_on_game_state_changed)

func _on_game_state_changed(new_state: GameManager.GameState) -> void:
	if new_state == GameManager.GameState.PAUSED:
		_show_menu()
	else:
		visible = false

func _show_menu() -> void:
	visible = true
	_update_stats()

func _update_stats() -> void:
	if _stats_label:
		var time := GameManager.game_time
		var mins := int(time) / 60
		var secs := int(time) % 60
		var stats_text := "--- SESSION STATS ---\n"
		stats_text += "Time: %02d:%02d\n" % [mins, secs]
		stats_text += "Level: %d\n" % GameManager.player_level
		stats_text += "Upgrades: %d\n" % GameManager.acquired_upgrades.size()
		_stats_label.text = stats_text

func _on_resume_pressed() -> void:
	GameManager.resume_game()

func _on_settings_pressed() -> void:
	if _settings_menu:
		_settings_menu.visible = true

func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
