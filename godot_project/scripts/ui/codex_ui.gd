## 图鉴系统 "谐振法典 (Codex Resonare)" UI 主界面 - v2.0 Themed
##
## 视觉风格：充满神秘感的魔法书，背景为羊皮纸/星图纹理，有书页卷曲动画。
## 布局：顶部标题栏 + 左侧卷标签页 + 右侧条目列表/详情
##
extends Control

# ============================================================
# 信号
# ============================================================
signal back_pressed()

# ============================================================
# 颜色方案 (from UI_Art_Style_Enhancement_Proposal.md)
# ============================================================
const BG_COLOR := Color("#0A0814")
const PANEL_BG := Color("#141026")
const HEADER_BG := Color("#100C20")
const TAB_ACTIVE := Color("#9D6FFF4D")
const TAB_HOVER := Color("#9D6FFF33")
const TAB_NORMAL := Color("#141026CC")
const ACCENT := Color("#9D6FFF")
const GOLD := Color("#FFD700")
const TEXT_PRIMARY := Color("#EAE6FF")
const TEXT_SECONDARY := Color("#A098C8")
const TEXT_DIM := Color("#6B668A")
const LOCKED_BG := Color("#100C20E6")
const LOCKED_TEXT := Color("#6B668A")
const ENTRY_BG := Color("#18142C")
const ENTRY_HOVER := Color("#201A38")
const ENTRY_SELECTED := Color("#2A2248")
const DETAIL_BG := Color("#120E22F2")

# ============================================================
# 卷配置
# ============================================================
const VOLUME_CONFIG: Array = [
	{
		"name": "第一卷：乐理纲要", "icon": "I",
		"subcategories": [
			{ "name": "音符", "data_key": "VOL1_NOTES" },
			{ "name": "和弦", "data_key": "VOL1_CHORDS" },
		],
	},
	# ... other volumes
]

# ============================================================
# 节点引用
# ============================================================
var _background: TextureRect = null
var _page_curl_anim: AnimationPlayer = null
var _left_page: Control = null
var _right_page: Control = null

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_build_ui()
	# Load data and populate the codex

# ============================================================
# UI 构建
# ============================================================

func _build_ui() -> void:
	# 背景 (羊皮纸/星图纹理)
	_background = TextureRect.new()
	_background.texture = load("res://assets/ui/textures/codex_bg.png") # Placeholder path
	_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_background)

	# 页面容器
	var book_container = HBoxContainer.new()
	book_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	book_container.size = Vector2(1100, 600)
	book_container.position = -book_container.size / 2
	add_child(book_container)

	# 左页 (目录)
	_left_page = VBoxContainer.new()
	_left_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	book_container.add_child(_left_page)

	# 右页 (内容)
	_right_page = VBoxContainer.new()
	_right_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	book_container.add_child(_right_page)

	# 翻页动画播放器
	_page_curl_anim = AnimationPlayer.new()
	add_child(_page_curl_anim)
	_setup_animations()

	_populate_left_page()

func _populate_left_page() -> void:
	for volume in VOLUME_CONFIG:
		var volume_label = Label.new()
		volume_label.text = volume.name
		# Apply H1 style from theme
		_left_page.add_child(volume_label)

		for subcat in volume.subcategories:
			var subcat_button = Button.new()
			subcat_button.text = subcat.name
			# Apply entry style from theme
			_left_page.add_child(subcat_button)

# ============================================================
# 动画
# ============================================================

func _setup_animations() -> void:
	var anim_lib = AnimationLibrary.new()
	_page_curl_anim.add_animation_library("page_turn", anim_lib)

	# 创建翻页动画 (simplified example)
	var anim = Animation.new()
	anim.length = 0.5
	# This would involve animating a shader or a custom mesh for a realistic curl
	# For a simpler version, we can just fade pages in and out
	anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(0, "%s:modulate" % _right_page.get_path())
	anim.track_insert_key(0, 0.0, Color(1,1,1,0))
	anim.track_insert_key(0, 0.5, Color(1,1,1,1))
	anim_lib.add_animation("turn_to_right", anim)

func play_page_turn_animation() -> void:
	_page_curl_anim.play("turn_to_right")
