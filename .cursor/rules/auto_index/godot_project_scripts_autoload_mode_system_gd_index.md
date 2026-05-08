# godot_project/scripts/autoload/mode_system.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 298 | 函数数: 26 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `mode_changed` | signal | `mode_changed(mode_id: String)` |  |
| `crit_from_dissonance` | signal | `crit_from_dissonance(crit_chance: float)` |  |
| `transpose_changed` | signal | `transpose_changed(semitone_offset: int)` |  |
| `_ready` | function | `_ready()` |  |
| `_on_game_started_event` | function | `_on_game_started_event(payload: Variant)` |  |
| `_on_game_reset_event` | function | `_on_game_reset_event(_payload: Variant = null)` |  |
| `apply_mode` | function | `apply_mode(mode_id: String)` |  |
| `reset` | function | `reset()` |  |
| `is_white_key_available` | function | `is_white_key_available(white_key: MusicData.WhiteKey)` |  |
| `get_damage_multiplier` | function | `get_damage_multiplier()` |  |
| `get_dissonance_multiplier` | function | `get_dissonance_multiplier()` |  |
| `get_current_mode_info` | function | `get_current_mode_info()` |  |
| `get_available_key_names` | function | `get_available_key_names()` |  |
| `on_spell_cast` | function | `on_spell_cast()` |  |
| `on_dissonance_applied` | function | `on_dissonance_applied(dissonance: float)` |  |
| `check_crit` | function | `check_crit()` |  |
| `get_crit_chance` | function | `get_crit_chance()` |  |
| `is_transpose_unlocked` | function | `is_transpose_unlocked()` |  |
| `set_transpose` | function | `set_transpose(semitones: int)` |  |
| `transpose_up` | function | `transpose_up()` |  |
| `transpose_down` | function | `transpose_down()` |  |
| `reset_transpose` | function | `reset_transpose()` |  |
| `get_current_key_name` | function | `get_current_key_name()` |  |
| `apply_transpose` | function | `apply_transpose(note: int)` |  |
| `get_pitch_shift` | function | `get_pitch_shift()` |  |
| `get_transpose_info` | function | `get_transpose_info()` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/autoload/mode_system.gd
```
