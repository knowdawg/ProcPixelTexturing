extends AnimatedSideButton


func use():
	if is_instance_valid(tt.activeElement):
		var i : Image = tt.activeElement.blueprint.image
		var mousePos := TerrainDestruction.foreground.get_global_mouse_position() #mous position is relative to the canvas layer
		TerrainDestruction.addTileImage(mousePos, i, TerrainDestruction.FOREGROUND)
		$AnimationPlayer.stop()
		$AnimationPlayer.play("Use")
