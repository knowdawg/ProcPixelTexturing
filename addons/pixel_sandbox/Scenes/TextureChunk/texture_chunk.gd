extends Node2D
class_name TextureChunk

"""
Texture Chunk is given a coordinate upon creation. When it becomes dirty (usualy via TerrainDestruction), it get the new texture data from the TerrainRendering's world data image
and preforms it's responsibilities. Its responsibilities include:
	-Update the world visual image based on tile data
	-Update collision
	-Update the light map based on tile data
"""

var chunkSize : int

var dirty : bool = true
var chunkCoord : Vector2i

"""
tileData is the data (in bytes) of the tiles for this chunk.
tileData is converted into an rgba8 image before being passed into the shader. This means a few things:
	-Seting / geting tiles is not as simple as an index. TileData is a 1d array thus some conversions neec to happen. See the worldToArray function
	-Each pixel in the rgba8 texture is 1 byte. Thus, 4 bytes in the array need to be traversed to get to the next pixel
	-tileData stores both foreground and background, the r channel is foreground and g channel is background
"""
var tileData : PackedByteArray

@export var visualizeChunk : bool = false
var active : bool = false

var bitmap : BitMap
var polygons : Array[PackedVector2Array]
var collPolys : Array[CollisionPolygon2D] = []

"""
The Edit array stores all the edits from the previous terrain tick.
When the chunk is updated, it iterates through each edit and applies it to tileData
"""
var edits : Array[TerrainEdit] = []

func setup(chunk_size : int, chunk_coord : Vector2i):
	chunkSize = chunk_size
	chunkCoord = chunk_coord
	
	global_position = (chunkSize * chunkCoord)
	
	tileData.resize(chunkSize * chunkSize * 4) #times 4 for each collor channel
	bitmap = BitMap.new()
	

func makeDirty():
	dirty = true

func updateBuffer():
	#Approach: create the image from data based on your chunk and the sourounding 8 chunks
	var chunkImage : Image = Image.create_empty(chunkSize * 3, chunkSize * 3, false, Image.FORMAT_RGBA8)
	for i in range(-1, 2): #get chunk -1 to 1, range is exclusive in the secound parameter
		for j in range(-1, 2):
			var d : PackedByteArray = TerrainRendering.getChunkTileData(chunkCoord + Vector2i(i, j))
			var im : Image = Image.create_from_data(chunkSize, chunkSize, false, Image.FORMAT_RGBA8, d)
			chunkImage.blit_rect(im, Rect2i(0, 0, chunkSize, chunkSize), Vector2i(i + 1, j + 1) * chunkSize)
	
	TerrainRendering.executeTextureChunkShader(chunkCoord, chunkImage)
	
	bitmap.create_from_image_alpha(chunkImage, 0.5)
	var rect := Rect2i(Vector2i(chunkSize, chunkSize), Vector2i(chunkSize, chunkSize))
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
	if edits.size() == 0:
		return
		#makeDirty()
	#if !dirty:
		#return
	
	TerrainRendering.addChunkGroupToDirtyChunkQueue(chunkCoord)
	for e : TerrainEdit in edits:
		applyTerrainEdit(e)
	edits.clear()
	#updateBuffer()
	#dirty = false
	
	

func localToArray(localTilePos : Vector2i, layer : TerrainRendering.LAYER_TYPE) -> int:
	var tileArrayIndex = localTilePos.x + (localTilePos.y * chunkSize)
	tileArrayIndex *= 4 #times 4 because there is 4 channels
	
	match layer:
		TerrainRendering.LAYER_TYPE.FOREGROUND:
			tileArrayIndex += 0 #red
		TerrainRendering.LAYER_TYPE.BACKGROUND:
			tileArrayIndex += 1 #green
		
	return tileArrayIndex

func worldToArray(tilePos : Vector2i, layer : TerrainRendering.LAYER_TYPE) -> int:
	var expectedChunkCoord : Vector2i = tilePos / chunkSize
	if expectedChunkCoord != chunkCoord:
		#printerr("Atempting to set tile with world position %d in chunk %d. It should be in chunk %d", tilePos, chunkCoord, expectedChunkCoord)
		return -1
	var localTilePos : Vector2i = tilePos % chunkSize
	
	return localToArray(localTilePos, layer)

func applyTerrainEdit(tEdit : TerrainEdit) -> int:
	for i in range(tEdit.layers.size()):
		var arrayIndex = localToArray(tEdit.localPositions[i], tEdit.layers[i])
		tileData[arrayIndex] = clamp(tEdit.tileIndexs[i], 0, 255)
		
	return 0

func getTile(tilePos : Vector2i, layer : TerrainRendering.LAYER_TYPE) -> int:
	var arrayIndex = worldToArray(tilePos, layer)
	if arrayIndex == -1: #error in the world to array function
		return 0
	var tile : int = tileData[arrayIndex]
	return tile

func _draw() -> void:
	if visualizeChunk:
		var c : Color = Color.LIME_GREEN
		if (chunkCoord.x + chunkCoord.y) % 2 == 0:
			c = Color.DARK_GREEN
		draw_rect(Rect2(Vector2(1.0, 1.0), Vector2(chunkSize - 1, chunkSize - 1)), c, false, 1.0, false)

func activate():
	active = true
	$StaticBody2D.process_mode = ProcessMode.PROCESS_MODE_INHERIT

func deActivate():
	active = false
	$StaticBody2D.process_mode = ProcessMode.PROCESS_MODE_DISABLED
