extends Sprite2D

var moveSpeed = 60.0

func _process(delta: float) -> void:
	if Input.is_action_pressed("ui_left"):
		position.x -= delta * moveSpeed
	if Input.is_action_pressed("ui_right"):
		position.x += delta * moveSpeed
	if Input.is_action_pressed("ui_up"):
		position.y -= delta * moveSpeed
	if Input.is_action_pressed("ui_down"):
		position.y += delta * moveSpeed
