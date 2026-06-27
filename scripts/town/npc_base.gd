## Base script for town NPC scene instances.
##
## Each NPC scene exports an id (matching the ids used by the dialogue
## system and NPC interaction logic) and a display name. The town scene
## finds NPCs by looking for children that are instances of TownNPC.
extends Node2D
class_name TownNPC

@export var npc_id: String = ""
@export var npc_display_name: String = ""
