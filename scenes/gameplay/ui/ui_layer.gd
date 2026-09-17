extends CanvasLayer
class_name UILayer

const MENU_SCENE := "res://scenes/menu/menu.tscn"
var exiting := false

@onready var throttle_progress_bar: TextureProgressBar = %ThrottleProgressBar
@onready var health_progress_bar: TextureProgressBar = %HealthProgressBar
@onready var mana_progress_bar: TextureProgressBar = %ManaProgressBar
@onready var roll_texture_bar: TextureProgressBar = %RollTextureBar
@onready var target_hud: TargetHud = %TargetHud
@onready var stick_reticle: StickReticle = %StickReticle
@onready var nose_indicator: NoseIndicator = %NoseIndicator
@onready var arena_warning: Label = %ArenaWarning
@onready var arena_allowance: ProgressBar = %ArenaAllowance

func update_arena_warning(message: String, fraction: float, outside := false) -> void:
	arena_warning.text = message
	arena_warning.get_parent().visible = not message.is_empty()
	arena_warning.modulate = Color.TOMATO if outside else Color.ORANGE
	arena_allowance.value = fraction

func _ready() -> void:
	# World is our Global link.
	World.ui_layer = self
	# Player will use this.

	MultiplayerService.game_exited.connect(_on_game_exited)
	if DebugMenu != null:
		DebugMenu.update_settings_label()
	if GGT.is_changing_scene():
		await GGT.scene_transition_finished
		await get_tree().process_frame
	if not MultiplayerService.in_lobby:
		_on_game_exited()
	elif not exiting:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## macOS releases the capture when the window loses focus; take it back when the game is in front
## and no menu is open.
func _notification(what: int) -> void:
	if what != NOTIFICATION_APPLICATION_FOCUS_IN or exiting or not is_node_ready():
		return
	var pause := get_node_or_null("PauseLayer") as CanvasLayer
	if pause != null and not pause.visible and MultiplayerService.in_lobby and not GGT.is_changing_scene():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_game_exited() -> void:
	if exiting:
		return
	exiting = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if GGT.is_changing_scene():
		await GGT.scene_transition_finished
		await get_tree().process_frame
	GGT.change_scene(MENU_SCENE, {"show_progress_bar": false})
