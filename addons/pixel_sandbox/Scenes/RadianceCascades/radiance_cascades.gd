extends Node
class_name RadianceCascades

@export var debugSprite : Sprite2D

@export_group("Radiance Cascades Parameters")
@export var cascadeCount : int = 6
@export var initialCascadeRayCount : int = 2
@export var initailCascadeRayLength : int = 1
@export var initialCascadeResolution : Vector2i = Vector2i(512, 512)

var rd : RenderingDevice

#First step: Raymarching from each probe
var cascadeShaderFile = preload("uid://bisgk0gq36n2y")
var cascadeShader : RID
var cascadePipeline : RID

#Secound step: Merge each cascades, highest angular resolution -> lowest angular resolution
var combineShaderFile = preload("uid://dnnbnbh3iidv7")
var combineShader : RID
var combinePipeline : RID

#Third Step: Calculate the radiance from all direction of the final probe layer
var integrateShaderFile = preload("uid://cxvi33278o674")
var integrateShader : RID
var integratePipeline : RID

#Keep track of image RID
var cascadeImageRIDs : Array[RID] = []
var finalOutputImageRID : RID

#Shader Uniforms
var lightSDFUniform : RDUniform
var lightImageUniform : RDUniform
var finalOutputImageUniform : RDUniform

var cascadeImageUniformsBinding0 : Array[RDUniform]
var cascadeImageUniformsBinding1 : Array[RDUniform]
var cascadeImageUniformsBinding2 : Array[RDUniform]

var workGroups : Vector3i

func _ready() -> void:
	setup()
	TerrainRendering.radCasc = self
	
	'''Set the light sprite's texture equal to radiance cascade texture '''
	var GI : Texture2DRD = Texture2DRD.new()
	GI.set_texture_rd_rid(finalOutputImageRID)
	var dirGI : Texture2DRD = Texture2DRD.new()
	dirGI.set_texture_rd_rid(cascadeImageRIDs[0])
		
	RenderingServer.global_shader_parameter_set("PS_GLOBAL_ILLUMINATION_TEXTURE_SIZE", initialCascadeResolution.x)
	RenderingServer.global_shader_parameter_set("PS_GLOBAL_ILLUMINATION", GI)
	RenderingServer.global_shader_parameter_set("PS_GLOBAL_ILLUMINATION_DIRECTIONAL_DATA", dirGI)
	RenderingServer.global_shader_parameter_set("PS_INITIAL_CASCADE_PROBE_SIZE", initialCascadeRayCount)
	
	if debugSprite:
		debugSprite.texture = GI

func updateGlobalIllumination():
	for i in range(len(cascadeImageRIDs)):
		var offsetX : int = int(TerrainRendering.tileTextureOffset.x * float(TerrainRendering.renderSectionSize))
		var offsetY : int = int(TerrainRendering.tileTextureOffset.y * float(TerrainRendering.renderSectionSize))
		
		var paramsData := PackedInt32Array([initialCascadeRayCount, initailCascadeRayLength, i, offsetX, offsetY])
		var params := TerrainRendering.getRIDStorageBufferInt(paramsData, rd)
		var paramUniform := TerrainRendering.getUniformStorageBuffer(params, 3)
		
		
		var uniformSet : RID = rd.uniform_set_create([lightSDFUniform, lightImageUniform, cascadeImageUniformsBinding2[i], paramUniform], cascadeShader, 0)
		var computeList : int = rd.compute_list_begin()
		
		TerrainRendering.executeComputeShader(workGroups, rd, computeList, cascadePipeline, [uniformSet])
		
		rd.free_rid(uniformSet)
		rd.free_rid(params)
	
	for i in range(len(cascadeImageRIDs) - 1, 0, -1):
		var mergeProbeSize : int = initialCascadeRayCount * pow(2, i - 1)
		
		var paramsData := PackedInt32Array([mergeProbeSize])
		var params := TerrainRendering.getRIDStorageBufferInt(paramsData, rd)
		var paramUniform := TerrainRendering.getUniformStorageBuffer(params, 2)
		
		var uniformSet : RID = rd.uniform_set_create([cascadeImageUniformsBinding0[i], cascadeImageUniformsBinding1[i-1], paramUniform], combineShader, 0)
		var computeList : int = rd.compute_list_begin()
		
		TerrainRendering.executeComputeShader(workGroups, rd, computeList, combinePipeline, [uniformSet])
		
		rd.free_rid(uniformSet)
		rd.free_rid(params)
	
	var paramsData := PackedInt32Array([initialCascadeRayCount])
	var params := TerrainRendering.getRIDStorageBufferInt(paramsData, rd)
	var paramUniform := TerrainRendering.getUniformStorageBuffer(params, 2)
	
	var uniformSet : RID = rd.uniform_set_create([cascadeImageUniformsBinding0[0], finalOutputImageUniform, paramUniform], integrateShader, 0)
	var computeList : int = rd.compute_list_begin()
	
	var integrateWorkGroups := Vector3i(1.0, 1.0, 1.0)
	integrateWorkGroups.x = int(float(initialCascadeResolution.x) / float(TerrainRendering.renderSectionSize) * 16.0 * initialCascadeRayCount) # Remove * initialCascadeRayCount after
	integrateWorkGroups.y = integrateWorkGroups.x
	
	TerrainRendering.executeComputeShader(integrateWorkGroups, rd, computeList, integratePipeline, [uniformSet])
	
	rd.free_rid(uniformSet)
	rd.free_rid(params)


func setup():
	var imSize := initialCascadeResolution * initialCascadeRayCount
	
	workGroups = Vector3i(0, 0, 1)
	workGroups.x = int(float(initialCascadeResolution.x * initialCascadeRayCount) / 32.0)
	workGroups.y = int(float(initialCascadeResolution.y * initialCascadeRayCount) / 32.0)
	#print("Work Groups: ", workGroups)
	
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
		
		cascadeImageUniformsBinding0.append(TerrainRendering.getUniformImage(rid, 0))
		cascadeImageUniformsBinding1.append(TerrainRendering.getUniformImage(rid, 1))
		cascadeImageUniformsBinding2.append(TerrainRendering.getUniformImage(rid, 2))
	
	var image := Image.create_empty(initialCascadeResolution.x, initialCascadeResolution.y, false, Image.FORMAT_RGBAF);
	image.fill(Color.BLACK)
	finalOutputImageRID = TerrainRendering.getRIDImage(image, rd)
	
	#Create Uniforms
	lightSDFUniform = TerrainRendering.getUniformImage(TerrainRendering.lightmapSDF, 0)
	lightImageUniform = TerrainRendering.getUniformImage(TerrainRendering.finalLightImageRID, 1)
	finalOutputImageUniform = TerrainRendering.getUniformImage(finalOutputImageRID, 1)
