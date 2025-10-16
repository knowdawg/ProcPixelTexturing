@tool
extends Sprite2D


@export var tm : TileMapLayer

#Min -160, -90
#Max 160, 90
var offsetVec : Vector2i = Vector2i(-160, -90)

var tileArrayTex : Image

func setArray() -> void:
	tileArrayTex = Image.create_empty(320, 180, true, Image.FORMAT_BPTC_RGBA)
	tileArrayTex.decompress()
	
	for x in range(320):
		for y in range(180):
			var index := tm.get_cell_source_id(Vector2i(x, y) + offsetVec)
			tileArrayTex.set_pixelv(Vector2i(x, y), Color((index + 1.0) * 0.1, 0.0, 0.0, 1.0))
			if index == -1:
				tileArrayTex.set_pixelv(Vector2i(x, y), Color(0.0, 0.0, 0.0, 0.0))
			
	var imTex : ImageTexture = ImageTexture.create_from_image(tileArrayTex)
	
	RenderingServer.global_shader_parameter_set("TILE_ARRAY_TEXTURE", imTex)


func _ready() -> void:
	setArray()

var moveSpeed = 60.0

func _process(_delta: float) -> void:
	if !Engine.is_editor_hint():
		var c : Camera2D = get_viewport().get_camera_2d()
		if c:
			var cPos : Vector2i = floor(c.global_position)
			RenderingServer.global_shader_parameter_set("WORLD_POSITION", c.global_position)
			global_position = cPos
			offsetVec = Vector2i(-160, -90) + cPos
		
		setArray()
	else:
		setArray()
