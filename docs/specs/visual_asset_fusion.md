# Visual Asset Fusion

Status: In progress
Last updated: 2026-06-28

## Goal

Wire the current generated visual asset candidates into the playable game in a small, reversible first pass. The purpose is to make the new art visible quickly while preserving current gameplay, scene routes, NPC interactions, and regression coverage.

## Scope

- Use the generated `assets/ui/icons/items/*.png` files for item, warehouse, hotbar, and buyer icons.
- Use generated `assets/ui/portraits/*_neutral.png` files for default NPC dialogue portraits.
- Use generated `assets/town/npcs/*_idle.png` files for the four town NPC world sprites.
- Use generated title and intro background assets behind the current live text.
- Add light UI skinning only where it is low risk and does not change interaction behavior.
- Update tests so the new loaded asset paths are checked explicitly.
- Update `docs/visual_assets/inventory.md` and `docs/current_tasks.md` to record which candidates are wired.

## Non-Goals

- Do not replace the full town background with a TileMap in this pass.
- Do not migrate mine tilesets or terrain atlases in this pass.
- Do not regenerate assets.
- Do not mark generated candidates as final `implemented` art unless a later visual review approves them.
- Do not edit `project.godot`.
- Do not change gameplay, economy, dialogue progression, collision, input maps, camera logic, or save/load behavior.

## Relevant Files

- `scripts/items/item_database.gd`: central icon source for hotbar, warehouse, buyer, and item lookups.
- `data/narrative/dialogues.json`: default portrait paths for each NPC.
- `scripts/town/mining_town_scene.gd`: special florist tears dialogue portrait path.
- `scenes/town/npc_elder.tscn`, `npc_blacksmith.tscn`, `npc_florist.tscn`, `npc_buyer.tscn`: NPC world sprite textures and scale.
- `scripts/ui/title_menu.gd`: title background and button visuals.
- `scripts/ui/intro.gd`: intro background behind narration text.
- `scripts/narrative/dialogue_ui.gd`: generated dialogue panel background.
- `scripts/ui/warehouse_ui.gd`: generated warehouse panel and slot art if time allows.
- `tests/project/run_all.gd`: regression checks for wired generated assets.
- `docs/visual_assets/inventory.md`: asset source of truth.
- `docs/current_tasks.md`: task-state update.

## Acceptance Criteria

- ItemDatabase no longer preloads item icons from `assets/props/*_alpha.png`.
- Raw geodes and identified minerals resolve to `assets/ui/icons/items/*.png` textures.
- Dialogue JSON default portraits point to `assets/ui/portraits/*_neutral.png`.
- The florist first-star gift dialogue uses the generated florist portrait.
- Town NPC scenes point to generated `assets/town/npcs/*_idle.png` sprites and use a scale appropriate for 64x64 sprites.
- Title and intro screens load generated backgrounds while preserving existing live text and scene transitions.
- Regression tests fail before the wiring change and pass after it.
- MCP editor/runtime acceptance captures the current scene, visible title/intro/town art, and any editor errors before completion.
- `docs/visual_assets/inventory.md` records the newly wired candidates in the Placeholder table's `Used by` column.
- `docs/current_tasks.md` records this first-pass fusion as complete and keeps larger TileMap/mine migrations as TODOs.

## Risks

- Generated candidates are still `placeholder` status, so this pass improves visibility but does not certify final art quality.
- Scene edits can rewrite Godot resource ids if opened in the editor; use small text patches only.
- NPC sprite scale changes can affect label placement. Keep label offsets unchanged unless runtime evidence shows visible drift.
- UI panel skinning can cause layout issues if the art is used as a fixed texture instead of a stylebox. Keep UI changes conservative.
