# Visual Asset Inventory

This file is the **single source of truth** for visual assets in
Anima Echo. Every PNG in the repository is listed here. Every row
in this file points at a sidecar `<name>.png.meta.md` next to the
asset on disk. A reviewer should never load an asset into the game
without first reading its sidecar.

The naming, status, and style contracts are in
[`docs/visual_assets.md`](../visual_assets.md).

## Status legend

- `implemented` — file exists, is loaded by the game, the visual
  is final, and the sidecar is complete.
- `placeholder` — file exists as a temporary stand-in, or exists to
  replace a code-drawn placeholder but is not wired yet. The sidecar
  records what is wrong or what review/wiring is still pending.
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
| `vector-source` | all future static assets | Path to the editable vector source such as `<name>.svg`. Use `missing` only for legacy raster placeholders that are waiting to be redrawn as vector. |
| `runtime-export` | all future static assets | Path to the exported runtime PNG Godot loads. |
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
   expects. UI icon source art should be 48×48 px by default; a
   specific UI may display it smaller. A 256×256 px icon will be
   sampled down. Document the scale in the PR description if it is
   not 1:1.

Any `No` answer is a blocker.

## Categories

The file paths follow the `docs/visual_assets.md#naming-convention`:

- `mine/characters/` — player sprite frames
- `mine/enemies/` — enemy sprite frames
- `mine/environment/` — tiles, decor, drop-in mineable nodes
- `town/map/` — the town background
- `town/npcs/` — NPC portrait / sprite sheets
- `props/` — interactive props (minecart, signs, ...)
- `ui/icons/` — warehouse slot icons and HUD icons

## Palettes

Each category uses one 16-colour palette. The palette is named
here and referenced by the sidecar's `palette` field.

- `mine/default` — TBD (set when the first mine asset is audited)
- `town/default` — TBD (set when the first town asset is audited)
- `ui/default` — TBD (set when the first UI icon is audited)

A future pass replaces the `TBD` with the actual colour list per
palette.

## Current Audit Snapshot

Audit date: 2026-06-26.

This pass checked the current docs, catalog, scene/script texture
references, and every `assets/**/*.png` file. It started as a
generation backlog, recorded the 2026-06-26 imagegen delivery for all
P0/P1/P2 rows, and then added the 2026-06-26 full static vector batch.
The vector batch is a first-pass placeholder art pass: SVG files are now
the editable sources, PNGs are Godot runtime exports, and every generated
PNG has a sidecar. Human art review and runtime wiring are still required
before any generated row should move to `implemented`.

Summary:

- PNGs under `assets/`: 126.
- SVG/vector sources under `assets/`: 127.
- Sidecar metadata files under `assets/`: 127.
- `assets/ui/icons/` exists and contains 17 generated 48x48 UI icons.
- Catalog items with generated UI icon files: 12 total, 4 raw geodes
  and 8 identified minerals.
- Static vector-source-first assets generated in this pass: 127 total.
- One missing texture reference exists in `scenes/mine/small_mine.tscn`:
  `res://assets/gj/environment/stones_1.png`. The likely intended file
  already exists at `res://assets/mine/environment/stones_1.png`, so this
  is a path fix, not a generation request.
- The four town NPC PNGs have sibling SVG sources and keep the existing
  town crop contract `Rect2(0, 0, 64, 64)`.
- The previous 23 imagegen assets now have sibling SVG sources and
  regenerated runtime PNG exports.
- Older static mine/town/prop PNGs now have project-internal sidecars and
  SVG sources. Player and gnoll animation sheets are deliberately excluded
  from this static vector batch and still need separate metadata.

Existing asset groups:

| Group | Count | Audit result | Notes |
|-------|-------|--------------|-------|
| `assets/mine/characters/player/*.png` | 8 | candidate keep | Player animation sheets are visually coherent and already wired through `main_char_sprite_frames.tres`; they need sidecars before they can be marked implemented. |
| `assets/mine/enemies/gnoll/*.png` | 6 | candidate keep | Gnoll animation sheets match the player scale/style and cover idle/walk/run/attack/hurt/death; sidecars still missing. |
| `assets/mine/environment/*.png` | 86 | generated placeholder | Cave tiles, crystals, stones, walls, runes, bones, greenery, decor, and `raw_anomalous_geode_pickup` were regenerated with sibling SVG sources and sidecars. Runtime scene compatibility still needs visual review. |
| `assets/props/minecart_return_to_town.png` | 1 | generated placeholder | 64x64 vector-authored minecart prop exists with sidecar and SVG source; review in the mine route before marking implemented. |
| `assets/props/oxygen_pump.png` | 1 | generated placeholder | 64x64 vector-authored oxygen pump PNG exists with sidecar and SVG source; it still needs `Sprite2D` wiring in `scenes/mine/oxygen_pump.tscn`. |
| `assets/town/map/town_map.png` | 1 | generated placeholder | Vector-authored town map export preserves the current 1672x941 runtime texture dimensions; review walkability/readability before final status. |
| `assets/town/npcs/*.png` | 4 | generated placeholder | 64x64 static NPC PNGs now have SVG sources and sidecars. These paths are loaded by the town scene but need human art review before final `implemented` status. |
| `assets/ui/icons/*.png` | 17 | generated placeholder | Catalog, warehouse, coin, oxygen, weight, and health icons now have SVG sources and sidecars. Catalog/HUD code does not load them yet. |
| `assets/ui/skin/*.png` | 18 | generated placeholder | Shared parchment/wood panels, button states, slots, bars, QTE ring, tooltip, toast, and nameplate now have SVG sources and sidecars. They are not wired into UI yet. |

Current code load-site audit:

| Use site | Asset | Result | Follow-up |
|----------|-------|--------|-----------|
| Town map | `assets/town/map/town_map.png` | generated placeholder | Sidecar and SVG source present; review world readability before final status. |
| Town miner NPC | `assets/town/npcs/npc_miner_sprites.png` | generated placeholder | 64x64 vector-authored replacement plus sidecar/SVG present; loaded by current town crop. |
| Town buyer NPC | `assets/town/npcs/npc_buyer_sprites.png` | generated placeholder | 64x64 vector-authored replacement plus sidecar/SVG present; loaded by current town crop. |
| Town identifier NPC | `assets/town/npcs/npc_identifier_sprites.png` | generated placeholder | 64x64 vector-authored replacement plus sidecar/SVG present; loaded by current town crop. |
| Town task clerk / board | `assets/town/npcs/npc_task_clerk_sprites.png` | generated placeholder | 64x64 vector-authored replacement plus sidecar/SVG present; loaded by current town crop. |
| Mine player | `assets/mine/characters/player/*.png` via `main_char_sprite_frames.tres` | usable legacy animation | Player animation sheets are intentionally excluded from the static vector batch; add sidecars in a separate animation metadata pass. |
| Mine enemy | `assets/mine/enemies/gnoll/*.png` | usable legacy animation | Gnoll animation sheets are intentionally excluded from the static vector batch; add sidecars in a separate animation metadata pass. |
| Mine pickups L1/L2/L3 | `crystal_1.png`, `crystal_6.png`, `crystal_4.png` | generated placeholder | New vector world pickup sprites exist; do not treat them as final warehouse icons. |
| Mineable node | `assets/gj/environment/stones_1.png` | broken reference | Fix to existing `assets/mine/environment/stones_1.png` or generate a new mine node and update the scene. |
| Cover | `assets/mine/environment/decor_6.png` | generated placeholder | Sidecar and SVG source present; review in cover scene. |
| Mine map / decor | `land.png`, `wall_1.png`, `wall_2.png`, `decor_19.png`, `decor_20.png`, `2D_Top_Down_Cave_Tileset.png` | generated placeholder | Sidecars and SVG sources present; TileSet compatibility still needs in-engine review. |
| Minecart exit | `assets/props/minecart_return_to_town.png` | generated placeholder | Sidecar and SVG source present; review in the mine return route. |
| Oxygen pump | `assets/props/oxygen_pump.png` | generated placeholder | Add a `Sprite2D` to `scenes/mine/oxygen_pump.tscn` if the mine scene should display this art. |
| Warehouse occupied slot | generated catalog icons in `assets/ui/icons/` | generated placeholder | Add a catalog/icon mapping or `ItemDatabase` mapping so the warehouse UI loads these files instead of code-drawn placeholders. |
| Health, oxygen, weight HUD | generated HUD icons in `assets/ui/icons/` | optional placeholder | Functional as code-drawn UI; wire these only if the UI direction wants icon labels. |

## Generated Vector Batch

The 2026-06-26 vector batch is generated by
`scripts/tools/generate_vector_assets.py`. That script is the batch
manifest for first-pass static art and emits each SVG source, PNG
runtime export, and `.png.meta.md` sidecar. Do not hand-edit generated
PNG exports without also updating the SVG source or the generator.

All rows in this section are `placeholder`: they exist on disk, have
complete sidecars, and are ready for visual review or runtime wiring,
but they are not final art.

| Group | Count | SVG sources | PNG exports | Sidecars | Notes |
|-------|-------|-------------|-------------|----------|-------|
| Mine environment | 86 | present | present | present | Includes cave tileset, land/lake, bones, crystals, decor, greenery, runes, stones, walls, and `raw_anomalous_geode_pickup`. |
| Props | 2 | present | present | present | `minecart_return_to_town` and `oxygen_pump`. |
| Town map | 1 | present | present | present | Export keeps current 1672x941 texture size. |
| Town NPC static sprites | 4 | present | present | present | Loaded by current town code but still pending human art review. |
| UI icons | 17 | present | present | present | Catalog icons plus HUD/menu symbols. Runtime icon mapping still pending. |
| UI skin | 18 | present | present | present | Panels, buttons, slots, bars, QTE ring, tooltip, toast, and nameplate. Runtime UI skin wiring still pending. |

## Implemented

No generated vector-batch asset is marked `implemented` yet. Several
placeholder assets are already loaded by existing scenes/scripts, but the
inventory keeps them as `placeholder` until a human review confirms
style, dimensions, scene readability, and intended use.

## Placeholder

This section lists generated files that exist but still need human
review, code wiring, or scene wiring before they can be marked
`implemented`.

| Path | Sidecar | Replaces | Used by | Sidecar status |
|------|----------|----------|---------|----------------|
| `assets/ui/icons/raw_common_geode.png` | `assets/ui/icons/raw_common_geode.png.meta.md` | `raw_common_geode_icon` | pending catalog/icon mapping | complete |
| `assets/ui/icons/raw_fine_geode.png` | `assets/ui/icons/raw_fine_geode.png.meta.md` | `raw_fine_geode_icon` | pending catalog/icon mapping | complete |
| `assets/ui/icons/raw_rare_geode.png` | `assets/ui/icons/raw_rare_geode.png.meta.md` | `raw_rare_geode_icon` | pending catalog/icon mapping | complete |
| `assets/ui/icons/raw_anomalous_geode.png` | `assets/ui/icons/raw_anomalous_geode.png.meta.md` | `raw_anomalous_geode_icon` | pending catalog/icon mapping | complete |
| `assets/ui/icons/copper_nugget.png` | `assets/ui/icons/copper_nugget.png.meta.md` | `copper_nugget_icon` | pending catalog/icon mapping | complete |
| `assets/ui/icons/iron_shard.png` | `assets/ui/icons/iron_shard.png.meta.md` | `iron_shard_icon` | pending catalog/icon mapping | complete |
| `assets/ui/icons/silver_vein.png` | `assets/ui/icons/silver_vein.png.meta.md` | `silver_vein_icon` | pending catalog/icon mapping | complete |
| `assets/ui/icons/gold_vein.png` | `assets/ui/icons/gold_vein.png.meta.md` | `gold_vein_icon` | pending catalog/icon mapping | complete |
| `assets/ui/icons/crystal_bloom.png` | `assets/ui/icons/crystal_bloom.png.meta.md` | `crystal_bloom_icon` | pending catalog/icon mapping | complete |
| `assets/ui/icons/moonlit_crystal.png` | `assets/ui/icons/moonlit_crystal.png.meta.md` | `moonlit_crystal_icon` | pending catalog/icon mapping | complete |
| `assets/ui/icons/star_fragment.png` | `assets/ui/icons/star_fragment.png.meta.md` | `star_fragment_icon` | pending catalog/icon mapping | complete |
| `assets/ui/icons/memory_core.png` | `assets/ui/icons/memory_core.png.meta.md` | `memory_core_icon` | pending catalog/icon mapping | complete |
| `assets/props/oxygen_pump.png` | `assets/props/oxygen_pump.png.meta.md` | `oxygen_pump` | pending `scenes/mine/oxygen_pump.tscn` sprite wiring | complete |
| `assets/mine/environment/raw_anomalous_geode_pickup.png` | `assets/mine/environment/raw_anomalous_geode_pickup.png.meta.md` | `raw_anomalous_geode_pickup` | pending deep-mine/drop-table wiring | complete |
| `assets/ui/icons/warehouse.png` | `assets/ui/icons/warehouse.png.meta.md` | `warehouse_icon` | optional UI icon wiring | complete |
| `assets/ui/icons/coin.png` | `assets/ui/icons/coin.png.meta.md` | `coin_icon` | optional UI icon wiring | complete |
| `assets/ui/icons/oxygen.png` | `assets/ui/icons/oxygen.png.meta.md` | `oxygen_icon` | optional HUD icon wiring | complete |
| `assets/ui/icons/weight.png` | `assets/ui/icons/weight.png.meta.md` | `weight_icon` | optional HUD icon wiring | complete |
| `assets/ui/icons/health.png` | `assets/ui/icons/health.png.meta.md` | `health_icon` | optional HUD icon wiring | complete |

## Todo

No static-art generation rows are open after the 2026-06-26 vector batch.
Remaining work is review, integration, and animation metadata:

- Review the 127 generated placeholder assets in-engine and promote only
  approved rows to `implemented`.
- Wire the 12 generated catalog item icons into the warehouse/hotbar UI.
- Add the generated oxygen pump sprite to `scenes/mine/oxygen_pump.tscn`.
- Decide whether the P2 HUD/menu icons should be loaded by the current UI.
- Apply the generated UI skin assets to warehouse, NPC popups, hotbar,
  HUD bars, toast, tooltip, and QTE.
- Add sidecars for the legacy player and gnoll animation sheets, which
  are intentionally excluded from the static vector batch.

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
