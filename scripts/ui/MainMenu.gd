extends Control
class_name MainMenu
## Title screen. Laid out with containers so it works from a phone in landscape
## to an ultrawide monitor.

const ACCENT := Color(0.29, 0.68, 1.0)

var _difficulty_option: OptionButton


func _ready() -> void:
	AudioManager.set_music_intensity(0)
	get_tree().paused = false
	TouchInput.reset()
	_build()


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.02, 0.06)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	_add_background(Art.texture("nebula"), Color(0.8, 0.8, 1.0, 0.55))
	_add_background(Art.texture("starfield"), Color(1, 1, 1, 0.9))

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(360, 0)
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	var title := Label.new()
	title.text = "NEON VELOCITY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", ACCENT)
	title.add_theme_color_override("font_shadow_color", Color(1.0, 0.3, 0.6, 0.65))
	title.add_theme_constant_override("shadow_offset_x", 4)
	title.add_theme_constant_override("shadow_offset_y", 4)
	box.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "a procedurally generated retro shooter"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9))
	box.add_child(subtitle)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	box.add_child(spacer)

	var new_run := _button(box, "NEW RUN")
	new_run.pressed.connect(_on_new_run)

	_difficulty_option = OptionButton.new()
	for i in GameManager.DIFFICULTIES.size():
		_difficulty_option.add_item(String(GameManager.DIFFICULTIES[i]["name"]), i)
	_difficulty_option.selected = clampi(int(SaveSystem.get_setting("gameplay", "difficulty", 1)), 0, 3)
	_difficulty_option.custom_minimum_size = Vector2(360, 44)
	Style.style_option(_difficulty_option)
	box.add_child(_difficulty_option)

	var settings := _button(box, "SETTINGS")
	settings.pressed.connect(_on_settings)

	var quit := _button(box, "QUIT")
	quit.pressed.connect(_on_quit)

	var best := Label.new()
	best.text = "BEST SCORE  %06d" % int(SaveSystem.meta.get("best_score", 0))
	best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	best.add_theme_font_size_override("font_size", 18)
	best.add_theme_color_override("font_color", Color(1.0, 0.92, 0.27))
	box.add_child(best)

	var hint := Label.new()
	hint.text = "WASD / arrows move   ·   Z or click fires   ·   Space dashes   ·   Q / E weapon   ·   Esc pauses"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -46
	hint.offset_bottom = -14
	hint.offset_left = 24
	hint.offset_right = -24
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.75))
	add_child(hint)

	var version := Label.new()
	version.text = "v%s" % str(ProjectSettings.get_setting("application/config/version", "1.0.0"))
	version.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	version.offset_left = -110
	version.offset_top = -34
	version.offset_right = -16
	version.offset_bottom = -10
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version.add_theme_font_size_override("font_size", 14)
	version.add_theme_color_override("font_color", Color(0.45, 0.45, 0.6))
	add_child(version)


func _add_background(texture: Texture2D, tint: Color) -> void:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.stretch_mode = TextureRect.STRETCH_TILE
	rect.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.modulate = tint
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)


func _button(parent: Node, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(360, 48)
	button.add_theme_font_size_override("font_size", 22)
	Style.style_button(button)
	button.pressed.connect(func() -> void: AudioManager.play_sfx("ui_click"))
	parent.add_child(button)
	return button


func _on_new_run() -> void:
	AudioManager.play_sfx("ui_confirm")
	var difficulty := _difficulty_option.selected
	SaveSystem.save_settings({"gameplay": {"difficulty": difficulty}})
	GameManager.start_new_run(difficulty)
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _on_settings() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/SettingsMenu.tscn")


func _on_quit() -> void:
	get_tree().quit()
