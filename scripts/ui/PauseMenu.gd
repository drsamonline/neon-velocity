extends CanvasLayer
class_name PauseMenu
## Escape menu. Runs while the tree is paused.

var _panel: Control


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var box := VBoxContainer.new()
	box.position = Vector2(490, 240)
	box.size = Vector2(300, 260)
	box.add_theme_constant_override("separation", 16)
	add_child(box)

	var title := Label.new()
	title.text = "PAUSED"
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.29, 0.68, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var resume := _button(box, "RESUME")
	resume.pressed.connect(func() -> void: set_paused(false))

	var restart := _button(box, "RESTART RUN")
	restart.pressed.connect(_on_restart)

	var settings := _button(box, "SETTINGS")
	settings.pressed.connect(_on_settings)

	var menu := _button(box, "QUIT TO MENU")
	menu.pressed.connect(_on_menu)

	_panel = box


func _button(parent: Node, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(300, 44)
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(func() -> void: AudioManager.play_sfx("ui_click"))
	parent.add_child(button)
	return button


func set_paused(paused: bool) -> void:
	visible = paused
	get_tree().paused = paused
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
