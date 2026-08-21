extends Node2D
class_name WorldChunk

#Debug
var visualizeChunk : bool = false

"""
Contains the tile data for a section of the world
"""

var chunkSize : int #size of chunk in pixels (square)
var chunkCoord : Vector2i #Location fo the chunk in chunk space
var isActive : bool = false #Is this chunk in the loaded rect?

"""
tileData is the data (in bytes) of the tiles for this chunk.
tileData is converted into an rgba8 image before being passed into the shader. This means a few things:
	-Seting / geting tiles is not as simple as an index. TileData is a 1d array thus some conversions need to happen. See the worldToArray function
	-Each pixel in the rgba8 texture is 1 byte. Thus, 4 bytes in the array need to be traversed to get to the next pixel
	-tileData stores both foreground and background, the r channel is foreground and g channel is background
"""
var tileData : PackedByteArray

"""Collision"""
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
	
	tileData.resize(chunkSize * chunkSize * 4) #4 bytes for 4 color channels
	bitmap = BitMap.new()


"""Applies all queued TerrainEdits. Returns true if changes were made, false if not"""
func updateChunk() -> bool:
	if edits.size() == 0:
		return false
	
	#Update data
	for e : TerrainEdit in edits:
		applyTerrainEdit(e)
	edits.clear()
	
	#Update collision
	var chunkImage : Image = Image.create_from_data(chunkSize, chunkSize, false, Image.FORMAT_RGBA8, tileData)
	
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
	
	return true

"""Given a coord in chunk space, return the tile data byte for that location"""
func localToArray(localTilePos : Vector2i, layer : PixelSandbox.LAYER) -> int:
	var tileArrayIndex = localTilePos.x + (localTilePos.y * chunkSize)
	tileArrayIndex *= 4 #times 4 because there is 4 channels
	
	match layer:
		PixelSandbox.LAYER.FOREGROUND:
			tileArrayIndex += 0 #red channel
		PixelSandbox.LAYER.BACKGROUND:
			tileArrayIndex += 1 #green channel
		
	return tileArrayIndex

"""Given a coord in world space, return the tile data byte for that location"""
func worldToArray(tilePos : Vector2i, layer : PixelSandbox.LAYER) -> int:
	var expectedChunkCoord : Vector2i = tilePos / chunkSize
	if expectedChunkCoord != chunkCoord:
		return -1
	
	var localX : int = tilePos.x & (chunkSize - 1)
	var localY : int = tilePos.y & (chunkSize - 1)
	
	var arrayIndex: int = (localX + (localY * chunkSize)) * 4
	match layer:
		PixelSandbox.LAYER.FOREGROUND:
			arrayIndex += 0 #red channel
		PixelSandbox.LAYER.BACKGROUND:
			arrayIndex += 1 #green channel
	
	return arrayIndex

func applyTerrainEdit(tEdit : TerrainEdit) -> int:
	for i in range(tEdit.layers.size()):
		var arrayIndex = localToArray(tEdit.localPositions[i], tEdit.layers[i])
		tileData[arrayIndex] = clamp(tEdit.tileIndexs[i], 0, 255)
	
	return 0

"""Outward facing tile query function"""
func getTile(tilePos : Vector2i, layer : PixelSandbox.LAYER) -> int:
	var arrayIndex = worldToArray(tilePos, layer)
	if arrayIndex == -1: #error in the world to array function
		return 0
	var tile : int = tileData[arrayIndex]
	return tile

"""Draw Chunk Borders"""
func _draw() -> void:
	if visualizeChunk:
		var c : Color = Color.LIME_GREEN
		if (chunkCoord.x + chunkCoord.y) % 2 == 0:
			c = Color.DARK_GREEN
		draw_rect(Rect2(Vector2(1.0, 1.0), Vector2(chunkSize - 1, chunkSize - 1)), c, false, 1.0, false)

func activate():
	isActive = true
	$StaticBody2D.process_mode = ProcessMode.PROCESS_MODE_INHERIT

func deActivate():
	isActive = false
	$StaticBody2D.process_mode = ProcessMode.PROCESS_MODE_DISABLED
