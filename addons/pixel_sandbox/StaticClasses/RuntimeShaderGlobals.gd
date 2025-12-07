@tool
extends Node
class_name RuntimeShaderGlobals

static var shaderGlobals : Dictionary[String, RenderingServer.GlobalShaderParameterType] = {
	"PS_BACKGROUND_BORDER_COLORS" : RenderingServer.GlobalShaderParameterType.GLOBAL_VAR_TYPE_SAMPLER2D,
	"PS_BACKGROUND_GRADIENTS" : RenderingServer.GlobalShaderParameterType.GLOBAL_VAR_TYPE_SAMPLER2DARRAY,
	"PS_BACKGROUND_NORMALS" : RenderingServer.GlobalShaderParameterType.GLOBAL_VAR_TYPE_SAMPLER2DARRAY,
	"PS_BACKGROUND_TEXTURES" : RenderingServer.GlobalShaderParameterType.GLOBAL_VAR_TYPE_SAMPLER2DARRAY,

	"PS_FOREGROUND_BORDER_COLORS" : RenderingServer.GlobalShaderParameterType.GLOBAL_VAR_TYPE_SAMPLER2D,
	"PS_FOREGROUND_GRADIENTS" : RenderingServer.GlobalShaderParameterType.GLOBAL_VAR_TYPE_SAMPLER2DARRAY,
	"PS_FOREGROUND_NORMALS" : RenderingServer.GlobalShaderParameterType.GLOBAL_VAR_TYPE_SAMPLER2DARRAY,
	"PS_FOREGROUND_TEXTURES" : RenderingServer.GlobalShaderParameterType.GLOBAL_VAR_TYPE_SAMPLER2DARRAY,
	
	"PS_FOREGROUND_SDF" : RenderingServer.GlobalShaderParameterType.GLOBAL_VAR_TYPE_SAMPLER2D,
	"PS_GLOBAL_ILLUMINATION" : RenderingServer.GlobalShaderParameterType.GLOBAL_VAR_TYPE_SAMPLER2D,
	
	"PS_RENDER_QUADRANT_SIZE" : RenderingServer.GlobalShaderParameterType.GLOBAL_VAR_TYPE_VEC2,
	"PS_TILE_TEXTURE_SCROLL" : RenderingServer.GlobalShaderParameterType.GLOBAL_VAR_TYPE_VEC2,
	"PS_WORLD_POSITION" : RenderingServer.GlobalShaderParameterType.GLOBAL_VAR_TYPE_VEC2,
	"PS_CAMERA_ZOOM" : RenderingServer.GlobalShaderParameterType.GLOBAL_VAR_TYPE_VEC2,
	
	"PS_SUN_DIRECTION" : RenderingServer.GlobalShaderParameterType.GLOBAL_VAR_TYPE_FLOAT,
	
	"PS_UNIQUE_TILES" : RenderingServer.GlobalShaderParameterType.GLOBAL_VAR_TYPE_INT,
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
