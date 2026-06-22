extends RefCounted

var catalog: Object
var transactions: Object
var rng: Object


func _init(game_catalog: Object = null, transaction_service: Object = null, game_rng: Object = null) -> void:
	catalog = game_catalog
	transactions = transaction_service
	rng = game_rng


func identify(raw_item_id: String, context: Dictionary = {}) -> Dictionary:
	var raw_item: Dictionary = catalog.get_item(raw_item_id)
	if raw_item.is_empty():
		return _fail("item_unknown", "Unknown raw item: %s" % raw_item_id)
	if str(raw_item.get("category", "")) != "raw_stone":
		return _fail("item_not_raw", "Only raw stones can be identified.")
	var table_id: String = str(raw_item.get("identify_table", ""))
	var entry: Dictionary = catalog.roll_weighted(catalog.get_identify_table(table_id), rng)
	if entry.is_empty():
		return _fail("identify_table_empty", "No identify entries for %s." % table_id)
	var result: Dictionary = transactions.apply({
		"type": "identify_stone",
		"raw_item_id": raw_item_id,
		"result_item_id": str(entry.get("item_id", "")),
		"quantity": int(entry.get("quantity", 1)),
		"context": context.duplicate(true),
	})
	if not result.get("ok", false):
		return result
	result["table_id"] = table_id
	return result


func _fail(code: String, message: String) -> Dictionary:
	return {
		"ok": false,
		"error": code,
		"message": message,
	}
