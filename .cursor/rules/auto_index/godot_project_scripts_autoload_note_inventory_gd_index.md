# godot_project/scripts/autoload/note_inventory.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 345 | 函数数: 32 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `inventory_changed` | signal | `inventory_changed(note_key: int, new_count: int)` |  |
| `spellbook_changed` | signal | `spellbook_changed(spellbook: Array)` |  |
| `insufficient_notes` | signal | `insufficient_notes(note_key: int)` |  |
| `note_acquired` | signal | `note_acquired(note_key: int, amount: int, source: String)` |  |
| `chord_spell_crafted` | signal | `chord_spell_crafted(chord_spell: Dictionary)` |  |
| `_ready` | function | `_ready()` |  |
| `_on_game_reset_event` | function | `_on_game_reset_event(_payload: Variant = null)` |  |
| `_init_inventory` | function | `_init_inventory()` |  |
| `reset` | function | `reset()` |  |
| `get_note_count` | function | `get_note_count(note_key: int)` |  |
| `get_black_key_count` | function | `get_black_key_count(black_key: int)` |  |
| `has_note` | function | `has_note(note_key: int, amount: int = 1)` |  |
| `has_black_key` | function | `has_black_key(black_key: int, amount: int = 1)` |  |
| `get_inventory_snapshot` | function | `get_inventory_snapshot()` |  |
| `get_total_note_count` | function | `get_total_note_count()` |  |
| `add_note` | function | `add_note(note_key: int, amount: int = 1, source: String = "unknown")` |  |
| `add_random_note` | function | `add_random_note(amount: int = 1, source: String = "level_up")` |  |
| `add_specific_note` | function | `add_specific_note(note_key: int, amount: int = 1, source: String = "upgrade")` |  |
| `add_black_key` | function | `add_black_key(black_key: int, amount: int = 1)` |  |
| `equip_note` | function | `equip_note(note_key: int)` |  |
| `equip_black_key` | function | `equip_black_key(black_key: int)` |  |
| `unequip_note` | function | `unequip_note(note_key: int)` |  |
| `unequip_black_key` | function | `unequip_black_key(black_key: int)` |  |
| `consume_notes_for_alchemy` | function | `consume_notes_for_alchemy(notes_to_consume: Array)` |  |
| `get_chord_spell` | function | `get_chord_spell(spell_id: String)` |  |
| `get_available_chord_spells` | function | `get_available_chord_spells()` |  |
| `mark_spell_equipped` | function | `mark_spell_equipped(spell_id: String, location: String)` |  |
| `mark_spell_unequipped` | function | `mark_spell_unequipped(spell_id: String)` |  |
| `get_spellbook_size` | function | `get_spellbook_size()` |  |
| `pickup_note_crystal` | function | `pickup_note_crystal(note_key: int = -1)` |  |
| `serialize` | function | `serialize()` |  |
| `deserialize` | function | `deserialize(data: Dictionary)` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/autoload/note_inventory.gd
```
