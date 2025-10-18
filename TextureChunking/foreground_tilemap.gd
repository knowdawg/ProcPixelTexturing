extends TileMapLayer
class_name ChunkedTilemap

@export_group("Chunk Details")
@export var chunkSize : int = 64
@export var outlineBufferSize : int = 12 #Buffer size on each side
@export var renderSectionSize : int = 512
@export var mapSize : Vector2i = Vector2i(512, 512)

@export_group("Tilemap Details")
@export var numOfTileIndexes : int = 10

@export_group("External Nodes")
@export var forgroundTexture : Sprite2D
@export var miniMap : Sprite2D

var chunks : Array = []
var activeChunks : Array[TextureChunk] = []
var dirtyChunks : Array[TextureChunk] = []
var chunk = preload("res://TextureChunking/texture_chunk.tscn")

var dirty : bool = false
var mapImage : Image

func isChunkInBounds(chunkCoord):
	if chunkCoord.x >= 0 and chunkCoord.x < chunks.size() and chunkCoord.y >= 0 and chunkCoord.y < chunks[0].size():
		return true
	return false

func addTile(pos : Vector2, tileIndex : int):
	dirty = true
	var tilePos : Vector2i = local_to_map(pos)
	set_cell(tilePos, tileIndex, Vector2i(0, 0), 0)
	
	var pixelPos := tilePos
	var index = get_cell_source_id(tilePos)
	setPixel(pixelPos, index)
	
	#$Sprite2D2.texture = ImageTexture.create_from_image(tileMapImage)
	
	#Dirty the chunk with the tile
	var chunkPos : Vector2 = (Vector2(tilePos)) / float(chunkSize)
	var chunkCoord : Vector2i = floor(chunkPos)
	if isChunkInBounds(chunkCoord):
		chunks[chunkCoord.x][chunkCoord.y].makeDirty()
	else:
		return
	
	
	#Dirty adjacent chunks if you are close enough to the border
	var chunkToOutlineRatio = float(outlineBufferSize) / float(chunkSize)
	var fract : Vector2 = chunkPos - floor(chunkPos)
	
	var updateLeft : bool = (fract.x < chunkToOutlineRatio) and isChunkInBounds(chunkCoord + Vector2i(-1, 0))
	var updateRight : bool = (fract.x + chunkToOutlineRatio >= 1.0) and isChunkInBounds(chunkCoord + Vector2i(1, 0))
	var updateUp : bool = (fract.y < chunkToOutlineRatio) and isChunkInBounds(chunkCoord + Vector2i(0, -1))
	var updateDown : bool = (fract.y + chunkToOutlineRatio >= 1.0) and isChunkInBounds(chunkCoord + Vector2i(0, 1))
	
	if updateLeft:
		chunks[chunkCoord.x - 1][chunkCoord.y].makeDirty() #Always Happening
	if updateRight:
		chunks[chunkCoord.x + 1][chunkCoord.y].makeDirty()
	if updateUp:
		chunks[chunkCoord.x][chunkCoord.y - 1].makeDirty() #Always happening
	if updateDown:
		chunks[chunkCoord.x][chunkCoord.y + 1].makeDirty()
	if updateLeft and updateUp:
		chunks[chunkCoord.x - 1][chunkCoord.y - 1].makeDirty()
	if updateLeft and updateDown:
		chunks[chunkCoord.x - 1][chunkCoord.y + 1].makeDirty()
	if updateRight and updateUp:
		chunks[chunkCoord.x + 1][chunkCoord.y - 1].makeDirty()
	if updateRight and updateDown:
		chunks[chunkCoord.x + 1][chunkCoord.y + 1].makeDirty()

func addTileRadius(pos : Vector2, tileIndex : int, radius : int):
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			var offset = Vector2(x, y)
			if offset.length() <= radius + 0.5:
				var p = pos + offset
				addTile(p, tileIndex)

func _ready() -> void:
	setupRenderingDevice()
	
	var tilemapSize : Vector2i = get_used_rect().size
	mapImage = Image.create_empty(mapSize.x, mapSize.y, false, Image.FORMAT_RGBAF)
	mapImage.fill(Color.BLACK)
	mapImage.decompress()
	
	for x in tilemapSize.x:
		for y in tilemapSize.y:
			var tileMapPos : Vector2i = Vector2i(x, y)
			var index = get_cell_source_id(tileMapPos)
			if index == -1:
				mapImage.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
			else:
				mapImage.set_pixelv(Vector2i(x, y), Color((index + 1.0) * (1.0 / float(numOfTileIndexes)), 0.0, 0.0, 1.0))
	
	var numOfChunks : Vector2 = ceil(mapSize / float(chunkSize))
	for x in numOfChunks.x:
		chunks.append([])
		for y in numOfChunks.y:
			var c : TextureChunk = chunk.instantiate()
			chunks[x].append(c)
			dirtyChunks.append(c)
			add_child(c)
			c.setup(chunkSize, outlineBufferSize, self, Vector2(x,y))

func _process(_delta: float) -> void:
	updateChunks()
	
	#Wait for all required chunks to update
	#await get_tree().process_frame
	
	if dirty:
		#updateCombinedTexture()
		dirty = false
	
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		addTileRadius(get_global_mouse_position(), 0, 6)
		
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var pos : Vector2 = local_to_map(get_global_mouse_position())
		addTileRadius(pos, -1, 6)

func updateChunks() -> void:
	if !is_instance_valid(get_viewport().get_camera_2d()):
		return
	var cameraPos := get_viewport().get_camera_2d().global_position
	var prevActiveChunks : Array[TextureChunk] = activeChunks.duplicate()
	activeChunks.clear()
	
	var centerChunk := worldToChunk(cameraPos)
	var chunkDementions : int = int(float(renderSectionSize) / float(chunkSize))
	var topLeftChunkOffset : int = int(float(chunkDementions) / 2.0)
	var worldChunkSize : Vector2i = Vector2(mapSize) / float(chunkSize)
	for x in range(chunkDementions):
		for y in range(chunkDementions):
			var cCoord : Vector2i = centerChunk + Vector2i(x - topLeftChunkOffset, y - topLeftChunkOffset)
			#Check out of bounds (for now might change later)
			if cCoord.x >= 0 and cCoord.y >= 0:
				if cCoord.x < worldChunkSize.x and cCoord.y < worldChunkSize.y:
					activeChunks.append(chunks[cCoord.x][cCoord.y])
	
	for c : TextureChunk in activeChunks:
		if !prevActiveChunks.has(c):
			c.makeDirty()
	
	for c : TextureChunk in activeChunks:
		c.updateChunk()
	
	var scroll : Vector2 = Vector2.ZERO
	scroll = Vector2(centerChunk * chunkSize) / float(renderSectionSize)
	RenderingServer.global_shader_parameter_set("TILE_TEXTURE_SCROLL", scroll)
	forgroundTexture.global_position = (scroll * float(renderSectionSize))# + (Vector2(float(renderSectionSize), float(renderSectionSize)) / 2.0)

func worldToChunk(pos : Vector2) -> Vector2i:
	var chunkCoord := Vector2i(pos) / chunkSize
	return chunkCoord

func getArrayTexture(coord : Vector2i) -> Image:
	var offset = (coord * chunkSize) - Vector2i(outlineBufferSize, outlineBufferSize)
	var chunkTotalSize = chunkSize + ((outlineBufferSize) * 2)
	var tileArrayTex = Image.create_empty(chunkTotalSize, chunkTotalSize, false, Image.FORMAT_RGBAF)
	tileArrayTex.decompress()
	
	tileArrayTex.blit_rect(mapImage, Rect2i(offset, Vector2i(chunkTotalSize, chunkTotalSize)), Vector2i.ZERO)
	
	#var index;
	#for x in range(chunkTotalSize):
		#for y in range(chunkTotalSize):
			#index = get_cell_source_id(Vector2i(x, y) + offset)
			#
			#if index == -1:
				#tileArrayTex.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
			#else:
				#tileArrayTex.set_pixelv(Vector2i(x, y), Color((index + 1.0) * (1.0 / float(numOfTileIndexes)), 0.0, 0.0, 1.0))
	#
	return tileArrayTex

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
	forgroundTexture.texture = tex2DRD
	miniMap.texture = tex2DRD
	

func executeTextureChunkShader(chunkCoord : Vector2i, tileImage : Image):
	#print(chunkCoord)
	#Chunk Data Setup
	var chunkData := PackedInt32Array([chunkCoord.x, chunkCoord.y, chunkSize, outlineBufferSize]).to_byte_array()
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

func setPixel(coord : Vector2i, index : int):
	if coord.x < 0 or coord.x > mapImage.get_size().x - 1:
		return
	if coord.y < 0 or coord.y > mapImage.get_size().y - 1:
		return
	
	if index == -1:
		mapImage.set_pixel(coord.x, coord.y, Color(0.0, 0.0, 0.0, 0.0))
	else:
		mapImage.set_pixelv(Vector2i(coord.x, coord.y), Color((index + 1.0) * (1.0 / float(numOfTileIndexes)), 0.0, 0.0, 1.0))
	
