extends Sprite2D
class_name TerrainTexture

@export var layer : TerrainRendering.LAYER_TYPE = TerrainRendering.LAYER_TYPE.FOREGROUND

var foregroundShader : String = "uid://dd6cxy2m7c1tb"
var backgroundShader : String = "uid://b8dwypbrob4j4"


func _ready() -> void:
	var m : ShaderMaterial = ShaderMaterial.new()
	m.resource_local_to_scene = true
	
	if layer == TerrainRendering.LAYER_TYPE.FOREGROUND:
		var tex2DRD : Texture2DRD = Texture2DRD.new()
		tex2DRD.set_texture_rd_rid(TerrainRendering.textureForegroundRID)
		texture = tex2DRD
		TerrainRendering.spriteForeground = self
		m.shader = load(foregroundShader)
	
	if layer == TerrainRendering.LAYER_TYPE.BACKGROUND:
		var tex2DRD : Texture2DRD = Texture2DRD.new()
		tex2DRD.set_texture_rd_rid(TerrainRendering.textureBackgroundRID)
		texture = tex2DRD
		TerrainRendering.spriteBackground = self
		m.shader = load(backgroundShader)
	
	material = m
	
