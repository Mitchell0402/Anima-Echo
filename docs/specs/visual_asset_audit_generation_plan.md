# Visual Asset Audit And Generation Plan

Last updated: 2026-06-28

## Goal

Rebuild the visual asset pipeline after the recent feature expansion. The project now needs a complete asset audit, a full batch-generation work order, and a stricter source rule: unless a task explicitly says otherwise, all new or replacement visual assets must be high-quality raster assets generated with `imagegen`. Do not use vector-drawn SVGs, hand-drawn geometric placeholder art, or code-drawn final art for game visuals.

This is a planning document only. It does not generate or wire new art yet.

## Scope

- Audit every current `assets/**/*.png`.
- Identify which existing assets need metadata, replacement, retirement, or continued use.
- List all currently needed batch-generated assets, including UI, dialogue, warehouse, shop, task, refine, HUD, title, intro, town, mine, NPC, item, and prop art.
- Define the town-map replacement plan: replace the single flat town map with a TileMap-built town using generated terrain tiles plus independent tree, decoration, building, and prop sprites.
- Update the asset rules so future agents treat `imagegen` raster generation as the default.

## Non-Goals

- Do not generate images in this step.
- Do not modify `.tscn`, `.tres`, `project.godot`, or gameplay scripts in this step.
- Do not delete existing assets until replacements exist and scenes are migrated.
- Do not rework gameplay, economy, NPC dialogue, or UI behavior.
- Do not generate player or enemy animation replacements. Player and enemy
  animation art is owner-created by hand later; this plan only audits the
  existing files and records sidecar metadata for them.
- Do not generate art for systems, screens, or states that are not currently
  present in the playable game. Future-facing assets such as good/evil-specific
  morality icons, ending screens, and end-statistics screens stay deferred until
  the feature that uses them is implemented.

## Current Audit Facts

### File Counts

Current PNG count under `assets/`: 128.

Current metadata sidecar count under `assets/`: 1.

Only audited sidecar today:

- `assets/props/task_board.png.meta.md`

Current PNGs by folder:

| Folder | PNG count | Audit state |
|--------|-----------|-------------|
| `assets/mine/characters/player` | 8 | Needs sidecars and style review. |
| `assets/mine/enemies/gnoll` | 6 | Needs sidecars and style review. |
| `assets/mine/environment` | 84 | Needs sidecars, atlas review, and likely split/rename cleanup. |
| `assets/props` | 25 | Needs sidecars; many are new alpha item/NPC assets. |
| `assets/town/map` | 1 | Must be replaced by TileMap terrain plus independent props/buildings. |
| `assets/town/npcs` | 4 | Legacy duplicate NPC sprites; likely obsolete after audit because current scenes use `assets/props/*_alpha.png`. |

### Current Loaded Asset Surface

Current code and scenes reference visual assets from these places:

- `data/narrative/dialogues.json`: NPC portrait paths for elder, blacksmith, florist, buyer.
- `scripts/items/item_database.gd`: warehouse/hotbar/item icons for raw geodes and identified minerals.
- `scenes/town/mining_town.tscn`: town map and task board.
- `scenes/town/npc_*.tscn`: NPC sprites.
- `scenes/town/town_player.tscn`: player sprite frames.
- `scenes/mine/test_scene.tscn`: cave terrain, decor, walls, minecart.
- `scenes/mine/small_mine.tscn`, `cover.tscn`, `gems/*.tscn`: mineable node, cover, geode pickup sprites.
- `scenes/mine/enemy.tscn`: gnoll enemy frames.
- `scenes/ui/title_menu.tscn`, `intro.tscn`: UI scenes whose visuals are currently mostly code-driven colors and text.
- `scripts/ui/*.gd`, `scripts/narrative/dialogue_ui.gd`, `scripts/town/mining_town_scene.gd`: runtime-created panels, HUD, dialogue, warehouse, task, shop, refine, toast, and title controls.

Important issue found during audit: `scenes/mine/deep_mine.tscn` references `res://assets/gj/environment/stones_1.png`, but the current normalized asset root shown by the file audit does not include `assets/gj`. Treat this as a migration risk in the implementation phase and verify whether the scene is active before wiring new art.

## Source And Style Rule

### Required Default

All new and replacement visual assets must be generated as raster PNGs with `imagegen`, unless the user explicitly asks for another source. `imagegen` output should be treated as authored art input, then reviewed, cropped, scaled, imported, and documented through sidecars.

### Disallowed By Default

- SVG/vector art as committed game visuals.
- Manually drawn vector illustrations.
- Code-drawn final UI panels, icons, sprites, or map decorations.
- Flat `ColorRect` or primitive-shape placeholders as final assets.

Existing code-created panels can remain temporarily while generated UI skins are produced, but the generation plan below assumes they will be replaced with PNG panel textures, icons, and backgrounds.

### Required Metadata

Every generated or kept PNG needs `<asset>.png.meta.md` next to it with:

- `id`
- `category`
- `sub-category`
- `source`
- `license`
- `status`
- `width`
- `height`
- `palette`
- `description`
- `style-notes`
- `created-by`
- `last-reviewed-by`
- `last-reviewed-on`
- `audit-on` for implemented or obsolete assets
- `replacement` for placeholder or obsolete assets

Use `source: imagegen:<model-or-session>` for generated art. Do not use `license: TBD`.

## Audit Disposition Plan

### Keep And Document

These may be kept if visual review passes, but each needs a sidecar:

- Player frames in `assets/mine/characters/player`.
- Gnoll frames in `assets/mine/enemies/gnoll`.
- Usable mine environment tiles/decor in `assets/mine/environment`.
- `assets/props/task_board.png` because it already has a sidecar and is scene-loaded.

### Replace

These should be regenerated even if they currently work, because the new art direction requires coherent imagegen raster assets and better UI/world separation:

- `assets/town/map/town_map.png`: replace with TileMap terrain plus independent props/buildings.
- All `assets/props/*_alpha.png` item icons currently used by warehouse/hotbar/item database.
- NPC portrait/sprite alpha assets under `assets/props/`.
- HUD icons and code-colored bars that are currently visible in game: health,
  oxygen, weight, stability, day/night, task, warehouse, and coin. Defer
  good/evil-specific morality icon variants until that UI state is actively
  used.
- Warehouse, dialogue, shop, task board, refine, title, settings, toast, and tooltip UI panels.

### Likely Obsolete

Mark obsolete after confirming no live load remains:

- `assets/town/npcs/npc_buyer_sprites.png`
- `assets/town/npcs/npc_identifier_sprites.png`
- `assets/town/npcs/npc_miner_sprites.png`
- `assets/town/npcs/npc_task_clerk_sprites.png`

These appear to be replaced by `assets/props/*_alpha.png` in current scenes and dialogue data.

## Batch Generation Work Order

Use the following batches in order. Each batch should produce PNG files plus sidecar `.png.meta.md` files before code or scene wiring begins.

### Active-Generation Boundary

For the first production pass, generate only assets that replace or support
currently playable UI, town, mine, NPC, warehouse, shop, task, refine, title,
intro, item, mineral, and prop surfaces. If a system is only planned, only partly
designed, or not yet visible in the game, leave its art out of the batch. This
keeps the imagegen workload focused on art that can be reviewed against current
screens instead of speculative future UI.

Explicitly deferred:

- Player and enemy animation sprite sheets. Existing player and gnoll PNGs
  still need audit rows and sidecars, but replacement animation is hand-made
  later and must not be generated by imagegen.
- Good/evil-specific UI variants that do not have an active visible surface yet.
- Future ending, boss, and end-statistics screens.
- Any other art whose only consumer is a planned feature rather than current
  code, current scenes, or current data.

### Batch 1: UI Foundations

Target folder: `assets/ui/`

| Asset id | Target path | Size | Used by |
|----------|-------------|------|---------|
| `ui_panel_dialogue_bottom` | `assets/ui/panels/dialogue_bottom.png` | 960x180 9-slice source | `DialogueUI` bottom dialogue box |
| `ui_panel_popup_medium` | `assets/ui/panels/popup_medium.png` | 420x280 9-slice source | NPC popup, shop, task, refine panels |
| `ui_panel_warehouse` | `assets/ui/panels/warehouse_panel.png` | 480x560 9-slice source | Warehouse overlay |
| `ui_slot_empty` | `assets/ui/slots/slot_empty.png` | 64x64 | Warehouse empty slot |
| `ui_slot_filled` | `assets/ui/slots/slot_filled.png` | 64x64 | Warehouse filled slot |
| `ui_slot_disabled` | `assets/ui/slots/slot_disabled.png` | 64x64 | Unavailable sell/task/shop slots |
| `ui_button_normal` | `assets/ui/buttons/button_normal.png` | 200x44 9-slice source | Title/menu/popup buttons |
| `ui_button_hover` | `assets/ui/buttons/button_hover.png` | 200x44 9-slice source | Hover state |
| `ui_button_disabled` | `assets/ui/buttons/button_disabled.png` | 200x44 9-slice source | Disabled state |
| `ui_tooltip` | `assets/ui/panels/tooltip.png` | 320x120 9-slice source | Warehouse tooltip |
| `ui_toast` | `assets/ui/panels/toast.png` | 420x64 9-slice source | Town toast messages |
| `ui_overlay_dim` | `assets/ui/overlays/dim_overlay.png` | 32x32 tileable | Modal dim overlay |

### Batch 2: HUD And Status Icons

Target folder: `assets/ui/icons/`

| Asset id | Target path | Size | Used by |
|----------|-------------|------|---------|
| `icon_coin` | `assets/ui/icons/coin.png` | 32x32 | Wallet, shop, sell results |
| `icon_health` | `assets/ui/icons/health.png` | 32x32 | Health bar |
| `icon_oxygen` | `assets/ui/icons/oxygen.png` | 32x32 | Oxygen bar |
| `icon_weight` | `assets/ui/icons/weight.png` | 32x32 | Weight bar |
| `icon_stability` | `assets/ui/icons/stability.png` | 32x32 | Town stability |
| `icon_day` | `assets/ui/icons/day.png` | 32x32 | Day counter |
| `icon_night` | `assets/ui/icons/night.png` | 32x32 | Night state |
| `icon_task` | `assets/ui/icons/task.png` | 32x32 | Task panel |
| `icon_warehouse` | `assets/ui/icons/warehouse.png` | 32x32 | Warehouse label/button |
| `icon_dialogue_next` | `assets/ui/icons/dialogue_next.png` | 24x24 | Dialogue next hint |

Deferred from this batch: good/evil-specific morality icons. Generate them only
after the visible morality UI is finalized.

### Batch 3: Item, Mineral, And Equipment Icons

Target folder: `assets/ui/icons/items/`

Every catalog item currently needs a clean inventory icon. Existing `assets/props/*_alpha.png` files can be used as visual references, but the generated target should live under UI icons so world props and UI icons do not share the same files.

| Asset id | Target path | Size | Notes |
|----------|-------------|------|-------|
| `item_raw_common_geode` | `assets/ui/icons/items/raw_common_geode.png` | 48x48 | Raw tier 1 geode |
| `item_raw_fine_geode` | `assets/ui/icons/items/raw_fine_geode.png` | 48x48 | Raw tier 2 geode |
| `item_raw_rare_geode` | `assets/ui/icons/items/raw_rare_geode.png` | 48x48 | Raw tier 3 geode |
| `item_raw_star_geode` | `assets/ui/icons/items/raw_star_geode.png` | 48x48 | Raw anomalous/star geode |
| `item_copper_nugget` | `assets/ui/icons/items/copper_nugget.png` | 48x48 | Identified mineral |
| `item_iron_shard` | `assets/ui/icons/items/iron_shard.png` | 48x48 | Identified mineral |
| `item_silver_vein` | `assets/ui/icons/items/silver_vein.png` | 48x48 | Identified mineral |
| `item_gold_vein` | `assets/ui/icons/items/gold_vein.png` | 48x48 | Identified mineral |
| `item_crystal_bloom` | `assets/ui/icons/items/crystal_bloom.png` | 48x48 | Identified mineral |
| `item_moonlit_crystal` | `assets/ui/icons/items/moonlit_crystal.png` | 48x48 | Identified mineral |
| `item_star_fragment` | `assets/ui/icons/items/star_fragment.png` | 48x48 | Sensitive mineral |
| `item_memory_core` | `assets/ui/icons/items/memory_core.png` | 48x48 | Sensitive mineral |
| `item_star_crystal` | `assets/ui/icons/items/star_crystal.png` | 48x48 | Key moral item |
| `item_refined_badge` | `assets/ui/icons/items/refined_badge.png` | 24x24 | Overlay marker for refined minerals |
| `equipment_pickaxe_basic` | `assets/ui/icons/equipment/pickaxe_basic.png` | 48x48 | Equipment shop |
| `equipment_backpack_basic` | `assets/ui/icons/equipment/backpack_basic.png` | 48x48 | Equipment shop |
| `equipment_slot_empty` | `assets/ui/icons/equipment/slot_empty.png` | 48x48 | Equipment UI slot |

Deferred from this batch: good/evil talisman icons and any other path-specific
equipment art whose UI state is not currently visible.

### Batch 4: Dialogue And NPC Portraits

Target folders:

- `assets/town/npcs/`
- `assets/ui/portraits/`

Each NPC needs a world sprite and a portrait. Do not reuse portrait art as a world sprite.

| Asset id | Target path | Size | Used by |
|----------|-------------|------|---------|
| `npc_elder_idle` | `assets/town/npcs/elder_idle.png` | 64x64 | Elder world sprite |
| `npc_blacksmith_idle` | `assets/town/npcs/blacksmith_idle.png` | 64x64 | Blacksmith world sprite |
| `npc_florist_idle` | `assets/town/npcs/florist_idle.png` | 64x64 | Florist world sprite |
| `npc_buyer_idle` | `assets/town/npcs/buyer_idle.png` | 64x64 | Buyer world sprite |
| `portrait_elder_neutral` | `assets/ui/portraits/elder_neutral.png` | 128x128 | Dialogue portrait |
| `portrait_blacksmith_neutral` | `assets/ui/portraits/blacksmith_neutral.png` | 128x128 | Dialogue portrait |
| `portrait_florist_neutral` | `assets/ui/portraits/florist_neutral.png` | 128x128 | Dialogue portrait |
| `portrait_buyer_neutral` | `assets/ui/portraits/buyer_neutral.png` | 128x128 | Dialogue portrait |
| `portrait_elder_concerned` | `assets/ui/portraits/elder_concerned.png` | 128x128 | Later-stage dialogue |
| `portrait_blacksmith_concerned` | `assets/ui/portraits/blacksmith_concerned.png` | 128x128 | Later-stage dialogue |
| `portrait_florist_concerned` | `assets/ui/portraits/florist_concerned.png` | 128x128 | Later-stage dialogue |
| `portrait_buyer_concerned` | `assets/ui/portraits/buyer_concerned.png` | 128x128 | Later-stage dialogue |

### Batch 5: Town TileMap Terrain

Target folder: `assets/town/tiles/`

The current `assets/town/map/town_map.png` must be replaced by a TileMap composition. The final town scene should use terrain tiles for ground and independent sprites for buildings, trees, and decorations.

| Asset id | Target path | Size | Notes |
|----------|-------------|------|-------|
| `town_tile_grass_a` | `assets/town/tiles/grass_a.png` | 32x32 | Base grass |
| `town_tile_grass_b` | `assets/town/tiles/grass_b.png` | 32x32 | Grass variation |
| `town_tile_dirt_path_center` | `assets/town/tiles/dirt_path_center.png` | 32x32 | Main path |
| `town_tile_dirt_path_edge_n` | `assets/town/tiles/dirt_path_edge_n.png` | 32x32 | Path edge |
| `town_tile_dirt_path_edge_s` | `assets/town/tiles/dirt_path_edge_s.png` | 32x32 | Path edge |
| `town_tile_dirt_path_edge_e` | `assets/town/tiles/dirt_path_edge_e.png` | 32x32 | Path edge |
| `town_tile_dirt_path_edge_w` | `assets/town/tiles/dirt_path_edge_w.png` | 32x32 | Path edge |
| `town_tile_dirt_path_corner_ne` | `assets/town/tiles/dirt_path_corner_ne.png` | 32x32 | Path corner |
| `town_tile_dirt_path_corner_nw` | `assets/town/tiles/dirt_path_corner_nw.png` | 32x32 | Path corner |
| `town_tile_dirt_path_corner_se` | `assets/town/tiles/dirt_path_corner_se.png` | 32x32 | Path corner |
| `town_tile_dirt_path_corner_sw` | `assets/town/tiles/dirt_path_corner_sw.png` | 32x32 | Path corner |
| `town_tile_plaza_stone_a` | `assets/town/tiles/plaza_stone_a.png` | 32x32 | Around task board / shops |
| `town_tile_plaza_stone_b` | `assets/town/tiles/plaza_stone_b.png` | 32x32 | Variation |
| `town_tile_water_center` | `assets/town/tiles/water_center.png` | 32x32 | Optional pond/stream |
| `town_tile_water_edge` | `assets/town/tiles/water_edge.png` | 32x32 | Optional pond/stream edge |
| `town_tile_shadow_soft` | `assets/town/tiles/shadow_soft.png` | 32x32 | Under buildings/trees if needed |

### Batch 6: Independent Town Buildings

Target folder: `assets/town/buildings/`

Buildings must be independent sprites placed on top of the TileMap, not painted into the terrain.

| Asset id | Target path | Size | Used by |
|----------|-------------|------|---------|
| `building_blacksmith` | `assets/town/buildings/blacksmith.png` | 192x160 | Blacksmith area |
| `building_florist` | `assets/town/buildings/florist.png` | 160x144 | Florist area |
| `building_buyer_shop` | `assets/town/buildings/buyer_shop.png` | 176x144 | Buyer/shop area |
| `building_elder_house` | `assets/town/buildings/elder_house.png` | 176x144 | Elder area |
| `building_warehouse` | `assets/town/buildings/warehouse.png` | 176x144 | Warehouse access fantasy, even if UI opens by key |
| `building_mine_gate` | `assets/town/buildings/mine_gate.png` | 192x160 | Mine entrance |
| `building_refine_station` | `assets/town/buildings/refine_station.png` | 96x96 | Refining interactable |

### Batch 7: Independent Town Trees And Decorations

Target folders:

- `assets/town/trees/`
- `assets/town/decor/`
- `assets/town/props/`

Trees, decorations, and props must be independent sprites so the town can be rearranged without regenerating the map.

| Asset id | Target path | Size | Notes |
|----------|-------------|------|-------|
| `tree_oak_small` | `assets/town/trees/oak_small.png` | 64x96 | Independent tree |
| `tree_oak_large` | `assets/town/trees/oak_large.png` | 96x128 | Independent tree |
| `tree_pine_small` | `assets/town/trees/pine_small.png` | 64x96 | Independent tree |
| `tree_pine_large` | `assets/town/trees/pine_large.png` | 96x128 | Independent tree |
| `tree_stump` | `assets/town/trees/stump.png` | 48x40 | Decoration |
| `decor_bush_round` | `assets/town/decor/bush_round.png` | 48x40 | Decoration |
| `decor_flower_patch_red` | `assets/town/decor/flower_patch_red.png` | 48x32 | Decoration |
| `decor_flower_patch_blue` | `assets/town/decor/flower_patch_blue.png` | 48x32 | Decoration |
| `decor_grass_clump_a` | `assets/town/decor/grass_clump_a.png` | 32x32 | Decoration |
| `decor_grass_clump_b` | `assets/town/decor/grass_clump_b.png` | 32x32 | Decoration |
| `prop_task_board` | `assets/town/props/task_board.png` | 48x48 | May replace/move current `assets/props/task_board.png` |
| `prop_notice_sign` | `assets/town/props/notice_sign.png` | 48x48 | Town hint/sign |
| `prop_lantern_post` | `assets/town/props/lantern_post.png` | 32x64 | Night atmosphere |
| `prop_bench` | `assets/town/props/bench.png` | 64x40 | Decoration |
| `prop_crate_stack` | `assets/town/props/crate_stack.png` | 64x48 | Market/warehouse decor |
| `prop_barrel` | `assets/town/props/barrel.png` | 32x48 | Market/warehouse decor |
| `prop_well` | `assets/town/props/well.png` | 80x80 | Town landmark |
| `prop_fence_horizontal` | `assets/town/props/fence_horizontal.png` | 64x32 | Layout boundary |
| `prop_fence_vertical` | `assets/town/props/fence_vertical.png` | 32x64 | Layout boundary |
| `prop_minecart_town` | `assets/town/props/minecart_town.png` | 80x64 | Mine route prop |

### Batch 8: Mine World Refresh

Target folders:

- `assets/mine/tiles/`
- `assets/mine/props/`
- `assets/mine/nodes/`

The existing mine environment contains many loose PNGs. Audit first; then regenerate a coherent set only for actively loaded mine surfaces.

| Asset id | Target path | Size | Used by |
|----------|-------------|------|---------|
| `mine_tileset_shallow` | `assets/mine/tiles/shallow_cave_tileset.png` | 512x512 atlas | Level 1 shallow mine TileMap: warmer brown stone, ordinary support beams, sparse crystals |
| `mine_tileset_mid` | `assets/mine/tiles/mid_cave_tileset.png` | 512x512 atlas | Level 2 mid-depth mine TileMap: darker slate, damp floor, denser mineral veins, faint blue-purple glow |
| `mine_tileset_deep` | `assets/mine/tiles/deep_cave_tileset.png` | 512x512 atlas | Level 3 deep mine TileMap: near-black rock, ancient ruins, star-crystal veins, oppressive teal/violet glow |
| `mine_tile_land` | `assets/mine/tiles/land.png` | 32x32 | Current scene background |
| `mine_wall_common` | `assets/mine/nodes/mine_wall_common.png` | 64x64 | `small_mine.tscn` |
| `mine_wall_deep` | `assets/mine/nodes/mine_wall_deep.png` | 64x64 | Deep mine |
| `mine_cover_crate` | `assets/mine/props/cover_crate.png` | 64x64 | Cover scene |
| `minecart_return` | `assets/mine/props/minecart_return.png` | 80x64 | Mine exit |
| `oxygen_pump` | `assets/mine/props/oxygen_pump.png` | 64x64 | Oxygen pump interactable |
| `gem_pickup_common` | `assets/mine/nodes/gem_pickup_common.png` | 48x48 | Common geode pickup |
| `gem_pickup_fine` | `assets/mine/nodes/gem_pickup_fine.png` | 48x48 | Fine geode pickup |
| `gem_pickup_rare` | `assets/mine/nodes/gem_pickup_rare.png` | 48x48 | Rare geode pickup |
| `gem_pickup_star` | `assets/mine/nodes/gem_pickup_star.png` | 48x48 | Star geode pickup |

### Deferred: Characters And Enemies

Do not generate player or enemy animation replacements with imagegen. The player
and enemy animation set will be created manually later so frame timing, pose
continuity, silhouettes, and attack readability can be controlled by hand.

For this plan, the character/enemy work is audit-only:

- Review existing player frames in `assets/mine/characters/player/`.
- Review existing gnoll frames in `assets/mine/enemies/gnoll/`.
- Add complete sidecar metadata and inventory rows for the existing files.
- Mark individual frames as `implemented` or `placeholder` based on the audit,
  but do not add imagegen replacement rows for player or enemy animation sheets.

### Batch 9: Title And Intro Screens

Target folder: `assets/ui/screens/`

| Asset id | Target path | Size | Used by |
|----------|-------------|------|---------|
| `screen_title_background` | `assets/ui/screens/title_background.png` | 1280x720 | Title menu background |
| `screen_intro_background` | `assets/ui/screens/intro_background.png` | 1280x720 | Intro narration backdrop |
| `screen_settings_panel` | `assets/ui/screens/settings_panel.png` | 640x420 | Settings popup |

Deferred from this batch: good, bad, neutral, boss, and statistics ending
screens. Generate these only after the ending flow exists in the playable game.

## Prompt Template For Imagegen Batches

Every batch prompt should include the same base style:

```text
Create high-quality 2D pixel-art raster PNG assets for Anima Echo, a top-down soft fantasy mining town game. Transparent background unless the asset is a full-screen screen/background. Crisp pixel edges, no vector art, no SVG style, no flat geometric placeholder look. Use a restrained coherent palette with warm town lights, cool mine shadows, subtle magical crystal accents, and readable silhouettes at game scale. Output each asset as an individual PNG with clean alpha, centered composition, and no text baked into the art unless the asset is explicitly a sign or title background.
```

For UI batches, add:

```text
UI assets should feel like polished pixel-game interface art: carved wood, worn brass, dark slate stone, parchment labels, and soft shadowed edges. Leave room for live Godot text. Do not bake English or Chinese text into panels/buttons.
```

For town TileMap batches, add:

```text
Town assets must be modular. Generate terrain tiles, buildings, trees, and props separately. Do not paint trees, houses, or decorations into a single map. Keep tile edges seamless for 32x32 TileMap assembly.
```

## Implementation Plan After Generation

1. Create missing folders under `assets/ui`, `assets/town`, and `assets/mine`.
2. Add generated PNG files and sidecars.
3. Update `docs/visual_assets/inventory.md` with every generated file.
4. Import assets in Godot and verify `.import` files are stable.
5. Migrate `ItemDatabase` to load item icons from `assets/ui/icons/items/`.
6. Replace code-created UI panels with `TextureRect`/theme-backed generated panel art where practical.
7. Replace `assets/town/map/town_map.png` with a TileMap scene layer.
8. Place independent town buildings, trees, decorations, NPCs, task board, refine station, warehouse marker, and mine route props.
9. Re-run `scripts/check.ps1`.
10. Manually smoke-test title, intro, town, warehouse, dialogue, shop, task board, refine picker, mine entry/exit, hotbar, and item icons.

## Acceptance Criteria For The Later Implementation

- `docs/visual_assets/inventory.md` lists every PNG in `assets/`.
- Every implemented or placeholder PNG has a complete `.png.meta.md` sidecar.
- No loaded visual asset has `license: TBD`.
- Current UI surfaces use generated raster assets rather than primitive-only panels wherever a visible skin is expected.
- Warehouse and item database icons use `assets/ui/icons/items/*`.
- No generated batch includes player/enemy animation replacements or art for
  future-only screens and states that are not currently visible in the game.
- Town scene no longer depends on a single full-map background PNG.
- Town terrain is TileMap-driven.
- Trees, decorations, buildings, and major props are independent sprites.
- Existing world interactions still work: NPC talk, task board, warehouse, refine station, mine entry, mine return.
- `scripts/check.ps1` passes, or failures are documented with exact failing test names and logs.

## Known Risks

- The asset count is high enough that sidecar and inventory maintenance can drift unless updated in the same commits as generated art.
- The town TileMap migration will touch scene layout and collision/navigation. It should be a separate implementation task after art generation.
- `project.godot` should not be rewritten. Any asset import or project setting change must be targeted.
- UI panels generated as fixed PNGs need 9-slice setup or careful scaling to avoid blurry or stretched edges.
- Future-only asset ideas can creep back into batch prompts unless each prompt
  is checked against the active-generation boundary above.
- The current `WarehouseUI` comment says a 3x4 grid, while architecture/current tasks mention a 48-slot warehouse. The visual plan should not lock in a final grid layout until the implementation verifies the intended current UI behavior.
- `scenes/mine/deep_mine.tscn` may reference a missing legacy path. Verify before replacing deep-mine visuals.

## Appendix A: Current PNG Inventory Snapshot

This is the current full `assets/**/*.png` snapshot from the audit pass. The next implementation should transfer these rows into `docs/visual_assets/inventory.md` with final statuses and sidecar links.

### Mine Player

- `assets/mine/characters/player/Sword_attack_with_shadow.png`
- `assets/mine/characters/player/Sword_Death_with_shadow.png`
- `assets/mine/characters/player/Sword_Hurt_with_shadow.png`
- `assets/mine/characters/player/Sword_Idle_with_shadow.png`
- `assets/mine/characters/player/Sword_Run_Attack_with_shadow.png`
- `assets/mine/characters/player/Sword_Run_with_shadow.png`
- `assets/mine/characters/player/Sword_Walk_Attack_with_shadow.png`
- `assets/mine/characters/player/Sword_Walk_with_shadow.png`

### Mine Enemy

- `assets/mine/enemies/gnoll/Gnoll_Death_with_shadow.png`
- `assets/mine/enemies/gnoll/Gnoll1_Attack_with_shadow.png`
- `assets/mine/enemies/gnoll/Gnoll1_Hurt_with_shadow.png`
- `assets/mine/enemies/gnoll/Gnoll1_Idle_with_shadow.png`
- `assets/mine/enemies/gnoll/Gnoll1_Run_with_shadow.png`
- `assets/mine/enemies/gnoll/Gnoll1_Walk_with_shadow.png`

### Mine Environment

- `assets/mine/environment/2D_Top_Down_Cave_Tileset.png`
- `assets/mine/environment/bone_1.png`
- `assets/mine/environment/bone_10.png`
- `assets/mine/environment/bone_2.png`
- `assets/mine/environment/bone_3.png`
- `assets/mine/environment/bone_4.png`
- `assets/mine/environment/bone_5.png`
- `assets/mine/environment/bone_6.png`
- `assets/mine/environment/bone_7.png`
- `assets/mine/environment/bone_8.png`
- `assets/mine/environment/bone_9.png`
- `assets/mine/environment/crystal_1.png`
- `assets/mine/environment/crystal_10.png`
- `assets/mine/environment/crystal_2.png`
- `assets/mine/environment/crystal_3.png`
- `assets/mine/environment/crystal_4.png`
- `assets/mine/environment/crystal_5.png`
- `assets/mine/environment/crystal_6.png`
- `assets/mine/environment/crystal_7.png`
- `assets/mine/environment/crystal_8.png`
- `assets/mine/environment/crystal_9.png`
- `assets/mine/environment/decor_1.png`
- `assets/mine/environment/decor_10.png`
- `assets/mine/environment/decor_11.png`
- `assets/mine/environment/decor_12.png`
- `assets/mine/environment/decor_13.png`
- `assets/mine/environment/decor_14.png`
- `assets/mine/environment/decor_15.png`
- `assets/mine/environment/decor_16.png`
- `assets/mine/environment/decor_17.png`
- `assets/mine/environment/decor_18.png`
- `assets/mine/environment/decor_19.png`
- `assets/mine/environment/decor_2.png`
- `assets/mine/environment/decor_20.png`
- `assets/mine/environment/decor_3.png`
- `assets/mine/environment/decor_4.png`
- `assets/mine/environment/decor_5.png`
- `assets/mine/environment/decor_6.png`
- `assets/mine/environment/decor_7.png`
- `assets/mine/environment/decor_8.png`
- `assets/mine/environment/decor_9.png`
- `assets/mine/environment/greenery_1.png`
- `assets/mine/environment/greenery_10.png`
- `assets/mine/environment/greenery_2.png`
- `assets/mine/environment/greenery_3.png`
- `assets/mine/environment/greenery_4.png`
- `assets/mine/environment/greenery_5.png`
- `assets/mine/environment/greenery_6.png`
- `assets/mine/environment/greenery_7.png`
- `assets/mine/environment/greenery_8.png`
- `assets/mine/environment/greenery_9.png`
- `assets/mine/environment/lake.png`
- `assets/mine/environment/land.png`
- `assets/mine/environment/rune_1.png`
- `assets/mine/environment/rune_2.png`
- `assets/mine/environment/rune_3.png`
- `assets/mine/environment/rune_4.png`
- `assets/mine/environment/rune_5.png`
- `assets/mine/environment/rune_6.png`
- `assets/mine/environment/rune_7.png`
- `assets/mine/environment/stones_1.png`
- `assets/mine/environment/stones_10.png`
- `assets/mine/environment/stones_2.png`
- `assets/mine/environment/stones_3.png`
- `assets/mine/environment/stones_4.png`
- `assets/mine/environment/stones_5.png`
- `assets/mine/environment/stones_6.png`
- `assets/mine/environment/stones_7.png`
- `assets/mine/environment/stones_8.png`
- `assets/mine/environment/stones_9.png`
- `assets/mine/environment/wall_1.png`
- `assets/mine/environment/wall_10.png`
- `assets/mine/environment/wall_11.png`
- `assets/mine/environment/wall_12.png`
- `assets/mine/environment/wall_13.png`
- `assets/mine/environment/wall_14.png`
- `assets/mine/environment/wall_2.png`
- `assets/mine/environment/wall_3.png`
- `assets/mine/environment/wall_4.png`
- `assets/mine/environment/wall_5.png`
- `assets/mine/environment/wall_6.png`
- `assets/mine/environment/wall_7.png`
- `assets/mine/environment/wall_8.png`
- `assets/mine/environment/wall_9.png`

### Props And Item-Like Art

- `assets/props/coin_alpha.png`
- `assets/props/copper_nugget_alpha.png`
- `assets/props/crystal_bloom_alpha.png`
- `assets/props/gold_vein_alpha.png`
- `assets/props/health_alpha.png`
- `assets/props/iron_shard_alpha.png`
- `assets/props/memory_core_alpha.png`
- `assets/props/minecart_return_to_town.png`
- `assets/props/moonlit_crystal_alpha.png`
- `assets/props/npc_buyer_sprites_alpha.png`
- `assets/props/npc_identifier_sprites_alpha.png`
- `assets/props/npc_miner_alpha.png`
- `assets/props/npc_task_clerk_sprites_alpha.png`
- `assets/props/oxygen_alpha.png`
- `assets/props/oxygen_pump_alpha.png`
- `assets/props/raw_anomalous_geode_alpha.png`
- `assets/props/raw_anomalous_geode_pickup_alpha.png`
- `assets/props/raw_common_geode_alpha.png`
- `assets/props/raw_fine_geode_alpha.png`
- `assets/props/raw_rare_geode_alpha.png`
- `assets/props/silver_vein_alpha.png`
- `assets/props/star_fragment_alpha.png`
- `assets/props/task_board.png`
- `assets/props/warehouse_alpha.png`
- `assets/props/weight_alpha.png`

### Town

- `assets/town/map/town_map.png`
- `assets/town/npcs/npc_buyer_sprites.png`
- `assets/town/npcs/npc_identifier_sprites.png`
- `assets/town/npcs/npc_miner_sprites.png`
- `assets/town/npcs/npc_task_clerk_sprites.png`
