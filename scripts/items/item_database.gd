extends Node
## 物品数据库（Autoload: ItemDatabase）
## 集中提供物品的堆叠上限、图标、显示名、堆叠键。
## 堆叠上限由 GameRuntime.catalog 决定（data/game/catalog.json 的 stack_size 字段）。
## 图标通过 @export 字段在编辑器中拖拽配置。

# ---- Raw Ore Textures (for hotbar, category=raw_stone) ----

@export_group("Raw Ores")
@export var icon_raw_common_geode: Texture2D = preload("res://assets/props/raw_common_geode_alpha.png")
@export var icon_raw_fine_geode: Texture2D = preload("res://assets/props/raw_fine_geode_alpha.png")
@export var icon_raw_rare_geode: Texture2D = preload("res://assets/props/raw_rare_geode_alpha.png")
@export var icon_raw_star_geode: Texture2D = preload("res://assets/props/raw_anomalous_geode_alpha.png")

# ---- Identified Mineral Textures (for warehouse / buyer, category=mineral) ----

@export_group("Identified Minerals")
@export var icon_copper_nugget: Texture2D = preload("res://assets/props/copper_nugget_alpha.png")
@export var icon_iron_shard: Texture2D = preload("res://assets/props/iron_shard_alpha.png")
@export var icon_silver_vein: Texture2D = preload("res://assets/props/silver_vein_alpha.png")
@export var icon_gold_vein: Texture2D = preload("res://assets/props/gold_vein_alpha.png")
@export var icon_crystal_bloom: Texture2D = preload("res://assets/props/crystal_bloom_alpha.png")
@export var icon_moonlit_crystal: Texture2D = preload("res://assets/props/moonlit_crystal_alpha.png")
@export var icon_star_fragment: Texture2D = preload("res://assets/props/star_fragment_alpha.png")
@export var icon_memory_core: Texture2D = preload("res://assets/props/memory_core_alpha.png")
@export var icon_star_crystal: Texture2D = preload("res://assets/props/raw_anomalous_geode_pickup_alpha.png")  # placeholder, needs dedicated art

# Stack limit fallback.

const DEFAULT_STACK_LIMIT: int = 99


func _ready() -> void:
	# Build runtime lookup so callers can say get_icon_by_item_id("copper_nugget").
	_item_texture_map = {
		"raw_common_geode": icon_raw_common_geode,
		"raw_fine_geode": icon_raw_fine_geode,
		"raw_rare_geode": icon_raw_rare_geode,
		"raw_star_geode": icon_raw_star_geode,
		"copper_nugget": icon_copper_nugget,
		"iron_shard": icon_iron_shard,
		"silver_vein": icon_silver_vein,
		"gold_vein": icon_gold_vein,
		"crystal_bloom": icon_crystal_bloom,
		"moonlit_crystal": icon_moonlit_crystal,
		"star_fragment": icon_star_fragment,
		"memory_core": icon_memory_core,
		"star_crystal": icon_star_crystal,
	}

var _item_texture_map: Dictionary = {}


func get_icon_by_item_id(item_id: String) -> Texture2D:
	return _item_texture_map.get(item_id, null)


func get_stack_limit(item_id: String) -> int:
	if item_id.is_empty():
		return DEFAULT_STACK_LIMIT
	var runtime: Node = get_node_or_null("/root/GameRuntime")
	if runtime != null and runtime.get("catalog") != null:
		return int(runtime.get("catalog").get_stack_size(item_id))
	return DEFAULT_STACK_LIMIT


func get_stack_key(type: String, data: Dictionary) -> String:
	if type == "gem":
		return "gem_L%d" % int(data.get("level", 1))
	return type


func get_description(item_id: String) -> String:
	if item_id.is_empty():
		return ""
	var runtime: Node = get_node_or_null("/root/GameRuntime")
	if runtime != null and runtime.get("catalog") != null:
		var item: Dictionary = runtime.get("catalog").get_item(item_id)
		return str(item.get("description", ""))
	return ""


func get_icon(type: String, data: Dictionary) -> Texture2D:
	if type == "gem":
		var lvl: int = int(data.get("level", 1))
		match lvl:
			1: return icon_raw_common_geode
			2: return icon_raw_fine_geode
			3: return icon_raw_rare_geode
			4: return icon_raw_star_geode
			_: return icon_raw_common_geode
	return get_icon_by_item_id(type)


func get_display_name(type: String, data: Dictionary) -> String:
	if type == "gem":
		return "原石 L%d" % int(data.get("level", 1))
	return type
