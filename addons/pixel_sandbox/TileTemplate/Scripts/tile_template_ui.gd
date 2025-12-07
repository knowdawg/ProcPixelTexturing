extends CanvasLayer
class_name BlueprintUI

@export var UIScale : float = 1.0

var activeElement : BlueprintElement
var activeSideButton : AnimatedSideButton
var activeShapeButton : Button

var blueprintElements : Array[Blueprint] = []
var blueprintElementFile = preload("uid://cwr1gaxdbbpg")

var visibleChildren : Array[Control] = []

var brushSize : Vector2i = Vector2i(8, 8)
var sampleSize : Vector2i =  Vector2i(32, 32)

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
	%BlueprintContainer.scale = Vector2(UIScale, UIScale)
	
	BlueprintManager.newBlueprint.connect(populateBlueprintElements)
	populateBlueprintElements()
	
	call_deferred("hideUI")
	call_deferred("setupSamples")

func setupSamples():
	for i in TerrainRendering.uniqueTiles:
		var im = TerrainRendering.generateSampleImage(i, sampleSize)
		
		var bp : Blueprint = Blueprint.new()
		bp.setup(im, im, Vector2.ZERO, true)
		
		var blueprintElement : BlueprintElement = blueprintElementFile.instantiate()
		blueprintElement.setup(bp, self, "", true)
		%MaterialGridContainer.add_child(blueprintElement)

func _process(_delta: float) -> void:
	checkForDrag()
	
	for e in blueprintElements:
		%BlueprintsScrollContainer.get_global_rect().size()
	
	if %Materials.visible and %BlueprintContainer.visible:
		if Input.is_action_just_pressed("TileTemplateDecreaseSize"):
			changeBrushSize(Vector2i(-1, -1))
		if Input.is_action_just_pressed("TileTemplateIncreaseSize"):
			changeBrushSize(Vector2i(1, 1))

var prevMousePos : Vector2 = Vector2.ZERO
var dragging : bool = false
func checkForDrag():
	var mousePos := get_viewport().get_mouse_position()
	var isMouseInside = %DragButton.get_global_rect().has_point(mousePos)
	
	if isMouseInside and Input.is_action_just_pressed("TileTemplateUse"):
		dragging = true
	
	if dragging:
		if Input.is_action_pressed("TileTemplateUse"):
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
	if event.is_action_pressed("TileTemplateAltUse"):
		if canClick():
			activeSideButton.altUse()

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


func changeBrushSize(amount : Vector2i):
	brushSize += amount
	brushSize = clamp(brushSize, Vector2i(1, 1), sampleSize)
	%Label.text = str(brushSize.x) + "x" + str(brushSize.y)

func _on_minus_pressed() -> void:
	changeBrushSize(Vector2i(-1, -1))

func _on_plus_pressed() -> void:
	changeBrushSize(Vector2i(1, 1))

func _on_tab_container_tab_changed(_tab: int) -> void:
	if is_instance_valid(activeElement):
		activeElement.deactivate()
	activeElement = null


func _on_square_toggled(toggled_on: bool) -> void:
	if toggled_on:
		if is_instance_valid(activeShapeButton):
			activeShapeButton.button_pressed = false
		activeShapeButton = %Square

func _on_circle_toggled(toggled_on: bool) -> void:
	if toggled_on:
		if is_instance_valid(activeShapeButton):
			activeShapeButton.button_pressed = false
		activeShapeButton = %Circle
