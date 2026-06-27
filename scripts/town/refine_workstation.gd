extends Node2D

## 矿石精炼工作台（独立交互物体）
##
## 消耗金币将普通矿物升级为精炼矿物。
## 精炼矿售价 ×2，送礼好感度 ×2。

const REFINE_COST_COMMON: int = 30
const REFINE_COST_RARE: int = 80
const REFINE_COST_LEGENDARY: int = 200

const INTERACT_RADIUS := 55.0

var _runtime: Node

func _ready() -> void:
	_runtime = get_node_or_null("/root/GameRuntime")

func station_position() -> Vector2:
	return position

func is_nearby(player_pos: Vector2) -> bool:
	return player_pos.distance_to(position) <= INTERACT_RADIUS

func get_refine_cost(rarity: String) -> int:
	match rarity:
		"rare", "epic": return REFINE_COST_RARE
		"legendary": return REFINE_COST_LEGENDARY
	return REFINE_COST_COMMON

func get_refined_item_id(original_id: String) -> String:
	return "refined_" + original_id

func refine(item_id: String) -> Dictionary:
	if _runtime == null:
		return {"ok": false, "error": "runtime not ready"}
	var warehouse: Object = _runtime.get("warehouse")
	var wallet: Object = _runtime.get("wallet")
	var catalog: Object = _runtime.get("catalog")
	if warehouse == null or wallet == null or catalog == null:
		return {"ok": false, "error": "services not ready"}

	var item: Dictionary = catalog.get_item(item_id)
	var category: String = str(item.get("category", ""))
	if category != "mineral":
		return {"ok": false, "error": "只能精炼矿物"}

	var rarity: String = str(item.get("rarity", "common"))
	var cost: int = get_refine_cost(rarity)
	if wallet.get_balance() < cost:
		return {"ok": false, "error": "铜板不足，需要 %d" % cost}

	var qty: int = int(warehouse.count_item(item_id))
	if qty <= 0:
		return {"ok": false, "error": "仓库中无此矿物"}

	wallet.spend_currency(cost)
	var removed: Dictionary = warehouse.remove_item(item_id, 1)
	if not removed.get("ok", false):
		wallet.spend_currency(-cost)  # refund
		return {"ok": false, "error": str(removed.get("error", "移除失败"))}

	var refined_id: String = get_refined_item_id(item_id)
	var base_price: int = int(item.get("base_price", 0)) * 2
	var name: String = "精炼" + str(item.get("name", item_id))
	# The refined item is added as a mineral with doubled price.
	var add_result: Dictionary = warehouse.add_item(refined_id, 1, {
		"name": name,
		"base_price": base_price,
		"rarity": rarity,
		"category": "mineral",
		"tags": ["refined"]
	})
	if not add_result.get("ok", false):
		return {"ok": false, "error": str(add_result.get("error", "添加失败"))}

	return {"ok": true, "refined_id": refined_id, "name": name, "base_price": base_price}
