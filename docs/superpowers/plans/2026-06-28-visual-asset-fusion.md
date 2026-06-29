# Visual Asset Fusion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the current generated visual candidates into the playable game without changing gameplay behavior.

**Architecture:** Keep asset routing centralized where it already exists. Item art flows through `ItemDatabase`, dialogue portraits flow through `data/narrative/dialogues.json`, world NPC sprites stay in the four NPC scenes, and title/intro backgrounds stay local to their UI scripts.

**Tech Stack:** Godot 4 GDScript, `.tscn` scene resources, JSON narrative data, PNG Texture2D resources, `tests/project/run_all.gd`.

---

### Task 1: Add Regression Coverage For First-Pass Wiring

**Files:**
- Modify: `tests/project/run_all.gd`

- [ ] Add test registrations after the existing visual asset tests:

```gdscript
_run_test("item database uses generated UI item icons", Callable(self, "_test_item_database_uses_generated_ui_item_icons"))
_run_test("town NPCs use generated candidate sprites", Callable(self, "_test_town_npcs_use_generated_candidate_sprites"))
_run_test("dialogue data uses generated portraits", Callable(self, "_test_dialogue_data_uses_generated_portraits"))
_run_test("title and intro use generated screen backgrounds", Callable(self, "_test_title_and_intro_use_generated_backgrounds"))
```

- [ ] Add the four test functions. They should read source files and scene text directly so they fail before production wiring:

```gdscript
func _test_item_database_uses_generated_ui_item_icons() -> void:
	var db_text := FileAccess.get_file_as_string("res://scripts/items/item_database.gd")
	var expected := [
		"res://assets/ui/icons/items/raw_common_geode.png",
		"res://assets/ui/icons/items/raw_fine_geode.png",
		"res://assets/ui/icons/items/raw_rare_geode.png",
		"res://assets/ui/icons/items/raw_star_geode.png",
		"res://assets/ui/icons/items/copper_nugget.png",
		"res://assets/ui/icons/items/iron_shard.png",
		"res://assets/ui/icons/items/silver_vein.png",
		"res://assets/ui/icons/items/gold_vein.png",
		"res://assets/ui/icons/items/crystal_bloom.png",
		"res://assets/ui/icons/items/moonlit_crystal.png",
		"res://assets/ui/icons/items/star_fragment.png",
		"res://assets/ui/icons/items/memory_core.png",
		"res://assets/ui/icons/items/star_crystal.png",
	]
	for path in expected:
		_assert_true(FileAccess.file_exists(path), "generated item icon exists: %s" % path)
		_assert_true(db_text.contains(path), "ItemDatabase preloads generated icon: %s" % path)
	_assert_false(db_text.contains("assets/props/raw_common_geode_alpha.png"), "ItemDatabase no longer uses old raw geode prop icon")
	_assert_false(db_text.contains("assets/props/raw_anomalous_geode_pickup_alpha.png"), "ItemDatabase no longer uses old star crystal placeholder icon")
```

```gdscript
func _test_town_npcs_use_generated_candidate_sprites() -> void:
	var scene_to_asset := {
		"res://scenes/town/npc_elder.tscn": "res://assets/town/npcs/elder_idle.png",
		"res://scenes/town/npc_blacksmith.tscn": "res://assets/town/npcs/blacksmith_idle.png",
		"res://scenes/town/npc_florist.tscn": "res://assets/town/npcs/florist_idle.png",
		"res://scenes/town/npc_buyer.tscn": "res://assets/town/npcs/buyer_idle.png",
	}
	for scene_path in scene_to_asset.keys():
		var asset_path: String = scene_to_asset[scene_path]
		var text := FileAccess.get_file_as_string(scene_path)
		_assert_true(FileAccess.file_exists(asset_path), "generated NPC sprite exists: %s" % asset_path)
		_assert_true(text.contains(asset_path), "NPC scene uses generated sprite: %s" % scene_path)
		_assert_true(text.contains("scale = Vector2(1.25, 1.25)") or not text.contains("scale = Vector2(0.07, 0.07)"), "NPC scene does not keep old alpha sprite scale: %s" % scene_path)
```

```gdscript
func _test_dialogue_data_uses_generated_portraits() -> void:
	var text := FileAccess.get_file_as_string("res://data/narrative/dialogues.json")
	var expected := [
		"res://assets/ui/portraits/elder_neutral.png",
		"res://assets/ui/portraits/blacksmith_neutral.png",
		"res://assets/ui/portraits/florist_neutral.png",
		"res://assets/ui/portraits/buyer_neutral.png",
	]
	for path in expected:
		_assert_true(FileAccess.file_exists(path), "generated portrait exists: %s" % path)
		_assert_true(text.contains(path), "dialogue JSON uses generated portrait: %s" % path)
	var town_text := FileAccess.get_file_as_string("res://scripts/town/mining_town_scene.gd")
	_assert_true(town_text.contains("res://assets/ui/portraits/florist_neutral.png"), "florist tears dialogue uses generated portrait")
	_assert_false(text.contains("assets/props/npc_identifier_sprites_alpha.png"), "dialogue JSON no longer uses old florist prop portrait")
```

```gdscript
func _test_title_and_intro_use_generated_backgrounds() -> void:
	var title_text := FileAccess.get_file_as_string("res://scripts/ui/title_menu.gd")
	var intro_text := FileAccess.get_file_as_string("res://scripts/ui/intro.gd")
	_assert_true(FileAccess.file_exists("res://assets/ui/screens/title_background.png"), "title background exists")
	_assert_true(FileAccess.file_exists("res://assets/ui/screens/intro_background.png"), "intro background exists")
	_assert_true(title_text.contains("res://assets/ui/screens/title_background.png"), "title menu loads generated background")
	_assert_true(intro_text.contains("res://assets/ui/screens/intro_background.png"), "intro scene loads generated background")
```

- [ ] Run the project regression suite and confirm these tests fail for the expected missing-path reasons:

```powershell
pwsh -File scripts/check.ps1 -SkipImportRefresh
```

### Task 2: Wire Item Icons Through ItemDatabase

**Files:**
- Modify: `scripts/items/item_database.gd`

- [ ] Replace the 13 `preload()` paths with generated UI item icon paths:

```gdscript
@export var icon_raw_common_geode: Texture2D = preload("res://assets/ui/icons/items/raw_common_geode.png")
@export var icon_raw_fine_geode: Texture2D = preload("res://assets/ui/icons/items/raw_fine_geode.png")
@export var icon_raw_rare_geode: Texture2D = preload("res://assets/ui/icons/items/raw_rare_geode.png")
@export var icon_raw_star_geode: Texture2D = preload("res://assets/ui/icons/items/raw_star_geode.png")
@export var icon_copper_nugget: Texture2D = preload("res://assets/ui/icons/items/copper_nugget.png")
@export var icon_iron_shard: Texture2D = preload("res://assets/ui/icons/items/iron_shard.png")
@export var icon_silver_vein: Texture2D = preload("res://assets/ui/icons/items/silver_vein.png")
@export var icon_gold_vein: Texture2D = preload("res://assets/ui/icons/items/gold_vein.png")
@export var icon_crystal_bloom: Texture2D = preload("res://assets/ui/icons/items/crystal_bloom.png")
@export var icon_moonlit_crystal: Texture2D = preload("res://assets/ui/icons/items/moonlit_crystal.png")
@export var icon_star_fragment: Texture2D = preload("res://assets/ui/icons/items/star_fragment.png")
@export var icon_memory_core: Texture2D = preload("res://assets/ui/icons/items/memory_core.png")
@export var icon_star_crystal: Texture2D = preload("res://assets/ui/icons/items/star_crystal.png")
```

- [ ] Run `pwsh -File scripts/check.ps1 -SkipImportRefresh` and confirm the item icon test passes or any remaining failures are unrelated to this task.

### Task 3: Wire NPC Sprites And Dialogue Portraits

**Files:**
- Modify: `scenes/town/npc_elder.tscn`
- Modify: `scenes/town/npc_blacksmith.tscn`
- Modify: `scenes/town/npc_florist.tscn`
- Modify: `scenes/town/npc_buyer.tscn`
- Modify: `data/narrative/dialogues.json`
- Modify: `scripts/town/mining_town_scene.gd`

- [ ] Replace each NPC scene texture path:

```text
npc_elder.tscn -> res://assets/town/npcs/elder_idle.png
npc_blacksmith.tscn -> res://assets/town/npcs/blacksmith_idle.png
npc_florist.tscn -> res://assets/town/npcs/florist_idle.png
npc_buyer.tscn -> res://assets/town/npcs/buyer_idle.png
```

- [ ] Change each NPC `Sprite2D` scale from `Vector2(0.07, 0.07)` to `Vector2(1.25, 1.25)` because the generated files are already 64x64 world sprites.
- [ ] Replace dialogue portrait paths:

```json
"elder": "res://assets/ui/portraits/elder_neutral.png"
"blacksmith": "res://assets/ui/portraits/blacksmith_neutral.png"
"florist": "res://assets/ui/portraits/florist_neutral.png"
"buyer": "res://assets/ui/portraits/buyer_neutral.png"
```

- [ ] Replace the florist tears dialogue portrait with `res://assets/ui/portraits/florist_neutral.png`.
- [ ] Run `pwsh -File scripts/check.ps1 -SkipImportRefresh`.

### Task 4: Wire Title And Intro Backgrounds Conservatively

**Files:**
- Modify: `scripts/ui/title_menu.gd`
- Modify: `scripts/ui/intro.gd`

- [ ] In `title_menu.gd`, replace the full-screen `ColorRect` with a `TextureRect` loading `res://assets/ui/screens/title_background.png`, then add a translucent dark `ColorRect` overlay before the existing menu container.
- [ ] In `intro.gd`, replace the pure black background with a `TextureRect` loading `res://assets/ui/screens/intro_background.png`, then add a dark overlay so the narration text remains readable.
- [ ] Do not bake text into the asset or change button labels, scene transitions, or input handling.
- [ ] Run `pwsh -File scripts/check.ps1 -SkipImportRefresh`.

### Task 5: Update Asset Inventory And Task Docs

**Files:**
- Modify: `docs/visual_assets/inventory.md`
- Modify: `docs/current_tasks.md`

- [ ] Update the Placeholder table `Used by` column for each newly wired asset.
- [ ] Keep status as `placeholder`; these candidates are now loaded but not final art.
- [ ] Record in `docs/current_tasks.md` that first-pass item/NPC/title/intro fusion is done, and leave TileMap/mine tileset/UI full skinning as TODOs.
- [ ] Run a final `pwsh -File scripts/check.ps1`.
