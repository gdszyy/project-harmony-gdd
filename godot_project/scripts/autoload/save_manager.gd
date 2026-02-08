## save_manager.gd
## 存档管理器 (Autoload)
## 负责游戏数据的持久化存储（ConfigFile/JSON）
extends Node

const SAVE_PATH = "user://save_game.cfg"
const SETTINGS_PATH = "user://settings.cfg"

var _save_data := ConfigFile.new()
var _settings_data := ConfigFile.new()

func _ready() -> void:
	load_game()
	load_settings()

# ============================================================
# 游戏进度存档
# ============================================================

func save_game() -> void:
	_save_data.set_value("progression", "total_kills", _save_data.get_value("progression", "total_kills", 0) + GameManager.session_kills)
	_save_data.set_value("progression", "best_time", max(_save_data.get_value("progression", "best_time", 0.0), GameManager.game_time))
	_save_data.set_value("progression", "max_level", max(_save_data.get_value("progression", "max_level", 1), GameManager.player_level))
	
	var err = _save_data.save(SAVE_PATH)
	if err != OK:
		push_error("Failed to save game data!")
	
	# 同时保存局外成长数据 (Issue #31)
	var meta_mgr := get_node_or_null("/root/MetaProgressionManager")
	if meta_mgr and meta_mgr.has_method("save_meta_data"):
		meta_mgr.save_meta_data()

func load_game() -> void:
	var err = _save_data.load(SAVE_PATH)
	if err != OK:
		# 首次运行，初始化默认值
		_save_data.set_value("progression", "total_kills", 0)
		_save_data.set_value("progression", "best_time", 0.0)
		_save_data.set_value("progression", "max_level", 1)

func get_best_time() -> float:
	return _save_data.get_value("progression", "best_time", 0.0)

# ============================================================
# 设置存档
# ============================================================

func save_settings(settings: Dictionary) -> void:
	for key in settings:
		_settings_data.set_value("audio", key, settings[key])
	_settings_data.save(SETTINGS_PATH)

func load_settings() -> Dictionary:
	var err = _settings_data.load(SETTINGS_PATH)
	var settings = {}
	if err == OK:
		for key in _settings_data.get_section_keys("audio"):
			settings[key] = _settings_data.get_value("audio", key)
	return settings
