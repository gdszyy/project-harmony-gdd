# godot_project/scripts/ui/tutorial_sequence.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 558 | 函数数: 26 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `sequence_started` | signal | `sequence_started(sequence_id: String)` |  |
| `sequence_step_changed` | signal | `sequence_step_changed(sequence_id: String, step_index: int)` |  |
| `sequence_completed` | signal | `sequence_completed(sequence_id: String)` |  |
| `sequence_skipped` | signal | `sequence_skipped(sequence_id: String)` |  |
| `all_sequences_completed` | signal | `all_sequences_completed()` |  |
| `_load_tutorial_sequences` | function | `_load_tutorial_sequences()` | 巨型函数 |
| `_ready` | function | `_ready()` |  |
| `_process` | function | `_process(delta: float)` |  |
| `trigger_event` | function | `trigger_event(trigger_id: String)` |  |
| `start_sequence` | function | `start_sequence(sequence_id: String)` |  |
| `advance_step` | function | `advance_step()` |  |
| `skip_current_sequence` | function | `skip_current_sequence()` |  |
| `is_sequence_completed` | function | `is_sequence_completed(sequence_id: String)` |  |
| `is_sequence_viewed` | function | `is_sequence_viewed(sequence_id: String)` |  |
| `is_playing` | function | `is_playing()` |  |
| `get_current_sequence_id` | function | `get_current_sequence_id()` |  |
| `get_current_step_index` | function | `get_current_step_index()` |  |
| `get_reviewable_entries` | function | `get_reviewable_entries()` |  |
| `notify_condition_met` | function | `notify_condition_met(condition: String)` |  |
| `reset_all_progress` | function | `reset_all_progress()` |  |
| `_complete_current_sequence` | function | `_complete_current_sequence()` |  |
| `_cleanup_sequence` | function | `_cleanup_sequence()` |  |
| `_find_hint_manager` | function | `_find_hint_manager()` |  |
| `_save_to_codex` | function | `_save_to_codex(sequence_id: String)` |  |
| `_save_progress` | function | `_save_progress()` |  |
| `_load_progress` | function | `_load_progress()` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/ui/tutorial_sequence.gd
```
