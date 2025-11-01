extends AnimatedSideButton

@export var preview : Sprite2D

var activeIm : Image
var activeTex : ImageTexture

func _process(_delta: float) -> void:
	updatePreview()
	if useContinous:
		use()
	if altUseContinous:
		altUse()

func updatePreview() -> void:
	if tt.activeSideButton == self and is_instance_valid(tt.activeElement):
		preview.visible = true
		
		activeIm = getActiveElementImage()
		activeTex = ImageTexture.create_from_image(activeIm)
		
		var pos = get_global_mouse_position()
		var scallar : Vector2 = get_viewport().get_camera_2d().zoom
		
		if(activeIm.get_size().x % 2 == 0):
			pos -= Vector2(0.5, 0.0) * scallar
		if(activeIm.get_size().y % 2 == 0):
			pos -= Vector2(0.0, 0.5) * scallar
		
		pos = snapToTilemap(pos)
		
		if(activeIm.get_size().x % 2 != 0):
			pos -= Vector2(0.5, 0.0) * scallar
		if(activeIm.get_size().y % 2 != 0):
			pos -= Vector2(0.0, 0.5) * scallar
		
		preview.texture = activeTex
		preview.position = pos
		preview.scale = scallar
		
	else:
		preview.visible = false

var sampleBrushSize : Vector2i = Vector2i(8, 8)
var useContinous : bool = false
func use():
	if is_instance_valid(tt.activeElement):
		if tt.activeElement.blueprint.canBeDragged and Input.is_action_pressed("TileTemplateUse"):
			useContinous = true
		else:
			useContinous = false
			
		var i : Image = getActiveElementImage()
		
		var mousePos := TerrainDestruction.foreground.get_global_mouse_position() #mous position is relative to the canvas layer
		TerrainDestruction.addTileImage(mousePos, i, TerrainDestruction.FOREGROUND)
		if useContinous == false:
			$AnimationPlayer.stop()
		$AnimationPlayer.play("Use")

var altUseContinous : bool = false
func altUse():
	if is_instance_valid(tt.activeElement):
		if tt.activeElement.blueprint.canBeDragged and Input.is_action_pressed("TileTemplateAltUse"):
			altUseContinous = true
		else:
			altUseContinous = false
		
		var i : Image = getActiveElementImage()
		var bitmap : BitMap = BitMap.new()
		bitmap.create_from_image_alpha(i, 0.5)
		
		var mousePos := TerrainDestruction.foreground.get_global_mouse_position()
		
		TerrainDestruction.addTileBitmap(mousePos, -1, bitmap, TerrainDestruction.FOREGROUND)
		if useContinous == false:
			$AnimationPlayer.stop()
		$AnimationPlayer.play("Use")

func getActiveElementImage() -> Image:
	var i : Image = tt.activeElement.blueprint.image
	if tt. activeElement.isSample:
		i = Image.create_empty(sampleBrushSize.x, sampleBrushSize.y, false, TerrainRendering.IMAGE_FORMAT)
		i.blit_rect(tt.activeElement.blueprint.image, Rect2i(Vector2i(0, 0), sampleBrushSize), Vector2i(0, 0))
	
	return i

func _ready() -> void:
	activeIm = Image.new()
	activeTex = ImageTexture.new()
