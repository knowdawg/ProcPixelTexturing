extends DirectionalLight2D
class_name Sun

func _process(delta: float) -> void:
	TerrainRendering.sunDirection = rotation
