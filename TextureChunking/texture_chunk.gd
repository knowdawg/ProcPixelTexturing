extends Node2D
class_name TextureChunk

var chunkSize : int #Start with 64
var outlineBufferSize : int #6
var totalChunkSize : int

var dirty : bool = true
var tilemapArrayTex : Image
var tilemap : ChunkedTilemap
var chunkCoord : Vector2i

var visualizeChunk : bool = true

func setup(chunk_size : int, outline_buffer_size : int, t_map : ChunkedTilemap, chunk_coord : Vector2i):
	chunkSize = chunk_size
	outlineBufferSize = outline_buffer_size
	tilemap = t_map
	chunkCoord = chunk_coord
	
	totalChunkSize = chunkSize + (outlineBufferSize * 2)
	
	global_position = (chunkSize * chunkCoord)

func makeDirty():
	dirty = true
	if !tilemap.dirtyChunks.has(self):
		tilemap.dirtyChunks.append(self)

func updateBuffer():
	tilemapArrayTex = tilemap.getArrayTexture(chunkCoord)
	tilemap.executeTextureChunkShader(chunkCoord, tilemapArrayTex)

func updateChunk():
	if dirty:
		updateBuffer()
		dirty = false
	

func _draw() -> void:
	if visualizeChunk:
		var c : Color = Color.LIME_GREEN
		if (chunkCoord.x + chunkCoord.y) % 2 == 0:
			c = Color.DARK_GREEN
		draw_rect(Rect2(Vector2(1.0, 1.0), Vector2(chunkSize - 1, chunkSize - 1)), c, false, 1.0, false)
