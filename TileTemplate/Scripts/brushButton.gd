extends AnimatedSideButton

@export var preview : Sprite2D

var activeIm : Image
var activeTex : ImageTexture

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if tt.activeSideButton == self and is_instance_valid(tt.activeElement):
		preview.visible = true
		
		activeIm = tt.activeElement.blueprint.image
		activeTex = ImageTexture.create_from_image(activeIm)
		
		var scallar : Vector2 = get_viewport().get_camera_2d().zoom
		var camPos := get_viewport().get_camera_2d().get_screen_center_position()
		var camFract : Vector2 = (Vector2(1.0, 1.0) - ((camPos) - floor(camPos))) * scallar
		#Snap to Grid, not currently working
		var pos := get_global_mouse_position()
		pos -= camFract
		pos = pos.snapped(scallar)
		pos += camFract
		
		if(activeIm.get_size().x % 2 != 0):
			pos -= Vector2(0.5, 0.0) * scallar
		if(activeIm.get_size().y % 2 == 0):
			pos -= Vector2(0.0, 0.5) * scallar
		
		preview.texture = activeTex
		preview.position = pos
		preview.scale = scallar
		
	else:
		preview.visible = false


func use():
	if is_instance_valid(tt.activeElement):
		var i : Image = tt.activeElement.blueprint.image
		var mousePos := TerrainDestruction.foreground.get_global_mouse_position() #mous position is relative to the canvas layer
		TerrainDestruction.addTileImage(mousePos, i, TerrainDestruction.FOREGROUND)
		$AnimationPlayer.stop()
		$AnimationPlayer.play("Use")


func _ready() -> void:
	activeIm = Image.new()
	activeTex = ImageTexture.new()
