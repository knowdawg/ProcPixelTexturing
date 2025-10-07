@tool
extends Sprite2D

@export_tool_button("SetArray", "Callable") var setArrayButton = setArray


@export var tm : TileMapLayer

#Min -160, -90
#Max 160, 90
var offsetVec : Vector2i = Vector2i(-160, -90)

var tileArrayTex : Image

func setArray() -> void:
	tileArrayTex = Image.create_empty(320, 180, false, Image.FORMAT_BPTC_RGBA)
	tileArrayTex.decompress()
	
	for x in range(320):
		for y in range(180):
			var index := tm.get_cell_source_id(Vector2i(x, y) + offsetVec)
			tileArrayTex.set_pixelv(Vector2i(x, y), Color((index + 1.0) * 0.1, 0.0, 0.0, 1.0))
	
	var imTex : ImageTexture = ImageTexture.create_from_image(tileArrayTex)
	material.set_shader_parameter("tileArrayTex", imTex)
	#material.set_shader_parameter("RESOLUTION", Vector2(100, 100))

func _ready() -> void:
	setArray()
