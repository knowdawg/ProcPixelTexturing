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

func contructTextureArrays():
	var tex2dArray := Texture2DArray.new()
	var normal2dArray := Texture2DArray.new()
	var gradient2dArray := Texture2DArray.new()
	
	var imageArray : Array[Image] = []
	var normalArray : Array[Image] = []
	var gradientArray : Array[Image] = []
	
	var borderColors : Image
	borderColors = Image.create_empty(uniqueTiles, 1, false, Image.FORMAT_RGBA8)
	
	for i in range(uniqueTiles):
		var im : Image
		im = foregroundTextureData.getTexture(i).get_image()
		im.convert(Image.FORMAT_RGBA8)
		imageArray.append(im)
		
		var norm : Image
		norm = foregroundTextureData.getNormal(i).get_image()
		norm.convert(Image.FORMAT_RGBA8)
		normalArray.append(norm)
		
		var grad : Image
		grad = foregroundTextureData.getGradient(i).get_image()
		grad.convert(Image.FORMAT_RGBA8)
		gradientArray.append(grad)
		
		borderColors.set_pixel(i, 0, foregroundTextureData.getBorder(i))
	
	tex2dArray.create_from_images(imageArray)
	normal2dArray.create_from_images(normalArray)
	gradient2dArray.create_from_images(gradientArray)
	
	var bcTex : ImageTexture = ImageTexture.create_from_image(borderColors)
	
	RenderingServer.global_shader_parameter_set("FOREGROUND_TEXTURES_SAMPLER_2D_ARRAY", tex2dArray)
	RenderingServer.global_shader_parameter_set("FOREGROUND_NORMALS_SAMPLER_2D_ARRAY", normal2dArray)
	RenderingServer.global_shader_parameter_set("FOREGROUND_GRADIENTS_SAMPLER_2D_ARRAY", gradient2dArray)
	RenderingServer.global_shader_parameter_set("FOREGROUND_BORDER_COLORS", bcTex)


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
