@tool
extends EditorPlugin


var autoloads : Dictionary[String, String] = {
	"TerrainRendering" : "res://Globals/TerrainRendering.gd",
	"TerrainDestruction" : "res://Globals/TerrainDestruction.gd",
	"WorldManager" : "res://Globals/WorldManager.gd"
}

func _enable_plugin() -> void:
	for s : String in autoloads.keys():
		add_autoload_singleton(s, autoloads[s])

func _disable_plugin() -> void:
	for s : String in autoloads.keys():
		remove_autoload_singleton(s)


func _enter_tree() -> void:
	# Initialization of the plugin goes here.
	pass


func _exit_tree() -> void:
	# Clean-up of the plugin goes here.
	pass
