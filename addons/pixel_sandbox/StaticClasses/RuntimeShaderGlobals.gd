@tool
extends Node
class_name RuntimeShaderGlobals

static var shaderGlobals : Dictionary[String, RenderingServer.GlobalShaderParameterType] = {
	"PS_FOREGROUND_SDF" : RenderingServer.GlobalShaderParameterType.GLOBAL_VAR_TYPE_SAMPLER2D,
	
	"PS_GLOBAL_ILLUMINATION" : RenderingServer.GlobalShaderParameterType.GLOBAL_VAR_TYPE_SAMPLER2D,
	"PS_GLOBAL_ILLUMINATION_TEXTURE_SIZE" : RenderingServer.GlobalShaderParameterType.GLOBAL_VAR_TYPE_INT,
	"PS_INITIAL_CASCADE_PROBE_SIZE" : RenderingServer.GlobalShaderParameterType.GLOBAL_VAR_TYPE_INT,
	
	"PS_RENDER_QUADRANT_SIZE" : RenderingServer.GlobalShaderParameterType.GLOBAL_VAR_TYPE_VEC2, #Size of all active chunks / lighting area ect ect
	"PS_TILE_TEXTURE_SCROLL" : RenderingServer.GlobalShaderParameterType.GLOBAL_VAR_TYPE_VEC2, #The amount from vec2(0.0) - vec2(1.0) of how much of the texture has scrolled based on camera position
	"PS_TOP_LEFT_CHUNK_POSITION" : RenderingServer.GlobalShaderParameterType.GLOBAL_VAR_TYPE_IVEC2, #Position in World Space of the top left most active chunk
	
	"PS_CAMERA_POSITION" : RenderingServer.GlobalShaderParameterType.GLOBAL_VAR_TYPE_VEC2, #Center Camera Position in World Space
	
	"PS_SCREEN_SIZE" : RenderingServer.GlobalShaderParameterType.GLOBAL_VAR_TYPE_VEC2,
	
	#Cosine-convolved directional diffuse: one array layer per facing direction, plus the fluence ambient
	"PS_DIFFUSE_DIRECTIONS" : RenderingServer.GlobalShaderParameterType.GLOBAL_VAR_TYPE_SAMPLER2DARRAY,
	"PS_FLUENCE" : RenderingServer.GlobalShaderParameterType.GLOBAL_VAR_TYPE_SAMPLER2D,
}

func _ready() -> void:
	RuntimeShaderGlobals.addGlobals()

static func addGlobals():
	for s : String in shaderGlobals.keys():
		RenderingServer.global_shader_parameter_add(s, shaderGlobals[s], null)
		print("Shader Global : ", s, " Added")

static func removeGlobals():
	for s : String in shaderGlobals.keys():
		RenderingServer.global_shader_parameter_remove(s)
		print("Shader Global : ", s, " Removed")
