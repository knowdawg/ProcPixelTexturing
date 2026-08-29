extends BasePacket
class_name TerrainPacket

const UNSET_ORDER : int = UINT32_MAX

"""
Base Class for packets that deal with terrain.
"""

static var tilePacketOrder : int = 0 #Order in which packets were applied. Repeats ever 2^32
static func getNextTilePacketOrder() -> int:
	tilePacketOrder = (tilePacketOrder + 1) % (UNSET_ORDER - 1) #(UINT32_MAX is reserved for UNSET_ORDER)
	return tilePacketOrder
static func getCurrentTilePacketOrder() -> int:
	return tilePacketOrder
