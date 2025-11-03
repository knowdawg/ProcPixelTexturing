extends Sprite2D

@export var layer : TerrainRendering.LAYER_TYPE = TerrainRendering.LAYER_TYPE.FOREGROUND

func _ready() -> void:
	if layer == TerrainRendering.LAYER_TYPE.FOREGROUND:
		var tex2DRD : Texture2DRD = Texture2DRD.new()
		tex2DRD.set_texture_rd_rid(TerrainRendering.textureForegroundRID)
		texture = tex2DRD
		TerrainRendering.spriteForeground = self
	
	if layer == TerrainRendering.LAYER_TYPE.BACKGROUND:
		var tex2DRD : Texture2DRD = Texture2DRD.new()
		tex2DRD.set_texture_rd_rid(TerrainRendering.textureBackgroundRID)
		texture = tex2DRD
		TerrainRendering.spriteBackground = self
