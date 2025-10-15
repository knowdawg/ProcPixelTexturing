extends DirectionalLight2D

func _process(_delta: float) -> void:
	RenderingServer.global_shader_parameter_set("SUN_DIRECTION", rotation - PI/2.0)
