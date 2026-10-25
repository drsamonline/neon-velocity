extends Control
class_name SettingsMenu
## Settings: audio, visuals, gameplay. Values are persisted on change.

var _sfx_slider: HSlider
var _music_slider: HSlider
var _crt_check: CheckBox
var _scanline_slider: HSlider
var _shake_check: CheckBox
var _fps_check: CheckBox
var _difficulty_option: OptionButton


func _ready() -> void:
	get_tree().paused = false
	_build()
	_load_values()


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.02, 0.06)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := VBoxContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	panel.add_theme_constant_override("separation", 14)
	center.add_child(panel)

	var title := Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.29, 0.68, 1.0))
	panel.add_child(title)

	_sfx_slider = _slider_row(panel, "SFX volume")
	_music_slider = _slider_row(panel, "Music volume")
	_crt_check = _check_row(panel, "CRT overlay")
	_scanline_slider = _slider_row(panel, "Scanline intensity")
	_shake_check = _check_row(panel, "Screen shake")
	_fps_check = _check_row(panel, "Show FPS")
	_fps_check.toggled.connect(func(on: bool) -> void:
		_apply()
		EventBus.settings_changed.emit("visual", "show_fps", on))

	var difficulty_row := _row(panel, "Default difficulty")
	_difficulty_option = OptionButton.new()
	for i in GameManager.DIFFICULTIES.size():
		_difficulty_option.add_item(String(GameManager.DIFFICULTIES[i]["name"]), i)
	_difficulty_option.custom_minimum_size = Vector2(240, 36)
	_difficulty_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	Style.style_option(_difficulty_option)
	difficulty_row.add_child(_difficulty_option)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	panel.add_child(spacer)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	panel.add_child(buttons)

	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(200, 46)
	Style.style_button(back)
	back.pressed.connect(_on_back)
	buttons.add_child(back)

	var reset := Button.new()
	reset.text = "RESET"
	reset.custom_minimum_size = Vector2(200, 46)
	Style.style_button(reset)
	reset.pressed.connect(_on_reset)
	buttons.add_child(reset)

	_sfx_slider.value_changed.connect(func(_v: float) -> void: _apply())
	_music_slider.value_changed.connect(func(_v: float) -> void: _apply())
	_scanline_slider.value_changed.connect(func(_v: float) -> void: _apply())
	_crt_check.toggled.connect(func(_on: bool) -> void: _apply())
	_shake_check.toggled.connect(func(_on: bool) -> void: _apply())
	_difficulty_option.item_selected.connect(func(_i: int) -> void: _apply())


func _row(parent: Node, label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(240, 32)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Style.TEXT)
	row.add_child(label)
	return row


func _slider_row(parent: Node, label_text: String) -> HSlider:
	var row := _row(parent, label_text)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(0, 28)
	row.add_child(slider)
	return slider


func _check_row(parent: Node, label_text: String) -> CheckBox:
	var row := _row(parent, label_text)
	var check := CheckBox.new()
	check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	check.custom_minimum_size = Vector2(40, 32)
	check.add_theme_color_override("font_color", Style.TEXT)
	row.add_child(check)
	return check


func _load_values() -> void:
	_sfx_slider.value = float(SaveSystem.get_setting("audio", "sfx_volume", 0.8)) * 100.0
	_music_slider.value = float(SaveSystem.get_setting("audio", "music_volume", 0.6)) * 100.0
	_crt_check.button_pressed = bool(SaveSystem.get_setting("visual", "crt_enabled", true))
	_scanline_slider.value = float(SaveSystem.get_setting("visual", "scanlines", 0.6)) * 100.0
	_shake_check.button_pressed = bool(SaveSystem.get_setting("visual", "screen_shake", true))
	_fps_check.button_pressed = bool(SaveSystem.get_setting("visual", "show_fps", false))
	_difficulty_option.selected = clampi(int(SaveSystem.get_setting("gameplay", "difficulty", 1)), 0, 3)


func _apply() -> void:
	var settings := {
		"audio": {
			"sfx_volume": _sfx_slider.value / 100.0,
			"music_volume": _music_slider.value / 100.0,
		},
		"visual": {
			"crt_enabled": _crt_check.button_pressed,
			"scanlines": _scanline_slider.value / 100.0,
			"screen_shake": _shake_check.button_pressed,
			"show_fps": _fps_check.button_pressed,
		},
		"gameplay": {
			"difficulty": _difficulty_option.selected,
		},
	}
	SaveSystem.save_settings(settings)
	AudioManager.set_bus_volume(AudioManager.SFX_BUS, settings["audio"]["sfx_volume"])
	AudioManager.set_bus_volume(AudioManager.MUSIC_BUS, settings["audio"]["music_volume"])
	EventBus.settings_changed.emit("audio", "sfx_volume", settings["audio"]["sfx_volume"])
	EventBus.settings_changed.emit("audio", "music_volume", settings["audio"]["music_volume"])
	EventBus.settings_changed.emit("visual", "crt_enabled", settings["visual"]["crt_enabled"])
	EventBus.settings_changed.emit("visual", "scanlines", settings["visual"]["scanlines"])
	EventBus.settings_changed.emit("visual", "screen_shake", settings["visual"]["screen_shake"])


func _on_reset() -> void:
	_sfx_slider.value = 80
	_music_slider.value = 60
	_crt_check.button_pressed = true
	_scanline_slider.value = 60
	_shake_check.button_pressed = true
	_fps_check.button_pressed = false
	_difficulty_option.selected = 1
	_apply()


func _on_back() -> void:
	AudioManager.play_sfx("ui_back")
	if GameManager.running:
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
