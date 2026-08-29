extends Sprite2D

var moveSpeed = 225.0

func _process(delta: float) -> void:
	if Input.is_action_pressed("ui_left"):
		position.x -= moveSpeed * delta
	if Input.is_action_pressed("ui_right"):
		position.x += moveSpeed * delta
	if Input.is_action_pressed("ui_up"):
		position.y -= moveSpeed * delta
	if Input.is_action_pressed("ui_down"):
		position.y += moveSpeed * delta
	
	var cam := get_viewport().get_camera_2d()
	if cam:
		var halfCam := (get_viewport_rect().size / cam.zoom) / 2.0 #Vector2(160.0, 90.0)
		position = position.clamp(Vector2(0.0, 0.0) + halfCam, Vector2(2048.0, 2048.0) - halfCam)
