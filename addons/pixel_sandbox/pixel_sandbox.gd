@tool
extends EditorPlugin


var autoloads : Dictionary[String, String] = {
	"TerrainRendering" : "res://addons/pixel_sandbox/Singletons/TerrainRendering.gd",
	"TerrainDestruction" : "res://addons/pixel_sandbox/Singletons/TerrainDestruction.gd",
	"WorldManager" : "res://addons/pixel_sandbox/Singletons/WorldManager.gd",
	"BlueprintManager" : "res://addons/pixel_sandbox/Singletons/BlueprintManager.gd",
}



func _enable_plugin() -> void:
	RuntimeShaderGlobals.addGlobals()
	for s : String in autoloads.keys():
		add_autoload_singleton(s, autoloads[s])
		print("Autoload : ", s, " Added")

func _disable_plugin() -> void:
	RuntimeShaderGlobals.removeGlobals()
	for s : String in autoloads.keys():
		remove_autoload_singleton(s)
		print("Autoload : ", s, " Removed")


func _enter_tree() -> void:
	pass
	# Initialization of the plugin goes here.

func _exit_tree() -> void:
	# Clean-up of the plugin goes here.
	pass
