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

## In Progress / Next Steps
- [ ] Configure `project.godot` rendering settings (Compatibility Renderer) and register Autoloads (`EventBus`, `ContentRegistry`).
- [ ] Implement `src/core/event_bus.gd` (typed signals).
- [ ] Implement `src/core/content_registry.gd` and base `Resource` schemas (`ItemData`, `CropData`) with direct `user://vanilla_data/` ingestion.
- [ ] Build GOG XNB asset extractor pipeline (`src/importer/`) targeting `/home/hysm/Games/Stardew Valley/` (Content validation, English locale filtering, textures, maps, and audio).
