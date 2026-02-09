## note_inventory.gd
## 音符经济系统 (Autoload)
## 管理玩家的音符库存、法术书（已合成和弦）、装备/卸下/消耗生命周期
##
## 设计要点：
##   - 音符是消耗品资源，每种白键音符独立堆叠
##   - 装备到序列器/手动施法槽时从库存扣除
##   - 从序列器/手动施法槽移除时返回库存
##   - 和弦炼成时永久消耗音符，生成的和弦法术存入法术书
##   - 法术书中的和弦法术可反复装备/卸下，不会被销毁
extends Node

# ============================================================
# 信号
# ============================================================
## 库存变化时触发（note_key: WhiteKey, new_count: int）
signal inventory_changed(note_key: int, new_count: int)
## 法术书变化时触发
signal spellbook_changed(spellbook: Array)
## 库存不足时触发（尝试装备但数量为0）
signal insufficient_notes(note_key: int)
## 音符获得时触发（用于UI动画）
signal note_acquired(note_key: int, amount: int, source: String)
## 和弦法术合成成功
signal chord_spell_crafted(chord_spell: Dictionary)

# ============================================================
# 常量
# ============================================================
## 每种音符的最大堆叠数量
const MAX_STACK_SIZE: int = 99

## 初始音符配置（游戏开局时的音符组合）
const STARTING_NOTES := {
	0: 4,  # C × 4
	1: 2,  # D × 2
	2: 2,  # E × 2
	3: 2,  # F × 2
	4: 3,  # G × 3
	5: 2,  # A × 2
	6: 1,  # B × 1
}

## 黑键修饰符初始库存
const STARTING_BLACK_KEYS := {
	0: 1,  # C# × 1
	1: 1,  # D# × 1
	2: 1,  # F# × 1
	3: 1,  # G# × 1
	4: 1,  # A# × 1
}

# ============================================================
# 音符库存
# ============================================================
## 白键音符库存 { WhiteKey(int): count(int) }
var note_inventory: Dictionary = {}

## 黑键修饰符库存 { BlackKey(int): count(int) }
var black_key_inventory: Dictionary = {}

# ============================================================
# 法术书（已合成的和弦法术）
# ============================================================
## 法术书：存储所有已合成的和弦法术
## 每个条目: {
##   "id": String (唯一ID),
##   "chord_type": MusicData.ChordType,
##   "chord_notes": Array[int] (MIDI音符),
##   "root_note": int (根音 WhiteKey),
##   "spell_form": String,
##   "spell_name": String,
##   "is_equipped": bool (是否已装备到某个槽位),
##   "equipped_location": String ("" / "sequencer_M1" / "manual_0" 等),
## }
var spellbook: Array[Dictionary] = []

## 法术书中下一个可用的ID
var _next_spell_id: int = 1

# ============================================================
# 生命周期
# ============================================================

func _ready() -> void:
	_init_inventory()

# ============================================================
# 初始化
# ============================================================

## 初始化库存为开局配置
func _init_inventory() -> void:
	note_inventory.clear()
	black_key_inventory.clear()

	# 初始化白键库存
	for key in MusicData.WhiteKey.values():
		note_inventory[key] = STARTING_NOTES.get(key, 0)

	# 初始化黑键库存
	for key in MusicData.BlackKey.values():
		black_key_inventory[key] = STARTING_BLACK_KEYS.get(key, 0)

## 完全重置（新游戏开始时调用）
func reset() -> void:
	_init_inventory()
	spellbook.clear()
	_next_spell_id = 1

	# 通知所有监听者
	for key in note_inventory.keys():
		inventory_changed.emit(key, note_inventory[key])
	spellbook_changed.emit(spellbook)

# ============================================================
# 库存查询
# ============================================================

## 获取某种音符的当前数量
func get_note_count(note_key: int) -> int:
	return note_inventory.get(note_key, 0)

## 获取某种黑键的当前数量
func get_black_key_count(black_key: int) -> int:
	return black_key_inventory.get(black_key, 0)

## 检查是否有足够的音符
func has_note(note_key: int, amount: int = 1) -> bool:
	return get_note_count(note_key) >= amount

## 检查是否有足够的黑键
func has_black_key(black_key: int, amount: int = 1) -> bool:
	return get_black_key_count(black_key) >= amount

## 获取所有音符的库存快照
func get_inventory_snapshot() -> Dictionary:
	return note_inventory.duplicate()

## 获取库存中音符的总数
func get_total_note_count() -> int:
	var total: int = 0
	for count in note_inventory.values():
		total += count
	return total

# ============================================================
# 音符获取（增加库存）
# ============================================================

## 添加音符到库存
func add_note(note_key: int, amount: int = 1, source: String = "unknown") -> void:
	if not note_inventory.has(note_key):
		return
	note_inventory[note_key] = min(note_inventory[note_key] + amount, MAX_STACK_SIZE)
	inventory_changed.emit(note_key, note_inventory[note_key])
	note_acquired.emit(note_key, amount, source)

## 添加随机音符到库存
func add_random_note(amount: int = 1, source: String = "level_up") -> int:
	var keys := note_inventory.keys()
	var random_key: int = keys[randi() % keys.size()]
	add_note(random_key, amount, source)
	return random_key

## 添加指定音符到库存（用于升级选择等）
func add_specific_note(note_key: int, amount: int = 1, source: String = "upgrade") -> void:
	add_note(note_key, amount, source)

## 添加黑键修饰符到库存
func add_black_key(black_key: int, amount: int = 1) -> void:
	if not black_key_inventory.has(black_key):
		return
	black_key_inventory[black_key] = min(black_key_inventory[black_key] + amount, MAX_STACK_SIZE)

# ============================================================
# 音符装备（从库存扣除，放入法术槽）
# ============================================================

## 装备音符到法术槽（库存 -1）
## 返回 true 表示成功，false 表示库存不足
func equip_note(note_key: int) -> bool:
	if not has_note(note_key):
		insufficient_notes.emit(note_key)
		return false
	note_inventory[note_key] -= 1
	inventory_changed.emit(note_key, note_inventory[note_key])
	return true

## 装备黑键修饰符
func equip_black_key(black_key: int) -> bool:
	if not has_black_key(black_key):
		return false
	black_key_inventory[black_key] -= 1
	return true

# ============================================================
# 音符卸下（从法术槽移除，返回库存）
# ============================================================

## 卸下音符，返回库存（库存 +1）
func unequip_note(note_key: int) -> void:
	if not note_inventory.has(note_key):
		return
	note_inventory[note_key] = min(note_inventory[note_key] + 1, MAX_STACK_SIZE)
	inventory_changed.emit(note_key, note_inventory[note_key])

## 卸下黑键修饰符
func unequip_black_key(black_key: int) -> void:
	if not black_key_inventory.has(black_key):
		return
	black_key_inventory[black_key] = min(black_key_inventory[black_key] + 1, MAX_STACK_SIZE)

# ============================================================
# 音符永久消耗（和弦炼成专用）
# ============================================================

## 消耗多个音符用于和弦炼成
## 返回 true 表示成功消耗，false 表示库存不足
func consume_notes_for_alchemy(notes_to_consume: Array) -> bool:
	# 先检查所有音符是否充足
	var required: Dictionary = {}
	for note_key in notes_to_consume:
		required[note_key] = required.get(note_key, 0) + 1

	for note_key in required.keys():
		if get_note_count(note_key) < required[note_key]:
			insufficient_notes.emit(note_key)
			return false

	# 全部充足，执行消耗
	for note_key in required.keys():
		note_inventory[note_key] -= required[note_key]
		inventory_changed.emit(note_key, note_inventory[note_key])

	return true

# ============================================================
# 法术书管理
# ============================================================

## 将合成的和弦法术添加到法术书
func add_chord_spell(chord_type: int, chord_notes: Array, root_note: int,
		spell_form: String, spell_name: String) -> Dictionary:
	var spell := {
		"id": "chord_spell_%d" % _next_spell_id,
		"chord_type": chord_type,
		"chord_notes": chord_notes,
		"root_note": root_note,
		"spell_form": spell_form,
		"spell_name": spell_name,
		"is_equipped": false,
		"equipped_location": "",
	}
	_next_spell_id += 1
	spellbook.append(spell)
	spellbook_changed.emit(spellbook)
	chord_spell_crafted.emit(spell)
	return spell

## 从法术书中获取指定ID的和弦法术
func get_chord_spell(spell_id: String) -> Dictionary:
	for spell in spellbook:
		if spell["id"] == spell_id:
			return spell
	return {}

## 获取法术书中所有未装备的和弦法术
func get_available_chord_spells() -> Array[Dictionary]:
	var available: Array[Dictionary] = []
	for spell in spellbook:
		if not spell["is_equipped"]:
			available.append(spell)
	return available

## 标记和弦法术为已装备
func mark_spell_equipped(spell_id: String, location: String) -> void:
	for spell in spellbook:
		if spell["id"] == spell_id:
			spell["is_equipped"] = true
			spell["equipped_location"] = location
			spellbook_changed.emit(spellbook)
			return

## 标记和弦法术为未装备（返回法术书）
func mark_spell_unequipped(spell_id: String) -> void:
	for spell in spellbook:
		if spell["id"] == spell_id:
			spell["is_equipped"] = false
			spell["equipped_location"] = ""
			spellbook_changed.emit(spellbook)
			return

## 获取法术书大小
func get_spellbook_size() -> int:
	return spellbook.size()

# ============================================================
# 敌人掉落：音符晶片拾取
# ============================================================

## 处理音符晶片拾取（由 xp_pickup 或类似系统调用）
func pickup_note_crystal(note_key: int = -1) -> void:
	if note_key < 0:
		# 随机音符
		add_random_note(1, "enemy_drop")
	else:
		add_note(note_key, 1, "enemy_drop")

# ============================================================
# 序列化（存档支持）
# ============================================================

## 导出为可序列化的字典
func serialize() -> Dictionary:
	return {
		"note_inventory": note_inventory.duplicate(),
		"black_key_inventory": black_key_inventory.duplicate(),
		"spellbook": spellbook.duplicate(true),
		"next_spell_id": _next_spell_id,
	}

## 从字典恢复状态
func deserialize(data: Dictionary) -> void:
	if data.has("note_inventory"):
		note_inventory = data["note_inventory"].duplicate()
	if data.has("black_key_inventory"):
		black_key_inventory = data["black_key_inventory"].duplicate()
	if data.has("spellbook"):
		spellbook.clear()
		for spell in data["spellbook"]:
			spellbook.append(spell.duplicate(true))
	if data.has("next_spell_id"):
		_next_spell_id = data["next_spell_id"]

	# 通知所有监听者
	for key in note_inventory.keys():
		inventory_changed.emit(key, note_inventory[key])
	spellbook_changed.emit(spellbook)
