extends AnimatedSideButton

func use():
	var b : Blueprint = Blueprint.new()
	
	var chunkCoord := TerrainDestruction.foreground.worldToChunk(get_global_mouse_position())
	var chunk : TextureChunk = TerrainDestruction.foreground.chunks[chunkCoord.x][chunkCoord.y]
	b.setup(chunk.tilemapArrayTex)
	
	BlueprintManager.saveBlueprint(b)
	
	button_pressed = false
	$AnimationPlayer.play("Use")
	
