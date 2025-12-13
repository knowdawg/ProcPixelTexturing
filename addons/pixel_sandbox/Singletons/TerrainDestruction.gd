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
	for x in image.get_size().x:
		for y in image.get_size().y:
			var curPos := worldPosition + Vector2(x, y) - offset
			var pixel : Color = image.get_pixel(x, y)
			if pixel.r == 0.0: #Skip if blank
				if skipBlank:
					continue
				pixel.r = 0.0
			var tile : int = int(floor(pixel.r * TerrainRendering.uniqueTiles))
			addTile(curPos, tile, tilemapType)

func addTileBitmap(worldPosition : Vector2, tileIndex : int, bitmap : BitMap, tilemapType : int):
	var offset : Vector2 = bitmap.get_size() / 2.0
	for x in bitmap.get_size().x:
		for y in bitmap.get_size().y:
			var pixel : bool = bitmap.get_bit(x, y)
			if pixel:
				var curPos := worldPosition + Vector2(x, y) - offset
				addTile(curPos, tileIndex, tilemapType)

func addTileRadius(worldPosition : Vector2, tileIndex : int, radius : int, tilemapType : int, forceDesruction : bool = false) -> Dictionary[int, int]:
	var prevTiles : Dictionary[int, int] = destroyedTileDictionary.duplicate()
	
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			var offset = Vector2(x, y)
			if offset.length() <= radius + 0.5:
				var p = worldPosition + offset
				var prevTile : int = addTile(p, tileIndex, tilemapType, forceDesruction)
				
				prevTiles[prevTile] = prevTiles[prevTile] + 1
	
	return prevTiles

func addTile(worldPosition : Vector2, tileIndex : int, tilemapType : int, forceDesruction : bool = false) -> int:
	var prevTile : int
	if tilemapType == FOREGROUND:
		prevTile = int((TerrainRendering.getPixel(worldPosition).r * 255.0) + 0.5)
		TerrainRendering.setPixel(worldPosition, tileIndex, TerrainRendering.LAYER_TYPE.FOREGROUND)
	if tilemapType == BACKGROUND:
		prevTile = int((TerrainRendering.getPixel(worldPosition).g * 255.0) + 0.5)
		TerrainRendering.setPixel(worldPosition, tileIndex, TerrainRendering.LAYER_TYPE.BACKGROUND)
	return prevTile
