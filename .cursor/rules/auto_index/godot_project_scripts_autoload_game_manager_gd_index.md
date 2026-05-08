# godot_project/scripts/autoload/game_manager.gd 函数索引

> 自动生成于 2026-05-08 | 总行数: 566 | 函数数: 54 | 语言: gdscript
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `beat_tick` | signal | `beat_tick(beat_index: int)` |  |
| `half_beat_tick` | signal | `half_beat_tick(half_beat_index: int)` |  |
| `measure_complete` | signal | `measure_complete(measure_index: int)` |  |
| `game_state_changed` | signal | `game_state_changed(new_state: GameState)` |  |
| `player_hp_changed` | signal | `player_hp_changed(current_hp: float, max_hp: float)` |  |
| `player_damaged` | signal | `player_damaged(damage: float, source_position: Vector2)` |  |
| `player_died` | signal | `player_died()` |  |
| `enemy_killed` | signal | `enemy_killed(enemy_position: Vector2, enemy_type: String)` |  |
| `xp_gained` | signal | `xp_gained(amount: int)` |  |
| `level_up` | signal | `level_up(new_level: int)` |  |
| `upgrade_selected` | signal | `upgrade_selected(upgrade: Dictionary)` |  |
| `chapter_timbre_changed` | signal | `chapter_timbre_changed(new_timbre: int)` |  |
| `inscription_acquired` | signal | `inscription_acquired(inscription: Dictionary)` |  |
| `easter_egg_triggered` | signal | `easter_egg_triggered(egg: Dictionary)` |  |
| `GameState` | enum | `GameState()` |  |
| `_ready` | function | `_ready()` |  |
| `_process` | function | `_process(delta: float)` |  |
| `_process_beat` | function | `_process_beat(delta: float)` |  |
| `_update_beat_interval` | function | `_update_beat_interval()` |  |
| `_reset_common_state` | function | `_reset_common_state()` |  |
| `reset_game` | function | `reset_game()` |  |
| `start_game` | function | `start_game()` |  |
| `pause_game` | function | `pause_game()` |  |
| `resume_game` | function | `resume_game()` |  |
| `game_over` | function | `game_over()` |  |
| `enter_upgrade_select` | function | `enter_upgrade_select()` |  |
| `damage_player` | function | `damage_player(amount: float, source_position: Vector2 = Vector2.ZERO)` |  |
| `heal_player` | function | `heal_player(amount: float)` |  |
| `apply_dissonance_damage` | function | `apply_dissonance_damage(dissonance: float)` |  |
| `add_xp` | function | `add_xp(amount: int)` |  |
| `apply_upgrade` | function | `apply_upgrade(upgrade: Dictionary)` |  |
| `_apply_note_acquire_upgrade` | function | `_apply_note_acquire_upgrade(upgrade: Dictionary)` |  |
| `_apply_note_stat_upgrade` | function | `_apply_note_stat_upgrade(upgrade: Dictionary)` |  |
| `_apply_fatigue_resist_upgrade` | function | `_apply_fatigue_resist_upgrade(upgrade: Dictionary)` |  |
| `_apply_rhythm_mastery_upgrade` | function | `_apply_rhythm_mastery_upgrade(upgrade: Dictionary)` |  |
| `_apply_chord_mastery_upgrade` | function | `_apply_chord_mastery_upgrade(upgrade: Dictionary)` |  |
| `_apply_survival_upgrade` | function | `_apply_survival_upgrade(upgrade: Dictionary)` |  |
| `_apply_timbre_mastery_upgrade` | function | `_apply_timbre_mastery_upgrade(upgrade: Dictionary)` |  |
| `_apply_inscription_upgrade` | function | `_apply_inscription_upgrade(upgrade: Dictionary)` |  |
| `_apply_modifier_mastery_upgrade` | function | `_apply_modifier_mastery_upgrade(upgrade: Dictionary)` |  |
| `_apply_special_upgrade` | function | `_apply_special_upgrade(upgrade: Dictionary)` |  |
| `_init_note_bonuses` | function | `_init_note_bonuses()` |  |
| `get_note_effective_stats` | function | `get_note_effective_stats(white_key: MusicData.WhiteKey)` |  |
| `get_beat_progress` | function | `get_beat_progress()` |  |
| `get_beat_in_measure` | function | `get_beat_in_measure()` |  |
| `get_bpm` | function | `get_bpm()` |  |
| `activate_chapter_timbre` | function | `activate_chapter_timbre(chapter: int)` |  |
| `switch_timbre` | function | `switch_timbre(timbre: int)` |  |
| `acquire_inscription` | function | `acquire_inscription(inscription: Dictionary)` |  |
| `get_unacquired_inscriptions` | function | `get_unacquired_inscriptions()` |  |
| `_check_music_history_easter_eggs` | function | `_check_music_history_easter_eggs()` |  |
| `is_current_chapter_timbre` | function | `is_current_chapter_timbre()` |  |
| `get_inscription_synergy_active` | function | `get_inscription_synergy_active(inscription: Dictionary)` |  |
| `_award_resonance_fragments` | function | `_award_resonance_fragments()` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" godot_project/scripts/autoload/game_manager.gd
```
