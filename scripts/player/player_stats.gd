extends Node

# 基础属性
@export var base_move_speed: float = 200.0
@export var z_axis_factor: float = 0.6  # 2.5D纵深减速系数

# 动态属性（负重系统已禁用，移速固定为基础速度）
var current_speed_multiplier: float = 1.0

## 负重系统已禁用
## @onready var _weight: Node = get_node_or_null("/root/WeightSystem")


func _ready() -> void:
	## 负重连接已禁用
	## if _weight:
	## 	if not _weight.weight_changed.is_connected(_on_weight_update):
	## 		_weight.weight_changed.connect(_on_weight_update)
	## 	current_speed_multiplier = _weight.get_speed_multiplier()
	pass


## 负重回调已禁用
## func _on_weight_update(_current: float, _maximum: float) -> void:
## 	if _weight:
## 		current_speed_multiplier = _weight.get_speed_multiplier()


func get_effective_speed() -> float:
	return base_move_speed
