### Resource That Stores All GenMaterial Resources and Stores Them all in an array

extends Resource
class_name TextureData

@export var materials : Array[GenMaterial]

@export_group("Error")
@export var errorTexture : Texture2D
@export var errorGrad : GradientTexture1D

func getTextureArray(numOfTextures : int) -> Texture2DArray:
	var tex2dArray := Texture2DArray.new()
	var imageArray : Array[Image] = []
	for i in range(numOfTextures):
		var im : Image
		im = getTexture(i).get_image()
		im.convert(Image.FORMAT_RGBA8)
		imageArray.append(im)
	
	tex2dArray.create_from_images(imageArray)
	
	return tex2dArray

func getNormalArray(numOfTextures : int) -> Texture2DArray:
	var tex2dArray := Texture2DArray.new()
	var imageArray : Array[Image] = []
	for i in range(numOfTextures):
		var im : Image
		im = getNormal(i).get_image()
		im.convert(Image.FORMAT_RGBA8)
		imageArray.append(im)
	
	tex2dArray.create_from_images(imageArray)
	
	return tex2dArray

func getGradientArray(numOfTextures : int) -> Texture2DArray:
	var tex2dArray := Texture2DArray.new()
	var imageArray : Array[Image] = []
	for i in range(numOfTextures):
		var im : Image
		im = getGradient(i).get_image()
		im.convert(Image.FORMAT_RGBA8)
		imageArray.append(im)
	
	tex2dArray.create_from_images(imageArray)
	
	return tex2dArray

func getBorderTexture(numOfTextures : int) -> ImageTexture:
	var borderColors : Image = Image.create_empty(numOfTextures, 1, false, Image.FORMAT_RGBA8)
	for i in range(numOfTextures):
		borderColors.set_pixel(i, 0, getBorder(i))
	
	var bcTex : ImageTexture = ImageTexture.create_from_image(borderColors)
	
	return bcTex

func getTexture(index : int) -> Texture2D:
	if index < materials.size():
		return materials[index].texture
	return errorTexture


func getNormal(index : int) -> Texture2D:
	if index < materials.size():
		return materials[index].normal
	return errorTexture


func getGradient(index : int) -> Texture2D:
	if index < materials.size():
		return materials[index].gradient
	return errorGrad


func getBorder(index : int) -> Color:
	if index < materials.size():
		return materials[index].border
	return Color.DEEP_PINK
