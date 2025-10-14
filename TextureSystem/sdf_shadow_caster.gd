extends Sprite2D

func _process(_delta: float) -> void:
	var c : Camera2D = get_viewport().get_camera_2d()
	if c:
		var cPos : Vector2i = floor(c.global_position)
		global_position = cPos
