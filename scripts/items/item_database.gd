extends Node

## 物品数据库（Autoload: ItemDatabase）
## 集中定义物品的堆叠上限、图标、显示名、堆叠键。
## 后续可改为基于资源文件的注册表，目前用常量足够。

const GEM_TEXTURES := {
	1: preload("res://assets/mine/environment/crystal_1.png"),
	2: preload("res://assets/mine/environment/crystal_6.png"),
	3: preload("res://assets/mine/environment/crystal_4.png"),
}

# 每种物品类型的堆叠上限
const STACK_LIMITS := {
	"gem": 99,
}

const DEFAULT_STACK_LIMIT: int = 99

func get_stack_limit(type: String) -> int:
	return STACK_LIMITS.get(type, DEFAULT_STACK_LIMIT)

## 堆叠键：决定哪些物品能堆到同一栈。gem 按等级区分（类型+等级）。
func get_stack_key(type: String, data: Dictionary) -> String:
	if type == "gem":
		return "gem_L%d" % int(data.get("level", 1))
	return type

func get_icon(type: String, data: Dictionary) -> Texture2D:
	if type == "gem":
		var lvl: int = int(data.get("level", 1))
		return GEM_TEXTURES.get(lvl, GEM_TEXTURES[1])
	return null

func get_display_name(type: String, data: Dictionary) -> String:
	if type == "gem":
		return "原石 L%d" % int(data.get("level", 1))
	return type
