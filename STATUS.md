# Project Status (`STATUS.md`)

## Current Phase
- **Phase 1: Clean-Room Core & Vanilla Data Pipeline** (External `ModLoader` deferred to Phase 2)

## Completed
- [x] Project architecture & rules defined (`ARCHITECTURE.md`, `AGENTS.md`, `USER.md`, `SOUL.md`).
- [x] Git repository initialized with clean-room `.gitignore` & linked to GitHub remote (`git@github.com:Hysm25/ReSDV.git`).
- [x] Directory layout initialized (`src/core`, `src/importer`, `src/resources`, `src/systems`, `src/entities`, `src/ui`).
- [x] Godot project initialized (`project.godot`, `.editorconfig`, `.gitattributes`).
- [x] Documented GOG Stardew Valley 1.6+ source structure (`ContentHashes.json`, locale filtering, XNB, xTile, XACT) and scope adjustments.

## In Progress / Next Steps
- [ ] Configure `project.godot` rendering settings (Compatibility Renderer) and register Phase 1 Autoloads (`EventBus`, `ContentRegistry`).
- [ ] Implement `src/core/event_bus.gd` (typed signals).
- [ ] Implement `src/core/content_registry.gd` and base `Resource` schemas (`ItemData`, `CropData`) with direct `user://vanilla_data/` ingestion.
- [ ] Build GOG XNB asset extractor pipeline (`src/importer/`) targeting `/home/hysm/Games/Stardew Valley/` (Content validation, English locale filtering, textures, maps, and audio).
- [ ] *(Deferred - Phase 2)* Implement external `ModLoader` (`user://mods/`, `mod.json` manifests, script mods).
