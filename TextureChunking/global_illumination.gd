extends Node

@export var sdfGen : SDFGenerator

@export var lightRayVisualizer : Sprite2D
@export var lightSDFVisualize : Sprite2D
@export var GlobalIlluminationVisualize : Sprite2D

var rd : RenderingDevice
var lightrayShaderFile = preload("uid://bw0seuypy6m0v")
var lightrayShader : RID
var pipelineLightray : RID
var lightrayImRID : RID


var jumpFloodIm1RID : RID
var jumpFloodIm2RID : RID
var lightRaySDFRID : RID
var globalIlluminationRID : RID
var GIShaderFile = preload("uid://baitjqntj0whw")
var GIShader : RID
var GIPipeline : RID

func _process(_delta: float) -> void:
	var rid : RID = createLightrayIm(TerrainRendering.foregroundSDF, TerrainRendering.backgroundSDF, lightrayImRID)
	TerrainRendering.lightrays = rid
	
	var t = Texture2DRD.new()
	t.texture_rd_rid = rid
	lightRayVisualizer.texture = t
	
	if sdfGen:
		var image1 = Image.create_empty(TerrainRendering.renderSectionSize, TerrainRendering.renderSectionSize, false, Image.FORMAT_RGBAF);
		image1.fill(Color.BLACK)
		jumpFloodIm1RID = TerrainRendering.getRIDImage(image1, rd)
		
		var image2 = Image.create_empty(TerrainRendering.renderSectionSize, TerrainRendering.renderSectionSize, false, Image.FORMAT_RGBAF);
		image2.fill(Color.BLACK)
		jumpFloodIm2RID = TerrainRendering.getRIDImage(image2, rd)
		
		lightRaySDFRID = sdfGen.createSDF(lightrayImRID, jumpFloodIm1RID, jumpFloodIm2RID, 1, 0, 0)
		
		var s = Texture2DRD.new()
		s.texture_rd_rid = lightRaySDFRID
		lightSDFVisualize.texture = s
		
		#Final Light Spreading
		var image3 = Image.create_empty(TerrainRendering.renderSectionSize, TerrainRendering.renderSectionSize, false, Image.FORMAT_RGBAF);
		image2.fill(Color.BLACK)
		globalIlluminationRID = TerrainRendering.getRIDImage(image3, rd)
		
		var lightmap : RDUniform = TerrainRendering.getUniformImage(lightrayImRID, 0)
		var lightSDF : RDUniform = TerrainRendering.getUniformImage(lightRaySDFRID, 1)
		var globalIllumination : RDUniform = TerrainRendering.getUniformImage(globalIlluminationRID, 2)
		
		var uniformSet : RID = rd.uniform_set_create([lightmap, lightSDF, globalIllumination], GIShader, 0)
		var computeList : int = rd.compute_list_begin()
		
		TerrainRendering.executeComputeShader(Vector3i(16,16,1), rd, computeList, GIPipeline, uniformSet)
		
		TerrainRendering.GI = globalIlluminationRID
		
		var d = Texture2DRD.new()
		d.texture_rd_rid = globalIlluminationRID
		RenderingServer.global_shader_parameter_set("GLOBAL_ILLUMINATION", d)
		GlobalIlluminationVisualize.texture = d

func _ready() -> void:
	setupRenderingDevice()

func setupRenderingDevice():
	rd = RenderingServer.get_rendering_device()
	
	lightrayShader = rd.shader_create_from_spirv(lightrayShaderFile.get_spirv())
	pipelineLightray = rd.compute_pipeline_create(lightrayShader)
	
	GIShader = rd.shader_create_from_spirv(GIShaderFile.get_spirv())
	GIPipeline = rd.compute_pipeline_create(GIShader)
	
	var image1 = Image.create_empty(TerrainRendering.renderSectionSize, TerrainRendering.renderSectionSize, false, Image.FORMAT_RGBAF);
	image1.fill(Color.BLACK)
	lightrayImRID = TerrainRendering.getRIDImage(image1, rd)
	

func createLightrayIm(bitmap1RID : RID, bitmap2RID : RID, outputImRID : RID) -> RID: #Bitmaps check the red channel
	#Seed
	var bitmap1 : RDUniform = TerrainRendering.getUniformImage(bitmap1RID, 0)
	var bitmap2 : RDUniform = TerrainRendering.getUniformImage(bitmap2RID, 1)
	var outputIm : RDUniform = TerrainRendering.getUniformImage(outputImRID, 2)
	
	var sunDirectionData := PackedFloat32Array([TerrainRendering.sunDirection])
	var sunDirection := TerrainRendering.getRIDStorageBufferFloat(sunDirectionData, rd)
	var sdUniform := TerrainRendering.getUniformStorageBuffer(sunDirection, 3)
	
	
	var uniformSet : RID = rd.uniform_set_create([bitmap1, bitmap2, outputIm, sdUniform], lightrayShader, 0)
	var computeList : int = rd.compute_list_begin()
	
	TerrainRendering.executeComputeShader(Vector3i(16,16,1), rd, computeList, pipelineLightray, uniformSet)
	
	rd.free_rid(sunDirection)
	
	return outputImRID
