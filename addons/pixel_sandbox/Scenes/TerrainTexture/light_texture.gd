extends Sprite2D
class_name LightingTexture

#Use multiply

func _ready() -> void:
	TerrainRendering.spriteLighting = self

func _process(_delta: float) -> void:
	scale = Vector2(TerrainRendering.renderSectionSize, TerrainRendering.renderSectionSize) / texture.get_size()
