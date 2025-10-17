extends Sprite2D

var rd : RenderingDevice
var textureChunkShaderFile
var textureChunkShader
var pipeline : RID
var enviermentalDataTextureRID : RID
func setupRenderingDevice():
	rd = RenderingServer.get_rendering_device()
	
	textureChunkShaderFile = load("res://TextureChunking/ComputerTest.glsl")
	textureChunkShader = rd.shader_create_from_spirv(textureChunkShaderFile.get_spirv())
	pipeline = rd.compute_pipeline_create(textureChunkShader)
	
	var image = Image.create_empty(512, 512, false, Image.FORMAT_RGBAF);
	image.fill(Color.RED)
	var textureView := RDTextureView.new()
	var textureFormat := RDTextureFormat.new()
	textureFormat.width = 512
	textureFormat.height = 512
	textureFormat.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	textureFormat.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT +
		RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT + 
		RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT + 
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	)
	enviermentalDataTextureRID = rd.texture_create(textureFormat, textureView, [image.get_data()])
	
	var tex2DRD : Texture2DRD = Texture2DRD.new()
	tex2DRD.set_texture_rd_rid(enviermentalDataTextureRID)
	texture = tex2DRD
	
	

func executeTextureChunkShader():
	#Output Buffer Setup
	var outputUniform := RDUniform.new()
	outputUniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	outputUniform.binding = 0
	outputUniform.add_id(enviermentalDataTextureRID)
	
	
	var uniformSet := rd.uniform_set_create([outputUniform], textureChunkShader, 0)
	var computeList = rd.compute_list_begin()
	
	rd.compute_list_bind_compute_pipeline(computeList, pipeline)
	rd.compute_list_bind_uniform_set(computeList, uniformSet, 0)
	rd.compute_list_dispatch(computeList, 8, 8, 1) #Work Groups
	rd.compute_list_end()
