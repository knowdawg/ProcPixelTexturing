extends BasePacket
class_name IDAssignment

var id : int #The new ID
var remoteIDs : Array[int] #All IDs on the server


static func create(id : int, remoteIDs : Array[int]) -> IDAssignment:
	var packet := IDAssignment.new()
	
	packet.packetType = PACKET_TYPE.ID_ASSIGNMENT
	packet.flag = ENetPacketPeer.FLAG_RELIABLE
	packet.id = id
	packet.remoteIDs = remoteIDs
	
	return packet

static func createFromData(data : PackedByteArray) -> IDAssignment:
	var packet := IDAssignment.new()
	packet.decode(data)
	return packet

func encode() -> PackedByteArray:
	var buffer := StreamPeerBuffer.new()
	buffer.put_data(super.encode())
	
	#id
	buffer.put_u8(id)
	#remoteIds
	buffer.put_data(PackedByteArray(remoteIDs))
	
	return buffer.data_array

func decode(data : PackedByteArray) -> StreamPeerBuffer:
	var buffer : StreamPeerBuffer = super.decode(data)
	
	id = buffer.get_u8()
	
	while buffer.get_available_bytes() > 0:
		remoteIDs.append(buffer.get_u8())
	
	return null #buffer fetched all remaining bytes
