extends TileMapLayer
class_name ChunkedTilemap

@export_group("Chunk Details")
@export var chunkSize : int = 64
@export var outlineBufferSize : int = 12 #Buffer size on each side

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
	
	if dirty:
		updateCombinedTexture()
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

func getArrayTexture(coord : Vector2i) -> ImageTexture:
	var offset = (coord * chunkSize) - Vector2i(outlineBufferSize, outlineBufferSize)
	var chunkTotalSize = chunkSize + ((outlineBufferSize) * 2)
	var tileArrayTex = Image.create_empty(chunkTotalSize, chunkTotalSize, false, Image.FORMAT_BPTC_RGBA)
	tileArrayTex.decompress()
	
	for x in range(chunkTotalSize):
		for y in range(chunkTotalSize):
			var index = get_cell_source_id(Vector2i(x, y) + offset)
			
			if index == -1:
				tileArrayTex.set_pixel(x, y, Color(0.0, 0.0, 0.0, 0.0))
			else:
				tileArrayTex.set_pixelv(Vector2i(x, y), Color((index + 1.0) * (1.0 / float(numOfTileIndexes)), 0.0, 0.0, 1.0))
	var im : ImageTexture = ImageTexture.create_from_image(tileArrayTex)
	return im
