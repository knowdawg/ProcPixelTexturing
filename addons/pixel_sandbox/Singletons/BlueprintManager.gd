extends Node


var blueprintDir : String = "user://Blueprints/"
var blueprints : Dictionary[Blueprint, String]

var dir : DirAccess

signal newBlueprint


func loadBlueprints():
	blueprints.clear()
	if dir.dir_exists(blueprintDir):
		var blueprintFileNames := DirAccess.get_files_at(blueprintDir)
		for fileName in blueprintFileNames:
			var filePath = blueprintDir + fileName
			if ResourceLoader.exists(filePath):
				var bp : Blueprint = load(filePath)
				blueprints[bp] = filePath
	newBlueprint.emit()

func _ready() -> void:
	dir = DirAccess.open("user://")
	if !dir.dir_exists("Blueprints"):
		dir.make_dir("Blueprints")
	loadBlueprints()

func saveBlueprint(blueprint : Blueprint):
	var blueprintSavePath : String = blueprintDir + "bp_" + str(Time.get_unix_time_from_system()) + ".tres"
	ResourceSaver.save(blueprint, blueprintSavePath)
	loadBlueprints()

func deleteBlueprint(bp : Blueprint):
	if blueprints.has(bp):
		var filePath = blueprints[bp]
		if ResourceLoader.exists(filePath):
			dir.remove(filePath)
			blueprints.erase(bp)
			loadBlueprints()
