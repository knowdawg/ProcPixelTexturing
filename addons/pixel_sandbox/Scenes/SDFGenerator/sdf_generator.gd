extends Node
class_name SDFGenerator

#@export var foregroundSdfVisualizer : Sprite2D
#@export var backgroundSdfVisualizer : Sprite2D

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

var forgroundSDFim1RID : RID
var forgroundSDFim2RID : RID

var backgroundSDFim1RID : RID
var backgroundSDFim2RID : RID

var workGroups : Vector3i
func setupRenderingDevice():
	var w : int = int(sqrt(float(TerrainRendering.renderSectionSize * TerrainRendering.renderSectionSize) / float(32 * 32)))
	workGroups = Vector3i(w, w, 1)
	
	rd = RenderingServer.get_rendering_device()
	
	JFSeedShader = rd.shader_create_from_spirv(JFSeedFile.get_spirv())
	pipelineSeed = rd.compute_pipeline_create(JFSeedShader)
	
	JFPassShader = rd.shader_create_from_spirv(JFPassFile.get_spirv())
	pipelinePass = rd.compute_pipeline_create(JFPassShader)
	
	JFDistanceShader = rd.shader_create_from_spirv(JFDistanceFile.get_spirv())
	pipelineDistance = rd.compute_pipeline_create(JFDistanceShader)
	
	var image1 = Image.create_empty(TerrainRendering.renderSectionSize, TerrainRendering.renderSectionSize, false, Image.FORMAT_RGBAF);
	image1.fill(Color.BLACK)
	forgroundSDFim2RID = TerrainRendering.getRIDImage(image1, rd)
	
	var image2 = Image.create_empty(TerrainRendering.renderSectionSize, TerrainRendering.renderSectionSize, false, Image.FORMAT_RGBAF);
	image2.fill(Color.BLACK)
	forgroundSDFim1RID = TerrainRendering.getRIDImage(image2, rd)
	
	
	var image3 = Image.create_empty(TerrainRendering.renderSectionSize, TerrainRendering.renderSectionSize, false, Image.FORMAT_RGBAF);
	image3.fill(Color.BLACK)
	backgroundSDFim1RID = TerrainRendering.getRIDImage(image3, rd)
	
	var image4 = Image.create_empty(TerrainRendering.renderSectionSize, TerrainRendering.renderSectionSize, false, Image.FORMAT_RGBAF);
	image4.fill(Color.BLACK)
	backgroundSDFim2RID = TerrainRendering.getRIDImage(image4, rd)
	

func createSDF(bitmapRID : RID, image1RID : RID, image2RID : RID, threshold : float = 0.0, sined : int = 1, offset : int = 1, offsetOveride : Vector2i = Vector2i(0, 0)) -> RID: #Bitmaps check the red channel
	#Seed
	var bitmap : RDUniform = TerrainRendering.getUniformImage(bitmapRID, 0)
	var outputIm : RDUniform = TerrainRendering.getUniformImage(image1RID, 1)
	
	var worldOffsetData := PackedInt32Array([
	int(TerrainRendering.tileTextureOffset.x * float(TerrainRendering.renderSectionSize) * float(offset)),
	int(TerrainRendering.tileTextureOffset.y * float(TerrainRendering.renderSectionSize) * float(offset)),
	sined
	])
	if offset == 0:
		worldOffsetData = PackedInt32Array([
		offsetOveride.x,
		offsetOveride.y,
		sined
		])
	
	var thresholdData := PackedFloat32Array([threshold])
	var thresholdRID := TerrainRendering.getRIDStorageBufferFloat(thresholdData, rd)
	var thresholdUniform := TerrainRendering.getUniformStorageBuffer(thresholdRID, 3)
	
	var woRID := TerrainRendering.getRIDStorageBufferInt(worldOffsetData, rd)
	var woUniform := TerrainRendering.getUniformStorageBufferInt(woRID, 2)
	
	var uniformSet : RID = rd.uniform_set_create([bitmap, outputIm, woUniform, thresholdUniform], JFSeedShader, 0)
	var computeList : int = rd.compute_list_begin()
	
	TerrainRendering.executeComputeShader(workGroups, rd, computeList, pipelineSeed, uniformSet)
	
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
		
		TerrainRendering.executeComputeShader(workGroups, rd, computeList, pipelinePass, uniformSet)
		
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
	
	woUniform = TerrainRendering.getUniformStorageBufferInt(woRID, 3)
	thresholdUniform = TerrainRendering.getUniformStorageBuffer(thresholdRID, 4)
	
	uniformSet = rd.uniform_set_create([bitmap, finalInput, finalOutput, woUniform, thresholdUniform], JFDistanceShader, 0)
	computeList = rd.compute_list_begin()
	
	TerrainRendering.executeComputeShader(workGroups, rd, computeList, pipelineDistance, uniformSet)
	
	rd.free_rid(woRID)
	rd.free_rid(thresholdRID)
	return returnRID

func _process(_delta: float) -> void:
	updateSDF()

func updateSDF():
	var t = Texture2DRD.new()
	t.texture_rd_rid = TerrainRendering.foregroundSDF
	#foregroundSdfVisualizer.texture = t
	
	t = Texture2DRD.new()
	t.texture_rd_rid = TerrainRendering.backgroundSDF
	#backgroundSdfVisualizer.texture = t
	
	var forgroundSDFRID : RID = createSDF(TerrainRendering.textureForegroundRID, forgroundSDFim1RID, forgroundSDFim2RID)
	TerrainRendering.foregroundSDF = forgroundSDFRID
	t = Texture2DRD.new()
	t.texture_rd_rid = forgroundSDFRID
	RenderingServer.global_shader_parameter_set("PS_FOREGROUND_SDF", t)

	var backgroudnSDFRID : RID = createSDF(TerrainRendering.textureBackgroundRID, backgroundSDFim1RID, backgroundSDFim2RID)
	TerrainRendering.backgroundSDF = backgroudnSDFRID
	
	var c : Camera2D = get_viewport().get_camera_2d()
	if c:
		var cPos : Vector2 = c.get_screen_center_position()
		cPos -= get_viewport().get_visible_rect().size / 2.0
		
		TerrainRendering.worldPosition = cPos
		RenderingServer.global_shader_parameter_set("PS_WORLD_POSITION", cPos)
		
		RenderingServer.global_shader_parameter_set("PS_CAMERA_ZOOM", c.zoom)
		

func _ready():
	setupRenderingDevice()
