extends SceneTree
## Headless smoke test: Godot --headless --path . -s tests/nose_indicator_test.gd

var _done := false

func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	_run()
	return true

func _run() -> void:
	var c := Vector2(400, 300)
	var r := NoseIndicator.clamp_to_edge(Vector2(420, 310), c, 200.0, false)
	assert(not r.clamped and r.pos == Vector2(420, 310), "inside the circle stays put")
	r = NoseIndicator.clamp_to_edge(Vector2(1400, 300), c, 200.0, false)
	assert(r.clamped and is_equal_approx(r.pos.distance_to(c), 200.0) and r.pos.x > c.x, "outside clamps to the circle")
	r = NoseIndicator.clamp_to_edge(Vector2(0, -1), c, 200.0, true)
	assert(r.clamped and r.pos.y < c.y and is_equal_approx(r.pos.distance_to(c), 200.0), "behind bearing lands on the circle")

	var ui = load("res://scenes/gameplay/ui/ui_layer.tscn").instantiate()
	var ni = ui.get_node_or_null("%NoseIndicator")
	assert(ni != null, "HUD has NoseIndicator")
	ni.update_nose(Vector3.ZERO, Vector3.FORWARD)
	ni._process(1.0 / 60.0)
	assert(not ni._visible, "no camera hides the marker")
	ni.clear()
	assert(not ni._has_data, "clear drops data")
	ui.free()

	# With a camera: nose straight ahead projects to screen center; nose behind clamps with a bearing.
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.global_position = Vector3(0, 0, 8)
	var vp_size := root.get_visible_rect().size
	var p = NoseIndicator.project_direction(cam, Vector3.ZERO, Vector3.FORWARD, 200.0)
	assert(not p.behind, "forward point is in front")
	assert(p.pos.distance_to(vp_size * 0.5) < 1.0, "forward nose sits at screen center")
	p = NoseIndicator.project_direction(cam, Vector3.ZERO, Vector3.BACK, 200.0)
	assert(p.behind, "back point is behind")
	p = NoseIndicator.project_direction(cam, Vector3.ZERO, Vector3(0, 0.5, -1).normalized(), 200.0)
	assert(not p.behind and p.pos.y < vp_size.y * 0.5, "nose up projects above center")
	p = NoseIndicator.project_direction(cam, Vector3.ZERO, Vector3(0, 1, 0.01).normalized(), 200.0)
	assert(p.behind and p.pos.y < 0.0, "grazing nose-up becomes an upward bearing")
	cam.free()
	print("nose_indicator_test: OK")
