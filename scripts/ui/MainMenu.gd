extends Control
class_name MainMenu
## Title screen.

const ACCENT := Color(0.29, 0.68, 1.0)

var _difficulty_option: OptionButton
var _best_label: Label


func _ready() -> void:
	AudioManager.set_music_intensity(0)
	get_tree().paused = false
	_build()


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.02, 0.06)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var nebula := TextureRect.new()
	nebula.texture = Art.texture("nebula")
	nebula.stretch_mode = TextureRect.STRETCH_TILE
	nebula.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	nebula.set_anchors_preset(Control.PRESET_FULL_RECT)
	nebula.modulate = Color(0.8, 0.8, 1.0, 0.55)
	add_child(nebula)

	var stars := TextureRect.new()
	stars.texture = Art.texture("starfield")
	stars.stretch_mode = TextureRect.STRETCH_TILE
	stars.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	stars.set_anchors_preset(Control.PRESET_FULL_RECT)
	stars.modulate = Color(1, 1, 1, 0.9)
	add_child(stars)

	var title := Label.new()
	title.text = "NEON VELOCITY"
	title.add_theme_font_size_override("font_size", 76)
	title.add_theme_color_override("font_color", ACCENT)
	title.add_theme_color_override("font_shadow_color", Color(1.0, 0.3, 0.6, 0.6))
	title.add_theme_constant_override("shadow_offset_x", 4)
	title.add_theme_constant_override("shadow_offset_y", 4)
	title.position = Vector2(0, 120)
	title.size = Vector2(1280, 90)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	var subtitle := Label.new()
	subtitle.text = "a procedurally generated retro shooter"
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.9))
	subtitle.position = Vector2(0, 210)
	subtitle.size = Vector2(1280, 30)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(subtitle)

	var box := VBoxContainer.new()
	box.position = Vector2(490, 300)
	box.size = Vector2(300, 320)
	box.add_theme_constant_override("separation", 14)
	add_child(box)

	var new_run := _button(box, "NEW RUN")
	new_run.pressed.connect(_on_new_run)

	_difficulty_option = OptionButton.new()
	for i in GameManager.DIFFICULTIES.size():
		_difficulty_option.add_item(String(GameManager.DIFFICULTIES[i]["name"]), i)
	_difficulty_option.selected = clampi(int(SaveSystem.get_setting("gameplay", "difficulty", 1)), 0, 3)
	_difficulty_option.custom_minimum_size = Vector2(300, 44)
	Style.style_option(_difficulty_option)
	box.add_child(_difficulty_option)

	var settings := _button(box, "SETTINGS")
	settings.pressed.connect(_on_settings)

	var quit := _button(box, "QUIT")
	quit.pressed.connect(_on_quit)

	_best_label = Label.new()
	_best_label.text = "BEST SCORE  %06d" % int(SaveSystem.meta.get("best_score", 0))
	_best_label.add_theme_font_size_override("font_size", 18)
	_best_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.27))
	_best_label.position = Vector2(0, 640)
	_best_label.size = Vector2(1280, 24)
	_best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_best_label)

	var controls := Label.new()
	controls.text = "WASD / arrows move   ·   Z or left click fires   ·   Space dashes   ·   Q / E switch weapon   ·   Esc pauses"
	controls.add_theme_font_size_override("font_size", 15)
	controls.add_theme_color_override("font_color", Color(0.6, 0.6, 0.75))
	controls.position = Vector2(0, 676)
	controls.size = Vector2(1280, 22)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(controls)


func _button(parent: Node, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(300, 46)
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
