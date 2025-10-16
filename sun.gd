extends DirectionalLight2D

var t = 0.0
func _process(delta: float) -> void:
	t += delta
	rotation = sin(t)
	
	RenderingServer.global_shader_parameter_set("SUN_DIRECTION", rotation - PI/2.0)
