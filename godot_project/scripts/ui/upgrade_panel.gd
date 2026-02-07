## upgrade_panel.gd
## 升级选择面板
## 肉鸽升级选择界面，每次升级提供3个选项
extends Control

# ============================================================
# 信号
# ============================================================
signal upgrade_chosen(upgrade: Dictionary)

# ============================================================
# 升级池
# ============================================================
const UPGRADE_POOL := [
	# === 音符属性强化 ===
	{
		"id": "dmg_boost_c", "category": "note_stat", "rarity": "common",
		"name": "C音符 伤害增幅", "desc": "C音符 DMG +0.5",
		"target_note": 0, "stat": "dmg", "value": 0.5,
		"icon_color": Color(0.0, 1.0, 0.8),
	},
	{
		"id": "dmg_boost_g", "category": "note_stat", "rarity": "common",
		"name": "G音符 伤害增幅", "desc": "G音符 DMG +0.5",
		"target_note": 4, "stat": "dmg", "value": 0.5,
		"icon_color": Color(1.0, 0.3, 0.1),
	},
	{
		"id": "spd_boost_d", "category": "note_stat", "rarity": "common",
		"name": "D音符 速度增幅", "desc": "D音符 SPD +0.5",
		"target_note": 1, "stat": "spd", "value": 0.5,
		"icon_color": Color(0.2, 0.6, 1.0),
	},
	{
		"id": "all_boost", "category": "note_stat", "rarity": "epic",
		"name": "全维强化", "desc": "选择一个音符，所有参数 +0.25",
		"target_note": -1, "stat": "all", "value": 0.25,
		"icon_color": Color(1.0, 0.8, 0.0),
	},
	# === 疲劳耐受 ===
	{
		"id": "monotony_resist", "category": "fatigue_resist", "rarity": "rare",
		"name": "单调耐受", "desc": "单调值累积速率 -10%",
		"type": "monotony_resist", "value": 0.1,
		"icon_color": Color(0.4, 0.8, 0.4),
	},
	{
		"id": "dissonance_decay", "category": "fatigue_resist", "rarity": "rare",
		"name": "不和谐消散", "desc": "不和谐值自然衰减 +0.5/秒",
		"type": "dissonance_decay", "value": 0.5,
		"icon_color": Color(0.6, 0.4, 0.8),
	},
	{
		"id": "density_resist", "category": "fatigue_resist", "rarity": "rare",
		"name": "密度耐受", "desc": "密度疲劳累积速率 -10%",
		"type": "density_resist", "value": 0.1,
		"icon_color": Color(0.4, 0.6, 0.8),
	},
	# === 节奏精通 ===
	{
		"id": "bpm_boost", "category": "rhythm_mastery", "rarity": "rare",
		"name": "节奏加速", "desc": "基础 BPM +5",
		"type": "bpm_boost", "value": 5.0,
		"icon_color": Color(1.0, 0.6, 0.0),
	},
	# === 和弦精通 ===
	{
		"id": "chord_power", "category": "chord_mastery", "rarity": "rare",
		"name": "和弦威力", "desc": "所有和弦伤害倍率 +0.1x",
		"type": "chord_power", "value": 0.1,
		"icon_color": Color(0.8, 0.6, 1.0),
	},
	{
		"id": "extended_unlock", "category": "chord_mastery", "rarity": "legendary",
		"name": "扩展和弦解锁", "desc": "解锁5-6音扩展和弦",
		"type": "extended_unlock",
		"icon_color": Color(1.0, 0.9, 0.0),
	},
	# === 生存强化 ===
	{
		"id": "max_hp", "category": "survival", "rarity": "common",
		"name": "生命强化", "desc": "最大生命值 +25",
		"type": "max_hp", "value": 25.0,
		"icon_color": Color(0.2, 0.8, 0.2),
	},
	{
		"id": "dodge", "category": "survival", "rarity": "rare",
		"name": "闪避本能", "desc": "基础闪避率 +3%",
		"type": "dodge", "value": 0.03,
		"icon_color": Color(0.8, 0.8, 1.0),
	},
]

## 稀有度颜色
const RARITY_COLORS := {
	"common": Color(0.6, 0.6, 0.6),
	"rare": Color(0.2, 0.6, 1.0),
	"epic": Color(0.7, 0.3, 1.0),
	"legendary": Color(1.0, 0.8, 0.0),
}

# ============================================================
# 状态
# ============================================================
var _current_options: Array[Dictionary] = []
var _is_visible: bool = false

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	visible = false
	GameManager.game_state_changed.connect(_on_game_state_changed)

# ============================================================
# 显示/隐藏
# ============================================================

func show_upgrade_options() -> void:
	_current_options = _generate_options(3)
	_is_visible = true
	visible = true
	_build_ui()

func hide_panel() -> void:
	_is_visible = false
	visible = false

# ============================================================
# 选项生成
# ============================================================

func _generate_options(count: int) -> Array[Dictionary]:
	var available := UPGRADE_POOL.duplicate(true)

	# 过滤已满的升级
	if GameManager.extended_chords_unlocked:
		available = available.filter(func(u): return u.get("id", "") != "extended_unlock")

	# 加权随机选择
	available.shuffle()
	var selected: Array[Dictionary] = []
	for i in range(min(count, available.size())):
		selected.append(available[i])

	return selected

# ============================================================
# UI 构建
# ============================================================

func _build_ui() -> void:
	# 清除旧的子节点
	for child in get_children():
		if child.name.begins_with("UpgradeOption"):
			child.queue_free()

	# 创建选项按钮
	for i in range(_current_options.size()):
		var option := _current_options[i]
		var button := _create_option_button(option, i)
		button.name = "UpgradeOption_%d" % i
		add_child(button)

func _create_option_button(option: Dictionary, index: int) -> Button:
	var button := Button.new()

	var rarity: String = option.get("rarity", "common")
	var rarity_color: Color = RARITY_COLORS.get(rarity, Color.WHITE)

	button.text = "%s\n%s\n[%s]" % [option.get("name", "???"), option.get("desc", ""), rarity.to_upper()]
	button.custom_minimum_size = Vector2(250, 120)

	# 位置
	var total_width := _current_options.size() * 270.0
	var start_x := (get_viewport_rect().size.x - total_width) / 2.0
	button.position = Vector2(start_x + index * 270.0, get_viewport_rect().size.y / 2.0 - 60)

	# 样式
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.9)
	style.border_color = rarity_color
	style.border_width_bottom = 2
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	button.add_theme_stylebox_override("normal", style)

	var hover_style := style.duplicate()
	hover_style.bg_color = Color(0.15, 0.15, 0.25, 0.95)
	button.add_theme_stylebox_override("hover", hover_style)

	button.add_theme_color_override("font_color", Color.WHITE)

	# 点击事件
	button.pressed.connect(func(): _on_option_selected(option))

	return button

# ============================================================
# 选择处理
# ============================================================

func _on_option_selected(option: Dictionary) -> void:
	GameManager.apply_upgrade(option)
	upgrade_chosen.emit(option)
	hide_panel()
	GameManager.resume_game()

func _on_game_state_changed(new_state: GameManager.GameState) -> void:
	if new_state == GameManager.GameState.UPGRADE_SELECT:
		show_upgrade_options()
	elif _is_visible:
		hide_panel()
