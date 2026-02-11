#!/usr/bin/env python3
import os
import re
from collections import defaultdict
from pathlib import Path

# 定义要分析的文档
docs_to_analyze = [
    "GDD.md",
    "Docs/Numerical_Design_Documentation.md",
    "Docs/Spell_Visual_Enhancement_Design.md",
    "Docs/Enemy_System_Design.md",
    "Docs/Art_And_VFX_Direction.md",
    "Docs/ART_IMPLEMENTATION_FRAMEWORK.md",
    "Docs/Audio_Design_Guide.md",
    "Docs/AestheticFatigueSystem_Documentation.md",
    "Docs/ResonanceSlicing_System_Design.md",
    "Docs/TimbreSystem_Documentation.md",
    "Docs/SummoningSystem_Documentation.md",
    "Docs/MetaProgressionSystem_Documentation.md",
    "Docs/关卡与Boss整合设计文档_v3.0.md",
]

base_path = Path("/home/ubuntu/project-harmony-gdd")

# 存储分析结果
analysis = {
    "note_definitions": defaultdict(list),
    "chord_definitions": defaultdict(list),
    "enemy_definitions": defaultdict(list),
    "system_descriptions": defaultdict(list),
}

# 音符参数表格模式
note_pattern = re.compile(r'\|\s*([CDEFGAB])\s*\|\s*(\d+)\s*\|\s*\*?\*?(\d+)\*?\*?\s*\|\s*\*?\*?(\d+)\*?\*?\s*\|\s*\*?\*?(\d+)\*?\*?\s*\|')

# 和弦类型模式
chord_pattern = re.compile(r'\|\s*(大三和弦|小三和弦|增三和弦|减三和弦|属七和弦|减七和弦|大七和弦|小七和弦|挂留和弦|属九和弦|大九和弦|减九和弦|属十一和弦|属十三和弦|减十三和弦)\s*\|')

# 敌人类型模式
enemy_pattern = re.compile(r'\*\*(Static|Silence|Screech|Pulse|Wall)\s*\(.*?\)\*\*')

print("=== 文档内容分析 ===\n")

for doc_path in docs_to_analyze:
    full_path = base_path / doc_path
    if not full_path.exists():
        print(f"⚠️  文件不存在: {doc_path}")
        continue
    
    print(f"📄 分析: {doc_path}")
    
    with open(full_path, 'r', encoding='utf-8') as f:
        content = f.read()
        lines = content.split('\n')
        
        # 查找音符定义
        for i, line in enumerate(lines):
            match = note_pattern.search(line)
            if match:
                note, dmg, spd, dur, size = match.groups()
                analysis["note_definitions"][note].append({
                    "file": doc_path,
                    "line": i + 1,
                    "values": f"DMG={dmg}, SPD={spd}, DUR={dur}, SIZE={size}"
                })
        
        # 查找和弦定义
        for i, line in enumerate(lines):
            match = chord_pattern.search(line)
            if match:
                chord = match.group(1)
                analysis["chord_definitions"][chord].append({
                    "file": doc_path,
                    "line": i + 1,
                    "context": line.strip()[:100]
                })
        
        # 查找敌人定义
        for i, line in enumerate(lines):
            match = enemy_pattern.search(line)
            if match:
                enemy = match.group(1)
                analysis["enemy_definitions"][enemy].append({
                    "file": doc_path,
                    "line": i + 1,
                    "context": line.strip()[:100]
                })

print("\n" + "="*60)
print("📊 分析结果汇总")
print("="*60)

# 检查音符定义的一致性
print("\n### 1. 音符参数定义")
for note in sorted(analysis["note_definitions"].keys()):
    defs = analysis["note_definitions"][note]
    if len(defs) > 0:
        print(f"\n音符 {note}:")
        unique_values = set(d["values"] for d in defs)
        if len(unique_values) == 1:
            print(f"  ✅ 定义一致: {list(unique_values)[0]}")
        else:
            print(f"  ⚠️  发现不一致定义:")
            for d in defs:
                print(f"     - {d['file']}:{d['line']} → {d['values']}")

# 检查和弦定义出现次数
print("\n### 2. 和弦类型出现统计")
for chord in sorted(analysis["chord_definitions"].keys()):
    defs = analysis["chord_definitions"][chord]
    print(f"\n{chord}: 出现 {len(defs)} 次")
    for d in defs:
        print(f"  - {d['file']}:{d['line']}")

# 检查敌人定义出现次数
print("\n### 3. 敌人类型出现统计")
for enemy in sorted(analysis["enemy_definitions"].keys()):
    defs = analysis["enemy_definitions"][enemy]
    print(f"\n{enemy}: 出现 {len(defs)} 次")
    for d in defs:
        print(f"  - {d['file']}:{d['line']}")

# 检查文档大小和潜在重复
print("\n### 4. 文档大小分析")
doc_sizes = []
for doc_path in docs_to_analyze:
    full_path = base_path / doc_path
    if full_path.exists():
        size = os.path.getsize(full_path)
        lines = len(open(full_path, 'r', encoding='utf-8').readlines())
        doc_sizes.append((doc_path, size, lines))

doc_sizes.sort(key=lambda x: x[1], reverse=True)
for doc, size, lines in doc_sizes:
    print(f"  {doc}: {size:,} bytes, {lines} 行")

print("\n" + "="*60)
print("分析完成")
print("="*60)
