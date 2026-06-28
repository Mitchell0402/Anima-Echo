# Visual Asset Inventory

This file is the **single source of truth** for visual assets in
Anima Echo. Every PNG in the repository is listed here. Every row
in this file points at a sidecar `<name>.png.meta.md` next to the
asset on disk. A reviewer should never load an asset into the game
without first reading its sidecar.

The naming, status, and style contracts are in
[`docs/visual_assets.md`](../visual_assets.md).

Default generation source: `imagegen` raster PNG. SVG/vector art and
manual geometric drawings are not accepted as committed game visuals
unless a task explicitly requests that exception.

## Status legend

- `implemented` — file exists, is loaded by the game, the visual
  is final, and the sidecar is complete.
- `placeholder` — file exists and is loaded, but is a temporary
  stand-in that should be replaced. The sidecar records what is
  wrong.
- `todo` — file does not exist yet. The row is the AI's work order.
  A sidecar is recommended for non-trivial assets so the AI
  generator has the brief up front.
- `obsolete` — file is no longer used by the game but is kept in
  the repository for reference. The sidecar records the retirement
  rationale.

## Metadata sidecar schema

Every `implemented` and `placeholder` row has a sidecar next to the
PNG. The required fields are:

| Field | Required for | Notes |
|-------|---------------|-------|
| `id` | all | Stable name. Must match the row. |
| `category` | all | `mine` / `town` / `props` / `ui`. |
| `sub-category` | all | e.g. `characters` / `icons` / `npcs`. |
| `source` | all | `authored-original` / `ai-generated:<model>` / `asset-library:<src>`. |
| `license` | all | `CC0` / `CC-BY-4.0` / `CC-BY-SA-4.0` / `CC-BY-NC-4.0` / `CC-BY-NC-SA-4.0` / `project-internal` / `TBD`. `TBD` is rejected by reviewers. |
| `status` | all | Must match this row. |
| `width`, `height` | all | Pixel dimensions of the source PNG. |
| `palette` | all | Name of the 16-colour palette (defined per category in this file). |
| `description` | all | One paragraph: what the asset depicts and where the game uses it. |
| `style-notes` | all | Anything an AI regenerator needs: line weight, perspective, animation timing, shadow policy, etc. |
| `created-by` | all | Author name or AI prompt slug. |
| `last-reviewed-by` | all | Dev who last verified the sidecar matches the file. |
| `last-reviewed-on` | all | ISO date of that review. |
| `audit-on` | `implemented`, `obsolete` | Date the asset was last audited against the style guide. |
| `replacement` | `placeholder`, `obsolete` | Name of the asset (if any) that replaces this one. |

A sidecar missing any required field is incomplete. A reviewer
should reject the commit and ask the author to fill the field in.

## Sidecar naming

The sidecar lives in the same directory as the asset and uses the
asset's relative path with `.meta.md` appended:

- `assets/mine/characters/player/Sword_Walk_with_shadow.png`
- `assets/mine/characters/player/Sword_Walk_with_shadow.png.meta.md`

So the sidecar for the same file is the file name with
`.png.meta.md` replacing `.png`.

## Review checklist (before loading an asset)

A reviewer — and the author of any change that adds a new
`load()` / `preload()` for a visual asset — must walk this list
before the code change merges:

1. **Inventory row exists** for the file path, with the right
   status.
2. **Sidecar exists** at `<file>.png.meta.md` next to the asset.
3. **All required fields** in the sidecar are filled. In
   particular `license` is not `TBD` and `status` matches the
   inventory row.
4. **`palette`** in the sidecar matches the category's palette in
   this file.
5. **`source`** indicates where the asset came from. If it is
   `ai-generated:<model>`, the sidecar records the exact prompt
   in `style-notes`.
6. **`last-reviewed-on`** is within the last 90 days. If the asset
   is older, the reviewer runs the audit workflow below before
   merging the code change.
7. **The intended use in the new code** matches `description` and
   `style-notes`. A button icon is not a world sprite. A
   placeholder is not a final asset.
8. **The asset's resolution** matches the import scale the code
   expects. The warehouse UI assumes 32×32 px icons; a 256×256 px
   icon will be sampled down. Document the scale in the PR
   description if it is not 1:1.

Any `No` answer is a blocker.

## Categories

The file paths follow the `docs/visual_assets.md#naming-convention`:

- `mine/characters/` — player sprite frames
- `mine/enemies/` — enemy sprite frames
- `mine/environment/` — tiles, decor, drop-in mineable nodes
- `town/map/` — the town background
- `props/` — interactive props and NPC sprites (task board, minecart, signs, NPC portraits)
- `ui/icons/` — warehouse slot icons and HUD icons

## Palettes

Each category uses one 16-colour palette. The palette is named
here and referenced by the sidecar's `palette` field.

- `mine/default` — TBD (set when the first mine asset is audited)
- `town/default` — TBD (set when the first town asset is audited)
- `ui/default` — TBD (set when the first UI icon is audited)

A future pass replaces the `TBD` with the actual colour list per
palette.

## Implemented

This section is filled in by the audit workflow (see the appendix
at the bottom). A future pass lists every file currently on disk in
`assets/` and either keeps it, downgrades it, or retires it.

| Path | Sidecar | Palette | Status | Used by | Last reviewed |
|------|----------|---------|--------|---------|---------------|
| `assets/props/task_board.png` | `task_board.png.meta.md` | `props-palette` | `implemented` | `scenes/town/mining_town.tscn` (TaskBoard/Sprite2D texture) | 2026-06-27 |

## Placeholder

This section lists files that exist as generated candidates or loaded temporary stand-ins. The sidecar describes what is wrong or why the file is not wired yet. Generated candidates stay here until a later implementation pass reviews and loads them.

| Path | Sidecar | Replaces | Used by | Sidecar status |
|------|----------|----------|---------|----------------|
| `assets/mine/nodes/gem_pickup_common.png` | `gem_pickup_common.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/mine/nodes/gem_pickup_fine.png` | `gem_pickup_fine.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/mine/nodes/gem_pickup_rare.png` | `gem_pickup_rare.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/mine/nodes/gem_pickup_star.png` | `gem_pickup_star.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/mine/nodes/mine_wall_common.png` | `mine_wall_common.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/mine/nodes/mine_wall_deep.png` | `mine_wall_deep.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/mine/props/cover_crate.png` | `cover_crate.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/mine/props/minecart_return.png` | `minecart_return.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/mine/props/oxygen_pump.png` | `oxygen_pump.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/mine/tiles/deep_cave_tileset.png` | `deep_cave_tileset.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/mine/tiles/land.png` | `land.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/mine/tiles/mid_cave_tileset.png` | `mid_cave_tileset.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/mine/tiles/shallow_cave_tileset.png` | `shallow_cave_tileset.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/town/buildings/blacksmith.png` | `blacksmith.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/town/buildings/buyer_shop.png` | `buyer_shop.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/town/buildings/elder_house.png` | `elder_house.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/town/buildings/florist.png` | `florist.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/town/buildings/mine_gate.png` | `mine_gate.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/town/buildings/refine_station.png` | `refine_station.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/town/buildings/warehouse.png` | `warehouse.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/town/decor/bush_round.png` | `bush_round.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/town/decor/flower_patch_blue.png` | `flower_patch_blue.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/town/decor/flower_patch_red.png` | `flower_patch_red.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/town/decor/grass_clump_a.png` | `grass_clump_a.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/town/decor/grass_clump_b.png` | `grass_clump_b.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/town/npcs/blacksmith_idle.png` | `blacksmith_idle.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/town/npcs/buyer_idle.png` | `buyer_idle.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/town/npcs/elder_idle.png` | `elder_idle.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/town/npcs/florist_idle.png` | `florist_idle.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/town/props/barrel.png` | `barrel.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/town/props/bench.png` | `bench.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/town/props/crate_stack.png` | `crate_stack.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/town/props/fence_horizontal.png` | `fence_horizontal.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/town/props/fence_vertical.png` | `fence_vertical.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/town/props/lantern_post.png` | `lantern_post.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/town/props/minecart_town.png` | `minecart_town.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/town/props/notice_sign.png` | `notice_sign.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/town/props/task_board.png` | `task_board.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/town/props/well.png` | `well.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/town/tiles/dirt_path_center.png` | `dirt_path_center.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/town/tiles/dirt_path_corner_ne.png` | `dirt_path_corner_ne.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/town/tiles/dirt_path_corner_nw.png` | `dirt_path_corner_nw.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/town/tiles/dirt_path_corner_se.png` | `dirt_path_corner_se.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/town/tiles/dirt_path_corner_sw.png` | `dirt_path_corner_sw.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/town/tiles/dirt_path_edge_e.png` | `dirt_path_edge_e.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/town/tiles/dirt_path_edge_n.png` | `dirt_path_edge_n.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/town/tiles/dirt_path_edge_s.png` | `dirt_path_edge_s.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/town/tiles/dirt_path_edge_w.png` | `dirt_path_edge_w.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/town/tiles/grass_a.png` | `grass_a.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/town/tiles/grass_b.png` | `grass_b.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/town/tiles/plaza_stone_a.png` | `plaza_stone_a.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/town/tiles/plaza_stone_b.png` | `plaza_stone_b.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/town/tiles/shadow_soft.png` | `shadow_soft.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/town/tiles/water_center.png` | `water_center.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/town/tiles/water_edge.png` | `water_edge.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/town/trees/oak_large.png` | `oak_large.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/town/trees/oak_small.png` | `oak_small.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/town/trees/pine_large.png` | `pine_large.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/town/trees/pine_small.png` | `pine_small.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/town/trees/stump.png` | `stump.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/ui/buttons/button_disabled.png` | `button_disabled.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/ui/buttons/button_hover.png` | `button_hover.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/ui/buttons/button_normal.png` | `button_normal.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/ui/icons/coin.png` | `coin.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/ui/icons/day.png` | `day.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/ui/icons/dialogue_next.png` | `dialogue_next.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/ui/icons/equipment/backpack_basic.png` | `backpack_basic.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/ui/icons/equipment/pickaxe_basic.png` | `pickaxe_basic.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/ui/icons/equipment/slot_empty.png` | `slot_empty.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/ui/icons/health.png` | `health.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/ui/icons/items/copper_nugget.png` | `copper_nugget.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/ui/icons/items/crystal_bloom.png` | `crystal_bloom.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/ui/icons/items/gold_vein.png` | `gold_vein.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/ui/icons/items/iron_shard.png` | `iron_shard.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/ui/icons/items/memory_core.png` | `memory_core.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/ui/icons/items/moonlit_crystal.png` | `moonlit_crystal.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/ui/icons/items/raw_common_geode.png` | `raw_common_geode.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/ui/icons/items/raw_fine_geode.png` | `raw_fine_geode.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/ui/icons/items/raw_rare_geode.png` | `raw_rare_geode.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/ui/icons/items/raw_star_geode.png` | `raw_star_geode.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/ui/icons/items/refined_badge.png` | `refined_badge.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/ui/icons/items/silver_vein.png` | `silver_vein.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/ui/icons/items/star_crystal.png` | `star_crystal.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/ui/icons/items/star_fragment.png` | `star_fragment.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/ui/icons/night.png` | `night.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/ui/icons/oxygen.png` | `oxygen.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/ui/icons/stability.png` | `stability.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/ui/icons/task.png` | `task.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/ui/icons/warehouse.png` | `warehouse.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/ui/icons/weight.png` | `weight.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/ui/overlays/dim_overlay.png` | `dim_overlay.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/ui/panels/dialogue_bottom.png` | `dialogue_bottom.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/ui/panels/popup_medium.png` | `popup_medium.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/ui/panels/toast.png` | `toast.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/ui/panels/tooltip.png` | `tooltip.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/ui/panels/warehouse_panel.png` | `warehouse_panel.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/ui/portraits/blacksmith_concerned.png` | `blacksmith_concerned.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/ui/portraits/blacksmith_neutral.png` | `blacksmith_neutral.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/ui/portraits/buyer_concerned.png` | `buyer_concerned.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/ui/portraits/buyer_neutral.png` | `buyer_neutral.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/ui/portraits/elder_concerned.png` | `elder_concerned.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/ui/portraits/elder_neutral.png` | `elder_neutral.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/ui/portraits/florist_concerned.png` | `florist_concerned.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/ui/portraits/florist_neutral.png` | `florist_neutral.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/ui/screens/intro_background.png` | `intro_background.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/ui/screens/settings_panel.png` | `settings_panel.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/ui/screens/title_background.png` | `title_background.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/ui/slots/slot_disabled.png` | `slot_disabled.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/ui/slots/slot_empty.png` | `slot_empty.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |
| `assets/ui/slots/slot_filled.png` | `slot_filled.png.meta.md` | _none; generated candidate_ | _not wired yet_ | `placeholder` |

## Todo (planned, not yet drawn)

This section is the AI's work order. Every row here corresponds to
a row in the future `Placeholders` section once the asset is drawn.

The current full batch-generation plan lives in
[`docs/specs/visual_asset_audit_generation_plan.md`](../specs/visual_asset_audit_generation_plan.md).

| Name | Category | Sub-category | Description | Target path | Style notes | Priority |
|------|----------|--------------|-------------|-------------|--------------|----------|
| _example_ | `ui` | `icons` | 32×32 px gold-brown rounded pebble | `assets/ui/icons/raw_common_geode.png` | transparent background, no shadow, palette `ui/default` | P1 |

## Obsolete

| Path | Sidecar | Replaced by | Retirement rationale |
|------|----------|-------------|---------------------|
| _none yet_ | | | |

## Appendix: keeping the inventory in sync

Until the inventory is auto-generated, the dev updates this file by
hand. The pattern is:

1. Run `find assets -type f -name "*.png"` to see every committed
   asset.
2. Run `find assets -type f -name "*.png.meta.md"` to see every
   sidecar.
3. Run `grep -rn "load.*\.png\|preload.*\.png" scripts/ tests/
   scenes/` to see every load site.
4. Run the review checklist above for every load site.
5. Diff the three lists against the tables in this file:
   - Files in `assets/` but not in any table → audit, grade, add
     with a sidecar.
   - Files in `assets/` that have a `placeholder` sidecar that is
     empty → fill the sidecar in.
   - Loads with no file → add a `todo` row.
   - Table rows whose file no longer exists → flip to `obsolete`
     and move to the obsolete section.
6. Commit the doc in the same change as any code or asset change.

The script form of this is a follow-up TODO recorded in
`docs/current_tasks.md`.
