extends TileMapLayer
class_name ChunkedTilemap

@export_group("Chunk Details")
@export var chunkSize : int = 64
@export var outlineBufferSize : int = 12 #Buffer size on each side
@export var renderSectionSize : int = 512

@export_group("Tilemap Details")
@export var numOfTileIndexes : int = 10

var chunks : Array = []
var dirtyChunks : Array[TextureChunk] = []
var chunk = preload("res://TextureChunking/texture_chunk.tscn")

var dirty : bool = false
var combinedImage : Image

func isChunkInBounds(chunkCoord):
	if chunkCoord.x >= 0 and chunkCoord.x < chunks.size() and chunkCoord.y >= 0 and chunkCoord.y < chunks[0].size():
		return true
	return false

func addTile(pos : Vector2, tileIndex : int):
	dirty = true
	set_cell(pos, tileIndex, Vector2i(0, 0), 0)
	
	#Dirty the chunk with the tile
	var chunkPos : Vector2i = pos / float(chunkSize)
	var chunkCoord : Vector2i = floor(chunkPos)
	if isChunkInBounds(chunkCoord):
		chunks[chunkCoord.x][chunkCoord.y].makeDirty()
	else:
		return
	
	
	#Dirty adjacent chunks if you are close enough to the border
	var chunkToOutlineRatio = float(outlineBufferSize) / float(chunkSize)
	var fract : Vector2 = chunkPos - floor(chunkPos)
	if fract.x < chunkToOutlineRatio:
		if isChunkInBounds(chunkCoord + Vector2i(-1, 0)):
			chunks[chunkCoord.x - 1][chunkCoord.y].makeDirty()
	if fract.x + chunkToOutlineRatio >= 1.0:
		if isChunkInBounds(chunkCoord + Vector2i(1, 0)):
			chunks[chunkCoord.x + 1][chunkCoord.y].makeDirty()
	if fract.y < chunkToOutlineRatio:
		if isChunkInBounds(chunkCoord + Vector2i(0, -1)):
			chunks[chunkCoord.x][chunkCoord.y - 1].makeDirty()
	if fract.y + chunkToOutlineRatio >= 1.0:
		if isChunkInBounds(chunkCoord + Vector2i(0, 1)):
			chunks[chunkCoord.x][chunkCoord.y + 1].makeDirty()

func addTileRadius(pos : Vector2, tileIndex : int, radius : int):
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			var offset = Vector2(x, y)
			if offset.length() <= radius + 0.5:
				var p = pos + offset
				addTile(p, tileIndex)

func _ready() -> void:
	setupRenderingDevice()
	
	combinedImage = Image.create_empty(512, 512, false, Image.FORMAT_BPTC_RGBA)
	combinedImage.decompress()
	
	var numOfChunks : Vector2 = ceil(Vector2(get_used_rect().size) / float(chunkSize))
	
	for x in numOfChunks.x:
		chunks.append([])
		for y in numOfChunks.y:
			var c : TextureChunk = chunk.instantiate()
			chunks[x].append(c)
			dirtyChunks.append(c)
			add_child(c)
			c.setup(chunkSize, outlineBufferSize, self, Vector2(x,y))

func _process(_delta: float) -> void:
	for x in chunks:
		for c : TextureChunk in x:
			c.updateChunk()
	
	#Wait for all required chunks to update
	#await get_tree().process_frame
	
	if dirty:
		#updateCombinedTexture()
		dirty = false
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var pos : Vector2 = local_to_map(get_global_mouse_position())
		addTileRadius(pos, 0, 6)
		
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var pos : Vector2 = local_to_map(get_global_mouse_position())
		addTileRadius(pos, -1, 6)

func updateChunks() -> void:
	for x in chunks:
		for c : TextureChunk in x:
			c.updateChunk()

func updateCombinedTexture():
	for c in dirtyChunks:
		var i : Image = c.getBuffer()
		combinedImage.blit_rect(i, Rect2i(0, 0, chunkSize, chunkSize), chunkSize * c.chunkCoord)
	dirtyChunks.clear()
	
	var tex : ImageTexture = ImageTexture.create_from_image(combinedImage)
	$ForegroundTexture.material.set_shader_parameter("TILE_ARRAY_TEXTURE", tex)

func getArrayTexture(coord : Vector2i) -> Image:
	var offset = (coord * chunkSize) - Vector2i(outlineBufferSize, outlineBufferSize)
	var chunkTotalSize = chunkSize + ((outlineBufferSize) * 2)
	var tileArrayTex = Image.create_empty(chunkTotalSize, chunkTotalSize, false, Image.FORMAT_RGBAF)
	tileArrayTex.decompress()
	
	var index;
	for x in range(chunkTotalSize):
		for y in range(chunkTotalSize):
			index = get_cell_source_id(Vector2i(x, y) + offset)
			
			if index == -1:
				tileArrayTex.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
			else:
				tileArrayTex.set_pixelv(Vector2i(x, y), Color((index + 1.0) * (1.0 / float(numOfTileIndexes)), 0.0, 0.0, 1.0))
	return tileArrayTex
	#
	#var im : ImageTexture = ImageTexture.create_from_image(tileArrayTex)
	#return im

#RenderingDevice Vars DONT FORGET TO FREE RIDs
var rd : RenderingDevice
var textureChunkShaderFile
var textureChunkShader
var pipeline : RID
var enviermentalDataTextureRID : RID
func setupRenderingDevice():
	rd = RenderingServer.get_rendering_device()
	
	textureChunkShaderFile = load("res://TextureChunking/GenerateTextureChunk.glsl")
	textureChunkShader = rd.shader_create_from_spirv(textureChunkShaderFile.get_spirv())
	pipeline = rd.compute_pipeline_create(textureChunkShader)
	
	var image = Image.create_empty(renderSectionSize, renderSectionSize, false, Image.FORMAT_RGBAF);
	image.fill(Color.BLACK)
	var textureView := RDTextureView.new()
	var textureFormat := RDTextureFormat.new()
	textureFormat.width = renderSectionSize
	textureFormat.height = renderSectionSize
	textureFormat.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	textureFormat.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT +
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT + 
		RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT + 
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	)
	enviermentalDataTextureRID = rd.texture_create(textureFormat, textureView, [image.get_data()])
	
	var tex2DRD : Texture2DRD = Texture2DRD.new()
	tex2DRD.set_texture_rd_rid(enviermentalDataTextureRID)
	$ForegroundTexture.texture = tex2DRD
	$Sprite2D.texture = tex2DRD
	
	

func executeTextureChunkShader(chunkCoord : Vector2i, tileImage : Image):
	#Chunk Data Setup
	print(chunkCoord)
	var chunkData := PackedFloat32Array([chunkCoord.x, chunkCoord.y, chunkSize, outlineBufferSize]).to_byte_array()
	var chunkDataRID : RID = rd.storage_buffer_create(chunkData.size(), chunkData)
	var chunkDataUniform := RDUniform.new()
	chunkDataUniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	chunkDataUniform.binding = 0
	chunkDataUniform.add_id(chunkDataRID)
	
	#TileImage Setup
	var tileImageRID : RID = getRIDImage(tileImage)
	var tileImageUniform := RDUniform.new()
	tileImageUniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	tileImageUniform.binding = 1
	tileImageUniform.add_id(tileImageRID)
	
	#Output Buffer Setup
	var outputUniform := RDUniform.new()
	outputUniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	outputUniform.binding = 2
	outputUniform.add_id(enviermentalDataTextureRID)
	
	
	var uniformSet := rd.uniform_set_create([chunkDataUniform, tileImageUniform, outputUniform], textureChunkShader, 0)
	var computeList = rd.compute_list_begin()
	
	rd.compute_list_bind_compute_pipeline(computeList, pipeline)
	rd.compute_list_bind_uniform_set(computeList, uniformSet, 0)
	rd.compute_list_dispatch(computeList, 8, 8, 1) #Work Groups
	rd.compute_list_end()
	
	rd.free_rid(chunkDataRID)
	rd.free_rid(tileImageRID)
	
	print(chunkCoord)
	
	#var imageData := rd.texture_get_data(enviermentalDataTextureRID, 0)
	#var outputImage := Image.create_from_data(renderSectionSize, renderSectionSize, false, Image.FORMAT_RGBAF, imageData)
	#$Sprite2D.texture = ImageTexture.create_from_image(outputImage)
	#
	#rd.texture_get_data_async(enviermentalDataTextureRID, 0, getDataAsycn)

#func getDataAsycn(data):
	#var outputImage := Image.create_from_data(renderSectionSize, renderSectionSize, false, Image.FORMAT_RGBAF, data)
	#if !outputImage:
		#print("uh oh")
	#$Sprite2D.texture = ImageTexture.create_from_image(outputImage)

func getRIDImage(image : Image) -> RID: #Read only
	var imageSize := image.get_size()
	
	var textureView := RDTextureView.new()
	var textureFormat := RDTextureFormat.new()
	textureFormat.width = imageSize.x
	textureFormat.height = imageSize.y
	textureFormat.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	textureFormat.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT + 
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
	)
	var rid := rd.texture_create(textureFormat, textureView, [image.get_data()])
	return rid



func exampleCompute():
	rd = RenderingServer.get_rendering_device()
	
	var shaderFile := preload("res://TextureChunking/ComputerTest.glsl")
	var shader := rd.shader_create_from_spirv(shaderFile.get_spirv())
	var pl := rd.compute_pipeline_create(shader)
	
	var inputData := PackedFloat32Array([0.1, 0.5, 1.0, 1.5, 2.0]).to_byte_array()
	var storageBuffer := rd.storage_buffer_create(inputData.size(), inputData)
	
	
	
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform.binding = 0 # this needs to match the "binding" in our shader file
	uniform.add_id(storageBuffer)
	
	var uniformSet := rd.uniform_set_create([uniform], shader, 0)
	var computeList = rd.compute_list_begin()
	
	rd.compute_list_bind_compute_pipeline(computeList, pl)
	rd.compute_list_bind_uniform_set(computeList, uniformSet, 0)
	rd.compute_list_dispatch(computeList, 5, 1, 1) #Work Groups
	rd.compute_list_end()
	
	#rd.submit()
	#rd.sync() #Wait for the shader to finish
	
	var outputBytes := rd.buffer_get_data(storageBuffer)
	var output := outputBytes.to_float32_array()
	print("Input: ", inputData.to_float32_array())
	print("Output: ", output)
	
