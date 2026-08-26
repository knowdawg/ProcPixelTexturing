extends TerrainPacket
class_name ChunkStream

var chunkCoord : Vector2i #usigned 16 bit int
var chunkDataCompressed  : PackedByteArray

var applyOrder : int

static func create(chunkCoord : Vector2i, chunkDataCompressed : PackedByteArray) -> ChunkStream:
	var packet := ChunkStream.new()
	
	packet.packetType = PACKET_TYPE.CHUNK_STREAM
	packet.flag = ENetPacketPeer.FLAG_RELIABLE
	
	packet.chunkCoord = chunkCoord
	packet.applyOrder = TerrainPacket.getNextTilePacketOrder()
	packet.chunkDataCompressed = chunkDataCompressed
	
	return packet

static func createFromData(data : PackedByteArray) -> ChunkStream:
	var packet := ChunkStream.new()
	packet.decode(data)
	return packet

func encode() -> PackedByteArray:
	var buffer := StreamPeerBuffer.new()
	buffer.put_data(super.encode())
	
	#Chunk Coord
	buffer.put_u16(chunkCoord.x)
	buffer.put_u16(chunkCoord.y)
	buffer.put_u32(applyOrder)
	#Chunk Data
	buffer.put_data(chunkDataCompressed)
	
	return buffer.data_array

func decode(data : PackedByteArray) -> StreamPeerBuffer:
	var buffer : StreamPeerBuffer = super.decode(data)
	
	chunkCoord = Vector2i(
		buffer.get_u16(),
		buffer.get_u16()
	)
	applyOrder = buffer.get_32()
	chunkDataCompressed = data.slice(buffer.get_position())
	
	return buffer


func send(target : ENetPacketPeer, channel : CHANNELS = CHANNELS.BULK):
	super.send(target, channel)

func broadcast(server : ENetConnection, channel : CHANNELS = CHANNELS.BULK):
	super.broadcast(server, channel)
