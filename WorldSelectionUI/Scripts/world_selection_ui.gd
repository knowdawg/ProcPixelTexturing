extends CanvasLayer
class_name WorldSelectionUI

var wouldUIElementFile = preload("uid://cl8a2rb1cpx3v")

func _ready() -> void:
	%CreateWorldNamePopup.visible = false
	WorldManager.worldsChanged.connect(populateWorldUIElements)
	populateWorldUIElements()


func populateWorldUIElements() -> void:
	for c in %WorldsUIContainer.get_children():
		if c is WorldUIElement:
			c.queue_free()
	
	for n in WorldManager.worlds.keys():
		var world = WorldManager.worlds[n]
		var worldUI : WorldUIElement = wouldUIElementFile.instantiate()
		worldUI.setup(world)
		%WorldsUIContainer.add_child(worldUI)


func _on_button_pressed() -> void:
	%CreateWorldNamePopup.visible = true
	%WorldNameLineEdit.grab_focus()
	#WorldManager.createNewWorld(str(Time.get_unix_time_from_system()), TerrainRendering.mapSize)


func _on_line_edit_text_submitted(new_text: String) -> void:
	WorldManager.createNewWorld(new_text, TerrainRendering.mapSize)
	%CreateWorldNamePopup.visible = false
	%WorldNameLineEdit.text = ""
