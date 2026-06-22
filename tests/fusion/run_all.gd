extends SceneTree

var _failures: Array[String] = []
var _assertions: int = 0


func _init() -> void:
	print("Running mine-platform-v2 fusion tests")
	_run_test("GJ mine scene keeps original playable structure", Callable(self, "_test_gj_mine_scene_structure"))
	_run_test("scene resources do not point at imported cache files", Callable(self, "_test_no_import_cache_scene_references"))
	_run_test("scripts do not keep stale uppercase preload paths", Callable(self, "_test_no_stale_uppercase_script_paths"))
	_run_test("legacy fusion files are cleaned out", Callable(self, "_test_legacy_fusion_files_cleaned"))
	_run_test("project docs describe current fused project", Callable(self, "_test_project_docs_are_current"))
	_run_test("project uses normalized source layout", Callable(self, "_test_project_uses_normalized_source_layout"))
	_run_test("no legacy res paths remain after layout migration", Callable(self, "_test_no_legacy_res_paths_after_layout_migration"))
	_run_test("p-1 town presentation assets are present", Callable(self, "_test_town_assets_present"))
	_run_test("town player uses GJ mine character visuals", Callable(self, "_test_town_player_uses_gj_character_visuals"))
	_run_test("town characters share one visual scale", Callable(self, "_test_town_characters_share_visual_scale"))
	_run_test("players move cardinally without diagonal input", Callable(self, "_test_players_move_cardinally"))
	_run_test("town walkable range is open for future level design", Callable(self, "_test_town_walkable_range_is_open"))
	_run_test("mine movement range is open for future level design", Callable(self, "_test_mine_movement_range_is_open"))
	_run_test("mine gem drops stay visible before pickup", Callable(self, "_test_mine_gem_drops_stay_visible_before_pickup"))
	_run_test("hotbar gem inventory items resolve icons", Callable(self, "_test_hotbar_gem_inventory_items_resolve_icons"))
	_run_test("mine return route uses generated minecart prop", Callable(self, "_test_minecart_return_route"))
	_run_test("unified runtime core is installed", Callable(self, "_test_unified_core_installed"))
	_run_test("project starts from fused town and keeps GJ mine route", Callable(self, "_test_project_scene_routes"))
	_run_test("mine scene exposes return route to fused town", Callable(self, "_test_mine_return_route"))
	_run_test("core economy supports mine to town progression loop", Callable(self, "_test_core_economy_loop"))
	_run_test("runtime code keeps one inventory and currency mutation boundary", Callable(self, "_test_single_mutation_boundary"))

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


func _test_gj_mine_scene_structure() -> void:
	var packed: PackedScene = load("res://scenes/mine/test_scene.tscn")
	_assert_true(packed != null, "GJ mine scene loads")
	if packed == null:
		return
	var scene := packed.instantiate()
	_assert_true(scene.get_node_or_null("MainCharacter") != null, "GJ mine keeps MainCharacter")
	_assert_true(scene.get_node_or_null("TileMapLayer") != null, "GJ mine keeps TileMapLayer")
	_assert_true(scene.get_node_or_null("TileMapLayer2") != null, "GJ mine keeps TileMapLayer2")
	_assert_true(_count_named_children(scene, "SmallMine") >= 5, "GJ mine keeps five mine nodes")
	_assert_true(scene.get_node_or_null("Cover") != null, "GJ mine keeps Cover")
	_assert_true(scene.get_node_or_null("Cover2") != null, "GJ mine keeps Cover2")
	_assert_true(scene.get_node_or_null("EnemyCollection/Enemy") != null, "GJ mine keeps first enemy")
	_assert_true(scene.get_node_or_null("EnemyCollection/Enemy3") != null, "GJ mine keeps second enemy")
	_assert_true(scene.get_node_or_null("PatrolRoute/PatrolA") != null, "GJ mine keeps PatrolA")
	scene.free()


func _test_no_import_cache_scene_references() -> void:
	for file_path in _list_files("res://scenes/mine", ".tscn"):
		var text := FileAccess.get_file_as_string(file_path)
		_assert_false(text.contains("res://.godot/imported"), "no imported cache reference in %s" % file_path)


func _test_no_stale_uppercase_script_paths() -> void:
	for file_path in _list_files("res://scripts", ".gd"):
		var text := FileAccess.get_file_as_string(file_path)
		_assert_false(text.contains(_res_path("Scripts/")), "no stale uppercase script preload in %s" % file_path)


func _test_legacy_fusion_files_cleaned() -> void:
	var removed_paths := [
		_res_path("data/mining_economy"),
		_res_path("assets/mining_economy"),
		_res_path("scripts/town/ui/negotiation_bar.gd"),
		_res_path("scripts/town/town_dialogue_menu.gd"),
		_res_path("scripts/town/town_hud.gd"),
		_res_path("scripts/town/town_panel_controller.gd"),
	]
	for path in removed_paths:
		_assert_false(_path_exists(path), "legacy unused file removed: %s" % path)


func _test_project_docs_are_current() -> void:
	var project_context := FileAccess.get_file_as_string("res://docs/PROJECT_CONTEXT.md")
	var summary := FileAccess.get_file_as_string("res://docs/fusion_v2_implementation_summary.md")
	_assert_false(FileAccess.file_exists(_res_path("PROJECT_CONTEXT.md")), "root project context doc moved into docs")
	_assert_true(project_context.contains("主场景：`res://scenes/town/mining_town.tscn`"), "project context names fused town as main scene")
	_assert_true(project_context.contains("矿洞场景：`res://scenes/mine/test_scene.tscn`"), "project context names GJ mine route")
	_assert_true(project_context.contains("MinecartExit"), "project context documents minecart return route")
	_assert_true(project_context.contains("RESULT: PASS 456 assertions"), "project context has current test count")
	_assert_false(project_context.contains("E:\\GD_Project\\GJ"), "project context does not mention old GJ workspace root")
	_assert_false(project_context.contains("主场景：`res://scenes/mine/test_scene.tscn`"), "project context does not use old GJ main scene")
	_assert_true(summary.contains("RESULT: PASS 456 assertions"), "fusion summary has current test count")
	_assert_false(summary.contains("mine player collision shape is disabled"), "fusion summary does not document broken collision state")


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
	var removed_root_entries := ["Scene", "Scripts", "art"]
	for entry_name in removed_root_entries:
		_assert_false(_root_entry_exists_exact(entry_name), "legacy top-level directory removed: %s" % entry_name)
	var removed_dirs := [
		_res_path("assets/fusion"),
		_res_path("assets/mining_economy"),
	]
	for dir_path in removed_dirs:
		_assert_false(DirAccess.dir_exists_absolute(dir_path), "legacy directory removed: %s" % dir_path)


func _test_no_legacy_res_paths_after_layout_migration() -> void:
	var roots := ["res://project.godot", "res://scenes", "res://scripts", "res://assets", "res://data", "res://docs", "res://tests"]
	var stale_terms := [
		_res_path("Scene/"),
		_res_path("Scripts/"),
		_res_path("art/"),
		_res_path("assets/mining_economy"),
		_res_path("assets/fusion"),
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


func _test_town_player_uses_gj_character_visuals() -> void:
	var town_script_text := FileAccess.get_file_as_string("res://scripts/town/fused_mining_town_scene.gd")
	_assert_true(town_script_text.contains("res://assets/gj/characters/player/main_char_sprite_frames.tres"), "town player uses GJ SpriteFrames resource")
	_assert_true(town_script_text.contains("AnimatedSprite2D.new()"), "town player creates AnimatedSprite2D")
	_assert_false(town_script_text.contains("player_sprites_normalized.png"), "town player no longer references p-1 town player sprite")
	var controller_script = load("res://scripts/town/town_player_controller.gd")
	var controller = controller_script.new()
	_assert_true(controller.has_method("configure_animated_sprite"), "town movement controller supports animated mine character sprite")
	controller.free()


func _test_town_characters_share_visual_scale() -> void:
	var town_script_text := FileAccess.get_file_as_string("res://scripts/town/fused_mining_town_scene.gd")
	_assert_true(town_script_text.contains("const TOWN_CHARACTER_SCALE := 1.25"), "town character scale preserves GJ player display size")
	_assert_false(town_script_text.contains("const TOWN_CHARACTER_SCALE := 0.28"), "town character scale does not shrink to old p-1 player size")
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
	var town_script_text := FileAccess.get_file_as_string("res://scripts/town/fused_mining_town_scene.gd")
	_assert_true(town_script_text.contains("\"blocked_polygons\": []"), "town movement has no temporary blocked polygons")
	var town_script = load("res://scripts/town/fused_mining_town_scene.gd")
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
	_assert_true(packed != null, "GJ mine scene loads for minecart route")
	if packed == null:
		return
	var scene := packed.instantiate()
	var minecart := scene.get_node_or_null("MinecartExit")
	_assert_true(minecart != null, "mine scene has MinecartExit node")
	if minecart != null:
		_assert_eq("res://scenes/town/mining_town.tscn", str(minecart.get("target_scene")), "minecart targets fused town")
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
	_assert_eq("res://scenes/town/mining_town.tscn", str(ProjectSettings.get_setting("application/run/main_scene", "")), "main scene is fused town")
	_assert_true(FileAccess.file_exists("res://scenes/town/mining_town.tscn"), "fused town scene exists")
	_assert_true(FileAccess.file_exists("res://scenes/mine/test_scene.tscn"), "GJ mine scene exists at normalized route")


func _test_mine_return_route() -> void:
	_assert_true(FileAccess.file_exists("res://scripts/town/mine_exit.gd"), "mine exit script exists")
	var packed: PackedScene = load("res://scenes/mine/test_scene.tscn")
	_assert_true(packed != null, "GJ mine scene loads for return route")
	if packed == null:
		return
	var scene := packed.instantiate()
	var exit := scene.get_node_or_null("MinecartExit")
	_assert_true(exit != null, "mine scene has MinecartExit node")
	if exit != null:
		_assert_eq("res://scenes/town/mining_town.tscn", str(exit.get("target_scene")), "mine exit targets fused town")
	scene.free()


func _test_core_economy_loop() -> void:
	var runtime_script = load("res://scripts/core/game_runtime.gd")
	_assert_true(runtime_script != null, "runtime script loads for economy loop")
	if runtime_script == null:
		return
	var runtime: Node = runtime_script.new()
	var init_result: Dictionary = runtime.initialize_for_new_game()
	_assert_true(init_result.get("ok", false), "runtime initializes core services")
	var collect_result: Dictionary = runtime.get("transactions").apply({
		"type": "collect_item",
		"item_id": "raw_common_geode",
		"quantity": 1,
		"source": "fusion_test_mine",
	})
	_assert_true(collect_result.get("ok", false), "mine collection enters unified inventory")
	_assert_true(runtime.get("inventory").has_item("raw_common_geode", 1), "raw geode is in unified inventory")
	var identify_result: Dictionary = runtime.get("identification_service").identify("raw_common_geode", {"station": "fusion_test_town"})
	_assert_true(identify_result.get("ok", false), "town identification consumes raw and creates mineral")
	_assert_eq(0, _count_item(runtime, "raw_common_geode"), "raw geode consumed after identification")
	var mineral_id := str(identify_result.get("item_id", ""))
	_assert_true(_count_item(runtime, mineral_id) >= 1, "identified mineral is in unified inventory")
	var balance_before_sale := int(runtime.get("wallet").get_balance())
	var sale_result: Dictionary = runtime.get("shop_service").sell_to_customer("buyer_blacksmith", mineral_id, 1, {"timing": "good"})
	_assert_true(sale_result.get("ok", false), "town buyer sells identified mineral through unified transaction")
	_assert_true(int(runtime.get("wallet").get_balance()) > balance_before_sale, "sale increases unified wallet")
	var task_claim: Dictionary = runtime.get("task_service").claim_reward("task_first_identification")
	_assert_true(task_claim.get("ok", false), "identification task can be claimed after town loop")
	_assert_true(runtime.get("inventory").has_item("raw_fine_geode", 1), "task reward enters unified inventory")
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
	for stack_variant in runtime.get("inventory").get_stacks():
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
