extends BasePacket
class_name ChunkStreamRequest

"""
Sent from Client to Server when the client detects a de-sync
"""

var chunkCoord : Vector2i #uint 16

static func create(chunkCoord : Vector2i) -> ChunkStreamRequest:
	var packet := ChunkStreamRequest.new()
	
	packet.packetType = PACKET_TYPE.CHUNK_STREAM_REQUEST
	packet.flag = ENetPacketPeer.FLAG_RELIABLE
	
	packet.chunkCoord = chunkCoord
	
	return packet

static func createFromData(data : PackedByteArray) -> ChunkStreamRequest:
	var packet := ChunkStreamRequest.new()
	packet.decode(data)
	return packet

func encode() -> PackedByteArray:
	var buffer := StreamPeerBuffer.new()
	buffer.put_data(super.encode())
	
	#Chunk Coord
	buffer.put_u16(chunkCoord.x)
	buffer.put_u16(chunkCoord.y)
	
	return buffer.data_array

func decode(data : PackedByteArray) -> StreamPeerBuffer:
	var buffer : StreamPeerBuffer = super.decode(data)
	
	chunkCoord = Vector2i(
		buffer.get_u16(),
		buffer.get_u16()
	)
	
	return buffer


func send(target : ENetPacketPeer, channel : CHANNELS = CHANNELS.BULK):
	super.send(target, channel)

func broadcast(server : ENetConnection, channel : CHANNELS = CHANNELS.BULK):
	super.broadcast(server, channel)
