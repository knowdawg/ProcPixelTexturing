extends Node2D
class_name TextureChunk

"""
Texture Chunk is given a coordinate upon creation. When it becomes dirty (usualy via TerrainDestruction), it get the new texture data from the TerrainRendering's world data image
and preforms it's responsibilities. Its responsibilities include:
	-Update the world visual image based on tile data
	-Update collision
	-Update the light map based on tile data
"""

var chunkSize : int #Start with 64
var outlineBufferSize : int #6
var totalChunkSize : int

var dirty : bool = true
var chunkImage : Image #The current section of the world texture that it updates the world texture with
var chunkCoord : Vector2i

var visualizeChunk : bool = false
var active : bool = false

var bitmap : BitMap
var polygons : Array[PackedVector2Array]
var collPolys : Array[CollisionPolygon2D] = []

func setup(chunk_size : int, outline_buffer_size : int, chunk_coord : Vector2i):
	chunkSize = chunk_size
	outlineBufferSize = outline_buffer_size
	chunkCoord = chunk_coord
	
	totalChunkSize = chunkSize + (outlineBufferSize * 2)
	
	global_position = (chunkSize * chunkCoord)
	
	bitmap = BitMap.new()

func makeDirty():
	dirty = true

func updateBuffer():
	chunkImage = TerrainRendering.getChunkImage(chunkCoord)
	TerrainRendering.executeTextureChunkShader(chunkCoord, chunkImage)
	
	if layer == TerrainRendering.LAYER_TYPE.FOREGROUND:
		bitmap.create_from_image_alpha(chunkImage, 0.5)
		var rect := Rect2i(Vector2i(outlineBufferSize, outlineBufferSize), Vector2i(chunkSize, chunkSize))
		polygons = bitmap.opaque_to_polygons(rect, 1.0)
		
		for cp in collPolys:
			cp.queue_free()
		collPolys.clear()
		
		for p in polygons:
			var colPoly := CollisionPolygon2D.new()
			colPoly.polygon = p
			collPolys.append(colPoly)
			$StaticBody2D.add_child(colPoly)

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
		


func activate():
	active = true
	$StaticBody2D.process_mode = ProcessMode.PROCESS_MODE_INHERIT
	#print("activated")


func deActivate():
	active = false
	$StaticBody2D.process_mode = ProcessMode.PROCESS_MODE_DISABLED
	#print("Deactivated")
