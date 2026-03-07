#Global script for adding and removing terrain from the world
extends Node

enum{
	FOREGROUND,
	BACKGROUND
}

var destroyedTileDictionary : Dictionary[int, int]

func _ready() -> void:
	destroyedTileDictionary[-1] = 0
	for i in range(TerrainRendering.uniqueTiles):
		destroyedTileDictionary[i] = 0

func addTileImage(worldPosition : Vector2, image : Image, tilemapType : int, skipBlank : bool = true):
	var offset : Vector2 = image.get_size() / 2.0
	var tEdits : Dictionary[Vector2i, TerrainEdit] = {}
	for x in image.get_size().x:
		for y in image.get_size().y:
			var p := worldPosition + Vector2(x, y) - offset
			p.clamp(Vector2i(0, 0), Vector2i(TerrainRendering.mapSize) - Vector2i(1, 1))
			
			var pixel : Color = image.get_pixel(x, y)
			if pixel.r == 0.0: #Skip if blank
				if skipBlank:
					continue
				pixel.r = 0.0
			var tileIndex : int = int(floor(pixel.r * TerrainRendering.uniqueTiles))
			
			var pChunkCoord : Vector2i = TerrainRendering.worldToChunk(p)
			if tEdits.has(pChunkCoord):
				tEdits[pChunkCoord].appendTerrainChange(p, tileIndex, tilemapType)
			else:
				tEdits[pChunkCoord] = TerrainEdit.new(pChunkCoord)
				tEdits[pChunkCoord].appendTerrainChange(p, tileIndex, tilemapType)
	for k : Vector2i in tEdits.keys():
		TerrainRendering.distributeTerrainEdit(tEdits[k])

func addTileBitmap(worldPosition : Vector2, tileIndex : int, bitmap : BitMap, tilemapType : int):
	var offset : Vector2 = bitmap.get_size() / 2.0
	var tEdits : Dictionary[Vector2i, TerrainEdit] = {}
	for x in bitmap.get_size().x:
		for y in bitmap.get_size().y:
			var pixel : bool = bitmap.get_bit(x, y)
			if pixel:
				var p := worldPosition + Vector2(x, y) - offset
				p.clamp(Vector2i(0, 0), Vector2i(TerrainRendering.mapSize) - Vector2i(1, 1))
				
				var pChunkCoord : Vector2i = TerrainRendering.worldToChunk(p)
				if tEdits.has(pChunkCoord):
					tEdits[pChunkCoord].appendTerrainChange(p, tileIndex, tilemapType)
				else:
					tEdits[pChunkCoord] = TerrainEdit.new(pChunkCoord)
					tEdits[pChunkCoord].appendTerrainChange(p, tileIndex, tilemapType)
	for k : Vector2i in tEdits.keys():
		TerrainRendering.distributeTerrainEdit(tEdits[k])


func addTileRadius(worldPosition : Vector2, tileIndex : int, radius : int, tilemapType : int, forceDesruction : bool = false) -> Dictionary[int, int]:
	#Curently not working with the new multithread aproach, need a delayed signal aproach probably
	var prevTiles : Dictionary[int, int] = destroyedTileDictionary.duplicate()
	
	#Iterate through the circle. For each pixel, if there is a tEdit for the chunk its in then add it to it.
	#Otherwise, create of tEdit at the pixels destination chunk and add the pixel to it
	#At the end, pass each tEdit to TerrainRendering
	var tEdits : Dictionary[Vector2i, TerrainEdit] = {}
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			var offset = Vector2(x, y)
			if offset.length() <= radius + 0.5:
				var p : Vector2i = worldPosition + offset
				p.clamp(Vector2i(0, 0), Vector2i(TerrainRendering.mapSize) - Vector2i(1, 1))
				
				var pChunkCoord : Vector2i = TerrainRendering.worldToChunk(p)
				if tEdits.has(pChunkCoord):
					tEdits[pChunkCoord].appendTerrainChange(p, tileIndex, tilemapType)
				else:
					tEdits[pChunkCoord] = TerrainEdit.new(pChunkCoord)
					tEdits[pChunkCoord].appendTerrainChange(p, tileIndex, tilemapType)
				
	for k : Vector2i in tEdits.keys():
		TerrainRendering.distributeTerrainEdit(tEdits[k])
	
	return prevTiles


func getTileRect(rect : Rect2i) -> PackedByteArray:
	var a : PackedByteArray
	
	return a
