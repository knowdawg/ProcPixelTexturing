extends Resource
class_name Blueprint


@export var image : Image
@export var position : Vector2i
@export var canBeDragged : bool = false #If holding down the mouse continously draws this blueprint
var thumbnailRID : RID

func setup(i : Image, pos : Vector2i, draggable : bool = false):
	image = i
	position = pos
	canBeDragged = draggable
	generateThumbnatil()
	

func ready():
	generateThumbnatil()

func generateThumbnatil():
	var rect : Rect2i = Rect2i(0, 0, 0, 0)
	rect.size = image.get_size()
	rect.position = position
	
	thumbnailRID = TerrainRendering.calculateEnviermentalTexture(rect, image, 0)
