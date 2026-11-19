# Project Architecture (`ARCHITECTURE.md`)

> **Project**: Clean-Room Re-implementation of *Stardew Valley* in **Godot 4.x (GDScript)**.
> **Goal**: Legal, open-source engine runtime that imports assets/data from a user-owned **GOG** copy of the game, built from day one with a first-class **Modding System** (inspired by Minecraft Horizon / OpenMW).

---

## 1. Core Legal & Data Boundary
- **Zero Copyrighted Assets**: This repository contains **engine code only**. No sprites, audio, maps, dialogue, or `.xnb` files from the original game are ever committed.
- **Asset Importer Pipeline**: On first launch (or via CLI tool), the engine extracts `.xnb` assets from the user's GOG installation into `user://vanilla_data/` (converted to PNG, OGG/WAV, JSON).
- **Vanilla as Base Mod**: The extracted `vanilla_data/` is loaded by the exact same `ModLoader` pipeline as user mods (`priority = 0`).

---

## 2. Mandatory Godot 4 & GDScript Standards
- **Godot Version**: Godot 4.3+ (Compatibility Renderer preferred for low-spec desktop & Android performance).
- **Strict Static Typing**: Every variable, parameter, and return type MUST be explicitly typed (e.g., `var count: int = 0`, `func get_item(id: StringName) -> ItemData:`).
- **Composition over Inheritance**: Prefer small component nodes and `Resource` subclasses over deep inheritance trees.
- **No God Objects**: Never dump game systems (farming, inventory, time) into `Player.gd` or `Main.gd`. Each system lives in its own isolated script/scene.

---

## 3. Core Architecture: Registry + EventBus + ModLoader

### Autoload Singletons (in load order)
1. `EventBus` (`res://src/core/event_bus.gd`):
   - Global typed signals for decoupled communication (`day_started`, `time_ticked`, `crop_planted`, `crop_harvested`, `item_used`, `mod_loaded`).
   - Systems and mods subscribe to signals instead of mutating other systems directly.
2. `ContentRegistry` (`res://src/core/content_registry.gd`):
   - Central dictionaries holding all registered game definitions (`items`, `crops`, `tiles`, `recipes`, `npcs`) keyed by namespaced IDs (e.g., `vanilla:parsnip`, `mymod:golden_parsnip`).
   - Supports overriding existing IDs based on mod load order.
3. `ModLoader` (`res://src/core/mod_loader.gd`):
   - Scans `user://vanilla_data/` first, then `user://mods/`.
   - Reads `mod.json` manifests (id, version, dependencies, load_order).
   - Loads Data Mods (JSON/Resources) into `ContentRegistry` and Script/Pack Mods (`.pck` / dynamic `.gd`) safely.

---

## 4. Directory Layout
```text
res://
├── project.godot
├── ARCHITECTURE.md
├── STATUS.md                 # Current progress & next immediate task
└── src/
    ├── core/                 # Autoloads: event_bus.gd, content_registry.gd, mod_loader.gd
    ├── importer/             # GOG folder scanner & XNB -> PNG/JSON/OGG extractor
    ├── resources/            # Custom Resource classes (ItemData, CropData, ToolData)
    ├── systems/              # Isolated systems (time/, farming/, inventory/, world/)
    ├── entities/             # Player, NPCs, World Objects
    └── ui/                   # HUD, Inventory UI, Mod Manager UI
