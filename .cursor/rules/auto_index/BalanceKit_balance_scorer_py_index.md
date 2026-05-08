# BalanceKit/balance_scorer.py 函数索引

> 自动生成于 2026-05-08 | 总行数: 1180 | 函数数: 32 | 语言: python
> **本文件由 code-indexer 兼容脚本自动生成，严禁手动编辑。**

## 函数 / 类型列表

| 名称 | 类型 | 签名 / 参数 | 备注 |
|------|------|-------------|------|
| `NoteStats` | class | `NoteStats()` |  |
| `total_dmg` | method | `total_dmg(self)` |  |
| `total_spd` | method | `total_spd(self)` |  |
| `total_dur` | method | `total_dur(self)` |  |
| `total_size` | method | `total_size(self)` |  |
| `actual_damage` | method | `actual_damage(self)` |  |
| `actual_speed` | method | `actual_speed(self)` |  |
| `actual_duration` | method | `actual_duration(self)` |  |
| `actual_radius` | method | `actual_radius(self)` |  |
| `hit_factor` | method | `hit_factor(self)` |  |
| `effective_range` | method | `effective_range(self)` |  |
| `effective_dps` | method | `effective_dps(self)` |  |
| `coverage_area` | method | `coverage_area(self)` |  |
| `create_base_notes` | function | `create_base_notes()` |  |
| `ChordType` | class | `ChordType()` |  |
| `create_chord_registry` | function | `create_chord_registry()` |  |
| `UpgradeCategory` | class | `UpgradeCategory()` |  |
| `Upgrade` | class | `Upgrade()` |  |
| `create_upgrade_pool` | function | `create_upgrade_pool()` |  |
| `MetaProgressionManager` | class | `MetaProgressionManager()` |  |
| `PlayerBuild` | class | `PlayerBuild()` |  |
| `beat_interval` | method | `beat_interval(self)` |  |
| `get_note_damage` | method | `get_note_damage(self, note_name: str)` |  |
| `apply_meta_upgrades` | method | `apply_meta_upgrades(self, meta_manager: MetaProgressionManager)` |  |
| `StrategyAction` | class | `StrategyAction()` |  |
| `StrategyDefinition` | class | `StrategyDefinition()` |  |
| `SimulationResult` | class | `SimulationResult()` |  |
| `StrategySimulator` | class | `StrategySimulator()` |  |
| `__init__` | method | `__init__(self, build: PlayerBuild, chord_registry: dict[str, ChordType])` |  |
| `simulate` | method | `simulate(self, strategy: StrategyDefinition)` | 巨型函数 |
| `create_strategy_library` | function | `create_strategy_library()` |  |
| `print_benchmark_report` | function | `print_benchmark_report(results: list[SimulationResult], title: str = "跑分报告")` |  |

## 巨型函数内部节点 (@section)

| 节点 | 说明 | 定位方式 |
|------|------|----------|
| 无 | - | - |

## 定位提示

本索引不记录行号。定位函数请使用：

```bash
grep -n "函数名" BalanceKit/balance_scorer.py
```
