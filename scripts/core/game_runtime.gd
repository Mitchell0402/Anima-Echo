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

var catalog: Object
var event_bus: Object
var inventory: Object
var wallet: Object
var rng: RandomNumberGenerator
var transactions: Object
var identification_service: Object
var negotiation_service: Object
var shop_service: Object
var task_service: Object


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
	inventory = GameInventoryScript.new(18)
	wallet = GameWalletScript.new(50)
	rng = RandomNumberGenerator.new()
	rng.randomize()
	transactions = GameTransactionServiceScript.new(catalog, inventory, wallet, event_bus, rng)
	identification_service = IdentificationServiceScript.new(catalog, transactions, rng)
	negotiation_service = NegotiationServiceScript.new(catalog, rng)
	shop_service = CustomerShopServiceScript.new(catalog, transactions, negotiation_service)
	task_service = TaskServiceScript.new(catalog, transactions, event_bus)
	task_service.accept_task("task_first_identification")
	return {"ok": true}


func shutdown() -> void:
	if task_service != null and task_service.has_method("dispose"):
		task_service.dispose()
	task_service = null
	shop_service = null
	negotiation_service = null
	identification_service = null
	transactions = null
	rng = null
	wallet = null
	inventory = null
	event_bus = null
	catalog = null
