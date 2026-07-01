extends Node

const GameCatalogScript = preload("res://scripts/core/game_catalog.gd")
const GameEventBusScript = preload("res://scripts/core/game_event_bus.gd")
const GameInventoryScript = preload("res://scripts/core/game_inventory.gd")
const GameTransactionServiceScript = preload("res://scripts/core/game_transaction_service.gd")
const GameWalletScript = preload("res://scripts/core/game_wallet.gd")
const CustomerShopServiceScript = preload("res://scripts/economy/customer_shop_service.gd")
const IdentificationServiceScript = preload("res://scripts/economy/identification_service.gd")
const NegotiationServiceScript = preload("res://scripts/economy/negotiation_service.gd")
const TaskServiceScript = preload("res://scripts/economy/task_service.gd")
const MoralityTrackerScript = preload("res://scripts/core/morality_tracker.gd")
const NpcAffectionScript = preload("res://scripts/narrative/npc_affection.gd")
const EquipmentSystemScript = preload("res://scripts/player/equipment_system.gd")

const HOTBAR_CAPACITY: int = 12
const HOTBAR_DEFAULT_MAX_ITEMS: int = 0
const WAREHOUSE_CAPACITY: int = 48
const WAREHOUSE_DEFAULT_MAX_ITEMS: int = 999
const MINE_SCENE_NAME: String = "testScene"
const DUNGEON_ROOM_SCENE: String = "res://scenes/mine/dungeon_room.tscn"

# ---- 地牢模式跨场景状态 ----
var dungeon_layout: Dictionary = {}         # DungeonGenerator.DungeonLayout 序列化
var dungeon_room_cleared: Dictionary = {}    # String(Vector2i) -> bool
var dungeon_current_room: Vector2i = Vector2i.ZERO
var dungeon_entrance_dir: Vector2i = Vector2i.ZERO  # 从哪个方向进入当前房间
var dungeon_difficulty: int = 1
var dungeon_player_health: float = 100.0

var catalog: Object
var event_bus: Object
var hotbar: Object            # In-mine backpack, 12 slots, cleared on mine entry and death.
var warehouse: Object         # At-home storage, 48 slots, 999-item soft cap.
var wallet: Object
var rng: RandomNumberGenerator
var transactions: Object
var identification_service: Object
var negotiation_service: Object
var shop_service: Object
var task_service: Object
var morality_tracker: Object
var npc_affection: Object
var equipment_system: Object
var customer_remaining_budget: Dictionary = {}  # customer_id -> int
var _blacksmith_first_talk_done: bool = false
var _florist_first_star_gifted: bool = false

signal mine_run_started
signal mine_run_ended(remaining_untransferred: int)

# 地牢模式：城镇入口传递难度给 dungeon_room
var _pending_mine_difficulty: int = 1

func set_pending_mine_difficulty(diff: int) -> void:
	_pending_mine_difficulty = clampi(diff, 1, 5)

func get_pending_mine_difficulty() -> int:
	return _pending_mine_difficulty

## 生成地牢布局并存储（跨场景持久）
func generate_dungeon_layout(combat_rooms: int) -> void:
	var gen := load("res://scripts/mine/dungeon_generator.gd")
	var layout = gen.generate(combat_rooms)
	dungeon_layout = {
		"rooms": layout.rooms,
		"connections": layout.connections,
		"boss_cell": layout.boss_cell,
		"start_cell": layout.start_cell,
	}
	dungeon_room_cleared.clear()
	for cell in layout.rooms:
		dungeon_room_cleared[str(cell)] = (layout.rooms[cell] == 0)  # START already cleared
	dungeon_current_room = layout.start_cell
	dungeon_entrance_dir = Vector2i.ZERO
	dungeon_player_health = 100.0

func get_dungeon_connections_for(cell: Vector2i) -> Array:
	var result: Array = []
	for conn in dungeon_layout.get("connections", []):
		var d: Dictionary = conn
		if d["from"] == cell:
			result.append({"neighbor": d["to"], "dir": d["to"] - cell})
		elif d["to"] == cell:
			result.append({"neighbor": d["from"], "dir": d["from"] - cell})
	return result

func is_dungeon_room_cleared(cell: Vector2i) -> bool:
	return dungeon_room_cleared.get(str(cell), false)

func mark_dungeon_room_cleared(cell: Vector2i) -> void:
	dungeon_room_cleared[str(cell)] = true


func _ready() -> void:
	if catalog == null:
		initialize_for_new_game()


func initialize_for_new_game() -> Dictionary:
	shutdown()
	catalog = GameCatalogScript.new()
	var load_result: Dictionary = catalog.load_defaults()
	if not load_result.get("ok", false):
		return load_result
	event_bus = GameEventBusScript.new()
	hotbar = GameInventoryScript.new(HOTBAR_CAPACITY)
	hotbar.max_items = HOTBAR_DEFAULT_MAX_ITEMS
	warehouse = GameInventoryScript.new(WAREHOUSE_CAPACITY)
	warehouse.max_items = WAREHOUSE_DEFAULT_MAX_ITEMS
	wallet = GameWalletScript.new(0)
	rng = RandomNumberGenerator.new()
	rng.randomize()
	_init_customer_budget()
	transactions = GameTransactionServiceScript.new(catalog, hotbar, warehouse, wallet, event_bus, rng)
	transactions.runtime = self
	identification_service = IdentificationServiceScript.new(catalog, transactions, rng)
	negotiation_service = NegotiationServiceScript.new(catalog, rng)
	shop_service = CustomerShopServiceScript.new(catalog, transactions, negotiation_service)
	task_service = TaskServiceScript.new(catalog, transactions, event_bus)
	task_service.set_source_collection(warehouse, "warehouse")
	task_service.accept_task("task_talk_to_townspeople")
	task_service.accept_task("task_first_identification")
	morality_tracker = MoralityTrackerScript.new()
	npc_affection = NpcAffectionScript.new()
	equipment_system = EquipmentSystemScript.new()
	equipment_system.load_data()
	_blacksmith_first_talk_done = false
	_florist_first_star_gifted = false
	return {"ok": true}


func _init_customer_budget() -> void:
	customer_remaining_budget.clear()
	for customer in catalog.get_customers():
		var customer_id: String = str(customer.get("id", ""))
		if customer_id.is_empty():
			continue
		customer_remaining_budget[customer_id] = int(customer.get("budget", 0))


func get_customer_remaining_budget(customer_id: String) -> int:
	return int(customer_remaining_budget.get(customer_id, 0))


func consume_customer_budget(customer_id: String, amount: int) -> Dictionary:
	if amount <= 0:
		return {"ok": true, "remaining": get_customer_remaining_budget(customer_id)}
	if not customer_remaining_budget.has(customer_id):
		return _fail("customer_unknown", "Unknown customer: %s" % customer_id)
	var current: int = int(customer_remaining_budget[customer_id])
	if current < amount:
		return _fail("customer_out_of_budget", "%s cannot afford %d (remaining %d)." % [customer_id, amount, current])
	customer_remaining_budget[customer_id] = current - amount
	return {"ok": true, "remaining": current - amount}


# Called when the player enters the mine. Clears hotbar, generates dungeon layout.
func begin_mine_run() -> void:
	hotbar.clear()

	# 根据难度决定战斗房间数
	var croom: int = 4
	match _pending_mine_difficulty:
		1: croom = 4
		2: croom = 4 if randi() % 2 == 0 else 5
		3: croom = 5
		4: croom = 5 if randi() % 2 == 0 else 6
		5: croom = 6

	dungeon_difficulty = _pending_mine_difficulty
	generate_dungeon_layout(croom)
	mine_run_started.emit()


# Called when the player returns to town. Dumps every hotbar stack into the
# warehouse via transactions. The dump is wrapped so a partial failure (for
# example, warehouse full) leaves the hotbar holding the untransferred items
# rather than losing them. Returns the count of items that could not be moved.
func end_mine_run() -> int:
	if hotbar == null or warehouse == null:
		return 0
	var total_untransferred: int = 0
	for stack_variant in hotbar.get_stacks():
		var stack: Dictionary = stack_variant
		var item_id: String = str(stack.get("item_id", ""))
		var quantity: int = int(stack.get("quantity", 0))
		var metadata: Dictionary = stack.get("metadata", {})
		if item_id.is_empty() or quantity <= 0:
			continue
		var result: Dictionary = transactions.apply({
			"type": "move_stack_from_hotbar_to_warehouse",
			"item_id": item_id,
			"quantity": quantity,
			"metadata": metadata,
			"source": "mine_run_end",
		})
		if not result.get("ok", false):
			total_untransferred += quantity
	mine_run_ended.emit(total_untransferred)
	return total_untransferred


# Called when the player dies in the mine. Hotbar is cleared; warehouse is
# untouched.
func on_player_killed_in_mine() -> void:
	if hotbar != null:
		hotbar.clear()


# Test / spec helper: true when the current scene is the mine. The weight
# system and warehouse-readonly UI use this to gate behavior.
func is_in_mine_scene() -> bool:
	var tree: SceneTree = get_tree() if is_inside_tree() else null
	if tree == null:
		return false
	var current: Node = tree.current_scene
	if current == null:
		return false
	var scene_name: String = str(current.name)
	return scene_name == MINE_SCENE_NAME or scene_name == "DungeonRoom"


func add_mine_tickets(n: int) -> void:
	if warehouse == null:
		return
	warehouse.add_item("mine_ticket", n)

func consume_mine_ticket() -> bool:
	if warehouse == null:
		return false
	return warehouse.remove_item("mine_ticket", 1).get("ok", false)

func get_mine_tickets() -> int:
	if warehouse == null:
		return 0
	return warehouse.count_item("mine_ticket")

func set_blacksmith_first_talk_done() -> void:
	_blacksmith_first_talk_done = true

func is_blacksmith_first_talk_done() -> bool:
	return _blacksmith_first_talk_done

func set_florist_first_star_gifted() -> void:
	_florist_first_star_gifted = true

func is_florist_first_star_gifted() -> bool:
	return _florist_first_star_gifted


func shutdown() -> void:
	if task_service != null and task_service.has_method("dispose"):
		task_service.dispose()
	task_service = null
	morality_tracker = null
	npc_affection = null
	equipment_system = null
	_blacksmith_first_talk_done = false
	_florist_first_star_gifted = false
	shop_service = null
	negotiation_service = null
	identification_service = null
	transactions = null
	rng = null
	wallet = null
	warehouse = null
	hotbar = null
	customer_remaining_budget.clear()
	event_bus = null
	catalog = null


func _fail(code: String, message: String) -> Dictionary:
	return {"ok": false, "error": code, "message": message}
