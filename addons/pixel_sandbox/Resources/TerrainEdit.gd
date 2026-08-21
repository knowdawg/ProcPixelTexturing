"""
Discribes a change made to a a single chunk.
All changes made to the world go through a Terrain Edit.
"""

extends Resource
class_name TerrainEdit

@export var destinationChunkCoord : Vector2i
@export var localPositions : Array[Vector2i] =[]
@export var tileIndexs : Array[int] = []
@export var layers : Array[PixelSandbox.LAYER] = []

func _init(_destinationChunkCoord : Vector2i) -> void:
	destinationChunkCoord = _destinationChunkCoord

func appendTerrainChange(worldPosition : Vector2i, tileIndex : int, layer : PixelSandbox.LAYER) -> void:
	var localPos : Vector2i = worldPosition % PixelSandbox.chunkSize
	localPositions.append(localPos)
	tileIndexs.append(tileIndex)
	layers.append(layer)
