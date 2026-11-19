---
tags: [ai-context, memory]
updated: 2026-11-19
---

# Persistent Memory & Quirks (`MEMORY.md`)

## 1. Project Context & Constraints
- **Clean-Room ReSDV**: Clean-room Stardew Valley re-implementation in Godot 4.3+ (strictly typed GDScript).
- **Asset Boundary**: Zero copyrighted assets in repository. Vanilla assets extracted from user-owned GOG installation into `user://vanilla_data/` and loaded directly into `ContentRegistry` during Phase 1.
- **GOG Game Source Details**:
  - Root: `/home/hysm/Games/Stardew Valley/` (Content path: `/home/hysm/Games/Stardew Valley/Content/`).
  - Validation: `ContentHashes.json` used for MD5/SHA validation of game files.
  - Data & Strings: `Data/` & `Strings/` dictionary XNBs. Must extract English base files and filter out localized suffixes (`*.de-DE.xnb`, `*.es-ES.xnb`, `*.fr-FR.xnb`, etc.).
  - Visuals & Maps: Texture XNBs extracted to PNG; `Maps/` xTile XNBs converted for Godot `TileMapLayer`.
  - Audio: `XACT/` wave banks (`Wave Bank.xwb`, `Wave Bank(1.4).xwb`) and sound bank (`Sound Bank.xsb`) unpacked to WAV/OGG.
- **Hardware Constraints**: 
  - Primary: EndeavourOS on Intel Core i5-2400 (AVX-only, no AVX2). If using Bun, require `bun-baseline`.
  - Mobile: Xiaomi Redmi Note 15 5G on Termux Fedora PRoot (`aarch64`, no `systemd`).
- **Shell Convention**: Interactive terminal commands in `fish`. Standalone executable scripts in POSIX/Bash.

## 2. Architectural Decisions
- **Autoload Singletons (Phase 1)**:
  1. `EventBus` (`res://src/core/event_bus.gd`): Typed global event dispatcher.
  2. `ContentRegistry` (`res://src/core/content_registry.gd`): Ingests `user://vanilla_data/` directly with `vanilla:*` namespace.
- **Deferred Architecture (Phase 2+)**:
  - `ModLoader` (`res://src/core/mod_loader.gd`): Multi-mod discovery (`user://mods/`), `mod.json` parsing, dependency graphs, and script/asset overriding.
- **Coding Standards**: Strict static typing for all variables, params, and return types. Composition over inheritance. No God Objects.

## 3. Active Session Notes
- Workspace documentation initialized and updated: `AGENTS.md`, `ARCHITECTURE.md`, `USER.md`, `SOUL.md`, `STATUS.md`, `MEMORY.md`.
- Scope refined: `ModLoader` deferred to Phase 2; Phase 1 prioritizes core runtime (`EventBus`, `ContentRegistry`) and vanilla data loading.
- GOG installation layout and extraction parameters fully documented.
- Next immediate task: Configure `project.godot` (Compatibility Renderer) and implement Phase 1 Autoloads (`EventBus`, `ContentRegistry`).
