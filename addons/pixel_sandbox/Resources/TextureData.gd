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

func getBorderGradientArray(numOfTextures : int) -> Texture2DArray:
	var tex2dArray := Texture2DArray.new()
	var imageArray : Array[Image] = []
	for i in range(numOfTextures):
		var im : Image
		im = getBorderGradient(i).get_image()
		im.convert(Image.FORMAT_RGBA8)
		imageArray.append(im)
	
	tex2dArray.create_from_images(imageArray)
	
	return tex2dArray

func getBorderTexture(numOfTextures : int) -> Image:
	var borderColors : Image = Image.create_empty(numOfTextures, 1, false, Image.FORMAT_RGBA8)
	for i in range(numOfTextures):
		borderColors.set_pixel(i, 0, getBorder(i))
	
	#var bcTex : ImageTexture = ImageTexture.create_from_image(borderColors)
	
	return borderColors

func getBorderParamArray(numOfTextures : int) -> PackedVector2Array:
	var borderParams : Array[Vector2] = []
	for i in range(numOfTextures):
		borderParams.append(getBorderParams(i))
	
	return PackedVector2Array(borderParams)

func getReflectivenessArray(numOfTextures : int) -> PackedFloat32Array:
	var reflectivenessArray : Array[float] = []
	for i in range(numOfTextures):
		reflectivenessArray.append(getIndexReflectiveness(i))
	
	return PackedFloat32Array(reflectivenessArray)

func getSolidArray(numOfTextures : int) -> PackedInt32Array:
	var solidArray : Array[bool] = []
	for i in range(numOfTextures):
		solidArray.append(isIndexSolid(i))
	
	return PackedInt32Array(solidArray)

func getLightEmissionTexture(numOfTextures : int) -> Image:
	var emissionColors : Image = Image.create_empty(numOfTextures, 1, false, Image.FORMAT_RGBAF)
	for i in range(numOfTextures):
		emissionColors.set_pixel(i, 0, getLightEmission(i))
	
	return emissionColors




func getTexture(index : int) -> Texture2D:
	if index < materials.size():
		if materials[index]:
			return materials[index].texture
	return errorTexture


func getNormal(index : int) -> Texture2D:
	if index < materials.size():
		if materials[index]:
			return materials[index].normal
	return errorTexture


func getGradient(index : int) -> Texture2D:
	if index < materials.size():
		if materials[index]:
			return materials[index].gradient
	return errorGrad

func getBorderGradient(index : int) -> Texture2D:
	if index < materials.size():
		if materials[index]:
			var g : GradientTexture1D = materials[index].borderGradient
			if g:
				return g
	return errorGrad


func getBorder(index : int) -> Color:
	if index < materials.size():
		if materials[index]:
			return materials[index].border
	return Color.DEEP_PINK

func getBorderParams(index : int) -> Vector2:
	if index < materials.size():
		if materials[index]:
			return Vector2(materials[index].borderSize, materials[index].borderWeight)
	return Vector2(4.0, 0.2)

func getIndexReflectiveness(index : int) -> float:
	if index < materials.size():
		if materials[index]:
			return materials[index].reflectiveness
	return 0.0

func isIndexSolid(index : int) -> bool:
	if index < materials.size():
		return materials[index].isSolid
	return true

func getLightEmission(index : int) -> Color:
	if index < materials.size():
		if materials[index]:
			return materials[index].lightEmission
	return Color(0.0, 0.0, 0.0, 0.0)
