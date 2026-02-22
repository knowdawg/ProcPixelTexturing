extends Camera2D

@export var targetSize : Vector2 = Vector2(320.0, 180.0)
func _process(_delta: float) -> void:
	var scaleFactor := get_viewport_rect().size / targetSize
	zoom = scaleFactor
	
	var c : Camera2D = get_viewport().get_camera_2d()
	if c == self:
		var cPos : Vector2 = c.get_screen_center_position()
		
		TerrainRendering.worldPosition = cPos
		RenderingServer.global_shader_parameter_set("PS_CAMERA_POSITION", cPos)
