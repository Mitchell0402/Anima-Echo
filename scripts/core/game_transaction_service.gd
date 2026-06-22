extends RefCounted

var catalog: Object
var inventory: Object
var wallet: Object
var event_bus: Object
var rng: Object


func _init(game_catalog: Object = null, game_inventory: Object = null, game_wallet: Object = null, game_event_bus: Object = null, game_rng: Object = null) -> void:
	catalog = game_catalog
	inventory = game_inventory
	wallet = game_wallet
	event_bus = game_event_bus
	rng = game_rng


func apply(request: Dictionary) -> Dictionary:
	var transaction_type: String = str(request.get("type", ""))
	var inventory_snapshot: Array = inventory.snapshot()
	var wallet_snapshot: int = wallet.snapshot()
	var result: Dictionary = _apply_inner(transaction_type, request)
	if not result.get("ok", false):
		inventory.restore(inventory_snapshot)
		wallet.restore(wallet_snapshot)
		return result
	return result


func _apply_inner(transaction_type: String, request: Dictionary) -> Dictionary:
	match transaction_type:
		"collect_item":
			return _collect_item(request)
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


func _sell_item(request: Dictionary) -> Dictionary:
	var item_id: String = str(request.get("item_id", ""))
	var quantity: int = int(request.get("quantity", 1))
	var unit_price: int = int(request.get("unit_price", catalog.get_item(item_id).get("base_price", 0)))
	if quantity <= 0:
		return _fail("quantity_invalid", "Quantity must be positive.")
	if not catalog.has_item(item_id):
		return _fail("item_unknown", "Unknown item: %s" % item_id)
	if not inventory.has_item(item_id, quantity):
		return _fail("insufficient_item", "Not enough %s." % item_id)
	var removed: Dictionary = inventory.remove_item(item_id, quantity)
	if not removed.get("ok", false):
		return removed
	var total_price: int = unit_price * quantity
	var paid: Dictionary = wallet.add_currency(total_price)
	if not paid.get("ok", false):
		return paid
	var item: Dictionary = catalog.get_item(item_id)
	var payload: Dictionary = {
		"item_id": item_id,
		"quantity": quantity,
		"unit_price": unit_price,
		"total_price": total_price,
		"customer_id": str(request.get("customer_id", "")),
	}
	event_bus.emit_game_event("item_sold", payload)
	if item.get("tags", []).has("sensitive"):
		event_bus.emit_game_event("moral_action_occurred", payload)
	return {"ok": true, "item_id": item_id, "quantity": quantity, "total_price": total_price}


func _identify_stone(request: Dictionary) -> Dictionary:
	var raw_item_id: String = str(request.get("raw_item_id", ""))
	var result_item_id: String = str(request.get("result_item_id", ""))
	var quantity: int = int(request.get("quantity", 1))
	var consume_raw: bool = bool(request.get("consume_raw", true))
	if quantity <= 0:
		return _fail("quantity_invalid", "Quantity must be positive.")
	if consume_raw and not inventory.has_item(raw_item_id, quantity):
		return _fail("insufficient_item", "Not enough raw stones.")
	if not catalog.has_item(result_item_id):
		return _fail("item_unknown", "Unknown item: %s" % result_item_id)
	if consume_raw:
		var removed: Dictionary = inventory.remove_item(raw_item_id, quantity)
		if not removed.get("ok", false):
			return removed
	var added: Dictionary = inventory.add_item(result_item_id, quantity, request.get("metadata", {}))
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
	var requirements: Array = request.get("requirements", [])
	if not inventory.has_requirements(requirements):
		return _fail("requirements_missing", "Missing delivery items.")
	for requirement_variant in requirements:
		var requirement: Dictionary = requirement_variant
		var removed: Dictionary = inventory.remove_item(str(requirement.get("item_id", "")), int(requirement.get("quantity", requirement.get("count", 1))))
		if not removed.get("ok", false):
			return removed
	event_bus.emit_game_event("task_items_delivered", {
		"task_id": str(request.get("task_id", "")),
		"requirements": requirements.duplicate(true),
	})
	return {"ok": true}


func _grant_task_rewards(request: Dictionary) -> Dictionary:
	var rewards: Array = request.get("rewards", [])
	var currency_reward: int = int(request.get("currency_reward", 0))
	for reward_variant in rewards:
		var reward: Dictionary = reward_variant
		var item_id: String = str(reward.get("item_id", ""))
		var quantity: int = int(reward.get("quantity", 1))
		if not catalog.has_item(item_id):
			return _fail("item_unknown", "Unknown reward item: %s" % item_id)
		var added: Dictionary = inventory.add_item(item_id, quantity)
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
	var unit_price: int = int(request.get("unit_price", catalog.get_item(item_id).get("base_price", 0)))
	var total_cost: int = unit_price * quantity
	if not catalog.has_item(item_id):
		return _fail("item_unknown", "Unknown item: %s" % item_id)
	var spent: Dictionary = wallet.spend_currency(total_cost)
	if not spent.get("ok", false):
		return spent
	var added: Dictionary = inventory.add_item(item_id, quantity, request.get("metadata", {}))
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
