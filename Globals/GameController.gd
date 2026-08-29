extends Node

var world2d : GLOBAL_WORLD
var GUI : GUIContainer

func _ready() -> void:
	await get_tree().process_frame
	
	var arguments = OS.get_cmdline_args()
	if "--server" in arguments:
		NetworkManager.startServer()
	elif "--client" in arguments:
		NetworkManager.startClient()
