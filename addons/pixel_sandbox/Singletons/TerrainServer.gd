extends Node
"""
Manages Terraian Data
"""

#Rect containing all active chunks
var loadedRect : Rect2

var chunkScene = preload("uid://bnwh18w01rigl")
#All chunks in the world, keyed on thier position in chunk space
var chunks       : Dictionary[Vector2i, WorldChunk]
#All chunks in the render quadrant
var activeChunks : Dictionary[Vector2i, WorldChunk]
var dirtyChunks  : Dictionary[Vector2i, WorldChunk]


func _ready() -> void:
	createChunks()

"""
PROCESS PIPELINE:
	Update Loaded Rect
	Update Chunks
"""
func _process(delta: float) -> void:
	updateLoadedRect()
	updateChunks()

"""
CHUNK PIPELINE:
	Calculate active chunks based on camera position, new chunks are dirtied.
	Update all Active Chunks. (This is where terrarin edits are applied)
	Give all dirty chunks to TerrainRendering to be re-rendered.
	Clear Dirty Chunks.
"""
func updateChunks() -> void:
	var cam : Camera2D = get_viewport().get_camera_2d()
	if !is_instance_valid(cam):
		return
	var cameraPos := cam.get_screen_center_position()
	
	var prevChunks : Dictionary[Vector2i, WorldChunk] = activeChunks
	activeChunks = {}
	
	#Update what chunks are in screen range
	var centerChunk := worldToChunk(cameraPos)
	var topLeftChunk := centerChunk - (loadedRectSizeInChunks() / 2)
	for x in range(loadedRectSizeInChunks().x):
		for y in range(loadedRectSizeInChunks().y):
			var curCoord : Vector2i = topLeftChunk + Vector2i(x, y)
			
			curCoord = clampChunkCoord(curCoord)
			activeChunks[curCoord] = chunks[curCoord]
	
	#Dirty new chunks
	for k : Vector2i in activeChunks.keys():
		var chunk : WorldChunk = activeChunks[k]
		if !prevChunks.has(k):
			chunk.activate()
			dirtyChunks[k] = chunk
			
	#De-activate chunks that are no longer in the loaded rect
	for k : Vector2i in prevChunks.keys():
		var chunk : WorldChunk = prevChunks[k]
		if !activeChunks.has(k):
			chunk.deActivate()
	
	#Update all active Chunks
	for k : Vector2i in activeChunks.keys():
		var chunk : WorldChunk = activeChunks[k]
		var changes : bool = chunk.updateChunk()
		if changes:
			dirtyChunkGroup(k)
	
	#Give Terrarain Rendering the dirty chunks
	TerrainRendering.reRenderChunks(dirtyChunks.values())
	dirtyChunks.clear()


func updateLoadedRect() -> void:
	if !is_instance_valid(get_viewport().get_camera_2d()):
		return
	var cameraPos := get_viewport().get_camera_2d().get_screen_center_position()
	var centerChunk := worldToChunk(cameraPos)
	var chunkDementions : int = int(float(PixelSandbox.renderSectionSize) / float(PixelSandbox.chunkSize))
	var topLeftChunkOffset : int = int(float(chunkDementions) / 2.0)
	
	var newLoadedRect := Rect2(0.0, 0.0, 0.0, 0.0)
	var topLeftChunkCoord : Vector2i = centerChunk - Vector2i(topLeftChunkOffset, topLeftChunkOffset)
	var numOfChunks := Vector2i(int(float(PixelSandbox.mapSize.x) / float(PixelSandbox.chunkSize)), int(float(PixelSandbox.mapSize.y) / float(PixelSandbox.chunkSize)))
	if topLeftChunkCoord.x < numOfChunks.x - 1 and topLeftChunkCoord.y < numOfChunks.y - 1:
		newLoadedRect.size = Vector2(PixelSandbox.renderSectionSize, PixelSandbox.renderSectionSize)
		if topLeftChunkCoord.x < 0:
			newLoadedRect.position.x = 0.0
			newLoadedRect.size.x += topLeftChunkCoord.x * PixelSandbox.chunkSize
		else:
			newLoadedRect.position.x = topLeftChunkCoord.x * PixelSandbox.chunkSize
		if topLeftChunkCoord.y < 0:
			newLoadedRect.position.y = 0.0
			newLoadedRect.size.y += topLeftChunkCoord.y * PixelSandbox.chunkSize
		else:
			newLoadedRect.position.y = topLeftChunkCoord.y * PixelSandbox.chunkSize
		if topLeftChunkCoord.x >= 0 and topLeftChunkCoord.y >= 0:
			newLoadedRect.position = chunks[topLeftChunkCoord].global_position
		loadedRect = newLoadedRect


"""--- Chunk Helper Functions ---"""

func createChunks() -> void:
	for x in worldSizeInChunks().x:
		for y in worldSizeInChunks().y:
			var c : WorldChunk = chunkScene.instantiate()
			var coord := Vector2i(x,y)
			chunks[coord] = c
			add_child(c)
			c.setup(PixelSandbox.chunkSize, coord)

func dirtyChunk(chunkCoord : Vector2i) -> void:
	dirtyChunks[chunkCoord] = chunks[chunkCoord]

#Dirty Chunks in a 3x3 Grid
func dirtyChunkGroup(chunkCoord : Vector2i) -> void:
	for i in range(-1, 2):
		for j in range(-1, 2):
			var coord : Vector2i = chunkCoord + Vector2i(i, j)
			coord = clampChunkCoord(coord)
			dirtyChunks[coord] = chunks[coord]

func dirtyAllChunks():
	dirtyChunks = chunks.duplicate()

func clampChunkCoord(coord : Vector2i) -> Vector2i:
	return coord.clamp(
		Vector2i(0, 0),
		worldSizeInChunks() - Vector2i(1, 1)
	)

func worldToChunk(pos : Vector2) -> Vector2i:
	var chunkCoord := floor(Vector2i(pos) / PixelSandbox.chunkSize)
	return chunkCoord
	
#Returns the tile data for a given chunkCoord
func getChunkTileData(chunkCoord : Vector2i) -> PackedByteArray:
	var clampedCoord : Vector2i = clampChunkCoord(chunkCoord)
	return chunks[clampedCoord].tileData



"""--- World Helper Functions ---"""
func worldSizeInChunks() -> Vector2i:
	return PixelSandbox.mapSize / PixelSandbox.chunkSize
	
func loadedRectSizeInChunks() -> Vector2i:
	return Vector2i(PixelSandbox.renderSectionSize, PixelSandbox.renderSectionSize) / PixelSandbox.chunkSize

func isPositionLoaded(pos : Vector2) -> bool:
	if !loadedRect:
		return false
	return loadedRect.has_point(pos)

#Distributes the given terrain edit to the corect chunk
func distributeTerrainEdit(tEdit : TerrainEdit):
	var ownerChunk : WorldChunk = chunks[tEdit.destinationChunkCoord]
	ownerChunk.edits.append(tEdit)

func getTile(pos : Vector2i, layer : int) -> int:
	if pos.x < 0 or pos.x > PixelSandbox.mapSize.x - 1:
		return 0
	if pos.y < 0 or pos.y > PixelSandbox.mapSize.y - 1:
		return 0
	
	#convert to chunk space
	var ownerChunkCoord : Vector2i = worldToChunk(pos)
	var ownerChunk : WorldChunk = chunks[ownerChunkCoord]
	return ownerChunk.getTile(pos, layer)


"""Blueprint Helper Funcitons"""
func addTileImage(worldPosition : Vector2, image : Image, layer : PixelSandbox.LAYER, skipBlank : bool = true):
	var offset : Vector2 = image.get_size() / 2.0
	var tEdits : Dictionary[Vector2i, TerrainEdit] = {}
	for x in image.get_size().x:
		for y in image.get_size().y:
			var p := worldPosition + Vector2(x, y) - offset
			p = p.clamp(Vector2i(0, 0), Vector2i(PixelSandbox.mapSize) - Vector2i(1, 1))
			
			var pixel : Color = image.get_pixel(x, y)
			if pixel.r == 0.0: #Skip if blank
				if skipBlank:
					continue
				pixel.r = 0.0
			var tileIndex : int = int(floor(pixel.r * PixelSandbox.tilesInGame))
			
			var pChunkCoord : Vector2i = worldToChunk(p)
			if tEdits.has(pChunkCoord):
				tEdits[pChunkCoord].appendTerrainChange(p, tileIndex, layer)
			else:
				tEdits[pChunkCoord] = TerrainEdit.new(pChunkCoord)
				tEdits[pChunkCoord].appendTerrainChange(p, tileIndex, layer)
	for k : Vector2i in tEdits.keys():
		distributeTerrainEdit(tEdits[k])

func addTileRadius(worldPosition : Vector2, tileIndex : int, radius : int, layer : PixelSandbox.LAYER, forceDesruction : bool = false):
	#Iterate through the circle. For each pixel, if there is a tEdit for the chunk its in then add it to it.
	#Otherwise, create of tEdit at the pixels destination chunk and add the pixel to it
	var tEdits : Dictionary[Vector2i, TerrainEdit] = {}
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			var offset = Vector2(x, y)
			if offset.length() <= radius + 0.5:
				var p : Vector2i = worldPosition + offset
				p = p.clamp(Vector2i(0, 0), Vector2i(PixelSandbox.mapSize) - Vector2i(1, 1))
				
				var pChunkCoord : Vector2i = worldToChunk(p)
				if tEdits.has(pChunkCoord):
					tEdits[pChunkCoord].appendTerrainChange(p, tileIndex, layer)
				else:
					tEdits[pChunkCoord] = TerrainEdit.new(pChunkCoord)
					tEdits[pChunkCoord].appendTerrainChange(p, tileIndex, layer)
				
	for k : Vector2i in tEdits.keys():
		distributeTerrainEdit(tEdits[k])
	
func addTileBitmap(worldPosition : Vector2, tileIndex : int, bitmap : BitMap, layer : PixelSandbox.LAYER):
	var offset : Vector2 = bitmap.get_size() / 2.0
	var tEdits : Dictionary[Vector2i, TerrainEdit] = {}
	for x in bitmap.get_size().x:
		for y in bitmap.get_size().y:
			var pixel : bool = bitmap.get_bit(x, y)
			if pixel:
				var p := worldPosition + Vector2(x, y) - offset
				p = p.clamp(Vector2i(0, 0), Vector2i(PixelSandbox.mapSize) - Vector2i(1, 1))
				
				var pChunkCoord : Vector2i = worldToChunk(p)
				if tEdits.has(pChunkCoord):
					tEdits[pChunkCoord].appendTerrainChange(p, tileIndex, layer)
				else:
					tEdits[pChunkCoord] = TerrainEdit.new(pChunkCoord)
					tEdits[pChunkCoord].appendTerrainChange(p, tileIndex, layer)
	for k : Vector2i in tEdits.keys():
		distributeTerrainEdit(tEdits[k])
