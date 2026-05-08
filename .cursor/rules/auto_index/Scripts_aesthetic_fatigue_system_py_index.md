# Scripts/aesthetic_fatigue_system.py 函数索引

> 自动生成于 2026-05-08 | 总行数: 1395 | 函数数: 39 | 语言: python
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `Note` | class | `Note()` |  |
| `KeyType` | class | `KeyType()` |  |
| `FatigueLevel` | class | `FatigueLevel()` |  |
| `PenaltyMode` | class | `PenaltyMode()` |  |
| `FatigueConfig` | class | `FatigueConfig()` |  |
| `SpellEvent` | class | `SpellEvent()` |  |
| `shannon_entropy` | function | `shannon_entropy(counts: dict, total: int)` |  |
| `weighted_shannon_entropy` | function | `weighted_shannon_entropy(events: list[tuple], decay_func, current_time: float)` |  |
| `transition_entropy` | function | `transition_entropy(sequence: list, vocab_size: int)` |  |
| `ngram_recurrence_rate` | function | `ngram_recurrence_rate(sequence: list, n: int)` |  |
| `quantize_interval` | function | `quantize_interval(interval: float, num_bins: int, max_val: float)` |  |
| `AestheticFatigueEngine` | class | `AestheticFatigueEngine()` |  |
| `__init__` | method | `__init__(self, config: Optional[FatigueConfig] = None)` |  |
| `record_spell` | method | `record_spell(self, event: SpellEvent)` |  |
| `get_note_fatigue_map` | method | `get_note_fatigue_map(self, current_time: float)` |  |
| `reset` | method | `reset(self)` |  |
| `_update_sustained_tracking` | method | `_update_sustained_tracking(self, current_time: float)` |  |
| `_prune_old_events` | method | `_prune_old_events(self, current_time: float)` |  |
| `_decay_weight` | method | `_decay_weight(self, dt: float)` |  |
| `_compute_recurrence` | method | `_compute_recurrence(self, sequence: list)` |  |
| `_compute_sustained_pressure` | method | `_compute_sustained_pressure(self, current_time: float)` |  |
| `_get_sustained_duration` | method | `_get_sustained_duration(self, current_time: float)` |  |
| `_index_to_level` | method | `_index_to_level(self, afi: float)` |  |
| `FatigueComponents` | class | `FatigueComponents()` |  |
| `PenaltyEffect` | class | `PenaltyEffect()` |  |
| `FatigueResult` | class | `FatigueResult()` |  |
| `__repr__` | method | `__repr__(self)` |  |
| `create_easy_config` | function | `create_easy_config()` |  |
| `create_normal_config` | function | `create_normal_config()` |  |
| `create_hard_config` | function | `create_hard_config()` |  |
| `create_maestro_config` | function | `create_maestro_config()` |  |
| `demo_scenario_monotonous` | function | `demo_scenario_monotonous()` |  |
| `demo_scenario_diverse` | function | `demo_scenario_diverse()` |  |
| `demo_scenario_nonstop_barrage` | function | `demo_scenario_nonstop_barrage()` |  |
| `demo_scenario_breathe` | function | `demo_scenario_breathe()` |  |
| `demo_scenario_recovery_with_rest` | function | `demo_scenario_recovery_with_rest()` |  |
| `demo_scenario_penalty_modes` | function | `demo_scenario_penalty_modes()` |  |
| `demo_note_fatigue_map` | function | `demo_note_fatigue_map()` |  |
| `demo_v1_vs_v2_comparison` | function | `demo_v1_vs_v2_comparison()` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" Scripts/aesthetic_fatigue_system.py
```
