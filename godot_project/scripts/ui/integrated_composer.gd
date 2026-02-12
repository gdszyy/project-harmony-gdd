## integrated_composer.gd
## v3.0 一体化编曲台 (Integrated Composer) — 全屏覆盖主界面
##
## 设计哲学："沉浸式创作流" (Immersive Composition Flow)
## 将音符库存、序列器、和弦炼成、法术书、手动施法槽整合为统一全屏视图，
## 在一个界面内完成所有法术编辑工作。
##
## 布局结构（从左到右）：
##   ┌──────────┬──────────────────────────┬────────────────┐
##   │ 左侧 20% │       中央 50%           │   右侧 30%     │
##   │          │                          │                │
##   │ 音符库存  │  4×4 序列器网格           │  和弦炼成区     │
##   │ (12音符)  │  (拖拽放置/移除/交换)     │  (原材料槽)     │
##   │          │                          │                │
##   │ 白键 ×7  │  ────────────────────    │  ────────────  │
##   │ 黑键 ×5  │                          │                │
##   │          │  手动施法槽 [1] [2] [3]   │  法术书         │
##   │          │                          │  (已合成和弦)   │
##   └──────────┴──────────────────────────┴────────────────┘
##
## 使用 Godot 内置拖拽 API（_get_drag_data / _can_drop_data / _drop_data）
## 与 SpellcraftSystem、NoteInventory 等全局单例对接
extends CanvasLayer

# ============================================================
# 信号
# ============================================================
## 音符放置到序列器时触发
signal note_placed(cell_idx: int, note: int)
## 序列器格子被清除时触发
signal cell_cleared(cell_idx: int)
## 和弦炼成完成时触发
signal chord_crafted(chord_spell: Dictionary)
## 兼容别名，与 chord_crafted 同步触发
signal alchemy_completed(chord_spell: Dictionary)
## 手动施法槽配置变更时触发
signal manual_slot_configured(slot_index: int, spell_data: Dictionary)
## 面板开关状态变更时触发
signal panel_toggled(is_open: bool)

# ============================================================
# 常量 — 全局 UI 主题规范（来自美术文档）
# ============================================================
## 面板背景色：星空紫，80% 不透明度
const THEME_BG_COLOR := Color("141026CC")
## 面板边框色：主强调色，40% 不透明度
const THEME_BORDER_COLOR := Color("9D6FFF66")
## 文本色：晶体白
const THEME_TEXT_COLOR := Color("EAE6FF")
## 按钮/强调色：主强调色
const THEME_ACCENT_COLOR := Color("9D6FFF")
## 有效放置区高亮色：谐振青
const THEME_DROP_HIGHLIGHT := Color("00FFD4")
## 无效操作反馈色
const THEME_INVALID_COLOR := Color("FF4444")
## 标题/次要文本色
const THEME_SUBTITLE_COLOR := Color("9D8FBF")

# ============================================================
# 音符颜色编码系统（来自 UI 设计文档 §4.1）
# ============================================================
const NOTE_COLORS_V3 := {
	0: Color("00FFD4"),  # C — 谐振青
	1: Color("0088FF"),  # D — 疾风蓝
	2: Color("66FF66"),  # E — 翠叶绿
	3: Color("8844FF"),  # F — 深渊紫
	4: Color("FF4444"),  # G — 烈焰红
	5: Color("FF8800"),  # A — 烈日橙
	6: Color("FF44AA"),  # B — 霓虹粉
}

## 黑键颜色（基于对应白键的暗化版本）
const BLACK_KEY_COLORS_V3 := {
	0: Color("009988"),  # C# — 谐振青暗化
	1: Color("005599"),  # D# — 疾风蓝暗化
	2: Color("6633CC"),  # F# — 深渊紫暗化
	3: Color("CC2222"),  # G# — 烈焰红暗化
	4: Color("CC6600"),  # A# — 烈日橙暗化
}

# ============================================================
# 状态
# ============================================================
var _is_open: bool = false

# ============================================================
# 子节点引用（在 _ready 中获取）
# ============================================================
@onready var _bg_panel: PanelContainer = $BackgroundPanel
@onready var _note_inventory_panel: Control = $BackgroundPanel/MainLayout/LeftPanel/NoteInventoryPanel
@onready var _sequencer_panel: Control = $BackgroundPanel/MainLayout/CenterPanel/SequencerGrid
@onready var _manual_slots_panel: Control = $BackgroundPanel/MainLayout/CenterPanel/ManualSlotsPanel
@onready var _alchemy_panel: Control = $BackgroundPanel/MainLayout/RightPanel/ChordAlchemyPanel
@onready var _spellbook_panel: Control = $BackgroundPanel/MainLayout/RightPanel/SpellbookPanel
@onready var _title_label: Label = $BackgroundPanel/HeaderBar/TitleLabel
@onready var _bpm_label: Label = $BackgroundPanel/HeaderBar/BPMLabel
@onready var _close_btn: Button = $BackgroundPanel/HeaderBar/CloseButton
@onready var _info_label: RichTextLabel = $BackgroundPanel/InfoBar/InfoLabel

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	## 初始时隐藏
	visible = false
	layer = 100  # 确保在所有游戏内容之上

	## 连接关闭按钮
	if _close_btn:
		_close_btn.pressed.connect(close_panel)

	## 连接子面板信号
	_connect_child_signals()

	## 连接全局信号
	if GameManager.has_signal("beat_tick"):
		GameManager.beat_tick.connect(_on_beat_tick)
	if NoteInventory.has_signal("inventory_changed"):
		NoteInventory.inventory_changed.connect(_on_inventory_changed)
	if NoteInventory.has_signal("spellbook_changed"):
		NoteInventory.spellbook_changed.connect(_on_spellbook_changed)
	if SpellcraftSystem.has_signal("sequencer_updated"):
		SpellcraftSystem.sequencer_updated.connect(_on_sequencer_updated)

func _connect_child_signals() -> void:
	## 连接音符库存面板的拖拽开始信号
	if _note_inventory_panel and _note_inventory_panel.has_signal("info_hover"):
		_note_inventory_panel.info_hover.connect(_on_info_hover)

	## 连接序列器面板信号
	if _sequencer_panel:
		if _sequencer_panel.has_signal("note_placed"):
			_sequencer_panel.note_placed.connect(_on_seq_note_placed)
		if _sequencer_panel.has_signal("cell_cleared"):
			_sequencer_panel.cell_cleared.connect(_on_seq_cell_cleared)
		if _sequencer_panel.has_signal("info_hover"):
			_sequencer_panel.info_hover.connect(_on_info_hover)

	## 连接炼成面板信号
	if _alchemy_panel:
		if _alchemy_panel.has_signal("alchemy_completed"):
			_alchemy_panel.alchemy_completed.connect(_on_alchemy_completed)
		if _alchemy_panel.has_signal("info_hover"):
			_alchemy_panel.info_hover.connect(_on_info_hover)

	## 连接法术书面板信号
	if _spellbook_panel and _spellbook_panel.has_signal("info_hover"):
		_spellbook_panel.info_hover.connect(_on_info_hover)

	## 连接手动施法槽信号
	if _manual_slots_panel:
		if _manual_slots_panel.has_signal("slot_configured"):
			_manual_slots_panel.slot_configured.connect(_on_manual_slot_configured)
		if _manual_slots_panel.has_signal("info_hover"):
			_manual_slots_panel.info_hover.connect(_on_info_hover)

# ============================================================
# 快捷键处理
# ============================================================

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		## Tab 键切换编曲台
		if event.keycode == KEY_TAB:
			toggle()
			get_viewport().set_input_as_handled()
		## Escape 键关闭编曲台
		elif event.keycode == KEY_ESCAPE and _is_open:
			close_panel()
			get_viewport().set_input_as_handled()
		## Ctrl+Z 撤销
		elif event.keycode == KEY_Z and event.ctrl_pressed and _is_open:
			if _sequencer_panel and _sequencer_panel.has_method("undo"):
				_sequencer_panel.undo()
			get_viewport().set_input_as_handled()
		## Ctrl+Y 重做
		elif event.keycode == KEY_Y and event.ctrl_pressed and _is_open:
			if _sequencer_panel and _sequencer_panel.has_method("redo"):
				_sequencer_panel.redo()
			get_viewport().set_input_as_handled()

# ============================================================
# 显示/隐藏
# ============================================================

## 切换编曲台显示状态
func toggle() -> void:
	if _is_open:
		close_panel()
	else:
		open_panel()

## 打开编曲台
func open_panel() -> void:
	_is_open = true
	visible = true

	## 暂停游戏
	get_tree().paused = true

	## 刷新所有子面板数据
	_refresh_all_panels()

	## 更新 BPM 显示
	if _bpm_label:
		_bpm_label.text = "BPM: %d" % int(GameManager.get_bpm())

	panel_toggled.emit(true)

## 关闭编曲台
func close_panel() -> void:
	## 通知炼成面板归还未使用的音符
	if _alchemy_panel and _alchemy_panel.has_method("return_unused_notes"):
		_alchemy_panel.return_unused_notes()

	_is_open = false
	visible = false

	## 恢复游戏
	get_tree().paused = false

	panel_toggled.emit(false)

## 供外部调用：和弦炼成完成后刷新法术书区域
func refresh_spellbook() -> void:
	if _spellbook_panel and _spellbook_panel.has_method("refresh"):
		_spellbook_panel.refresh()

## 刷新所有子面板
func _refresh_all_panels() -> void:
	if _note_inventory_panel and _note_inventory_panel.has_method("refresh"):
		_note_inventory_panel.refresh()
	if _sequencer_panel and _sequencer_panel.has_method("refresh"):
		_sequencer_panel.refresh()
	if _spellbook_panel and _spellbook_panel.has_method("refresh"):
		_spellbook_panel.refresh()
	if _manual_slots_panel and _manual_slots_panel.has_method("refresh"):
		_manual_slots_panel.refresh()
	if _alchemy_panel and _alchemy_panel.has_method("refresh"):
		_alchemy_panel.refresh()

# ============================================================
# 信息栏更新
# ============================================================

## 更新底部信息栏内容
func _update_info_bar(title: String, desc: String, color: Color = THEME_TEXT_COLOR) -> void:
	if not _info_label:
		return
	_info_label.clear()
	_info_label.push_color(color)
	_info_label.push_bold()
	_info_label.add_text(title)
	_info_label.pop()
	_info_label.pop()
	_info_label.add_text("  —  ")
	_info_label.push_color(THEME_SUBTITLE_COLOR)
	_info_label.add_text(desc)
	_info_label.pop()

## 清空信息栏
func _clear_info_bar() -> void:
	if _info_label:
		_info_label.clear()
		_info_label.push_color(THEME_SUBTITLE_COLOR)
		_info_label.add_text("悬停任意元素查看详细信息  |  Tab: 关闭  |  Ctrl+Z/Y: 撤销/重做")
		_info_label.pop()

# ============================================================
# 子面板信号回调
# ============================================================

func _on_seq_note_placed(cell_idx: int, note_key: int) -> void:
	note_placed.emit(cell_idx, note_key)

func _on_seq_cell_cleared(cell_idx: int) -> void:
	cell_cleared.emit(cell_idx)

func _on_alchemy_completed(chord_spell_data: Dictionary) -> void:
	chord_crafted.emit(chord_spell_data)
	alchemy_completed.emit(chord_spell_data)
	## 刷新法术书
	refresh_spellbook()

func _on_manual_slot_configured(slot_index: int, spell_data: Dictionary) -> void:
	manual_slot_configured.emit(slot_index, spell_data)

func _on_info_hover(title: String, desc: String, color: Color) -> void:
	_update_info_bar(title, desc, color)

# ============================================================
# 全局信号回调
# ============================================================

func _on_beat_tick(_beat_index: int) -> void:
	## 转发给序列器面板
	if _sequencer_panel and _sequencer_panel.has_method("on_beat_tick"):
		_sequencer_panel.on_beat_tick(_beat_index)

func _on_inventory_changed(_note_key: int, _new_count: int) -> void:
	if _is_open and _note_inventory_panel and _note_inventory_panel.has_method("refresh"):
		_note_inventory_panel.refresh()

func _on_spellbook_changed(_spellbook: Array) -> void:
	if _is_open:
		refresh_spellbook()

func _on_sequencer_updated(_sequence) -> void:
	if _is_open and _sequencer_panel and _sequencer_panel.has_method("refresh"):
		_sequencer_panel.refresh()

# ============================================================
# 静态工具方法 — 供子面板使用
# ============================================================

## 获取音符颜色（v3.0 新配色方案）
static func get_note_color(note_key: int) -> Color:
	return NOTE_COLORS_V3.get(note_key, Color(0.5, 0.5, 0.5))

## 获取黑键颜色
static func get_black_key_color(black_key_idx: int) -> Color:
	return BLACK_KEY_COLORS_V3.get(black_key_idx, Color(0.4, 0.4, 0.4))

## 获取音符名称
static func get_note_name(note_key: int) -> String:
	return MusicData.WHITE_KEY_STATS.get(note_key, {}).get("name", "?")

## 获取黑键名称
static func get_black_key_name(black_key_idx: int) -> String:
	return MusicData.BLACK_KEY_MODIFIERS.get(black_key_idx, {}).get("name", "?")

## 创建拖拽预览控件（统一的拖拽视觉风格）
static func create_drag_preview(text: String, color: Color, icon_size: Vector2 = Vector2(48, 48)) -> Control:
	var preview := Control.new()
	preview.custom_minimum_size = icon_size
	preview.size = icon_size

	var panel := Panel.new()
	panel.custom_minimum_size = icon_size
	panel.size = icon_size

	## 创建半透明背景样式
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.4)
	style.border_color = color
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	## 辉光效果通过 shadow 模拟
	style.shadow_color = Color(color.r, color.g, color.b, 0.5)
	style.shadow_size = 4
	panel.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = icon_size
	label.size = icon_size
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", 16)

	preview.add_child(panel)
	preview.add_child(label)
	return preview

## 创建面板样式（统一的面板外观）
static func create_panel_stylebox(bg_alpha: float = 0.8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.078, 0.063, 0.149, bg_alpha)  # 星空紫
	style.border_color = THEME_BORDER_COLOR
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style
