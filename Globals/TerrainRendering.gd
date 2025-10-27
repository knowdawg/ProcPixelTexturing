extends Node

#Imaportant RID
var envirementalDataTextureRID : RID
var backgroundDataTextureRID : RID

var foregroundSDF : RID
var backgroundSDF : RID

var worldPosition : Vector2
var tileTextureOffset : Vector2

var sunDirection : float =  - PI / 2.0
var lightrays : RID
var GI : RID

#World Details
var chunkSize : int = 32
var outlineBufferSize : int = 12 #Buffer size on each side
var renderSectionSize : int = 512
var mapSize : Vector2i = Vector2i(2048, 2048)
var loadedRect : Rect2

#Texture Details
var uniqueTiles : int = 64
var textureSize := Vector2i(256, 256)
var foregroundTextureData : TextureData = preload("uid://dmla4e53rjkn6")
var backgroundTextureData : TextureData = preload("uid://bidpxtfdflemt")

#Global Signals Related to Rendering
var enviermentDirty : bool = false
signal onEnviermentalChanged


func enviromentChanged():
	enviermentDirty = true

func contructTextureArrays():
	#Foreground
	var tex2dArray := foregroundTextureData.getTextureArray(uniqueTiles)
	var normal2dArray := foregroundTextureData.getNormalArray(uniqueTiles)
	var gradient2dArray := foregroundTextureData.getGradientArray(uniqueTiles)
	var borderColors := foregroundTextureData.getBorderTexture(uniqueTiles)
	RenderingServer.global_shader_parameter_set("FOREGROUND_TEXTURES_SAMPLER_2D_ARRAY", tex2dArray)
	RenderingServer.global_shader_parameter_set("FOREGROUND_NORMALS_SAMPLER_2D_ARRAY", normal2dArray)
	RenderingServer.global_shader_parameter_set("FOREGROUND_GRADIENTS_SAMPLER_2D_ARRAY", gradient2dArray)
	RenderingServer.global_shader_parameter_set("FOREGROUND_BORDER_COLORS", borderColors)
	
	#Background
	tex2dArray = backgroundTextureData.getTextureArray(uniqueTiles)
	normal2dArray = backgroundTextureData.getNormalArray(uniqueTiles)
	gradient2dArray = backgroundTextureData.getGradientArray(uniqueTiles)
	borderColors = backgroundTextureData.getBorderTexture(uniqueTiles)
	RenderingServer.global_shader_parameter_set("BACKGROUND_TEXTURES_SAMPLER_2D_ARRAY", tex2dArray)
	RenderingServer.global_shader_parameter_set("BACKGROUND_NORMALS_SAMPLER_2D_ARRAY", normal2dArray)
	RenderingServer.global_shader_parameter_set("BACKGROUND_GRADIENTS_SAMPLER_2D_ARRAY", gradient2dArray)
	RenderingServer.global_shader_parameter_set("BACKGROUND_BORDER_COLORS", borderColors)
	

func isPositionLoaded(pos : Vector2) -> bool:
	if !loadedRect:
		return false
	if pos.x > loadedRect.position.x and pos.y > loadedRect.position.y:
		if pos.x < loadedRect.position.x + loadedRect.size.x and pos.y < loadedRect.position.y + loadedRect.size.y:
			return true
	return false

func _ready() -> void:
	RenderingServer.global_shader_parameter_set("RENDER_QUADRANT_SIZE", Vector2(renderSectionSize, renderSectionSize))
	contructTextureArrays()
	
	#Setup pipeline for calculate Enviermental Textures
	renDev = RenderingServer.get_rendering_device()
	textureChunkShaderFile = load("uid://dvrxg8j3h7sl")
	textureChunkShader = renDev.shader_create_from_spirv(textureChunkShaderFile.get_spirv())
	persPipeline = renDev.compute_pipeline_create(textureChunkShader)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ReloadTexture"):
		contructTextureArrays()
		
	if enviermentDirty:
		enviermentDirty = false
		onEnviermentalChanged.emit()

var renDev : RenderingDevice
var textureChunkShaderFile
var textureChunkShader
var persPipeline : RID
func calculateEnviermentalTexture(calculateRect : Rect2i, tileImage : Image, outlineSize : int) -> RID:
	#var rectPos := calculateRect.position
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
	var outputImage : Image = Image.create_empty(maxDimention, maxDimention, false, Image.FORMAT_RGBAF)
	outputImage.fill(Color.BLACK)
	var outputImageRID : RID = getRIDImage(outputImage, renDev)
	var outputUniform := getUniformImage(outputImageRID, 2)
	
	var uniformSet := renDev.uniform_set_create([chunkDataUniform, tileImageUniform, outputUniform], textureChunkShader, 0)
	var computeList = renDev.compute_list_begin()
	
	var w = sqrt(float(maxDimention * maxDimention) / float(8 * 8))
	w += 1
	var workgroups := Vector3i(int(w), int(w), 1)
	executeComputeShader(workgroups, renDev, computeList, persPipeline, uniformSet)
	
	renDev.free_rid(chunkDataRID)
	renDev.free_rid(tileImageRID)
	
	return outputImageRID


func executeComputeShader(workGroup : Vector3i, rd : RenderingDevice, computeList : int, pipeline : RID, uniformSet : RID):
	rd.compute_list_bind_compute_pipeline(computeList, pipeline)
	rd.compute_list_bind_uniform_set(computeList, uniformSet, 0)
	rd.compute_list_dispatch(computeList, workGroup.x, workGroup.y, workGroup.z) #Work Groups
	rd.compute_list_end()

func getUniformImage(imageRID : RID, binding : int) -> RDUniform:
	var imageUniform := RDUniform.new()
	imageUniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	imageUniform.binding = binding
	imageUniform.add_id(imageRID)
	return imageUniform

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

func getRIDImage(image : Image, rd : RenderingDevice) -> RID: #Read only
	var imageSize := image.get_size()
	var textureView := RDTextureView.new()
	var textureFormat := RDTextureFormat.new()
	textureFormat.width = imageSize.x
	textureFormat.height = imageSize.y
	textureFormat.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	textureFormat.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT +
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT + 
		RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT + 
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	)
	var rid := rd.texture_create(textureFormat, textureView, [image.get_data()])
	return rid
