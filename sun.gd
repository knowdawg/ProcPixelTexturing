extends DirectionalLight2D

var t = 0.0
func _process(delta: float) -> void:
	t += delta
	#rotation = sin(t)
	
	TerrainRendering.sunDirection = rotation
