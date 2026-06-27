extends RefCounted
## Single mutation boundary. Every change to inventory / warehouse / wallet
## flows through apply(request). Each request type snapshots both collections
## and the wallet; a failure inside _apply_inner restores them.

const ERROR_WAREHOUSE_FULL: String = "warehouse_full"
const ERROR_WAREHOUSE_SOFT_CAP: String = "warehouse_soft_cap"

var catalog: Object
var inventory: Object         # Alias of GameRuntime.hotbar. Kept as `inventory` so the
                              # service can be constructed and tested in isolation;
                              # the public field on GameRuntime is `hotbar`.
var warehouse: Object
var wallet: Object
var event_bus: Object
var rng: Object
var runtime: Object  # Optional reference to GameRuntime. Used by _sell_item to
                     # check and decrement the customer budget atomically with
                     # the rest of the transaction. When null, budget is not
                     # enforced (legacy / test paths).


func _init(game_catalog: Object = null, game_inventory: Object = null, game_warehouse: Object = null, game_wallet: Object = null, game_event_bus: Object = null, game_rng: Object = null) -> void:
	catalog = game_catalog
	inventory = game_inventory
	warehouse = game_warehouse
	wallet = game_wallet
	event_bus = game_event_bus
	rng = game_rng


func apply(request: Dictionary) -> Dictionary:
	var transaction_type: String = str(request.get("type", ""))
	var inventory_snapshot: Array = inventory.snapshot() if inventory != null and inventory.has_method("snapshot") else []
	var warehouse_snapshot: Array = warehouse.snapshot() if warehouse != null and warehouse.has_method("snapshot") else []
	var wallet_snapshot: int = wallet.snapshot() if wallet != null and wallet.has_method("snapshot") else 0
	# Snapshot the customer budget too if the request will touch it. Only
	# sell_item consumes budget today; we snapshot on demand to keep
	# the rollback path symmetric (always restore to whatever was there).
	var budget_snapshot: Dictionary = _snapshot_budget()
	var result: Dictionary = _apply_inner(transaction_type, request)
	if not result.get("ok", false):
		if inventory != null and inventory.has_method("restore"):
			inventory.restore(inventory_snapshot)
		if warehouse != null and warehouse.has_method("restore"):
			warehouse.restore(warehouse_snapshot)
		if wallet != null and wallet.has_method("restore"):
			wallet.restore(wallet_snapshot)
		_restore_budget(budget_snapshot)
		return result
	return result


# Take a shallow copy of customer_remaining_budget so the transaction
# service can roll it back on failure. The dictionary values are ints, so
# a shallow copy is enough.
func _snapshot_budget() -> Dictionary:
	if runtime == null or not runtime.has_method("get"):
		return {}
	var src: Dictionary = runtime.get("customer_remaining_budget")
	if src == null:
		return {}
	return src.duplicate(true)


func _restore_budget(snapshot: Dictionary) -> void:
	if runtime == null or snapshot.is_empty():
		return
	if not runtime.has_method("get"):
		return
	var target: Dictionary = runtime.get("customer_remaining_budget")
	if target == null:
		return
	target.clear()
	for key in snapshot.keys():
		target[key] = snapshot[key]


func _apply_inner(transaction_type: String, request: Dictionary) -> Dictionary:
	match transaction_type:
		"collect_item":
			return _collect_item(request)
		"collect_item_into_warehouse":
			return _collect_item_into_warehouse(request)
		"move_stack_from_hotbar_to_warehouse":
			return _move_stack_from_hotbar_to_warehouse(request)
		"sell_item":
			return _sell_item(request)
		"identify_stone":
			return _identify_stone(request)
		"deliver_task_items":
			return _deliver_task_items(request)
		"grant_task_rewards":
			return _grant_task_rewards(request)
		"buy_item":
			return _buy_item(request)
		_:
			return _fail("transaction_unknown", "Unknown transaction type: %s" % transaction_type)


func _collect_item(request: Dictionary) -> Dictionary:
	var item_id: String = str(request.get("item_id", ""))
	var quantity: int = int(request.get("quantity", 1))
	if not catalog.has_item(item_id):
		return _fail("item_unknown", "Unknown item: %s" % item_id)
	var added: Dictionary = inventory.add_item(item_id, quantity, request.get("metadata", {}))
	if not added.get("ok", false):
		return added
	event_bus.emit_game_event("item_collected", {
		"item_id": item_id,
		"quantity": quantity,
		"source": str(request.get("source", "")),
	})
	return {"ok": true, "item_id": item_id, "quantity": quantity}


func _collect_item_into_warehouse(request: Dictionary) -> Dictionary:
	var item_id: String = str(request.get("item_id", ""))
	var quantity: int = int(request.get("quantity", 1))
	if not catalog.has_item(item_id):
		return _fail("item_unknown", "Unknown item: %s" % item_id)
	var added: Dictionary = warehouse.add_item(item_id, quantity, request.get("metadata", {}))
	if not added.get("ok", false):
		# Translate the warehouse-soft-cap and warehouse-full errors to
		# distinct codes so callers (and the run_all test) can distinguish
		# "would exceed item cap" from "no slot left".
		if added.get("error", "") == "inventory_soft_cap":
			return _fail(ERROR_WAREHOUSE_SOFT_CAP, added.get("message", ""))
		if added.get("error", "") == "inventory_full":
			return _fail(ERROR_WAREHOUSE_FULL, added.get("message", ""))
		return added
	event_bus.emit_game_event("item_collected", {
		"item_id": item_id,
		"quantity": quantity,
		"source": str(request.get("source", "")),
		"destination": "warehouse",
	})
	return {"ok": true, "item_id": item_id, "quantity": quantity}


func _move_stack_from_hotbar_to_warehouse(request: Dictionary) -> Dictionary:
	var item_id: String = str(request.get("item_id", ""))
	var quantity: int = int(request.get("quantity", 1))
	if not catalog.has_item(item_id):
		return _fail("item_unknown", "Unknown item: %s" % item_id)
	if not inventory.has_item(item_id, quantity):
		return _fail("insufficient_item", "Not enough %s in hotbar." % item_id)
	var meta: Dictionary = request.get("metadata", {})
	# First try to add to the warehouse; if that fails, abort without
	# touching the hotbar so the dump can be retried after the player
	# frees warehouse space.
	var added: Dictionary = warehouse.add_item(item_id, quantity, meta)
	if not added.get("ok", false):
		if added.get("error", "") == "inventory_soft_cap":
			return _fail(ERROR_WAREHOUSE_SOFT_CAP, added.get("message", ""))
		if added.get("error", "") == "inventory_full":
			return _fail(ERROR_WAREHOUSE_FULL, added.get("message", ""))
		return added
	var removed: Dictionary = inventory.remove_item(item_id, quantity, meta)
	if not removed.get("ok", false):
		# Roll back the warehouse add: snapshot/restore will also catch this
		# in apply(), but call explicitly so a manual call site is safe.
		warehouse.remove_item(item_id, quantity, meta)
		return _fail("hotbar_remove_failed", "Could not remove from hotbar after warehouse add.")
	event_bus.emit_game_event("item_collected", {
		"item_id": item_id,
		"quantity": quantity,
		"source": str(request.get("source", "mine_run_end")),
		"destination": "warehouse",
	})
	return {"ok": true, "item_id": item_id, "quantity": quantity}


func _sell_item(request: Dictionary) -> Dictionary:
	var item_id: String = str(request.get("item_id", ""))
	var quantity: int = int(request.get("quantity", 1))
	var source: String = str(request.get("source", "inventory"))
	var customer_id: String = str(request.get("customer_id", ""))
	var unit_price: int = int(request.get("unit_price", catalog.get_item(item_id).get("base_price", 0)))
	if quantity <= 0:
		return _fail("quantity_invalid", "Quantity must be positive.")
	if not catalog.has_item(item_id):
		return _fail("item_unknown", "Unknown item: %s" % item_id)
	# Customer budget check happens inside the transaction so the rollback
	# in apply() restores it on any downstream failure. If runtime is
	# null (legacy / test), the budget is not enforced.
	var total_price: int = unit_price * quantity
	if runtime != null and customer_id != "":
		if runtime.has_method("get_customer_remaining_budget"):
			var remaining: int = int(runtime.get_customer_remaining_budget(customer_id))
			if total_price > 0 and remaining < total_price:
				return _fail("customer_out_of_budget",
					"%s cannot afford %d (remaining %d)." % [customer_id, total_price, remaining])
	# Sell reads from the warehouse (which is the only collection the town
	# NPC actions see). The hotbar is in-mine and never seen by a town NPC.
	var source_collection: Object = warehouse if source == "warehouse" else inventory
	if not source_collection.has_item(item_id, quantity):
		return _fail("insufficient_item", "Not enough %s." % item_id)
	var removed: Dictionary = source_collection.remove_item(item_id, quantity)
	if not removed.get("ok", false):
		return removed
	# Decrement the customer budget now that we are committed to the
	# sale. If wallet.add_currency fails after this point, apply() will
	# roll back the budget snapshot.
	if runtime != null and customer_id != "" and total_price > 0:
		if runtime.has_method("consume_customer_budget"):
			var consumed: Dictionary = runtime.consume_customer_budget(customer_id, total_price)
			if not consumed.get("ok", false):
				return consumed
	var paid: Dictionary = wallet.add_currency(total_price)
	if not paid.get("ok", false):
		return paid
	var item: Dictionary = catalog.get_item(item_id)
	var payload: Dictionary = {
		"item_id": item_id,
		"quantity": quantity,
		"unit_price": unit_price,
		"total_price": total_price,
		"customer_id": customer_id,
	}
	event_bus.emit_game_event("item_sold", payload)
	if item.get("tags", []).has("sensitive"):
		event_bus.emit_game_event("moral_action_occurred", payload)
	return {"ok": true, "item_id": item_id, "quantity": quantity, "total_price": total_price}


func _identify_stone(request: Dictionary) -> Dictionary:
	var raw_item_id: String = str(request.get("raw_item_id", ""))
	var result_item_id: String = str(request.get("result_item_id", ""))
	var quantity: int = int(request.get("quantity", 1))
	var source: String = str(request.get("source", "warehouse"))
	var consume_raw: bool = bool(request.get("consume_raw", true))
	var destination: String = str(request.get("destination", "warehouse"))
	if quantity <= 0:
		return _fail("quantity_invalid", "Quantity must be positive.")
	if not catalog.has_item(result_item_id):
		return _fail("item_unknown", "Unknown item: %s" % result_item_id)
	var source_collection: Object = warehouse if source == "warehouse" else inventory
	if consume_raw:
		if not source_collection.has_item(raw_item_id, quantity):
			return _fail("insufficient_item", "Not enough raw stones.")
		var removed: Dictionary = source_collection.remove_item(raw_item_id, quantity)
		if not removed.get("ok", false):
			return removed
	var dest_collection: Object = warehouse if destination == "warehouse" else inventory
	var added: Dictionary = dest_collection.add_item(result_item_id, quantity, request.get("metadata", {}))
	if not added.get("ok", false):
		return added
	var payload: Dictionary = {
		"raw_item_id": raw_item_id,
		"item_id": result_item_id,
		"quantity": quantity,
		"context": request.get("context", {}),
	}
	event_bus.emit_game_event("item_identified", payload)
	return {"ok": true, "item_id": result_item_id, "quantity": quantity}


func _deliver_task_items(request: Dictionary) -> Dictionary:
	var source: String = str(request.get("source", "warehouse"))
	var requirements: Array = request.get("requirements", [])
	var source_collection: Object = warehouse if source == "warehouse" else inventory
	if not source_collection.has_requirements(requirements):
		return _fail("requirements_missing", "Missing delivery items.")
	for requirement_variant in requirements:
		var requirement: Dictionary = requirement_variant
		var removed: Dictionary = source_collection.remove_item(str(requirement.get("item_id", "")), int(requirement.get("quantity", requirement.get("count", 1))))
		if not removed.get("ok", false):
			return removed
	event_bus.emit_game_event("task_items_delivered", {
		"task_id": str(request.get("task_id", "")),
		"requirements": requirements.duplicate(true),
	})
	return {"ok": true}
	return {"ok": true}


func _grant_task_rewards(request: Dictionary) -> Dictionary:
	var destination: String = str(request.get("destination", "warehouse"))
	var rewards: Array = request.get("rewards", [])
	var currency_reward: int = int(request.get("currency_reward", 0))
	var dest_collection: Object = warehouse if destination == "warehouse" else inventory
	for reward_variant in rewards:
		var reward: Dictionary = reward_variant
		var item_id: String = str(reward.get("item_id", ""))
		var quantity: int = int(reward.get("quantity", 1))
		if not catalog.has_item(item_id):
			return _fail("item_unknown", "Unknown reward item: %s" % item_id)
		var added: Dictionary = dest_collection.add_item(item_id, quantity)
		if not added.get("ok", false):
			return added
	if currency_reward > 0:
		var paid: Dictionary = wallet.add_currency(currency_reward)
		if not paid.get("ok", false):
			return paid
	event_bus.emit_game_event("task_reward_claimed", {
		"task_id": str(request.get("task_id", "")),
		"rewards": rewards.duplicate(true),
		"currency_reward": currency_reward,
	})
	return {"ok": true}


func _buy_item(request: Dictionary) -> Dictionary:
	var item_id: String = str(request.get("item_id", ""))
	var quantity: int = int(request.get("quantity", 1))
	var destination: String = str(request.get("destination", "warehouse"))
	var unit_price: int = int(request.get("unit_price", catalog.get_item(item_id).get("base_price", 0)))
	var total_cost: int = unit_price * quantity
	if not catalog.has_item(item_id):
		return _fail("item_unknown", "Unknown item: %s" % item_id)
	var spent: Dictionary = wallet.spend_currency(total_cost)
	if not spent.get("ok", false):
		return spent
	var dest_collection: Object = warehouse if destination == "warehouse" else inventory
	var added: Dictionary = dest_collection.add_item(item_id, quantity, request.get("metadata", {}))
	if not added.get("ok", false):
		return added
	event_bus.emit_game_event("item_bought", {
		"item_id": item_id,
		"quantity": quantity,
		"unit_price": unit_price,
		"total_cost": total_cost,
	})
	return {"ok": true, "item_id": item_id, "quantity": quantity, "total_cost": total_cost}


func _fail(code: String, message: String) -> Dictionary:
	return {
		"ok": false,
		"error": code,
		"message": message,
	}
