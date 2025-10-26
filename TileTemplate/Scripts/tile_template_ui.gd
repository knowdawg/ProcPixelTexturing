extends CanvasLayer
class_name TileTemplateUI


var activeElement : BlueprintElement
var activeSideButton : AnimatedSideButton

var blueprintElements : Array[Blueprint] = []
var blueprintElementFile = preload("res://TileTemplate/Scenes/BlueprintElement.tscn")

func _ready() -> void:
	BlueprintManager.newBlueprint.connect(populateBlueprintElements)
	populateBlueprintElements()

func populateBlueprintElements():
	for c in %BlueprintGridContainer.get_children():
		if c is BlueprintElement:
			c.queue_free()
	
	for b in BlueprintManager.blueprints:
		var blueprintElement : BlueprintElement = blueprintElementFile.instantiate()
		blueprintElement.setup(b, self, BlueprintManager.blueprints[b])
		%BlueprintGridContainer.add_child(blueprintElement)

func deleteCurrentBlueprint():
	if activeElement:
		BlueprintManager.deleteBlueprint(activeElement.blueprint)

func canUseSideButton() -> bool:
	return true
