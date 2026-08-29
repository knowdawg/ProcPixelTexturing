extends Node

"""
Manages Rendering Terrain Data
"""

var sdfGen : SDFGenerator
var lightmapSDF : RID

var radCasc : RadianceCascades

var textureWrapCount : Vector2 #Amount of times the envirement texture has wrapped in on itself
var textureWrapPixelOffset : Vector2i #The pixel count of the current offset
var cameraPosition : Vector2
var cameraChunkPixelProgress : Vector2i #distance from the camera to the top left corner of the chunk it is in

"""---WORLD IMAGES---"""
"""
worldVisualImage:
	the actualy image that the user sees on the screen. This is the output of the generateTextureChunk shader
"""
var worldVisualImageForegroundRID : RID
var worldVisualImageBackgroundRID : RID

"""
worldNormalImage:
	the image that normals are writen to as an output of generateTextureChunk shader.
	Alpha channel stores specular
"""
var worldNormalImageForegroundRID : RID
var worldNormalImageBackgroundRID : RID

"""
worldCustomImage:
	Stores unique properties for custom post processing for certain pixels.
	Example: Pixels that reflect the screen texture
"""
var worldCustomImageForegroundRID : RID
var worldCustomImageBackgroundRID : RID

"""---LIGHTING IMAGES---"""
"""
Light Map:
	This is a image that stores all blocks's emission color.
	For blocks that want to block light and cast shadows, thier emission color should be (0.0, 0.0, 0.0, 1.0)
	For blocks that want dont want to block light, thier emission color should be (0.0, 0.0, 0.0, 0.0)
"""
var finalLightImageRID : RID
var lightMapRID : RID

"""
Light Buffer:
	A subviewport that renders only emisive materials in the scene.
	Each frame, this is combined with the lightmap before lighting calculations are done
"""
var lightBuffer : CustomBuffer
var lightBufferRID : RID
var additiveBlendShaderFile
var additiveBlendShader
var additiveBlendPipeline

"""
Reflection Buffer:
	A subviewport that renders all things that will be reflected by the terrain.
"""
var reflectionBuffer : CustomBuffer


var spriteForeground : Sprite2D
var spriteBackground : Sprite2D

@onready var foregroundTextureData : TextureData = load(PixelSandbox.textureDataForeground)
@onready var backgroundTextureData : TextureData = load(PixelSandbox.textureDataBackground)

var textureUniforms : Array[RDUniform]
var bufferUniforms : Array[RDUniform]
var textureUniformSet : RID
var buffferUniformSet : RID

var renDev : RenderingDevice
var textureChunkShaderFile
var textureChunkShader
var persPipeline : RID

#Constants
const TERRAIN_IMAGE_FORMAT : int = Image.FORMAT_RGBA8
const LIGHTING_IMAGE_FORMAT = Image.FORMAT_RGBAH #RGBA16f

#returns an image of the specified size filled with the specified material
func generateSampleImage(tile : int, size : Vector2i) -> Image:
	var im : Image = Image.create_empty(size.x, size.y, false, TERRAIN_IMAGE_FORMAT)
	im.fill(Color(float(tile) / float(PixelSandbox.tilesInGame - 1), 0.0, 0.0, 1.0))
	return im

func constructTextureArrays():
	###---------TEXTURES---------###
	#Create a default sampler
	var samplerState := RDSamplerState.new()
	samplerState.mag_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	samplerState.min_filter = RenderingDevice.SAMPLER_FILTER_NEAREST
	samplerState.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_REPEAT
	samplerState.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_REPEAT
	samplerState.repeat_w = RenderingDevice.SAMPLER_REPEAT_MODE_REPEAT
	samplerState.compare_op = RenderingDevice.COMPARE_OP_NEVER
	var defaultSampler := renDev.sampler_create(samplerState)
	
	#Foreground
	var tex2dArray : Texture2DArray = foregroundTextureData.getTextureArray()
	var normal2dArray : Texture2DArray = foregroundTextureData.getNormalArray()
	var gradient2dArray : Texture2DArray = foregroundTextureData.getGradientArray()
	var borderGradient2dArray : Texture2DArray = foregroundTextureData.getBorderGradientArray()
	var borderColors := foregroundTextureData.getBorderTexture()
	var emissionColors := foregroundTextureData.getLightEmissionTexture()
	
	
	var samplerUniformType = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	
	var u : RDUniform
	
	u = RDUniform.new()
	u.binding = 0
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	u.add_id(defaultSampler)
	u.add_id(getRIDImage2DArray(tex2dArray, renDev))
	textureUniforms.append(u)
	
	u = RDUniform.new()
	u.binding = 1
	u.uniform_type = samplerUniformType
	u.add_id(defaultSampler)
	u.add_id(getRIDImage2DArray(normal2dArray, renDev))
	textureUniforms.append(u)
	
	u = RDUniform.new()
	u.binding = 2
	u.uniform_type = samplerUniformType
	u.add_id(defaultSampler)
	u.add_id(getRIDImage2DArray(gradient2dArray, renDev))
	textureUniforms.append(u)
	
	u = RDUniform.new()
	u.binding = 3
	u.uniform_type = samplerUniformType
	u.add_id(defaultSampler)
	u.add_id(getRIDImage2DArray(borderGradient2dArray, renDev))
	textureUniforms.append(u)
	
	u = RDUniform.new()
	u.binding = 4
	u.uniform_type = samplerUniformType
	u.add_id(defaultSampler)
	u.add_id(getRIDImage(borderColors, renDev))
	textureUniforms.append(u)
	
	u = RDUniform.new()
	u.binding = 5
	u.uniform_type = samplerUniformType
	u.add_id(defaultSampler)
	u.add_id(getRIDImage(emissionColors, renDev))
	textureUniforms.append(u)
	
	
	#Background
	tex2dArray = backgroundTextureData.getTextureArray()
	normal2dArray = backgroundTextureData.getNormalArray()
	gradient2dArray = backgroundTextureData.getGradientArray()
	borderGradient2dArray = backgroundTextureData.getBorderGradientArray()
	borderColors = backgroundTextureData.getBorderTexture()
	emissionColors = backgroundTextureData.getLightEmissionTexture()
	
	u = RDUniform.new()
	u.binding = 6
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	u.add_id(defaultSampler)
	u.add_id(getRIDImage2DArray(tex2dArray, renDev))
	textureUniforms.append(u)
	
	u = RDUniform.new()
	u.binding = 7
	u.uniform_type = samplerUniformType
	u.add_id(defaultSampler)
	u.add_id(getRIDImage2DArray(normal2dArray, renDev))
	textureUniforms.append(u)
	
	u = RDUniform.new()
	u.binding = 8
	u.uniform_type = samplerUniformType
	u.add_id(defaultSampler)
	u.add_id(getRIDImage2DArray(gradient2dArray, renDev))
	textureUniforms.append(u)
	
	u = RDUniform.new()
	u.binding = 9
	u.uniform_type = samplerUniformType
	u.add_id(defaultSampler)
	u.add_id(getRIDImage2DArray(borderGradient2dArray, renDev))
	textureUniforms.append(u)
	
	u = RDUniform.new()
	u.binding = 10
	u.uniform_type = samplerUniformType
	u.add_id(defaultSampler)
	u.add_id(getRIDImage(borderColors, renDev))
	textureUniforms.append(u)
	
	u = RDUniform.new()
	u.binding = 11
	u.uniform_type = samplerUniformType
	u.add_id(defaultSampler)
	u.add_id(getRIDImage(emissionColors, renDev))
	textureUniforms.append(u)
	
	textureUniformSet = renDev.uniform_set_create(textureUniforms, textureChunkShader, 0)
	
	
	###---------ARRAYS---------###
	
	var foregroundBorderParams : PackedVector2Array = foregroundTextureData.getBorderParamArray()
	var backgroundBorderParams : PackedVector2Array = backgroundTextureData.getBorderParamArray()
	var solidArray : PackedInt32Array = foregroundTextureData.getSolidArray()
	var foregroundReflectivenessArray : PackedFloat32Array = foregroundTextureData.getReflectivenessArray()
	var backgroundReflectivenessArray : PackedFloat32Array = backgroundTextureData.getReflectivenessArray()
	
	
	var borderParamsBufferForeground : RID = renDev.storage_buffer_create(foregroundBorderParams.size() * 8, foregroundBorderParams.to_byte_array())
	var borderParamsBufferBackground : RID = renDev.storage_buffer_create(backgroundBorderParams.size() * 8, backgroundBorderParams.to_byte_array())
	var solidBuffer : RID = renDev.storage_buffer_create(solidArray.size() * 4, solidArray.to_byte_array())
	var foregroundReflectivenessArrayBuffer : RID = renDev.storage_buffer_create(
		foregroundReflectivenessArray.size() * 4,
		foregroundReflectivenessArray.to_byte_array()
	)
	var backgroundReflectivenessArrayBuffer : RID = renDev.storage_buffer_create(
		backgroundReflectivenessArray.size() * 4,
		backgroundReflectivenessArray.to_byte_array()
	)
	
	
	var buffers: Array[RID] = [
		borderParamsBufferForeground,
		borderParamsBufferBackground,
		solidBuffer,
		foregroundReflectivenessArrayBuffer,
		backgroundReflectivenessArrayBuffer
	]
	for i in range(5):
		u = RDUniform.new()
		u.binding = i
		u.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
		u.add_id(buffers[i])
		bufferUniforms.append(u)
	
	buffferUniformSet = renDev.uniform_set_create(bufferUniforms, textureChunkShader, 1)


func _ready() -> void:
	setupPipeline()

func setupPipeline():
	#Setup pipeline for calculate Enviermental Textures
	renDev = RenderingServer.get_rendering_device()
	#Texture Chunk Shader Settup
	textureChunkShaderFile = load("uid://dvrxg8j3h7sl")
	textureChunkShader = renDev.shader_create_from_spirv(textureChunkShaderFile.get_spirv())
	persPipeline = renDev.compute_pipeline_create(textureChunkShader)
	#Additive Blend Shader Settup (for merging the lightmap and lightbuffer)
	additiveBlendShaderFile = load("uid://b2l1ub01t6vsa")
	additiveBlendShader = renDev.shader_create_from_spirv(additiveBlendShaderFile.get_spirv())
	additiveBlendPipeline = renDev.compute_pipeline_create(additiveBlendShader)
	
	setupEnviromentObjects()
	constructTextureArrays()
	
	#setup lightmap SDF
	var image = Image.create_empty(PixelSandbox.renderSectionSize, PixelSandbox.renderSectionSize, false, Image.FORMAT_RGBAF);
	image.fill(Color.BLACK)
	lightmapSDF = getRIDImage(image, renDev)
	
	#Connect to Terrain Server's dirty chunk signal
	TerrainServer.dirtyChunkBroadcast.connect(reRenderChunks)

func _process(_delta: float) -> void:
	#Dont update if you are a server or not connected to a server
	if ClientNetworkGlobals.id == -1: return
	
	updateTileTextureScrollAndSpritePosition()
	
	if is_instance_valid(sdfGen) and is_instance_valid(radCasc):
		sdfGen.createSDF(finalLightImageRID, lightmapSDF, 0.0, true)
		
	#Combine the LightBuffer with the lightMapRID
	if is_instance_valid(lightBuffer) and lightBufferRID.is_valid():
		executeAdditiveBlendShader(lightMapRID, lightBufferRID, finalLightImageRID)
		radCasc.updateGlobalIllumination()
	
	if Input.is_action_just_pressed("ReloadTexture"):
		constructTextureArrays()

func setupEnviromentObjects() -> void:
	"""Create an image on the GPU for each of the world images"""
	#Difuse:
	worldVisualImageForegroundRID = createAndGetImageRID(
		PixelSandbox.renderSectionSize,
		TERRAIN_IMAGE_FORMAT
	)
	worldVisualImageBackgroundRID = createAndGetImageRID(
		PixelSandbox.renderSectionSize,
		TERRAIN_IMAGE_FORMAT
	)
	
	#Normal:
	worldNormalImageForegroundRID = createAndGetImageRID(
		PixelSandbox.renderSectionSize,
		TERRAIN_IMAGE_FORMAT
	)
	worldNormalImageBackgroundRID = createAndGetImageRID(
		PixelSandbox.renderSectionSize,
		TERRAIN_IMAGE_FORMAT
	)
	
	#Custom:
	worldCustomImageForegroundRID = createAndGetImageRID(
		PixelSandbox.renderSectionSize,
		LIGHTING_IMAGE_FORMAT
	)
	worldCustomImageBackgroundRID = createAndGetImageRID(
		PixelSandbox.renderSectionSize,
		LIGHTING_IMAGE_FORMAT
	)
	
	#Output of Generate Texture Chunk shader
	lightMapRID = createAndGetImageRID(
		PixelSandbox.renderSectionSize,
		LIGHTING_IMAGE_FORMAT
	)
	#Image that is sent to the lighting shader. Combination of the Light Buffer and the Lightmap
	finalLightImageRID = createAndGetImageRID(
		PixelSandbox.renderSectionSize,
		LIGHTING_IMAGE_FORMAT
	)


func reRenderChunks(dirtyChunks : Array[WorldChunk]):
	#Dont update if you are a server or not connected to a server
	if ClientNetworkGlobals.id == -1: return
	
	for c in dirtyChunks:
		#Approach: create the image from data based on your chunk and the sourounding 8 chunks
		var chunkImage : Image = Image.create_empty(c.chunkSize * 3, c.chunkSize * 3, false, TERRAIN_IMAGE_FORMAT)
		for i in range(-1, 2): #get chunk -1 to 1
			for j in range(-1, 2):
				var d : PackedByteArray = TerrainServer.getChunkTileData(c.chunkCoord + Vector2i(i, j))
				var im : Image = Image.create_from_data(c.chunkSize, c.chunkSize, false, TERRAIN_IMAGE_FORMAT, d)
				chunkImage.blit_rect(im, Rect2i(0, 0, c.chunkSize, c.chunkSize), Vector2i(i + 1, j + 1) * c.chunkSize)
		
		executeTextureChunkShader(c.chunkCoord, chunkImage)


func updateTileTextureScrollAndSpritePosition() -> void:
	if !is_instance_valid(get_viewport().get_camera_2d()):
		return
	cameraPosition = get_viewport().get_camera_2d().get_screen_center_position()
	cameraChunkPixelProgress = Vector2i(cameraPosition) % PixelSandbox.chunkSize
	var centerChunk := TerrainServer.worldToChunk(cameraPosition)
	
	var scroll : Vector2 = Vector2.ZERO
	scroll = Vector2(centerChunk * PixelSandbox.chunkSize) / float(PixelSandbox.renderSectionSize)
	textureWrapCount = scroll - Vector2(0.5, 0.5)
	textureWrapPixelOffset = Vector2i(textureWrapCount * PixelSandbox.renderSectionSize) % PixelSandbox.renderSectionSize
	
	RenderingServer.global_shader_parameter_set("PS_TILE_TEXTURE_SCROLL", textureWrapCount)
	
	var cPos : Vector2 = (centerChunk - (Vector2i(PixelSandbox.renderSectionSize / PixelSandbox.chunkSize, PixelSandbox.renderSectionSize / PixelSandbox.chunkSize) / 2)) * PixelSandbox.chunkSize
	RenderingServer.global_shader_parameter_set("PS_TOP_LEFT_CHUNK_POSITION", cPos)
	
	RenderingServer.global_shader_parameter_set("PS_SCREEN_SIZE", get_viewport().get_visible_rect().size / get_viewport().get_camera_2d().zoom)
	
	#Set this property in the camera or else its a frame behind
	#RenderingServer.global_shader_parameter_set("PS_CAMERA_POSITION", cameraPos)
	
	if is_instance_valid(spriteForeground):
		spriteForeground.global_position = (scroll * float(PixelSandbox.renderSectionSize))
	if is_instance_valid(spriteBackground):
		spriteBackground.global_position = (scroll * float(PixelSandbox.renderSectionSize))
	

#Recives a section of the worldDataImage and updates the visual output based on that info
func executeTextureChunkShader(chunkCoord : Vector2i, tileImage : Image):
	#Chunk Data Setup
	var chunkData := PackedInt32Array([chunkCoord.x, chunkCoord.y, PixelSandbox.chunkSize, PixelSandbox.chunkSize])
	var chunkDataRID : RID = getRIDStorageBufferInt(chunkData, renDev)
	var chunkDataUniform : RDUniform = getUniformStorageBufferInt(chunkDataRID, 0)
	
	#TileImage Setup
	var tileImageRID : RID = getRIDImage(tileImage, renDev)
	var tileImageUniform : RDUniform = getUniformImage(tileImageRID, 1)
	
	#Output Buffer Setup
	var outputForeground : RDUniform = getUniformImage(worldVisualImageForegroundRID, 2)
	var outputBackground : RDUniform = getUniformImage(worldVisualImageBackgroundRID, 3)
	var lightMap : RDUniform = getUniformImage(lightMapRID, 4)
	var outputNormalForeground : RDUniform = getUniformImage(worldNormalImageForegroundRID, 5)
	var outputNormalBackground : RDUniform = getUniformImage(worldNormalImageBackgroundRID, 6)
	var outputCustomForeground : RDUniform = getUniformImage(worldCustomImageForegroundRID, 7)
	var outputCustomBackground : RDUniform = getUniformImage(worldCustomImageBackgroundRID, 8)
	
	
	var uniformSet : RID = renDev.uniform_set_create([
		chunkDataUniform,
		tileImageUniform,
		outputForeground,
		outputBackground,
		lightMap,
		outputNormalForeground,
		outputNormalBackground,
		outputCustomForeground,
		outputCustomBackground
	], textureChunkShader, 2)
	
	var computeList: int = renDev.compute_list_begin()
	
	var w : int = int(ceil(float(PixelSandbox.chunkSize) / 8.0))
	var workgroups := Vector3i(int(w), int(w), 1)
	
	
	executeComputeShader(
		workgroups,
		renDev,
		computeList,
		persPipeline,
		[textureUniformSet, buffferUniformSet, uniformSet]
	)
	
	renDev.free_rid(chunkDataRID)
	renDev.free_rid(tileImageRID)

func executeAdditiveBlendShader(source1 : RID, source2 : RID, dest : RID):
	var source1ImageUniform : RDUniform = getUniformImage(source1, 0)
	var source2ImageUniform : RDUniform = getUniformImage(source2, 1)
	var destImageUniform : RDUniform = getUniformImage(dest, 2)
	
	var cam : Camera2D = get_viewport().get_camera_2d()
	if !is_instance_valid(cam):
		return
	var camPos : Vector2i = Vector2i(round(
		cam.get_screen_center_position())
	) - Vector2i(
		PixelSandbox.renderSectionSize / 2,
		PixelSandbox.renderSectionSize / 2
	)
	
	var sb : RID = getRIDStorageBufferInt([camPos.x, camPos.y,
	 textureWrapPixelOffset.x, textureWrapPixelOffset.y], renDev)
	var sbUniform : RDUniform = getUniformStorageBufferInt(sb, 3)
	var uniformSet : RID = renDev.uniform_set_create([source1ImageUniform, source2ImageUniform, destImageUniform, sbUniform], additiveBlendShader, 0)
	
	var computeList: int = renDev.compute_list_begin()
	
	var w : int = int(ceil(float(PixelSandbox.renderSectionSize) / 32.0))
	var workgroups := Vector3i(int(w), int(w), 1)
	
	executeComputeShader(workgroups, renDev, computeList, additiveBlendPipeline, [uniformSet])
	
	renDev.free_rid(sb)

#A version of executeTextureChunkShader for blueprints that writes to a seperate output buffer instead of the main visual immage
func calculateEnviermentalTexture(calculateRect : Rect2i, tileImage : Image, outlineSize : int) -> Array[RID]:
	var rectSize := calculateRect.size
	var maxDimention : int = max(rectSize.x, rectSize.y)
	var centerOffset := -(rectSize - Vector2i(maxDimention, maxDimention))
	centerOffset = centerOffset / 2
	#Chunk Data Setup
	var chunkData := PackedInt32Array([centerOffset.x, centerOffset.y, 1, outlineSize])
	var chunkDataRID : RID = getRIDStorageBufferInt(chunkData, renDev)
	var chunkDataUniform := getUniformStorageBufferInt(chunkDataRID, 0)
	
	#TileImage Setup
	var tileImageRID : RID = getRIDImage(tileImage, renDev)
	var tileImageUniform : RDUniform = getUniformImage(tileImageRID, 1)
	
	#Output Buffer Setup
	var outputImageForeground : Image = Image.create_empty(maxDimention, maxDimention, false, TERRAIN_IMAGE_FORMAT)
	outputImageForeground.fill(Color.BLACK)
	var outputImageForegroundRID : RID = getRIDImage(outputImageForeground, renDev)
	var outputUniformForeground := getUniformImage(outputImageForegroundRID, 2)
	
	var outputImageBackground: Image = Image.create_empty(maxDimention, maxDimention, false, TERRAIN_IMAGE_FORMAT)
	outputImageBackground.fill(Color.BLACK)
	var outputImageBackgroundRID : RID = getRIDImage(outputImageBackground, renDev)
	var outputUniformBackground := getUniformImage(outputImageBackgroundRID, 3)
	
	#Blueprints dont use lightmaps or normals... for now... and probabbly never. Writint a seperate shader for the blueprints would probably be a good idea
	var dummyLightmap: Image = Image.create_empty(maxDimention, maxDimention, false, LIGHTING_IMAGE_FORMAT)
	dummyLightmap.fill(Color.BLACK)
	var dummyLightmapRID : RID = getRIDImage(dummyLightmap, renDev)
	var dummyLightmapUniform := getUniformImage(dummyLightmapRID, 4)
	
	var dummyNormal1 := getUniformImage(dummyLightmapRID, 5)
	var dummyNormal2 := getUniformImage(dummyLightmapRID, 6)
	var dummyCustom1 := getUniformImage(dummyLightmapRID, 7)
	var dummyCustom2 := getUniformImage(dummyLightmapRID, 8)
	
	var uniformSet := renDev.uniform_set_create([chunkDataUniform, tileImageUniform, outputUniformForeground, outputUniformBackground, dummyLightmapUniform, dummyNormal1, dummyNormal2, dummyCustom1, dummyCustom2], textureChunkShader, 2)
	var computeList: int = renDev.compute_list_begin()
	
	var w : int = int(ceil(float(PixelSandbox.chunkSize) / 8.0))
	var workgroups := Vector3i(int(w), int(w), 1)
	executeComputeShader(workgroups, renDev, computeList, persPipeline, [textureUniformSet, buffferUniformSet, uniformSet])
	
	renDev.free_rid(chunkDataRID)
	renDev.free_rid(tileImageRID)
	renDev.free_rid(dummyLightmapRID)
	
	return [outputImageForegroundRID, outputImageBackgroundRID]


"""--- Compute Shader Boilerplate functions ---"""
func createAndGetImageRID(size : int, imageFormat : int) -> RID:
	var im = Image.create_empty(size, size, false, imageFormat);
	im.fill(Color(0.0, 0.0, 0.0, 0.0))
	return getRIDImage(im, RenderingServer.get_rendering_device())
	

func executeComputeShader(workGroup : Vector3i, rd : RenderingDevice, computeList : int, pipeline : RID, uniformSetArray : Array[RID]):
	rd.compute_list_bind_compute_pipeline(computeList, pipeline)
	for i in range(len(uniformSetArray)):
		rd.compute_list_bind_uniform_set(computeList, uniformSetArray[i], i)
	rd.compute_list_dispatch(computeList, workGroup.x, workGroup.y, workGroup.z) #Work Groups
	rd.compute_list_end()

func getUniformImage(imageRID : RID, binding : int) -> RDUniform:
	var imageUniform := RDUniform.new()
	imageUniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	imageUniform.binding = binding
	imageUniform.add_id(imageRID)
	return imageUniform

func getUniformSampler(imageRID : RID, samplerRID : RID, binding : int):
	var samplerUniform := RDUniform.new()
	samplerUniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	samplerUniform.binding = binding
	samplerUniform.add_id(samplerRID)
	samplerUniform.add_id(imageRID)
	
	return samplerUniform

func getUniformStorageBufferInt(dataRID : RID, binding : int) -> RDUniform:
	var storageBufferUniform := RDUniform.new()
	storageBufferUniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	storageBufferUniform.binding = binding
	storageBufferUniform.add_id(dataRID)
	return storageBufferUniform

func getUniformStorageBuffer(dataRID : RID, binding : int) -> RDUniform:
	return getUniformStorageBufferInt(dataRID, binding)

func getRIDStorageBufferInt(data : PackedInt32Array, rd : RenderingDevice) -> RID:
	var packedData := data.to_byte_array()
	var dataRID : RID = rd.storage_buffer_create(packedData.size(), packedData)
	return dataRID

func getRIDStorageBufferFloat(data : PackedFloat32Array, rd : RenderingDevice) -> RID:
	var packedData := data.to_byte_array()
	var dataRID : RID = rd.storage_buffer_create(packedData.size(), packedData)
	return dataRID

func getRIDImage(image : Image, rd : RenderingDevice) -> RID:
	var imageSize := image.get_size()
	var textureView := RDTextureView.new()
	var textureFormat := RDTextureFormat.new()
	textureFormat.width = imageSize.x
	textureFormat.height = imageSize.y
	
	# Match the format to the image's actual format
	match image.get_format():
		Image.FORMAT_RGBA8:
			textureFormat.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
		Image.FORMAT_RGBAF:
			textureFormat.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
		Image.FORMAT_RF:
			textureFormat.format = RenderingDevice.DATA_FORMAT_R32_SFLOAT
		Image.FORMAT_RGF:
			textureFormat.format = RenderingDevice.DATA_FORMAT_R32G32_SFLOAT
		Image.FORMAT_RGBF:
			textureFormat.format = RenderingDevice.DATA_FORMAT_R32G32B32_SFLOAT
		Image.FORMAT_RGBAH:
			textureFormat.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
		_:
			# Default to RGBA8
			print("WARNING: Unknown image format ", image.get_format(), ", defaulting to RGBA8")
			textureFormat.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	
	textureFormat.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT +
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT + 
		RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT + 
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	)
	var rid := rd.texture_create(textureFormat, textureView, [image.get_data()])
	return rid

func getRIDImage2DArray(imageArray : Texture2DArray, rd : RenderingDevice) -> RID:
	var textureView := RDTextureView.new()
	var textureFormat := RDTextureFormat.new()
	textureFormat.width = imageArray.get_width()
	textureFormat.height = imageArray.get_height()
	textureFormat.array_layers = imageArray.get_layers()
	
	textureFormat.texture_type = RenderingDevice.TEXTURE_TYPE_2D_ARRAY
	textureFormat.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
	
	textureFormat.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT +
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT + 
		RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT + 
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	)
	
	var imageDataArray : Array[PackedByteArray] = []
	for i in range(imageArray.get_layers()):
		var curIm : Image = imageArray.get_layer_data(i)
		imageDataArray.append(curIm.get_data())
	
	var rid := rd.texture_create(textureFormat, textureView, imageDataArray)

	return rid

#Creates a blank rgba16f 2D texture array usable as both a compute storage image and a sampler
func getRIDBlankImage2DArray(width : int, height : int, layers : int, rd : RenderingDevice) -> RID:
	var textureFormat := RDTextureFormat.new()
	textureFormat.width = width
	textureFormat.height = height
	textureFormat.array_layers = layers
	textureFormat.texture_type = RenderingDevice.TEXTURE_TYPE_2D_ARRAY
	textureFormat.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	textureFormat.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT +
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT +
		RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT +
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	)

	var blankLayer := Image.create_empty(width, height, false, LIGHTING_IMAGE_FORMAT)
	blankLayer.fill(Color.BLACK)
	var layerData : Array[PackedByteArray] = []
	for i in range(layers):
		layerData.append(blankLayer.get_data())

	return rd.texture_create(textureFormat, RDTextureView.new(), layerData)
