"""
=============================================================================
Project Harmony — 跑分可视化报告生成器
=============================================================================

本脚本调用 balance_scorer.py 的跑分系统，生成可视化图表和结构化报告。
用于在数值调整后一键生成平衡性分析报告。

用法：
    python3 BalanceKit/generate_report.py

输出：
    BalanceKit/Reports/ 目录下的图表和JSON报告
"""

import sys
import os
import json

# 确保可以导入同目录模块
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.style as mplstyle
mplstyle.use('seaborn-v0_8-whitegrid')
plt.rcParams['font.family'] = 'Noto Sans CJK SC'
plt.rcParams['axes.unicode_minus'] = False
plt.rcParams['figure.dpi'] = 150

import numpy as np

from balance_scorer import (
    PlayerBuild, create_chord_registry, create_strategy_library,
    create_upgrade_pool, run_full_benchmark, SimulationResult,
    create_base_notes, DMG_PER_POINT, NoteStats
)

# 输出目录
REPORT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "Reports")
os.makedirs(REPORT_DIR, exist_ok=True)


def build_scenarios():
    """构建三个阶段的Build。"""
    upgrades = create_upgrade_pool()
    upgrade_map = {u.id: u for u in upgrades}

    # 初始Build
    build_base = PlayerBuild()

    # 中期Build
    build_mid = PlayerBuild()
    build_mid.apply_upgrade(upgrade_map["note_dmg"], 3, "G")
    build_mid.apply_upgrade(upgrade_map["note_dmg"], 2, "B")
    build_mid.apply_upgrade(upgrade_map["global_dmg"], 2)
    build_mid.apply_upgrade(upgrade_map["monotony_tolerance"], 2)
    build_mid.apply_upgrade(upgrade_map["density_tolerance"], 1)
    build_mid.apply_upgrade(upgrade_map["chord_dmg"], 2)
    build_mid.apply_upgrade(upgrade_map["bpm_boost"], 2)
    build_mid.apply_upgrade(upgrade_map["hp_boost"], 3)

    # 后期Build
    build_late = PlayerBuild()
    build_late.apply_upgrade(upgrade_map["note_dmg"], 5, "G")
    build_late.apply_upgrade(upgrade_map["note_dmg"], 4, "B")
    build_late.apply_upgrade(upgrade_map["note_spd"], 3, "D")
    build_late.apply_upgrade(upgrade_map["note_size"], 3, "E")
    build_late.apply_upgrade(upgrade_map["global_dmg"], 4)
    build_late.apply_upgrade(upgrade_map["monotony_tolerance"], 4)
    build_late.apply_upgrade(upgrade_map["density_tolerance"], 3)
    build_late.apply_upgrade(upgrade_map["dissonance_tolerance"], 3)
    build_late.apply_upgrade(upgrade_map["monotony_decay"], 2)
    build_late.apply_upgrade(upgrade_map["chord_dmg"], 4)
    build_late.apply_upgrade(upgrade_map["chord_dissonance_resist"], 3)
    build_late.apply_upgrade(upgrade_map["extended_chord_unlock"], 1)
    build_late.apply_upgrade(upgrade_map["bpm_boost"], 4)
    build_late.apply_upgrade(upgrade_map["hp_boost"], 5)
    build_late.apply_upgrade(upgrade_map["hp_regen"], 3)
    build_late.apply_upgrade(upgrade_map["progression_power"], 2)
    build_late.apply_upgrade(upgrade_map["resolution_mastery"], 2)

    return {
        "初始": build_base,
        "中期": build_mid,
        "后期": build_late,
    }


def plot_strategy_comparison(all_results: dict[str, list[SimulationResult]]):
    """图1: 策略综合得分对比（三阶段）。"""
    fig, axes = plt.subplots(1, 3, figsize=(20, 7), sharey=True)

    for idx, (phase, results) in enumerate(all_results.items()):
        ax = axes[idx]
        names = [r.strategy_name for r in results]
        scores = [r.composite_score for r in results]
        colors = ['#2ecc71' if s > 20 else '#f39c12' if s > 0 else '#e74c3c' for s in scores]

        bars = ax.barh(range(len(names)), scores, color=colors, edgecolor='white', linewidth=0.5)
        ax.set_yticks(range(len(names)))
        ax.set_yticklabels(names, fontsize=8)
        ax.set_xlabel('综合得分', fontsize=10)
        ax.set_title(f'{phase}阶段', fontsize=12, fontweight='bold')
        ax.axvline(x=0, color='gray', linestyle='--', alpha=0.5)

        for bar, score in zip(bars, scores):
            ax.text(bar.get_width() + 0.5, bar.get_y() + bar.get_height()/2,
                    f'{score:.1f}', va='center', fontsize=7)

    fig.suptitle('Project Harmony — 策略综合得分对比（初始/中期/后期）', fontsize=14, fontweight='bold')
    plt.tight_layout()
    plt.savefig(os.path.join(REPORT_DIR, 'strategy_comparison.png'), bbox_inches='tight')
    plt.close()
    print("  [OK] strategy_comparison.png")


def plot_dps_vs_risk(all_results: dict[str, list[SimulationResult]]):
    """图2: DPS vs 风险散点图。"""
    fig, axes = plt.subplots(1, 3, figsize=(18, 6))

    for idx, (phase, results) in enumerate(all_results.items()):
        ax = axes[idx]
        for r in results:
            color = '#2ecc71' if r.composite_score > 20 else '#f39c12' if r.composite_score > 0 else '#e74c3c'
            ax.scatter(r.risk_score, r.effective_dps, s=80, c=color, alpha=0.8, edgecolors='black', linewidth=0.5)
            ax.annotate(r.strategy_name[:6], (r.risk_score, r.effective_dps),
                        fontsize=6, ha='center', va='bottom')

        ax.set_xlabel('风险评分', fontsize=10)
        ax.set_ylabel('有效DPS', fontsize=10)
        ax.set_title(f'{phase}阶段', fontsize=12, fontweight='bold')
        ax.axhline(y=60, color='blue', linestyle=':', alpha=0.3, label='基准DPS')
        ax.legend(fontsize=8)

    fig.suptitle('Project Harmony — DPS vs 风险散点图', fontsize=14, fontweight='bold')
    plt.tight_layout()
    plt.savefig(os.path.join(REPORT_DIR, 'dps_vs_risk.png'), bbox_inches='tight')
    plt.close()
    print("  [OK] dps_vs_risk.png")


def plot_fatigue_peaks(all_results: dict[str, list[SimulationResult]]):
    """图3: 各策略的疲劳峰值热力图。"""
    fig, axes = plt.subplots(1, 3, figsize=(20, 7))

    for idx, (phase, results) in enumerate(all_results.items()):
        ax = axes[idx]
        names = [r.strategy_name for r in results]
        data = np.array([
            [r.peak_monotony for r in results],
            [r.peak_density for r in results],
            [r.peak_dissonance for r in results],
        ])

        im = ax.imshow(data, cmap='RdYlGn_r', aspect='auto', vmin=0, vmax=100)
        ax.set_xticks(range(len(names)))
        ax.set_xticklabels(names, rotation=45, ha='right', fontsize=7)
        ax.set_yticks([0, 1, 2])
        ax.set_yticklabels(['单调值', '密度值', '不和谐值'], fontsize=9)
        ax.set_title(f'{phase}阶段', fontsize=12, fontweight='bold')

        for i in range(3):
            for j in range(len(names)):
                ax.text(j, i, f'{data[i, j]:.0f}', ha='center', va='center', fontsize=6,
                        color='white' if data[i, j] > 50 else 'black')

    fig.suptitle('Project Harmony — 疲劳峰值热力图', fontsize=14, fontweight='bold')
    plt.colorbar(im, ax=axes, shrink=0.6, label='疲劳值 (0-100)')
    plt.tight_layout()
    plt.savefig(os.path.join(REPORT_DIR, 'fatigue_heatmap.png'), bbox_inches='tight')
    plt.close()
    print("  [OK] fatigue_heatmap.png")


def plot_growth_curve():
    """图4: 数值成长曲线（音符DPS随升级的变化）。"""
    upgrades = create_upgrade_pool()
    upgrade_map = {u.id: u for u in upgrades}

    levels = range(0, 7)  # 0-6级DMG升级
    notes_to_track = ["C", "G", "B", "E"]

    fig, ax = plt.subplots(figsize=(10, 6))

    for note_name in notes_to_track:
        dps_values = []
        for lv in levels:
            build = PlayerBuild()
            if lv > 0:
                build.apply_upgrade(upgrade_map["note_dmg"], lv, note_name)
            note = build.notes[note_name]
            dmg = (note.total_dmg + build.global_dmg_bonus) * DMG_PER_POINT
            hit = note.hit_factor
            dps = dmg * hit / build.beat_interval
            dps_values.append(dps)

        ax.plot(list(levels), dps_values, marker='o', linewidth=2, label=f'{note_name}音符')

    ax.set_xlabel('伤害增幅升级等级', fontsize=11)
    ax.set_ylabel('有效DPS', fontsize=11)
    ax.set_title('Project Harmony — 音符DPS成长曲线（单维度升级）', fontsize=13, fontweight='bold')
    ax.legend(fontsize=10)
    ax.grid(True, alpha=0.3)

    plt.tight_layout()
    plt.savefig(os.path.join(REPORT_DIR, 'growth_curve.png'), bbox_inches='tight')
    plt.close()
    print("  [OK] growth_curve.png")


def plot_chord_dissonance_curve():
    """图5: 和弦不和谐度-威力-风险关系图。"""
    chords = create_chord_registry()

    fig, ax = plt.subplots(figsize=(12, 7))

    for name, c in chords.items():
        color = '#e74c3c' if c.is_extended else '#3498db'
        marker = 's' if c.note_count >= 5 else 'o'
        size = c.note_count * 40

        ax.scatter(c.base_dissonance, c.dmg_multiplier, s=size, c=color,
                   marker=marker, alpha=0.7, edgecolors='black', linewidth=0.5)
        ax.annotate(name, (c.base_dissonance, c.dmg_multiplier),
                    fontsize=7, ha='center', va='bottom',
                    xytext=(0, 5), textcoords='offset points')

    ax.set_xlabel('不和谐度', fontsize=11)
    ax.set_ylabel('伤害倍率', fontsize=11)
    ax.set_title('Project Harmony — 和弦不和谐度 vs 伤害倍率', fontsize=13, fontweight='bold')

    # 添加图例
    from matplotlib.lines import Line2D
    legend_elements = [
        Line2D([0], [0], marker='o', color='w', markerfacecolor='#3498db', markersize=10, label='基础和弦(3-4音)'),
        Line2D([0], [0], marker='s', color='w', markerfacecolor='#e74c3c', markersize=10, label='扩展和弦(5-6音)'),
    ]
    ax.legend(handles=legend_elements, fontsize=10)
    ax.grid(True, alpha=0.3)

    plt.tight_layout()
    plt.savefig(os.path.join(REPORT_DIR, 'chord_dissonance_power.png'), bbox_inches='tight')
    plt.close()
    print("  [OK] chord_dissonance_power.png")


def plot_extended_chord_penalty():
    """图6: 扩展和弦的不和谐度惩罚增长曲线。"""
    chords = create_chord_registry()

    note_counts = []
    dissonances = []
    fatigue_costs = []
    names = []

    # 按音数分组取平均
    from collections import defaultdict
    by_count = defaultdict(list)
    for name, c in chords.items():
        by_count[c.note_count].append(c)

    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 6))

    counts = sorted(by_count.keys())
    avg_diss = [np.mean([c.base_dissonance for c in by_count[n]]) for n in counts]
    avg_fatigue = [np.mean([c.fatigue_dissonance for c in by_count[n]]) for n in counts]
    max_diss = [max([c.base_dissonance for c in by_count[n]]) for n in counts]
    min_diss = [min([c.base_dissonance for c in by_count[n]]) for n in counts]

    ax1.fill_between(counts, min_diss, max_diss, alpha=0.2, color='#e74c3c')
    ax1.plot(counts, avg_diss, 'o-', color='#e74c3c', linewidth=2, markersize=8, label='平均不和谐度')
    ax1.set_xlabel('和弦音数', fontsize=11)
    ax1.set_ylabel('不和谐度', fontsize=11)
    ax1.set_title('和弦音数 vs 不和谐度', fontsize=12, fontweight='bold')
    ax1.legend(fontsize=10)
    ax1.grid(True, alpha=0.3)

    ax2.plot(counts, avg_fatigue, 's-', color='#8e44ad', linewidth=2, markersize=8, label='平均疲劳不和谐代价')
    ax2.set_xlabel('和弦音数', fontsize=11)
    ax2.set_ylabel('疲劳不和谐代价', fontsize=11)
    ax2.set_title('和弦音数 vs 疲劳代价', fontsize=12, fontweight='bold')
    ax2.legend(fontsize=10)
    ax2.grid(True, alpha=0.3)

    fig.suptitle('Project Harmony — 扩展和弦惩罚增长曲线', fontsize=14, fontweight='bold')
    plt.tight_layout()
    plt.savefig(os.path.join(REPORT_DIR, 'extended_chord_penalty.png'), bbox_inches='tight')
    plt.close()
    print("  [OK] extended_chord_penalty.png")


def plot_delay_range_analysis(chord_registry):
    """图7: 延迟与距离风险分析图 (v2.1新增)。"""
    from balance_scorer import StrategySimulator, SPD_PER_POINT, DUR_PER_POINT

    fig, axes = plt.subplots(1, 3, figsize=(20, 6))

    # --- 子图1: 音符射程与距离因子 ---
    ax1 = axes[0]
    notes = create_base_notes()
    note_names = list(notes.keys())
    ranges = [n.effective_range for n in notes.values()]
    # 计算调整后的range_hit
    sim = StrategySimulator(PlayerBuild(), chord_registry)
    range_hits = []
    for n in notes.values():
        rh = min(1.0, n.effective_range / sim.REFERENCE_RANGE)
        sc = min(sim.SIZE_COMP_CAP, max(0, n.total_size - sim.SIZE_BASELINE) * sim.SIZE_COMP_FACTOR)
        rh = rh + sc * (1.0 - rh)
        range_hits.append(rh)

    x = np.arange(len(note_names))
    bars = ax1.bar(x, ranges, color=['#2ecc71' if rh >= 0.9 else '#f39c12' if rh >= 0.7 else '#e74c3c' for rh in range_hits],
                   edgecolor='white', linewidth=0.5)
    ax1.set_xticks(x)
    ax1.set_xticklabels(note_names, fontsize=11)
    ax1.set_ylabel('有效射程 (px)', fontsize=10)
    ax1.set_title('音符有效射程', fontsize=12, fontweight='bold')
    ax1.axhline(y=sim.REFERENCE_RANGE, color='blue', linestyle='--', alpha=0.5, label=f'基准射程({sim.REFERENCE_RANGE:.0f}px)')
    ax1.legend(fontsize=8)

    # 在柱子上标注range_hit
    for bar, rh in zip(bars, range_hits):
        ax1.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 20,
                 f'{rh:.2f}', ha='center', va='bottom', fontsize=9, fontweight='bold')

    # --- 子图2: 和弦延迟命中折扣 ---
    ax2 = axes[1]
    delay_chords = [(name, c) for name, c in chord_registry.items() if c.delay_beats > 0]
    if delay_chords:
        names = [n for n, _ in delay_chords]
        delays = [c.delay_beats for _, c in delay_chords]
        base_hits = [1.0 / (1.0 + sim.DELAY_PENALTY_RATE * c.delay_beats) for _, c in delay_chords]
        aoe_comps = [min(sim.AOE_COMP_CAP, c.aoe_radius_mult * sim.AOE_COMP_FACTOR) for _, c in delay_chords]
        adjusted_hits = [bh + ac * (1.0 - bh) for bh, ac in zip(base_hits, aoe_comps)]
        dmg_mults = [c.dmg_multiplier for _, c in delay_chords]

        x = np.arange(len(names))
        width = 0.35
        bars1 = ax2.bar(x - width/2, base_hits, width, label='基础命中率', color='#e74c3c', alpha=0.8)
        bars2 = ax2.bar(x + width/2, adjusted_hits, width, label='AOE补偿后', color='#2ecc71', alpha=0.8)

        ax2.set_xticks(x)
        ax2.set_xticklabels(names, rotation=30, ha='right', fontsize=8)
        ax2.set_ylabel('延迟命中率', fontsize=10)
        ax2.set_title('延迟法术命中折扣', fontsize=12, fontweight='bold')
        ax2.legend(fontsize=8)
        ax2.set_ylim(0, 1.1)

        # 标注延迟拍数和伤害倍率
        for bar, d, dm in zip(bars2, delays, dmg_mults):
            ax2.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.02,
                     f'{d:.0f}拍/{dm:.1f}x', ha='center', va='bottom', fontsize=7)

    # --- 子图3: 风险-补偿平衡散点图 ---
    ax3 = axes[2]
    # 对每个和弦计算 "实际有效倍率" = dmg_multiplier * delay_hit
    for name, c in chord_registry.items():
        if c.dmg_multiplier > 0:
            delay_hit = 1.0
            if c.delay_beats > 0:
                delay_hit = 1.0 / (1.0 + sim.DELAY_PENALTY_RATE * c.delay_beats)
                aoe_comp = min(sim.AOE_COMP_CAP, c.aoe_radius_mult * sim.AOE_COMP_FACTOR)
                delay_hit = delay_hit + aoe_comp * (1.0 - delay_hit)

            raw_power = c.dmg_multiplier
            eff_power = c.dmg_multiplier * delay_hit
            risk = c.fatigue_dissonance * 100 + c.delay_beats * 10

            color = '#e74c3c' if c.is_extended else '#3498db'
            marker = 's' if c.delay_beats > 0 else 'o'
            ax3.scatter(risk, eff_power, s=c.note_count * 40, c=color,
                       marker=marker, alpha=0.7, edgecolors='black', linewidth=0.5)
            ax3.annotate(name[:4], (risk, eff_power), fontsize=6, ha='center', va='bottom')

            # 画一条从raw到eff的竖线表示延迟损失
            if c.delay_beats > 0:
                ax3.plot([risk, risk], [eff_power, raw_power], color='gray', linestyle=':', alpha=0.5)
                ax3.scatter(risk, raw_power, s=20, c='gray', marker='x', alpha=0.5)

    ax3.set_xlabel('综合风险 (疲劳代价+延迟)', fontsize=10)
    ax3.set_ylabel('有效伤害倍率', fontsize=10)
    ax3.set_title('风险-补偿平衡图', fontsize=12, fontweight='bold')
    ax3.grid(True, alpha=0.3)

    from matplotlib.lines import Line2D
    legend_elements = [
        Line2D([0], [0], marker='o', color='w', markerfacecolor='#3498db', markersize=8, label='基础和弦(无延迟)'),
        Line2D([0], [0], marker='s', color='w', markerfacecolor='#3498db', markersize=8, label='基础和弦(有延迟)'),
        Line2D([0], [0], marker='s', color='w', markerfacecolor='#e74c3c', markersize=8, label='扩展和弦(有延迟)'),
        Line2D([0], [0], marker='x', color='gray', markersize=8, label='延迟前原始倍率'),
    ]
    ax3.legend(handles=legend_elements, fontsize=7, loc='upper left')

    fig.suptitle('Project Harmony — 延迟与距离风险分析 (v2.1)', fontsize=14, fontweight='bold')
    plt.tight_layout()
    plt.savefig(os.path.join(REPORT_DIR, 'delay_range_analysis.png'), bbox_inches='tight')
    plt.close()
    print("  [OK] delay_range_analysis.png")


def generate_json_report(all_results: dict[str, list[SimulationResult]]):
    """生成JSON格式的结构化跑分报告。"""
    report = {}
    for phase, results in all_results.items():
        phase_data = []
        for r in results:
            phase_data.append({
                "strategy": r.strategy_name,
                "effective_dps": round(r.effective_dps, 1),
                "raw_dps": round(r.raw_dps, 1),
                "burst_dps": round(r.burst_dps, 1),
                "survival_score": round(r.survival_score, 1),
                "risk_score": round(r.risk_score, 1),
                "composite_score": round(r.composite_score, 1),
                "peak_monotony": round(r.peak_monotony, 1),
                "peak_density": round(r.peak_density, 1),
                "peak_dissonance": round(r.peak_dissonance, 1),
                "dissonance_damage": round(r.dissonance_damage, 1),
                "lockout_beats": r.lockout_beats,
                "total_healing": round(r.total_healing, 1),
                "total_shielding": round(r.total_shielding, 1),
                # v2.1 新增
                "total_delay_discount": round(r.total_delay_discount, 3),
                "total_range_discount": round(r.total_range_discount, 3),
                "delay_exposure_time": round(r.delay_exposure_time, 1),
                "avg_range_factor": round(r.avg_range_factor, 3),
                "proximity_risk": round(r.proximity_risk, 2),
            })
        report[phase] = phase_data

    path = os.path.join(REPORT_DIR, 'benchmark_results.json')
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(report, f, ensure_ascii=False, indent=2)
    print(f"  [OK] benchmark_results.json")


def main():
    print()
    print("╔══════════════════════════════════════════════════════════════════════════╗")
    print("║     Project Harmony — 跑分可视化报告生成器                                ║")
    print("╚══════════════════════════════════════════════════════════════════════════╝")
    print()

    chord_registry = create_chord_registry()
    strategies = create_strategy_library()
    scenarios = build_scenarios()

    # 运行所有场景的跑分
    print("正在运行跑分...")
    all_results = {}
    for phase, build in scenarios.items():
        results = run_full_benchmark(build, strategies, chord_registry)
        all_results[phase] = results
        print(f"  [OK] {phase}阶段完成")

    # 生成图表
    print("\n正在生成可视化图表...")
    plot_strategy_comparison(all_results)
    plot_dps_vs_risk(all_results)
    plot_fatigue_peaks(all_results)
    plot_growth_curve()
    plot_chord_dissonance_curve()
    plot_extended_chord_penalty()
    plot_delay_range_analysis(chord_registry)

    # 生成JSON报告
    print("\n正在生成结构化报告...")
    generate_json_report(all_results)

    print(f"\n所有报告已生成至: {REPORT_DIR}/")
    print("完成！")


if __name__ == "__main__":
    main()
