---
tags: [ai-context, memory]
updated: 2026-11-19
---

# Persistent Memory & Quirks (`MEMORY.md`)

## 1. Project Context & Constraints
- **Clean-Room ReSDV**: Clean-room Stardew Valley re-implementation in Godot 4.3+ (strictly typed GDScript).
- **Asset Boundary**: Zero copyrighted assets in repository. Vanilla assets extracted from user-owned GOG installation to `user://vanilla_data/` and loaded by `ModLoader` as base mod (`priority = 0`).
- **Hardware Constraints**: 
  - Primary: EndeavourOS on Intel Core i5-2400 (AVX-only, no AVX2). If using Bun, require `bun-baseline`.
  - Mobile: Xiaomi Redmi Note 15 5G on Termux Fedora PRoot (`aarch64`, no `systemd`).
- **Shell Convention**: Interactive terminal commands in `fish`. Standalone executable scripts in POSIX/Bash.

## 2. Architectural Decisions
- **Autoload Singletons**:
  1. `EventBus` (`res://src/core/event_bus.gd`)
  2. `ContentRegistry` (`res://src/core/content_registry.gd`)
  3. `ModLoader` (`res://src/core/mod_loader.gd`)
- **Coding Standards**: Strict static typing for all variables, params, and return types. Composition over inheritance. No God Objects.

## 3. Active Session Notes
- Workspace documentation initialized: `AGENTS.md`, `ARCHITECTURE.md`, `USER.md`, `SOUL.md`, `STATUS.md`, `MEMORY.md`.
- Git repository configured: linked to `git@github.com:Hysm25/ReSDV.git`, strict clean-room `.gitignore` active.
- Target directory layout initialized under `src/` (`core`, `importer`, `resources`, `systems`, `entities`, `ui`).
- `project.godot` initialized.
- Next immediate task: Configure renderer to Compatibility and implement Autoloads (`EventBus`, `ContentRegistry`, `ModLoader`).
