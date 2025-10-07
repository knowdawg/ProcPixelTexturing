extends Label

func _process(delta: float) -> void:
	text = "FPS: " + str(1.0 / delta)
