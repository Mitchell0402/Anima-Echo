extends Node
## Global weight system. Calculates the total weight of items in the
## player's in-mine hotbar and exposes per-tier penalties (speed, noise,
## oxygen). Disabled in town — the warehouse is the player's storage in
## town and there is no in-town movement that weight should affect.

const MINE_SCENE_NAME: String = "testScene"
const DUNGEON_SCENE_NAME: String = "DungeonRoom"

enum Tier { LIGHT, HEAVY, OVERLOAD }

const LIGHT_MAX: float = 60.0
const HEAVY_MAX: float = 100.0
const OVERLOAD_MAX: float = 200.0

const SPEED_MULT: Dictionary = { Tier.LIGHT: 1.0, Tier.HEAVY: 0.8, Tier.OVERLOAD: 0.6 }
const NOISE_MULT: Dictionary = { Tier.LIGHT: 1.0, Tier.HEAVY: 1.3, Tier.OVERLOAD: 1.8 }
const OXYGEN_MULT: Dictionary = { Tier.LIGHT: 1.0, Tier.HEAVY: 1.2, Tier.OVERLOAD: 1.5 }

signal weight_changed(current: float, maximum: float)
signal tier_changed(new_tier: Tier)

var current_weight: float = 0.0
var current_tier: Tier = Tier.LIGHT


func _ready() -> void:
	var runtime: Node = get_node_or_null("/root/GameRuntime")
	if runtime and runtime.get("hotbar") and runtime.get("catalog"):
		runtime.get("hotbar").changed.connect(_on_inventory_changed)
		_on_inventory_changed()


func _on_inventory_changed() -> void:
	_update_weight()


# Recompute the weight from the runtime hotbar. The hotbar is the only
# collection that affects weight: the warehouse does not. Updates are
# also gated to the mine scene so a 0-weight town hotbar does not produce
# spurious weight_changed signals.
func _update_weight() -> void:
	if not _is_in_mine_scene():
		# In town (or anywhere else), the weight system is dormant. The bar
		# is hidden by the player-attached WeightBar (which subscribes to
		# weight_changed) and will not reappear until the next mine run.
		if not is_equal_approx(0.0, current_weight):
			current_weight = 0.0
			weight_changed.emit(0.0, HEAVY_MAX)
		return
	var runtime: Node = get_node_or_null("/root/GameRuntime")
	if runtime == null:
		return

	var inv: Object = runtime.get("hotbar")
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


func _is_in_mine_scene() -> bool:
	var tree: SceneTree = get_tree() if is_inside_tree() else null
	if tree == null:
		return false
	var current: Node = tree.current_scene
	if current == null:
		return false
	return str(current.name) == MINE_SCENE_NAME or str(current.name) == DUNGEON_SCENE_NAME


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
