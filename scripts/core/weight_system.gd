extends Node

## 全局负重系统（Autoload 单例：WeightSystem）
## 从 GameRuntime.inventory 和 GameRuntime.catalog 计算当前总重，
## 判定三档负重状态，对外暴露各档惩罚倍率。

enum Tier { LIGHT, HEAVY, OVERLOAD }

const LIGHT_MAX: float = 65.0
const HEAVY_MAX: float = 100.0
const OVERLOAD_MAX: float = 180.0

# 各档惩罚倍率
const SPEED_MULT: Dictionary = { Tier.LIGHT: 1.0, Tier.HEAVY: 0.8, Tier.OVERLOAD: 0.6 }
const NOISE_MULT: Dictionary = { Tier.LIGHT: 1.0, Tier.HEAVY: 1.3, Tier.OVERLOAD: 1.8 }
const OXYGEN_MULT: Dictionary = { Tier.LIGHT: 1.0, Tier.HEAVY: 1.3, Tier.OVERLOAD: 1.7 }

signal weight_changed(current: float, maximum: float)
signal tier_changed(new_tier: Tier)

var current_weight: float = 0.0
var current_tier: Tier = Tier.LIGHT


func _ready() -> void:
	var runtime: Node = get_node_or_null("/root/GameRuntime")
	if runtime and runtime.get("inventory") and runtime.get("catalog"):
		runtime.get("inventory").changed.connect(_on_inventory_changed)
		_on_inventory_changed()


func _on_inventory_changed() -> void:
	_update_weight()


func _update_weight() -> void:
	var runtime: Node = get_node_or_null("/root/GameRuntime")
	if runtime == null:
		return

	var inv: Object = runtime.get("inventory")
	var cat: Object = runtime.get("catalog")
	if inv == null or cat == null:
		return

	var total: float = 0.0
	for stack: Dictionary in inv.get_stacks():
		var item_id: String = str(stack.get("item_id", ""))
		var quantity: int = int(stack.get("quantity", 0))
		var item: Dictionary = cat.get_item(item_id)
		var w: float = float(item.get("weight", 0.0))
		total += w * quantity

	if is_equal_approx(total, current_weight):
		return

	current_weight = total
	weight_changed.emit(current_weight, HEAVY_MAX)

	var new_tier: Tier = _calc_tier(total)
	if new_tier != current_tier:
		current_tier = new_tier
		tier_changed.emit(new_tier)


func _calc_tier(weight: float) -> Tier:
	if weight > HEAVY_MAX:
		return Tier.OVERLOAD
	if weight > LIGHT_MAX:
		return Tier.HEAVY
	return Tier.LIGHT


func get_speed_multiplier() -> float:
	return SPEED_MULT.get(current_tier, 1.0)


func get_noise_multiplier() -> float:
	return NOISE_MULT.get(current_tier, 1.0)


func get_oxygen_multiplier() -> float:
	return OXYGEN_MULT.get(current_tier, 1.0)


func get_current_weight() -> float:
	return current_weight
