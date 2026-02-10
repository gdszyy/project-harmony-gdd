# 音频效果器系统设计文档

**日期**: 2026-02-09  
**版本**: v5.2  
**目标**: 为不同的法术效果附加对应的音频效果器，增强音效与视觉效果的一致性

---

## 一、设计理念

### 1.1 核心思想

**音效应该反映法术的视觉和机制特征**：
- 穿透效果应该有锐利、穿透性的音色
- 追踪效果应该有音高变化，模拟弹体转向
- 分裂效果应该有立体声展宽，模拟弹体分散
- 回响效果应该有延迟/回声，模拟声音的重复
- 散射效果应该有混响和随机化，模拟弹体散开

### 1.2 技术约束

**Godot 4的音频处理能力**：
- 支持实时音频效果器（AudioEffect）
- 支持音频总线（AudioBus）系统
- 支持程序化音频生成（AudioStreamGenerator）
- **限制**：实时DSP处理能力有限，需要优化性能

**实现策略**：
- **方案A（推荐）**：在音符合成阶段直接应用效果器处理
- **方案B**：使用AudioBus动态路由和效果器链
- **方案C**：预生成带效果的音频样本并缓存

---

## 二、修饰符音频效果映射

### 2.1 穿透（PIERCE）

**视觉特征**：弹体穿透敌人，不消失  
**音效特征**：锐利、高频、穿透性

**音频效果器配置**：
```gdscript
{
    "high_pass_filter": {
        "cutoff_freq": 2000.0,  # 高通滤波，保留高频
        "resonance": 1.5,       # 增加共振，强调锐利感
    },
    "pitch_shift": {
        "semitones": 2,         # 音高提升2个半音
    },
    "attack_boost": {
        "multiplier": 1.5,      # 增强瞬态冲击
    },
    "reverb": {
        "room_size": 0.2,       # 小空间混响
        "damping": 0.8,         # 高阻尼，减少拖尾
        "wet": 0.15,            # 轻微混响
    }
}
```

**实现方式**：
- 在合成器中应用高通滤波器
- 调整ADSR包络，缩短Attack时间
- 增加高频泛音比例

---

### 2.2 追踪（HOMING）

**视觉特征**：弹体会转向目标  
**音效特征**：音高调制，模拟多普勒效应

**音频效果器配置**：
```gdscript
{
    "pitch_modulation": {
        "lfo_rate": 4.0,        # LFO频率（Hz）
        "lfo_depth": 0.15,      # 调制深度（半音）
        "waveform": "sine",     # 正弦波调制
    },
    "vibrato": {
        "rate": 5.5,            # 颤音速率
        "depth": 0.008,         # 颤音深度
    },
    "stereo_pan": {
        "enabled": true,        # 启用立体声平移
        "auto_pan_rate": 3.0,   # 自动平移速率
    }
}
```

**实现方式**：
- 在波形生成时应用LFO调制
- 动态调整音高，模拟弹体运动
- 添加轻微的颤音效果

---

### 2.3 分裂（SPLIT）

**视觉特征**：弹体击中后分裂成多个小弹体  
**音效特征**：立体声展宽，多声部叠加

**音频效果器配置**：
```gdscript
{
    "stereo_widening": {
        "width": 1.5,           # 立体声宽度
        "haas_delay": 0.015,    # Haas效应延迟（秒）
    },
    "chorus": {
        "voices": 3,            # 合唱声部数量
        "rate": 1.2,            # 调制速率
        "depth": 0.02,          # 调制深度
        "mix": 0.4,             # 混合比例
    },
    "detune": {
        "amount": 8,            # 失谐量（音分）
        "voices": 2,            # 失谐声部数量
    }
}
```

**实现方式**：
- 生成多个轻微失谐的音符副本
- 应用Haas效应创建立体声宽度
- 混合多个声部，模拟分裂感

---

### 2.4 回响（ECHO）

**视觉特征**：延迟后再次发射弹体  
**音效特征**：延迟/回声效果

**音频效果器配置**：
```gdscript
{
    "delay": {
        "delay_time": 0.3,      # 延迟时间（秒）
        "feedback": 0.4,        # 反馈量
        "wet": 0.6,             # 湿信号比例
        "filter_cutoff": 3000,  # 低通滤波截止频率
    },
    "decay_envelope": {
        "multiplier": 0.7,      # 回声音量衰减
    }
}
```

**实现方式**：
- 在音符播放后添加延迟副本
- 应用衰减包络，模拟回声衰减
- 使用低通滤波器，模拟声音在空间中的传播

---

### 2.5 散射（SCATTER）

**视觉特征**：弹体分散成多个随机方向的小弹体  
**音效特征**：混响、随机化、空间感

**音频效果器配置**：
```gdscript
{
    "reverb": {
        "room_size": 0.6,       # 中等空间混响
        "damping": 0.5,         # 中等阻尼
        "wet": 0.5,             # 较强混响
        "spread": 1.0,          # 立体声扩散
    },
    "randomization": {
        "pitch_variance": 0.1,  # 音高随机变化（半音）
        "timing_variance": 0.02,# 时间随机变化（秒）
        "velocity_variance": 0.15, # 力度随机变化
    },
    "noise_layer": {
        "type": "white",        # 白噪声
        "mix": 0.08,            # 噪声混合比例
        "filter_cutoff": 5000,  # 滤波截止频率
    }
}
```

**实现方式**：
- 生成多个音符，每个音符有轻微的音高和时间偏移
- 添加混响效果，增强空间感
- 混入少量噪声，模拟散射的混乱感

---

## 三、和弦法术形态音频效果

### 3.1 强化弹体（MAJOR - 大三和弦）

**音效特征**：饱满、和谐、力量感

**音频效果器配置**：
```gdscript
{
    "harmonics_boost": {
        "multiplier": 1.3,      # 增强泛音
    },
    "compression": {
        "threshold": 0.6,       # 压缩阈值
        "ratio": 3.0,           # 压缩比
        "attack": 0.001,        # 压缩起音
        "release": 0.05,        # 压缩释放
    }
}
```

---

### 3.2 爆炸弹体（AUGMENTED - 增三和弦）

**音效特征**：紧张、爆裂、不和谐

**音频效果器配置**：
```gdscript
{
    "distortion": {
        "drive": 0.3,           # 失真驱动
        "mix": 0.4,             # 失真混合
    },
    "pitch_shift": {
        "semitones": -2,        # 降低音高
    },
    "sub_bass": {
        "frequency_ratio": 0.5, # 添加低八度
        "mix": 0.3,             # 低音混合
    }
}
```

---

### 3.3 冲击波（DIMINISHED - 减三和弦）

**音效特征**：不稳定、扩散、冲击感

**音频效果器配置**：
```gdscript
{
    "ring_modulation": {
        "frequency": 220.0,     # 环形调制频率
        "mix": 0.25,            # 调制混合
    },
    "reverb": {
        "room_size": 0.8,       # 大空间混响
        "wet": 0.6,             # 强混响
    }
}
```

---

### 3.4 法阵/区域（DOMINANT_7 - 属七和弦）

**音效特征**：持续、氛围、空间感

**音频效果器配置**：
```gdscript
{
    "pad_synthesis": {
        "attack_time": 0.2,     # 缓慢起音
        "release_time": 0.5,    # 长释放
    },
    "reverb": {
        "room_size": 0.9,       # 大空间
        "wet": 0.7,             # 强混响
    },
    "low_pass_filter": {
        "cutoff": 2000,         # 柔和音色
        "resonance": 0.5,
    }
}
```

---

## 四、实现架构

### 4.1 音频效果器处理器类

创建新文件：`scripts/systems/audio_effect_processor.gd`

```gdscript
class_name AudioEffectProcessor
extends RefCounted

## 应用修饰符效果到音频缓冲区
static func apply_modifier_effect(
    buffer: Array[float],
    modifier: MusicData.ModifierEffect,
    sample_rate: int = 44100
) -> void:
    match modifier:
        MusicData.ModifierEffect.PIERCE:
            _apply_pierce_effect(buffer, sample_rate)
        MusicData.ModifierEffect.HOMING:
            _apply_homing_effect(buffer, sample_rate)
        MusicData.ModifierEffect.SPLIT:
            _apply_split_effect(buffer, sample_rate)
        MusicData.ModifierEffect.ECHO:
            _apply_echo_effect(buffer, sample_rate)
        MusicData.ModifierEffect.SCATTER:
            _apply_scatter_effect(buffer, sample_rate)

## 穿透效果：高通滤波 + 增强Attack
static func _apply_pierce_effect(buffer: Array[float], sample_rate: int) -> void:
    # 高通滤波器
    _apply_high_pass_filter(buffer, 2000.0, sample_rate)
    # 增强瞬态
    _apply_transient_boost(buffer, 1.5)

## 追踪效果：音高调制
static func _apply_homing_effect(buffer: Array[float], sample_rate: int) -> void:
    # LFO音高调制
    _apply_pitch_lfo(buffer, 4.0, 0.15, sample_rate)

## 分裂效果：立体声展宽（需要双声道）
static func _apply_split_effect(buffer: Array[float], _sample_rate: int) -> void:
    # 添加合唱效果
    _apply_simple_chorus(buffer, 3, 0.02)

## 回响效果：延迟
static func _apply_echo_effect(buffer: Array[float], sample_rate: int) -> void:
    # 添加延迟
    _apply_delay(buffer, 0.3, 0.4, sample_rate)

## 散射效果：混响 + 随机化
static func _apply_scatter_effect(buffer: Array[float], sample_rate: int) -> void:
    # 添加混响
    _apply_simple_reverb(buffer, 0.6, 0.5, sample_rate)
    # 添加噪声
    _apply_noise_layer(buffer, 0.08)
```

---

### 4.2 集成到NoteSynthesizer

修改 `scripts/systems/note_synthesizer.gd`：

```gdscript
## 生成带修饰符效果的音符
func generate_note_with_modifier(
    note: int,
    modifier: MusicData.ModifierEffect,
    timbre: int = MusicData.TimbreType.NONE,
    octave: int = 4,
    duration: float = DEFAULT_NOTE_DURATION,
    velocity: float = 0.8
) -> AudioStreamWAV:
    
    # 先生成基础音符
    var wav := generate_note(note, timbre, octave, duration, velocity)
    if wav == null or modifier < 0:
        return wav
    
    # 提取音频数据
    var buffer := _wav_to_buffer(wav)
    
    # 应用修饰符效果
    AudioEffectProcessor.apply_modifier_effect(buffer, modifier, SAMPLE_RATE)
    
    # 转换回WAV
    return _buffer_to_wav(buffer)
```

---

### 4.3 集成到GlobalMusicManager

修改 `scripts/autoload/global_music_manager.gd`：

```gdscript
## 播放带修饰符的音符音效
func play_note_sound_with_modifier(
    note: int,
    modifier: MusicData.ModifierEffect,
    duration: float = 0.2,
    timbre_override: int = -1,
    velocity: float = 0.8,
    pitch_shift: int = 0
) -> void:
    
    # 冷却检查
    var cooldown_key := "note_%d_mod_%d" % [note, modifier]
    if not _check_note_cooldown(cooldown_key):
        return
    
    var timbre := timbre_override if timbre_override >= 0 else _current_timbre
    var octave := 4 + (pitch_shift / 12)
    
    # 生成带修饰符的音符
    if _synthesizer == null:
        _init_synthesizer()
    
    var wav := _synthesizer.generate_note_with_modifier(
        note, modifier, timbre, octave, duration, velocity
    )
    if wav == null:
        return
    
    # 播放
    var player := _get_note_player()
    if player == null:
        return
    
    player.stream = wav
    player.volume_db = _velocity_to_db(velocity)
    player.pitch_scale = 1.0
    player.play()
    
    note_played.emit(note, timbre)
```

---

## 五、DSP算法实现

### 5.1 高通滤波器（High-Pass Filter）

```gdscript
static func _apply_high_pass_filter(
    buffer: Array[float],
    cutoff_freq: float,
    sample_rate: int
) -> void:
    var rc := 1.0 / (cutoff_freq * TAU)
    var dt := 1.0 / float(sample_rate)
    var alpha := rc / (rc + dt)
    
    var prev_input := buffer[0]
    var prev_output := buffer[0]
    
    for i in range(1, buffer.size()):
        var output := alpha * (prev_output + buffer[i] - prev_input)
        buffer[i] = output
        prev_input = buffer[i]
        prev_output = output
```

---

### 5.2 延迟效果（Delay）

```gdscript
static func _apply_delay(
    buffer: Array[float],
    delay_time: float,
    feedback: float,
    sample_rate: int
) -> void:
    var delay_samples := int(delay_time * sample_rate)
    if delay_samples >= buffer.size():
        return
    
    for i in range(delay_samples, buffer.size()):
        buffer[i] += buffer[i - delay_samples] * feedback
```

---

### 5.3 简单混响（Simple Reverb）

```gdscript
static func _apply_simple_reverb(
    buffer: Array[float],
    room_size: float,
    wet: float,
    sample_rate: int
) -> void:
    # 使用多个延迟线模拟混响
    var delays := [0.029, 0.037, 0.041, 0.043]  # 秒
    var decay := 0.5 * room_size
    
    for delay_time in delays:
        var delay_samples := int(delay_time * sample_rate)
        if delay_samples >= buffer.size():
            continue
        
        for i in range(delay_samples, buffer.size()):
            buffer[i] += buffer[i - delay_samples] * decay * wet
```

---

### 5.4 合唱效果（Chorus）

```gdscript
static func _apply_simple_chorus(
    buffer: Array[float],
    voices: int,
    detune_amount: float
) -> void:
    var original := buffer.duplicate()
    
    for v in range(1, voices):
        var detune := detune_amount * (v - voices / 2.0)
        for i in range(buffer.size()):
            # 简化版：通过插值模拟音高偏移
            var offset := int(i * detune)
            var idx := (i + offset) % buffer.size()
            buffer[i] += original[idx] * (1.0 / float(voices))
```

---

## 六、性能优化

### 6.1 缓存策略

- **预生成常用组合**：预先生成常用音符+修饰符的组合
- **LRU缓存**：限制缓存大小，使用最近最少使用策略
- **异步生成**：在后台线程生成音频，避免卡顿

### 6.2 效果简化

- **低质量模式**：在性能不足时禁用复杂效果
- **效果层级**：根据重要性分级，优先处理关键效果
- **批量处理**：合并多个效果的处理流程

---

## 七、测试计划

### 7.1 功能测试

1. **单个修饰符测试**：
   - 测试每个修饰符的音效是否符合预期
   - 验证效果器参数是否合理

2. **组合测试**：
   - 测试修饰符+音色的组合
   - 测试修饰符+和弦的组合

3. **性能测试**：
   - 测试大量弹体同时播放时的性能
   - 监控CPU和内存占用

### 7.2 音乐性测试

1. **音色一致性**：验证效果器不会破坏原有音色特征
2. **混音平衡**：确保各效果的音量平衡合理
3. **玩家反馈**：收集玩家对音效的主观评价

---

## 八、总结

本设计文档提出了一套完整的音频效果器系统，为每个法术修饰符和和弦形态设计了对应的音频处理效果。通过在音符合成阶段应用DSP算法，可以实现丰富的音效变化，增强游戏的沉浸感和表现力。

**关键特性**：
- ✅ 5种修饰符专属音频效果
- ✅ 基于DSP的实时音频处理
- ✅ 缓存优化，保证性能
- ✅ 模块化设计，易于扩展

**下一步**：
1. 实现AudioEffectProcessor类
2. 集成到NoteSynthesizer
3. 测试并调优参数
4. 收集玩家反馈并迭代
