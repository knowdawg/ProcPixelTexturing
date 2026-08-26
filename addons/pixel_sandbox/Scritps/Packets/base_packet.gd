class_name BasePacket

enum PACKET_TYPE{
	ID_ASSIGNMENT,
	PLAYER_VIEW_POSITION,
	CHUNK_STREAM,
	CHUNK_STREAM_REQUEST,
	TERRAIN_CHANGE,
	CHUNK_HASH,
}

enum CHANNELS{
	CRITICAL,
	BULK,
	MISC
}

static var curPacket : int = 0

var packetType : PACKET_TYPE

var flag : int

#Overide
func encode() -> PackedByteArray:
	var buffer := StreamPeerBuffer.new()
	buffer.put_u8(packetType)
	
	return buffer.data_array

#Overide
func decode(data : PackedByteArray) -> StreamPeerBuffer:
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = data
	
	packetType = buffer.get_u8()
	
	return buffer

#Overide for different channel
func send(target : ENetPacketPeer, channel : CHANNELS = CHANNELS.CRITICAL):
	target.send(channel, encode(), flag)

#Overide for different channel
func broadcast(server : ENetConnection, channel : CHANNELS = CHANNELS.CRITICAL):
	server.broadcast(channel, encode(), flag)
