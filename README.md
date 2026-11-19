# ReSDV

> **Clean-Room Re-implementation of *Stardew Valley*** in **Godot 4.x (GDScript)**.

A clean-room, open-source engine runtime that runs *Stardew Valley* natively by importing assets and data from a user-owned GOG installation (v1.6+).

---

## Legal & Asset Boundary
This repository contains **engine code only**. No copyrighted sprites, audio, maps, dialogues, or `.xnb` files are included. On setup/launch, assets are extracted directly from the user's legal installation into `user://vanilla_data/` and loaded by the engine runtime.

---

## Documentation
- [AGENTS.md](AGENTS.md): Global agent execution blueprint and `fish` shell build templates.
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md): Technical architecture, GOG 1.6+ content layout, and autoload singletons.
- [docs/STATUS.md](docs/STATUS.md): Roadmap, completed milestones, and immediate next steps.
- [docs/MEMORY.md](docs/MEMORY.md): Persistent memory, hardware invariants (AVX-only / Termux PRoot), and active session state.
- [docs/USER.md](docs/USER.md): User environment, hardware specifications, and stack preferences.
- [docs/SOUL.md](docs/SOUL.md): Persona directives, output standards, and execution safety rules.
