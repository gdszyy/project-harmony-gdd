# godot_project/scripts/autoload/codex_manager.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 424 | 函数数: 30 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `entry_unlocked` | signal | `entry_unlocked(entry_id: String, entry_name: String, volume: CodexData.Volume)` |  |
| `milestone_reached` | signal | `milestone_reached(entry_id: String, milestone: int, current_kills: int)` |  |
| `completion_updated` | signal | `completion_updated(volume: CodexData.Volume, unlocked: int, total: int)` |  |
| `_ready` | function | `_ready()` |  |
| `_load_codex_data` | function | `_load_codex_data()` |  |
| `_unlock_default_entries` | function | `_unlock_default_entries()` |  |
| `_connect_signals` | function | `_connect_signals()` |  |
| `unlock_entry` | function | `unlock_entry(entry_id: String)` |  |
| `_unlock_entry_internal` | function | `_unlock_entry_internal(entry_id: String, emit_signal: bool)` |  |
| `get_unlocked_entries` | function | `get_unlocked_entries()` |  |
| `is_unlocked` | function | `is_unlocked(entry_id: String)` |  |
| `unlock_all` | function | `unlock_all()` |  |
| `reset_all` | function | `reset_all()` |  |
| `record_kill` | function | `record_kill(enemy_key: String)` |  |
| `get_kill_count` | function | `get_kill_count(enemy_key: String)` |  |
| `_check_kill_milestones` | function | `_check_kill_milestones(entry_id: String, current_kills: int)` |  |
| `get_milestone_progress` | function | `get_milestone_progress(entry_id: String)` |  |
| `get_volume_completion` | function | `get_volume_completion(volume: CodexData.Volume)` |  |
| `get_total_completion` | function | `get_total_completion()` |  |
| `_rebuild_completion_cache` | function | `_rebuild_completion_cache()` |  |
| `_on_enemy_killed` | function | `_on_enemy_killed(enemy_position: Vector2, enemy_type: String = "static")` |  |
| `_on_spell_cast` | function | `_on_spell_cast(spell_data: Dictionary)` |  |
| `_on_chord_cast` | function | `_on_chord_cast(chord_data: Dictionary)` |  |
| `on_enemy_died` | function | `on_enemy_died(_position: Vector2, _xp_value: int, enemy_type: String)` |  |
| `_save_entry` | function | `_save_entry(entry_id: String)` |  |
| `_save_kill_count` | function | `_save_kill_count(enemy_key: String)` |  |
| `_save_milestones` | function | `_save_milestones(entry_id: String)` |  |
| `_save_all` | function | `_save_all()` |  |
| `_get_entry_volume` | function | `_get_entry_volume(entry_id: String)` |  |
| `get_unlocked_entries_for_volume` | function | `get_unlocked_entries_for_volume(volume: CodexData.Volume)` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/autoload/codex_manager.gd
```
