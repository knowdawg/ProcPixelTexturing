extends Sprite2D

@export var foreground : bool = true

func _ready() -> void:
	var tex2DRD : Texture2DRD = Texture2DRD.new()
	tex2DRD.set_texture_rd_rid(TerrainRendering.lightMapRID)
	texture = tex2DRD
