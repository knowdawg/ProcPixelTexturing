extends CanvasLayer


func _ready() -> void:
	%ErrorLabel.text = ""
	
	NetworkManager.onServerStarted.connect(func() -> void:
		visible = false
	)
	NetworkManager.onConnectedToServer.connect(func() -> void:
		visible = false
	)

func _on_join_button_button_up() -> void:
	var error := NetworkManager.startClient(
		%IPLineEdit.text,
		int(%PortLineEdit.text)
	)
	if error == Error.OK:
		return
	%ErrorLabel.text = error_string(error)

func _on_host_button_button_up() -> void:
	var error := NetworkManager.startServer(
		%IPLineEdit.text,
		int(%PortLineEdit.text)
	)
	if error == Error.OK:
		return
	%ErrorLabel.text = error_string(error)
