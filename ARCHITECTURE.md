# Project Architecture (`ARCHITECTURE.md`)

> **Project**: Clean-Room Re-implementation of *Stardew Valley* in **Godot 4.x (GDScript)**.
> **Goal**: Legal, open-source engine runtime that imports assets/data from a user-owned **GOG** copy of the game (v1.6+). Phase 1 focuses strictly on the clean-room engine core and direct vanilla data ingestion, with a first-class **Modding System** (`ModLoader`) planned for Phase 2+.

---

## 1. Core Legal & Data Boundary
- **Zero Copyrighted Assets**: This repository contains **engine code only**. No sprites, audio, maps, dialogue, or `.xnb` files from the original game are ever committed.
- **Asset Importer Pipeline**: On first launch (or via CLI tool), the engine extracts assets from the user's GOG installation into `user://vanilla_data/` (converted to PNG, OGG/WAV, JSON).
- **Vanilla Ingestion (Phase 1)**: `user://vanilla_data/` is ingested directly into `ContentRegistry` under the `vanilla:*` namespace. External `ModLoader` orchestration (`user://mods/`) is deferred to Phase 2.

---

## 2. GOG Source Structure (Stardew Valley 1.6+)
- **Installation Root**: `/home/hysm/Games/Stardew Valley/`
- **Content Directory**: `/home/hysm/Games/Stardew Valley/Content/`
- **Integrity Validation**:
  - `ContentHashes.json`: Contains expected MD5/SHA hashes for all vanilla game files. Used by the importer to validate source files before processing.
- **Data & Text Dictionaries**:
  - `Content/Data/` & `Content/Strings/`: Contain game tables, item definitions, dialogue, and quests wrapped in `.xnb`.
  - **Locale Filtering**: Importer extracts base English files (`<Name>.xnb`) and filters out non-English localized suffixes (e.g., `*.de-DE.xnb`, `*.es-ES.xnb`, `*.fr-FR.xnb`, `*.it-IT.xnb`, `*.ja-JP.xnb`, `*.ko-KR.xnb`, `*.pt-BR.xnb`, `*.ru-RU.xnb`, `*.tr-TR.xnb`, `*.zh-CN.xnb`).
- **Textures & Sprites**:
  - Subdirectories: `Animals/`, `Buildings/`, `Characters/`, `LooseSprites/`, `Minigames/`, `Portraits/`, `TerrainFeatures/`, `TileSheets/`, `VolcanoLayouts/`.
  - Formatted as `.xnb` wrapping 2D pixel textures; extracted to standard `.png` format.
- **Maps (xTile)**:
  - `Content/Maps/`: Map files wrapped in `.xnb` representing xTile structure (layers, tile sheets, custom tile properties). Decoded and converted to Godot 4 `TileMapLayer` scenes/resources.
- **Audio Banks (XACT)**:
  - `Content/XACT/`: Wave banks (`Wave Bank.xwb`, `Wave Bank(1.4).xwb`), sound bank (`Sound Bank.xsb`), and settings (`FarmerSounds.xgs`). Audio streams are unpacked into standard `.wav` / `.ogg` files.

---

## 3. Mandatory Godot 4 & GDScript Standards
- **Godot Version**: Godot 4.3+ (Compatibility Renderer preferred for low-spec desktop & Android performance).
- **Strict Static Typing**: Every variable, parameter, and return type MUST be explicitly typed (e.g., `var count: int = 0`, `func get_item(id: StringName) -> ItemData:`).
- **Composition over Inheritance**: Prefer small component nodes and `Resource` subclasses over deep inheritance trees.
- **No God Objects**: Never dump game systems (farming, inventory, time) into `Player.gd` or `Main.gd`. Each system lives in its own isolated script/scene.

---

## 4. Core Architecture: Registry + EventBus

### Autoload Singletons (Phase 1)
1. `EventBus` (`res://src/core/event_bus.gd`):
   - Global typed signals for decoupled communication (`day_started`, `time_ticked`, `crop_planted`, `crop_harvested`, `item_used`).
   - Systems subscribe to signals instead of mutating other systems directly.
2. `ContentRegistry` (`res://src/core/content_registry.gd`):
   - Central dictionaries holding all registered game definitions (`items`, `crops`, `tiles`, `recipes`, `npcs`) keyed by namespaced IDs (`vanilla:parsnip`).
   - In Phase 1, loads extracted JSON/Resources directly from `user://vanilla_data/`.

### Deferred Architecture (Phase 2+)
- `ModLoader` (`res://src/core/mod_loader.gd`):
  - Scans `user://mods/`, parses `mod.json` manifests, resolves dependencies and load order, and supports overriding `vanilla:*` entries with modded data or dynamic `.pck`/`.gd` scripts.

---

## 5. Directory Layout
```text
res://
├── project.godot
├── ARCHITECTURE.md
├── STATUS.md                 # Current progress & next immediate task
├── MEMORY.md                 # Persistent architectural memory & quirks
└── src/
    ├── core/                 # Autoloads: event_bus.gd, content_registry.gd (mod_loader.gd in Phase 2)
    ├── importer/             # GOG folder scanner & XNB -> PNG/JSON/OGG extractor
    ├── resources/            # Custom Resource classes (ItemData, CropData, ToolData)
    ├── systems/              # Isolated systems (time/, farming/, inventory/, world/)
    ├── entities/             # Player, NPCs, World Objects
    └── ui/                   # HUD, Inventory UI
```
