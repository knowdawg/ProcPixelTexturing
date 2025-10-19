extends Node
class_name SDFGenerator


@export var sdfVisualizer : Sprite2D

#RenderingDevice Vars DONT FORGET TO FREE RIDs
var rd : RenderingDevice
var JFSeedFile = preload("uid://c7jemw6btcgn7")
var JFSeedShader : RID
var pipelineSeed : RID

var JFPassFile = preload("uid://txbtpr7bv3gw")
var JFPassShader : RID
var pipelinePass : RID

var JFDistanceFile = preload("uid://cvtjqjev0utwf")
var JFDistanceShader : RID
var pipelineDistance : RID

var im1RID : RID
var im2RID : RID
func setupRenderingDevice():
	rd = RenderingServer.get_rendering_device()
	
	
	JFSeedShader = rd.shader_create_from_spirv(JFSeedFile.get_spirv())
	pipelineSeed = rd.compute_pipeline_create(JFSeedShader)
	
	JFPassShader = rd.shader_create_from_spirv(JFPassFile.get_spirv())
	pipelinePass = rd.compute_pipeline_create(JFPassShader)
	
	JFDistanceShader = rd.shader_create_from_spirv(JFDistanceFile.get_spirv())
	pipelineDistance = rd.compute_pipeline_create(JFDistanceShader)
	
	var image1 = Image.create_empty(TerrainRendering.renderSectionSize, TerrainRendering.renderSectionSize, false, Image.FORMAT_RGBAF);
	image1.fill(Color.BLACK)
	im2RID = TerrainRendering.getRIDImage(image1, rd)
	
	var image2 = Image.create_empty(TerrainRendering.renderSectionSize, TerrainRendering.renderSectionSize, false, Image.FORMAT_RGBAF);
	image2.fill(Color.BLACK)
	im1RID = TerrainRendering.getRIDImage(image2, rd)
	

func createSDF(bitmapRID : RID, image1RID : RID, image2RID : RID) -> RID: #Bitmaps check the red channel
	#Seed
	var bitmap : RDUniform = TerrainRendering.getUniformImage(bitmapRID, 0)
	var outputIm : RDUniform = TerrainRendering.getUniformImage(image1RID, 1)
	
	var uniformSet : RID = rd.uniform_set_create([bitmap, outputIm], JFSeedShader, 0)
	var computeList : int = rd.compute_list_begin()
	
	TerrainRendering.executeComputeShader(Vector3i(16,16,1), rd, computeList, pipelineSeed, uniformSet)
	
	
	var passes : int = ceil(log(TerrainRendering.renderSectionSize) / log(2.0))
	for i in passes:
		var curOffset : int = int(TerrainRendering.renderSectionSize / (pow(2.0, i + 1)))
		#Standard Pass
		var data := PackedInt32Array([curOffset])
		var dataRID : RID = TerrainRendering.getRIDStorageBufferInt(data, rd)
		var dataUniform := TerrainRendering.getUniformStorageBufferInt(dataRID, 0)
		
		var input : RDUniform
		var output : RDUniform
		if i % 2 == 0:
			input = TerrainRendering.getUniformImage(image1RID, 1)
			output = TerrainRendering.getUniformImage(image2RID, 2)
		else:
			input = TerrainRendering.getUniformImage(image2RID, 1)
			output = TerrainRendering.getUniformImage(image1RID, 2)
		
		uniformSet = rd.uniform_set_create([dataUniform, input, output], JFPassShader, 0)
		computeList = rd.compute_list_begin()
		
		TerrainRendering.executeComputeShader(Vector3i(16,16,1), rd, computeList, pipelinePass, uniformSet)
		
		rd.free_rid(dataRID)
	
	#Final Distance Pass
	bitmap = TerrainRendering.getUniformImage(bitmapRID, 0)
	var finalInput : RDUniform
	var finalOutput : RDUniform
	var returnRID : RID
	if (passes - 1) % 2 == 0:
		finalInput = TerrainRendering.getUniformImage(image2RID, 1)
		finalOutput = TerrainRendering.getUniformImage(image1RID, 2)
		returnRID = image1RID
	else:
		finalInput = TerrainRendering.getUniformImage(image1RID, 1)
		finalOutput = TerrainRendering.getUniformImage(image2RID, 2)
		returnRID = image2RID
	
	
	uniformSet = rd.uniform_set_create([bitmap, finalInput, finalOutput], JFDistanceShader, 0)
	computeList = rd.compute_list_begin()
	
	TerrainRendering.executeComputeShader(Vector3i(16,16,1), rd, computeList, pipelineDistance, uniformSet)
	
	return returnRID

func _process(_delta: float) -> void:
	var t = Texture2DRD.new()
	t.texture_rd_rid = TerrainRendering.foregroundSDF
	sdfVisualizer.texture = t
	
	var SDFRID : RID = createSDF(TerrainRendering.envirementalDataTextureRID, im1RID, im2RID)
	TerrainRendering.foregroundSDF = SDFRID
	
	
	
	var c : Camera2D = get_viewport().get_camera_2d()
	if c:
		var cPos : Vector2 = c.global_position
		cPos -= get_viewport().get_visible_rect().size / 2.0
		RenderingServer.global_shader_parameter_set("WORLD_POSITION", cPos)
		

func _ready():
	setupRenderingDevice()
