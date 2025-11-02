extends Panel
class_name BlueprintElement


var blueprint : Blueprint
var tileTemplateUI : BlueprintUI
var filePath : String
var isSample : bool

var drawLayer : Blueprint.DRAWLAYER = Blueprint.DRAWLAYER.BOTH

func changeDrawLayer(newLayer : Blueprint.DRAWLAYER):
	if drawLayer != newLayer:
		drawLayer = newLayer
		$AnimationPlayer.play("DrawLayerSwitch")

func setup(b : Blueprint, tt : BlueprintUI, file : String, isSampleElement : bool = false):
	blueprint = b
	tileTemplateUI = tt
	filePath = file
	
	blueprint.ready()
	
	drawLayer = blueprint.drawLayer
	updateDrawlayerIcon()
	
	var tex2dRD := Texture2DRD.new()
	tex2dRD.texture_rd_rid = b.thumbnailRIDForeground
	%Foreground.texture = tex2dRD
	
	tex2dRD = Texture2DRD.new()
	tex2dRD.texture_rd_rid = b.thumbnailRIDBackground
	%Background.texture = tex2dRD
	
	isSample = isSampleElement
	if isSample:
		custom_minimum_size /= 2.0
	
	pivot_offset = custom_minimum_size / 2.0

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

func updateDrawlayerIcon() -> void:
	match drawLayer:
		Blueprint.DRAWLAYER.FOREGROUND:
			%ForegroundBackgroundTexture.texture.region = Rect2(0, 0, 20, 20)
			%Foreground.modulate.a = 1.0
			%Background.modulate.a = 0.3
			%Foreground.z_index = 1
			%Background.z_index = 0
		Blueprint.DRAWLAYER.BACKGROUND:
			%ForegroundBackgroundTexture.texture.region = Rect2(20, 0, 20, 20)
			%Foreground.modulate.a = 0.3
			%Background.modulate.a = 1.0
			%Foreground.z_index = 0
			%Background.z_index = 1
		Blueprint.DRAWLAYER.BOTH:
			%ForegroundBackgroundTexture.texture.region = Rect2(40, 0, 20, 20)
			%Foreground.modulate.a = 1.0
			%Background.modulate.a = 1.0
			%Foreground.z_index = 1
			%Background.z_index = 0

func _on_button_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				pass
			MOUSE_BUTTON_RIGHT:
				match drawLayer:
					Blueprint.DRAWLAYER.FOREGROUND:
						changeDrawLayer(Blueprint.DRAWLAYER.BACKGROUND)
						blueprint.drawLayer = drawLayer
						updateDrawlayerIcon()
					Blueprint.DRAWLAYER.BACKGROUND:
						changeDrawLayer(Blueprint.DRAWLAYER.BOTH)
						blueprint.drawLayer = drawLayer
						updateDrawlayerIcon()
					Blueprint.DRAWLAYER.BOTH:
						changeDrawLayer(Blueprint.DRAWLAYER.FOREGROUND)
						blueprint.drawLayer = drawLayer
						updateDrawlayerIcon()
