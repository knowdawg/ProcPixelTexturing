extends Resource
class_name GenMaterial


@export var texture : Texture2D
@export var normal : Texture2D
@export var gradient : GradientTexture1D
@export var border : Color

@export var borderSize : float = 4.0
@export var borderWeight : float = 0.2

#Light Emission is the color of the tile. If you want the tile to give off light, set its color ocordingly
#If you want if to block light, set its color to (0.0, 0.0, 0.0, 1.0). This should be the default for foreground genMaterials
#If you dont wannt it to block light and not give off light, its color should be (0.0, 0.0, 0.0, 0.0). This should be the default for background genMaterials
@export var lightEmission : Color = Color.BLACK
@export var isSolid : bool = true
