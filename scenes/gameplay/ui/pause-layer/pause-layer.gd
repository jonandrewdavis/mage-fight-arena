extends CanvasLayer

const PLAYER_ITEM := preload("res://scenes/gameplay/ui/pause-layer/player_list_item.tscn")
var players: Dictionary = {}

func _ready() -> void:
	hide()
	%ResumeButton.pressed.connect(resume)
	%SettingsButton.pressed.connect(func() -> void: %SettingsMenu.show())
	%LeaveButton.pressed.connect(MultiplayerService.leave_game)
	%LoadLevelButton.pressed.connect(_load_level)
	%SettingsMenu.visibility_changed.connect(func() -> void:
		%PauseRoot.visible = not %SettingsMenu.visible
		if not %SettingsMenu.visible:
			%ResumeButton.grab_focus())
	%SettingsMenu.confirm_button_clicked.connect(func() -> void: %SettingsMenu.hide())
	# Any path that closes the menu (Resume, Tab, Esc, code) must hand the mouse back to the game.
	visibility_changed.connect(_sync_mouse_mode)
	multiplayer.peer_connected.connect(_add_player)
	multiplayer.peer_disconnected.connect(_remove_player)
	_add_player(multiplayer.get_unique_id())
	for peer_id in multiplayer.get_peers():
		_add_player(peer_id)
	%HostPanel.visible = MultiplayerService.is_host()
	if MultiplayerService.is_host():
		for key in LevelLoader.LEVEL_DICT:
			%LevelOption.add_item(key)
		%LobbyAddressLabel.text = "Address: " + MultiplayerService.get_lobby_address()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_menu") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_toggle()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_toggle()

func _toggle() -> void:
	if GGT.is_changing_scene() or not MultiplayerService.in_lobby:
		return
	if %SettingsMenu.visible:
		%SettingsMenu.hide()
	elif visible:
		resume()
	else:
		show()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		%ResumeButton.grab_focus()

func resume() -> void:
	%SettingsMenu.hide()
	hide()
	_sync_mouse_mode()

## Captured while playing, visible while any menu is up. Safe to call repeatedly.
func _sync_mouse_mode() -> void:
	if not is_inside_tree() or GGT.is_changing_scene() or not MultiplayerService.in_lobby:
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if visible else Input.MOUSE_MODE_CAPTURED

func _add_player(peer_id: int) -> void:
	if players.has(peer_id):
		return
	var item := PLAYER_ITEM.instantiate()
	item.peer_id = peer_id
	%PlayerList.add_child(item)
	players[peer_id] = item

func _remove_player(peer_id: int) -> void:
	if players.has(peer_id):
		var item: Node = players[peer_id]
		%PlayerList.remove_child(item)
		item.queue_free()
		players.erase(peer_id)

func _load_level() -> void:
	World.change_level(%LevelOption.get_item_text(%LevelOption.selected))
