extends Area2D

## 掩体。玩家靠近后按 interact(E) 躲藏（消失、停止移动、敌人丢失目标）。
## 再按一次 E 离开。通过玩家状态机协作，敌人通过 player.is_hidden() 判断。

@export var hide_player_visuals: bool = true

var player_in_range: CharacterBody2D = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	add_to_group("cover")

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("interact"):
		return
	if event is InputEventKey and event.echo:
		return

	var player := player_in_range
	if player == null:
		return

	if player.has_method("is_hidden") and player.is_hidden():
		_exit_cover(player)
		get_viewport().set_input_as_handled()
	elif player.has_method("can_move") and player.can_move():
		_enter_cover(player)
		get_viewport().set_input_as_handled()

func _enter_cover(player: CharacterBody2D) -> void:
	if player.has_method("enter_hidden") and not player.enter_hidden():
		return
	if hide_player_visuals:
		player.visible = false
	print("[Cover] 玩家进入掩体")

func _exit_cover(player: CharacterBody2D) -> void:
	if hide_player_visuals:
		player.visible = true
	if player.has_method("exit_hidden"):
		player.exit_hidden()
	print("[Cover] 玩家离开掩体")

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.is_in_group("player"):
		player_in_range = body as CharacterBody2D

func _on_body_exited(body: Node2D) -> void:
	if body == player_in_range:
		# 玩家躲藏中被移出范围时兜底恢复，避免卡在隐藏状态
		if body is CharacterBody2D and body.has_method("is_hidden") and body.is_hidden():
			_exit_cover(body as CharacterBody2D)
		player_in_range = null
