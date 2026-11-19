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

## In Progress / Next Steps
- [ ] Build GOG XNB asset extractor pipeline (`src/importer/`) targeting `/home/hysm/Games/Stardew Valley/` (Content validation, English locale filtering, textures, maps, and audio).
- [ ] Implement foundational gameplay systems (`src/systems/time/`, `src/systems/world/`, `src/systems/farming/`).
