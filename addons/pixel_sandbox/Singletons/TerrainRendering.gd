extends Node

enum LAYER_TYPE {FOREGROUND, BACKGROUND}

#Imaportant RID
var textureForegroundRID : RID
var textureBackgroundRID : RID

var foregroundSDF : RID
var backgroundSDF : RID

var worldPosition : Vector2
var tileTextureOffset : Vector2

var sunDirection : float =  - PI / 2.0
var lightrays : RID
var GI : RID

#World Details
var chunkSize : int = PixelSandboxSettings.chunkSize
var outlineBufferSize : int = PixelSandboxSettings.outlineBufferSize
var renderSectionSize : int = PixelSandboxSettings.renderSectionSize
var mapSize : Vector2i = PixelSandboxSettings.mapSize
var loadedRect : Rect2

#World Objects
var imageForeground : Image
var imageBackground : Image
var chunksForeground : Array
var chunksBackground : Array
var activeChunksForeground : Array[TextureChunk]
var activeChunksBackground : Array[TextureChunk]
var spriteForeground : Sprite2D
var spriteBackground : Sprite2D
var chunk = preload("uid://dafgjgn78ehp2")

#Texture Details
var uniqueTiles : int = 64
var textureSize := Vector2i(256, 256)

var foregroundTextureData : TextureData = load(PixelSandboxSettings.textureDataForeground)
var backgroundTextureData : TextureData = load(PixelSandboxSettings.textureDataBackground)



#Constants
var IMAGE_FORMAT : int = Image.FORMAT_RGBAF

func dirtyAll():
	var numOfChunks : Vector2i = Vector2i(chunksForeground.size(), chunksForeground[0].size())
	for x in numOfChunks.x:
		for y in numOfChunks.y:
			chunksForeground[x][y].makeDirty()
			chunksBackground[x][y].makeDirty()

#returns an image of the specified size filled with the specified material
func generateSampleImage(tile : int, size : Vector2i) -> Image:
	var im : Image = Image.create_empty(size.x, size.y, false, IMAGE_FORMAT)
	im.fill(Color(float(tile) / float(uniqueTiles), 0.0, 0.0, 1.0))
	return im

func contructTextureArrays():
	#Foreground
	var tex2dArray := foregroundTextureData.getTextureArray(uniqueTiles)
	var normal2dArray := foregroundTextureData.getNormalArray(uniqueTiles)
	var gradient2dArray := foregroundTextureData.getGradientArray(uniqueTiles)
	var borderColors := foregroundTextureData.getBorderTexture(uniqueTiles)
	RenderingServer.global_shader_parameter_set("PS_FOREGROUND_TEXTURES", tex2dArray)
	RenderingServer.global_shader_parameter_set("PS_FOREGROUND_NORMALS", normal2dArray)
	RenderingServer.global_shader_parameter_set("PS_FOREGROUND_GRADIENTS", gradient2dArray)
	RenderingServer.global_shader_parameter_set("PS_FOREGROUND_BORDER_COLORS", borderColors)
	
	#Background
	tex2dArray = backgroundTextureData.getTextureArray(uniqueTiles)
	normal2dArray = backgroundTextureData.getNormalArray(uniqueTiles)
	gradient2dArray = backgroundTextureData.getGradientArray(uniqueTiles)
	borderColors = backgroundTextureData.getBorderTexture(uniqueTiles)
	RenderingServer.global_shader_parameter_set("PS_BACKGROUND_TEXTURES", tex2dArray)
	RenderingServer.global_shader_parameter_set("PS_BACKGROUND_NORMALS", normal2dArray)
	RenderingServer.global_shader_parameter_set("PS_BACKGROUND_GRADIENTS", gradient2dArray)
	RenderingServer.global_shader_parameter_set("PS_BACKGROUND_BORDER_COLORS", borderColors)
	

func isPositionLoaded(pos : Vector2) -> bool:
	if !loadedRect:
		return false
	if pos.x > loadedRect.position.x and pos.y > loadedRect.position.y:
		if pos.x < loadedRect.position.x + loadedRect.size.x and pos.y < loadedRect.position.y + loadedRect.size.y:
			return true
	return false

func _ready() -> void:
	RuntimeShaderGlobals.addGlobals()
	
	RenderingServer.global_shader_parameter_set("PS_RENDER_QUADRANT_SIZE", Vector2(renderSectionSize, renderSectionSize))
	RenderingServer.global_shader_parameter_set("PS_UNIQUE_TILES", uniqueTiles)
	contructTextureArrays()
	
	#Setup pipeline for calculate Enviermental Textures
	renDev = RenderingServer.get_rendering_device()
	textureChunkShaderFile = load("uid://dvrxg8j3h7sl")
	textureChunkShader = renDev.shader_create_from_spirv(textureChunkShaderFile.get_spirv())
	persPipeline = renDev.compute_pipeline_create(textureChunkShader)
	
	
	setupEnviromentObjects()
	setupChunks()

func _process(_delta: float) -> void:
	updateLoadedRect()
	updateTileTextureScrollAndSpritePosition()
	
	updateChunks(LAYER_TYPE.FOREGROUND)
	updateChunks(LAYER_TYPE.BACKGROUND)
	
	#if Input.is_action_just_pressed("ReloadTexture"):
		#contructTextureArrays()

func setupEnviromentObjects() -> void:
	imageForeground = Image.create_empty(mapSize.x, mapSize.y, false, IMAGE_FORMAT)
	imageForeground.fill(Color(0.0, 0.0, 0.0, 0.0))
	imageForeground.decompress()
	imageBackground = Image.create_empty(mapSize.x, mapSize.y, false, IMAGE_FORMAT)
	imageBackground.fill(Color(0.0, 0.0, 0.0, 0.0))
	imageBackground.decompress()
	
	
	var image = Image.create_empty(renderSectionSize, renderSectionSize, false, IMAGE_FORMAT);
	image.fill(Color.BLACK)
	textureForegroundRID = TerrainRendering.getRIDImage(image, renDev)
	
	var image2 = Image.create_empty(renderSectionSize, renderSectionSize, false, IMAGE_FORMAT);
	image2.fill(Color.BLACK)
	textureBackgroundRID = TerrainRendering.getRIDImage(image2, renDev)
	

func setupChunks() -> void:
	var numOfChunks : Vector2 = ceil(TerrainRendering.mapSize / float(TerrainRendering.chunkSize))
	for x in numOfChunks.x:
		chunksForeground.append([])
		chunksBackground.append([])
		for y in numOfChunks.y:
			var cFor : TextureChunk = chunk.instantiate()
			var cBack : TextureChunk = chunk.instantiate()
			chunksForeground[x].append(cFor)
			chunksBackground[x].append(cBack)
			add_child(cFor)
			add_child(cBack)
			cFor.setup(chunkSize, outlineBufferSize, Vector2(x,y), LAYER_TYPE.FOREGROUND)
			cBack.setup(chunkSize, outlineBufferSize, Vector2(x,y), LAYER_TYPE.BACKGROUND)

func updateChunks(layer : LAYER_TYPE) -> void:
	if !is_instance_valid(get_viewport().get_camera_2d()):
		return
		
	var activeChunks : Array[TextureChunk]
	var chunks : Array
	if layer == LAYER_TYPE.FOREGROUND:
		activeChunks = activeChunksForeground
		chunks = chunksForeground
	elif layer == LAYER_TYPE.BACKGROUND:
		activeChunks = activeChunksBackground
		chunks = chunksBackground
	
	var cameraPos := get_viewport().get_camera_2d().get_screen_center_position()
	var prevActiveChunks : Array[TextureChunk] = activeChunks.duplicate()
	activeChunks.clear()

	
	#Update what chunks are in screen range
	var centerChunk := worldToChunk(cameraPos)
	var chunkDementions : int = int(float(TerrainRendering.renderSectionSize) / float(TerrainRendering.chunkSize))
	var topLeftChunkOffset : int = int(float(chunkDementions) / 2.0)
	var worldChunkSize : Vector2i = Vector2(TerrainRendering.mapSize) / float(TerrainRendering.chunkSize)
	for x in range(chunkDementions):
		for y in range(chunkDementions):
			var cCoord : Vector2i = centerChunk + Vector2i(x - topLeftChunkOffset, y - topLeftChunkOffset)
			#Check out of bounds (for now might change later)
			if cCoord.x >= 0 and cCoord.y >= 0:
				if cCoord.x < worldChunkSize.x and cCoord.y < worldChunkSize.y:
					activeChunks.append(chunks[cCoord.x][cCoord.y])
	
	#Update The chunks
	for c : TextureChunk in activeChunks:
		if !prevActiveChunks.has(c):
			c.activate()
			c.makeDirty()
	for c : TextureChunk in prevActiveChunks:
		if !activeChunks.has(c):
			c.deActivate()
	for c : TextureChunk in activeChunks:
		c.active = true
		c.updateChunk()


func getChunkImage(coord : Vector2i, layer : LAYER_TYPE) -> Image:
	var offset = (coord * TerrainRendering.chunkSize) - Vector2i(TerrainRendering.outlineBufferSize, TerrainRendering.outlineBufferSize)
	var chunkTotalSize = TerrainRendering.chunkSize + ((TerrainRendering.outlineBufferSize) * 2)
	var chunkImage = Image.create_empty(chunkTotalSize, chunkTotalSize, false, Image.FORMAT_RGBAF)
	chunkImage.decompress()
	
	if layer == LAYER_TYPE.FOREGROUND:
		chunkImage.blit_rect(imageForeground, Rect2i(offset, Vector2i(chunkTotalSize, chunkTotalSize)), Vector2i.ZERO)
	if layer == LAYER_TYPE.BACKGROUND:
		chunkImage.blit_rect(imageBackground, Rect2i(offset, Vector2i(chunkTotalSize, chunkTotalSize)), Vector2i.ZERO)
	
	return chunkImage

func getPixel(pos : Vector2i, layer : LAYER_TYPE) -> int:
	var mapImage : Image
	if layer == LAYER_TYPE.FOREGROUND:
		mapImage = imageForeground
	if layer == LAYER_TYPE.BACKGROUND:
		mapImage = imageBackground
	
	if pos.x < 0 or pos.x > mapImage.get_size().x - 1:
		return -1
	if pos.y < 0 or pos.y > mapImage.get_size().y - 1:
		return -1
	
	var val : float = mapImage.get_pixelv(pos).r
	
	return int(val * TerrainRendering.uniqueTiles) - 1

func setPixel(pos : Vector2, tileIndex : int, layer : LAYER_TYPE):
	var chunks : Array
	var mapImage : Image
	if layer == LAYER_TYPE.FOREGROUND:
		chunks = chunksForeground
		mapImage = imageForeground
	if layer == LAYER_TYPE.BACKGROUND:
		chunks = chunksBackground
		mapImage = imageBackground
	
	var tilePos : Vector2i = pos#local_to_map(pos)
	
	#update Pixel on the image
	if tilePos.x < 0 or tilePos.x > mapImage.get_size().x - 1:
		return
	if tilePos.y < 0 or tilePos.y > mapImage.get_size().y - 1:
		return
	if tileIndex == -1:
		mapImage.set_pixel(tilePos.x, tilePos.y, Color(0.0, 0.0, 0.0, 0.0))
	else:
		mapImage.set_pixelv(Vector2i(tilePos.x, tilePos.y), Color((tileIndex + 1.0) * (1.0 / float(TerrainRendering.uniqueTiles)), 0.0, 0.0, 1.0))
	
	
	#Dirty the chunk with the tile
	var chunkPos : Vector2 = (Vector2(tilePos)) / float(TerrainRendering.chunkSize)
	var chunkCoord : Vector2i = floor(chunkPos)
	if isChunkInBounds(chunkCoord):
		chunks[chunkCoord.x][chunkCoord.y].makeDirty()
	else:
		return
	
	#Dirty adjacent chunks if you are close enough to the border
	var chunkToOutlineRatio = float(TerrainRendering.outlineBufferSize) / float(TerrainRendering.chunkSize)
	var fract : Vector2 = chunkPos - floor(chunkPos)
	
	var updateLeft : bool = (fract.x < chunkToOutlineRatio) and isChunkInBounds(chunkCoord + Vector2i(-1, 0))
	var updateRight : bool = (fract.x + chunkToOutlineRatio >= 1.0) and isChunkInBounds(chunkCoord + Vector2i(1, 0))
	var updateUp : bool = (fract.y < chunkToOutlineRatio) and isChunkInBounds(chunkCoord + Vector2i(0, -1))
	var updateDown : bool = (fract.y + chunkToOutlineRatio >= 1.0) and isChunkInBounds(chunkCoord + Vector2i(0, 1))
	
	if updateLeft:
		chunks[chunkCoord.x - 1][chunkCoord.y].makeDirty()
	if updateRight:
		chunks[chunkCoord.x + 1][chunkCoord.y].makeDirty()
	if updateUp:
		chunks[chunkCoord.x][chunkCoord.y - 1].makeDirty()
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

func isChunkInBounds(chunkCoord):
	if chunkCoord.x >= 0 and chunkCoord.x < chunksForeground.size() and chunkCoord.y >= 0 and chunkCoord.y < chunksForeground[0].size():
		return true
	return false

func updateTileTextureScrollAndSpritePosition() -> void:
	if !is_instance_valid(get_viewport().get_camera_2d()):
		return
	var cameraPos := get_viewport().get_camera_2d().get_screen_center_position()
	var centerChunk := worldToChunk(cameraPos)
	
	var scroll : Vector2 = Vector2.ZERO
	scroll = Vector2(centerChunk * chunkSize) / float(renderSectionSize)
	tileTextureOffset = scroll
	RenderingServer.global_shader_parameter_set("PS_TILE_TEXTURE_SCROLL", scroll)
	
	if is_instance_valid(spriteForeground):
		spriteForeground.global_position = (scroll * float(renderSectionSize))
	if is_instance_valid(spriteBackground):
		spriteBackground.global_position = (scroll * float(renderSectionSize))
	

func updateLoadedRect() -> void:
	if !is_instance_valid(get_viewport().get_camera_2d()):
		return
	var cameraPos := get_viewport().get_camera_2d().get_screen_center_position()
	var centerChunk := worldToChunk(cameraPos)
	var chunkDementions : int = int(float(TerrainRendering.renderSectionSize) / float(TerrainRendering.chunkSize))
	var topLeftChunkOffset : int = int(float(chunkDementions) / 2.0)
	
	var newLoadedRect := Rect2(0.0, 0.0, 0.0, 0.0)
	var topLeftChunkCoord : Vector2i = centerChunk - Vector2i(topLeftChunkOffset, topLeftChunkOffset)
	var numOfChunks := Vector2i(int(float(mapSize.x) / float(chunkSize)), int(float(mapSize.y) / float(chunkSize)))
	if topLeftChunkCoord.x < numOfChunks.x - 1 and topLeftChunkCoord.y < numOfChunks.y - 1:
		newLoadedRect.size = Vector2(renderSectionSize, renderSectionSize)
		if topLeftChunkCoord.x < 0:
			newLoadedRect.position.x = 0.0
			newLoadedRect.size.x += topLeftChunkCoord.x * chunkSize
		else:
			newLoadedRect.position.x = topLeftChunkCoord.x * chunkSize
		if topLeftChunkCoord.y < 0:
			newLoadedRect.position.y = 0.0
			newLoadedRect.size.y += topLeftChunkCoord.y * chunkSize
		else:
			newLoadedRect.position.y = topLeftChunkCoord.y * chunkSize
		if topLeftChunkCoord.x >= 0 and topLeftChunkCoord.y >= 0:
			newLoadedRect.position = chunksForeground[topLeftChunkCoord.x][topLeftChunkCoord.y].global_position
		loadedRect = newLoadedRect
	

func worldToChunk(pos : Vector2) -> Vector2i:
	var chunkCoord := Vector2i(pos) / chunkSize
	return chunkCoord

func executeTextureChunkShader(chunkCoord : Vector2i, tileImage : Image, layer : LAYER_TYPE):
	var textureRID : RID
	if layer == LAYER_TYPE.FOREGROUND:
		textureRID = textureForegroundRID
	if layer == LAYER_TYPE.BACKGROUND:
		textureRID = textureBackgroundRID
	
	#Chunk Data Setup
	var chunkData := PackedInt32Array([chunkCoord.x, chunkCoord.y, TerrainRendering.chunkSize, TerrainRendering.outlineBufferSize])
	var chunkDataRID : RID = TerrainRendering.getRIDStorageBufferInt(chunkData, renDev)
	var chunkDataUniform := TerrainRendering.getUniformStorageBufferInt(chunkDataRID, 0)
	
	#TileImage Setup
	var tileImageRID : RID = TerrainRendering.getRIDImage(tileImage, renDev)
	var tileImageUniform : RDUniform = TerrainRendering.getUniformImage(tileImageRID, 1)
	
	#Output Buffer Setup
	var outputUniform := TerrainRendering.getUniformImage(textureRID, 2)
	
	var uniformSet := renDev.uniform_set_create([chunkDataUniform, tileImageUniform, outputUniform], textureChunkShader, 0)
	var computeList = renDev.compute_list_begin()
	
	var w = sqrt(float(TerrainRendering.chunkSize * TerrainRendering.chunkSize) / float(8 * 8))
	var workgroups := Vector3i(int(w), int(w), 1)
	TerrainRendering.executeComputeShader(workgroups, renDev, computeList, persPipeline, uniformSet)
	
	renDev.free_rid(chunkDataRID)
	renDev.free_rid(tileImageRID)

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







#Compute Shader Boilerplate functions

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
