extends Node
## 物品数据库（Autoload: ItemDatabase）
## 集中提供物品的堆叠上限、图标、显示名、堆叠键。
## 堆叠上限由 GameRuntime.catalog 决定（data/game/catalog.json 的 stack_size 字段），
## 这样新增物品类型只需要改 catalog，不需要同步修改这里。

# 每种物品的图标与显示名仍然使用常量（gem 三个等级是写死视觉资源）。
const GEM_TEXTURES := {
	1: preload("res://assets/mine/environment/crystal_1.png"),
	2: preload("res://assets/mine/environment/crystal_6.png"),
	3: preload("res://assets/mine/environment/crystal_4.png"),
}

# Stack limit fallback. The real source of truth is GameCatalog.get_stack_size;
# this is only used if GameRuntime is not yet ready when a caller asks.
const DEFAULT_STACK_LIMIT: int = 99

## 堆叠上限:从 GameRuntime.catalog.get_stack_size(item_id) 读取。
## Fallback 到 DEFAULT_STACK_LIMIT,处理 GameRuntime 尚未 ready 的情况(理论上不会发生,
## 因为调用方都在 GameRuntime._ready 之后才被触达,但保留防御以防未来重构 autoload 顺序)。
func get_stack_limit(item_id: String) -> int:
	if item_id.is_empty():
		return DEFAULT_STACK_LIMIT
	var runtime: Node = get_node_or_null("/root/GameRuntime")
	if runtime != null and runtime.get("catalog") != null:
		return int(runtime.get("catalog").get_stack_size(item_id))
	return DEFAULT_STACK_LIMIT

## 堆叠键:决定哪些物品能堆到同一栈。gem 按等级区分(类型+等级)。
## 该函数仍按 type 接收,是因为热栏 UI 渲染时还按 "gem" 这类 coarse 类型拿贴图与显示名。
func get_stack_key(type: String, data: Dictionary) -> String:
	if type == "gem":
		return "gem_L%d" % int(data.get("level", 1))
	return type

## 描述:从 GameRuntime.catalog 读取(不持有本地副本)。
## Fallback 返回空字符串,ItemDatabase 永远不该自己写描述。
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
		return GEM_TEXTURES.get(lvl, GEM_TEXTURES[1])
	return null

func get_display_name(type: String, data: Dictionary) -> String:
	if type == "gem":
		return "原石 L%d" % int(data.get("level", 1))
	return type
