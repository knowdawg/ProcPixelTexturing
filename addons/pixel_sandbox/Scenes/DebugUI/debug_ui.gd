extends CanvasLayer
class_name DebugUI


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ShowDebugUI"):
		visible = !visible
	
	if !visible:
		return
	
	#Images
	%EmisiveTiles.texture = getTexture2dRID(TerrainRendering.lightMapRID)
	%EmisiveObjects.texture = TerrainRendering.lightBuffer.get_texture()
	%RadianceCascadesInput.texture = getTexture2dRID(TerrainRendering.finalLightImageRID)
	if(TerrainRendering.radCasc):
		%Mip1.texture = getTexture2dRID(TerrainRendering.radCasc.mipImageRIDs[1])
		%Mip2.texture = getTexture2dRID(TerrainRendering.radCasc.mipImageRIDs[2])
		%Mip3.texture = getTexture2dRID(TerrainRendering.radCasc.mipImageRIDs[3])
		%Mip4.texture = getTexture2dRID(TerrainRendering.radCasc.mipImageRIDs[4])
		
		%Cascade0.texture = getTexture2dRID(TerrainRendering.radCasc.cascadeImageRIDs[0])
		%Cascade1.texture = getTexture2dRID(TerrainRendering.radCasc.cascadeImageRIDs[1])
		%Cascade2.texture = getTexture2dRID(TerrainRendering.radCasc.cascadeImageRIDs[2])
		%Cascade3.texture = getTexture2dRID(TerrainRendering.radCasc.cascadeImageRIDs[3])
		%Cascade4.texture = getTexture2dRID(TerrainRendering.radCasc.cascadeImageRIDs[4])
		
		$Sprite2D.texture = getTexture2dRID(TerrainRendering.radCasc.integratedCascadeOutput)
	
	#Text
	%TerrainRenderingValues.text = ""
	%TerrainRenderingValues.text += "FPS: %s\n" % str(1.0 / delta)
	%TerrainRenderingValues.text += "TextureWrapCount: %.3v\n" % TerrainRendering.textureWrapCount
	%TerrainRenderingValues.text += "TextureWrapPixelOffset: %.0v\n" % TerrainRendering.textureWrapPixelOffset
	%TerrainRenderingValues.text += "CameraPosition: %.3v\n" % TerrainRendering.cameraPosition
	%TerrainRenderingValues.text += "CameraChunkPixelProgress: %.0v\n" % TerrainRendering.cameraChunkPixelProgress


func getTexture2dRID(imageRID : RID) -> Texture2DRD:
	var tex : Texture2DRD = Texture2DRD.new()
	tex.set_texture_rd_rid(imageRID)
	return tex
