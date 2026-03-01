extends Resource
class_name TerrainEdit

#@export var worldPositions : Array[Vector2i] = []
@export var destinationChunkCoord : Vector2i
@export var localPositions : Array[Vector2i] =[]
@export var tileIndexs : Array[int] = []
@export var layers : Array[TerrainRendering.LAYER_TYPE] = []

func _init(_destinationChunkCoord : Vector2i) -> void:
	destinationChunkCoord = _destinationChunkCoord

func appendTerrainChange(worldPosition : Vector2i, tileIndex : int, layer : TerrainRendering.LAYER_TYPE) -> void:
	var localPos : Vector2i = worldPosition % TerrainRendering.chunkSize
	localPositions.append(localPos)
	tileIndexs.append(tileIndex)
	layers.append(layer)
