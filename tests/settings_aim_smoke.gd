extends Node
## Headless smoke test with autoloads: Godot --headless --path . res://tests/settings_aim_smoke.tscn

func _ready() -> void:
	var menu = load("res://addons/ggt-core/settings/settings_menu.tscn").instantiate()
	add_child(menu)
	assert(menu.aim_sensitivity_slider != null, "slider path resolves")
	assert(is_equal_approx(menu.aim_sensitivity_slider.value, GGT_GameConfig.get_aim_sensitivity()), "slider shows config value")

	var aim := AimLook.new()
	add_child(aim)
	assert(is_equal_approx(aim.sensitivity, GGT_GameConfig.get_aim_sensitivity()), "AimLook reads config")

	menu.aim_sensitivity_slider.value = 0.3
	assert(is_equal_approx(GGT_GameConfig.get_aim_sensitivity(), 0.3), "slider writes config")
	assert(is_equal_approx(aim.sensitivity, 0.3), "AimLook follows config signal")
	assert(menu.aim_sensitivity_value.text == "0.3", "value label updates")

	var stick := MouseStick.new()
	add_child(stick)
	assert(menu.invert_flight_checkbox != null, "invert checkbox path resolves")
	assert(menu.invert_flight_checkbox.button_pressed == GGT_GameConfig.get_invert_flight(), "checkbox shows config value")
	assert(stick.invert_y == GGT_GameConfig.get_invert_flight(), "MouseStick reads config")
	menu.invert_flight_checkbox.button_pressed = true
	assert(GGT_GameConfig.get_invert_flight(), "checkbox writes config")
	assert(stick.invert_y, "MouseStick follows config signal")
	stick.enabled = true
	stick.apply_motion(Vector2(0, -10000))
	assert(stick.value.y < 0.0, "inverted: forward climbs")
	assert(menu.auto_level_checkbox != null, "auto level checkbox path resolves")
	assert(not menu.auto_level_checkbox.button_pressed, "auto level defaults off")
	menu.auto_level_checkbox.button_pressed = true
	assert(GGT_GameConfig.get_auto_level(), "auto level checkbox writes config")
	GGT_GameConfig.reset()
	assert(not GGT_GameConfig.get_auto_level(), "reset restores auto level off")
	assert(is_equal_approx(aim.sensitivity, GGT_GameConfig.DEFAULT_AIM_SENSITIVITY), "reset restores default")
	assert(stick.invert_y == GGT_GameConfig.DEFAULT_INVERT_FLIGHT, "reset restores invert default")
	assert(stick.value.y > 0.0, "reset re-evaluates stick value")
	assert(InputMap.has_action("toggle_menu"), "toggle_menu action exists")
	var has_tab := false
	for ev in InputMap.action_get_events("toggle_menu"):
		if ev is InputEventKey and ev.physical_keycode == KEY_TAB:
			has_tab = true
	assert(has_tab, "toggle_menu bound to Tab")
	print("settings_aim_smoke OK")
	get_tree().quit()
