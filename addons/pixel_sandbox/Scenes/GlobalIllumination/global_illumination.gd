extends Node
class_name GlobalIllumination

@export var sdfGen : SDFGenerator

#@export var lightRayVisualizer : Sprite2D
#@export var lightSDFVisualize : Sprite2D
#@export var GlobalIlluminationVisualize : Sprite2D

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

var workGroups : Vector3i

func updateGI():
	var rid : RID = createLightrayIm(TerrainRendering.foregroundSDF, TerrainRendering.backgroundSDF, lightrayImRID)
	TerrainRendering.lightrays = rid
	
	var t = Texture2DRD.new()
	t.texture_rd_rid = rid
	#lightRayVisualizer.texture = t
	
	if sdfGen:
		lightRaySDFRID = sdfGen.createSDF(lightrayImRID, jumpFloodIm1RID, jumpFloodIm2RID, 0.6, 1, 0, Vector2i(int(float(TerrainRendering.renderSectionSize) / 2.0), int(float(TerrainRendering.renderSectionSize) / 2.0)))
		
		var s = Texture2DRD.new()
		s.texture_rd_rid = lightRaySDFRID
		#lightSDFVisualize.texture = s
		
		#Final Light Spreading
		var lightmap : RDUniform = TerrainRendering.getUniformImage(lightrayImRID, 0)
		var lightSDF : RDUniform = TerrainRendering.getUniformImage(lightRaySDFRID, 1)
		var globalIllumination : RDUniform = TerrainRendering.getUniformImage(globalIlluminationRID, 2)
		
		var uniformSet : RID = rd.uniform_set_create([lightmap, lightSDF, globalIllumination], GIShader, 0)
		var computeList : int = rd.compute_list_begin()
		
		TerrainRendering.executeComputeShader(workGroups, rd, computeList, GIPipeline, uniformSet)
		
		TerrainRendering.GI = globalIlluminationRID
		
		var d = Texture2DRD.new()
		d.texture_rd_rid = globalIlluminationRID
		RenderingServer.global_shader_parameter_set("PS_GLOBAL_ILLUMINATION", d)
		#GlobalIlluminationVisualize.texture = d

func _ready() -> void:
	setupRenderingDevice()
	
func _process(_delta: float) -> void:
	updateGI()

func setupRenderingDevice():
	var w : int = int(sqrt(float(TerrainRendering.renderSectionSize * TerrainRendering.renderSectionSize) / float(32 * 32)))
	workGroups = Vector3i(w, w, 1)
	
	rd = RenderingServer.get_rendering_device()
	
	lightrayShader = rd.shader_create_from_spirv(lightrayShaderFile.get_spirv())
	pipelineLightray = rd.compute_pipeline_create(lightrayShader)
	
	GIShader = rd.shader_create_from_spirv(GIShaderFile.get_spirv())
	GIPipeline = rd.compute_pipeline_create(GIShader)
	
	var image1 = Image.create_empty(TerrainRendering.renderSectionSize, TerrainRendering.renderSectionSize, false, Image.FORMAT_RGBAF);
	image1.fill(Color.BLACK)
	lightrayImRID = TerrainRendering.getRIDImage(image1, rd)
	
	
	var image2 = Image.create_empty(TerrainRendering.renderSectionSize, TerrainRendering.renderSectionSize, false, Image.FORMAT_RGBAF);
	image2.fill(Color.BLACK)
	jumpFloodIm1RID = TerrainRendering.getRIDImage(image2, rd)
	
	var image3 = Image.create_empty(TerrainRendering.renderSectionSize, TerrainRendering.renderSectionSize, false, Image.FORMAT_RGBAF);
	image3.fill(Color.BLACK)
	jumpFloodIm2RID = TerrainRendering.getRIDImage(image3, rd)
	
	var image4 = Image.create_empty(TerrainRendering.renderSectionSize, TerrainRendering.renderSectionSize, false, Image.FORMAT_RGBAF);
	image4.fill(Color.BLACK)
	globalIlluminationRID = TerrainRendering.getRIDImage(image4, rd)
	

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
	
	TerrainRendering.executeComputeShader(workGroups, rd, computeList, pipelineLightray, uniformSet)
	
	rd.free_rid(sunDirection)
	
	return outputImRID
