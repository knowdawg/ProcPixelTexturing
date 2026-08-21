extends Node
class_name RadianceCascades

@export_group("Radiance Cascades Parameters")
@export var cascadeCount : int = 5
@export var initialCascadeRayCount : int = 2
@export var initailCascadeRayLength : int = 1
@export var initialCascadeResolution : Vector2i = Vector2i(512, 512)
@export var directionCount : int = 16 #cosine-convolved diffuse layers baked; cannot exceed c1 ray count

const MIP_LEVELS : int = 10

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
var mergedRaysRID : RID
var diffuseDirectionsRID : RID
var fluenceRID : RID

#Scale Cascade's mips to thier resolution
#A 256-probe cascade reading a 512 light map should sample 1 level deeper: log2(512/256) = 1.
func resolutionMipOffset() -> int:
	var ratio : float = float(PixelSandbox.renderSectionSize) / float(initialCascadeResolution.x)
	return max(0, int(round(log(ratio) / log(2.0))))

func cascadeMip(i : int) -> int:
	return i
	return min(i + resolutionMipOffset(), MIP_LEVELS - 1)

#Uniforms
func setup():
	rd = RenderingServer.get_rendering_device()
	
	var  samplerState : RDSamplerState = RDSamplerState.new()
	samplerState.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR #dont know if linear or nearest is better
	samplerState.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	samplerState.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	samplerState.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_CLAMP_TO_EDGE
	sampler = rd.sampler_create(samplerState)
	
	#create the mips
	mipImageRIDs.append(TerrainRendering.finalLightImageRID)
	for i in range(1, MIP_LEVELS):
		var imSize : int = max(1, int(PixelSandbox.renderSectionSize / pow(2, float(i)))) #Halve each level
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
	
	#Setup the compute shaders / pipelines
	mipmapShader = rd.shader_create_from_spirv(mipmapShaderFile.get_spirv())
	mipmapPipeline = rd.compute_pipeline_create(mipmapShader)
	
	gatherCascadeShader = rd.shader_create_from_spirv(gatherCascadeShaderFile.get_spirv())
	gatherCascadePipeline = rd.compute_pipeline_create(gatherCascadeShader)
	
	mergeCascadesShader = rd.shader_create_from_spirv(mergeCascadesShaderFile.get_spirv())
	mergeCascadesPipeline = rd.compute_pipeline_create(mergeCascadesShader)
	
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
	
	RenderingServer.global_shader_parameter_set("PS_GLOBAL_ILLUMINATION_TEXTURE_SIZE", initialCascadeResolution.x)

	var dirDiffuse : Texture2DArrayRD = Texture2DArrayRD.new()
	dirDiffuse.set_texture_rd_rid(diffuseDirectionsRID)
	RenderingServer.global_shader_parameter_set("PS_DIFFUSE_DIRECTIONS", dirDiffuse)

	var fluence : Texture2DRD = Texture2DRD.new()
	fluence.set_texture_rd_rid(fluenceRID)
	RenderingServer.global_shader_parameter_set("PS_FLUENCE", fluence)


func updateGlobalIllumination():
	#Step 1: Generate Mipmaps
	for i in range(1, MIP_LEVELS):
		var w : int = max(1, (PixelSandbox.renderSectionSize / int(pow(2, float(i)))) / 16)
		var workGroups : Vector3i = Vector3i(w, w, 1)
		
		var source : RDUniform = TerrainRendering.getUniformImage(mipImageRIDs[i - 1], 0)
		var outputBuffer : RDUniform = TerrainRendering.getUniformImage(mipImageRIDs[i], 1)

		var uniformSet : RID = rd.uniform_set_create([source, outputBuffer], mipmapShader, 0)
		rd.draw_command_begin_label("RC/GenerateMipmap[%d]" % i, Color.CYAN)
		var computeList : int = rd.compute_list_begin()

		TerrainRendering.executeComputeShader(workGroups, rd, computeList, mipmapPipeline, [uniformSet])
		rd.draw_command_end_label()

		rd.free_rid(uniformSet)
	
	#Step 2: Gather Cascades
	for i in range(cascadeCount):
		var w : int = (PixelSandbox.renderSectionSize / 32) * initialCascadeRayCount
		var workGroups : Vector3i = Vector3i(w, w, 1)
		
		var lightmapMip = mipImageRIDs[cascadeMip(i)]
		var lightImage : RDUniform = TerrainRendering.getUniformSampler(lightmapMip, sampler, 0)
		var outputCascadeBuffer : RDUniform = TerrainRendering.getUniformImage(cascadeImageRIDs[i], 1)
		
		var paramsData := PackedInt32Array([initialCascadeRayCount, initailCascadeRayLength, i, initialCascadeResolution.x, PixelSandbox.renderSectionSize])
		var params := TerrainRendering.getRIDStorageBufferInt(paramsData, rd)
		var paramUniform := TerrainRendering.getUniformStorageBuffer(params, 2)
		
		var uniformSet : RID = rd.uniform_set_create([lightImage, outputCascadeBuffer, paramUniform], gatherCascadeShader, 0)
		rd.draw_command_begin_label("RC/GatherCascade[%d]" % i, Color.YELLOW)
		var computeList : int = rd.compute_list_begin()

		TerrainRendering.executeComputeShader(workGroups, rd, computeList, gatherCascadePipeline, [uniformSet])
		rd.draw_command_end_label()

		rd.free_rid(uniformSet)
		rd.free_rid(params)
	
	#Step 3: Merge Cascades, only down to cascade 1
	for i in range(cascadeCount - 1, 1, -1):
		
		var w : int = (PixelSandbox.renderSectionSize / 32) * initialCascadeRayCount
		var workGroups : Vector3i = Vector3i(w, w, 1)
		
		var mergeProbeSize : int = initialCascadeRayCount * pow(2, i - 1)
		
		var bigCascade : RDUniform = TerrainRendering.getUniformImage(cascadeImageRIDs[i], 0)
		var smaleCascade : RDUniform = TerrainRendering.getUniformImage(cascadeImageRIDs[i - 1], 1)
		
		var paramsData := PackedInt32Array([mergeProbeSize])
		var params := TerrainRendering.getRIDStorageBufferInt(paramsData, rd)
		var paramUniform := TerrainRendering.getUniformStorageBuffer(params, 2)
		
		var uniformSet : RID = rd.uniform_set_create([bigCascade, smaleCascade, paramUniform], mergeCascadesShader, 0)
		rd.draw_command_begin_label("RC/MergeCascades[%d]" % i, Color.ORANGE)
		var computeList : int = rd.compute_list_begin()
		
		TerrainRendering.executeComputeShader(workGroups, rd, computeList, mergeCascadesPipeline, [uniformSet])
		rd.draw_command_end_label()
		
		rd.free_rid(uniformSet)
		rd.free_rid(params)
	
	#produces the final fluence + directional diffuse
	bakeDiffuseDirections()

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
	rd.draw_command_begin_label("RC/MergeRays", Color.GREEN)
	var mergeList : int = rd.compute_list_begin()
	TerrainRendering.executeComputeShader(workGroups, rd, mergeList, mergeRaysPipeline, [mergeSet])
	rd.draw_command_end_label()
	rd.free_rid(mergeSet)

	#Pass 2: cosine-convolve mergedRays -> directional diffuse
	var mergedRaysIn : RDUniform = TerrainRendering.getUniformImage(mergedRaysRID, 0)
	var diffuseDirections : RDUniform = TerrainRendering.getUniformImage(diffuseDirectionsRID, 1)

	var convSet : RID = rd.uniform_set_create([mergedRaysIn, diffuseDirections], convolutionShader, 0)
	rd.draw_command_begin_label("RC/DiffuseDirectionConvolution", Color.MAGENTA)
	var convList : int = rd.compute_list_begin()
	TerrainRendering.executeComputeShader(workGroups, rd, convList, convolutionPipeline, [convSet])
	rd.draw_command_end_label()
	rd.free_rid(convSet)
