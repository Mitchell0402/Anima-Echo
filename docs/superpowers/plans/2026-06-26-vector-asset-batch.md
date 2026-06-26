# Vector Asset Batch Plan

Date: 2026-06-26
Branch: `codex/visual-asset-management`

## Goal

Generate the previous 23 P0/P1/P2 visual assets and the remaining
static renovation backlog as vector-source-first assets.

## Scope

- Add SVG sources beside runtime PNG exports.
- Regenerate static mine environment art, props, town map, town NPC
  static sprites, UI icons, and UI skin textures.
- Write complete sidecar metadata for every generated PNG.
- Keep player and enemy animated raster sheets unchanged.
- Keep scene/script wiring unchanged in this pass.

## Work Items

1. Add a deterministic repository script that owns the batch manifest
   and emits SVG, PNG, and `.png.meta.md` sidecars.
2. Run the script to generate the full first-pass vector batch.
3. Refresh Godot imports so new SVG and PNG files have `.import`
   metadata.
4. Update visual asset docs to record the new vector-source coverage
   and remaining review/wiring work.
5. Verify generated file counts, sidecar completeness, import refresh,
   and whitespace cleanliness.

## Acceptance Criteria

- Every previous imagegen P0/P1/P2 PNG has a sibling SVG source.
- Every static mine environment PNG has a sibling SVG source and
  sidecar.
- Minecart, oxygen pump, town map, UI icons, and UI skin backlog have
  SVG sources, PNG exports, and sidecars.
- No player or enemy animation PNG is overwritten.
- Docs identify this as a first-pass generated vector placeholder batch
  pending human art review and runtime UI wiring.

