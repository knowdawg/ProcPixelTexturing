extends Resource
class_name TextureData


func getTexture(index : int) -> Texture2D:
	match index:
		0: return sandstoneTexture
		1: return sandTexture
		2: return obsidianTexture
		3: return woodTexture
	return errorTexture #Failed to find


func getNormal(index : int) -> Texture2D:
	match index:
		0: return sandstoneNormal
		1: return sandNormal
		2: return obsidianNormal
		3: return woodNormal
	return errorTexture #Failed to find


func getGradient(index : int) -> Texture2D:
	match index:
		0: return sandstoneGrad
		1: return sandGrad
		2: return obsidianGrad
		3: return woodGrad
	return errorGrad #Failed to find


func getBorder(index : int) -> Color:
	match index:
		0: return sandstoneBorder
		1: return sandBorder
		2: return obsidianBorder
		3: return woodBorder
	return Color.DEEP_PINK #Failed to find


@export_group("misc")
@export var errorTexture : Texture2D
@export var errorGrad : GradientTexture1D

#@export_group("")
#@export var Texture : Texture
#@export var Normal : Texture
#@export var Grad : GradientTexture1D
#@export var Border : Color

@export_group("sandstone")
@export var sandstoneTexture : Texture2D
@export var sandstoneNormal : Texture2D
@export var sandstoneGrad : GradientTexture1D
@export var sandstoneBorder : Color

@export_group("sand")
@export var sandTexture : Texture2D
@export var sandNormal : Texture2D
@export var sandGrad : GradientTexture1D
@export var sandBorder : Color

@export_group("obsidian")
@export var obsidianTexture : Texture2D
@export var obsidianNormal : Texture2D
@export var obsidianGrad : GradientTexture1D
@export var obsidianBorder : Color

@export_group("wood")
@export var woodTexture : Texture2D
@export var woodNormal : Texture2D
@export var woodGrad : GradientTexture1D
@export var woodBorder : Color
