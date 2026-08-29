extends BasePacket
class_name ChunkHash

"""
Sent from Server to Client after a chunk becomes inactive for a bit.
Sends what SHOULD be the chunk's hash on the client side.
If the hashes dont match, or if the client does not have the most recent edit, then there is a de-sync.
Clients request full chunk stream on de-sync.
"""

var chunkCoord : Vector2i #uint 16
var chunkHash  : int #int 64
var mostRecentTerrainEdit : int #uint 32; Client verifies at THIS edit

static func create(chunkCoord : Vector2i, chunkHash : int, mostRecentTerrainEdit : int) -> ChunkHash:
	var packet := ChunkHash.new()
	
	packet.packetType = PACKET_TYPE.CHUNK_HASH
	packet.flag = ENetPacketPeer.FLAG_RELIABLE
	
	packet.chunkCoord = chunkCoord
	packet.chunkHash = chunkHash
	packet.mostRecentTerrainEdit = max(0, mostRecentTerrainEdit)
	
	return packet

static func createFromData(data : PackedByteArray) -> ChunkHash:
	var packet := ChunkHash.new()
	packet.decode(data)
	return packet

func encode() -> PackedByteArray:
	var buffer := StreamPeerBuffer.new()
	buffer.put_data(super.encode())
	
	#Chunk Coord
	buffer.put_u16(chunkCoord.x)
	buffer.put_u16(chunkCoord.y)
	#Hash
	buffer.put_64(chunkHash)
	#MostRecentEdit
	buffer.put_u32(mostRecentTerrainEdit)
	
	return buffer.data_array

func decode(data : PackedByteArray) -> StreamPeerBuffer:
	var buffer : StreamPeerBuffer = super.decode(data)
	
	chunkCoord = Vector2i(
		buffer.get_u16(),
		buffer.get_u16()
	)
	chunkHash = buffer.get_64()
	mostRecentTerrainEdit = buffer.get_u32()
	
	return buffer


func send(target : ENetPacketPeer, channel : CHANNELS = CHANNELS.CRITICAL):
	super.send(target, channel)

func broadcast(server : ENetConnection, channel : CHANNELS = CHANNELS.CRITICAL):
	super.broadcast(server, channel)
