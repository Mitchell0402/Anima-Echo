# Visual Asset Fusion

Status: Implemented for direct-match assets
Last updated: 2026-06-28

## Goal

Wire the current generated visual asset candidates into the playable game wherever the existing project already has a safe scene, script, or UI surface for them. The purpose is to make the new art visible quickly while preserving current gameplay, scene routes, NPC interactions, collision, input, and regression coverage.

## Scope

- Use the generated `assets/ui/icons/items/*.png` files for item, warehouse, hotbar, and buyer icons.
- Use generated `assets/ui/portraits/*_neutral.png` files for default NPC dialogue portraits.
- Use generated `assets/town/npcs/*_idle.png` files for the four town NPC world sprites.
- Use generated title and intro background assets behind the current live text.
- Replace old mine pickup/node/prop visuals with generated `assets/mine/nodes/*.png` and `assets/mine/props/*.png` where the current scenes already expose equivalent Sprite2D nodes.
- Add generated town building/decor/prop/tree art as a non-colliding overlay layer in the current town scene.
- Add generated mine gate, refine station, oxygen pump, task board, button, panel, overlay, and slot art to their existing scene or UI surfaces.
- Update tests so the new loaded asset paths are checked explicitly.
- Update `docs/visual_assets/inventory.md` and `docs/current_tasks.md` to record which candidates are wired.

## Non-Goals

- Do not replace the full town background with a TileMap in this pass.
- Do not migrate mine or town tilesets/terrain atlases in this pass.
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
- `scripts/ui/warehouse_ui.gd`: generated warehouse panel, tooltip, overlay, and slot art.
- `scripts/ui/hotbar_ui.gd`: generated hotbar slot art.
- `scenes/mine/gems/*.tscn`, `scenes/mine/small_mine.tscn`, `deep_mine.tscn`, `cover.tscn`, `oxygen_pump.tscn`, `test_scene.tscn`: generated mine pickup, node, and prop art.
- `scenes/town/mining_town.tscn`, `scenes/town/mine_entrance.tscn`: generated town environment art and direct entity art.
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
- Mine gem pickup, mine node, cover, oxygen pump, mine gate, refine station, task board, and minecart return sprites use generated paths.
- Town direct-match buildings, props, decor, and trees are visible through a non-colliding `GeneratedTownLayer`.
- Dialogue, warehouse, hotbar, popup, and menu buttons use generated UI skin assets without changing interaction behavior.
- Regression tests fail before the wiring change and pass after it.
- MCP editor/runtime acceptance captures the current scene, visible title/intro/town art, and any editor errors before completion.
- `docs/visual_assets/inventory.md` records the newly wired candidates in the Placeholder table's `Used by` column.
- `docs/current_tasks.md` records this fusion as complete for direct-match assets and keeps larger TileMap migrations/context-specific UI icon work as TODOs.

## Risks

- Generated candidates are still `placeholder` status, so this pass improves visibility but does not certify final art quality.
- Scene edits can rewrite Godot resource ids if opened in the editor; use small text patches only.
- NPC sprite scale changes can affect label placement. Keep label offsets unchanged unless runtime evidence shows visible drift.
- UI panel skinning can cause layout issues if the art is used as a fixed texture instead of a stylebox. Keep UI changes conservative.
- The generated town overlay is decorative and non-colliding. It can overlap the legacy town map until a later TileMap migration replaces the map cleanly.
