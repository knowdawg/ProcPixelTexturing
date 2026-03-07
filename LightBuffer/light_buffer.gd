extends SubViewport
class_name LightBuffer


@export var world2D : Node2D
@export var camera : Camera2D

func _ready() -> void:
	world2D.get_viewport().set_canvas_cull_mask_bit(9, false)
	world_2d = world2D.get_viewport().world_2d
	
	size.x = TerrainRendering.renderSectionSize
	size.y = TerrainRendering.renderSectionSize
	
	
	
	TerrainRendering.lightBuffer = self

func _process(_delta: float) -> void:
	pass
	#might be like delayed by a frame
	#camera.global_position = world2D.get_viewport().get_camera_2d().get_screen_center_position()

func getViewportTextureRID():
	var viewport_rid = get_texture().get_rid()
	var rd_texture_rid: RID = RenderingServer.texture_get_rd_texture(viewport_rid)
	
	return rd_texture_rid
