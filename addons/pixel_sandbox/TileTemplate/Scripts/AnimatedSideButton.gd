extends Button
class_name AnimatedSideButton

@export var tt : BlueprintUI

var prevAnimation : String = ""


func _on_mouse_entered() -> void:
	if !button_pressed:
		$AnimationPlayer.play("Hover")
		prevAnimation = "Hover"

func _on_mouse_exited() -> void:
	if !button_pressed and prevAnimation == "Hover":
		$AnimationPlayer.play("UnHover")
		prevAnimation = "UnHover"

func _on_toggled(toggled_on: bool) -> void:
	if toggled_on:
		$AnimationPlayer.play("Select")
		prevAnimation = "Select"
		if tt.activeSideButton:
			if tt.activeSideButton != self:
				tt.activeSideButton.button_pressed = false
		tt.activeSideButton = self
	else:
		if tt.activeSideButton:
			if tt.activeSideButton == self:
				tt.activeSideButton = null
		$AnimationPlayer.play("Reset")
		prevAnimation = "Reset"

func snapToTilemap(globPos : Vector2) -> Vector2:
	if is_instance_valid(get_viewport().get_camera_2d()):
		var scallar : Vector2 = getScallar()
		var camPos := get_viewport().get_camera_2d().get_screen_center_position()
		var camFract : Vector2 = ((camPos) - floor(camPos)) * scallar
		var pos := globPos
		
		pos += camFract
		pos = pos.snapped(scallar)
		pos -= camFract
		
		return pos
	return Vector2.ZERO

func getScallar() -> Vector2:
	if is_instance_valid(get_viewport().get_camera_2d()):
		return get_viewport().get_camera_2d().zoom
	return Vector2.ZERO

func use():
	pass

func altUse():
	pass
