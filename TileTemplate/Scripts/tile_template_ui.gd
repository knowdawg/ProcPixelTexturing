extends CanvasLayer
class_name BlueprintUI

var activeElement : BlueprintElement
var activeSideButton : AnimatedSideButton

var blueprintElements : Array[Blueprint] = []
var blueprintElementFile = preload("res://TileTemplate/Scenes/BlueprintElement.tscn")

var visibleChildren : Array[Control] = []

func hideUI():
	%BlueprintContainer.visible = false
	%ShowButtonContainer.visible = true
	if is_instance_valid(activeElement):
		activeElement.deactivate()
		activeElement = null
	if is_instance_valid(activeSideButton):
		activeSideButton.button_pressed = false
		activeSideButton = null

func showUI():
	%BlueprintContainer.visible = true
	%ShowButtonContainer.visible = false


func _ready() -> void:
	BlueprintManager.newBlueprint.connect(populateBlueprintElements)
	populateBlueprintElements()
	
	call_deferred("hideUI")

func _process(_delta: float) -> void:
	checkForDrag()
	
	for e in blueprintElements:
		%BlueprintsScrollContainer.get_global_rect().size()

var prevMousePos : Vector2 = Vector2.ZERO
var dragging : bool = false
func checkForDrag():
	var mousePos := get_viewport().get_mouse_position()
	var isMouseInside = %DragButton.get_global_rect().has_point(mousePos)
	if isMouseInside or dragging:
		if Input.is_action_pressed("TileTemplateUse"):
			dragging = true
			
			var mouseDelta : Vector2 = mousePos - prevMousePos
			var containerRect : Rect2 = %BlueprintContainer.get_global_rect()
			for i in range(4):
				var xPos : float = containerRect.position.x + (mouseDelta.x / float(i + 1))# * %BlueprintContainer.scale.x
				if get_viewport().get_visible_rect().encloses(Rect2(xPos, containerRect.position.y, containerRect.size.x, containerRect.size.y)):
					%BlueprintContainer.global_position.x = xPos
					break
			for i in range(4):
				var yPos : float = containerRect.position.y + (mouseDelta.y / float(i + 1))# * %BlueprintContainer.scale.x
				if get_viewport().get_visible_rect().encloses(Rect2(containerRect.position.x, yPos, containerRect.size.x, containerRect.size.y)):
					%BlueprintContainer.global_position.y = yPos
					break
		else:
			dragging = false
	prevMousePos = mousePos

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("TileTemplateUse"):
		if canClick():
			activeSideButton.use()

func canClick():
	if !is_instance_valid(activeSideButton):
		return false
	return true

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
