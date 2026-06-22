extends Area2D

@export var gem_value: int = 1
@export var gem_level: int = 1
@export var lifetime: float = 30.0
@export var gem_tint: Color = Color.WHITE
@export var pickup_speed: float = 300.0
@export var pickup_radius: float = 48.0
@export var collect_distance: float = 15.0  # ✅ 收集距离，不需要完全碰到
@export var pickup_delay: float = 0.0  # 免拾取时间（掉落物用，避免立刻被拾回）

var is_collected: bool = false
var is_flying_to_player: bool = false
var target_player: Node2D = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	
	print("[Gem Debug] 🔍 Gem L%d | Collision Layer: %d | Collision Mask: %d" % [
		gem_level, collision_layer, collision_mask
	])
	
	if has_node("Sprite2D"):
		$Sprite2D.modulate = gem_tint
	
	var timer = get_tree().create_timer(lifetime)
	timer.timeout.connect(_fade_out)
	
	# 免拾取期：关闭监测，到点后重新开启（会重新检测当前重叠的玩家）
	if pickup_delay > 0.0:
		monitoring = false
		var delay_timer = get_tree().create_timer(pickup_delay)
		delay_timer.timeout.connect(func(): monitoring = true)
	
	_spawn_animation()

func launch(initial_velocity: Vector2) -> void:
	var start_pos = global_position
	
	var end_pos = start_pos + Vector2(initial_velocity.x * 0.3, abs(initial_velocity.x * 0.2) + 10)
	var mid_pos = start_pos + Vector2(initial_velocity.x * 0.15, -abs(initial_velocity.x * 0.2) - 10)
	
	var tween = create_tween()
	tween.tween_property(self, "global_position", mid_pos, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "global_position", end_pos, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	tween.tween_callback(func():
		var bounce_tween = create_tween()
		var bounce_pos = end_pos + Vector2(0, -5)
		bounce_tween.tween_property(self, "global_position", bounce_pos, 0.05).set_trans(Tween.TRANS_SINE)
		bounce_tween.tween_property(self, "global_position", end_pos, 0.08).set_trans(Tween.TRANS_SINE)
	)

func _physics_process(delta: float) -> void:
	if not is_flying_to_player:
		_try_distance_pickup()
	if not is_flying_to_player or not target_player:
		return
	
	var distance = global_position.distance_to(target_player.global_position)
	
	# ✅ 靠近玩家一定距离就收集
	if distance < collect_distance:
		_collect()
		return
	
	# ✅ 使用 move_toward，永远不会追不上
	var direction = (target_player.global_position - global_position).normalized()
	global_position += direction * pickup_speed * delta

func _on_body_entered(body: Node2D) -> void:
	if is_collected or is_flying_to_player:
		return
	
	if body.is_in_group("player"):
		var inventory = body.get_node_or_null("InventoryManager")
		if inventory and inventory.is_full():
			print("[Gem] ⚠️ 背包已满，无法收集")
			return
		
		is_flying_to_player = true
		target_player = body
		print("[Gem] 🧲 L%d 原石开始飞向玩家: %s" % [gem_level, body.name])


func _try_distance_pickup() -> void:
	if is_collected or is_flying_to_player or not monitoring:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	if global_position.distance_to(player.global_position) > pickup_radius:
		return
	var inventory = player.get_node_or_null("InventoryManager")
	if inventory and inventory.is_full():
		return
	is_flying_to_player = true
	target_player = player
	print("[Gem] 🧲 L%d 原石进入拾取范围: %s" % [gem_level, player.name])

func _collect() -> void:
	if is_collected:
		return
	
	var player = target_player
	if not player:
		queue_free()
		return
	
	var inventory = player.get_node_or_null("InventoryManager")
	var runtime = get_node_or_null("/root/GameRuntime")
	if inventory != null and inventory.is_full():
		is_flying_to_player = false
		target_player = null
		return
	
	var item_data = {
		"level": gem_level,
		"value": gem_value
	}
	
	if runtime == null or runtime.get("transactions") == null:
		is_flying_to_player = false
		target_player = null
		return
	var item_id := _runtime_item_id_for_level(gem_level)
	var result: Dictionary = runtime.get("transactions").apply({
		"type": "collect_item",
		"source": "gj_gem_pickup",
		"item_id": item_id,
		"quantity": 1,
		"metadata": item_data,
	})
	var success: bool = result.get("ok", false)
	if success and inventory != null and inventory.has_method("_sync_from_runtime"):
		inventory.call("_sync_from_runtime")
	
	if success:
		is_collected = true
		print("[Gem] 💎 L%d 原石已收集！价值: %d" % [gem_level, gem_value])
		if inventory != null:
			print("[背包] 当前物品数: %d/%d" % [inventory.get_item_count(), inventory.MAX_SLOTS])
		queue_free()
	else:
		is_flying_to_player = false
		target_player = null

func _runtime_item_id_for_level(level: int) -> String:
	match level:
		1:
			return "raw_common_geode"
		2:
			return "raw_fine_geode"
		3:
			return "raw_rare_geode"
		_:
			return "raw_common_geode"

func _spawn_animation() -> void:
	scale = Vector2(0.1, 0.1)
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1, 1), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _fade_out() -> void:
	if not is_collected:
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0, 0.5)
		tween.tween_callback(queue_free)
