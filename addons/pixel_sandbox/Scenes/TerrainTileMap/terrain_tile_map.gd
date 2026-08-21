extends TileMapLayer
class_name TerrainTileMap


@export var layer := PixelSandbox.LAYER.FOREGROUND
@export var active : bool = true

func _ready() -> void:
	if !active:
		return
	var tilemapSize : Vector2i = get_used_rect().size
	var offset : Vector2i = get_used_rect().position
	
	var tEdits : Dictionary[Vector2i, TerrainEdit] = {}
	#add tilemapdata to map image
	for x in tilemapSize.x:
		for y in tilemapSize.y:
			var p := Vector2i(x, y) + offset
			p.clamp(Vector2i(0, 0), Vector2i(PixelSandbox.mapSize) - Vector2i(1, 1))
			var tileIndex = get_cell_source_id(p) + 1
			
			var pChunkCoord : Vector2i = TerrainServer.worldToChunk(p)
			if tEdits.has(pChunkCoord):
				tEdits[pChunkCoord].appendTerrainChange(p, tileIndex, layer)
			else:
				tEdits[pChunkCoord] = TerrainEdit.new(pChunkCoord)
				tEdits[pChunkCoord].appendTerrainChange(p, tileIndex, layer)
			
	for k : Vector2i in tEdits.keys():
		TerrainServer.distributeTerrainEdit(tEdits[k])
	
	#Clear the tilemap
	for x in tilemapSize.x:
		for y in tilemapSize.y:
			var tileMapPos : Vector2i = Vector2i(x, y) + offset
			set_cell(tileMapPos, -1, Vector2i(0, 0), 0)
