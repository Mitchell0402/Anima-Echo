extends RefCounted

var catalog: Object
var rng: Object


func _init(game_catalog: Object = null, game_rng: Object = null) -> void:
	catalog = game_catalog
	rng = game_rng


func resolve_offer(customer_id: String, item_id: String, quantity: int = 1, context: Dictionary = {}) -> Dictionary:
	var item: Dictionary = catalog.get_item(item_id)
	if item.is_empty():
		return _fail("item_unknown", "Unknown item: %s" % item_id)
	var customer: Dictionary = catalog.get_customer(customer_id)
	if customer.is_empty():
		return _fail("customer_unknown", "Unknown customer: %s" % customer_id)
	if quantity <= 0:
		return _fail("quantity_invalid", "Quantity must be positive.")
	var tags: Array = item.get("tags", [])
	for tag in customer.get("rejected_tags", []):
		if tags.has(tag):
			return _fail("customer_rejected_item", "%s rejected %s." % [customer_id, item_id])
	var base_price: int = int(item.get("base_price", 1))
	if str(context.get("price_mode", "")) == "base":
		var base_unit_price: int = maxi(1, base_price)
		return {
			"ok": true,
			"customer_id": customer_id,
			"item_id": item_id,
			"quantity": quantity,
			"unit_price": base_unit_price,
			"total_price": base_unit_price * quantity,
			"price_mode": "base",
		}
	var multiplier: float = float(customer.get("price_multiplier", 1.0))
	var preferred_bonus: float = _preferred_bonus(tags, customer.get("preferred_tags", []))
	var timing_bonus: float = _timing_bonus(str(context.get("timing", "normal")))
	var variance: float = lerpf(0.96, 1.04, _randf())
	var unit_price: int = maxi(1, int(round(float(base_price) * multiplier * preferred_bonus * timing_bonus * variance)))
	return {
		"ok": true,
		"customer_id": customer_id,
		"item_id": item_id,
		"quantity": quantity,
		"unit_price": unit_price,
		"total_price": unit_price * quantity,
	}


func _preferred_bonus(item_tags: Array, preferred_tags: Array) -> float:
	for tag in preferred_tags:
		if item_tags.has(tag):
			return 1.08
	return 1.0


# Timing multiplier on top of the base price. "normal" is the
# default path used by the direct-sell button (no QTE, no
# negotiation). "perfect" is the bonus the QTE gives on success
# and "bad" is the discount it gives on failure.
func _timing_bonus(timing: String) -> float:
	match timing:
		"perfect":
			return 1.18
		"good":
			# Kept for backward compatibility: "good" used to mean
			# 1.08x. The direct-sell path now passes "normal" so the
			# 1.08x branch is no longer reached; map "good" to 1.0x
			# so any future caller that still says "good" gets the
			# expected base price instead of an unexplained 8% bonus.
			return 1.0
		"normal":
			return 1.0
		"bad":
			return 0.85
		_:
			return 1.0


func _randf() -> float:
	if rng != null and rng.has_method("randf"):
		return clampf(float(rng.call("randf")), 0.0, 1.0)
	return randf()


func _fail(code: String, message: String) -> Dictionary:
	return {
		"ok": false,
		"error": code,
		"message": message,
	}
