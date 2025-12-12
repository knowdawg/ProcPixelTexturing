extends Resource
class_name GenMaterial


@export var texture : Texture2D
@export var normal : Texture2D
@export var gradient : GradientTexture1D
@export var border : Color

@export var borderSize : float = 4.0
@export var borderWeight : float = 0.2

@export var lightEmission : Color = Color.BLACK
@export var isSolid : bool = true
