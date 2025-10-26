extends Button
class_name BlueprintTrashButton


var prevAnimation : String = ""


func _on_mouse_entered() -> void:
	if !button_pressed:
		$AnimationPlayer.play("Hover")
		prevAnimation = "Hover"

func _on_mouse_exited() -> void:
	if !button_pressed and prevAnimation == "Hover":
		$AnimationPlayer.play("UnHover")
		prevAnimation = "UnHover"

func _on_pressed() -> void:
	$AnimationPlayer.play("Use")
	prevAnimation = "Use"
