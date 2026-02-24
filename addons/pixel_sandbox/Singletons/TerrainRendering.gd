extends Node

enum LAYER_TYPE {FOREGROUND, BACKGROUND}

var sdfGen : SDFGenerator
var radCasc : RadianceCascades

var foregroundSDF : RID
var backgroundSDF : RID
var lightmapSDF : RID

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

var worldDataImage : Image
"""
worldDataImage:
	r: foregroundTileID
	g: backgroundTileID
	b: extra, probably for foregroundTileDamage in the future
	a: extra, probably for backgroundTileDamage in the future
"""

var worldVisualImageForegroundRID : RID
var worldVisualImageBackgroundRID : RID
"""
worldVisualImage:
	the actualy image that the user sees on the screen. This is the output of the generateTextureChunk shader
"""

var worldNormalImageForegroundRID : RID
var worldNormalImageBackgroundRID : RID
"""
worldNormalImage:
	the image that normals are writen to as an output of generateTextureChunk shader
"""

var lightMapRID : RID
"""
Light Map:
	This is a image that stores all blocks's emission color.
	For blocks that want to block light and cast shadows, thier emission color should be (0.0, 0.0, 0.0, 1.0)
	For blocks that want dont want to block light, thier emission color should be (0.0, 0.0, 0.0, 0.0)
"""

var spriteForeground : Sprite2D
var spriteBackground : Sprite2D
var spriteLighting : Sprite2D

var chunks : Array
var activeChunks : Dictionary[Vector2i, TextureChunk] #Contains All Chunks in the current Render Quadrant
var dirtyChunkQueue : Dictionary[TextureChunk, bool] #When you would dirty chunks, instead add them to this queue. Each update loop, this will be itterated over. Prevents repeated dirty fucntion calls
var chunk = preload("uid://dafgjgn78ehp2")

#Texture Details
var uniqueTiles : int = 256 #Keep at 256 as each image channel are in 8 bits
var textureSize := Vector2i(256, 256)

var foregroundTextureData : TextureData = load(PixelSandboxSettings.textureDataForeground)
var backgroundTextureData : TextureData = load(PixelSandboxSettings.textureDataBackground)

var textureUniforms : Array[RDUniform]
var bufferUniforms : Array[RDUniform]
var textureUniformSet : RID
var buffferUniformSet : RID

var renDev : RenderingDevice
var textureChunkShaderFile
var textureChunkShader
var persPipeline : RID

#Constants
var IMAGE_FORMAT : int = Image.FORMAT_RGBAF

func dirtyAll():
	var numOfChunks : Vector2i = Vector2i(chunks.size(), chunks[0].size())
	for x in numOfChunks.x:
		for y in numOfChunks.y:
			#chunks[x][y].makeDirty()
			dirtyChunkQueue[chunks[x][y]] = true

#returns an image of the specified size filled with the specified material
func generateSampleImage(tile : int, size : Vector2i) -> Image:
	var im : Image = Image.create_empty(size.x, size.y, false, IMAGE_FORMAT)
	im.fill(Color(float(tile) / float(uniqueTiles - 1), 0.0, 0.0, 1.0))
	return im

func contructTextureArrays():
	
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
	var tex2dArray : Texture2DArray = foregroundTextureData.getTextureArray(uniqueTiles)
	var normal2dArray : Texture2DArray = foregroundTextureData.getNormalArray(uniqueTiles)
	var gradient2dArray : Texture2DArray = foregroundTextureData.getGradientArray(uniqueTiles)
	var borderColors := foregroundTextureData.getBorderTexture(uniqueTiles)
	var emissionColors := foregroundTextureData.getLightEmissionTexture(uniqueTiles)
	
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
	u.add_id(getRIDImage(borderColors, renDev))
	textureUniforms.append(u)
	
	u = RDUniform.new()
	u.binding = 4
	u.uniform_type = samplerUniformType
	u.add_id(defaultSampler)
	u.add_id(getRIDImage(emissionColors, renDev))
	textureUniforms.append(u)
	
	
	#Background
	tex2dArray = backgroundTextureData.getTextureArray(uniqueTiles)
	normal2dArray = backgroundTextureData.getNormalArray(uniqueTiles)
	gradient2dArray = backgroundTextureData.getGradientArray(uniqueTiles)
	borderColors = backgroundTextureData.getBorderTexture(uniqueTiles)
	emissionColors = backgroundTextureData.getLightEmissionTexture(uniqueTiles)
	
	u = RDUniform.new()
	u.binding = 5
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	u.add_id(defaultSampler)
	u.add_id(getRIDImage2DArray(tex2dArray, renDev))
	textureUniforms.append(u)
	
	u = RDUniform.new()
	u.binding = 6
	u.uniform_type = samplerUniformType
	u.add_id(defaultSampler)
	u.add_id(getRIDImage2DArray(normal2dArray, renDev))
	textureUniforms.append(u)
	
	u = RDUniform.new()
	u.binding = 7
	u.uniform_type = samplerUniformType
	u.add_id(defaultSampler)
	u.add_id(getRIDImage2DArray(gradient2dArray, renDev))
	textureUniforms.append(u)
	
	u = RDUniform.new()
	u.binding = 8
	u.uniform_type = samplerUniformType
	u.add_id(defaultSampler)
	u.add_id(getRIDImage(borderColors, renDev))
	textureUniforms.append(u)
	
	u = RDUniform.new()
	u.binding = 9
	u.uniform_type = samplerUniformType
	u.add_id(defaultSampler)
	u.add_id(getRIDImage(emissionColors, renDev))
	textureUniforms.append(u)
	
	textureUniformSet = renDev.uniform_set_create(textureUniforms, textureChunkShader, 0)
	
	
	###---------ARRAYS---------###
	
	var foregroundBorderParams : PackedVector2Array = foregroundTextureData.getBorderParamArray(uniqueTiles)
	var backgroundBorderParams : PackedVector2Array = backgroundTextureData.getBorderParamArray(uniqueTiles)
	var solidArray : PackedInt32Array = foregroundTextureData.getSolidArray(uniqueTiles)
	
	var borderParamsBufferForeground : RID = renDev.storage_buffer_create(foregroundBorderParams.size() * 8, foregroundBorderParams.to_byte_array())
	var borderParamsBufferBackground : RID = renDev.storage_buffer_create(backgroundBorderParams.size() * 8, backgroundBorderParams.to_byte_array())
	var solidBuffer : RID = renDev.storage_buffer_create(solidArray.size() * 4, solidArray.to_byte_array())
	
	for i in range(3):
		u = RDUniform.new()
		u.binding = i
		u.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
		u.add_id([
			borderParamsBufferForeground,
			borderParamsBufferBackground,
			solidBuffer
			][i])
		bufferUniforms.append(u)
	
	buffferUniformSet = renDev.uniform_set_create(bufferUniforms, textureChunkShader, 1)


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
	
	#Setup pipeline for calculate Enviermental Textures
	renDev = RenderingServer.get_rendering_device()
	textureChunkShaderFile = load("uid://dvrxg8j3h7sl")
	textureChunkShader = renDev.shader_create_from_spirv(textureChunkShaderFile.get_spirv())
	persPipeline = renDev.compute_pipeline_create(textureChunkShader)
	setupEnviromentObjects()
	
	contructTextureArrays()
	setupChunks()
	
	#setup foreground SDF
	var image := Image.create_empty(renderSectionSize, renderSectionSize, false, Image.FORMAT_RGBAF);
	image.fill(Color.BLACK)
	foregroundSDF = TerrainRendering.getRIDImage(image, renDev)
	
	image = Image.create_empty(renderSectionSize, renderSectionSize, false, Image.FORMAT_RGBAF);
	image.fill(Color.BLACK)
	lightmapSDF = TerrainRendering.getRIDImage(image, renDev)

func _process(_delta: float) -> void:
	if is_instance_valid(sdfGen):
		sdfGen.createSDF(worldVisualImageForegroundRID, foregroundSDF, 0.0, true)
	updateLoadedRect()
	updateTileTextureScrollAndSpritePosition()
	
	updateChunks()
	
	if is_instance_valid(sdfGen):
		sdfGen.createSDF(lightMapRID, lightmapSDF, 0.0, true)
		if is_instance_valid(radCasc):
			radCasc.updateGlobalIllumination()
			#radCasc.finalOutputImageRID

func setupEnviromentObjects() -> void:
	worldDataImage = Image.create_empty(mapSize.x, mapSize.y, false, Image.FORMAT_RGBA8)
	worldDataImage.fill(Color(0.0, 0.0, 0.0, 0.0))
	worldDataImage.decompress()
	
	#Create an image on the GPU for each of the world images
	var worldImageForeground = Image.create_empty(renderSectionSize, renderSectionSize, false, Image.FORMAT_RGBA8);
	worldImageForeground.fill(Color(0.0, 0.0, 0.0, 0.0))
	worldVisualImageForegroundRID = TerrainRendering.getRIDImage(worldImageForeground, renDev)
	
	var worldImageBackground = Image.create_empty(renderSectionSize, renderSectionSize, false, Image.FORMAT_RGBA8);
	worldImageBackground.fill(Color(0.0, 0.0, 0.0, 0.0))
	worldVisualImageBackgroundRID = TerrainRendering.getRIDImage(worldImageBackground, renDev)
	
	var worldNormalImageForeground = Image.create_empty(renderSectionSize, renderSectionSize, false, Image.FORMAT_RGBA8);
	worldNormalImageForeground.fill(Color(0.0, 0.0, 0.0, 0.0))
	worldNormalImageForegroundRID = TerrainRendering.getRIDImage(worldNormalImageForeground, renDev)
	
	var worldNormalImageBackground = Image.create_empty(renderSectionSize, renderSectionSize, false, Image.FORMAT_RGBA8);
	worldNormalImageBackground.fill(Color(0.0, 0.0, 0.0, 0.0))
	worldNormalImageBackgroundRID = TerrainRendering.getRIDImage(worldNormalImageBackground, renDev)
	
	#Create an image on the GPU for the lightmap
	var lightmapImage = Image.create_empty(renderSectionSize, renderSectionSize, false, Image.FORMAT_RGBAF);
	lightmapImage.fill(Color(0.0, 0.0, 0.0, 0.0))
	lightMapRID = TerrainRendering.getRIDImage(lightmapImage, renDev)
	

func setupChunks() -> void:
	var numOfChunks : Vector2 = ceil(TerrainRendering.mapSize / float(TerrainRendering.chunkSize))
	for x in numOfChunks.x:
		chunks.append([])
		for y in numOfChunks.y:
			var cFor : TextureChunk = chunk.instantiate()
			chunks[x].append(cFor)
			add_child(cFor)
			cFor.setup(chunkSize, outlineBufferSize, Vector2(x,y))

func updateChunks() -> void:
	var cam : Camera2D = get_viewport().get_camera_2d()
	if !is_instance_valid(cam):
		return
	
	var cameraPos := cam.get_screen_center_position()
	var prevActiveChunks : Dictionary[Vector2i, TextureChunk] = activeChunks
	activeChunks = {}
	
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
					activeChunks[cCoord] = chunks[cCoord.x][cCoord.y]
					#activeChunks.append(chunks[cCoord.x][cCoord.y])
	
	#Update The chunks
	for k : Vector2i in activeChunks.keys():
		var c : TextureChunk = activeChunks[k]
		if !prevActiveChunks.has(c.chunkCoord):
			c.activate()
			#c.makeDirty()
			dirtyChunkQueue[c] = true
	for k : Vector2i in prevActiveChunks.keys():
		var c : TextureChunk = prevActiveChunks[k]
		if !activeChunks.has(c.chunkCoord):
			c.deActivate()
	for k : Vector2i in activeChunks.keys():
		var c : TextureChunk = activeChunks[k]
		c.active = true
		c.updateChunk()
	
	for c : TextureChunk in dirtyChunkQueue:
		c.makeDirty()
	dirtyChunkQueue.clear()


func getChunkImage(coord : Vector2i) -> Image:
	var offset = (coord * TerrainRendering.chunkSize) - Vector2i(TerrainRendering.outlineBufferSize, TerrainRendering.outlineBufferSize)
	var chunkTotalSize = TerrainRendering.chunkSize + ((TerrainRendering.outlineBufferSize) * 2)
	var chunkImage = Image.create_empty(chunkTotalSize, chunkTotalSize, false, Image.FORMAT_RGBA8)
	chunkImage.decompress()
	
	chunkImage.blit_rect(worldDataImage, Rect2i(offset, Vector2i(chunkTotalSize, chunkTotalSize)), Vector2i.ZERO)
	
	return chunkImage

func getPixel(pos : Vector2i) -> Color:
	
	if pos.x < 0 or pos.x > worldDataImage.get_size().x - 1:
		return Color(0.0, 0.0, 0.0, 0.0)
	if pos.y < 0 or pos.y > worldDataImage.get_size().y - 1:
		return Color(0.0, 0.0, 0.0, 0.0)
	
	var val : Color = worldDataImage.get_pixelv(pos)
	
	return val

func setPixel(pos : Vector2, tileIndex : int, layer : LAYER_TYPE):
	#update Pixel on the image
	if pos.x < 0 or pos.x > worldDataImage.get_size().x - 1:
		return
	if pos.y < 0 or pos.y > worldDataImage.get_size().y - 1:
		return
	
	var indexFloat : float = clamp((float(tileIndex) / float(uniqueTiles - 1)), 0.0, 1.0)
	var prevCol : Color = getPixel(pos)
	
	if layer == LAYER_TYPE.FOREGROUND:
		worldDataImage.set_pixel(pos.x, pos.y, Color(indexFloat, prevCol.g, 0.0, 0.0))
	elif layer == LAYER_TYPE.BACKGROUND:
		worldDataImage.set_pixel(pos.x, pos.y, Color(prevCol.r, indexFloat, 0.0, 0.0))
	
	
	#Dirty the chunk with the tile
	var chunkPos : Vector2 = (Vector2(pos)) / float(TerrainRendering.chunkSize)
	var chunkCoord : Vector2i = floor(chunkPos)
	if isChunkInBounds(chunkCoord):
		dirtyChunkQueue[chunks[chunkCoord.x][chunkCoord.y]] = true
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
		dirtyChunkQueue[chunks[chunkCoord.x - 1][chunkCoord.y]] = true
	if updateRight:
		dirtyChunkQueue[chunks[chunkCoord.x + 1][chunkCoord.y]] = true
	if updateUp:
		dirtyChunkQueue[chunks[chunkCoord.x][chunkCoord.y - 1]] = true
	if updateDown:
		dirtyChunkQueue[chunks[chunkCoord.x][chunkCoord.y + 1]] = true
	if updateLeft and updateUp:
		dirtyChunkQueue[chunks[chunkCoord.x - 1][chunkCoord.y - 1]] = true
	if updateLeft and updateDown:
		dirtyChunkQueue[chunks[chunkCoord.x - 1][chunkCoord.y + 1]] = true
	if updateRight and updateUp:
		dirtyChunkQueue[chunks[chunkCoord.x + 1][chunkCoord.y - 1]] = true
	if updateRight and updateDown:
		dirtyChunkQueue[chunks[chunkCoord.x + 1][chunkCoord.y + 1]] = true

func isChunkInBounds(chunkCoord):
	if chunkCoord.x >= 0 and chunkCoord.x < chunks.size() and chunkCoord.y >= 0 and chunkCoord.y < chunks[0].size():
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
	
	var cPos : Vector2 = (centerChunk - (Vector2i(renderSectionSize / chunkSize, renderSectionSize / chunkSize) / 2)) * chunkSize
	RenderingServer.global_shader_parameter_set("PS_TOP_LEFT_CHUNK_POSITION", cPos)
	
	RenderingServer.global_shader_parameter_set("PS_SCREEN_SIZE", get_viewport().get_visible_rect().size / get_viewport().get_camera_2d().zoom)
	
	#Set this property in the camera or else its a frame behind
	#RenderingServer.global_shader_parameter_set("PS_CAMERA_POSITION", cameraPos)
	
	if is_instance_valid(spriteForeground):
		spriteForeground.global_position = (scroll * float(renderSectionSize))
	if is_instance_valid(spriteBackground):
		spriteBackground.global_position = (scroll * float(renderSectionSize))
	if is_instance_valid(spriteLighting):
		spriteLighting.global_position = (scroll * float(renderSectionSize))
	

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
			newLoadedRect.position = chunks[topLeftChunkCoord.x][topLeftChunkCoord.y].global_position
		loadedRect = newLoadedRect
	

func worldToChunk(pos : Vector2) -> Vector2i:
	var chunkCoord := Vector2i(pos) / chunkSize
	return chunkCoord


#Recives a section of the worldDataImage and updates the visual output based on that info
func executeTextureChunkShader(chunkCoord : Vector2i, tileImage : Image):
	#Chunk Data Setup
	var chunkData := PackedInt32Array([chunkCoord.x, chunkCoord.y, TerrainRendering.chunkSize, TerrainRendering.outlineBufferSize])
	var chunkDataRID : RID = TerrainRendering.getRIDStorageBufferInt(chunkData, renDev)
	var chunkDataUniform : RDUniform = TerrainRendering.getUniformStorageBufferInt(chunkDataRID, 0)
	
	#TileImage Setup
	var tileImageRID : RID = TerrainRendering.getRIDImage(tileImage, renDev)
	var tileImageUniform : RDUniform = TerrainRendering.getUniformImage(tileImageRID, 1)
	
	#Output Buffer Setup
	var outputForeground : RDUniform = TerrainRendering.getUniformImage(worldVisualImageForegroundRID, 2)
	var outputBackground : RDUniform = TerrainRendering.getUniformImage(worldVisualImageBackgroundRID, 3)
	var lightMap : RDUniform = TerrainRendering.getUniformImage(lightMapRID, 4)
	var outputNormalForeground : RDUniform = TerrainRendering.getUniformImage(worldNormalImageForegroundRID, 5)
	var outputNormalBackground : RDUniform = TerrainRendering.getUniformImage(worldNormalImageBackgroundRID, 6)
	
	
	var uniformSet : RID = renDev.uniform_set_create([chunkDataUniform, tileImageUniform, outputForeground, outputBackground, lightMap, outputNormalForeground, outputNormalBackground], textureChunkShader, 2)
	
	var computeList = renDev.compute_list_begin()
	
	var w : int = int(ceil(float(TerrainRendering.chunkSize) / 8.0))
	var workgroups := Vector3i(int(w), int(w), 1)
	
	
	TerrainRendering.executeComputeShader(workgroups, renDev, computeList, persPipeline, [textureUniformSet, buffferUniformSet, uniformSet])
	
	renDev.free_rid(chunkDataRID)
	renDev.free_rid(tileImageRID)


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
	var outputImageForeground : Image = Image.create_empty(maxDimention, maxDimention, false, Image.FORMAT_RGBA8)
	outputImageForeground.fill(Color.BLACK)
	var outputImageForegroundRID : RID = getRIDImage(outputImageForeground, renDev)
	var outputUniformForeground := getUniformImage(outputImageForegroundRID, 2)
	
	var outputImageBackground: Image = Image.create_empty(maxDimention, maxDimention, false, Image.FORMAT_RGBA8)
	outputImageBackground.fill(Color.BLACK)
	var outputImageBackgroundRID : RID = getRIDImage(outputImageBackground, renDev)
	var outputUniformBackground := getUniformImage(outputImageBackgroundRID, 3)
	
	#Blueprints dont use lightmaps or normals... for now... and probabbly never. Writint a seperate shader for the blueprints would probably be a good idea
	var dummyLightmap: Image = Image.create_empty(maxDimention, maxDimention, false, Image.FORMAT_RGBAF)
	dummyLightmap.fill(Color.BLACK)
	var dummyLightmapRID : RID = getRIDImage(dummyLightmap, renDev)
	var dummyLightmapUniform := getUniformImage(dummyLightmapRID, 4)
	
	var dummyNormal1 := getUniformImage(dummyLightmapRID, 5)
	var dummyNormal2 := getUniformImage(dummyLightmapRID, 6)
	
	var uniformSet := renDev.uniform_set_create([chunkDataUniform, tileImageUniform, outputUniformForeground, outputUniformBackground, dummyLightmapUniform, dummyNormal1, dummyNormal2], textureChunkShader, 2)
	var computeList = renDev.compute_list_begin()
	
	var w : int = int(ceil(float(TerrainRendering.chunkSize) / 8.0))
	var workgroups := Vector3i(int(w), int(w), 1)
	executeComputeShader(workgroups, renDev, computeList, persPipeline, [textureUniformSet, buffferUniformSet, uniformSet])
	
	renDev.free_rid(chunkDataRID)
	renDev.free_rid(tileImageRID)
	
	return [outputImageForegroundRID, outputImageBackgroundRID]


#Compute Shader Boilerplate functions

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
#RenderingDevice.DATA_FORMAT_A8B8G8R8_UINT_PACK32

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
