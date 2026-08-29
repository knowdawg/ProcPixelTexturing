extends Node
"""
Manages Chunks and Terraian Data
"""

#Signals
signal dirtyChunkBroadcast(c : Array[WorldChunk])

var chunkScene = preload("uid://bnwh18w01rigl")
#All chunks in the world, keyed on thier position in chunk space
var chunks       : Dictionary[Vector2i, WorldChunk]
#All chunks in the render quadrant of all active WorldViews
var activeChunks : Dictionary[Vector2i, WorldChunk]
var dirtyChunks  : Dictionary[Vector2i, WorldChunk]

#client id to that clinets world view. Only 1 for a client, many for a server
var activeWorldViews : Dictionary[int, WorldView]

"""Server Variables"""
#clientID to Chunks that need to be streamed to them
var clientChunkStreamQueue : Dictionary[int, Array] = {}

"""Client Variables"""
#Group together similar terrain changes and only send them at server tick rate
var queuedTerrainChanges : Array[TerrainChange]

func _ready() -> void:
	createChunks()
	
	NetworkManager.onServerStarted.connect(startServer)
	NetworkManager.onClientStarted.connect(startClient)
	

"""START SERVER"""
#Create a world view whenever a client connects
#Errase a client's world view when they disconnect
func startServer():
	NetworkManager.onClientConnected.connect(newClient)
	NetworkManager.onClientDisconnected.connect(clientDisconect)
	ServerNetworkGlobals.onPlayerViewPositionRecieved.connect(receivePlayerViewPosition)
	ServerNetworkGlobals.onPlayerTerrainChangeRecieved.connect(receiveTerrainChangeFromClient)
	ServerNetworkGlobals.onChunkStreamRequest.connect(recieveChunkStreamRequest)
	
func newClient(newID : int):
	activeWorldViews[newID] = WorldView.new()
	clientChunkStreamQueue[newID] = []
	
func clientDisconect(clientID : int):
	activeWorldViews.erase(clientID)
	clientChunkStreamQueue.erase(clientID)


"""START CLIENT"""
#Create ones own worldview when id is recieved
func startClient():
	ClientNetworkGlobals.onIDAssigned.connect(IDRecieved)
	ClientNetworkGlobals.onChunkStreamRevieved.connect(receiveChunkPacket)
	ClientNetworkGlobals.onTerrainChangeRecieved.connect(receiveTerrainChangeFromServer)
	ClientNetworkGlobals.onChunkHashRevieved.connect(receiveChunkHashPacket)
	
func IDRecieved(id : int):
	activeWorldViews[id] = WorldView.new()

func _physics_process(delta: float) -> void:
	updateWorld(delta)

"""
UPDATE PIPELINE:
	Update Loaded Rect
	Update Chunks
"""

var t := 0.0
func updateWorld(delta):
	t += delta
	if NetworkManager.isServer: #Server TerrainServer runs on a set tick rate
		var tickThreshold : float = 1.0 / PixelSandbox.terrainServerTicksPerSecond
		if t < tickThreshold:
			return
		t -= tickThreshold
	
	#Send Client Data To Server
	if !NetworkManager.isServer:
		var tickThreshold : float = 1.0 / PixelSandbox.clientFlushesPerSecond
		if t > tickThreshold:
			t -= tickThreshold
			_sendQueuedTerrainChanges()
			sendPlayerViewPostionToServer()
			ClientNetworkGlobals.flushToServer()
	
	#Update World Views
	for view : WorldView in activeWorldViews.values():
		updateWorldViewLoadedRect(view)
	for id : int in activeWorldViews.keys():
		var view : WorldView = activeWorldViews[id]
		updateWorldViewActiveChunks(id, view)
	
	updateChunks(delta)
	
	#Stream new chunks to clients
	if NetworkManager.isServer:
		for id in clientChunkStreamQueue.keys():
			var newChunks : Array = clientChunkStreamQueue[id] as Array[WorldChunk]
			var totalBytesSent : int = 0
			while newChunks:
				var curChunk : WorldChunk = newChunks.pop_front()
				totalBytesSent += sendChunkToClient(id, curChunk)
				
				#Limmit the number of bytes sent to each client each tick
				if totalBytesSent > ServerNetworkGlobals.MAX_SENT_BYTES_PER_TICK:
					break
		NetworkManager.connection.flush()

"""
CHUNK PIPELINE:
	Calculate active chunks based on a WorldView, new chunks are dirtied.
	Update all Active Chunks. (This is where terrarin edits are applied)
	Clear Dirty Chunks.
"""
func updateChunks(delta : float) -> void:
	var prevChunks : Dictionary[Vector2i, WorldChunk] = activeChunks
	activeChunks = {}
	
	#Add all chunks in world views
	for view : WorldView in activeWorldViews.values():
		for coord : Vector2i in view.activeChunks.keys():
			var viewChunk : WorldChunk = view.activeChunks[coord]
			activeChunks[coord] = viewChunk
	
	#Activate new chunks
	for k : Vector2i in activeChunks.keys():
		var chunk : WorldChunk = activeChunks[k]
		if !prevChunks.has(k):
			chunk.activate()
	
	#De-activate chunks that are no longer in a worldview
	for k : Vector2i in prevChunks.keys():
		var chunk : WorldChunk = prevChunks[k]
		if !activeChunks.has(k):
			chunk.deActivate()
	
	#Update all active Chunks
	for k : Vector2i in activeChunks.keys():
		var chunk : WorldChunk = activeChunks[k]
		var changes : bool = chunk.updateChunk(delta)
		if changes:
			dirtyChunkGroup(k)
		
		#if the chunk is desynced, request the full chunk from the server
		if (chunk.desync == true and chunk.timeUntilChunkStreamRequest <= 0.0) and !NetworkManager.isServer:
			print("Requesting Re-sycn")
			chunk.timeUntilChunkStreamRequest = chunk.CHUNK_STREAM_REQUEST_DELAY
			sendChunkStreamRequest(chunk.chunkCoord)
		
		#If enough time has passed since the last edit on the server, send a chunk hash packet to all clients with that active chunk
		if (chunk.timeSinceLastEdit > 1.0 and chunk.verificationSent == false) and NetworkManager.isServer:
			var packet := ChunkHash.create(
				chunk.chunkCoord,
				chunk.chunkHash,
				chunk.mostRecentGraduatedEdit.applyOrder if chunk.mostRecentGraduatedEdit else 0
			)
			for id in activeWorldViews.keys():
				if activeWorldViews[id].activeChunks.has(chunk.chunkCoord):
					packet.send(NetworkManager.clients[id])
					chunk.verificationSent = true
	
	#Broadcast the dirty chunks for TerrainRendering to intercept
	dirtyChunkBroadcast.emit(dirtyChunks.values())
	dirtyChunks.clear()


func updateWorldViewLoadedRect(view : WorldView) -> void:
	var centerChunk := worldToChunk(view.position)
	var chunkDementions : int = int(float(PixelSandbox.renderSectionSize) / float(PixelSandbox.chunkSize))
	var topLeftChunkOffset : int = int(float(chunkDementions) / 2.0)
	
	var newLoadedRect := Rect2(0.0, 0.0, 0.0, 0.0)
	var topLeftChunkCoord : Vector2i = centerChunk - Vector2i(topLeftChunkOffset, topLeftChunkOffset)
	var numOfChunks := Vector2i(int(float(PixelSandbox.mapSize.x) / float(PixelSandbox.chunkSize)), int(float(PixelSandbox.mapSize.y) / float(PixelSandbox.chunkSize)))
	if topLeftChunkCoord.x < numOfChunks.x - 1 and topLeftChunkCoord.y < numOfChunks.y - 1:
		newLoadedRect.size = Vector2(PixelSandbox.renderSectionSize, PixelSandbox.renderSectionSize)
		if topLeftChunkCoord.x < 0:
			newLoadedRect.position.x = 0.0
			newLoadedRect.size.x += topLeftChunkCoord.x * PixelSandbox.chunkSize
		else:
			newLoadedRect.position.x = topLeftChunkCoord.x * PixelSandbox.chunkSize
		if topLeftChunkCoord.y < 0:
			newLoadedRect.position.y = 0.0
			newLoadedRect.size.y += topLeftChunkCoord.y * PixelSandbox.chunkSize
		else:
			newLoadedRect.position.y = topLeftChunkCoord.y * PixelSandbox.chunkSize
		if topLeftChunkCoord.x >= 0 and topLeftChunkCoord.y >= 0:
			newLoadedRect.position = chunks[topLeftChunkCoord].global_position
		view.loadedRect = newLoadedRect


func updateWorldViewActiveChunks(id : int, view : WorldView):
	var prevChunks : Dictionary[Vector2i, WorldChunk] = view.activeChunks
	view.activeChunks = {}
	
	#Fetch new active chunks
	var centerChunk := worldToChunk(view.position)
	var topLeftChunk := centerChunk - (loadedRectSizeInChunks() / 2)
	for x in range(loadedRectSizeInChunks().x):
		for y in range(loadedRectSizeInChunks().y):
			var curCoord : Vector2i = topLeftChunk + Vector2i(x, y)
			
			curCoord = clampChunkCoord(curCoord)
			view.activeChunks[curCoord] = chunks[curCoord]
	
	#Stream new chunks to clients
	if NetworkManager.isServer:
		for k : Vector2i in view.activeChunks.keys():
			var chunk : WorldChunk = view.activeChunks[k]
			if !prevChunks.has(k): #new chunk
				if clientChunkStreamQueue[id].has(chunk): continue #dont add duplicates
				clientChunkStreamQueue[id].append(chunk)

"""--- Chunk Helper Functions ---"""

func createChunks() -> void:
	for x in worldSizeInChunks().x:
		for y in worldSizeInChunks().y:
			var c : WorldChunk = chunkScene.instantiate()
			var coord := Vector2i(x,y)
			chunks[coord] = c
			add_child(c)
			c.setup(PixelSandbox.chunkSize, coord)

func dirtyChunk(chunkCoord : Vector2i) -> void:
	dirtyChunks[chunkCoord] = chunks[chunkCoord]

#Dirty Chunks in a 3x3 Grid
func dirtyChunkGroup(chunkCoord : Vector2i) -> void:
	for i in range(-1, 2):
		for j in range(-1, 2):
			var coord : Vector2i = chunkCoord + Vector2i(i, j)
			coord = clampChunkCoord(coord)
			dirtyChunks[coord] = chunks[coord]

func dirtyAllChunks():
	dirtyChunks = chunks.duplicate()

func clampChunkCoord(coord : Vector2i) -> Vector2i:
	return coord.clamp(
		Vector2i(0, 0),
		worldSizeInChunks() - Vector2i(1, 1)
	)

func worldToChunk(pos : Vector2) -> Vector2i:
	var chunkCoord := floor(pos / float(PixelSandbox.chunkSize))
	return chunkCoord
	
#Returns the tile data for a given chunkCoord
func getChunkTileData(chunkCoord : Vector2i) -> PackedByteArray:
	var clampedCoord : Vector2i = clampChunkCoord(chunkCoord)
	return chunks[clampedCoord].tileData



"""--- World Helper Functions ---"""
func worldSizeInChunks() -> Vector2i:
	return PixelSandbox.mapSize / PixelSandbox.chunkSize
	
func loadedRectSizeInChunks() -> Vector2i:
	return Vector2i(PixelSandbox.renderSectionSize, PixelSandbox.renderSectionSize) / PixelSandbox.chunkSize

#Return all world views containing the passed in point
func pointToWorldViews(point : Vector2) -> Dictionary[int, WorldView]:
	var worldViewContainers : Dictionary[int, WorldView]
	for id in activeWorldViews.keys():
		var view : WorldView = activeWorldViews[id]
		if !view.loadedRect:
			continue
		if view.loadedRect.has_point(point):
			worldViewContainers[id] = view
	return worldViewContainers

func getTile(pos : Vector2i, layer : int) -> int:
	if pos.x < 0 or pos.x > PixelSandbox.mapSize.x - 1:
		return 0
	if pos.y < 0 or pos.y > PixelSandbox.mapSize.y - 1:
		return 0
	
	#convert to chunk space
	var ownerChunkCoord : Vector2i = worldToChunk(pos)
	var ownerChunk : WorldChunk = chunks[ownerChunkCoord]
	return ownerChunk.getTile(pos, layer)

#Distributes the given terrain edit to the corect chunk.
func applyTerrainEdit(tEdit : TerrainEdit):
	var ownerChunk : WorldChunk = chunks[tEdit.destinationChunkCoord]
	ownerChunk.addTerrainEditToQueue(tEdit)
	


"""--- All Terrain Changes go through here ---"""
func makeTerrainChange(
	worldPosition : Vector2i,
	tileIndex : int,
	radius : int,
	layer : PixelSandbox.LAYER,
	shape : TerrainChange.SHAPE,
	isDestructive : bool
):
	var tChange := TerrainChange.create(
		worldPosition,
		tileIndex,
		radius,
		layer,
		shape,
		isDestructive
	)
	
	_makeTerrainChangeFromPacket(tChange) #Apply the terrain change imidietly
	if NetworkManager.isServer:
		return
	else:#batch packets
		_addTerrainChangeToQueue(tChange)

#Group together similar terrain changes into one packet
func _addTerrainChangeToQueue(change : TerrainChange) -> void:
	for queuedChange : TerrainChange in queuedTerrainChanges:
		if queuedChange.canMerge(change):
			queuedChange.mergeWith(change)
			return
	queuedTerrainChanges.append(change)

func _sendQueuedTerrainChanges() -> void:
	if queuedTerrainChanges.size() == 0: return
	
	for change : TerrainChange in queuedTerrainChanges:
		if !NetworkManager.isServer:
			change.send(NetworkManager.server)
	queuedTerrainChanges.clear()

func _makeTerrainChangeFromPacket(change : TerrainChange):
	var totalEdits : Array[TerrainEdit] = []
	for i in range(change.points.size()):
		var point := change.points[i]
		var packetID := change.packetIDs[i]
		var tEdits : Dictionary[Vector2i, TerrainEdit] = {} #Terrain Edits for this point
		for x in range(-change.radius, change.radius + 1):
			for y in range(-change.radius, change.radius + 1):
				var offset = Vector2i(x, y)
				
				if change.shape == TerrainChange.SHAPE.SQUARE or _isInCircle(offset, change.radius):
					var p : Vector2i = point + offset
					p = p.clamp(Vector2i(0, 0), Vector2i(PixelSandbox.mapSize) - Vector2i(1, 1))
					
					var pChunkCoord : Vector2i = worldToChunk(p)
					if tEdits.has(pChunkCoord):
						tEdits[pChunkCoord].appendTerrainChange(p, change.tile, change.layer, change.isDestructive)
					else:
						tEdits[pChunkCoord] = TerrainEdit.new(
							pChunkCoord, change.authorID, packetID, change.applyOrder 
						)
						tEdits[pChunkCoord].appendTerrainChange(p, change.tile, change.layer, change.isDestructive)
		totalEdits.append_array(tEdits.values())
	for tEdit : TerrainEdit in totalEdits:
		applyTerrainEdit(tEdit)

func _isInCircle(offset : Vector2i, radius : int) -> bool:
	if offset.length() <= float(radius) + 0.5:
		return true
	return false


"""--- Packet Creation ---"""
#Server ->
func sendChunkToClient(clientID : int, chunk : WorldChunk) -> int:
	var snapshot : PackedByteArray = chunk.getSnapshot()
	ChunkStream.create(
		chunk.chunkCoord, snapshot
	).send(NetworkManager.clients[clientID])
	
	return snapshot.size()

#Client ->
func sendPlayerViewPostionToServer():
	if !activeWorldViews.has(ClientNetworkGlobals.id): return #No Worldview yet
	if !is_instance_valid(get_viewport().get_camera_2d()): return
	#Update the client worldview to be on the camera
	activeWorldViews[ClientNetworkGlobals.id].position = (
		get_viewport().get_camera_2d().get_screen_center_position()
	)
	var newPos = activeWorldViews[ClientNetworkGlobals.id].position
	
	PlayerViewPosition.create(
		newPos
	).send(NetworkManager.server)

func sendChunkStreamRequest(chunkCoord : Vector2i):
	ChunkStreamRequest.create(
		chunkCoord
	).send(NetworkManager.server)

"""--- Packet Recieption ---"""
# -> Client
func receiveChunkPacket(packet : ChunkStream):
	var recievedChunk : WorldChunk = chunks[packet.chunkCoord]
	recievedChunk.applySnapshot(packet)

# -> Server
func receivePlayerViewPosition(id : int, packet : PlayerViewPosition):
	activeWorldViews[id].position = packet.pos

# -> Server
func receiveTerrainChangeFromClient(id : int, packet : TerrainChange):
	packet.setOrder()
	_makeTerrainChangeFromPacket(packet)
	packet.broadcast(NetworkManager.connection)

# -> Client
func receiveTerrainChangeFromServer(packet : TerrainChange):
	_makeTerrainChangeFromPacket(packet)

# -> Client
func receiveChunkHashPacket(packet : ChunkHash):
	var chunkToCheck : WorldChunk = chunks[packet.chunkCoord]
	chunkToCheck.verificationPacket = packet #The chunk will run verification on it on its next update
	chunkToCheck.forceDirty = true

# -> Server
func recieveChunkStreamRequest(id : int, packet : ChunkStreamRequest):
	sendChunkToClient(id, chunks[packet.chunkCoord])
