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
- Isolated Inventory & Hotbar UI system implemented & verified:
  - Built `InventorySlot` (`src/systems/inventory/inventory_slot.gd`) and `InventoryManager` (`src/systems/inventory/inventory_manager.gd`) handling slot storage, item stacking, addition/removal, and active slot selection.
  - Decoupled `Player` from manual inventory tracking, delegating tool and seed actions to `InventoryManager` while maintaining backward-compatible fallbacks.
  - Extended `ContentRegistry` with default tool definitions (`vanilla:hoe`, `vanilla:watering_can`, `vanilla:axe`, `vanilla:pickaxe`, `vanilla:scythe`) and cached `AtlasTexture` icon generation from extracted `TileSheets/tools.png` and `Maps/springobjects.png`.
  - Built 12-slot bottom Hotbar HUD (`src/ui/hotbar_ui.gd`, `src/ui/hotbar_slot_ui.gd`) rendering real item icons, stack counts, golden selection highlight, number shortcuts (1-9, 0, -, =), and mouse wheel/click slot switching.
  - Verified with automated test suite `tests/test_inventory.tscn` and full engine test suite.
- XACT Audio Extraction Pipeline & Sound System implemented & verified:
  - Reverse-engineered `Sound Bank.xsb` (cue mapping and variation tables for 433 cues) and `Wave Bank.xwb` (437 MS-ADPCM wave tracks).
  - Built standalone pure-Python MS-ADPCM stereo decoder with zero dependencies (`src/importer/extract_assets.py`) unpacking 23 gameplay SFX (`hoeHit`, `dirtyHit`, `wateringCan`, `slosh`, `coin`, `harvest`, `seeds`, `doorOpen`, `doorClose`, `axchop`, `pickUpItem`, `toolSwap`, `grassyStep`, `stoneStep`, `woodyStep`, `thudStep`, `cut`, `hammer`, `openBox`, `boulderBreak`, etc.) into standard 16-bit PCM WAVs in `user://vanilla_data/audio/`.
  - Built typed `AudioManager` (`src/systems/audio/audio_manager.gd`) with custom RIFF/WAV loader, polyphonic player pool (8 players), and reactive `EventBus` connections for tilling (`hoeHit`), watering (`wateringCan`), planting (`dirtyHit`), harvesting (`coin`), warping (`doorOpen` / `doorClose`), and tool switching (`toolSwap`).
  - Integrated `AudioManager` into `src/main.tscn` and verified via automated test suite `tests/test_audio.tscn` and full regression test suite.
- Energy & Stamina System, Fatigue/Exhaustion States, and Tool Animations implemented & verified:
  - Built `EnergyManager` (`src/systems/stats/energy_manager.gd`) handling authentic stamina mechanics: 270.0 max energy, 2.0 cost per tool swing (0.0 for scythe), exhaustion trigger at `<= 0.0`, incapacitation trigger at `<= -15.0`, overnight recovery (100% when normal, 50% when exhausted), and food consumption utilizing vanilla formula (`energy = edibility * 2.5`, `health = energy * 0.45`).
  - Integrated with `Player` (`src/entities/player/player.gd`): halved movement speed (110.0 -> 55.0) when exhausted, tool usage animation lock (0.22s) with directional lean, swinging tool rendering via `ContentRegistry.get_item_icon`, swing swoosh arcs, particle effects, sweat drops when exhausted, and edible item consumption via `E` key or right-click.
  - Extended `HUD` (`src/ui/hud.tscn`, `src/ui/hud.gd`) with vertical stamina bar showing current/max energy, dynamic color gradients (green -> yellow -> orange -> red), and "TIRED!" exhaustion status indicator.
  - Verified with automated test suite `tests/test_energy.tscn` and full regression test suite.
- Inventory Expansion (Backpack Upgrades) & Chest Container Storage implemented & verified:
  - Extended `InventoryManager` (`src/systems/inventory/inventory_manager.gd`) with backpack capacity upgrading (12 -> 24 -> 36 slots), hotbar slot selection clamping to 12 slots, and cyclic hotbar row rotation via `Tab` key.
  - Extended extractor pipeline (`src/importer/extract_assets.py`) to extract `TileSheets/Craftables.png` (128x1472), and updated `ContentRegistry` to load BigCraftables icons and register default `vanilla:chest` item (BigCraftable 130).
  - Built `ItemContainer` (`src/systems/inventory/item_container.gd`) data model with 36 slots, organization sorting, slot swapping, and serialization (`to_dict` / `from_dict`).
  - Built physical `Chest` world entity (`src/entities/objects/chest.gd`) with collision shape, authentic closed/open sprite frames (130 / 135) from `Craftables.png`, and tool shake effect when occupied.
  - Built `ChestManager` (`src/systems/world/chest_manager.gd`) managing chest lifecycle, cross-location visibility and collision persistence (`Farm` vs `FarmHouse`), obstacle validation, and axe/pickaxe pickup of empty chests.
  - Built full modal `ChestUI` (`src/ui/chest_ui.tscn`, `src/ui/container_slot_ui.gd`) rendering 36 container slots alongside player inventory, supporting full stack transfers (left click) and single item transfers (right click), organize sorting, and `Esc` / `E` dismiss.
  - Connected `AudioManager` to play authentic SFX: `openBox` when opening, `doorClose` when closing, `woodyStep` when placed, and `axchop` when picked up.
  - Verified with automated test suite `tests/test_chest.tscn` and full engine regression test suite.
- NPC Movement Schedules & Dialogue Engine implemented & verified:
  - Built `DialogueEngine` (`src/systems/dialogue/dialogue_engine.gd`) loading vanilla NPC dialogue dictionaries (`Robin.json`, `Lewis.json`), substituting tokens (`@`, `%farm`), parsing emotion tags (`$h`, `$s`, `$u`), and separating multi-page dialogues.
  - Built `ScheduleEngine` (`src/systems/dialogue/schedule_engine.gd`) parsing authentic time-indexed schedule entries, converting SDV directions, and evaluating active waypoints per game clock tick.
  - Built `NPC` entity (`src/entities/npc/npc.gd`) loading 64x320/64x256 character sprites and 128x256/128x192 portrait textures, with 4-directional animated walk cycles, tile navigation, and player interaction.
  - Built `NPCManager` (`src/systems/npc/npc_manager.gd`) coordinating NPC schedules on time ticks, handling cross-location visibility/collisions, and managing player conversations.
  - Built `DialogueBoxUI` modal (`src/ui/dialogue_box_ui.tscn`, `src/ui/dialogue_box_ui.gd`) rendering 64x64 cropped emotion portraits, villager nameplate, wrapped dialogue text, and page advance triggers.
  - Verified with automated test suite `tests/test_npc.tscn` and full engine regression test suite.
- Foraging & Debris Clearing system implemented & verified:
  - Extended importer pipeline (`src/importer/extract_assets.py`) to unpack `TerrainFeatures/grass.xnb` into `user://vanilla_data/TerrainFeatures/grass.png` (66x240) and added `ContentRegistry.get_grass_texture()`.
  - Built `DebrisObject` (`src/entities/objects/debris_object.gd`) supporting Twigs (294, 295), Stones (32, 34, 343), Weeds (0, 313, 314, 315), Wild Grass (4 seasonal tuft variations), and Spring Forageables (Wild Horseradish `vanilla:16`, Daffodil `vanilla:18`, Leek `vanilla:20`, Dandelion `vanilla:22`) with authentic sprite atlas rendering, directional tool shake feedback, and physical obstacle collision (`StaticBody2D` + `CollisionShape2D`).
  - Built `DebrisManager` (`src/systems/world/debris_manager.gd`) coordinating tool interaction checks (Axe -> Wood `vanilla:388` + `axchop`, Pickaxe -> Stone `vanilla:390` + `hammer`, Scythe -> Fiber `vanilla:771` / Hay `vanilla:178` + `cut`), stamina deduction (2.0 for tools, 0.0 for scythe/hand), ineffective tool deflection, forage pickup (`pickUpItem`), starter debris generator (`spawn_initial_farm_debris`), and cross-location persistence across `Farm` <-> `FarmHouse`.
  - Integrated with `Player` (`src/entities/player/player.gd`) and `FarmGrid` (`src/systems/world/farm_grid.gd`) enforcing that untilled dirt cannot be tilled if occupied by debris.
  - Fixed visual-to-logical coordinate alignment: anchored `DebrisObject` positioning to tile top-left `Vector2(cell) * 16.0` with `Sprite2D` centered at `Vector2(8, 8)` (`centered = true`, `offset = Vector2.ZERO`, `z_index = 2`) and matching centered `CollisionShape2D` (16x16 box at `Vector2(8, 8)`), ensuring `FarmGrid` highlight cells and player tool swings strictly target the rendered visual bounds.
  - Verified with automated test suite `tests/test_debris.tscn` and full engine regression test suite.
- Next immediate task: Implement fishing minigame and water body interactions. (Fallback: `~/.ai-context/MEMORY.md`)
