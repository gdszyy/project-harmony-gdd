# godot_project/scripts/autoload/global_music_manager.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 511 | 函数数: 23 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `beat_energy_updated` | signal | `beat_energy_updated(energy: float)` |  |
| `spectrum_updated` | signal | `spectrum_updated(low: float, mid: float, high: float)` |  |
| `note_played` | signal | `note_played(note: int, timbre: int)` |  |
| `chord_played` | signal | `chord_played(notes: Array, timbre: int)` |  |
| `request_spell_sfx` | signal | `request_spell_sfx(position: Vector2, is_perfect_beat: bool)` |  |
| `request_chord_sfx` | signal | `request_chord_sfx(position: Vector2)` |  |
| `_ready` | function | `_ready()` |  |
| `_init_synth_manager_integration` | function | `_init_synth_manager_integration()` |  |
| `_process` | function | `_process(_delta: float)` |  |
| `_connect_sfx_signals` | function | `_connect_sfx_signals()` |  |
| `_deferred_connect_sfx` | function | `_deferred_connect_sfx()` |  |
| `_setup_audio_buses` | function | `_setup_audio_buses()` |  |
| `_init_synthesizer` | function | `_init_synthesizer()` |  |
| `_init_note_pool` | function | `_init_note_pool()` |  |
| `_update_spectrum_analysis` | function | `_update_spectrum_analysis()` |  |
| `get_beat_energy` | function | `get_beat_energy()` |  |
| `get_spectrum` | function | `get_spectrum()` |  |
| `set_timbre` | function | `set_timbre(timbre: int)` |  |
| `get_current_timbre` | function | `get_current_timbre()` |  |
| `_get_audio_manager` | function | `_get_audio_manager()` | 巨型函数 |
| `_get_note_player` | function | `_get_note_player()` |  |
| `_check_note_cooldown` | function | `_check_note_cooldown(key: String)` |  |
| `_velocity_to_db` | function | `_velocity_to_db(velocity: float)` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/autoload/global_music_manager.gd
```
