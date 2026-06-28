extends Node2D
class_name Bed

## 床——玩家休息/昼夜切换交互物体。
##
## 白天：休息到夜晚（不消耗门票）
## 夜晚：睡到天亮（结束夜晚 → 新的一天）

const INTERACT_RADIUS := 50.0


func is_nearby(player_pos: Vector2) -> bool:
	return player_pos.distance_to(position) <= INTERACT_RADIUS
