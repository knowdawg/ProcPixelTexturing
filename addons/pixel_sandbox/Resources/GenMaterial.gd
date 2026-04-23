extends Resource
class_name GenMaterial


@export var texture : Texture2D #Greyscale image
@export var normal : Texture2D #Specular intensity stored in the alpha channel
@export var gradient : GradientTexture1D
@export var border : Color

@export var borderSize : float = 4.0 #How wide the border with have an influcnec on the color
@export var borderWeight : float = 0.5 #How much influence being near the border has on being colored by the border gradient. 0 means its purly based off the texure, 1 means its purly based of of being close to the border
@export var borderGradient : GradientTexture1D

#Light Emission is the color of the tile. If you want the tile to give off light, set its color ocordingly
#If you want if to block light, set its color to (0.0, 0.0, 0.0, 1.0). This should be the default for foreground genMaterials
#If you dont wannt it to block light and not give off light, its color should be (0.0, 0.0, 0.0, 0.0). This should be the default for background genMaterials
@export var lightEmission : Color = Color(0.0, 0.0, 0.0, 0.25) #0.118, 0.25
@export var isSolid : bool = true
