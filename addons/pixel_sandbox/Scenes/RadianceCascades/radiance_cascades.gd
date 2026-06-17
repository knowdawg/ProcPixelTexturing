extends Node
class_name RadianceCascades

@export_group("Radiance Cascades Parameters")
@export var cascadeCount : int = 6
@export var initialCascadeRayCount : int = 2
@export var initailCascadeRayLength : int = 1
@export var initialCascadeResolution : Vector2i = Vector2i(512, 512)
@export var directionCount : int = 16 #cosine-convolved diffuse layers baked; cannot exceed c1 ray count

var mipScale : float = 0.5

"""----------Compute Shaders----------"""
var rd : RenderingDevice
var sampler : RID
#Mipmap Shader
var mipmapShaderFile = preload("uid://dtlktq75wb17s")
var mipmapShader : RID
var mipmapPipeline : RID
#Gather Cascade Shader
var gatherCascadeShaderFile = preload("uid://bjglfxo50elcd")
var gatherCascadeShader : RID
var gatherCascadePipeline : RID
#Merge Cascades Shader
var mergeCascadesShaderFile = preload("uid://djqe87hqn7eo2")
var mergeCascadesShader : RID
var mergeCascadesPipeline : RID
#Integrate Cascade Shader
var integrateShaderFile = preload("uid://c2567w5h2vofu")
var integrateShader : RID
var integratePipeline : RID
#Pass 1: merge c1+c0 rays -> mergedRays texture + fluence
var mergeRaysShaderFile = preload("uid://bv4jleh8ak6d1")
var mergeRaysShader : RID
var mergeRaysPipeline : RID
#Pass 2: cosine-convolve mergedRays -> directional diffuse
var convolutionShaderFile = preload("uid://cb8v8u4i0f25e")
var convolutionShader : RID
var convolutionPipeline : RID

#RIDs
var mipImageRIDs : Array[RID] = []
var cascadeImageRIDs : Array[RID] = []
var integratedCascadeOutput : RID
var mergedRaysRID : RID
var diffuseDirectionsRID : RID
var fluenceRID : RID

#Uniforms
func setup():
	rd = RenderingServer.get_rendering_device()
	
	var  samplerState : RDSamplerState = RDSamplerState.new()
	samplerState.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR #dont know if linear or nearest is better
	samplerState.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	samplerState.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	samplerState.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	sampler = rd.sampler_create(samplerState)
	
	#create a mipmap for each cascade, cascade 0 just has the base light image
	mipImageRIDs.append(TerrainRendering.finalLightImageRID)
	for i in range(1, cascadeCount):
		var imSize : int = TerrainRendering.renderSectionSize / pow(2, float(i)) #Halve each cascade
		var image := Image.create_empty(imSize, imSize, false, TerrainRendering.LIGHTING_IMAGE_FORMAT);
		image.fill(Color.BLACK)
		mipImageRIDs.append(TerrainRendering.getRIDImage(image, rd))
	
	#create the images for each cascade, size remains the same as 1/4 probes and 4x rays
	for i in range(cascadeCount):
		var imSize : Vector2 = initialCascadeResolution * initialCascadeRayCount
		
		var image := Image.create_empty(imSize.x, imSize.y, false, TerrainRendering.LIGHTING_IMAGE_FORMAT)
		image.fill(Color.BLACK)
		cascadeImageRIDs.append(TerrainRendering.getRIDImage(image, rd))
	
	#merged rays texture (one layer per ray): Pass 1 output, Pass 2 input
	var c1RayCount : int = (initialCascadeRayCount * 2) * (initialCascadeRayCount * 2)
	mergedRaysRID = TerrainRendering.getRIDBlankImage2DArray(initialCascadeResolution.x, initialCascadeResolution.y, c1RayCount, rd)

	#directional diffuse texture array (one layer per facing direction) + fluence ambient
	diffuseDirectionsRID = TerrainRendering.getRIDBlankImage2DArray(initialCascadeResolution.x, initialCascadeResolution.y, directionCount, rd)

	var fluenceImage := Image.create_empty(initialCascadeResolution.x, initialCascadeResolution.y, false, TerrainRendering.LIGHTING_IMAGE_FORMAT)
	fluenceImage.fill(Color.BLACK)
	fluenceRID = TerrainRendering.getRIDImage(fluenceImage, rd)
	
	#create the final output of the RC
	var image := Image.create_empty(initialCascadeResolution.x, initialCascadeResolution.y, false, TerrainRendering.LIGHTING_IMAGE_FORMAT)
	image.fill(Color.BLACK)
	integratedCascadeOutput = TerrainRendering.getRIDImage(image, rd)
	
	#Setup the compute shaders / pipelines
	mipmapShader = rd.shader_create_from_spirv(mipmapShaderFile.get_spirv())
	mipmapPipeline = rd.compute_pipeline_create(mipmapShader)
	
	gatherCascadeShader = rd.shader_create_from_spirv(gatherCascadeShaderFile.get_spirv())
	gatherCascadePipeline = rd.compute_pipeline_create(gatherCascadeShader)
	
	mergeCascadesShader = rd.shader_create_from_spirv(mergeCascadesShaderFile.get_spirv())
	mergeCascadesPipeline = rd.compute_pipeline_create(mergeCascadesShader)
	
	integrateShader = rd.shader_create_from_spirv(integrateShaderFile.get_spirv())
	integratePipeline = rd.compute_pipeline_create(integrateShader)
	
	
	#spec constants: c0ProbeSize, c1ProbeSize, directionCount, c1RayCountPerProbe
	var c1ProbeSize : int = initialCascadeRayCount * 2

	var scProbe := RDPipelineSpecializationConstant.new()
	scProbe.constant_id = 0
	scProbe.value = initialCascadeRayCount

	var scC1 := RDPipelineSpecializationConstant.new()
	scC1.constant_id = 1
	scC1.value = c1ProbeSize

	var scDirCount := RDPipelineSpecializationConstant.new()
	scDirCount.constant_id = 2
	scDirCount.value = directionCount

	var scC1RayCount := RDPipelineSpecializationConstant.new()
	scC1RayCount.constant_id = 3
	scC1RayCount.value = c1ProbeSize * c1ProbeSize

	#Pass 1 (MergeRays): c0ProbeSize, c1ProbeSize, c1RayCountPerProbe
	mergeRaysShader = rd.shader_create_from_spirv(mergeRaysShaderFile.get_spirv())
	mergeRaysPipeline = rd.compute_pipeline_create(mergeRaysShader, [scProbe, scC1, scC1RayCount])

	#Pass 2 (DiffuseDirectionConvolution): directionCount, c1RayCountPerProbe
	convolutionShader = rd.shader_create_from_spirv(convolutionShaderFile.get_spirv())
	convolutionPipeline = rd.compute_pipeline_create(convolutionShader, [scDirCount, scC1RayCount])

func _ready() -> void:
	setup()
	TerrainRendering.radCasc = self
	
	'''Set the light sprite's texture equal to radiance cascade texture '''
	var GI : Texture2DRD = Texture2DRD.new()
	GI.set_texture_rd_rid(integratedCascadeOutput)
	var dirGI : Texture2DRD = Texture2DRD.new()
	dirGI.set_texture_rd_rid(cascadeImageRIDs[0])
	
	RenderingServer.global_shader_parameter_set("PS_GLOBAL_ILLUMINATION_TEXTURE_SIZE", initialCascadeResolution.x)
	RenderingServer.global_shader_parameter_set("PS_GLOBAL_ILLUMINATION", GI)
	RenderingServer.global_shader_parameter_set("PS_INITIAL_CASCADE_PROBE_SIZE", initialCascadeRayCount)
	
	var dirDiffuse : Texture2DArrayRD = Texture2DArrayRD.new()
	dirDiffuse.set_texture_rd_rid(diffuseDirectionsRID)
	RenderingServer.global_shader_parameter_set("PS_DIFFUSE_DIRECTIONS", dirDiffuse)

	var fluence : Texture2DRD = Texture2DRD.new()
	fluence.set_texture_rd_rid(fluenceRID)
	RenderingServer.global_shader_parameter_set("PS_FLUENCE", fluence)


func updateGlobalIllumination():
	#Step 1: Generate Mipmaps
	for i in range(1, cascadeCount):
		if i > 5:
			continue
		var w : int = (TerrainRendering.renderSectionSize / int(pow(2, float(i)))) / 16
		var workGroups : Vector3i = Vector3i(w, w, 1)
		
		var source : RDUniform = TerrainRendering.getUniformImage(mipImageRIDs[i - 1], 0)
		var outputBuffer : RDUniform = TerrainRendering.getUniformImage(mipImageRIDs[i], 1)
		
		var uniformSet : RID = rd.uniform_set_create([source, outputBuffer], mipmapShader, 0)
		var computeList : int = rd.compute_list_begin()
		
		TerrainRendering.executeComputeShader(workGroups, rd, computeList, mipmapPipeline, [uniformSet])
		
		rd.free_rid(uniformSet)
	
	#Step 2: Gather Cascades
	for i in range(cascadeCount):
		var w : int = (TerrainRendering.renderSectionSize / 32) * initialCascadeRayCount
		var workGroups : Vector3i = Vector3i(w, w, 1)
		
		var lightmapMip = mipImageRIDs[i]
		var lightImage : RDUniform = TerrainRendering.getUniformSampler(lightmapMip, sampler, 0)
		var outputCascadeBuffer : RDUniform = TerrainRendering.getUniformImage(cascadeImageRIDs[i], 1)
		
		var paramsData := PackedInt32Array([initialCascadeRayCount, initailCascadeRayLength, i])
		var params := TerrainRendering.getRIDStorageBufferInt(paramsData, rd)
		var paramUniform := TerrainRendering.getUniformStorageBuffer(params, 2)
		
		var uniformSet : RID = rd.uniform_set_create([lightImage, outputCascadeBuffer, paramUniform], gatherCascadeShader, 0)
		var computeList : int = rd.compute_list_begin()
		
		TerrainRendering.executeComputeShader(workGroups, rd, computeList, gatherCascadePipeline, [uniformSet])
		
		rd.free_rid(uniformSet)
		rd.free_rid(params)
	
	#Step 3: Merge Cascades
	for i in range(cascadeCount - 1, 0, -1):
		if i == 1: #Right before the final merge
			bakeDiffuseDirections()
			continue
		
		var w : int = (TerrainRendering.renderSectionSize / 32) * initialCascadeRayCount
		var workGroups : Vector3i = Vector3i(w, w, 1)
		
		var mergeProbeSize : int = initialCascadeRayCount * pow(2, i - 1)
		
		var bigCascade : RDUniform = TerrainRendering.getUniformImage(cascadeImageRIDs[i], 0)
		var smaleCascade : RDUniform = TerrainRendering.getUniformImage(cascadeImageRIDs[i - 1], 1)
		
		var paramsData := PackedInt32Array([mergeProbeSize])
		var params := TerrainRendering.getRIDStorageBufferInt(paramsData, rd)
		var paramUniform := TerrainRendering.getUniformStorageBuffer(params, 2)
		
		var uniformSet : RID = rd.uniform_set_create([bigCascade, smaleCascade, paramUniform], mergeCascadesShader, 0)
		var computeList : int = rd.compute_list_begin()
		
		TerrainRendering.executeComputeShader(workGroups, rd, computeList, mergeCascadesPipeline, [uniformSet])
		
		rd.free_rid(uniformSet)
		rd.free_rid(params)
	
	return #backDifuseDirections calculates fluence by default
	#Step 4: Integrate Final Cascade
	var paramsData := PackedInt32Array([initialCascadeRayCount])
	var params := TerrainRendering.getRIDStorageBufferInt(paramsData, rd)
	var paramUniform := TerrainRendering.getUniformStorageBuffer(params, 2)
	
	var cascade0ImageUniform = TerrainRendering.getUniformImage(cascadeImageRIDs[0], 0)
	var integratedCascadeOutputUniform = TerrainRendering.getUniformImage(integratedCascadeOutput, 1)
	
	var uniformSet : RID = rd.uniform_set_create([cascade0ImageUniform, integratedCascadeOutputUniform, paramUniform], integrateShader, 0)
	var computeList : int = rd.compute_list_begin()
	
	var integrateWorkGroups := Vector3i(1.0, 1.0, 1.0)
	integrateWorkGroups.x = int(float(initialCascadeResolution.x) / float(TerrainRendering.renderSectionSize) * 16.0 * initialCascadeRayCount) # Remove * initialCascadeRayCount after
	integrateWorkGroups.y = integrateWorkGroups.x
	
	TerrainRendering.executeComputeShader(integrateWorkGroups, rd, computeList, integratePipeline, [uniformSet])
	
	rd.free_rid(uniformSet)
	rd.free_rid(params)

#Uses the c1 rays ocluded by c0 to bake cosine-convolved directional diffuse + fluence ambient
func bakeDiffuseDirections():
	var w : int = (initialCascadeResolution.x / 32)
	var workGroups : Vector3i = Vector3i(w, w, 1)

	#Pass 1: merge c1+c0 rays -> mergedRays + fluence
	var c1 : RDUniform = TerrainRendering.getUniformImage(cascadeImageRIDs[1], 0)
	var c0 : RDUniform = TerrainRendering.getUniformImage(cascadeImageRIDs[0], 1)
	var mergedRays : RDUniform = TerrainRendering.getUniformImage(mergedRaysRID, 2)
	var fluence : RDUniform = TerrainRendering.getUniformImage(fluenceRID, 3)

	var mergeSet : RID = rd.uniform_set_create([c1, c0, mergedRays, fluence], mergeRaysShader, 0)
	var mergeList : int = rd.compute_list_begin()
	TerrainRendering.executeComputeShader(workGroups, rd, mergeList, mergeRaysPipeline, [mergeSet])
	rd.free_rid(mergeSet)

	#Pass 2: cosine-convolve mergedRays -> directional diffuse
	var mergedRaysIn : RDUniform = TerrainRendering.getUniformImage(mergedRaysRID, 0)
	var diffuseDirections : RDUniform = TerrainRendering.getUniformImage(diffuseDirectionsRID, 1)

	var convSet : RID = rd.uniform_set_create([mergedRaysIn, diffuseDirections], convolutionShader, 0)
	var convList : int = rd.compute_list_begin()
	TerrainRendering.executeComputeShader(workGroups, rd, convList, convolutionPipeline, [convSet])
	rd.free_rid(convSet)
