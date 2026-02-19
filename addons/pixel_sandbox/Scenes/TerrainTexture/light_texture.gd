extends Sprite2D
class_name LightingTexture

func _ready() -> void:
	TerrainRendering.spriteLighting = self

func _process(_delta: float) -> void:
	if texture:
		scale = Vector2(TerrainRendering.renderSectionSize, TerrainRendering.renderSectionSize) / texture.get_size()
