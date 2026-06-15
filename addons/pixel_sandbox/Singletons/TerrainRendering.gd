extends Node

enum LAYER_TYPE {FOREGROUND, BACKGROUND}

var sdfGen : SDFGenerator
var radCasc : RadianceCascades

var lightmapSDF : RID


var textureWrapCount : Vector2 #Amount of times the envirement texture has wrapped in on itself
var textureWrapPixelOffset : Vector2i #The pixel count of the current offset
var cameraPosition : Vector2
var cameraChunkPixelProgress : Vector2i #distance from the camera to the top left corner of the chunk it is in

var GI : RID

#World Details
var chunkSize : int = PixelSandboxSettings.chunkSize
var renderSectionSize : int = PixelSandboxSettings.renderSectionSize
var mapSize : Vector2i = PixelSandboxSettings.mapSize
var loadedRect : Rect2

#World Objects
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

"""---LIGHTING IMAGES---"""
var finalLightImageRID : RID
var lightMapRID : RID
"""
Light Map:
	This is a image that stores all blocks's emission color.
	For blocks that want to block light and cast shadows, thier emission color should be (0.0, 0.0, 0.0, 1.0)
	For blocks that want dont want to block light, thier emission color should be (0.0, 0.0, 0.0, 0.0)
"""
var lightBuffer : LightBuffer
var lightBufferRID : RID
"""
Light Buffer:
	A subviewport that renders only emisive materials in the scene.
	Each frame, this is combined with the lightmap before lighting calculations are done
"""
var additiveBlendShaderFile
var additiveBlendShader
var additiveBlendPipeline

var spriteForeground : Sprite2D
var spriteBackground : Sprite2D

var chunks : Array
var activeChunks : Dictionary[Vector2i, TextureChunk] #Contains All Chunks in the current Render Quadrant
var dirtyChunkQueue : Dictionary[TextureChunk, bool] #When you would dirty chunks, instead add them to this queue. Each update loop, this will be itterated over. Prevents repeated dirty fucntion calls
var chunk = preload("uid://dafgjgn78ehp2")

#Texture Details
var uniqueTiles : int = 256 #Keep at 256 as each image channel are in 8 bits

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
const TERRAIN_IMAGE_FORMAT : int = Image.FORMAT_RGBA8
const LIGHTING_IMAGE_FORMAT = Image.FORMAT_RGBAH #RGBA16f

func dirtyAll():
	var numOfChunks : Vector2i = Vector2i(chunks.size(), chunks[0].size())
	for x in numOfChunks.x:
		for y in numOfChunks.y:
			#chunks[x][y].makeDirty()
			dirtyChunkQueue[chunks[x][y]] = true

#returns an image of the specified size filled with the specified material
func generateSampleImage(tile : int, size : Vector2i) -> Image:
	var im : Image = Image.create_empty(size.x, size.y, false, TERRAIN_IMAGE_FORMAT)
	im.fill(Color(float(tile) / float(uniqueTiles - 1), 0.0, 0.0, 1.0))
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
	var tex2dArray : Texture2DArray = foregroundTextureData.getTextureArray(uniqueTiles)
	var normal2dArray : Texture2DArray = foregroundTextureData.getNormalArray(uniqueTiles)
	var gradient2dArray : Texture2DArray = foregroundTextureData.getGradientArray(uniqueTiles)
	var borderGradient2dArray : Texture2DArray = foregroundTextureData.getBorderGradientArray(uniqueTiles)
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
	tex2dArray = backgroundTextureData.getTextureArray(uniqueTiles)
	normal2dArray = backgroundTextureData.getNormalArray(uniqueTiles)
	gradient2dArray = backgroundTextureData.getGradientArray(uniqueTiles)
	borderGradient2dArray = backgroundTextureData.getBorderGradientArray(uniqueTiles)
	borderColors = backgroundTextureData.getBorderTexture(uniqueTiles)
	emissionColors = backgroundTextureData.getLightEmissionTexture(uniqueTiles)
	
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
	setupChunks()
	
	#setup lightmap SDF
	
	var image = Image.create_empty(renderSectionSize, renderSectionSize, false, Image.FORMAT_RGBAF);
	image.fill(Color.BLACK)
	lightmapSDF = TerrainRendering.getRIDImage(image, renDev)

func _process(_delta: float) -> void:
	updateLoadedRect()
	updateTileTextureScrollAndSpritePosition()
	
	updateChunks()
	
	if is_instance_valid(sdfGen) and is_instance_valid(radCasc):
		sdfGen.createSDF(finalLightImageRID, lightmapSDF, 0.0, true)
		
	#Combine the LightBuffer with the lightMapRID
	if is_instance_valid(lightBuffer):
		lightBufferRID = lightBuffer.getViewportTextureRID()
		executeAdditiveBlendShader(lightMapRID, lightBufferRID, finalLightImageRID)
	
		radCasc.updateGlobalIllumination()
		
	if Input.is_action_just_pressed("ReloadTexture"):
		constructTextureArrays()

func setupEnviromentObjects() -> void:
	#Create an image on the GPU for each of the world images
	var worldImageForeground = Image.create_empty(renderSectionSize, renderSectionSize, false, TERRAIN_IMAGE_FORMAT);
	worldImageForeground.fill(Color(0.0, 0.0, 0.0, 0.0))
	worldVisualImageForegroundRID = TerrainRendering.getRIDImage(worldImageForeground, renDev)
	
	var worldImageBackground = Image.create_empty(renderSectionSize, renderSectionSize, false, TERRAIN_IMAGE_FORMAT);
	worldImageBackground.fill(Color(0.0, 0.0, 0.0, 0.0))
	worldVisualImageBackgroundRID = TerrainRendering.getRIDImage(worldImageBackground, renDev)
	
	var worldNormalImageForeground = Image.create_empty(renderSectionSize, renderSectionSize, false, TERRAIN_IMAGE_FORMAT);
	worldNormalImageForeground.fill(Color(0.0, 0.0, 0.0, 0.0))
	worldNormalImageForegroundRID = TerrainRendering.getRIDImage(worldNormalImageForeground, renDev)
	
	var worldNormalImageBackground = Image.create_empty(renderSectionSize, renderSectionSize, false, TERRAIN_IMAGE_FORMAT);
	worldNormalImageBackground.fill(Color(0.0, 0.0, 0.0, 0.0))
	worldNormalImageBackgroundRID = TerrainRendering.getRIDImage(worldNormalImageBackground, renDev)
	
	#Create an image on the GPU for the lightmap, the one the chunks write to
	var lightmapImage = Image.create_empty(renderSectionSize, renderSectionSize, false, LIGHTING_IMAGE_FORMAT);
	lightmapImage.fill(Color(0.0, 0.0, 0.0, 0.0))
	lightMapRID = TerrainRendering.getRIDImage(lightmapImage, renDev)
	
	#Create an image on the GPU for the final lightmap, the one that is sent to the lighting shader
	var finalLightImage = Image.create_empty(renderSectionSize, renderSectionSize, false, LIGHTING_IMAGE_FORMAT);
	finalLightImage.fill(Color(0.0, 0.0, 0.0, 0.0))
	finalLightImageRID = TerrainRendering.getRIDImage(finalLightImage, renDev)

func setupChunks() -> void:
	var numOfChunks : Vector2 = ceil(TerrainRendering.mapSize / float(TerrainRendering.chunkSize))
	for x in numOfChunks.x:
		chunks.append([])
		for y in numOfChunks.y:
			var cFor : TextureChunk = chunk.instantiate()
			chunks[x].append(cFor)
			add_child(cFor)
			cFor.setup(chunkSize, Vector2(x,y))

#Dirties chunks in a 3x3 grid
func addChunkGroupToDirtyChunkQueue(chunkCoord : Vector2i) -> void:
	for i in range(-1, 2):
		for j in range(-1, 2):
			var clampedCoord : Vector2i = chunkCoord + Vector2i(i, j)
			clampedCoord.clamp(Vector2i(0, 0), Vector2i(chunks.size() - 1, chunks[0].size() - 1))
			dirtyChunkQueue[chunks[clampedCoord.x][clampedCoord.y]] = true

func addToDirtyChunkQueue(chunkCoord : Vector2i) -> void:
	dirtyChunkQueue[chunks[chunkCoord.x][chunkCoord.y]] = true

"""
CHUNK PIPELINE:
	Calculate active chunks based on camera position, new tiles are flagged for rendering
	Iterate over each active chunk and apply thier TerrainEdits. Each chunk with tEdits will flag self and adjacent chunks for rendering
	Iterate over all chunks that are queued for rendering and render them
"""
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
	
	#New chunks are flagged for rendering
	for k : Vector2i in activeChunks.keys():
		var c : TextureChunk = activeChunks[k]
		if !prevActiveChunks.has(c.chunkCoord):
			c.activate()
			dirtyChunkQueue[c] = true
	#De-activate chunks that are no longer in the render quadrant
	for k : Vector2i in prevActiveChunks.keys():
		var c : TextureChunk = prevActiveChunks[k]
		if !activeChunks.has(c.chunkCoord):
			c.deActivate()
	
	#Set all chunks in the render quadrant to active and update them all. This is where they apply thier tEdits
	for k : Vector2i in activeChunks.keys():
		var c : TextureChunk = activeChunks[k]
		c.active = true
		c.updateChunk()
	
	#For each chunk marked for rendering, render them
	for c : TextureChunk in dirtyChunkQueue:
		if activeChunks.has(c.chunkCoord):
			c.updateBuffer()
	dirtyChunkQueue.clear()
	

func getTile(pos : Vector2i, layer : LAYER_TYPE) -> int:
	if pos.x < 0 or pos.x > mapSize.x - 1:
		return 0
	if pos.y < 0 or pos.y > mapSize.y - 1:
		return 0
	
	#convert to chunk space
	var ownerChunkCoord : Vector2i = worldToChunk(pos)
	var ownerChunk : TextureChunk = chunks[ownerChunkCoord.x][ownerChunkCoord.y]
	#Call the method on the chunk
	return ownerChunk.getTile(pos, layer)

#Distributes the given terrain edit to the corect chunk
func distributeTerrainEdit(tEdit : TerrainEdit) -> int:
	var ownerChunk : TextureChunk = chunks[tEdit.destinationChunkCoord.x][tEdit.destinationChunkCoord.y]
	ownerChunk.edits.append(tEdit)
	
	return 0

func isChunkInBounds(chunkCoord):
	if chunkCoord.x >= 0 and chunkCoord.x < chunks.size() and chunkCoord.y >= 0 and chunkCoord.y < chunks[0].size():
		return true
	return false

func updateTileTextureScrollAndSpritePosition() -> void:
	if !is_instance_valid(get_viewport().get_camera_2d()):
		return
	cameraPosition = get_viewport().get_camera_2d().get_screen_center_position()
	cameraChunkPixelProgress = Vector2i(cameraPosition) % chunkSize
	var centerChunk := worldToChunk(cameraPosition)
	
	var scroll : Vector2 = Vector2.ZERO
	scroll = Vector2(centerChunk * chunkSize) / float(renderSectionSize)
	textureWrapCount = scroll - Vector2(0.5, 0.5)
	textureWrapPixelOffset = Vector2i(textureWrapCount * renderSectionSize) % renderSectionSize
	
	RenderingServer.global_shader_parameter_set("PS_TILE_TEXTURE_SCROLL", textureWrapCount)
	
	var cPos : Vector2 = (centerChunk - (Vector2i(renderSectionSize / chunkSize, renderSectionSize / chunkSize) / 2)) * chunkSize
	RenderingServer.global_shader_parameter_set("PS_TOP_LEFT_CHUNK_POSITION", cPos)
	
	RenderingServer.global_shader_parameter_set("PS_SCREEN_SIZE", get_viewport().get_visible_rect().size / get_viewport().get_camera_2d().zoom)
	
	#Set this property in the camera or else its a frame behind
	#RenderingServer.global_shader_parameter_set("PS_CAMERA_POSITION", cameraPos)
	
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
			newLoadedRect.position = chunks[topLeftChunkCoord.x][topLeftChunkCoord.y].global_position
		loadedRect = newLoadedRect
	

func worldToChunk(pos : Vector2) -> Vector2i:
	var chunkCoord := Vector2i(pos) / chunkSize
	return chunkCoord

#Returns the tile data for a given chunkCoord, used by the texture chunks to create thier exstended texture
func getChunkTileData(chunkCoord : Vector2i) -> PackedByteArray:
	var clampedCoord : Vector2i = Vector2i(clampi(chunkCoord.x, 0, (mapSize.x / chunkSize) - 1), clampi(chunkCoord.y, 0, (mapSize.y / chunkSize) - 1))
	var c : TextureChunk = chunks[clampedCoord.x][clampedCoord.y]
	return c.tileData

#Recives a section of the worldDataImage and updates the visual output based on that info
func executeTextureChunkShader(chunkCoord : Vector2i, tileImage : Image):
	#Chunk Data Setup
	var chunkData := PackedInt32Array([chunkCoord.x, chunkCoord.y, TerrainRendering.chunkSize, TerrainRendering.chunkSize])
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
	
	var computeList: int = renDev.compute_list_begin()
	
	var w : int = int(ceil(float(TerrainRendering.chunkSize) / 8.0))
	var workgroups := Vector3i(int(w), int(w), 1)
	
	
	TerrainRendering.executeComputeShader(workgroups, renDev, computeList, persPipeline, [textureUniformSet, buffferUniformSet, uniformSet])
	
	renDev.free_rid(chunkDataRID)
	renDev.free_rid(tileImageRID)

func executeAdditiveBlendShader(source1 : RID, source2 : RID, dest : RID):
	var source1ImageUniform : RDUniform = getUniformImage(source1, 0)
	var source2ImageUniform : RDUniform = getUniformImage(source2, 1)
	var destImageUniform : RDUniform = getUniformImage(dest, 2)
	
	var cam : Camera2D = get_viewport().get_camera_2d()
	if !is_instance_valid(cam):
		return
	var camPos : Vector2i = Vector2i(round(cam.get_screen_center_position())) - Vector2i(renderSectionSize / 2, renderSectionSize / 2)
	
	var sb : RID = getRIDStorageBufferInt([camPos.x, camPos.y,
	 textureWrapPixelOffset.x, textureWrapPixelOffset.y], renDev)
	var sbUniform : RDUniform = getUniformStorageBufferInt(sb, 3)
	var uniformSet : RID = renDev.uniform_set_create([source1ImageUniform, source2ImageUniform, destImageUniform, sbUniform], additiveBlendShader, 0)
	
	var computeList: int = renDev.compute_list_begin()
	
	var w : int = int(ceil(float(TerrainRendering.renderSectionSize) / 32.0))
	var workgroups := Vector3i(int(w), int(w), 1)
	
	TerrainRendering.executeComputeShader(workgroups, renDev, computeList, additiveBlendPipeline, [uniformSet])
	
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
	
	var uniformSet := renDev.uniform_set_create([chunkDataUniform, tileImageUniform, outputUniformForeground, outputUniformBackground, dummyLightmapUniform, dummyNormal1, dummyNormal2], textureChunkShader, 2)
	var computeList: int = renDev.compute_list_begin()
	
	var w : int = int(ceil(float(TerrainRendering.chunkSize) / 8.0))
	var workgroups := Vector3i(int(w), int(w), 1)
	executeComputeShader(workgroups, renDev, computeList, persPipeline, [textureUniformSet, buffferUniformSet, uniformSet])
	
	renDev.free_rid(chunkDataRID)
	renDev.free_rid(tileImageRID)
	renDev.free_rid(dummyLightmapRID)
	
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
