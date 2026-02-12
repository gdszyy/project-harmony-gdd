# 《Project Harmony》场景美术落地指南

**作者：** Manus AI
**版本：** 1.0
**日期：** 2026年2月12日

---

## 0. 文档目的与工作流

本文档是《场景地图机制与美术风格设计文档》的实践篇，旨在为美术师和技术美术师提供一套可执行的、详细的场景资产生产规范。它将每个章节的抽象美术风格分解为具体的视觉元素、色彩方案以及可用于AI图像生成（如NanoBanana）的精确Prompt。

**核心工作流：**
1.  **风格定义**: 理解本章的核心美术风格、关键视觉元素和色彩光影规范。
2.  **资产生成**: 根据“AI生成资产列表”，使用提供的NanoBanana Prompt生成带有绿幕背景的2D场景组件。
3.  **绿幕抠图**: 对生成的图像进行批量绿幕抠图，获得透明底的PNG资产。
4.  **引擎集成**: 将资产导入Godot引擎，根据《技术美术蓝图》的指导，组合成动态、可交互的场景。

**绿幕（Green Screen）使用规范：**
- **所有场景组件**都必须使用纯绿幕背景生成，以便于批量处理。
- **Prompt中必须包含** `on a solid green screen background` 或类似的明确指令。
- **避免绿色元素**: 在设计Prompt时，应尽量避免在主体物中使用与绿幕相近的绿色，以防抠图时产生边缘问题。

---

## 第一章：律动尊者·毕达哥拉斯

### 1.1 核心美术风格：光之神殿 (Temple of Light)

本章的美术风格是**“数字化的古希腊极简主义”**。想象一个由纯粹能量和神圣几何构成的空间，它不是物理实体，而是数学法则的视觉体现。所有元素都应呈现出一种非物质的、由光构成的质感。

- **质感**: 自发光、半透明、矢量线条、无瑕疵的光滑表面。
- **动态**: 所有元素的运动都应平滑、优雅，并与全局节拍严格同步。

### 1.2 关键视觉元素

- **地面**: 动态脉冲的能量网格，线条由纯白或谐振青构成。
- **柱子**: 由旋转的同心光环构成的非实体柱子，作为场景的结构支撑。
- **背景**: 无限深邃的黑暗空间，点缀着如星辰般缓慢移动的几何粒子。
- **边界**: 由密集的、垂直下落的数字“白噪音”构成的能量墙。

### 1.3 色彩与光影

- **主色调**: `#0A0814` (深渊黑) 作为背景，`#EAE6FF` (晶体白) 和 `#00FFD4` (谐振青) 作为核心发光色。
- **高光/强调色**: `#FFD700` (圣光金)，仅用于“完美卡拍”或Boss的关键技能，代表至高的和谐。
- **光影**: 场景中没有传统光源。所有光线均来自物体本身。必须启用**Glow（辉光）**后处理效果，营造出光线弥散、柔和的氛围。

### 1.4 AI生成资产列表与Prompt规范

#### 资产1：神殿光柱 (Temple Light Pillar)

- **用途**: 构成场景结构，可作为动态障碍物。
- **NanoBanana Prompt**:

```
Masterpiece, best quality, concept art of a divine pillar of light, made of multiple glowing concentric white and cyan rings rotating around a central axis, ethereal, translucent, sacred geometry, minimalist, abstract, on a solid green screen background, vector art style, clean lines, radiant glow, no texture, pure energy. --ar 1:3 --style raw
```

#### 资产2：克拉尼图形地面贴图 (Chladni Pattern Ground Texture)

- **用途**: 作为Boss战阶段的核心地面，其线条为危险区域。
- **NanoBanana Prompt**:

```
Masterpiece, top-down view, a complex Chladni plate pattern, intricate sacred geometry like a mandala, lines are made of glowing golden light, on a pitch-black background, abstract, minimalist, scientific diagram, high contrast, on a solid green screen background. --ar 1:1 --style raw
```

#### 资产3：白噪音边界 (White Noise Barrier)

- **用途**: 构成圆形战斗场地的边界。
- **NanoBanana Prompt**:

```
Masterpiece, best quality, abstract texture of a dense digital white noise wall, like a waterfall of glitching static and binary code, glowing cyan and white particles, vertical movement, data stream, on a solid green screen background, seamless, tileable texture. --ar 2:1 --style raw
```

---

## 第二章：圣咏宗师·圭多

### 2.1 核心美术风格：哥特回响 (Gothic Echo)

本章风格为**“数字化转译的哥特式建筑”**。重点在于捕捉哥特建筑高耸、空灵、神秘的氛围，并用光影和“视觉回响”来诠释“混响”这一音乐概念。材质应介于实体与非实体之间，如同一个记忆中的教堂。

- **质感**: 磨砂石材质感、彩色玻璃的半透明感、光束的体积感。
- **动态**: 场景主体静止，但光影和粒子（如尘埃）应缓慢变化，营造出时间的流逝感。和弦攻击产生的“视觉回响”是核心动态元素。

### 2.2 关键视觉元素

- **地面**: 刻有巨大五线谱的石砖地面。五线谱线条会随节拍微弱发光。
- **背景**: 巨大的哥特式玫瑰窗剪影，从外部透入体积光。
- **结构**: 高耸的拱门和立柱的剪影，融入黑暗的背景中，只露出边缘轮廓。
- **互动元素**: “回声圣坛”，一个小型石制祈祷台，被激活时会发出柔和的光芒。

### 2.3 色彩与光影

- **主色调**: `#1A1A2E` (暗夜蓝) 和 `#4A4A6A` (岩石灰) 构成环境基调。
- **光源**: 主要来自背景的玫瑰窗，投下**体积光 (Volumetric Light)**。光束的颜色是柔和的彩色（琥珀、深红、钴蓝）。“回声圣坛”和玩家技能是次要光源。
- **光影**: 强调高对比度的光影，巨大的阴影是场景构图的重要部分。丁达尔效应（光束中可见的尘埃）是关键氛围元素。

### 2.4 AI生成资产列表与Prompt规范

#### 资产1：哥特玫瑰窗 (Gothic Rose Window)

- **用途**: 作为场景的核心背景和主光源。
- **NanoBanana Prompt**:

```
Masterpiece, concept art of a massive Gothic rose window, intricate stained glass, depicting abstract sacred geometry, glowing with divine light from behind, dominant colors are cobalt blue, deep red, and amber, cinematic lighting, on a solid green screen background. --ar 1:1 --style raw
```

#### 资产2：回声圣坛 (Echoing Altar)

- **用途**: 场景中的核心互动机制单位。
- **NanoBanana Prompt**:

```
Masterpiece, best quality, concept art of a small, ancient stone altar, gothic style, with a single slot for a glowing orb, covered in faint magical runes, slightly weathered, isometric view, on a solid green screen background. --ar 1:1 --style raw
```

#### 资产3：五线谱石砖地面 (Staff-Engraved Stone Floor)

- **用途**: 游戏区域的地面贴图。
- **NanoBanana Prompt**:

```
Masterpiece, top-down view, a seamless tileable texture of a dark stone floor, large gothic bricks, engraved with a giant, faintly glowing musical staff (five horizontal lines), ancient, mysterious, moody lighting, on a solid green screen background. --ar 1:1 --style raw
```


---

## 第三章：大构建师·巴赫

### 3.1 核心美术风格：巴洛克机械城 (Baroque Machina)

本章风格是**“神圣化的精密机械”**。将巴洛克时期的华丽、繁复与钟表、管风琴的机械结构相结合，创造一个如同上帝的音乐盒般的宇宙。所有元素都应服务于一种宏大、精确、逻辑严密的秩序感。

- **质感**: 拉丝黄铜、抛光青铜、深色实木、金属的厚重感。
- **动态**: 运动是核心。巨大的齿轮以恒定、可预测的速度旋转，活塞同步起落。整个场景就是一个巨大的、正在演奏的机械装置，其运动与BPM严格同步。

### 3.2 关键视觉元素

- **平台**: 玩家和敌人所在的战斗区域是巨大的、缓慢旋转的黄铜齿轮。
- **背景**: 无数层级的、更小的齿轮、传动带和活塞构成的复杂网络。巨大的、发光的管风琴管在远景中拔地而起。
- **连接元素**: 连接不同齿轮平台的机械桥梁，会随着节拍升降或伸缩。
- **环境光**: 从齿轮缝隙和机械深处透出的温暖、柔和的蒸汽光。

### 3.3 色彩与光影

- **主色调**: `#A97142` (黄铜) 和 `#5A3A22` (深色木材) 构成环境基调。
- **强调色**: `#FFE8A9` (亮金色) 用于金属高光，`#FFFFFF` 的蒸汽白用于动态效果。
- **光影**: 光源复杂，主要来自机械内部的自发光和环境中的蒸汽。应有强烈的体积光效果，光线穿过蒸汽和机械缝隙，形成光束。金属表面应有清晰的高光反射。

### 3.4 AI生成资产列表与Prompt规范

#### 资产1：巨型齿轮平台 (Giant Gear Platform)

- **用途**: 构成游戏的核心战斗区域。
- **NanoBanana Prompt**:

```
Masterpiece, concept art, a massive, intricate brass gear, functioning as a floating platform, baroque style filigree engravings on the surface, top-down isometric view, cinematic lighting, on a solid green screen background. --ar 1:1 --style raw
```

#### 资产2：背景机械网络 (Background Mechanical Network)

- **用途**: 作为场景的动态背景，需要是可平铺的无缝贴图。
- **NanoBanana Prompt**:

```
Masterpiece, best quality, a seamless tileable texture of an intricate network of rotating gears, pistons, and pipes, steampunk, baroque filigree, brass and bronze, dark and moody, volumetric light shafts, on a solid green screen background. --ar 1:1 --style raw
```

#### 资产3：发光管风琴 (Glowing Organ Pipes)

- **用途**: 远景中的标志性建筑，其光芒会随和弦进行而变化。
- **NanoBanana Prompt**:

```
Masterpiece, concept art, a colossal row of majestic, glowing organ pipes, made of polished silver and brass, baroque style, emitting a soft, divine light, seen from a low angle, on a solid green screen background. --ar 1:2 --style raw
```

---

## 第四章：古典完形·莫扎特

### 4.1 核心美术风格：洛可可水晶厅 (Rococo Crystal Hall)

本章风格是**“极致对称的奢华”**。灵感源于凡尔赛宫镜厅，但更加抽象和数字化。核心是“对称”和“反射”，所有元素都必须是完美无瑕、结构清晰的。

- **质感**: 抛光大理石、镜面、水晶、金箔。所有表面都应具有强烈的反射或折射效果。
- **动态**: 动态较少，强调一种永恒、完美的静止状态。唯一的动态来自玩家和敌人的弹幕在镜面之间的无数次反射，形成万花筒般的效果。

### 4.2 关键视觉元素

- **地面**: 完美抛光的白色大理石，带有强烈的镜面反射效果，可以反射弹幕和角色。
- **对称轴**: 一条贯穿场景中轴线的、几乎不可见的能量线，是弹道反射的来源。
- **墙壁/边界**: 由巨大的、无缝的镜子构成，镜子边缘有华丽的金色洛可可风格雕花边框。
- **装饰**: 巨大的水晶吊灯悬挂在场景“天花板”的中心，是主光源。

### 4.3 色彩与光影

- **主色调**: `#FFFFFF` (乳白) 和 `#FFFDD0` (奶油色) 作为基调，`#FFDF00` (金箔金) 作为装饰色。
- **辅助色**: `#ADD8E6` (淡蓝) 和 `#FFB6C1` (淡粉) 等柔和的粉彩色，用于点缀和区分不同的奏鸣曲式区域。
- **光影**: 光线明亮、均匀，几乎没有阴影。水晶吊灯是主光源，光线经过无数镜面和水晶的反射与折射，在整个空间中形成璀璨、闪耀的效果。需要强烈的Bloom效果。

### 4.4 AI生成资产列表与Prompt规范

#### 资产1：洛可可镜框 (Rococo Mirror Frame)

- **用途**: 作为战斗场地的边界，需要是可重复的模块。
- **NanoBanana Prompt**:

```
Masterpiece, concept art, an ornate, lavish rococo style picture frame, carved with intricate gold leaf filigree, swirls, and floral motifs, empty inside, on a solid green screen background. --ar 1:2 --style raw
```

#### 资产2：水晶吊灯 (Crystal Chandelier)

- **用途**: 场景的中心装饰和主光源。
- **NanoBanana Prompt**:

```
Masterpiece, best quality, concept art of a magnificent, enormous crystal chandelier, dripping with thousands of sparkling, refractive crystals, emitting a brilliant, warm light, rococo style, seen from below, on a solid green screen background. --ar 1:1 --style raw
```

#### 资产3：大理石地面贴图 (Marble Floor Texture)

- **用途**: 游戏区域的地面，需要有反射属性。
- **NanoBanana Prompt**:

```
Masterpiece, top-down view, a seamless tileable texture of a flawless white marble floor, with subtle, elegant grey veins, highly polished, mirror-like reflections, rococo style, on a solid green screen background. --ar 1:1 --style raw
```


---

## 第五章：狂想者·贝多芬

### 5.1 核心美术风格：浪漫主义风暴 (Romanticist Tempest)

本章风格是**“崇高化的自然力量”**。灵感来自19世纪浪漫主义风景画，特别是卡斯帕·大卫·弗里德里希的作品。重点是表现自然的宏伟、戏剧性和不可预测性，将情感的激烈冲突外化为狂暴的天气。

- **质感**: 粗糙的岩石、被风化的废墟、流动的水面、动态的云层。
- **动态**: 整个场景都是动态的。狂风、暴雨、闪电、翻滚的乌云。环境本身就是主角，其动态变化与本章的“动态BPM”和“不和谐度”机制深度绑定。

### 5.2 关键视觉元素

- **地面**: 崎岖不平的悬崖顶端，地面是湿漉漉的、反光的风化岩石，布满裂缝，裂缝中透出微光。
- **背景**: 翻滚的、层次丰富的乌云，被远处的闪电不时照亮。远处是哥特式教堂的废墟剪影。
- **天气效果**: 倾斜的、密集的暴雨粒子；遵循“命运动机”节奏劈落的程序化闪电。
- **互动元素**: 雨水在地面汇成的水洼，被闪电击中后会变成导电的危险区域。

### 5.3 色彩与光影

- **主色调**: `#2F3E46` (风暴灰) 和 `#0C1446` (靛蓝) 构成天空和环境的基调。
- **光源**: 唯一的光源是闪电。闪电的瞬间强光会投下锐利、拉长的动态阴影，这是本章的核心光影特征。
- **强调色**: `#FFFFFF` (闪电白) 和 `#FF4500` (岩浆橙)，用于岩石裂缝和技能爆发，与冷色调背景形成强烈对比。

### 5.4 AI生成资产列表与Prompt规范

#### 资产1：风暴悬崖地面 (Stormy Cliff Ground)

- **用途**: 构成崎岖不平的战斗地面。
- **NanoBanana Prompt**:

```
Masterpiece, concept art, top-down view of a rugged, weathered cliff top, dark volcanic rock, wet and reflective surface, cracks filled with faint orange glowing lava, romanticism painting style, on a solid green screen background. --ar 1:1 --style raw
```

#### 资产2：动态风暴云背景 (Dynamic Stormy Clouds)

- **用途**: 作为场景的动态背景，需要是可循环的动画序列或精灵图集。
- **NanoBanana Prompt**:

```
Masterpiece, best quality, a dramatic, turbulent sky filled with dark, rolling storm clouds, romanticism painting style like Caspar David Friedrich, shafts of light breaking through, cinematic, on a solid green screen background, seamless loop. --ar 16:9 --style raw
```

#### 资产3：哥特废墟剪影 (Gothic Ruin Silhouette)

- **用途**: 放置在远景，增加场景的悲剧和崇高感。
- **NanoBanana Prompt**:

```
Masterpiece, concept art, the silhouette of a ruined gothic cathedral on a distant cliff, stark, jagged, against a stormy sky, romanticism painting style, on a solid green screen background. --ar 2:1 --style raw
```

---

## 第六章：摇摆公爵·艾灵顿

### 6.1 核心美术风格：装饰风艺术俱乐部 (Art Deco Club)

本章风格是**“程式化的都市夜生活”**。融合装饰风艺术（Art Deco）的几何感和黑色电影（Film Noir）的光影，营造一个既奢华又暧昧的1930年代爵士俱乐部氛围。

- **质感**: 天鹅绒、抛光黄铜、烟雾、霓虹灯管的柔和光晕。
- **动态**: 核心动态是“摇摆”。聚光灯的移动、烟雾的飘散、霓虹灯的闪烁，都带有一种慵懒、摇摆的节奏感。

### 6.2 关键视觉元素

- **地面**: 暗红色、高光泽的木质舞池，能模糊地反射上方的霓虹灯光。
- **结构**: 由黄铜栏杆和天鹅绒幕布围合的舞台区域。背景是吧台和卡座的模糊剪影。
- **光源**: 移动的聚光灯和固定的霓虹灯招牌是主光源。
- **氛围**: 浓厚的、有体积感的烟雾是本章最重要的氛围元素，光线在其中会产生美丽的丁达尔效应。

### 6.3 色彩与光影

- **主色调**: `#3D0000` (暗红) 和 `#001F3F` (深宝蓝) 构成环境的暗色基调。
- **光源色**: `#FF00AA` (霓虹粉) 和 `#00BFFF` (霓虹蓝) 是霓虹灯的颜色。`#FFD700` (金色) 是聚光灯的颜色。
- **光影**: 强烈的光影对比（Chiaroscuro）。大部分区域很暗，只有被聚光灯和霓虹灯照亮的区域是清晰的。烟雾使光线变得柔和、弥散。

### 6.4 AI生成资产列表与Prompt规范

#### 资产1：霓虹灯招牌 (Neon Sign)

- **用途**: 场景中的环境点缀和光源，可以拼出“SWING”, “JAZZ”, “CALL”, “RESPONSE”等字样。
- **NanoBanana Prompt**:

```
Masterpiece, best quality, concept art of a vintage 1930s neon sign, Art Deco style font, glowing with a vibrant pink and blue light, slightly flickering, on a solid green screen background. (Specify the word, e.g., 'SWING') --ar 3:1 --style raw
```

#### 资产2：装饰风艺术栏杆 (Art Deco Railing)

- **用途**: 围合舞池区域，作为场景的结构元素。
- **NanoBanana Prompt**:

```
Masterpiece, a repeatable module of a lavish Art Deco railing, made of polished brass, intricate geometric patterns, symmetrical, glamorous, on a solid green screen background, isometric view. --ar 2:1 --style raw
```

#### 资产3：天鹅绒幕布 (Velvet Curtain)

- **用途**: 作为舞台背景，需要有厚重感和垂坠感。
- **NanoBanana Prompt**:

```
Masterpiece, concept art of a heavy, deep red velvet curtain, tied back with a golden rope, elegant folds and drapes, theatre stage background, on a solid green screen background. --ar 1:2 --style raw
```

---

## 第七章：合成主脑·噪音

### 7.1 核心美术风格：故障艺术空间 (Glitch Art Space)

本章是**“数字世界的崩溃”**。这是“数字衰变”美学的极致体现。整个空间是非写实的、抽象的，由损坏的数据和错误的渲染构成。玩家身处音乐宇宙的底层代码之中，一切都在解构和崩坏。

- **质感**: 像素块、扫描线、数据蚊（Datamosh）、色度偏移（Chromatic Aberration）。
- **动态**: 极度不稳定。所有元素都在高频抖动、闪烁、错位。运动是卡顿的、非线性的。

### 7.2 关键视觉元素

- **地面/空间**: 没有固定的地面。玩家悬浮在一个由动态频谱分析图和示波器波形构成的三维空间中。
- **背景**: 倾泻而下的“代码瀑布”（类似《黑客帝国》），混合着破碎的像素块。
- **结构**: 漂浮在空间中的、损坏的UI元素，如VU表、加载条、错误窗口等。
- **相位区域**: 不同相位区域通过强烈的全屏色彩滤镜（如高通区为蓝色，低通区为红色）和不同的故障效果来区分。

### 7.3 色彩与光影

- **主色调**: `#000000` (纯黑) 为底色，但会被高饱和度的**RGB三原色**（`#FF0000`, `#00FF00`, `#0000FF`）的故障闪烁所打破。
- **核心色**: `#00FF41` (矩阵绿) 用于代码瀑布，`#FF00AA` (故障洋红) 用于核心敌人。
- **光影**: 没有稳定光源。光线来自随机的、全屏的故障闪烁和色度偏移。整个场景的亮度和颜色都在剧烈、快速地变化。

### 7.4 AI生成资产列表与Prompt规范

#### 资产1：代码瀑布背景 (Codefall Background)

- **用途**: 构成场景的动态背景。
- **NanoBanana Prompt**:

```
Masterpiece, best quality, abstract animation of a Matrix-style codefall, glowing green characters and glyphs cascading down on a black background, digital, cyberspace, seamless loop, on a solid green screen background. --ar 1:1 --style raw
```

#### 资产2：故障化UI元素 (Glitched UI Elements)

- **用途**: 作为漂浮在环境中的障碍物或装饰。
- **NanoBanana Prompt**:

```
Masterpiece, a collection of glitched and distorted UI elements, like a broken progress bar, a flickering error message window, and a corrupted VU meter, digital decay, datamoshing, pixelated, chromatic aberration, on a solid green screen background. --ar 1:1 --style raw
```

#### 资产3：频谱地面 (Spectrum Floor)

- **用途**: 作为玩家移动的“地面”参考。
- **NanoBanana Prompt**:

```
Masterpiece, top-down view, a dynamic, glowing audio spectrum analyzer visualization, vibrant neon bars dancing to music, abstract, cyberspace, on a solid green screen background, seamless loop. --ar 1:1 --style raw
```


---

## 附录A：绿幕抠图批处理脚本

以下Python脚本可用于批量将绿幕背景的PNG图像转换为透明底PNG：

```python
#!/usr/bin/env python3
"""
Green Screen Removal Script for Project Harmony Assets
Usage: python3 remove_greenscreen.py <input_dir> <output_dir>
"""

import sys
import os
from PIL import Image
import numpy as np

def remove_green_screen(input_path, output_path, tolerance=80):
    """
    移除图像中的纯绿色背景，生成透明底PNG。
    tolerance: 绿色判定的容差值（0-255），值越大，移除的绿色范围越广。
    """
    img = Image.open(input_path).convert("RGBA")
    data = np.array(img)
    
    # 定义绿色范围
    r, g, b, a = data[:,:,0], data[:,:,1], data[:,:,2], data[:,:,3]
    
    # 绿色通道远高于红色和蓝色通道的像素被视为绿幕
    green_mask = (g > 100) & (g - r > tolerance) & (g - b > tolerance)
    
    # 将绿幕像素的alpha设为0
    data[green_mask, 3] = 0
    
    # 处理边缘（半透明过渡）
    from scipy.ndimage import binary_dilation
    edge_mask = binary_dilation(green_mask, iterations=2) & ~green_mask
    data[edge_mask, 3] = data[edge_mask, 3] // 2  # 边缘半透明
    
    result = Image.fromarray(data)
    result.save(output_path)

def batch_process(input_dir, output_dir):
    os.makedirs(output_dir, exist_ok=True)
    for filename in os.listdir(input_dir):
        if filename.lower().endswith(('.png', '.jpg', '.jpeg')):
            input_path = os.path.join(input_dir, filename)
            output_path = os.path.join(output_dir, filename.rsplit('.', 1)[0] + '.png')
            print(f"Processing: {filename}")
            remove_green_screen(input_path, output_path)
            print(f"  -> Saved: {output_path}")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python3 remove_greenscreen.py <input_dir> <output_dir>")
        sys.exit(1)
    batch_process(sys.argv[1], sys.argv[2])
```

---

## 附录B：七章场景概念图一览

| 章节 | 场景名称 | 概念图路径 |
| :--- | :--- | :--- |
| 第一章 | 光之神殿 | `Assets/ConceptArt/Ch1_Temple_of_Light_GreenScreen.png` |
| 第二章 | 哥特回响 | `Assets/ConceptArt/Ch2_Gothic_Echo_GreenScreen.png` |
| 第三章 | 巴洛克机械城 | `Assets/ConceptArt/Ch3_Baroque_Machina_GreenScreen.png` |
| 第四章 | 洛可可水晶厅 | `Assets/ConceptArt/Ch4_Rococo_Crystal_Hall_GreenScreen.png` |
| 第五章 | 浪漫主义风暴 | `Assets/ConceptArt/Ch5_Romantic_Tempest_GreenScreen.png` |
| 第六章 | 装饰风艺术俱乐部 | `Assets/ConceptArt/Ch6_Art_Deco_Club_GreenScreen.png` |
| 第七章 | 故障艺术空间 | `Assets/ConceptArt/Ch7_Glitch_Art_Space_GreenScreen.png` |

---

## 参考文献

[1] `GDD.md` — 游戏核心设计文档
[2] `Docs/关卡与Boss整合设计文档_v3.0.md` — 关卡与Boss整合设计文档
[3] `Docs/Art_And_VFX_Direction.md` — 美术与VFX方向总文档
[4] `Docs/ART_IMPLEMENTATION_FRAMEWORK.md` — 技术美术蓝图
