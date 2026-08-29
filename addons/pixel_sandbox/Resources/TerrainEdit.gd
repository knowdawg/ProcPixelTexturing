"""
Discribes a change made to a a single chunk.
All changes made to the world go through a Terrain Edit.
"""

extends Resource
class_name TerrainEdit

@export var destinationChunkCoord : Vector2i

@export var localPositions : Array[Vector2i] = []
@export var tileIndexs : Array[int] = []
@export var layers : Array[PixelSandbox.LAYER] = []
@export var destructiveEdits : Array[bool] = [] #Currently Does Nothing


"""Rollback"""
const TIMEOUT_TIME_MS : int = 2000 #2 sec
var authorID       : int #Client that made the original change
var packetID       : int
var applyOrder     : int #The order in which the changes need to be applied, or INT64_MAX if local
var creationTime   : int


func _init(
	_destinationChunkCoord : Vector2i = Vector2i(-1, -1),
	_authorID : int = -1,
	_packetID : int = -1,
	_applyOrder : int = TerrainChange.UNSET_ORDER
) -> void:
	destinationChunkCoord = _destinationChunkCoord
	authorID = _authorID
	packetID = _packetID
	applyOrder = _applyOrder
	
	creationTime = Time.get_ticks_msec()

func isTimedOut() -> bool:
	if applyOrder == TerrainChange.UNSET_ORDER and Time.get_ticks_msec() > creationTime + TIMEOUT_TIME_MS:
		return true
	return false

func appendTerrainChange(worldPosition : Vector2i, tileIndex : int, layer : PixelSandbox.LAYER, isDestructive : bool) -> void:
	var localPos : Vector2i = worldPosition % PixelSandbox.chunkSize
	
	localPositions.append(localPos)
	tileIndexs.append(tileIndex)
	layers.append(layer)
	destructiveEdits.append(isDestructive)
