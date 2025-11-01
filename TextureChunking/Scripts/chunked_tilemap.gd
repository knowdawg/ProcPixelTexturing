extends TileMapLayer
class_name ChunkedTilemap

enum tilemapType {FOREGROUND, BACKGROUND}
@export var type : tilemapType = tilemapType.FOREGROUND

@export_group("External Nodes")
@export var texture : Sprite2D
@export var miniMap : Sprite2D

var chunks : Array = []
var activeChunks : Array[TextureChunk] = []
var chunk = preload("uid://dafgjgn78ehp2")

var dirty : bool = false
var mapImage : Image

func isChunkInBounds(chunkCoord):
	if chunkCoord.x >= 0 and chunkCoord.x < chunks.size() and chunkCoord.y >= 0 and chunkCoord.y < chunks[0].size():
		return true
	return false

func addTile(pos : Vector2, tileIndex : int):
	dirty = true
	var tilePos : Vector2i = local_to_map(pos)
	#set_cell(tilePos, tileIndex, Vector2i(0, 0), 0)
	
	#var pixelPos := tilePos
	#var index = get_cell_source_id(tilePos)
	setPixel(tilePos, tileIndex)
	
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

func _ready() -> void:
	setupRenderingDevice()
	
	if type == tilemapType.FOREGROUND:
		TerrainDestruction.foreground = self
	if type == tilemapType.BACKGROUND:
		TerrainDestruction.background = self
	
	var tilemapSize : Vector2i = get_used_rect().size
	var tilemapPos : Vector2i = get_used_rect().position
	mapImage = Image.create_empty(TerrainRendering.mapSize.x, TerrainRendering.mapSize.y, false, Image.FORMAT_RGBAF)
	mapImage.fill(Color(0.0, 0.0, 0.0, 0.0))
	mapImage.decompress()
	
	for x in tilemapSize.x:
		for y in tilemapSize.y:
			var tileMapPos : Vector2i = Vector2i(x, y) + tilemapPos
			var index = get_cell_source_id(tileMapPos)
			if index == -1:
				mapImage.set_pixel(tileMapPos.x, tileMapPos.y, Color(0.0, 0.0, 0.0, 0.0))
			else:
				mapImage.set_pixelv(Vector2i(tileMapPos.x, tileMapPos.y), Color((index + 1.0) * (1.0 / float(TerrainRendering.uniqueTiles)), 0.0, 0.0, 1.0))
	
	for x in tilemapSize.x: #Clear the tilemap
		for y in tilemapSize.y:
			var tileMapPos : Vector2i = Vector2i(x, y) + tilemapPos
			set_cell(tileMapPos, -1, Vector2i(0, 0), 0)
	
	var numOfChunks : Vector2 = ceil(TerrainRendering.mapSize / float(TerrainRendering.chunkSize))
	for x in numOfChunks.x:
		chunks.append([])
		for y in numOfChunks.y:
			var c : TextureChunk = chunk.instantiate()
			chunks[x].append(c)
			add_child(c)
			var chunkType = TextureChunk.tilemapType.FOREGROUND if type == tilemapType.FOREGROUND else TextureChunk.tilemapType.BACKGROUND
			c.setup(TerrainRendering.chunkSize, TerrainRendering.outlineBufferSize, self, Vector2(x,y), chunkType)

func _process(_delta: float) -> void:
	updateChunks()
	if dirty:
		#updateCombinedTexture()
		dirty = false
	
	#var bm : BitMap = BitMap.new()
	#bm.create_from_image_alpha(bitmapImage.get_image(), 0.5)
	
	#if type == tilemapType.FOREGROUND:
		#if !Input.is_action_pressed("ui_accept"):
			#if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				##TerrainDestruction.addTileImage(get_global_mouse_position(), imageTest.get_image(), TerrainDestruction.FOREGROUND)
				##TerrainDestruction.addTileBitmap(get_global_mouse_position(), TILE.SANDSTONE, bm, TerrainDestruction.FOREGROUND)
				#TerrainDestruction.addTileRadius(get_global_mouse_position(), TILE.WOOD, 6, TerrainDestruction.FOREGROUND)
				#
			#if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
				#var pos : Vector2 = local_to_map(get_global_mouse_position())
				#TerrainDestruction.addTileRadius(pos, TILE.EMPTY, 6, TerrainDestruction.FOREGROUND)
			#
	#if type == tilemapType.BACKGROUND:
		#if Input.is_action_pressed("ui_accept"):
			#if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				#TerrainDestruction.addTileRadius(get_global_mouse_position(), TILE.WOOD, 10, TerrainDestruction.BACKGROUND)
				#
			#if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
				#var pos : Vector2 = local_to_map(get_global_mouse_position())
				#TerrainDestruction.addTileRadius(pos, TILE.EMPTY, 6, TerrainDestruction.BACKGROUND)

func updateChunks() -> void:
	if !is_instance_valid(get_viewport().get_camera_2d()):
		return
	var cameraPos := get_viewport().get_camera_2d().get_screen_center_position()
	var prevActiveChunks : Array[TextureChunk] = activeChunks.duplicate()
	activeChunks.clear()
	
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
	
	
	if type == tilemapType.FOREGROUND:
		var loadedRect := Rect2(0.0, 0.0, 0.0, 0.0)
		var topLeftChunkCoord : Vector2i = centerChunk - Vector2i(topLeftChunkOffset, topLeftChunkOffset)
		var numOfChunks := Vector2i(int(float(TerrainRendering.mapSize.x) / float(TerrainRendering.chunkSize)), int(float(TerrainRendering.mapSize.y) / float(TerrainRendering.chunkSize)))
		if topLeftChunkCoord.x < numOfChunks.x - 1 and topLeftChunkCoord.y < numOfChunks.y - 1:
			loadedRect.position = chunks[topLeftChunkCoord.x][topLeftChunkCoord.y].global_position
			loadedRect.size = Vector2(TerrainRendering.renderSectionSize, TerrainRendering.renderSectionSize)
			if topLeftChunkCoord.x < 0:
				loadedRect.position.x = 0.0
				loadedRect.size.x += topLeftChunkCoord.x * TerrainRendering.chunkSize
			if topLeftChunkCoord.y < 0:
				loadedRect.position.y = 0.0
				loadedRect.size.y += topLeftChunkCoord.y * TerrainRendering.chunkSize
			TerrainRendering.loadedRect = loadedRect
	
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
	
	var scroll : Vector2 = Vector2.ZERO
	scroll = Vector2(centerChunk * TerrainRendering.chunkSize) / float(TerrainRendering.renderSectionSize)
	TerrainRendering.tileTextureOffset = scroll
	RenderingServer.global_shader_parameter_set("TILE_TEXTURE_SCROLL", scroll)
	texture.global_position = (scroll * float(TerrainRendering.renderSectionSize))# + (Vector2(float(renderSectionSize), float(renderSectionSize)) / 2.0)

func worldToChunk(pos : Vector2) -> Vector2i:
	var chunkCoord := Vector2i(pos) / TerrainRendering.chunkSize
	return chunkCoord

func getArrayTexture(coord : Vector2i) -> Image:
	var offset = (coord * TerrainRendering.chunkSize) - Vector2i(TerrainRendering.outlineBufferSize, TerrainRendering.outlineBufferSize)
	var chunkTotalSize = TerrainRendering.chunkSize + ((TerrainRendering.outlineBufferSize) * 2)
	var tileArrayTex = Image.create_empty(chunkTotalSize, chunkTotalSize, false, Image.FORMAT_RGBAF)
	tileArrayTex.decompress()
	
	tileArrayTex.blit_rect(mapImage, Rect2i(offset, Vector2i(chunkTotalSize, chunkTotalSize)), Vector2i.ZERO)
	
	return tileArrayTex

#RenderingDevice Vars DONT FORGET TO FREE RIDs
var rd : RenderingDevice
var textureChunkShaderFile
var textureChunkShader
var pipeline : RID
var enviermentalDataTextureRID : RID
func setupRenderingDevice():
	rd = RenderingServer.get_rendering_device()
	
	textureChunkShaderFile = load("uid://dvrxg8j3h7sl")
	textureChunkShader = rd.shader_create_from_spirv(textureChunkShaderFile.get_spirv())
	pipeline = rd.compute_pipeline_create(textureChunkShader)
	
	var image = Image.create_empty(TerrainRendering.renderSectionSize, TerrainRendering.renderSectionSize, false, Image.FORMAT_RGBAF);
	image.fill(Color.BLACK)
	enviermentalDataTextureRID = TerrainRendering.getRIDImage(image, rd)
	
	if type == tilemapType.FOREGROUND:
		TerrainRendering.envirementalDataTextureRID = enviermentalDataTextureRID
	elif type == tilemapType.BACKGROUND:
		TerrainRendering.backgroundDataTextureRID = enviermentalDataTextureRID
	
	var tex2DRD : Texture2DRD = Texture2DRD.new()
	tex2DRD.set_texture_rd_rid(enviermentalDataTextureRID)
	texture.texture = tex2DRD
	miniMap.texture = tex2DRD

func executeTextureChunkShader(chunkCoord : Vector2i, tileImage : Image):
	#Chunk Data Setup
	var chunkData := PackedInt32Array([chunkCoord.x, chunkCoord.y, TerrainRendering.chunkSize, TerrainRendering.outlineBufferSize])
	var chunkDataRID : RID = TerrainRendering.getRIDStorageBufferInt(chunkData, rd)
	var chunkDataUniform := TerrainRendering.getUniformStorageBufferInt(chunkDataRID, 0)
	
	#TileImage Setup
	var tileImageRID : RID = TerrainRendering.getRIDImage(tileImage, rd)
	var tileImageUniform : RDUniform = TerrainRendering.getUniformImage(tileImageRID, 1)
	
	#Output Buffer Setup
	var outputUniform := TerrainRendering.getUniformImage(enviermentalDataTextureRID, 2)
	
	var uniformSet := rd.uniform_set_create([chunkDataUniform, tileImageUniform, outputUniform], textureChunkShader, 0)
	var computeList = rd.compute_list_begin()
	
	var w = sqrt(float(TerrainRendering.chunkSize * TerrainRendering.chunkSize) / float(8 * 8))
	var workgroups := Vector3i(int(w), int(w), 1)
	TerrainRendering.executeComputeShader(workgroups, rd, computeList, pipeline, uniformSet)
	
	rd.free_rid(chunkDataRID)
	rd.free_rid(tileImageRID)

func setPixel(coord : Vector2i, index : int):
	if coord.x < 0 or coord.x > mapImage.get_size().x - 1:
		return
	if coord.y < 0 or coord.y > mapImage.get_size().y - 1:
		return
	
	if index == -1:
		mapImage.set_pixel(coord.x, coord.y, Color(0.0, 0.0, 0.0, 0.0))
	else:
		mapImage.set_pixelv(Vector2i(coord.x, coord.y), Color((index + 1.0) * (1.0 / float(TerrainRendering.uniqueTiles)), 0.0, 0.0, 1.0))
	
