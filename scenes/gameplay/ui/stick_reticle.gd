extends Control
class_name StickReticle
## Mouse-stick reticle after the Chevifier PlaneController prototype: a white ring at the stick
## radius, a red disc for the dead zone, and a white dot at the current deflection.

@export var ring_color := Color.WHITE
@export var ring_width := 5.0
@export var dead_zone_color := Color.RED
@export var dot_color := Color.WHITE
@export var dot_radius := 10.0

var _radius := 250.0
var _dead_zone := 0.1
var _value := Vector2.ZERO

## value: deflection with length <= 1 (+x right, +y forward). radius_px: stick radius in pixels.
func update_stick(value: Vector2, radius_px: float, dead_zone: float) -> void:
	_value = value.limit_length(1.0)
	_radius = radius_px
	_dead_zone = clampf(dead_zone, 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	draw_arc(center, _radius, 0.0, TAU, 64, ring_color, ring_width, true)
	draw_circle(center, _radius * _dead_zone, dead_zone_color)
	# Forward on the mouse = up on screen.
	draw_circle(center + Vector2(_value.x, -_value.y) * _radius, dot_radius, dot_color)
