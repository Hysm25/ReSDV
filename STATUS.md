# Project Status (`STATUS.md`)

## Current Phase
- **Phase 1: Core Engine & Modding Foundation**

## Completed
- [x] Project architecture & rules defined (`ARCHITECTURE.md`, `AGENTS.md`, `USER.md`, `SOUL.md`).
- [x] Git repository initialized with clean-room `.gitignore` & linked to GitHub remote (`git@github.com:Hysm25/ReSDV.git`).
- [x] Directory layout initialized (`src/core`, `src/importer`, `src/resources`, `src/systems`, `src/entities`, `src/ui`).
- [x] Godot project initialized (`project.godot`, `.editorconfig`, `.gitattributes`).

## In Progress / Next Steps
- [ ] Configure `project.godot` rendering settings (Compatibility Renderer) and register Autoloads.
- [ ] Implement `src/core/event_bus.gd`.
- [ ] Implement `src/core/content_registry.gd` and base `Resource` schemas (`ItemData`, `CropData`).
- [ ] Implement `src/core/mod_loader.gd` to parse `mod.json` from `user://vanilla_data/` and `user://mods/`.
- [ ] Build GOG XNB asset extractor pipeline (`src/importer/`).
