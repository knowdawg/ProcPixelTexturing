extends Node
class_name RadianceCascades

@export var sdfGen : SDFGenerator

@export var debugSprite : Sprite2D;

@export_group("Radiance Cascades Parameters")
@export var cascadeCount : int = 1
@export var initialCascadeRayCount : int = 8
@export var initailCascadeRayLength : int = 2
@export var initialCascadeResolution : Vector2i = Vector2i(64, 64)

var rd : RenderingDevice
var cascadeShaderFile = preload("uid://bisgk0gq36n2y")
var cascadeShader : RID
var cascadePipeline : RID

var cascadeImages : Array[Image] = []
var cascadeImageRIDs : Array[RID] = []

var workGroups : Vector3i

func _ready() -> void:
	setup()

func _process(_delta: float) -> void:
	updateGlobalIllumination()

func updateGlobalIllumination():
	for i in range(len(cascadeImageRIDs)):
		#Find an elegant way to get a light image and thus a light sdf as well
		var lightSDF : RDUniform = TerrainRendering.getUniformImage(bitmap1RID, 0)
		var lightImage : RDUniform = TerrainRendering.getUniformImage(bitmap2RID, 1)
		var outputIm : RDUniform = TerrainRendering.getUniformImage(cascadeImageRIDs[i], 2)
		
		var paramsData := PackedFloat32Array([])
		var params := TerrainRendering.getRIDStorageBufferFloat(paramsData, rd)
		var paramUniform := TerrainRendering.getUniformStorageBuffer(params, 3)
		
		
		var uniformSet : RID = rd.uniform_set_create([lightSDF, lightImage, outputIm, paramUniform], cascadeShader, 0)
		var computeList : int = rd.compute_list_begin()
		
		TerrainRendering.executeComputeShader(workGroups, rd, computeList, cascadePipeline, uniformSet)
		
		rd.free_rid(params)

func setup():
	var imSize := initialCascadeResolution * initialCascadeRayCount
	workGroups = Vector3i(16, 16, 1)
	
	rd = RenderingServer.get_rendering_device()
	cascadeShader = rd.shader_create_from_spirv(cascadeShaderFile.get_spirv())
	cascadePipeline = rd.compute_pipeline_create(cascadeShader)
	
	for i in range(cascadeCount):
		var image := Image.create_empty(imSize.x, imSize.y, false, Image.FORMAT_RGBAF);
		image.fill(Color.BLACK)
		var rid : RID = TerrainRendering.getRIDImage(image, rd)
		
		cascadeImages.append(image)
		cascadeImageRIDs.append(rid)
