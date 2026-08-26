extends BasePacket
class_name PlayerViewPosition

var pos : Vector2

static func create(pos : Vector2) -> PlayerViewPosition:
	var packet := PlayerViewPosition.new()
	
	packet.packetType = PACKET_TYPE.PLAYER_VIEW_POSITION
	packet.flag = ENetPacketPeer.FLAG_UNSEQUENCED
	packet.pos = pos
	
	return packet

static func createFromData(data : PackedByteArray) -> PlayerViewPosition:
	var packet := PlayerViewPosition.new()
	packet.decode(data)
	return packet

func encode() -> PackedByteArray:
	var buffer := StreamPeerBuffer.new()
	buffer.put_data(super.encode())
	
	#position
	buffer.put_float(pos.x)
	buffer.put_float(pos.y)
	
	return buffer.data_array

func decode(data : PackedByteArray) -> StreamPeerBuffer:
	var buffer : StreamPeerBuffer = super.decode(data)
	
	pos = Vector2(
		buffer.get_float(),
		buffer.get_float()
	)
	
	return buffer
