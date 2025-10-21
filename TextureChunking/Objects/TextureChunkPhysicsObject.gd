extends RigidBody2D
class_name TextureChunkPhysicsObject


func _physics_process(_delta: float) -> void:
	
	if TerrainRendering.isPositionLoaded(global_position):
		freeze = false
	else:
		freeze = true
