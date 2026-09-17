extends SceneTree
## Headless smoke test: Godot --headless --path . -s tests/mouse_stick_test.gd

var _done := false

func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	_run()
	return true

func _run() -> void:
	var stick := MouseStick.new()
	stick.enabled = true
	root.add_child(stick)
	var r := stick.radius_px

	stick.apply_motion(Vector2(0, -10000))
	assert(is_equal_approx(stick.deflection.length(), r), "deflection clamps at radius")
	assert(stick.value.is_equal_approx(Vector2(0, 1)), "mouse forward = full pitch")

	stick.reset()
	stick.apply_motion(Vector2(10000, 0))
	assert(stick.value.is_equal_approx(Vector2(1, 0)), "mouse right = full yaw right")

	stick.reset()
	stick.apply_motion(Vector2(10000, 10000))
	assert(is_equal_approx(stick.value.length(), 1.0), "diagonal clamps to the ring, not the square")
	assert(stick.value.x > 0.0 and stick.value.y < 0.0, "diagonal keeps direction")

	stick.reset()
	stick.apply_motion(Vector2(0, -r * stick.dead_zone * 0.5 / stick.sensitivity))
	assert(stick.value == Vector2.ZERO, "inside dead zone reads zero")
	assert(stick.display_value().length() > 0.0, "display still shows deflection inside dead zone")

	stick.reset()
	stick.apply_motion(Vector2(0, -r * 0.55 / stick.sensitivity))
	assert(is_equal_approx(stick.value.y, (0.55 - stick.dead_zone) / (1.0 - stick.dead_zone)), "dead zone rescales to 0..1")

	stick.reset()
	stick.apply_motion(Vector2(0, -100))
	assert(is_equal_approx(stick.deflection.y, 100.0 * stick.sensitivity), "sensitivity scales motion")

	stick.invert_y = true
	stick.reset()
	stick.apply_motion(Vector2(0, -10000))
	assert(stick.value.y < 0.0, "invert_y flips pitch only")
	stick.invert_y = false

	for i in 60:
		stick._process(1.0 / 60.0)
	assert(is_equal_approx(stick.value.length(), 1.0), "sticky stick holds without recenter_speed")

	assert(not stick.is_active(), "headless mouse is never captured")
	stick.enabled = false
	assert(stick.value == Vector2.ZERO and stick.deflection == Vector2.ZERO, "disabling resets the stick")

	var player = load("res://player/mage/player_mage.tscn").instantiate()
	player.name = "1"
	player.set_physics_process(false)
	root.add_child(player)
	assert(player.mouse_stick != null, "player has MouseStick")
	assert(player.mouse_stick.enabled, "authority enables the stick")
	player.mouse_stick.apply_motion(Vector2(10000, -10000))
	player._physics_process(1.0 / 60.0)
	assert(player.turn_input.is_zero_approx(), "turn_input is cleared at end of tick")
	player.queue_free()

	var ui = load("res://scenes/gameplay/ui/ui_layer.tscn").instantiate()
	var reticle = ui.get_node_or_null("%StickReticle")
	assert(reticle != null, "HUD has StickReticle")
	reticle.update_stick(Vector2(0.5, 0.5), 250.0, 0.1)
	ui.free()
	print("mouse_stick_test: OK")
