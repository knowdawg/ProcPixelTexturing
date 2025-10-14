extends Node

#Uses the Jump Flood algroithm to generate a SDF from any passed in texture
#Major Credit to: https://samuelbigos.github.io/posts/2dgi1-2d-global-illumination-in-godot.html

@export var resolution := Vector2i(320, 180)

var baseTexture : Image
#Amoung of passes required for Jump Flood to fill entier texture
var PASSES : int
var viewportPasses : Array[SubViewport] = []

var layer : int = -1
func _process(_delta: float) -> void:
	#TEST CODE
	if Input.is_action_just_pressed("ui_accept"):
		layer += 1
		if layer > viewportPasses.size() - 1:
			layer -= viewportPasses.size()
			$Output.texture = %SDFGenerator.get_texture()
		else:
			$Output.texture = viewportPasses[layer].get_texture()
	
	#%SeedRect.material.set_shader_parameter("image", baseTexture)
	#$Output.texture = %SDFGenerator.get_texture()
	RenderingServer.global_shader_parameter_set("SDF_LIGHT_TEXTURE", %SDFGenerator.get_texture())

func _ready() -> void:
	PASSES = ceil(log(max(resolution.x, resolution.y)) / log(2.0))
	
	%Seed.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	%Seed.size = resolution
	#%SeedRect.size = resolution
	#%SeedRect.material.set_shader_parameter("image", baseTexture)
	
	
	
	for i in range(PASSES):
		
		var offset : float = pow(2.0, PASSES - 1 - i)
		
		var curPassViewport : SubViewport
		if i == 0:
			curPassViewport = %JumpFloodPass
		else:
			curPassViewport = %JumpFloodPass.duplicate(0)
			add_child(curPassViewport)
			curPassViewport.get_child(0).material = curPassViewport.get_child(0).material.duplicate(0)
		
		viewportPasses.append(curPassViewport)
		
		var input_texture : ViewportTexture = %Seed.get_texture()
		if i > 0:
			input_texture = viewportPasses[i - 1].get_texture()
		setVieportParams(curPassViewport, input_texture, offset)
	
	
	%SDFGenerator.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	%SDFGenerator.size = resolution
	#%SDFGenerator.get_child(0).size = resolution
	%SDFGenerator.get_child(0).material.set_shader_parameter("image", viewportPasses[viewportPasses.size() - 1].get_texture())
	
	$Output.texture = %SDFGenerator.get_texture()

func setVieportParams(v : SubViewport, t : ViewportTexture, offset : float):
	v.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	v.size = resolution
	
	#v.get_child(0).size = resolution
	v.get_child(0).material.set_shader_parameter("image", t)
	v.get_child(0).material.set_shader_parameter("offset", offset)
