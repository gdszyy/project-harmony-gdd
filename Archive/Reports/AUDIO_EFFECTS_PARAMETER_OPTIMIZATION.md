# 音频效果器参数优化说明

**日期**: 2026-02-09  
**版本**: v5.2.1  
**优化目标**: 确保音调不变、减少失真、保持音色纯净

---

## 一、优化原则

### 1.1 核心原则

1. **音调保持不变**
   - 移除所有会改变音高的效果（LFO音高调制、Vibrato颤音）
   - 使用音量调制（Tremolo）替代音高调制
   - 确保所有效果器不影响基频

2. **减少失真**
   - 大幅降低失真效果的强度
   - 避免过度的非线性处理
   - 保持信号的干净度

3. **保持音色纯净**
   - 所有效果器参数都调整为"轻微"或"极轻微"
   - 效果器只是"点缀"，不破坏原有音色
   - 优先保留音乐性，而非追求极端效果

---

## 二、修饰符效果参数优化

### 2.1 穿透（PIERCE）

#### 优化前
```gdscript
_apply_high_pass_filter(buffer, 2000.0, sample_rate)  # 过高的截止频率
_apply_transient_boost(buffer, 1.5)                   # 过强的增强
_apply_simple_reverb(buffer, 0.2, 0.15, sample_rate)  # 混响偏强
```

#### 优化后
```gdscript
_apply_high_pass_filter(buffer, 1200.0, sample_rate)  # 降低截止频率，保留更多低频
_apply_transient_boost(buffer, 1.2)                   # 减少增强倍数
_apply_simple_reverb(buffer, 0.15, 0.08, sample_rate) # 减少混响强度
```

#### 优化效果
- ✅ 保留更多低频，音色更饱满
- ✅ 瞬态增强更自然
- ✅ 混响更加微妙

---

### 2.2 追踪（HOMING）

#### 优化前（改变音高）
```gdscript
_apply_pitch_lfo(buffer, 4.0, 0.15, sample_rate)  # LFO音高调制，会改变音高
_apply_vibrato(buffer, 5.5, 0.008, sample_rate)   # 颤音，会改变音高
```

#### 优化后（不改变音高）
```gdscript
_apply_tremolo(buffer, 6.0, 0.12, sample_rate)         # 音量调制，不改变音高
_apply_simple_reverb(buffer, 0.2, 0.1, sample_rate)    # 轻微混响
```

#### 优化效果
- ✅ **完全不改变音高**，只调制音量
- ✅ 使用Tremolo模拟弹体运动感
- ✅ 添加轻微混响增加空间动态感

#### 技术说明
**Tremolo（音量调制）**：
```gdscript
var lfo := sin(t * rate * TAU) * depth
var gain := 1.0 + lfo
buffer[i] *= gain
```
- 通过LFO调制音量，不改变音高
- 深度控制在0.12，音量变化范围为 88% ~ 112%
- 频率6Hz，产生轻微的脉动感

---

### 2.3 分裂（SPLIT）

#### 优化前
```gdscript
_apply_simple_chorus(buffer, 3, 0.02)  # 3声部，失谐量较大
```

#### 优化后
```gdscript
_apply_simple_chorus(buffer, 2, 0.008)  # 2声部，失谐量极小
```

#### 优化效果
- ✅ 减少声部数量，避免过度混浊
- ✅ 大幅减少失谐量（0.02 → 0.008），音高更稳定
- ✅ 效果更加微妙

---

### 2.4 回响（ECHO）

#### 优化前
```gdscript
_apply_delay(buffer, 0.3, 0.4, sample_rate)         # 延迟时间和反馈较强
_apply_low_pass_filter(buffer, 3000.0, sample_rate) # 滤波较强
```

#### 优化后
```gdscript
_apply_delay(buffer, 0.25, 0.25, sample_rate)       # 减少延迟时间和反馈
_apply_low_pass_filter(buffer, 4000.0, sample_rate) # 提高截止频率，保留更多高频
```

#### 优化效果
- ✅ 回声更加微妙，不喧宾夺主
- ✅ 保留更多高频，音色更清晰

---

### 2.5 散射（SCATTER）

#### 优化前
```gdscript
_apply_simple_reverb(buffer, 0.6, 0.5, sample_rate)  # 混响较强
_apply_noise_layer(buffer, 0.08)                     # 噪声较多
_apply_volume_randomization(buffer, 0.15)            # 随机化较强
```

#### 优化后
```gdscript
_apply_simple_reverb(buffer, 0.4, 0.25, sample_rate) # 减少混响强度
_apply_noise_layer(buffer, 0.03)                     # 大幅减少噪声
_apply_volume_randomization(buffer, 0.08)            # 减少随机化强度
```

#### 优化效果
- ✅ 混响更加温和
- ✅ 噪声减少62.5%（0.08 → 0.03），音色更干净
- ✅ 随机化更加微妙

---

## 三、和弦形态效果参数优化

### 3.1 爆炸弹体（AUGMENTED - 增三和弦）

#### 优化前
```gdscript
_apply_distortion(buffer, 0.3, 0.4)      # 失真较强
_apply_sub_bass_boost(buffer, 0.3)       # 低音增强较强
```

#### 优化后
```gdscript
_apply_distortion(buffer, 0.15, 0.2)     # 失真减少50%
_apply_sub_bass_boost(buffer, 0.15)      # 低音增强减少50%
```

#### 优化效果
- ✅ **失真大幅减少**，音色更干净
- ✅ 低音增强更加微妙
- ✅ 保留爆炸感但不破坏音色

---

### 3.2 冲击波（DIMINISHED - 减三和弦）

#### 优化前
```gdscript
_apply_ring_modulation(buffer, 220.0, 0.25, sample_rate)  # 环形调制较强
_apply_simple_reverb(buffer, 0.8, 0.6, sample_rate)       # 混响很强
```

#### 优化后
```gdscript
_apply_ring_modulation(buffer, 220.0, 0.12, sample_rate)  # 环形调制减少52%
_apply_simple_reverb(buffer, 0.5, 0.35, sample_rate)      # 混响减少42%
```

#### 优化效果
- ✅ 环形调制更加微妙，不过度金属化
- ✅ 混响更加温和

---

### 3.3 法阵（DOMINANT_7 - 属七和弦）

#### 优化前
```gdscript
_apply_low_pass_filter(buffer, 2000.0, sample_rate)  # 滤波较强
_apply_simple_reverb(buffer, 0.9, 0.7, sample_rate)  # 混响很强
```

#### 优化后
```gdscript
_apply_low_pass_filter(buffer, 3000.0, sample_rate)  # 提高截止频率，保留更多高频
_apply_simple_reverb(buffer, 0.6, 0.4, sample_rate)  # 混响减少43%
```

#### 优化效果
- ✅ 音色更明亮，不过度柔和
- ✅ 混响更加适度

---

### 3.4 强化弹体（MAJOR - 大三和弦）

#### 优化前
```gdscript
_apply_soft_compression(buffer, 0.6, 3.0)  # 压缩较强
```

#### 优化后
```gdscript
_apply_soft_compression(buffer, 0.7, 2.0)  # 提高阈值，降低压缩比
```

#### 优化效果
- ✅ 压缩更加温和，保留动态范围

---

## 四、参数对比表

### 4.1 修饰符效果参数对比

| 修饰符 | 参数 | 优化前 | 优化后 | 变化 |
|--------|------|--------|--------|------|
| **穿透** | 高通截止频率 | 2000Hz | 1200Hz | -40% |
| | 瞬态增强倍数 | 1.5 | 1.2 | -20% |
| | 混响wet | 0.15 | 0.08 | -47% |
| **追踪** | 效果类型 | 音高调制 | 音量调制 | **不改变音高** |
| | 调制深度 | 0.15 | 0.12 | -20% |
| **分裂** | 合唱声部 | 3 | 2 | -33% |
| | 失谐量 | 0.02 | 0.008 | -60% |
| **回响** | 延迟反馈 | 0.4 | 0.25 | -38% |
| | 低通截止频率 | 3000Hz | 4000Hz | +33% |
| **散射** | 混响wet | 0.5 | 0.25 | -50% |
| | 噪声混合 | 0.08 | 0.03 | -63% |
| | 音量随机化 | 0.15 | 0.08 | -47% |

---

### 4.2 和弦形态效果参数对比

| 和弦形态 | 参数 | 优化前 | 优化后 | 变化 |
|----------|------|--------|--------|------|
| **爆炸** | 失真drive | 0.3 | 0.15 | -50% |
| | 失真mix | 0.4 | 0.2 | -50% |
| | 低音增强 | 0.3 | 0.15 | -50% |
| **冲击波** | 环形调制mix | 0.25 | 0.12 | -52% |
| | 混响wet | 0.6 | 0.35 | -42% |
| **法阵** | 低通截止频率 | 2000Hz | 3000Hz | +50% |
| | 混响wet | 0.7 | 0.4 | -43% |
| **强化** | 压缩阈值 | 0.6 | 0.7 | +17% |
| | 压缩比 | 3.0 | 2.0 | -33% |

---

## 五、技术改进

### 5.1 移除音高调制效果

**原有问题**：
- `_apply_pitch_lfo()` 和 `_apply_vibrato()` 会改变音高
- 通过采样偏移模拟音高变化，但会破坏音调

**解决方案**：
- 新增 `_apply_tremolo()` 函数，使用音量调制替代音高调制
- 只调制音量（振幅），不改变音高（频率）
- 保持音调纯净，同时保留动态感

**代码对比**：

**音高调制（已移除）**：
```gdscript
var offset := int(lfo * sample_rate * 0.01)  # 采样偏移
var idx := clampi(i + offset, 0, buffer.size() - 1)
buffer[i] = original[idx]  # 改变音高
```

**音量调制（新增）**：
```gdscript
var lfo := sin(t * rate * TAU) * depth
var gain := 1.0 + lfo
buffer[i] *= gain  # 只改变音量，不改变音高
```

---

### 5.2 失真效果优化

**优化策略**：
- 所有失真参数减少50%
- 使用tanh软削波，避免硬削波
- 降低混合比例，保留更多原始信号

**效果**：
- 失真更加温和
- 音色更加干净
- 保留音乐性

---

## 六、测试建议

### 6.1 音调稳定性测试

1. **频谱分析**：
   - 使用频谱分析仪检查基频是否稳定
   - 验证效果器不会引入音高偏移
   - 对比有/无效果器的频谱差异

2. **听感测试**：
   - 播放音阶，验证音高是否准确
   - 检查是否有音高漂移或颤动
   - 确认音调清晰可辨

---

### 6.2 音色纯净度测试

1. **失真测试**：
   - 检查是否有明显的失真或削波
   - 验证音色是否保持干净
   - 确认效果器不会引入杂音

2. **混响测试**：
   - 检查混响是否过度
   - 验证音色是否保持清晰
   - 确认不会有"泥泞"感

---

### 6.3 对比测试

1. **A/B对比**：
   - 对比有/无效果器的音效
   - 验证效果器是否"点缀"而非"主导"
   - 确认原有音色特征得到保留

2. **参数调优**：
   - 根据测试结果微调参数
   - 收集玩家反馈
   - 迭代优化

---

## 七、总结

### 7.1 优化成果

✅ **音调保持不变**
- 移除所有音高调制效果
- 使用音量调制替代
- 确保基频稳定

✅ **失真大幅减少**
- 所有失真参数减少50%
- 音色更加干净
- 保留音乐性

✅ **音色保持纯净**
- 所有效果器参数调整为"轻微"级别
- 效果器只是"点缀"，不破坏原有音色
- 优先保留音乐性

---

### 7.2 关键改进

| 改进项 | 说明 |
|--------|------|
| **追踪效果** | 从音高调制改为音量调制，**完全不改变音高** |
| **失真强度** | 所有失真参数减少50%，音色更干净 |
| **混响强度** | 平均减少40-50%，避免过度混响 |
| **噪声层** | 减少63%，保持音色纯净 |
| **合唱效果** | 声部减少33%，失谐量减少60% |

---

### 7.3 设计哲学

**"Less is More"（少即是多）**：
- 效果器应该是"调味料"，而非"主菜"
- 保留原有音色的纯净和音乐性
- 通过微妙的效果增强表现力，而非改变音色本质

**"Subtle Enhancement"（微妙增强）**：
- 所有效果器都调整为"轻微"或"极轻微"
- 效果应该在不知不觉中增强体验
- 避免过度处理导致的听觉疲劳

---

**修改文件**：
- `godot_project/scripts/systems/audio_effect_processor.gd`
- `AUDIO_EFFECTS_PARAMETER_OPTIMIZATION.md` (本文档)
