extends Button
class_name AnimatedSideButton

@export var tt : TileTemplateUI

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

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("TileTemplateUse") and tt.activeSideButton == self:
		if tt.canUseSideButton():
			use()

func use():
	pass
