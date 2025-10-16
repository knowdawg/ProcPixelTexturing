extends Sprite2D

var moveSpeed = 4.0

func _process(delta: float) -> void:
	if Input.is_action_pressed("ui_left"):
		position.x -= moveSpeed
	if Input.is_action_pressed("ui_right"):
		position.x += moveSpeed
	if Input.is_action_pressed("ui_up"):
		position.y -= moveSpeed
	if Input.is_action_pressed("ui_down"):
		position.y += moveSpeed
