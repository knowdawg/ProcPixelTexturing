extends Node2D
class_name TextureChunk

var chunkSize : int #Start with 64
var outlineBufferSize : int #6
var totalChunkSize : int

var dirty : bool = true
var tilemapArrayTex : Image
var tilemap : ChunkedTilemap
var chunkCoord : Vector2

var imageBuffer : Image

func setup(chunk_size : int, outline_buffer_size : int, t_map : ChunkedTilemap, chunk_coord : Vector2):
	chunkSize = chunk_size
	outlineBufferSize = outline_buffer_size
	tilemap = t_map
	chunkCoord = chunk_coord
	
	totalChunkSize = chunkSize + (outlineBufferSize * 2)
	imageBuffer = Image.create_empty(chunkSize, chunkSize, false, Image.FORMAT_BPTC_RGBA)
	%SubViewport.size = Vector2i(chunkSize, chunkSize)
	
	global_position = chunkSize * chunkCoord

func makeDirty():
	dirty = true
	if !tilemap.dirtyChunks.has(self):
		tilemap.dirtyChunks.append(self)

func updateBuffer():
	tilemapArrayTex = tilemap.getArrayTexture(chunkCoord)
	tilemap.executeTextureChunkShader(chunkCoord, tilemapArrayTex)
	#%ColorRect.material.set_shader_parameter("texSize", Vector2(totalChunkSize, totalChunkSize))
	#%ColorRect.material.set_shader_parameter("tileArrayTex", tilemapArrayTex)
	#%SubViewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	#$DisableUpdateTimer.start()
	#$Sprite2D.texture = tilemapArrayTex

func updateChunk():
	if dirty:
		updateBuffer()
		dirty = false
		#imageBuffer = %SubViewport.get_texture().get_image()

func getBuffer() -> Image:
	imageBuffer = %SubViewport.get_texture().get_image()
	return imageBuffer

func _ready() -> void:
	%SubViewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func _on_disable_update_timer_timeout() -> void:
	if !dirty and %SubViewport.render_target_update_mode == SubViewport.UPDATE_ONCE:
		%SubViewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
