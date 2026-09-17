extends Control
class_name NoseIndicator
## Boresight ("nose") marker: where the mage's forward vector points on screen.
## The camera rig lags the body, so under input this marker leads the center reticle and
## slides back as the camera catches up. Screen center is the commanded direction.

## World units along the nose to project. Far enough that the camera's offset behind the
## player is negligible parallax, finite so unproject_position stays stable.
@export var probe_distance := 200.0
@export var nose_color := Color("d03cff")
@export var nose_radius := 10.0
@export var nose_wing := 12.0
@export var line_width := 2.0
## Marker fades toward fade_min_alpha when the nose is within this many pixels of center.
@export var fade_within_px := 6.0
@export_range(0.0, 1.0) var fade_min_alpha := 0.25
## Marker is clamped to a circle of radius min(size)/2 - edge_margin.
@export var edge_margin := 24.0
## Exponential rate toward the projected point. 0 = raw. The camera lag already provides catch-up.
@export_range(0.0, 60.0, 0.5) var smoothing := 0.0

var _origin := Vector3.ZERO
var _nose_dir := Vector3.FORWARD
var _source: Node3D
var _has_data := false

var _screen := Vector2.ZERO
var _visible := false
var _clamped := false
var _outward := Vector2.UP

func _ready() -> void:
	var config := get_node_or_null("/root/GGT_GameConfig")
	if config:
		visible = config.get_show_boresight()
		config.show_boresight_changed.connect(func(value: bool) -> void: visible = value)

func update_nose(origin: Vector3, nose_dir: Vector3, source: Node3D = null) -> void:
	_origin = origin
	_nose_dir = nose_dir
	_source = source
	_has_data = true

func clear() -> void:
	_has_data = false
	_source = null
	_visible = false
	queue_redraw()

## Camera-space depth (world units in front of the camera) below which the point counts as behind.
const MIN_DEPTH := 1.0
## Points more than ~79 degrees off the camera axis (lateral / depth > this) have huge, sign-unstable
## unproject results, so they are treated as behind and reduced to a bearing.
const MAX_LATERAL_RATIO := 5.0

## Screen position of origin + dir * distance. `behind` is true when the point is behind (or nearly
## beside) the camera; `pos` then holds only a unit bearing from center, not a real position.
static func project_direction(camera: Camera3D, origin: Vector3, dir: Vector3, distance: float) -> Dictionary:
	var world := origin + dir * distance
	var local := camera.global_transform.basis.inverse() * (world - camera.global_position)
	if local.z > -MIN_DEPTH or Vector2(local.x, local.y).length() > -local.z * MAX_LATERAL_RATIO:
		var bearing := Vector2(local.x, -local.y)
		if bearing.is_zero_approx():
			bearing = Vector2.UP
		return {"pos": bearing.normalized(), "behind": true}
	return {"pos": camera.unproject_position(world), "behind": false}

## Keep the marker inside a circle around center. When behind, `p` is a bearing (see project_direction)
## and the result sits on the circle in that direction.
static func clamp_to_edge(p: Vector2, center: Vector2, radius: float, behind: bool) -> Dictionary:
	var d := p if behind else p - center
	if not behind and d.length() <= radius:
		return {"pos": p, "clamped": false}
	if d.is_zero_approx():
		d = Vector2.UP
	return {"pos": center + d.normalized() * radius, "clamped": true}

func _process(delta: float) -> void:
	var viewport := get_viewport()
	var camera: Camera3D = viewport.get_camera_3d() if viewport else null
	if camera == null or not _has_data:
		if _visible:
			_visible = false
			queue_redraw()
		return
	var origin := _origin
	var dir := _nose_dir
	if _source != null and is_instance_valid(_source) and _source.is_inside_tree():
		var xf := _source.get_global_transform_interpolated()
		origin = xf.origin
		dir = -xf.basis.z
	var center := size * 0.5
	var radius := maxf(minf(size.x, size.y) * 0.5 - edge_margin, 1.0)
	var projected := project_direction(camera, origin, dir, probe_distance)
	var clamped := clamp_to_edge(projected.pos, center, radius, projected.behind)
	var target: Vector2 = clamped.pos
	_clamped = clamped.clamped
	_outward = (target - center).normalized() if not (target - center).is_zero_approx() else Vector2.UP
	if smoothing > 0.0 and _visible:
		_screen = _screen.lerp(target, 1.0 - exp(-smoothing * delta))
	else:
		_screen = target
	_visible = true
	queue_redraw()

func _draw() -> void:
	if not _visible:
		return
	var center := size * 0.5
	var err := _screen.distance_to(center)
	var alpha := lerpf(fade_min_alpha, 1.0, clampf(err / maxf(fade_within_px, 0.001), 0.0, 1.0))
	var c := Color(nose_color, nose_color.a * alpha)
	if _clamped:
		_draw_chevron(_screen, _outward, c)
		return
	var p := _screen
	draw_arc(p, nose_radius, 0.0, TAU, 32, c, line_width, true)
	draw_circle(p, 2.0, c)
	draw_line(p + Vector2(nose_radius, 0), p + Vector2(nose_radius + nose_wing, 0), c, line_width, true)
	draw_line(p - Vector2(nose_radius, 0), p - Vector2(nose_radius + nose_wing, 0), c, line_width, true)
	draw_line(p - Vector2(0, nose_radius), p - Vector2(0, nose_radius + nose_wing * 0.5), c, line_width, true)

## Small ">" at the clamp point, pointing away from center.
func _draw_chevron(p: Vector2, outward: Vector2, c: Color) -> void:
	var side := Vector2(-outward.y, outward.x)
	var tip := p + outward * nose_radius * 0.5
	var back := p - outward * nose_radius
	draw_line(tip, back + side * nose_radius, c, line_width, true)
	draw_line(tip, back - side * nose_radius, c, line_width, true)
