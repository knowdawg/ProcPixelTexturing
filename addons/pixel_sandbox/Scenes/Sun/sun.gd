extends DirectionalLight2D
class_name Sun

func _process(delta: float) -> void:
	TerrainRendering.sunDirection = rotation
	
	#var d = 90 - abs(rotation_degrees + 90.0)
	#
	#height = d / 100.0
