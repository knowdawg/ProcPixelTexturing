extends SubViewport
class_name CustomBuffer

@export var world2D : Node2D
@export var camera : Camera2D

@export var visibilityLayer : int

func _ready() -> void:
	world2D.get_viewport().set_canvas_cull_mask_bit(visibilityLayer - 1, false) #-1 because layers start at 0
	world_2d = world2D.get_viewport().world_2d
	
	size.x = PixelSandbox.renderSectionSize
	size.y = PixelSandbox.renderSectionSize
	
	#get RID's once
	if visibilityLayer == 10:
		TerrainRendering.lightBuffer = self
		TerrainRendering.lightBufferRID = getViewportTextureRID()
	elif visibilityLayer == 9:
		TerrainRendering.reflectionBuffer = self
		var viewport_tex : ViewportTexture = get_texture()
		RenderingServer.global_shader_parameter_set("PS_REFLECTION_BUFFER", viewport_tex)


func getViewportTextureRID():
	var viewport_rid = get_texture().get_rid()
	var rd_texture_rid: RID = RenderingServer.texture_get_rd_texture(viewport_rid)
	
	return rd_texture_rid
