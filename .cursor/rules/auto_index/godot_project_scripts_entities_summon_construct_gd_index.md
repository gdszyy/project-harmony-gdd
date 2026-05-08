# godot_project/scripts/entities/summon_construct.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 650 | 函数数: 31 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `construct_expired` | signal | `construct_expired(construct_id: int)` |  |
| `construct_action` | signal | `construct_action(construct_id: int, action_name: String)` |  |
| `construct_excited` | signal | `construct_excited(construct_id: int)` |  |
| `ConstructCategory` | enum | `ConstructCategory()` |  |
| `_ready` | function | `_ready()` |  |
| `_process` | function | `_process(delta: float)` |  |
| `_on_beat` | function | `_on_beat(beat_index: int)` |  |
| `_perform_action` | function | `_perform_action(is_strong: bool, multiplier: float)` |  |
| `_action_rhythm_tower` | function | `_action_rhythm_tower(mult: float)` |  |
| `_action_prism` | function | `_action_prism(_mult: float)` |  |
| `_action_bass_wall` | function | `_action_bass_wall(mult: float)` |  |
| `_action_cleanse` | function | `_action_cleanse(_mult: float)` |  |
| `_action_sub_bass` | function | `_action_sub_bass(mult: float)` |  |
| `_action_harmony_aura` | function | `_action_harmony_aura(mult: float)` |  |
| `_action_hi_hat_trap` | function | `_action_hi_hat_trap(mult: float)` |  |
| `_update_continuous_effects` | function | `_update_continuous_effects(_delta: float)` |  |
| `_prism_enhance_projectiles` | function | `_prism_enhance_projectiles()` |  |
| `excite` | function | `excite()` |  |
| `update_network` | function | `update_network(all_constructs: Array)` |  |
| `_fire_projectile` | function | `_fire_projectile(dir: Vector2, damage: float, speed: float)` |  |
| `_find_nearest_enemy` | function | `_find_nearest_enemy(max_range: float)` |  |
| `_create_visual` | function | `_create_visual()` |  |
| `_play_spawn_animation` | function | `_play_spawn_animation()` |  |
| `_update_visual` | function | `_update_visual(_delta: float)` |  |
| `_beat_visual_pulse` | function | `_beat_visual_pulse(is_strong: bool)` |  |
| `_play_excitation_visual` | function | `_play_excitation_visual()` |  |
| `_start_fade_out` | function | `_start_fade_out()` |  |
| `_setup_audio_controller` | function | `_setup_audio_controller()` |  |
| `_trigger_event_audio` | function | `_trigger_event_audio()` |  |
| `get_audio_info` | function | `get_audio_info()` |  |
| `_setup_vfx_controller` | function | `_setup_vfx_controller()` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/entities/summon_construct.gd
```
