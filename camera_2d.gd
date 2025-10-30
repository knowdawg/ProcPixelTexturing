extends Sprite2D

var moveSpeed = 200.0

func _process(delta: float) -> void:
	if Input.is_action_pressed("ui_left"):
		position.x -= moveSpeed * delta
	if Input.is_action_pressed("ui_right"):
		position.x += moveSpeed * delta
	if Input.is_action_pressed("ui_up"):
		position.y -= moveSpeed * delta
	if Input.is_action_pressed("ui_down"):
		position.y += moveSpeed * delta
