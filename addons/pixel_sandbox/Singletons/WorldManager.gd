extends Node

var worldDir : String = "user://Worlds/"
var worlds : Dictionary[String, World]

var dir : DirAccess

var curWorld : World

signal worldsChanged

func loadWorld(w : World) -> void:
	if worlds.has(w.name):
		curWorld = w
		TerrainRendering.imageForeground = curWorld.worldImageForeground
		TerrainRendering.imageBackground = curWorld.worldImageBackground
		TerrainRendering.dirtyAll()
		print("World Loaded")
		return
	
	printerr("Cannot find world")
	return

func loadWorldsIntoMemory() -> void:
	worlds.clear()
	if dir.dir_exists(worldDir):
		var worldFileNames := DirAccess.get_files_at(worldDir)
		for fileName in worldFileNames:
			var filePath = worldDir + fileName
			if ResourceLoader.exists(filePath):
				var world : World = load(filePath)
				worlds[world.name] = world
	worldsChanged.emit()

func loadWorldIntoMemory(w : World):
	if worlds.has(w.name):
		worlds.erase(w.name)
	
	var filePath = getWorldFilePath(w)
	if ResourceLoader.exists(filePath):
		var world : World = load(filePath)
		worlds[world.name] = world
		worldsChanged.emit()

func removeWorldFromMemotry(w : World):
	if worlds.has(w.name):
		worlds.erase(w.name)
		worldsChanged.emit()
		print("World removed From memory")

func _ready() -> void:
	dir = DirAccess.open("user://")
	if !dir.dir_exists("Worlds"):
		dir.make_dir("Worlds")
	loadWorldsIntoMemory()

func createNewWorld(worldName : String, worldSize : Vector2i) -> void:
	var w : World = World.new()
	w.name = worldName
	w.worldImageForeground = Image.create_empty(worldSize.x, worldSize.y,  false, TerrainRendering.IMAGE_FORMAT)
	w.worldImageForeground.fill(Color(0.0, 0.0, 0.0, 0.0))
	w.worldImageBackground = Image.create_empty(worldSize.x, worldSize.y,  false, TerrainRendering.IMAGE_FORMAT)
	w.worldImageBackground.fill(Color(0.0, 0.0, 0.0, 0.0))
	
	saveWorld(w, false)

func saveCurrentWorld() -> void:
	if !is_instance_valid(curWorld):
		printerr("Could not find Current World")
		return
	saveWorld(curWorld)

func saveWorld(w : World, copyTileData : bool = true):
	var worldName = w.name
	
	if copyTileData:
		w.worldImageForeground = TerrainRendering.imageForeground
		w.worldImageBackground = TerrainRendering.imageBackground
	
	if worlds.has(worldName):
		print("Overwriting existing world")
	else:
		print("Saving New World")
	
	var worldSavePath : String = getWorldFilePath(w)
	ResourceSaver.save(w, worldSavePath)
	loadWorldIntoMemory(w)
	
	print("World Saved!")
	print(worlds)

func deleteWorld(w : World):
	var worldName = w.name
	
	if worlds.has(worldName):
		var filePath = getWorldFilePath(w)
		if ResourceLoader.exists(filePath):
			dir.remove(filePath)
			removeWorldFromMemotry(w)
			print("World Deleted")
			return
	
	printerr("World to be deleted not found")

func getWorldFilePath(w : World) -> String:
	var worldName = w.name
	
	return worldDir + worldName + ".res"
