# Project Memory Index

Anima Echo is a Godot 4.x 2D mining prototype being cleaned up into a baseline for GitHub-based AI-assisted development.

## Start Here

- [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md): detailed current project context and prototype notes.
- [architecture.md](architecture.md): stable module boundaries, scene flow, data flow, and known architecture TODOs.
- [current_tasks.md](current_tasks.md): current cleanup state, risks, and next practical tasks.
- [testing.md](testing.md): how to run the existing project checks and manual smoke tests.
- [glossary.md](glossary.md): project-specific terms.
- [specs/weight_system.md](specs/weight_system.md): tiered encumbrance (Light/Heavy/Overload) with speed and noise penalties.

## Templates

- [specs/_template.md](specs/_template.md): copy for new non-trivial feature specs.
- [decisions/_template.md](decisions/_template.md): copy for architecture or workflow decision records.
- `.github/pull_request_template.md`: default pull request checklist.
- `.github/ISSUE_TEMPLATE/feature_request.md`: default feature request issue template.

## Repository Shape

- `project.godot`: Godot project settings, autoloads, input map, and main scene route.
- `scenes/`: authored Godot scenes for the town, mine, player, enemies, covers, mines, and gems.
- `scripts/`: gameplay, runtime, economy, item, town, mine, player, enemy, and UI scripts.
- `assets/`: project art assets split into mine, town, and reusable props.
- `data/game/catalog.json`: item, loot, identification, customer, and task data.
- `tests/project/run_all.gd`: current automated regression entrypoint.
- `addons/godot_mcp/`: Godot MCP editor/runtime helper addon.

## Working Rules

- Start non-trivial features with a focused spec in `docs/specs/`.
- Keep reusable logic out of demo-only scenes when practical.
- Route inventory and currency mutations through the runtime transaction boundary.
- Avoid unnecessary `.tscn`, `.tres`, `project.godot`, and generated import file rewrites.
- Run `scripts/check.ps1` before opening a pull request when Godot CLI is available.

## TODO

- Create `.codex/session-start.md` only if future sessions need a concise repo-specific startup handoff.
- Add CI documentation after a GitHub Actions workflow exists.
