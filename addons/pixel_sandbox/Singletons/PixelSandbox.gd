extends Node

"""
Contains:
	Global Variables
	Global Enums
	Global Refrances
To constant data across Pixel Sandbox
"""

"""--- SETTINGS ---"""
var chunkSize : int = 64
#Amount of the world (in pixels) that is rendered at once
var renderSectionSize : int = 1024
#Size of the world (in pixels)
var mapSize : Vector2i = Vector2i(2048, 2048)
#
var tilesInGame : int = 256


"""--- ENUMS ---"""
enum LAYER{
	FOREGROUND,
	BACKGROUND,
}


"""--- REFRANCES ---"""
var textureDataForeground : String = "uid://dmla4e53rjkn6"
var textureDataBackground : String = "uid://bp6n8tyh8kgct"



#Startup settup for the pluggin
func _ready() -> void:
	RuntimeShaderGlobals.addGlobals()
	RenderingServer.global_shader_parameter_set("PS_RENDER_QUADRANT_SIZE", Vector2(renderSectionSize, renderSectionSize))
