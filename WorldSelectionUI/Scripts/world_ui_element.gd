extends MarginContainer
class_name WorldUIElement

var myWorld : World

func setup(w : World):
	myWorld = w
	
	%WorldName.text = myWorld.name


func _on_save_pressed() -> void:
	if myWorld:
		WorldManager.saveWorld(myWorld)
	else:
		printerr("World UI Element does not have a world to save")

func _on_load_pressed() -> void:
	if myWorld:
		WorldManager.loadWorld(myWorld)
	else:
		printerr("World UI Element does not have a world to load")

func _on_delete_pressed() -> void:
	if myWorld:
		WorldManager.deleteWorld(myWorld)
	else:
		printerr("World UI Element does not have a world to delete")
