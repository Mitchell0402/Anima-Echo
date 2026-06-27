# Visual Asset Inventory

This file is the single source of truth for visual asset status in Anima
Echo. The naming, metadata, and review rules are defined in
[`docs/visual_assets.md`](../visual_assets.md).

## Status Legend

- `implemented` - exists, is loaded by runtime, and has complete sidecar
  metadata.
- `development` - exists under `assets/development/`, has SVG/PNG/meta, and
  is ready for art review or future integration, but is not loaded by runtime.
- `placeholder` - exists and is loaded, but is a temporary stand-in.
- `todo` - does not exist yet; the row is a work order.
- `obsolete` - no longer used, retained for reference.

## Metadata Sidecar Schema

Required fields for every `implemented`, `development`, and `placeholder`
PNG:

| Field | Required for | Notes |
|-------|--------------|-------|
| `id` | all | Stable name. Must match the manifest or inventory row. |
| `category` | all | Runtime category or `development`. |
| `sub-category` | all | Directory/use group, such as `ui/icons` or `mine/environment`. |
| `source` | all | Origin of the asset. |
| `vector-source` | all static art | Path to the canonical SVG/vector source. |
| `runtime-export` | all static art | Path to the exported PNG. For `development`, this is a review export, not a loaded runtime path. |
| `license` | all | Must not be `TBD`. |
| `status` | all | Must match this inventory. |
| `width`, `height` | all | PNG dimensions. |
| `palette` | all | Palette family below. |
| `description` | all | What the asset depicts. |
| `intended-use` | all | Where this asset is meant to be used after review. |
| `style-notes` | all | Style constraints, references, and generation notes. |
| `created-by` | all | Author or generator. |
| `last-reviewed-by` | all | Reviewer or generator author who checked the sidecar. |
| `last-reviewed-on` | all | ISO date. |
| `audit-on` | `implemented`, `obsolete` | Last runtime style audit date. |
| `replacement` | `placeholder`, `obsolete` | Replacement id/path when known. |

## Palettes

- `development/mine` - dark stone, moss green, bone, cyan crystal, and warm
  highlight palette for mine environment and props.
- `development/town` - warm grass, wood, path, roof, water, and light trim
  palette for town map/NPC development art.
- `development/ui` - parchment, wood, brass, muted green, slate, and cream
  palette for icons and UI skin.
- `mine/default`, `town/default`, `ui/default` - legacy runtime palettes.
  These remain to be audited separately.

## Planned Development Library

> **All assets in this section are `todo` — they have not been generated
> yet.** The 127 assets below were previously generated and committed but
> were lost in a revert. The design, groupings, palettes, and asset names
> are preserved here as the work order for re-generation. No files exist
> under `assets/development/` at this time.

When the generation script is (re)created, the expected outputs are:

- SVG vector sources under `assets/development/`.
- PNG alpha exports.
- Metadata sidecars (`<name>.png.meta.md`).
- `assets/development/manifest.json` _(not yet created)_.
- Contact sheets under `tmp/development_asset_contact_sheets/`.

The planned generation script is
`scripts/tools/generate_development_assets.py` _(not yet created)_.

### Summary

| Group | Count | Planned Directory | Status | Runtime loaded? |
|-------|-------|--------------------|--------|-----------------|
| Mine environment | 85 | `assets/development/mine/environment/` | `todo` | no |
| Props | 2 | `assets/development/props/` | `todo` | no |
| Town map | 1 | `assets/development/town/map/` | `todo` | no |
| Town NPC static art | 4 | `assets/development/town/npcs/` | `todo` | no |
| UI icons | 17 | `assets/development/ui/icons/` | `todo` | no |
| UI skin | 18 | `assets/development/ui/skin/` | `todo` | no |
| **Total** | **127** | `assets/development/` | `todo` | no |

### Development Asset Groups

The following groups define the 127 planned assets. Each asset name below
is a `todo` work-order row: when generated, it will produce `<name>.svg`,
`<name>.png`, and `<name>.png.meta.md` with `status: development`.

#### Mine Environment (85 assets)

Includes `2D_Top_Down_Cave_Tileset`, `bone_1` through `bone_10`,
`crystal_1` through `crystal_10`, `decor_1` through `decor_20`,
`greenery_1` through `greenery_10`, `lake`, `land`, `rune_1` through
`rune_7`, `stones_1` through `stones_10`, `wall_1` through `wall_14`, and
`raw_anomalous_geode_pickup`.

These are planned review-source replacements for cave tiles, cave decor,
raw pickups, walls, bones, crystals, stones, greenery, and runes. Most are
intended as vector mosaics derived from the current high-detail runtime
art; `raw_anomalous_geode_pickup` will use the `tmp/imagegen` alpha
reference.

#### Props (2 assets)

Includes `minecart_return_to_town` and `oxygen_pump`.

The minecart is planned to be derived from the current high-detail runtime
minecart art. The oxygen pump will use the `tmp/imagegen` alpha reference.
Neither asset will be loaded from `assets/development/`.

#### Town Map And NPCs (5 assets)

Includes `town_map`, `npc_miner_sprites`, `npc_buyer_sprites`,
`npc_identifier_sprites`, and `npc_task_clerk_sprites`.

The town map is planned as a review-size vector mosaic derived from the
current town background. NPCs will use the `tmp/imagegen` alpha references.

#### UI Icons (17 assets)

Includes all raw geodes, identified minerals, and HUD/menu icons:
`raw_common_geode`, `raw_fine_geode`, `raw_rare_geode`,
`raw_anomalous_geode`, `copper_nugget`, `iron_shard`, `silver_vein`,
`gold_vein`, `crystal_bloom`, `moonlit_crystal`, `star_fragment`,
`memory_core`, `warehouse`, `coin`, `oxygen`, `weight`, and `health`.

These will use the `tmp/imagegen` alpha references and are intended for
future warehouse, shop, HUD, and menu review.

#### UI Skin (18 assets)

Includes `panel_parchment_9slice`, `panel_wood_9slice`,
`button_normal_9slice`, `button_hover_9slice`, `button_pressed_9slice`,
`button_disabled_9slice`, `slot_empty`, `slot_filled`, `slot_locked`,
`tooltip_9slice`, `toast_9slice`, `bar_frame_horizontal`,
`bar_fill_health`, `bar_fill_oxygen`, `bar_fill_progress`,
`weight_frame_vertical`, `qte_ring`, and `dialog_nameplate`.

These are planned early vector-authored UI surfaces for later warehouse,
buy/sell, dialog, toast, HUD, and QTE styling. They will need in-engine UI
review before runtime adoption.

## Implemented

The legacy runtime assets still live under `assets/mine/`, `assets/town/`,
and `assets/props/`. Their implemented/placeholder audit remains a separate
pass; this change does not re-grade or replace them.

## Placeholder

No placeholder assets are tracked at this time.

## Todo

- **Re-create the generation script** `scripts/tools/generate_development_assets.py` and regenerate the 127 planned development assets listed above.
- Review contact sheets under `tmp/development_asset_contact_sheets/` once assets are regenerated.
- Decide which development assets should graduate into runtime paths.
- Add sidecars for legacy player and enemy animation sheets in a separate
  animation metadata pass.
- When wiring begins, copy/export approved art out of `assets/development/`
  into the appropriate runtime root and update the row status.
- Audit every existing `assets/**/*.png` and add a `<name>.png.meta.md`
  sidecar next to each (legacy runtime asset audit).

## Obsolete

| Path | Sidecar | Replaced by | Retirement rationale |
|------|---------|-------------|----------------------|
| _none yet_ | | | |

## Review Checklist Before Loading An Asset

1. Inventory or `assets/development/manifest.json` row exists.
2. Sidecar exists next to the PNG.
3. All required fields are filled.
4. `license` is not `TBD`.
5. `status` matches the intended use. Runtime-loaded files should not stay
   `development`.
6. Intended use matches the new code.
7. Resolution/import scale matches the runtime target.
8. `last-reviewed-on` is within 90 days.
