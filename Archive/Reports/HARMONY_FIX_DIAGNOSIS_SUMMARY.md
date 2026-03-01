# Project Harmony 修复任务规划

## 诊断结果综合摘要

基于三个诊断任务的完整结果：

### 代码架构诊断 (tsk-91b92f0f-f92) — 已完成
- **TutorialHintManager 路径断裂** [高危]: 11处代码通过 `/root/TutorialHintManager` 访问，但该节点未注册为 Autoload，导致教程提示功能完全失效
- **_process 无条件重绘** [高危]: 26个UI脚本在 `_process` 中无条件调用 `queue_redraw()`，造成持续CPU浪费
- **_draw() 中的无限重绘循环** [高危]: `test_chamber.gd` 和 `chord_alchemy_panel_v3.gd` 等脚本在 `_draw()` 中调用 `queue_redraw()`
- **孤立脚本**: 48个 .gd 脚本未被引用（其中13个在 archive/ 可安全删除，其余为功能性孤岛）
- **未使用信号**: `pool_expanded_warning` 和 `upgrade_cancelled` 从未被 emit
- **硬编码常量**: ~1910处魔法数字，162处硬编码 `res://` 路径
- **调试残留**: 69处 `print` 语句
- **SynthManager 路径不规范**: 注册为 Autoload 但不在 autoload/ 目录
- **大文件**: 60个文件超500行，`spell_visual_manager.gd` 超2000行

### 内容完成度诊断 — 已完成
- 总体内容完成度 ~65%
- Boss 内容 40%（有骨架缺血肉，缺 Shader/BGM/阶段机制）
- 音频资源 10%（Boss BGM 0/7，章节 BGM 0/7）
- 波次数据 100%
- 敌人脚本 80%

### 修改方案规划 — 已完成
- 6个开放 Issue 均为已完成工作报告，建议关闭
- 项目实际完成度远高于文档记录
- 需要 TODO.md v11.0 大规模更新

---

## 修复任务清单

### FIX-01: 修复 TutorialHintManager 路径断裂 [P0-高危]
将 TutorialHintManager 注册为 Autoload，修复11处断裂引用。

### FIX-02: 优化 UI 重绘性能 [P0-高危]
修复26个UI脚本的 _process 无条件 queue_redraw()，修复 _draw() 中的无限重绘循环。

### FIX-03: 清理技术债务 [P1-中]
- 删除 scripts/archive/ 目录（13个废弃脚本）
- 移除2个未使用信号
- 清理69处 print 语句
- 将 SynthManager 移至 autoload/ 目录

### FIX-04: 重建 TODO.md v11.0 [P0]
基于代码库现状全面重建 TODO.md，反映真实完成度。

### FIX-05: 关闭已完成的 GitHub Issues [P1]
关闭 #123, #124, #125, #126, #129, #130 并添加关闭说明。
