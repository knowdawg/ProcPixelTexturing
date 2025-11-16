extends Camera2D

@export var targetSize : Vector2 = Vector2(320.0, 180.0)
func _process(_delta: float) -> void:
	var scaleFactor := get_viewport_rect().size / targetSize
	zoom = scaleFactor
