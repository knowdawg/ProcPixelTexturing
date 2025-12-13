extends Node
class_name SDFGenerator

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

var pingpongIm : RID

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
	pingpongIm = TerrainRendering.getRIDImage(image1, rd)
	
	

#Creates a sdf based on bitmapRID of the size of the render quadrant
#Returns finalImage
func createSDF(bitmapRID : RID, finalImage : RID, threshold : float = 0.0, offsetByCameraPos : bool = true) -> RID: #Bitmaps check the red channel
	var passes : int = ceil(log(TerrainRendering.renderSectionSize) / log(2.0))
	var imOrderArray : Array[RID] = [pingpongIm, finalImage]
	if (passes - 1) % 2 == 0:
		imOrderArray = [finalImage, pingpongIm]
	
	var bitmap : RDUniform = TerrainRendering.getUniformImage(bitmapRID, 0)
	var outputIm : RDUniform = TerrainRendering.getUniformImage(imOrderArray[0], 1)
	
	
	var worldOffsetData := PackedInt32Array([
	int(TerrainRendering.tileTextureOffset.x * float(TerrainRendering.renderSectionSize)),
	int(TerrainRendering.tileTextureOffset.y * float(TerrainRendering.renderSectionSize))
	])
	if !offsetByCameraPos:
		worldOffsetData = PackedInt32Array([0, 0])
	
	var thresholdData := PackedFloat32Array([threshold])
	var thresholdRID := TerrainRendering.getRIDStorageBufferFloat(thresholdData, rd)
	var thresholdUniform := TerrainRendering.getUniformStorageBuffer(thresholdRID, 3)
	
	var woRID := TerrainRendering.getRIDStorageBufferInt(worldOffsetData, rd)
	var woUniform := TerrainRendering.getUniformStorageBufferInt(woRID, 2)
	
	var uniformSet : RID = rd.uniform_set_create([bitmap, outputIm, woUniform, thresholdUniform], JFSeedShader, 0)
	var computeList : int = rd.compute_list_begin()
	
	TerrainRendering.executeComputeShader(workGroups, rd, computeList, pipelineSeed, [uniformSet])
	
	for i in passes:
		var curOffset : int = int(TerrainRendering.renderSectionSize / (pow(2.0, i + 1)))
		#Standard Pass
		var data := PackedInt32Array([curOffset])
		var dataRID : RID = TerrainRendering.getRIDStorageBufferInt(data, rd)
		var dataUniform := TerrainRendering.getUniformStorageBufferInt(dataRID, 0)
		
		var input : RDUniform
		var output : RDUniform
		if i % 2 == 0:
			input = TerrainRendering.getUniformImage(imOrderArray[0], 1)
			output = TerrainRendering.getUniformImage(imOrderArray[1], 2)
		else:
			input = TerrainRendering.getUniformImage(imOrderArray[1], 1)
			output = TerrainRendering.getUniformImage(imOrderArray[0], 2)
		
		uniformSet = rd.uniform_set_create([dataUniform, input, output], JFPassShader, 0)
		computeList = rd.compute_list_begin()
		
		TerrainRendering.executeComputeShader(workGroups, rd, computeList, pipelinePass, [uniformSet])
		
		rd.free_rid(dataRID)
	
	#Final Distance Pass
	bitmap = TerrainRendering.getUniformImage(bitmapRID, 0)
	var finalInput : RDUniform = TerrainRendering.getUniformImage(pingpongIm, 1)
	var finalOutput : RDUniform = TerrainRendering.getUniformImage(finalImage, 2)
	var returnRID : RID
	
	woUniform = TerrainRendering.getUniformStorageBufferInt(woRID, 3)
	thresholdUniform = TerrainRendering.getUniformStorageBuffer(thresholdRID, 4)
	
	uniformSet = rd.uniform_set_create([bitmap, finalInput, finalOutput, woUniform, thresholdUniform], JFDistanceShader, 0)
	computeList = rd.compute_list_begin()
	
	TerrainRendering.executeComputeShader(workGroups, rd, computeList, pipelineDistance, [uniformSet])
	
	rd.free_rid(woRID)
	rd.free_rid(thresholdRID)
	return returnRID


#@export var debugSprite : Sprite2D
#
#var sdf : RID
#func updateSDF():
	#createSDF(TerrainRendering.worldVisualImageForegroundRID, sdf, 0.0, true)
	#TerrainRendering.foregroundSDF = sdf
	#
	#var tex2DRD : Texture2DRD = Texture2DRD.new()
	#tex2DRD.set_texture_rd_rid(sdf)
	#debugSprite.texture = tex2DRD
#
#func _process(_delta: float) -> void:
	#updateSDF()

func _ready():
	setupRenderingDevice()
	
