extends Node2D
class_name MineEntrance

## 矿洞入口独立交互物体。
##
## 玩家靠近后按 E 弹出矿洞选择面板（普通/深层）。
## 门票检查和进入逻辑由 mining_town_scene.gd 处理。

const INTERACT_RADIUS := 55.0


func is_nearby(player_pos: Vector2) -> bool:
	return player_pos.distance_to(position) <= INTERACT_RADIUS
