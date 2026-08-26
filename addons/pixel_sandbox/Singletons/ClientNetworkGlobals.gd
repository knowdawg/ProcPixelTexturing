extends Node

#Signals
signal onIDAssigned(newID : int)
signal onRemoteIDAdded(newID : int)

signal onChunkStreamRevieved(packet : ChunkStream)
signal onTerrainChangeRecieved(packet : TerrainChange)
signal onChunkHashRevieved(packet : ChunkHash)

var id : int = -1
var remoteIDs : Array[int] = []

func _ready() -> void:
	NetworkManager.onClientPacketRecieved.connect(onClientPacketRecieved)


func onClientPacketRecieved(data : PackedByteArray):
	var packetType : BasePacket.PACKET_TYPE = data.decode_u8(0)
	
	match packetType:
		BasePacket.PACKET_TYPE.ID_ASSIGNMENT:
			manageIDs(IDAssignment.createFromData(data))
			
		BasePacket.PACKET_TYPE.CHUNK_STREAM:
			onChunkStreamRevieved.emit(ChunkStream.createFromData(data))
			
		BasePacket.PACKET_TYPE.TERRAIN_CHANGE:
			onTerrainChangeRecieved.emit(TerrainChange.createFromData(data))
			
		BasePacket.PACKET_TYPE.CHUNK_HASH:
			onChunkHashRevieved.emit(ChunkHash.createFromData(data))
			
		_:
			push_error("Packet of unknown type: ", packetType, " recieved!")


func manageIDs(packet : IDAssignment):
	if id == -1: #Curently has no ID, this packet is my assignment
		id = packet.id
		onIDAssigned.emit(id)
		
		for remoteID in packet.remoteIDs:
			remoteIDs.append(remoteID)
			onRemoteIDAdded.emit(remoteID)
	else: #New ID incoming, add it to remoteIDs
		remoteIDs.append(packet.id)
		onRemoteIDAdded.emit(packet.id)
