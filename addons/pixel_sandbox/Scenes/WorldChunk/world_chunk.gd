extends Node2D
class_name WorldChunk

#Debug
var visualizeChunk : bool = true

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

"""
Hash
"""
var tileDataHash : int = 0

"""Collision"""
var bitmap : BitMap
var polygons : Array[PackedVector2Array]
var collPolys : Array[CollisionPolygon2D] = []

"""
The Edit array stores all the edits from the previous terrain tick.
When the chunk is updated, it iterates through each edit and applies it to tileData
"""
var edits : Array[TerrainEdit] = []
var newLocalEdits : Array[TerrainEdit] = [] #add local edits here
var localEdits : Array[TerrainEdit] = [] #local edits live here after being applied

"""
Rollback
"""
const EDIT_BUFFER_MAX_SIZE  : int = 32
var tileDataRollback        : PackedByteArray
var tileDataHashRollback    : int = 0
var editRollbackBuffer      : Array[TerrainEdit] = [] #Stores the 64 most recent terrain edits

var mostRecentGraduatedEdit : TerrainEdit

"""
Verification
"""
var timeSinceLastEdit : float = 0.0
var verificationSent : bool = false #Whether the server has sent a ChunkHash verification packet for this chunk.
var verificationPacket : ChunkHash

"""
De-Sync
"""
const CHUNK_STREAM_REQUEST_DELAY : float = 1.0 #Amount of type between requesting a chunk sync when de-synced
var timeUntilChunkStreamRequest : float = 0.0

var desync : bool = false
var forceDirty : bool = false

func _process(delta: float) -> void:
	visible = visualizeChunk
	if desync:
		modulate.a = 0.5
	else:
		modulate.a = 0.1

func setup(chunk_size : int, chunk_coord : Vector2i):
	chunkSize = chunk_size
	chunkCoord = chunk_coord
	
	global_position = (chunkSize * chunkCoord)
	
	tileData.resize(chunkSize * chunkSize * 4) #4 bytes for 4 color channels
	recalculateHash()
	
	bitmap = BitMap.new()
	
	tileDataRollback.resize(chunkSize * chunkSize * 4)

func addTerrainEditToQueue(tEdit : TerrainEdit):
	if NetworkManager.isServer:
		edits.append(tEdit)
		return
	
	if mostRecentGraduatedEdit:
		if tEdit.applyOrder < mostRecentGraduatedEdit.applyOrder:
			desync = true
			return
	
	if tEdit.authorID != ClientNetworkGlobals.id:
		edits.append(tEdit)
		return
	
	if tEdit.applyOrder == TerrainChange.UNSET_ORDER: #local edit
		newLocalEdits.append(tEdit)
		return
	
	#If this is my terrain edit coming back from the server then it is confirmed. Remove it from local edits and add it to edits
	for i : int in range(localEdits.size()):
		var e : TerrainEdit = localEdits[i]
		if e.packetID == tEdit.packetID:
			localEdits.remove_at(i)
			break
	edits.append(tEdit)

"""Applies all queued TerrainEdits. Returns true if changes were made, false if not"""
func updateChunk(delta : float) -> bool:
	timeSinceLastEdit += delta
	timeUntilChunkStreamRequest -= delta
	
	for tEdit : TerrainEdit in localEdits:
		if tEdit.isTimedOut():
			forceDirty = true
	
	if edits.size() == 0 and newLocalEdits.size() == 0 and !forceDirty:
		return false
	forceDirty = false
	
	#Update data
	applyTerrainEdits()
	timeSinceLastEdit = 0
	verificationSent = false
	
	if verificationPacket:
		if isChunkInSyncWith(verificationPacket) == false:
			desync = true
		verificationPacket = null
	
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
	
	$Label.text = "Hash: \n" + str(tileDataHash)
	
	return true


func applyTerrainEdits():
	if NetworkManager.isServer:
		#Server does not need rollback, it is the source of truth. Edits automaticaly graduate
		for tEdit : TerrainEdit in edits:
			for j in range(tEdit.layers.size()):
				var idx = localToArray(tEdit.localPositions[j], tEdit.layers[j])
				var newTile = clamp(tEdit.tileIndexs[j], 0, 255)
				var oldTile : int = tileData[idx]
				if oldTile == newTile: continue
				
				tileDataHash ^= _getByteHash(idx, oldTile) ^ _getByteHash(idx, newTile)
				tileData[idx] = newTile
			mostRecentGraduatedEdit = tEdit
		edits.clear()
		return
	
	#Insert newLocalEdits into localEdits
	localEdits.append_array(newLocalEdits)
	newLocalEdits.clear()
	
	#Insert new edits into the sorted buffer
	for newEdit : TerrainEdit in edits:
		var insertIdx : int = editRollbackBuffer.bsearch_custom(
			newEdit,
			func(a : TerrainEdit, b : TerrainEdit) -> bool:
				return a.applyOrder < b.applyOrder
		)
		
		editRollbackBuffer.insert(insertIdx, newEdit)
	edits.clear()
	
	
	"""Apply Graduating Edits"""
	#This many edits at the front of the array will become permenant
	var graduatingEditCount : int = max(0, editRollbackBuffer.size() - EDIT_BUFFER_MAX_SIZE)
	#Apply the graduating edits
	for i : int in range(graduatingEditCount):
		var tEdit : TerrainEdit = editRollbackBuffer[i]
		
		for j in range(tEdit.layers.size()):
			var idx = localToArray(tEdit.localPositions[j], tEdit.layers[j])
			var newTile = clamp(tEdit.tileIndexs[j], 0, 255)
			var oldTile : int = tileDataRollback[idx]
			if oldTile == newTile: continue
			
			#Undo Old Byte Hash and apply the new one
			tileDataHashRollback ^= _getByteHash(idx, oldTile) ^ _getByteHash(idx, newTile)
			#Apply the actualy data change
			tileDataRollback[idx] = newTile
		mostRecentGraduatedEdit = tEdit
	
	#Prune the graduated elements
	if graduatingEditCount > 0:
		editRollbackBuffer = editRollbackBuffer.slice(graduatingEditCount)
	
	"""Apply Rollback Edits"""
	#Reset to rollback state
	tileDataHash = tileDataHashRollback
	tileData = tileDataRollback.duplicate()
	
	#Replay rollback edits
	for tEdit : TerrainEdit in editRollbackBuffer:
		for j in range(tEdit.layers.size()):
			var idx = localToArray(tEdit.localPositions[j], tEdit.layers[j])
			var newTile = clamp(tEdit.tileIndexs[j], 0, 255)
			var oldTile : int = tileData[idx]
			if oldTile == newTile: continue
			
			tileDataHash ^= _getByteHash(idx, oldTile) ^ _getByteHash(idx, newTile)
			tileData[idx] = newTile
	
	
	"""Apply local edits"""
	#Clear all timed out Local Terrain Edits
	var localEditsPruned : Array[TerrainEdit] = []
	for tEdit : TerrainEdit in localEdits:
		if tEdit.isTimedOut():
			desync = true
			continue
		localEditsPruned.append(tEdit)
	localEdits = localEditsPruned
	
	#Replay Local Edits
	for tEdit : TerrainEdit in localEdits:
		for j in range(tEdit.layers.size()):
			var idx = localToArray(tEdit.localPositions[j], tEdit.layers[j])
			var newTile = clamp(tEdit.tileIndexs[j], 0, 255)
			var oldTile : int = tileData[idx]
			if oldTile == newTile: continue
			
			tileDataHash ^= _getByteHash(idx, oldTile) ^ _getByteHash(idx, newTile)
			tileData[idx] = newTile


"""
Verifies Chunk against a chunkhash packet.
Return true if the hashes match, false if they do not
"""
func isChunkInSyncWith(packet : ChunkHash) -> bool:
	if mostRecentGraduatedEdit:
		if packet.mostRecentTerrainEdit < mostRecentGraduatedEdit.applyOrder: #Outdated verification
			return true
		
		if packet.mostRecentTerrainEdit == mostRecentGraduatedEdit.applyOrder:
			if packet.chunkHash == tileDataHashRollback:
				return true
	
	var checkHash = tileDataHashRollback
	var checkData = tileDataRollback.duplicate()
	for tEdit : TerrainEdit in editRollbackBuffer:
		for j in range(tEdit.layers.size()):
			var idx = localToArray(tEdit.localPositions[j], tEdit.layers[j])
			var newTile = clamp(tEdit.tileIndexs[j], 0, 255)
			var oldTile : int = checkData[idx]
			if oldTile == newTile: continue
			
			checkHash ^= _getByteHash(idx, oldTile) ^ _getByteHash(idx, newTile)
			checkData[idx] = newTile
		if tEdit.applyOrder == packet.mostRecentTerrainEdit:
			if checkHash == packet.chunkHash:
				return true
			return false
	
	if tileDataHash == packet.chunkHash:
		return true
	
	
	return false


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


"""Outward facing tile query function"""
func getTile(tilePos : Vector2i, layer : PixelSandbox.LAYER) -> int:
	var arrayIndex = worldToArray(tilePos, layer)
	if arrayIndex == -1: #error in the world to array function
		return 0
	var tile : int = tileData[arrayIndex]
	return tile

"""Draw Chunk Borders"""
func _draw() -> void:
	var c : Color
	if isActive:
		c = Color.LIME_GREEN
		if (chunkCoord.x + chunkCoord.y) % 2 == 0:
			c = Color.DARK_GREEN
	if !isActive:
		c = Color.RED
		if (chunkCoord.x + chunkCoord.y) % 2 == 0:
			c = Color.DARK_RED
	draw_rect(Rect2(Vector2(1.0, 1.0), Vector2(chunkSize - 1, chunkSize - 1)), c, false, 1.0, false)

func activate():
	isActive = true
	$StaticBody2D.process_mode = ProcessMode.PROCESS_MODE_INHERIT
	queue_redraw()

func deActivate():
	isActive = false
	$StaticBody2D.process_mode = ProcessMode.PROCESS_MODE_DISABLED
	queue_redraw()


#Calculates a unique hash for a value at a specific array index
func _getByteHash(index : int, val : int) -> int:
	var h : int = (index * 0x45d9f3b) ^ ((val + 1) * 0x119de1f3)
	h = ((h >> 16) ^ h) * 0x45d9f3b
	h = ((h >> 16) ^ h) * 0x45d9f3b
	h = (h >> 16) ^ h
	return h & 0x7FFFFFFF # Mask to positive 32-bit int

#Use only after a chunk stream
func recalculateHash() -> void:
	tileDataHash = 0
	for i in range(tileData.size()):
		var val = tileData[i]
		tileDataHash ^= _getByteHash(i, val)


func getSnapshot() -> PackedByteArray:
	return tileData.compress(FileAccess.COMPRESSION_ZSTD)

func applySnapshot(packet : ChunkStream) -> void:
	tileData = packet.chunkDataCompressed.decompress(tileData.size(), FileAccess.COMPRESSION_ZSTD)
	recalculateHash()
	#set rollback (confirmed) state to the snapshot
	tileDataRollback = tileData.duplicate()
	tileDataHashRollback = tileDataHash
	
	#Clear all edits that come before the snapshot
	var prunedEdits : Array[TerrainEdit] = []
	for tEdit : TerrainEdit in edits:
		if packet.applyOrder > tEdit.applyOrder : continue
		prunedEdits.append(tEdit)
	edits = prunedEdits.duplicate()
	prunedEdits.clear()
	#Clear all rollback edits that come before the snapshot
	for tEdit : TerrainEdit in editRollbackBuffer:
		if packet.applyOrder > tEdit.applyOrder : continue
		prunedEdits.append(tEdit)
	editRollbackBuffer = prunedEdits
	
	desync = false
	forceDirty = true
	timeSinceLastEdit = 0
	verificationSent = false
	verificationPacket = null
