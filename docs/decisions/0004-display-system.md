# 0004 — Display System and Game Camera

Status: Accepted
Date: 2026-06-25

## Context

The warehouse implementation PR landed a project-level [display] section
but kept the town scene's UI on hard-coded world coordinates. Manual
testing showed three problems:

1. The town map was sized to the design baseline (1152x648) without
   telling the camera, so a stretched window showed the map at the
   top-left corner with black bars around it.
2. The NPC name label used a hard-coded `Vector2(-28, -52)` offset that
   was tuned for a 1.25x sprite scale. If the scale changed the label
   drifted away from the sprite head.
3. The popup was placed at `Vector2(690, 328)`, hard-coded for the
   1280x720 baseline. At 1920x1080 the popup ended up in the upper
   left; at 900x600 it clipped off the right edge.

We needed a proper three-layer display model (world / camera / UI) so
the game stays readable at any window size.

## Decision

Three-layer model:

```
  +-----------------------------------------------+
  | World (fixed 1152 x 648 in this game)         |
  |  - player, NPCs, mine, hotbar                 |
  |  - never changes                              |
  +--------------------+--------------------------+
                       |  Camera2D (GameCamera)
                       |  - target follows the player
                       |  - smooth lerp + look-ahead
                       |  - clamps inside world bounds
                       |  - integer zoom that fits the world
                       v
  +-----------------------------------------------+
  | View (viewport at zoom x world size)          |
  +--------------------+--------------------------+
                       |  Godot stretch mode = viewport
                       |  (see project.godot [display])
                       v
  +-----------------------------------------------+
  | Screen (window pixels)                        |
  |  - UI CanvasLayer: hotbar, popup, warehouse   |
  |  - uses anchor presets, never positions       |
  +-----------------------------------------------+
```

### World

Fixed in size. The town is `Rect2(Vector2.ZERO, Vector2(1152, 648))`.
The mine uses its own TileMap and keeps the same convention.

### Camera

`scripts/camera_2d.gd` (`GameCamera`):

- `target`: Node2D that the camera follows (the player).
- `world_bounds`: Rect2 the camera cannot leave.
- `smooth_speed`: lerp factor toward the target.
- `look_ahead_distance`: optional offset toward the player's facing
  direction so they can see more of where they are going.
- `_clamp_to_world()`: keeps the camera inside world_bounds so the
  player never sees black edges. When the viewport is wider than the
  world on one axis, the camera centres on that axis instead of
  clamping to an edge.
- `fit_world_to_viewport_integer()`: returns an integer zoom >= 1
  that fits the world inside the viewport. Combined with stretch
  mode = "viewport" and stretch scale_mode = "integer", this keeps
  the world pixel-perfect at any window size (1x, 2x, 3x ...).

### UI

All UI lives on a CanvasLayer independent of the camera. Layout uses
Godot anchor presets:

- `PRESET_TOP_WIDE` for the top prompt + status bar (already used).
- `PRESET_CENTER` for the NPC popup (replaces `Vector2(690, 328)`).
- `PRESET_TOP_LEFT` for the warehouse label (replaces `Vector2(16, 48)`).
- NPC labels are children of the NPC Node2D and use a local offset
  that scales with `TOWN_CHARACTER_SCALE`. Their position is
  `Vector2(-28, -TOWN_NPC_LABEL_VERTICAL_OFFSET)` where
  `TOWN_NPC_LABEL_VERTICAL_OFFSET = 40 * TOWN_CHARACTER_SCALE + 8`.

### Stretch

`project.godot` now declares:

```
[display]
window/stretch/mode="viewport"
window/stretch/aspect="keep"
window/stretch/scale_mode="integer"
```

`viewport` keeps the internal coordinates at 1280x720 regardless of
window size. `keep` letter-boxes if the window is a different aspect.
`integer` only allows 1x, 2x, 3x, ... scaling so textures stay
sharp (combined with `texture_filter = TEXTURE_FILTER_NEAREST`).

## Consequences

- The town renders consistently at any supported window size. The
  world fills the viewport, NPCs stay at the same world positions,
  the camera smoothes between them, and UI overlays stay anchored.
- Switching between editor runs with a different window size does
  not require scene reloads. The integer zoom is computed in the
  camera's `_ready` after `call_deferred`, so it is always
  re-evaluated against the current viewport.
- The mine scene still has its own hard-coded TileMap size and
  Camera2D attached to the player. A future PR should bring the
  mine into the same model. See `current_tasks.md` for the follow-up.
- `fit_world_to_viewport_integer()` always returns at least 1x.
  At a viewport smaller than the world bounds, the world is clipped
  rather than scaled down, which preserves pixel art. If we want a
  different policy (e.g. fit-to-window) we can add a `fit_mode`
  export without changing the public API.

## Migration notes

- `mining_town_scene._build_world()` no longer attaches a Camera2D
  to the player. Instead it instantiates a `GameCamera` at the scene
  root and sets its target to the player.
- `mining_town_scene._build_ui()` uses anchor presets instead of
  absolute positions. The popup size hint is preserved as a custom
  minimum so the panel does not collapse on small viewports.
- The warehouse UI was already viewport-aware from the warehouse
  PR (PR #8). No further changes were needed here.