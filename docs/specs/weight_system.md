# Weight System

Status: In Progress
Last updated: 2026-06-23

## Goal

Introduce a tiered encumbrance system where the total weight of raw geodes in the player's backpack affects movement speed, noise emission, and later oxygen consumption.

## Scope

- In scope: 3-tier weight (Light 0-65, Heavy 66-100, Overload 101-180), speed penalty, noise multiplier, WeightBar UI, catalog weight data
- Out of scope: oxygen consumption (reserved interface only), warehouse/storage weight, hotbar weight display

## Acceptance Criteria

- [ ] Collecting geodes increases the WeightBar fill and updates the tier.
- [ ] Light tier (0-65): full speed, normal noise, green bar.
- [ ] Heavy tier (66-100): 80% speed, 1.3x noise, yellow bar.
- [ ] Overload tier (101-180): 60% speed, 1.8x noise, orange-red bar.
- [ ] WeightBar displays at player head with segmented color and "current / 100" text.
- [ ] Existing gameplay routes (town/mine transitions, enemy AI) still work.

## Relevant Files

- `res://data/game/catalog.json` — weight field added to 4 raw geode items
- `res://scripts/core/weight_system.gd` — new autoload, core weight logic
- `res://scripts/player/player_stats.gd` — speed multiplier driven by WeightSystem
- `res://scripts/player/move_controller.gd` — noise multiplier from WeightSystem
- `res://scripts/ui/weight_bar.gd` — new UI bar, player-attached
- `res://scenes/mine/main_character_stats.tscn` — added WeightBar node
- `res://project.godot` — registered WeightSystem autoload

## Risks

- WeightSystem.autoload depends on GameRuntime.inventory being initialized first. Autoload order (GameRuntime before WeightSystem in project.godot) mitigates this.
- If future features store non-geode items in GameRuntime.inventory during mine scenes, their weight (default 0) is harmless.

## Verification

- Automated: run `tests/project/run_all.gd` to confirm existing tests still pass
- Manual: enter mine, collect geodes, observe WeightBar color/text change and speed/noise change
