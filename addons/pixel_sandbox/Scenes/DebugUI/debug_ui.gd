extends CanvasLayer
class_name DebugUI

var t : float = 0.0
#How often the volitile text updates
var updateInterval : float = 0.5
var framesSincelastInterval : int = 0

#Frame
var highestFrameTime : float = -1.0
var lowestFrameTime : float = 99.9
var totalFrameTime : float = 0

#Bandwidth
var totalUploadSnapshot : int = 0
var totalDownloadSnapshot : int = 0

func _ready() -> void:
	PixelSandbox.onDebugStateChange.connect(updateUI)

func _process(delta: float) -> void:
	visible = true
	
	updateFPSTimes(delta)
	framesSincelastInterval += 1
	
	t += delta
	if t < updateInterval: return
	t -= updateInterval
	
	updateUI(PixelSandbox.debugState)
	
	framesSincelastInterval = 0
	cleatFPSTimes()
	updateBandwidthSnapshots()


func updateUI(debugState : PixelSandbox.DEBUG_STATES):
	%TerrainRenderingValues.text = ""
	%TerrainRenderingValues.text += "Ave FPS: %s\n" % str(1.0 / (totalFrameTime / float(framesSincelastInterval)))
	%TerrainRenderingValues.text += "    High: %s\n" % str(1.0 / highestFrameTime)
	%TerrainRenderingValues.text += "    Low: %s\n" % str(1.0 / lowestFrameTime)
	match debugState:
		PixelSandbox.DEBUG_STATES.TEXTURE_SCROLL:
			%TerrainRenderingValues.text += "TextureWrapCount: %.3v\n" % TerrainRendering.textureWrapCount
			%TerrainRenderingValues.text += "TextureWrapPixelOffset: %.0v\n" % TerrainRendering.textureWrapPixelOffset
			%TerrainRenderingValues.text += "CameraPosition: %.3v\n" % TerrainRendering.cameraPosition
			%TerrainRenderingValues.text += "CameraChunkPixelProgress: %.0v\n" % TerrainRendering.cameraChunkPixelProgress
			%TerrainRenderingValues.text += "isServer?: " + ("True" if NetworkManager.isServer else "False") + "\n"
		
		PixelSandbox.DEBUG_STATES.NETWORK:
			if !NetworkManager.isServer:
				%TerrainRenderingValues.text += "Client ID: %s\n" % str(ClientNetworkGlobals.id)
			else:
				%TerrainRenderingValues.text += "--- Server ---\n"
			%TerrainRenderingValues.text += "Upload (bytes) per sec: %s\n" % str(NetworkManager.bytesUploaded - totalUploadSnapshot)
			%TerrainRenderingValues.text += "Download (bytes) per sec: %s\n" % str(NetworkManager.bytesDownloaded - totalDownloadSnapshot)
			
		_:
			%TerrainRenderingValues.text = ""

func updateBandwidthSnapshots():
	totalUploadSnapshot = NetworkManager.bytesUploaded
	totalDownloadSnapshot = NetworkManager.bytesDownloaded

func updateFPSTimes(delta : float):
	highestFrameTime = max(delta, highestFrameTime)
	lowestFrameTime = min(delta, lowestFrameTime)
	totalFrameTime += delta

func cleatFPSTimes():
	highestFrameTime = -1.0
	lowestFrameTime = 99.9
	totalFrameTime = 0.0
