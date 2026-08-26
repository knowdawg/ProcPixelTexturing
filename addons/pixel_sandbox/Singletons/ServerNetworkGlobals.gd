extends Node

#Consts
const MAX_SENT_BYTES_PER_TICK : int = 1000

#signals
signal onPlayerViewPositionRecieved(clientID : int, packet : PlayerViewPosition)
signal onPlayerTerrainChangeRecieved(clientID : int, packet : TerrainChange)
signal onChunkStreamRequest(clientID : int, packet : ChunkStreamRequest)

var clientIDs : Array[int]

func _ready() -> void:
	NetworkManager.onClientConnected.connect(onClientConnected)
	NetworkManager.onClientDisconnected.connect(onClientDisconnected)
	NetworkManager.onServerPacketRecieved.connect(onClientPacketRecieved)
	

"""New client connected, give it an ID"""
func onClientConnected(id : int):
	clientIDs.append(id)
	
	IDAssignment.create(id, clientIDs).broadcast(
		NetworkManager.connection
	)

func onClientDisconnected(id : int):
	clientIDs.erase(id)
	
	#Notify Clients that the peer left: IP
	

func onClientPacketRecieved(clientID : int, data : PackedByteArray):
	var packetType : BasePacket.PACKET_TYPE = data.decode_u8(0)
	
	match packetType:
		BasePacket.PACKET_TYPE.PLAYER_VIEW_POSITION:
			onPlayerViewPositionRecieved.emit(
				clientID,
				PlayerViewPosition.createFromData(data)
			)
		
		BasePacket.PACKET_TYPE.TERRAIN_CHANGE:
			#if randi_range(0, 5) != 0: return #Force server to drop packets
			onPlayerTerrainChangeRecieved.emit(
				clientID,
				TerrainChange.createFromData(data)
			)
			
		BasePacket.PACKET_TYPE.CHUNK_STREAM_REQUEST:
			onChunkStreamRequest.emit(
				clientID,
				ChunkStreamRequest.createFromData(data)
			)
			
		_:
			push_error("Packet of unknown type: ", packetType, " recieved!")
