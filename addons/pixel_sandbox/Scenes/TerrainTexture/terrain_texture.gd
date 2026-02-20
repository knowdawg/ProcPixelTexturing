extends Sprite2D
class_name TerrainTexture

@export var layer : TerrainRendering.LAYER_TYPE = TerrainRendering.LAYER_TYPE.FOREGROUND

var foregroundShader : String = "uid://dd6cxy2m7c1tb"
var backgroundShader : String = "uid://b8dwypbrob4j4"


func _ready() -> void:
	var t : CanvasTexture = texture
	
	var m : ShaderMaterial = ShaderMaterial.new()
	m.resource_local_to_scene = true
	
	if layer == TerrainRendering.LAYER_TYPE.FOREGROUND:
		var foregroundTex2DRD : Texture2DRD = Texture2DRD.new()
		foregroundTex2DRD.set_texture_rd_rid(TerrainRendering.worldVisualImageForegroundRID)
		t.diffuse_texture = foregroundTex2DRD
		
		var foregroundNormal2DRD : Texture2DRD = Texture2DRD.new()
		foregroundNormal2DRD.set_texture_rd_rid(TerrainRendering.worldNormalImageForegroundRID)
		t.normal_texture = foregroundNormal2DRD
		
		TerrainRendering.spriteForeground = self
		m.shader = load(foregroundShader)
	
	if layer == TerrainRendering.LAYER_TYPE.BACKGROUND:
		var backgroundTex2DRD : Texture2DRD = Texture2DRD.new()
		backgroundTex2DRD.set_texture_rd_rid(TerrainRendering.worldVisualImageBackgroundRID)
		t.diffuse_texture = backgroundTex2DRD
		
		var backgroundNormal2DRD : Texture2DRD = Texture2DRD.new()
		backgroundNormal2DRD.set_texture_rd_rid(TerrainRendering.worldNormalImageBackgroundRID)
		t.normal_texture = backgroundNormal2DRD
		
		TerrainRendering.spriteBackground = self
		m.shader = load(backgroundShader)
	
	material = m
	
