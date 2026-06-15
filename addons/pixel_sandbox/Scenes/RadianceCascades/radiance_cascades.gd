extends Node
class_name RadianceCascades

@export_group("Radiance Cascades Parameters")
@export var cascadeCount : int = 6
@export var initialCascadeRayCount : int = 2
@export var initailCascadeRayLength : int = 1
@export var initialCascadeResolution : Vector2i = Vector2i(512, 512)

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
#Calculate Circular Harmonic Coefficients
var harmonicShaderFile = preload("uid://q4cohqurebh6")
var harmonicShader : RID
var harmonicPipeline : RID

#RIDs
var mipImageRIDs : Array[RID] = []
var cascadeImageRIDs : Array[RID] = []
var integratedCascadeOutput : RID
var harmonicImageRIDs : Array[RID] = []

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
	
	#create the images that will store the harmonic coefficients
	for i in range(5):#L2: 5 coefficients (DC, cos, sin, cos2, sin2), one texture each holding rgb
		var imSize : Vector2 = initialCascadeResolution
		var image := Image.create_empty(imSize.x, imSize.y, false, TerrainRendering.LIGHTING_IMAGE_FORMAT)
		image.fill(Color.BLACK)
		harmonicImageRIDs.append(TerrainRendering.getRIDImage(image, rd))
	
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
	
	
	var scProbe := RDPipelineSpecializationConstant.new()
	scProbe.constant_id = 0
	scProbe.value = initialCascadeRayCount

	var scC1 := RDPipelineSpecializationConstant.new()
	scC1.constant_id = 1
	scC1.value = initialCascadeRayCount * 2
	
	harmonicShader = rd.shader_create_from_spirv(harmonicShaderFile.get_spirv())
	harmonicPipeline = rd.compute_pipeline_create(harmonicShader, [scProbe, scC1])

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
	
	var HC : Texture2DRD;
	
	HC = Texture2DRD.new()
	HC.set_texture_rd_rid(harmonicImageRIDs[0])
	RenderingServer.global_shader_parameter_set("PS_CH_L0", HC)

	HC = Texture2DRD.new()
	HC.set_texture_rd_rid(harmonicImageRIDs[1])
	RenderingServer.global_shader_parameter_set("PS_CH_L1C", HC)

	HC = Texture2DRD.new()
	HC.set_texture_rd_rid(harmonicImageRIDs[2])
	RenderingServer.global_shader_parameter_set("PS_CH_L1S", HC)

	HC = Texture2DRD.new()
	HC.set_texture_rd_rid(harmonicImageRIDs[3])
	RenderingServer.global_shader_parameter_set("PS_CH_L2C", HC)

	HC = Texture2DRD.new()
	HC.set_texture_rd_rid(harmonicImageRIDs[4])
	RenderingServer.global_shader_parameter_set("PS_CH_L2S", HC)


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
			calculateCircularHarmonics()
		
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

#Uses the c1 rays ocluded by c0 to calculte circular harmonic coeficients for smooth directional lighting
func calculateCircularHarmonics():
	var w : int = (initialCascadeResolution.x / 32)
	var workGroups : Vector3i = Vector3i(w, w, 1)
	
	var c1 : RDUniform = TerrainRendering.getUniformImage(cascadeImageRIDs[1], 0)
	var c0 : RDUniform = TerrainRendering.getUniformImage(cascadeImageRIDs[0], 1)
	
	var CH_L0 : RDUniform = TerrainRendering.getUniformImage(harmonicImageRIDs[0], 2)
	var CH_L1C : RDUniform = TerrainRendering.getUniformImage(harmonicImageRIDs[1], 3)
	var CH_L1S : RDUniform = TerrainRendering.getUniformImage(harmonicImageRIDs[2], 4)
	var CH_L2C : RDUniform = TerrainRendering.getUniformImage(harmonicImageRIDs[3], 5)
	var CH_L2S : RDUniform = TerrainRendering.getUniformImage(harmonicImageRIDs[4], 6)

	var paramsData := PackedInt32Array([initialCascadeResolution.x, 16, 2, 4])
	var params := TerrainRendering.getRIDStorageBufferInt(paramsData, rd)
	var paramUniform := TerrainRendering.getUniformStorageBuffer(params, 7)

	var uniformSet : RID = rd.uniform_set_create([c1, c0, CH_L0, CH_L1C, CH_L1S, CH_L2C, CH_L2S, paramUniform], harmonicShader, 0)
	var computeList : int = rd.compute_list_begin()
	
	TerrainRendering.executeComputeShader(workGroups, rd, computeList, harmonicPipeline, [uniformSet])
	
	rd.free_rid(uniformSet)
	rd.free_rid(params)
