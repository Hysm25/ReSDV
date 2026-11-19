# Project Status (`docs/STATUS.md`)

## Current Phase
- **Phase 1: Clean-Room Core & Vanilla Data Pipeline**

## Completed
- [x] Project architecture & rules defined (`docs/ARCHITECTURE.md`, `AGENTS.md`, `docs/USER.md`, `docs/SOUL.md`, `docs/MEMORY.md`).
- [x] Git repository initialized with clean-room `.gitignore` & linked to GitHub remote (`git@github.com:Hysm25/ReSDV.git`).
- [x] Directory layout initialized (`src/core`, `src/importer`, `src/resources`, `src/systems`, `src/entities`, `src/ui`).
- [x] Godot project initialized (`project.godot`, `.editorconfig`, `.gitattributes`).
- [x] Documented GOG Stardew Valley 1.6+ source structure (`ContentHashes.json`, locale filtering, XNB, xTile, XACT).
- [x] Reorganized Markdown documentation into `docs/` directory with `AGENTS.md` and `README.md` at root.
- [x] Refined project scope: dropped `ModLoader` references to focus 100% on native clean-room re-implementation.
- [x] Configured `project.godot` (Compatibility renderer `gl_compatibility`, main scene `res://src/main.tscn`, registered Autoloads).
- [x] Implemented `src/core/event_bus.gd` (typed signals for time, farming, inventory, stats, and content loading).
- [x] Implemented `src/resources/item_data.gd` and `src/resources/crop_data.gd` (strict static typing, serialization/deserialization).
- [x] Implemented `src/core/content_registry.gd` (namespaced ID resolution, direct `user://vanilla_data/` ingestion, JSON parsing).
- [x] Verified headless run and unit assertions via `godot --headless --path . --quit` and test suite.
- [x] Built GOG asset & data extraction pipeline (`src/importer/`): C99 native LZX decompressor (`xnb_decompress.c`, `lzx.c`), standalone Python 3 extractor (`extract_assets.py`), and Godot trigger wrapper (`gog_importer.gd`).
- [x] Extracted vanilla assets to `user://vanilla_data/` (798 items, 50 crops, `TileSheets/crops.png`, `TileSheets/tools.png`, `Maps/springobjects.png`) with `ContentHashes.json` validation.
- [x] Verified full headless ingestion into `ContentRegistry` and passed all assertion tests (`tests/test_core.tscn`, `tests/test_importer.tscn`).
- [x] Implemented Time & Calendar system (`src/systems/time/time_manager.gd`): 10-minute in-game ticks, calendar day/season/year progression, `EventBus` signals, and debug advance keys (`F1`/`T`, `F2`).
- [x] Implemented Farm Grid & Terrain system (`src/systems/world/farm_grid.gd`): 16x16 tile grid management, soil states (untilled, tilled, watered), and selection highlighting.
- [x] Implemented Crop Lifecycle system (`src/systems/farming/crop_manager.gd`): renders vanilla crop sprites from `user://vanilla_data/TileSheets/crops.png`, manages phase progression on daily watering, and handles harvest yields.
- [x] Implemented Player controller (`src/entities/player/`): 8-directional movement, grid targeting, tool selection (Hoe, Watering Can, Parsnip Seeds, Hand), and minimal HUD (`src/ui/hud.tscn`).
- [x] Assembled playable Vertical Slice (`src/main.tscn`) and verified end-to-end integration via `tests/test_vertical_slice.tscn`.
- [x] Implemented xTile binary map extraction & Godot 4 `TileMapLayer` rendering: extended importer (`src/importer/extract_assets.py`) to unpack `Farm.xnb` (80x65) and `FarmHouse.xnb` (12x12) into JSON and tilesheet PNGs (`spring_outdoorsTileSheet.png`, `spring_outdoorsTileSheet2.png`, `paths.png`, etc.), built typed `MapLoader` (`src/systems/world/map_loader.gd`) creating `TileMapLayer` nodes per layer (`Back`, `Buildings`, `Paths`, `Front`, `AlwaysFront`, `AlwaysFront2`), generated 160 merged static collision shapes for impassable obstacles, parsed warps/actions, and integrated with `FarmGrid` diggability rules.
- [x] Implemented Location & Warp transition system between Farm and FarmHouse: built `LocationManager` (`src/systems/world/location_manager.gd`) handling seamless bidirectional transitions between `Farm` door (64, 14) and `FarmHouse` exit (3, 12)/(3, 11), emitted typed `EventBus.location_changed` signals, managed `Camera2D` bounds (1280x1040 exterior vs 192x192 interior), switched physics collisions, preserved `FarmGrid` & `CropManager` state during interior visits with ongoing crop lifecycle progression, and verified via `tests/test_warps.tscn`.
- [x] Implemented isolated Inventory & Hotbar UI system: built `InventorySlot` (`src/systems/inventory/inventory_slot.gd`) and `InventoryManager` (`src/systems/inventory/inventory_manager.gd`) decoupling item/seed/harvest tracking from Player, extended `ContentRegistry` with tool registrations (`vanilla:hoe`, `vanilla:watering_can`, `vanilla:axe`, `vanilla:pickaxe`, `vanilla:scythe`) and cached `AtlasTexture` icon extraction from `TileSheets/tools.png` and `Maps/springobjects.png`, built 12-slot bottom Hotbar UI (`src/ui/hotbar_ui.gd`, `src/ui/hotbar_slot_ui.gd`) with stack counters, golden active highlight, mouse click and wheel/number selection, and verified via `tests/test_inventory.tscn`.
- [x] Implemented XACT audio extraction pipeline & sound system: reverse-engineered `Sound Bank.xsb` (cue mapping and variation tables for 433 cues) and `Wave Bank.xwb` (437 MS-ADPCM wave tracks), built standalone pure-Python MS-ADPCM stereo decoder with zero dependencies (`extract_assets.py`) unpacking 23 gameplay SFX (`hoeHit`, `dirtyHit`, `wateringCan`, `slosh`, `coin`, `harvest`, `seeds`, `doorOpen`, `doorClose`, `axchop`, `pickUpItem`, `toolSwap`, etc.) to standard 16-bit PCM WAVs in `user://vanilla_data/audio/`, built typed `AudioManager` (`src/systems/audio/audio_manager.gd`) with custom RIFF/WAV loader, polyphonic player pool, and reactive `EventBus` connections (tilling, watering, planting, harvesting, warping, tool switching), and verified via `tests/test_audio.tscn`.
- [x] Implemented Energy & Stamina system, fatigue/exhaustion mechanics, edible food consumption, and tool usage animations: built `EnergyManager` (`src/systems/stats/energy_manager.gd`) with authentic Stardew Valley mechanics (270.0 max energy, 2.0 tool stamina cost, 0.0 scythe cost, exhaustion at <= 0.0, incapacitation at <= -15.0, overnight recovery 100% normal vs 50% exhausted, and vanilla edibility formula `edibility * 2.5`), integrated with `Player` (halved movement speed 55.0 when exhausted, eating foods from hotbar via E / RMB, and tool swing animations with lean and particle feedback), added vertical stamina bar to `HUD` (`src/ui/hud.tscn`), and verified via `tests/test_energy.tscn`.

## In Progress / Next Steps
- [ ] Implement inventory expansion / chest container storage.
- [ ] Implement NPC movement schedules and dialogue engine.
- [ ] Implement foraging / debris clearing (chopping branches, breaking rocks, cutting grass).
