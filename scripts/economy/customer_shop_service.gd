extends RefCounted
## Customer shop service. Sells items from the warehouse to a customer
## buyer, routed through the transaction service so the wallet, warehouse
## and customer budget are all updated atomically.
##
## The budget check and decrement are handled inside GameTransactionService
## (so a failure anywhere in the apply() call rolls back the budget
## snapshot). This service is a thin wrapper that resolves the offer and
## delegates to the transaction boundary.

var catalog: Object
var transactions: Object
var negotiation: Object


func _init(game_catalog: Object = null, transaction_service: Object = null, negotiation_service: Object = null) -> void:
	catalog = game_catalog
	transactions = transaction_service
	negotiation = negotiation_service


func sell_to_customer(customer_id: String, item_id: String, quantity: int = 1, context: Dictionary = {}) -> Dictionary:
	var offer: Dictionary = negotiation.resolve_offer(customer_id, item_id, quantity, context)
	if not offer.get("ok", false):
		return offer
	var result: Dictionary = transactions.apply({
		"type": "sell_item",
		"customer_id": customer_id,
		"item_id": item_id,
		"quantity": quantity,
		"unit_price": int(offer.get("unit_price", 0)),
		"source": "warehouse",
	})
	if not result.get("ok", false):
		return result
	result["offer"] = offer
	return result


func list_customers() -> Array:
	return catalog.get_customers()
