#Global script for adding and removing terrain from the world
extends Node

var foreground : ChunkedTilemap
var background : ChunkedTilemap

enum{
	FOREGROUND,
	BACKGROUND
}


func addTileImage(worldPosition : Vector2, image : Image, tilemapType : int):
	var offset : Vector2 = image.get_size() / 2.0
	for x in image.get_size().x:
		for y in image.get_size().y:
			var curPos := worldPosition + Vector2(x, y) - offset
			var pixel : Color = image.get_pixel(x, y)
			if pixel.r == 0.0: #Skip if blank
				continue
			var tile : int = int(floor(pixel.r * TerrainRendering.uniqueTiles)) - 1
			addTile(curPos, tile, tilemapType)


func addTileBitmap(worldPosition : Vector2, tileIndex : int, bitmap : BitMap, tilemapType : int):
	var offset : Vector2 = bitmap.get_size() / 2.0
	for x in bitmap.get_size().x:
		for y in bitmap.get_size().y:
			var pixel : bool = bitmap.get_bit(x, y)
			if pixel:
				var curPos := worldPosition + Vector2(x, y) - offset
				addTile(curPos, tileIndex, tilemapType)

func addTileRadius(worldPosition : Vector2, tileIndex : int, radius : int, tilemapType : int):
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			var offset = Vector2(x, y)
			if offset.length() <= radius + 0.5:
				var p = worldPosition + offset
				addTile(p, tileIndex, tilemapType)

func addTile(worldPosition : Vector2, tileIndex : int, tilemapType : int) -> void:
	if tilemapType == FOREGROUND:
		if is_instance_valid(foreground):
			foreground.addTile(worldPosition, tileIndex)
			return
	if tilemapType == BACKGROUND:
		if is_instance_valid(background):
			background.addTile(worldPosition, tileIndex)
			return
