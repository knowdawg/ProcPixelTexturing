extends Sprite2D
class_name TerrainTexture

@export var layer : TerrainRendering.LAYER_TYPE = TerrainRendering.LAYER_TYPE.FOREGROUND

var foregroundShader : String = "uid://dd6cxy2m7c1tb"
var backgroundShader : String = "uid://b8dwypbrob4j4"


func _ready() -> void:
	var t : CanvasTexture = texture
	
	var m : ShaderMaterial = ShaderMaterial.new()
	m.resource_local_to_scene = true
	
	var foregroundTex2DRD : Texture2DRD = Texture2DRD.new()
	foregroundTex2DRD.set_texture_rd_rid(TerrainRendering.worldVisualImageForegroundRID)
	var backgroundTex2DRD : Texture2DRD = Texture2DRD.new()
	backgroundTex2DRD.set_texture_rd_rid(TerrainRendering.worldVisualImageBackgroundRID)
	
	if layer == TerrainRendering.LAYER_TYPE.FOREGROUND:
		t.diffuse_texture = foregroundTex2DRD
		
		var foregroundNormal2DRD : Texture2DRD = Texture2DRD.new()
		foregroundNormal2DRD.set_texture_rd_rid(TerrainRendering.worldNormalImageForegroundRID)
		t.normal_texture = foregroundNormal2DRD
		
		var foregroundCustom2DRD : Texture2DRD = Texture2DRD.new()
		foregroundCustom2DRD.set_texture_rd_rid(TerrainRendering.worldCustomImageForegroundRID)
		t.specular_texture = foregroundCustom2DRD
		
		TerrainRendering.spriteForeground = self
		m.shader = load(foregroundShader)
		m.set_shader_parameter("backgroundTexture", backgroundTex2DRD)
	
	if layer == TerrainRendering.LAYER_TYPE.BACKGROUND:
		t.diffuse_texture = backgroundTex2DRD
		
		var backgroundNormal2DRD : Texture2DRD = Texture2DRD.new()
		backgroundNormal2DRD.set_texture_rd_rid(TerrainRendering.worldNormalImageBackgroundRID)
		t.normal_texture = backgroundNormal2DRD
		
		var backgroundCustom2DRD : Texture2DRD = Texture2DRD.new()
		backgroundCustom2DRD.set_texture_rd_rid(TerrainRendering.worldCustomImageBackgroundRID)
		t.specular_texture = backgroundCustom2DRD
		
		TerrainRendering.spriteBackground = self
		m.shader = load(backgroundShader)
		
		m.set_shader_parameter("foregroundTexture", foregroundTex2DRD)
	
	material = m
	
