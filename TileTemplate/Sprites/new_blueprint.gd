extends AnimatedSideButton

@export var magnify : Sprite2D

var active : bool = false

var startingMousePos : Vector2i = Vector2i.ZERO
var finalMousePos : Vector2i = Vector2i.ZERO

var startingMousePosLocal : Vector2i = Vector2i.ZERO
var startingCameraPos : Vector2 = Vector2.ZERO

func use():
	var world = GameController.WORLD
	if !is_instance_valid(world):
		return
	startingMousePos = world.get_global_mouse_position().snapped(Vector2(1.0, 1.0))
	startingMousePosLocal = snapToTilemap(get_global_mouse_position())
	startingCameraPos = get_viewport().get_camera_2d().global_position
	active = true

func createBlueprint():
	var forground = TerrainDestruction.foreground
	var background = TerrainDestruction.background
	if !is_instance_valid(forground):
		return
	if !is_instance_valid(background):
		return
	
	var selectedRect : Rect2i = getCurRect(finalMousePos)
	
	if selectedRect.size.x == 0 or selectedRect.size.y == 0:
		return
	
	var forIm : Image = Image.new()
	forIm = Image.create_empty(selectedRect.size.x, selectedRect.size.y, false, Image.FORMAT_RGBAF)
	forIm.blit_rect(forground.mapImage, selectedRect, Vector2i(0, 0))
	
	var backIm : Image = Image.new()
	backIm = Image.create_empty(selectedRect.size.x, selectedRect.size.y, false, Image.FORMAT_RGBAF)
	backIm.blit_rect(background.mapImage, selectedRect, Vector2i(0, 0))
	
	var b : Blueprint = Blueprint.new()
	b.setup(forIm, backIm, selectedRect.position, false)
	BlueprintManager.saveBlueprint(b)

func _draw() -> void:
	if active == true:
		var rect := getLocalRect()
		
		rect.position -= Vector2i(global_position)
		
		rect.position = Vector2i(Vector2(rect.position) / get_global_transform().get_scale())
		rect.size = Vector2i(Vector2(rect.size) / get_global_transform().get_scale())
		
		draw_rect(rect, Color(1.0, 1.0, 1.0, 0.5), true)
		draw_rect(rect, Color(1.0, 1.0, 1.0, 1.0), false, getScallar().x / 2.0)
		
		magnify.visible = true
		magnify.position = snapToTilemap(get_global_mouse_position())
		
	elif tt.activeSideButton == self:
		var mouseTile : Rect2 = Rect2(0.0, 0.0, 0.0, 0.0)
		mouseTile.position = snapToTilemap(get_global_mouse_position()) - global_position
		mouseTile.size = getScallar()
		
		draw_line(mouseTile.position - Vector2(getScallar().x * 5.0, 0.0), mouseTile.position + Vector2(getScallar().x * 5.0, 0.0), Color.WHITE, getScallar().x / 4.0)
		draw_line(mouseTile.position - Vector2(0.0, getScallar().y * 5.0), mouseTile.position + Vector2(0.0, getScallar().y * 5.0), Color.WHITE, getScallar().y / 4.0)
		
		magnify.visible = true
		magnify.position = snapToTilemap(get_global_mouse_position())
	else:
		magnify.visible = false

func getLocalRect() -> Rect2i:
	var cameraOffset  : Vector2 = getScallar() * (startingCameraPos - get_viewport().get_camera_2d().get_screen_center_position())
	var ogPos : Vector2 = Vector2(startingMousePosLocal) + cameraOffset
	
	var curMousePos : Vector2i = Vector2i(snapToTilemap(get_global_mouse_position()))
	
	var selectedRect : Rect2i = Rect2i(0, 0, 0, 0)
	selectedRect.position.x = min(ogPos.x, curMousePos.x)
	selectedRect.position.y = min(ogPos.y, curMousePos.y)
	selectedRect.size.x = abs(ogPos.x - curMousePos.x)
	selectedRect.size.y = abs(ogPos.y - curMousePos.y)
	
	return selectedRect

func getCurRect(mousePos : Vector2) -> Rect2i:
	var curMousePos : Vector2i = Vector2i(mousePos)
	var selectedRect : Rect2i = Rect2i(0, 0, 0, 0)
	selectedRect.position.x = min(startingMousePos.x, curMousePos.x)
	selectedRect.position.y = min(startingMousePos.y, curMousePos.y)
	selectedRect.size.x = abs(startingMousePos.x - curMousePos.x)
	selectedRect.size.y = abs(startingMousePos.y - curMousePos.y)
	
	return selectedRect

func _process(_delta: float) -> void:
	queue_redraw()
	
	var world = GameController.WORLD
	if !is_instance_valid(world):
		return
	
	if active:
		if Input.is_action_just_released("TileTemplateUse"):
			active = false
			finalMousePos = world.get_global_mouse_position().snapped(Vector2(1.0, 1.0))
			
			$AnimationPlayer.play("Use")
			button_pressed = false

func _on_toggled(toggled_on: bool) -> void:
	if toggled_on:
		$AnimationPlayer.play("Select")
		prevAnimation = "Select"
		if tt.activeSideButton:
			if tt.activeSideButton != self:
				tt.activeSideButton.button_pressed = false
		tt.activeSideButton = self
	else:
		if tt.activeSideButton:
			if tt.activeSideButton == self:
				tt.activeSideButton = null
		if $AnimationPlayer.current_animation != "Use":
			$AnimationPlayer.play("Reset")
			prevAnimation = "Reset"
