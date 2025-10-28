extends Button

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
	else:
		$AnimationPlayer.play("Reset")
		prevAnimation = "Reset"
