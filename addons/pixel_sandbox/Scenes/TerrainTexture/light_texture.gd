extends Sprite2D
class_name LightingTexture

#Use multiply

func _ready() -> void:
	TerrainRendering.spriteLighting = self
