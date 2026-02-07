# Project Harmony: Resonance Horizon — Godot 4.6 Implementation

## Overview

This is the Godot 4.6 game project for **Project Harmony: Resonance Horizon**, a survivor-like roguelike that deeply integrates music theory with a magic system. Players cast spells through musical notes and chords, with gameplay mechanics rooted in real music theory concepts.

## Project Structure

```
godot_project/
├── project.godot              # Godot project configuration
├── icon.svg                   # Project icon
├── scenes/                    # Scene files (.tscn)
│   ├── main_menu.tscn         # Main menu scene (entry point)
│   ├── main_game.tscn         # Core gameplay scene
│   └── game_over.tscn         # Game over / results scene
├── scripts/
│   ├── autoload/              # Global singletons (Autoload)
│   │   ├── game_manager.gd          # Game state, BPM, leveling
│   │   ├── music_theory_engine.gd   # Chord recognition, progression analysis
│   │   ├── global_music_manager.gd  # Audio bus, spectrum analysis
│   │   ├── fatigue_manager.gd       # Aesthetic Fatigue Engine (AFI)
│   │   ├── spellcraft_system.gd     # Sequencer, spell casting, chord building
│   │   └── input_setup.gd           # Input action registration
│   ├── data/
│   │   └── music_data.gd            # Music theory constants, note stats, chord maps
│   ├── entities/
│   │   ├── player.gd                # Player controller (dodecahedron core)
│   │   └── enemy_base.gd            # Enemy base class (jagged shards)
│   ├── systems/
│   │   ├── projectile_manager.gd    # MultiMesh bullet system
│   │   └── enemy_spawner.gd         # Wave-based enemy spawning
│   ├── scenes/
│   │   ├── main_menu.gd             # Main menu logic
│   │   ├── main_game.gd             # Game loop orchestration
│   │   └── game_over.gd             # Game over screen
│   └── ui/
│       ├── hud.gd                   # HUD overlay (HP, fatigue, BPM)
│       ├── hp_bar.gd                # Waveform HP bar (sine → sawtooth)
│       ├── fatigue_meter.gd         # AFI meter with component breakdown
│       ├── sequencer_ui.gd          # 4-measure sequencer grid
│       └── upgrade_panel.gd         # Roguelike upgrade selection
└── shaders/
    ├── sacred_geometry.gdshader     # Sacred geometry patterns (menu BG)
    ├── pulsing_grid.gdshader        # Beat-reactive ground grid
    ├── fatigue_filter.gdshader      # Full-screen fatigue post-processing
    ├── projectile_glow.gdshader     # Projectile glow effect
    └── event_horizon.gdshader       # Arena boundary (white noise wall)
```

## Core Systems

### 1. Music Theory Engine
- Real-time chord identification from note combinations
- Chord function analysis (Tonic / Dominant / Predominant)
- Chord progression tracking with bonus effects (D→T resolution, etc.)
- Dissonance calculation for self-damage mechanics

### 2. Aesthetic Fatigue System (AFI)
- 8-dimensional fatigue analysis: pitch entropy, transition entropy, rhythm entropy, chord diversity, n-gram recurrence, density, rest deficit, sustained pressure
- Exponential time-decay weighting with sliding window
- 5 fatigue levels (None → Critical) with damage multiplier penalties
- Real-time recovery suggestions

### 3. Spellcraft System
- 7 white keys (C-B) as base spells with unique stat profiles
- 5 black keys as modifier effects (Pierce, Homing, Split, Echo, Scatter)
- 4-measure × 4-beat sequencer for automated casting
- Chord building with 0.3s input window
- 9 base chord types → 9 spell forms (projectile, DoT, explosive, shockwave, field, divine strike, shield, summon, charged)
- 6 extended chord types (unlockable) for advanced spells

### 4. Projectile Manager
- Data-driven bullet system (no individual nodes)
- MultiMeshInstance2D for GPU batch rendering
- Supports: piercing, homing, splitting, echo, scatter, explosive, shockwave, field, summon

### 5. Enemy System
- Quantized step-movement (12 FPS) for "dissonant" feel
- 4 enemy types: Basic, Fast, Tank, Swarm
- Difficulty scaling over time (HP, speed, spawn rate)

## Art Direction

- **Color Palette**: Deep navy/black backgrounds, cyan/teal accents, warm gold highlights
- **Player**: Regular dodecahedron energy core with sacred geometry patterns
- **Enemies**: Jagged, irregular polygon shards with glitch effects
- **UI**: Waveform HP bar (sine when healthy → sawtooth when damaged)
- **Shaders**: Beat-reactive grid, fatigue desaturation filter, sacred geometry backgrounds

## Input Mapping

| Key | Action |
|-----|--------|
| WASD / Arrows | Movement |
| A S D F G H J | Notes: C D E F G A B |
| W E T Y U | Modifiers: C# D# F# G# A# |
| 1 2 3 | Manual cast slots |
| ESC | Pause |
| TAB | Toggle sequencer |

## Requirements

- Godot Engine 4.6+
- Forward+ rendering mode
- 1920×1080 target resolution

## Getting Started

1. Open this folder in Godot 4.6
2. The main scene is `scenes/main_menu.tscn`
3. Press F5 to run the project
4. Use WASD to move, note keys to cast spells

## Design Documents

See the `/Docs` folder in the repository root for complete design documentation:
- `GDD.md` — Full Game Design Document
- `Numerical_Design_Documentation.md` — Detailed numerical balance
- `AestheticFatigueSystem_Documentation.md` — Fatigue system deep dive
- `Godot_Implementation_Guide.md` — Technical implementation guide
- `Art_Direction_Resonance_Horizon.md` — Visual design specifications
