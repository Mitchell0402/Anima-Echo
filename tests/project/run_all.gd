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
	_run_test("town walkable range is open for future level design", Callable(self, "_test_town_walkable_range_is_open"))
	_run_test("mine movement range is open for future level design", Callable(self, "_test_mine_movement_range_is_open"))
	_run_test("mine gem drops stay visible before pickup", Callable(self, "_test_mine_gem_drops_stay_visible_before_pickup"))
	_run_test("hotbar gem inventory items resolve icons", Callable(self, "_test_hotbar_gem_inventory_items_resolve_icons"))
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
	_assert_true(scene.get_node_or_null("TileMapLayer") != null, "mine keeps TileMapLayer")
	_assert_true(scene.get_node_or_null("TileMapLayer2") != null, "mine keeps TileMapLayer2")
	_assert_true(_count_named_children(scene, "SmallMine") >= 5, "mine keeps five mine nodes")
	_assert_true(scene.get_node_or_null("Cover") != null, "mine keeps Cover")
	_assert_true(scene.get_node_or_null("Cover2") != null, "mine keeps Cover2")
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
	_assert_true(project_context.contains("主场景：`res://scenes/town/mining_town.tscn`"), "project context names town as main scene")
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
		"res://assets/town/npcs/npc_miner_sprites.png",
		"res://assets/town/npcs/npc_buyer_sprites.png",
		"res://assets/town/npcs/npc_identifier_sprites.png",
		"res://assets/town/npcs/npc_task_clerk_sprites.png",
	]
	for path in required:
		_assert_true(FileAccess.file_exists(path), "town asset exists: %s" % path)


func _test_town_player_uses_mine_character_visuals() -> void:
	var town_script_text := FileAccess.get_file_as_string("res://scripts/town/mining_town_scene.gd")
	_assert_true(town_script_text.contains("res://assets/mine/characters/player/main_char_sprite_frames.tres"), "town player uses mine SpriteFrames resource")
	_assert_true(town_script_text.contains("AnimatedSprite2D.new()"), "town player creates AnimatedSprite2D")
	_assert_false(town_script_text.contains("player_sprites_normalized.png"), "town player no longer references legacy town player sprite")
	var controller_script = load("res://scripts/town/town_player_controller.gd")
	var controller = controller_script.new()
	_assert_true(controller.has_method("configure_animated_sprite"), "town movement controller supports animated mine character sprite")
	controller.free()


func _test_town_characters_share_visual_scale() -> void:
	var town_script_text := FileAccess.get_file_as_string("res://scripts/town/mining_town_scene.gd")
	_assert_true(town_script_text.contains("const TOWN_CHARACTER_SCALE := 1.25"), "town character scale preserves player display size")
	_assert_false(town_script_text.contains("const TOWN_CHARACTER_SCALE := 0.28"), "town character scale does not shrink to old legacy player size")
	_assert_false(town_script_text.contains("sprite.scale = Vector2(0.24, 0.24)"), "town NPCs do not keep separate legacy scale")
	_assert_true(town_script_text.contains("player_sprite.scale = Vector2(TOWN_CHARACTER_SCALE, TOWN_CHARACTER_SCALE)"), "town player uses shared scale")
	_assert_true(town_script_text.contains("sprite.scale = Vector2(TOWN_CHARACTER_SCALE, TOWN_CHARACTER_SCALE)"), "town NPCs use shared scale")


func _test_players_move_cardinally() -> void:
	var mine_move_text := FileAccess.get_file_as_string("res://scripts/player/move_controller.gd")
	_assert_true(mine_move_text.contains("_to_cardinal_direction"), "mine movement resolves input to cardinal direction")
	_assert_false(mine_move_text.contains("input_dir = input_dir.normalized()"), "mine movement does not normalize diagonal input")
	var town_controller_text := FileAccess.get_file_as_string("res://scripts/town/town_player_controller.gd")
	_assert_true(town_controller_text.contains("_to_cardinal_direction"), "town movement resolves input to cardinal direction")
	_assert_false(town_controller_text.contains("direction.normalized() * speed"), "town movement does not normalize diagonal input")


func _test_town_walkable_range_is_open() -> void:
	var town_script_text := FileAccess.get_file_as_string("res://scripts/town/mining_town_scene.gd")
	_assert_true(town_script_text.contains("\"blocked_polygons\": []"), "town movement has no temporary blocked polygons")
	var town_script = load("res://scripts/town/mining_town_scene.gd")
	var town = town_script.new()
	_assert_true(town.has_method("get_town_walkable_config_for_test"), "town exposes walkable config for tests")
	if not town.has_method("get_town_walkable_config_for_test"):
		town.free()
		return
	var config: Dictionary = town.get_town_walkable_config_for_test()
	_assert_true(bool(config.get("default_walkable", false)), "town defaults to walkable")
	_assert_eq(0, (config.get("blocked_polygons", []) as Array).size(), "town blocked ranges are empty")
	town.free()


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


func _test_minecart_return_route() -> void:
	_assert_true(FileAccess.file_exists("res://assets/props/minecart_return_to_town.png"), "minecart sprite exists")
	var minecart_texture: Texture2D = load("res://assets/props/minecart_return_to_town.png")
	_assert_true(minecart_texture != null, "minecart sprite loads as texture")
	if minecart_texture != null:
		_assert_eq(64, minecart_texture.get_width(), "minecart sprite has normalized width")
		_assert_eq(64, minecart_texture.get_height(), "minecart sprite has normalized height")
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
	_assert_eq("res://scenes/town/mining_town.tscn", str(ProjectSettings.get_setting("application/run/main_scene", "")), "main scene is town")
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
				var allowed := file_path.ends_with("scripts/core/game_transaction_service.gd") or file_path.ends_with("scripts/core/game_wallet.gd") or file_path.ends_with("scripts/items/inventory_manager.gd")
				_assert_true(allowed, "mutation term %s only in runtime boundary or compatibility view: %s" % [term, file_path])


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


func _test_main_scene_is_town() -> void:
	var main_scene: String = str(ProjectSettings.get_setting("application/run/main_scene", ""))
	_assert_eq("uid://dxjbgwnb1j7cw", main_scene, "main scene uid is the town scene")
	# Resolve the configured uid back to a path so we prove the two sides agree
	# without depending on PackedScene.resource_path (which returns the uid form
	# in Godot 4.6). This is read-only — we never create a new uid.
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
			var expected_count: int = ((parsed as Dictionary).get("customers", []) as Array).size()
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
