extends Node

func _process(_delta: float) -> void:
	RenderingServer.global_shader_parameter_set("GLOBAL_ILLUMINATION", $Blur.get_texture())
