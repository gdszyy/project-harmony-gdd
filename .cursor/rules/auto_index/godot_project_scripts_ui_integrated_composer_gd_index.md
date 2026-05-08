# godot_project/scripts/ui/integrated_composer.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 381 | 函数数: 31 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `IntegratedComposer` | class_name | `IntegratedComposer()` |  |
| `note_placed` | signal | `note_placed(cell_idx: int, note: int)` |  |
| `cell_cleared` | signal | `cell_cleared(cell_idx: int)` |  |
| `chord_crafted` | signal | `chord_crafted(chord_spell: Dictionary)` |  |
| `alchemy_completed` | signal | `alchemy_completed(chord_spell: Dictionary)` |  |
| `manual_slot_configured` | signal | `manual_slot_configured(slot_index: int, spell_data: Dictionary)` |  |
| `panel_toggled` | signal | `panel_toggled(is_open: bool)` |  |
| `_ready` | function | `_ready()` |  |
| `_connect_child_signals` | function | `_connect_child_signals()` |  |
| `_unhandled_input` | function | `_unhandled_input(event: InputEvent)` |  |
| `toggle` | function | `toggle()` |  |
| `open_panel` | function | `open_panel()` |  |
| `close_panel` | function | `close_panel()` |  |
| `refresh_spellbook` | function | `refresh_spellbook()` |  |
| `_refresh_all_panels` | function | `_refresh_all_panels()` |  |
| `_update_info_bar` | function | `_update_info_bar(title: String, desc: String, color: Color = THEME_TEXT_COLOR)` |  |
| `_clear_info_bar` | function | `_clear_info_bar()` |  |
| `_on_seq_note_placed` | function | `_on_seq_note_placed(cell_idx: int, note_key: int)` |  |
| `_on_seq_cell_cleared` | function | `_on_seq_cell_cleared(cell_idx: int)` |  |
| `_on_alchemy_completed` | function | `_on_alchemy_completed(chord_spell_data: Dictionary)` |  |
| `_on_manual_slot_configured` | function | `_on_manual_slot_configured(slot_index: int, spell_data: Dictionary)` |  |
| `_on_info_hover` | function | `_on_info_hover(title: String, desc: String, color: Color)` |  |
| `_on_beat_tick` | function | `_on_beat_tick(_beat_index: int)` |  |
| `_on_inventory_changed` | function | `_on_inventory_changed(_note_key: int, _new_count: int)` |  |
| `_on_spellbook_changed` | function | `_on_spellbook_changed(_spellbook: Array)` |  |
| `_on_sequencer_updated` | function | `_on_sequencer_updated(_sequence)` |  |
| `get_note_color` | static_func | `get_note_color(note_key: int)` |  |
| `get_black_key_color` | static_func | `get_black_key_color(black_key_idx: int)` |  |
| `get_note_name` | static_func | `get_note_name(note_key: int)` |  |
| `get_black_key_name` | static_func | `get_black_key_name(black_key_idx: int)` |  |
| `create_panel_stylebox` | static_func | `create_panel_stylebox(bg_alpha: float = 0.8)` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/ui/integrated_composer.gd
```
