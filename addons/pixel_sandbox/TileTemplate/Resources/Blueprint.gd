extends Resource
class_name Blueprint


@export var imageForground : Image
@export var imageBackground : Image
@export var position : Vector2i
@export var canBeDragged : bool = false #If holding down the mouse continously draws this blueprint
var thumbnailRIDForeground : RID
var thumbnailRIDBackground : RID

enum DRAWLAYER {
	FOREGROUND,
	BACKGROUND,
	BOTH
}
@export var drawLayer : DRAWLAYER = DRAWLAYER.BOTH

func setup(forIm : Image, backIm : Image, pos : Vector2i, draggable : bool = false):
	imageForground = forIm
	imageBackground = backIm
	position = pos
	canBeDragged = draggable
	generateThumbnatil()
	

func ready():
	generateThumbnatil()

func generateThumbnatil():
	var rect : Rect2i = Rect2i(0, 0, 0, 0)
	rect.size = imageForground.get_size().max(imageBackground.get_size())
	rect.position = position
	
	thumbnailRIDForeground = TerrainRendering.calculateEnviermentalTexture(rect, imageForground, 0)
	thumbnailRIDBackground = TerrainRendering.calculateEnviermentalTexture(rect, imageBackground, 0)
