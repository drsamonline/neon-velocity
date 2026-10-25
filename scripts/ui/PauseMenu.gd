extends CanvasLayer
class_name PauseMenu
## Escape menu, and the on-screen pause button. Runs while the tree is paused.

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.66)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(320, 0)
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.29, 0.68, 1.0))
	box.add_child(title)

	_button(box, "RESUME").pressed.connect(func() -> void: set_paused(false))
	_button(box, "RESTART RUN").pressed.connect(_on_restart)
	_button(box, "SETTINGS").pressed.connect(_on_settings)
	_button(box, "QUIT TO MENU").pressed.connect(_on_menu)


func _button(parent: Node, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(320, 46)
	button.add_theme_font_size_override("font_size", 20)
	Style.style_button(button)
	button.pressed.connect(func() -> void: AudioManager.play_sfx("ui_click"))
	parent.add_child(button)
	return button


func set_paused(paused: bool) -> void:
	visible = paused
	get_tree().paused = paused
	TouchInput.reset()
	AudioManager.play_sfx("ui_pause")
	EventBus.pause_toggled.emit(paused)


func is_open() -> bool:
	return visible


func _on_restart() -> void:
	set_paused(false)
	GameManager.start_new_run(GameManager.difficulty)
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _on_settings() -> void:
	set_paused(false)
	get_tree().change_scene_to_file("res://scenes/ui/SettingsMenu.tscn")


func _on_menu() -> void:
	set_paused(false)
	GameManager.running = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
