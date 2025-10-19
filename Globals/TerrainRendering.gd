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

#World Details
var chunkSize : int = 64
var outlineBufferSize : int = 12 #Buffer size on each side
var renderSectionSize : int = 512
var mapSize : Vector2i = Vector2i(2048, 2048)
var uniqueTiles : int = 10


func _process(_delta: float) -> void:
	if worldPosition:
		RenderingServer.global_shader_parameter_set("WORLD_POSITION", worldPosition)
	
	if foregroundSDF:
		var t = Texture2DRD.new()
		t.texture_rd_rid = foregroundSDF
		RenderingServer.global_shader_parameter_set("FOREGROUND_SDF", t)

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
