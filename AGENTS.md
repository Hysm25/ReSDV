# Global Execution Blueprint (`AGENTS.md`)

> **Purpose**: Global operational blueprint and execution rules for AI agents across all workspaces.

---

## 1. Context Injections
- **User Profile & Environment**: @[USER](~/.ai-context/USER.md)
- **Assistant Persona & Guardrails**: @[SOUL](~/.ai-context/SOUL.md)
- **Persistent Memory & Quirks**: @[MEMORY](~/.ai-context/MEMORY.md)

---

## 2. Universal Build & Run Templates (`fish` Shell)
> All interactive commands must be formatted for the `fish` shell.

```fish
# JavaScript / TypeScript (Bun - use bun-baseline on Sandy Bridge):
bun install
bun run dev
bun test

# Python (uv):
uv sync
# or: uv venv; source .venv/bin/activate.fish; uv pip install -r requirements.txt

# Rust:
cargo fetch
cargo run
cargo test

# Godot 4 (CLI / Headless check):
godot --headless --path . --quit
godot --path .
