# Visual Assets

The repository tracks every image the game needs to draw so an
asset-generation AI can produce the missing ones in a coherent style.
The game itself is a 2D top-down pixel prototype, so every asset
falls into one of two categories:

- **World art** (sprites, tiles, environments) that the player sees
  in the scene. Lives under `assets/`.
- **UI art** (icons, panels, buttons) that the menus draw. Lives
  under `assets/ui/` (this directory does not exist yet — it is the
  default landing spot for new UI assets).

The companion inventory list is `docs/visual_assets/inventory.md`.
That file is the **single source of truth** for "what is implemented
today" and "what still needs to be drawn". Update it whenever a new
asset is added, removed, or re-graded.

## Hard rules

These rules apply to every visual asset in the repository. They are
also the first thing a reviewer should check before any new asset is
loaded by the game.

1. **Every asset has a sidecar metadata file.** A `foo.png` lives
   next to a `foo.png.meta.md` in the same directory. The sidecar
   describes everything an AI generator, a reviewer, or a future
   code change would need to know about the asset.
2. **Review the metadata before loading the asset.** A code change
   that adds a new `load()` / `preload()` for a visual asset must
   cite the asset's metadata file in the code review and confirm
   the file's status, palette, and intended use match the new use
   site.
3. **The inventory is canonical.** Every asset on disk appears in
   `docs/visual_assets/inventory.md`. The inventory's status must
   match what is on disk: an `implemented` row whose file is missing,
   or a `todo` row whose file already exists, both break the
   contract. A reviewer should reject either.
4. **Existing assets must be audited and graded.** The first pass on
   this document also re-examines every `assets/**/*.png` already
   in the repository, gives each one a metadata sidecar, and
   assigns it a status (`implemented` / `placeholder` / `obsolete`).
   Anything that no longer matches the style guide is downgraded
   to `placeholder` until the AI produces a replacement.

## Naming convention

Every visual asset follows this structure:

```
assets/<category>/<sub-category>/<name>_<state>[_<variant>].png
```

- `<category>` is one of `mine/`, `town/`, `props/`, `ui/`.
- `<sub-category>` is the asset type (`characters/`, `enemies/`,
  `environment/`, `npcs/`, `map/`, `icons/`, etc.).
- `<name>` is the asset's stable name in `camel_case`. The name must
  match a row in `inventory.md`.
- `<state>` is the animation state if the asset is part of a sprite
  sheet (`idle`, `walk`, `run`, `attack`, `hurt`, `death`, etc.).
- `<variant>` is an optional colour or size variant
  (`_with_shadow`, `_lvl1`, `_rare`, etc.).

Examples (existing):

- `assets/mine/characters/player/Sword_Walk_with_shadow.png`
- `assets/mine/enemies/gnoll/Gnoll1_Attack_with_shadow.png`
- `assets/props/npc_miner_alpha.png`

Examples (planned, not yet drawn):

- `assets/ui/icons/raw_common_geode.png` — the warehouse slot icon
  for a tier-1 raw geode.
- `assets/ui/icons/copper_nugget.png` — the warehouse slot icon for
  the equivalent mineral.

## Sidecar metadata

Every PNG has a sidecar `<same-name>.png.meta.md` next to it. The
sidecar is required for `implemented` and `placeholder` assets; it
is optional but recommended for `todo` assets (the AI generator can
read it as a brief).

Required fields for `implemented` and `placeholder` assets:

- **`id`** — the stable name. Must match the inventory row.
- **`category`** — `mine` / `town` / `props` / `ui`.
- **`sub-category`** — `characters` / `enemies` / `environment` /
  `npcs` / `map` / `icons` / `prop-name`.
- **`source`** — where the asset came from.
  - `authored-original` for art produced in-house.
  - `ai-generated:<model>` for art produced by an external image
    model (e.g. `ai-generated:midjourney-v6`).
  - `asset-library:<source>` for art imported from a third-party
    library (e.g. `asset-library:opengameart/cave-tileset`).
- **`license`** — the licence under which the asset is distributed.
  - `CC0` for public domain.
  - `CC-BY-4.0` or `CC-BY-SA-4.0` for Creative Commons with
    attribution / share-alike.
  - `CC-BY-NC-4.0` or `CC-BY-NC-SA-4.0` for non-commercial variants.
  - `project-internal` for art we authored and only ship inside
    this repository.
  - `TBD` for assets whose licence has not been recorded yet. The
    reviewer must reject the asset until this is filled in.
- **`status`** — one of `implemented`, `placeholder`, `todo`,
  `obsolete`. Must match the inventory row.
- **`width` / `height`** — pixel dimensions of the source PNG.
- **`palette`** — the 16-colour palette used, named in
  `inventory.md` (one palette per category).
- **`description`** — a one-paragraph summary of what the asset
  depicts and where it is used in the game.
- **`style-notes`** — anything an AI regenerating this asset needs
  to know: line weight, perspective, lighting, animation timing,
  whether a shadow is required, etc.
- **`created-by`** — author name or AI prompt slug.
- **`last-reviewed-by`** — name of the dev who last verified the
  sidecar matches the file on disk and the inventory row.
- **`last-reviewed-on`** — ISO date of that review.

A sidecar that is missing any of these fields is incomplete and
should be treated like an `implemented` asset without a sidecar: a
reviewer should reject it.

## Style guide

The look of Anima Echo is a soft pixel-art top-down view at a single
display zoom. Every asset must follow these rules so the AI outputs
stay consistent and drop-in compatible:

- **Resolution**: 64×64 px per character and 32×32 px per tile or
  icon by default. UI icons are 48×48 px. Larger source art is fine
  if the import scale is documented in the sidecar `style-notes`.
- **Filter**: `TEXTURE_FILTER_NEAREST` is set in code. **Do not**
  add bilinear or trilinear filtering to the source PNG. Keep
  crisp pixel edges.
- **Palette**: a single 16-colour palette per category. Author the
  palette once (in `inventory.md`) and reuse it across every asset
  in the same category. The sidecar references the palette by name.
- **Centring**: sprites are centred (`Sprite2D.centered = true`).
  Anchor the bottom of the sprite at world Y = 0 so feet and ground
  align.
- **Shadow**: a single 2-px soft drop-shadow is acceptable and
  encouraged for the world layer. UI icons do not need shadows.
- **Background**: fully transparent (`alpha = 0`). Do not bake in
  green-screen or solid backgrounds.

## Generation workflow

1. The dev adds a row to `inventory.md` with:
   - the asset's stable name
   - the category / sub-category
   - a one-line description
   - the status (`todo`, `placeholder`, `implemented`)
   - the target file path it will live at
2. An external image-generation AI reads `inventory.md` plus this
   file and draws the missing rows.
3. The dev drops the new file at the target path **alongside its
   sidecar metadata file** and flips the row's status to
   `implemented`. The sidecar must be filled in before the status
   change is committed.
4. A reviewer runs the inventory check (see below) and confirms
   every new asset has a sidecar with all required fields.
5. Any code that should display the asset (warehouse UI, NPC
   sprite, etc.) is wired up in a separate code change that
   references the asset's sidecar in the commit message and code
   review.

## Audit workflow (one-time + ongoing)

The first pass over the existing repository goes like this:

1. List every `assets/**/*.png` with `find assets -name "*.png"`.
2. For each file, decide its current quality:
   - **Keep** — matches the style guide. Becomes `implemented`,
     gets a sidecar with all required fields.
   - **Downgrade** — close to the style guide but has obvious
     issues (wrong palette, mismatched scale, off-perspective).
     Becomes `placeholder`, gets a sidecar noting the issues and
     a `todo` row in the inventory for the replacement.
   - **Retire** — no longer used by the game or not worth keeping.
     Becomes `obsolete`, optionally deleted in a follow-up PR.
3. Cross-reference the game's `load()` / `preload()` calls against
   the audit result. Every load site must point at an
   `implemented` asset with a complete sidecar.
4. Add an `audit-on` field to the sidecar recording the date of
   the audit so future passes can diff against it.

A future follow-up (recorded in `docs/current_tasks.md`) will turn
this into a CI check.

## Asset status legend

- `implemented` — the file exists, is loaded by the game, the
  visual is final, and the sidecar is complete. A reviewer can
  ship the asset without further work.
- `placeholder` — the file exists and is loaded, but is a temporary
  stand-in (a `ColorRect`, a debug shape, or an unscaled source).
  The sidecar records what is wrong. The AI should replace it;
  the inventory has a matching `todo` row.
- `todo` — the file does not exist yet. The game currently shows
  nothing, a flat colour, or a debug label in its place. The row
  in `inventory.md` is the work order. A sidecar is optional
  (the AI generator reads the inventory row instead) but
  recommended for the harder assets.
- `obsolete` — the file is no longer used by the game but is kept
  in the repository for reference. Deletion is safe after a
  release branch cuts. The sidecar records the retirement
  rationale and the asset it was replaced by.

## When to update the inventory

Update `docs/visual_assets/inventory.md` in the same change as:

- A new asset is committed to `assets/`.
- A new sidecar metadata file is committed next to an existing
  asset.
- The game starts (or stops) loading an existing asset.
- The target file path for a planned asset changes.
- A placeholder is replaced by final art, or vice versa.
- An asset is re-graded during the audit pass.

The inventory and the repository should never disagree about which
files exist. A CI lint could enforce this later but is not part of
the current PR.
