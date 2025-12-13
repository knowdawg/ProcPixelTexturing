extends Sprite2D

@export var foreground : bool = true

func _ready() -> void:
	var tex2DRD : Texture2DRD = Texture2DRD.new()
	if foreground:
		tex2DRD.set_texture_rd_rid(TerrainRendering.worldVisualImageForegroundRID)
	else:
		tex2DRD.set_texture_rd_rid(TerrainRendering.worldVisualImageBackgroundRID)
	texture = tex2DRD
