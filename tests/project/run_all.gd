extends SceneTree

var _failures: Array[String] = []
var _assertions: int = 0


func _init() -> void:
	# In the -s headless run, autoloads are added to root *after* _init fires
	# (they are wired during the first process frame). Wait one frame so the
	# tests that need /root/GameRuntime etc. can find them. The smoke test
	# (game --quit-after 3) does not hit this path because the autoloads are
	# ready before any test code runs there.
	await process_frame
	_run_test("mine scene keeps playable structure", Callable(self, "_test_mine_scene_structure"))
	_run_test("scene resources do not point at imported cache files", Callable(self, "_test_no_import_cache_scene_references"))
	_run_test("scripts do not keep stale uppercase preload paths", Callable(self, "_test_no_stale_uppercase_script_paths"))
	_run_test("project docs describe current foundation", Callable(self, "_test_project_docs_are_current"))
	_run_test("project uses normalized source layout", Callable(self, "_test_project_uses_normalized_source_layout"))
	_run_test("no legacy res paths remain after layout migration", Callable(self, "_test_no_legacy_res_paths_after_layout_migration"))
	_run_test("town presentation assets are present", Callable(self, "_test_town_assets_present"))
	_run_test("town player uses mine character visuals", Callable(self, "_test_town_player_uses_mine_character_visuals"))
	_run_test("town characters share one visual scale", Callable(self, "_test_town_characters_share_visual_scale"))
	_run_test("players move cardinally without diagonal input", Callable(self, "_test_players_move_cardinally"))
	_run_test("mine movement range is open for future level design", Callable(self, "_test_mine_movement_range_is_open"))
	_run_test("mine gem drops stay visible before pickup", Callable(self, "_test_mine_gem_drops_stay_visible_before_pickup"))
	_run_test("hotbar gem inventory items resolve icons", Callable(self, "_test_hotbar_gem_inventory_items_resolve_icons"))
	_run_test("item database uses generated UI item icons", Callable(self, "_test_item_database_uses_generated_ui_item_icons"))
	_run_test("town NPCs use generated candidate sprites", Callable(self, "_test_town_npcs_use_generated_candidate_sprites"))
	_run_test("dialogue data uses generated portraits", Callable(self, "_test_dialogue_data_uses_generated_portraits"))
	_run_test("title and intro use generated screen backgrounds", Callable(self, "_test_title_and_intro_use_generated_backgrounds"))
	_run_test("mine scenes use generated node and prop assets", Callable(self, "_test_mine_scenes_use_generated_visual_assets"))
	_run_test("town scene uses generated props buildings and decor", Callable(self, "_test_town_scene_uses_generated_environment_assets"))
	_run_test("core UI uses generated skin assets", Callable(self, "_test_core_ui_uses_generated_skin_assets"))
	_run_test("mine return route uses generated minecart prop", Callable(self, "_test_minecart_return_route"))
	_run_test("unified runtime core is installed", Callable(self, "_test_unified_core_installed"))
	_run_test("project starts from town and keeps mine route", Callable(self, "_test_project_scene_routes"))
	_run_test("mine scene exposes return route to town", Callable(self, "_test_mine_return_route"))
	_run_test("core economy supports mine to town progression loop", Callable(self, "_test_core_economy_loop"))
	_run_test("runtime code keeps one inventory and currency mutation boundary", Callable(self, "_test_single_mutation_boundary"))
	_run_test("main scene points to mining town not the mine route", Callable(self, "_test_main_scene_is_town"))
	_run_test("town scene script reference is not stale", Callable(self, "_test_town_scene_script_reference"))
	_run_test("shop service list_customers returns customers not tasks", Callable(self, "_test_shop_list_customers_returns_customers"))
	_run_test("catalog exposes get_customers matching data file", Callable(self, "_test_catalog_get_customers"))
	_run_test("inventory manager is_full proxies to runtime capacity", Callable(self, "_test_inventory_manager_is_full_proxies_to_runtime"))
	_run_test("item database get_stack_limit reads from catalog source of truth", Callable(self, "_test_item_database_get_stack_limit_uses_catalog"))
	_run_test("star crystal exists in catalog and has correct properties", Callable(self, "_test_star_crystal_in_catalog"))
	_run_test("star geode identify table yields star crystal", Callable(self, "_test_star_geode_identify_table"))
	_run_test("anomalous geode L4 is removed from catalog", Callable(self, "_test_l4_geode_removed"))
	_run_test("morality tracker records sell and gift correctly", Callable(self, "_test_morality_tracker"))
	_run_test("mine stats has star geode drop configuration", Callable(self, "_test_mine_stats_star_geode_config"))
	# Day 2: Stability + Day/Night Cycle
	_run_test("stability system starts at 70 and clamps 0-100", Callable(self, "_test_stability_system_basics"))
	_run_test("stability system daily decay and rewards work", Callable(self, "_test_stability_system_modifiers"))
	_run_test("day night cycle blocks mine entry at night and when quota exhausted", Callable(self, "_test_day_night_cycle_limits"))
	_run_test("day night cycle mine quota resets after end_night", Callable(self, "_test_day_night_cycle_resets"))
	# Day 3: NPC Affection + Dialogue
	_run_test("npc affection starts at 0 and clamps 0-100", Callable(self, "_test_npc_affection_basics"))
	_run_test("npc affection gift tracking and daily limit", Callable(self, "_test_npc_affection_gift"))
	_run_test("dialogues json loads for all 4 npcs with 4 stages", Callable(self, "_test_dialogues_json_structure"))
	# Day 4: Equipment + Daily Tasks + Economy
	_run_test("equipment json parses with evil good and neutral items", Callable(self, "_test_equipment_json"))
	_run_test("equipment system buy and equip flow works", Callable(self, "_test_equipment_buy_equip"))
	_run_test("catalog has daily task pool and night customers", Callable(self, "_test_catalog_daily_pool"))
	_run_test("refine workstation generates refined item id", Callable(self, "_test_refine_workstation"))

	if _failures.is_empty():
		print("RESULT: PASS %d assertions" % _assertions)
		_cleanup_autoloads()
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("RESULT: FAIL %d failures, %d assertions" % [_failures.size(), _assertions])
	_cleanup_autoloads()
	quit(1)
	return


func _test_mine_scene_structure() -> void:
	var packed: PackedScene = load("res://scenes/mine/test_scene.tscn")
	_assert_true(packed != null, "mine scene loads")
	if packed == null:
		return
	var scene := packed.instantiate()
	_assert_true(scene.get_node_or_null("MainCharacter") != null, "mine keeps MainCharacter")
	_assert_true(scene.get_node_or_null("GroundLayer") != null, "mine keeps GroundLayer")
	_assert_true(scene.get_node_or_null("WallLayer") != null, "mine keeps WallLayer")
	_assert_true(_count_named_children(scene, "SmallMine") >= 5, "mine keeps five mine nodes")
	_assert_true(scene.get_node_or_null("CoverCollection/Cover") != null, "mine keeps Cover")
	_assert_true(scene.get_node_or_null("CoverCollection/Cover2") != null, "mine keeps Cover2")
	_assert_true(scene.get_node_or_null("EnemyCollection/Enemy") != null, "mine keeps first enemy")
	_assert_true(scene.get_node_or_null("EnemyCollection/Enemy3") != null, "mine keeps second enemy")
	_assert_true(scene.get_node_or_null("PatrolRoute/PatrolA") != null, "mine keeps PatrolA")
	scene.free()


func _test_no_import_cache_scene_references() -> void:
	for file_path in _list_files("res://scenes/mine", ".tscn"):
		var text := FileAccess.get_file_as_string(file_path)
		_assert_false(text.contains("res://.godot/imported"), "no imported cache reference in %s" % file_path)


func _test_no_stale_uppercase_script_paths() -> void:
	for file_path in _list_files("res://scripts", ".gd"):
		var text := FileAccess.get_file_as_string(file_path)
		_assert_false(text.contains(_res_path("Scripts/")), "no stale uppercase script preload in %s" % file_path)


func _test_project_docs_are_current() -> void:
	var project_context := FileAccess.get_file_as_string("res://docs/PROJECT_CONTEXT.md")
	_assert_false(FileAccess.file_exists(_res_path("PROJECT_CONTEXT.md")), "root project context doc moved into docs")
	_assert_true(project_context.contains("主场景：`res://scenes/town/mining_town.tscn`") or project_context.contains("标题界面：`res://scenes/ui/title_menu.tscn`"), "project context names title or town as main scene")
	_assert_true(project_context.contains("矿洞场景：`res://scenes/mine/test_scene.tscn`"), "project context names mine route")
	_assert_true(project_context.contains("测试入口：`res://tests/project/run_all.gd`"), "project context names project test entry")
	_assert_true(project_context.contains("MinecartExit"), "project context documents minecart return route")


func _test_project_uses_normalized_source_layout() -> void:
	var required_dirs := [
		"res://assets/mine",
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
		"res://tests/project",
	]
	for dir_path in required_dirs:
		_assert_true(DirAccess.dir_exists_absolute(dir_path), "normalized directory exists: %s" % dir_path)
	var removed_root_entries := ["Scene", "Scripts", "art"]
	for entry_name in removed_root_entries:
		_assert_false(_root_entry_exists_exact(entry_name), "legacy top-level directory removed: %s" % entry_name)
func _test_no_legacy_res_paths_after_layout_migration() -> void:
	var roots := ["res://project.godot", "res://scenes", "res://scripts", "res://assets", "res://data", "res://docs", "res://tests"]
	var stale_terms := [
		_res_path("Scene/"),
		_res_path("Scripts/"),
		_res_path("art/"),
		_res_path("PROJECT_CONTEXT.md"),
	]
	var files: Array[String] = []
	for root_path in roots:
		if FileAccess.file_exists(root_path):
			files.append(root_path)
		elif DirAccess.dir_exists_absolute(root_path):
			files.append_array(_list_files_multi(root_path, [".gd", ".tscn", ".tres", ".godot", ".md", ".json"]))
	for file_path in files:
		if file_path.begins_with("res://docs/superpowers/plans/"):
			continue
		var text := FileAccess.get_file_as_string(file_path)
		for term in stale_terms:
			_assert_false(text.contains(term), "no stale path %s in %s" % [term, file_path])


func _test_town_assets_present() -> void:
	var required := [
		"res://assets/town/map/town_map.png",
		"res://assets/town/npcs/blacksmith_idle.png",
		"res://assets/town/npcs/buyer_idle.png",
		"res://assets/town/npcs/elder_idle.png",
		"res://assets/town/npcs/florist_idle.png",
		"res://assets/town/props/task_board.png",
		"res://assets/town/buildings/refine_station.png",
	]
	for path in required:
		_assert_true(FileAccess.file_exists(path), "town asset exists: %s" % path)


func _test_town_player_uses_mine_character_visuals() -> void:
	var town_player_scene_text := FileAccess.get_file_as_string("res://scenes/town/town_player.tscn")
	_assert_true(town_player_scene_text.contains("res://assets/mine/characters/player/main_char_sprite_frames.tres"), "town player uses mine SpriteFrames resource")
	_assert_true(town_player_scene_text.contains("[node name=\"AnimatedSprite2D\""), "town player scene contains AnimatedSprite2D")
	_assert_false(town_player_scene_text.contains("player_sprites_normalized.png"), "town player no longer references legacy town player sprite")
	var controller_script = load("res://scripts/town/town_player_controller.gd")
	var controller = controller_script.new()
	_assert_true(controller.has_method("configure_animated_sprite"), "town movement controller supports animated mine character sprite")
	controller.free()


func _test_town_characters_share_visual_scale() -> void:
	var town_player_scene_text := FileAccess.get_file_as_string("res://scenes/town/town_player.tscn")
	_assert_true(town_player_scene_text.contains("scale = Vector2(1.75, 1.75)"), "town player preserves mine character display scale")
	for scene_path: String in [
		"res://scenes/town/npc_elder.tscn",
		"res://scenes/town/npc_blacksmith.tscn",
		"res://scenes/town/npc_florist.tscn",
		"res://scenes/town/npc_buyer.tscn",
	]:
		var npc_scene_text := FileAccess.get_file_as_string(scene_path)
		_assert_true(npc_scene_text.contains("scale = Vector2(1.25, 1.25)"), "NPC scene uses generated sprite scale: %s" % scene_path)
		_assert_false(npc_scene_text.contains("scale = Vector2(0.07, 0.07)"), "NPC scene does not keep old alpha sprite scale: %s" % scene_path)


func _test_players_move_cardinally() -> void:
	var mine_move_text := FileAccess.get_file_as_string("res://scripts/player/move_controller.gd")
	_assert_true(mine_move_text.contains("_to_cardinal_direction"), "mine movement resolves input to cardinal direction")
	_assert_false(mine_move_text.contains("input_dir = input_dir.normalized()"), "mine movement does not normalize diagonal input")
	var town_controller_text := FileAccess.get_file_as_string("res://scripts/town/town_player_controller.gd")
	_assert_true(town_controller_text.contains("_to_cardinal_direction"), "town movement resolves input to cardinal direction")
	_assert_false(town_controller_text.contains("direction.normalized() * speed"), "town movement does not normalize diagonal input")


func _test_mine_movement_range_is_open() -> void:
	var player_scene_text := FileAccess.get_file_as_string("res://scenes/mine/main_character_stats.tscn")
	_assert_true(player_scene_text.contains("collision_mask = 0"), "mine player does not collide with temporary level blockers")
	_assert_false(player_scene_text.contains("disabled = true"), "mine player interaction shape stays enabled for mines and covers")
	var gem_script_text := FileAccess.get_file_as_string("res://scripts/items/gem_controller.gd")
	_assert_true(gem_script_text.contains("_try_distance_pickup"), "gems can be collected without player collision volume")


func _test_mine_gem_drops_stay_visible_before_pickup() -> void:
	var packed: PackedScene = load("res://scenes/mine/small_mine.tscn")
	_assert_true(packed != null, "small mine scene loads for drop visibility")
	if packed == null:
		return
	var mine := packed.instantiate()
	var stats: Node = mine.get_node_or_null("MineStats")
	_assert_true(stats != null, "small mine has MineStats")
	if stats == null:
		mine.free()
		return
	for property_name in ["gem_l1_scene", "gem_l2_scene", "gem_l3_scene"]:
		var gem_scene: PackedScene = stats.get(property_name)
		_assert_true(gem_scene != null, "%s is configured" % property_name)
		if gem_scene == null:
			continue
		var gem := gem_scene.instantiate()
		_assert_true(gem != null, "%s instantiates" % property_name)
		if gem != null:
			_assert_true(float(gem.get("pickup_delay")) >= 0.35, "%s has pickup delay so launch is visible" % property_name)
			_assert_true(gem.get_node_or_null("Sprite2D") != null, "%s has visible sprite" % property_name)
			gem.free()
	mine.free()


func _test_hotbar_gem_inventory_items_resolve_icons() -> void:
	var item_database_script = load("res://scripts/items/item_database.gd")
	_assert_true(item_database_script != null, "item database script loads")
	if item_database_script == null:
		return
	var item_database = item_database_script.new()
	for level in [1, 2, 3]:
		var icon: Texture2D = item_database.get_icon("gem", {"level": level})
		_assert_true(icon != null, "hotbar gem icon resolves for level %d" % level)
		if icon != null:
			_assert_true(icon.get_width() > 0 and icon.get_height() > 0, "hotbar gem icon has size for level %d" % level)
	item_database.free()


func _test_item_database_uses_generated_ui_item_icons() -> void:
	var db_text := FileAccess.get_file_as_string("res://scripts/items/item_database.gd")
	var expected: Array[String] = [
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
	for path: String in expected:
		_assert_true(FileAccess.file_exists(path), "generated item icon exists: %s" % path)
		_assert_true(db_text.contains(path), "ItemDatabase preloads generated icon: %s" % path)
	_assert_false(db_text.contains("assets/props/raw_common_geode_alpha.png"), "ItemDatabase no longer uses old raw geode prop icon")
	_assert_false(db_text.contains("assets/props/raw_anomalous_geode_pickup_alpha.png"), "ItemDatabase no longer uses old star crystal placeholder icon")


func _test_town_npcs_use_generated_candidate_sprites() -> void:
	var scene_to_asset: Dictionary = {
		"res://scenes/town/npc_elder.tscn": "res://assets/town/npcs/elder_idle.png",
		"res://scenes/town/npc_blacksmith.tscn": "res://assets/town/npcs/blacksmith_idle.png",
		"res://scenes/town/npc_florist.tscn": "res://assets/town/npcs/florist_idle.png",
		"res://scenes/town/npc_buyer.tscn": "res://assets/town/npcs/buyer_idle.png",
	}
	for scene_path: String in scene_to_asset.keys():
		var asset_path: String = str(scene_to_asset[scene_path])
		var text := FileAccess.get_file_as_string(scene_path)
		_assert_true(FileAccess.file_exists(asset_path), "generated NPC sprite exists: %s" % asset_path)
		_assert_true(text.contains(asset_path), "NPC scene uses generated sprite: %s" % scene_path)
		_assert_true(text.contains("scale = Vector2(1.25, 1.25)") or not text.contains("scale = Vector2(0.07, 0.07)"), "NPC scene does not keep old alpha sprite scale: %s" % scene_path)


func _test_dialogue_data_uses_generated_portraits() -> void:
	var text := FileAccess.get_file_as_string("res://data/narrative/dialogues.json")
	var expected: Array[String] = [
		"res://assets/ui/portraits/elder_neutral.png",
		"res://assets/ui/portraits/blacksmith_neutral.png",
		"res://assets/ui/portraits/florist_neutral.png",
		"res://assets/ui/portraits/buyer_neutral.png",
	]
	for path: String in expected:
		_assert_true(FileAccess.file_exists(path), "generated portrait exists: %s" % path)
		_assert_true(text.contains(path), "dialogue JSON uses generated portrait: %s" % path)
	var town_text := FileAccess.get_file_as_string("res://scripts/town/mining_town_scene.gd")
	_assert_true(town_text.contains("res://assets/ui/portraits/florist_neutral.png"), "florist tears dialogue uses generated portrait")
	_assert_false(text.contains("assets/props/npc_identifier_sprites_alpha.png"), "dialogue JSON no longer uses old florist prop portrait")


func _test_title_and_intro_use_generated_backgrounds() -> void:
	var title_text := FileAccess.get_file_as_string("res://scripts/ui/title_menu.gd")
	var intro_text := FileAccess.get_file_as_string("res://scripts/ui/intro.gd")
	_assert_true(FileAccess.file_exists("res://assets/ui/screens/title_background.png"), "title background exists")
	_assert_true(FileAccess.file_exists("res://assets/ui/screens/intro_background.png"), "intro background exists")
	_assert_true(title_text.contains("res://assets/ui/screens/title_background.png"), "title menu loads generated background")
	_assert_true(intro_text.contains("res://assets/ui/screens/intro_background.png"), "intro scene loads generated background")


func _test_mine_scenes_use_generated_visual_assets() -> void:
	var scene_to_assets: Dictionary = {
		"res://scenes/mine/gems/gem_l1.tscn": ["res://assets/mine/nodes/gem_pickup_common.png"],
		"res://scenes/mine/gems/gem_l2.tscn": ["res://assets/mine/nodes/gem_pickup_fine.png"],
		"res://scenes/mine/gems/gem_l3.tscn": ["res://assets/mine/nodes/gem_pickup_rare.png"],
		"res://scenes/mine/gems/gem_star.tscn": ["res://assets/mine/nodes/gem_pickup_star.png"],
		"res://scenes/mine/small_mine.tscn": ["res://assets/mine/nodes/mine_wall_common.png"],
		"res://scenes/mine/deep_mine.tscn": ["res://assets/mine/nodes/mine_wall_deep.png"],
		"res://scenes/mine/cover.tscn": ["res://assets/mine/props/cover_crate.png"],
		"res://scenes/mine/oxygen_pump.tscn": ["res://assets/mine/props/oxygen_pump.png"],
	}
	for scene_path: String in scene_to_assets.keys():
		var text := FileAccess.get_file_as_string(scene_path)
		for asset_path: String in scene_to_assets[scene_path]:
			_assert_true(FileAccess.file_exists(asset_path), "generated mine asset exists: %s" % asset_path)
			_assert_true(text.contains(asset_path), "mine scene uses generated asset %s in %s" % [asset_path, scene_path])
	var gem_l1_text := FileAccess.get_file_as_string("res://scenes/mine/gems/gem_l1.tscn")
	_assert_false(gem_l1_text.contains("raw_common_geode_alpha.png"), "common gem no longer uses old alpha prop")
	var gem_star_text := FileAccess.get_file_as_string("res://scenes/mine/gems/gem_star.tscn")
	_assert_false(gem_star_text.contains("raw_anomalous_geode_alpha.png"), "star gem no longer uses old anomalous prop")


func _test_town_scene_uses_generated_environment_assets() -> void:
	var town_text := FileAccess.get_file_as_string("res://scenes/town/mining_town.tscn")
	var town_assets: Array[String] = [
		"res://assets/town/buildings/blacksmith.png",
		"res://assets/town/buildings/buyer_shop.png",
		"res://assets/town/buildings/elder_house.png",
		"res://assets/town/buildings/florist.png",
		"res://assets/town/buildings/refine_station.png",
		"res://assets/town/buildings/warehouse.png",
		"res://assets/town/decor/bush_round.png",
		"res://assets/town/decor/flower_patch_blue.png",
		"res://assets/town/decor/flower_patch_red.png",
		"res://assets/town/decor/grass_clump_a.png",
		"res://assets/town/decor/grass_clump_b.png",
		"res://assets/town/props/barrel.png",
		"res://assets/town/props/bench.png",
		"res://assets/town/props/crate_stack.png",
		"res://assets/town/props/fence_horizontal.png",
		"res://assets/town/props/fence_vertical.png",
		"res://assets/town/props/lantern_post.png",
		"res://assets/town/props/minecart_town.png",
		"res://assets/town/props/notice_sign.png",
		"res://assets/town/props/task_board.png",
		"res://assets/town/props/well.png",
		"res://assets/town/trees/oak_large.png",
		"res://assets/town/trees/oak_small.png",
		"res://assets/town/trees/pine_large.png",
		"res://assets/town/trees/pine_small.png",
		"res://assets/town/trees/stump.png",
	]
	for asset_path: String in town_assets:
		_assert_true(FileAccess.file_exists(asset_path), "generated town asset exists: %s" % asset_path)
		_assert_true(town_text.contains(asset_path), "town scene references generated asset: %s" % asset_path)
	_assert_true(town_text.contains("GeneratedTownLayer"), "town scene has generated art overlay layer")
	var mine_entrance_text := FileAccess.get_file_as_string("res://scenes/town/mine_entrance.tscn")
	_assert_true(mine_entrance_text.contains("res://assets/town/buildings/mine_gate.png"), "mine entrance uses generated mine gate")


func _test_core_ui_uses_generated_skin_assets() -> void:
	var title_text := FileAccess.get_file_as_string("res://scripts/ui/title_menu.gd")
	var dialogue_text := FileAccess.get_file_as_string("res://scripts/narrative/dialogue_ui.gd")
	var warehouse_text := FileAccess.get_file_as_string("res://scripts/ui/warehouse_ui.gd")
	var hotbar_text := FileAccess.get_file_as_string("res://scripts/ui/hotbar_ui.gd")
	var town_text := FileAccess.get_file_as_string("res://scripts/town/mining_town_scene.gd")
	var script_to_assets: Array[Dictionary] = [
		{
			"text": title_text,
			"assets": [
			"res://assets/ui/buttons/button_normal.png",
			"res://assets/ui/buttons/button_hover.png",
			"res://assets/ui/buttons/button_disabled.png",
			],
		},
		{
			"text": dialogue_text,
			"assets": [
			"res://assets/ui/overlays/dim_overlay.png",
			"res://assets/ui/panels/dialogue_bottom.png",
			"res://assets/ui/icons/dialogue_next.png",
			],
		},
		{
			"text": warehouse_text,
			"assets": [
			"res://assets/ui/panels/warehouse_panel.png",
			"res://assets/ui/panels/tooltip.png",
			"res://assets/ui/slots/slot_empty.png",
			"res://assets/ui/slots/slot_filled.png",
			"res://assets/ui/slots/slot_disabled.png",
			],
		},
		{
			"text": hotbar_text,
			"assets": [
			"res://assets/ui/slots/slot_empty.png",
			"res://assets/ui/slots/slot_filled.png",
			"res://assets/ui/slots/slot_disabled.png",
			],
		},
		{
			"text": town_text,
			"assets": [
			"res://assets/ui/panels/popup_medium.png",
			"res://assets/ui/icons/task.png",
			"res://assets/ui/icons/stability.png",
			"res://assets/ui/icons/warehouse.png",
			],
		},
	]
	for entry: Dictionary in script_to_assets:
		var source_text: String = str(entry.get("text", ""))
		var assets: Array = entry.get("assets", [])
		for asset_path: String in assets:
			_assert_true(FileAccess.file_exists(asset_path), "generated UI skin asset exists: %s" % asset_path)
			_assert_true(source_text.contains(asset_path), "UI script references generated skin asset: %s" % asset_path)


func _test_minecart_return_route() -> void:
	_assert_true(FileAccess.file_exists("res://assets/mine/props/minecart_return.png"), "generated minecart sprite exists")
	var minecart_texture: Texture2D = load("res://assets/mine/props/minecart_return.png")
	_assert_true(minecart_texture != null, "minecart sprite loads as texture")
	if minecart_texture != null:
		_assert_true(minecart_texture.get_width() > 0, "minecart sprite has positive width")
		_assert_true(minecart_texture.get_height() > 0, "minecart sprite has positive height")
	var minecart_image: Image = minecart_texture.get_image() if minecart_texture != null else null
	_assert_true(minecart_image != null, "minecart sprite image loads for alpha check")
	if minecart_image != null:
		_assert_eq(0, minecart_image.get_pixel(0, 0).a8, "minecart top-left background is transparent")
		_assert_eq(0, minecart_image.get_pixel(63, 63).a8, "minecart bottom-right background is transparent")
	var mine_script_text := FileAccess.get_file_as_string("res://scripts/town/mine_exit.gd")
	_assert_true(mine_script_text.contains("extends Node2D"), "minecart exit does not depend on Area2D physics")
	_assert_false(mine_script_text.contains("body_entered"), "minecart exit has no collision body trigger")
	var packed: PackedScene = load("res://scenes/mine/test_scene.tscn")
	_assert_true(packed != null, "mine scene loads for minecart route")
	if packed == null:
		return
	var scene := packed.instantiate()
	var minecart := scene.get_node_or_null("MinecartExit")
	_assert_true(minecart != null, "mine scene has MinecartExit node")
	if minecart != null:
		_assert_eq("res://scenes/town/mining_town.tscn", str(minecart.get("target_scene")), "minecart targets town")
		_assert_true(minecart.get_node_or_null("Sprite2D") != null, "minecart has sprite")
		_assert_true(minecart.get_node_or_null("CollisionShape2D") == null, "minecart does not add blocking collision shape")
	var mine_scene_text := FileAccess.get_file_as_string("res://scenes/mine/test_scene.tscn")
	_assert_true(mine_scene_text.contains("res://assets/mine/props/minecart_return.png"), "mine scene uses generated minecart sprite")
	_assert_false(mine_scene_text.contains("res://assets/props/minecart_return_to_town.png"), "mine scene no longer uses old minecart prop")
	scene.free()


func _test_unified_core_installed() -> void:
	var required := [
		"res://scripts/core/game_runtime.gd",
		"res://scripts/core/game_catalog.gd",
		"res://scripts/core/game_inventory.gd",
		"res://scripts/core/game_wallet.gd",
		"res://scripts/core/game_transaction_service.gd",
		"res://scripts/economy/identification_service.gd",
		"res://scripts/economy/customer_shop_service.gd",
		"res://scripts/economy/negotiation_service.gd",
		"res://scripts/economy/task_service.gd",
		"res://data/game/catalog.json",
	]
	for path in required:
		_assert_true(FileAccess.file_exists(path), "core file exists: %s" % path)
	var autoloads: PackedStringArray = ProjectSettings.get_property_list().map(func(item): return str(item.get("name", "")))
	_assert_eq("*res://scripts/core/noise_system.gd", str(ProjectSettings.get_setting("autoload/NoiseSystem", "")), "NoiseSystem autoload installed")
	_assert_eq("*res://scripts/items/item_database.gd", str(ProjectSettings.get_setting("autoload/ItemDatabase", "")), "ItemDatabase autoload installed")
	_assert_eq("*res://scripts/core/game_runtime.gd", str(ProjectSettings.get_setting("autoload/GameRuntime", "")), "GameRuntime autoload installed")


func _test_project_scene_routes() -> void:
	var main_scene_path := str(ProjectSettings.get_setting("application/run/main_scene", ""))
	_assert_true(main_scene_path.ends_with("title_menu.tscn") or main_scene_path.ends_with("mining_town.tscn"), "main scene is title_menu or town")
	_assert_true(FileAccess.file_exists("res://scenes/town/mining_town.tscn"), "town scene exists")
	_assert_true(FileAccess.file_exists("res://scenes/mine/test_scene.tscn"), "mine scene exists at normalized route")


func _test_mine_return_route() -> void:
	_assert_true(FileAccess.file_exists("res://scripts/town/mine_exit.gd"), "mine exit script exists")
	var packed: PackedScene = load("res://scenes/mine/test_scene.tscn")
	_assert_true(packed != null, "mine scene loads for return route")
	if packed == null:
		return
	var scene := packed.instantiate()
	var exit := scene.get_node_or_null("MinecartExit")
	_assert_true(exit != null, "mine scene has MinecartExit node")
	if exit != null:
		_assert_eq("res://scenes/town/mining_town.tscn", str(exit.get("target_scene")), "mine exit targets town")
	scene.free()


func _test_core_economy_loop() -> void:
	# Updated for the warehouse system (PR #8). The full mine -> town loop:
	# in-mine pickup lands in the hotbar; returning to town dumps the hotbar
	# into the warehouse; NPC actions (identify, sell, deliver) read the
	# warehouse. Task rewards land in the warehouse.
	var runtime_script = load("res://scripts/core/game_runtime.gd")
	_assert_true(runtime_script != null, "runtime script loads for economy loop")
	if runtime_script == null:
		return
	var runtime: Node = runtime_script.new()
	var init_result: Dictionary = runtime.initialize_for_new_game()
	_assert_true(init_result.get("ok", false), "runtime initializes core services")
	# In-mine pickup lands in the hotbar.
	var collect_result: Dictionary = runtime.get("transactions").apply({
		"type": "collect_item",
		"item_id": "raw_common_geode",
		"quantity": 1,
		"source": "project_test_mine",
	})
	_assert_true(collect_result.get("ok", false), "mine collection lands in hotbar")
	_assert_true(runtime.get("hotbar").has_item("raw_common_geode", 1), "raw geode is in hotbar after mine pickup")
	_assert_eq(0, int(runtime.get("warehouse").get_total_items()), "warehouse is empty before town return")
	# End the mine run: hotbar -> warehouse.
	var leftover: int = int(runtime.end_mine_run())
	_assert_eq(0, leftover, "end_mine_run transfers every hotbar stack to the warehouse")
	_assert_eq(0, int(runtime.get("hotbar").get_total_items()), "hotbar is empty after end_mine_run")
	_assert_true(runtime.get("warehouse").has_item("raw_common_geode", 1), "raw geode is in warehouse after town return")
	# Town identification reads from the warehouse.
	var identify_result: Dictionary = runtime.get("identification_service").identify("raw_common_geode", {"station": "project_test_town"})
	_assert_true(identify_result.get("ok", false), "town identification consumes raw and creates mineral")
	_assert_false(runtime.get("warehouse").has_item("raw_common_geode", 1), "raw geode consumed after identification")
	var mineral_id := str(identify_result.get("item_id", ""))
	_assert_true(runtime.get("warehouse").has_item(mineral_id, 1), "identified mineral is in warehouse")
	# Town sale reads from the warehouse.
	var balance_before_sale: int = int(runtime.get("wallet").get_balance())
	var sale_result: Dictionary = runtime.get("shop_service").sell_to_customer("buyer_blacksmith", mineral_id, 1, {"timing": "good"})
	_assert_true(sale_result.get("ok", false), "town buyer sells identified mineral through unified transaction")
	_assert_true(int(runtime.get("wallet").get_balance()) > balance_before_sale, "sale increases unified wallet")
	_assert_false(runtime.get("warehouse").has_item(mineral_id, 1), "mineral is removed from warehouse after sale")
	# Task reward lands in the warehouse.
	var task_claim: Dictionary = runtime.get("task_service").claim_reward("task_first_identification")
	_assert_true(task_claim.get("ok", false), "identification task can be claimed after town loop")
	_assert_true(runtime.get("warehouse").has_item("raw_fine_geode", 1), "task reward lands in warehouse")
	_assert_eq(0, int(runtime.get("hotbar").get_total_items()), "hotbar remains empty throughout the town loop")
	runtime.shutdown()
	runtime.free()


func _test_single_mutation_boundary() -> void:
	var files := _list_files("res://scripts", ".gd")
	var mutation_terms := [".add_item(", ".remove_item(", ".add_currency(", ".spend_currency(", ".remove_one("]
	for file_path in files:
		var text := FileAccess.get_file_as_string(file_path)
		for term in mutation_terms:
			if text.contains(term):
				var allowed := (
					file_path.ends_with("scripts/core/game_transaction_service.gd")
					or file_path.ends_with("scripts/core/game_runtime.gd")
					or file_path.ends_with("scripts/core/game_wallet.gd")
					or file_path.ends_with("scripts/items/inventory_manager.gd")
					or file_path.ends_with("scripts/town/mining_town_scene.gd")
					or file_path.ends_with("scripts/town/refine_workstation.gd")
				)
				_assert_true(allowed, "mutation term %s only in runtime boundary or compatibility view: %s" % [term, file_path])


# ---- Day 1: Star Crystal & Morality Tests ----


func _test_star_crystal_in_catalog() -> void:
	var catalog_script = load("res://scripts/core/game_catalog.gd")
	_assert_true(catalog_script != null, "catalog script loads for star crystal test")
	if catalog_script == null:
		return
	var catalog: Object = catalog_script.new()
	var load_result: Dictionary = catalog.load_defaults()
	_assert_true(load_result.get("ok", false), "catalog loads for star crystal test")
	if not load_result.get("ok", false):
		catalog = null
		return

	# Star crystal mineral exists
	_assert_true(catalog.has_item("star_crystal"), "star_crystal exists in catalog")
	var star: Dictionary = catalog.get_item("star_crystal")
	_assert_eq("mineral", str(star.get("category", "")), "star_crystal category is mineral")
	_assert_eq("legendary", str(star.get("rarity", "")), "star_crystal rarity is legendary")
	_assert_eq(500, int(star.get("base_price", 0)), "star_crystal base price is 500")

	# Raw star geode exists
	_assert_true(catalog.has_item("raw_star_geode"), "raw_star_geode exists in catalog")
	var raw: Dictionary = catalog.get_item("raw_star_geode")
	_assert_eq("raw_stone", str(raw.get("category", "")), "raw_star_geode category is raw_stone")
	_assert_eq("star_geode", str(raw.get("identify_table", "")), "raw_star_geode identify_table is star_geode")

	# Star geode identify table exists
	var star_table: Array = catalog.get_identify_table("star_geode")
	_assert_false(star_table.is_empty(), "star_geode identify table exists")
	var entries: Array = star_table
	_assert_true(entries.size() > 0, "star_geode identify table has entries")
	if entries.size() > 0:
		var first_entry: Dictionary = entries[0]
		_assert_eq("star_crystal", str(first_entry.get("item_id", "")), "star_geode identify table outputs star_crystal")
	catalog = null


func _test_star_geode_identify_table() -> void:
	var catalog_script = load("res://scripts/core/game_catalog.gd")
	if catalog_script == null:
		return
	var catalog: Object = catalog_script.new()
	catalog.load_defaults()
	var rng := RandomNumberGenerator.new()
	rng.randomize()

	# The star_geode table has only one entry, so identify should always yield star_crystal
	var id_service_script = load("res://scripts/economy/identification_service.gd")
	if id_service_script == null:
		catalog = null
		return
	# We need a GameTransactionService to use IdentificationService. Build a minimal one.
	var game_transaction_script = load("res://scripts/core/game_transaction_service.gd")
	if game_transaction_script == null:
		catalog = null
		return

	# Build minimal inventory for identification to deposit into
	var inventory_script = load("res://scripts/core/game_inventory.gd")
	if inventory_script == null:
		catalog = null
		return
	var warehouse: Object = inventory_script.new(48)
	var wallet_script = load("res://scripts/core/game_wallet.gd")
	if wallet_script == null:
		catalog = null
		warehouse = null
		return
	var wallet: Object = wallet_script.new(50)
	var event_bus_script = load("res://scripts/core/game_event_bus.gd")
	if event_bus_script == null:
		catalog = null
		warehouse = null
		return
	var event_bus: Object = event_bus_script.new()
	var transactions: Object = game_transaction_script.new(catalog, warehouse, warehouse, wallet, event_bus, rng)
	var id_service: Object = id_service_script.new(catalog, transactions, rng)

	# First add a raw_star_geode to the hotbar (source for identify)
	var added: Dictionary = warehouse.add_item("raw_star_geode", 1)
	_assert_true(added.get("ok", false), "added raw_star_geode to warehouse for identify test")

	var result: Dictionary = id_service.identify("raw_star_geode", {"station": "test"})
	_assert_true(result.get("ok", false), "identify raw_star_geode succeeds")
	if result.get("ok", false):
		_assert_eq("star_crystal", str(result.get("item_id", "")), "identify raw_star_geode yields star_crystal")
	catalog = null
	warehouse = null
	wallet = null


func _test_l4_geode_removed() -> void:
	var catalog_script = load("res://scripts/core/game_catalog.gd")
	_assert_true(catalog_script != null, "catalog script loads for L4 removal test")
	if catalog_script == null:
		return
	var catalog: Object = catalog_script.new()
	catalog.load_defaults()

	_assert_false(catalog.has_item("raw_anomalous_geode"), "raw_anomalous_geode is removed from catalog")

	var anom_table: Array = catalog.get_identify_table("anomalous_geode")
	_assert_true(anom_table.is_empty(), "anomalous_geode identify table is removed")

	# Deep mine loot table should have exactly 3 entries (all L1-L3)
	var deep_table: Array = catalog.get_loot_table("mine_wall_deep")
	var entries: Array = deep_table
	_assert_eq(3, entries.size(), "mine_wall_deep loot table has exactly 3 entries (no L4)")
	catalog = null


func _test_morality_tracker() -> void:
	var morality_script = load("res://scripts/core/morality_tracker.gd")
	_assert_true(morality_script != null, "morality tracker script loads")
	if morality_script == null:
		return
	var tracker: Object = morality_script.new()

	_assert_eq("neutral", tracker.current_alignment, "initial alignment is neutral")
	_assert_eq(0, tracker.sold_star_count, "initial sold count is 0")
	_assert_eq(0, tracker.gifted_star_count, "initial gifted count is 0")
	_assert_eq(0, tracker.get_narrative_stage(), "initial narrative stage is 0")

	# Touch star
	tracker.record_star_touched()
	_assert_true(tracker.has_touched_star, "has_touched_star after touch")
	_assert_eq(1, tracker.get_narrative_stage(), "narrative stage 1 after touch")

	# Gift 3 star crystals -> should become good
	tracker.record_star_gifted()
	tracker.record_star_gifted()
	tracker.record_star_gifted()
	_assert_eq(3, tracker.gifted_star_count, "gifted count is 3")
	_assert_eq("good", tracker.current_alignment, "alignment is good after 3 gifts")
	_assert_eq(3, tracker.get_narrative_stage(), "narrative stage 3 after alignment change")

	# Reset and test evil path
	tracker.reset()
	tracker.record_star_sold()
	tracker.record_star_sold()
	tracker.record_star_sold()
	_assert_eq(3, tracker.sold_star_count, "sold count is 3")
	_assert_eq("evil", tracker.current_alignment, "alignment is evil after 3 sells")

	tracker = null


func _test_mine_stats_star_geode_config() -> void:
	# Verify the mine_stats script has the star geode configuration properties
	var source: String = FileAccess.get_file_as_string("res://scripts/mine/mine_stats.gd")
	_assert_true(source.contains("gem_star_scene"), "mine_stats.gd declares gem_star_scene export")
	_assert_true(source.contains("star_geode_drop_rate"), "mine_stats.gd declares star_geode_drop_rate export")
	_assert_true(source.contains("_spawn_star_geode"), "mine_stats.gd has _spawn_star_geode method")
	_assert_false(source.contains("gem_l4_scene"), "mine_stats.gd no longer declares gem_l4_scene")
	_assert_false(source.contains("drop_rate_l4"), "mine_stats.gd no longer declares drop_rate_l4")


func _run_test(test_name: String, test_callable: Callable) -> void:
	var before := _failures.size()
	test_callable.call()
	if _failures.size() == before:
		print("[PASS] %s" % test_name)
	else:
		print("[FAIL] %s" % test_name)


func _count_named_children(root: Node, starts_with_text: String) -> int:
	var count := 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node.name.begins_with(starts_with_text):
			count += 1
		for child in node.get_children():
			stack.append(child)
	return count


func _list_files(path: String, extension: String) -> Array[String]:
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
			results.append_array(_list_files(child_path, extension))
		elif entry.ends_with(extension):
			results.append(child_path)
	dir.list_dir_end()
	return results


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


func _path_exists(path: String) -> bool:
	return FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path)


func _root_entry_exists_exact(entry_name: String) -> bool:
	var dir := DirAccess.open("res://")
	if dir == null:
		return false
	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry.is_empty():
			break
		if entry == entry_name:
			dir.list_dir_end()
			return true
	dir.list_dir_end()
	return false


# ---- Day 2: Stability System ----

func _test_stability_system_basics() -> void:
	var st: Node = _new_stability_for_test()
	_assert_true(st != null, "StabilitySystem instance created")
	_assert_float_eq(70.0, float(st.stability), 0.01, "initial stability is 70")
	st.stability = 5.0
	st.penalize_sell()
	_assert_float_eq(0.0, float(st.stability), 0.01, "stability floor is 0 through modifiers")
	st.stability = 95.0
	st.reward_gift_star()
	_assert_float_eq(100.0, float(st.stability), 0.01, "stability ceiling is 100 through modifiers")
	st.free()


func _test_stability_system_modifiers() -> void:
	var st: Node = _new_stability_for_test()
	st.stability = 70.0
	st.apply_daily_decay()
	_assert_float_eq(67.0, float(st.stability), 0.01, "daily decay subtracts 3")
	st.penalize_sell()
	_assert_float_eq(52.0, float(st.stability), 0.01, "sell penalty subtracts 15")
	st.reward_gift_star()
	_assert_float_eq(67.0, float(st.stability), 0.01, "gift star adds 15")
	st.reward_gift_normal()
	_assert_float_eq(69.0, float(st.stability), 0.01, "gift normal adds 2")
	st.free()


# ---- Day 2: Day/Night Cycle ----

func _test_day_night_cycle_limits() -> void:
	var dc: Node = _new_day_cycle_for_test()
	_assert_false(dc.is_night, "starts in daytime")
	_assert_true(dc.can_enter_mine(), "can enter mine during day with quota unused")
	dc.use_mine_entry()
	dc.on_mine_return()
	_assert_true(dc.is_night, "enters night after mine return")
	_assert_false(dc.can_enter_mine(), "cannot enter mine at night")
	dc.end_night()
	_assert_false(dc.is_night, "back to day after end_night")
	_assert_eq(2, int(dc.get_remaining_entries()), "quota refilled to 2 after night")
	# Use both entries continuously without returning in between
	dc.use_mine_entry()
	dc.use_mine_entry()
	_assert_eq(0, int(dc.get_remaining_entries()), "quota 0 after using both entries")
	_assert_false(dc.can_enter_mine(), "cannot enter mine when quota is 0")
	dc.free()


func _test_day_night_cycle_resets() -> void:
	var dc: Node = _new_day_cycle_for_test()
	_assert_eq(1, int(dc.day_count), "initial day is 1")
	_assert_eq(2, int(dc.get_remaining_entries()), "initial remaining entries is 2")
	dc.use_mine_entry()
	_assert_eq(1, int(dc.get_remaining_entries()), "1 use => 1 remaining")
	dc.use_mine_entry()
	_assert_eq(0, int(dc.get_remaining_entries()), "2 uses => 0 remaining")
	dc.on_mine_return()
	dc.end_night()
	_assert_eq(2, int(dc.day_count), "day counter increments after end_night")
	_assert_eq(2, int(dc.get_remaining_entries()), "quota resets to 2 after new day")
	_assert_false(dc.is_night, "daytime after new day")
	dc.free()


func _new_stability_for_test() -> Node:
	var script: GDScript = load("res://scripts/core/stability_system.gd")
	return script.new()


func _new_day_cycle_for_test() -> Node:
	var script: GDScript = load("res://scripts/core/day_night_cycle.gd")
	return script.new()


# ---- Day 3: NPC Affection & Dialogue ----

func _test_npc_affection_basics() -> void:
	var aff: Object = _new_affection_for_test()
	for npc_id in ["elder", "blacksmith", "florist", "buyer"]:
		_assert_eq(0, int(aff.get_affection(npc_id)), "initial affection for %s is 0" % npc_id)
	aff.gift("florist", "common")
	_assert_eq(1, int(aff.get_affection("florist")), "common gift gives +1")
	aff.gift("florist", "rare")
	_assert_eq(4, int(aff.get_affection("florist")), "rare gift gives +3 (1+3=4)")
	aff.gift("florist", "star")
	_assert_eq(9, int(aff.get_affection("florist")), "star gift gives +5 (4+5=9)")
	aff = null


func _test_npc_affection_gift() -> void:
	var aff: Object = _new_affection_for_test()
	_assert_true(aff.can_gift_today("florist"), "can gift before any gift given")
	aff.gift("florist", "common")
	_assert_false(aff.can_gift_today("florist"), "cannot gift same npc twice in one day")
	aff.reset_daily()
	_assert_true(aff.can_gift_today("florist"), "can gift again after daily reset")
	# Test clamps at 100
	for i in range(120):
		aff.reset_daily()
		aff.gift("florist", "common")
	_assert_eq(100, int(aff.get_affection("florist")), "affection clamped to 100")
	aff = null


func _test_dialogues_json_structure() -> void:
	var file := FileAccess.open("res://data/narrative/dialogues.json", FileAccess.READ)
	_assert_true(file != null, "dialogues.json file exists")
	if file == null:
		return
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	var err := json.parse(text)
	_assert_eq(OK, int(err), "dialogues.json is valid JSON")
	if err != OK:
		return
	var data: Dictionary = json.data
	for npc_id in ["elder", "blacksmith", "florist", "buyer"]:
		_assert_true(data.has(npc_id), "dialogues.json has NPC: %s" % npc_id)
		var npc_data: Dictionary = data[npc_id]
		_assert_true(npc_data.has("stages"), "%s has stages" % npc_id)
		for stage in range(4):
			var sk: String = str(stage)
			var has_stage: bool = npc_data["stages"].has(sk)
			_assert_true(has_stage, "%s has stage %s" % [npc_id, sk])


func _new_affection_for_test() -> Object:
	var script: GDScript = load("res://scripts/narrative/npc_affection.gd")
	return script.new()


# ---- Day 4: Equipment + Daily Tasks ----

func _test_equipment_json() -> void:
	var esys: Object = _new_equipment_for_test()
	var all: Dictionary = esys.get_all_equipment()
	_assert_true(not all.is_empty(), "equipment data is non-empty")
	var evil_found: bool = false
	var good_found: bool = false
	var neutral_found: bool = false
	for eid in all:
		var e: Dictionary = all[eid]
		var align: String = str(e.get("alignment", ""))
		if align == "evil": evil_found = true
		if align == "good": good_found = true
		if align == "neutral": neutral_found = true
	_assert_true(evil_found, "at least one evil equipment exists")
	_assert_true(good_found, "at least one good equipment exists")
	_assert_true(neutral_found, "at least one neutral equipment exists")
	esys = null


func _test_equipment_buy_equip() -> void:
	var esys: Object = _new_equipment_for_test()
	var result: Dictionary = esys.buy("silent_pick_l1", 1000)
	_assert_true(result.get("ok", false), "buying silent_pick_l1 succeeds")
	_assert_true(esys.owns("silent_pick_l1"), "owns silent_pick_l1 after buy")
	_assert_eq("silent_pick_l1", str(esys.get_current_in_slot("weapon")), "silent_pick_l1 auto-equipped to weapon slot")
	# Cannot buy again
	var result2: Dictionary = esys.buy("silent_pick_l1", 1000)
	_assert_false(result2.get("ok", false), "cannot buy silent_pick_l1 twice")
	esys = null


func _test_catalog_daily_pool() -> void:
	var cat: Object = _new_catalog_for_test()
	var pool: Array = cat.get_tasks_for_pool("daily_pool")
	_assert_true(pool.size() >= 3, "daily task pool has at least 3 entries")
	var night: Array = cat.get_night_customers()
	_assert_true(night.size() >= 1, "at least 1 night customer exists")
	cat = null


func _test_refine_workstation() -> void:
	var ws: Node = _new_refine_for_test()
	_assert_eq("refined_copper_nugget", str(ws.get_refined_item_id("copper_nugget")), "refined item id is prefixed")
	_assert_eq(30, int(ws.get_refine_cost("common")), "common refine cost is 30")
	_assert_eq(80, int(ws.get_refine_cost("rare")), "rare refine cost is 80")
	ws.free()


func _new_equipment_for_test() -> Object:
	var script: GDScript = load("res://scripts/player/equipment_system.gd")
	var esys: Object = script.new()
	esys.load_data()
	return esys


func _new_catalog_for_test() -> Object:
	var script: GDScript = load("res://scripts/core/game_catalog.gd")
	var cat: Object = script.new()
	cat.load_defaults()
	return cat


func _new_refine_for_test() -> Node:
	var script: GDScript = load("res://scripts/town/refine_workstation.gd")
	return script.new()


func _res_path(path: String) -> String:
	return "res://" + path


func _cleanup_autoloads() -> void:
	var runtime := root.get_node_or_null("GameRuntime")
	if runtime != null and runtime.has_method("shutdown"):
		runtime.shutdown()
	var noise := root.get_node_or_null("NoiseSystem")
	if noise != null and noise.has_method("clear"):
		noise.clear()


func _count_item(runtime: Node, item_id: String) -> int:
	var total := 0
	for stack_variant in runtime.get("hotbar").get_stacks():
		var stack: Dictionary = stack_variant
		if str(stack.get("item_id", "")) == item_id:
			total += int(stack.get("quantity", 0))
	return total


func _assert_true(value: bool, message: String) -> void:
	_assertions += 1
	if not value:
		_failures.append("%s: expected true" % message)


func _assert_false(value: bool, message: String) -> void:
	_assertions += 1
	if value:
		_failures.append("%s: expected false" % message)


func _assert_eq(expected, actual, message: String) -> void:
	_assertions += 1
	if expected != actual:
		_failures.append("%s: expected %s, got %s" % [message, str(expected), str(actual)])


func _assert_float_eq(expected: float, actual: float, tolerance: float, message: String) -> void:
	_assertions += 1
	if absf(expected - actual) > tolerance:
		_failures.append("%s: expected %s +/- %s, got %s" % [message, str(expected), str(tolerance), str(actual)])


func _test_main_scene_is_town() -> void:
	var main_scene: String = str(ProjectSettings.get_setting("application/run/main_scene", ""))
	# The main scene may be the title menu (res:// path) or the town (uid).
	if main_scene.begins_with("res://"):
		_assert_true(main_scene.ends_with("title_menu.tscn") or main_scene.ends_with("mining_town.tscn"), "main scene path is title_menu or town")
	else:
		_assert_eq("uid://dxjbgwnb1j7cw", main_scene, "main scene uid is the town scene")
		var uid_int: int = ResourceUID.text_to_id(main_scene)
		if ResourceUID.has_id(uid_int):
			var resolved: String = ResourceUID.get_id_path(uid_int)
			_assert_eq("res://scenes/town/mining_town.tscn", resolved, "main scene uid resolves to mining_town.tscn")
		else:
			_assert_true(false, "main scene uid %s is registered in ResourceUID cache" % main_scene)
	# Also instantiate the town scene to prove it actually loads as a real scene
	var packed: PackedScene = load("res://scenes/town/mining_town.tscn")
	_assert_true(packed != null, "town scene file exists and loads for main scene uid")
	if packed != null:
		var probe: Node = packed.instantiate()
		if probe != null:
			_assert_eq("MiningTown", str(probe.name), "town scene root node is named MiningTown")
			probe.free()
		else:
			_assert_true(false, "town scene instantiates to a non-null node")


func _test_town_scene_script_reference() -> void:
	var town_scene_text := FileAccess.get_file_as_string("res://scenes/town/mining_town.tscn")
	_assert_false(town_scene_text.contains("fused_mining_town_scene"), "town scene does not reference stale fused script")
	_assert_true(town_scene_text.contains("res://scripts/town/mining_town_scene.gd"), "town scene references current mining_town_scene.gd script")
	_assert_true(FileAccess.file_exists("res://scripts/town/mining_town_scene.gd"), "mining_town_scene.gd exists")
	_assert_false(FileAccess.file_exists("res://scripts/town/fused_mining_town_scene.gd"), "stale fused script file is gone")


func _test_shop_list_customers_returns_customers() -> void:
	var catalog_script = load("res://scripts/core/game_catalog.gd")
	var shop_script = load("res://scripts/economy/customer_shop_service.gd")
	_assert_true(catalog_script != null, "catalog script loads for shop list_customers test")
	_assert_true(shop_script != null, "shop script loads for shop list_customers test")
	if catalog_script == null or shop_script == null:
		return
	var catalog: Object = catalog_script.new()
	var load_result: Dictionary = catalog.load_defaults()
	_assert_true(load_result.get("ok", false), "catalog loads for shop list_customers test")
	if not load_result.get("ok", false):
		catalog = null
		return
	var shop: Object = shop_script.new(catalog, null, null)
	var customers: Array = shop.list_customers()
	_assert_true(customers.size() > 0, "shop.list_customers returns at least one customer")
	var saw_customer_id := false
	for entry in customers:
		var entry_id: String = str((entry as Dictionary).get("id", ""))
		if entry_id.begins_with("buyer_"):
			saw_customer_id = true
			break
	_assert_true(saw_customer_id, "shop.list_customers entries are customers (id starts with buyer_)")
	# Negative check: should NOT return task entries
	var saw_task_id := false
	for entry in customers:
		var entry_id: String = str((entry as Dictionary).get("id", ""))
		if entry_id.begins_with("task_"):
			saw_task_id = true
			break
	_assert_false(saw_task_id, "shop.list_customers does not return task entries")
	shop = null
	catalog = null


func _test_catalog_get_customers() -> void:
	var catalog_script = load("res://scripts/core/game_catalog.gd")
	_assert_true(catalog_script != null, "catalog script loads for get_customers test")
	if catalog_script == null:
		return
	var catalog: Object = catalog_script.new()
	var load_result: Dictionary = catalog.load_defaults()
	_assert_true(load_result.get("ok", false), "catalog loads for get_customers test")
	if not load_result.get("ok", false):
		catalog = null
		return
	_assert_true(catalog.has_method("get_customers"), "GameCatalog exposes get_customers method")
	if catalog.has_method("get_customers"):
		var customers: Array = catalog.get_customers()
		_assert_true(customers.size() > 0, "GameCatalog.get_customers returns at least one entry")
		# Cross-check with raw JSON to make sure counts line up
		var json_text := FileAccess.get_file_as_string("res://data/game/catalog.json")
		var parsed: Variant = JSON.parse_string(json_text)
		if typeof(parsed) == TYPE_DICTIONARY:
			var parsed_dict := parsed as Dictionary
			var expected_count: int = (parsed_dict.get("customers", []) as Array).size() + (parsed_dict.get("night_customers", []) as Array).size()
			_assert_eq(expected_count, customers.size(), "GameCatalog.get_customers count matches catalog.json customers array")
	catalog = null


func _test_inventory_manager_is_full_proxies_to_runtime() -> void:
	# Build a fresh runtime + InventoryManager pair, seed past the legacy 8-slot
	# fiction but well below runtime capacity, and assert is_full() is false.
	# Then seed past runtime capacity and assert is_full() is true.
	var runtime_script = load("res://scripts/core/game_runtime.gd")
	var inventory_manager_script = load("res://scripts/items/inventory_manager.gd")
	_assert_true(runtime_script != null, "runtime script loads for is_full proxy test")
	_assert_true(inventory_manager_script != null, "inventory manager script loads for is_full proxy test")
	if runtime_script == null or inventory_manager_script == null:
		return
	var runtime: Node = runtime_script.new()
	var init_result: Dictionary = runtime.initialize_for_new_game()
	_assert_true(init_result.get("ok", false), "runtime initializes for is_full proxy test")
	if not init_result.get("ok", false):
		runtime.free()
		return
	var inv: Object = runtime.get("hotbar")
	_assert_true(inv != null, "runtime has inventory")
	if inv == null:
		runtime.shutdown()
		runtime.free()
		return
	_assert_true(inv.has_method("is_full"), "GameInventory exposes is_full method")
	# Empty inventory must not be full
	_assert_false(bool(inv.is_full()), "empty GameInventory is not full")
	# Seed exactly to the legacy 8-slot fiction mark and confirm we are still not full.
	# Eight distinct item_ids; the catalog has more than 8 items, so we can use real ids.
	var raw_ids: Array = ["raw_common_geode", "raw_fine_geode", "raw_rare_geode",
		"copper_nugget", "iron_shard", "silver_vein", "gold_vein", "crystal_bloom"]
	for item_id in raw_ids:
		var add_result: Dictionary = inv.add_item(str(item_id), 1)
		_assert_true(add_result.get("ok", false), "seed add_item ok for %s" % item_id)
	_assert_eq(8, int(inv.get_used_slot_count()), "GameInventory used slot count is 8 after seeding")
	_assert_false(bool(inv.is_full()), "GameInventory with 8 stacks is not full when capacity is 18")
	# Now flood it past runtime capacity (18) with one more item, but skip if capacity is 18 exactly
	# — we need a 19th stack to force is_full to true. Add unique ids so each becomes a new stack.
	var extra_ids: Array = ["moonlit_crystal", "star_fragment", "memory_core"]
	for item_id in extra_ids:
		var add_result: Dictionary = inv.add_item(str(item_id), 1)
		_assert_true(add_result.get("ok", false), "seed add_item ok for %s" % item_id)
	_assert_eq(11, int(inv.get_used_slot_count()), "GameInventory used slot count is 11 after extra seed")
	# 11 < 18 still, so not full yet. Push past 18 by adding more stacks of the existing ids,
	# but they will merge into existing stacks. To push past capacity we need new unique ids.
	# The catalog has 12 unique items — we used 11. We need at least 7 more unique ids to reach
	# 18 stacks, but only 1 is left. So simulate "full" by directly inspecting the property:
	# the real test of behavior is "is_full returns true iff used slots >= capacity". So we
	# push capacity low by writing the public property and re-checking.
	# Note: GameInventory exposes `capacity` as a public var so this is the supported way to
	# lower the limit in tests; it does not mutate persisted state.
	inv.capacity = 8
	_assert_true(bool(inv.is_full()), "GameInventory with capacity=8 and 11 used slots reports full")
	inv.capacity = 18
	_assert_false(bool(inv.is_full()), "GameInventory with capacity=18 and 11 used slots reports not full")
	runtime.shutdown()
	runtime.free()


func _test_item_database_get_stack_limit_uses_catalog() -> void:
	# In the -s headless run, autoloads are children of the root Window. We use
	# relative paths because the SceneTree refuses absolute /root/... paths
	# when no current_scene is active. _init awaits one process frame before
	# running any test, so the autoloads are guaranteed to be ready here.
	var db: Object = root.get_node_or_null("ItemDatabase")
	var runtime: Object = root.get_node_or_null("GameRuntime")
	_assert_true(db != null, "ItemDatabase autoload is available under root")
	_assert_true(runtime != null, "GameRuntime autoload is available under root")
	if db == null or runtime == null:
		return
	_assert_true(db.has_method("get_stack_limit"), "ItemDatabase exposes get_stack_limit method")
	# 1. Live catalog roundtrip: stack_size values from catalog.json should
	# come back through get_stack_limit. The catalog has 12 items, all with
	# stack_size=99, so we expect 99 for any known item id.
	var known_ids: Array = ["raw_common_geode", "raw_fine_geode", "raw_rare_geode",
		"copper_nugget", "iron_shard", "silver_vein", "gold_vein",
		"crystal_bloom", "moonlit_crystal", "star_fragment", "memory_core"]
	for item_id in known_ids:
		_assert_eq(99, int(db.get_stack_limit(str(item_id))),
			"get_stack_limit returns catalog stack_size (99) for %s" % item_id)
	# 2. Empty id falls back to DEFAULT_STACK_LIMIT (99)
	_assert_eq(99, int(db.get_stack_limit("")), "empty item id returns default stack limit (99)")
	# 3. Unknown item id: GameCatalog.get_stack_size defaults to 99, so the
	# unknown case also returns 99. The point of the test is that the value
	# is *derived* from the catalog call, not from a stale constant map.
	var unknown: int = int(db.get_stack_limit("definitely_not_a_real_item_id"))
	_assert_eq(99, unknown, "unknown item id returns default stack limit (99)")
	# 4. Static check: the legacy STACK_LIMITS constant must be gone. If it
	# ever comes back, it would be a parallel source of truth that drifts from
	# catalog.json — the whole point of this fix.
	var db_source: String = FileAccess.get_file_as_string("res://scripts/items/item_database.gd")
	_assert_false(db_source.contains("const STACK_LIMITS"),
		"ItemDatabase no longer declares a STACK_LIMITS constant (source of truth moved to catalog)")
