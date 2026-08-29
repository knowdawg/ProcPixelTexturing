extends Node

"""
Contains:
	Global Variables
	Global Enums
	Global Refrances
To constant data across Pixel Sandbox
"""

"""--- SETTINGS ---"""
var terrainServerTicksPerSecond : float = 24.0
var clientFlushesPerSecond      : float = 12.0


var chunkSize : int = 64
#Amount of the world (in pixels) that is rendered at once
var renderSectionSize : int = 1024
#Size of the world (in pixels)
var mapSize : Vector2i = Vector2i(2048, 2048)
var tilesInGame : int = 256


"""--- DEBUG STATE ---"""
signal onDebugStateChange(newState : DEBUG_STATES)
enum DEBUG_STATES{
	NONE,
	TEXTURE_SCROLL,
	NETWORK,
	CHUNK,
}
var debugState : DEBUG_STATES = DEBUG_STATES.NETWORK


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

func _input(event : InputEvent) -> void:
	if event.is_action_pressed("ShowDebugUI"):
		debugState = (debugState + 1) % DEBUG_STATES.size()
		onDebugStateChange.emit(debugState)
