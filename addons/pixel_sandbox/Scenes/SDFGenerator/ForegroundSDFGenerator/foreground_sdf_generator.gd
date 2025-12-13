extends Node

@export var sdfGen : SDFGenerator

@export var debugger : Sprite2D

var sdf : RID

#func _ready() -> void:
	#var rd = RenderingServer.get_rendering_device()
	#
	#var image1 = Image.create_empty(TerrainRendering.renderSectionSize, TerrainRendering.renderSectionSize, false, Image.FORMAT_RGBAF);
	#image1.fill(Color.BLACK)
	#sdf = TerrainRendering.getRIDImage(image1, rd)


#func _process(_delta: float) -> void:
	#var rd = RenderingServer.get_rendering_device()
	#var worldRID : RID = TerrainRendering.worldVisualImageForegroundRID
	#
	#sdfGen.createSDF(worldRID, sdf, 0.0, true)
	#
	#if debugger:
		#var tex2DRD : Texture2DRD = Texture2DRD.new()
		#tex2DRD.set_texture_rd_rid(sdf)
		#debugger.texture = tex2DRD
