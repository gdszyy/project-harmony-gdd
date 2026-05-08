# godot_project/scripts/systems/boss_arena_decorator.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 669 | 函数数: 29 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `BossArenaDecorator` | class_name | `BossArenaDecorator()` |  |
| `arena_activated` | signal | `arena_activated(boss_key: String)` |  |
| `arena_deactivated` | signal | `arena_deactivated()` |  |
| `arena_phase_changed` | signal | `arena_phase_changed(phase_index: int)` |  |
| `_ready` | function | `_ready()` |  |
| `_build_environment_layers` | function | `_build_environment_layers()` |  |
| `activate_boss_arena` | function | `activate_boss_arena(boss_key: String)` |  |
| `deactivate_boss_arena` | function | `deactivate_boss_arena()` |  |
| `on_boss_phase_changed` | function | `on_boss_phase_changed(phase_index: int)` |  |
| `is_arena_active` | function | `is_arena_active()` |  |
| `_apply_arena_config` | function | `_apply_arena_config(config: Dictionary)` |  |
| `_create_particles` | function | `_create_particles(config: Dictionary)` |  |
| `_clear_particles` | function | `_clear_particles()` |  |
| `_create_geometric_particles` | function | `_create_geometric_particles(color: Color)` |  |
| `_create_rising_particles` | function | `_create_rising_particles(color: Color)` |  |
| `_create_clockwork_particles` | function | `_create_clockwork_particles(color: Color)` |  |
| `_create_sparkle_particles` | function | `_create_sparkle_particles(color: Color)` |  |
| `_create_storm_particles` | function | `_create_storm_particles(color: Color)` |  |
| `_create_smoke_particles` | function | `_create_smoke_particles(color: Color)` |  |
| `_create_glitch_particles` | function | `_create_glitch_particles(color: Color)` |  |
| `_create_base_particles` | function | `_create_base_particles()` |  |
| `_fade_in_arena` | function | `_fade_in_arena()` |  |
| `_fade_out_arena` | function | `_fade_out_arena()` |  |
| `_transition_phase_color` | function | `_transition_phase_color(new_color: Color)` |  |
| `_hide_all` | function | `_hide_all()` |  |
| `_process` | function | `_process(delta: float)` |  |
| `_update_beat_pulse` | function | `_update_beat_pulse(_delta: float)` |  |
| `_update_glitch_effect` | function | `_update_glitch_effect(_delta: float)` |  |
| `_notify_visual_manager` | function | `_notify_visual_manager(boss_key: String, entering: bool)` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/systems/boss_arena_decorator.gd
```
