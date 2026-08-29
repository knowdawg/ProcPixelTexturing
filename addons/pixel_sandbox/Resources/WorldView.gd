extends Resource
class_name WorldView

"""
All players have a worldview which drives TerrainServer's new / active chunks
"""

var clientID : int
var position : Vector2

var loadedRect : Rect2i

#Active chunks under THIS worldview
var activeChunks : Dictionary[Vector2i, WorldChunk]
