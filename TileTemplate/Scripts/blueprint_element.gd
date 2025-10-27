extends Panel
class_name BlueprintElement


var blueprint : Blueprint
var tileTemplateUI : BlueprintUI
var filePath : String

func setup(b : Blueprint, tt : BlueprintUI, file : String):
	blueprint = b
	tileTemplateUI = tt
	filePath = file
	
	b.ready()
	
	var tex2dRD := Texture2DRD.new()
	tex2dRD.texture_rd_rid = b.thumbnailRID
	$MarginContainer/BlueprintTexture.texture = tex2dRD
	

func deactivate():
	$Button.button_pressed = false

func _on_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		if is_instance_valid(tileTemplateUI.activeElement):
			if tileTemplateUI.activeElement != self:
				tileTemplateUI.activeElement.deactivate()
		tileTemplateUI.activeElement = self
		$AnimationPlayer.play("Selected")
	else:
		if is_instance_valid(tileTemplateUI.activeElement):
			if tileTemplateUI.activeElement == self:
				tileTemplateUI.activeElement = null
		$AnimationPlayer.play("Deselect")

func _process(_delta: float) -> void:
	if $Button.button_pressed:
		$MarginContainer/Selected.visible = true
	else:
		$MarginContainer/Selected.visible = false

var t : Tween
func _ready() -> void:
	t = create_tween()
	
	t.tween_property($MarginContainer/Selected, "border_color", Color(0.5, 1.0, 1.0, 1.0), 1.0).set_ease(Tween.EASE_IN_OUT)
	t.tween_property($MarginContainer/Selected, "border_color", Color(1.0, 1.0, 1.0, 1.0), 1.0).set_ease(Tween.EASE_IN_OUT)
	t.set_loops()
	
	$AnimationPlayer.play("Ready")
