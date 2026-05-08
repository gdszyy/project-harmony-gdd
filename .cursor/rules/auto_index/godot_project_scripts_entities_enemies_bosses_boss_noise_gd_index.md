# godot_project/scripts/entities/enemies/bosses/boss_noise.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 1141 | 函数数: 36 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `WaveformType` | enum | `WaveformType()` |  |
| `_on_boss_ready` | function | `_on_boss_ready()` |  |
| `_define_phases` | function | `_define_phases()` |  |
| `_on_boss_process` | function | `_on_boss_process(delta: float)` |  |
| `_switch_waveform` | function | `_switch_waveform()` |  |
| `_perform_attack` | function | `_perform_attack(attack: Dictionary)` |  |
| `_spawn_noise_projectile` | function | `_spawn_noise_projectile(config: Dictionary)` |  |
| `_attack_sine_wave_sweep` | function | `_attack_sine_wave_sweep(attack_data: Dictionary)` |  |
| `_attack_square_grid` | function | `_attack_square_grid(attack_data: Dictionary)` |  |
| `_attack_sawtooth_slash` | function | `_attack_sawtooth_slash(attack_data: Dictionary)` |  |
| `_attack_noise_burst` | function | `_attack_noise_burst(attack_data: Dictionary)` |  |
| `_attack_data_stream` | function | `_attack_data_stream(attack_data: Dictionary)` |  |
| `_attack_bitcrush_zone` | function | `_attack_bitcrush_zone(_attack_data: Dictionary)` |  |
| `_attack_glitch_teleport_assault` | function | `_attack_glitch_teleport_assault(attack_data: Dictionary)` |  |
| `_attack_waveform_combo` | function | `_attack_waveform_combo(attack_data: Dictionary)` |  |
| `_attack_frequency_sweep` | function | `_attack_frequency_sweep(attack_data: Dictionary)` |  |
| `_attack_singularity_collapse` | function | `_attack_singularity_collapse(attack_data: Dictionary)` |  |
| `_on_beat` | function | `_on_beat(beat_index: int)` |  |
| `_on_phase_entered` | function | `_on_phase_entered(phase_index: int, _config: Dictionary)` |  |
| `take_damage` | function | `take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO, is_perfect_beat: bool = false)` |  |
| `_on_death_effect` | function | `_on_death_effect()` |  |
| `_start_frequency_shift` | function | `_start_frequency_shift()` |  |
| `_start_spectrum_collapse` | function | `_start_spectrum_collapse()` |  |
| `_update_spectrum_collapse` | function | `_update_spectrum_collapse(_delta: float)` |  |
| `_play_diminished_13th_chord` | function | `_play_diminished_13th_chord()` |  |
| `_stop_all_attacks` | function | `_stop_all_attacks()` |  |
| `_get_attack_data_by_name` | function | `_get_attack_data_by_name(attack_name: String)` |  |
| `_update_glitch_visual` | function | `_update_glitch_visual(delta: float)` |  |
| `_update_afterimages` | function | `_update_afterimages(delta: float)` |  |
| `_get_type_name` | function | `_get_type_name()` |  |
| `_get_custom_projectile_logics` | function | `_get_custom_projectile_logics()` |  |
| `_sine_wave_projectile_logic` | function | `_sine_wave_projectile_logic(proj: Node2D)` |  |
| `_random_walk_projectile_logic` | function | `_random_walk_projectile_logic(proj: Node2D)` |  |
| `_on_player_phase_changed` | function | `_on_player_phase_changed(phase_id: int)` |  |
| `_set_attack_weight` | function | `_set_attack_weight(attack_name: String, weight: float)` |  |
| `_reset_attack_weights` | function | `_reset_attack_weights()` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/entities/enemies/bosses/boss_noise.gd
```
