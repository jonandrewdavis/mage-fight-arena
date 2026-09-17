extends Node
class_name MouseStick
## Virtual analog stick driven by mouse motion, after the Chevifier PlaneController prototype.
##
## The prototype confines the cursor to a circle and reads its offset from the center as a stick.
## This game captures the mouse, so relative motion accumulates into a deflection clamped to
## [radius_px] instead. x = yaw, y = pitch, both -1..1 after the dead zone.

## Pixels of mouse travel for full deflection.
@export_range(10.0, 1000.0, 1.0) var radius_px := 250.0
## Deflection (0..1) ignored around center so small jitters don't move the mage.
@export_range(0.0, 0.5, 0.01) var dead_zone := 0.1
## Multiplier on raw mouse motion before it fills the radius.
@export_range(0.05, 5.0, 0.05) var sensitivity := 0.5
## false = push the mouse forward to dive (airplane style, like the prototype). true = forward climbs.
@export var invert_y := false
## How fast the stick springs back to center when the mouse is still. 0 = sticky like the prototype.
@export_range(0.0, 30.0, 0.5) var recenter_speed := 0.0
## While this action is held the mouse belongs to free-look; the stick holds its value.
@export var look_action := "secondary"

## Raw deflection in pixels, length <= radius_px. +x = mouse right, +y = mouse pushed forward (up on screen).
var deflection := Vector2.ZERO
## Stick value, length <= 1, after dead zone and inversion. x = yaw right, y = same sign as the "up" action.
var value := Vector2.ZERO
var enabled := false:
	set(v):
		enabled = v
		set_process(enabled)
		set_process_input(enabled)
		if not enabled:
			reset()

func _ready() -> void:
	set_process(enabled)
	set_process_input(enabled)
	var config := get_node_or_null("/root/GGT_GameConfig")
	if config:
		invert_y = config.get_invert_flight()
		config.invert_flight_changed.connect(func(value: bool) -> void:
			invert_y = value
			_update_value())

func _input(event: InputEvent) -> void:
	if not enabled or not is_active():
		return
	if event is InputEventMouseMotion:
		apply_motion(event.screen_relative)

## True while the mouse is captured and not borrowed by free-look.
func is_active() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not Input.is_action_pressed(look_action)

func apply_motion(rel: Vector2) -> void:
	# Screen y grows downward; pushing the mouse forward is negative rel.y.
	deflection += Vector2(rel.x, -rel.y) * sensitivity
	deflection = deflection.limit_length(radius_px)
	_update_value()

func _process(delta: float) -> void:
	if recenter_speed <= 0.0 or not is_active():
		return
	var weight := 1.0 - exp(-recenter_speed * delta)
	deflection = deflection.lerp(Vector2.ZERO, weight)
	if deflection.length() < 0.5:
		deflection = Vector2.ZERO
	_update_value()

func _update_value() -> void:
	var raw := deflection / radius_px
	var len := raw.length()
	if len <= dead_zone:
		value = Vector2.ZERO
		return
	# Rescale so the edge of the dead zone reads 0 and the rim reads 1.
	var scaled := clampf((len - dead_zone) / (1.0 - dead_zone), 0.0, 1.0)
	value = raw.normalized() * scaled
	if invert_y:
		value.y = -value.y

## Deflection normalized to length <= 1 for HUD display (before dead zone).
func display_value() -> Vector2:
	return deflection / radius_px

func reset() -> void:
	deflection = Vector2.ZERO
	value = Vector2.ZERO
