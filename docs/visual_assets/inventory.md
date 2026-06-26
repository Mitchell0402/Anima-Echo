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

## Implemented

This section is filled in by the audit workflow (see the appendix
at the bottom). A future pass lists every file currently on disk in
`assets/` and either keeps it, downgrades it, or retires it. The
section is empty in this PR.

| Path | Sidecar | Palette | Status | Used by | Last reviewed |
|------|----------|---------|--------|---------|---------------|
| _example row_ | `Sword_Walk_with_shadow.png.meta.md` | `mine/default` | `implemented` | `scripts/town/mining_town_scene.gd:188` (player sprite frames) | TBD |

## Placeholder

This section lists files that exist and are loaded but are
temporary stand-ins. The sidecar describes what is wrong, and the
`Todo` section below carries the matching `todo` row that the AI
generator should fulfil.

| Path | Sidecar | Replaces | Used by | Sidecar status |
|------|----------|----------|---------|----------------|
| _empty in this PR_ | | | | |

## Todo (planned, not yet drawn)

This section is the AI's work order. Every row here corresponds to
a row in the future `Placeholders` section once the asset is drawn.

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
