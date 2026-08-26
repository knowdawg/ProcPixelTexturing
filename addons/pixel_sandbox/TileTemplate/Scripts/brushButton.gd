extends AnimatedSideButton

@export var previewForground : Sprite2D
@export var previewBackground : Sprite2D

var forActiveIm : Image
var forActiveTex : ImageTexture

var backActiveIm : Image
var backActiveTex : ImageTexture

func _process(delta: float) -> void:
	updatePreview()
	
	if useContinous:
		use()
	if altUseContinous:
		altUse()

func updatePreview() -> void:
	if tt.activeSideButton == self and is_instance_valid(tt.activeElement):
		previewForground.visible = false
		previewBackground.visible = false
		if tt.activeElement.drawLayer == Blueprint.DRAWLAYER.FOREGROUND or tt.activeElement.drawLayer == Blueprint.DRAWLAYER.BOTH:
			previewForground.visible = true
		if tt.activeElement.drawLayer == Blueprint.DRAWLAYER.BACKGROUND or tt.activeElement.drawLayer == Blueprint.DRAWLAYER.BOTH:
			previewBackground.visible = true
		
		forActiveIm = getActiveElementImage(true)
		forActiveTex = ImageTexture.create_from_image(forActiveIm)
		
		backActiveIm = getActiveElementImage(false)
		backActiveTex = ImageTexture.create_from_image(backActiveIm)
		
		var pos = get_global_mouse_position()
		var scallar : Vector2 = get_viewport().get_camera_2d().zoom
		
		if(forActiveIm.get_size().x % 2 == 0):
			pos -= Vector2(0.5, 0.0) * scallar
		if(forActiveIm.get_size().y % 2 == 0):
			pos -= Vector2(0.0, 0.5) * scallar
		
		pos = snapToTilemap(pos)
		
		if(forActiveIm.get_size().x % 2 != 0):
			pos -= Vector2(0.5, 0.0) * scallar
		if(forActiveIm.get_size().y % 2 != 0):
			pos -= Vector2(0.0, 0.5) * scallar
		
		previewForground.texture = forActiveTex
		previewForground.position = pos
		previewForground.scale = scallar
		
		previewBackground.texture = backActiveTex
		previewBackground.position = pos
		previewBackground.scale = scallar
		
	else:
		previewForground.visible = false
		previewBackground.visible = false

var sampleBrushSize : Vector2i = Vector2i(8, 8)
var useContinous : bool = false
func use():
	if is_instance_valid(tt.activeElement):
		if tt.activeElement.blueprint.canBeDragged and Input.is_action_pressed("TileTemplateUse"):
			useContinous = true
		else:
			useContinous = false
			
		var tile : int = tt.activeElement.blueprint.imageForground.get_pixel(16, 16).r * 255.0
		var mousePos := Vector2i(get_viewport().get_camera_2d().get_global_mouse_position())
		var radius : int = ceil(float(tt.brushSize.x) / 2.0)
		
		if tt.activeElement.drawLayer == Blueprint.DRAWLAYER.FOREGROUND or tt.activeElement.drawLayer == Blueprint.DRAWLAYER.BOTH:
			TerrainServer.makeTerrainChange(
				mousePos,
				tile,
				radius,
				PixelSandbox.LAYER.FOREGROUND,
				TerrainChange.SHAPE.CIRCLE,
				true
			)
		if tt.activeElement.drawLayer == Blueprint.DRAWLAYER.BACKGROUND or tt.activeElement.drawLayer == Blueprint.DRAWLAYER.BOTH:
			TerrainServer.makeTerrainChange(
				mousePos,
				tile,
				radius,
				PixelSandbox.LAYER.BACKGROUND,
				TerrainChange.SHAPE.CIRCLE,
				true
			)
		
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
		
		var tile : int = 0
		var mousePos := get_viewport().get_camera_2d().get_global_mouse_position()
		var radius : int = ceil(float(tt.brushSize.x) / 2.0)
		
		if tt.activeElement.drawLayer == Blueprint.DRAWLAYER.FOREGROUND or tt.activeElement.drawLayer == Blueprint.DRAWLAYER.BOTH:
			TerrainServer.makeTerrainChange(
				mousePos,
				tile,
				radius,
				PixelSandbox.LAYER.FOREGROUND,
				TerrainChange.SHAPE.CIRCLE,
				true
			)
		
		if tt.activeElement.drawLayer == Blueprint.DRAWLAYER.BACKGROUND or tt.activeElement.drawLayer == Blueprint.DRAWLAYER.BOTH:
			TerrainServer.makeTerrainChange(
				mousePos,
				tile,
				radius,
				PixelSandbox.LAYER.BACKGROUND,
				TerrainChange.SHAPE.CIRCLE,
				true
			)
		
		if altUseContinous == false:
			$AnimationPlayer.stop()
		$AnimationPlayer.play("Use")

func getActiveElementImage(isForeground : bool = true) -> Image:
	var im : Image
	if isForeground:
		im = tt.activeElement.blueprint.imageForground
	else:
		im = tt.activeElement.blueprint.imageBackground
	
	if tt. activeElement.isSample:
		sampleBrushSize = tt.brushSize
		im = Image.create_empty(sampleBrushSize.x, sampleBrushSize.y, false, TerrainRendering.TERRAIN_IMAGE_FORMAT)
		
		if isForeground:
			im.blit_rect(tt.activeElement.blueprint.imageForground, Rect2i(Vector2i(0, 0), sampleBrushSize), Vector2i(0, 0))
		else:
			im.blit_rect(tt.activeElement.blueprint.imageBackground, Rect2i(Vector2i(0, 0), sampleBrushSize), Vector2i(0, 0))
		
		if tt.activeShapeButton:
			if tt.activeShapeButton.name == "Circle":
				var centerVec = Vector2(im.get_size() - Vector2i(1, 1)) / 2.0
				for x in im.get_size().x:
					for y in im.get_size().y:
						var r : float = Vector2(x, y).distance_to(centerVec)
						if r > float(tt.brushSize.x) / 2.0:
							im.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
	
	return im

func _ready() -> void:
	forActiveIm = Image.new()
	forActiveTex = ImageTexture.new()
	backActiveIm = Image.new()
	backActiveTex = ImageTexture.new()
