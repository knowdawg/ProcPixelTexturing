extends Button
class_name BlueprintUITopButton

@export var tt : BlueprintUI

enum topButonType {HIDE, SHOW}
@export var type : topButonType = topButonType.HIDE

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
	if type == topButonType.SHOW:
		tt.showUI()
	if type == topButonType.HIDE:
		tt.hideUI()
