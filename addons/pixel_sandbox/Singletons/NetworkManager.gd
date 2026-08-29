extends Node

#Server Signals
signal onServerStarted()
signal onClientConnected(client_id : int)
signal onClientDisconnected(client_id : int)
signal onServerPacketRecieved(client_id : int, packet : PackedByteArray)

#Client Signals
signal onClientStarted()
signal onConnectedToServer()
signal onDisconnectedFromServer()
signal onClientPacketRecieved(packet : PackedByteArray)


#Server Variables
var availableClientIds : Array = range(255, -1, -1)
var clients : Dictionary[int, ENetPacketPeer]

#Client Variables
var server : ENetPacketPeer

#General Variables
var connection : ENetConnection
var isServer : bool = false

#Debug
var bytesDownloaded : int = 0
var bytesUploaded : int = 0 #ticked up in the BasePacket class

func _physics_process(delta: float) -> void:
	if connection == null: return #Server / client not started
	
	handleEvents()



func handleEvents():
	var packetEvent : Array = connection.service()
	var eventType : ENetConnection.EventType = packetEvent[0]
	
	#Fetch all the raw packets
	var packets : Array[PackedByteArray] = []
	var peers : Array[ENetPacketPeer] = []
	while eventType != ENetConnection.EVENT_NONE:
		var peer : ENetPacketPeer = packetEvent[1]
		
		match eventType:
			ENetConnection.EVENT_RECEIVE:
				var packet := peer.get_packet()
				bytesDownloaded += packet.size()
				packets.append(packet)
				peers.append(peer)
				
			ENetConnection.EVENT_CONNECT:
				if isServer:
					clientConnected(peer)
				else:
					connectedToServer()
				
			ENetConnection.EVENT_DISCONNECT:
				if isServer:
					clientDisconnected(peer)
				else:
					disconnectedToServer()
					return
				
			ENetConnection.EVENT_ERROR:
				push_warning("Packet caused on error!")
				return
				
		packetEvent = connection.service()
		eventType = packetEvent[0]
	
	#Resolve all the packets
	for i in range(packets.size()):
		var packet := packets[i]
		var peer := peers[i]
		if isServer:
			onServerPacketRecieved.emit(peer.get_meta("id"), packet)
		else:
			onClientPacketRecieved.emit(packet)

func startServer(ipAddress : String = "127.0.0.1", port : int = 6776) -> Error:
	connection = ENetConnection.new()
	var error := connection.create_host_bound(ipAddress, port)
	if error:
		print("Server Failed to Start: ", error_string(error))
		connection = null
		return error
	
	print("Server Started!")
	isServer = true
	onServerStarted.emit()
	
	return Error.OK

func clientConnected(client : ENetPacketPeer):
	var clientID = availableClientIds.pop_back()
	client.set_meta("id", clientID)
	
	#Prevent ENet's Adaptive Throttle
	client.throttle_configure(0, 0, 0)
	#Retry sending packets in 150ms - 500ms after a congestion
	client.set_timeout(0, 150, 500)
	
	clients[clientID] = client
	
	print("Client connected with ID: ", clientID)
	onClientConnected.emit(clientID)

func clientDisconnected(client : ENetPacketPeer):
	var cleintID = client.get_meta("id")
	availableClientIds.push_back(cleintID)
	clients.erase(cleintID)
	
	print("Disconected client with ID: ", cleintID)
	onClientDisconnected.emit(cleintID)



func startClient(ipAddress : String = "127.0.0.1", port : int = 6776) -> Error:
	connection = ENetConnection.new()
	var error := connection.create_host(1)
	if error:
		print("Client Failed to Start: ", error_string(error))
		connection = null
		return error
	
	print("Client Started!")
	isServer = false
	
	server = connection.connect_to_host(ipAddress, port)
	
	onClientStarted.emit()
	
	return Error.OK

func connectedToServer():
	print("Connected To Server!")
	onConnectedToServer.emit()

func disconnectedToServer():
	print("Disconnected From Server!")
	onDisconnectedFromServer.emit()
	connection = null

func disconectClient():
	if isServer: return
	
	server.peer_disconnect()
