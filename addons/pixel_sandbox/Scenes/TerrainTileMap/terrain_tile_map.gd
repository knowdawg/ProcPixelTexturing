extends TileMapLayer
class_name TerrainTileMap


@export var layer := TerrainRendering.LAYER_TYPE.FOREGROUND
@export var active : bool = true

func _ready() -> void:
	if !active:
		return
	var tilemapSize : Vector2i = get_used_rect().size
	var offset : Vector2i = get_used_rect().position
	
	#add tilemapdata to map image
	for x in tilemapSize.x:
		for y in tilemapSize.y:
			var coord := Vector2i(x, y) + offset
			var index = get_cell_source_id(coord)
			if index == -1:
				TerrainRendering.setPixel(coord, -1, layer)
			else:
				TerrainRendering.setPixel(coord, index, layer)
	
	#Clear the tilemap
	for x in tilemapSize.x:
		for y in tilemapSize.y:
			var tileMapPos : Vector2i = Vector2i(x, y) + offset
			set_cell(tileMapPos, -1, Vector2i(0, 0), 0)
