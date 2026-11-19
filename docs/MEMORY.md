---
tags: [ai-context, memory]
updated: 2026-11-19
---

# Persistent Memory & Quirks (`docs/MEMORY.md`)

## 1. Project Context & Constraints
- **Clean-Room ReSDV**: Clean-room Stardew Valley re-implementation in Godot 4.3+ (strictly typed GDScript).
- **Asset Boundary**: Zero copyrighted assets in repository. Vanilla assets extracted from user-owned GOG installation into `user://vanilla_data/` and loaded directly into `ContentRegistry`.
- **GOG Game Source Details**:
  - Root: `/home/hysm/Games/Stardew Valley/` (Content path: `/home/hysm/Games/Stardew Valley/Content/`).
  - Validation: `ContentHashes.json` used for MD5/SHA validation of game files.
  - Data & Strings: `Data/` & `Strings/` dictionary XNBs. Must extract English base files and filter out localized suffixes (`*.de-DE.xnb`, `*.es-ES.xnb`, `*.fr-FR.xnb`, etc.).
  - Visuals & Maps: Texture XNBs extracted to PNG; `Maps/` xTile XNBs converted for Godot `TileMapLayer`.
  - Audio: `XACT/` wave banks (`Wave Bank.xwb`, `Wave Bank(1.4).xwb`) and sound bank (`Sound Bank.xsb`) unpacked to WAV/OGG.
- **Hardware Constraints**: 
  - Primary: CachyOS Linux on Intel Core i5-2400 (AVX-only, no AVX2). If using Bun, require `bun-baseline`.
  - Mobile: Xiaomi Redmi Note 15 5G on Termux Fedora PRoot (`aarch64`, no `systemd`).
- **Shell Convention**: Interactive terminal commands in `fish`. Standalone executable scripts in POSIX/Bash.

## 2. Architectural Decisions
- **Autoload Singletons**:
  1. `EventBus` (`res://src/core/event_bus.gd`): Typed global event dispatcher.
  2. `ContentRegistry` (`res://src/core/content_registry.gd`): Ingests `user://vanilla_data/` directly with `vanilla:*` namespace.
- **Coding Standards**: Strict static typing for all variables, params, and return types. Composition over inheritance. No God Objects.

## 3. Active Session Notes
- Project documentation reorganized into `docs/` (`docs/ARCHITECTURE.md`, `docs/STATUS.md`, `docs/MEMORY.md`, `docs/USER.md`, `docs/SOUL.md`) with `AGENTS.md` and `README.md` at root.
- Scope streamlined: 100% focused on clean-room Stardew Valley re-implementation (all `ModLoader` references removed).
- Engine foundation implemented:
  - `project.godot` configured with `gl_compatibility` renderer, `src/main.tscn` root scene, and registered `EventBus` + `ContentRegistry` autoloads.
  - `EventBus` (`res://src/core/event_bus.gd`) implemented with typed global signals.
  - `ItemData` (`res://src/resources/item_data.gd`) and `CropData` (`res://src/resources/crop_data.gd`) implemented with strict typing and serialization.
  - `ContentRegistry` (`res://src/core/content_registry.gd`) implemented with namespaced queries and direct `user://vanilla_data/` loading.
  - Headless execution and verification test suite passed.
- GOG asset and data extraction pipeline (`src/importer/`) implemented & verified:
  - C99 standalone LZX decompressor (`src/importer/lzx.c`, `src/importer/lzx.h`, `src/importer/xnb_decompress.c`) compiled with `gcc -O2` (AVX-only & ARM64 portable, zero AVX2 dependencies).
  - Standalone Python 3 pipeline (`src/importer/extract_assets.py`) validates MD5 hashes via `ContentHashes.json`, unpacks `Strings/Objects.xnb` (1,532 entries), `Data/Crops.xnb` (50 crops), `Data/Objects.xnb` (798 objects), and exports RGBA PNGs (`crops.png`, `tools.png`, `springobjects.png`) into `user://vanilla_data/`.
  - Godot wrapper `GOGImporter` (`res://src/importer/gog_importer.gd`) handles missing asset detection and automatic extraction trigger.
  - Verification test suite (`tests/test_importer.tscn`) and core headless runs passed cleanly.
- Vertical Slice gameplay loop implemented & verified:
  - `TimeManager` (`src/systems/time/time_manager.gd`): 10-minute game ticks, day/season/year progression, `EventBus` signals, debug advance keys (`F1`/`T`, `F2`).
  - `FarmGrid` (`src/systems/world/farm_grid.gd`): 16x16 tile management, soil states (untilled, tilled, watered), selection cursor.
  - `CropManager` (`src/systems/farming/crop_manager.gd`): Ingests `vanilla:472` Parsnip and all 50 crops, renders sprites from `user://vanilla_data/TileSheets/crops.png`, advances growth on overnight watering, delivers harvest yields.
  - `Player` (`src/entities/player/player.gd`): 8-directional movement, grid targeting, tool actions (Hoe, Watering Can, Parsnip Seeds, Hand).
  - `HUD` (`src/ui/hud.gd`): displays time, calendar, active tool, and harvested items.
  - All test suites passed: `tests/test_core.tscn`, `tests/test_importer.tscn`, `tests/test_vertical_slice.tscn`, and headless main scene.
- Real xTile map extraction and Godot 4 `TileMapLayer` rendering implemented & verified:
  - Extractor (`src/importer/extract_assets.py`) reverse engineered and parses xTile `tBIN10` binary format from `Maps/Farm.xnb` and `Maps/FarmHouse.xnb` into JSON with layer definitions, tile sheets, animated tiles, and tile properties (`Diggable`, `Passable`, `Warp`, `Action`).
  - Extracted referenced seasonal tilesheet textures to standard PNGs (`Maps/spring_outdoorsTileSheet.png`, `Maps/spring_outdoorsTileSheet2.png`, `Maps/spring_outdoorTileSheet_extra.png`, `Maps/paths.png`, etc.) in `user://vanilla_data/Maps/`.
  - Built typed `MapLoader` (`src/systems/world/map_loader.gd`) creating Godot 4 `TileMapLayer` nodes per layer (`Back`, `Buildings`, `Paths`, `Front`, `AlwaysFront`, `AlwaysFront2`), generating 160 merged static collision shapes for impassable obstacles on `Buildings`, parsing warps, and tracking diggable/action tiles.
  - Integrated `FarmGrid` with `MapLoader`: 80x65 grid dimension sync, procedural background disabling when real map is loaded, and diggability enforcement (`is_tile_diggable`) allowing tilling only on authentic diggable dirt (e.g. `(64, 18)`).
  - Integrated `Player` with `MapLoader`: automatic spawn at Farmhouse entrance `(64, 15)` and camera bounds clipping to farm dimensions (1280x1040).
  - Verified with test suites (`tests/test_map_loader.tscn`, `tests/test_vertical_slice.tscn`) and headless `main.tscn`.
- Location & Warp transition system implemented & verified:
  - Built typed `LocationManager` (`src/systems/world/location_manager.gd`) managing active location lifecycle, seamless map swapping, and physics collision switching.
  - Configured authentic bidirectional warps: `Farm` porch door `(64, 14)` -> `FarmHouse` interior `(3, 11)` with facing UP, and `FarmHouse` exit `(3, 12)` -> `Farm` porch `(64, 15)` with facing DOWN.
  - Integrated `Player` with `LocationManager`: automatic cell detection, movement into door detection, dynamic `Camera2D` limit clipping (1280x1040 Farm vs 192x192 FarmHouse), and tool action restriction while indoors.
  - Guaranteed `FarmGrid` & `CropManager` state persistence: soil states and planted crops remain in memory while indoors, continue advancing overnight across `EventBus.day_started`, and seamlessly re-appear upon returning outside.
  - Verified with automated test suite `tests/test_warps.tscn` and full headless engine verification.
- Next immediate task: Expand audio pipeline for XACT wave banks (`XACT/*.xwb`) and sound bank (`Sound Bank.xsb`).
