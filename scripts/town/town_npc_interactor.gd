extends Node2D

const NPC_IDS: Array[String] = ["blacksmith", "florist", "buyer", "elder"]

var _npc_positions := {
	"blacksmith": Vector2(250, 220),
	"buyer": Vector2(900, 220),
	"elder": Vector2(560, 430),
	"florist": Vector2(910, 575)
}


func get_npc_ids() -> Array[String]:
	return NPC_IDS.duplicate()


func get_npc_position(npc_id: String) -> Vector2:
	return _npc_positions.get(npc_id, Vector2.ZERO)


func nearest_npc_id(world_position: Vector2, radius: float) -> String:
	var best_id := ""
	var best_distance := radius
	for npc_id: String in NPC_IDS:
		var distance := world_position.distance_to(get_npc_position(npc_id))
		if distance <= best_distance:
			best_distance = distance
			best_id = npc_id
	return best_id
