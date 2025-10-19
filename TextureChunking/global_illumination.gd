extends Node

@export var lightRayVisualizer : Sprite2D

var rd : RenderingDevice
var lightrayShaderFile = preload("uid://bw0seuypy6m0v")
var lightrayShader : RID
var pipelineLightray : RID
var lightrayImRID : RID


func _process(_delta: float) -> void:
	var rid : RID = createLightrayIm(TerrainRendering.foregroundSDF, TerrainRendering.backgroundSDF, lightrayImRID)
	TerrainRendering.lightrays = rid
	
	var t = Texture2DRD.new()
	t.texture_rd_rid = rid
	lightRayVisualizer.texture = t
	RenderingServer.global_shader_parameter_set("GLOBAL_ILLUMINATION", t)
	

func _ready() -> void:
	setupRenderingDevice()

func setupRenderingDevice():
	rd = RenderingServer.get_rendering_device()
	
	lightrayShader = rd.shader_create_from_spirv(lightrayShaderFile.get_spirv())
	pipelineLightray = rd.compute_pipeline_create(lightrayShader)
	
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
