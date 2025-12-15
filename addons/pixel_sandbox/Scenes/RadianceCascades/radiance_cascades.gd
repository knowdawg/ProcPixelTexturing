extends Node
class_name RadianceCascades

@export var debugSprite : Sprite2D;

@export_group("Radiance Cascades Parameters")
@export var cascadeCount : int = 6
@export var initialCascadeRayCount : int = 4 #8, 16, 32, 64, 128
@export var initailCascadeRayLength : int = 1
@export var initialCascadeResolution : Vector2i = Vector2i(128, 128)

var rd : RenderingDevice

var cascadeShaderFile = preload("uid://bisgk0gq36n2y")
var cascadeShader : RID
var cascadePipeline : RID

var combineShaderFile = preload("uid://dnnbnbh3iidv7")
var combineShader : RID
var combinePipeline : RID

var integrateShaderFile = preload("uid://b0k2vav6dsip1")
var integrateShader : RID
var integratePipeline : RID

var cascadeImageRIDs : Array[RID] = []

var finalOutputImageRID : RID

var workGroups : Vector3i

func _ready() -> void:
	setup()
	TerrainRendering.radCasc = self
	
	var tex2DRD : Texture2DRD = Texture2DRD.new()
	tex2DRD.set_texture_rd_rid(finalOutputImageRID)
	debugSprite.texture = tex2DRD


func updateGlobalIllumination():
	for i in range(len(cascadeImageRIDs)):
		var lightSDF : RDUniform = TerrainRendering.getUniformImage(TerrainRendering.lightmapSDF, 0)
		var lightImage : RDUniform = TerrainRendering.getUniformImage(TerrainRendering.lightMapRID, 1)
		var outputIm : RDUniform = TerrainRendering.getUniformImage(cascadeImageRIDs[i], 2)
		
		var offsetX : int = int(TerrainRendering.tileTextureOffset.x * float(TerrainRendering.renderSectionSize))
		var offsetY : int = int(TerrainRendering.tileTextureOffset.y * float(TerrainRendering.renderSectionSize))
		
		var paramsData := PackedInt32Array([initialCascadeRayCount, initailCascadeRayLength, i, offsetX, offsetY])
		var params := TerrainRendering.getRIDStorageBufferInt(paramsData, rd)
		var paramUniform := TerrainRendering.getUniformStorageBuffer(params, 3)
		
		
		var uniformSet : RID = rd.uniform_set_create([lightSDF, lightImage, outputIm, paramUniform], cascadeShader, 0)
		var computeList : int = rd.compute_list_begin()
		
		TerrainRendering.executeComputeShader(workGroups, rd, computeList, cascadePipeline, [uniformSet])
		
		rd.free_rid(params)
	
	for i in range(len(cascadeImageRIDs) - 1, 0, -1):
		var bigCascade : RDUniform = TerrainRendering.getUniformImage(cascadeImageRIDs[i], 0)
		var mergeCascade : RDUniform = TerrainRendering.getUniformImage(cascadeImageRIDs[i - 1], 1)
		
		var mergeProbeSize : int = initialCascadeRayCount * pow(2, i - 1)
		
		var paramsData := PackedInt32Array([mergeProbeSize])
		var params := TerrainRendering.getRIDStorageBufferInt(paramsData, rd)
		var paramUniform := TerrainRendering.getUniformStorageBuffer(params, 2)
		
		var uniformSet : RID = rd.uniform_set_create([bigCascade, mergeCascade, paramUniform], combineShader, 0)
		var computeList : int = rd.compute_list_begin()
		
		TerrainRendering.executeComputeShader(workGroups, rd, computeList, combinePipeline, [uniformSet])
		
		rd.free_rid(params)
	
	
	var cascade0Uniform : RDUniform = TerrainRendering.getUniformImage(cascadeImageRIDs[0], 0)
	var outputUniform : RDUniform = TerrainRendering.getUniformImage(finalOutputImageRID, 1)
	
	var paramsData := PackedInt32Array([initialCascadeRayCount])
	var params := TerrainRendering.getRIDStorageBufferInt(paramsData, rd)
	var paramUniform := TerrainRendering.getUniformStorageBuffer(params, 2)
	
	var uniformSet : RID = rd.uniform_set_create([cascade0Uniform, outputUniform, paramUniform], integrateShader, 0)
	var computeList : int = rd.compute_list_begin()
	
	TerrainRendering.executeComputeShader(workGroups, rd, computeList, integratePipeline, [uniformSet])
	
	rd.free_rid(params)


func setup():
	var imSize := initialCascadeResolution * initialCascadeRayCount
	if imSize != Vector2i(TerrainRendering.renderSectionSize, TerrainRendering.renderSectionSize):
		printerr("Warning: Radiance Cascades Cascade Image size is not equal to TerrainRendering's render section size. This is not currently suported")
	workGroups = Vector3i(16, 16, 1)
	
	rd = RenderingServer.get_rendering_device()
	
	cascadeShader = rd.shader_create_from_spirv(cascadeShaderFile.get_spirv())
	cascadePipeline = rd.compute_pipeline_create(cascadeShader)
	
	combineShader = rd.shader_create_from_spirv(combineShaderFile.get_spirv())
	combinePipeline = rd.compute_pipeline_create(combineShader)
	
	integrateShader = rd.shader_create_from_spirv(integrateShaderFile.get_spirv())
	integratePipeline = rd.compute_pipeline_create(integrateShader)
	
	for i in range(cascadeCount):
		var image := Image.create_empty(imSize.x, imSize.y, false, Image.FORMAT_RGBAF);
		image.fill(Color.BLACK)
		var rid : RID = TerrainRendering.getRIDImage(image, rd)
		
		cascadeImageRIDs.append(rid)
	
	var image := Image.create_empty(initialCascadeResolution.x, initialCascadeResolution.y, false, Image.FORMAT_RGBAF);
	image.fill(Color.BLACK)
	finalOutputImageRID = TerrainRendering.getRIDImage(image, rd)
