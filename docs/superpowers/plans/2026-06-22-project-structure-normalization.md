# Project Structure Normalization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Normalize `mine-platform-v2` into a cleaner, professional single-root Godot project layout while preserving all playable GJ mine and fused town behavior.

**Architecture:** Keep `project.godot` at repo root and converge top-level source folders toward lowercase conventional Godot paths: `scenes/`, `scripts/`, `assets/`, `data/`, `docs/`, `tests/`, and `addons/`. Migrate in phases so every `res://` move is protected by tests, static reference scans, import, and headless scene startup.

**Tech Stack:** Godot 4.6.3, GDScript, `.tscn` text scenes, JSON data, PowerShell migration commands, `tests/fusion/run_all.gd`.

---

## Target Layout

```text
mine-platform-v2/
  addons/
    godot_mcp/
  assets/
    gj/
      characters/
      enemies/
      environment/
    town/
      map/
      npcs/
    props/
      minecart_return_to_town.png
  data/
    game/
      catalog.json
  docs/
    PROJECT_CONTEXT.md
    fusion_v2_implementation_summary.md
    superpowers/
      plans/
  scenes/
    mine/
      test_scene.tscn
      main_character_stats.tscn
      small_mine.tscn
      cover.tscn
      enemy.tscn
      gems/
        gem_abstract.tscn
        gem_l1.tscn
        gem_l2.tscn
        gem_l3.tscn
    town/
      mining_town.tscn
  scripts/
    core/
    economy/
    enemies/
    items/
    mine/
    player/
    town/
    ui/
  tests/
    fusion/
  project.godot
```

## Migration Rules

- Preserve `addons/godot_mcp/` at root; it is a Godot editor plugin path and should not be buried.
- Preserve `project.godot` at root.
- Do not move `.godot/`; it is local cache and should remain ignored.
- Move in small phases and run the full verification after each phase.
- Do not delete GJ art just because it looks unused; first scan real scene/resource references.
- Every moved `res://` path must be updated in `.gd`, `.tscn`, `.tres`, `.godot`, `.md`, and test files.
- Prefer lowercase new paths. Old uppercase `Scene/` and `Scripts/` should disappear only after reference scans are clean.

## Verification Commands

Run after every task:

```powershell
& 'C:\Users\Mitchell\Documents\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'C:\Users\Mitchell\Documents\mine-platform-v2' -s res://tests/fusion/run_all.gd
```

Expected after tests are updated for this migration:

```text
RESULT: PASS
```

Run import after file moves:

```powershell
& 'C:\Users\Mitchell\Documents\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'C:\Users\Mitchell\Documents\mine-platform-v2' --import
```

Smoke start town:

```powershell
& 'C:\Users\Mitchell\Documents\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'C:\Users\Mitchell\Documents\mine-platform-v2' --quit-after 3
```

Smoke start mine:

```powershell
& 'C:\Users\Mitchell\Documents\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'C:\Users\Mitchell\Documents\mine-platform-v2' res://scenes/mine/test_scene.tscn --quit-after 3
```

Static stale-path scan:

```powershell
rg -n "res://Scene/|res://Scripts/|res://art/|res://assets/mining_economy|res://assets/fusion|res://PROJECT_CONTEXT.md" project.godot scenes scripts assets data docs tests -g "*.gd" -g "*.tscn" -g "*.tres" -g "*.godot" -g "*.md" -g "*.json"
```

Expected after all migration tasks: no output except historical notes inside the migration plan if the scan includes `docs/superpowers/plans`.

---

### Task 1: Add Structure Guard Tests

**Files:**
- Modify: `C:\Users\Mitchell\Documents\mine-platform-v2\tests\fusion\run_all.gd`

- [ ] **Step 1: Add a failing structure test**

Add a new test registration after `project docs describe current fused project`:

```gdscript
_run_test("project uses normalized source layout", Callable(self, "_test_project_uses_normalized_source_layout"))
```

Add this test function:

```gdscript
func _test_project_uses_normalized_source_layout() -> void:
	var required_dirs := [
		"res://assets/gj",
		"res://assets/town",
		"res://assets/props",
		"res://data/game",
		"res://docs",
		"res://scenes/mine",
		"res://scenes/town",
		"res://scripts/core",
		"res://scripts/economy",
		"res://scripts/player",
		"res://scripts/mine",
		"res://scripts/enemies",
		"res://scripts/items",
		"res://scripts/town",
		"res://scripts/ui",
		"res://tests/fusion",
	]
	for dir_path in required_dirs:
		_assert_true(DirAccess.dir_exists_absolute(dir_path), "normalized directory exists: %s" % dir_path)
	var removed_dirs := [
		"res://Scene",
		"res://Scripts",
		"res://art",
		"res://assets/fusion",
		"res://assets/mining_economy",
	]
	for dir_path in removed_dirs:
		_assert_false(DirAccess.dir_exists_absolute(dir_path), "legacy top-level directory removed: %s" % dir_path)
```

- [ ] **Step 2: Add a stale path scan test**

Add this helper:

```gdscript
func _list_files_multi(path: String, extensions: Array[String]) -> Array[String]:
	var results: Array[String] = []
	var dir := DirAccess.open(path)
	if dir == null:
		return results
	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry.is_empty():
			break
		if entry.begins_with("."):
			continue
		var child_path := "%s/%s" % [path, entry]
		if dir.current_is_dir():
			results.append_array(_list_files_multi(child_path, extensions))
		else:
			for extension in extensions:
				if entry.ends_with(extension):
					results.append(child_path)
					break
	dir.list_dir_end()
	return results
```

Add this test function:

```gdscript
func _test_no_legacy_res_paths_after_layout_migration() -> void:
	var roots := ["res://project.godot", "res://scenes", "res://scripts", "res://assets", "res://data", "res://docs", "res://tests"]
	var stale_terms := ["res://Scene/", "res://Scripts/", "res://art/", "res://assets/mining_economy", "res://assets/fusion", "res://PROJECT_CONTEXT.md"]
	var files: Array[String] = []
	for root_path in roots:
		if FileAccess.file_exists(root_path):
			files.append(root_path)
		elif DirAccess.dir_exists_absolute(root_path):
			files.append_array(_list_files_multi(root_path, [".gd", ".tscn", ".tres", ".godot", ".md", ".json"]))
	for file_path in files:
		var text := FileAccess.get_file_as_string(file_path)
		for term in stale_terms:
			_assert_false(text.contains(term), "no stale path %s in %s" % [term, file_path])
```

Register it after the normalized layout test:

```gdscript
_run_test("no legacy res paths remain after layout migration", Callable(self, "_test_no_legacy_res_paths_after_layout_migration"))
```

- [ ] **Step 3: Run test to verify RED**

Run:

```powershell
& 'C:\Users\Mitchell\Documents\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'C:\Users\Mitchell\Documents\mine-platform-v2' -s res://tests/fusion/run_all.gd
```

Expected: FAIL because `Scene`, `Scripts`, `art`, `assets/mining_economy`, and `assets/fusion` still exist.

---

### Task 2: Move Root Documentation Into `docs/`

**Files:**
- Move: `C:\Users\Mitchell\Documents\mine-platform-v2\PROJECT_CONTEXT.md` -> `C:\Users\Mitchell\Documents\mine-platform-v2\docs\PROJECT_CONTEXT.md`
- Modify: `C:\Users\Mitchell\Documents\mine-platform-v2\tests\fusion\run_all.gd`
- Modify: `C:\Users\Mitchell\Documents\mine-platform-v2\docs\fusion_v2_implementation_summary.md`

- [ ] **Step 1: Move the file**

Run:

```powershell
Move-Item -LiteralPath 'C:\Users\Mitchell\Documents\mine-platform-v2\PROJECT_CONTEXT.md' -Destination 'C:\Users\Mitchell\Documents\mine-platform-v2\docs\PROJECT_CONTEXT.md'
```

- [ ] **Step 2: Update tests to read the new path**

Change:

```gdscript
var project_context := FileAccess.get_file_as_string("res://PROJECT_CONTEXT.md")
```

to:

```gdscript
var project_context := FileAccess.get_file_as_string("res://docs/PROJECT_CONTEXT.md")
```

Add this assertion inside `_test_project_docs_are_current()`:

```gdscript
_assert_false(FileAccess.file_exists("res://PROJECT_CONTEXT.md"), "root project context doc moved into docs")
```

- [ ] **Step 3: Update docs to mention the new doc location**

In `docs/fusion_v2_implementation_summary.md`, add under `Current Project`:

```markdown
- AI context doc: `res://docs/PROJECT_CONTEXT.md`
```

- [ ] **Step 4: Verify**

Run the fusion suite. Expected: only remaining failures are from later structure moves.

---

### Task 3: Normalize New Fusion Asset Paths

**Files:**
- Move: `assets/fusion/props/minecart_return_to_town.png` -> `assets/props/minecart_return_to_town.png`
- Modify: `Scene/test_scene.tscn` for now; later this becomes `scenes/mine/test_scene.tscn`
- Modify: `tests/fusion/run_all.gd`
- Modify: docs under `docs/`

- [ ] **Step 1: Move the minecart asset**

Run:

```powershell
New-Item -ItemType Directory -Force -Path 'C:\Users\Mitchell\Documents\mine-platform-v2\assets\props' | Out-Null
Move-Item -LiteralPath 'C:\Users\Mitchell\Documents\mine-platform-v2\assets\fusion\props\minecart_return_to_town.png' -Destination 'C:\Users\Mitchell\Documents\mine-platform-v2\assets\props\minecart_return_to_town.png'
Move-Item -LiteralPath 'C:\Users\Mitchell\Documents\mine-platform-v2\assets\fusion\props\minecart_return_to_town.png.import' -Destination 'C:\Users\Mitchell\Documents\mine-platform-v2\assets\props\minecart_return_to_town.png.import'
```

- [ ] **Step 2: Remove empty fusion folders**

Run:

```powershell
Remove-Item -LiteralPath 'C:\Users\Mitchell\Documents\mine-platform-v2\assets\fusion' -Recurse -Force
```

- [ ] **Step 3: Update `res://assets/fusion` references**

Replace:

```text
res://assets/fusion/props/minecart_return_to_town.png
```

with:

```text
res://assets/props/minecart_return_to_town.png
```

in:

```text
C:\Users\Mitchell\Documents\mine-platform-v2\Scene\test_scene.tscn
C:\Users\Mitchell\Documents\mine-platform-v2\tests\fusion\run_all.gd
C:\Users\Mitchell\Documents\mine-platform-v2\docs\PROJECT_CONTEXT.md
C:\Users\Mitchell\Documents\mine-platform-v2\docs\fusion_v2_implementation_summary.md
```

- [ ] **Step 4: Import and verify**

Run Godot import, then run tests. Expected: no minecart resource load errors.

---

### Task 4: Normalize Town Asset Paths

**Files:**
- Move: `assets/mining_economy/town/*` -> `assets/town/*`
- Modify: `scripts/town/fused_mining_town_scene.gd` after script migration, or current `Scripts/town/fused_mining_town_scene.gd` if this task is executed before Task 5.
- Modify: tests and docs.

- [ ] **Step 1: Move town assets**

Run:

```powershell
New-Item -ItemType Directory -Force -Path 'C:\Users\Mitchell\Documents\mine-platform-v2\assets\town\map' | Out-Null
New-Item -ItemType Directory -Force -Path 'C:\Users\Mitchell\Documents\mine-platform-v2\assets\town\npcs' | Out-Null
Move-Item -LiteralPath 'C:\Users\Mitchell\Documents\mine-platform-v2\assets\mining_economy\town\town_map.png' -Destination 'C:\Users\Mitchell\Documents\mine-platform-v2\assets\town\map\town_map.png'
Move-Item -LiteralPath 'C:\Users\Mitchell\Documents\mine-platform-v2\assets\mining_economy\town\town_map.png.import' -Destination 'C:\Users\Mitchell\Documents\mine-platform-v2\assets\town\map\town_map.png.import'
Move-Item -LiteralPath 'C:\Users\Mitchell\Documents\mine-platform-v2\assets\mining_economy\town\npc_miner_sprites.png' -Destination 'C:\Users\Mitchell\Documents\mine-platform-v2\assets\town\npcs\npc_miner_sprites.png'
Move-Item -LiteralPath 'C:\Users\Mitchell\Documents\mine-platform-v2\assets\mining_economy\town\npc_miner_sprites.png.import' -Destination 'C:\Users\Mitchell\Documents\mine-platform-v2\assets\town\npcs\npc_miner_sprites.png.import'
Move-Item -LiteralPath 'C:\Users\Mitchell\Documents\mine-platform-v2\assets\mining_economy\town\npc_buyer_sprites.png' -Destination 'C:\Users\Mitchell\Documents\mine-platform-v2\assets\town\npcs\npc_buyer_sprites.png'
Move-Item -LiteralPath 'C:\Users\Mitchell\Documents\mine-platform-v2\assets\mining_economy\town\npc_buyer_sprites.png.import' -Destination 'C:\Users\Mitchell\Documents\mine-platform-v2\assets\town\npcs\npc_buyer_sprites.png.import'
Move-Item -LiteralPath 'C:\Users\Mitchell\Documents\mine-platform-v2\assets\mining_economy\town\npc_identifier_sprites.png' -Destination 'C:\Users\Mitchell\Documents\mine-platform-v2\assets\town\npcs\npc_identifier_sprites.png'
Move-Item -LiteralPath 'C:\Users\Mitchell\Documents\mine-platform-v2\assets\mining_economy\town\npc_identifier_sprites.png.import' -Destination 'C:\Users\Mitchell\Documents\mine-platform-v2\assets\town\npcs\npc_identifier_sprites.png.import'
Move-Item -LiteralPath 'C:\Users\Mitchell\Documents\mine-platform-v2\assets\mining_economy\town\npc_task_clerk_sprites.png' -Destination 'C:\Users\Mitchell\Documents\mine-platform-v2\assets\town\npcs\npc_task_clerk_sprites.png'
Move-Item -LiteralPath 'C:\Users\Mitchell\Documents\mine-platform-v2\assets\mining_economy\town\npc_task_clerk_sprites.png.import' -Destination 'C:\Users\Mitchell\Documents\mine-platform-v2\assets\town\npcs\npc_task_clerk_sprites.png.import'
```

- [ ] **Step 2: Remove old town asset folder**

Run:

```powershell
Remove-Item -LiteralPath 'C:\Users\Mitchell\Documents\mine-platform-v2\assets\mining_economy' -Recurse -Force
```

- [ ] **Step 3: Update references**

Replace:

```text
res://assets/mining_economy/town/town_map.png
res://assets/mining_economy/town/npc_miner_sprites.png
res://assets/mining_economy/town/npc_buyer_sprites.png
res://assets/mining_economy/town/npc_identifier_sprites.png
res://assets/mining_economy/town/npc_task_clerk_sprites.png
```

with:

```text
res://assets/town/map/town_map.png
res://assets/town/npcs/npc_miner_sprites.png
res://assets/town/npcs/npc_buyer_sprites.png
res://assets/town/npcs/npc_identifier_sprites.png
res://assets/town/npcs/npc_task_clerk_sprites.png
```

in script, tests, and docs.

- [ ] **Step 4: Verify**

Run import and tests. Expected: town asset tests pass, town smoke starts.

---

### Task 5: Normalize Script Paths

**Files:**
- Move: `Scripts/*` -> `scripts/*`
- Update: `project.godot`, `.tscn`, `.gd`, `.md`, `.tres`, tests.

- [ ] **Step 1: Create target script directories**

Run:

```powershell
New-Item -ItemType Directory -Force -Path scripts\core,scripts\economy,scripts\town,scripts\player,scripts\mine,scripts\enemies,scripts\items,scripts\ui | Out-Null
```

- [ ] **Step 2: Move core and economy**

Run:

```powershell
Move-Item -LiteralPath Scripts\core\* -Destination scripts\core
Move-Item -LiteralPath Scripts\economy\* -Destination scripts\economy
```

- [ ] **Step 3: Move town scripts**

Run:

```powershell
Move-Item -LiteralPath Scripts\town\fused_mining_town_scene.gd -Destination scripts\town\fused_mining_town_scene.gd
Move-Item -LiteralPath Scripts\town\fused_mining_town_scene.gd.uid -Destination scripts\town\fused_mining_town_scene.gd.uid
Move-Item -LiteralPath Scripts\town\mine_exit.gd -Destination scripts\town\mine_exit.gd
Move-Item -LiteralPath Scripts\town\mine_exit.gd.uid -Destination scripts\town\mine_exit.gd.uid
Move-Item -LiteralPath Scripts\mining_economy\ui\town\town_walkable_map.gd -Destination scripts\town\town_walkable_map.gd
Move-Item -LiteralPath Scripts\mining_economy\ui\town\town_walkable_map.gd.uid -Destination scripts\town\town_walkable_map.gd.uid
Move-Item -LiteralPath Scripts\mining_economy\ui\town\town_npc_interactor.gd -Destination scripts\town\town_npc_interactor.gd
Move-Item -LiteralPath Scripts\mining_economy\ui\town\town_npc_interactor.gd.uid -Destination scripts\town\town_npc_interactor.gd.uid
Move-Item -LiteralPath Scripts\mining_economy\ui\town\town_player_controller.gd -Destination scripts\town\town_player_controller.gd
Move-Item -LiteralPath Scripts\mining_economy\ui\town\town_player_controller.gd.uid -Destination scripts\town\town_player_controller.gd.uid
```

- [ ] **Step 4: Move player scripts**

Run:

```powershell
Move-Item -LiteralPath Scripts\player.gd -Destination scripts\player\player.gd
Move-Item -LiteralPath Scripts\player.gd.uid -Destination scripts\player\player.gd.uid
Move-Item -LiteralPath Scripts\playerStats.gd -Destination scripts\player\player_stats.gd
Move-Item -LiteralPath Scripts\playerStats.gd.uid -Destination scripts\player\player_stats.gd.uid
Move-Item -LiteralPath Scripts\move_controller.gd -Destination scripts\player\move_controller.gd
Move-Item -LiteralPath Scripts\move_controller.gd.uid -Destination scripts\player\move_controller.gd.uid
Move-Item -LiteralPath Scripts\health_bar.gd -Destination scripts\ui\health_bar.gd
Move-Item -LiteralPath Scripts\health_bar.gd.uid -Destination scripts\ui\health_bar.gd.uid
Move-Item -LiteralPath Scripts\hotbar_ui.gd -Destination scripts\ui\hotbar_ui.gd
Move-Item -LiteralPath Scripts\hotbar_ui.gd.uid -Destination scripts\ui\hotbar_ui.gd.uid
```

- [ ] **Step 5: Move mine, enemy, and item scripts**

Run:

```powershell
Move-Item -LiteralPath Scripts\mine_interaction.gd -Destination scripts\mine\mine_interaction.gd
Move-Item -LiteralPath Scripts\mine_interaction.gd.uid -Destination scripts\mine\mine_interaction.gd.uid
Move-Item -LiteralPath Scripts\mine_stats.gd -Destination scripts\mine\mine_stats.gd
Move-Item -LiteralPath Scripts\mine_stats.gd.uid -Destination scripts\mine\mine_stats.gd.uid
Move-Item -LiteralPath Scripts\progress_ui.gd -Destination scripts\ui\progress_ui.gd
Move-Item -LiteralPath Scripts\progress_ui.gd.uid -Destination scripts\ui\progress_ui.gd.uid
Move-Item -LiteralPath Scripts\cover.gd -Destination scripts\mine\cover.gd
Move-Item -LiteralPath Scripts\cover.gd.uid -Destination scripts\mine\cover.gd.uid
Move-Item -LiteralPath Scripts\gem_controller.gd -Destination scripts\items\gem_controller.gd
Move-Item -LiteralPath Scripts\gem_controller.gd.uid -Destination scripts\items\gem_controller.gd.uid
Move-Item -LiteralPath Scripts\gem.gd -Destination scripts\items\gem.gd
Move-Item -LiteralPath Scripts\gem.gd.uid -Destination scripts\items\gem.gd.uid
Move-Item -LiteralPath Scripts\inventory_manager.gd -Destination scripts\items\inventory_manager.gd
Move-Item -LiteralPath Scripts\inventory_manager.gd.uid -Destination scripts\items\inventory_manager.gd.uid
Move-Item -LiteralPath Scripts\item_database.gd -Destination scripts\items\item_database.gd
Move-Item -LiteralPath Scripts\item_database.gd.uid -Destination scripts\items\item_database.gd.uid
Move-Item -LiteralPath Scripts\enemy_ai.gd -Destination scripts\enemies\enemy_ai.gd
Move-Item -LiteralPath Scripts\enemy_ai.gd.uid -Destination scripts\enemies\enemy_ai.gd.uid
Move-Item -LiteralPath Scripts\noise_system.gd -Destination scripts\core\noise_system.gd
Move-Item -LiteralPath Scripts\noise_system.gd.uid -Destination scripts\core\noise_system.gd.uid
```

- [ ] **Step 6: Remove empty legacy script directories**

Run:

```powershell
Remove-Item -LiteralPath Scripts -Recurse -Force
```

- [ ] **Step 7: Update all `res://Scripts/` references**

Replace path prefixes according to this mapping:

```text
res://scripts/core/ -> res://scripts/core/
res://scripts/economy/ -> res://scripts/economy/
res://scripts/town/ -> res://scripts/town/
res://scripts/town/ -> res://scripts/town/
res://scripts/player/player.gd -> res://scripts/player/player.gd
res://scripts/player/player_stats.gd -> res://scripts/player/player_stats.gd
res://scripts/player/move_controller.gd -> res://scripts/player/move_controller.gd
res://scripts/ui/health_bar.gd -> res://scripts/ui/health_bar.gd
res://scripts/ui/hotbar_ui.gd -> res://scripts/ui/hotbar_ui.gd
res://scripts/ui/progress_ui.gd -> res://scripts/ui/progress_ui.gd
res://scripts/mine/mine_interaction.gd -> res://scripts/mine/mine_interaction.gd
res://scripts/mine/mine_stats.gd -> res://scripts/mine/mine_stats.gd
res://scripts/mine/cover.gd -> res://scripts/mine/cover.gd
res://scripts/items/gem_controller.gd -> res://scripts/items/gem_controller.gd
res://scripts/items/gem.gd -> res://scripts/items/gem.gd
res://scripts/items/inventory_manager.gd -> res://scripts/items/inventory_manager.gd
res://scripts/items/item_database.gd -> res://scripts/items/item_database.gd
res://scripts/enemies/enemy_ai.gd -> res://scripts/enemies/enemy_ai.gd
res://scripts/core/noise_system.gd -> res://scripts/core/noise_system.gd
```

Update these file families:

```text
project.godot
Scene/*.tscn
scenes/**/*.tscn
scripts/**/*.gd
tests/**/*.gd
docs/**/*.md
```

- [ ] **Step 8: Verify**

Run import, fusion tests, town smoke, mine smoke. Expected: tests pass and no `res://Scripts/` references remain outside migration docs.

---

### Task 6: Normalize Scene Paths

**Files:**
- Move: `Scene/*` -> `scenes/mine/*`
- Modify: `project.godot`, scenes, scripts, tests, docs.

- [ ] **Step 1: Create target mine scene directories**

Run:

```powershell
New-Item -ItemType Directory -Force -Path scenes\mine\gems | Out-Null
```

- [ ] **Step 2: Move mine scenes**

Run:

```powershell
Move-Item -LiteralPath Scene\test_scene.tscn -Destination scenes\mine\test_scene.tscn
Move-Item -LiteralPath Scene\main_character_stats.tscn -Destination scenes\mine\main_character_stats.tscn
Move-Item -LiteralPath Scene\small_mine.tscn -Destination scenes\mine\small_mine.tscn
Move-Item -LiteralPath Scene\cover.tscn -Destination scenes\mine\cover.tscn
Move-Item -LiteralPath Scene\enemy.tscn -Destination scenes\mine\enemy.tscn
Move-Item -LiteralPath Scene\gem_abstract.tscn -Destination scenes\mine\gems\gem_abstract.tscn
Move-Item -LiteralPath Scene\Gem_L1.tscn -Destination scenes\mine\gems\gem_l1.tscn
Move-Item -LiteralPath Scene\Gem_L2.tscn -Destination scenes\mine\gems\gem_l2.tscn
Move-Item -LiteralPath Scene\Gem_L3.tscn -Destination scenes\mine\gems\gem_l3.tscn
Remove-Item -LiteralPath Scene -Recurse -Force
```

- [ ] **Step 3: Update scene references**

Replace:

```text
res://scenes/mine/test_scene.tscn -> res://scenes/mine/test_scene.tscn
res://scenes/mine/main_character_stats.tscn -> res://scenes/mine/main_character_stats.tscn
res://scenes/mine/small_mine.tscn -> res://scenes/mine/small_mine.tscn
res://scenes/mine/cover.tscn -> res://scenes/mine/cover.tscn
res://scenes/mine/enemy.tscn -> res://scenes/mine/enemy.tscn
res://scenes/mine/gems/gem_abstract.tscn -> res://scenes/mine/gems/gem_abstract.tscn
res://scenes/mine/gems/gem_l1.tscn -> res://scenes/mine/gems/gem_l1.tscn
res://scenes/mine/gems/gem_l2.tscn -> res://scenes/mine/gems/gem_l2.tscn
res://scenes/mine/gems/gem_l3.tscn -> res://scenes/mine/gems/gem_l3.tscn
```

Update:

```text
scenes/mine/*.tscn
scenes/mine/gems/*.tscn
scenes/town/mining_town.tscn
scripts/**/*.gd
tests/**/*.gd
docs/**/*.md
```

- [ ] **Step 4: Verify**

Run import, fusion tests, town smoke, and mine smoke with:

```powershell
& 'C:\Users\Mitchell\Documents\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'C:\Users\Mitchell\Documents\mine-platform-v2' res://scenes/mine/test_scene.tscn --quit-after 3
```

Expected: mine starts with the original GJ nodes present.

---

### Task 7: Normalize GJ Art Paths

**Files:**
- Move: `art/main_Char/*` -> `assets/gj/characters/player/*`
- Move: `art/monster/*` -> `assets/gj/enemies/gnoll/*`
- Move: `art/enivorment/*` -> `assets/gj/environment/*`
- Move: `assets/gj/characters/player/main_char_sprite_frames.tres` -> `assets/gj/characters/player/main_char_sprite_frames.tres`
- Modify: all scenes, scripts, tests, docs.

- [ ] **Step 1: Create target asset directories**

Run:

```powershell
New-Item -ItemType Directory -Force -Path assets\gj\characters\player,assets\gj\enemies\gnoll,assets\gj\environment | Out-Null
```

- [ ] **Step 2: Move player art**

Run:

```powershell
Move-Item -LiteralPath art\main_Char\* -Destination assets\gj\characters\player
Move-Item -LiteralPath art\mainChar_sprite_frames.tres -Destination assets\gj\characters\player\main_char_sprite_frames.tres
```

- [ ] **Step 3: Move enemy and environment art**

Run:

```powershell
Move-Item -LiteralPath art\monster\* -Destination assets\gj\enemies\gnoll
Move-Item -LiteralPath art\enivorment\* -Destination assets\gj\environment
Remove-Item -LiteralPath art -Recurse -Force
```

- [ ] **Step 4: Update art references**

Replace prefixes:

```text
res://assets/gj/characters/player/ -> res://assets/gj/characters/player/
res://assets/gj/enemies/gnoll/ -> res://assets/gj/enemies/gnoll/
res://assets/gj/environment/ -> res://assets/gj/environment/
res://assets/gj/characters/player/main_char_sprite_frames.tres -> res://assets/gj/characters/player/main_char_sprite_frames.tres
```

Update:

```text
assets/gj/characters/player/main_char_sprite_frames.tres
scenes/**/*.tscn
scripts/**/*.gd
tests/**/*.gd
docs/**/*.md
```

- [ ] **Step 5: Verify**

Run import, fusion tests, town smoke, and mine smoke.

Expected:

- GJ player sprite frames load.
- Enemy sprite frames load.
- Mine TileMaps load.
- Gems and cover sprites load.
- No `res://art/` references remain outside migration docs.

---

### Task 8: Update Documentation And Cleanup Empty Folders

**Files:**
- Modify: `docs/PROJECT_CONTEXT.md`
- Modify: `docs/fusion_v2_implementation_summary.md`
- Modify: `.gitignore` if needed

- [ ] **Step 1: Update `docs/PROJECT_CONTEXT.md`**

Update the top section to:

```markdown
> Main scene: `res://scenes/town/mining_town.tscn`.
> Mine scene: `res://scenes/mine/test_scene.tscn`.
> 主场景：`res://scenes/town/mining_town.tscn`
> 矿洞场景：`res://scenes/mine/test_scene.tscn`
```

Update paths in the document to the normalized layout:

```text
res://scripts/
res://assets/gj/
res://assets/town/
res://assets/props/
res://scenes/mine/
```

- [ ] **Step 2: Update `docs/fusion_v2_implementation_summary.md`**

Set current project section to:

```markdown
- Main scene: `res://scenes/town/mining_town.tscn`
- GJ mine scene: `res://scenes/mine/test_scene.tscn`
- Runtime autoload: `GameRuntime` -> `res://scripts/core/game_runtime.gd`
- AI context doc: `res://docs/PROJECT_CONTEXT.md`
```

- [ ] **Step 3: Check `.gitignore`**

Ensure `.gitignore` includes:

```gitignore
.godot/
*.tmp
```

Do not ignore `.import` files unless the project policy explicitly changes; Godot projects normally keep source `.import` metadata with assets.

- [ ] **Step 4: Remove empty directories**

Run:

```powershell
Get-ChildItem -Directory -Recurse | Sort-Object FullName -Descending | Where-Object { -not (Get-ChildItem -Force -LiteralPath $_.FullName) } | Remove-Item -Force
```

- [ ] **Step 5: Verify docs and stale paths**

Run:

```powershell
rg -n "res://Scene/|res://Scripts/|res://art/|res://assets/mining_economy|res://assets/fusion|res://PROJECT_CONTEXT.md" project.godot scenes scripts assets data docs tests -g "*.gd" -g "*.tscn" -g "*.tres" -g "*.godot" -g "*.md" -g "*.json"
```

Expected: no output except this migration plan if the command includes `docs/superpowers/plans`.

---

### Task 9: Final Verification

**Files:**
- No source changes expected unless verification reveals stale references.

- [ ] **Step 1: Run full regression**

Run:

```powershell
& 'C:\Users\Mitchell\Documents\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'C:\Users\Mitchell\Documents\mine-platform-v2' -s res://tests/fusion/run_all.gd
```

Expected:

```text
RESULT: PASS
```

- [ ] **Step 2: Run Godot import**

Run:

```powershell
& 'C:\Users\Mitchell\Documents\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'C:\Users\Mitchell\Documents\mine-platform-v2' --import
```

Expected: exit code `0`, no missing resource errors.

- [ ] **Step 3: Smoke start town**

Run:

```powershell
& 'C:\Users\Mitchell\Documents\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'C:\Users\Mitchell\Documents\mine-platform-v2' --quit-after 3
```

Expected: exit code `0`.

- [ ] **Step 4: Smoke start mine**

Run:

```powershell
& 'C:\Users\Mitchell\Documents\Godot\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'C:\Users\Mitchell\Documents\mine-platform-v2' res://scenes/mine/test_scene.tscn --quit-after 3
```

Expected: exit code `0`; GJ inventory initialization logs are acceptable.

- [ ] **Step 5: Final top-level check**

Run:

```powershell
Get-ChildItem -Force | Select-Object Mode,Name
```

Expected source-facing top level:

```text
.godot
addons
assets
data
docs
scenes
scripts
tests
.editorconfig
.gitattributes
.gitignore
project.godot
```

No top-level `Scene`, `Scripts`, `art`, or `PROJECT_CONTEXT.md`.

---

## Self-Review

- Spec coverage: Covers outer cleanliness, conventional single-root Godot layout, scene/script/art/data/doc migration, and verification.
- Risk management: High-risk GJ path moves are delayed until after low-risk docs/assets/script migration. Each task has a verification stop.
- No placeholders: Every task has exact source paths, target paths, replacement mappings, and commands.
- Known risk: Godot UID metadata may update during import; preserve `.uid` files when moving scripts and rely on import/tests for validation.
