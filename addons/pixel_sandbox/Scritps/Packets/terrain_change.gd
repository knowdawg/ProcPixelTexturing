extends TerrainPacket
class_name TerrainChange

enum SHAPE{
	CIRCLE,
	SQUARE
}
static var curPacketID : int = 0 #repeats every 2^16

var pos           : Vector2i
var tile          : int
var radius        : int #min: 0, max: 255 (2^8)
#Layer, Shape, isDestructive are all packed into 1 byte
var layer         : PixelSandbox.LAYER
var shape         : SHAPE
var isDestructive : bool #Whether the edit only applies to empty tiles or to all tiles

var authorID      : int #Client that made the original change
var packetID      : int
var applyOrder    : int #The order in which the changes were applied. UNSET_ORDER if not yet set by server


func setOrder():
	applyOrder = TerrainPacket.getNextTilePacketOrder()


static func create(
	pos : Vector2i,
	tile : int,
	radius : int,
	layer : PixelSandbox.LAYER,
	shape : SHAPE,
	isDestructive : bool
	) -> TerrainChange:
	var packet := TerrainChange.new()
	
	packet.pos = pos.clamp(Vector2i(-2147483648, -2147483648), Vector2i(2147483647, 2147483647))
	packet.packetType = PACKET_TYPE.TERRAIN_CHANGE
	packet.flag = ENetPacketPeer.FLAG_RELIABLE
	
	packet.tile = tile
	packet.radius = radius
	
	packet.layer = clamp(layer, 0, 1)
	packet.shape = clamp(shape, 0, 1)
	packet.isDestructive = isDestructive
	
	packet.authorID = ClientNetworkGlobals.id
	packet.packetID = curPacketID
	curPacketID = (curPacketID + 1) % 65536 #(2^16)
	
	packet.applyOrder = UNSET_ORDER
	
	return packet

static func createFromData(data : PackedByteArray) -> TerrainChange:
	var packet := TerrainChange.new()
	packet.decode(data)
	return packet

func encode() -> PackedByteArray:
	var buffer := StreamPeerBuffer.new()
	buffer.put_data(super.encode())
	
	buffer.put_32(pos.x)
	buffer.put_32(pos.y)
	buffer.put_u8(tile)
	buffer.put_u8(radius)
	
	var packedVars : int = 0
	packedVars |= layer << 2
	packedVars |= shape << 1
	packedVars |= int(isDestructive)
	buffer.put_u8(packedVars)
	
	buffer.put_u8(authorID)
	buffer.put_u16(packetID)
	
	buffer.put_u32(
		clamp(applyOrder, 0, UNSET_ORDER)
		)
	
	return buffer.data_array

func decode(data : PackedByteArray) -> StreamPeerBuffer:
	var buffer : StreamPeerBuffer = super.decode(data)
	
	pos = Vector2i(
		buffer.get_32(),
		buffer.get_32()
	)
	tile = buffer.get_u8()
	radius = buffer.get_u8()
	
	var packedVars : int = buffer.get_u8()
	layer = (packedVars >> 2) & 0x1
	shape = (packedVars >> 1) & 0x1
	isDestructive = bool((packedVars) & 0x1)
	
	authorID = buffer.get_u8()
	packetID = buffer.get_u16()
	
	applyOrder = buffer.get_u32()
	
	return null #No bytes remaining


func send(target : ENetPacketPeer, channel : CHANNELS = CHANNELS.CRITICAL):
	super.send(target, channel)

func broadcast(server : ENetConnection, channel : CHANNELS = CHANNELS.CRITICAL):
	super.broadcast(server, channel)
