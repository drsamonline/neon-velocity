extends CanvasLayer
class_name ModSelect
## Pops up when a mod pickup is collected: pick one of three.

var _buttons: Array[Button] = []
var _choices: Array[String] = []
var _open: bool = false


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	EventBus.mod_choices_offered.connect(open)


func open(choices: Array) -> void:
	if _open or choices.is_empty():
		return
	_open = true
	visible = true
	get_tree().paused = true
	for child in get_children():
		child.queue_free()
	_build(choices)


func _build(choices: Array) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.01, 0.05, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var box := VBoxContainer.new()
	box.position = Vector2(390, 200)
	box.size = Vector2(500, 320)
	box.add_theme_constant_override("separation", 12)
	add_child(box)

	var title := Label.new()
	title.text = "CHOOSE A MOD"
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1.0, 0.92, 0.27))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	_buttons.clear()
	_choices.clear()
	for mod_id in choices:
		_choices.append(String(mod_id))
		var mod: Dictionary = WeaponSystem.MODS[String(mod_id)]
		var button := Button.new()
		button.text = "%s\n%s" % [String(mod["name"]), String(mod["blurb"])]
		button.custom_minimum_size = Vector2(500, 62)
		button.add_theme_font_size_override("font_size", 18)
		var id := String(mod_id)
		button.pressed.connect(func() -> void: _choose(id))
		box.add_child(button)
		_buttons.append(button)


## Pick by index; also used by the number keys and by the automated tests.
func choose(index: int) -> void:
	if not _open or index < 0 or index >= _choices.size():
		return
	_choose(_choices[index])


func _unhandled_input(event: InputEvent) -> void:
	if not _open or not (event is InputEventKey) or not event.is_pressed():
		return
	var key := (event as InputEventKey).physical_keycode
	if key >= KEY_1 and key <= KEY_3:
		choose(key - KEY_1)
		get_viewport().set_input_as_handled()


func _choose(mod_id: String) -> void:
	WeaponSystem.apply_mod(mod_id)
	_close()


func _close() -> void:
	_open = false
	visible = false
	get_tree().paused = false
	for child in get_children():
		child.queue_free()


func is_open() -> bool:
	return _open
