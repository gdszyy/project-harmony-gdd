# godot_project/scripts/entities/harmonic_avatar_manager.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 384 | 函数数: 28 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `HarmonicAvatarManager` | class_name | `HarmonicAvatarManager()` |  |
| `mode_changed` | signal | `mode_changed(old_mode_id: int, new_mode_id: int)` |  |
| `avatar_ready` | signal | `avatar_ready()` |  |
| `spellcast_visual_triggered` | signal | `spellcast_visual_triggered(gesture_name: String)` |  |
| `_ready` | function | `_ready()` |  |
| `_process` | function | `_process(_delta: float)` |  |
| `_setup_skeleton` | function | `_setup_skeleton()` |  |
| `_configure_skeleton_for_mode` | function | `_configure_skeleton_for_mode(mode_id: int)` |  |
| `_setup_mode` | function | `_setup_mode(mode_id: int)` |  |
| `switch_mode` | function | `switch_mode(new_mode_id: int)` |  |
| `_connect_game_signals` | function | `_connect_game_signals()` |  |
| `on_beat_pulse` | function | `on_beat_pulse(beat_index: int = 0)` |  |
| `_on_beat_tick` | function | `_on_beat_tick(_beat_index: int = 0)` |  |
| `_on_spell_cast` | function | `_on_spell_cast(spell_data: Dictionary)` |  |
| `_on_chord_cast` | function | `_on_chord_cast(chord_data: Dictionary)` |  |
| `_on_manual_cast` | function | `_on_manual_cast(_slot: int)` |  |
| `_on_class_applied` | function | `_on_class_applied(class_id: String, _class_name: String)` |  |
| `_trigger_spellcast_visual` | function | `_trigger_spellcast_visual(spell_data: Dictionary)` |  |
| `_on_gesture_started` | function | `_on_gesture_started(gesture_name: String)` |  |
| `_on_gesture_finished` | function | `_on_gesture_finished(_gesture_name: String)` |  |
| `apply_damage_visual` | function | `apply_damage_visual(source_direction: Vector3 = Vector3.BACK)` |  |
| `get_current_mode_id` | function | `get_current_mode_id()` |  |
| `get_current_mode_name` | function | `get_current_mode_name()` |  |
| `get_current_mode_node` | function | `get_current_mode_node()` |  |
| `get_skeleton` | function | `get_skeleton()` |  |
| `get_current_shader_material` | function | `get_current_shader_material()` |  |
| `is_transitioning` | function | `is_transitioning()` |  |
| `force_mode` | function | `force_mode(mode_id: int)` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/entities/harmonic_avatar_manager.gd
```
