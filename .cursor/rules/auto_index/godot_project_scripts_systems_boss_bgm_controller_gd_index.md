# godot_project/scripts/systems/boss_bgm_controller.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 498 | 函数数: 21 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `BossBGMController` | class_name | `BossBGMController()` |  |
| `boss_bgm_started` | signal | `boss_bgm_started(boss_key: String)` |  |
| `boss_bgm_ended` | signal | `boss_bgm_ended()` |  |
| `boss_bgm_phase_changed` | signal | `boss_bgm_phase_changed(phase_index: int)` |  |
| `_ready` | function | `_ready()` |  |
| `enter_boss_bgm` | function | `enter_boss_bgm(boss_key: String)` |  |
| `exit_boss_bgm` | function | `exit_boss_bgm()` |  |
| `on_boss_phase_changed` | function | `on_boss_phase_changed(phase_index: int)` |  |
| `is_boss_bgm_active` | function | `is_boss_bgm_active()` |  |
| `_apply_boss_bgm_config` | function | `_apply_boss_bgm_config(config: Dictionary)` |  |
| `_apply_phase_config` | function | `_apply_phase_config(base_config: Dictionary, phase_config: Dictionary)` |  |
| `_save_current_state` | function | `_save_current_state()` |  |
| `_restore_saved_state` | function | `_restore_saved_state()` |  |
| `_transition_bpm` | function | `_transition_bpm(target_bpm: float)` |  |
| `_transition_intensity` | function | `_transition_intensity(target_intensity: float)` |  |
| `_adjust_layer_volumes` | function | `_adjust_layer_volumes(kick_boost: float, pad_adjust: float)` |  |
| `_apply_pitch_shift` | function | `_apply_pitch_shift(shift: float)` |  |
| `_on_boss_fight_started` | function | `_on_boss_fight_started(boss_name: String)` |  |
| `_on_boss_fight_ended` | function | `_on_boss_fight_ended(_boss_name: String, _victory: bool)` |  |
| `_get_bgm_manager` | function | `_get_bgm_manager()` |  |
| `_resolve_boss_key` | function | `_resolve_boss_key(boss_name: String)` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/systems/boss_bgm_controller.gd
```
